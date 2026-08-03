#!/bin/sh
# Every relative ../<slug>/SKILL.md cross-link inside skills/**/*.md must resolve on disk.
# Portable POSIX sh; zero runtime deps.
set -u
[ -d skills ] || { echo "FAIL: skills/ not found (run from repo root)"; exit 2; }
status=0
# Skill slugs contain no spaces, so word-splitting the find output is safe here.
for f in $(find skills -type f -name '*.md' | sort); do
  d=$(dirname "$f")
  links=$(grep -oE '\.\./[a-z0-9-]+/SKILL\.md' "$f" | sort -u)
  [ -n "$links" ] || continue
  for link in $links; do
    [ -f "$d/$link" ] || { echo "FAIL $f -> $link (dangling cross-link)"; status=1; }
  done
done
if [ "$status" -eq 0 ]; then
  echo "ok: all inter-skill cross-links resolve"
fi
exit "$status"
