# PROCEDURAL_WALLS: can the exterior walls stop looking stacked, and cost fewer triangles? (v0.8.0 Step N10, G2)

- **Status:** RUN (agent: builder, tests, probes and shots on software Vulkan, llvmpipe, under xvfb; not the owner's
  hardware). The pick (A, B or a mix), how it looks and feels in play: **OWNER ONLY** (D50).
- **Build:** branch `v080-n10` from `0479c41` (the step's commit, `v0.8.0 Step N10: …`; the tests, probes and shots
  ran on its tree before it was committed, only these docs were written after). Godot `4.7.2.stable.official.ed1daf0bf`;
  OS Linux 6.18.44 (cloud container, 4 cores, no GPU).
- **Date:** 2026-10-17
- **Superseded by N13** (D50 = A everywhere, no kit pillar accents): [WALLS_EVERYWHERE.md](WALLS_EVERYWHERE.md).
- **Who ran it:** agent

## What the owner asked
- **O66:** the stacked kit pieces on the exterior walls overlap and look cheap on long walls; a procedural wall
  instead of stacking one model, fewer triangles, "simpler using textures for most of it", exterior walls only.
- **O67** (on the first prototype): keep the ruin texture and "professional looking walls that have been model",
  "add some variance to it and don't make it a block with a texture". So: option A is modelled, and an option B (the
  kit kept, the stacking fixed, decimated) to compare; the dev toggle switches today / A / B.
- **O68** (on the render preview): "I love this new feeling but the texture seems a bit too grained … make it
  bigger". Fixed below ([the grain fix](#o68-the-grain-fix)).

## The two options
**A, `ProceduralWall`** (`src/presentation/world_view/procedural_wall.gd`, its grid `wall_grid.gd`): a pure
function of the walls' footprints, the light props' niches, the rooms, the doorways and the floor seed (the cosmetic
stream: a `RandomNumberGenerator` from the seed and integer hashes salted from it; never the sim, EI-05). Rules:
1. **Looks solid = is solid.** The structural walls' union is cut on a grid made of every footprint's edges (so
   doorways, T-joins and corners fall on grid lines), refined to 0.6 m. The core is that union, its faces 0.12 m back
   from the footprint (corner vertices move back along both faces: mitred), from 2 cm below the ground to the top.
   Every core face is the boundary of exactly one cell pair: no overlap, no gap, no z-fighting where walls meet. The
   doorways are the sim's gaps; light props get a niche cut (rule 4 of the dresser keeps its slots).
2. **The top is laid stones**: rows 0.6 m deep of stones 0.45-1.05 m long (each row shifted at random), each flat at
   its own height with a step face down to a lower neighbour. The height: 1.0 m, lowered in slumps (4 m noise) and
   collapsed stretches (7 m noise, down to 0.55 m), notched (1.5 m lattice: breaks through the top), a few tall
   remnants (3 m lattice), jittered per stone (-0.22..+0.12 m), 15 % of the top stones missing, snapped to 7 cm;
   always 0.55-1.4 m (walls still read as walls).
3. **The face** (O67: depth, not a textured block): in front of the core, between it and the footprint, each straight
   run is laid in courses (0, 0.36, 0.7, 1.02, 1.4 m, the same everywhere so corners line up) of staggered blocks
   0.5-1.15 m long with 2.5 cm joints; per block: flush (65 %), recessed 4-8 cm (25 %) or missing (10 %: the darker
   core shows); its front corners jittered; 22 % with a chipped top corner; upper courses 6 mm a course further back
   (a lean); never above the stone behind. Pilasters every 3.5-6 m on runs of 3 m and more; quoin stones (0.3 m) at
   outer corners, 20 % missing (chipped corners); bent rebar out of the top on some stretches (0.12 a metre).
4. **Fallen chunks**: low stones (at most 0.25 m, the decoration limit's rule) on a room's floor at a face's base,
   0.3 a metre, kept 1 m from doorways.
5. **The look**: the owner's `tex_wall_<biome>` on the faces (mapped once from the top down, repeating along the wall)
   and `tex_wall_top_<biome>` on everything that looks up; one surface, one material per floor (a small shader picks
   the texture by the vertex colour's alpha), flat-shaded facets, vertex colour darkening the base (grime) and the
   recesses. Kept from the kit: a decimated `wall_pillar` every 8-12 m on walls 9 m or longer and 1.4 m or thinner
   (corners have the quoins, so nothing stacks on them); the light props, in their niches.

One mesh per sim wall (so the occlusion still fades a single wall: the faded copy of the material, alpha-hashed).
Crystals still find their wall spots (they read the walls' footprints; `test_crystals_still_find_their_wall_spots`).

**B, `StageDresser.STYLE_FIT`**: the owner's four wall pieces kept, laid edge to edge at their own length and height
(0.90 / 2.30 / 0.95 / 0.77 m, read from the models), in rows about 0.85 m deep across a thick wall (each row its own
pieces), the few cm of rest spread over a stretch's pieces (99.8 % of pieces within ±15 % of their length), never the
same piece twice in a row (the endings may repeat one, then it is turned the other way), each turned 180° and/or
mirrored at random, pillars at the ends of long walls; drawn from decimated copies made by
`scripts/assets/kit_lod.gd` (welded at the UV seams so the simplifier gets past them, then each kept triangle given back
its own UV chart): wall_1m 11,711 → 2,925, wall_2m 12,585 → 1,569, wall_broken 10,864 → 2,715, wall_pillar 11,345 →
2,835 triangles (`assets/models/kit_lod/<id>_lod.res`).

**The switch** (`ViewPrefs.wall_style`): `auto` (the prototype's default: Ruins draws A, the other four biomes today's
kit), `old`, `a`, `b`. In the game: F10 → Tools → **Walls** (shows `walls: <style>`), then **Restart floor**.

## The textures
The owner delivered all ten (`unprocessed_images/walls/`, 1536 × 1024 RGB, 2026-10-17; no CC0 texture was needed or
used). `scripts/assets/n10_wall_prep.py`: the faces cross-faded left-right over 6 % (not top-bottom: they are mapped
once down the wall, so the rust drips stay at the top), the tops on both axes; then brightened to a mean of 0.55, the
kit's own rule (`kit_prep.py`'s MODEL_MEAN: the uploads averaged 0.23-0.57 and read black under the night moods). Kept
3:2. Imported VRAM-compressed with mipmaps (as `ground_b.png`). Listed in `assets/models/manifest.json` (the owner's
licence line, extended); credits rebuilt (`data/credits/licences.tres`).

## O68: the grain fix
Cause, found: the ten textures had been imported **without mipmaps** (Godot's default for a PNG it hadn't seen on a 3D
material yet), so at the game's camera each pixel sampled one texel of a 1536 px texture shrunk ~10×: grain and
shimmer. Fixes, all four in:
1. **Bigger tiles**: one face tile covers `BiomeMood.wall_texture_m` metres along the wall (its height by the 3:2
   aspect), one top tile `wall_top_texture_m` (data, in the dev panel's lighting group; a change shows on Restart
   floor). Chosen: **Ruins, Night Rocks, Frozen Shore, Starfall 4.0 m / 4.5 m; Red Canyon 5.0 m / 5.0 m** (its strata
   wider). Before: 2.4 m / 3.0 m.
2. **No aliasing**: the textures' imports now generate mipmaps; the shader samples them trilinear + anisotropic
   (`filter_linear_mipmap_anisotropic`).
3. **No visible tiling**: the face's u is offset and flipped per 3.5-5 m stretch of a run (the seams fall on block
   joints), each top stone takes its own offset, and stones and blocks take a 7 m low-frequency brightness (0.8-1).
4. **Softening the textures at install: not used** (the grain was gone after 1-3; the shapes kept full detail).

Shimmer, measured: each spot rendered, then rendered again with the camera moved 0.13 m (`pan=1`); the two frames
aligned by the best whole-pixel shift, the mean absolute grey difference left over (0-255; edges and the sub-pixel
move stay in it for both, so only before vs after means anything). "Before" is `grain=old`
(`ProceduralWall.legacy_look`: 2.4 m / 3 m tiles, no mipmap sampling, no offsets, no variation: the first prototype's
look):

| spot | before O68 | after O68 |
|---|---|---|
| Ruins corner | 6.72 | 1.27 |
| Ruins doorway | 5.07 | 2.08 |
| Ruins start hall | 0.96 | 0.85 |

Shots: `n10_shots/grain_ruins_{start,door,corner}.jpg` (before | after, the game's camera).

## Numbers: walls before and after (Ruins, real floors)
**The builder on generated floors** (`tests/unit/presentation/test_procedural_wall.gd`, `gut.p` lines; floors from
`FloorGenerator.generate(seed)`): triangles per metre of wall face (both sides of a wall count; the kit spends
11-12.6k triangles per 0.9-2.3 m piece):

| seed | option A triangles | face (m) | per metre | kit wall pieces on structural walls: today → A |
|---|---|---|---|---|
| 77 | 136,896 | 1,966 | 69.6 | 1,402 → 53 (pillar accents) |
| 501 | 136,968 | 2,208 | 62.0 | 1,546 → 115 |
| 1234 | 143,828 | 2,168 | 66.3 | 1,504 → 106 |

**The game's view** (`scripts/checks/biome_probe.gd`, new `walls=` argument; the floor `SaveLab.floor_world(seed, 1)`,
the start room and the next two rooms, 6 frames each at 640 × 360, llvmpipe). `wall_tris` counts the structural walls'
meshes at full detail (the kit pieces also have generated LODs the renderer may use, so their drawn share is lower);
`prims` and `draws` are RenderingServer's, everything in the frame (shadow passes included). `build_ms` is the whole
view's setup (most of it loading the kit models the first time); `proc_build_ms` option A's builder alone.

| seed 20261008 | today | A | B |
|---|---|---|---|
| wall meshes | 1,827 | 288 | 2,952 |
| wall triangles (full detail) | 21,528,542 | 568,346 | 7,042,086 |
| proc_build_ms | — | 1,365.4 | — |
| build_ms (whole view) | 13,421.6 | 16,242.2 | 14,822.6 |
| frame_ms avg / p95 | 4,458.8 / 6,485.8 | 2,638.0 / 3,679.9 | 3,958.0 / 5,099.4 |
| cpu_ms avg | 4,370.0 | 2,666.7 | 3,951.1 |
| draws avg / p95 | 503.1 / 777 | 507.7 / 608 | 766.4 / 893 |
| objects avg | 860.6 | 571.5 | 1,065.2 |
| prims avg | 6,356,666 | 4,877,483 | 6,129,838 |

| seed 7 | today | A | B |
|---|---|---|---|
| wall meshes | 1,814 | 242 | 3,411 |
| wall triangles (full detail) | 21,420,831 | 453,182 | 8,136,717 |
| proc_build_ms | — | 1,737.8 | — |
| build_ms (whole view) | 14,377.5 | 13,624.1 | 11,218.0 |
| frame_ms avg / p95 | 2,036.1 / 2,741.9 | 1,194.5 / 1,434.5 | 1,492.6 / 1,962.4 |
| cpu_ms avg | 3,999.4 | 2,417.2 | 3,461.1 |
| draws avg / p95 | 615.6 / 688 | 630.4 / 710 | 867.3 / 979 |
| objects avg | 969.8 | 682.7 | 1,162.1 |
| prims avg | 6,711,743 | 5,280,463 | 5,655,059 |

Read: A cuts the walls' triangles ~38-47× and the frame's primitives 21-23 %; frames on the software renderer
1.7× faster (frame_ms is wall time on a shared 4-core machine: the two seeds ran at different loads, compare within a
seed only). **Draw calls did not fall** (A 508 / 630 vs today 503 / 616 on average): the kit pieces were already culled
one by one, while one mesh per sim wall is drawn whole whenever any of it is on screen, and each wall is drawn again for
every shadow pass. B costs **more** draw calls (+52 %, +41 %) and objects than today (more, smaller pieces).
**Option A's build time, missed:** 1.37 s and 1.74 s a floor on this machine (1.08-1.42 s in the shot runs), not
"small". It runs behind the loading cover, but it is pure GDScript on the main thread; options if the owner picks A:
build it on a worker thread while the floor loads (it touches no node), or merge each stone row's tops (fewer
vertices). Not done in the prototype.

## What looks off (the agent's read of the shots; the owner judges)
- A's thick walls (up to 5 m: the partitions are two room frames back to back) read from above as a field of laid
  stones, a ruined platform more than a wall; the face texture shows little at the game's camera (the faces are short
  and mostly in shade), the top texture does most of the work.
- A's decimated kit pillars are grey-tinted kit stone next to the owner's brown wall textures: they stand out. Dropping
  them, or tinting them to the wall texture, is a one-line change.
- B looks softer and puffier than today: the decimated copies lose the kit's chips and edges (wall_2m kept 1,569 of
  12,585 triangles), and rows of whole pieces read as stacked blocks; it fixes the overlaps and the stretched pieces,
  not the "stacked" look.
- Some before/after pairs are framed a few metres apart (`red_canyon_door.jpg`, `grain_ruins_*.jpg`): the camera was
  snapped to the same point in each run; the difference was not tracked down.
- In other biomes A uses the same stone layout and the biome's own texture; Frozen Shore's and Starfall's walls are
  not dressed by their BiomeLook (that look covers cover pieces and decoration only).

## Shots (`n10_shots/`, the game's camera, view size 17, 1280 × 720 scaled to 640 wide per panel)
- Ruins, today | A | B: `ruins_start.jpg` (start hall), `ruins_small.jpg` (smallest room), `ruins_big.jpg` (biggest
  room, 2.5 m from its +y wall), `ruins_corner.jpg` (a corner of the biggest room), `ruins_door.jpg` (the start hall's
  first doorway).
- Each other biome, today | A: `night_rocks_{corner,door}.jpg`, `red_canyon_{corner,door}.jpg`,
  `frozen_shore_{corner,door}.jpg`, `starfall_{corner,door}.jpg`.
- O68: `grain_ruins_{start,door,corner}.jpg`.

## Tests
New: `tests/unit/presentation/test_procedural_wall.gd` (13): A is the same for a seed; nothing taller than a chunk
outside the footprints; doorways and niches open; exactly one top over every point 0.33 m inside the union (room
corners included: no gap, no overlap at the joins); the top within 0.55-1.4 m (rebar ≤ +0.5 m); triangles per metre
under 150; under a tenth of the kit pieces on A's walls, light props with niches; crystals still placed along walls;
B's pieces edge to edge per row, never the same piece the same way round side by side, nine in ten within ±15 % of
their length; FIT_LEN = the models' own sizes; the decimated copies ≤ 3k triangles and under a third of the original,
textured; a procedural wall fades with its wall; the style follows the toggle (Ruins A by default) and every biome
finds its two textures; the dev panel's Walls button cycles auto → old → a → b → auto.
Changed on purpose: `tests/content/test_model_manifest.gd` also checks `assets/models/kit_lod/` (`.res`). No existing
count changed: the dresser's default style is the kit (`STYLE_KIT`), so `test_stage_dresser.gd` and the shard tests run
unchanged.

## Commands
```
python3 -I scripts/assets/n10_wall_prep.py                       # the ten textures: seams, brightness; hashes
godot --headless --path . -s scripts/assets/kit_lod.gd           # the four decimated wall pieces; hashes
godot --headless --path . --editor --import --quit
godot --headless --path . -s scripts/content/build_credits.gd
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_procedural_wall.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/debug -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<run_flow, designed_rooms, floor, kit, frozen_shore, starfall, void, dev_panel, dev_master_panel, dev_gate, dev_live_balance e2e> -gexit
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --audio-driver Dummy --resolution 640x360 -s scripts/checks/biome_probe.gd -- biome=ruins seed=<20261008|7> \
  frames=6 settle=6 spots=3 cpu=1 walls=<old|a|b> tag=n10_<walls>_<seed>
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --audio-driver Dummy --resolution 1280x720 -s scripts/shots/walls_n10.gd -- walls=<old|a|b> [biome=<b>] \
  [spots=corner,door] [pan=1] [grain=old tag=a_grain_old]
python3 -I scripts/shots/n10_sheet.py                            # side-by-side JPGs + the shimmer numbers
```

## Raw output
`n10_wall_prep.py`:
```
tex_wall_ruins source:    seam x 10.8 (neighbours 7.3)  y 24.1 (neighbours 6.6)
tex_wall_ruins installed: seam x 10.3 (neighbours 11.3)  y 39.8 (neighbours 11.1)
878525c4827684fd5f4020c99dcc4a4e5176130ae1f0a98bdeff392613d31d70   3301124  assets/textures/kit/tex_wall_ruins.png
tex_wall_top_ruins source:    seam x 26.6 (neighbours 14.3)  y 24.6 (neighbours 14.2)
tex_wall_top_ruins installed: seam x 18.3 (neighbours 20.0)  y 21.5 (neighbours 19.2)
1db1598d612366902cbd2169f9ec9be13a528725795d68f23bbe13c49d3e89dd   3780584  assets/textures/kit/tex_wall_top_ruins.png
tex_wall_night_rocks source:    seam x 11.8 (neighbours 5.8)  y 9.5 (neighbours 5.2)
tex_wall_night_rocks installed: seam x 12.3 (neighbours 11.2)  y 20.4 (neighbours 10.6)
85bdaa51877ed111029f3be9956d52d18e6789176dcfd7996936f1e4138adadd   3232935  assets/textures/kit/tex_wall_night_rocks.png
tex_wall_top_night_rocks source:    seam x 15.0 (neighbours 10.2)  y 15.8 (neighbours 9.8)
tex_wall_top_night_rocks installed: seam x 21.3 (neighbours 17.9)  y 16.2 (neighbours 16.8)
3b014adb6e712469794ea9e962927bff524e64b1920b0619d666cef613dff4d9   3596236  assets/textures/kit/tex_wall_top_night_rocks.png
tex_wall_red_canyon source:    seam x 7.1 (neighbours 3.5)  y 6.5 (neighbours 4.9)
tex_wall_red_canyon installed: seam x 6.5 (neighbours 4.4)  y 9.8 (neighbours 6.5)
7e61bf9410fd4d3088c9526e0fcb69a4df88a74ec6e6559791de36c4cf310422   2542109  assets/textures/kit/tex_wall_red_canyon.png
tex_wall_top_red_canyon source:    seam x 9.1 (neighbours 6.2)  y 11.6 (neighbours 6.6)
tex_wall_top_red_canyon installed: seam x 6.7 (neighbours 6.4)  y 6.0 (neighbours 6.6)
f46a5c6ecd3e666909126726499c9c4340029a2fe0e4bc35ba12e1b116302bf0   2710277  assets/textures/kit/tex_wall_top_red_canyon.png
tex_wall_frozen_shore source:    seam x 22.7 (neighbours 9.0)  y 16.2 (neighbours 7.2)
tex_wall_frozen_shore installed: seam x 14.0 (neighbours 10.0)  y 18.7 (neighbours 8.4)
6d452b0bc3d7032af66816f10abb8e80c8febbd80830ea74c62135195705b00c   3043687  assets/textures/kit/tex_wall_frozen_shore.png
tex_wall_top_frozen_shore source:    seam x 16.9 (neighbours 10.1)  y 19.3 (neighbours 9.0)
tex_wall_top_frozen_shore installed: seam x 8.8 (neighbours 9.1)  y 9.5 (neighbours 7.9)
d7d3006872c34fceb3d48e1321bfe150dcc2cff1b4dc4449fbfef2157683f71f   2932168  assets/textures/kit/tex_wall_top_frozen_shore.png
tex_wall_starfall source:    seam x 7.0 (neighbours 5.9)  y 10.9 (neighbours 5.7)
tex_wall_starfall installed: seam x 14.3 (neighbours 11.8)  y 24.2 (neighbours 12.1)
946c37eadbb0ae5ad1e1e2a0645b5dbaacfeeccbcd674f29691c02d2517c8b47   3279425  assets/textures/kit/tex_wall_starfall.png
tex_wall_top_starfall source:    seam x 16.4 (neighbours 10.8)  y 16.5 (neighbours 10.9)
tex_wall_top_starfall installed: seam x 19.5 (neighbours 17.6)  y 20.4 (neighbours 17.4)
7a74b728d819f7a48fb7d07f5d0f7549d0dcd6b5de875cfb07abe492c74aeb27   3615162  assets/textures/kit/tex_wall_top_starfall.png
```
`kit_lod.gd`:
```
wall_1m: 11711 -> 2925 triangles  c9951c1f633b448ec8d80a50017539d05ff6e28c7fc7d9fac72bd411bdf2ef97  assets/models/kit_lod/wall_1m_lod.res
wall_2m: 12585 -> 1569 triangles  0f7babd0e20c5afb7ed9ea1183902777343bc26c2dada3014aa522e29b70ebb1  assets/models/kit_lod/wall_2m_lod.res
wall_broken: 10864 -> 2715 triangles  3a42355de4972d190c1ec0e20c9d2d986d31b8c40102de0d0bbbc402b945b490  assets/models/kit_lod/wall_broken_lod.res
wall_pillar: 11345 -> 2835 triangles  ff521d7554083c331c4476bb8ad8a27cfe994ec31ec3cf5ee6805ee23dcd2b6d  assets/models/kit_lod/wall_pillar_lod.res
```
`biome_probe.gd` (the lines that matter, per run):
```
walls: style=kit (pref old) wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0 build_ms=13421.6
scene: nodes=6114 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       4458.769  6485.841  6485.841
cpu_ms         4370.000  6100.000  6100.000
render_gpu     4476.988  6472.316  6472.316
draws           503.111   777.000   777.000
objects         860.611  1255.000  1255.000
prims          6356666.278  9815395.000  9815395.000

walls: style=proc (pref a) wall_meshes=288 wall_tris=568346 proc_build_ms=1365.4 build_ms=16242.2
scene: nodes=4576 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       2637.971  3679.893  3679.893
cpu_ms         2666.667  3950.000  3950.000
render_gpu     2585.398  3628.596  3628.596
draws           507.722   608.000   608.000
objects         571.500   661.000   661.000
prims          4877482.778  5801983.000  5801983.000

walls: style=fit (pref b) wall_meshes=2952 wall_tris=7042086 proc_build_ms=0.0 build_ms=14822.6
scene: nodes=7245 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       3957.989  5099.392  5099.392
cpu_ms         3951.111  5230.000  5230.000
render_gpu     3899.967  5057.729  5057.729
draws           766.389   893.000   893.000
objects        1065.167  1324.000  1324.000
prims          6129838.056  7051525.000  7051525.000

walls: style=kit (pref old) wall_meshes=1814 wall_tris=21420831 proc_build_ms=0.0 build_ms=14377.5
scene: nodes=5665 omni_lights=87 (kit fire lights 51) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       2036.064  2741.898  2741.898
cpu_ms         3999.444  5490.000  5490.000
render_gpu     2014.132  2837.207  2837.207
draws           615.556   688.000   688.000
objects         969.833  1106.000  1106.000
prims          6711742.778  8661277.000  8661277.000

walls: style=proc (pref a) wall_meshes=242 wall_tris=453182 proc_build_ms=1737.8 build_ms=13624.1
scene: nodes=4090 omni_lights=87 (kit fire lights 51) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       1194.487  1434.494  1434.494
cpu_ms         2417.222  3230.000  3230.000
render_gpu     1187.825  1418.876  1418.876
draws           630.389   710.000   710.000
objects         682.722   745.000   745.000
prims          5280463.167  7139166.000  7139166.000

walls: style=fit (pref b) wall_meshes=3411 wall_tris=8136717 proc_build_ms=0.0 build_ms=11218.0
scene: nodes=7258 omni_lights=87 (kit fire lights 51) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       1492.594  1962.437  1962.437
cpu_ms         3461.111  4520.000  4520.000
render_gpu     1455.674  1814.151  1814.151
draws           867.278   979.000   979.000
objects        1162.056  1286.000  1286.000
prims          5655058.833  7340930.000  7340930.000
```
`walls_n10.gd` (the shot runs' stats lines):
```
# first shot run, before the O68 fix
walls_n10: biome=ruins walls=a style=proc wall_meshes=288 wall_tris=568172 proc_build_ms=1142.0
walls_n10: biome=frozen_shore walls=a style=proc wall_meshes=288 wall_tris=568172 proc_build_ms=1104.9
walls_n10: biome=night_rocks walls=a style=proc wall_meshes=288 wall_tris=568172 proc_build_ms=1082.5
walls_n10: biome=red_canyon walls=a style=proc wall_meshes=288 wall_tris=568172 proc_build_ms=993.0
walls_n10: biome=starfall walls=a style=proc wall_meshes=288 wall_tris=568172 proc_build_ms=1255.1
walls_n10: biome=ruins walls=b style=fit wall_meshes=2952 wall_tris=7042086 proc_build_ms=0.0
walls_n10: biome=ruins walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=frozen_shore walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=night_rocks walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=red_canyon walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=starfall walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
# second shot run, after the O68 fix
walls_n10: biome=frozen_shore walls=a style=proc wall_meshes=288 wall_tris=568346 proc_build_ms=1210.4
walls_n10: biome=night_rocks walls=a style=proc wall_meshes=288 wall_tris=568346 proc_build_ms=1304.7
walls_n10: biome=red_canyon walls=a style=proc wall_meshes=288 wall_tris=568346 proc_build_ms=1414.1
walls_n10: biome=starfall walls=a style=proc wall_meshes=288 wall_tris=568346 proc_build_ms=1288.7
walls_n10: biome=ruins walls=a style=proc wall_meshes=288 wall_tris=568346 proc_build_ms=1317.1
walls_n10: biome=ruins walls=a style=proc wall_meshes=288 wall_tris=568346 proc_build_ms=1421.4
```
`n10_sheet.py` (shimmer):
```
shimmer a_grain_old  ruins_corner     6.72 (aligned at -6,-1 px)
shimmer a            ruins_corner     1.27 (aligned at -6,-1 px)
shimmer a_grain_old  ruins_door       5.07 (aligned at -6,-1 px)
shimmer a            ruins_door       2.08 (aligned at -6,-1 px)
shimmer a_grain_old  ruins_start      0.96 (aligned at -6,-1 px)
shimmer a            ruins_start      0.85 (aligned at -6,-1 px)
```
`test_procedural_wall.gd`:
```
seed 77: 136896 triangles, 1966 m of face, 69.6 per metre
seed 501: 136968 triangles, 2208 m of face, 62.0 per metre
seed 1234: 143828 triangles, 2168 m of face, 66.3 per metre
seed 77: kit wall pieces 1402 -> 53
seed 501: kit wall pieces 1546 -> 115
seed 1234: kit wall pieces 1504 -> 106
option B: 7448 of 7464 pieces within ±15% of their natural length
wall_1m: 11711 -> 2925 triangles
wall_2m: 12585 -> 1569 triangles
wall_broken: 10864 -> 2715 triangles
wall_pillar: 11345 -> 2835 triangles
13/13 passed.
---- All tests passed! ----
```
Suites: tests/content + tests/arch 136/136 passing; tests/unit/presentation 763/763 passing; tests/unit/debug 16/16 passing; the 11 e2e files 18/18 passing; lint: gdformat --check: "1012 files would be left unchanged"; gdlint: "Success: no problems found". Not run locally: the full suite, the seams, the bot sims (the owner's rule: the lead runs the seams after the merge).
