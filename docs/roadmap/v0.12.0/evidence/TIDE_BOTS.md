# TIDE_BOTS: does ignoring the Tidecaller's dance cost clearly more than playing it?

- **Status:** RUN. **The expectation is NOT MET** (see "Result"): the numbers are below, nothing was retuned.
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
