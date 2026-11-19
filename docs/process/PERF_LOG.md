# Logging a normal game (perf log)

v0.10.5 (owner: "play a normal game, log it and then you can measure what takes the most frames"). The game records
every rendered frame to a CSV while you play; a script turns the CSV into a short report of what cost the frames.

## 1. Launch with the flag

Everything after `--` goes to the game. Two modes:

| Flag | What each frame records |
|---|---|
| `--perf-log=light` | the frame time, the sim ticks run that frame, the load (live enemies, hero and enemy projectiles, drawn effects, boss alive and its phase), the scene (menu, hub, loading, run, training, playground), the floor and biome, the main window's render time on the GPU and on the CPU; every 2 s the node count, draw calls, primitives, objects drawn, video memory |
| `--perf-log` | all of that, plus the frame probe's breakdown (the sim's step and its phases, each view's sync, every SimDriver listener, the rest of the script time), the main thread's frame in order (process, after it, the draw, between frames, physics), the engine's frame setup, the renderer's time **per render pass** on the GPU and the CPU, a census of what the scene holds every 2 s, and the display and Graphics options |

Light costs less; use the full mode to find out *what* is slow. With no flag nothing records and nothing is slower.

**The per-pass times need one more flag, `--gpu-profile`, given to the engine before the `--`** (the renderer writes
its pass timestamps only then). Without it everything else records and the summary says the passes are missing. The
engine also prints a short "GPU PROFILE" to the console every 2 s; that is normal.

**Git Bash** (from the project folder; `godot` is Godot 4.7.2):

```bash
godot --path . --gpu-profile -- --perf-log
godot --path . -- --perf-log=light
```

**PowerShell**:

```powershell
godot --path . --gpu-profile -- --perf-log
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . --gpu-profile -- --perf-log
```

An exported build takes the same flags: `"Zero Depth.exe" --gpu-profile -- --perf-log`. Godot's `--help` lists
`--gpu-profile` for release exports too, but the per-pass times have only been checked running the project with the
engine binary, not yet in an export: if an export's summary says the passes are missing, that is why.

While it records, the top-right corner shows **● PERF**. Press **F9** when something feels bad: the corner flashes
"mark N" and the frame is marked in the CSV. F9 does nothing when the game isn't recording.

Play normally (about 10 minutes is plenty), then quit from the menu or close the window.

## 2. Where the CSV lands

`%APPDATA%\Godot\app_userdata\Zero Depth\perf\perf_<date>_<time>.csv`, for example
`C:\Users\<you>\AppData\Roaming\Godot\app_userdata\Zero Depth\perf\perf_20261102_201500.csv`. The game also prints
the full path to the console when it starts recording. Each launch writes a new file.

The rows are written in the background every couple of seconds, when you return to the menu and when you quit, so
a crash loses at most the last two seconds. A 10-minute full log at 144 fps is about 86,000 rows.

## 3. Summarize it

```bash
python scripts/perf/summarize_perf.py "$APPDATA/Godot/app_userdata/Zero Depth/perf/perf_20261102_201500.csv"
```

```powershell
python scripts\perf\summarize_perf.py "$env:APPDATA\Godot\app_userdata\Zero Depth\perf\perf_20261102_201500.csv"
```

It writes `build/perf/<csv name>_summary.md` (about 250 lines) and prints its top lines. Read it top-down: the first
section, **What is biggest**, answers "what is taking the most" in a few lines:
- the frame (play frames, hitches over 1 s left out) and how often it was GPU-bound, CPU-bound or waiting in the draw;
- the GPU's time for the main window and the CPU's time recording it;
- the five costliest render passes on the GPU, with their share of the GPU's time;
- the main thread's parts (sim / views / listeners / other script / engine+draw), then the same frame in order: the
  process step (the views' once-a-frame sync with its listeners, and the rest of the nodes' `_process`), after it
  until the draw, the draw, between frames, the physics steps (the sim's ticks with their `ticked` listeners, and the
  engine's own part: the game uses no Godot physics, so that is the physics interpolation's tick);
- inside the draw: recording the viewports, the estimated wait, the frame setup;
- what the scene held on average (lights and shadows, particles, MultiMesh instances, transparent geometry,
  materials, shaders, texture memory).

Then:
- the totals per scene and floor (avg / p50 / p95 / p99 / max ms, fps);
- GPU against CPU per scene and floor (GPU ms, render CPU ms, the draw's wait, the bound shares);
- the GPU time per render pass: mean / p95 / p99 / share / CPU for the 15 costliest passes, the top passes per biome,
  and the passes that grow at the worst 1 % of frames;
- the 50 worst frames, each with its top 5 costs and its load;
- the stutter clusters (bursts over 33 ms and over 50 ms: when, how long, what dominated);
- the frame time (and the GPU's) against the enemy count and the projectile count, then against what the scene held:
  lights casting shadows, all lights, emitting particles, transparent geometry; the census's averages and the pack
  effects alive per family;
- the top costs over the run, split into sim / views / listeners / other script / engine+draw;
- the display and Graphics options in force, and every change to them;
- a ±2 s window round each F9 mark, with what dominated it, its GPU time and bound share and its top passes.

**GPU-bound or CPU-bound.** A frame is GPU-bound when the GPU's time for it is at least 85 % of the frame; otherwise
it is *waiting* when the draw spent at least 25 % of the frame not recording the viewports (vsync, a frame cap, the
present), else CPU-bound. A CPU-bound frame gets faster through the script and engine rows; a GPU-bound one through
the passes. With vsync on, quiet frames read as waiting: record with vsync off (Options) to see the real headroom.

`python scripts/perf/summarize_perf.py --self-check` tests the script on a generated 40,000-row CSV (a planted stutter
whose GPU time is mostly shadows, the GPU's numbers arriving late, censuses, an options change).

## 4. What the columns mean

Both modes:

| Column | Meaning |
|---|---|
| `frame_ms` | the time between two rows: one whole frame on the main thread |
| `gpu_us`, `rcpu_us` | the main window's render time on the GPU and on the CPU (`viewport_get_measured_render_time_gpu/cpu`). The engine reads them a frame or two late; the summary matches them to their frame |
| `rec_us` | the recorder's own main-thread time (its overhead) |

The full mode adds:

| Column | Meaning |
|---|---|
| `step_us` … `engine_us`, `bd` | the breakdown, as before: the sim's step and its phases, the views' sync, the listeners, other script, the rest (`engine_us`) |
| `draw_us` | the draw's wall time on the main thread (`frame_pre_draw` to `frame_post_draw`): recording the viewports, the wait for the GPU, vsync and the present |
| `setup_us` | the engine's frame setup on the CPU (`get_frame_setup_time_cpu`: updating the instances before the draw) |
| `proc_us`, `phys_us` | the engine's `TIME_PROCESS` and `TIME_PHYSICS_PROCESS` monitors. Godot keeps the **slowest step of each second** there, not the frame's own: a ceiling, not a per-frame cost |
| `proc_span_us`, `after_us`, `between_us`, `phys_span_us` | the frame in order on the main thread: the process step (from the recorder, which runs first, to the end of the last `_process`), after it until the draw (deferred calls, transforms, deletes), after the draw until the next physics step (OS events, input, a frame cap's sleep), the physics steps. With `draw_us` they add up to `frame_ms` |
| `gp` | the renderer's passes for one frame: `@lag;id:gpu_us:cpu_us;…`. `lag` is how many frames late the engine read them; sections under 1 µs on the GPU and 3 µs on the CPU are left out |
| `gp_new` | the names of the pass ids first seen in this row, `id=name` joined by `\|`. A pass inside the main window is `win/<name>`, one inside any other viewport (the HUD's still parts, a gallery) `sub/<name>` (summed over them), one outside every viewport its bare name |
| `sc` | the census, every 2 s, spread over a few frames (`census_us` its whole cost, `census_begin_us` and `census_slice_max_us` its largest single frames): visible lights by type `l_dir`, `l_omni`, `l_spot` and those casting shadows `sh_*`, the sun's `cascades` and `dir_dist`; `geo` visible geometry, `mesh`, `mm` MultiMesh nodes and `mm_n` their instances, `gpup` / `cpup` emitting particle systems and `gpup_n` / `cpup_n` their particles, `sprite3d`, `label3d`, `decals`, `fog_vol`, `geo_shadow` geometry casting shadows, `alpha` transparent geometry (an estimate: a transparency, an alpha-blended material, a shader that writes ALPHA, blends or reads the screen, a sprite without an alpha cut), `mats` and `shaders` in use; `tex_mb`, `buf_mb`, `vid_mb`, `static_mb`, `objects`, `resources`, `orphans`, `pipe_compiles`; `phys3d`, `phys2d`, `nav_maps`, `nav_us`; the views: `actor_nodes` (actors drawn as their own node), `actor_batched` (enemies drawn by the batch), `critters`, `pack` and `pack.<family>` (pack effects alive), `forms_meshes`, `forms_particles`, `vfx_used`. "Visible" is visible in the tree; the camera's culling is not known |
| `cfg` | the display and Graphics options, written in the first row and again when they change: the window, the 3D render size, scale and scaler, vsync, the frame cap, the refresh rate, MSAA / FXAA / TAA, anisotropy, the shadow atlases, the environment's SSAO / SSIL / SSR / glow / SDFGI / fog / volumetric fog / tonemap, the renderer, the adapter, whether the pass times are on (`gpu_passes`), and every Graphics option (`opt.*`) |

The passes Forward+ named on this project (the main window, Starfall's fight): Frame Begin, Prepare Render Frame,
Update GPUParticles, Cull 3D Scene, Cull DirectionalLight3D Split N, Render Light3D N with its Cull OmniLight3D Shadow
Paraboloid halves, Prepare and Setup 3D Scene, Render Depth Pre-Pass, Setup Shadows, Render Directional/SpotLight
Shadows, Prepare Depth for SSAO/SSIL, Process SSAO, Process SSIL, Pre Opaque Render, Bake 3D Cluster (Render and Pack
3D Cluster Elements), Update Volumetric Fog and Volumetric Fog (Render FogVolumes, Render Fog, Filter Fog, Integrate
Fog), Render Opaque Pass, Setup Sky, Render Sky, the compositor-effect hooks (Process Pre/Post Opaque, Post Sky,
Pre/Post Transparent Compositor Effects), Copy Screen Texture, Copy Depth Texture, Render 3D Transparent Pass, Resolve,
Copy Final Framebuffer (SSIL/SSR), Tonemap, Glow, then the 2D: Cull 2D Lights, Render Canvas N, Cull CanvasItem Tree,
Render CanvasItems. The ink outline has no pass of its own: it is a full-screen quad (`InkPass`) drawn in the 3D
Transparent Pass, and it reads the depth buffer, one of the reasons for Copy Depth Texture. A
pass the scene does not use (SSR, SDFGI) does not appear.

## Notes

- The breakdown's buckets nest: `view.*` and `actors.*` sit inside the views' sync, `phase.*` inside `sim_step`.
  The five-part split (sim / views / listeners / other script / engine+draw) does not overlap.
- In the Playground the full mode skips the per-listener timing (its biome switch reconnects the view's listeners);
  everything else is recorded.
- The recorder is app-side (`src/app/perf_recorder.gd`); the shared breakdown (`src/app/perf_breakdown.gd`) is the
  same code the frame probe's `--breakdown` uses. The pass reader is `src/app/perf_gpu_passes.gd`; the census and the
  options are `src/app/perf_scene_census.gd`.
- **The full mode's cost** is in `rec_us`: on Starfall's heavy fight at 2560 × 1440 on the owner's PC, a mean of
  about 0.8 ms and a p99 of 1.3 ms a frame
  ([`PERF_LOG_GPU.md`](../roadmap/v0.12.0/evidence/PERF_LOG_GPU.md)). The light mode adds two calls a frame.
- The frame probe takes the flags too: `godot --path . --gpu-profile … -s scripts/checks/frame_probe.gd -- …
  --perf-log` logs the probe's scene (scene `playground`) like a game.
