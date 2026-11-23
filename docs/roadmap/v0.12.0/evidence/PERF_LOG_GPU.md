# PERF_LOG_GPU: does the perf log say what takes the most, the graphics card included?

- **Status:** RUN (one probe run; the machine had other work open, so the times are indications, not targets)
- **Build:** the working tree of `v0.12.0 Step 35` on parent `80694620` (branch `v0120-s35`), the debug native
  library copied from the main checkout; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200
- **Machine:** the owner's PC (i7-10700K, RTX 3060). No other Godot process before or after the run
  (`tasklist | grep -ci godot`: 0 and 0); open meanwhile: 11 claude.exe, 4 python.exe, 2 blender-mcp.exe, 1 node.exe
- **Date:** 2026-11-19
- **Who ran it:** agent

## Command
```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-s35 "$GODOT" --path . --gpu-profile --position -10000,-10000 \
  --resolution 2560x1440 --windowed -s scripts/checks/frame_probe.gd -- --biome=starfall --enemies=60 --heavy \
  --secs=20 --warm=3 --size=2560x1440 --perf-log
python scripts/perf/summarize_perf.py "C:/Users/extri/Desktop/zerodepth/appdata-s35/Godot/app_userdata/Zero Depth/perf/perf_20261119_102600.csv"
```
(The probe passes `--perf-log` on to Main, which attaches the recorder from the boot, so the log holds the menu, the
Playground's load and the probe's scene. The window came out 2560 × 1421: the screen's title bar.)

## Raw output

The probe's own report (its measured 20 s):
```
build: Gun + ITEM_GUN_GLAIVE L3, ITEM_GUN_RING L3, ITEM_SPLIT_SHOT L3, ITEM_EMBER_CORE L3, ITEM_STORM_CORE L3, ITEM_GUN_TWIN L5, ITEM_HALO_SHOT L5, ITEM_GUN_RAPID_FIRE L5, ITEM_WILDFIRE L5, ITEM_CHAIN_BLAST L5, ITEM_GUN_RUNE_EXPLOSION L5  (at level 3 (Glaive, Ring, Split, fire core, lightning core) + the --heavy cards at level 5)
frames=660  avg_ms=30.313  p50_ms=29.082  p95_ms=42.015  p99_ms=56.279
1pct_low_fps=15.2 (1000 / mean of the slowest 7 frames)  max_ms=91.618  over_6.94ms=660 (100.00 %)  avg_fps=33.0
render_cpu_ms_avg=2.137  render_gpu_ms_avg=15.767  (RenderingServer viewport measured time)
```

The summary's top and its per-pass section (`build/perf/perf_20261119_102600_summary.md`, 238 lines):
```
# Perf log perf_20261119_102600

818 frames over 37.7 s, full log (perf_20261119_102600.csv), 0 F9 marks. Times in ms unless marked.

## What is biggest

- **Frame** (play frames): avg 28.81 ms (35 fps), p95 42.45, p99 60.20. GPU-bound 1%, CPU-bound 98%, waiting in the draw 1%. (1 hitches over 1000 ms left out of this section's means.)
- **GPU**: the main window's render takes 14.61 ms a frame on the GPU (p95 18.56), 2.02 ms of CPU recording it.
- **Costliest GPU passes**: Render 3D Transparent Pass 7.59 ms (51%), Render Opaque Pass 3.14 ms (21%), Process SSIL 0.92 ms (6%), Render Depth Pre-Pass 0.68 ms (5%), Glow 0.49 ms (3%).
- **Main thread**: engine+draw (unaccounted) 18.13 ms, views 6.56 ms, sim 2.92 ms, listeners 0.80 ms, other script 0.40 ms.
- **Main thread, in order**: the process step 13.86 ms (the timed sim, views and listeners 10.68, the rest of the nodes' _process 3.18), after it until the draw 2.91, the draw 6.59, then until the next step (events, input, a frame cap) 1.06, the physics steps 4.36.
- **Inside engine+draw**: the draw 6.59 ms a frame, of which recording the viewports 2.02 ms and waiting (GPU, vsync, present; est.) 3.16 ms; the frame setup 1.41 ms.
- **Scene** (mean): 18 lights (2 casting shadows), 1783 particles in 90 emitting systems, 2837 MultiMesh instances, 373 of 1022 visible geometry transparent (est.), 492 materials, 48 shaders; textures 1739 MB.

[… the totals and the GPU/CPU table trimmed …]
## GPU time per render pass

Play frames with their passes known: 812 (the engine reads a frame's stamps 1 frames late; matched here). `sub/` is any viewport but the main window (summed); `win/` is dropped.

| pass | gpu mean ms | p95 | p99 | share | cpu mean ms |
|---|---:|---:|---:|---:|---:|
| Render 3D Transparent Pass | 7.593 | 11.349 | 12.041 | 51% | 0.563 |
| Render Opaque Pass | 3.136 | 3.618 | 3.838 | 21% | 0.263 |
| Process SSIL | 0.923 | 1.154 | 1.188 | 6% | 0.044 |
| Render Depth Pre-Pass | 0.681 | 0.932 | 1.041 | 5% | 0.355 |
| Glow | 0.493 | 0.705 | 0.742 | 3% | 0.011 |
| Tonemap | 0.491 | 0.725 | 0.772 | 3% | 0.013 |
| Process SSAO | 0.331 | 0.494 | 0.621 | 2% | 0.026 |
| Copy Final Framebuffer (SSIL/SSR) | 0.268 | 0.509 | 0.564 | 2% | 0.014 |
| Update GPUParticles | 0.255 | 0.437 | 0.597 | 2% | 0.645 |
| Render CanvasItems | 0.148 | 0.383 | 0.433 | 1% | 0.114 |
| Render Directional/SpotLight Shadows | 0.123 | 0.281 | 0.410 | 1% | 0.095 |
| Copy Depth Texture | 0.100 | 0.256 | 0.351 | 1% | 0.005 |
| > Bake 3D Cluster | 0.060 | 0.059 | 0.067 | 0% | 0.002 |
| Render 3D Cluster Elements | 0.040 | 0.051 | 0.054 | 0% | 0.010 |
| Render Fog | 0.040 | 0.038 | 0.216 | 0% | 0.004 |

The costliest passes at the worst 1% of play frames (8 frames, from 62.1 ms; gpu mean ms there against the whole play):

- Render 3D Transparent Pass: 10.16 ms (overall 7.59, +2.57)
- Render Opaque Pass: 3.93 ms (overall 3.14, +0.79)
- Process SSIL: 1.00 ms (overall 0.92, +0.07)
- Update GPUParticles: 0.76 ms (overall 0.26, +0.51)
- Render Depth Pre-Pass: 0.75 ms (overall 0.68, +0.06)
- Glow: 0.48 ms (overall 0.49, -0.01)
- Tonemap: 0.41 ms (overall 0.49, -0.09)
- Process SSAO: 0.38 ms (overall 0.33, +0.05)
[… trimmed …]
The census on average: l_dir 2, sh_dir 1, l_omni 16, sh_omni 1, l_spot 0, sh_spot 0, cascades 1, tex_mb 1739, buf_mb 127, vid_mb 2131, static_mb 682, objects 23731, resources 4744, orphans 3555, phys3d 0, phys2d 0, nav_maps 0, nav_us 6, pipe_compiles 186, census_begin_us 96, mats 492, shaders 48, census_us 9670, census_slice_max_us 371, actor_nodes 41, actor_batched 8, critters 2, pack 76, forms_meshes 0, forms_particles 0, vfx_used 102, geo 1022, geo_shadow 181, mesh 675, alpha 373, mm 175, mm_n 2837, gpup 90, gpup_n 1783, fog_vol 1, dir_dist 78, decals 27, label3d 54, sprite3d 15.
Pack effects alive per family (mean): status 19.8, enemy_shot 15.4, area 14.1, hit 10.5, explosion 6.4, projectile 3.8, bolt 2.5, impact 1.9, beam 1.1, cloud 0.5.
```

## Result
| Question | Measured |
|---|---|
| GPU or CPU bound | CPU-bound 98 % of the play frames: the GPU's 14.6 ms of a 28.8 ms frame |
| The costliest GPU passes | Render 3D Transparent Pass 7.59 ms (51 %), Render Opaque Pass 3.14 ms (21 %), Process SSIL 0.92 ms, Render Depth Pre-Pass 0.68 ms, Glow 0.49 ms |
| The main thread in order | the process step 13.86 ms (the timed sim, views and listeners 10.68, the rest of the nodes' `_process` 3.18), after it until the draw 2.91, the draw 6.59 (recording 2.02, wait est. 3.16, setup 1.41), between frames 1.06, the physics steps 4.36 |
| The full mode's own cost | `rec_us` mean 779 µs, p99 1,330 µs a frame; the census 9.7 ms in all every 2 s, at most 371 µs in one frame |
| The per-pass times in a non-editor run | yes: running the project with the engine binary and `--gpu-profile` (no editor). Without the flag the renderer writes no pass stamps (a scratch scene: 0 timestamps). **In an export: NOT YET RUN** (Godot's `--help` lists `--gpu-profile` for release templates) |
| The log's size | 2.9 MB for 818 rows (about 3.6 KB a row in the full mode with passes) |

## Interpretation
The log now names what the frame spends: on this scene the main thread, not the graphics card, sets the frame rate
(the GPU needs about half of it), and of the GPU's half the transparent pass is the biggest single part, ahead of
the opaque pass. A busy machine and a scripted fight: proportions, not targets. The owner's own log (floors 1–3,
2560 × 1440, the real run) recorded with `--gpu-profile -- --perf-log` is the evidence that counts: **OWNER ONLY**.
