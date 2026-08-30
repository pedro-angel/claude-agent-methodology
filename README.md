# claude-agent-methodology

[![checks](https://github.com/pedro-angel/claude-agent-methodology/actions/workflows/checks.yml/badge.svg)](https://github.com/pedro-angel/claude-agent-methodology/actions/workflows/checks.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An engineering methodology for Claude Code agents: 19 skills for task-matched depth, a set of always-on rules for every reply, and tooling that makes consumption pinned, verified, and duplicate-free.

## What's in the repo

```text
skills/                 One directory per skill; each SKILL.md carries rules, red flags, worked examples.
rules/always-on.md      The rules that bind every turn — append them to your ~/.claude/CLAUDE.md.
tools/consume/          Pinned consumption: materialize, bump, boot check, provisioner, tests.
tools/claude/           Machine guard: a skill-overlap SessionStart check.
scripts/checks/         The validators CI runs on this repo.
INSTALL.md              Step by step, from a bare user to a verified install.
```

## How consumption works

One symlink in `~/.claude/skills/` points at a read-only export of one reviewed commit. A boot check runs at every session start and reports `OK`, `MISSING`, or `PARTIAL`. Updates are deliberate: a bump reviews the diff and re-points the symlink; the previous pin stays for one-command rollback. The overlap guard warns, inside the session itself, if any skill here ever collides with a skill another installed plugin provides.

Install: **[INSTALL.md](INSTALL.md)**.

## Deliberate non-duplication

This pack does not duplicate capabilities the superpowers and extended-superpowers plugins already provide — environment research, adversarial review, acceptance testing, and definition-of-done gating live there. Running those plugins alongside this pack produces zero overlapping skills, and the overlap guard enforces that this stays true.

## The skills

### Designing before building

| Skill | Use it when |
| --- | --- |
| [spec-driven-development](skills/spec-driven-development/SKILL.md) | Starting a non-trivial feature, or docs and code have drifted apart |
| [decision-memory](skills/decision-memory/SKILL.md) | A decision would otherwise be re-derived from scratch next session |
| [seams-over-speculation](skills/seams-over-speculation/SKILL.md) | A design or request generalizes beyond the present requirement |

### Structuring the system

| Skill | Use it when |
| --- | --- |
| [hexagonal-with-enforced-contracts](skills/hexagonal-with-enforced-contracts/SKILL.md) | The app touches external systems — databases, LLMs, cloud SDKs, HTTP APIs |
| [configuration-single-source-of-truth](skills/configuration-single-source-of-truth/SKILL.md) | A value is about to be duplicated across scripts, code, docs, and CI |
| [dev-environment-facade](skills/dev-environment-facade/SKILL.md) | Wiring the dev workflow — local stack, test tiers, gate commands |

### Changing code without breaking it

| Skill | Use it when |
| --- | --- |
| [surgical-changes-with-checkpoints](skills/surgical-changes-with-checkpoints/SKILL.md) | Every edit — smallest correct diff, checkpoint before risky work |
| [additive-default-off-feature-flags](skills/additive-default-off-feature-flags/SKILL.md) | Adding a capability to something that already works |
| [currency-and-audit-before-trust](skills/currency-and-audit-before-trust/SKILL.md) | Reusing inherited code, or making a security-relevant claim |

### Proving it actually works

| Skill | Use it when |
| --- | --- |
| [battle-testing-on-real-infra](skills/battle-testing-on-real-infra/SKILL.md) | About to call an integration or deployment "done" |
| [grounded-verifiable-gates](skills/grounded-verifiable-gates/SKILL.md) | An LLM's output decides what happens next |
| [honest-reframing-over-overclaiming](skills/honest-reframing-over-overclaiming/SKILL.md) | A live result contradicts the story you hoped to tell |

### Working with humans and other agents

| Skill | Use it when |
| --- | --- |
| [evidence-over-deference](skills/evidence-over-deference/SKILL.md) | A request rests on a premise you can check, or a direction you haven't weighed |
| [reversible-by-default-confirm-consequential](skills/reversible-by-default-confirm-consequential/SKILL.md) | An agent can touch systems you don't own |
| [parallel-agent-fan-out](skills/parallel-agent-fan-out/SKILL.md) | Fanning out many write-capable sub-agents across one build |
| [autonomous-self-improvement-loop-safety](skills/autonomous-self-improvement-loop-safety/SKILL.md) | Building automation that edits, tests, or deploys itself |

### Security, secrets, and handoff

| Skill | Use it when |
| --- | --- |
| [structural-security-boundary](skills/structural-security-boundary/SKILL.md) | Containing untrusted or agent-generated execution |
| [secrets-and-teardown-discipline](skills/secrets-and-teardown-discipline/SKILL.md) | Handling credentials, infrastructure-as-code, or ephemeral cloud |
| [docs-as-deliverable](skills/docs-as-deliverable/SKILL.md) | Shipping or handing off code |

Two phrases bind narrowly everywhere: "real infrastructure / live system" means a genuine instance provisioned for the purpose, never the production estate; destructive verbs bind only to resources the current process, test, or change itself created.

## Philosophy

- **Process before code.** Run the relevant process skill before implementing — don't back-fill the design afterward.
- **Machines enforce, not memory.** A linter, a gate, a session hook — encode the discipline so it survives the next contributor who didn't read this.
- **Reality is the only proof.** Mocks prove wiring; only a live run proves the guarantee. An unverified claim is a hope.
- **Reversible by default, a human on the irreversible 1%.** Cheap, undoable work flows freely; consequential acts pause for approval.

## License

[MIT](LICENSE) — copy it into your own projects, proprietary ones included, with no obligation beyond keeping the copyright notice.

*Claude is a trademark of Anthropic, PBC; this project is independent and not affiliated with or endorsed by Anthropic. superpowers and extended-superpowers are third-party plugins by their respective authors.*
