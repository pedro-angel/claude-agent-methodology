---
name: seams-over-speculation
description: Use when scoping a design, sizing an implementation, or reviewing a change that generalizes beyond the present requirement — put the future into the design as seams, implement only what today's requirement exercises, and challenge speculative generality once before building it.
---

# The Future Belongs in the Design, Not the Diff

Analysis and design should look ahead; code should not. When designing, name where change is likely and shape the boundary so that change stays cheap — a seam. When implementing, build only what the present requirement exercises. A seam costs one boundary and adds no behavior; a speculative feature costs code, tests, docs, review, and drift for its whole life — and is usually wrong in detail by the time the future it guessed at arrives.

## When to use

Apply when scoping any design, and again when reviewing any diff: does this change carry behavior no present requirement exercises? Apply hardest at the moments generality is cheapest to type — an agent scaffolding a module, a "while I'm here" refactor, a config surface being laid out. Apply symmetrically to the human's requests: a proposal to "make it generic", "support every X", or "add a plugin system" gets the same look as your own impulse to abstract.

Red-flag thoughts — if you catch yourself thinking any of these, STOP and apply this skill:

- "We'll need it later." (Later pays with better information; today pays with a guess.)
- "It's only one extra parameter." (Every parameter is permanent API surface — callers, tests, docs.)
- "While I'm here, I'll make it generic." (That is a second task; scope it on its own.)
- "A registry / plugin system / strategy layer will make this extensible."
- "This abstraction is cleaner." (An abstraction with one caller is indirection, not design.)
- "The human asked for the general version, so the general version is the requirement." (Weigh it, then challenge once.)

## The rule

1. **Design with the future in view.** Name the axes where change is plausible — a second format, a second provider, a bigger scale — and say which are real enough to shape the design. Foresight is analysis work; it is free to be ambitious.
2. **Shape seams, not features.** A seam is a boundary that keeps tomorrow's change cheap without building it: the one interface where a second implementation would attach, the one choke point where a policy would go, a hard-coded default in the single place a parameter would later live. A seam adds no behavior and needs no new tests.
3. **Implement only what the present requirement exercises.** If no current caller, test, or requirement reaches a branch, parameter, flag, or config key, it does not ship. An [additive-default-off-feature-flags](../additive-default-off-feature-flags/SKILL.md) flag guards a capability that exists; a flag for an imagined capability is speculation wearing a safety vest.
4. **Generalize on the second concrete need.** One case is an instance; the first *imagined* case does not count. The second real case brings the information the abstraction actually needs — the axis that truly varies — which the first-day guess almost never has.
5. **Park the future as a note, not code.** A future need real enough to name is recorded — a [decision-memory](../decision-memory/SKILL.md) note, a line in the design doc, an issue — together with the trigger that would activate it. The insight survives; the liability does not ship.
6. **Challenge speculative generality once; the decision wins.** When the human proposes generality beyond the present need, apply [evidence-over-deference](../evidence-over-deference/SKILL.md): name the carrying cost, offer the present-only version plus the seam that keeps their future cheap — once. If they still want it built, build it well.

## Why

The costs are asymmetric. A seam is one boundary, reviewed once. Shipped generality is a standing liability: every future maintainer reads it, tests cover it, docs mention it, security review considers it — and when the anticipated future finally arrives, it usually arrives shaped differently, so the speculative version is deleted anyway, now with a deprecation. Under-building costs one later diff written with better information; over-building costs carrying the wrong thing indefinitely. Agents tilt the field further: generality is now nearly free to type, so the scarce resource is no longer the keystroke — it is the reviewer's attention and every future reader's time. YAGNI predates agents; agents made it binding.

## In practice

This skill was commissioned by a human who named their own tendency: "when analyzing and designing I need to make sure that your gaze is in the future too, but no need to implement the future" — and asked the agent to push back on excess generalization rather than comply with it. That request fixes the shape of the duty: the gaze ahead lives in the design conversation (rules 1–2), the restraint lives in the diff (rules 3–4), and the challenge is owed even — especially — when the speculation is the human's (rule 6).

The call in miniature: asked to "export the report as CSV, and make the exporter pluggable so we can add formats later", the present requirement is one format. The seam is a single `render(report) -> bytes` function the CSV writer sits behind. The speculation is the format registry, the abstract base class, and the second format nobody asked for. Ship the function, park "more formats — trigger: a second real format request" as a note, and say so in one sentence.

## Anti-patterns

- Building the plugin system for the first plugin.
- A parameter, flag, branch, or config key no present caller or test reaches.
- Deep generic machinery — type parameters, strategy registries, layered indirection — for an axis of change nobody named.
- Silently building the human's speculative ask, or silently dropping it; both skip the one challenge owed.
- Refusing the generality but losing the insight: no parked note, so the foresight is re-derived next quarter.
- Spending the challenge on trivia — a name, an ordering, a two-line helper. Below the bar, say nothing (the floor of [evidence-over-deference](../evidence-over-deference/SKILL.md) applies).
- Inverting the rule into timidity: refusing a real present requirement because it is large. The test is whether today's requirement exercises the code, not whether the code is small.

## Enforcement

Little of this is machine-checkable — the judgment lives in the design conversation. What a machine can hold:

- Dead-surface linters (unused parameter, unused export, unreachable branch) catch speculation after the fact.
- Coverage on new code makes rule 3 observable: behavior no test reaches is either untested or unneeded, and both are findings.
- The diff itself: the smallest-correct-diff discipline of [surgical-changes-with-checkpoints](../surgical-changes-with-checkpoints/SKILL.md) gives review a baseline — generality beyond the requirement shows up as size.
- The parked-future trail: [decision-memory](../decision-memory/SKILL.md) gives the note a place to live, so "we did not build it" never decays into "we forgot it".

---

Related skills:

- [../surgical-changes-with-checkpoints/SKILL.md](../surgical-changes-with-checkpoints/SKILL.md)
- [../additive-default-off-feature-flags/SKILL.md](../additive-default-off-feature-flags/SKILL.md)
- [../decision-memory/SKILL.md](../decision-memory/SKILL.md)
- [../evidence-over-deference/SKILL.md](../evidence-over-deference/SKILL.md)
