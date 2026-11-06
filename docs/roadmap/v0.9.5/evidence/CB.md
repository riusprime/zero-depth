# Step CB (v0.9.5): dash recharges in 10 s, blink in 15 s

Owner line: "Dashing and blink have to be nerfed on cooldowns, dash will have a 10s cooldown and blink 15s, these can
already be upgraded with current cards."

Base: origin/main d33bc82a, branch `v095-cb`. Machine: owner's PC, Windows, Godot 4.7.2, headless, `--fixed-fps 60`.

## Changes
- `data/player/runner.tres`: dash `cooldown_seconds` 1.4 -> 10.0. `src/sim/world/player_table.gd:82` default 1.4 -> 10.0 (equal).
- `data/abilities/blink.tres`: `level_cooldown` (2.5, 2.3, 2.1, 1.9, 1.7) -> (15.0, 14.0, 13.0, 12.0, 11.0).
- Left alone: the Storm affinity +0.3 s (now 10.3 s, 618 ticks), card values, stat caps, Swift Feet (200 permille, now 480 ticks).
- Blink fallbacks: `player_table.gd:37` `blink_cooldown_ticks = 150` is only a table default; the real game reads
  `Abilities.blink_cooldown` (the ability table's `level_cooldown`), so it is left alone. `utility_definition.gd` 2.5 s left alone.

## Golden regenerated on purpose
`godot --headless --path . -s tests/golden/generate_modifier_equivalence.gd` rewrote
`tests/golden/fixtures/modifier_equivalence.json`. All 22 digests changed (every scenario presses dash every 97 ticks):
blade_plain 0753493ad566, gun_plain 983ddb292073, both_plain 2136761eb55e, blade_long_edge 7989a52eac4b,
blade_twin_arc 53dc6694fe6b, blade_ember_edge a9903c2e1615, blade_overcharge 200f37c3d31e, blade_conductor 00f8e395df03,
blade_serrated_edge 10ec5451af13, blade_glacial_edge 30c55947fc52, blade_wildfire_rider ef8bbf45673a,
gun_splinter_shot 1a4d9f110a2d, gun_rapid_coil a32e18444ae1, gun_ricochet_core 0ecaeac698ba, gun_static_chain 131e2fce3668,
gun_frost_core 12f7e6fa5c79, gun_cinder_shot edce8c6ca8c5, gun_barbed_bolts a8fef12512af, gun_glacial_rider 586a3158aa71,
blade_all 897e1d0b70a2, gun_all 017199d894fc, both_all 7b49193f9a30 (first 12 hex shown, new values).
`tests/golden` folder: 2 tests, all pass, `test_replay_ground_plane.gd` unchanged and green.

## Tests whose expectations changed (all cooldown assumptions)
- `test_abilities.gd`: blink table (900, 840, 780, 720, 660 ticks); 15 s cd runs; L3 holds 780 ticks and the recharge waits are 790 ticks.
- `test_items_j.gd` Swift Feet: 600 ticks plain, 480 with Swift Feet.
- `application/test_wardrobe.gd`: plain dash 10 s, Storm 10.3 s.
- `test_player_skill.gd` `test_the_dash_waits_10_seconds` (renamed from 1_4): 600 ticks, buffered press after 600.
- `e2e/test_e2e_kit.gd` (test renamed `..._dash_waits_10_s`): 600 total, waits 570 more frames for the second dash.
- `test_items.gd` kinetic dash, `test_combos.gd` slipstream, `e2e/test_e2e_nemesis.gd` `_dash_answered`: test is about
  hits/window/answer, not the wait, so the test zeroes `dash_cooldown_left` before the next dash.
Initial failures before these edits: 5 (abilities x2 groups, items_j, wardrobe), e2e kit 1, nemesis 2, items 1, player_skill 1, combos 1.

## Raw totals (after fixes; each run its own APPDATA)
- Run a (the step's listed unit/content/application files, 13 scripts): before fixes 158 tests, 153 pass, 5 fail (the cooldown ones above).
- Run f (kit, nemesis e2e + abilities, items_j, wardrobe, after fixes): 50 tests, 50 pass.
- Run e (11 e2e files incl. curses, hints, input, pad_aim, damage_soak, utility): 26 tests, 23 pass before fixes; the 3 failures are kit + 2 nemesis, fixed, rerun in f.
- Run b (balance_tools, nemesis views, final_pace, nemesis, kit/heat/build views, boss_dodge 1-3, hud_style, e2e hud_style): 87/87.
- Run r (38 other unit/sim files mentioning dash or blink): 467 tests, 464 pass, 3 fail (items kinetic, player_skill, combos slipstream), fixed.
- Run h (combos, player_skill, items, abilities, modifier_equivalence after fixes): 68/68.
- Not re-run after the fixes: the other files of run r that already passed. e2e boss_dodge ran in run b only (pass).
- Bots (`tests/support/build_fight.gd`, nemesis_lab, survival_run via test_balance_tools, test_final_pace, test_nemesis): pass, no survival bar failed.
- HUD: no test asserts the pip's seconds text; `test_kit_views`/`test_hud_style` pass unchanged. NOT YET RUN: a visual check of "10"/"15" on the HUD.
- Lint: gdformat --check and gdlint clean on every touched file.
