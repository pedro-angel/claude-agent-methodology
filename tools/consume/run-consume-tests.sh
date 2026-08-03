#!/bin/sh
# run-consume-tests.sh — run the POSITIVE (non-deny) tools/consume/ tests: the AC-5 proxy,
# the negatives, the hygiene guards, the dedup + collector/scan meta-tests. The enumerated
# deny-path members are run (and their enumeration enforced) by check-consume-deny-paths.sh,
# so they are EXCLUDED here to avoid double-running. Wired as a pre-commit hook (Slice D,
# scoped to tools/consume/). Fails closed if it finds no tests. POSIX sh, zero runtime deps.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tests_dir="$here/tests"
collector="$here/check-consume-deny-paths.sh"

# The deny members are covered by the collector; exclude them here. Safe fallback: if the
# collector's set can't be read, run everything (a superset — nothing is silently skipped).
deny=""
[ -f "$collector" ] && deny=$(grep '^EXPECTED=' "$collector" | sed 's/^EXPECTED="//; s/"$//')

status=0
n=0
for f in "$tests_dir"/t_*; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  # exclude the deny members — literal comparison, not a glob case-pattern
  excluded=no
  for dm in $deny; do
    [ "$dm" = "$name" ] && { excluded=yes; break; }
  done
  [ "$excluded" = yes ] && continue
  n=$((n + 1))
  out=$(sh "$f" 2>&1)          # run ONCE; keep output for diagnostics on failure
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $name"
    printf '%s\n' "$out" | tail -n 3
    status=1
  fi
done

[ "$n" -gt 0 ] || { echo "FAIL (fail-closed): no positive tools/consume tests found under $tests_dir"; exit 1; }
[ "$status" -eq 0 ] && echo "ok: all $n positive tools/consume test(s) pass"
exit "$status"
