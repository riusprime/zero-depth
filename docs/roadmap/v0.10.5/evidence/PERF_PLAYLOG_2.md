# PERF_PLAYLOG_2: the owner's second logged run, after the perf fixes (2026-11-02)

The owner's PC (i7-10700K, RTX 3060), build `6ebbd16c` (the fixes in PROGRESS: the cracked wall, first-use warmup,
draw calls, the nav flood, the HUD split). Floors 1–2 (ruins, frozen_shore), 6 F9 marks. The CSV stays on the owner's
PC (`perf_20261102_182259.csv`, 113 MB, untracked). A different run from PERF_PLAYLOG_1 (other floors, builds and
fights), so compare by enemy count, not by floor.

```
python scripts/perf/summarize_perf.py "$APPDATA/Godot/app_userdata/Zero Depth/perf/perf_20261102_182259.csv"
→ build/perf/perf_20261102_182259_summary.md
97154 frames over 1237.8 s, full log, 6 F9 marks. The recorder's own main-thread time: mean 185 us, p99 346 us a frame.
| run f1 ruins         | 49194 | 12.61 | 11.46 | 20.26 | 25.69 | 74.91 | 79 |
| run f2 frozen_shore  | 30473 | 15.91 | 14.75 | 28.17 | 33.33 | 89.88 | 63 |
| all                  | 97154 | 12.74 | 11.12 | 23.60 | 30.47 | 1952.00 | 78 |
```

The lead's comparison (a scratch script over both CSVs; run frames, unpaused; frame avg ms, then mean us per frame):

```
run 1 (perf_20261102_160412)
 enemies 0:     avg  7.98 | engine  6501 draw 4064 views  884 sim  135
 enemies 1-10:  avg 10.30 | engine  7294 draw 3627 views 1667 sim  694
 enemies 11-20: avg 12.20 | engine  8040 draw 3681 views 2045 sim 1268
 enemies 21-40: avg 14.80 | engine  9044 draw 3851 views 2722 sim 1909
 enemies 41+:   avg 28.09 | engine 15084 draw 5630 views 5099 sim 5958
 draw_calls median 1103 p95 1894; nodes median 5988
run 2 (perf_20261102_182259)
 enemies 0:     avg  9.70 | engine  7394 draw 4229 views 1448 sim  251
 enemies 1-10:  avg 11.40 | engine  7887 draw 3427 views 1975 sim  778
 enemies 11-20: avg 12.40 | engine  8315 draw 3650 views 2077 sim 1058
 enemies 21-40: avg 16.01 | engine  9947 draw 3902 views 2990 sim 1838
 enemies 41+:   avg 21.04 | engine 11882 draw 4195 views 3931 sim 3632
 draw_calls median 981 p95 1574; nodes median 8303
```

Worst run frames: 89.9 ms (f2, 1161.2 s: view.actors 39.0, view.challenge 13.5; the boss room's boss appearing),
74.9 ms (f1: hud.rewards 15.4), 53.5 ms (f1: hud.shop 20.3). No frame near run 1's 1107.9 ms; no view.fireballs or
view.elite_fx spike in the 50 worst. Outside play: a 1952 ms hub frame at 55.5 s, loading frames up to 484 ms.

Owner-only: how it felt — OWNER ONLY.
