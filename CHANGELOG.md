# Changelog

All notable changes to the pack. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions are the git tags consumers pin (`TAG` + asserted commit).

## [Unreleased]

## [v0.3.1] — 2026-08-30

### Removed

- The reply judge (`tools/claude/reply-judge.sh`, `tools/claude/reply-rubric.txt`) and its
  INSTALL.md step. It graded each finished reply with a headless model call and bounced violations
  back once, so the consumer read every corrected reply twice, paid one extra model call per
  substantial reply, and gained no learning across sessions — the rules it enforced are already in
  the always-on context. Consumers that installed it by hand: remove the `Stop` entry pointing at
  `~/.methodology-consumer/reply-judge.sh` from `~/.claude/settings.json` and delete the two files.

## [v0.3.0] — 2026-08-25

### Added

- `seams-over-speculation` skill and its always-on line ("Design for tomorrow, build for today").

## [v0.2.0]

### Added

- The pack as first consumed by a pinned tag: 18 skills, always-on rules, pinned consumption
  tooling, machine guards.
