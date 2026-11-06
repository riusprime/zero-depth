# VX-W: the VFX pack warms up without freezing loads

Machine: the owner's PC (i7-10700K, RTX 3060, Vulkan 1.4 Forward+), other agents' jobs running at the same time, so the
numbers compare options; they are not absolutes. Window off screen (`--position -10000,-10000`, 640x360), `--fixed-fps 60`.
Build: branch `v0100-vxw` cut from `claude/v0100-vfx` at `ef2be210` (commit SHA in the report).

## The problem

VX0 spawned every table id once behind each floor load's cover, one ViewBuildQueue job per id. The table has about 140
ids now. Each id's first draw compiles shaders and pipelines (10-600 ms, on the render thread, after the job). Every
load paid it again, because the compiled shaders go with the scene when nothing holds the scene (see "Finding").

## Probes

```
build/run_probe.sh  = godot --path . --position -10000,-10000 --fixed-fps 60 --audio-driver Dummy --resolution 640x360 -s <script> -- <args>
scripts/checks/load_probe.gd --menu-only --warm=<mode> [--idle=<ms>]     (new_run, then continue, then restart)
scripts/checks/pack_first_use_probe.gd --warm=<mode> [--restart] [--idle=<ms>]   (10 never-used ids spawned in a live floor, 12 frames each)
```

`--warm=` sets `PackFx.warm_mode`: `load` (VX0, every load warms every id), `none`, `session` (the first load warms every
id, later loads nothing), `menu` (the chosen build: see below). New: `pack_first_use_probe.gd`, `--warm=` and `--idle=`
in `load_probe.gd`.

## Numbers (raw lines, "covered ... longest frame" is the longest frame while the cover is up)

Cover frames, `load_probe.gd --menu-only`:

| Option | new_run | continue | restart | main menu longest frame |
|---|---|---|---|---|
| (a) `load`, VX0 per load | 848.7 ms (39.0 s covered) | 649.8 ms (21.9 s) | 599.2 ms (21.2 s) | 9.0 ms (5 s) |
| no warm at all (`none`, the baseline) | 655.6 ms (23.7 s) | 343.6 ms (8.2 s) | 351.9 ms (7.6 s) | 9.7 ms |
| (b) `session`, first load warms all, scenes kept | 698.8 ms (34.4 s) | 321.6 ms (6.8 s) | 320.2 ms (6.9 s) | 14.9 ms |
| (c) `menu`, idle 30 s at the menu | 351.7 ms (17.2 s) | 271.7 ms (5.7 s) | 295.8 ms (5.9 s) | 95.2 ms (4 frames over 50 ms in 30 s) |
| (c) `menu`, Play after only 3 s | 331.1 ms (17.0 s) | 291.1 ms (5.9 s) | 290.4 ms (5.9 s) | 101.5 ms (4 frames over 50 ms in 3 s) |

(The first load of a process is slow in every row: the whole game's own shaders. "none" new_run 655 ms is the game's
`effects` job, not the pack.) Raw lines, option (c) 30 s:

```
load_probe: pack warm mode menu
load_probe: idle      menu 4262 frames, 30000 ms; longest frame   95.2 ms; frames over 50 ms 4
load_probe: new_run   covered 2057 frames, 17231.8 ms; longest frame  351.7 ms; still mark frames 0; after-60 longest   10.0 ms
load_probe: continue  covered  629 frames,  5683.4 ms; longest frame  271.7 ms; still mark frames 0; after-60 longest    9.7 ms
load_probe: restart   covered  639 frames,  5870.5 ms; longest frame  295.8 ms; still mark frames 0; after-60 longest   10.1 ms
```

"still mark frames 0" in every run: the cover's mark moved on every frame.

First use in a fight (`pack_first_use_probe.gd`, 10 ids spread over the table, worst frame of 12 after each spawn):

| Option | worst of 10 | mean of worst | per-id range |
|---|---|---|---|
| `none` | 625.0 ms | 276.7 ms | 25-625 ms |
| (a) `load` (VX0), first floor | 2099.8 ms (one id, `vx1_muzzle_01`; all others 10-18 ms) | 222.0 ms | |
| `session` with `--restart`, scenes NOT kept (first try) | 551.8 ms | 245.8 ms | 28-552 ms |
| (b) `session` with `--restart`, scenes kept | 15.4 ms | 12.6 ms | 7.8-15.4 ms |
| (c) `menu` with `--restart`, idle 25 s | 17.9 ms | 12.1 ms | 8.1-17.9 ms |
| (c) `menu`, Play after 3 s (rest warmed under the cover) | 15.7 ms | 12.9 ms | |

The 2099.8 ms in the (a) row is a single outlier on a busy machine (no other id above 18 ms); it is not repeated here.

## Finding

1. Compiled shaders live as long as the scene resource that owns them. `PackFx` read each scene with `load()` and kept
   nothing, so the warm of one floor was lost with its view: after a restart every effect stalled again (551.8 ms row).
   Keeping the `PackedScene`s in a static dictionary for the session fixed that (15.4 ms row). This is the main fix.
2. With scenes kept, the warm only has to happen once a session. Doing it as option (b), under the first floor's cover,
   leaves the first floor with 699 ms frames and a 34 s load (about 140 spawns, one per frame, 20-400 ms each).
3. Doing it at the main menu (c), a spawn every 4 frames in a 96x96 off-screen SubViewport with its own World3D, an MSAA
   equal to the window's and a camera, compiles pipelines the real viewport reuses: the fight probe shows no stall
   after it. The menu has 4 frames over 50 ms (max 101 ms) in 3-30 s, where it has none without the warm. The cover's
   longest frames fall to the no-warm baseline or below (272-352 ms against 343-656 ms), and the loads are shorter.
4. If Play is pressed before the menu is done, the floor's own queue warms only the ids left
   (`PackFx.pending_warm_ids()`); that case was measured (3 s row): longest cover frame 331 ms.
5. No rendering setting is involved. In 4.7.2 `ProjectSettings` has only `rendering/shader_compiler/shader_cache/*` and
   `rendering/rendering_device/pipeline_cache/*` (both already on); there is no ubershader or pipeline-precompile switch.
   `project.godot` is untouched.

## Choice: (c), plus keeping the scenes

- `PackFx` keeps every effect scene it reads for the session (`_scene`), and can ask the loader threads for all of them
  (`request_scenes`, `scenes_ready`; `load_threaded_request`).
- `PackFxSessionWarm` (new) starts in `Main._ready` (`PackFxSessionWarm.start(self)`; not in headless): requests the
  scenes, then every 4 frames spawns the next id not yet warmed in the off-screen viewport.
- `PackFx.pending_warm_ids()` (new): what a floor load still has to warm. `WorldViewRoot._queue_pack_warmup` queues
  those. A load of a fully warmed session queues none.
- `PackFx.warm(id)` and `warm_all()` stay (the tests).
- `PackFx.warm_mode` (`menu` default, `session`, `load`, `none`) is kept as a switch for the probes and tests.

Owner-hardware and feel items stay open: whether the menu's 4 short hitches (about 100 ms) are visible to the player
`OWNER ONLY`; a different GPU's compile times `NOT YET RUN (owner hardware)` beyond this PC.

## Tests

```
test_pack_fx.gd, test_pack_fx_session_warm.gd (new, 3), test_view_build_queue.gd, e2e loading_cover, main_menu, pad_menus, shell, old_save, saves:
  Scripts 9 / Tests 40 / Passing 38 / Failing 2    (before the test_view_build_queue fix)
  failing: test_pack_fx.gd test_follow_sees_a_tick_that_stopped_as_a_pause ("no new tick for HOLD_S"; it waits engine time and
           reads wall time under --fixed-fps, not touched by this step), and test_view_build_queue's sliced-vs-one-call
           node count (the second view warmed nothing; the test now sets warm_mode = load)
test_view_build_queue.gd after the fix: Scripts 1 / Tests 5 / Passing 5 / Asserts 933
tests/content + tests/arch + tests/golden: Scripts 34 / Tests 172 / Passing 172 / Asserts 32150 / All tests passed!
gdlint src scripts tests: Success: no problems found
```
