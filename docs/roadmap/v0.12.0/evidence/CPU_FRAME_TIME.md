# CPU_FRAME_TIME: where the main thread's frame goes on the owner's PC, and what this step made cheaper

- **Status:** RUN (indications: another session ran Godot on the machine during part of it, see each run's load line)
- **Build:** before: `aad6ce07` (branch `lead-v0120`); after: the working tree of `v0.12.0 Step 38` on parent
  `aad6ce07` (branch `v0120-s38`), the debug native library copied from the main checkout (no native change);
  Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200; Forward+, Vulkan 1.4.351
- **Machine:** the owner's PC (i7-10700K, RTX 3060), driven by an agent
- **Date:** 2026-11-19
- **Who ran it:** agent
- **The before runs** were made in the same worktree with `src/` stashed (`git stash push -- src/`), right after the
  after runs; the probe scripts were the same in both.

The owner's frame (perf log `perf_20261119_113014`, play frames): 13.7 ms, CPU-bound 74 %. Owner-only: how the game
feels after this step on their PC (OWNER ONLY).

## 1. The "other nodes' _process" (2.5 ms in the log's summary)

**The summary's split was wrong.** `summarize_perf.py` took every timed bucket (the sim and the `ticked` listeners
included) off the process step, but the sim's ticks and their listeners run in the physics steps
(`SimDriver._physics_process` → `step_once`). Fixed; the owner's log summarized again with the fixed script:

```
C:/Users/extri/AppData/Local/Python/pythoncore-3.14-64/python.exe -I scripts/perf/summarize_perf.py \
  "C:/Users/extri/AppData/Roaming/Godot/app_userdata/Zero Depth/perf/perf_20261119_113014.csv"
- **Main thread, in order**: the process step 7.10 ms (the views' sync and its listeners 3.17, the rest of the nodes'
  _process 3.93), after it until the draw 1.29, the draw 3.43, then until the next step (events, input, a frame cap)
  0.28, the physics steps 1.60 (the sim's ticks and their listeners 1.41, the engine's own 0.19).
```
The rest of the nodes' `_process` is 3.9 ms, not 2.5 (the perf recorder's own 0.6 ms a frame is in it).

**Which nodes.** The frame probe's `--process` (every script node's `_process` timed from the probe; it adds its own
cost, so proportions only):
```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-s38b "$GODOT" --path . --position -10000,-10000 \
  --resolution 2560x1440 --windowed -s scripts/checks/frame_probe.gd -- --biome=starfall --enemies=35 --secs=20 \
  --warm=3 --size=2560x1440 --breakdown --process
frames=846  avg_ms=23.644  p50_ms=23.393  p95_ms=30.776  p99_ms=35.407   (sha=aad6ce07, 172 script nodes with a _process)
  script.attack_form_view.gd        1583 us a frame   (the effects layer: every effect sprite laid out each frame)
  script.vat_crowd.gd                545
  script.stone_thrower_avatar.gd     237   (one node)
  script.empty_draw_cull.gd          223
  script.player_avatar.gd            217
  script.shard_views.gd              128
  script.horde_avatar.gd              97
  script.dps_meter.gd                 90   (the Playground only)
  ... 128 scripts, 4,459 us in all; the avatars 999 us
```
The effects layer (`AttackFormCanvas._process` → `VfxCore.finish`, every drawer) is the biggest: per-sprite GDScript
work at the frame rate. Its RenderingServer writes are not the cost: a micro-bench (400 instances, 3 setters each)
measured 78–81 µs, and filling one buffer in GDScript instead 160 µs, so the writes stay. No idle node was found
processing for nothing among the files this step may touch; the avatars, `vat_crowd.gd` and `actor_views.gd` belong to
the model steps running in parallel and were not touched.

Fixed here:
- `EmptyDrawCull` told the renderer every pool's visibility every frame (one RenderingServer call a pool a frame); it
  now tells it only when a pool's answer changes.
- The fire props' flames (`WorldViewRoot._draw_prop_fires`, 265 µs a frame in the owner's log, the costliest drawer in
  play): a fire wholly out of the picture (`ScreenCull`) is not laid out, and each fire's fixed numbers (its flames'
  feet, beat, height, frame period) are worked out once instead of every frame (same sums, same pixels).

Measured in a real floor (`scripts/checks/ui_spike_probe.gd -- --only=walk`: floor 1, the hero circling the arrival
room for 600 frames, 2560 × 1440; the three runs back to back, `src/presentation/world_view/` stashed in part):

| build | mean frame | `vfx.world_view_root._draw_prop_fires` (µs a frame) | other Godot processes at start |
|---|---:|---:|---:|
| before (neither) | 6.94 ms | 123 | 2 |
| the cull only | 7.00 ms | 86 | 2 |
| the cull and the fixed numbers | 6.95 ms | 73 | 0 |

The drawer is 41 % cheaper; the frame's mean does not show it at this size (noise).

## 2. The physics steps (1.6 ms)

The game has no Godot physics: the census reads `phys3d 0, phys2d 0` (no body, area or shape in the tree), and only
`SimDriver` and gallery/shot tools have a `_physics_process`. The physics steps are the sim: in the owner's log they
are 1.60 ms a frame, of which `step_once` (the sim's tick 0.90 and its `ticked` listeners 0.46) is 1.41 ms; the
engine's own 0.19 ms is the physics interpolation's tick and the empty physics step. Nothing to remove: the physics
interpolation is what smooths the 60 Hz sim at 144 fps (the views rely on it, see `physics_interpolation_mode` across
`src/presentation/world_view/`); switching it off would change the look.

## 3. The views' sync and the listeners

The owner's log, per frame: the views' sync 2.51 ms (`view.actors` 0.71 of it, `actors.update` 0.43), the HUD
(`frame.main.gd._on_frame`) 0.77, the audio director's tick sync 0.25. Below `view.actors` the sync is a long tail of
about 80 views at 10–120 µs each (`sync.occlusion` 119, `view.attack_forms` 117, `view.rewards` 57, `view.pulses` 51,
`view.telegraphs` 51, ...); `hud.kit` 206, `hud.minimap` 102, `hud.top` 86. No single view holds a large waste;
`view.actors` sits in `actor_views.gd`, which the parallel model steps are editing. NOT DONE in this step.

## 4. The Seekers' homing (`phase.proj.steer`, 14–34 ms stutters in the oldest log)

Not moved to C++: the cost was found in GDScript algorithms that could be made cheap with the same results, and an
exact C++ port would need the actor grid's query order too. Three changes, every result the same:
- `SeekerMods.pick` scanned the whole hit list once per enemy near the dart (`_hit_before`); it reads the dart's hits
  once into a set.
- It kept every candidate in an insertion sort; it now picks the one at its rank (`_nth_nearest`: the float32
  distances order every candidate whose stored distance differs; only candidates sharing the picked distance are
  placed the insertion's way, so ties land exactly where the sort put them).
- The query and the dart's filter are one pass (the same grid query, order and distances as `World.enemies_near`).
- `Seekers.target`'s hero-centred pick is kept by rank while the shots steer (`World.seek_memo`, on only inside
  `NativeShots.sweep`'s steering loop; nothing moves or dies there; not hashed, not saved).

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-s38b "$GODOT" --headless --path . -s scripts/checks/attack_phases.gd \
  -- --enemies=40 --ticks=1800 --cards=gun_seekers:5,split_shot:5,gun_pierce:5,gun_twin:5
```
(`--cards` is new in `attack_phases.gd`, the frame probe's option.)

| build | `proj.steer` mean / p99 / max | `step` mean / p99 / max | outcome_hash |
|---|---|---|---|
| before (`aad6ce07`) | 2.920 / 6.431 / 8.366 ms | 4.010 / 8.504 / 12.211 ms | `c8483f3a16198ba7…6383e9` |
| after | 1.857 / 3.921 / 4.778 ms | 2.957 / 6.118 / 8.368 ms | `c8483f3a16198ba7…6383e9` |

Raw before: `proj.steer mean 2.920 p99 6.431 max 8.366 ms`, `step mean 4.010 p99 8.504 max 12.211 ms`,
`outcome_hash c8483f3a16198ba7cdb49de81d5e2cf99fe3576a710c1c4e22eff04bed6383e9 final_tick_hash
fcd5d180501d58b091e1627c6fcca69ca47761a088fad7ecb14c360f18ba8a84`. Raw after: `proj.steer mean 1.857 p99 3.921 max
4.778 ms`, `step mean 2.957 p99 6.118 max 8.368 ms`, the same two hashes. mean_projectiles=68.7 in both.
The steering is 36 % cheaper; the tick 26 %. The hashes are equal: the same game.

## 5. The one-frame spikes

`scripts/checks/ui_spike_probe.gd` (new): the real game (main.tscn, floor 1, Blade), E opens the shop and an altar's
pick, a boss spawned beside the hero; the slowest frame of the 14 after each and the buckets:
```
APPDATA=... "$GODOT" --path . --position -10000,-10000 --resolution 2560x1440 --windowed \
  -s scripts/checks/ui_spike_probe.gd -- --rounds=4 --only=shop,pick,boss,walk
```
Fixed:
- The shop built and freed all its card boxes in its open frame (and again on every buy or reroll). Its boxes are now
  built ahead (behind the loading cover, and in the frames after a render), and the replaced ones freed one a frame.
- The card icons were read from disk the first time a card showed (about 2 ms each). `AstralCardArt.warm_icons` asks a
  loader thread for every icon as the HUD is built (210 icons, 256 × 256 lossless: about 52 MB of video memory).

| what | before (`hud.shop` / `hud.rewards` ms, rounds 0–3) | after |
|---|---|---|
| shop open | 53.4, 24.8, 20.7, 15.7 | 43.7, 12.3, 15.6, 13.0 |
| pick open | 25.4, 0.0 (under 1), 0.0, 43.0 | 20.7, 0.0, 0.0, 0.0 |
| slowest frame, shop | 85.9, 49.1, 39.5, 30.6 | 75.7, 26.3, 32.6, 27.8 |
| slowest frame, pick | 40.7, 9.0, 9.7, 54.9 | 35.8, 9.8, 9.0, 10.0 |

The first open of each still costs 20–45 ms: the text (the fonts' glyphs drawn the first time) and the cards' first
layout. NOT DONE.

**A boss appearing** (`actors.spawn` 27–31 ms the first time a kind appears, before and after): built in
`ActorViews._make_actor` and the boss avatars, which the parallel model steps are editing. NOT DONE; the fix is to
build the floor's boss once behind the loading cover (`ShaderWarmup` builds the horde kinds the same way).

## 6. Video memory, and the Night Rocks freeze

`scripts/checks/texture_census.gd` (new): floor 1 of a Blade run (Night Rocks), every texture the scene's nodes use,
its size estimated from its import (the renderer's texture_mem_used counts everything, render targets included):
```
textures the scene's nodes use: 70, about 554.1 MB (estimated from their size, import and mipmaps); the renderer's
texture_mem_used: 2176.0 MB (all textures, render targets included)
by folder: res://assets/models/shop 341.3 MB, res://assets/textures/vfx 120.0 MB, res://assets/models/kit 57.3 MB, ...
   341.33  8192x8192  lossless+mips  res://assets/models/shop/shop_tent_Color_d95e3a75-f7a5-437f-a2f1-abaede581843.jpg
     5.33  1024x1024  lossless+mips  res://assets/textures/vfx/fx_crystal_shatter.png   (and 34 more at 1024, lossless)
```
- **One texture is a sixth of the video memory:** the shop tent's 8192 × 8192 colour map, imported lossless with
  mipmaps (about 341 MB). Seen from the iso camera the tent covers a few hundred pixels, so the GPU samples its
  1024-or-smaller mip levels anyway: `process/size_limit=2048` (or VRAM compression) in its `.import` would free about
  320 MB with no visible change. Not changed here: assets and their imports belong to the model steps running in
  parallel. For the lead.
- The VFX sheets and the kit models' 1024 maps are lossless (4 bytes a pixel); VRAM compression would quarter them
  (about 130 MB) at a small change of look, for the owner to judge.
- About 1.6 GB of the 2.2 GB is not textures the scene's nodes hold: render targets at 2560 × 1440 (SSIL, SSAO, glow,
  the depth and colour copies), the shadow atlases (4096 positional, 4096 directional), the pack effects' textures
  and the fonts. Not split further: NOT YET RUN.
- The Night Rocks freeze (170–350 ms frames at 1185–1220 s of `perf_20261119_110215`): NOT YET RUN.

## 7. The frame probe before and after (the Playground, the Gun, 35 enemies)

```
APPDATA=... "$GODOT" --path . --position -10000,-10000 --resolution 2560x1440 --windowed \
  -s scripts/checks/frame_probe.gd -- --biome=<b> --enemies=35 --secs=20 --warm=3 --size=2560x1440 --spans --breakdown
```
| scene | before avg / p50 / p95 / p99 ms | after avg / p50 / p95 / p99 ms |
|---|---|---|
| Starfall | 16.531 / 16.768 / 24.529 / 30.773 | 18.058 / 17.063 / 26.948 / 36.631 |
| Frozen Shore | 15.703 / 15.585 / 22.227 / 27.991 | 15.388 / 15.156 / 22.245 / 32.738 |

No Godot process of another session at the start or the end of either set (`tasklist`: 0). The difference is noise
in both directions: every bucket the step did not touch (the sim's tick, the views' sync) moved by as much (Starfall
`sim_step` 1,301 → 1,423 µs, `sync_all` 3,972 → 4,624 µs). The Playground's scene has no Seekers, no shop and few fire
props, so this step's changes barely reach it. The owner's own perf log after this step: NOT YET RUN (OWNER ONLY).

## What is left (biggest first)

1. The effects layer's per-frame layout (1.6 ms a frame in the probe): GDScript per sprite at the frame rate. A native
   drawer, or laying the sprites out once a tick and letting the shader animate them, would be the next big cut.
2. The avatars (1.0 ms) and `vat_crowd.gd` (0.55 ms) per frame, and `view.actors` (0.7 ms a tick): the model steps'
   files.
3. The shop tent texture (320 MB of video memory) and the lossless 1024 maps.
4. The first open of the pick and the shop (20–45 ms: glyphs, first layout) and a boss's first build (27–31 ms).

## 8. The effects layer (Step 40)

- **Status:** RUN, indications only: another session's Godot processes ran during every run (the counts below), so
  the quiet-machine protocol (`PERF_TOOLS.md` §2) was not met.
- **Build:** base `259980cd` (branch `lead-v0120`); after: the working tree of `v0.12.0 Step 40` on parent `259980cd`
  (branch `v0120-s40`); the debug native library copied from the main checkout (no native change). The base runs were
  made in the same worktree with `src/` and `tests/` stashed, alternating base and after.
- **Machine:** the owner's PC (i7-10700K, RTX 3060), driven by an agent. **Date:** 2026-11-19.

**Where the layer's time goes.** `script.attack_form_view.gd` (`AttackFormCanvas.draw_at`) is mostly not the attack
forms' own layout: split with temporary buckets (removed again), about 90 % of it is `VfxCore.finish`, the drawers every
view hands the layer, and inside them the pack scenes' spawns. One base run, Seekers + Split Shot + Venom Core at L5:
```
script.attack_form_view.gd 1651   afc.vfx_finish 1468   (the canvas's own forms, bolts, begin and pools: about 180)
vfx.hero.impact_fx.draw     481   imp.spray 182, imp.sparks 120, imp.hitpack 121 (3 impacts drawn a frame)
vfx.status_visuals._draw_vfx 308  st.poison 246 (12 poisoned enemies a frame: the held cloud's touch 123, bubble spawns)
vfx.canyon_shore_views 128, vfx.variant_views 123, vfx.fireball_views.draw_lights 114, vfx.finish_rest 101
core.put 150 for 54 sprites a frame (every pool's per-sprite write together)
pk.spawn 349 a frame (609 in the 430 of 751 frames that spawned): take 140 (put back in the tree 86, new instances),
         restart 95, colour 88
```
So the per-sprite layout and its MultiMesh writes are a small part (`core.put` ~150 µs for every sprite); laying the
sprites out once a tick with a shader would save little at the owner's ~73 fps and nothing of the spawns.

**What changed (no look changes, EI-07):**
- `ImpactFx`: each impact's spark and spray flight (direction times reach) is worked out once (again when a merge makes
  it stronger), not every frame; the same sums in the same order, so the pieces land on the same spots
  (`spray_at` shares the helper).
- `HitPack.state`: int keys per layer instead of a new `[layer, tag, seed]` array per call, and the prune at most once a
  tick (it ran on every new hit while more than 48 young instances were remembered; an instance past `PRUNE_TICKS` is
  new whether kept or not, so nothing drawn changes).
- `PackFx`: a pooled instance spawned again in the colour it holds skips the controller's setters (they rewrite every
  material); the last `REST_PER_ID` (4) released instances of an id rest in the tree, hidden, for `REST_MS` (1 s) before
  they are parked outside it, so a hit or a bubble that spawns again soon does not leave and rejoin the tree.
- `VfxCore`: a floor mark's decal is placed only when it starts showing a mark (its fade still every frame); the probe's
  drawer bucket names are built once per drawer, not every frame.

**Before / after** (`--process --breakdown`, Starfall, 35 enemies, the cards above, 2560 × 1440, off screen, one process):
```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-s40 "$GODOT" --path . --position -10000,-10000 --resolution 2560x1440 \
  --windowed -s scripts/checks/frame_probe.gd -- --biome=starfall --enemies=35 --secs=20 --warm=3 --size=2560x1440 \
  --process --breakdown --cards=gun_seekers:5,split_shot:5,venom_core:5
```
| run (in order) | Godot lines in `tasklist` before / after | avg frame ms | `attack_form_view.gd` µs | impact_fx | status_visuals | finish_rest | variant_views | fireball_views |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| base 1 | 6 / 2 | 28.264 | 1,424 | 382 | 279 | 96 | 82 | 91 |
| after 1 | 2 / 6 | 28.677 | 1,509 | 260 | 239 | 92 | 322 | 155 |
| base 2 | 6 / 6 | 29.250 | 1,733 | 396 | 294 | 114 | 186 | 166 |
| after 2 | 6 / 4 | 26.309 | 1,197 | 221 | 213 | 77 | 187 | 125 |

(An earlier base run of the same command, before any change: 1,366 µs, 6 Godot lines at its start.)
- The drawers this step changed are lower in both after runs: `impact_fx` 382–396 → 221–260 µs (about −37 %),
  `status_visuals` 279–294 → 213–239 (about −20 %), `finish_rest` 96–114 → 77–92.
- **The layer's total is inside the spread** (base 1,366–1,733 µs, after 1,197–1,509): the scenario is not the same
  from run to run (which enemies and variants spawn, how many pack scenes start), and drawers this step did not touch
  (`variant_views` 82–322, `fireball_views` 91–166, `canyon_shore_views` 81–205) move by more than the gain.
- **The target (under ~0.4 ms) is missed.** What is left is spread over about 25 drawers in other views
  (`canyon_shore_views` and others belong to the parallel model steps) and the pack scenes' spawns (engine work:
  restarting particles and animations); a native drawer would take neither. Not built; the lead decides.

**Still frames** (`--fixed-fps 60 --shot-at=N:<png>`, frames 420 and 600 of the scenario, base then after): the same
moment, the same impacts, sparks, poison clouds and bubbles, floor marks and seekers in both; the files are not
byte-identical (the pack's GPU particles differ in small places, e.g. the smoke round a frozen enemy). A same-build
repeat to show that variance: NOT YET RUN. Owner-only: whether anything looks different in play (OWNER ONLY).

**Owner, 2026-11-19, on the pooled effects resting hidden in the tree for 1 s before parking (a change to the v0.10.5 PC_POOLS rule that idle instances wait outside the tree):** "Yes, allow it".
