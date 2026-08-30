# INSTALL — step by step, any host, any user

This takes one user on one machine from nothing to the full methodology: an immutable, reviewed
export of one commit serving every project, always-on rules in every session, a boot check at each
session start, and a one-command update path. Run every block as the user being provisioned.

What you end up with:

| Artifact | Path | Job |
| --- | --- | --- |
| The tier symlink | `~/.claude/skills/claude-agent-methodology` | one link → the pinned, read-only export; serves every project |
| The consumer store | `~/.methodology-consumer/` | materializations, the boot check, its log, your `bump` command |
| Always-on rules | `~/.claude/CLAUDE.md` | the every-turn rules, loaded into every session |
| A SessionStart hook | in `~/.claude/settings.json` | runs the boot check at each session start |

## Step 1 — prerequisites

```sh
command -v git && command -v claude && { command -v jq || command -v python3; } \
  && echo READY || echo MISSING-TOOLS
```

`git` and the `claude` CLI are required everywhere; `jq` *or* `python3` is needed once, for the
provisioning step's settings merge. The user must also be **signed in to Claude** (run `claude`
once interactively and log in) — the Step 5 session checks need a working session.

## Step 2 — get the pack and choose the pin

```sh
git clone https://github.com/pedro-angel/claude-agent-methodology ~/claude-agent-methodology
PACK=~/claude-agent-methodology
SHA=$(git -C "$PACK" rev-parse origin/main)     # or a specific reviewed commit / tag
echo "pinning: $SHA"
```

The pin is the point: your agent consumes this exact commit, read-only, until you deliberately
move it. Review what you pin (`git -C "$PACK" log -1 $SHA`) — choosing it is the approval.

## Step 3 — provision

```sh
sh "$PACK/tools/consume/install-consumer.sh" "$PACK" "$SHA" "$HOME/.methodology-consumer" "$HOME/.claude"
```

The four arguments, in order: the pack checkout, the approved pin, a consumer root unique to this
user, and this user's Claude config dir. On success it prints one `install-consumer: OK` line. It
materializes the pin into a read-only export, links it as the tier, installs the boot check
*outside* the tier (a broken tier can't silence its own alarm), and registers the SessionStart
hook — refusing loudly if any wiring step fails.

If some other installed plugin ever overlaps a skill here, `MAT_EXCLUDE_SKILLS="<slug …>"` before
this command omits the named skills from the materialization, recorded in a read-only `.excluded`.
With superpowers and extended-superpowers, no exclusions are needed — the pack ships disjoint.

## Step 4 — always-on rules and your `bump` command

The rules that must bind every turn live in user memory, not in a skill. Idempotent — safe to
re-run after a bump:

```sh
TIER=$(readlink "$HOME/.claude/skills/claude-agent-methodology")
grep -q 'Reader-first communication' "$HOME/.claude/CLAUDE.md" 2>/dev/null \
  || cat "$TIER/rules/always-on.md" >> "$HOME/.claude/CLAUDE.md"
```

Then install the update command once:

```sh
cat > "$HOME/.methodology-consumer/bump" <<EOF
#!/bin/sh
# bump <ref-or-sha> — THE way to update the methodology for this user.
set -eu
PACK=$PACK
CROOT=\$HOME/.methodology-consumer
[ \$# -eq 1 ] || { echo "usage: bump <ref-or-sha>" >&2; exit 1; }
git -C "\$PACK" fetch origin >/dev/null 2>&1 || true
sha=\$(git -C "\$PACK" rev-parse --verify "\${1}^{commit}")
sh "\$PACK/tools/consume/bump.sh" "\$PACK" "\$sha" "\$sha" "\$CROOT/mat" "\$HOME/.claude/skills/claude-agent-methodology"
tail -1 "\$CROOT/.methodology-bootcheck.log" 2>/dev/null || true
EOF
chmod +x "$HOME/.methodology-consumer/bump"
```

## Step 5 — verify it took

```sh
# 1. the tier resolves with the expected skill count
wc -l "$(readlink "$HOME/.claude/skills/claude-agent-methodology")/.skillset"   # 19

# 2. a real session fires the boot check
claude -p "reply with exactly: ok" >/dev/null 2>&1 || true
tail -1 "$HOME/.methodology-consumer/.methodology-bootcheck.log"   # METHODOLOGY OK — tier claude-agent-methodology, 19 skill(s)

# 3. the rules reach a fresh session
claude -p "Do not use tools. Does your context contain a section titled 'Reader-first communication'? Answer INHERITED or NOT PRESENT."
```

If any check misses, stop and fix before relying on the install — the boot-check log's `MISSING`
or `PARTIAL` token names the fault.

## Step 6 — the machine guard (recommended)

One session hook, fail-open — a broken guard never blocks your work.

**Overlap guard** — warns inside the session if any skill here ever collides with another
installed plugin's skill (exact, prefix, or token-similar name):

```sh
cp "$PACK/tools/claude/overlap-check.sh" "$HOME/.methodology-consumer/"
chmod +x "$HOME/.methodology-consumer/overlap-check.sh"
```

Register it in `~/.claude/settings.json` (append to the existing `hooks` object the provisioner
created):

```json
"SessionStart": [ …existing…, { "hooks": [ { "type": "command", "command": "'$HOME/.methodology-consumer/overlap-check.sh'" } ] } ]
```

## Updating and rolling back

```sh
"$HOME/.methodology-consumer/bump" origin/main    # shows the executable-content diff for review
```

A bump keeps the previous materialization; rollback is re-pointing one symlink:

```sh
ls "$HOME/.methodology-consumer/mat/"
ln -sfn "$HOME/.methodology-consumer/mat/<previous-sha>" "$HOME/.claude/skills/claude-agent-methodology"
```

After a bump, re-run the Step 4 rules block (the guard makes it free) and the Step 5 checks.

## Uninstalling

```sh
rm "$HOME/.claude/skills/claude-agent-methodology"
rm -rf "$HOME/.methodology-consumer"
```

Then delete the boot-check, overlap, and judge entries from `hooks` in `~/.claude/settings.json`,
and remove the every-turn section from `~/.claude/CLAUDE.md` if you no longer want the rules.
