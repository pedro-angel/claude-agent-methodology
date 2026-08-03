#!/bin/sh
# overlap-check.sh — SessionStart guard: no skill ships twice on this machine silently.
# Compares the methodology tier's skills against every OTHER installed skill source
# (other ~/.claude/skills entries + installed plugins) and reports collisions by
# exact name, hyphen-prefix, or token-subsequence (catches adversarial-review ~
# adversarial-lens-review). Warn-only: exits 0 always; the report lands in the
# boot-check log AND on stdout, which Claude Code injects into the session context —
# so the agent itself sees it and must surface it.
# False positive? Record the pair in ~/.methodology-consumer/overlap-allow (one "a b" per line).
set -u
CFG=$HOME/.claude
CROOT=$HOME/.methodology-consumer
LOG=$CROOT/.methodology-bootcheck.log
TIER=$CFG/skills/claude-agent-methodology
tier_name=$(basename "$TIER")
[ -f "$TIER/.skillset" ] || exit 0
tier_slugs=$(cat "$TIER/.skillset")

others=""
for e in "$CFG"/skills/*; do
  [ -e "$e" ] || continue
  [ "$(basename "$e")" = "$tier_name" ] && continue
  [ -f "$e/SKILL.md" ] && others="$others $(basename "$e")"
  if [ -d "$e/skills" ]; then
    for s in "$e"/skills/*/; do [ -d "$s" ] && others="$others $(basename "$s")"; done
  fi
done
pj=$CFG/plugins/installed_plugins.json
if [ -f "$pj" ] && command -v jq >/dev/null 2>&1; then
  for p in $(jq -r '.plugins[][]?.installPath // empty' "$pj" 2>/dev/null); do
    for s in "$p"/skills/*/; do [ -d "$s" ] && others="$others $(basename "$s")"; done
  done
fi
[ -n "$others" ] || exit 0

# subseq A B: every hyphen-token of A appears, in order, in B
subseq() {
  rest=$2
  for t in $(printf '%s' "$1" | tr '-' ' '); do
    case "-$rest-" in *"-$t-"*) rest=${rest#*"$t"} ;; *) return 1 ;; esac
  done
  return 0
}
allowed() {
  [ -f "$CROOT/overlap-allow" ] || return 1
  grep -qx "$1 $2" "$CROOT/overlap-allow" || grep -qx "$2 $1" "$CROOT/overlap-allow"
}

hits=""
for a in $tier_slugs; do
  for b in $others; do
    match=""
    [ "$a" = "$b" ] && match=exact
    [ -z "$match" ] && case "$b" in "$a"-*) match=prefix ;; esac
    [ -z "$match" ] && case "$a" in "$b"-*) match=prefix ;; esac
    [ -z "$match" ] && { subseq "$a" "$b" || subseq "$b" "$a"; } && match=tokens
    [ -n "$match" ] && ! allowed "$a" "$b" && hits="$hits
  tier:$a ~ other:$b ($match)"
  done
done

[ -n "$hits" ] || exit 0
printf 'METHODOLOGY OVERLAP %s —%s\n' "$(date -u +%FT%TZ)" "$hits" >> "$LOG"
cat <<MSG
METHODOLOGY OVERLAP DETECTED — a pack skill duplicates another installed skill:$hits
Agent: tell the user in your FIRST reply. Fix: add the tier slug to EXCLUDES in
~/.methodology-consumer/bump, remove the current materialization, re-run bump
(or record a false positive in ~/.methodology-consumer/overlap-allow).
MSG
exit 0
