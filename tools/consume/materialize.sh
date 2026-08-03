#!/bin/sh
# materialize.sh — produce a read-only export of a commit.
#
# Usage: materialize.sh <checkout> <sha> <out-dir>
#   <checkout>  a git checkout of the pack (the source of the export)
#   <sha>       the commit to materialize (the pin of record)
#   <out-dir>   a NOT-yet-existing directory to create as the materialization
#
# Env (optional, default-off): MAT_EXCLUDE_SKILLS — space-separated skill slugs
# to OMIT from this materialization. A consumer-side choice (e.g. skills another
# installed plugin already owns), recorded in a read-only .excluded beside
# .skillset; .skillset derives from what remains, so the boot check stays green.
# Fail-closed: a slug that is malformed or absent from the export aborts — a
# typo must not silently ship the very skill it meant to exclude.
#
# On success <out-dir> holds the export of <sha> (no .git), a frozen .skillset
# descriptor derived from its own skills/, read-only (a-w). All-or-nothing:
# failure leaves no partial <out-dir> and exits non-zero. Idempotence and the
# atomic symlink publish are the CALLER's job (bump.sh / install-consumer.sh) —
# this unit only produces a verified directory.
#
# Fidelity: `git archive` of a rev-parse-verified, content-addressed commit is
# deterministic; a COMPLETE extraction (both `git archive` and `tar` exit 0) IS
# that commit's content, so a truncated / disk-full export fails loud. (No
# per-file hash loop — it false-refused non-ASCII paths, symlinks and
# export-ignore entries, and added nothing over git's own object integrity.)
# POSIX sh; needs only git + tar.
set -eu

die() { printf 'materialize: FAIL — %s\n' "$1" >&2; exit 1; }

[ $# -eq 3 ] || die "usage: materialize.sh <checkout> <sha> <out-dir>"
checkout=$1
sha=$2
out=$3

[ -d "$checkout/.git" ] || die "not a git checkout: $checkout"
sha=$(git -C "$checkout" rev-parse --verify --quiet "${sha}^{commit}") \
  || die "not a commit in $checkout: $2"
[ -e "$out" ] && die "out-dir already exists (reap or choose a fresh path): $out"
parent=$(dirname "$out")
[ -d "$parent" ] || die "parent dir does not exist: $parent"

tmp=$(mktemp -d "$parent/.mat.tmp.XXXXXX") || die "mktemp failed"
tar="$tmp.tar"
cleanup() { chmod -R u+w "$tmp" 2>/dev/null || true; rm -rf "$tmp" "$tar"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM HUP

# Archive then extract as TWO checked steps — POSIX sh has no `pipefail`, so a
# piped `git archive | tar` would hide a mid-stream failure. These two exit
# checks are the fidelity guarantee (see header).
git -C "$checkout" archive --format=tar "$sha" >"$tar" || die "git archive failed"
tar -x -f "$tar" -C "$tmp" || die "tar extract failed (truncated / disk-full?)"

# Consumer-side exclusion (default-off; see header). Runs BEFORE the .skillset
# derivation so the descriptor reflects what actually ships.
if [ -n "${MAT_EXCLUDE_SKILLS:-}" ]; then
  for s in $MAT_EXCLUDE_SKILLS; do
    case "$s" in
      *[!a-z0-9-]*) die "exclusion slug malformed (kebab-case only): $s" ;;
    esac
    [ -d "$tmp/skills/$s" ] || die "exclusion slug not in export: $s"
    rm -rf "$tmp/skills/$s" || die "could not exclude: $s"
  done
  for s in $MAT_EXCLUDE_SKILLS; do printf '%s\n' "$s"; done | LC_ALL=C sort >"$tmp/.excluded"
fi

# Freeze the skill-set descriptor from the export's OWN skills/ dirs (never a
# hand-authored list — that would re-introduce a silent drift surface).
# ($1..$3 are saved above, so reusing the positional params for the glob is free.)
set -- "$tmp"/skills/*/
if [ -d "$1" ]; then
  for d in "$@"; do basename "$d"; done | LC_ALL=C sort >"$tmp/.skillset"
else
  : >"$tmp/.skillset"   # a skill-less tier (glob stayed literal) → empty descriptor
fi

chmod -R a-w "$tmp"

# Publish atomically within the same filesystem (rename the fully-built temp).
mv "$tmp" "$out" || die "publish (mv) failed"
[ -f "$out/.skillset" ] || die "post-publish check: $out is not a materialization (lost a rename race?)"
trap - EXIT INT TERM HUP
rm -f "$tar"
printf 'materialize: OK — %s @ %s (%s skills)\n' "$out" "$sha" "$(wc -l <"$out/.skillset" | tr -d ' ')"
