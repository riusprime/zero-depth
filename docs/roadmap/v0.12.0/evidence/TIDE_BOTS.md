# TIDE_BOTS: does ignoring the Tidecaller's dance cost clearly more than playing it?

- **Status:** RUN. **The expectation is NOT MET** (see "Result"; still not met after step 4b, its section at the
  end): the numbers are below, nothing was retuned.
- **Build:** the tree of the commit that adds this file (`v0.12.0 Step 4`; its parent is `c7ae896b`) on `v0120-t4`,
  run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200 (the owner's
  PC, i7-10700K), debug native library built from this tree
- **Date:** 2026-11-14
- **Who ran it:** agent

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden -gtest=res://tests/unit/sim/test_tide_bots.gd,res://tests/unit/sim/test_tide_dance.gd,res://tests/unit/sim/test_tidecaller.gd,res://tests/unit/sim/test_tidecaller_streams.gd,res://tests/unit/sim/test_boss_pace.gd,res://tests/unit/sim/test_boss_hazard.gd,res://tests/unit/sim/test_world_snapshot.gd,res://tests/unit/sim/test_readable_cause.gd,res://tests/unit/sim/test_judge_time.gd,res://tests/unit/presentation/test_attack_visuals_2.gd,res://tests/unit/presentation/test_tidecaller_views.gd,res://tests/unit/presentation/test_tide_wave_views.gd,res://tests/unit/presentation/test_boss_views.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. Only
`test_tide_bots.gd` prints the lines below. That process exited 1 because of tests of the old Pull in
`test_tidecaller.gd` and the hazard count in `test_boss_hazard.gd`, updated afterwards; the bots' test and the sim
were not changed after this run.)

## What the bots do
`tests/unit/sim/test_tide_bots.gd`: the real compiled Tidecaller (2,500 HP, the data's numbers, **no floor
scaling**) in a 24 m walled room, a hero with the starting Gun or Blade and no items. The hero has its real max HP
(100; the dance's costs are shares of it) and is refilled every tick, so no fight ends early; `hp_lost` is the damage
it took. `rip`, `tide`, `eye` are the HP lost to Riptide, High Tide and the Maelstrom's eye; `other` is everything
else (rings, crossing waves, Undertow, Shell Slam, which neither bot dodges).
- **plays:** in a High Tide walks into the dry circle; in a row of Riptide walks straight across to the safe strip;
  in the Maelstrom stays out of the eye, and steps out of it before anything else (the Blade stands 0.25 m outside
  it, inside its 2.2 m reach). Otherwise holds its weapon's distance and attacks.
- **ignores:** holds its weapon's distance (Gun 4–6 m, Blade 1.2 m from the boss's edge) and attacks.

## Raw output
```
TIDEBOT| weapon=gun bot=plays seed=5 dead=true ticks=6340 seconds=105.7 max_hp=100 hp_lost=1139 biggest=50 rip=35 tide=36 eye=0 other=1068 rows=3 strip_hits=1 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=5 dead=true ticks=6274 seconds=104.6 max_hp=100 hp_lost=1309 biggest=50 rip=210 tide=36 eye=0 other=1063 rows=3 strip_hits=6 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=plays seed=6 dead=true ticks=6412 seconds=106.9 max_hp=100 hp_lost=1125 biggest=50 rip=105 tide=33 eye=0 other=987 rows=3 strip_hits=3 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=33 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=6 dead=true ticks=6310 seconds=105.2 max_hp=100 hp_lost=1340 biggest=53 rip=210 tide=36 eye=0 other=1094 rows=3 strip_hits=6 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=plays seed=7 dead=true ticks=6379 seconds=106.3 max_hp=100 hp_lost=1197 biggest=50 rip=140 tide=36 eye=0 other=1021 rows=3 strip_hits=4 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=7 dead=true ticks=6275 seconds=104.6 max_hp=100 hp_lost=1307 biggest=50 rip=210 tide=33 eye=0 other=1064 rows=3 strip_hits=6 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=33 throws=0 eye_cost=0
TIDEBOT| weapon=gun over 3 seeds: plays { "ticks": 19131, "hp_lost": 3461, "rip": 280, "tide": 105, "eye": 0, "other": 3076, "strip_hits": 8, "throws": 0 }, ignores { "ticks": 18859, "hp_lost": 3956, "rip": 630, "tide": 105, "eye": 0, "other": 3221, "strip_hits": 18, "throws": 0 }
TIDEBOT| weapon=blade bot=plays seed=5 dead=true ticks=6405 seconds=106.8 max_hp=100 hp_lost=1047 biggest=38 rip=78 tide=0 eye=180 other=789 rows=4 strip_hits=3 strip_cost=26 tides=2 seconds_outside=0.2 tide_cost=0 throws=6 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=5 dead=true ticks=3829 seconds=63.8 max_hp=100 hp_lost=520 biggest=38 rip=52 tide=36 eye=210 other=222 rows=2 strip_hits=2 strip_cost=26 tides=1 seconds_outside=5.8 tide_cost=36 throws=7 eye_cost=30
TIDEBOT| weapon=blade bot=plays seed=6 dead=true ticks=6400 seconds=106.7 max_hp=100 hp_lost=795 biggest=38 rip=26 tide=0 eye=150 other=619 rows=4 strip_hits=1 strip_cost=26 tides=2 seconds_outside=0.3 tide_cost=0 throws=5 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=6 dead=true ticks=3828 seconds=63.8 max_hp=100 hp_lost=483 biggest=38 rip=26 tide=30 eye=210 other=217 rows=2 strip_hits=1 strip_cost=26 tides=1 seconds_outside=5.8 tide_cost=30 throws=7 eye_cost=30
TIDEBOT| weapon=blade bot=plays seed=7 dead=true ticks=5405 seconds=90.1 max_hp=100 hp_lost=715 biggest=38 rip=78 tide=6 eye=180 other=451 rows=3 strip_hits=3 strip_cost=26 tides=1 seconds_outside=2.3 tide_cost=6 throws=6 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=7 dead=true ticks=3980 seconds=66.3 max_hp=100 hp_lost=668 biggest=38 rip=104 tide=33 eye=210 other=321 rows=2 strip_hits=4 strip_cost=26 tides=1 seconds_outside=6.0 tide_cost=33 throws=7 eye_cost=30
TIDEBOT| weapon=blade over 3 seeds: plays { "ticks": 18210, "hp_lost": 2557, "rip": 182, "tide": 6, "eye": 510, "other": 1859, "strip_hits": 7, "throws": 17 }, ignores { "ticks": 11637, "hp_lost": 1671, "rip": 182, "tide": 99, "eye": 630, "other": 760, "strip_hits": 7, "throws": 21 }
    [Pending]:  NOT MET, ignoring the dance costs at least 30 % more HP: gun: ignoring cost 3956 HP in 18859 ticks, playing 3461 HP in 19131 ticks; blade: ignoring cost 1671 HP in 11637 ticks, playing 2557 HP in 18210 ticks
```

## Result

| | Gun plays | Gun ignores | Blade plays | Blade ignores |
|---|---|---|---|---|
| Fight length, 3 seeds (s) | 318.9 | 314.3 | 303.5 | 194.0 |
| HP lost, all | 3,461 | 3,956 | 2,557 | 1,671 |
| HP lost to the dance (rip + tide + eye) | 385 | 735 | 698 | 911 |
| Strip hits | 8 | 18 | 7 | 7 |
| Seconds outside the dry circle | 18.0 | 18.0 | 2.8 | 17.6 |
| Eye throws | 0 | 0 | 17 | 21 |
| Most one strip hit / one eye hit / one whole High Tide cost | 35 / — / 36 | 35 / — / 36 | 26 / 30 / 6 | 26 / 30 / 36 |

- **What holds** (asserted): every Tidecaller dies; no single strip hit, eye hit or whole High Tide costs more than
  40 % of the hero's max HP; the dance itself costs the bot that ignores it more (Gun 735 against 385, Blade 911
  against 698).
- **NOT MET: "ignores loses clearly more HP".** Gun: 3,956 against 3,461 (14 % more; the test asks 30 %). Blade: the
  bot that **ignores** loses **less** (1,671 against 2,557) and wins in 64 s instead of about 100 s. The test reports
  this as pending, not as passed. Nothing was retuned.
- **What the numbers show** (read from the raw lines, not traced tick by tick):
  1. About 10 HP a second comes from attacks neither bot dodges (`other`: 3,076 to 3,221 for the Gun), so the dance
     is a small part of the total in this harness.
  2. The Gun bot that plays is outside the dry circle for the whole 6 s in all three fights. It reaches the circle
     and leaves it again when the Tidecaller walks up: the boss still walks at the hero in the Maelstrom, so its eye
     moves onto the dry circle. Before the bot was told to step out of the eye first, it stayed (0.2 to 3.5 s
     outside) and was thrown 2 to 4 times a fight instead.
  3. The Blade that stands in the eye (ignores) is thrown 7 times a fight for 30 each and still wins far sooner,
     because it never stops hitting; the Blade that respects the eye has only a 0.7 m band between the eye (1.5 m
     from the boss's edge) and its reach (2.2 m), with the boss walking at it and the water carrying it in, and is
     still thrown 5 to 6 times.
  4. The bot that plays is still hit by 7 or 8 strips of 36 to 44 casts: not traced which casts.
- **The brief's eye of 2.5 m was not used:** the Blade reaches 2.2 m, so a 2.5 m eye leaves it no place to hit
  from. The data has 1.5 m (`maelstrom_eye_m`).

## Not measured
- The Tidecaller at floor-4 scaling (the bots fight it unscaled), and a real boss room (larger than 24 m and maybe
  not square).
- An earlier run of the same harness, before the plays bot stepped out of the eye first, is not kept as evidence
  beyond the sentence above.
- Feel, difficulty, "do you notice the pull": `OWNER ONLY`.

## After step 4b (2026-11-14)

- **Status:** RUN. **The expectation is still NOT MET** (Gun 28 % more, not 30 %; the Blade that ignores still
  loses less). Nothing was retuned; the test's `pending` is unchanged.
- **What changed:** from the Maelstrom's phase on the Tidecaller walks straight to the room's centre at its own speed
  (attacking as it goes) and then never moves; the dry circle keeps the eye, the hero's width and 1 m clear of
  itself anywhere on that walk (SIM_CONTRACTS §10p). No number, eye radius, pull or bot changed.
- **Build:** the tree of the commit that adds this section (`v0.12.0 Step 4b`; its parent is `847115c6`) on
  `v0120-t4b`, run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200
  (the owner's PC), debug native library built from this tree. Two other agents ran Godot at the same time (no
  timing is read from it).
- **Who ran it:** agent

### Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden -gtest=res://tests/unit/sim/test_tide_dance.gd,res://tests/unit/sim/test_tide_bots.gd,res://tests/unit/sim/test_tidecaller.gd,res://tests/unit/sim/test_world_snapshot.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. Exit 0: 264 tests, 263
passing, 1 pending, the bots' target below.)

### Raw output
```
TIDEBOT| weapon=gun bot=plays seed=5 dead=true ticks=6523 seconds=108.7 max_hp=100 hp_lost=1146 biggest=50 rip=35 tide=6 eye=0 other=1105 rows=3 strip_hits=1 strip_cost=35 tides=1 seconds_outside=1.4 tide_cost=6 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=5 dead=true ticks=6282 seconds=104.7 max_hp=100 hp_lost=1344 biggest=50 rip=210 tide=33 eye=0 other=1101 rows=3 strip_hits=6 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=33 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=plays seed=6 dead=true ticks=6630 seconds=110.5 max_hp=100 hp_lost=1002 biggest=50 rip=70 tide=0 eye=0 other=932 rows=3 strip_hits=2 strip_cost=35 tides=1 seconds_outside=0.4 tide_cost=0 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=6 dead=true ticks=6398 seconds=106.6 max_hp=100 hp_lost=1437 biggest=50 rip=210 tide=36 eye=0 other=1191 rows=3 strip_hits=6 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=plays seed=7 dead=true ticks=6506 seconds=108.4 max_hp=100 hp_lost=1105 biggest=50 rip=70 tide=6 eye=0 other=1029 rows=3 strip_hits=2 strip_cost=35 tides=1 seconds_outside=1.3 tide_cost=6 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=7 dead=true ticks=6474 seconds=107.9 max_hp=100 hp_lost=1397 biggest=50 rip=245 tide=36 eye=0 other=1116 rows=3 strip_hits=7 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=0 eye_cost=0
TIDEBOT| weapon=gun over 3 seeds: plays { "ticks": 19659, "hp_lost": 3253, "rip": 175, "tide": 12, "eye": 0, "other": 3066, "strip_hits": 5, "throws": 0 }, ignores { "ticks": 19154, "hp_lost": 4178, "rip": 665, "tide": 105, "eye": 0, "other": 3408, "strip_hits": 19, "throws": 0 }
TIDEBOT| weapon=blade bot=plays seed=5 dead=true ticks=6408 seconds=106.8 max_hp=100 hp_lost=1070 biggest=38 rip=26 tide=33 eye=300 other=711 rows=4 strip_hits=1 strip_cost=26 tides=2 seconds_outside=7.3 tide_cost=27 throws=10 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=5 dead=true ticks=3828 seconds=63.8 max_hp=100 hp_lost=523 biggest=38 rip=52 tide=33 eye=210 other=228 rows=2 strip_hits=2 strip_cost=26 tides=1 seconds_outside=5.3 tide_cost=33 throws=7 eye_cost=30
TIDEBOT| weapon=blade bot=plays seed=6 dead=true ticks=5986 seconds=99.8 max_hp=100 hp_lost=939 biggest=38 rip=52 tide=30 eye=210 other=647 rows=4 strip_hits=2 strip_cost=26 tides=2 seconds_outside=6.0 tide_cost=30 throws=7 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=6 dead=true ticks=3844 seconds=64.1 max_hp=100 hp_lost=532 biggest=38 rip=78 tide=27 eye=210 other=217 rows=2 strip_hits=3 strip_cost=26 tides=1 seconds_outside=5.6 tide_cost=27 throws=7 eye_cost=30
TIDEBOT| weapon=blade bot=plays seed=7 dead=true ticks=6052 seconds=100.9 max_hp=100 hp_lost=902 biggest=38 rip=52 tide=6 eye=180 other=664 rows=4 strip_hits=2 strip_cost=26 tides=2 seconds_outside=1.4 tide_cost=6 throws=6 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=7 dead=true ticks=4162 seconds=69.4 max_hp=100 hp_lost=741 biggest=38 rip=104 tide=21 eye=240 other=376 rows=2 strip_hits=4 strip_cost=26 tides=1 seconds_outside=6.1 tide_cost=21 throws=8 eye_cost=30
TIDEBOT| weapon=blade over 3 seeds: plays { "ticks": 18446, "hp_lost": 2911, "rip": 130, "tide": 69, "eye": 690, "other": 2022, "strip_hits": 5, "throws": 23 }, ignores { "ticks": 11834, "hp_lost": 1796, "rip": 234, "tide": 81, "eye": 660, "other": 821, "strip_hits": 9, "throws": 22 }
    [Pending]:  NOT MET, ignoring the dance costs at least 30 % more HP: gun: ignoring cost 4178 HP in 19154 ticks, playing 3253 HP in 19659 ticks; blade: ignoring cost 1796 HP in 11834 ticks, playing 2911 HP in 18446 ticks
```

### Result

| | Gun plays | Gun ignores | Blade plays | Blade ignores |
|---|---|---|---|---|
| Fight length, 3 seeds (s) | 327.7 | 319.2 | 307.4 | 197.2 |
| HP lost, all | 3,253 | 4,178 | 2,911 | 1,796 |
| HP lost to the dance (rip + tide + eye) | 187 | 770 | 889 | 975 |
| Strip hits | 5 | 19 | 5 | 9 |
| Seconds outside the dry circle | 3.1 | 18.0 | 14.7 | 17.0 |
| Eye throws | 0 | 0 | 23 | 22 |

- **The moving eye is fixed for the Gun:** the bot that plays is now outside the dry circle 0.4 to 1.4 s a High Tide
  (it was the whole 6 s), and its High Tide costs 12 HP over 3 fights (it was 105). The dance costs the Gun that
  ignores it 770 against 187.
- **NOT MET, Gun:** 4,178 against 3,253 is 28 % more (the test asks 30 %; it was 14 %). Most of both totals is
  `other` (3,066 and 3,408), attacks neither bot dodges.
- **NOT MET, Blade:** the bot that ignores still loses less (1,796 against 2,911) and wins in about 66 s instead of
  about 102 s. Read from the numbers, not traced: the Blade that plays is still thrown by the eye 6 to 10 times a
  fight (690 HP), about as often as the one that stands in it; and its High Tides cost it 33 and 30 in seeds 5 and
  6 (6 to 7 s outside), so it did not reach the circle in time (its centre is now at least 8.8 m from the boss's
  centre, farther from a Blade's hitting distance). This step did not touch the eye's radius or the Blade's band (step 4's reading 3).

## After step 4c (2026-11-15)

- **Status:** RUN. **The expectation is still NOT MET** (ignoring costs the Gun 5 % more, the Blade 21 % more; the
  test asks 30 %). Nothing was retuned; the test's `pending` is unchanged.
- **What changed (owner rows R1-R7):** one big mechanic at a time (`BossTideBeats`: Pull, Riptide row or High Tide
  in each phase's order, 3 s of calm between, the stream, the waves and the other attacks held from a beat's due
  tick to 1.5 s after it); rings every 2.6 / 2.4 / 2.2 s, one wave every 5 s, none in phase 3; the push 4 m and
  the shots within 3 m of the set-down popped; Riptide warnings 2.5 / 3.0 s and never shorter than the walk to the
  safe strip (+30 %). No damage number, pull strength, Maelstrom number or bot changed. The bots' 24 m room has a
  sealed arena, so the R6 room fix does not reach them.
- **Build:** the tree of the commit that adds this section (`v0.12.0 Step 4c`; its parent is `37dee0c6`) on
  `v0120-t4c`, run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200
  (the owner's PC), debug native library built from this tree. Another agent ran Godot at the same time (no timing
  is read from it).
- **Who ran it:** agent

### Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_tide_bots.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. Exit 0: 2 tests, 1
passing, 1 pending, the bots' target below.)

### Raw output
```
TIDEBOT| weapon=gun bot=plays seed=5 dead=true ticks=4905 seconds=81.8 max_hp=100 hp_lost=738 biggest=50 rip=0 tide=0 eye=0 other=738 rows=1 strip_hits=0 strip_cost=0 tides=1 seconds_outside=0.0 tide_cost=0 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=5 dead=true ticks=4657 seconds=77.6 max_hp=100 hp_lost=737 biggest=50 rip=35 tide=36 eye=40 other=626 rows=1 strip_hits=1 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=1 eye_cost=40
TIDEBOT| weapon=gun bot=plays seed=6 dead=true ticks=4771 seconds=79.5 max_hp=100 hp_lost=678 biggest=50 rip=0 tide=0 eye=0 other=678 rows=1 strip_hits=0 strip_cost=0 tides=1 seconds_outside=0.1 tide_cost=0 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=6 dead=true ticks=4634 seconds=77.2 max_hp=100 hp_lost=779 biggest=50 rip=35 tide=36 eye=40 other=668 rows=1 strip_hits=1 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=1 eye_cost=40
TIDEBOT| weapon=gun bot=plays seed=7 dead=true ticks=4887 seconds=81.5 max_hp=100 hp_lost=810 biggest=50 rip=0 tide=0 eye=0 other=810 rows=1 strip_hits=0 strip_cost=0 tides=1 seconds_outside=0.0 tide_cost=0 throws=0 eye_cost=0
TIDEBOT| weapon=gun bot=ignores seed=7 dead=true ticks=4630 seconds=77.2 max_hp=100 hp_lost=827 biggest=50 rip=105 tide=36 eye=40 other=646 rows=1 strip_hits=3 strip_cost=35 tides=1 seconds_outside=6.0 tide_cost=36 throws=1 eye_cost=40
TIDEBOT| weapon=gun over 3 seeds: plays { "ticks": 14563, "hp_lost": 2226, "rip": 0, "tide": 0, "eye": 0, "other": 2226, "strip_hits": 0, "throws": 0 }, ignores { "ticks": 13921, "hp_lost": 2343, "rip": 175, "tide": 108, "eye": 120, "other": 1940, "strip_hits": 5, "throws": 3 }
TIDEBOT| weapon=blade bot=plays seed=5 dead=true ticks=4168 seconds=69.5 max_hp=100 hp_lost=421 biggest=38 rip=0 tide=0 eye=120 other=301 rows=1 strip_hits=0 strip_cost=0 tides=1 seconds_outside=0.0 tide_cost=0 throws=4 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=5 dead=true ticks=3745 seconds=62.4 max_hp=100 hp_lost=593 biggest=38 rip=52 tide=33 eye=270 other=238 rows=1 strip_hits=2 strip_cost=26 tides=1 seconds_outside=6.0 tide_cost=33 throws=9 eye_cost=30
TIDEBOT| weapon=blade bot=plays seed=6 dead=true ticks=4920 seconds=82.0 max_hp=100 hp_lost=524 biggest=38 rip=0 tide=0 eye=210 other=314 rows=2 strip_hits=0 strip_cost=0 tides=1 seconds_outside=0.0 tide_cost=0 throws=7 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=6 dead=true ticks=3466 seconds=57.8 max_hp=100 hp_lost=535 biggest=38 rip=52 tide=3 eye=240 other=240 rows=1 strip_hits=2 strip_cost=26 tides=1 seconds_outside=1.2 tide_cost=3 throws=8 eye_cost=30
TIDEBOT| weapon=blade bot=plays seed=7 dead=true ticks=4300 seconds=71.7 max_hp=100 hp_lost=509 biggest=38 rip=26 tide=0 eye=150 other=333 rows=1 strip_hits=1 strip_cost=26 tides=1 seconds_outside=0.0 tide_cost=0 throws=5 eye_cost=30
TIDEBOT| weapon=blade bot=ignores seed=7 dead=true ticks=3810 seconds=63.5 max_hp=100 hp_lost=634 biggest=38 rip=52 tide=27 eye=300 other=255 rows=1 strip_hits=2 strip_cost=26 tides=1 seconds_outside=5.3 tide_cost=27 throws=10 eye_cost=30
TIDEBOT| weapon=blade over 3 seeds: plays { "ticks": 13388, "hp_lost": 1454, "rip": 26, "tide": 0, "eye": 480, "other": 948, "strip_hits": 1, "throws": 16 }, ignores { "ticks": 11021, "hp_lost": 1762, "rip": 156, "tide": 63, "eye": 810, "other": 733, "strip_hits": 6, "throws": 27 }
    [Pending]:  NOT MET, ignoring the dance costs at least 30 % more HP: gun: ignoring cost 2343 HP in 13921 ticks, playing 2226 HP in 14563 ticks; blade: ignoring cost 1762 HP in 11021 ticks, playing 1454 HP in 13388 ticks
```

### Result

| | Gun plays | Gun ignores | Blade plays | Blade ignores |
|---|---|---|---|---|
| Fight length, 3 seeds (s) | 242.7 | 232.0 | 223.1 | 183.7 |
| HP lost, all | 2,226 | 2,343 | 1,454 | 1,762 |
| HP lost to the dance (rip + tide + eye) | 0 | 403 | 506 | 1,029 |
| Strip hits | 0 | 5 | 1 | 6 |
| Eye throws | 0 | 3 | 16 | 27 |

- **NOT MET, Gun:** 2,343 against 2,226 is 5 % more (after step 4b: 28 %). The dance now costs the Gun that plays
  nothing (0 against 403), but both fights are shorter and have one row and one High Tide each, so most of both
  totals is `other` (2,226 and 1,940), the attacks neither bot dodges.
- **NOT MET, Blade, but the sign turned:** the Blade that ignores now loses more than the one that plays (1,762
  against 1,454, 21 % more; after step 4b it lost less). Read from the numbers, not traced.

### The rhythm, one scripted 3-minute fight per phase

From `test_three_minutes_a_phase_one_at_a_time_and_nothing_else_meanwhile` in `tests/unit/sim/test_tide_beats.gd`
(TideLab's 24 m room, the full Tidecaller AI, the hero standing still and refilled, the boss held in its phase).
`running_s` is the seconds of that minute in which a big mechanic ran (a Pull from its bell to its push's end, a
row from its first warning to its last wave, a High Tide from its cast to its flood's end). Command:

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_tidecaller_streams.gd,res://tests/unit/sim/test_tide_beats.gd -gexit
```
(exit 0: 29 tests, 29 passing)

```
TIDEBEATS| phase=1 minute=1 running_s=13.5 pulls=3 rows=0 high_tides=0
TIDEBEATS| phase=1 minute=2 running_s=13.5 pulls=3 rows=0 high_tides=0
TIDEBEATS| phase=1 minute=3 running_s=13.5 pulls=3 rows=0 high_tides=0
TIDEBEATS| phase=2 minute=1 running_s=27.0 pulls=1 rows=2 high_tides=0
TIDEBEATS| phase=2 minute=2 running_s=23.6 pulls=2 rows=1 high_tides=0
TIDEBEATS| phase=2 minute=3 running_s=24.1 pulls=1 rows=2 high_tides=0
TIDEBEATS| phase=3 minute=1 running_s=24.8 pulls=0 rows=1 high_tides=2
TIDEBEATS| phase=3 minute=2 running_s=26.5 pulls=0 rows=1 high_tides=1
TIDEBEATS| phase=3 minute=3 running_s=25.8 pulls=0 rows=2 high_tides=1
```
