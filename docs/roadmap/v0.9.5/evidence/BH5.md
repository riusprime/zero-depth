# v0.9.5 Step BH5 evidence

The Hollow Crown's first two bodies. Owner rows HC1, HC2, HC3 (BOSSES_HARD.md).

- Machine: the owner's PC (Windows 11, Godot 4.7.2 console build, headless, `--fixed-fps 60 --language en`).
- Build: base `8ba5aebd971a46bf1432c85aac119c1eb09cfab2` (branch `v095-bh5`, after merging `claude/v095-feedback`) plus
  this step's working tree. The step's own commit is the branch head.
- Command per file: `APPDATA=$TEMP/zd-bh5 godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://<file> -gexit --language en`
  (folders: `-gdir=res://tests/content -gdir=res://tests/golden -gdir=res://tests/arch -ginclude_subdirs`).

## What changed (all in data except one validation bound)

- HC1 Colossus: Fist Combo 5.5 -> 6.5 m/s (both variants); Leap Slam telegraph 0.7 -> 0.55 s (x 0.75 is 0.525, under the
  0.55 s rule, so it sits on the floor; all three variants), quake ring (and the phase-2 double ring) 6.5 -> 7.5 m/s;
  Boulder lob 4.2 -> 5.2 m/s. Spike Chase/Burst unchanged. Damage unchanged.
  `BulletPatternDefinition.MAX_SPEED_MPS` 7.0 -> 8.0 (code constant) so the 7.5 m/s ring validates.
- HC2 Prism balls: ring 32 -> 28 per ring, gaps 2 -> 3 wide (4 gaps; 16 orbs a wave); flower 64 -> 52; spiral 10 -> 8
  arms. Extra, not asked: the ring's `turn_per_wave_degrees` 33.75 -> 45 (the wider gaps otherwise overlapped between
  waves, so the hero no longer had to step; 45 is half the 90 degree gap period).
- HC3 window: Cross `window_seconds` 2.5 -> 3.5 and `active_seconds` 7.5 -> 8.5 (spin stays 5 s, shut). After each ball
  pattern she is open for 2.0 s: done with the existing `recovery_seconds` (0 -> 2.0; the shield only holds in the windup
  and active states) and `cooldown_seconds` 0.5 -> 0.0, not a new field. Her pattern's active time already runs until
  the last orb is gone, so the 2.0 s starts then (asserted: no orb in the air as it opens).

## Measured gaps (test_hollow_crown_hard, `gut.p` lines)

Widest free gap a wave leaves (chord between neighbouring orbs less the orb's width), over every wave and every
metre 3..7 m from her centre; a 0.5 m-radius hero fits (>= 1.0) and the test asserts >= 1.2 m:

| Pattern | least | most |
|---|---|---|
| crown_ring | 2.20 m | 5.67 m |
| crown_spiral | 1.90 m | 4.96 m |
| crown_flower | 1.38 m | 3.76 m |

Existing dodge lab (4 m out): ring 3.07 m, spiral 2.66 m, flower 1.98 m corridors; step between waves: ring 1.52 m/s,
flower 2.51 m/s (run 6.0 m/s). Its "not wide open" cap moved from 3 to 5 hero widths.

## final_pace (test_final_pace.gd, 16/16 before and after)

Bodies (s), [max HP, measured dps]:

| Build | Before | After |
|---|---|---|
| base blade | 103.7 / 98.6 / 152.6, Prism [703, 35] | 103.7 / 113.3 / 156.4, Prism [1121, 35] |
| strong blade | 72.8 / 80.5 / 151.4, Prism [2232, 206] | 72.8 / 71.8 / 149.4, Prism [3559, 206] |
| absurd gun (loop 3) | 49.3 / 53.5 / 49.5, Prism [999, 121] | 49.1 / 49.4 / 49.1, Prism [1650, 126] |
| absurd blade (loop 3) | 49.2 / 63.2 / 101.0, Prism [2689, 327] | 49.0 / 63.2 / 91.0, Prism [4180, 319] |

The Prism's HP follows her open share of a rotation (0.180 -> 0.287, compiled from the windows), so her time target
holds; the bots' times move by -10 % to +15 % (bot noise: they hit only inside windows). No pace assertion failed; the
minute floor holds in every row. The loop ease from BH1 is untouched.

## Tests changed

- `test_prism.gd`: four rings of 16 (was 24); "not wide open" 5 hero widths (was 3); window share 0.287 (was 0.180) and
  her HP 1883 (was 1181) at 100 dps; "three bolts in each 3.5 s window" (was two in 2.5 s).
- `tests/content/test_boss_pace.gd`: Colossus Leap Slam telegraph 0.55 (was 0.7).
- New `tests/unit/sim/test_hollow_crown_hard.gd` (7 tests): fists 6.5; leap telegraph 33 ticks and ring 7.5; boulders 5.2
  and Spike Chase unchanged; pattern counts; mid-arena gaps >= 1.2 m; the Cross's 3.5 s window open / spin shut (probed
  through every spin and window tick); 2.0 s open after each ball pattern.

## Totals

| Run | Result |
|---|---|
| test_colossus / test_final_boss / test_final_pace | 11 / 22 / 16 passing |
| test_prism | 27 passing (11861 asserts) |
| test_hollow_crown_hard | 7 passing |
| test_boss_hard, _2, _3 | 11 / 17 / 14 passing |
| test_readable_cause / test_bosses / test_bosses_2 | 4 / 16 / 19 passing |
| tests/content + golden + arch (33 scripts, first run) | 162 passing, 1 failing (test_boss_pace, the 0.7 pin, fixed); re-run of test_boss_pace 6/6 |
| e2e prism / final_boss / final_approach | 1 / 1 / 1 passing |
| Lint (gdformat, gdlint) over touched `.gd` | no problems |

Not re-run after the pin fix: the whole content/golden/arch folders (only test_boss_pace).
