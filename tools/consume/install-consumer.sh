#!/bin/sh
# install-consumer.sh — provision a consumer: install a pinned methodology tier
# and wire a tier-independent boot check that fires on every session.
#
# Usage: install-consumer.sh <checkout> <sha> <consumer-root> <config-dir>
#   <checkout>       a git checkout of the pack
#   <sha>            the operator-approved pin (a worker passes its GIVEN sha — it
#                    resolves nothing itself: bump uses sha as both ref + intended)
#   <consumer-root>  a per-consumer-UNIQUE dir for materializations + the boot
#                    check + its log (the caller guarantees uniqueness — REQ-6)
#   <config-dir>     the consumer's Claude config dir (e.g. ~/.claude); the tier
#                    symlink and the SessionStart hook go here
#
# Honors MAT_EXCLUDE_SKILLS via bump.sh → materialize.sh (consumer-side skill
# exclusion — default-off, fail-closed, recorded in the export's .excluded).
# Materializes the pin (via bump.sh), installs bootcheck.sh OUTSIDE any tier (a
# dangling tier can't disable its own check — P13: a SessionStart hook fires even
# headless), registers it as a SessionStart hook, then ASSERTS the wiring or fails
# the provisioning. POSIX sh. The runtime hot path (materialize/bump/boot) is zero-dep;
# this one-shot provisioner uses jq OR python3 for the settings.json merge.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
die() { printf 'install-consumer: FAIL — %s\n' "$1" >&2; exit 1; }

[ $# -eq 4 ] || die "usage: install-consumer.sh <checkout> <sha> <consumer-root> <config-dir>"
checkout=$1
sha=$2
croot=$3
cfg=$4
{ command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; } \
  || die "provisioning needs a JSON tool (jq or python3) to merge settings.json safely"
tier=claude-agent-methodology
# croot/cfg are embedded (single-quoted) in a shell hook command below; a single
# quote in either would break that quoting. Reject it fail-closed (config paths
# never contain one) rather than shell-escaping for a case that shouldn't arise.
case "$croot$cfg" in *"'"*) die "consumer-root and config-dir must not contain a single quote";; esac
mkdir -p "$croot/mat" "$cfg/skills" || die "could not create $croot/mat or $cfg/skills"

# Each install-owned write target must be absent or a plain regular file. Refuse a
# pre-existing symlink (writing through it could clobber an unrelated file — Copilot #25)
# OR any other non-regular type, notably a DIRECTORY: `cp` would copy INTO it and the
# `[ -x ]` wiring assert would still pass (dirs are executable), reporting success with a
# broken hook. Fail loud instead. (Broader untrusted-env tamper-resistance is the
# consumer's structural boundary per SPECS; this is local write-target hygiene.)
for f in "$croot/bootcheck.sh" "$cfg/settings.json"; do
  if [ -L "$f" ] || { [ -e "$f" ] && [ ! -f "$f" ]; }; then
    die "refusing to write to a pre-existing non-regular-file (symlink/dir/...) at: $f"
  fi
done

# 1. Install the pin: materialize + symlink (operator-approved -> auto-approve the
#    exec review; a worker's sha is given, so bump resolves nothing new).
BUMP_ASSUME_YES=1 sh "$here/bump.sh" "$checkout" "$sha" "$sha" "$croot/mat" "$cfg/skills/$tier" \
  || die "bump (materialize + symlink) failed"

# 2. Install the boot check OUTSIDE any tier (a copy at the consumer root).
cp "$here/bootcheck.sh" "$croot/bootcheck.sh" || die "could not install bootcheck.sh"
chmod +x "$croot/bootcheck.sh" || die "could not chmod +x $croot/bootcheck.sh"

# 3. Register a SessionStart hook that runs it every session, appending to a named
#    log. Dedupes any prior methodology boot-check hook (idempotent re-provision).
#    settings.json must be a single well-formed JSON object (a real Claude config is).
#    Merge to a SAME-DIR temp and atomically rename (mirrors materialize.sh), so a
#    concurrent session-start never reads a truncated file. The prior file mode is
#    preserved best-effort — if stat can't report it, the file keeps mktemp's 0600
#    (a safe, more-restrictive fallback), never a widened mode.
log="$croot/.methodology-bootcheck.log"
bootpath="$croot/bootcheck.sh"           # the SPECIFIC hook we install — match this, not a generic
hookcmd="'$bootpath' '$cfg/skills' $tier >> '$log' 2>&1 || true"
settings="$cfg/settings.json"
[ -f "$settings" ] || printf '{}\n' >"$settings" || die "could not initialize $settings"
tmp=$(mktemp "$cfg/.settings.json.XXXXXX") || die "mktemp failed"
trap 'rm -f "$tmp"' EXIT
trap 'rm -f "$tmp"; exit 130' INT TERM HUP
if command -v jq >/dev/null 2>&1; then
  jq --arg cmd "$hookcmd" --arg needle "$bootpath" '
    .hooks = (.hooks // {})
    | .hooks.SessionStart = (
        ((.hooks.SessionStart // [])
         | map(.hooks = ((.hooks // []) | map(select(((.command // "") | tostring) | contains($needle) | not))))
         | map(select((.hooks | length) > 0)))
        + [ { "hooks": [ { "type": "command", "command": $cmd } ] } ]
      )
  ' "$settings" >"$tmp" || die "settings.json merge failed (jq; is it a well-formed JSON object?)"
else
  HOOKCMD="$hookcmd" NEEDLE="$bootpath" python3 - "$settings" >"$tmp" <<'PY' || die "settings.json merge failed (python3; is it a well-formed JSON object?)"
import json, os, sys
needle = os.environ["NEEDLE"]
with open(sys.argv[1]) as f:
    d = json.load(f)
h = d.setdefault("hooks", {})
kept = []
for e in h.get("SessionStart", []):
    hooks = [hh for hh in (e.get("hooks") or []) if needle not in str(hh.get("command", ""))]
    if hooks:
        e = dict(e); e["hooks"] = hooks; kept.append(e)
kept.append({"hooks": [{"type": "command", "command": os.environ["HOOKCMD"]}]})
h["SessionStart"] = kept
json.dump(d, sys.stdout, indent=2)
PY
fi
mode=$(stat -c '%a' "$settings" 2>/dev/null || stat -f '%Lp' "$settings" 2>/dev/null) || mode=
if [ -n "$mode" ]; then chmod "$mode" "$tmp" || die "could not set mode on the new settings.json"; fi
mv "$tmp" "$settings" || die "publish settings.json failed (mv)"
trap - EXIT INT TERM HUP

# 4. Assert the boot-check hook is registered — scoped to .hooks.SessionStart (a JSON
#    tool is guaranteed above), not a raw file grep that a stray substring could green.
#    Fail loud, or the consumer is NOT provisioned.
[ -x "$croot/bootcheck.sh" ] || die "wiring check: bootcheck.sh missing/not executable"
[ -L "$cfg/skills/$tier" ]   || die "wiring check: tier symlink missing"
# Don't suppress the tool's stderr or let a parse failure become a bare set -e exit —
# a failed read here must die LOUD and diagnosable (not a silent non-zero).
if command -v jq >/dev/null 2>&1; then
  ss_ok=$(jq -r --arg needle "$bootpath" 'any(.hooks.SessionStart[]?.hooks[]?; ((.command // "") | tostring) | contains($needle))' "$settings") \
    || die "wiring check: could not parse settings.json (jq)"
else
  ss_ok=$(NEEDLE="$bootpath" python3 -c 'import json,os,sys
needle=os.environ["NEEDLE"]
d=json.load(open(sys.argv[1]))
print("true" if any(needle in str(hh.get("command","")) for e in d.get("hooks",{}).get("SessionStart",[]) for hh in (e.get("hooks") or [])) else "false")' "$settings") \
    || die "wiring check: could not parse settings.json (python3)"
fi
[ "$ss_ok" = true ] || die "wiring check: SessionStart boot-check hook not registered"

printf 'install-consumer: OK — %s pinned @ %s + boot check wired (log: %s)\n' "$tier" "$sha" "$log"
