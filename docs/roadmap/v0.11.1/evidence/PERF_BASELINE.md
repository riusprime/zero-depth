# PERF_BASELINE: where does a frame go, before Wave 3?

- **Status:** RUN
- **Build:** `757a82cc` on `claude/v0110` (clean worktree `wt-seams`); Godot `4.7.2.stable.official.ed1daf0bf`;
  Windows 11 Pro 10.0.26200
- **Machine:** the owner's PC (i7-10700K, RTX 3060). No other Godot process ran.
- **Date:** 2026-11-10
- **Who ran it:** agent (the lead)

## Commands
```
godot --headless --path . -s scripts/bench/sim_bench.gd
godot --headless --path . -s scripts/checks/horde_phases.gd -- --counts=20,60,120 --ticks=1800
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon --secs=20
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=60 --heavy --fx --secs=20
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=120 --only=swarmer --secs=20
```
and the three frame-probe scenes again with `--breakdown --process` (the breakdown's own timing adds about 5–7 ms
a frame, so read it for proportions, not totals).

## Raw output
`sim_bench` (ms per tick):
```
horde            mean 5.315 ms  p50 6.383  p99 9.176  max 19.35  actors 121  projectiles 198  walls 329  realtime x3.1  over4ms 2863
reference        mean 0.653 ms  p50 0.640  p99 0.909  max 2.60  actors 13  projectiles 42  walls 12  realtime x25.5  over4ms 0
reference_boss   mean 0.526 ms  p50 0.564  p99 1.113  max 3.20  actors 3  projectiles 30  walls 416  realtime x31.7  over4ms 0
reference_floor  mean 1.076 ms  p50 0.981  p99 2.697  max 6.25  actors 12  projectiles 3  walls 416  realtime x15.5  over4ms 2
stress           mean 3.953 ms  p50 3.918  p99 5.367  max 13.60  actors 61  projectiles 311  walls 40  realtime x4.2  over4ms 1542
stress_ai        mean 2.920 ms  p50 3.215  p99 5.842  max 21.57  actors 62  projectiles 38  walls 329  realtime x5.7  over4ms 745
horde_in_band False   stress_in_band False   stress_ai_in_band False
reference_in_band True   reference_floor_in_band True   reference_boss_in_band True
```
`horde_phases` (ms per tick, by phase):
```
enemies=20 ticks=1800 mean_alive=20.0
  step        mean   1.141  p99   2.179  max  12.794 ms
  nav_flood   mean   0.178  p99   0.794
  ai          mean   0.282  p99   0.485      ai.plan     mean   0.080
  move        mean   0.348  p99   0.517      move.steer 0.102  move.walls 0.115  move.pairs 0.072  move.grid 0.023
  actions     mean   0.049    resolve mean 0.068    proj mean 0.078
enemies=60 ticks=1800 mean_alive=60.0
  step        mean   2.349  p99   3.685  max  14.032 ms
  nav_flood   mean   0.202  p99   0.864
  ai          mean   0.759  p99   1.126      ai.plan     mean   0.225
  move        mean   0.789  p99   1.120      move.steer 0.285  move.walls 0.187  move.pairs 0.209  move.grid 0.068
  actions     mean   0.065    resolve mean 0.160    proj mean 0.185
enemies=120 ticks=1800 mean_alive=120.0
  step        mean   4.262  p99   6.508  max  15.494 ms
  nav_flood   mean   0.269  p99   0.970
  ai          mean   1.469  p99   2.147      ai.plan     mean   0.446
  move        mean   1.478  p99   2.084      move.steer 0.549  move.walls 0.351  move.pairs 0.438  move.grid 0.095
  actions     mean   0.082    resolve mean 0.300    proj mean 0.420
  outcome_hash 14f2fbce4fb2e51c13976d0e0b6f3b1424a72563957855b01c3c11a4f5abbcad
```
`frame_probe` (no breakdown; every frame timed):
```
20 enemies, standard build:  frames=1348  avg_ms=14.841  p50_ms=15.015  p95_ms=20.973  p99_ms=24.678
  1pct_low_fps=27.8  max_ms=135.067  over_6.94ms=1348 (100.00 %)  avg_fps=67.4
  render_cpu_ms_avg=1.566  render_gpu_ms_avg=4.830   draw_calls 700–1080, objects 18,379–20,783 a frame
60 enemies, heavy build:     frames=545   avg_ms=36.740  p50_ms=34.555  p95_ms=50.883  p99_ms=75.763
  1pct_low_fps=10.6  max_ms=151.948  over_6.94ms=545 (100.00 %)  avg_fps=27.2
  render_cpu_ms_avg=2.685  render_gpu_ms_avg=10.777  draw_calls 1,401–1,853, objects 20,743–25,721 a frame
120 swarmers (VAT on, 114 VAT bodies): frames=676  avg_ms=29.611  p50_ms=28.012  p95_ms=48.180  p99_ms=77.754
  1pct_low_fps=10.1  max_ms=109.931  over_6.94ms=676 (100.00 %)  avg_fps=33.8
  render_cpu_ms_avg=1.870  render_gpu_ms_avg=4.654
```
`frame_probe --breakdown --process`, the largest buckets (µs per frame: mean, p99):
```
120 swarmers (35.9 ms a frame with the breakdown on)
  frame.scene_process              20863     63873
  engine.physics_process            9461     20436
  sim_step                          7781     22462
  frame.world_view_root.gd.sync      6782     44247
  frame.draw_pre_to_post            5112      9405
  view.actors                       2760     39977
  phase.move                        2248      6312
  phase.ai                          2105      5996
  script.attack_form_view.gd        1993      4984
  phase.dash_abilities              1696      9473
  actors.update                     1161      2928
  vfx.status_visuals._draw_vfx       703      3056
  script.vat_crowd.gd                646      1651
  phase.resolve                      496      1331
  view.status_fx                     475      1549
  view.shards                        474      3052
  script.horde_avatar.gd             365       923
  phase.proj                         310      2446
  view.prism_views 79, view.ruins_rocks_fx 82, view.seekers 64, view.cores 62, view.pulses 61, view.voids 58 …
60 enemies, heavy build (41.3 ms a frame with the breakdown on)
  frame.scene_process              23815     41781
  sim_step                          7393     15546
  frame.world_view_root.gd.sync      7248     30618
  frame.draw_pre_to_post            7130     10971
  view.actors                       2767     25567
  script.attack_form_view.gd        2483      5048
  phase.move                        2119      4461
  phase.ai                          2051      3811
  phase.dash_abilities               976      4333
  vfx.status_visuals._draw_vfx       652      2297
  phase.resolve                      596      1613
20 enemies, standard build (21.9 ms a frame with the breakdown on)
  frame.scene_process              14624     23558
  frame.world_view_root.gd.sync      3939      7452
  frame.draw_pre_to_post            3930      6494
  sim_step                          2176      5684
  script.attack_form_view.gd        1158      3110
  view.actors                        984      2488
  phase.move                         445       949
  phase.ai                           439       935
  hud.kit 158, hud.minimap 89
```
The full reports are in the lead's worktree under `build/perf_base/` (not tracked).

## Target bands
| Metric | Target | Source |
|---|---|---|
| Stress tick | mean ≤ 2 ms, p99 ≤ 4 ms | ARCHITECTURE §13 |
| Horde tick (120 enemies, 200 projectiles) | mean ≤ 4 ms | v0.4.0 PLAN "Performance" |
| Frame | every frame under 6.94 ms (144 fps), judged on the 1 % lows | v0.9.5 PF |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Stress tick | mean 3.953 ms, p99 5.367 ms | No |
| Stress tick with real AI | mean 2.920 ms, p99 5.842 ms | No |
| Horde tick | mean 5.315 ms | No |
| Frame, 20 enemies | avg 14.8 ms, 1 % low 27.8 fps; 100 % of frames over 6.94 ms | No |
| Frame, 60 enemies, heavy build | avg 36.7 ms, 1 % low 10.6 fps | No |
| Frame, 120 swarmers | avg 29.6 ms, 1 % low 10.1 fps | No |

These match the project's earlier evidence on the same PC (60 enemies with VAT on: avg 28.96 ms on 2026-11-06,
`v0.10.5/evidence/VAT_ROLLOUT.md`), so this is the standing state, not a regression from v0.11.1.

## Interpretation
- **The frame is bound by script, not by the GPU.** With 120 swarmers the GPU takes 4.7 ms and the render CPU
  1.9 ms of a 29.6 ms frame. With 20 enemies the GPU takes 4.8 ms of 14.8 ms.
- **The sim tick is linear in the enemy count: about 35 µs an enemy a tick,** split evenly between `ai` (1.47 ms at
  120) and `move` (1.48 ms: steering 0.55, pairs 0.44, walls 0.35). Below 60 fps more than one tick runs a frame
  (7.8 ms of sim a frame in the 120 scene), so a slow tick compounds.
- **The 1 % lows are spawn hitches.** `view.actors` averages 2.8 ms but its p99 is 25–40 ms: the frames in which an
  enemy's view is built. That is what a 10 fps 1 % low is.
- **The hero's attacks cost more than the audit's hit and RNG items:** `phase.dash_abilities` is 1.0–1.7 ms a frame
  with a p99 of 4–9 ms; `resolve` (hits) is 0.3–0.6 ms.
- **One view script runs 1.2–2.5 ms every frame** in every scene: `attack_form_view.gd`'s `_process`.
- **About forty views sync every frame with nothing to show,** 60–130 µs each.
- **20,000 objects are drawn a frame** even with 20 enemies (the count is over every pass, shadows included), and
  the draw takes 3.9–7.1 ms of the main thread.
- **What the audit got wrong here:** it ranked moving every enemy onto the crowd renderer first (V1). The enemies'
  own `_process` is 0.37 ms for 120 of them (3 µs each, not 40 µs); the cost in `view.actors` is the per-frame
  update (1.2 ms) and the spawn. The HUD is under 0.3 ms a frame. Audio does not show up at all.
- **What this does not show:** which lines inside `ai`, `move`, `dash_abilities`, `attack_form_view` and the draw
  cost the time. Each Wave 3 step starts by splitting its own bucket.
- **The 144 fps target is far away in these scenes.** With the GPU at 4.8 ms and the draw at 3.9 ms, the scripts
  would have to fit in about 2 ms. A realistic aim for this version is to state after each step what the three
  scenes measure; whether 144 fps stays the target is the owner's call (OWNER_TODO).
