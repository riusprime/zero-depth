# EP3: floor 1 eases; a small heal-orb chance from the start

Base build SHA: c93036cf (the commit under this step's commit). Machine: owner PC (Windows, Godot 4.7.2 console).

## Change
- `data/run/five_floors.tres`: enemy HP and damage floor tables start at 850 (were 1000).
- `data/rewards/floor.tres`: `heal_orb_chance = 0.03` (was 0.0).
- `ContentDef.check_permille_table` gained `start_min := 1000`; `RunDefinition.validate` passes 500 for the two enemy floor tables only. Other callers keep "exactly 1000".

## Commands (each: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <arg> -gexit`)
| Arg | Result (raw summary lines) |
|---|---|
| `-gdir=res://tests/content -ginclude_subdirs` (run before the later test edits; includes test_validation_errors.gd's 3 new tests) | Scripts 30, Tests 161, Passing 161, Asserts 13217 |
| `-gtest=res://tests/unit/sim/test_heal_orbs.gd` | Tests 11, Passing 11, Asserts 48 |
| `-gtest=res://tests/e2e/test_e2e_heal_orbs.gd` | Tests 1, Passing 1, Asserts 8 |
| `-gtest=res://tests/unit/sim/test_five_floors.gd` | Tests 8, Passing 8, Asserts 6112 |
| `-gtest=res://tests/unit/sim/test_run_flow.gd` | Tests 18, Passing 18, Asserts 678 |
| `-gtest=res://tests/unit/sim/test_loop_deep_ease.gd` | Tests 5, Passing 5, Asserts 226 |
| `-gtest=res://tests/unit/sim/test_routes.gd` | Tests 12, Passing 12, Asserts 46626 |
| `-gtest=res://tests/unit/sim/test_breakables.gd` | Tests 11, Passing 11, Asserts 10951 |
| `-gtest=res://tests/unit/presentation/test_shard_altar.gd` | Tests 5, Passing 5, Asserts 106 |
| `-gtest=res://tests/e2e/test_e2e_purple_portal.gd` | Tests 1, Passing 1, Asserts 66 |
| `-gtest=res://tests/e2e/test_e2e_portal.gd` | Tests 1, Passing 1, Asserts 229 |
| `-gtest=res://tests/unit/application/test_balance_tools.gd` | Tests 5, Passing 5, Asserts 23 |
| `-gtest=res://tests/unit/application/test_old_saves.gd` | Tests 11, Passing 11, Asserts 157 |

test_content_valid.gd is inside tests/content (green). Not run: goldens/hash fixtures (none edited; none run).
The first runs of test_heal_orbs, test_e2e_heal_orbs, test_five_floors and test_run_flow failed on the old expectations (below); the table shows the re-runs after the edits.

## Expectation edits (old -> new)
- `tests/unit/sim/test_heal_orbs.gd` test_the_shipped_numbers: `[0, 250]` -> `[30, 250]`. Added test_the_shipped_three_percent_base_drops_without_a_card.
- `tests/e2e/test_e2e_heal_orbs.gd`: the "no orb from 5 kills" assert removed (the base is now 3 %, so an early orb can drop); the loop breaks on an orb only after the card is granted.
- `tests/unit/sim/test_five_floors.gd`: shipped tables `[1000,...]` -> `[850,...]` (HP and damage); test_enemies_and_bosses_scale_per_floor floor 1 HP/damage 1000 -> 850.
- `tests/unit/sim/test_run_flow.gd`: shipped tables first entry 1000 -> 850; test_enemies_scale_with_the_floor floor 1 permille 1000 -> 850 (HP and damage).
- `tests/content/test_validation_errors.gd`: three new tests (850 valid; 400 invalid for both fields; a tier table at 900 still invalid).

## Read-only grep: readers of the first entry
No code indexes `[0]` of either table. They are read only through `SpawnTable.per_floor`:
- `src/sim/run/run_state.gd:237-238` (`scale_enemies`): per_floor of both tables for floor f, then the Deep factor, the loop factor (loop > 1) and `_loop_deep_ease`.
- `src/application/content_compiler.gd:910-911`: copies both arrays into the run table.
- `src/sim/run/run_table.gd:17-18`: defaults `[1000, 1900, 3610]` / `[1000, 1400, 1960]` (left as is).
