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
