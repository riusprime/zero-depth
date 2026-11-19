# NIGHT_ROCKS_FREEZE: the 170–350 ms frames of the owner's Night Rocks fight

- **Status:** RUN (this PC, scripted); the owner's own fight after the fix: NOT YET RUN (owner hardware)
- **Build:** before `259980cd` (`lead-v0120`); after: Step 41's commit on `v0120-s41` (parent `259980cd`). The owner's
  build of the log, `80694620`, was also run (a detached worktree, no change). Godot `4.7.2.stable.official`,
  Windows 11 Pro 10.0.26200
- **Machine:** the owner's PC (i7-10700K, RTX 3060), driven by an agent, one Godot process of this agent at a time.
  Other sessions ran Godot meanwhile: during the timed before/after runs `tasklist` counted 2 Godot processes (this
  one and the other session's `seams.sh`), so the frame times carry that load; the before and after runs alternated
  under it. Pipeline compile counts do not depend on load.
- **Date:** 2026-11-19
- **Who ran it:** agent

## What the owner's log shows

`perf_20261119_110215.csv` (the owner's log, streamed; old recorder, no per-pass GPU times, no spans): floor 3,
Night Rocks, 1181–1216 s: 14 frames of 120–349 ms, nearly all "engine+draw (unaccounted)", the draw window itself
4–9 ms, no script bucket over 3 ms in the spike frames or the three frames before each. The rest of that window is a
spiral: frames of 40–90 ms with 4 sim ticks each. The engine's own GPU profile in the owner's `godot.log` (printed
once a second with `--gpu-profile`) stays at 6–15 ms over that window: no pass explodes.

Night Rocks is not slower by itself: the owner's calm and busy frames grow along the session in every biome
(calm frames, ms: Red Canyon 8.0, Ruins 10.2, Starfall 11.7, Night Rocks 13.8; the views 0.9 → 2.5 ms, the
unaccounted 3.3 → 5.6 ms). Night Rocks was the run's last and heaviest floor. The one-frame freezes, though, are
Night Rocks' only (other biomes: 2 frames over 120 ms in the same log).

The owner's later log, `perf_20261119_113014` (the new recorder), has the same kind of freeze on Starfall (572–574 s:
193, 141, 128, 248 ms): its spans put the time in "between" (after the draw, before the next physics step: 96–210
ms). The census's `pipe_compiles` did not move there, but that counter only sums the draw and background
(specialization) compiles and leaves out the main-thread ones (surface, mesh, canvas), so it could not show them. This
step adds those (`pipe_surface`, `pipe_mesh`, `pipe_canvas`).

## Reproduction

### The Playground probe (Night Rocks roster, 26 enemies, a Seekers build like the owner's)

```
"$GODOT" --path . --gpu-profile --resolution 2560x1440 --windowed --position -10000,-10000 \
  -s scripts/checks/frame_probe.gd -- --biome=night_rocks --enemies=26 \
  --kinds=charger,needle,swarmer,warden,rock_lurker,stone_thrower,dim_needle --hp=3000 --size=2560x1440 \
  --warm=0 --secs=40 --cards=gun_seekers:5,ember_core:5,split_shot,gun_ring,storm_core --perf-log
```
- `80694620` (the owner's build), first run after its import: `max_ms=943.075`; spike frames 946 ms and 785 ms at
  17.5 and 22.4 s, `engine_us` 927,925 and 766,298 with `draw_us` 1,928 and 4,234: the owner's signature.
- The same, second run (warm caches): `max_ms=84.654`. `259980cd` warm: `max_ms=70.391`.
- `259980cd` with `user://shader_cache` and `user://vulkan` deleted first: `max_ms=862.395` (34.69 s: 864.6 ms, its
  `between_us` 659,029, `draw_us` 77,953; the census's compile counter moved by one between 33.3 and 35.1 s); a
  second cold run: `max_ms=176.084`, its slowest frame the one that compiled one surface pipeline.

So the freeze is not code that changed since the owner's build: it is a pipeline compiled mid-fight, from tens of
milliseconds with warm caches up to about a second when the caches are stale (the owner's after an update: every
changed shader misses).

### What compiles mid-fight: the real floor 3

`scripts/checks/floor_fight_probe.gd` (new) plays the real Night Rocks floor 3 (seed 4404: the Overrun room 9, the
arena room 6, then the rooms by hops), the hero invulnerable and firing the Seekers build;
`scripts/checks/pipeline_watch.gd` (new, `--pipelines`) prints each frame whose compile counters moved, with what
was drawn or made for the first time in it and the two frames before.

```
"$GODOT" --path . --resolution 2560x1440 --windowed --position -10000,-10000 -s scripts/checks/floor_fight_probe.gd \
  -- --biome=night_rocks --floor=3 --secs=100 --cards=gun_seekers:5,ember_core:5,split_shot,gun_ring,storm_core \
  --pipelines
```
Before (`259980cd`), cold caches, the fight's surface (main-thread) compiles:
```
PIPES t=65.56 fight frame_ms=142.3 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 4] new: stage_kit MeshInstance3D ArrayMesh std:t1 s1 bb0 bl0 c2 tex10 vc0 | enemy_batch ...
PIPES t=70.02 fight frame_ms=41.0 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 2] new: ruins_rocks_views MeshInstance3D stone_thrower.glb::ArrayMesh_gf2fp std:t0 s1 bb0 bl0 c0 tex10 vc0
PIPES t=71.54 fight frame_ms=143.7 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 1] new: stage_kit MeshInstance3D ArrayMesh std:t1 s1 bb0 bl0 c0 tex10 vc0
PIPES t=78.85 fight frame_ms=72.2 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 1] new: heat_visuals MeshInstance3D SphereMesh std:t1 s1 bb0 bl0 c2 tex00 vc0
PIPES t=87.51 fight frame_ms=61.7 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 1] new: stage_kit MeshInstance3D ArrayMesh shader:Shader#-9223368026512909281
PIPES t=94.14 fight frame_ms=76.0 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 1] new:
PIPES t=109.30 fight frame_ms=77.3 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 1] new:
PIPES t=110.51 fight frame_ms=39.3 canvas/mesh/surface/draw/spec=[0, 0, 7, 0, 2] new: telegraph_views MeshInstance3D ImmediateMesh ...
PIPES t=124.51 fight frame_ms=70.1 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 1] new:
PIPES t=139.67 fight frame_ms=62.1 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 1] new:
PIPES t=154.86 fight frame_ms=50.7 canvas/mesh/surface/draw/spec=[0, 0, 1, 0, 1] new:
floor_fight_probe: pipelines compiled (canvas/mesh/surface/draw/spec) [2, 0, 337, 0, 166]
```
(frame times here include the watch's own walk of the tree; only the counts and what is named are the evidence.)
Per run, the fight's surface compiles: cold 11 and 17 (two runs), warm 16, 9, 11.

Three causes, each named in those lines:
1. **A wall fading.** When a wall stands between the camera and the hero its pieces swap to a faded copy of their
   material (StageKit, transparent). Nothing draws that copy until the first fade, mid-fight: one compile per kit
   material (the `stage_kit ... std:t1` lines, 142–161 ms frames cold). The warm-up left the models'
   StandardMaterial3D looks out, on the belief that the floor draws them already: the faded copies it never does.
2. **The heat effects, again and again.** Every vent, overheat and Overclock burst draws copies of HeatVisuals'
   templates and frees them. A StandardMaterial3D's shader is made on its first draw and freed with its last drawn
   copy; the templates themselves were never drawn, so each burst compiled the shader again (the lines every ~15 s
   with nothing new named: the hero overheats under held fire). Tested: with one hidden instance of each template
   kept, those lines went (run 6: none after the first).
3. **Night Rocks' own: the Stone Thrower's first rock.** Each thrown rock was given a new material; the first throw
   compiled its look (`ruins_rocks_views ... stone_thrower.glb`).

Not fixed here, still in the list: the first enemies batched (`enemy_batch`/`vat_crowd`, once, ~65 ms warm; the batch
and VAT files belong to the other session), the telegraph lines' ImmediateMesh variants (once, 7 surfaces), and the
Playground's own first spawns.

## The fix

- `ShaderWarmup` draws a view's `warm_looks()`: [mesh, material] pairs no node shows yet, one proxy each, behind the
  loading cover.
- `StageKit.warm_looks()`: every faded copy on a mesh its pieces draw (the procedural walls' faded material too).
- `HeatVisuals.warm_looks()`: its four templates on their meshes (one ring mesh for every blast now, not a new torus
  each). Drawn once, each template keeps its shader made, so no burst compiles it again.
- `RuinsRocksViews`: one material for every thrown rock, and its `warm_looks()` gives it with the rock's mesh.
- The perf census counts the main-thread compiles (`pipe_surface`, `pipe_mesh`, `pipe_canvas`), so the owner's next log
  can show a compile where this one could not.

## After: the same real floor, `--pipelines`, cold caches

```
floor_fight_probe: pipelines compiled (canvas/mesh/surface/draw/spec) [2, 0, 328, 0, 165]
```
The fight's surface compiles: **0** (before: 11 and 17 cold, 9–16 warm). Every remaining fight-time line is a
background (specialization) compile only, e.g.
`PIPES t=67.24 fight frame_ms=47.0 canvas/mesh/surface/draw/spec=[0, 0, 0, 0, 3] || made: enemy_batch ...`.

## Before and after, timed: the real floor 3, the perf log, cold caches, twice each, alternated

```
rm -rf "$APPDATA/Godot/app_userdata/Zero Depth/shader_cache" "$APPDATA/Godot/app_userdata/Zero Depth/vulkan"
"$GODOT" --path . --gpu-profile --resolution 2560x1440 --windowed --position -10000,-10000 \
  -s scripts/checks/floor_fight_probe.gd -- --biome=night_rocks --floor=3 --secs=100 \
  --cards=gun_seekers:5,ember_core:5,split_shot,gun_ring,storm_core --perf-log
```
The floor-3 run frames of each log (a streaming read of the CSV; `between`/`draw` in us):
```
before1 perf_20261119_140750
floor3 run frames=7531 avg=13.45 p99=35.5 max=142.3 over100=2 over50=11
 worst5: 142ms@51.2s(between 370, draw 114105, en 4) 133ms@45.2s(between 356, draw 103710, en 9) 77ms@65.5s(between 53755, draw 3891, en 3) 59ms@58.5s(between 342, draw 18720, en 9) 57ms@44.4s(between 2560, draw 9831, en 0)
after1 perf_20261119_141039
floor3 run frames=6884 avg=14.72 p99=36.6 max=60.2 over100=0 over50=6
 worst5: 60ms@44.4s(between 2907, draw 9212, en 0) 55ms@43.1s(between 70, draw 1003, en 0) 51ms@98.5s(between 21933, draw 5229, en 9) 51ms@72.8s(between 22642, draw 4687, en 9) 51ms@58.4s(between 21462, draw 5773, en 9)
before2 perf_20261119_141328
floor3 run frames=6213 avg=16.30 p99=40.5 max=135.4 over100=2 over50=16
 worst5: 135ms@50.8s(between 361, draw 90032, en 4) 126ms@44.9s(between 356, draw 96935, en 9) 81ms@58.2s(between 21962, draw 17520, en 9) 59ms@117.9s(between 21826, draw 7223, en 33) 56ms@72.6s(between 20968, draw 5974, en 5)
after2 perf_20261119_141616
floor3 run frames=7492 avg=13.52 p99=35.1 max=79.9 over100=0 over50=9
 worst5: 80ms@55.3s(between 54797, draw 3997, en 1) 62ms@44.4s(between 3561, draw 9886, en 0) 61ms@141.6s(between 47229, draw 3864, en 5) 55ms@43.2s(between 59, draw 993, en 0) 54ms@100.6s(between 21654, draw 5828, en 9)
```
- The two compile freezes of each before run (126–142 ms, at the fight's first fade and first bursts, ~45 and
  ~51 s) are gone in both after runs: worst 60 and 80 ms, no frame over 100 ms (before: 2 each).
- The averages and p99 move by the other session's load (13.5–16.3 ms either way): not a measurement of this change.
- The 50–80 ms frames left in both (a `between` of 20–55 ms, about once a second) are there before and after.

## Reading, and what is not known

- Reproduced: one-frame freezes of 130 ms to about a second, in the fight, from pipelines compiled mid-fight, on the
  owner's build and on the base, with the owner's signature (engine time outside the scripts, the draw window
  small). The worst ones need stale caches, which a player has after every update.
- Fixed and measured: the three sources named above; the real floor's fight compiles no surface pipeline any more.
- **Not proven:** that these are all of the owner's 14 freezes at 1181–1216 s. Their log cannot show compiles, and
  the cluster of 14 over 35 s is more than this floor's fight produced here (2 over 100 ms per cold run, up to 17
  compiles). The owner's next log on the new recorder names any that remain (`pipe_surface` rising between two
  censuses round a freeze). NOT YET RUN (owner hardware).
- The spiral (frames of 40–90 ms with 4 ticks for seconds) is the sim and the views falling behind at that load; the
  freezes start it. Not changed here.
- The 108 ms `shards.drops_drawn` frame of the owner's Starfall log (572.5 s) is another cause, not looked into here.
