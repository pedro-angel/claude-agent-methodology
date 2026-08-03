#!/bin/sh
# _lib.sh — shared helpers for the consumption-tool tests. Sourced, POSIX sh.
# Exposes: $TOOLS, mk_pack, run_rc, scrub, pass, fail.
# shellcheck disable=SC2034  # TOOLS is consumed by the scripts that source this
TOOLS=$(cd "$(dirname "$0")/.." && pwd)

# mk_pack <slug>...  — create a scratch git "pack" checkout with the given skills;
# prints its path.
mk_pack() {
  d=$(mktemp -d)
  (
    cd "$d" || exit 1
    git init -q && git config user.email a@b.c && git config user.name t
    for s in "$@"; do
      mkdir -p "skills/$s"
      printf -- '---\nname: %s\ndescription: Use when %s.\n---\n## Enforcement\nx\n' "$s" "$s" >"skills/$s/SKILL.md"
    done
    git add -A && git commit -qm v1
  ) >/dev/null 2>&1 || return 1
  printf '%s\n' "$d"
}

# mk_bump_pack — a scratch pack with 4 commits; prints "<dir> <v1> <v2> <v3> <v4>".
# v1: skills/alpha=ONE ; v2: alpha=TWO ; v3: +claude-tier/hooks/h.sh ; v4: +skills/beta
mk_bump_pack() {
  d=$(mktemp -d)
  (
    cd "$d" || exit 1
    git init -q && git config user.email a@b.c && git config user.name t
    mkdir -p skills/alpha && printf ONE >skills/alpha/SKILL.md && git add -A && git commit -qm v1
    printf TWO >skills/alpha/SKILL.md && git add -A && git commit -qm v2
    mkdir -p claude-tier/hooks && printf 'echo hi' >claude-tier/hooks/h.sh && git add -A && git commit -qm v3
    mkdir -p skills/beta && printf B >skills/beta/SKILL.md && git add -A && git commit -qm v4
  ) >/dev/null 2>&1 || return 1
  printf '%s %s %s %s %s\n' "$d" \
    "$(git -C "$d" rev-parse HEAD~3)" "$(git -C "$d" rev-parse HEAD~2)" \
    "$(git -C "$d" rev-parse HEAD~1)" "$(git -C "$d" rev-parse HEAD)"
}

# run_rc <cmd...> — run, discard output, print the exit code (no pipe, so the
# code is the command's own, not a pipeline's last stage).
run_rc() { "$@" >/dev/null 2>&1; printf '%s\n' "$?"; }

# scrub <path>... — remove read-only materialization trees (need +w first).
scrub() { for p in "$@"; do [ -n "$p" ] && { chmod -R u+w "$p" 2>/dev/null; rm -rf "$p"; }; done; }

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
