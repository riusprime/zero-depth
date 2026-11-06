# PERF_PLAYLOG_4: the owner's full-log run for the slowdown over a run (2026-11-06)

The owner: the game gets slower the further a run goes, in every run, whatever the biome order. They played five
floors (frozen_shore, ruins, red_canyon, starfall, night_rocks) and the start of loop 2's floor 1 (starfall) with the
full recorder (`--perf-log`) on their PC (i7-10700K, RTX 3060), 9 F9 marks. Build: the owner's checkout of
`claude/v0100-cleanup` (the CSV doesn't record the SHA). The CSV stays on the owner's PC
(`%APPDATA%\Godot\app_userdata\Zero Depth\perf\perf_20261106_102549.csv`, 198 MB, untracked).

```
python scripts/perf/summarize_perf.py "$APPDATA/Godot/app_userdata/Zero Depth/perf/perf_20261106_102549.csv"
→ build/perf/perf_20261106_102549_summary.md
113591 frames over 1779.1 s, full log, 9 F9 marks. The recorder's own main-thread time: mean 219 us, p99 388 us a frame.
| run f1 frozen_shore | 20471 | 13.74 | 12.61 | 24.31 | 30.92 | 147.30 | 73 |
| run f2 ruins        | 20129 | 12.27 |  9.20 | 23.47 | 29.75 |  67.51 | 82 |
| run f3 red_canyon   | 20224 | 16.98 | 15.55 | 33.57 | 43.68 |  83.98 | 59 |
| run f4 starfall     | 23532 | 17.86 | 16.46 | 31.54 | 42.54 |  75.39 | 56 |
| run f5 night_rocks  | 15093 | 24.32 | 21.06 | 50.95 | 64.91 |  94.17 | 41 |
| run f1 starfall     |  2812 |  8.58 |  8.41 |  9.62 | 10.40 | 103.67 | 117 |
| all                 |113591 | 15.66 | 13.47 | 33.18 | 49.60 | 4269.23 | 64 |
Top costs: sim 2248 us/frame (14%), views 2451 (16%), listeners 973 (6%), engine+draw (unaccounted) 9968 (64%)
```

## The lead's cuts (scratch scripts over the CSVs; run frames, unpaused)

**The same biome is slower on a later floor** (frames with 0–10 enemies, median ms; the 2026-11-05 run is PERF_PLAYLOG_3):

```
night_rocks   floor 1 (11-05) 10.6 ms, objects 5570  | floor 5 (11-06) 14.9 ms, objects 9653
red_canyon    floor 2 (11-05) 10.3 ms, objects 5175  | floor 3 (11-06) 17.0 ms, objects 7910
starfall      floor 3 (11-05) 13.7 ms, objects 8699  | floor 4 (11-06) 16.6 ms, objects 9244
frozen_shore  floor 4 (11-05) 12.3 ms, objects 6184  | floor 1 (11-06) 10.4 ms, objects 4074
```

**By floor, this run (0–10 enemies):**

```
f1 frozen_shore  10.4 ms | sim/tick 1300 us | engine 7677 us | objects 4074 | nodes 3859 | draws 688 | proj 11.0
f2 ruins         11.9 ms | sim/tick 1479 us | engine 8400 us | objects 6466 | nodes 3688 | draws 775 | proj 11.6
f3 red_canyon    17.0 ms | sim/tick 1787 us | engine 10565 us | objects 7910 | nodes 4169 | draws 830 | proj 21.6
f4 starfall      16.6 ms | sim/tick 1875 us | engine 11202 us | objects 9244 | nodes 4075 | draws 869 | proj 35.5
f5 night_rocks   14.9 ms | sim/tick 2034 us | engine 9629 us | objects 9653 | nodes 5057 | draws 946 | proj 29.6
loop 2 f1 starfall 8.4 ms | (start of the floor, no fighting yet)  | objects 2588 | nodes 3278
```

**Within each floor** the objects drawn climb from arrival to the end (median per quarter of the floor, all frames):
f1 2655 → 3755 → 5616 → 6125; f2 4168 → 4639 → 6450 → 6505; f3 6272 → 7752 → 8022 → 7955; f4 6424 → 9244 → 9250 →
9281; f5 6158 → 8216 → 8637 → 9830. The nodes stay at 3700–6700 throughout.

**Not the hero's projectiles:** with no hero projectile out and 0–10 enemies, floors 1–2 draw a median 2678 objects and
floors 3–5 9159.

## What it shows, and what it doesn't

- Not the biome order (the owner's point): the same biome costs more on a later floor.
- Not a growing node count: the scene's nodes stay flat, and loop 2's floor 1 starts back at 8.4 ms.
- Two things grow: (1) the **objects the renderer draws** (camera and shadow passes), within each floor and from floor
  to floor, with the engine+draw time (7.7 → 11.2 ms); (2) the **sim per tick** (1.3 → 2.0 ms), which follows the
  hero's projectiles (11 → 30–35 at 0–10 enemies: the build growing). A frame over 16.7 ms runs two ticks, so the two
  compound.
- **Not known yet: what the extra drawn objects are.** `scripts/checks/draw_census.gd` splits them by source, but only
  on a fresh floor 1; it would need to read a late floor after the hero has explored it. NOT YET RUN.

Owner-only: how it felt — OWNER ONLY.
