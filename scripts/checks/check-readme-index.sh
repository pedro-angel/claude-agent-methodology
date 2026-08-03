#!/bin/sh
# The README skill-index must list exactly the skills/ directories — no missing, no extra.
# Matches the index links of the form (skills/<slug>/SKILL.md).
# Portable POSIX sh; temp files + comm.
set -u
[ -f README.md ] || { echo "FAIL: README.md not found (run from repo root)"; exit 2; }
[ -d skills ] || { echo "FAIL: skills/ not found (run from repo root)"; exit 2; }
dirs=$(mktemp) || exit 2
rows=$(mktemp) || exit 2
trap 'rm -f "$dirs" "$rows"' EXIT INT TERM
ls -d skills/*/ 2>/dev/null | sed 's#^skills/##; s#/$##' | sort -u > "$dirs"
[ -s "$dirs" ] || { echo "FAIL: no skills found under skills/"; exit 2; }
grep -oE '\(skills/[a-z0-9-]+/SKILL\.md\)' README.md \
  | sed -E 's#\(skills/([a-z0-9-]+)/SKILL\.md\)#\1#' | sort -u > "$rows"
status=0
miss=$(comm -23 "$dirs" "$rows")
extra=$(comm -13 "$dirs" "$rows")
if [ -n "$miss" ]; then
  echo "FAIL: README index is missing these skills:"; printf '  %s\n' $miss; status=1
fi
if [ -n "$extra" ]; then
  echo "FAIL: README index lists non-existent skills:"; printf '  %s\n' $extra; status=1
fi
if [ "$status" -eq 0 ]; then
  echo "ok: README index == skills/ dirs ($(wc -l < "$dirs" | tr -d ' ') rows)"
fi
exit "$status"
