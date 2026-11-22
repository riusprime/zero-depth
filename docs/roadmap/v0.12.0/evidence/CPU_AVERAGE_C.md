# CPU_AVERAGE_C: fewer separate things for the engine to handle (the rooms' static pieces, lights, occlusion)

Build: `0f298c3d` (branch `v0120-s50`), the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2, **two other agents running
Godot at the same time**: every timing here is an indication. The Godot process count is printed with each run.

**Outcome: nothing cut.** The census and the A/B below show the stage's static pieces are already batched, every
piece belongs to one sim wall (the cutaway fades walls one by one), and the most hiding the whole kit could ever
save is 0.1-0.4 ms of a CPU-bound frame. No merge was found that both keeps the same pixels and saves anything
measurable, so no code changed; the still-frame proof is therefore not needed (the tree is the base tree).

## 1. What the floor holds (seed 4404, first floor)

Scratch census (`build/s50_kit_census.gd`, untracked: boots `main.tscn`, starts the run with every floor in the
biome, as `draw_census.gd` does, and counts the view's nodes once the loading cover is gone):

```
"$G" --path . --position -10000,-10000 --resolution 1280x720 --windowed -s res://build/s50_kit_census.gd -- --biome=red_canyon
```

| | Red Canyon | Night Rocks |
|---|---:|---:|
| nodes under the view | 3,088 (draw_census) | 3,177 |
| the stage (StageView and its children) | 876 nodes | 876 nodes, 826 geometry, 797 shown |
| the kit: wall and cover pieces (MeshInstance3D) | 404 | 399 |
| the kit: procedural wall meshes (one per sim wall) | 95 | 95 |
| the kit: decoration MultiMesh chunks | 108 | 239 |
| the kit: torch lights / flames | 32 / 32 | 34 / 34 |
| kit pieces not on a wall | **0** | **0** |
| sim walls dressed, by pieces on them | 1: 324, 2: 21, 3: 5, 4: 9, 5: 8, 6: 7 | 1: 326, 2: 19, 3: 4, 4: 9, 5: 8, 6: 7 |
| pieces by kind (mesh + material) | mesa_chunk 302, cactus 30, fire_barrel 29, rock_large 29, cattle_skull_post 9, brazier_pole 3, wagon_wreck 2 | rock_large 259, rock_spire 58, dead_tree 47, fire_barrel 29, brazier_pole 5, stone_arch 1 |

The ground is already one MultiMesh for the floor (`Ground0`), the contact shadows one mesh, the shards one mesh plus
one MultiMesh per room, decoration one MultiMesh per kind per 16 m chunk. The view's 2,281 MeshInstance3D are mostly
the effects layer's hidden pools (VoidView 130, SeekersView 152, Remnants 137, JudgeViews 128, PrismViews 109, ...:
shown 0), which are step 48's, and a hidden instance is out of the renderer's cull.

`draw_census.gd` (the renderer's own counts, sim paused, each source hidden in turn):

```
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/draw_census.gd -- --biome=red_canyon --spots=5 --tag=base --shot
```
Godot processes: 4 before, 2 after. Report `build/perf/draw_census_red_canyon_base.txt` (sha 0f298c3d), the rows
that matter:

```
nodes under the view: 3088
  by class: MeshInstance3D 2281, Node3D 315, MultiMeshInstance3D 290, OmniLight3D 83, Decal 64, GPUParticles3D 33, CPUParticles3D 5, Node 4, Label3D 4, CanvasLayer 2
  OmniLight3D: 83 (shown 21, shadow on 2)  shadow-casting geometry shown: 653
source                                         draws objects     prims | cam_dc cam_obj | shd_dc shd_obj |  cv_dc
all shown (total)                                261     419    812498 |    109     131 |    131     190 |     21
walls: procedural wall meshes                     46      46     64683 |     14      14 |     32      32 |      0
walls: kit wall/cover pieces                      42     124    397398 |     10      32 |     32      92 |      0
decor: kit decoration MultiMeshes                 14      14    285639 |     14      14 |      0       0 |      0
lights: torch flames                               2       2       144 |      2       2 |      0       0 |      0
lights: torch OmniLight3D                         45      55     86984 |      5       5 |     40      50 |      0
lights: torch shadows                             40      50     86735 |      0       0 |     40      50 |      0
decor: shard clusters                             44      50     78733 |     11      11 |     34      39 |      0
stage: other children                             93     142    205494 |      2       2 |     91     140 |      0
lights: sun shadow                                91     140    205490 |      0       0 |     91     140 |      0
hero                                              26      26     12648 |     11      11 |     15      16 |      0
fx: the other views                               77      77     20832 |     39      39 |     38      38 |      0
  view: ShopStallView                             38      38      8496 |     17      17 |     20      20 |      0
per spot, all shown (draws objects prims cam_dc cam_obj shd_dc shd_obj cv_dc), median of 147 readings:
  room 0: [124, 136, 435117, 64, 69, 59, 66, 1]  (draws over the readings 124..124)
  room 2: [294, 355, 669569, 144, 163, 148, 190, 2]  (draws over the readings 294..294)
  room 4: [181, 358, 1026745, 78, 126, 81, 146, 22]  (draws over the readings 181..235)
  room 6: [473, 724, 966886, 171, 184, 255, 330, 47]  (draws over the readings 473..473)
  room 8: [233, 521, 964172, 88, 115, 110, 220, 35]  (draws over the readings 233..233)
```

Read: the kit's 124 wall/cover objects a frame already go out as 42 draws (the renderer instances the same mesh and
material itself: 32 camera objects in 10 draws); most of the stage's draws are the shadow passes (the sun's 91, the two
torch shadows' 40), which are light and shadow settings this step may not change.

Night Rocks, the floor and a fight (one process after the other):

```
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/draw_census.gd -- --biome=night_rocks --spots=5 --tag=base
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/draw_census.gd -- --biome=night_rocks --fight=40 --tag=base
```
Godot processes: 2 before, 4 between, 2 after; both exit 0. `build/perf/draw_census_night_rocks_base.txt`:

```
nodes under the view: 3177
  by class: MeshInstance3D 2235, MultiMeshInstance3D 421, Node3D 315, OmniLight3D 85, Decal 64, GPUParticles3D 35, CPUParticles3D 5, Node 4, Label3D 4, CanvasLayer 2
  OmniLight3D: 85 (shown 21, shadow on 2)  shadow-casting geometry shown: 620
source                                         draws objects     prims | cam_dc cam_obj | shd_dc shd_obj |  cv_dc
all shown (total)                                248     397   1459026 |    118     137 |    110     163 |     21
walls: procedural wall meshes                     46      46     62220 |     14      14 |     32      32 |      0
walls: kit wall/cover pieces                      40     113    450208 |     13      32 |     27      81 |      0
decor: kit decoration MultiMeshes                 24      24    522581 |     24      24 |      0       0 |      0
lights: torch flames                               2       2       176 |      2       2 |      0       0 |      0
lights: torch OmniLight3D                         46      56    106955 |      6       6 |     40      50 |      0
lights: torch shadows                             40      50    106667 |      0       0 |     40      50 |      0
decor: shard clusters                             48      55    103480 |     12      12 |     36      43 |      0
floor: biome edge                                  1      -2    344764 |      1       1 |      0       0 |      0
stage: other children                             72     115    220359 |      2       2 |     70     113 |      0
lights: sun shadow                                70     113    220355 |      0       0 |     70     113 |      0
hero                                              22      22      3232 |     11      11 |     11      11 |      0
fx: the other views                               51      51     24402 |     31      31 |     20      20 |      0
per spot, all shown (draws objects prims cam_dc cam_obj shd_dc shd_obj cv_dc), median of 148 readings:
  room 0: [133, 141, 843870, 74, 76, 58, 64, 1]  (draws over the readings 133..133)
  room 2: [285, 335, 1356872, 163, 178, 120, 155, 2]  (draws over the readings 285..285)
  room 4: [210, 380, 1793457, 106, 148, 82, 146, 22]  (draws over the readings 210..264)
  room 6: [376, 600, 1629376, 147, 156, 186, 238, 43]  (draws over the readings 375..377)
  room 8: [237, 528, 1671556, 100, 128, 102, 214, 35]  (draws over the readings 237..237)
```

`build/perf/draw_census_night_rocks_fight40_base.txt` (the Playground's fight, 40 enemies, the heavy build):

```
nodes under the view: 3084
  by class: MeshInstance3D 1811, Node3D 533, MultiMeshInstance3D 301, GPUParticles3D 145, OmniLight3D 90, Decal 65, Label3D 57, AnimationPlayer 54, Sprite3D 13, Node 4
source                                         draws objects     prims | cam_dc cam_obj | shd_dc shd_obj |  cv_dc
all shown (total)                                668    1297   1224150 |    554     580 |     58      59 |     56
floor: ground tiles                               12      12      2820 |     12      12 |      0       0 |      0
walls: procedural wall meshes                     50      50     50628 |     42      42 |      8       8 |      0
walls: kit wall/cover pieces                       2       2      5440 |      1       1 |      1       1 |      0
props: kit pieces not on a wall                    1       2     16420 |      1       2 |      0       0 |      0
decor: kit decoration MultiMeshes                 17      17     53778 |     17      17 |      0       0 |      0
decor: shard clusters                              6       6     17712 |      4       4 |      2       2 |      0
lights: sun shadow                                58      59    400700 |      0       0 |     58      59 |      0
hero                                              23      23      5157 |     15      15 |      8       8 |      0
enemies                                          172     196    455968 |    158     181 |     14      15 |      0
actors: other                                     63      63    382865 |     47      47 |     16      16 |      0
fx: the other views                              334     329    408508 |    314     309 |     20      20 |      0
  view: PackFx                                   242     238    376138 |    242     238 |      0       0 |      0
```

Read: in a fight the stage (ground, walls, props, decoration, shards) is about 88 of 668 draws; the enemies (172),
the other actors (63) and the effects (334, PackFx alone 242) are the rest: steps 48 and 49's files.

## 2. The ceiling: what the stage's static pieces cost, hidden whole

Scratch A/B (`build/s50_stage_ab.gd`, untracked): the same run, room 6 (the floor's busiest in the census), the hero
put at its centre, 120 frames, then the sim paused, vsync off, no fps cap; then alternating 240-frame blocks (the
first 20 dropped) of each state, 4 rounds, 880 frames a state. `frame` is the mean wall time between frames; `vp_cpu`
is `RenderingServer.viewport_get_measured_render_time_cpu` (the root viewport's CPU recording). Hiding is the upper
bound of any merge: a merge keeps the pixels, so it keeps part of the cost.

```
"$G" --path . --position -10000,-10000 --resolution 640x360 --windowed -s res://build/s50_stage_ab.gd -- --biome=<b> --room=6
```
640 x 360 (the GPU off the critical path, so the frame is the CPU's):

```
procs before: 2
stage_ab biome=red_canyon room=6 frames/state=880
  all shown                    frame 2.823 ms  vp_cpu 0.678 ms
  kit hidden (lights kept)     frame 2.729 ms  vp_cpu 0.563 ms
  kit pieces hidden            frame 2.737 ms  vp_cpu 0.623 ms
  decor hidden                 frame 2.899 ms  vp_cpu 0.688 ms
  stage scripts' _process off  frame 3.017 ms  vp_cpu 0.756 ms
procs after: 2
procs before: 2
stage_ab biome=night_rocks room=6 frames/state=880
  all shown                    frame 3.179 ms  vp_cpu 0.782 ms
  kit hidden (lights kept)     frame 2.768 ms  vp_cpu 0.532 ms
  kit pieces hidden            frame 2.882 ms  vp_cpu 0.629 ms
  decor hidden                 frame 2.939 ms  vp_cpu 0.670 ms
  stage scripts' _process off  frame 3.236 ms  vp_cpu 0.829 ms
procs after: 2
```
2560 x 1440 (the owner's size):
```
procs before: 0
stage_ab biome=red_canyon room=6 frames/state=880
  all shown                    frame 8.214 ms  vp_cpu 0.788 ms
  kit hidden (lights kept)     frame 7.603 ms  vp_cpu 0.642 ms
  kit pieces hidden            frame 7.924 ms  vp_cpu 0.698 ms
  decor hidden                 frame 8.172 ms  vp_cpu 0.824 ms
procs after: 2
procs before: 2
stage_ab biome=night_rocks room=6 frames/state=880
  all shown                    frame 8.496 ms  vp_cpu 0.812 ms
  kit hidden (lights kept)     frame 7.727 ms  vp_cpu 0.572 ms
  kit pieces hidden            frame 8.305 ms  vp_cpu 0.690 ms
  decor hidden                 frame 8.401 ms  vp_cpu 0.713 ms
procs after: 2
```
(At 2560 x 1440 the frame is mostly the GPU's, so its frame column is the GPU's share too; the `vp_cpu` column is the
CPU's.)

Read: everything the kit draws (walls, cover, procedural walls, decoration; lights kept) is 0.12-0.25 ms of the
CPU's recording and 0.09-0.41 ms of a CPU-bound frame, with the sim paused (no enemies, no effects). The wall and
cover pieces alone are 0.05-0.15 ms of recording. The stage scripts' `_process` (the kit's light flicker and fades,
the atmosphere's fog and dust follow, the backdrop's follow) turned off saved nothing measurable (both runs were
slower, within the noise of the shared machine), so making them skip unchanged sets would not show either.

## 3. The merges considered, and why none was made

| Merge | Most it could save | Why not made |
|---|---|---|
| Kit pieces off the walls into MultiMeshes | nothing | there are none: every piece belongs to a sim wall (section 1) |
| Same-mesh pieces of one wall into one MultiMesh per wall (keeps the per-wall fade) | at most 30 of 404 instances (Red Canyon), 26 of 399 (Night Rocks): under a tenth of the 0.05-0.15 ms the pieces cost | The pieces are unit meshes scaled to their size and carry generated levels of detail. The renderer picks a level from the instance's own scale (`inst->lod_model_scale * inst->lod_bias`, `render_forward_clustered.cpp` `_fill_render_list`; an orthographic camera fixes the distance at 1), and a MultiMesh's per-instance scale is not in it, so merged pieces could switch to a coarser level: a possible visible change for a saving below measurement |
| Every wall's pieces of one mesh across walls into one MultiMesh | most of the 0.05-0.15 ms | breaks the cutaway: a wall fades by swapping its pieces' material (`StageKit.set_faded`), per wall; fading one instance of a MultiMesh needs a new per-instance shader (a material change) plus the level-of-detail change above. The owner decides |
| The decoration chunks merged further | within the noise (`decor hidden`, all of it: -0.08 / +0.24 ms of frame, -0.01 / +0.11 ms of recording, Red Canyon / Night Rocks) | already one MultiMesh per kind per 16 m chunk, chunked on purpose so off-screen chunks are culled |
| Lights | — | not touched (the step's rule); the census shows the torches' and the sun's shadow passes are most of the stage's draws |
| Empty Node3D levels (`Decor_<kind>` groups) | nothing a frame | static nodes cost nothing per frame (no transform change, no notification); tests and tools find decoration by these names |
| Stop setting unchanged transforms (fog, dust, backdrop follow; torch shadow opacity) | not measurable (`_process off` row) | not made: no gain to show |

Occlusion: the game has no occlusion culling (no `OccluderInstance3D`, no `use_occlusion_culling`); "occlusion" is the
cutaway's per-wall fade above, and hidden rooms hide their own nodes until revealed (`StageView._hide`).

## 4. What is left (outside this step's files)

- The view holds 2,281 MeshInstance3D, most in the effects layer's pools (hidden, so out of the renderer's cull):
  step 48's files.
- The stage's draws are mostly shadow passes (the sun 91 draws / 140 objects, two torch shadows 40 / 50 in Red Canyon's
  mean): a light or shadow setting, which this pass may not change.

## Tests

No code changed, so no test was run for this step (the tree is `0f298c3d`'s). Lint: not run (nothing changed under
`src`, `scripts` or `tests`).
