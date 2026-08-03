#!/bin/sh
# Every skills/<slug>/SKILL.md must open with YAML frontmatter carrying:
#   name: <slug>            (must equal the directory slug)
#   description: Use when ...
# Portable POSIX sh — no bashisms, no process substitution. Zero runtime deps.
set -u
[ -d skills ] || { echo "FAIL: skills/ not found (run from repo root)"; exit 2; }
ls skills/*/SKILL.md >/dev/null 2>&1 || { echo "FAIL: no skills/*/SKILL.md found"; exit 2; }
status=0
for f in skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  slug=$(basename "$(dirname "$f")")
  # Extract the leading frontmatter block (between the line-1 '---' and the next '---').
  # awk exits 2 if line 1 is not '---'; otherwise prints the block and exits 0.
  fm=$(awk 'NR==1 && $0!="---"{exit 2} NR>1 && $0=="---"{exit 0} NR>1{print}' "$f")
  if [ $? -eq 2 ]; then
    echo "FAIL $f: missing opening '---' frontmatter"; status=1; continue
  fi
  printf '%s\n' "$fm" | grep -q "^name: ${slug}\$" || {
    echo "FAIL $f: frontmatter 'name:' missing or != dir slug '${slug}'"; status=1; }
  printf '%s\n' "$fm" | grep -qE '^description: Use when ' || {
    echo "FAIL $f: 'description:' must start with 'Use when '"; status=1; }
  grep -q '^## Enforcement$' "$f" || {
    echo "FAIL $f: missing '## Enforcement' section (what a machine can check for this principle)"; status=1; }
done
if [ "$status" -eq 0 ]; then
  echo "ok: skill frontmatter (name==slug, 'Use when' description, Enforcement section)"
fi
exit "$status"
