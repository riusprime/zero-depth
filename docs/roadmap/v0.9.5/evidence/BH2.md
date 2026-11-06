# v0.9.5 Step BH2 evidence

One hard spell each for the Gatekeeper, the Warlord, the Brood Mother, the Hive Lens and the Siege Engine (BOSSES_HARD.md
B1-B5), plus the BH1 cleanup (the loop-ease numbers are data). Owner: "we have to modify 1 spell for each that will be
hard to dodge, bosses should feel like a challeng".

- Machine: the owner's PC (Windows 11, Godot 4.7.2 console build, headless, `--fixed-fps 60 --language en`).
- Build: base `f9197302ad3ccb98ff825ac28cf0729e04b471f6` (branch `v095-bh2`, cut from the worktree HEAD, then merged
  `claude/v095-feedback`) plus this step's working tree. The step's own commit is the branch head.
- **Environment problem, reported as it happened:** drive C: was 100 % full (0 to 25 MB free) during this step. The first
  `--import` ran out of space midway: audio `.sample` files and many `.glb` imports are unusable in this worktree
  (`Unrecognized binary resource file`), and Godot could not save `editor_settings-4.7.tres`. So every test that needs an
  imported audio or model asset fails here for that reason alone (listed below), and the e2e labs that boot `main.tscn`
  crash on a corrupt model import. They are `NOT YET RUN`.
- Lint: `gdformat` then `gdlint` over every touched `.gd` (24 files): `Success: no problems found`.

## What changed, per boss (all numbers are data, validated by `HardRules`; damage is unchanged everywhere)

- **B1 Gatekeeper, Shock Lanes.** `lock_seconds` 0.8 -> 0.55 on `shock_lanes`, `shock_lanes_2` and the new
  `shock_lanes_follow` (telegraph 1.6 -> 1.35: it still tracks 0.8 s, then locks 0.55 s). Phases 2 and 3 (`shock_lanes_follow`,
  `shock_lanes_2`) add `second_seconds` 0.4 and `second_offset_m` 0.6 (half the 1.2 m lane): each cross is followed 0.4 s after
  it strikes by a second cross shifted 0.6 m on each axis the way the hero is heading (toward the boss on an axis they stand
  still on). The second cross is drawn locked from the tick the first locks (0.95 s ahead). With second crosses only the
  second ones leave pillars (the first ones' would cut the second lanes short). Phase 2 swaps `shock_lanes` for
  `shock_lanes_follow` (the punish attack stays `shock_lanes`).
- **B2 Warlord, Javelin Fan.** Telegraph 0.45 -> 0.6 s (the 0.55 rule). Both patterns are now 2 fans 0.3 s apart (were 3 of
  0.25 s and 4 of 0.22 s). `lead_seconds` 0.35: the first fan is aimed at the tick it fires at where the hero will be in 0.35 s
  (their sim velocity, cut short by walls: `EnemyAi.clear_run`), the second at where they are then.
- **B3 Brood Mother, Leap Chain.** `chain` 2 -> 3; `last_lead_seconds` 0.35 (same lead rule, on the last leap's aim);
  `last_radius_bonus_permille` 200 (landing disc 2.2 -> 2.64 m). Body radius untouched.
- **B4 Hive Lens, Focus Beam** (`focus_beam`, `focus_beam_3`). `turn_dps` 40 and `active_seconds` 0.3 -> 1.2: the beam burns
  1.2 s as a whole lane and turns toward the hero by at most 40 degrees a second (7585/1000 units a tick, the remainder carried;
  no trig). It hits once per attack for its damage (50 / 34). The telegraph keeps drawing the lanes while it burns, and
  `BossStrikeViews` redraws the beam where it points now.
- **B5 Siege Engine, Mortar Grid** (`mortar_grid`, `mortar_grid_3`). `safe_cells` 2: every volley strikes all but 2 cells of the
  5 x 5 board. One draw of the boss's `ai` stream at the attack's start orders the 9 inner cells (none on the outer ring);
  the first two safe cells come from the 4 cells beside the centre, the second pair (from volley `ceil(volleys/2)`: volley 2 of 2,
  volley 3 of 3) from the other inner cells, one of them within a cell of an old one; cells near a wall (1 m) are skipped.
  `lock_seconds` 0.8 -> 0.6: a later volley shows only for its lock, so the swap is telegraphed 0.6 s. `radius_m` 1.1 -> 1.45 so no
  pocket between four cells fits the hero (validated), and the 1.0 s / 0.9 s gap between volleys is over the lock.

## BH1 cleanup

`LOOP_EASE_MAX` 3, `LOOP_TIME_EASE_PERMILLE` 120 and `LOOP_DAMAGE_EASE_PERMILLE` 80 left `final_pace.gd`: they are
`loop_ease_max`, `loop_time_ease_permille`, `loop_damage_ease_permille` in `data/tuning/sim.tres` (`SimTuningDefinition`, validated:
0..10 loops, and loops x per-loop cut < 1000), compiled into `SimTuning` and read as `w.tuning.*`. `test_final_pace.gd` passed
unchanged (in the batch below); `tests/content/test_sim_tuning.gd` passes.

## Runs (raw totals; `NOT YET RUN` where stated)

| Batch | Tests | Result |
|---|---|---|
| `tests/unit/sim`: test_boss_challenge, _fights, _fights_2, _fights_3, _gates, _markers, _pace, _pressure, _signatures, _signatures_2, test_bosses, test_bosses_2, test_bullet_patterns, test_final_pace (before the test updates) | 192 | 186 pass, 6 fail: all six were old pins of the changed numbers (below) |
| New: `test_boss_hard.gd`, `test_boss_hard_2.gd` (final run) | 28 | 28 pass, 543 asserts |
| Updated + pace: test_boss_fights_2, _fights_3, _markers, test_boss_pace (dodge lab by dash), test_boss_animations, test_boss_fight_views_3 (with the new ones) | 94 | 93 pass; 1 `Unexpected Errors` in test_boss_animations (a model failed to import: disk) |
| `tests/arch`, `tests/golden`, `tests/content` (final) | 163 | 159 pass; 4 fail, all `... imports` (audio samples) / model manifest: the broken import, not this step. Before the `HardRules` layering fix arch failed: `content uses BossStore` (fixed by a pinned constant) |
| `tests/e2e/test_e2e_boss_dodge*.gd`, `test_e2e_boss_strikes`, `test_e2e_stone_spikes` | - | `NOT YET RUN` (the process crashed on a corrupt `.glb` import; needs free disk and a clean `--import`) |
| `test_five_floors`, `test_curse_room`, `test_modifier_smoke`, `test_event_rarity` | - | not run (the brief) |

## Tests changed because a pinned number is the spell's old one (no bar lowered)

`tests/content/test_boss_pace.gd` (attack count 109 -> 110; shock_lanes telegraph 1.6 -> 1.35; javelin windup 27 -> 36 ticks and
wave gap 0.25 / 0.22 -> 0.3), `test_bullet_pattern_validation.gd` (row_lanes lock 0.55), `test_boss_fights_2.gd` (a step aside
after the lock is now followed by the beam), `test_boss_fights_3.gd` (mortar lock 36; the checkerboard test is replaced by the
new ones), `test_boss_markers.gd` (phase 2 list; 2 fans), `test_boss_animations.gd` (windup 36), `test_boss_fight_views_3.gd` (23 cells
drawn, hero moves one tick after the lock). The tests' dash bot (`test_boss_pace.gd`) learned the new answer: for the
turning beams it circles the boss (tangent, drifting in toward 3.5 m); all other bars are as they were.

## Dodge result per boss (unit-level labs in `test_boss_hard*.gd`; the e2e labs are `NOT YET RUN`)

- **Gatekeeper:** stepping 1 m toward the boss (out of the first cross) is hit by the second; 1 m the other way, or 1.9 m
  toward the boss, takes 0 damage.
- **Warlord:** a hero running along +y gets the first fan aimed ahead of them (angle between 0 and 1/4 turn from straight at
  them); the lead stops at a wall.
- **Brood Mother:** three landings; discs 2.2, 2.2, 2.64 m; only the last aims by the lead.
- **Hive Lens:** the beam turns toward the hero at most 8 units a tick (45 degrees a second at the rounding), about 0.89 x 546 units
  in 1.2 s; standing 2 m aside is hit; circling at 4 m (86 degrees a second) is never hit; a 3 m/s stroll round it at 11 m is caught.
  The dash lab (`test_each_sped_up_attack_is_dashable_after_its_telegraph`) passes for `focus_beam` and `focus_beam_3` at 2.5 m and 8 m
  with the circling bot (it failed, 2.5 m, with the old straight-run bot, which is why the bot changed).
- **Siege Engine:** 24 seeds: exactly 2 cells unstruck per volley, none on the outer ring, the swap pair disjoint and within a cell
  of the first; walls: safe cells keep 1 m off a wall; standing in a first cell is safe until the swap and hit after it;
  moving to a swap cell in time is never hit; the pocket between four cells is hit.

## Not done / open

- Safe cells are not drawn with their own marker: they are the holes in the board (a view that marks them is a follow-up).
- The Gatekeeper's second cross leans the hero's way, so a hero who keeps running into it sees the lane move; the owner may want
  it fixed toward the boss (one line in `BossHard.second_point`).
- Full e2e and `bash scripts/ci/seams.sh` not run here (disk).
