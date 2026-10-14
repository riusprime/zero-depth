# v0.8.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`, fast-forwarded to v0.7.5's `f1a9ab5` (v0.7.5 is
not in `main` yet).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| PF | Spread + Split + Explosive no longer drops the frame: a few explosions look as before; under load nearby ones merge and the extra ones thin (no light of their own); past 96 live bolts the rest fly as plain darts; at most 256 player shots alive (`data/tuning/sim.tres`). Probe tick + frame avg 26-37 ms → 8-9.4 ms (target ~12 ms met); p95 16.5-20.1 ms (missed, reported). Owner's fps: OWNER ONLY ([`evidence/PERF.md`](evidence/PERF.md)) | `v080-pf` (this step's commit) |

## Goldens changed on purpose
- none yet

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q6 (PLAN "Design questions") | 2026-10-14 | pending | |
| G1 BOSS_SIGNATURES | — | not yet written | |
| G1 BLADE_AUDIT | — | not yet written | |

## Open
- v0.7.5 PR riusprime/zero-depth#6 not merged.

## Blockers
- none

## History
- 2026-10-14: PF (agent, branch `v080-pf`): `scripts/checks/perf_probe.gd`; the explosions' drawing was 20-22 ms of a
  26-37 ms tick + frame (5,000 sprites asked, 995 shown); burst budget (VfxLayer, BurstBudget), live-bolt budget, look
  cache, and the sim cap `player_shots_max` 256 (the probe: the sim was 5 ms avg, 15 ms p95 with Twin). After: avg
  8-9.4 ms, p95 16.5-20.1 ms (over the 12 ms target; reported, not widened). Goldens unchanged.
- 2026-10-14: the owner's v0.7.5 playtest message (O1–O11, verbatim in PLAN); three read-only audits of the live
  code; plan written.
