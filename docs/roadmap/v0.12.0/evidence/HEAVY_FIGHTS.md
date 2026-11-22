# What the slow frames of a heavy fight cost (owner, 2026-11-22)

The owner: "all of those are on average, but during heavy loads when the fps drop what takes the highest, maybe we can
targert the problem better like that, before doing these big rewrites"; then "Measure first yes".

## 1. The owner's log: where the slow frames are

Log `perf_20261122_122528.csv` (owner's play, before steps 48-50), read with the summarizer's loader
(`scripts/perf/summarize_perf.py` `load()`) by scratch scripts, not tracked. Play frames 58,731.

- Frames of 16.7 ms or more: Red Canyon 2.4 %, Night Rocks 17.7 %.
- Night Rocks 720-900 s with 25 or more enemies: 11,100 frames, 62 fps, 39 % of them at 16.7 ms or more, those at
  18.21 ms on average, with 42.8 enemies.
- The slowness is held, not spikes: frame by frame from 800 s, almost every frame is over 16.7 ms.

A slow frame there (ms, mean of 4,292 frames):

| Part | ms |
|---|---:|
| Process step | 9.55 |
| of it: the views' sync | 4.18 (`view.actors` 1.71: `actors.update` 1.14, `actors.enemy_sync` 0.44) |
| of it: HUD and main | 0.82 |
| of it: the untimed `_process` | 4.55 |
| After the process step, before the draw | 2.33 |
| Draw (main thread) | 2.80 (1.20 waiting) |
| Physics span | 3.26 (`sim_step` 2.11, `ticked_all` 0.73, of it the audio director 0.44) |
| GPU, for reference | 9.61 |

## 2. The same fight reproduced, and split by enemy kind

Machine: the owner's PC (i7-10700K, RTX 3060), no other Godot process before or after any run. Tree `383aaf48`
(`lead-v0120`, steps 48-50 in), worktree `wt-lead`. Vsync off, no fps cap (the frame probe's pacing).

```
COMMON="--biome=night_rocks --enemies=42 --secs=30 --warm=5 --size=2560x1440"
godot --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- $COMMON \
  --kinds=charger,needle,swarmer,warden,rock_lurker,stone_thrower,dim_needle --spans --redraws --proc-census   # r1
...  $COMMON --kinds=charger,needle,swarmer,warden,rock_lurker,stone_thrower,dim_needle --process --breakdown  # r2
...  $COMMON --kinds=charger,swarmer --spans                                                                   # r3
...  $COMMON --kinds=needle,warden,rock_lurker,stone_thrower,dim_needle --spans                                # r4
```

Every run exited 0, with 0 Godot processes before and after.

Raw lines:

```
r1 frames=1567  avg_ms=19.148  p50_ms=18.378  p95_ms=26.638  p99_ms=33.364
r1 render_cpu_ms_avg=1.394  render_gpu_ms_avg=10.801
r1 spans (us a frame, mean): probe_script=155  nodes_process=10416  after_process=1950  draw=3741  after_draw=375  physics_pre=35  nodes_physics=2231  physics_post=245  sum=19148
r1 actor view nodes (last frame): total=577 direct_children=52 batched_enemies=7
r1 script nodes processing: warden_avatar.gd 12/12, stone_thrower_avatar.gd 11/11, needle_avatar.gd 7/7, rock_lurker_avatar.gd 6/6
r3 frames=2133  avg_ms=14.067  p50_ms=13.666  p95_ms=20.194  p99_ms=25.166
r3 render_cpu_ms_avg=1.248  render_gpu_ms_avg=9.339
r3 spans (us a frame, mean): probe_script=125  nodes_process=6295  after_process=1593  draw=4144  after_draw=574  physics_pre=24  nodes_physics=1236  physics_post=75  sum=14067
r3 actor view nodes (last frame): total=69 direct_children=5 batched_enemies=42
r4 frames=1386  avg_ms=21.654  p50_ms=20.510  p95_ms=31.203  p99_ms=39.828
r4 render_cpu_ms_avg=1.500  render_gpu_ms_avg=12.449
r4 spans (us a frame, mean): probe_script=171  nodes_process=11676  after_process=2133  draw=4067  after_draw=390  physics_pre=47  nodes_physics=2818  physics_post=352  sum=21654
r4 actor view nodes (last frame): total=806 direct_children=60 batched_enemies=0
```

r2 (`--process`: every script node's `_process` called and timed by the probe, which costs itself, so the frame is
33.8 ms there; read the rows as proportions), µs a frame:

```
script.stone_thrower_avatar.gd       925
script.vat_crowd.gd                  782
script.attack_form_view.gd           714
script.warden_avatar.gd              629
script.needle_avatar.gd              622
script.rock_lurker_avatar.gd         313
script.player_avatar.gd              194
actors.update                       1459
actors.enemy_sync                    537
```

## 3. What it says

- The same 42 enemies cost 14.1 ms a frame as swarmers and chargers (the C++ batch) and 21.7 ms as the model kinds (a node tree and
  a script avatar each). The difference is 7.6 ms. Of it, 5.4 ms is the process step, 1.6 ms the physics span and 0.5 ms the engine's work
  after the process.
- Not all of it is the display. The model kinds throw, shoot and telegraph more, so their sim (the physics span) and
  their shots' views cost more, and a rewrite of the display keeps that.
- The display's share: the model avatars' own `_process` is about 2.5 ms in r2, and their sync (`actors.update`,
  `enemy_sync`) about 2.0 ms. The rough figure for moving them into the batch is 3-5 ms in a 40-enemy fight. It is not
  measured; it only comes from these rows.
- Per enemy in r2: Stone Thrower about 84 µs, Needle about 89 µs, Warden and Rock Lurker about 52 µs.
- The GPU comes next. At 10.8 ms in r1 and 12.4 ms in r4, a CPU cut past about 11 ms there shows as the GPU's limit
  with vsync off.
