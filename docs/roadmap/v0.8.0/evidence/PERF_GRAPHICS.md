# v0.8.0 — performance and graphics (owner O86)

The owner's feedback files: [`feedback/2026-10-19_perf_and_wand_math.md`](../feedback/2026-10-19_perf_and_wand_math.md)
and [`feedback/2026-10-19_graphics_upgrade.md`](../feedback/2026-10-19_graphics_upgrade.md). No fps or frame time is
measured in the cloud (CLAUDE.md "No timing on a busy machine"): the owner runs the fps test on their own machine.

## FS — the stage's shadows and ground

**Question.** Can the stage draw the same picture with fewer shadow-atlas rebuilds, a smaller sun shadow map and far
fewer ground nodes? (perf review Part 2 items 2, 3, 4, 8; graphics file §2.)

**Build.** Branch `v080-fs` from `d2ae864` (head of `claude/perf-graphics-v080`). The runs below were on `d2ae864` plus
the uncommitted Step FS diff. The commit is the one that adds this section.

### Findings checked against this branch first

| Item | On this branch before FS | Done |
|---|---|---|
| 2: shadow omnis re-picked every 15 frames | Still true (`PICK_EVERY := 15`). P3 had already added the fade, the 4-caster budget and a flat 1.5 m keep margin | The casters are re-picked every 60 frames (`SHADOW_PICK_EVERY`), or at once when a caster leaves the view's reach. A light keeps its shadow until another is nearer by 2.5 m + 20 % of its distance. The view fade still runs every 15 frames; fade, budget and flicker unchanged |
| 3 / graphics §2: sun shadow 8192 | Still 8192 | 4096 (the two files disagree, 4096 vs 2048; 4096 taken, the owner judges from the shots). Filter quality 4 and `SHADOW_BLUR` unchanged |
| 4: a PlaneMesh + MeshInstance3D per ground tile | Still true | One MultiMeshInstance3D per material, one shared unit plane, each instance scaled to its clipped tile. Checker is flat colour; textured ground is world-space triplanar, so scaling doesn't change its mapping |
| 8a: `Color("#FF2A22")` parsed every frame in `horde_visuals._process` | Still true | Hoisted to `MINE_LIGHT_HI` / `MINE_LIGHT_LO` consts |
| 8b: `attack_form_view` key formatted per projectile | Already fixed by PF (the digest/tier signature is checked once a sync) | Skipped |

### Ground count (deterministic)

Command (scratch script outside the repo, Ruins mood, the probe's floor):

```
godot --headless --path . -s /tmp/claude-0/-home-user-zero-depth/3f8d7839-8540-5f57-8a00-ef0898d2b68a/scratchpad/fs/ground_count.gd
```

Raw output:

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
ground_rects=76 tiles=2475 old_nodes=2475 old_planemeshes=2475 new_ground_nodes=1 new_instances=2475 new_meshes=1
```

On this floor the old code made 2475 MeshInstance3D nodes and 2475 PlaneMeshes for the ground. The new code makes 1 node,
1 mesh and 2475 instances. `old_*` is the tile count the old loop would have made one node and one PlaneMesh each for
(same loop, same rects).

### Tests

```
godot --headless --path . --editor --import --quit
```
exit 0.

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_stage_kit_lights.gd,res://tests/unit/presentation/test_stage_ground.gd,res://tests/unit/presentation/test_stage_mood.gd,res://tests/unit/presentation/test_view_build_queue.gd,res://tests/unit/presentation/test_deep_look.gd,res://tests/unit/presentation/test_frozen_shore.gd,res://tests/unit/presentation/test_starfall.gd -gexit
```
```
Scripts               7
Tests                37
Passing Tests        36
Failing Tests         1
Asserts           226338/226348
Time              139.015s
```
The one failure was the new `test_stage_ground.gd`. It read the tiles back with `MultiMesh.get_instance_transform`, but
headless the RenderingServer doesn't keep them (every transform came back as identity: `[6.0] expected to equal [58.5]`
for the covered area). The tile geometry moved into a pure `StageView.room_ground_cells` that the build uses, and the
test reads that. Re-run of that file after the fix:

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_stage_ground.gd -gexit
```
```
Scripts               1
Tests                 2
Passing Tests         2
Asserts              26
Time              0.008s
```
The six other files were not re-run after that refactor. It moved the loop into a function, with the same code.

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_floor.gd,res://tests/e2e/test_e2e_lighting.gd,res://tests/e2e/test_e2e_arenas.gd -gexit
```
```
Scripts               3
Tests                 5
Passing Tests         5
Asserts             116
Time              51.892s
```

Lint: `gdlint src scripts tests` gives `Success: no problems found`. `gdformat --check src scripts tests` flags only
`src/presentation/world_view/boss_door_view.gd`, which already fails at `d2ae864`, untouched here.

### Shots: sun shadow 8192 vs 4096 (for the owner)

Ruins, the probe's floor, the start room. Software Vulkan (llvmpipe) under xvfb, **not** the owner's GPU. The 8192 run
used `project.godot` set back to 8192 for that run only, then restored to 4096.

```
xvfb-run -a godot --path . --audio-driver Dummy --resolution 960x540 -s scripts/checks/biome_probe.gd -- biome=ruins spots=1 light_spot=1 frames=1 settle=8 shot=1 tag=fs_4096
xvfb-run -a godot --path . --audio-driver Dummy --resolution 960x540 -s scripts/checks/biome_probe.gd -- biome=ruins spots=1 light_spot=1 frames=1 settle=8 shot=1 tag=fs_8192
```

Raw scene lines (identical in both runs):
```
biome_probe: biome=ruins seed=20261008 floor=1 spots=2 frames=1 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
scene: nodes=2017 omni_lights=105 (kit fire lights 62) spot_lights=0 particles=3
draws           519.500   597.000   597.000
objects         571.500   632.000   632.000
omni_shadow       4.000     4.000     4.000
```
The probe's timing lines are noise on this machine and are not evidence. `compare -metric AE` between the two PNGs:
15128 pixels differ (of 518400).

- [`fs_shots/ruins_0_8192.jpg`](fs_shots/ruins_0_8192.jpg): before (8192)
- [`fs_shots/ruins_0_4096.jpg`](fs_shots/ruins_0_4096.jpg): after (4096)

No render from before the ground change was taken (CLAUDE.md "No baseline copies"). The textured ground runs on
continuously across tiles in the 4096 shot. One lighter square patch near the bottom-left (about x 150, y 470) wasn't
checked against an older render.

### Lead check: the ground against the owner's reference (O88)
FS's 960×540 shots above read brighter and flatter than the reference. Cause: the container had no Vulkan driver, so
Godot fell back to `gl_compatibility` (log: `renderer=gl_compatibility`, "SSIL is only available when using the
Forward+ renderer"). The lead installed `mesa-vulkan-drivers` (lavapipe) and re-shot FS's tree (`696db2ce`) with the
reference's tool and room:
```
XDG_DATA_HOME=<empty dir> VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_2x2_1 out=fs
room_layouts: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1600, 900) biome=ruins targets=[[&"room_2x2_1", 20261031, 2]] missing=[]
room_layouts: room_2x2_1_ruins seed=20261031 floor=1 room=2 cells=(2, 2) size=27.4x25.3 m turn=0 mirror=1 props=586
```
[`fs_shots/ruins_room_forward_plus.jpg`](fs_shots/ruins_room_forward_plus.jpg) beside
[`mi_shots/ruins_room.jpg`](mi_shots/ruins_room.jpg): by eye the same ground, light pools and shadows (no pixel diff
made). The 8192/4096 pair above was rendered in `gl_compatibility`; it still shows the shadow-size difference, but not
the game's real look.

### Owner-only

| Target | Status |
|---|---|
| fps / frame time on the owner's PC, before vs after FS | NOT YET RUN (owner hardware) |
| 4096 sun shadow edges acceptable (vs 8192) | OWNER ONLY |
| No visible change in the ground, shadows and torch light | OWNER ONLY |
## FV

**Owner lines.**
- O86: "Two files of new feedback to reduce fps and upgrade graphics … I'll do the fps test on my own machine you
  don't need to run them".
- O87: "the main problem is that when a visual op build hits a horde of enemies the game lags, so we are trying to fix
  how the fps drops when a lot of enemies are being hit with explosions fires and multiple attacks at the same time".

The source is `feedback/2026-10-19_perf_and_wand_math.md` Part 3, which was written against old `main`. I re-checked
each item against `claude/perf-graphics-v080` at `d2ae864`.

**Build:** branch `v080-fv` from `d2ae864`. The code under test is this step's commit (amended from a local WIP), including the probe, status and
Charger changes. Godot `4.7.2.stable.official.ed1daf0bf`, headless, on a cloud machine with 4 CPUs.

### What was already done (skipped)
- **The explosion build's frame budget (PF):** the first 12 bursts of a frame draw in full, nearby ones merge after
  that, the next ones are thinned, and none are drawn past 32. `BurstBudget` keeps at most 32 bursts alive and the
  sim caps player shots at 256. Part 3's "Twin + Explosive" burst case was largely covered by this; FV adds the light
  merge on top.
- **Shocked enemies:** they already asked for no light (`_lightning(..., lit = false)`).
- **Frosted enemies:** they never had a light.
- **Decals, glow and damage numbers:** left alone, as the brief said. The probe shows `DamageNumbers` at 0.09 ms per
  tick, so it is not a hot spot.

### What changed (presentation only; no sim, data or golden change)
1. **Merged lights** (`VfxCore._light` → `_light_merged`, `LIGHT_MERGE_M` = 2.5 m):
   - Every element's field, ring, line and burst now joins a light of the same colour within 2.5 m. This was already
     the fire patches' rule. Only the exact same colour merges: warm fire, explosions and burning enemies merge with
     each other, while cold storm, ice, venom, blood and void each stay separate.
   - A lone effect's light is unchanged.
   - Each merge brightens the shared light by 1.08x, now capped at `LIGHT_MERGE_BOOST_MAX` (1.3, a starting value)
     times the brightest light in the group. Before, the boost had no limit: 40 burning enemies in one spot would have
     reached about 1.08^39, roughly 20x. Fire with up to three merges looks the same as before.
   - `_light_merged` now honours `_lights_off`. Before, a burst PF had thinned could still ask for a light through
     the merged path.
2. **Status lights budgeted** (`_light_status`, `_flush_status_lights`):
   - A burning enemy's light is gathered over the frame and laid in at its end, brightest first, with ties broken by
     place (x, then z).
   - Each one merges within 2.5 m. At most `STATUS_LIGHTS_MAX` (4, a starting value) new lights come from statuses;
     the rest are dropped.
3. **Pressure thinning** (`VfxCore._thin`, `PRESSURE` = 0.7, a starting value):
   - Once a pool is 70 % full, or the frame has used 70 % of `MAX_SPRITES`, an effect halves (rounding up) its
     explosion debris, smoke and sparks, its lightning-end sparks and embers, and its frost crystals (fields, rings,
     lines, bursts and frosted enemies) with their sparks and mist.
   - The blast, flash, bolts and flames are kept.
   - It reads only this frame's counts, in the callers' fixed draw order.
4. **O87 per-enemy fixes the horde probe pointed at:**
   - `StatusVisuals`: under the effects layer, each enemy with a status no longer builds its ~15 hidden box, prism and
     shell meshes (the layer draws embers, drips, crystals, sparks and the shell). The shock pips and guard orbs are
     built the first time they show.
   - `ChargerAvatar`: the body and leg meshes (geometry only; every colour is a per-instance material) are built once
     and shared, as the Warden's already were. Before, every respawned Charger rebuilt about 20 SurfaceTool meshes.
5. **The horde probe** (`scripts/checks/perf_probe.gd --horde[=N]`):
   - Setup: 110 live Chargers chase the hero and are topped back up (at most 8 a tick, at fixed spiral spots). The
     build is Twin, Split, Explosive, Cinder Shot, Static Chain, Ember Core and Wildfire, all at level 5. The hero
     can't be hurt and the aim turns once every 256 ticks.
   - Output: sim/sync/frame plus the per-view sync breakdown (`WorldViewRoot.profile_sync`, a plain call in the game),
     and per-tick counts.
   - **Probe fix:** the probe added a crowd avatar to its process list again every tick ActorViews turned it back on,
     so each avatar ran once per tick it had been near. The first horde run read `frame_ms` 567 ms avg because of this.
     The probe now rebuilds its list each tick (see "Probe bug" below).
   - The probe's `sync_ms` no longer includes the horde's top-up.

### Commands and raw results

**Tests (lint first):**
```
gdformat --check src scripts tests && gdlint src scripts tests
→ gdlint: Success: no problems found
→ gdformat: "1 file would be reformatted" = src/presentation/world_view/boss_door_view.gd, untouched by FV (already so at d2ae864)

godot --headless --path . --editor --import --quit            → exit 0

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<tests/unit/presentation/>test_vfx_pressure.gd,
  test_vfx_budget.gd,test_vfx_layer.gd,test_status_visuals.gd,test_vfx_interpolation.gd,test_attack_visuals.gd,
  test_attack_visuals_2.gd,test_hit_impact.gd,test_attack_forms.gd -gexit
→ Scripts 9, Tests 101, Passing Tests 101, Asserts 19122, Orphans 3, Time 91.024s

(after the StatusVisuals and ChargerAvatar changes)
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<tests/unit/presentation/>test_charger_avatar.gd,
  test_status_visuals.gd,test_vfx_layer.gd,test_damage_flash.gd,test_boss_views.gd,test_melee_strikes.gd,
  test_windup_tells.gd,test_hit_impact.gd,test_vfx_pressure.gd,test_vfx_budget.gd -gexit
→ Scripts 10, Tests 85, Passing Tests 85, Asserts 3365, Orphans 4, Time 39.011s
```

**Horde probe:**
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde --seconds=10 --tag=<tag>
```
- "before" is `d2ae864`'s `vfx_core.gd` and `vfx_layer.gd`, copied in for the run, with the fixed probe.
- "after" is FV.
- Both runs grant all 7 cards ("ok"). The sim's counts match exactly, so the sim was untouched: projectiles 20.887,
  events 13.060, hits 2.547, damage 3.173, kills 0.375, status_applies 4.440, damage 10794 over 10 s.

| metric (avg / p95 / max) | before | after |
|---|---|---|
| lights_asked (light requests a frame) | 39.560 / 65 / 72 | **7.618 / 11 / 11** |
| lights_merged | — | 27.655 / 43 / 45 |
| status_lights_asked / dropped | — | 27.768 / 53 / 57 ; 4.287 / 17 / 28 |
| lights_on | 9.860 / 10 / 10 | 7.523 / 10 / 10 |
| sprites_drawn | 550.503 / 780 / 902 | 550.503 / 780 / 902 |
| pieces_thinned | — | 0 / 0 / 0 (no pool reached 70 % in this build) |
| status_drawn (enemies with a status) | 27.807 / 53 / 57 | 27.807 / 53 / 57 |
| flashing / damage_numbers | 3.323 / 2.403 | 3.323 / 2.403 |
| sim_ms | 4.760 / 9.589 / 19.658 | 4.749 / 9.740 / 16.244 |
| sync_ms | 9.735 / 21.195 / 51.196 | 8.147 / 13.902 / 25.384 |
| frame_ms (CPU only, headless) | 8.553 / 15.878 / 31.896 | 8.642 / 12.620 / 16.824 |
| total_ms | 23.049 / 40.778 / 77.503 | 21.538 / 31.726 / 51.246 |

The ms rows are one run each on a busy 4-CPU machine. They rank the hot spots and are not measurements.
**The frame target: NOT YET RUN (owner hardware).**

**Ranking, raw (ms per tick, avg):**
```
before                                   after
frame cost by node:                      frame cost by node:
  ChargerAvatar      4.572                 ChargerAvatar      4.546
  AttackFormView     3.107                 AttackFormView     3.220
  PlayerAvatar       0.180                 PlayerAvatar       0.185
  HitFeel            0.118                 HitFeel            0.116
  BarChunks          0.112                 HeroPulseViews     0.107
  HeroPulseViews     0.107                 BarChunks          0.106
  DamageNumbers      0.089                 DamageNumbers      0.088
sync cost by view:                       sync cost by view:
  actors             4.181                 actors             3.158
  status_fx          1.343                 status_fx          0.784
  item_fx            0.739                 item_fx            0.738
  attack_forms       0.437                 attack_forms       0.425
  spikes             0.380                 spikes             0.385
  telegraphs         0.324                 telegraphs         0.320
  hit_feel           0.260                 hit_feel           0.250
```

### What the probe says is left (not changed; proposals)
1. **The sim:** 4.7 ms avg, 9.7 ms p95. I didn't change it (it would change goldens), and I didn't time inside it.
   PF's earlier phase timer put about 95 % of a Twin tick in `_projectile_hits`. Proposed next step: a probe-only
   phase timer on the horde, then a spatial grid for the projectile and explosion queries over N enemies. The
   outcomes stay the same; only the query order is a hash risk to check.
2. **`ChargerAvatar` animation:** 4.5 ms for 110 avatars, about 41 µs each, CPU only. ActorViews already stops
   animating avatars past `ANIMATE_RADIUS_M`. Proposal for the owner, since it changes the look: past the nearest
   ~40 enemies, animate at half rate (every other frame).
3. **`AttackFormView`:** 3.2 ms. This is the effects layer's frame (sprites laid out, lights, decals); the sprite
   count is unchanged.
4. **The GPU** is not in a headless frame: the fill rate of the additive sprites and the lights. Most of FV's light
   savings land there (39.6 → 7.6 light requests a frame; at most 10 lights are on at any time, but far fewer now
   compete). The owner's PC run shows that. Command for the owner:
   `godot --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde --seconds=10` (without `--headless` the
   wall time includes the draw), and `build/perf/perf_probe_horde.txt`.

### Probe bug (found here)
- `perf_probe._adopt` appended every node that was processing on each tick. ActorViews turns each near crowd avatar
  back on every sync (its off-screen LOD), so a near avatar was appended again every tick and ran N times by tick N.
- The first horde run read `frame_ms` 567.029 avg, with ChargerAvatar at 562.938 ms. The fixed probe reads 8.553 on
  the same code.
- The fix: the probe turns every node it took over back on before each sync, lets ActorViews turn the far crowd off,
  and runs each processing node once a tick.
- PF's dummy-only runs may have been affected only if dummies carry `enemy_avatar`. They were not re-run here.

## GX

Owner lines: O86 (the graphics feedback `feedback/2026-10-19_graphics_upgrade.md` §1, §3, §4, §5); O88 (2026-10-19):
"the image of reference for lighting is this one, improving graphics should be from there, the fog, better lighting or
particles and improvements, never going out of that" — the reference is
[`mi_shots/ruins_room.jpg`](mi_shots/ruins_room.jpg).

Build: branch `v080-gx` from `d2ae864`. Code at the WIP commit `69683756` (amended from WIP `3e57166a`, same code), plus this commit's data changes (height haze
`fog_height` 0.4 → 0.0 in Ruins, Night Rocks and Red Canyon; Night Rocks `volumetric_light_energy` 1.5 → 1.0), which
were made before the final shots and the tests below. Machine: cloud container, 4 CPUs, lavapipe (llvmpipe) Vulkan.

### What was built (all on the "high" lighting tier; "low" is unchanged)

- **Volumetric fog (§1).** `StageAtmosphere` (`src/presentation/world_view/stage_atmosphere.gd`) holds a FogVolume box
  that follows the view's focus, from 1 m under the floor up to the mood's `volumetric_height`. The Environment's own
  volumetric density is 0: an even density over the 48-72 m between the iso camera and the floor would black out the
  frame. The void never takes the fog (`volumetric_fog_sky_affect` 0). The fire props light it
  (`volumetric_light_energy`), the sun or moon barely (`volumetric_sun_energy`, 0 except Frozen Shore's 0.05).
  **Volumetric fog does render under the orthographic camera** (the shots below), so §6 (fake cones) was not needed.
- **Height haze (§4).** `fog_height` / `fog_height_density` mood fields. Godot has one fog colour, so the haze tints
  toward `fog_color`; it can't darken. To keep O88's look it is set only under the floor's level (`fog_height` 0): it
  touches Frozen Shore's sea (0.35) and nothing on the first three biomes' floors; Starfall 0 (its stars stay clear,
  ART_DIRECTION "no fog").
- **Embers and dust (§3).** One GPUParticles3D per kit light prop (28 warm additive soft dots, parented to the light,
  so it hides and stops emitting when StageKit fades the light out of the view's reach), one cool dust emitter
  (90 motes) over the view. Reduced motion freezes them.
- **Crystal glint (§5).** On this branch crystal roughness was already 0.12-0.24; metallic 0.2
  (`ShardMesh.CRYSTAL_METALLIC`) added to the room shards (ShardMesh, ShardCluster), CodeProps star crystal and ice,
  Starfall's drifting void crystals and the curse room's glow crystals; the owner's `star_crystal` and `ice_shard`
  .glb materials are glossed at load (`KitModels.GLOSS`, the files untouched). Stone stays matte.
- Mood values per biome in `data/biomes/*.tres`; ranges in `BiomeMood.problems()`; CONTENT_SCHEMA updated.

### Shots (one per biome, the reference's tool and room)

Command (per biome; `S` the agent's scratchpad):

```
XDG_DATA_HOME=$S/xdg VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/room_layouts.gd -- \
  biome=<id> only=room_2x2_1 out=gx
```

Every log line read `renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1600, 900)`, target
`[&"room_2x2_1", 20261031, 2]`, `missing=[]`. Side by side (before = `mi_shots/<biome>_room.jpg`, after = this build):
[`gx_shots/`](gx_shots/). The befores are earlier builds' shots of the same room, so props differ a little and the
numbers compare the frames' overall brightness, not GX alone. Luma per frame (each scaled to 720 px high; mean, standard
deviation, share of pixels under 20 of 255), from the agent's side-by-side script:

| Biome | Before | After |
|---|---|---|
| Ruins | mean=38.4 stddev=21.8 share<20=0.232 | mean=37.8 stddev=21.7 share<20=0.211 |
| Night Rocks (first shot, light energy 1.5) | mean=16.9 stddev=16.2 share<20=0.673 | mean=18.1 stddev=18.2 share<20=0.678 |
| Night Rocks (light energy 1.0, kept) | mean=16.9 stddev=16.2 share<20=0.673 | mean=16.8 stddev=17.0 share<20=0.716 |
| Red Canyon | mean=26.1 stddev=18.9 share<20=0.362 | mean=26.4 stddev=20.1 share<20=0.371 |
| Frozen Shore | mean=98.8 stddev=36.8 share<20=0.002 | mean=95.1 stddev=36.4 share<20=0.007 |
| Starfall | mean=50.1 stddev=30.0 share<20=0.218 | mean=49.2 stddev=29.7 share<20=0.215 |

Night Rocks' first shot read brighter (the torch fog spread a warm wash), so its torch fog energy was lowered and that
biome alone re-shot. The look against the reference: OWNER ONLY.

### Tests

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -ginclude_subdirs -gtest=res://tests/unit/presentation/test_stage_atmosphere.gd,res://tests/unit/presentation/test_stage_mood.gd,res://tests/unit/presentation/test_stage_kit_lights.gd,res://tests/unit/presentation/test_kit_models.gd,res://tests/unit/presentation/test_deep_look.gd,res://tests/unit/presentation/test_frozen_shore.gd,res://tests/unit/presentation/test_starfall.gd,res://tests/unit/presentation/test_curse_room_view.gd
Scripts               8
Tests                49
Passing Tests        49
Asserts           225066
Time              157.094s
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -ginclude_subdirs -gdir=res://tests/content
Scripts              26
Tests               134
Passing Tests       134
Asserts            9679
Time              29.732s
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -ginclude_subdirs -gdir=res://tests/arch
Scripts               2
Tests                 4
Passing Tests         4
Asserts           12233
Time              1.371s
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -ginclude_subdirs -gtest=res://tests/e2e/test_e2e_lighting.gd
Scripts               1
Tests                 1
Passing Tests         1
Asserts              15
Time              15.123s
---- All tests passed! ----
```

Lint: `gdformat --check src scripts tests` flags only `src/presentation/world_view/boss_door_view.gd`, already so at
`d2ae864` (not touched here); `gdlint src scripts tests`: `Success: no problems found`.

### Cost

fps High vs Low with the new atmosphere: `NOT YET RUN (owner hardware)`. The owner compares Options > Display >
Lighting quality High and Low on the same room.

## HV

**Owner line.** O89: "Okay let's go for all of them and I'll play and test how the game feels the target of these is
trying to optimize performance at maximum without losing the game vibe but not getting fps drops during the fun part
of the game, if not I'll tell you what to discard, if something is not going to be loaded when far make sure it is far
enough so it does not happen in the screen it should be for outside of the screen but lag mostly comes from shooting
hordes with multiple modifiers".

**Build:** branch `v080-hv` from `07af5d59`; the code under test is this step's commit (the working tree that became
it). Godot `4.7.2.stable.official.ed1daf0bf`, headless, a cloud machine with 4 CPUs. Presentation only: no sim, data,
content or golden change.

### What changed
1. **Unchanged material writes skipped.**
   - `ActorViews._set_flash` remembers, per actor id, the glow state it last wrote (`_shown`: lit, rest, or a tint's
     colour and energy) and returns at once when it is the same. A burning or frozen enemy got `set_tint` from
     `ItemVisuals._sync_burns` every tick, and each call rewrote emission on every body material.
   - `set_tint` keeps the stored tint when it hasn't changed. `flash()` on an actor that is already flashing only
     extends its frame count (`HitFeel` flashes on every DAMAGE event).
   - The guard keys on the state, not on how the material is written, so HR's shared materials can change the write
     underneath.
   - `ChargerAvatar`: the visor's `emission_energy_multiplier` is written only when it changes by more than 1e-4, and
     `_model.position` only when it changes.
   - `StatusVisuals`: the shock pips' `material_override` is compared before it is set. The per-tick Dictionaries are
     reused: the alive set, one entry per affected actor (its `on` swapped with a scratch dict), and a scratch dict that
     enemies with no status are read into. Before, a new Dictionary was built per actor per tick.
2. **Charger pose without Arrays.** `_pose_leg` used to build two duplicates, literal arrays and about five `_plus()`
   results per leg, a typed `segs` array, and three property writes per segment (about 40 Arrays per Charger a frame).
   - It now uses local floats, summed in the old order, and one `transform` write per segment and for the body.
   - `tests/unit/presentation/test_charger_pose_hv.gd` copies the old `_pose`/`_pose_leg` as the reference. It checks
     every transform with exact `==` on 7 states: still, walking, windup, charge, dazed, rising, mixed.
   - First run: the body and hips matched, but some segments were off in the last float bit. The cause was the test
     harness, not the pose. `setup()` had posed the reference nodes with one transform write, and a rotation set after
     that keeps a scale read back from the basis (0.99999994). The old code never wrote a transform, so its nodes always
     had an exact unit scale. The reference now puts each node's scale back to exactly one first, and every transform
     matches exactly.
3. **Off-screen culling** (owner rule: never visible on screen).
   - New `src/presentation/camera/screen_cull.gd`. `WorldViewRoot.sync` refreshes it each tick from the camera itself:
     its global transform (position, roll), `size` (with the flourish zoom), the shake and kick `h_offset`/`v_offset`,
     and the viewport aspect.
   - A point's gap is how far outside that rectangle it lands on screen. An orthographic projection never makes a
     distance longer, so a gap of g screen metres is at least g ground metres (about 1.7 g along the screen's vertical).
   - What is skipped, and when:

     | Thing | Skipped when the gap is over | Notes |
     |---|---|---|
     | Enemy model animation | 4 m (largest model, height included) + 6 m | stays on 2 m farther (hysteresis); replaces the 24 m circle round the hero, kept only for views with no camera (unit tests) |
     | Status VFX | actor radius + 3.5 m (flames; the status light's 3 m range) + 6 m | `StatusVisuals._draw_vfx` |
     | Flashes | size + 3 m + 6 m | `AttackFormCanvas` |
     | Landings | 3 × radius + 3 m (a burst's light reaches 3r + 2 m) + 6 m | `AttackFormCanvas` |
     | Live rings and patches | radius + 3 m + 6 m | `AttackFormCanvas` |
     | Live bolts | half the trail + (length + 1 m) × scale + 6 m | `AttackFormCanvas` |

   - A bolt with a tether back to the hero is never skipped, since its line can cross the screen. A skipped bolt still
     counts toward `LIVE_BOLTS_MAX`, so the same bolts get their rims as before.
   - When an enemy model turns back on, it runs `advance(0.05)` four times at once, then its own `_process` runs again
     before that frame is drawn.
   - `_first_sync` snaps the camera before the first sync too, so that sync culls against the right view.
   - `tests/unit/presentation/test_screen_cull.gd` checks:
     - the edge `ScreenCull` finds matches `Camera3D.unproject_position` (right edge at the viewport width, top edge
       at 0);
     - at the edge, and at edge + reach + margin − 0.1 m, an enemy model animates, a status draws and a flash draws;
     - past that, each is skipped;
     - the hysteresis band;
     - the tint and flash rewrite guards.
   - First run: the "coming back" check placed the enemy exactly on the threshold, which float rounding put just
     outside. It was moved 0.5 m inside.
4. **Attack-form CPU** (same output).
   - New `attack_forms/live_bolt_look.gd`: a live bolt's look fields are read once into typed fields, kept on the look
     under `&"hv_live"`.
   - The bolt is laid out with the pools in hand (`_put_in`) and a reused points Array. `_emit_parts(sd, …)` replaces
     the new Dictionary per bolt.
   - The pools are kept as lists (no `pools.values()` ×4 a frame), and the kept effects are swapped instead of rebuilt.
5. **Catch-up ticks: measured and reasoned, not changed.**
   - `project.godot` has `max_physics_steps_per_frame = 4`, and `main.gd` connects `driver.ticked` to `view.sync`. Below
     60 fps Godot runs about 60/F ticks a frame (1.5 at 40 fps, 2 at 30, at most 4), and the whole view sync runs for
     each. Headless `--fixed-fps 60` always runs one tick a frame, so this machine cannot show it.
   - The probe's new catch-up model replays Godot's step rule over the run's measured CPU costs. It is CPU only, uses
     this machine's timings, and ranks only:
     - before: frames with 0/1/2/3/4 ticks [0, 124, 104, 48, 31], 1.95 view syncs a frame;
     - after: [0, 209, 140, 33, 3], 1.56 view syncs a frame.
   - Syncing the heavy views once a frame is not provably safe:
     - the avatars' `strike_note` and `_track_motion` read per-tick state;
     - `AttackFormView._sync_bolts` builds trails from one point per sync;
     - `StatusVisuals._frame` counts syncs (it times the shock sparks);
     - physics interpolation needs a position written every tick.
   - Per the brief, it was left unchanged. On the owner's PC the dev panel's `ticks_last_frame` shows the real count.

### Tests (this step's tree)
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_charger_pose_hv.gd,res://tests/unit/presentation/test_screen_cull.gd -gexit
Tests                 9
Passing Tests         9
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<20 files: test_charger_avatar, test_crowd_view, test_damage_flash, test_hit_impact, test_hit_feel, test_status_visuals, test_vfx_layer, test_vfx_budget, test_vfx_pressure, test_vfx_interpolation, test_attack_forms, test_attack_forms_live, test_attack_form_looks, test_attack_visuals, test_attack_visuals_2, test_windup_tells, test_melee_strikes, test_horde_avatars, test_enemy_palettes, test_boss_views> -gexit
Tests               180
Passing Tests       180
Asserts           24393
Time              28.71s
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<e2e: test_e2e_horde_enemies, test_e2e_enemies, test_e2e_attacks, test_e2e_camera, test_e2e_health_bars, test_e2e_run_flow, test_e2e_combo, test_e2e_playground> -gexit
Tests                13
Passing Tests        13
Time              131.361s
---- All tests passed! ----

gdformat --check src scripts tests   -> 1048 files would be left unchanged
gdlint src scripts tests             -> Success: no problems found
```

### Horde probe, before and after
`godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde --seconds=10 --tag=hv_before|hv_after`.
Before: `07af5d59`'s `actor_views.gd`, `charger_avatar.gd`, `status_visuals.gd`, `attack_form_canvas.gd` and
`world_view_root.gd` copied in temporarily, with this step's probe. After: this step's tree. The outputs are in
`build/perf/perf_probe_hv_before.txt` and `perf_probe_hv_after.txt`.

**Counts** (deterministic; this is the evidence). Every count shared by both runs is identical:

| Metric (avg / p95 / max) | Before and after |
|---|---|
| projectiles | 20.887 / 51 / 82 |
| events | 13.060 / 58 / 171 |
| bursts_drawn | 16.700 / 25 / 27 |
| sprites_drawn | 550.503 / 780 / 902 |
| lights_on | 7.523 / 10 / 10 |
| form_meshes | 90.092 / 221 / 386 |
| status_drawn | 27.807 / 53 / 57 |
| flashing | 3.323 / 10 / 16 |
| damage | 10794 over 10 s |

After only:
- `animated` 104.313 / 110 / 110: about 6 of the 110 Chargers, on average, were wholly off this room's screen.
- `status_culled` 0 / 0 / 0: the probe's burning enemies were all within reach of the view.

**Timings** (noisy cloud CPU; these rank only, they are not a measurement):

| ms per tick, avg | Before | After |
|---|---|---|
| sim | 4.816 | 4.692 (not this step's code) |
| view sync | 8.204 | 7.469 |
| frame (`_process`) | 8.687 | 6.587 |
| total | 21.707 | 18.749 |
| ChargerAvatar frame | 4.560 | 2.639 |
| AttackFormView frame | 3.256 | 3.140 |
| sync: actors | 3.202 | 3.273 |
| sync: status_fx | 0.808 | 0.676 |
| sync: item_fx | 0.720 | 0.223 |

What the timings say:
- The pose rewrite and the visor guard roughly halve the Charger animation cost.
- The tint guard takes most of the cost out of `item_fx`.
- `AttackFormView` barely moved: its cost is not in the per-bolt look-ups this step removed. The next candidate is
  the effects layer drawn inside its frame.
- `actors` sync is unchanged: avatar `sync` and bars dominate, and HR's shared materials touch that area.

**fps:** NOT YET RUN (owner hardware). **Look and feel:** OWNER ONLY.

## HR

Step HR (owner O89: "optimize performance at maximum without losing the game vibe … lag mostly comes from shooting
hordes with multiple modifiers … if not I'll tell you what to discard"). Branch `v080-hr` from `07af5d59`, HV
(`33dfbdf8`) merged in. Agent work; fps and feel on the owner's PC: OWNER ONLY.

### What changed: same pixels (no switch)

- **The X-ray is a pass of the piece's own material, not a twin mesh.** Before, every enemy body piece had a second
  MeshInstance3D (the "twin") with its own StandardMaterial3D in STENCIL_MODE_XRAY: an opaque draw, a depth
  prepass and the X-ray pass per piece, and one more node to move. Now one shared X-ray pass per team colour and
  shrink (`EnemyLooks.xray`: unshaded, alpha, no depth test, drawn where the stencil is not 1, team colour at 0.85,
  shrunk 0.96 about the piece's origin as the twin's node was, or grown by `XRAY_GROW / scale` on the owner's
  models). It is chained after the body's outline pass, so the stencil rule is unchanged: an enemy shows through
  walls in its team colour, never through itself. This covers the horde kinds, the Charger and Hatchling, and every
  `AvatarBase._outlined` body (Warden, Needle, Arc Caster, Bomb Drone, the hero). Not changed: the bosses and the
  Lens Drone (their own twin code, one or two on screen) and the grey-cube fallback.
- **No empty outline pass on the owner's models.** Their materials were STENCIL_MODE_OUTLINE at thickness 0: an
  extra pass that drew nothing. Now they write the stencil only (as the eyes and glows already did).
- **Shared enemy materials, flash and glow per enemy.** The horde kinds' and the Charger's/Hatchling's body
  materials are `EnemyLooks` ShaderMaterials shared by every enemy of the same look. Their shading is Godot 4.7.2's
  own generated StandardMaterial3D code for the old settings (roughness 1, specular 0.5, Burley, Schlick-GGX,
  emission on, the colour map on the models), with the default textures it sampled written as their constant values.
  The biome's grey cast and the role glow (`ActorViews.tint_greys` / `role_glow`, N1) are picked in when the
  material is made. The hit flash and the status tints are an `instance uniform` per piece (`zd_hit`), and the
  glowing accents' energy another (`zd_glow`, the visor's too). Each is written only when its value changes,
  behind HV's per-actor guards. The code bodies' meshes are shared too (one per shape), so a crowd's identical
  pieces draw as one instanced draw. Other kinds (Warden, Needle, Arc Caster, Bomb Drone, the bosses, the hero)
  keep their own StandardMaterial3D: fewer on screen.

### What changed: the switches (owner: say which to discard)

All are in `src/presentation/world_view/render_switches.gd`, one constant each (and the line in `project.godot`
where named). Set a constant to `false` to get the old look back.

| # | Switch | On screen | To turn it off |
|---|---|---|---|
| 1 | `TORCH_DUAL_PARABOLOID` | The four shadow-casting torches use dual-paraboloid shadows (2 shadow renders each, not 6). Shadows can stretch a little near the paraboloid seam. In the Ruins shot below the torch pools look a little larger and warmer than the reference; this switch is the likely cause (not isolated) | `false` |
| 2 | `SCATTER_NO_SHADOW` | Small floor scatter (rubble, tufts, debris, drifts; the dresser caps them at 0.4 m, the switch at 0.6 m) casts no shadow. Walls, cover and props keep theirs | `false` |
| 3 | `MSAA_OFF` | No 2x MSAA on the 3D view; the ink pass draws the edges. Silhouette edges between ink lines may show more stair-steps | `false` (sets 2x again at run time), or `project.godot` `msaa_3d=2` |
| 4 | `RENDER_THREAD` | **Off.** Measured below: the separate render thread gave engine errors in the horde e2e | It is off: `project.godot` `thread_model=1`. To try it: `thread_model=2` |
| 5 | `SHADER_WARMUP` | Same pixels. Behind the loading cover, each effect shader on a hidden pool piece, the first-use materials (hero pulse, fireball, boss marks, flare, sigil) and one of each horde kind plus a Charger and Hatchling are drawn once, a thousandth of their size in front of the camera, then removed after 3 frames (`ShaderWarmup`) | `false` |

**Why the render thread is off (switch 4).** With `thread_model=2`, the same tree, test and command:

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_horde_enemies.gd -gexit 2>&1 | grep -c 'Parameter "material" is null'
thread_model=1: 0
thread_model=2: 15
```

The errors read `ERROR: Parameter "material" is null. at: material_get_instance_shader_parameters
(servers/rendering/dummy/storage/material_storage.cpp:264)`: an instance reached a material the render thread had
not made yet. Godot 4.7.2 also prints at every start that the separate thread is "experimental … can lead to project
crashes or instability". No synchronous read-back blocked it: the game path has one `get_image` (VfxCore cuts the
floor marks once, on the load's worker); `get_rendering_info` is only in tools.

### Draws in a horde, before and after (counts, not timings)

New probe `scripts/checks/horde_draws.gd`. Scene: the iso camera, a sun with shadows, a ground, and a wall in front
of part of the crowd. 120 enemies are added to a real World with the compiled enemies and stepped 90 ticks past
their spawn. ActorViews draws them with the X-ray technique, a third of them flashing. The probe reads draws,
objects and primitives on 30 frames after 30 settle frames. "Before" is `07af5d59`'s `src/` and `project.godot`
checked out in this worktree with the same probe, then put back. Build: the runs were made on WIP commits `deacb89f`
(horde kinds) and `7360f0ac` (Chargers, and the Ruins shot), since squashed into this step's commit; their `src/` and
`project.godot` are this commit's (only the probe's options and these docs changed after). Machine: cloud container,
lavapipe (llvmpipe) Forward+, 1920x1080.

```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/checks/horde_draws.gd -- n=120 tag=before shot=1
horde_draws: 120 enemies (7 kinds), tag=before
renderer=forward_plus msaa_3d=2 thread_model=1
frames read: 30 (after 30 settle)
draw_calls median: 6042 (min 6042, max 6042)
objects median: 6042
primitives median: 2417245
actor MeshInstance3D nodes: 1858

(build deacb89f) ... -- n=120 tag=after shot=1
horde_draws: 120 enemies (7 kinds), tag=after
renderer=forward_plus msaa_3d=0 thread_model=1
frames read: 30 (after 30 settle)
draw_calls median: 2069 (min 2063, max 2080)
objects median: 4228
primitives median: 1737177
actor MeshInstance3D nodes: 1149

(build 7360f0ac) ... -- n=120 tag=charger_before charger=1     (src/project.godot at 07af5d59)
horde_draws: 120 enemies (Chargers), tag=charger_before
renderer=forward_plus msaa_3d=2 thread_model=1
frames read: 30 (after 30 settle)
draw_calls median: 10239 (min 10239, max 10239)
objects median: 10239
primitives median: 1163465
actor MeshInstance3D nodes: 2415

(build 7360f0ac) ... -- n=120 tag=charger_after charger=1
horde_draws: 120 enemies (Chargers), tag=charger_after
renderer=forward_plus msaa_3d=0 thread_model=1
frames read: 30 (after 30 settle)
draw_calls median: 3596 (min 3577, max 3624)
objects median: 9877
primitives median: 1163465
actor MeshInstance3D nodes: 2293
```

So in this scene the draw calls fell from 6042 to about 2069 for 120 horde-kind enemies (about 66 % fewer) and
from 10239 to about 3596 for 120 Chargers (about 65 % fewer). Frame time on the owner's PC: NOT YET RUN (owner
hardware).

### Shots

- `hr_shots/xray_horde_before_after.jpg`: the probe's crowd, before (left) and after (right). The enemies behind the
  wall show through it in red in both, visible enemies are not overdrawn, the flashing third is white in both. One
  difference: where an enemy's own parts overlap behind the wall, the after side shows faint inner edges, because the
  X-ray is now drawn per part surface (alpha 0.85 over alpha 0.85) where some twins were one merged mesh.
- `hr_shots/ruins_reference_vs_hr.jpg`: the reference `mi_shots/ruins_room.jpg` (left) and the same tool and room
  with every switch on (right), from `scripts/shots/room_layouts.gd -- biome=ruins only=room_2x2_1 out=hr` (build
  `7360f0ac`, log `renderer=forward_plus device=llvmpipe`). `hr_shots/ruins_room_hr.jpg` is the full frame. The walls,
  cover, scatter and grade match. The torch pools (bottom-left fire, top) look a little larger and warmer than the
  reference (see switch 1).

### Tests (this step's tree, after the HV merge, `thread_model=1`)

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<24 presentation files> -gexit
(test_horde_avatars, test_hit_impact, test_enemy_palettes, test_warden_avatar, test_needle_avatar, test_player_avatar,
 test_stage_kit_lights, test_shader_warmup, test_windup_tells, test_damage_flash, test_melee_strikes,
 test_new_enemy_avatars, test_charger_avatar, test_boss_animations, test_boss_models_2, test_view_build_queue,
 test_kit_decor_lod, test_boss_views, test_health_bars, test_charger_pose_hv, test_screen_cull, test_crowd_view,
 test_status_visuals, test_attack_forms_live)
Tests               188
Passing Tests       186
Failing Tests         2
```

The 2 failures are `test_view_build_queue.gd`'s `test_a_view_built_in_slices_is_the_view_built_in_one_call` and
`test_a_view_made_from_parts_made_ahead_is_the_same_view`: the Atmosphere's FogLayer and Dust sit at different
places in the two views. They are **not from HR**: the same file run alone fails the same 2 tests on `07af5d59` and
on HV's `33dfbdf8` (`Passing Tests 3 / Failing Tests 2` on each).

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_horde_enemies.gd,res://tests/e2e/test_e2e_attacks.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_heat.gd,res://tests/e2e/test_e2e_lighting.gd -gexit
Tests                10
Passing Tests        10
Time              96.49s
```

Lint: `gdformat --check src scripts tests` (1053 files unchanged) and `gdlint src scripts tests` (no problems).

## Next candidates (read-only audit, 2026-10-19; owner: "Any other findings on the code that could improve the lag and fps that doesn't change the game?")
Three read-only reviews of `db26b485` (sim, view CPU, GPU). Nothing measured or changed; sizes are estimates from the code.
**Same game and same pixels:**
1. Material values rewritten when unchanged: burn/frost tint every tick (`item_visuals.gd:89-93` → `actor_views.gd:192,205`, ~25 materials per Charger), hit flash re-set on every DAMAGE (`actor_views.gd:157-160`), Charger visor every frame (`charger_avatar.gd:239`), shock pips' `material_override` every tick (`status_visuals.gd:195`). Fix: skip when equal.
2. Charger pose allocates ~10 Arrays per leg per frame (`charger_avatar.gd:243-291`, ~4,400 a frame at 110). Fix: local floats, one transform write.
3. X-ray twin = a second MeshInstance3D + own material per part (`horde_avatar.gd:383-395`, `avatar_base.gd:316,333-347`), and model enemies keep an outline pass at thickness 0 (`horde_avatar.gd:403-409`). Fix: one shared `next_pass` X-ray material per kind; `write_stencil` instead of the empty outline. One owner shot behind a wall.
4. Per-enemy unique materials break draw batching (`horde_avatar.gd:84-89,400-410`, `actor_views.gd:290-349`). Fix: a shared ShaderMaterial per kind with instance uniforms. Larger job; owner checks flash and tint.
5. Status VFX and attack forms laid out off-screen (`status_visuals.gd:320`, `attack_form_canvas.gd:303-345`); avatars animate in a 24 m circle around the hero, not the camera's view (`actor_views.gd:16,93`). Fix: cull to the camera's ground rectangle + margin.
6. Sim: full O(N) scans in Explosive bursts, chain seek, Wildfire, shockwave (`attacks.gd:344,363`, `engines.gd:374,505,523`, `item_effects.gd:104`); per-hit allocations (`attack_spec.gd:308` `hooks_on`, `attacks.gd:745` ×3, `damage.gd:68,98-101`); actor-pair collision query slices (`dense_grid.gd:131-146`). A DenseGrid already exists; fixes keep candidate order ascending. First: a probe-only sim phase timer (the horde's 4.7 ms is not mostly bolt hits: 2.5 hits a tick).
7. AttackFormCanvas per-bolt Dictionary/Array work (`attack_form_canvas.gd:545-588`, `:353`).
8. Experiments: `rendering/driver/threads/thread_model` = Separate (stability check); shader warm-up behind the loading cover (`hero_pulse_views.gd:359`, `hero_cast_fx.gd:93`, `blade_swing_fx.gd:48`, `boss_strike_looks.gd:272`).
9. Risky, measure first: when frames drop, the whole view sync runs once per catch-up tick (`project.godot:33` `max_physics_steps_per_frame=4`, `main.gd:424`); measure `SimDriver.ticks_last_frame` in a horde.
**Changes pixels (owner's eye):** torch shadows as dual paraboloid instead of cube (`stage_kit.gd:252-260`, 24 → 8 shadow passes); no shadows from small floor scatter (`stage_kit.gd:177-184`); MSAA off with the ink lines.
