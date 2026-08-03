#!/bin/sh
# reply-judge.sh — Stop-hook judge: checks the session's final reply against the
# every-turn communication rules (rubric beside this script) via a headless
# haiku call, and bounces a violating reply back ONCE for revision.
#
# Off switch (one line):   touch ~/.methodology-consumer/judge-off
# Re-enable:               rm    ~/.methodology-consumer/judge-off
#
# Fail-open by design: any parse, tool, or judge failure exits 0 — a broken
# judge must never block replies. Recursion-proof: the judge's own headless
# session inherits METHODOLOGY_JUDGE=1 and its Stop hook exits immediately.
set -u
[ -f "$HOME/.methodology-consumer/judge-off" ] && exit 0
[ "${METHODOLOGY_JUDGE:-}" = 1 ] && exit 0            # never judge the judge
command -v jq >/dev/null 2>&1 || exit 0
command -v claude >/dev/null 2>&1 || exit 0

input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0   # one bounce max
tp=$(printf '%s' "$input" | jq -r '.transcript_path // .conversation_transcript_path // empty')
[ -n "$tp" ] && [ -f "$tp" ] || exit 0

reply=$(jq -rs '[.[] | select(.type=="assistant")] | last | .message.content | map(select(.type=="text") | .text) | join("\n")' "$tp" 2>/dev/null)
[ -n "$reply" ] || exit 0
[ "$(printf '%s' "$reply" | wc -c | tr -d ' ')" -ge 400 ] || exit 0   # short replies skip the round-trip

rubric="$HOME/.methodology-consumer/reply-rubric.txt"
[ -f "$rubric" ] || exit 0

tmp=$(mktemp) || exit 0
trap 'rm -f "$tmp"' EXIT
{ cat "$rubric"; echo; echo "--- REPLY UNDER REVIEW ---"; printf '%s\n' "$reply"; } \
  | METHODOLOGY_JUDGE=1 claude -p --model haiku >"$tmp" 2>/dev/null &
pid=$!
n=0
while kill -0 "$pid" 2>/dev/null; do
  n=$((n + 1))
  [ "$n" -gt 90 ] && { kill "$pid" 2>/dev/null; exit 0; }   # wedged judge never wedges the session
  sleep 1
done
wait "$pid" 2>/dev/null

out=$(grep -o '{"verdict".*}' "$tmp" | head -1)
[ -n "$out" ] || exit 0
if [ "$(printf '%s' "$out" | jq -r '.verdict // empty' 2>/dev/null)" = "FAIL" ]; then
  rule=$(printf '%s' "$out" | jq -r '.rule // "unknown"')
  reason=$(printf '%s' "$out" | jq -r '.reason // ""')
  printf 'Reply-judge: the final reply violates %s — %s Revise it to satisfy the every-turn communication rules, then finish.\n' "$rule" "$reason" >&2
  exit 2
fi
exit 0
