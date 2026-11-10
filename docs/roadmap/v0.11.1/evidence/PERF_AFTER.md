# PERF_AFTER: what did Wave 3 change, measured on a quiet machine?

- **Status:** RUN
- **Builds:** `bb24e09e` (Wave 3 without step 47), `df3b9039` (with step 47), `930485be` (with the shard fix), all on
  `claude/v0110`, clean worktree `wt-seams`; the thread trial `14c6c93f` on `v0111-s48` (worktree `wt-s48`). Godot
  `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200
- **Machine:** the owner's PC (i7-10700K, RTX 3060). No other Godot process ran (`tasklist` counted 0 before and
  after each batch). One exception: a single-core Python job of a few seconds (building image pairs for the owner)
  ran during the first batch, while `sim_bench` or `horde_phases` was running.
- **Date:** 2026-11-10
- **Who ran it:** agent (the lead)
- **Before:** [`PERF_BASELINE.md`](PERF_BASELINE.md) (`757a82cc`, the same machine and commands)

## Commands
The baseline's, unchanged:
```
godot --headless --path . -s scripts/bench/sim_bench.gd
godot --headless --path . -s scripts/checks/horde_phases.gd -- --counts=20,60,120 --ticks=1800
godot --headless --path . -s scripts/checks/attack_phases.gd -- --ticks=1800
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon --secs=20
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=60 --heavy --fx --secs=20
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=120 --only=swarmer --secs=20
```
and the two horde scenes again with `--breakdown --process`. The thread trial: the three probe scenes with
`--sim-thread=off` then `--sim-thread=on`, alternating, three rounds.

## Raw output
`sim_bench` at `bb24e09e` (`mean_ms`):
```
horde 4.137   reference 0.550   reference_boss 0.496   reference_floor 0.863   stress 3.312   stress_ai 2.166
horde_in_band false   stress_in_band false   stress_ai_in_band false
reference_in_band true   reference_floor_in_band true   reference_boss_in_band true
```
`horde_phases` at `bb24e09e`:
```
enemies=20   step mean 0.865 p99 1.661   ai 0.189   move 0.263
enemies=60   step mean 1.717 p99 2.878   ai 0.513   move 0.593
enemies=120  step mean 3.090 p99 5.034   ai 0.984   move 1.100
  outcome_hash 14f2fbce4fb2e51c13976d0e0b6f3b1424a72563957855b01c3c11a4f5abbcad  (the baseline's)
```
`attack_phases` at `bb24e09e` (the heavy build, headless):
```
dash_abilities mean 0.359 p99 2.167   step mean 2.194 p99 4.180
outcome_hash 1b6aa2970d1fdff851a8898bf3aa90487f06269ebc38fd8aa179a8ec0016c980
```
`frame_probe`, no breakdown. At `bb24e09e` (one run a scene):
```
20 enemies:           frames=1973 avg_ms=10.138 p50_ms=9.286  p95_ms=16.972 p99_ms=22.879 1pct_low_fps=32.5 max_ms=113.419 over_6.94ms=75.98 %  gpu 4.159 cpu 1.211
60 enemies, heavy:    frames=650  avg_ms=30.790 p50_ms=30.104 p95_ms=41.736 p99_ms=47.919 1pct_low_fps=17.7 max_ms=63.694                      gpu 10.273 cpu 2.229
120 swarmers:         frames=887  avg_ms=22.552 p50_ms=20.735 p95_ms=41.613 p99_ms=53.724 1pct_low_fps=16.8 max_ms=69.755                      gpu 6.164 cpu 1.381
```
At `df3b9039` (step 47 merged):
```
60 enemies, heavy:    frames=722  avg_ms=27.738 p99_ms=49.296 1pct_low_fps=18.8  gpu 9.122 cpu 2.032
60 enemies, heavy:    frames=710  avg_ms=28.176 p99_ms=49.335 1pct_low_fps=18.6  gpu 9.358 cpu 2.133
20 enemies:           frames=2115 avg_ms=9.460  p99_ms=22.271 1pct_low_fps=40.4  gpu 3.887 cpu 1.130
120 swarmers:         frames=866  avg_ms=23.096 p99_ms=54.863 1pct_low_fps=16.5  gpu 6.168 cpu 1.387
```
At `930485be` (the shard fix; two runs a scene): the final state.
```
20 enemies:           frames=1996 avg_ms=10.024 p50_ms=9.189  p95_ms=16.918 p99_ms=22.182 1pct_low_fps=36.1 max_ms=48.161 over_6.94ms=73.00 %  gpu 4.002 cpu 1.169
20 enemies:           frames=1928 avg_ms=10.375 p50_ms=9.710  p95_ms=16.616 p99_ms=20.008 1pct_low_fps=42.2 max_ms=40.128 over_6.94ms=80.13 %  gpu 4.199 cpu 1.214
60 enemies, heavy:    frames=741  avg_ms=27.001 p50_ms=26.162 p95_ms=36.304 p99_ms=44.240 1pct_low_fps=19.4 max_ms=63.778 over_6.94ms=100 %    gpu 9.914 cpu 2.075
60 enemies, heavy:    frames=706  avg_ms=28.344 p50_ms=27.704 p95_ms=37.761 p99_ms=45.069 1pct_low_fps=20.7 max_ms=57.048 over_6.94ms=100 %    gpu 9.579 cpu 2.127
120 swarmers:         frames=813  avg_ms=24.629 p50_ms=23.703 p95_ms=35.496 p99_ms=43.690 1pct_low_fps=21.6 max_ms=49.404 over_6.94ms=100 %    gpu 7.082 cpu 1.456
120 swarmers:         frames=873  avg_ms=22.926 p50_ms=22.043 p95_ms=35.228 p99_ms=41.846 1pct_low_fps=21.6 max_ms=53.044 over_6.94ms=100 %    gpu 6.501 cpu 1.416
```
`view.shards` with `--breakdown --process` (µs a frame: mean, p99):
```
                      baseline        bb24e09e (step 31's bake)   930485be (shapes shared)
120 swarmers          474 / 3052      3871 / 20991                590 / 4907
60 enemies, heavy     —               1262 / 11285                626 / 5428
```
The largest buckets at `930485be`, 120 swarmers (29.2 ms a frame with the breakdown on; µs: mean, p99):
```
frame.scene_process              18103     33234
engine.physics_process            8931     21963
frame.world_view_root.gd.sync     5971     19106
sim_step                          4925     15022
frame.draw_pre_to_post            4178      6848
view.actors                       2397     13053
script.attack_form_view.gd        1954      5076
phase.move 1456   phase.dash_abilities 1229   actors.update 1227   phase.ai 1157
vfx.status_visuals._draw_vfx 741   script.vat_crowd.gd 656   view.shards 590   script.horde_avatar.gd 410
```
The thread trial (`14c6c93f`), plain runs, off then on, alternating:
```
20 enemies    r1 off avg_ms=10.441 1pct_low=32.9 | on avg_ms=10.199 1pct_low=40.6
              r2 off avg_ms=9.164  1pct_low=42.9 | on avg_ms=8.874  1pct_low=39.0
              r3 off avg_ms=9.822  1pct_low=43.3 | on avg_ms=9.042  1pct_low=43.1
60 heavy fx   r1 off avg_ms=28.322 1pct_low=18.4 | on avg_ms=25.888 1pct_low=18.9
              r2 off avg_ms=26.704 1pct_low=18.5 | on avg_ms=24.465 1pct_low=19.8
              r3 off avg_ms=29.204 1pct_low=18.0 | on avg_ms=26.170 1pct_low=18.2
120 swarmers  r1 off avg_ms=25.884 1pct_low=16.4 | on avg_ms=21.963 1pct_low=16.9
              r2 off avg_ms=22.301 1pct_low=16.1 | on avg_ms=21.626 1pct_low=19.4
              r3 off avg_ms=27.496 1pct_low=15.7 | on avg_ms=21.016 1pct_low=17.8
```
and with `--breakdown`, 120 swarmers (µs a frame, mean): off `engine.physics_process 7847  sim_step 4307`; on
`engine.physics_process 5970  sim_step 4424  sim_join_wait 1582`. The full reports are in the two worktrees under
`build/perf_after/`, `build/perf_after47/`, `build/perf_final/` and `build/perf_thread/` (not tracked).

## Target bands
| Metric | Target | Source |
|---|---|---|
| Stress tick | mean ≤ 2 ms, p99 ≤ 4 ms | ARCHITECTURE §13 |
| Horde tick (120 enemies, 200 projectiles) | mean ≤ 4 ms | v0.4.0 PLAN "Performance" |
| Frame | every frame under 6.94 ms (144 fps), judged on the 1 % lows | v0.9.5 PF |

## Result
| Metric | Baseline (`757a82cc`) | After (`930485be`; the sim rows `bb24e09e`) | In band? |
|---|---|---|---|
| Horde tick (`sim_bench`) | 5.315 ms | 4.137 ms | No (by 0.14 ms) |
| Stress tick | 3.953 ms | 3.312 ms | No |
| Stress tick with real AI | 2.920 ms | 2.166 ms | No (by 0.17 ms) |
| Tick at 120 enemies (`horde_phases`) | 4.262 ms | 3.090 ms (−27 %) | — |
| Frame, 20 enemies | 14.8 ms (67 fps); 1 % low 27.8 fps; max 135 ms | 10.0–10.4 ms (96–100 fps); 1 % low 36–42 fps; max 40–48 ms | No (73–80 % of frames over 6.94 ms) |
| Frame, 60 enemies, heavy build | 36.7 ms (27 fps); 1 % low 10.6 fps; p99 75.8 ms | 27.0–28.3 ms (35–37 fps); 1 % low 19.4–20.7 fps; p99 44–45 ms | No |
| Frame, 120 swarmers | 29.6 ms (34 fps); 1 % low 10.1 fps; p99 77.8 ms | 22.9–24.6 ms (41–44 fps); 1 % low 21.6 fps; p99 42–44 ms | No |
| GPU, 60 enemies, heavy build | 10.8 ms | 9.6–9.9 ms (9.1–9.4 ms in the two runs at `df3b9039`) | — |

The outcome hashes of `horde_phases` and `attack_phases` equal the ones recorded before the changes: the sim's
results did not change.

## Interpretation
- **Frames are 20–31 % shorter on average, and the 1 % lows about doubled in the two horde scenes** (10 → 20 fps).
  The worst frames fell most: p99 76–78 ms → 42–45 ms. That is step 26 (spawns) and the tick's cuts.
- **Every target is still missed.** The horde tick is 0.14 ms over its 4 ms; the stress tick is 1.3 ms over its 2 ms.
  144 fps is far away: no horde frame is under 6.94 ms, and a quarter of the 20-enemy scene's are.
- **Step 31's shard bake was a regression, caught here:** it cut draws but built every drop's mesh in script
  (`view.shards` 0.47 → 3.87 ms a frame at 120 enemies). With the shapes shared it is 0.59 ms, close to the baseline;
  the average frame did not move with the fix (inside the run-to-run spread of about ±1.5 ms), the worst frames did
  (max 70 → 49–53 ms, 1 % low 16.8 → 21.6 fps).
- **Step 47 (lighter effect meshes) took about 1 ms off the GPU in the heavy scene** (10.3 → 9.1–9.9 ms) and nothing
  measurable off the average frame, which is bound by script. The triangle counts fell much more than the GPU time,
  so the effects' GPU cost is mostly not triangles (the lead's reading: overdraw of transparent layers).
- **The thread trial is a consistent but modest gain:** the average frame is 4 % shorter at 20 enemies, 9 % at 60
  with the heavy build, 15 % at 120 swarmers (25.2 → 21.5 ms), with the 1 % lows about the same. It is less than the
  tick's own cost because under 60 fps the catch-up ticks still run on the main thread, and the draw (4–5 ms) is no
  longer than the tick, so the main thread waits 1.6 ms a frame for the worker. It costs one rendered frame of delay.
- **Not explained:** the GPU time in the 120-swarmer scene rose (4.7 ms at the baseline, 6.2–7.1 ms now) while the
  frame got shorter. Run-to-run spread on the same build is about ±1.5 ms of average frame time in the horde scenes,
  so differences smaller than that between two rows mean nothing.
- **Where a horde frame goes now** (120 swarmers, proportions from the breakdown): the views' sync 6.0 ms (the
  per-enemy update 2.4 ms of it), the sim 4.9 ms a frame (one or two ticks), the draw 4.2 ms, the effects layer's
  drawers 2.0 ms, the rest spread thin.
