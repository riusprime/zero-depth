# Q5_FIX: the views sync once a frame (PERF_Q5 §5, fixes 1 and 2)

- **Status:** RUN (with a caveat on the machine: see "Read this first")
- **Owner's ask:** Q5, answered 2026-11-02 "Q5 yes fix it" (PERF_Q5.md: ~18 fps with 60 enemies).
- **Build:** branch `v0105-q5` cut from `08189c2b`. Every probe run printed `sha=08189c2b`: the "before" runs on the
  untouched tree (this step's changes stashed), the "after" runs with this step's changes uncommitted. The step's commit
  is the one that adds this file.
- **Machine:** the owner's PC, i7-10700K, RTX 3060 (`NVIDIA GeForce RTX 3060`, Forward+), 1920 x 1080 windowed, off
  screen, vsync off. Godot `4.7.2.stable` console build. Windows 11 Pro 10.0.26200.
- **Date:** 2026-11-02. **Who ran it:** agent.

## Read this first: the machine was not idle

From 11:03 the owner's Godot editor (`--path …/zero-depth-v090 --editor`) and a game it launched (`--scene
res://src/app/mai…`, 3.4 GB) were running the whole time; every run below (11:16 to 11:38) ran beside them. That load
moves the numbers by a lot: the two "after" sets, the same code apart from one error print, differ by 5.6 ms at 0
enemies and 6.6 ms at 60. So the absolute numbers are not clean evidence and none of them should be quoted as the
game's frame time; the before/after direction at 20 and 60 enemies holds in both after sets. A clean before/after on an
idle machine: `NOT YET RUN` (one run each, with nothing else open).

## Commands

```
export APPDATA=$(mktemp -d)    # a fresh one for every run
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- \
  --biome=red_canyon --heavy --fx --secs=20 --warm=4 --enemies=N
```

N = 60, 20, 0, one run each, one at a time; logs in `build/q5fix/` (untracked): `before{60,20,0}.log`,
`first_after/after{60,20,0}.log`, `after{60,20,0}.log`.

The first "after" set ran with a bug in the actors view's new part cache (`get_meta(key, null)` still reports an error
when the meta is missing: 487 error lines at 60 enemies, one per new actor); it was fixed and the set ran again
(`after*.log`). Both sets are shown.

## Results (raw)

```
== before60
frame_probe  sha=08189c2b  biome=red_canyon  ab=none
scenario: Playground room seed 4404, Gun, 60 live enemies, warm-up 4.0 s, measured 20.0 s
frames=320  avg_ms=62.644  p50_ms=64.460  p95_ms=83.454  p99_ms=101.964
1pct_low_fps=7.8 (1000 / mean of the slowest 4 frames)  max_ms=162.752  over_6.94ms=320 (100.00 %)  avg_fps=16.0
render_cpu_ms_avg=3.291  render_gpu_ms_avg=9.214  (RenderingServer viewport measured time)
== before20
frames=856  avg_ms=23.381  p50_ms=20.456  p95_ms=42.870  p99_ms=59.015
1pct_low_fps=12.0 (1000 / mean of the slowest 9 frames)  max_ms=147.028  over_6.94ms=787 (91.94 %)  avg_fps=42.8
render_cpu_ms_avg=1.872  render_gpu_ms_avg=5.162  (RenderingServer viewport measured time)
== before0
frames=2340  avg_ms=8.553  p50_ms=8.353  p95_ms=13.965  p99_ms=16.551
1pct_low_fps=44.9 (1000 / mean of the slowest 24 frames)  max_ms=30.961  over_6.94ms=1439 (61.50 %)  avg_fps=116.9
render_cpu_ms_avg=0.742  render_gpu_ms_avg=3.459  (RenderingServer viewport measured time)
== first_after/after60   (with the get_meta error print)
frames=539  avg_ms=37.202  p50_ms=34.536  p95_ms=53.136  p99_ms=120.832
1pct_low_fps=5.1 (1000 / mean of the slowest 6 frames)  max_ms=451.390  over_6.94ms=539 (100.00 %)  avg_fps=26.9
render_cpu_ms_avg=3.062  render_gpu_ms_avg=10.008  (RenderingServer viewport measured time)
== first_after/after20
frames=1216  avg_ms=16.450  p50_ms=14.862  p95_ms=28.408  p99_ms=47.222
1pct_low_fps=14.2 (1000 / mean of the slowest 13 frames)  max_ms=180.153  over_6.94ms=1216 (100.00 %)  avg_fps=60.8
render_cpu_ms_avg=1.915  render_gpu_ms_avg=4.693  (RenderingServer viewport measured time)
== first_after/after0
frames=2913  avg_ms=6.868  p50_ms=6.395  p95_ms=9.646  p99_ms=10.291
1pct_low_fps=49.2 (1000 / mean of the slowest 30 frames)  max_ms=119.382  over_6.94ms=1242 (42.64 %)  avg_fps=145.6
render_cpu_ms_avg=0.700  render_gpu_ms_avg=3.267  (RenderingServer viewport measured time)
== after60   (the committed code)
frames=457  avg_ms=43.827  p50_ms=40.876  p95_ms=63.535  p99_ms=184.907
1pct_low_fps=4.1 (1000 / mean of the slowest 5 frames)  max_ms=341.498  over_6.94ms=457 (100.00 %)  avg_fps=22.8
render_cpu_ms_avg=3.224  render_gpu_ms_avg=10.772  (RenderingServer viewport measured time)
== after20
frames=1280  avg_ms=15.631  p50_ms=15.143  p95_ms=23.169  p99_ms=30.716
1pct_low_fps=21.2 (1000 / mean of the slowest 13 frames)  max_ms=149.939  over_6.94ms=1280 (100.00 %)  avg_fps=64.0
render_cpu_ms_avg=1.734  render_gpu_ms_avg=4.783  (RenderingServer viewport measured time)
== after0
frames=1603  avg_ms=12.485  p50_ms=13.738  p95_ms=24.955  p99_ms=27.387
1pct_low_fps=29.9 (1000 / mean of the slowest 17 frames)  max_ms=122.429  over_6.94ms=1201 (74.92 %)  avg_fps=80.1
render_cpu_ms_avg=0.742  render_gpu_ms_avg=3.351  (RenderingServer viewport measured time)
```

(The 20 and 0 headers match the 60 one except the enemy count; trimmed. Each log ends with Godot's usual leak lines.)

| Enemies | before avg ms / fps | after (first set) | after (committed) |
|---|---|---|---|
| 60 | 62.6 / 16.0 | 37.2 / 26.9 | 43.8 / 22.8 |
| 20 | 23.4 / 42.8 | 16.5 / 60.8 | 15.6 / 64.0 |
| 0 | 8.6 / 116.9 | 6.9 / 145.6 | 12.5 / 80.1 |

Against the model (PERF_Q5 §5: fix 1 about -19 ms at 60 enemies, more with fix 2): -25.4 ms (first set) and -18.8 ms
(committed set) at 60, on a loaded machine. The 0-enemy after run is slower than before; at 0 enemies a frame runs under
one tick (nothing to save from fix 1), and the two after sets disagree by 5.6 ms there, which is the machine's load,
not the code (the same code). The p99 and max at 60 enemies are higher after (185 / 341 ms against 102 / 163); not
explained by this run; it may be the load too. Not re-tuned, not re-run.

## What changed

1. **`SimDriver.frame_ticked`** (new): emitted from `SimDriver._process` once a rendered frame that ran one tick or
   more (none for a frame with no tick). The driver sits before the view in the tree, so the views sync before their own
   `_process` and before the draw, as before. The sim is unchanged and steps every tick.
2. **Per listener:**
   - `WorldViewRoot.sync` (every world view): `ticked` → `frame_ticked` (floors: `main.gd`; the Playground and the
     Training room: `training_flow.gd`; the biome swap disconnects both). The Playground's edit (`edited`) still syncs
     at once.
   - The HUD (`Hud.sync`): out of `Main._on_tick` into a new `Main._on_frame` on `frame_ticked`; the Playground's and
     Training room's `_on_playground_tick` (the HUD only) on `frame_ticked`. The HUD's pickups and DPS read the event
     log from their own cursors.
   - Kept on every tick (gameplay-facing or edge-sensitive): the save's room entry, the Codex (`codex_recorder`), the
     achievements and collectibles (`MetaHooks.observe`), the hints, the outcome / portal / end panel checks, the audio
     (`audio.sync`: it reads state edges such as windups), `playground_session` / `training_session` `_on_tick`, the
     hub (`hub_session`, unchanged: one light view).
   - New on every tick: `WorldViewRoot.note_tick` (cheap: one shot check and one pass over the actors' states).
3. **Nothing between two frames is lost:**
   - Hits, damage numbers, deaths, statuses, attack forms, stress marks, remnants: each view reads
     `WorldReader.events_since(its own cursor)`, so a sync sees every event since its last one (the log keeps 4,096).
   - What the sim shows for one tick only and keeps in no log goes through **`LatchedReader`** (new,
     `src/presentation/world_view/latched_reader.gd`, extends `WorldReader`, read-only): the world views' reader. It
     notes each tick (`note`) and shows the next sync (`settle`) a Gun shot fired in any tick since the last sync
     (`shot_fired`: the volley cues, the cast flourish, the hero's cast accent) and an enemy that was `STATE_ACTIVE` in
     any such tick (`actor_state`: 100 enemy attacks are active for one tick, 0.0167 s; the avatars' strike motions, the
     horde tracers and the boss attack cues key on it). Everything else reads the latest tick.
   - `ViewSchedule.due` (the half-rate views, status_fx and modifier_marks): a parity alone could skip a view for good
     at a steady two ticks a frame; a view also syncs once two ticks or more passed since its last sync. At one tick a
     frame it is every other tick, as before.
4. **Physics interpolation:** the views now write the transforms in `_process`, after the frame's ticks pumped the
   previous transform. A scratch check (`build/q5fix/interp_check.gd`, untracked: the hero node's
   `get_global_transform_interpolated()` at `frame_pre_draw` against the sim's positions, 0 enemies, 8 s) gave, in m:
   one-tick frames n=475 mean error 0.0000 against lerp(tick-1, tick, fraction); no-tick frames n=415 0.0000; the
   few multi-tick frames (n=4) 0.0000 against lerp(last frame's tick, tick, fraction), i.e. the in-between tick is
   skipped (an error under one tick's step, only while the game is below 60 fps). The 60-enemy check printed nothing
   (fewer than 300 frames). No physics-interpolation warning in any log. `reset_physics_interpolation` on a fresh node is
   unchanged (it runs in the same sync that places it).
5. **Fix 2 (cheaper sync), the actors view only:** each actor's parts (facing, bar, elite bar, dazed mark, hero
   avatar, enemy avatar, boss flag) are read from the node's metas once and kept by id (`ActorViews._parts`), instead of
   ~9 `get_meta` / `has_meta` calls a sync; the facing's yaw is written only when it changed (rewritten after a Void
   lean); the position is written once (was twice with a ground); HP and team read once. Fireballs, telegraphs and
   status_fx: not changed (their cost is in reads that build dictionaries on the sim's reader, or their tests read the
   draw right after the sync; not a clear win inside this step).
6. **EI-07 / forecasts:** the views still only read (LatchedReader extends WorldReader and adds no write); forecasts are
   untouched. **Determinism:** no file under `src/sim/` changed.
7. `scripts/checks/frame_probe.gd --breakdown` also times the `frame_ticked` listeners (`frame.<script>.<method>`).

## Tests

`"$G" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gdir=… -ginclude_subdirs | -gtest=…> -gexit`, four
runs at once, each with its own `APPDATA` (logs `build/q5fix/t_*.log`):

| Run | Scripts | Tests | Passing | Failing |
|---|---|---|---|---|
| `tests/unit/presentation` (with the new file) | 178 | 1283 | 1283 | 0 |
| `tests/arch`, `tests/unit/app` | 5 | 17 | 17 | 0 |
| e2e: arrival, blade_feel, damage_soak, health_bars, attacks, gun_pool | 6 | 10 | 10 | 0 |
| e2e: saves, run_flow, playground, training_room, hud_style, old_save | 6 | 12 | 11 | 1 |

The one failure, `test_e2e_playground.gd`: `[99999995] expected to equal [100000000]: and whole again before each
tick`. The same file on the untouched tree (`08189c2b`, this step's changes stashed) fails the same assert with the
same values (`build/q5fix/t_pg_before.log`): it predates this step, not fixed here. Lint: `gdformat --check src scripts
tests` (1574 unchanged) and `gdlint src scripts tests` (no problems).

`tests/unit/presentation/test_view_sync_once_a_frame.gd` (new, 5 tests):
the driver's signal once a frame with ticks and never for a frame without; hits on the first and third of three
unsynced ticks both flash and both get their number; every shot of 90 ticks reaches the cast with three ticks a frame;
a one-tick strike reads `STATE_ACTIVE` at the next sync and only then; the half-rate views sync every frame at two ticks
a frame and half the ticks at one.

Owner-only: how it feels at 60 enemies (`OWNER ONLY`).
