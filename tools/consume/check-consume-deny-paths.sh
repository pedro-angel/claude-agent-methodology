#!/bin/sh
# check-consume-deny-paths.sh — collect the enumerated deny-path tests, run them, and
# FAIL CLOSED if the set is empty or an enumerated member has no test file.
#
# The 10-member EXPECTED set below is the source of truth; SPECS AC-9 + DESIGN mirror it
# (grown from 9 on 2026-08-02: +t_exclude_unknown_refused, the exclusion fail-closed path).
# Slice D wires this into the pre-commit gate + CI, scoped to tools/consume/ changes; the
# generic templates/git-controls mirror carries the hook dormant, not this script.
# Fail-closed-on-missing IS the meta-property (removing a member's file reddens the gate;
# t_collector_fails_closed asserts exactly that).
set -u
here=$(cd "$(dirname "$0")" && pwd)
tests_dir="$here/tests"

# The enumerated deny-path set (completes across the remaining slices):
EXPECTED="t_export_fidelity_mismatch t_sha_mismatch t_force_refused t_first_resolution_wins t_reap_preserves_current_previous t_review_fail_closed t_missing t_partial t_wiring_absent_at_provision t_exclude_unknown_refused"

[ -n "$EXPECTED" ] || { echo "FAIL (fail-closed): the enumerated deny-path set is empty"; exit 1; }

status=0
n=0
for name in $EXPECTED; do
  n=$((n + 1))
  f="$tests_dir/$name"
  if [ ! -f "$f" ]; then
    echo "FAIL (fail-closed): enumerated deny-path '$name' has no test file"
    status=1
    continue
  fi
  if sh "$f" >/dev/null 2>&1; then
    echo "ok: $name"
  else
    echo "FAIL: deny-path test '$name' did not pass"
    status=1
  fi
done
[ "$status" -eq 0 ] && echo "ok: all $n enumerated deny-path test(s) pass"
exit "$status"
