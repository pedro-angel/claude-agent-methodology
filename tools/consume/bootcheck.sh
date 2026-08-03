#!/bin/sh
# bootcheck.sh — tier-independent methodology integrity check.
#
# Usage: bootcheck.sh <skills-root> <tier>
#   Reads ONLY the consumer's tier symlink (<skills-root>/<tier>) and the frozen
#   .skillset inside its target. Asserts the tier resolves and is complete:
#     - symlink absent / dangling                    -> MISSING
#     - .skillset absent or != actual skills/*/ dirs -> PARTIAL
#   On a fault it exits non-zero and writes ONE stderr line ending in the token,
#   matching  ^METHODOLOGY .* (MISSING|PARTIAL)$  (token LAST). Both sides of the
#   skill-set comparison are re-sorted here (LC_ALL=C), so a healthy tier never
#   false-PARTIALs on a producer ordering change. No external record, no CORRUPTED
#   (read-only + produce-time fidelity already cover content).
#
# Must be installed OUTSIDE any tier (by provisioning) so a dangling tier cannot
# disable it. Supersedes the P9 prototype (token-first / .pinned-sha / DRIFTED).
# POSIX sh.
set -eu

# fail <message> <TOKEN>  — token LAST, on stderr, then exit non-zero.
fail() { printf 'METHODOLOGY %s %s\n' "$1" "$2" >&2; exit 1; }

[ $# -eq 2 ] || { printf 'usage: bootcheck.sh <skills-root> <tier>\n' >&2; exit 2; }
root=$1
tier=$2
# A tier is a plugin name; reject anything that isn't (a newline would break the
# single-line token contract; a slash would escape the skills root).
case $tier in "" | *[!A-Za-z0-9._-]*) printf 'bootcheck: invalid tier name\n' >&2; exit 2 ;; esac
dir="$root/$tier"

[ -e "$dir" ] || fail "tier '$tier' does not resolve" MISSING
[ -f "$dir/.skillset" ] || fail "tier '$tier' has no .skillset" PARTIAL

# Compare the frozen .skillset to the export's actual skills/*/ dirs, both re-sorted
# here (string vars — no temp file, so nothing leaks on a signal).
have=$(set -- "$dir"/skills/*/; if [ -d "$1" ]; then for s in "$@"; do basename "$s"; done | LC_ALL=C sort; fi)
want=$(LC_ALL=C sort "$dir/.skillset")
[ "$want" = "$have" ] || fail "tier '$tier' skill set does not match .skillset" PARTIAL

if [ -n "$want" ]; then n=$(printf '%s\n' "$want" | wc -l | tr -d ' '); else n=0; fi
printf 'METHODOLOGY OK — tier %s, %s skill(s)\n' "$tier" "$n"
