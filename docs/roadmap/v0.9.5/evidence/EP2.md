# EP2 evidence: floors 1-2 offer more wand cards; stats matched from floor 3

Build SHA (base, before the EP2 commit): d33bc82a. Machine: owner PC (Windows 11, Godot 4.7.2 stable). Run 2026-10-31.
Each run: `export APPDATA=<worktree>/build/<dir>` then Godot `--headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <args> -gexit`.

| Run | Args | Result (raw summary) |
|---|---|---|
| Pacing | `-gtest=res://tests/unit/sim/test_loot_pacing.gd` | `14/14 passed.` Tests 14, Passing 14, Asserts 813 |
| Content | `-gdir=res://tests/content -ginclude_subdirs` | Scripts 30, Tests 156, Passing Tests 156 |
| Sim | `-gtest=` test_offers, test_loot_rewards, test_arenas, test_curses, test_rarity, test_rewards, test_routes, test_wand_migration (all `res://tests/unit/sim/`) | Scripts 8, Tests 108, Passing Tests 108, Asserts 54472 |
| e2e (first run) | `-gtest=res://tests/e2e/test_e2e_card_levels.gd,...test_e2e_combo.gd,...test_e2e_reward_cards.gd` | Tests 6, Passing 5, Failing 1: `test_pick_a_combo_pair_from_altars_and_chests` "the floor's cards hold a combo pair" (line 63) |
| e2e combo (after edit) | `-gtest=res://tests/e2e/test_e2e_combo.gd` | `1/1 passed.` Asserts 19 |

card_levels e2e (2/2) and reward_cards e2e (3/3) passed in the first run.

## Expectation edits
- `tests/unit/sim/test_loot_pacing.gd`: floor 1 weights `[1400, 1400, 400, 600, 20]` -> `[1500, 1600, 900, 600, 20]`; floor 2 `[1000, 1000, 1000, 1200, 100]` -> `[1300, 1400, 1100, 1200, 100]` (the shipped data changed on purpose).
- `tests/e2e/test_e2e_combo.gd`: its labelled helper forced mods-only draws through `reward_table.*_card_weights`, which the pacing table's per-stage type weights now override; it also sets `loot_pacing.altar_type_weights` / `chest_type_weights` to `[0, 1, 1000]` on every stage. Same intent, no assertion changed.

No golden or hash fixture was edited; none failed.
