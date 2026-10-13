# ASCENSION: does the Ascension portal end the run or start an endless, harder loop with the build kept (owner N4), reachable from the real game?

- **Status:** RUN (tests and shots); feel, difficulty of loop 2+ and the look on the owner's hardware: OWNER ONLY
- **Build:** the code at `997fe4c` (WIP commit) plus the AP working tree that became the Step AP commit on `v075-ap`
  (cut from `9bbe930`); see "Command" for which run saw which tree. Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux
  6.18.44 (cloud container shared with other agents and a full suite; llvmpipe for the shots)
- **Date:** 2026-10-13
- **Who ran it:** agent

## What was built
- **Sim** (`src/sim/run/ascension.gd`, `BossFlow`, `World.step`, `WorldReader`, `RunState`): on a run's last floor of
  a loop the gate is the Ascension portal; walking into its opening opens the choice and the world waits; End the run
  (pick 1) wins the run (outcome 1), Ascend (pick 2) ends the floor (outcome 3) and `RunState.finish_floor` starts the
  next loop at its floor 1; Not yet (cancel) closes the choice until the hero steps out. Loop scaling, threat and
  catch-up cap from data; the run's floor counted across loops for seeds, bosses, routes, biomes, shop/curse cadence
  and wand slots. SIM_CONTRACTS "The Ascension portal and the endless loop".
- **Data** `data/run/three_floors.tres` (`RunDefinition`, CONTENT_SCHEMA): `loop_enemy_hp_permille` 4000,
  `loop_enemy_damage_permille` 2000, `loop_boss_hp_permille` 2000, `loop_boss_damage_permille` 1500,
  `loop_scale_cap_permille` 100000, `loop_threat` 2, `loop_catch_up_cap_permille` 500 (starting values).
- **Presentation:** `AscensionPortal` (its own shard-style look: pale hexagonal dais, gold-white spire, lavender
  obelisks, a rising column of golden-white light; `PortalGate` untouched), `AscensionPanel` (three plaques: End the
  run gold, Ascend violet, Not yet silver), the transit's way in flashes gold there, the HUD gate line, "Loop N · "
  on the HUD floor line, the floor card, the pause line and the recap's floor line from loop 2 on, and a recap line
  "Loops cleared: N". 13 new locale rows (en + es).
- **Saves:** `run.loop`, `run.loop_floors` in the payload, no version bump (ARCHITECTURE §10); new World and BossFlow
  fields in `WorldSnapshot.ADDED_SINCE_V05`, so every older save loads as loop 1.
- **Codex / achievements hook:** `Main._record_ascension` after each Ascend: `codex.add(&"runs", &"ascended",
  &"times")` and `codex.raise_to(&"runs", &"loop", &"best", loop)` (CODEX.md "Counter API" note).

## For the merge (AC)
- AC's `main.achievement_tracker` is not on this base. `Main._record_ascension` already calls it, guarded:
  `get(&"achievement_tracker")` → `report(&"runs:ascended")` once per Ascend (marked `FOR THE MERGE` in
  `src/app/main.gd`); it does nothing until the tracker exists. It sits behind the tweaked-run check like the Codex
  writes; if AC filters tweaked runs itself, the lead may move the call above that check.
- End the run ends the run with **outcome 1** (`WorldReader.outcome`; `test_end_the_run_wins_it`,
  `test_end_the_run_shows_the_victory_recap`), so AC's win achievements count it with no extra report.

## Command
Lint, after the last code change:
```
gdformat --check src scripts tests && gdlint src scripts tests
```
Targeted unit tests (code at `997fe4c`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_run_flow.gd,res://tests/unit/sim/test_routes.gd,res://tests/unit/sim/test_portal_transit.gd,res://tests/unit/sim/test_after_boss.gd,res://tests/unit/sim/test_world_snapshot.gd,res://tests/unit/sim/test_catch_up.gd,res://tests/unit/sim/test_wand.gd,res://tests/unit/sim/test_curses.gd,res://tests/unit/application/test_old_saves.gd,res://tests/unit/application/test_run_saves.gd,res://tests/unit/presentation/test_run_recap.gd,res://tests/unit/presentation/test_portal_transit_view.gd,res://tests/unit/presentation/test_routes_view.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_ascension.gd,res://tests/e2e/test_e2e_ascension.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/application/test_ascension_saves.gd,res://tests/unit/presentation/test_ascension_views.gd -gexit
```
The e2e set (code at `997fe4c` plus the new tests):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_ascension.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_portal.gd,res://tests/e2e/test_e2e_after_boss.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_old_save.gd,res://tests/e2e/test_e2e_routes.gd,res://tests/e2e/test_e2e_shop.gd,res://tests/e2e/test_e2e_curses.gd,res://tests/e2e/test_e2e_hud_style.gd,res://tests/e2e/test_e2e_ui_polish.gd,res://tests/e2e/test_e2e_spanish.gd,res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_codex.gd,res://tests/e2e/test_e2e_dev_master_panel.gd,res://tests/e2e/test_e2e_frozen_shore.gd,res://tests/e2e/test_e2e_wand_build.gd,res://tests/e2e/test_e2e_shell.gd -gexit
```
The touched folders (tests/unit/sim, application, presentation, content, arch, golden): first as one `-gdir` run,
which I stopped after 48 complete scripts (it would not finish inside the session's time limit on the loaded
machine), then the remaining 144 scripts as two `-gtest` lists in parallel (chunks of `res://tests/...` paths):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/sim,res://tests/unit/application,res://tests/unit/presentation,res://tests/content,res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<chunk 0: 72 scripts> -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<chunk 1: 72 scripts> -gexit
```
Shots:
```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/ascension.gd -- lang=en
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/ascension.gd -- lang=es
```

## Raw output
GUT summaries (each run's own `Totals` block, ANSI colours stripped). Which tree each saw: the targeted unit run, the
two new-test runs and the e2e set ran on `997fe4c` plus the new test files; the stopped `-gdir` run on `997fe4c`; the
two chunks and the final run on the step's final code (after the AC hook in `Main._record_ascension` and the column's
lower brightness). The orphans are the dev panels the e2e open (the other e2e that use the dev panel report them too).
```
$ targeted unit tests (13 scripts)
Totals
Scripts              13
Tests               128
Passing Tests       128
Asserts           53520
Time              783.216s
---- All tests passed! ----

$ test_ascension + test_e2e_ascension
Totals
Scripts               2
Tests                14
Passing Tests        14
Asserts             172
Orphans              90
Time              98.221s
---- All tests passed! ----

$ test_ascension_saves + test_ascension_views
Totals
Scripts               2
Tests                 7
Passing Tests         7
Asserts              66
Time              18.379s
---- All tests passed! ----

$ the e2e set (18 scripts)
Totals
Scripts              18
Tests                33
Passing Tests        33
Asserts             725
Orphans             150
Time              314.918s
---- All tests passed! ----

$ touched folders, chunk 0
Totals
Deprecated            1
Scripts              71
Tests               402
Passing Tests       402
Asserts           124849
Time              361.384s
---- All tests passed! ----

$ touched folders, chunk 1
Totals
Scripts              73
Tests               589
Passing Tests       589
Asserts           1877769
Time              3200.311s
---- All tests passed! ----

$ final code: tests/unit/app + test_ascension_views + test_e2e_ascension
Totals
Scripts               3
Tests                10
Passing Tests        10
Asserts             143
Orphans              90
Time              64.824s
---- All tests passed! ----

$ touched folders, the stopped -gdir run (no summary: stopped by me)
scripts started 49, tests started 544, [Failed] lines 0; the last script (test_modifier_smoke_mx4) was cut short and re-run in chunk 1
```
Lint (final code):
```
722 files would be left unchanged
Success: no problems found
```
Shots (the scripts' own lines; files under `build/shots/v0.7.0-dev/ascension/`, not tracked; the en run was the
second try: a first try at 1600x900 timed out on llvmpipe after `1_dormant`; the en run still drew the brighter first
column, which I then toned down, so `es/2_open.png` shows the shipped brightness. Both logs also print one engine line,
`ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()`, while the shot script builds the view; not
seen in any e2e run's output):
```
ascension: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) seed=20261013 lang=en
ascension: floor 3 biome night_rocks portal (-93.515, -26.56)
ascension: res://build/shots/v0.7.0-dev/ascension/en/1_dormant.png
ascension: res://build/shots/v0.7.0-dev/ascension/en/2_open.png
ascension: res://build/shots/v0.7.0-dev/ascension/en/3_choice.png
ascension: floor 1 biome red_canyon portal (50.05, 95.235)
ascension: res://build/shots/v0.7.0-dev/ascension/en/4_blue_gate_floor1.png
ascension: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) seed=20261013 lang=es
ascension: floor 3 biome night_rocks portal (-93.515, -26.56)
ascension: res://build/shots/v0.7.0-dev/ascension/es/1_dormant.png
ascension: res://build/shots/v0.7.0-dev/ascension/es/2_open.png
ascension: res://build/shots/v0.7.0-dev/ascension/es/3_choice.png
ascension: floor 1 biome red_canyon portal (50.05, 95.235)
ascension: res://build/shots/v0.7.0-dev/ascension/es/4_blue_gate_floor1.png
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| The Ascension portal after the run's last boss, its own look, the blue portal unchanged | present | PLAN N4, task |
| End the run | a victory: the existing recap | PLAN N4 |
| Ascend | loop 2 floor 1, the build kept, new biomes, harder | PLAN N4 |
| Shop / curse cadence across loops | never two featured floors back to back at a seam | MAPS.md, task |
| Old saves | load as loop 1; Continue works mid-loop | task |
| Reachable from the real game | e2e through main.tscn and `Input.parse_input_event` | CLAUDE.md |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Portal and look | floor 3 draws `AscensionPortal`, not `PortalGate` (e2e + view test); shots 1-4 | yes |
| End the run | outcome 1, EndPanel `UI_RUN_COMPLETE`, "Loops cleared: 1", the save gone (e2e) | yes |
| Ascend | loop 2, floor 1, run floor 4, abilities, levels, items, wand order, card levels, stats and wand slots equal; a new biome; T + 2 (e2e) | yes |
| Cadence | shop floors 1, 3, 5, 7, 9 across loops; run floor 4 no shop and no cursed chests, 5 has them (unit) | yes |
| Saves | a loop-2 payload round-trips to the same state hash; a v0.6.1 recorded save and a pre-AP floor-3 payload load as loop 1 (unit); Continue after Main menu resumes loop 2 (e2e) | yes |

## Interpretation
- This proves the flow and the rules: the portal is reachable, both choices do what N4 asks, the build carries, the
  loop is deterministic and saves load. It does not prove the loop is fun or fair: the per-loop factors (enemy HP ×4,
  damage ×2, boss HP ×2, damage ×1.5, T + 2, catch-up caps + 0.5 per loop) are starting values chosen so loop 2's
  floor 1 sits a little above loop 1's floor 3; no bot sim was run (not in this step's scope). Whether loop 2 feels
  right, and how deep a strong build can go, is **OWNER ONLY** (playtest).
- The portal's look is the lead's reading (no G2 round, the owner asked for no interventions). The shots are on
  llvmpipe; the look on the owner's PC is **OWNER ONLY**.
