# EP1: element pairs work from Lv 1 and grow with level

Build base SHA: c93036cf (claude/v095-feedback) plus this step's commit. Machine: the owner's PC (Windows, Git Bash), Godot 4.7.2.

## What changed
- A pair is on while the Gun holds both elements at any level; pair level = min of the two element levels (1-3);
  strength scales by `level_permille` = [400, 700, 1000] (Lv 3 = the old numbers).
- New: `ElementPairs.held_element/levels/level/scale/bonus`, `World.pair_levels` (saved, hashed, an older save reads Lv 3),
  `ElementLevels.held`, `ElementLevelsFsf.held`, `ElementPairTable.level_permille`, `ElementPairsDefinition.level_permille` (+ validation).
- X1 burst, X2 cloud time, X4, X5, X6, X7, X10 scaled; X3/X8/X9 act on the first `level` jumps below Lv 3 (`on_jump` takes the jump index).
- PAIR_ON is emitted when a pair turns on or its level rises (`amount_applied` = new level).
- Eight DESC rows reworded. Two were shortened by a few characters from the brief's text (the existing test caps DESC at 60 chars):
  THERMAL_SHOCK es "...estalla al golpe (hasta x3)." and COLD_CIRCUIT en "...frozen foes...".
- Tests: `_off()` is now a world holding only the first element; X4/X7/X10 "off" cases set `pair_mask = 0`;
  `test_pair_banner.gd` used "Lv 2 + Lv 3: no pair" (old rule), now "one element: no pair". New tests: on at Lv 1, level = min,
  X1 x1.8/x2.4/x3, X3 jump index, PAIR_ON on level rise (and none on a plain refresh), old-save Lv 3, snapshot carries `pair_levels`.

## Commands and raw results (APPDATA set to build/appdata)
`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> -gexit`
- test_element_pairs + test_pair_banner: Tests 33, Passing 33, Asserts 314.
- Before the banner fix, the 8-file set (test_element_pairs, test_e2e_element_pairs, test_pair_banner, test_plaques, test_element_levels_fsf, test_element_levels_venom_bleed, test_world_snapshot, test_old_saves): Tests 99, Passing 98, Failing 1 (the banner test "Lv 2 and Lv 3: no pair", fixed above); the other 7 files passed.
- `-gdir=res://tests/content,res://tests/arch -ginclude_subdirs`: Scripts 32, Tests 162, Passing 162, Asserts 31578.
- `-gdir=res://tests/golden -ginclude_subdirs`: Tests 2, Passing 2, Asserts 4.
- gdformat --check / gdlint on every touched .gd: clean.
- Not run: full suite, seams (per the brief).
