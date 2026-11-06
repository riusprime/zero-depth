# v0.9.5 Step RC: Gravity Stitch, the mutations and the trigger cards leave the game

Owner lines: "Gravity stich, double trail have to go, I don't like those as a modifier, the mutations one were not good so
we are removing them" (double trail = Double Exposure, confirmed) and "we are removing all on end, on finisher, on hit,
and on kill cards".

Build base: d33bc82a (branch `v095-rc`, cut from it). Machine: owner PC, Windows 11, Godot 4.7.2, several Godot
processes at once (timings are not evidence).

## Decision: retired through the migration table, files kept (deviation from the step text)

The step said to delete the ten item and modifier files. Not done, on purpose: item indices are the order of
`ModifierCompiler.item_defs` (kind, then id), and run saves, snapshots and the golden digests name cards by index.
Deleting ten cards shifts every later index. Every earlier retirement (Spread, Explosive, the old Void, Charge,
Boomerang) kept its `.tres` and was added to `data/wand/migration.tres` instead: `WandCompiler.retire_items` marks it
`retired`, `ItemPool` never offers it, and `WandMigration.run` drops or maps it on load. RC follows that pattern.

The ten ids (all verified to have an item and a modifier file): shared_gravity_stitch, mut_double_exposure,
mut_grand_finale, trigger_on_hit, trigger_on_kill, trigger_on_end, trigger_on_finisher, trigger_on_hit_twice,
trigger_on_kill_twice, trigger_on_end_twice. Each got a row in `old_ids` with `""` in both `blade_into` and `gun_into`
(dropped, its salvage price refunded as shards, as Charge on the Blade).

## Files changed

- `data/wand/migration.tres`: 10 rows added (48 -> 58 old ids).
- `data/wardrobe/affinity_astral.tres`: `shared_gravity_stitch` removed from the favoured cards.
- `scripts/checks/rarity_odds.gd`: the broken-build recipes that required a trigger card are removed (the Blade's first
  recipe lost its trigger group).
- No file deleted. No sim file was ever specific to these cards (the remnant "anchor" code is Gravity Stitch's, but
  `shared_faultline` and `shared_stress_mark` share `Remnants`; left as engine code). The arch lint passed.

## Tests

Deleted (4 tests; each one's subject is a retired card):
- tests/e2e/test_e2e_wand_shared.gd (whole file, plus its .uid): test_on_end_and_explosive_cast_a_small_slash_that_explodes
- tests/unit/sim/test_wand_shared_order.gd: test_the_four_triggers_are_offered_on_both_weapons,
  test_t4_shows_on_finisher_with_the_blade_and_on_crit_with_the_gun
- tests/unit/sim/test_wand_migration.gd: test_the_legendary_triggers_cast_their_spell_twice

Added (1): tests/unit/sim/test_wand_migration.gd test_the_trigger_cards_the_mutations_and_gravity_stitch_are_retired_and_dropped
(retired on both weapons, never offered, a wand holding trigger_on_hit + mut_double_exposure + shared_gravity_stitch loads
with them gone and the rest kept, salvage refunded, no migration row lands on them).

Net -3. `tests/MIN_TEST_COUNT` (3292) left as is; the next green `verify` total sets it.

Edited to follow the retirement (assertions or fixtures, no test removed): test_wand_migration_validation (58 rows),
test_wand_migration (52 retired items), test_codex (no Triggers section, Chain Blast as the Legendary example, Crit
alt-name assertion removed), test_rarity (Legendary tier = Chain Blast), test_loot_rewards (no mutation in the jackpot
pool), test_wand (carry test uses live cards), test_e2e_wand_build (live cards in the eight slots, trigger pips
assertion removed), test_e2e_reward_cards (holds a card at the ceiling so the jackpot exists).

Tests that use a retired trigger card only as a lab fixture for the generic trigger or child-spell path (a lab adds
the card directly, as it does for Explosive) are kept; they exercise engine code that stays.

## Commands and raw totals

Import: `godot --headless --path . --editor --import --quit`. Tests: `godot --headless --fixed-fps 60 --path . -s
addons/gut/gut_cmdln.gd -gtest=... -gexit` (own APPDATA per run).
- tests/content + tests/arch + tests/golden (dirs): 162 tests, 162 passing, 28909 asserts. Goldens unchanged.
- unit/sim listed files, run 1 (14 files incl. modifier_smoke, modifier_equivalence): 167 tests, 166 passing; the one
  failure (test_rarity) was fixed and test_rarity re-run: 9/9.
- unit/sim run 2 (15 files): 195 tests, 193 passing. Failures: test_loot_rewards jackpot (fixed, re-run with test_codex:
  22/22) and test_final_pace "strong blade body 2: no slower than the base build" ([146.7] >= [147.8]). NOT FIXED, NOT
  VERIFIED as pre-existing: the strong build there holds no card RC retires, but it was not run on the base commit.
- test_wand_migration full file: 16/17 (the new test failed on first run because Gun slot rules refuse a retired card;
  fixed to add the cards as an old save would; the new test alone: 1/1; the other 16 passed).
- application/presentation/e2e listed files: all passing after the fixes above (test_codex, test_e2e_reward_cards,
  test_e2e_wand_build re-run: 3 files, no failure except the stale sections list, fixed afterwards and re-run in the
  22/22 run).
- Lint: gdformat --check and gdlint on every touched file: clean.

## Changed digests

None. `tests/golden/fixtures/modifier_equivalence.json` and the replay golden are unchanged and green (the retired
cards stay in the item table, so indices and scenarios are unchanged).
