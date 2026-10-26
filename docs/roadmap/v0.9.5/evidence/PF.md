# PF1: the X-ray pass is gone, and the frame-time profiler exists

Step PF1 of v0.9.5 (the first half of PF). Base: `claude/v095-feedback` at `1a7307b7`. The owner-PC measurement and
the cuts it points to are PF2 and are NOT YET RUN.

## Part A: the X-ray silhouette pass removed

Owner (L21): "No enemy is drawn behind walls or floors". PLAN PF: the X-ray pass goes.

Removed outright (no dead paths left):
- `ActorViews.technique` defaults to `&"outline"` (rim only); `_ghost_material` and the per-body-piece "ghost" box
  (a second `MeshInstance3D` in `STENCIL_MODE_XRAY`) are deleted. `main.gd`'s gallery setup passes `&"outline"`.
- `EnemyLooks`: the `xray()` shader pass (`_XRAY` shader, `XRAY_ALPHA`, `XRAY_SHRINK`), `chain_xray()`, `xray_of()`
  and the `xray_pass` parameter of `body()`, `accent()` and `_outline_pass()` (their cache keys lose it too).
- `AvatarBase`: the `xray_twin()` helper, the `xray_pass` parameter of `shared_body()`, the `chain_xray` call in
  `_outlined()`.
- `EliteAvatar`, `HordeAvatar`: `_xray`, `XRAY_GROW`, and the code that built the pass. `ChargerAvatar`: the pass on
  its merged plates (and the now unused `team` / `technique` arguments of `_piece` and `_build_leg`).
- `BossAvatar` (the skinned `XrayTwin` node), `BossParts.piece` (the twin box), `LensDroneAvatar` (the twin per part).
- Kept on purpose: the stencil outline (the rim) and `AvatarBase.write_stencil` (faces / visors still mark the
  stencil like the body pieces do; harmless without the pass). The `technique` argument stays on the avatars'
  `setup()` (underscore-named where unused) so the many callers and tests did not need a signature change.
- Scripts: `scripts/checks/horde_draws.gd` and `scripts/shots/galleries.gd` pass `&"outline"` instead of `&"xray"`
  (the gallery's `occlusion_xray` row names are historical; they now draw the rim).

Tests changed (other coverage kept): the 5 boss view files, the horde, needle, player, warden, charger and
colour-blind palette tests used to assert that the X-ray pass existed; they now assert there is none (no `XrayTwin`
node, no `STENCIL_MODE_XRAY` material, same body pieces). 20 other test files only swapped the `&"xray"` argument.

Checks run (headless, this machine, `--language en`, `APPDATA=$TEMP/zd-pf1*`):
- gdformat + gdlint on every touched file: clean. `src/app/main.gd` still 1000 lines (the cap).
- `tests/unit/presentation` (whole folder, 161 scripts): 1090 / 1091 on the first run; the one failure (`test_boss_models`, an old "mesh and its X-ray twin = 2" assert) was fixed and that file re-run: 6 / 6. So 1091 / 1091 after the fix.
- `tests/arch`: 4 / 4 passed (2 scripts, 18203 asserts).
- e2e `test_e2e_run_flow`, `test_e2e_horde_enemies`, `test_e2e_playground`: 6 / 6 passed (3 scripts, 155 asserts).
- Not run: the seams, the full suite (GitHub runs it).

## Part B: the profiler `scripts/checks/frame_probe.gd`

Boots the real `main.tscn`, opens the Playground (seed 4404, the real room, views and sim) with the Gun, grants
Glaive + Ring + Split Shot + Ember Core (fire) + Storm Core (lightning) at level 3, keeps 20 live enemies round the
hero (7-12 m out, topped up each second; the hero cannot die), holds fire (right mouse), sweeps the aim round a
circle and strafes left / up / right / down in 2 s legs. 1920x1080 windowed, vsync off, no fps cap (restored on exit;
the profile is in-memory and `APPDATA` is a temp folder, so the owner's settings are never touched). Warm-up 3 s,
measured 30 s (defaults). Writes `build/perf/<sha>_<biome>[_ab-<flags>].txt` (git-ignored) and prints it; never writes
into `docs/`.

Per biome it reports: frames, average, p50, p95, p99, max (ms), the 1 % low fps (1000 / mean of the slowest 1 % of
frame times), the count over 6.94 ms, the RenderingServer CPU and GPU render time averages, and per second the draw
calls, objects, primitives, video memory, node count and particle-node counts (total / emitting).

Command lines (Git Bash, from the repo root; Godot must render, so no `--headless`):

```bash
G="/c/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
# both biomes (Frozen Shore, Red Canyon), the target run:
APPDATA=$TEMP/zd-frame "$G" --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd
# one biome:
APPDATA=$TEMP/zd-frame "$G" --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- --biome=frozen_shore
# A/B (one cost off at a time; repeat per flag, compare with the run above):
APPDATA=$TEMP/zd-frame "$G" --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- --biome=frozen_shore --ab=shadows_low
#   flags: shadows_low | no_ssil | fx_half | fx_low | planar_floor  (comma-separated to combine)
#   other options: --secs=30 --warm=3
```

`--ab` flags (only those that map to an existing knob):
- `shadows_low`: directional shadow atlas 2048 and soft-shadow filter quality 1 (project: 4096, quality 4).
- `no_ssil`: the stage's SSIL off.
- `fx_half`: the Options "Effects density" at Medium (the existing knob; there is no exact "half" setting). `fx_low`:
  Low.
- `planar_floor`: NOT AVAILABLE. The kit ground (`StageView._ground_material`) is world-triplanar for every biome
  (`uv1_triplanar` and `uv1_world_triplanar` true) and no planar path exists to switch to. The report prints the
  triplanar state.
- Not available either: any per-hit VFX thinning finer than the density setting, and status-effect particle caps
  (no knob exists).

### Smoke output: SMOKE ONLY, MACHINE BUSY, NOT EVIDENCE

Run on the owner's PC (RTX 3060) while another agent's Godot and my own test runs were using it, with shortened
runs (10 s measured, 2 s warm-up), at `1a7307b7` plus the uncommitted PF1 tree. These numbers prove the tool works
and say nothing about the game's frame time. (The `floor:` line in the first two blocks is from before I fixed the
triplanar detection: it printed 0 materials; the third block shows the fixed line.)

Command: `... -s scripts/checks/frame_probe.gd -- --secs=10 --warm=2`

```
frame_probe  sha=1a7307b7  biome=frozen_shore  ab=none
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 2.0 s, measured 10.0 s
flags: none
frames=735  avg_ms=13.615  p50_ms=14.464  p95_ms=19.101  p99_ms=28.739
1pct_low_fps=27.2 (1000 / mean of the slowest 8 frames)  max_ms=45.394  over_6.94ms=586 (79.73 %)  avg_fps=73.4
render_cpu_ms_avg=1.396  render_gpu_ms_avg=3.459  (RenderingServer viewport measured time)
  draw_calls 980-1283, objects 9518-10206, primitives 212121-337624, video mem 1861 MB, particle nodes 4 (1-2 emitting)

frame_probe  sha=1a7307b7  biome=red_canyon  ab=none
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 2.0 s, measured 10.0 s
flags: none
frames=651  avg_ms=15.387  p50_ms=15.027  p95_ms=28.616  p99_ms=37.958
1pct_low_fps=21.1 (1000 / mean of the slowest 7 frames)  max_ms=56.642  over_6.94ms=542 (83.26 %)  avg_fps=65.0
render_cpu_ms_avg=1.483  render_gpu_ms_avg=3.770
  draw_calls 976-1173, objects 9847-10361, primitives 344415-418927, video mem 1867 MB, particle nodes 4
```

Command: `... -- --biome=frozen_shore --secs=4 --warm=1 --ab=no_ssil,shadows_low,fx_half,planar_floor` (flags check)

```
frame_probe  sha=1a7307b7  biome=frozen_shore  ab=no_ssil,shadows_low,fx_half,planar_floor
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: no_ssil=on, shadows_low=on, fx_half=on, planar_floor=NOT AVAILABLE
frames=181  avg_ms=22.115  p50_ms=17.471  p95_ms=51.694  p99_ms=74.414
1pct_low_fps=12.4 (1000 / mean of the slowest 2 frames)  max_ms=86.923  over_6.94ms=178 (98.34 %)
render_cpu_ms_avg=1.714  render_gpu_ms_avg=4.096
```

The one reading worth passing on, still "smoke": the RenderingServer's own render CPU (about 1.4 ms) and GPU
(about 3.5 ms) times were far below the frame time, which suggests the frame is bound by the main thread (sim and
views) or by the busy machine, not the GPU. Only an idle-machine run can tell; that is the lead's.

## Owner-PC measurement: baseline (lead, 2026-10-26)

- Machine: the owner's PC (i7-10700K, RTX 3060, Windows 11), Godot 4.7.2 console build, 1920x1080 windowed, vsync off,
  no cap. Idle: no other Godot process (`tasklist` count 0 before the run), no agent running.
- Build: `b9ff8110` (claude/v095-feedback with RS1 and PF1 merged).
- Command: `APPDATA=$TEMP/zd-frame "$G" --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd`
- Raw report heads (the per-second samples are in `build/perf/`; draw calls 1060–1470, objects 9.6k→12.4k rising over
  the 30 s, nodes ~2.6–2.8k, particle nodes 4):

```
frame_probe  sha=b9ff8110  biome=frozen_shore  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know whether other processes were busy: name the machine and check the CPU was idle before quoting it as evidence)
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 3.0 s, measured 30.0 s
build: ITEM_GUN_GLAIVE, ITEM_GUN_RING, ITEM_SPLIT_SHOT, ITEM_EMBER_CORE, ITEM_STORM_CORE at level 3 (Glaive, Ring, Split, fire core, lightning core)
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: none
frames=2000  avg_ms=15.002  p50_ms=15.158  p95_ms=25.536  p99_ms=38.631
1pct_low_fps=18.6 (1000 / mean of the slowest 20 frames)  max_ms=135.738  over_6.94ms=1690 (84.50 %)  avg_fps=66.7
render_cpu_ms_avg=1.549  render_gpu_ms_avg=3.881  (RenderingServer viewport measured time)
```

```
frame_probe  sha=b9ff8110  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know whether other processes were busy: name the machine and check the CPU was idle before quoting it as evidence)
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 3.0 s, measured 30.0 s
build: ITEM_GUN_GLAIVE, ITEM_GUN_RING, ITEM_SPLIT_SHOT, ITEM_EMBER_CORE, ITEM_STORM_CORE at level 3 (Glaive, Ring, Split, fire core, lightning core)
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: none
frames=2062  avg_ms=14.551  p50_ms=15.177  p95_ms=21.246  p99_ms=38.817
1pct_low_fps=21.6 (1000 / mean of the slowest 21 frames)  max_ms=64.227  over_6.94ms=1707 (82.78 %)  avg_fps=68.7
render_cpu_ms_avg=1.583  render_gpu_ms_avg=3.791  (RenderingServer viewport measured time)
```

**Reading:** the target (every frame under 6.94 ms) is missed by far: about 67–69 fps average, 1 % lows 18.6–21.6 fps,
83–85 % of frames over 6.94 ms. The renderer's own times are small (CPU 1.5 ms, GPU 3.8–3.9 ms), so the frame is
bound by the main thread's script work (sim step and view sync), not by the GPU: shadows, SSIL and the floor are not
the first cut. The rising object count is worth a look. Next: PF2 profiles the main thread and cuts there.

## Owner-PC measurement after the cuts: NOT YET RUN

To be filled by the lead from a run on an idle machine: the exact command, the raw `build/perf/<sha>_<biome>.txt`
output and the build SHA ([`TEMPLATES.md`](../../../process/TEMPLATES.md) section 3), for Frozen Shore and Red
Canyon, then the A/B runs per flag. Target: every frame under 6.94 ms, judged on the 1 % lows.

## PF2: main-thread cuts

Step PF2 of v0.9.5. Base: `claude/v095-feedback` at `2427d296`. Machine: the owner's PC (RTX 3060) while other Godot
windows and test runs of other agents were using it, so every absolute number below is **machine possibly busy, not
evidence**. Only back-to-back ratios are quoted; the lead takes the owner-PC numbers. `fight_bench.gd` was NOT written:
the sim's phases are already measured in the renderer run through `World.phase_probe`, so the real scene needed no
second harness.

### The tool (`frame_probe.gd --breakdown`, `--process`)

`--breakdown` adds per frame (mean, p99, mean over the frames the bucket ran, frames it ran in; microseconds) the
buckets: `step_once` (the physics tick: input, `sim_step`, `ticked_all`), `sim_step` (`World.step`) with its phases
(`World.phase_probe`), `ticked_all` split per `SimDriver.ticked` listener (`tick.<script>.<method>`), `sync_all` and
`view.<name>` (each view's sync, via `WorldViewRoot.profile_sync`), `sync.occlusion`, and the frame's three engine
slices `frame.scene_process` (probe `_process` to `frame_pre_draw`), `frame.draw_pre_to_post`, `frame.rest_after_draw`.
`PerfMarks` (`src/presentation/perf_marks.gd`) is the static helper: one bool check when off. `--process` takes every
node's `_process` off the engine and times it from the probe, per script. `--ab=no_interp` turns physics interpolation
off. The per-second samples gained `resources` and `orphan_nodes`.

### Where a frame goes (Red Canyon, 15 s, one run, before any cut, busy machine)

```
frames=999 avg_ms=15.0 (66 fps)
step_once            6200 us/frame  (ran in 838 of 999 frames: ~60 Hz ticks in ~67 fps frames)
  sim_step           1596   (ai 319, move 296, proj 289 [sweep 234], nav_flood 269 [1054 on its 255 ticks], dash_abilities 153)
  ticked_all         4557
    view sync        3385   (actors 906, fireballs 207, attack_forms 154, status_fx 145, telegraphs 144, spikes 105, signatures 100, ~55 more views at 30-90 each)
    HUD (Playground) 1068   (build_hud 666 alone)
frame.scene_process  2907   (script _process of all nodes is under ~1000 of it; physics interpolation off: no change)
frame.draw_pre_to_post 3022
frame.rest_after_draw  2885
```

Reading: the 60 Hz tick (sim + view sync + HUD) is about 6.2 ms of a 15 ms frame; the engine's scene process, the draw and
the present are about 9 ms and are not script work I can cut (render CPU 1.5 ms, GPU 3.9 ms from the same run). The
view sync is a long tail: about 60 views at 30-200 us each, each looping every actor through `WorldReader` calls
(about 1 us a call in GDScript), even when its feature is idle (a boss view in a room with no boss). The 144 fps target
is NOT reachable by these cuts.

### Cuts

1. `src/presentation/hud/build_hud.gd` (+ `WorldReader.pips_key()`, `has_abilities()`): the build pips were rewritten
   every tick (`reader.build()`, `wand()`, `abilities()` allocate and parse every card; each pip write redraws a stone
   box; `_place()` re-lays the row). Now a cheap key (cards, levels, wand size, weapon form, abilities held, locale)
   gates all of it; the plate is re-placed only when the key or the anchor moved. `build_hud` 666 -> 24 us/tick; the
   Playground HUD tick (`_on_playground_tick`) 1068 -> 384 us (same session, two runs).
2. `src/presentation/world_view/fireball_views.gd`: `_draw` skips a look that has nothing in the air and drew nothing
   last time (3 MultiMesh writes per idle look per tick). `view.fireballs` about 245 -> 146-202 us.
3. `src/presentation/world_view/status_visuals.gd` (+ `WorldReader.any_status(i)`): one call replaces six per statusless
   enemy. `view.status_fx` about 200 -> 156-170 us.

Back-to-back A/B of cuts 2 and 3 (and 1) in alternating runs (before1/after1 ... before3/after3; after1 overlapped a
second probe window and is discarded): frame avg 17.6 / 17.9 / 16.8 ms before vs 15.1 / 13.6 ms after (after1 discarded).
Per-view numbers move with the machine load (`sim_step`, unchanged code, ranged 1.4-2.2 ms between runs), so read them as
direction only. Not done (checked, left): memoising `reader.telegraph(i)` (all 10 callers together cost about 220 us and
a memo could go stale inside a tick in tests), a per-kind actor index for the boss views, the hero avatar's 22-key state
dictionary (about 100 us), `ActorViews._update_actor`'s property writes. These are the next candidates.

### Object count (9.6k -> 12.4k)

Not a leak. In the 30 s samples `resources` stays 1175, `nodes` 2.5k-2.8k, `orphan_nodes` 0. A 100 s run: objects 9.6k
-> about 14k by ~50 s, then flat at 13.7-14.5k. The climb is `World._events`, the sim's bounded event log of `SimEvent`
RefCounted objects (`EVENT_LOG_CAP` 4096 + `EVENT_LOG_TRIM` 512), filling up in a fight. No per-hit material, mesh or
decal is created without being freed.

### Tests (headless, `--language en`)

- gdformat/gdlint on every touched file: clean.
- `tests/golden` 2 / 2, `tests/arch` 4 / 4 (18255 asserts), `tests/content` 158 / 158 (30 scripts).
- 18 scripts, 128 / 128 passing (27427 asserts): `test_modifier_equivalence`, `test_world_snapshot`, presentation
  `card_level_views`, `ember_stone`, `reward_cards`, `ui_polish`, `wand_views`, `status_visuals`, `enemy_fireball_views`,
  `vfx_layer`, `attack_visuals`, `boss_fight_views`; e2e `run_flow`, `playground`, `wand_build`, `swap`, `card_levels`,
  `enemy_fireballs`. Goldens and equivalence digests did not move (no sim state changed; the reader gained read-only
  functions).
- Not run: seed-loop tests, the seams, the full suite (GitHub).
