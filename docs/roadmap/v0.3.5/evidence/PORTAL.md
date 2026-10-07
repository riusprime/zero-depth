# PORTAL: does the portal take the hero with a tick-owned animation, and does the next floor open on an arrival?

- **Status:** RUN (agent checks). How it looks and feels in play: OWNER ONLY.
- **Build:** base `66124b6` on `claude/lucid-fermat-9wv2tf` plus this step's working tree (the commit
  `v0.3.5 Step PT: portal entry and floor arrival animations` that adds this file); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18 (cloud container)
- **Date:** 2026-10-07
- **Who ran it:** agent

Owner lines: F19 ("an animation of the character entering a portal (make it lighter blue matching his eye
color)"), F20 ("an animation getting to one of the new rooms"; lead's reading: the next floor's start room).

## What was built
- **Portal colour.** `PortalGate` takes its swirl, light and floor glow from `ThemePalette.color(&"player_core")`,
  the colour the hero's visor glows (`PlayerAvatar.visor_color()`): a deep shade of it, it, and near white. It follows
  the colour-blind mode like the visor does. (Replaces v0.2.0 L12's "bluer than the player's cyan"; the old test
  that asserted the opposite was rewritten to assert the new owner line.)
- **Sim (EI-03).** `BossFlow` gains a state `ENTERING` (appended to the enum: it is hashed) and an arrival count.
  Walking into the open gate emits `FLOOR_EXIT` once and starts `ENTERING`; for `enter_ticks` (60, ~1.0 s; 24 with
  reduced motion) `World.step` only advances the transit: the frame is ignored, nothing moves, run time stops. Then
  `EXITED` (outcome 3) and the app loads the next floor. A floor after the first opens with `arrive_ticks`
  (48, ~0.8 s; 18 with reduced motion) of the same hold before control returns. The run flow (`Main._start_floor`)
  sets both lengths at setup (`BossFlow.set_transit`); worlds built without it (tests, bots) keep the 60-tick way in
  and no arrival. `WorldReader.portal_enter_progress()`, `arrival_progress()`, `transit_holds()` expose it.
  SIM_CONTRACTS §2 phase 1c documents the hold.
- **View (EI-07).** `PortalTransitView` (in `WorldViewRoot`, synced after the actors) reads the progress and poses
  the hero's model: way in = drawn to the portal's centre, three turns of spin, shrink, a one-shot burst of 28
  light-blue motes, a light-blue flash (light, an additive ball, a faint screen flash) and the gate's flare; arrival =
  a light-blue column on the start spot, motes gathering, the hero growing and unwinding; then the model, its ring
  and HP bar are restored. Reduced motion: no pull, spin, motes or column; the screen fades out on the way in and
  in on the arrival. Every material is built once; only colours and uniforms change (no `emission_enabled` toggles).
  The app's black fade-in is shortened to 0.2 s on floors that open on the arrival so the column shows.
- **Sound.** `FLOOR_EXIT` plays the existing `blink_out` cue at pitch 0.7 (no new asset).
- **Not built:** the optional scan reveal on first entering an undiscovered room (skipped: the minimap and HUD are
  another workstream's this wave, and it would add clutter without an owner ask).

## Golden changes
None. `BossFlow.hash_into` now also streams `enter_tick, enter_ticks, arrive_ticks, arrive_left`, so the state hash
of every world with a boss flow (generated floors) changes; no golden fixture uses one (`replay_ground_plane.json`
and `export_smoke_hash.txt` run the kernel scenario, which has no boss flow), and both golden tests pass unchanged.

## Command (targeted)
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_portal_transit.gd,res://tests/unit/presentation/test_portal_transit_view.gd,res://tests/unit/presentation/test_portal_gate.gd,res://tests/e2e/test_e2e_portal.gd -gexit
```

## Raw output (targeted)
```
[… start trimmed …]
* test_reduced_motion_shortens_both
* test_the_first_floor_has_no_arrival_and_the_lengths_are_about_a_second
* test_the_transit_is_hashed_and_deterministic
5/5 passed.
res://tests/unit/presentation/test_portal_transit_view.gd
* test_the_way_in_draws_spins_and_shrinks_the_hero_into_motes
* test_the_arrival_grows_the_hero_inside_a_column_then_rests
* test_reduced_motion_is_a_plain_fade
* test_materials_are_built_once
4/4 passed.
res://tests/unit/presentation/test_portal_gate.gd
* test_setup_places_and_turns_the_gate
* test_opening_is_clear_and_portal_fills_it
* test_portal_shader_has_the_expected_uniforms
* test_the_portal_is_the_visors_light_blue
* test_sealed_is_the_default_and_toggles_the_uniform
* test_gate_strings_exist_in_both_languages
6/6 passed.
res://tests/e2e/test_e2e_portal.gd
* test_into_the_portal_and_out_on_floor_two
1/1 passed.
==============================================
= Run Summary
==============================================
Totals
------
Scripts               4
Tests                16
Passing Tests        16
Asserts             857
Time              19.454s
---- All tests passed! ----
```

## Command (full suite)
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash scripts/verify.sh
```

## Raw output (full suite)
```
358 files would be left unchanged
Success: no problems found
[… verify.sh output trimmed …]
Totals
------
Scripts             116
Tests               674
Passing Tests       674
Asserts           415251
Time              455.048s

---- All tests passed! ----
Results saved to build/gut.xml
check_gut_log: ok (674 passing, minimum 674)
```

## Screenshot strip
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" \
  godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/portal_transit.gd
```
```
portal_transit: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
portal_transit: res://build/shots/v0.3.5/portal/in_1_20.png tick=92
portal_transit: res://build/shots/v0.3.5/portal/in_2_50.png tick=110
portal_transit: res://build/shots/v0.3.5/portal/in_3_68.png tick=121
portal_transit: res://build/shots/v0.3.5/portal/in_4_83.png tick=130
portal_transit: res://build/shots/v0.3.5/portal/out_1_10.png tick=5
portal_transit: res://build/shots/v0.3.5/portal/out_2_35.png tick=17
portal_transit: res://build/shots/v0.3.5/portal/out_3_60.png tick=29
portal_transit: res://build/shots/v0.3.5/portal/out_4_85.png tick=41
portal_transit: res://build/shots/v0.3.5/portal/portal_transit_sheet.png 2560x720 ["in_1_20", "in_2_50", "in_3_68", "in_4_83", "out_1_10", "out_2_35", "out_3_60", "out_4_85"]
```
[`portal_transit_sheet.png`](portal_transit_sheet.png) (copied by hand from `build/`): top row, the way in at 20 %,
50 %, 68 %, 83 % (software renderer, llvmpipe); bottom row, the arrival on floor 2 at 10 %, 35 %, 60 %, 85 %. The
script poses the run directly (it kills the boss and places the hero), so floor 1's title card still shows over the
gate in the top row; in play the card has gone by the time the boss is dead.

## Result
| Check | Measured | OK? |
|---|---|---|
| Way in holds the world, input ignored, then the floor ends once | `ENTER_TICKS` = 60 ticks, `FLOOR_EXIT` ×1, outcome 3 after (unit) | yes |
| Arrival holds, then the stick moves the hero | `ARRIVE_TICKS` = 48 ticks (unit); e2e within ±3 frames | yes |
| Reduced motion shortens both to a fade | 24 / 18 ticks; no motes, spin or column (unit, view) | yes |
| Through `main.tscn` with real input: phase seen, floor 2 started exactly once | e2e | yes |
| Looks and feels right | — | OWNER ONLY |

## Interpretation
Both animations are owned by sim ticks; the view decides nothing. The lengths (60 / 48 ticks, 24 / 18 calm) are
starting values. Not proved here: how it reads at the owner's frame rate and screen (OWNER ONLY), and whether the
held second feels too long after a boss fight.
