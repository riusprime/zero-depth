# Step SM: the Stress Mark shows a weak side

Base SHA (before the step): 98ba461d (claude/v095-feedback merged). Machine: owner PC, Windows, Godot 4.7.2 headless.
Owner line and Q14 a: per enemy within 6 m, a random screen side, x2 once from within 45 degrees, 8 s per enemy, bosses
carry 4 marks, no levels.

## Commands and raw totals (each run with its own APPDATA, `--language en`)

| Command (godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd ...) | Result |
|---|---|
| -gtest=tests/unit/sim/test_stress_marks.gd | 12/12, 65 asserts |
| -gtest=tests/unit/presentation/test_stress_mark_views.gd + test_stress_marks + tests/e2e/test_e2e_stress_mark.gd + tests/content/test_credits_licences.gd | 21/21, 131 asserts |
| -gtest=test_remnant_views, test_remnant_cards, test_stress_marks, test_stress_mark_views | 33/33 |
| -gdir=res://tests/content | 157/157 |
| -gdir=res://tests/golden | 2/2 |
| -gdir=res://tests/arch | 4/4 (after the view read the sim only through WorldReader) |
| test_modifier_equivalence, test_wand_shared, test_wand_shared_order, test_rewards, test_audio_director | all passed (3, 10, 9, 24, 15) |
| test_loot_rewards.gd | 8/10: 2 failures that do not touch this step (the tests hold `gun_big_shot` at level 2, its `level_max` is 1 since CLV); NOT caused by SM, not fixed here |

The e2e printed `SM e2e: hits on the marked enemy [10, 5, 5]`: the first hit, from the shown side, was double the next two.
Lint: gdformat --check src tests clean; gdlint reports one line-length error in tests/unit/sim/test_wisps.gd (not touched here).

## Changed digests / goldens
No golden changed. test_modifier_equivalence passed unchanged. The Stress Mark card now has no remnant op (a no-op `count + 0`
op keeps the modifier valid), so tests that held it in `tests/support/build_fight.gd` fights may play differently; their
hashes are computed in-test, not pinned.

## Not done
- No screenshot of marked enemies: no quick shot script adapted (NOT YET RUN).
- Owner-only: how the arc looks and feels.
