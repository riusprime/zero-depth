# v0.8.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`, fast-forwarded to v0.7.5's `f1a9ab5` (v0.7.5 is
not in `main` yet).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| LS | Each Ascension loop past the first gives enemies and bosses alike HP ×6 and damage ×1.2 (owner Q6; was enemy HP ×4 / damage ×2, boss HP ×2 / damage ×1.5), the ×100 cap kept: HP caps at loop 4; evidence [`evidence/LOOP_SCALING.md`](evidence/LOOP_SCALING.md) | `51c3b08` (branch `v080-ls`) |
| RT part 1 (system + 3 layouts) | Rooms of 2×2, 3×2 and 3×3 cells are furnished from hand-designed layouts (dense clusters of tall blocks, crate stacks, wrecks, fire barrels, broken walls and pillars, grass and rubble, an open lane in the middle), picked per room and turned and mirrored by the generator, restyled by each biome; other sizes keep their rule-built rooms until their layouts come; a save made before RT resumes on its own floor. G2 asked; evidence [`evidence/ROOMS.md`](evidence/ROOMS.md) | this commit (branch `v080-rt`) |

## Goldens changed on purpose
- none yet (LS: none; loop 1 is unscaled, `tests/golden` 2/2 and `test_modifier_equivalence.gd` 3/3 pass unchanged)
- RT1: none (no golden fixture holds a run floor: the replay and export-smoke goldens use the kernel arena;
  `tests/golden` passes unchanged). Run floors change on purpose (floor rules 4); a floor saved before keeps its own.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q6 (PLAN "Owner decisions") | 2026-10-14 | by role; prompts for the seven kinds without an owner design; only the Arc Caster rune and Mine Layer mines keep ground marks; code clips first; CC0 + the owner's generator; HP ×6 / damage ×1.2 per loop | 2026-10-14 |
| G1 [BOSS_SIGNATURES](BOSS_SIGNATURES.md) S1–S6 | 2026-10-14 | pending | |
| G1 [BLADE_AUDIT](BLADE_AUDIT.md) B1–B7 | 2026-10-14 | pending | |
| G2 RT: the first 3 designed rooms ([evidence/ROOMS.md](evidence/ROOMS.md), shots in `evidence/rt_shots/`) | 2026-10-14 | pending | |
| G2 MU: 3 menu and card directions | — | not yet made | |

## Open
- v0.7.5 PR riusprime/zero-depth#6 not merged.
- RT (agent's reading, for the lead to confirm with the owner): "start, portal/boss rooms, shop and arenas keep their
  rules" read as their selection rules; the shop, arena and Overrun rooms are chosen after the floor is generated,
  so they may hold a designed interior (SR redesigns the shop room). The start hall, portal room and boss room never do.

## Blockers
- none

## History
- 2026-10-14: the owner's v0.7.5 playtest message (O1–O11, verbatim in PLAN); three read-only audits of the live
  code; plan written.
- 2026-10-14: Q1–Q6 answered (PLAN "Owner decisions"). PF (direct fix) started by an agent on `v080-pf`.
- 2026-10-14: LS and TG started by agents (`v080-ls`, `v080-tg`); the lead wrote the G1 audits BOSS_SIGNATURES and BLADE_AUDIT and the enemy-model prompts (`docs/art/requests/v0.8.0_enemy_models.md`).
- 2026-10-14: the owner's second message (O12–O15: designed rooms, the shop room per biome, the menu without shard cards, the art list) added to PLAN; the full art list is `docs/art/requests/v0.8.0_ART_LIST.md`.
- 2026-10-14: LS (agent, branch `v080-ls` from `98698cb`): `data/run/three_floors.tres` and the `RunDefinition`
  defaults to HP 6000 / damage 1200 ‰ per loop for enemies and bosses; CONTENT_SCHEMA updated; two new tests in
  `tests/unit/sim/test_ascension.gd` (the loop 1-5 factors; an enemy and a boss on loops 2 and 3); new
  `scripts/checks/loop_scaling.gd` (writes `build/loop_scaling.txt`). The F10 dev panel lists the fields already
  (every field of `data/run`). Run locally: lint clean (801 files); `tests/golden` 2/2; `tests/content` 133/133;
  `tests/unit/debug` 11/11; `test_ascension.gd` + `test_ascension_saves.gd` 16/16; `test_modifier_equivalence.gd`
  3/3; e2e `test_e2e_ascension.gd` + `test_e2e_achievements.gd` 4/4. Not run locally: the full suite (CLAUDE.md).
- 2026-10-14: RT part 1 (agent, branch `v080-rt` from `96cbbbd`): `RoomLayoutDefinition` (+ group, piece) and
  `data/room_layouts/` (2×2, 3×2, 3×3, written by `scripts/content/room_layouts.py`); `RoomLayouts` /
  `RoomLayoutTable` and the generator's layout draw, orientation settle and group-by-group furnishing on the `map`
  stream (no new sub-stream); `FLOOR_RULES` 4 (older saves rebuild without layouts); the dresser's biome swaps for
  designed rooms; `scripts/shots/room_layouts.gd`; PLAN "### RT"; CONTENT_SCHEMA and SIM_CONTRACTS "Designed rooms".
  Run locally: lint clean (810 files); `tests/content` 136/136; `tests/arch` + `tests/golden` 6/6; map/generator sim
  tests by name 12 scripts green (93 tests; the starglow/run-flow pair re-run on its own after a timeout); 
  `tests/unit/application` + `tests/unit/debug` 103/103; presentation dresser/biomes 36/36; e2e saves/old save/run
  flow/designed rooms 7/7 and the e2e shard 127/127. Shots: 10 at 1920×1080 (llvmpipe), 6 copied to
  `evidence/rt_shots/`. Not run locally: the full suite. G2 RT asked.
