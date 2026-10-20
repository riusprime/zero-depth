# BALANCE_RM: remnants, Dodge Imprint, Fracture Bank, two mutations, Thermal Break (step RM)

Owner O91; spec [`../BALANCE_PASS.md`](../BALANCE_PASS.md) "RM" and MR 4. Mechanics tests only: no bot, no balance
numbers measured (owner P1). Feel, fun and whether the starting values are right: **OWNER ONLY** (playtest).

Tree: branch `v080-rm`, `860bead3` (the merge of `7107051c`, SG + final MR) plus this step's uncommitted fixes, which the
final commit holds (the share rounding lead fix, `RemnantRule.digest_into`, card text ≤ 60 characters, content counts,
the re-recorded equivalence golden). Machine: cloud container (4 CPUs), Godot 4.7.2 headless. Times are noise.

## Commands and raw totals
```
godot --headless --path . --editor --import --quit                                  # exit 0
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> [-gdir=res://tests/content] -gexit
```
1. New files (`test_remnants`, `test_remnant_cards`, `test_thermal_break`, `test_remnant_views`):
   `Tests 32, Passing Tests 31, Failing Tests 1` — `test_gravity_stitch_pulls_enemies_and_bends_shots`: distance
   1.4254 expected 1.5 ± 0.05, and an anchor still standing after 80 ticks. Cause: the bent shot hit the enemy and left a
   second anchor (correct behaviour); the test now checks the first anchor's pull and life.
2. Touched sim files (`test_remnant_cards`, `test_wand_blade`, `test_mx4_modifiers_2`, `test_wand`, `test_wand_compile`,
   `test_wand_blade_order`, `test_wand_shared`, `test_wand_shared_order`, `test_modifier_equivalence`, `test_black_holes`,
   `test_player_kit`, `test_engines`, `test_modifiers`, `test_player_builds`, `test_rarity`, `test_rewards`,
   `test_world_snapshot`, `test_gun_feel`, `test_gun_pool`): `Tests 247, Passing Tests 245, Failing Tests 2,
   Time 201.785s`. Failures: `test_modifier_equivalence` (blade_all, gun_all, both_all digests and hits: on purpose,
   re-recorded below) and `test_world_snapshot.test_every_hashed_store_is_snapshotted` (`RemnantRule` had a
   `hash_into`; now `digest_into`, listed in `LOADOUT_CLASSES`).
3. `test_modifier_equivalence`, `test_world_snapshot`, `test_wand_smoke` + `tests/content`: `Tests 154, Passing Tests
   150, Failing Tests 4, Time 396.288s`. Failures: the item and modifier counts (107 / 95, six new each) and eight card
   sentences over 60 characters; `test_world_snapshot` (as 2, before the rename). The equivalence golden and the
   every-card × slot smoke passed.
4. `test_world_snapshot`, presentation (`test_remnant_views`, `test_blade_form_view`, `test_card_frames`,
   `test_element_glyphs`, `test_wand_views`, `test_black_hole_views`), e2e (`test_e2e_remnants`, `test_e2e_wand_blade`,
   `test_e2e_wand_shared`, `test_e2e_old_save`, `test_e2e_void`) + `tests/content`: `Tests 188, Passing Tests 188,
   Time 224.786s`, exit 0.

Every failure above was fixed and its file re-run green (4 for snapshot, content; 3 for the golden and the smoke; the
gravity test in 2). Not run locally: `test_curse_room.gd` (not touched), the full suite (GitHub).

## Golden re-recorded on purpose
`godot --headless --path . -s tests/golden/generate_modifier_equivalence.gd` (exit 0):
```
GOLD| blade_all d33041ce87e39442f485a40767f41afbb48a8ae18a97a2a6839eef439a789f27 hits=122 damage=4160 kills=14
GOLD| gun_all ec2691d270fabb3f43f18aaf14e312c7327c8d304d0f60fa786336fac4ea64a2 hits=380 damage=4160 kills=14
GOLD| both_all e9ce164275b6c085fddce27fb70d32119bced4f0aa57afee642995e286419079 hits=193 damage=4160 kills=14
```
(was hits 126 / 442 / 189). These cases hold Fire + Frost (Thermal Break), Overcharge's migration to Fracture Bank and
the sharing cards (the half-up share); the causes were not separated. The other 19 cases are unchanged.
