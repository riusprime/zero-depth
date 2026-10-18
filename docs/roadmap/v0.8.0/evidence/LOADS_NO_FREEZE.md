# N12: loads that never freeze the screen (v0.8.0 N12, owner O70)

- **Status:** RUN (agent; headless CPU side, and Xvfb + llvmpipe for the menu loads). How it feels, and frame times
  on the owner's PC: **OWNER ONLY**.
- **Build:** "before" = `1d0f989` (N10 and N11 merged; an untouched `git archive` copy with its own import and
  `scripts/checks/load_probe.gd` copied in), and for the phase split `aa7f710` (a scratch copy with timing lines added
  to `main.gd`, `world_view_root.gd`, `stage_view.gd`; never committed). "after" = branch `v080-n12` on `1d0f989`
  (merges of `85ed28d` and `1d0f989`), the working tree run before the Step N12 commit (its SHA is in PROGRESS's Done
  row; only these docs were written after the runs). Godot `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 (cloud
  container, 4 cores, no GPU), shared with other agents (the load average is printed at the end of each run).
- **Date:** 2026-10-17
- **Who ran it:** agent

Owner (O70, verbatim in [`../PLAN.md`](../PLAN.md)): "the loading screens still freeze the game. So the loading
screens meant to be something that stays over the, the game screen while it loads, so you have the loading feeling
and it doesn't freeze. For example, when you cross a portal, we have the animation and the game freezes completely.
Then you can uh, see where it catches up when you spawn. So it should be like a surely animation where things move
and then open it, but never stop moving or freezing. And the same should happen with the black screen that loads the
game at the beginning … for now we have to make it not freeze."

## What was wrong (measured first)
Every load (N3's cover) ran the whole floor build inside **one frame**: the cover was drawn, then one call built the
content, the World, the view and the HUD, so the mark and the iris stood still for that whole frame. Before
(`aa7f710` with timing lines, headless, ms, one run; `b_world` = the World, `d_view` = the whole view, `v_*` its parts,
`s_*` the stage's, `k_*` the kit's, `h_*` the crystal shards'):
```
load_probe: new_run   covered   30 frames, 16778.9 ms; longest frame 16665.0 ms; still mark frames 0; after-60 longest    5.2 ms; floor=1 hash=54d731d93431
load_probe: new_run   phases ms: a_compile=6.5 b_world=1751.5 c_app=4.8 d_view=14433.7 e_hud=24.5 k_dresser=27.1 k_stagekit=423.7 s_contact=2.3 s_edge=0.0 s_env_ground=23.9 s_ice=0.0 s_kit=939.6 s_walls=610.9 v_boss_models=8002.4 v_children=4673.0 v_stage=1576.7 v_sync=88.9
load_probe: gate      covered   95 frames,  2957.0 ms; longest frame 2633.5 ms; still mark frames 1; after-60 longest    4.5 ms; floor=2 hash=0068eac5ac11
load_probe: gate      phases ms: a_compile=341.4 b_world=1190.9 c_app=3.0 d_view=950.7 e_hud=23.9 k_dresser=35.1 k_stagekit=65.2 s_contact=1.8 s_edge=0.0 s_env_ground=31.6 s_ice=0.0 s_kit=814.0 s_walls=5.0 v_boss_models=0.1 v_children=62.1 v_stage=852.5 v_sync=12.5
load_probe: ascension phases ms: a_compile=347.9 b_world=20.5 c_app=1.6 d_view=3328.0 e_hud=18.6 v_boss_models=3238.9 v_children=31.8 v_stage=32.6 v_sync=9.5
```
A second run split `v_children` (`c8_props` = the boss door, shrine and shop stall: 1971-6929 ms cold, 1-3 ms warm)
and the shards (`h_shard_place` 214-419 ms, `h_shard_build` 69-108 ms). So, per load: the content read and compile
(~340 ms on a portal), the World (0.9-2.0 s), the boss, kit and shop models read cold on the first floor (5-9 s
bosses, 2-7 s shop stall, 0.5 s walls; ~0 later), the crystal placement (0.2-0.4 s), and since N10 the Ruins walls'
geometry (1.3-1.8 s, `view:dress` below). The frame after the cover opened was not long headless (`after-60` 3-13 ms):
headless has no renderer, so the "catch up" the owner saw (the first frames drawing new materials) shows only with a
renderer (llvmpipe below).

## What N12 does
- **The World on a worker thread** (`src/app/floor_plan.gd`, `FloorPlan.build`): the content read, the compile and
  the whole World build (new run, Continue, a portal's next floor) moved out of `Main._start_floor` into a plan that
  touches no node, writes no file and reads nothing a frame reads; `CoverLoads.on_worker` runs it on a
  `WorkerThreadPool` task and the frames go on. The dev panel's overrides are written into the content on the main
  thread first (`DevTuning.apply`). While the task runs the main thread runs no sim (the old floor is gone, the new one
  has no driver yet) and builds no World, so the sim's shared scratch (NavField's buffers, WorldSnapshot's field list)
  is used by one thread at a time. The tools, the tests and the dev panel's Restart floor still build it in one call
  (`start_stage`, `continue_run`, `_start_floor`), with the same `FloorPlan`.
- **The view in slices** (`src/presentation/world_view/view_build_queue.gd`, `ViewBuildQueue`): `WorldViewRoot.setup`
  and `StageView.build` became queues of jobs (`queue_setup`, `queue_build`; `setup()` / `build()` run them all at
  once, so every tool and test is unchanged). `CoverLoads.build_view` runs ~6 ms of jobs a frame. A job may add
  follow-ups right after itself (`add_next`): the kit's pieces 48 a job and each decoration kind
  (`StageKit.queue_build`), the procedural walls' meshes 8 walls a job (N10's option A), each room's crystals
  (`ShardCluster.begin` / `build_room`). Pure work runs as **worker jobs** (`add_worker`): the models
  (`ViewWarmup.warm`), the dresser and N10's ruin geometry together (`StageView._dress`: `StageDresser.dress` and
  `ProceduralWall.build`, both pure functions of their dictionaries and the cosmetic stream), and the crystal placement
  (`ShardDressing.place`). The view is added with `PROCESS_MODE_DISABLED` while it builds (nothing in it runs on a
  half-built floor) and goes live in its own frame with the HUD (`Main._floor_live`). N10's wall builder joined the
  queue without changing its rules (`stage_dresser.gd`, `procedural_wall.gd` untouched).
- **Warm-up** (`view_warmup.gd`): the boss, kit (with decoration detail and the chest's halves), shop-stall models,
  N10's wall textures and the effects layer's sheets and floor marks (`VfxCore.warm`, with the marks and the two sprite
  shaders now cached once per run of the game instead of rebuilt each floor) are read into their caches on a worker as
  the view's first job; the main thread only adopts what is cached.
- **The old floor freed in slices**: behind a cover, the old view is taken out of the tree and freed 4 ms a frame,
  deepest nodes first (`CoverLoads.free_slowly`; one `queue_free` of it cost ~100 ms in the portal's frame).
- Determinism: the World is the same object graph built by the same code on another thread, so it hashes the same
  (`tests/unit/app/test_floor_plan.gd`, and every load's hash in the probe equals the before tree's); the views are the
  same nodes in the same places (`tests/unit/presentation/test_view_build_queue.gd`). Input: the driver is added only
  when the floor goes live, F10 is ignored while a load runs, so nothing is read until the cover opens, as before; N11's
  `SimDriver.hold` (the arrival waits for the cover) is set on the new driver as before.

## Commands
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/load_probe.gd
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 640x360 -s scripts/checks/load_probe.gd -- --menu-only
```
The probe boots `main.tscn` and runs Main's own loads (a tool: it poses the hero and kills the boss by script, as
`scripts/shots/loading_cover.gd`): a new run from the build pick, the gate, Continue from the main menu, the Deep gate
(floor 3, Ruins in this seed's order: N10's walls on), the Ascension portal (to the final arena), Restart, the Loop
device. It times every frame while the cover shows ("covered"), the 60 frames after it opened ("after-60"), counts
the frames the cover's clock did not advance on ("still mark frames"), and first a 5 s control on the main menu with
no load ("idle"). Headless frames take microseconds, so a load spans 10^4-10^5 frames there.

## Raw output: headless, before (`1d0f989`)
```
load_probe: idle      menu 440537 frames, 5000 ms; longest frame    3.2 ms; frames over 50 ms 0
load_probe: new_run   covered   30 frames, 10676.0 ms; longest frame 10596.0 ms; still mark frames 0; after-60 longest    5.3 ms; floor=1 hash=be343c47a7e0
load_probe: gate      covered   95 frames,  2434.8 ms; longest frame 2174.5 ms; still mark frames 1; after-60 longest    7.6 ms; floor=2 hash=48b12e5e40a9
load_probe: continue  covered   30 frames,  1992.0 ms; longest frame 1948.7 ms; still mark frames 0; after-60 longest    8.7 ms; floor=2 hash=48b12e5e40a9
load_probe: deep      covered   95 frames,  3968.1 ms; longest frame 3703.1 ms; still mark frames 1; after-60 longest    5.9 ms; floor=3 hash=92161518eb63
load_probe: ascension covered   95 frames,  2918.8 ms; longest frame 2683.0 ms; still mark frames 0; after-60 longest    6.0 ms; floor=3 hash=2bf9e5547f33
load_probe: restart   covered   30 frames,  2555.8 ms; longest frame 2516.9 ms; still mark frames 0; after-60 longest    5.5 ms; floor=1 hash=be343c47a7e0
load_probe: loop      covered   95 frames,  2155.6 ms; longest frame 1894.9 ms; still mark frames 0; after-60 longest    6.1 ms; floor=1 hash=5fc49b6032ed
load_probe: done; load average 1.06 1.18 1.71 1/113 1228
```
(Each load's one long frame is frame 2 of the cover from a menu, frame 61 of a portal's iris.)

## Raw output: headless, after (`v080-n12` working tree)
```
load_probe: new_run   covered 390729 frames, 10910.0 ms; longest frame   60.5 ms; still mark frames 0; after-60 longest    3.2 ms; floor=1 hash=be343c47a7e0
load_probe: new_run   frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 84013:61cv
load_probe: gate      covered 53391 frames,  2584.1 ms; longest frame   48.6 ms; still mark frames 1; after-60 longest    5.4 ms; floor=2 hash=48b12e5e40a9
load_probe: continue  covered 59304 frames,  2225.5 ms; longest frame   45.0 ms; still mark frames 0; after-60 longest    5.2 ms; floor=2 hash=48b12e5e40a9
load_probe: deep      covered 96705 frames,  4399.5 ms; longest frame   37.1 ms; still mark frames 1; after-60 longest    7.0 ms; floor=3 hash=92161518eb63
load_probe: ascension covered 77709 frames,  3027.1 ms; longest frame   33.4 ms; still mark frames 0; after-60 longest    5.5 ms; floor=3 hash=2bf9e5547f33
load_probe: restart   covered 74332 frames,  2849.9 ms; longest frame   32.9 ms; still mark frames 0; after-60 longest    3.5 ms; floor=1 hash=be343c47a7e0
load_probe: loop      covered 44335 frames,  2259.2 ms; longest frame   42.1 ms; still mark frames 0; after-60 longest    6.9 ms; floor=1 hash=5fc49b6032ed
load_probe: done; load average 1.33 1.56 1.79 1/113 1888
```
Phases of that run (ms; `world` = the World on its worker, `view:<job>` summed per job name, worker jobs included,
`view_longest_job` / `view_longest_step` = the longest main-thread job / frame of view building):
```
load_probe: new_run   phases ms: total=10868.8 view=8485.5 view:devices=16.2 view:dress=24.3 view:edge=0.0 view:effects=13.8 view:first_sync=13.0 view:ground=23.2 view:ice=0.0 view:kit=25.0 view:kit_decor=2.0 view:kit_nodes=6.8 view:kit_shadows=0.0 view:models=7991.9 view:shards=72.8 view:shards_place=271.0 view:stage_light=0.2 view:views=4.1 view:walls=4.1 view_frames=306688.0 view_longest_job=23.2 view_longest_step=23.4 world=2304.7
load_probe: gate      phases ms: end_floor=10.9 total=2352.6 view=685.3 view:devices=14.2 view:dress=39.5 view:edge=0.0 view:effects=10.1 view:first_sync=14.6 view:ground=22.4 view:ice=0.0 view:kit=29.8 view:kit_decor=1.9 view:kit_nodes=8.2 view:kit_shadows=0.0 view:models=19.2 view:shards=99.1 view:shards_place=409.4 view:stage_light=0.2 view:views=3.6 view:walls=4.5 view_frames=12574.0 view_longest_job=45.6 view_longest_step=48.4 world=1602.2
load_probe: continue  phases ms: total=2180.2 view=684.3 view:devices=14.3 view:dress=25.1 view:edge=0.0 view:effects=10.4 view:first_sync=12.4 view:ground=23.3 view:ice=0.0 view:kit=27.2 view:kit_decor=1.8 view:kit_nodes=7.1 view:kit_shadows=0.0 view:models=20.9 view:shards=92.8 view:shards_place=435.0 view:stage_light=0.2 view:views=3.7 view:walls=4.1 view_frames=15230.0 view_longest_job=41.9 view_longest_step=44.8 world=1442.8
load_probe: deep      phases ms: end_floor=11.8 total=4131.8 view=1976.4 view:devices=10.0 view:dress=1461.4 view:edge=0.0 view:effects=10.0 view:first_sync=15.4 view:ground=26.3 view:ice=0.0 view:kit=12.8 view:kit_decor=2.1 view:kit_nodes=12.8 view:kit_proc_walls=39.7 view:kit_shadows=0.0 view:models=11.2 view:shards=64.6 view:shards_place=286.9 view:stage_light=0.2 view:views=4.5 view:walls=7.5 view_frames=44928.0 view_longest_job=26.3 view_longest_step=26.5 world=2085.2
load_probe: ascension phases ms: end_floor=8.8 total=2757.6 view=2284.6 view:devices=0.2 view:effects=10.5 view:final_arena=32.4 view:first_sync=12.3 view:models=2224.5 view:stage_light=0.3 view:views=2.0 view_frames=68257.0 view_longest_job=32.4 view_longest_step=32.8 world=411.9
load_probe: restart   phases ms: total=2798.2 view=494.3 view:devices=15.9 view:dress=24.2 view:edge=0.0 view:effects=10.0 view:first_sync=16.8 view:ground=24.2 view:ice=0.0 view:kit=26.2 view:kit_decor=1.9 view:kit_nodes=7.3 view:kit_shadows=0.0 view:models=12.0 view:shards=74.6 view:shards_place=266.4 view:stage_light=0.2 view:views=3.6 view:walls=3.9 view_frames=9093.0 view_longest_job=24.2 view_longest_step=24.4 world=2241.7
load_probe: loop      phases ms: end_floor=8.9 total=1993.0 view=519.4 view:devices=14.0 view:dress=25.2 view:edge=0.0 view:effects=10.0 view:first_sync=19.4 view:ground=29.5 view:ice=0.0 view:kit=32.0 view:kit_decor=3.7 view:kit_nodes=8.3 view:kit_shadows=0.0 view:models=16.4 view:shards=81.5 view:shards_place=262.5 view:stage_light=0.2 view:views=3.8 view:walls=4.5 view_frames=9075.0 view_longest_job=29.5 view_longest_step=29.7 world=1391.4
```

## The longest frame per load, headless
| Load | before (ms) | after (ms) | covered time before → after (ms) | frames over 50 ms after |
|---|---|---|---|---|
| New run (build pick, first floor, cold models) | 10,596.0 | **60.5** | 10,676 → 10,910 | 1 (61 ms, view building) |
| Gate portal | 2,174.5 | 48.6 | 2,435 → 2,584 | 0 |
| Continue | 1,948.7 | 45.0 | 1,992 → 2,226 | 0 |
| Deep gate (Ruins, N10 walls) | 3,703.1 | 37.1 | 3,968 → 4,400 | 0 |
| Ascension portal (final arena) | 2,683.0 | 33.4 | 2,919 → 3,027 | 0 |
| Restart | 2,516.9 | 32.9 | 2,556 → 2,850 | 0 |
| Loop device | 1,894.9 | 42.1 | 2,156 → 2,259 | 0 |

**Target (no frame over ~50 ms headless): met on six of seven loads; missed on the run's first load, one frame of
60.5 ms** (reported, not retuned; the run before the last change, the view hidden while it builds: 61.7 ms). Earlier runs of the same tree on a busier machine (load average 5-7, other agents'
Godot runs) had more: the cold first load 2-13 frames of 52-320 ms, and some warm loads one frame of 51-280 ms, most
of them while a worker job ran (`w`/`v` tags); the 5 s idle control on the main menu had none in any run, so the main
thread was held while a worker loaded (CPU contention on 4 shared cores, or a lock the worker's resource loads take;
not found). The longest main-thread job is now 23-46 ms (the kit's pieces, the final arena's stage, the dresser's frame). The
total time behind the cover is about the same (the work is the same, now off the main thread or spread out): 0.1-0.4 s
longer per load.
"still mark frames 1" on the gate and Deep gate (before too): the frame the iris starts, before the cover's clock first
ticks. Headless `after-60` stays 3-9 ms; the first frames drawn are in the llvmpipe runs.

## Xvfb + llvmpipe (CPU rendering), the menu loads
A frame of play there takes ~1 s at 640x360 (llvmpipe draws the whole 3D frame on the CPU), so only the new run,
Continue and Restart were run (`--menu-only`); a first try of the full run (after tree) timed out waiting for the gate
load ("gate never opened" after 180 s of ~1 s frames) and is not used.
Before (`1d0f989`):
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 640x360 -s scripts/checks/load_probe.gd -- --menu-only
load_probe: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
load_probe: new_run   covered   30 frames, 36756.7 ms; longest frame 19815.7 ms; still mark frames 0; after-60 longest  735.9 ms; floor=1 hash=be343c47a7e0
load_probe: continue  covered   30 frames, 24285.3 ms; longest frame 7571.0 ms; still mark frames 0; after-60 longest  700.5 ms; floor=1 hash=be343c47a7e0
load_probe: restart   covered   30 frames, 23218.6 ms; longest frame 5154.0 ms; still mark frames 0; after-60 longest  749.9 ms; floor=1 hash=be343c47a7e0
load_probe: done (menu loads only)
```
After:
```
load_probe: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
load_probe: new_run   covered 3524 frames, 44543.8 ms; longest frame 2185.2 ms; still mark frames 0; after-60 longest  729.8 ms; floor=1 hash=be343c47a7e0
load_probe: continue  covered  826 frames, 28013.5 ms; longest frame 1769.1 ms; still mark frames 0; after-60 longest 1450.9 ms; floor=1 hash=be343c47a7e0
load_probe: restart   covered  549 frames, 27999.4 ms; longest frame 1739.4 ms; still mark frames 0; after-60 longest  735.6 ms; floor=1 hash=be343c47a7e0
load_probe: done (menu loads only)
```
| Load (llvmpipe, 640x360) | longest frame before (ms) | after (ms) | the longest after, where | longest frame while the floor builds, after (ms) |
|---|---|---|---|---|
| New run | 19,815.7 | 2,185.2 | the floor's first drawn frame, still covered | 618 |
| Continue | 7,571.0 | 1,769.1 | the same | 377 |
| Restart | 5,154.0 | 1,739.4 | the same | 624 |

(From the probe's "frames over 50 ms" lines of the same runs, not pasted whole: ~100 indices each.) On llvmpipe every
frame of play takes ~600 ms (the idle menu: 26-32 ms), and the frames while the floor builds 70-620 ms (the post
effects over the cover; the view is hidden while it builds, an earlier run with it shown had 600-1,800 ms frames). The
one long frame left is the first frame that draws the new floor (1.7-2.2 s, under the cover before it opens): the
first draw of the floor's materials (shader and pipeline compilation, CPU-bound on llvmpipe). A GPU compiles them far
faster, but they are not warmed: D51.

## Tests (the commands and their totals)
```
gdformat --check src scripts tests && gdlint src scripts tests
-> 1023 files would be left unchanged / Success: no problems found
bash scripts/ci/gut_shard.sh --check
-> gut_shard: ok (367 test files in 6 shards)
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/application,res://tests/unit/app,res://tests/unit/debug,res://tests/unit/presentation -ginclude_subdirs -gexit
-> Scripts 160, Tests 1031, Passing 1031, Asserts 1998628, Time 721.825s   (before the last change: main.gd hides the view while it builds)
godot ... -gtest=<10 e2e: loading_cover, run_flow, saves, old_save, ascension, routes, portal, pad_aim, builds, arrival> -gexit
-> Scripts 10, Tests 22, Passing 22, Asserts 629, Time 244.783s   (before the last change)
godot ... -gtest=<13 e2e: the 10 above + kit, lighting, floor> -gexit   (after the last change)
-> Scripts 13, Tests 27, Passing 27, Asserts 725, Time 262.863s   (test_e2e_loading_cover: "new run: 333381 frames, 10822 ms", "gate: 41191 frames, 2124 ms")
godot ... -gtest=<15 e2e that cross loads: pad_menus, after_boss, final_boss, wand_build, nemesis, difficulty, hints, shell, dev_master_panel, damage_soak, codex, health_bars, attack_order, floor, kit> -gexit   (before the last change)
-> Scripts 15, Tests 30, Passing 27, Failing 3: test_e2e_pad_menus test_pad_a_resumes_from_pause ("the sim runs again"),
   test_e2e_wand_build test_the_swap_at_eight_slots_fits_the_screen_and_inserts_with_the_pad ("a ninth card: the Swap
   panel" …), test_e2e_dev_master_panel test_f10_edit_restart_floor ("typed into the content": 40, expected 97).
   The same 15 files on the before tree (`1d0f989`): Tests 30, Passing 27, Failing 3, the same three tests with the
   same messages: not caused by N12 (the first two fail on both trees in a 3-file run of pad_menus, wand_build and
   dev_master_panel too; the third passes in that run and alone, and fails only after the other files, on both). Not fixed here.
```
New tests: `tests/unit/app/test_floor_plan.gd` (a new run for three seeds and both builds, floor 2 and the last floor:
the World built on a WorkerThreadPool task hashes as the main-thread build, built and after 120 ticks),
`tests/unit/presentation/test_view_build_queue.gd` (order, follow-ups, a worker job off the main thread, the budget
spreading jobs over frames, and a Ruins and a Night Rocks floor's view built in slices equal to the one-call view:
every node, name, class and transform), `test_e2e_loading_cover` (a new run's load and a portal's load each span more
than 3 drawn frames and the cover's clock advanced on every one). The e2e helper's `frames()` waits through a load
(wall clock, at most 120 s), so a test's frame counts stay frames of play; `E2e.loaded()`; saves and old_save await
`CoverLoads.finished` to read the resumed world before its first tick.
Not run: the full suite, the seams script, the bot tests (owner rule), `tests/unit/sim`.

## Interpretation
- O70 is built for every load: the cover and its mark (and a portal's iris) are drawn moving on every frame while the
  floor builds; the World is built on a worker thread, the view a few milliseconds a frame, the models read ahead on a
  worker. The floor is the same floor (hashes, nodes).
- Not met: one 62 ms frame on the first load headless (target ~50 ms), and on llvmpipe the first frames that draw the
  new floor's materials (shader compilation) still hold the cover (numbers above). A shader warm-up (drawing each
  material once behind the first black cover) was not built: D51 asks whether it's needed on your PC.
- Not proved: the feel, and the frame times on the owner's PC (OWNER ONLY).

## v0.8.0 LD: the floor's first frame (at `96bb48a`, branch `v080-ld` from `5ff24af`)

**The cause** (measured in MI's follow-up, MODELS_INSTALL §5, "cause 3"). When the World's build ended,
`Main._floor_nodes` made the floor's nodes in a single frame. `WorldViewRoot.new()` creates the view's 36 parts in
that frame: about 16 ms on a quiet process, 23-55 ms per load in the probe, and 149 ms once while starved. On the
first floor of a session, the Codex and achievement trackers are made in the same frame, which reached 60-95 ms
(`cpu=95.8 runq=0.1 … step1=0.0[]`).

**The fix.**
- `WorldViewRoot.parts` lists those parts. `WorldViewRoot.prebuild(budget_ms)` makes the ones not yet made, with
  at least one per call.
- `CoverLoads.prebuild_view()` calls it once a frame with `VIEW_BUDGET_MS` (6 ms) behind the cover. `Main._load_plan`
  runs it just before `_floor_nodes`.
- The view's initialisers take the parts made ahead (`_part()`). Without any made ahead, as with `setup()`,
  `_open_floor_now` and the tests, each part is made new, as before.
- `drop_prebuilt()` frees parts that no view took.
- Neither the parts nor the order the view builds them in changes. New test
  `test_a_view_made_from_parts_made_ahead_is_the_same_view` (`tests/unit/presentation/test_view_build_queue.gd`):
  every part made ahead is taken, and the view has the same nodes, names and places as one made in one call.
- No sim change.
- The load probe's frame hooks are now off by default (`ViewBuildQueue.probe`, `CoverLoads.probe`).
  `scripts/checks/load_probe.gd` turns them on.

**Measured.**
- A standalone timing script (scratch, not committed), four rounds:
  - `WorldViewRoot.new()` alone: 51.4 / 23.6 / 15.5 / 15.0 ms;
  - `prebuild(6.0)` slices: up to 9.4 ms (one part runs over the budget alone);
  - `WorldViewRoot.new()` after prebuild: 0.1 ms.
- In a probe run with a temporary print around `_floor_nodes` (not committed), the seven loads took
  8.1 / 2.6 / 0.3 / 2.9 / 4.4 / 4.9 / 3.9 ms.
- `view_parts_frames`: 6-9 frames per load.

**load_probe ×3** (`godot --headless --fixed-fps 60 --path . -s scripts/checks/load_probe.gd`). The lead's seams were
running in parallel on the 4-vCPU machine, at load average 5.5-6.4:

| load | run 1 longest (ms) | run 2 longest (ms) | run 3 longest (ms) |
|---|---|---|---|
| new run (Night Rocks) | 109.8 | 161.3 | 207.0 |
| gate (Red Canyon) | 118.4 | 92.5 | 98.5 |
| continue (Red Canyon) | 34.0 | 29.1 | 198.2 |
| deep (Ruins) | 99.1 | 178.6 | 52.8 |
| ascension (final arena) | 212.5 | 54.3 | 133.0 |
| restart (Night Rocks) | 359.2 | 43.4 | 138.3 |
| loop (Night Rocks) | 27.6 | 32.0 | 34.4 |

```
[run 1]
load_probe: new_run   covered 119349 frames, 16994.6 ms; longest frame  109.8 ms; still mark frames 0; after-60 longest    6.1 ms; floor=1 hash=163692b46115
load_probe: gate      covered 24863 frames,  5043.5 ms; longest frame  118.4 ms; still mark frames 1; after-60 longest    5.9 ms; floor=2 hash=a33b90d81650
load_probe: continue  covered 34589 frames,  4858.4 ms; longest frame   34.0 ms; still mark frames 0; after-60 longest    5.4 ms; floor=2 hash=a33b90d81650
load_probe: deep      covered 36405 frames,  6143.6 ms; longest frame   99.1 ms; still mark frames 1; after-60 longest    7.4 ms; floor=3 hash=6781bb34aae4
load_probe: ascension covered 24751 frames,  3875.5 ms; longest frame  212.5 ms; still mark frames 0; after-60 longest    5.4 ms; floor=3 hash=2bf9e5547f33
load_probe: restart   covered 36238 frames,  5628.1 ms; longest frame  359.2 ms; still mark frames 0; after-60 longest    3.8 ms; floor=1 hash=163692b46115
load_probe: loop      covered 28297 frames,  4367.2 ms; longest frame   27.6 ms; still mark frames 0; after-60 longest    6.7 ms; floor=1 hash=56901631297e
load_probe: done; load average 5.90 5.12 5.60 8/160 30302
[run 2]
load_probe: new_run   covered 150599 frames, 19184.2 ms; longest frame  161.3 ms; still mark frames 0; after-60 longest    4.7 ms; floor=1 hash=163692b46115
load_probe: gate      covered 32112 frames,  5332.1 ms; longest frame   92.5 ms; still mark frames 1; after-60 longest    6.1 ms; floor=2 hash=a33b90d81650
load_probe: continue  covered 28153 frames,  4380.3 ms; longest frame   29.1 ms; still mark frames 0; after-60 longest    4.9 ms; floor=2 hash=a33b90d81650
load_probe: deep      covered 34487 frames,  6444.8 ms; longest frame  178.6 ms; still mark frames 1; after-60 longest    7.1 ms; floor=3 hash=6781bb34aae4
load_probe: ascension covered 29325 frames,  4268.7 ms; longest frame   54.3 ms; still mark frames 0; after-60 longest    6.0 ms; floor=3 hash=2bf9e5547f33
load_probe: restart   covered 36637 frames,  5694.3 ms; longest frame   43.4 ms; still mark frames 0; after-60 longest    3.8 ms; floor=1 hash=163692b46115
load_probe: loop      covered 28343 frames,  4576.6 ms; longest frame   32.0 ms; still mark frames 0; after-60 longest    5.9 ms; floor=1 hash=56901631297e
load_probe: done; load average 5.75 5.29 5.62 6/156 30358
[run 3]
load_probe: new_run   covered 153116 frames, 18289.2 ms; longest frame  207.0 ms; still mark frames 0; after-60 longest    3.5 ms; floor=1 hash=163692b46115
load_probe: gate      covered 24736 frames,  4785.7 ms; longest frame   98.5 ms; still mark frames 1; after-60 longest    5.9 ms; floor=2 hash=a33b90d81650
load_probe: continue  covered 28342 frames,  4558.2 ms; longest frame  198.2 ms; still mark frames 0; after-60 longest    5.2 ms; floor=2 hash=a33b90d81650
load_probe: deep      covered 37116 frames,  5723.0 ms; longest frame   52.8 ms; still mark frames 1; after-60 longest    9.5 ms; floor=3 hash=6781bb34aae4
load_probe: ascension covered 25032 frames,  3925.9 ms; longest frame  133.0 ms; still mark frames 0; after-60 longest    5.5 ms; floor=3 hash=2bf9e5547f33
load_probe: restart   covered 41209 frames,  5597.0 ms; longest frame  138.3 ms; still mark frames 0; after-60 longest    9.7 ms; floor=1 hash=163692b46115
load_probe: loop      covered 25523 frames,  3941.1 ms; longest frame   34.4 ms; still mark frames 0; after-60 longest    6.2 ms; floor=1 hash=56901631297e
load_probe: done; load average 6.40 5.62 5.72 7/159 30475
```
**What the frames over 50 ms were** (the probe's breakdown, three worst per load, from
`build/perf/ld_probe_<n>.log`):
- **None is the floor's first frame any more.** No `step1=0.0[]` frame with real CPU time is left in any load's
  eight worst.
- Every frame over 62 ms but one is the main thread waiting:
  - for a CPU (`runq` about the frame's length, 0-4.6 ms of its own CPU; for example
    `359.2 ms cv cpu=4.0 runq=358.9 … step1=0.0[wait:dress]`);
  - or neither running nor in the run queue (`cpu=0.0 runq=0.0`, 98-172 ms; the machine).

  While the main thread only polls the worker, the frame's own work is under 5 ms.
- **The one exception, not explained:** run 3, new run, `80.2 ms cv cpu=58.1 runq=24.0 … step1=0.0[wait:dress]`. That
  is 58 ms of main-thread CPU in a frame where the queue only polled the dress worker. It was seen before LD too
  (MI follow-up run "e": `225.6 ms cv cpu=138.9 … [wait:dress]`). Not found here.
- The view jobs over 50 ms are real main-thread work under contention:
  - `final_arena` 51-54 ms (`cpu` 40-44 ms, ascension runs 1-2);
  - `ground` 51 ms (`cpu` 38.6 ms, deep run 3).

  Each is a single job; they predate LD.

**Target (≤ 50 ms per frame): still missed on this machine, reported.** The share of over-50 frames that come from the
game's own work fell to the jobs above, and the one frame not explained. The rest are waits for a CPU. A quiet machine
and the owner's hardware: **NOT YET RUN**.

**Tests:**
- `gdformat --check src scripts tests` (1033 files unchanged) + `gdlint` (no problems);
- `tests/arch` 4/4;
- `-gtest=` 14 files, 44/44 (Asserts 5426, 323.2 s):
  - unit: view_build_queue (5, 1 new), loading_cover, floor_receiver, ascension_views, portal_transit_view,
    routes_view;
  - e2e: loading_cover, arrival, saves, run_flow, old_save, dev_panel, dev_master_panel, dev_gate.

Not run locally: seams, the full suite.

