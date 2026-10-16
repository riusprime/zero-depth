# VOID_AND_PORTALS: Void's black holes; the Ascension portal and the Loop device (v0.8.0 P2, owner O24, O28)

Owner, 2026-10-16 (verbatim in [`../PLAN.md`](../PLAN.md) O24 and O28): "The Void spell is buggy, and its current
enemy-pulling mechanic is unsatisfying. Change Void so shots have a chance to spawn a small black hole lasting 2
seconds, attracting nearby enemies and dealing damage"; "Final boss should not be at the end the run … it should be a
continue flow, and you can pick a small different device than the ascension to loop we separate it into two different
actions from now on, not a menu, two different visual elements the ascension to go fight final boss or the loop
element, separated".

- **Status:** RUN (agent: headless tests, a scratch placement probe, software-rendered shots). How it feels, whether
  the two devices read apart and the black holes' strength: **OWNER ONLY**.
- **Build:** the working tree of branch `v080-p2` (parent `6da58e4`) holding the `v0.8.0 Step P2` changes; every run
  below was made on that tree before the commit (only these docs, the shots' copies and one test's wait, noted below,
  were written after some runs). Godot `4.7.2.stable.official.ed1daf0bf`; Linux cloud container shared with two other
  agents (P1, P3), so timings are slow and noisy.
- **Date:** 2026-10-16. **Who ran it:** agent.
- What was built and the readings: PLAN "P2"; the flow: [`../FINAL_BOSS.md`](../FINAL_BOSS.md) "The flow since P2".

## What changed (player-facing)
- **Void.** No pull on every hit any more. Each shot (a Gun bolt where it ends; a slash where it first lands) has
  8 % (+3 % a level: 8 / 11 / 14 / 17 / 20 %) to leave a small dark swirling black hole for 2 s; it draws enemies within
  3.5 m in at 3 m/s and every 0.2 s hurts the ones within 1.4 m for 30 % of the shot (damage over time); at most 3
  stand (a new one replaces the oldest). Starting values.
- **The last floor.** No choice menu, no "End the run". When the boss dies, two separate things open: the Ascension
  portal (walk into its light: the final boss) and the smaller green Loop device beside it (step on it: the next
  loop's floor 1 with your build), each named over it; the HUD names both.

## Tests
Lint (after the last code change):
```
$ gdformat --check src scripts tests && gdlint src scripts tests
943 files would be left unchanged
Success: no problems found
```

The touched folders and the e2e reaching the change (`godot --headless --fixed-fps 60 --path . -s
addons/gut/gut_cmdln.gd <-gdir=… -ginclude_subdirs | -gtest=…> -gexit`; each block is the run's GUT `Totals`, ANSI
codes stripped):

| Run | Raw totals |
|---|---|
| `-gdir=res://tests/unit/sim` (whole folder) | **timed out** (`timeout 3500`, exit 124) under the machine's load after 55 of 111 scripts: 673 tests reported, 0 `[Failed]`, every script line "N/N passed"; the 56th (`test_ice_patches.gd`) was cut. The rest was run in two halves: |
| sim scripts 56–83 (`test_ice_patches` … `test_room_layouts`) | `Scripts 28 / Tests 284 / Passing Tests 284 / Asserts 1612721 / Time 3079.361s` |
| sim scripts 84–111 (`test_room_themes` … `test_world_walls`) | `Scripts 28 / Tests 257 / Passing Tests 256 / Failing Tests 1 / Asserts 193861/193862 / Time 3404.228s`: `[Failed]: blade: an attack left a black hole` (`test_wand_shared.gd` `test_s6_…`, line 200) |
| the fix: the test swung once a tick (`_attack(w, weapon, 1)`), so most presses fell inside the swing; now 14 ticks between swings, as `test_black_holes.gd`. Re-run of `test_wand_shared`, `test_ascension`, `test_black_holes`, `test_mx4_modifiers` | `Scripts 4 / Tests 51 / Passing Tests 51 / Asserts 3223 / Time 55.03s` |
| `-gdir=res://tests/unit/application` | `Scripts 13 / Tests 99 / Passing Tests 99 / Asserts 1017 / Time 142.988s` |
| `-gdir=res://tests/unit/presentation` | `Warnings 2 / Deprecated 1 / Scripts 97 / Tests 686 / Passing Tests 686` |
| `-gdir=res://tests/content` (after the card text was shortened: the first run failed `test_item_descriptions_are_short`, `[123] expected to be <= than [60]: ITEM_GRAVITY_WELL_DESC en`, `[150] … es`) | `Scripts 25 / Tests 126 / Passing Tests 126 / Asserts 8686 / Time 72.52s` |
| `-gdir=res://tests/arch` | `Scripts 2 / Tests 4 / Passing Tests 4 / Asserts 11277 / Time 2.362s` |
| `-gdir=res://tests/golden` | `Scripts 1 / Tests 2 / Passing Tests 2 / Asserts 4 / Time 10.528s` |
| e2e `test_e2e_ascension.gd` + `test_e2e_void.gd` | `Scripts 2 / Tests 3 / Passing Tests 3 / Asserts 159 / Time 86.026s` |
| e2e `test_e2e_final_boss.gd` + `test_e2e_nemesis.gd` | `Scripts 2 / Tests 4 / Passing Tests 4 / Asserts 449 / Time 144.134s` |
| e2e `test_e2e_old_save`, `_saves`, `_run_flow`, `_achievements`, `_codex`, `_wand_shared` | `Scripts 6 / Tests 9 / Passing Tests 9 / Asserts 182 / Time 107.953s` |

Not run locally: the full suite (owner rule: GitHub runs it on the PR), the bots (owner rule), `scripts/ci/seams.sh`
(the lead's).

What the new tests prove:
- `tests/unit/sim/test_black_holes.gd` (10): the card compiles 80/110/140/170/200 ‰ and no pull on both weapons; the
  roll draws once on `ability` (5000 rolls: `8 % card: 356 holes in 5000 rolls (0.071)`); a hole stands 120 ticks,
  at most 3 (the oldest replaced); the pull (3 m/s, not past 0.3 m, 6 m away untouched); 9 DoT pulses (TAG_DOT, proc
  0, never a HIT) in its life; the pulse share; in play `level-5 Void, 600 ticks of shooting: 9 holes opened` and
  `level-5 Void, 60 slashes: 5 holes`; replay to the same hash; a snapshot with holes standing restores and plays on
  the same; a build without Void draws nothing on `ability`.
- `tests/unit/sim/test_ascension.gd`: the Loop device on the last floor only, in the boss room, out of the portal's
  opening, no wall on its pad and nothing solid added (6 seeds); both devices dormant during the fight; the portal
  goes straight in to the final boss; without a final boss the portal wins the run; the Loop device starts loop 2
  with the build; no pick waits.
- `tests/unit/application/test_ascension_saves.gd`: a last-floor save from before P2 (the retired fields saved,
  Ascend's number 2) restores onto the rebuilt floor with the Loop device and reads as the Loop device.
- `tests/unit/presentation/test_ascension_views.gd`, `test_black_hole_views.gd`: the Loop device's own colour (apart
  from the portal's, the gate's and Deep's), smaller, lit and named only once open, reduced motion; the holes drawn from
  the pool where the sim's stand, opening and closing, reduced motion.
- `tests/e2e/test_e2e_ascension.gd` (main.tscn, real input): both devices drawn, dormant, then open and named, the HUD
  naming both; walking onto the Loop device → loop 2 floor 1 with the build, the Codex counting it, Continue; another
  run walks into the Ascension portal → the final arena, no recap, no loop counted. `test_e2e_final_boss.gd` and
  `test_e2e_nemesis.gd` reach the arena by walking into the portal. `tests/e2e/test_e2e_void.gd`: Void granted 5 times
  in a Gun run, held fire leaves black holes (at most 3) that the view draws.

## Goldens
None changed. `tests/golden` 2/2 above; `test_modifier_equivalence.gd` ran in the sim half 56–83 (284/284). No golden
case holds Void; `AttackSpec.hole_permille` / `hole_damage_permille` are `LATE_INT_FIELDS` (hashed only when set), the
holes hash only while one stands, and an Ascension floor's BossFlow hash keeps its fields.

## The Loop device's place (scratch probe, not tracked)
A scratch script (in the session's scratchpad, not committed) built 60 real last floors (`SaveLab.run_state(1000 + s,
3)`, s = 1..60) and measured where `Ascension.place_loop_device` put the pad:
```
$ SEEDS=60 godot --headless --path . -s <scratchpad>/loop_spots.gd
PROBE| seeds=60 beside_the_portal=60 fallback_boss_spawn=0 pad_to_portal_front_m=4.80..4.80 pad_to_altar_min_m=19.56
```
Every floor put it beside the portal (4.8 m from the portal's front point); the fallback (3 m from the boss's spawn,
toward the portal, clear of the legendary altar) was never needed. (The probe ran before the fallback moved off
`boss_spawn`; it was 0 then too.)

## Shots
Software-rendered (llvmpipe), Ruins, run seed 20261013, floor 3; the world is never stepped (the portal's state and the
holes are set for the view):
```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
    --audio-driver Dummy --resolution 1600x900 -s scripts/shots/ascension.gd -- lang=en
ascension: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) seed=20261013 lang=en
ascension: floor 3 biome ruins portal (-108.125, -44.9)
ascension: res://build/shots/v0.7.5-dev/ascension/en/1_dormant.png
ascension: res://build/shots/v0.7.5-dev/ascension/en/2_open_both_devices.png
ascension: res://build/shots/v0.7.5-dev/ascension/en/3_loop_device_close.png
Killed
```
The process was killed by the container's memory limit (`Memory cgroup out of memory: Killed process … (godot)`, the
other agents' runs sharing it) before the black-hole shots; they were taken by a second run of the same script with
its `holes` option (only the black-hole shots):
```
$ … -s scripts/shots/ascension.gd -- lang=en holes
ascension: res://build/shots/v0.7.5-dev/ascension/en/4_black_holes.png
ascension: res://build/shots/v0.7.5-dev/ascension/en/5_black_hole_close.png
ascension: res://build/shots/v0.7.5-dev/ascension/en/6_blue_gate_floor1.png
```
Copied by hand into [`p2_shots/`](p2_shots/) as JPEG (quality 85): `1_dormant` (both devices dormant),
`2_open_both_devices` (the Ascension portal's column and name, the green Loop device beside it), `3_loop_device_close`,
`4_black_holes` (three holes, ages 30/60/90 ticks, standing enemies round the middle one), `5_black_hole_close`.

## Not checked here
- The feel of the holes (strength, size, 8 %), and whether the devices read apart on the owner's screen: **OWNER
  ONLY** (OWNER_TODO D20, D21 and the checks).
- The "buggy" Void the owner saw was not reproduced in play; the reading of the old code is in PLAN "P2".
