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

### Owner-only

| Target | Status |
|---|---|
| fps / frame time on the owner's PC, before vs after FS | NOT YET RUN (owner hardware) |
| 4096 sun shadow edges acceptable (vs 8192) | OWNER ONLY |
| No visible change in the ground, shadows and torch light | OWNER ONLY |
