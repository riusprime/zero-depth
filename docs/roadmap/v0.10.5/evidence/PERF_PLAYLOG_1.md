# PERF_PLAYLOG_1: the owner's logged run (2026-11-02)

The owner played one long run with the recorder (`--perf-log`, full) on their PC (i7-10700K, RTX 3060), at build
`0a2e2756`: floors 1–4 (ruins, starfall, red_canyon, frozen_shore), bosses, the Purple Portal, several builds. The CSV
stays on the owner's PC (`%APPDATA%\Godot\app_userdata\Zero Depth\perf\perf_20261102_160412.csv`, 135 MB, untracked).

```
python scripts/perf/summarize_perf.py "$APPDATA/Godot/app_userdata/Zero Depth/perf/perf_20261102_160412.csv"
→ build/perf/perf_20261102_160412_summary.md
```

Raw lines from the summary (the lead's own extra cuts, from a scratch script over the same CSV, are marked *):

```
120543 frames over 1499.0 s, full log, 21 F9 marks. The recorder's own main-thread time: mean 171 us, p99 305 us a frame.
| run f1 ruins        | 35870 | 10.57 |  9.30 | 17.25 | 20.78 |   69.43 |  95 |
| run f2 starfall     | 21444 | 12.10 | 10.85 | 18.75 | 23.09 | 1107.88 |  83 |
| run f3 red_canyon   | 40391 | 14.34 | 13.05 | 26.20 | 35.56 |   72.77 |  70 |
| run f4 frozen_shore | 16613 | 13.57 | 12.69 | 22.17 | 28.62 |  118.36 |  74 |
| all                 |120543 | 12.44 | 10.83 | 21.71 | 30.92 | 4043.89 |  80 |
Enemies 0: 7.98 avg | 1-10: 10.30 | 11-20: 12.20 | 21-40: 14.68 | 41-60: 28.09 (p99 52.70)
Top costs: sim 1278 us/frame (10%), views 2050 (16%), listeners 815 (7%), engine+draw (unaccounted) 8272 (67%)
Buckets (max): sim_step 25.4 ms, view.actors 38.4, phase.nav_flood 17.7, tick.audio_director.gd.sync 28.6,
  sync.occlusion 28.2, frame.main.gd._on_frame (the HUD) 30.7
Worst frames: 4043.9 ms hub (start); 1107.9 ms run f2 (531.3 s, 22 enemies, engine+draw 1097.8); 814.2 ms hub (end);
  loading frames 98–317 ms; 118.4 ms f4 (view.elite_fx 56.2); 69.4 ms f1 (view.fireballs 53.1); 64.7 ms f2 (view.fireballs 47.3)
* run frames: engine_us mean 8235 (p95 12632), draw_us mean 3811 (p95 5729)
* draw calls (run frames, by quantile): 108 → frame ~10.5 ms; median 1103 → ~15.2 ms; p95 1894 → ~24.6 ms (objects ~9750);
  max 2444
* the HUD over 10 ms: single frames, every ~2–3 s at 1122–1146 s (f3, 27 enemies) and at 231–252 s (f1, 27 enemies);
  the HUD's mean is 0.4–0.5 ms
* boss frames vs not: f1 11.0 vs 10.5 ms, f2 12.5 vs 12.0, f3 13.7 vs 14.4 (bosses are not the cost)
```

Owner-only: how it felt — OWNER ONLY.
