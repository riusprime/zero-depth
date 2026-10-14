# TELEGRAPHS: which normal enemies still mark the ground, and do the bodies tell the windup instead? (v0.8.0 Step TG)

- **Status:** RUN (tests); the feel is OWNER ONLY
- **Build:** the working tree of `v080-tg` (base `98698cb` on `claude/lucid-fermat-9wv2tf`) with this step's changes,
  before its commit (the Step TG commit is that tree plus this file and the PROGRESS/PLAN rows); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`
- **Date:** 2026-10-14
- **Who ran it:** agent

Owner O4 (verbatim in [`../PLAN.md`](../PLAN.md)): "for most of them unless the things that are thrown from a distance
we are gonna be deleting the red tray that they show when they aim like we already did with some of them before".
Q3 answer (2026-10-14): "Only things landing at range (Recommended)": ground marks stay only on the Arc Caster's rune
and the Mine Layer's armed mines.

## What changed, per kind
| Kind | Before (v0.7.5) | Now (v0.8.0 TG) | The body's tell |
|---|---|---|---|
| Charger | red lane on the ground (windup) and the running lane (charge) | both `"ground": false`; nothing drawn | crouch + draw-back deepening with progress, visor brightens and flashes over the last 20 %; faces the lane |
| Hatchling | same as the Charger | same as the Charger | the Charger's model at 0.66 scale, same tell |
| Swarmer | lane (windup and running) | `"ground": false` | crouch + draw-back, eye glow and flash |
| Splitter / Splitling | disc in front | `"ground": false` | crouch + draw-back, seam glow and flash |
| Shield Bearer | `bash` lane | `"ground": false` (style kept) | crouch + draw-back (shield already draws back), visor glow and flash |
| Warden | slam disc round itself | `"ground": false` | knees-bent crouch (fists already climb overhead), visor glow and flash |
| Sniper | `snipe` line | `"ground": false` (style kept) | crouch, barrel dips, scope glow and flash, a muzzle gem at the barrel tip that charges and flares (in the air) |
| Needle | burst lanes | `"ground": false` | squat + nose down the aim, eyes and muzzle charge and flash |
| Arc Caster | rune disc (fan/spread already `cast`, off the ground since v0.7.5 EF) | **unchanged: the rune stays on the ground** | — |
| Mine Layer | armed mines (`discs`, `mine`) | **unchanged: stay on the ground** | — |
| Bomb Drone, Lens Drone | `lob` / `cast`, off the ground since v0.7.5 EF | unchanged | — |
| Mender | no attack | unchanged | — |
| Bosses | tracked-then-locked markers | **unchanged** | — |

- **Sim.** `EnemyAi.telegraph()` adds `"ground": false` to those dictionaries; every other field (shape, `obb` /
  `obbs` / `center` + `radius`, `progress`, `style`) stays, so the parity tests, the forecasts and the readable-cause
  check read the same shapes and timings. `telegraph()` is computed from actor state and never stored: `WorldSnapshot`
  has no telegraph field, so no hash, save or golden changes (the golden replay passed unchanged, below). Elites
  are their kind's AI (`Curses.make_elite` only raises HP), so they follow the same rule (tested).
- **Presentation.** `TelegraphViews` already skips `ground: false`. `AvatarBase` gains the shared tell
  (`tell_crouch`, `tell_glow`, `windup_progress`; starting values `TELL_CROUCH_BY` 0.6, `TELL_FLASH_FROM` 0.8,
  `TELL_GLOW_CLIMB` 1.5, `TELL_GLOW_FLASH` 2.5, `TELL_FLICKER_HZ` 9), read from the telegraph's `progress` in each
  avatar's `sync()`. Reduced motion (`ViewPrefs.reduced_motion`): the flash is a steady step up (no flicker), and the
  Charger's / Warden's tremble, the Charger's visor shimmer, the Needle's eye pulse and the horde bob stop; the crouch
  (a slow pose) stays. The facing: the sim holds an enemy's facing through its windup (the Needle and Sniper track
  until their commit window, then hold), and `ActorViews` sets the model's yaw from it unsmoothed, so the body
  points down the attack and stops turning before the strike (tested).
- **Docs.** `PRESENTATION_CONTRACTS.md` §4 (body cues instead of ground marks), `SIM_CONTRACTS.md` §10e,
  `BOSS_FIGHTS.md` "Normal enemies" (superseded rows).

## Commands
```
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --path . --editor --import --quit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_boss_telegraph_parity.gd,res://tests/unit/presentation/test_charger_avatar.gd,res://tests/unit/presentation/test_colour_modes.gd,res://tests/unit/presentation/test_horde_avatars.gd,res://tests/unit/presentation/test_needle_avatar.gd,res://tests/unit/presentation/test_new_enemy_avatars.gd,res://tests/unit/presentation/test_player_avatar.gd,res://tests/unit/presentation/test_telegraph_parity.gd,res://tests/unit/presentation/test_warden_avatar.gd,res://tests/unit/presentation/test_windup_tells.gd,res://tests/unit/presentation/test_enemy_fireball_views.gd,res://tests/unit/sim/test_enemies.gd,res://tests/unit/sim/test_enemy_ai.gd,res://tests/unit/sim/test_enemy_fireballs.gd,res://tests/unit/sim/test_enemy_ground_marks.gd,res://tests/unit/sim/test_horde.gd,res://tests/unit/sim/test_horde_enemies.gd,res://tests/unit/sim/test_readable_cause.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/golden,res://tests/arch -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_enemies.gd,res://tests/e2e/test_e2e_horde_enemies.gd,res://tests/e2e/test_e2e_new_enemies.gd,res://tests/e2e/test_e2e_enemy_fireballs.gd,res://tests/e2e/test_e2e_audio.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_curses.gd,res://tests/unit/presentation/test_event_views.gd,res://tests/unit/presentation/test_ui_polish.gd -gexit
```

## Raw output
Lint:
```
802 files would be left unchanged
Success: no problems found
```

Unit (sim + presentation; ANSI colour codes stripped, the per-test lines trimmed to the per-file totals):
```
res://tests/unit/presentation/test_boss_telegraph_parity.gd
9/9 passed.
res://tests/unit/presentation/test_charger_avatar.gd
6/6 passed.
res://tests/unit/presentation/test_colour_modes.gd
4/4 passed.
res://tests/unit/presentation/test_horde_avatars.gd
8/8 passed.
res://tests/unit/presentation/test_needle_avatar.gd
8/8 passed.
res://tests/unit/presentation/test_new_enemy_avatars.gd
6/6 passed.
res://tests/unit/presentation/test_player_avatar.gd
10/10 passed.
res://tests/unit/presentation/test_telegraph_parity.gd
3/3 passed.
res://tests/unit/presentation/test_warden_avatar.gd
8/8 passed.
res://tests/unit/presentation/test_windup_tells.gd
5/5 passed.
res://tests/unit/presentation/test_enemy_fireball_views.gd
4/4 passed.
res://tests/unit/sim/test_enemies.gd
12/12 passed.
res://tests/unit/sim/test_enemy_ai.gd
17/17 passed.
res://tests/unit/sim/test_enemy_fireballs.gd
10/10 passed.
res://tests/unit/sim/test_enemy_ground_marks.gd
3/3 passed.
res://tests/unit/sim/test_horde.gd
6/6 passed.
res://tests/unit/sim/test_horde_enemies.gd
23/23 passed.
res://tests/unit/sim/test_readable_cause.gd
4/4 passed.
Scripts              18
Tests               146
Passing Tests       146
Asserts           38418
Time              88.131s
---- All tests passed! ----
```

Golden + arch:
```
res://tests/golden/test_replay_ground_plane.gd
* test_replay_matches_every_checkpoint
* test_two_runs_in_one_process_agree
2/2 passed.
res://tests/arch/test_layering.gd
* test_no_reference_crosses_a_layer_the_wrong_way
* test_rules
2/2 passed.
res://tests/arch/test_sim_purity.gd
* test_sim_sources_are_pure
* test_the_lint_catches_planted_tokens
2/2 passed.
Scripts               3
Tests                 6
Passing Tests         6
Asserts            8926
Time              8.258s
---- All tests passed! ----
```

E2E (through `main.tscn` and `Input.parse_input_event`):
```
res://tests/e2e/test_e2e_enemies.gd
* test_the_first_enemies_arrive_and_telegraph
1/1 passed.
res://tests/e2e/test_e2e_horde_enemies.gd
* test_the_dev_panel_brings_in_each_horde_kind_and_it_acts
* test_the_mender_heals_an_ally_the_player_shot
2/2 passed.
res://tests/e2e/test_e2e_new_enemies.gd
* test_the_dev_panel_brings_in_both_new_enemies_and_they_attack
1/1 passed.
res://tests/e2e/test_e2e_enemy_fireballs.gd
* test_an_arc_caster_casts_a_fan_of_three_plasma_balls_with_no_ground_line
1/1 passed.
res://tests/e2e/test_e2e_audio.gd
* test_menus_floor_and_blade_have_their_sounds
* test_captions_on_show_the_boss_telegraph
2/2 passed.
Scripts               5
Tests                 7
Passing Tests         7
Asserts             687
Time              37.573s
---- All tests passed! ----
```

Readable-cause users (curses, event views, UI polish):
```
res://tests/unit/sim/test_curses.gd
13/13 passed.
res://tests/unit/presentation/test_event_views.gd
6/6 passed.
res://tests/unit/presentation/test_ui_polish.gd
14/14 passed.
Scripts               3
Tests                33
Passing Tests        33
Asserts            3190
Time              466.214s
---- All tests passed! ----
```

## Tests changed or added
- **Added** `tests/unit/sim/test_enemy_ground_marks.gd`: the per-kind table (Charger, Hatchling, Swarmer, Splitter,
  Splitling, Shield Bearer, Warden, Sniper, Needle: none; Arc Caster: `disc/rune`; Mine Layer: `discs/mine`; Bomb
  Drone, Lens Drone, Mender: none), each kind still telegraphing its shape; the same for elites; the Charger's
  off-ground lane still filling 0..1000 over the windup.
- **Added** `tests/unit/presentation/test_windup_tells.gd`: the tell curves; every tell avatar crouches, brightens and
  flashes (≥ 1.3× over the last 20 %); the flash is steady under reduced motion and flickers without it; the Sniper's
  muzzle charges in the air (and the other kinds have none); the model faces the locked attack and holds still over
  the commit window.
- **Changed** `tests/unit/sim/test_enemy_fireballs.gd` (`…keep_their_shapes_off_the_ground`: the shapes stay,
  `ground` is false), `tests/unit/presentation/test_enemy_fireball_views.gd` (the Needle draws no lines on the
  ground but still telegraphs), `tests/e2e/test_e2e_enemies.gd` (no ground mark from a Charger or a Needle; an
  enemy's body crouches in its windup within 15 s), `tests/e2e/test_e2e_horde_enemies.gd` (a body-cue telegraph
  counts when the model crouches; the mines still need the drawn circle).

## Result
| Check | Measured | Pass? |
|---|---|---|
| Normal kinds with a ground mark | Arc Caster rune, Mine Layer mines only (`test_enemy_ground_marks`) | yes |
| Elites | same table (`test_elites_follow_their_kind`) | yes |
| Hit area = telegraph shape | `test_telegraph_parity` 3/3 | yes |
| Golden replay | unchanged, 2/2 | yes |
| The tell reads (crouch, glow, flash, facing) | `test_windup_tells` 5/5 | yes |
| It feels readable in play | — | OWNER ONLY |

## Interpretation
The sim no longer asks the view to draw the melee kinds', the Sniper's or the Needle's marks; the shapes and timings
are unchanged, so hits, forecasts and the readable-cause recap are as before. Whether a crouch and a flash are enough
to dodge a Charger or a Sniper without the lane is the owner's playtest question (OWNER ONLY); the tell's numbers are
starting values in `AvatarBase` (TELL_*).
