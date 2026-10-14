# v0.8.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`, fast-forwarded to v0.7.5's `f1a9ab5` (v0.7.5 is
not in `main` yet).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| LS | Each Ascension loop past the first gives enemies and bosses alike HP ×6 and damage ×1.2 (owner Q6; was enemy HP ×4 / damage ×2, boss HP ×2 / damage ×1.5), the ×100 cap kept: HP caps at loop 4; evidence [`evidence/LOOP_SCALING.md`](evidence/LOOP_SCALING.md) | this commit (`v0.8.0 Step LS`) |

## Goldens changed on purpose
- none yet (LS: none; loop 1 is unscaled, `tests/golden` 2/2 and `test_modifier_equivalence.gd` 3/3 pass unchanged)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q6 (PLAN "Owner decisions") | 2026-10-14 | by role; prompts for the seven kinds without an owner design; only the Arc Caster rune and Mine Layer mines keep ground marks; code clips first; CC0 + the owner's generator; HP ×6 / damage ×1.2 per loop | 2026-10-14 |
| G1 BOSS_SIGNATURES | — | not yet written | |
| G1 BLADE_AUDIT | — | not yet written | |

## Open
- v0.7.5 PR riusprime/zero-depth#6 not merged.

## Blockers
- none

## History
- 2026-10-14: the owner's v0.7.5 playtest message (O1–O11, verbatim in PLAN); three read-only audits of the live
  code; plan written.
- 2026-10-14: Q1–Q6 answered (PLAN "Owner decisions"). PF (direct fix) started by an agent on `v080-pf`.
- 2026-10-14: LS (agent, branch `v080-ls` from `98698cb`): `data/run/three_floors.tres` and the `RunDefinition`
  defaults to HP 6000 / damage 1200 ‰ per loop for enemies and bosses; CONTENT_SCHEMA updated; two new tests in
  `tests/unit/sim/test_ascension.gd` (the loop 1-5 factors; an enemy and a boss on loops 2 and 3); new
  `scripts/checks/loop_scaling.gd` (writes `build/loop_scaling.txt`). The F10 dev panel lists the fields already
  (every field of `data/run`). Run locally: lint clean (801 files); `tests/golden` 2/2; `tests/content` 133/133;
  `tests/unit/debug` 11/11; `test_ascension.gd` + `test_ascension_saves.gd` 16/16; `test_modifier_equivalence.gd`
  3/3; e2e `test_e2e_ascension.gd` + `test_e2e_achievements.gd` 4/4. Not run locally: the full suite (CLAUDE.md).
