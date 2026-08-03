#!/bin/sh
# check-no-marketplace-artifacts.sh — AC-9 / REQ-10 non-goal fence: the pack ships NO
# marketplace or signing artifacts. FAILS CLOSED if:
#   * any TRACKED file is a marketplace.json / *.sig / *.asc (case-insensitive), or
#   * a tracked .claude-plugin/*.json manifest declares a "marketplace" key (DESIGN's pinned
#     literal) or a signing-related key (a JSON key with a colon, not a word in prose).
# Scans the git index; fail-closed if not inside a git work tree. POSIX sh, zero runtime deps.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd) || { echo "FAIL (fail-closed): cannot resolve repo root"; exit 2; }
cd "$repo" || { echo "FAIL (fail-closed): cannot cd to repo root"; exit 2; }
# git ls-files returns EMPTY (rc=128) outside a work tree — that must not read as "clean".
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "FAIL (fail-closed): not inside a git work tree"; exit 2; }

status=0

# forbidden artifact filenames anywhere in the tree (case-insensitive)
bad=$(git ls-files | grep -Ei '(^|/)marketplace\.json$|\.sig$|\.asc$' || true)
if [ -n "$bad" ]; then
  echo "FAIL: marketplace/signing artifact file(s) present (REQ-10 forbids them):"
  printf '%s\n' "$bad" | sed 's/^/  /'
  status=1
fi

# forbidden KEYS in .claude-plugin/*.json manifests (DESIGN pinned literal + signing keys)
manifests=$(git ls-files | grep -E '(^|/)\.claude-plugin/[^/]*\.json$' || true)
keyed=$(printf '%s\n' "$manifests" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  if grep -Eiq '"(marketplace|signing|signature|signatures|signed|publickey|keyid|cert|certificate)"[[:space:]]*:' -- "$f"; then
    printf '%s\n' "$f"
  fi
done)
if [ -n "$keyed" ]; then
  echo "FAIL: marketplace/signing manifest key(s) in a .claude-plugin manifest (REQ-10):"
  printf '%s\n' "$keyed" | sed 's/^/  /'
  status=1
fi

[ "$status" -eq 0 ] && echo "ok: no marketplace/signing artifacts (REQ-10 non-goal held)"
exit "$status"
