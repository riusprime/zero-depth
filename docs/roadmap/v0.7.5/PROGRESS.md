# v0.7.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: a new branch cut from `main` after v0.7.0 merges (owner N1).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| NB1 | Biome 4, Frozen Shore: a cold moonlit snow biome over a frozen sea, ice patches you slide on, in the run's biome draw (3 floors from 4) | `v0.7.5 Step NB1` commit |

## Goldens changed on purpose
- NB1: none. `tests/golden` passes unchanged; ice is laid only on Frozen Shore floors and is not hashed itself.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| The lead's readings in PLAN (the Ascension loop, the cosmic biome's name, the achievement list) | — | the owner asked for no interventions; corrected at the playtest | |

## History
- 2026-10-12: plan from the owner's message (verbatim in PLAN), written while the v0.7.0 suite ran.
- 2026-10-12: NB1 Frozen Shore built on `v075-nb1` (from `6381fcb`): biome data, ice in the sim (`map:ice`), its look, tests; evidence [`evidence/FROZEN_SHORE.md`](evidence/FROZEN_SHORE.md). Not pushed.
