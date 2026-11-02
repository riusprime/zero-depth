# PERF_Q5: where the frame time goes (measure only)

- **Status:** RUN (measure only: no change to `src/`)
- **Build:** branch `v0105-perf` cut from `8aa31854`; the probe prints `sha=8aa31854`. The first six runs (base, `--process`)
  ran on the untouched tree; the last five (`--breakdown` alone, the A/Bs) ran with this step's one probe change
  (`--ab=no_anim`, below) uncommitted. The step's commit is the one that adds this file.
  Godot `4.7.2.stable` (`Godot_v4.7.2-stable_win64_console.exe`); Windows 11 Pro 10.0.26200.
- **Machine:** the owner's PC, i7-10700K, RTX 3060 (the probe reads `NVIDIA GeForce RTX 3060`, Forward+), 1920 x 1080
  windowed, off screen (`--position -10000,-10000`), vsync off, no fps cap. The runs ran one at a time; nothing else
  heavy ran meanwhile.
- **Date:** 2026-11-02
- **Who ran it:** agent

The O12 scenario: `scripts/checks/frame_probe.gd`, red_canyon, the Playground room (seed 4404), the Gun, the five
probe cards at level 3 plus the six `--heavy` cards at level 5 (11 cards), fire held, the aim circling, the hero
strafing; 4 s warm-up, 20 s measured, real time.

## Commands

```
export APPDATA=$(mktemp -d)    # a fresh one for every run
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- \
  --biome=red_canyon --heavy --fx --secs=20 --warm=4 --enemies=N [--breakdown | --process] [--ab=no_anim | --ab=no_interp]
```

| Run | N | Extra flags | Log (untracked) |
|---|---|---|---|
| base60 / base20 / base0 | 60 / 20 / 0 | none (the timing baseline) | `build/q5/base*.log` |
| bdo60 / bdo20 / bdo0 | 60 / 20 / 0 | `--breakdown` (PerfMarks, each view's sync, the sim's phase timer, the tick listeners) | `build/q5/bdo*.log` |
| bd60 / bd20 / bd0 | 60 / 20 / 0 | `--process` (the breakdown plus every node's `_process` called and timed by the probe) | `build/q5/bd*.log` |
| noanim60 | 60 | `--breakdown --ab=no_anim` | `build/q5/noanim60.log` |
| nointerp60 | 60 | `--breakdown --ab=no_interp` | `build/q5/nointerp60.log` |

The one probe change: `--ab=no_anim` sets every `AnimationMixer` under the view inactive, once a second (so new enemies
too). It only exists to test whether the AnimationPlayers are the engine's unexplained `_process` time.

**What the breakdown costs.** `--breakdown` makes the frame 3.4 to 4.0 ms slower (bdo vs base: 8.16 vs 4.75, 16.23
vs 12.59, 59.62 vs 55.61 ms); most of it lands in `frame.scene_process` (the probe's per-frame bookkeeping runs there).
`--process` costs more again (bd60 69.6 ms: it walks the 5,500-node tree every frame), so it is used only for the
per-script `_process` split. The buckets below are from bdo60 unless named.

## 1. Baseline (base runs, no breakdown)

```
== base60
frame_probe  sha=8aa31854  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know whether other processes were busy: name the machine and check the CPU was idle before quoting it as evidence)
scenario: Playground room seed 4404, Gun, 60 live enemies, warm-up 4.0 s, measured 20.0 s
build: ITEM_GUN_GLAIVE, ITEM_GUN_RING, ITEM_SPLIT_SHOT, ITEM_EMBER_CORE, ITEM_STORM_CORE, ITEM_GUN_TWIN, ITEM_HALO_SHOT, ITEM_GUN_RAPID_FIRE, ITEM_WILDFIRE, ITEM_CHAIN_BLAST, ITEM_GUN_RUNE_EXPLOSION at level 3 (Glaive, Ring, Split, fire core, lightning core) + the --heavy cards at level 5
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: none
frames=360  avg_ms=55.609  p50_ms=56.253  p95_ms=82.046  p99_ms=101.907
1pct_low_fps=8.6 (1000 / mean of the slowest 4 frames)  max_ms=140.041  over_6.94ms=360 (100.00 %)  avg_fps=18.0
render_cpu_ms_avg=2.854  render_gpu_ms_avg=11.391  (RenderingServer viewport measured time)
== base20
frames=1589  avg_ms=12.590  p50_ms=12.458  p95_ms=23.178  p99_ms=33.182
1pct_low_fps=23.0 (1000 / mean of the slowest 16 frames)  max_ms=134.094  over_6.94ms=1210 (76.15 %)  avg_fps=79.4
render_cpu_ms_avg=1.533  render_gpu_ms_avg=4.158  (RenderingServer viewport measured time)
== base0
frames=4211  avg_ms=4.750  p50_ms=3.691  p95_ms=8.252  p99_ms=9.637
1pct_low_fps=58.6 (1000 / mean of the slowest 43 frames)  max_ms=122.465  over_6.94ms=1148 (27.26 %)  avg_fps=210.5
render_cpu_ms_avg=0.704  render_gpu_ms_avg=3.138  (RenderingServer viewport measured time)
```

(The 20 and 0 headers match the 60 one except the enemy count; trimmed. Every log also ends with Godot's usual
"RID allocations ... leaked at exit" lines.)

60 enemies: **p50 56.3 ms, p95 82.0 ms, 18.0 fps**, the same as O12 (p50 54.3 / 62.7 ms there). The GPU takes 11.4 ms
and the render CPU 2.9 ms: the rest is the main thread.

## 2. The main thread, per frame (bdo60, raw)

```
frames=336  avg_ms=59.617  p50_ms=61.280  p95_ms=90.361  p99_ms=101.740
render_cpu_ms_avg=2.898  render_gpu_ms_avg=11.796  (RenderingServer viewport measured time)
breakdown (us per frame; main-thread script time; 'ran' = mean over frames the bucket was entered):
  bucket                            mean       p99  ran_mean ran_frames
  frame_total                      59735    101830     59735       336
  step_once                        33434     65152     33434       336
  engine.process                   29844     79007     29844       336
  engine.physics_process           29128     69003     29128       336
  ticked_all                       22825     47924     22825       336
  tick.world_view_root.gd.sync     20652     46509     20652       336
  sync_all                         20637     46500     20637       336
  sim_step                         10405     19553     10405       336
  frame.scene_process              10154     20484     10185       335
  frame.draw_pre_to_post            8483     15201      8509       335
  frame.rest_after_draw             7463     16116      7485       335
  view.actors                       6792     17812      6792       336
  actors.update                     4063      7327      4063       336
  phase.ai                          3106      5419      3106       336
  phase.move                        2497      4248      2497       336
  view.fireballs                    1736      5960      1736       336
  tick.main.gd._on_playground_tick      1716      2804      1716       336
  actors.enemy_sync                 1582      3612      1582       336
  phase.dash_abilities              1380      6453      1380       336
  view.telegraphs                   1317      3724      1317       336
  phase.nav_flood                   1133      4565      2265       168
  view.status_fx                    1035      2100      1038       335
  phase.move.steer                   978      1605       978       336
  view.runes                         960     16985       960       336
  phase.move.pairs                   817      1551       817       336
  view.attack_forms                  737      1760       737       336
  phase.proj                         707      1415       707       336
  phase.ai.plan                      681      1364       681       336
  actors.animate                     640      1317       640       336
  phase.resolve                      635      1104       635       336
  phase.proj.sweep                   607      1215       607       336
  view.horde_fx                      564      1319       564       336
  view.elite_fx                      545      1229       545       336
  sync.occlusion                     507       900       507       336
  actors.hero_sync                   472       802       472       336
  view.item_fx                       469       764       469       336
  tick.playground_session.gd._on_tick       416       661       416       336
  [… 108 smaller rows trimmed: the other ~55 views (each under 0.4 ms), the other phases, counts …]
  count.actors                        49        61        49       336
  count.projectiles                   28        46        28       336
  ticks                                3         4         3       336
node classes: MeshInstance3D=2467, Node3D=1082, GPUParticles3D=503, OmniLight3D=250, AnimationPlayer=213, Label=175, Control=127, MultiMeshInstance3D=110, Label3D=81, Decal=76, AudioStreamPlayer3D=57, VBoxContainer=43, HBoxContainer=32, PanelContainer=28, ColorRect=23, Sprite3D=18, Panel=12, Node2D=8; visible VisualInstance3D=1046
```

From the bd60 (`--process`) run, the nodes' own `_process`, summed by script: 5.5 ms a frame in all, led by
`attack_form_view.gd` 2.29, `bolt.gd` 0.45, `elite_avatar.gd` 0.44, `horde_avatar.gd` 0.43, `fireball_views.gd` 0.29,
`player_avatar.gd` 0.22 ms.

How to read it:

- **The frame is four parts that add up:** `step_once` (every sim tick of the frame and its listeners) 33.4 +
  `frame.scene_process` (the nodes' `_process` and the engine's idle work) 10.2 + `frame.draw_pre_to_post` (the
  main thread's rendering) 8.5 + `frame.rest_after_draw` (present, the physics server's step, the physics-interpolation
  pump, everything outside the sim between one draw and the next frame's process) 7.5 = 59.6 ms.
- **Ticks a frame.** The sim steps in `SimDriver._physics_process` at 60 Hz with `max_physics_steps_per_frame=4`. At
  59.6 ms a frame, real time needs 59.6 / 16.67 = **3.6 ticks a frame** (the probe prints the mean rounded: 3; p99 4,
  the cap). So everything in `step_once` is paid 3.6 times a frame.
- **Per tick at 60 enemies:** 33.4 / 3.6 = **9.3 ms**: the views' sync 5.8, the sim 2.9, the other listeners 0.6
  (the Playground's upkeep 0.48, `playground_session` 0.12).
- **The views sync on every tick, not once a frame** (`driver.ticked.connect(view.sync)`, `main.gd:479`). Of the 20.7 ms:
  the actors view 6.8 (`actors.update` 4.1, `enemy_sync` 1.6, `animate` 0.6, `hero_sync` 0.5), fireballs 1.7,
  telegraphs 1.3, status_fx 1.0, runes 1.0, attack_forms 0.7, horde_fx 0.6, elite_fx 0.5, item_fx 0.5, occlusion 0.5,
  and ~55 smaller views 4.6.
- **The sim tick** (2.9 ms; 10.4 a frame): AI 3.1 (of it `ai.plan` 0.7, the flow-field grid 0.1), move and collide 2.5
  (steer 1.0, pairs 0.8, walls 0.4, grid 0.2), dash and abilities 1.4, the nav flood 1.1 (on half the frames: 2.3
  when it runs), projectiles 0.7, enemy attacks 0.6, statuses 0.25, after (spawns, directors) 0.25, actions 0.25,
  the dead 0.04; 0.2 untimed (the input and the interact steps before the AI). No hashing: `state_hash` is on demand.
- **Physics:** none besides the sim; `engine.physics_process` is the sim's step.
- **`Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS`** (the `engine.*` rows: 29.8 / 29.1 ms at 60, 14.6 / 22.2 at 0
  enemies, more than that run's whole 8.2 ms frame): Godot keeps the slowest frame of each second for these monitors, so
  they are per-second maxima, not means. Not used below.
- **The AnimationPlayers are not the engine's `_process` time:** `--ab=no_anim` (213 players stopped) timed
  62.5 ms against 59.6 (`frame.scene_process` 10.7 vs 10.2): no saving, inside the run-to-run spread (~4 ms: base60
  55.6 vs O12's 57.1 and 63.3 on the same scenario).
- **Physics interpolation** (`--ab=no_interp`, one run): 50.8 ms against 59.6 (p50 48.4, 19.7 fps); `frame.scene_process`
  8.9, `draw_pre_to_post` 7.5, `rest_after_draw` 6.1, and fewer ticks a frame (3.05) because the frame is shorter.
  About 9 ms, twice the spread.
- **Counts (per-second samples, mean of 20):** draw calls 1,787, objects 19,487, nodes 5,565, particle nodes 448
  (169 emitting); 49 actors and 28 projectiles a frame.

```
== noanim60
flags: no_anim=on
frames=321  avg_ms=62.486  p50_ms=65.296  p95_ms=89.201  p99_ms=137.155
render_cpu_ms_avg=2.981  render_gpu_ms_avg=11.661  (RenderingServer viewport measured time)
  frame.scene_process              10736     20573     10769       320
== nointerp60
flags: no_interp=on
frames=394  avg_ms=50.847  p50_ms=48.425  p95_ms=80.761  p99_ms=90.072
1pct_low_fps=8.9 (1000 / mean of the slowest 4 frames)  max_ms=163.211  over_6.94ms=394 (100.00 %)  avg_fps=19.7
render_cpu_ms_avg=2.646  render_gpu_ms_avg=10.546  (RenderingServer viewport measured time)
  step_once                        28288     56225     28288       394
  sim_step                          8832     17311      8832       394
  tick.world_view_root.gd.sync     17511     41893     17511       394
  frame.scene_process               8947     18958      8970       393
  frame.draw_pre_to_post            7501     12553      7520       393
  frame.rest_after_draw             6050     11244      6065       393
```

## 3. Top 10 costs at 60 enemies (ms per frame, bdo60, leaves that do not overlap)

| # | Cost | ms / frame | Per tick | Where |
|---|---|---|---|---|
| 1 | The nodes' `_process` and the engine's idle work (`frame.scene_process`; ~3.5 of it is the probe's own bookkeeping, ~5.5 the scripts' `_process`, led by `attack_form_view.gd` 2.3) | 10.2 | per frame | engine + `src/presentation` |
| 2 | Main-thread rendering (`frame.draw_pre_to_post`: culling and submitting ~1,790 draw calls, 1,046 visible instances, 448 particle nodes, 250 omni lights; render CPU 2.9 of it) | 8.5 | per frame | engine |
| 3 | Between the draw and the next frame (`frame.rest_after_draw`: present, the physics server, the interpolation pump of each tick) | 7.5 | per frame | engine |
| 4 | The actors view's sync (`ActorViews`: update 4.1, enemy sync 1.6, animate 0.6, hero 0.5) | 6.8 | 1.9 | `actor_views.gd` |
| 5 | The ~55 small views' syncs together (each under 0.4 ms a frame; ~2.9 ms a tick even with 0 enemies) plus the sync's own culling and occlusion | 5.7 | 1.6 | `world_view_root.gd` and its views |
| 6 | Sim: AI | 3.1 | 0.87 | `enemy_ai.gd`, `World._run_ai` |
| 7 | Sim: move and collide (steer 1.0, pairs 0.8, walls 0.4, grid 0.2) | 2.5 | 0.70 | `World._move_and_collide` |
| 8 | The fireballs view's sync | 1.7 | 0.48 | `fireball_views` |
| 9 | The Playground's tick upkeep (`Main._on_playground_tick`; probe and Playground only, not a run) | 1.7 | 0.48 | `main.gd` |
| 10 | Sim: dash and abilities (`dash_abilities`) | 1.4 | 0.39 | `ItemEffects.dash_hits`, `Abilities.advance` |

Next: the telegraphs view 1.3, the nav flood 1.1, status_fx 1.0, runes 1.0 (p99 17.0: a spike view), attack_forms 0.7,
projectiles 0.7, enemy attacks 0.6.

## 4. Scaling 0 → 20 → 60 enemies

| | 0 | 20 | 60 |
|---|---|---|---|
| base: avg / p50 / p95 ms | 4.75 / 3.69 / 8.25 | 12.59 / 12.46 / 23.18 | 55.61 / 56.25 / 82.05 |
| base: avg fps / 1 % low fps | 210.5 / 58.6 | 79.4 / 23.0 | 18.0 / 8.6 |
| render CPU / GPU ms (base) | 0.70 / 3.14 | 1.53 / 4.16 | 2.85 / 11.39 |
| breakdown run avg ms | 8.16 | 16.23 | 59.62 |
| ticks a frame (avg ms / 16.67) | 0.49 | 0.97 | 3.58 |
| `step_once` ms / frame | 2.22 | 6.06 | 33.43 |
| of it the views' sync | 1.46 | 3.77 | 20.65 |
| of it the sim | 0.30 | 1.58 | 10.41 |
| **per tick:** step / sync / sim ms | 4.5 / 3.0 / 0.61 | 6.2 / 3.9 / 1.63 | 9.3 / 5.8 / 2.91 |
| per frame outside the ticks (scene_process + draw + rest) ms | 1.98 + 2.69 + 1.28 = 5.9 | 3.82 + 4.21 + 2.14 = 10.2 | 10.15 + 8.48 + 7.46 = 26.1 |
| draw calls / nodes / particle nodes | 523 / 3,009 / 194 | 1,093 / 4,180 / 305 | 1,787 / 5,565 / 448 |

The 20-enemy frame on the owner's PC (owner's earlier ask): **12.6 ms avg, p50 12.5, p95 23.2, 79 fps.**

**Why 3x the enemies costs 4.4x the frame.** Both parts grow about linearly with the enemies (per tick 6.2 → 9.3 ms;
outside the ticks 10.2 → 26.1 ms). The multiplier is the fixed step: a frame longer than 16.7 ms runs more ticks, and
each tick pays the whole view sync again. The frame time fits `T = F / (1 - C / 16.67)` (F the per-frame part, C the
per-tick part): 26.1 / (1 - 9.3 / 16.67) = 59.6 ms at 60 enemies, 10.2 / (1 - 6.2 / 16.67) = 16.3 ms at 20 (measured
59.6 and 16.2). At 60 enemies, each ms off a tick saves about 7 ms of frame; each ms off the per-frame part about
2.3 ms. Above 66.7 ms a frame the cap of 4 ticks bites and the game runs slower than real time (the p95 frames do).

## 5. What to fix first (ranked; no change made; savings modelled with the formula above from bdo60, ±4 ms spread)

1. **Sync the views once a frame, not once per tick.** The views would read the ticks' events gathered since the last
   frame and the last tick's state. C 9.3 → 3.5 ms, F 26.1 → 31.9 ms: **59.6 → ~41 ms (-19 ms, 17 → ~25 fps).** The
   catch: views such as `hit_feel`, `damage_numbers` and `attack_form_view` read `reader.events` each tick, and physics interpolation reads the per-tick transforms, so this is a
   presentation-contract change (EI-07 holds: the views still only read), a design step and not a direct fix.
2. **Make the sync itself cheaper:** the actors view (1.9 ms a tick: `actors.update` 1.1), then fireballs, telegraphs,
   status_fx, and the ~3 ms a tick the ~60 views cost with no enemies at all (each view walks its state every tick).
   Halving the sync per tick (5.8 → 2.9): **~-17 ms alone (→ ~43 ms)**; with #1, ~37 ms.
3. **The sim tick's AI and move** (1.6 ms of its 2.9 a tick: `ai` 0.87, `move` 0.70 with steer and pairs). Each ms here
   is ~7 ms of frame while the catch-up runs 3-4 ticks: halving the two **~-6 ms (→ ~54 ms)**; after #1 much less
   (~-2 ms).
4. **Physics interpolation** (`--ab=no_interp`, one run): **-9 ms (59.6 → 50.8)**. It is what keeps the motion smooth
   above 60 fps, so turning it off is the owner's call; a cheaper path is fewer interpolated nodes (the 5,565 nodes,
   1,082 bare Node3D, 2,467 meshes).
5. **The per-frame engine and script part (26 ms):** the scripts' `_process` (5.5 ms, `attack_form_view.gd` 2.3), the
   main thread's draw (8.5 ms for ~1,790 draw calls, 503 GPUParticles3D, 250 OmniLight3D). Each ms here is ~2.3 ms of
   frame now and 1.3 ms after #1. Halving `attack_form_view`'s `_process`: ~-2.6 ms.

Not a cause: the AnimationPlayers (`--ab=no_anim`, no saving), the GPU (11.4 ms, under the main thread's ~45 ms), the
render CPU (2.9 ms).

Owner-only: none of this is a feel judgement; the numbers are on the owner's PC as named above.
