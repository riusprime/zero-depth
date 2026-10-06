# Roguelike Gap Analysis v0.1 — retired

> **Retired 2026-10-06 by the owner:** "the framework is all there is." There is no separate report. The design
> source is the audit framework, committed verbatim in [`ROGUELIKE_AUDIT_FRAMEWORK.md`](ROGUELIKE_AUDIT_FRAMEWORK.md).
> This file stays only so that older `GA` citations resolve. **New docs must not cite `GA`.**

## What the old `GA` citations now mean

Every number the kit used to attribute to "the gap analysis" came from the owner-approved kit plan of
2026-10-06. Those numbers are **owner decisions**, recorded in
[`../architecture/LOCKED_DECISIONS.md`](../architecture/LOCKED_DECISIONS.md) (change log, 2026-10-06). Topics the
plan didn't give numbers for are **open design questions**. Each one is decided in the Phase 0 of the version that
needs it, as a numbered design question ([`../process/OWNER_GATES.md`](../process/OWNER_GATES.md) §4). The lead
proposes the numbers and the owner picks.

| Old citation | Now | Decided in |
|---|---|---|
| `GA: run structure` | Owner decision: PD-03 (3 floors × 7–9 encounters + 1–3 branches, median 35–45 min) | done |
| `GA: rewards` | Owner decision: PD-07 (the schedule). Pools and weights are a design question | v0.3.0 |
| `GA: slots` | Owner decision: PD-08 (6 + 3) | done |
| `GA: items` | Owner decision: ≤ 4 plain-support items per 24-item pool. The 12 slice roles are a design question | v0.2.0 |
| `GA: enemies` | Owner decision: the names Charger, Warden, Needle, Disruptor, Splitter, Anchor. Behaviours and `MIN_TELEGRAPH_TICKS` are design questions | v0.1.0, v0.3.0 |
| `GA: boss` | Owner decision: boss 1 has pursuit / lanes / recovery, with stagger. The numbers are a design question | v0.3.0 |
| `GA: input` | Owner decision: pad-only aim assist, about a 12° cone | done |
| `GA: meta` | Owner decision: PD-06 | done |
| `GA: milestones` | Owner decision: M0–M6 as in ROADMAP §4 | done |
| `GA §5` (player kit) | Design question. v0.0.1 uses starting values ([`GAME_BLUEPRINT.md`](GAME_BLUEPRINT.md) §C) that the owner tunes in the Windows check | v0.0.1, v0.1.0 |
| `GA §1–3` (scorecard bands) | Design question, framed by the audit framework's sections 1–3 | v0.2.0 (first sims) |
| `GA: caps`, `GA: scaling`, `GA: threat` | Design questions | v0.2.0, v0.3.0 |
