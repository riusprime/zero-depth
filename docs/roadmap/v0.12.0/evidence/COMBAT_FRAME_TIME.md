# COMBAT_FRAME_TIME: where the frame goes in the owner's three slow fights (F18), and what the fixes changed

- **Status:** RUN (indications: other agents' Godot runs shared the machine for most of it, see "Machine and load")
- **Build:** before `ee030910` (v0.12.0, `claude/v0120`); after: the step's commit on `v0120-s16` (its parent
  `ee030910`); Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200; Forward+, Vulkan 1.4.351
- **Machine:** the owner's PC (i7-10700K, RTX 3060), driven by an agent
- **Date:** 2026-11-18
- **Who ran it:** agent

## Machine and load

Other agents ran Godot tests on this machine the whole time: the probes' own `godot_before` / `godot_after` counts
(`tasklist | grep -ic godot`, each Godot is two processes, the console wrapper and the game) read 2 to 10, so one to
four other Godots, mostly GUT runs, beside each measurement. Frame times therefore move a lot from run to run: the
same unchanged build, same scene, gave 10.8, 14.8 and 10.5 ms of average frame within half an hour (`a_sv_hp`,
`a_sv_r2`, `a_sv_r3` below). Under PERF_TOOLS §2 these are indications, not evidence of a gain. The script buckets
(`--breakdown`, time a view's sync took) are read beside the frame times: they move with the load too, but less.
The final before/after (the last section of results) ran when no other Godot was running before or after each run.

## The owner's report and what was reproduced

The owner (2026-11-11 build, ~2K, fullscreen, profile: lighting high, effects high, frame cap 144): about 120 fps
with no enemies, about 80 shooting, about 40 with Seekers and Venom and few enemies, about 35 in Starfall with 30–40
enemies, about 60 in Frozen Shore at 1600 × 900 with little on screen.

| Scenario | Probe scene | Reproduced? |
|---|---|---|
| (a) Seekers + Venom | the Playground in Red Canyon, the Gun with `gun_seekers` and `venom_core` at level 5, 12 enemies kept alive, their HP × 3 (a later floor, so Venom's stacks build), 2560 × 1440 | The drop is there: +3.3 ms a frame over the Gun alone in the same scene (7.5 → 10.8 ms, busy machine); 8.4 ms on the quieter before/after runs. The absolute numbers are about twice the owner's frame rate |
| (b) Starfall, 35 enemies | Starfall, 35 enemies cycling the biome's roster (charger, needle, swarmer, warden, star warper, gravity node, split sniper), HP × 3, the probe's default build, 2560 × 1440 | 14.3 ms (70 fps) here against the owner's ~35 fps |
| (c) Frozen Shore | Frozen Shore, 12 enemies of its roster (core four, frost spitter, glacier turtle, frost charger), 1600 × 900; and the real generated floor with no enemies (`biome_probe`) | 8.5 ms (118 fps) in the fight; the still floor ≈ 5 ms like the other biomes. Not reproduced |

Every scene here runs at about twice the owner's frame rate on the same hardware. What differs from the owner's
session is not known: the owner's build was the 2026-11-11 one (several frame-time steps of v0.11.1 landed that
day: the batched enemies, the native core, the Ring fix), a real run has a whole floor and a longer session, and the
owner's fights had their own cards. **Ask the owner which build they played, and for a perf log of the same fights
on this build** (`godot --path . -- --perf-log`, PERF_LOG.md): the probe scenes are not their fights.

## Commands

The probe gained two scene options for this page (`scripts/checks/frame_probe.gd`): `--kinds=<kind,...>` (the live
enemies cycle through those kinds: a biome's roster) and `--hp=<permille>` (every placed enemy's HP scaled), and
`frame_spans.gd` one switch, `--ab=no_kind_memo` (the views' reader asks the sim on every call: the fix below off).
Every run below is this wrapper (`build/s16_run.sh`, not tracked), from the worktree, with its own `APPDATA`:

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-s16 \
"C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" \
  --path . --resolution <WxH> --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --size=<WxH> <scene>
```

| Tag | `<WxH>` and `<scene>` |
|---|---|
| a, Gun alone | `2560x1440 --biome=red_canyon --cards=none --enemies=12 --hp=3000 --secs=15 --spans --breakdown --fx` |
| a, Seekers + Venom | `2560x1440 --biome=red_canyon --cards=gun_seekers:5,venom_core:5 --enemies=12 --hp=3000 --secs=15 --spans --breakdown --fx` |
| b | `2560x1440 --biome=starfall --kinds=charger,needle,swarmer,warden,star_warper,gravity_node,split_sniper --enemies=35 --hp=3000 --secs=15 --spans --breakdown --fx` |
| c | `1600x900 --biome=frozen_shore --kinds=charger,needle,swarmer,warden,frost_spitter,glacier_turtle,frost_charger --enemies=12 --secs=15 --spans --breakdown --fx` |

The still floors: `... -s scripts/checks/biome_probe.gd -- biome=<id> tag=<tag> frames=180 [off=<switch>]` at
`--resolution 1600x900`.

## Raw output: the scenes before any change (build `ee030910`, nothing edited)

```
== a_gun_hp exit=0 godot_before=4 godot_after=4 sha=ee030910 dirty=0
frames=2012  avg_ms=7.458  p50_ms=7.249  p95_ms=9.916  p99_ms=13.932
1pct_low_fps=60.3 (1000 / mean of the slowest 21 frames)  max_ms=32.822  over_6.94ms=1241 (61.68 %)  avg_fps=134.1
render_cpu_ms_avg=0.738  render_gpu_ms_avg=5.242  (RenderingServer viewport measured time)
spans (us a frame, mean): probe_script=472  nodes_process=3415  after_process=454  draw=2328  after_draw=330  physics_pre=8  nodes_physics=407  physics_post=43  sum=7458
== a_sv_hp exit=0 godot_before=4 godot_after=4 sha=ee030910 dirty=0
frames=1394  avg_ms=10.770  p50_ms=10.000  p95_ms=17.003  p99_ms=20.154
1pct_low_fps=42.8 (1000 / mean of the slowest 14 frames)  max_ms=37.238  over_6.94ms=1315 (94.33 %)  avg_fps=92.8
render_cpu_ms_avg=0.913  render_gpu_ms_avg=5.574  (RenderingServer viewport measured time)
spans (us a frame, mean): probe_script=609  nodes_process=5326  after_process=879  draw=2379  after_draw=364  physics_pre=13  nodes_physics=1119  physics_post=81  sum=10770
== b_sf35 exit=0 godot_before=4 godot_after=4 sha=ee030910 dirty=0
frames=1049  avg_ms=14.302  p50_ms=13.706  p95_ms=21.932  p99_ms=27.737
1pct_low_fps=32.8 (1000 / mean of the slowest 11 frames)  max_ms=37.268  over_6.94ms=1049 (100.00 %)  avg_fps=69.9
render_cpu_ms_avg=1.085  render_gpu_ms_avg=8.232  (RenderingServer viewport measured time)
spans (us a frame, mean): probe_script=604  nodes_process=7233  after_process=1444  draw=3272  after_draw=349  physics_pre=16  nodes_physics=1200  physics_post=183  sum=14302
== c_fs exit=0 godot_before=4 godot_after=0 sha=ee030910 dirty=0
frames=1775  avg_ms=8.453  p50_ms=8.426  p95_ms=13.012  p99_ms=16.252
1pct_low_fps=54.1 (1000 / mean of the slowest 18 frames)  max_ms=33.471  over_6.94ms=1211 (68.23 %)  avg_fps=118.3
render_cpu_ms_avg=0.860  render_gpu_ms_avg=2.986  (RenderingServer viewport measured time)
spans (us a frame, mean): probe_script=516  nodes_process=4026  after_process=777  draw=2173  after_draw=359  physics_pre=9  nodes_physics=521  physics_post=72  sum=8453
```

Draw calls and primitives, the mean of the per-second samples: a Gun alone 258 / 379,600; a Seekers + Venom 325 /
475,829; b 461 / 629,108; c 317 / 238,234.

`biome_probe` (still floor, no enemies, 1600 × 900, 5 spots × 180 frames, avg / p95 / max frame ms):

```
== frozen_shore base exit=0 godot_before=2
frame_ms          8.109    14.037    38.147
== starfall base exit=0 godot_before=8
frame_ms          5.583     8.276    14.037
== red_canyon base exit=0 godot_before=6
frame_ms          5.017     7.194    10.103
== frozen_shore off_fog exit=0 godot_before=4
frame_ms          5.299     7.462     8.667
== frozen_shore off_glow exit=0 godot_before=6
frame_ms          4.760     6.810    10.778
== frozen_shore off_ssao exit=0 godot_before=2
frame_ms          4.779     6.717     8.550
== frozen_shore off_ssil exit=0 godot_before=4
frame_ms          5.447     8.255    11.646
== frozen_shore off_sun_shadow exit=0 godot_before=8
frame_ms          5.686     7.913    13.972
== frozen_shore off_kit_shadows exit=0 godot_before=6
frame_ms          5.533     7.523    21.770
== frozen_shore off_decor exit=0 godot_before=6
frame_ms          9.455    11.561    31.554
```

The first Frozen Shore run (8.1 ms, max 38 ms) was the batch's first, on a cold shader cache; every later Frozen
Shore run with one switch off reads 4.8–5.7 ms except `off_decor` (9.5 ms, the busiest moment), so no switch stands
out from the spread. Frozen Shore's floor costs what the other biomes' do.

## Where the time goes

### (a) Seekers + Venom: +3.3 ms over the Gun alone, spread over many parts

The `--breakdown` buckets, Seekers + Venom minus the Gun alone in the same scene (µs a frame, mean):

| Part | Δ | What it is |
|---|---|---|
| the views' sync (`sync_all`) | +1,126 | every view's tick read; the biggest shares: `view.actors` +194, `view.seekers` +173, `view.attack_forms` +98, `view.pulses` +73, `view.glaives` / `bombs` / `scatter` / `telegraphs` / `heat_fx` +20–37 each |
| the sim (`sim_step`) | +657 | `phase.proj.steer` +396: the Seekers' homing, run in GDScript for every projectile each tick (`NativeShots.sweep` → `ProjectileMoves.steer`), about 650 µs a tick |
| the other frame work in `nodes_process` | about +800 | the hero's per-frame effect drawing (`AttackFormCanvas.draw_at` 811 µs a frame in `--process`, against 404 µs for the Gun alone with no enemies in a `--process` run of the Frozen Shore room; within it the effects layer's drawers, led by `ImpactFx.draw` 229 µs, `FireballViews.draw_lights` 186 µs, `StatusVisuals._draw_vfx` 113 µs a frame) and the engine's own node work |
| `after_process` | +425 | redraws, transforms, the delete queue |

The pack's effects (the javelin per dart, the poison bubbles) are not the cause: `--ab=no_pack_fx` (9.96 ms) and
`--ab=no_anim` (9.58 ms) read inside the base's own spread (10.5–14.8 ms). The GPU moved 5.24 → 5.57 ms: not GPU-bound.

The one cost the views pay for every shot many times a tick: which form draws a shot. Fourteen presentation files loop over every
projectile each sync and ask `projectile_is_wave`, `_bomb`, `_void`, `_pellet`, `_disc`, `_dart`, `_wisp` (three of
them, the bolt layer, the lances and the pulses, ask nearly all of them for every shot), and each answer looks the shot's attack spec up by name (`Attacks.projectile_spec` →
`Modifiers.book(w).find(key)`). With Seekers' volleys that is several hundred lookups a tick.

### (b) Starfall, 35 enemies: the enemies' nodes, a Needle's bent telegraph, the GPU

From the `b_sf35` breakdown (µs a frame, mean; p99 in brackets): `view.actors` 1,199 (2,394), of it `actors.update`
811: five of the seven roster kinds are not batched (needle, warden, star warper, gravity node, split sniper), so each
is a node tree and a GDScript avatar. `view.telegraphs` 845 (4,162): a run with marks inside it put 838 (4,611) of
that in `reader.telegraph(i)` itself, the sim's telegraph for a Needle near a Gravity Node (`EnemyAi.burst_lines` →
`StarfallKinds.bent_lanes`: each shot's path walked tick by tick, a wall test every 4 ticks, every tick of the
windup). `after_process` 1,444 against 454–879 elsewhere. The GPU 8.2 ms (5.2–5.6 in Red Canyon) at 2560 × 1440:
Starfall's volumetric fog, SSIL and glow; at this load the GPU alone allows about 120 fps.

In the telegraphs' own drawing, each disc telegraph's ring (a `TorusMesh`, 48 × 32) and each lane's four edge boxes
were given their size again on every tick, and Godot builds a primitive mesh again on every property set. A headless
micro-bench on this machine (`TorusMesh` with 48 rings, the size set and the arrays built 500 times):

```
torus48 build us each: 175.3  box build us each: 4.7
```

So every disc telegraph on screen rebuilt about 175 µs of mesh a tick (the build lands in `after_process`), plus
the upload, while its radius never changes during a windup.

### (c) Frozen Shore

The fight at 1600 × 900 is 8.5 ms (GPU 3.0 ms): `view.actors` 382, the effects layer's drawers (`variant_views`
134, `status_visuals` 91, `glaive_view` 87), nothing outstanding. The still floor costs what the other biomes' do
(above). The Frozen Shore enemies' animations: frost spitter and glacier turtle are code-made `HordeAvatar` bodies
(`CanyonShoreBodies`), not skeletons or VAT; `--ab=no_anim` in (a) showed the AnimationPlayers are no large cost.
Not reproduced at the owner's 60 fps.

## What changed

1. **The views' reader keeps which form draws each shot for the tick** (`LatchedReader`: `projectile_is_bomb`,
   `_pellet`, `_disc`, `_dart`, `_void`, `_wave`, `_wisp` answered once per projectile per tick, as bits, dropped on
   every tick, note and settle). The answers are the sim's own (a test compares them every tick of a Seekers + Venom
   fight); no look changes. `--ab=no_kind_memo` turns it off.
2. **A telegraph's ring and edges are rebuilt only when their size changes** (`TelegraphViews._update`): the disc's
   `TorusMesh` radii when the radius differs from the one it was built at, a lane's four `BoxMesh` edges when its
   half-size differs. The meshes are the same as before at every tick; no look changes.
3. **The Seekers' trail motes hidden for the effects layer's sprites are not placed** (`SeekersView._place`): with
   the effects layer on, each mote is drawn as a sprite and its quad is hidden; its transform was still written
   every frame. No look changes.

## Result: the kind memo off against on, alternated (scene a)

`--spans --breakdown`, the same build with `--ab=no_kind_memo` (off) and without (on), alternated off, on, off, on:

```
== a_m_off1 exit=0 godot_before=6 godot_after=8
frames=976  avg_ms=15.377  p50_ms=13.633  p95_ms=28.854  p99_ms=48.052
== a_m_on1 exit=0 godot_before=8 godot_after=8
frames=1241  avg_ms=12.093  p50_ms=11.322  p95_ms=18.706  p99_ms=22.712
== a_m_off2 exit=0 godot_before=8 godot_after=6
frames=1132  avg_ms=13.253  p50_ms=13.126  p95_ms=19.695  p99_ms=24.557
== a_m_on2 exit=0 godot_before=6 godot_after=6
frames=1228  avg_ms=12.216  p50_ms=11.285  p95_ms=18.907  p99_ms=24.680
```

The sync buckets, µs a tick (the bucket's mean over the frames that synced):

| Run | `sync_all` | `view.attack_forms` | `view.seekers` | `view.glaives` | `view.bombs` | `view.scatter` | `view.lances` | `view.pulses` |
|---|---|---|---|---|---|---|---|---|
| off1 | 4,731 | 394 | 372 | 84 | 80 | 69 | 48 | 266 |
| on1 | 3,855 | 190 | 272 | 49 | 45 | 34 | 43 | 250 |
| off2 | 4,123 | 352 | 322 | 76 | 74 | 62 | 42 | 249 |
| on2 | 3,841 | 198 | 296 | 52 | 48 | 37 | 43 | 281 |

Both pairs agree: the shot views' sync fell by about 300–400 µs a tick (`attack_forms` halves, `glaives`, `bombs`,
`scatter` about −45 %), `sync_all` by 280–880 µs a tick. The average frame fell in both pairs (−3.3 and −1.0 ms),
but the base's own spread on this machine today is larger than that: the frame-time gain is an indication.

## Result: before against after, alternated, all three scenes

The step's four files as at `ee030910` (base) against the fix (fix), written into the same worktree before each run,
alternated base, fix per scene, twice (`build/s16_ab.sh`, not tracked); each run `--spans` only, the scene commands
above without `--breakdown --fx`. No other Godot ran before or after any of these twelve runs (`godot_before=0
godot_after=0`), but other agents may have started and stopped Godot runs in between; the owner was not playing.

```
== ab_a_base1 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=0
frames=1794  avg_ms=8.365  p50_ms=8.175  p95_ms=10.953  p99_ms=12.966
== ab_a_fix1 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=3
frames=1806  avg_ms=8.306  p50_ms=8.187  p95_ms=10.733  p99_ms=12.762
== ab_b_base1 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=0
frames=1092  avg_ms=13.750  p50_ms=13.174  p95_ms=20.556  p99_ms=25.778
== ab_b_fix1 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=3
frames=1166  avg_ms=12.868  p50_ms=12.636  p95_ms=18.151  p99_ms=22.602
== ab_c_base1 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=0
frames=2076  avg_ms=7.228  p50_ms=6.999  p95_ms=10.855  p99_ms=15.395
== ab_c_fix1 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=3
frames=2274  avg_ms=6.597  p50_ms=6.128  p95_ms=10.067  p99_ms=13.382
== ab_a_base2 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=0
frames=1783  avg_ms=8.418  p50_ms=8.234  p95_ms=11.117  p99_ms=13.115
== ab_a_fix2 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=3
frames=1785  avg_ms=8.408  p50_ms=8.200  p95_ms=11.316  p99_ms=13.557
== ab_b_base2 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=0
frames=1201  avg_ms=12.495  p50_ms=11.893  p95_ms=17.849  p99_ms=21.351
== ab_b_fix2 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=3
frames=1218  avg_ms=12.319  p50_ms=11.394  p95_ms=17.648  p99_ms=21.365
== ab_c_base2 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=0
frames=2211  avg_ms=6.788  p50_ms=6.444  p95_ms=9.727  p99_ms=12.988
== ab_c_fix2 exit=0 godot_before=0 godot_after=0 sha=ee030910 dirty=3
frames=2141  avg_ms=7.010  p50_ms=6.901  p95_ms=11.378  p99_ms=14.466
```

(`sha` is the worktree's HEAD; `dirty` counts the changed files under `src/`: 0 in a base run, the step's 3 in a fix
run.) The rest of each report (1 % low, GPU, spans in µs a frame, draw calls as the mean of the per-second samples):

| Run | 1 % low fps | GPU ms | `nodes_process` | `after_process` | `draw` | draw calls |
|---|---|---|---|---|---|---|
| a base1 / fix1 | 64.4 / 66.1 | 5.90 / 5.89 | 3,860 / 3,809 | 658 / 667 | 2,661 / 2,663 | 316 / 321 |
| a base2 / fix2 | 60.8 / 59.4 | 5.96 / 6.04 | 3,816 / 3,793 | 671 / 679 | 2,739 / 2,741 | 314 / 336 |
| b base1 / fix1 | 32.9 / 39.2 | 9.74 / 9.54 | 6,877 / 6,171 | 1,418 / 1,351 | 3,704 / 3,790 | 467 / 492 |
| b base2 / fix2 | 37.2 / 39.8 | 9.20 / 8.87 | 6,083 / 6,029 | 1,288 / 1,204 | 3,613 / 3,600 | 477 / 450 |
| c base1 / fix1 | 57.2 / 61.2 | 2.97 / 2.85 | 3,607 / 3,219 | 686 / 647 | 2,063 / 1,918 | 357 / 335 |
| c base2 / fix2 | 64.7 / 58.8 | 2.89 / 2.93 | 3,328 / 3,630 | 630 / 580 | 1,952 / 1,927 | 318 / 300 |

Every frame-time difference is inside the base's own spread (a: 8.365–8.418 ms; b: 12.495–13.750 ms; c:
6.788–7.228 ms): **no frame-time gain is shown**. Starfall's `after_process` (where a rebuilt mesh lands) is lower in
both pairs (−67 and −84 µs), the size of a few disc rings a second, also inside the noise of one run. Two things these
quieter runs show: Seekers + Venom at 2560 × 1440 runs at 8.4 ms (about 119 fps), and Starfall's GPU time (8.9–9.7 ms)
is now most of its frame: at 2560 × 1440 Starfall is close to GPU-bound.


## Causes found and not fixed

| Cause | Where | Size here | Why not here |
|---|---|---|---|
| A Needle's bent telegraph lanes worked out on every tick of its windup (a wall test every 4 ticks of each shot's flight) | `EnemyAi.burst_lines` → `StarfallKinds.bent_lanes` (sim, read by the views through `reader.telegraph`) | 838 µs a frame mean, 4.6 ms p99, in Starfall | sim code; the lanes could be worked out once a windup (they change only if a Gravity Node moves or dies) |
| The Seekers' homing steered in GDScript for every projectile each tick | `NativeShots.sweep` → `ProjectileMoves.steer` (sim) | about 650 µs a tick with Seekers at level 5 | sim code; a native kernel would be `native/` |
| Five of Starfall's seven roster kinds are a node tree and a GDScript avatar each | `ActorViews` (`EnemyBatch.KINDS` holds nine kinds) | `view.actors` 1.2 ms a frame at 35 enemies | batching more kinds is its own step (the batch, the native crowd writer and their proofs) |
| The hero's effects layer drawn in GDScript every frame, piece by piece | `ImpactFx.draw`, `FireballViews.draw_lights`, `StatusVisuals._draw_vfx` | 229 / 186 / 113 µs a frame in scene a | `fireball_views.gd` belongs to a parallel step; the others are many small draws, no single fix |
| Starfall's GPU time | volumetric fog, SSIL, glow at 2560 × 1440 | 8.2 ms against 5.2–5.6 ms in Red Canyon | the Options/graphics step (17) owns the graphics settings |

## Interpretation

On this build and this machine, none of the three scenes drops to the owner's numbers: Seekers + Venom costs about
1–3 ms over the Gun alone (8.4 ms at 2560 × 1440 on the quieter runs), and every scene runs at about twice the owner's
frame rate. The fixes take 300–400 µs a tick off the shot views' sync in a Seekers fight (measured in script time,
both alternated pairs agree) and stop a disc telegraph's ring being rebuilt (about 175 µs each) on every tick, with
no change to any look and none to the sim. In frame time the alternated before/after shows no gain beyond the spread:
the fixes are real but small against the frame, and they do not explain the owner's numbers. The causes that are
large here are not in this step's reach (the table above): a Needle's bent telegraph and the Seekers' homing in the
sim, the unbatched Starfall kinds, the per-piece effects drawing, Starfall's GPU time. The next evidence is the owner's
own fights on this build (a perf log, PERF_LOG.md), with the build they played named.
