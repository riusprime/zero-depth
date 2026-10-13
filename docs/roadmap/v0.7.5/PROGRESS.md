# v0.7.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: a new branch cut from `main` after v0.7.0 merges (owner N1).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| MG | Floors of 16-20 rooms (was 11-13) with bigger rooms and an extra-large 4×4; 20 % fewer challenge rooms (3.23 → 2.42 a floor); the shop on floors 1, 3, 5 …; cursed chests only on floors 1, 3, 5 …, at most one a floor; all tunable in data (F10); a save made before v0.7.5 resumes on its v0.7.0 floor ([`evidence/MAPS.md`](evidence/MAPS.md)) | the `v0.7.5 Step MG` commit on `v075-mg` |

## Goldens changed on purpose
- MG: none. `tests/golden` passes with its fixtures unchanged; every seed's floor layout changed on purpose (N9), and no golden fixture holds one

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| The lead's readings in PLAN (the Ascension loop, the cosmic biome's name, the achievement list) | — | the owner asked for no interventions; corrected at the playtest | |

## History
- 2026-10-12: plan from the owner's message (verbatim in PLAN), written while the v0.7.0 suite ran.
- 2026-10-13: MG (agent, branch `v075-mg` from `6381fcb`): `data/map` (new `MapDefinition`, in the F10 panel's
  Difficulty page), `FloorCadence` for the shop and cursed chests, arena share 0.11, `RunState.floor_rules` so an
  old save keeps its floor. Measured before/after with `scripts/checks/map_stats.gd` (evidence/MAPS.md). Tests run by
  the agent (not the full suite): lint clean; `tests/unit/sim` 910/910 (its test_curses and test_shop_placement were
  edited during the run and re-run: with test_old_saves, 22/22); content + arch + golden + unit/application +
  unit/debug 160/160; 15 e2e files (shop, curses, events, arenas, arena, run_flow, saves, old_save, floor, routes,
  minimap, rewards, dev_master_panel, portal, after_boss) 26/26; 8 presentation files (minimap, minimap orientation,
  stage dresser, shard dressing, shop, routes, event and reward views) 54/54. Open for the lead: the full suite;
  the save snapshot cost on a bigger floor (save_bench NOT YET RUN); AP must pass the run's absolute floor number to
  the shop and curse cadence.
