# PERF_PLAYLOG_2: the owner's logged Blade run (2026-11-05)

The owner played one run with the Blade and the recorder (`--perf-log=light`) on their PC (i7-10700K, RTX 3060):
floors 1–5 (night_rocks, red_canyon, starfall, frozen_shore, ruins), the hub, and the training room (a stretch with
100–200 enemies at about 2480 s). The build is the owner's checkout of `claude/v0100-cleanup`; the CSV doesn't record
the SHA (the branch was at `7528ccd7` when the lead read it). The CSV stays on the owner's PC
(`%APPDATA%\Godot\app_userdata\Zero Depth\perf\perf_20261105_172113.csv`, 13.6 MB, untracked).

```
python scripts/perf/summarize_perf.py "$APPDATA/Godot/app_userdata/Zero Depth/perf/perf_20261105_172113.csv"
→ build/perf/perf_20261105_172113_summary.md
```

Raw lines from the summary (the lead's own cut, from a scratch script over the same CSV, is marked *):

```
211439 frames over 2562.8 s, light log, 0 F9 marks. The recorder's own main-thread time: mean 70 us, p99 117 us a frame.
| run f1 night_rocks   | 23438 | 11.87 | 11.18 | 16.67 | 19.92 | 183.89 | 84 |
| run f2 red_canyon    | 15491 | 10.94 | 10.29 | 16.27 | 18.46 |  64.15 | 91 |
| run f3 starfall      | 24509 | 15.42 | 15.86 | 22.31 | 26.37 |  70.00 | 65 |
| run f4 frozen_shore  | 23658 | 14.92 | 14.42 | 24.08 | 29.60 |  68.52 | 67 |
| run f5 ruins         | 65075 | 13.72 | 11.49 | 26.97 | 33.34 |  85.80 | 73 |
| hub                  |  8053 |  8.01 |  7.93 |  8.95 |  9.62 | 1711.74 | 125 |
| training             | 45333 |  8.24 |  6.96 | 15.50 | 34.79 | 1872.61 | 121 |
| all                  |211439 | 12.12 | 10.38 | 22.45 | 31.70 | 1872.61 | 83 |
Enemies 0: 9.48 avg | 1-10: 10.40 | 11-20: 13.79 | 21-40: 17.63 | 41-60: 18.88 (p99 40.98) | 61-100: 25.14 | 101+: 22.86 (p99 124.23)
Projectiles 201-400: 12 frames, 125.96 avg (training)
Worst frames: 1872.6 ms training (0 ticks, 1 enemy); 1711.7 ms hub (0 ticks); 1359.1 ms training; loading frames 120–582 ms;
  183.9 ms run f1 (24.3 s, 4 enemies); 120–159 ms training at 2484–2491 s (120–205 enemies, 87–216 enemy projectiles)
Stutter over 50 ms: 265 frames in 125 clusters; the longest 9.85 s in training (146 enemies, 111 proj);
  in runs, f5 ruins clusters at 41–65 enemies, worst 82.6 ms
* draw calls (run frames, sampled every 2 s, 1032 samples): p5 611, median 931, p95 1456, max 1854
```

## Against PERF_PLAYLOG_1 (2026-11-02, the Gun, full log, build `0a2e2756`)

| | PLAYLOG_1 | PLAYLOG_2 |
|---|---:|---:|
| all frames, fps | 80 | 83 |
| 41–60 enemies, avg ms | 28.09 (p99 52.70) | 18.88 (p99 40.98) |
| draw calls, run median / p95 / max | 1103 / 1894 / 2444 | 931 / 1456 / 1854 |

Not like for like: a different weapon (Blade vs Gun), other biomes per floor, and a light log (no cost breakdown, so
sim / views / engine+draw are not measured here). Timing on the owner's PC is real evidence.

## Open

- The training room at 100–200 enemies runs 120–160 ms a frame (a stress the real floors don't reach).
- Single scene-change frames of 1.4–1.9 s (hub, training) and 120–580 ms loading frames, as in PLAYLOG_1.
- A full log (`--perf-log`) is needed to say what costs the f5 ruins clusters and the training stretch.
