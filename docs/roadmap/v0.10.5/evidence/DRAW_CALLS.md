# DRAW_CALLS: where the draw calls come from, and the ones cut without changing the look

- **Status:** RUN
- **Build:** branch `v0105-draw` cut from `f33df41c`. Every tool prints `sha=f33df41c`: the "before" runs ran on that
  tree (this step's two `src/` changes stashed; the new census script and the unused `EmptyDrawCull` class present),
  the "after" runs on the same tree with the step's changes uncommitted. The step's commit is the one that adds this file.
  Godot `4.7.2.stable` (`Godot_v4.7.2-stable_win64_console.exe`); Windows 11 Pro 10.0.26200.
- **Machine:** the owner's PC, i7-10700K, RTX 3060 (the tools read `NVIDIA GeForce RTX 3060`, Forward+), 1920 x 1080
  windowed, off screen (`--position -10000,-10000`). **Other agents ran Godot jobs on this PC at the same time**, so the
  frame times in §4 are noise-prone (one run each, as asked); the draw-call counts are not affected.
- **Date:** 2026-11-02
- **Who ran it:** agent

Why: the owner's logged run (PERF_PLAYLOG_1) spent 67 % of the frame outside the scripts, and the frame time followed
the draw calls (~100 → 10.5 ms, median 1,103 → 15.2 ms, p95 1,894 → 24.6 ms).

## 1. The census (`scripts/checks/draw_census.gd`)

Boots the real game (`main.tscn`), starts a run (seed 4404), forces the biome on every floor and rebuilds the first
floor, then for 5 rooms (the start room and rooms spread over the floor) puts the hero at the room's centre, lets the
floor run 90 sim ticks after the loading cover is gone, pauses the sim, snaps the camera onto the hero, and reads
RenderingServer's frame totals and the root viewport's split: the camera pass (`cam_`), the shadow passes (`shd_`:
the sun and each shadowed torch's two dual-paraboloid renders) and the 2D (`cv_dc`). Then it hides each source in turn,
each against an everything-shown reading taken just before it; a row is what hiding that source removed (median of 6
frames, mean over the 5 rooms). A torch's light and its shadow are read with the kit's light fades held (`StageKit`
re-shows its lights every frame). `--fight=N` runs the frame probe's fight instead (the Playground, the Gun with the
probe's `--heavy` cards, N enemies kept round the hero, fire held) for 300 ticks and reads that one paused frame.

```
export APPDATA=$(mktemp -d)    # a fresh one for every run
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed --audio-driver Dummy \
  -s scripts/checks/draw_census.gd -- --biome=red_canyon --tag=before|after --shot
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed --audio-driver Dummy \
  -s scripts/checks/draw_census.gd -- --biome=red_canyon --fight=60 --tag=before|after --shot
```

### What the census says (before)

On a quiet run floor (482 draw calls, mean of the 5 rooms; 140 camera, 202 shadow, 140 2D):

| Source | Draws | Camera | Shadow | Note |
|---|---|---|---|---|
| Torch shadows (4 torches, 2 renders each) | 104 | 0 | 104 | every caster in reach, 8 extra passes |
| Sun shadow | 98 | 0 | 98 | |
| Shard clusters (decoration) | 103 | 11 | 91 | baked one mesh per room already; the cost is the shadow passes |
| **Empty effect pools** (boss strikes 22, VfxLayer 18, signatures 11, spikes 9, final boss 9, interphase 2) | **~71** | 31 | 40 | **MultiMeshes with 0 instances, still drawn; 0 primitives** |
| Procedural wall meshes | 54 | 14 | 41 | one mesh per sim wall |
| Kit wall/cover pieces | 50 | 10 | 40 | 139 objects: the renderer already batches same-mesh pieces |
| Shop stall, chests, breakables, door, altar, pedestals | ~80 | 38 | 42 | real props |
| Kit decoration (MultiMesh per kind per 16 m chunk since v0.8.0 P3) | 14 | 14 | 0 | already instanced, no shadow |
| Hero | 28 | 11 | 18 | |
| HUD and UI (2D) | ~140 | | | the minimap alone is 1,633 of the frame's ~2,450 "objects" |

In a 60-enemy fight (2,284 draws; 1,543 camera, 288 sun shadow, 453 2D): enemies 874 (762 camera, ~13 per enemy),
the VFX pack's particles 691 (568 camera, **123 in the sun's shadow**), dropped shards (ShardViews) 114, the build
HUD 183 (2D), item icons 60 and combo badges 94 (2D), the empty pools ~40 (VfxLayer 18, boss views ~20). The stage
(ground, walls, decoration, shards) is ~40 of it: in a fight the stage is not the cost.

The "objects drawn" of the owner's log (6,000-10,000) are mostly 2D: the minimap's draw commands (1,633 on a floor)
count as objects; the 3D objects are a few hundred.

## 2. What changed (presentation only, EI-07; the sim untouched)

1. **`EmptyDrawCull`** (`src/presentation/world_view/empty_draw_cull.gd`, one child of `WorldViewRoot`): every effect
   pool under the view (a MultiMeshInstance3D whose MultiMesh shows a counted part: `visible_instance_count` ≥ 0 when
   it joins the tree) is hidden **from the renderer only** (`RenderingServer.instance_set_visible` on its own
   instance) on any frame it is shown but has no instance to draw, and shown again the frame it has one. It runs after
   every other node's `_process` (`process_priority` 2^30), so a pool filled this frame draws this frame. The node's
   `visible` is never touched: the views, `ShaderWarmup`'s proxies and the tests see what they set. Static
   MultiMeshes (the kit's decoration, `-1`: all instances) are never watched. An empty MultiMesh draws no pixel, so
   the look is the same; the census's primitives stay the same (877,674 → 878,580 is the 2D's change, the 3D rows
   are equal).
2. **`PackFxSessionWarm`** (the VFX pack's menu warm-up): once every id is warmed, its 96 x 96 off-screen viewport
   stops rendering (`UPDATE_DISABLED`, `STEP_FRAMES` after the last warm). It rendered its empty world every frame of
   the session: a whole extra 3D pass (no draw calls, so the census cannot show it; in the census runs the warm-up was
   still running when the floor was read, `update=4`).

Nothing else was built: the other big sources are either already batched (decoration, wall pieces), or cutting them
changes the look (§5).

## 3. The census, before → after

Quiet run floor, Red Canyon, mean of the 5 rooms:

| | Draws | Camera | Shadow | 2D | Objects | Primitives |
|---|---|---|---|---|---|---|
| Before | 482 | 140 | 202 | 140 | 2,450 | 877,674 |
| After | 422 | 110 | 161 | 151 | 2,438 | 878,580 |
| 3D only (camera + shadow) | **342 → 271 (-71, -21 %)** | | | | | |

By source, what changed: the empty pools' ~71 draws (31 camera, 40 shadow) are gone (VfxLayer 18 → 2; the boss
strike, signature, spike, final-boss and interphase views from 53 to under 1.5); the torch-shadow and shard rows fall
by ~30 because those pools no longer sit in the torches' shadow passes. The 2D's +11 is the HUD (an onboarding tip and
the achievement toast come and go); it is not this change. Per room, 3D draws: 234 → 160, 421 → 346, 282 → 208,
478 → 423, 293 → 219.

60-enemy fight (one paused frame of a real-time fight, so the two snapshots are different moments): 2,284 → 2,102
draws; the idle rows went (VfxLayer 18 → 4, the boss views ~20 → under 1.5); the rest moves with the fight (PackFx
691 → 541, enemies 874 → 896). The "before" fight ran with the census before its last two changes (shot timing, the
"of which" count); the measuring was the same.

### Raw output, floor

```
draw_census  sha=f33df41c  biome=red_canyon  fight=-1  tag=before
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)
run seed 4404, first floor, rooms [0, 2, 4, 6, 8], 90 sim ticks settle, sim paused while read
SubViewports in the tree: 1 ["@Node@4 (96, 96) update=4"]
nodes under the view: 2579
  by class: MeshInstance3D 1968, Node3D 225, MultiMeshInstance3D 185, OmniLight3D 85, Decal 64, GPUParticles3D 33, Label3D 5, CPUParticles3D 5, CanvasLayer 2, TextureRect 1
  particles: 38 (emitting and shown: 6)
  drawn but empty (shown, nothing to draw), by view: { "VfxLayer": 16, "StoneSpikeViews": 1, "BossSignatureViews": 3, "TideViews": 1, "TideWaveViews": 1, "InterphaseViews": 2, "TwinViews": 5, "JudgeViews": 4, "ShadeViews": 1, "BossStrikeViews": 6, "FinalBossViews": 1, "(of which EmptyDrawCull keeps out of the renderer)": 0 }
  OmniLight3D: 85 (shown 21, shadow on 4)  shadow-casting geometry shown: 621
mean over the spots; a source's row is what hiding it removes (all shown minus hidden)
source                                         draws objects     prims | cam_dc cam_obj | shd_dc shd_obj |  cv_dc
all shown (total)                                482    2450    877674 |    140     162 |    202     269 |    140
walls: procedural wall meshes                     54      54     75546 |     14      14 |     41      41 |      0
walls: kit wall/cover pieces                      50     139    438752 |     10      32 |     40     107 |      0
decor: kit decoration MultiMeshes                 14      14    277073 |     14      14 |      0       0 |      0
lights: torch flames                               2       2       144 |      2       2 |      0       0 |      0
lights: torch OmniLight3D                        107     125    154525 |      3       3 |    104     122 |      0
lights: torch shadows                            104     122    154263 |      0       0 |    104     122 |      0
decor: shard clusters                            103     116    147192 |     11      11 |     91     105 |      0
stage: other children                            100     149    204955 |      2       2 |     98     147 |      0
lights: sun shadow                                98     147    204951 |      0       0 |     98     147 |      0
hero                                              28      28     12731 |     11      11 |     18      18 |      0
fx: the other views                              153     153     21983 |     69      69 |     84      84 |      0
  view: RewardViews                               13      13      6116 |      1       1 |     12      12 |      0
  view: EventPedestalViews                        11      11      1204 |     11      11 |      0       0 |      0
  view: VfxLayer                                  18      18        72 |     18      18 |      0       0 |      0
  view: StoneSpikeViews                            9       9         0 |      1       1 |      8       8 |      0
  view: BossSignatureViews                        11      11         0 |      3       3 |      8       8 |      0
  view: InterphaseViews                            2       2         0 |      2       2 |      0       0 |      0
  view: BossStrikeViews                           22      22         0 |      6       6 |     16      16 |      0
  view: FinalBossViews                             9       9         0 |      1       1 |      8       8 |      0
  view: BossDoorView                               6       6      2730 |      3       3 |      3       3 |      0
  view: BreakablesView                             7       7       864 |      2       2 |      6       6 |      0
  view: ShopStallView                             38      38      8496 |     17      17 |     20      20 |      0
  view: AltarStage                                 5       5      2500 |      4       4 |      1       1 |      0
hud: VBoxContainer @VBoxContainer@5478             8      29        88 |      0       0 |      0       0 |      8
hud: HudFrame                                      8       9        46 |      0       0 |      0       0 |      8
hud: HeatMeter                                     6      13        52 |      0       0 |      0       0 |      6
hud: Minimap                                      31    1633      1739 |      0       0 |      0       0 |     31
hud: KitHud                                        5      37       101 |      0       0 |      0       0 |      5
hud: AbilitySquares                               14      18      1561 |      0       0 |      0       0 |     14
hud: PhaseHud                                      2      10        19 |      0       0 |      0       0 |      2
hud: ShopHud                                       1       4        30 |      0       0 |      0       0 |      1
hud: BuildHud                                     22      40       322 |      0       0 |      0       0 |     22
ui: AchievementToast                              22     119      1818 |      0       0 |      0       0 |     22
ui: OnboardingHints                                9      53       135 |      0       0 |      0       0 |      9
(68 sources that move draws and objects by under 1.5 not listed)
per spot, all shown (draws objects prims cam_dc cam_obj shd_dc shd_obj cv_dc), median of 104 readings:
  room 0: [235, 251, 516209, 96, 101, 138, 149, 1]  (draws over the readings 235..235)
  room 2: [423, 494, 775268, 177, 195, 244, 297, 2]  (draws over the readings 423..423)
  room 4: [476, 3282, 1169632, 113, 161, 169, 246, 194]  (draws over the readings 476..543)
  room 6: [724, 3901, 888427, 197, 212, 281, 356, 246]  (draws over the readings 724..738)
  room 8: [551, 4322, 1038834, 116, 143, 177, 297, 258]  (draws over the readings 551..551)
draw_census  sha=f33df41c  biome=red_canyon  fight=-1  tag=after
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)
run seed 4404, first floor, rooms [0, 2, 4, 6, 8], 90 sim ticks settle, sim paused while read
SubViewports in the tree: 1 ["@Node@4 (96, 96) update=4"]
nodes under the view: 2580
  by class: MeshInstance3D 1968, Node3D 225, MultiMeshInstance3D 185, OmniLight3D 85, Decal 64, GPUParticles3D 33, Label3D 5, CPUParticles3D 5, Node 2, CanvasLayer 2
  particles: 38 (emitting and shown: 6)
  drawn but empty (shown, nothing to draw), by view: { "VfxLayer": 16, "StoneSpikeViews": 1, "BossSignatureViews": 3, "TideViews": 1, "TideWaveViews": 1, "InterphaseViews": 2, "TwinViews": 5, "JudgeViews": 4, "ShadeViews": 1, "BossStrikeViews": 6, "FinalBossViews": 1, "(of which EmptyDrawCull keeps out of the renderer)": 41 }
  OmniLight3D: 85 (shown 21, shadow on 4)  shadow-casting geometry shown: 621
mean over the spots; a source's row is what hiding it removes (all shown minus hidden)
source                                         draws objects     prims | cam_dc cam_obj | shd_dc shd_obj |  cv_dc
all shown (total)                                422    2438    878580 |    110     133 |    161     228 |    151
walls: procedural wall meshes                     54      54     75546 |     14      14 |     41      41 |      0
walls: kit wall/cover pieces                      50     139    438752 |     10      32 |     40     107 |      0
decor: kit decoration MultiMeshes                 14      14    277073 |     14      14 |      0       0 |      0
lights: torch flames                               2       2       144 |      2       2 |      0       0 |      0
lights: torch OmniLight3D                         73      91    154525 |      5       5 |     68      86 |      0
lights: torch shadows                             68      86    154263 |      0       0 |     68      86 |      0
decor: shard clusters                             73      86    147192 |     11      11 |     61      75 |      0
stage: other children                             95     156    204979 |      2       2 |     93     142 |      0
lights: sun shadow                                93     142    204951 |      0       0 |     93     142 |      0
hero                                              26      26     12731 |     11      11 |     16      16 |      0
fx: the other views                               82      82     21983 |     40      40 |     43      43 |      0
  view: RewardViews                               13      13      6116 |      1       1 |     12      12 |      0
  view: EventPedestalViews                        11      11      1204 |     11      11 |      0       0 |      0
  view: VfxLayer                                  13      62       981 |      2       2 |      0       0 |     11
  view: BossDoorView                               6       6      2730 |      3       3 |      3       3 |      0
  view: BreakablesView                             7       7       864 |      2       2 |      6       6 |      0
  view: ShopStallView                             38      38      8496 |     17      17 |     20      20 |      0
  view: AltarStage                                 5       5      2500 |      4       4 |      1       1 |      0
hud: VBoxContainer @VBoxContainer@5478             8      29        88 |      0       0 |      0       0 |      8
hud: HudFrame                                      8       9        46 |      0       0 |      0       0 |      8
hud: HeatMeter                                     6      13        52 |      0       0 |      0       0 |      6
hud: Minimap                                      31    1633      1739 |      0       0 |      0       0 |     31
hud: KitHud                                        5      37       101 |      0       0 |      0       0 |      5
hud: AbilitySquares                               14      18      1561 |      0       0 |      0       0 |     14
hud: PhaseHud                                      2      10        19 |      0       0 |      0       0 |      2
hud: ShopHud                                       1       4        30 |      0       0 |      0       0 |      1
hud: BuildHud                                     22      40       322 |      0       0 |      0       0 |     22
ui: AchievementToast                              22     119      1818 |      0       0 |      0       0 |     22
ui: OnboardingHints                                9      53       135 |      0       0 |      0       0 |      9
(73 sources that move draws and objects by under 1.5 not listed)
per spot, all shown (draws objects prims cam_dc cam_obj shd_dc shd_obj cv_dc), median of 104 readings:
  room 0: [161, 177, 516209, 67, 72, 93, 104, 1]  (draws over the readings 161..161)
  room 2: [348, 419, 775268, 147, 165, 199, 252, 2]  (draws over the readings 348..348)
  room 4: [456, 3498, 1174162, 84, 132, 124, 201, 248]  (draws over the readings 402..469)
  room 6: [669, 3846, 888427, 167, 182, 256, 331, 246]  (draws over the readings 669..683)
  room 8: [477, 4248, 1038834, 87, 114, 132, 252, 258]  (draws over the readings 477..477)
```

### Raw output, fight

```
draw_census  sha=f33df41c  biome=red_canyon  fight=60  tag=before
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)
fight: Playground, Gun + the frame probe's --heavy cards, 60 enemies kept, 300 sim ticks, then paused
SubViewports in the tree: 1 ["@Node@4 (96, 96) update=4"]
nodes under the view: 5503
  by class: MeshInstance3D 2915, Node3D 1387, GPUParticles3D 421, OmniLight3D 234, AnimationPlayer 197, MultiMeshInstance3D 110, Decal 76, Label3D 75, AudioStreamPlayer3D 57, Sprite3D 20
  particles: 423 (emitting and shown: 158)
  drawn but empty (shown, nothing to draw), by view: { "VfxLayer": 16, "FireballViews": 7, "StoneSpikeViews": 1, "BossSignatureViews": 3, "TideViews": 1, "TideWaveViews": 1, "InterphaseViews": 2, "TwinViews": 5, "JudgeViews": 4, "ShadeViews": 1, "BossStrikeViews": 6, "FinalBossViews": 1 }
  OmniLight3D: 234 (shown 17, shadow on 0)  shadow-casting geometry shown: 563
source                                         draws objects     prims | cam_dc cam_obj | shd_dc shd_obj |  cv_dc
all shown (total)                               2284    3167   6238536 |   1543    1721 |    288     338 |    453
floor: ground tiles                              -14      14   -145057 |     -8      18 |     -6      -4 |      0
walls: procedural wall meshes                      6      20   -199932 |     10      24 |     -8      -8 |      0
walls: kit wall/cover pieces                       2       1      5428 |      1       0 |      1       1 |      0
decor: kit decoration MultiMeshes                 11      11    176557 |     11      11 |      0       0 |      0
decor: shard clusters                              6       6     17712 |      4       4 |      2       2 |      0
stage: other children                            290     340   2811243 |      2       2 |    288     338 |      0
lights: sun shadow                               288     338   2811239 |      0       0 |    288     338 |      0
hero                                              23      23      5157 |     15      15 |      8       8 |      0
enemies                                          874    1091    466866 |    762     929 |    112     162 |      0
fx: the other views                              899     900   5513475 |    738     739 |    161     161 |      0
  view: TelegraphViews                             2       2      3648 |      2       2 |      0       0 |      0
  view: ShardViews                               114     114      2190 |     81      81 |     33      33 |      0
  view: HordeVisuals                              27      27     28044 |     27      27 |      0       0 |      0
  view: EventPedestalViews                        13      12      1152 |     13      12 |      0       0 |      0
  view: AttackFormView                             2       2       208 |      2       2 |      0       0 |      0
  view: RuneExplosionView                          3       8       484 |      3       8 |      0       0 |      0
  view: VfxLayer                                  18      18       300 |     18      18 |      0       0 |      0
  view: PackFx                                   691     688   5463624 |    568     565 |    123     123 |      0
  view: BladeFormView                              2       1         1 |      2       1 |      0       0 |      0
  view: FireballViews                              9       9     13824 |      9       9 |      0       0 |      0
  view: StoneSpikeViews                            2       2         0 |      1       1 |      1       1 |      0
  view: BossSignatureViews                         4       4         0 |      3       3 |      1       1 |      0
  view: TideWaveViews                              2       0         0 |      2       0 |      0       0 |      0
  view: InterphaseViews                            1       2         0 |      1       2 |      0       0 |      0
  view: ShadeViews                                 2       1         0 |      2       1 |      0       0 |      0
  view: BossStrikeViews                            8       8         0 |      6       6 |      2       2 |      0
  view: FinalBossViews                             2       2         0 |      1       1 |      1       1 |      0
hud: VBoxContainer @VBoxContainer@2075            13      49       146 |      0       0 |      0       0 |     13
hud: HudFrame                                     14      19        84 |      0       0 |      0       0 |     14
hud: HBoxContainer ItemIcons                      60      60       533 |      0       0 |      0       0 |     60
hud: HBoxContainer ComboBadges                    47      55      1168 |      0       0 |      0       0 |     47
hud: ComboCard                                    47     119      3384 |      1       0 |      0       0 |     46
hud: Label @Label@2080                             4      28        56 |      0       0 |      0       0 |      4
hud: HeatMeter                                    10      22        86 |      0       0 |      0       0 |     10
hud: Minimap                                      19     234       456 |      0       0 |      0       0 |     19
hud: KitHud                                        9      62       168 |      0       0 |      0       0 |      9
hud: AbilitySquares                               24      33      2608 |      0       0 |      0       0 |     24
hud: BuildHud                                    183     212      4100 |      0       0 |      0       0 |    183
ui: DpsMeter                                       5     133       370 |      0       0 |      0       0 |      5
ui: Label PlaygroundHint                           2      18        36 |      1       0 |      0       0 |      1
(55 sources that move draws and objects by under 1.5 not listed)
per spot, all shown (draws objects prims cam_dc cam_obj shd_dc shd_obj cv_dc), median of 97 readings:
  room -1: [2284, 3167, 6238536, 1543, 1721, 288, 338, 453]  (draws over the readings 2269..2296)
draw_census  sha=f33df41c  biome=red_canyon  fight=60  tag=after
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)
fight: Playground, Gun + the frame probe's --heavy cards, 60 enemies kept, 300 sim ticks, then paused
SubViewports in the tree: 1 ["@Node@4 (96, 96) update=4"]
nodes under the view: 5427
  by class: MeshInstance3D 2870, Node3D 1366, GPUParticles3D 407, OmniLight3D 237, AnimationPlayer 200, MultiMeshInstance3D 110, Decal 77, Label3D 73, AudioStreamPlayer3D 57, Sprite3D 18
  particles: 409 (emitting and shown: 150)
  drawn but empty (shown, nothing to draw), by view: { "VfxLayer": 13, "FireballViews": 6, "StoneSpikeViews": 1, "BossSignatureViews": 3, "TideViews": 1, "TideWaveViews": 1, "InterphaseViews": 2, "TwinViews": 5, "JudgeViews": 4, "ShadeViews": 1, "BossStrikeViews": 6, "FinalBossViews": 1, "(of which EmptyDrawCull keeps out of the renderer)": 44 }
  OmniLight3D: 237 (shown 17, shadow on 0)  shadow-casting geometry shown: 551
source                                         draws objects     prims | cam_dc cam_obj | shd_dc shd_obj |  cv_dc
all shown (total)                               2102    2909   6387529 |   1418    1559 |    235     269 |    449
floor: ground tiles                               23      27       836 |     23      27 |      0       0 |      0
walls: procedural wall meshes                     41      45     39280 |     37      41 |      4       4 |      0
decor: kit decoration MultiMeshes                 12      11    176559 |     12      11 |      0       0 |      0
lights: torch shadows                              3       0        -2 |      3       0 |      0       0 |      0
decor: shard clusters                              6       6     17712 |      4       4 |      2       2 |      0
stage: other children                            237     271   2897900 |      2       2 |    235     269 |      0
lights: sun shadow                               234     269   2897896 |     -1       0 |    235     269 |      0
hero                                              23      23      5159 |     15      15 |      8       8 |      0
enemies                                          896    1057    439367 |    781     908 |    115     149 |      0
actors: other                                     -1       9       108 |     -1       9 |      0       0 |      0
fx: the other views                              698     700   5689987 |    593     595 |    105     105 |      0
  view: TelegraphViews                             2       2      3648 |      2       2 |      0       0 |      0
  view: RewardViews                                3       0         0 |      3       0 |      0       0 |      0
  view: ShardViews                               100     101      1934 |     71      72 |     29      29 |      0
  view: DamageNumbers                             -3       0         0 |     -3       0 |      0       0 |      0
  view: HordeVisuals                              27      27     28044 |     27      27 |      0       0 |      0
  view: EventPedestalViews                        12      12      1152 |     12      12 |      0       0 |      0
  view: AttackFormView                             1       2       106 |      1       2 |      0       0 |      0
  view: LaserView                                 -3       0         2 |     -3       0 |      0       0 |      0
  view: RuneExplosionView                          4       9       564 |      4       9 |      0       0 |      0
  view: VfxLayer                                   4       4       218 |      4       4 |      0       0 |      0
  view: PackFx                                   541     539   5640206 |    465     463 |     76      76 |      0
  view: BladeFormView                              2       1         1 |      2       1 |      0       0 |      0
  view: FireballViews                              3       3     14114 |      3       3 |      0       0 |      0
  view: TwinViews                                 -1      -2       -24 |     -1      -2 |      0       0 |      0
hud: VBoxContainer @VBoxContainer@2075            13      49       146 |      0       0 |      0       0 |     13
hud: HudFrame                                     14      19        86 |      0       0 |      0       0 |     14
hud: HBoxContainer ItemIcons                      57      60       533 |     -3       0 |      0       0 |     60
hud: HBoxContainer ComboBadges                    47      55      1168 |      0       0 |      0       0 |     47
hud: ComboCard                                    44     119      3382 |     -2       0 |      0       0 |     46
hud: HeatMeter                                    10      22        86 |      0       0 |      0       0 |     10
hud: Minimap                                      19     234       458 |      0       0 |      0       0 |     19
hud: KitHud                                        9      62       170 |      0       0 |      0       0 |      9
hud: AbilitySquares                               24      33      2610 |      0       0 |      0       0 |     24
hud: BuildHud                                    183     212      4100 |      0       0 |      0       0 |    183
hud: CardFlights                                  -2      -2       -24 |     -2      -2 |      0       0 |      0
ui: DpsMeter                                       5     134       374 |      0       0 |      0       0 |      5
ui: Label PlaygroundHint                           1      18        36 |      0       0 |      0       0 |      1
(57 sources that move draws and objects by under 1.5 not listed)
per spot, all shown (draws objects prims cam_dc cam_obj shd_dc shd_obj cv_dc), median of 97 readings:
  room -1: [2102, 2909, 6387529, 1418, 1559, 235, 269, 449]  (draws over the readings 2099..2211)
```

## 4. Frame probe, before → after (one run each)

```
export APPDATA=$(mktemp -d)    # a fresh one for every run
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- \
  --biome=red_canyon --heavy --fx --secs=20 --warm=4 --enemies=N      # N = 0, 20, 60
```

| N | avg ms before → after | p95 ms | avg fps | median draw calls (20 one-second samples) |
|---|---|---|---|---|
| 0 | 5.59 → 5.91 | 7.33 → 8.27 | 179.0 → 169.1 | 521 → 476 |
| 20 | 13.66 → 16.13 | 22.73 → 25.99 | 73.2 → 62.0 | 1,162 → 1,175 |
| 60 | 42.84 → 40.31 | 59.44 → 62.99 | 23.3 → 24.8 | 1,976 → 1,954 |

The frame times do not follow the change: 0 and 20 enemies got slower, 60 faster, with three other agents' Godot jobs
on the same PC. They are reported as measured and are **not** evidence of a gain or a loss; the counts are. The
change cuts ~45 draw calls with no enemies and is within the fight's own spread with 20 or 60. A clean timing needs an
idle machine: **NOT YET RUN (owner hardware, idle)**.

```
== before0
frame_probe  sha=f33df41c  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know 
scenario: Playground room seed 4404, Gun, 0 live enemies, warm-up 4.0 s, measured 20.0 s
frames=3581  avg_ms=5.586  p50_ms=5.701  p95_ms=7.328  p99_ms=8.826
1pct_low_fps=53.8 (1000 / mean of the slowest 36 frames)  max_ms=139.047  over_6.94ms=274 (7.65 %)  avg_fps=179.0
render_cpu_ms_avg=0.741  render_gpu_ms_avg=3.480  (RenderingServer viewport measured time)
== before20
frame_probe  sha=f33df41c  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know 
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 4.0 s, measured 20.0 s
frames=1464  avg_ms=13.661  p50_ms=12.862  p95_ms=22.729  p99_ms=28.970
1pct_low_fps=23.8 (1000 / mean of the slowest 15 frames)  max_ms=135.001  over_6.94ms=1440 (98.36 %)  avg_fps=73.2
render_cpu_ms_avg=1.645  render_gpu_ms_avg=4.535  (RenderingServer viewport measured time)
== before60
frame_probe  sha=f33df41c  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know 
scenario: Playground room seed 4404, Gun, 60 live enemies, warm-up 4.0 s, measured 20.0 s
frames=467  avg_ms=42.837  p50_ms=40.782  p95_ms=59.444  p99_ms=89.768
1pct_low_fps=8.7 (1000 / mean of the slowest 5 frames)  max_ms=154.422  over_6.94ms=467 (100.00 %)  avg_fps=23.3
render_cpu_ms_avg=3.537  render_gpu_ms_avg=11.553  (RenderingServer viewport measured time)
== after0
frame_probe  sha=f33df41c  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know 
scenario: Playground room seed 4404, Gun, 0 live enemies, warm-up 4.0 s, measured 20.0 s
frames=3382  avg_ms=5.914  p50_ms=5.853  p95_ms=8.274  p99_ms=9.785
1pct_low_fps=47.0 (1000 / mean of the slowest 34 frames)  max_ms=160.475  over_6.94ms=461 (13.63 %)  avg_fps=169.1
render_cpu_ms_avg=0.830  render_gpu_ms_avg=3.615  (RenderingServer viewport measured time)
== after20
frame_probe  sha=f33df41c  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know 
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 4.0 s, measured 20.0 s
frames=1240  avg_ms=16.134  p50_ms=15.942  p95_ms=25.993  p99_ms=35.074
1pct_low_fps=20.6 (1000 / mean of the slowest 13 frames)  max_ms=150.165  over_6.94ms=1240 (100.00 %)  avg_fps=62.0
render_cpu_ms_avg=1.934  render_gpu_ms_avg=4.997  (RenderingServer viewport measured time)
== after60
frame_probe  sha=f33df41c  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know 
scenario: Playground room seed 4404, Gun, 60 live enemies, warm-up 4.0 s, measured 20.0 s
frames=497  avg_ms=40.305  p50_ms=37.581  p95_ms=62.992  p99_ms=81.772
1pct_low_fps=9.6 (1000 / mean of the slowest 5 frames)  max_ms=152.559  over_6.94ms=497 (100.00 %)  avg_fps=24.8
render_cpu_ms_avg=3.302  render_gpu_ms_avg=10.922  (RenderingServer viewport measured time)
```

## 5. Proposals for the owner (not built: each changes the look, a model, or another step's files)

| # | Source (census) | Proposal | Draws it would cut | Why not built |
|---|---|---|---|---|
| P1 | Torch shadows, 104 draws a quiet floor (22 %) | `StageKit.SHADOW_LIGHTS` 4 → 2, or the torches' `shadow_caster_mask` leaving out the shard clusters and small props | ~50 (2 torches), or the shards' ~60 | fewer torch shadows on screen |
| P2 | The VFX pack's particles in the sun's shadow, 123 draws in the 60-enemy fight | the pack's GPUParticles3D `cast_shadow` off | ~120 in a fight | the sparks and smoke stop casting shadows |
| P3 | Enemies, ~13 draws each (762 camera draws for 60) | each enemy model's parts merged into fewer surfaces at load (the rig's bones permitting), or one MultiMesh per kind for the crowd | several hundred in a fight | a model change; the actors view is another step's |
| P4 | Procedural walls, 54 draws (14 camera, 41 shadow) | one merged mesh per room chunk, with the per-wall meshes swapped in for a chunk while one of its walls fades (the cutaway) or is a hidden room's | ~35 a floor (estimate, not measured) | the cutaway (S15b) and hidden rooms (TD) fade and hide single walls: a design step with its own occlusion test |
| P5 | Dropped shards (ShardViews), 114 draws in the fight | one MultiMesh per shard look | ~100 in a fight | the pickups view is another step's |
| P6 | The 2D: build HUD 183 draws in a fight, item icons 60, combo badges 94; the minimap 1,633 draw commands a floor | fewer, merged canvas items (one `_draw` per panel) | ~250 in a fight | HUD work |
| P7 | The sun's shadow fit | `IsoRig`'s near plane 0.1 → ~35 m (the ground is 48-72 m away): the sun's orthographic shadow fits the camera's near..80 m, a tighter range culls fewer casters | not measured | sharper shadows: a look change |

## 6. Shots (untracked, `build/shots/v0.10.5/draw/`)

Red Canyon, the same 5 rooms and the same paused tick, the camera snapped on the hero, before and after:
`red_canyon_before_<0-4>.png` / `red_canyon_after_<0-4>.png`, and the fight: `red_canyon_fight60_before_0.png` /
`red_canyon_fight60_after_0.png` (a different moment of a real-time fight; for the look only). Pixel diff of the 5
floor pairs (more than 24/255 on any channel): 0.02 %, 0.69 %, 0.12 %, 0.37 %, 0.03 % of the pixels, all in what moves
with real time (the lava backdrop, the torch flicker, the bobbing crystal fragments, the dust). Only the biome the
census ran was shot: the change is the same on every biome (it is in the view root, not in a biome's look).
