# CALMER_WALLS: calmer walls in the busy biomes, the same model; one wall style (v0.8.0 Step N15, D53)

- **Status:** RUN (agent: llvmpipe shots under xvfb and a busyness script over them, builder tests; not the owner's
  hardware). How it looks: **OWNER ONLY** (D56).
- **Build:** branch `v080-n15` from `53a39d9`, the working tree before the Step N15 commit (only these docs and the
  PLAN/PROGRESS/OWNER_TODO rows were written after the runs; the commit's SHA is in PROGRESS's Done row). "Before":
  `git archive 53a39d9` unpacked in a scratch folder with its own import cache, with only this step's
  `scripts/shots/walls_n10.gd` (its `mask=1`) copied in, so the before frames are N13's walls. Godot
  `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 (cloud container, 4 cores, no GPU; llvmpipe 20.1.2).
- **Date:** 2026-10-18
- **Who ran it:** agent

Owner (O73, verbatim in [`../PLAN.md`](../PLAN.md)): "Night biome textures look busy - this is true, how could we make
it less bussy keeping this model?"; "Remove the old/B toggles? yes"; "Are the rim and rubble tops OK? - some biomes
look too busy as described"; "Keep the new pillars? - yes".

## How busy: the number
`scripts/shots/walls_n10.gd` (the game's own `WorldViewRoot`, the game's camera at view size 17, 1280 × 720, floor
`SaveLab.floor_world(20261008, 1)`) with `mask=1` saves each spot's frame and the same frame with the procedural walls
flat magenta. `scripts/shots/n15_busyness.py` takes the magenta pixels, eroded 2 px (no outline, no ink line, no fog
edge), and measures on the frame's luma (Rec. 709, 0-1):
- **edge** (the busyness number): the mean Sobel gradient magnitude, how much the image changes pixel to pixel;
- **contrast**: the mean local standard deviation over 9 × 9 px;
- **luma**: the walls' mean brightness (a calmer wall must not just be a darker one); **rel_edge** = edge / luma;
- **area**: the walls' silhouette (the magenta closed over 3 px, so the ink lines inside count): the ruin's shape from
  the camera; **ink**: the share of the silhouette under the ink pass's lines (the modelled edges).

Two spots per biome, `small` (the smallest room) and `corner` (a corner of the biggest room; the biggest room's own
frame is mostly interior cover, under 13 k wall pixels, so it is not measured). The number repeats: the after tree at
N13's values (`n15_repeat`, Night Rocks and Starfall) gave the before tree's numbers to the fourth decimal; Ruins and
Red Canyon (not changed) give the same numbers before and after.

### Before (N13) → after (N15), the mean of the two spots
| biome | edge | change | contrast | luma | rel_edge | area (px) | ink |
|---|---|---|---|---|---|---|---|
| Ruins | 0.0193 → 0.0194 | 0 % (not changed) | 0.0374 → 0.0374 | 0.112 → 0.112 | 0.173 → 0.173 | 258,706 → 258,702 | 0.120 → 0.120 |
| Night Rocks | 0.0291 → **0.0173** | **−40.5 %** | 0.0499 → 0.0357 | 0.083 → 0.098 | 0.354 → 0.179 | 260,156 → 262,447 | 0.118 → 0.109 |
| Red Canyon | 0.0097 → 0.0097 | 0 % (not changed) | 0.0234 → 0.0234 | 0.078 → 0.078 | 0.125 → 0.125 | 258,775 → 258,769 | 0.119 → 0.119 |
| Frozen Shore | 0.0240 → **0.0161** | **−32.9 %** | 0.0634 → 0.0531 | 0.343 → 0.349 | 0.070 → 0.046 | 260,367 → 262,988 | 0.119 → 0.110 |
| Starfall | 0.0407 → **0.0239** | **−41.3 %** | 0.0725 → 0.0524 | 0.181 → 0.205 | 0.226 → 0.117 | 261,724 → 264,012 | 0.121 → 0.111 |

Read: before, the busy ones were Starfall (edge 0.041, the highest), Night Rocks (0.029; by rel_edge the highest,
0.35: a dark wall with a speckled top) and Frozen Shore (0.024, above Ruins' 0.019; its blotchy snow tops). Ruins
(0.019) and Red Canyon (0.010) were the calm ones and are not changed. After: the three busy biomes drop 33-41 % (the
target was ~30 % or more); Starfall is still the busiest (0.024, Ruins 0.019). The silhouette stays: the walls' area
from the camera changes +0.9 % (Night Rocks, Starfall: +2,291 / +2,288 px) and +1.0 % (Frozen Shore), the same ruin;
fewer ink lines cross the walls (−7 to −9 %: fewer missing blocks and smaller steps). The calmer walls are a little
brighter (luma +2 % Frozen Shore, +13 % Starfall, +18 % Night Rocks: less dark noise, a lighter fill), not darker.

A first try (`n15_t1`: detail 0.35, face contrast 0.55, top 0.6, tiles 5.5 / 6 m, stones ×1.5, breaks and jitter
×0.5, fill lumps 1.8 m) dropped Night Rocks 60 % and Starfall 61 %, but the tops read nearly flat (O67: "I don't want to
lose the ruin texture"); not kept.

## What changed
1. **The calming values, per biome, in data** (`BiomeMood`, validated by `problems()`, on the dev panel's lighting
   page like the other mood fields (DevFields lists a mood's fields by reflection; not looked at on screen); the
   defaults are N13's look). In the walls' shader (`WallCalm.SHADER`):
   `wall_detail` (how much of the textures' finest detail stays; the rest blends into a sample 2.5 mips coarser),
   `wall_face_contrast` and `wall_top_contrast` (each texture's contrast round its own mean colour, its last mip; the
   face's lower so the painted blocks don't double the modelled ones). In the builder (`ProceduralWall` rule 6,
   `WallCalm.calm_of`): `wall_stone_scale` (the top's laid stones bigger), `wall_breakage` (missing, recessed and
   chipped blocks, gone top stones and missing quoins), `wall_jitter` (corner and height jitter, round the same mean
   height), `wall_fill_lump_m` and `wall_fill_noise` (bigger, flatter rubble-fill lumps), `wall_tint_noise` (stones' and
   blocks' brightness noise), `wall_fill_shade` (the fill's brightness against the rim's 0.97: a smaller step). Only
   thresholds and ranges scale: the cosmetic stream's draws are the same whatever the values, so a biome at the
   defaults builds N13's walls vertex for vertex (tested). The textures on disk are not changed (no re-install: the
   softening is in the shader, so it stays tunable).
2. **The values chosen** (starting values, from the shots):

| field | default (N13) | Ruins, Red Canyon | Night Rocks | Starfall | Frozen Shore |
|---|---|---|---|---|---|
| `wall_texture_m` / `wall_top_texture_m` | 4.0 / 4.5 | 4.0 / 4.5; 5.0 / 5.0 (as before) | 5.0 / 5.5 | 5.0 / 5.5 | 4.5 / 5.0 |
| `wall_detail` | 1.0 | 1.0 | 0.55 | 0.55 | 0.65 |
| `wall_face_contrast` | 1.0 | 1.0 | 0.7 | 0.7 | 0.8 |
| `wall_top_contrast` | 1.0 | 1.0 | 0.75 | 0.75 | 0.8 |
| `wall_stone_scale` | 1.0 | 1.0 | 1.3 | 1.3 | 1.2 |
| `wall_breakage` | 1.0 | 1.0 | 0.6 | 0.6 | 0.75 |
| `wall_jitter` | 1.0 | 1.0 | 0.6 | 0.6 | 0.75 |
| `wall_fill_lump_m` | 1.2 | 1.2 | 1.6 | 1.6 | 1.5 |
| `wall_fill_noise` | 1.0 | 1.0 | 0.6 | 0.6 | 0.75 |
| `wall_tint_noise` | 1.0 | 1.0 | 0.6 | 0.6 | 0.7 |
| `wall_fill_shade` | 0.66 | 0.66 | 0.76 | 0.76 | 0.72 |

3. **Triangles per metre ≤ N13's** (`test_calmer_walls_cost_no_more_triangles`, three generated floors): Night Rocks
   and Starfall 67.6 → 67.2, 62.0 → 61.8, 65.8 → 65.4; Frozen Shore 67.6 → 67.1, 62.0 → 61.5, 65.8 → 65.4; Ruins and
   Red Canyon unchanged. The shot floor's walls: 170,396 → 168,890 triangles (Night Rocks, Starfall), 168,530 (Frozen
   Shore). Pillars kept (O73: yes): the same 50 / 112 / 102 on the three floors; the fill still sits ~0.4 m under the
   rim (0.43-0.46 m against 0.83-0.85 m).
4. **One wall style (D53: "Remove the old/B toggles? yes"):** gone are `ViewPrefs.wall_style` (and `WALL_STYLES`,
   `next_wall_style`), the dev panel's Walls button and its readout (F10 → Tools), `DevWalls`, `UI_DEV_WALL_STYLE`,
   `StageView.resolved_wall_style` and `wall_style`, `StageDresser.STYLE_KIT` / `STYLE_PROC` / `STYLE_FIT` and the kit's
   exterior-wall tiling (`_dress_wall`, `_fill`, option B's `_dress_wall_fit`, `_fit`, `fit_sequence`, `FIT_*`, the low
   broken wall behind a light), `KitModels.get_lod_piece` / `LOD_DIR`, `StageKit.piece_of`'s `lod`, the decimated
   `assets/models/kit_lod/` copies, `scripts/assets/kit_lod.gd`, their four manifest rows and the credits' sentence
   (`data/credits/licences.tres` rebuilt by `scripts/content/build_credits.gd`: the owner-supplied entry's files 89 → 85), and
   the probes' `walls=` (`biome_probe.gd`, `load_probe.gd`, `walls_n10.gd`). The dresser draws every structural wall
   the builder handles (all of them on generated floors: tested over five biomes × three seeds and 40 seeds) with only
   its light props; a structural wall it could not draw would be dressed as cover. The kit pieces stay where they are
   used: light props, interior cover, designed rooms' pieces. `grep` over `src scripts tests locale data assets` for
   `wall_style`, `STYLE_FIT`, `kit_lod`, `get_lod_piece`, `DevWalls`, `UI_DEV_WALL_STYLE`, `resolved_wall_style`,
   `fit_sequence`: one match, the test that asserts the decimated copies are gone
   (`test_procedural_wall.gd:427`).

## Shots (`n15_shots/`, the game's camera, 1280 × 720 scaled to 640 wide; left N13, right N15)
`<biome>_small.jpg` (the smallest room), `<biome>_corner.jpg` (a corner of the biggest room) for `ruins`,
`night_rocks`, `red_canyon`, `frozen_shore`, `starfall` (`scripts/shots/n15_sheet.py`). The agent's read (the owner
judges): Night Rocks' and Starfall's tops lose the fine speckle and read as stones; the painted blocks on the faces
are fainter behind the modelled courses; the rims have fewer gaps and steps, the rubble fill bigger and flatter; the
ruin's outline (slumps, breaks, pillars) is the same. Ruins and Red Canyon are the same frames.

## Tests
`tests/unit/presentation/test_procedural_wall.gd` (13, was 15): removed the option B tests (`…lays_whole_pieces…`,
`…lengths_are_the_models_own`, `…decimated_copies_are_light`), `test_the_wall_style_follows_the_dev_toggle` and
`test_the_dev_panel_walls_button_cycles_the_style`; `test_no_kit_pieces_on_the_exterior_walls_in_any_biome` now checks
the dresser's only path (no kit piece on a structural wall, every structural wall drawn by the builder, every cover
slab dressed, every light in its niche); new `test_every_biome_draws_its_own_procedural_walls` (tile sizes and
textures per biome; no Walls button, no readout, no decimated copies), `test_each_biome_calms_its_walls_from_its_data`
(the defaults are N13's builder and shader, vertex for vertex; out-of-range values are flagged; each biome validates
and its shader values reach the material), `test_calmer_walls_cost_no_more_triangles`.
`tests/unit/presentation/test_stage_dresser.gd`: "every wall is dressed" → every slab dressed, every structural wall
built by the builder. `tests/content/test_model_manifest.gd`: the `kit_lod` folder is no longer listed.

## Commands
```
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/unit/debug -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_floor.gd,res://tests/e2e/test_e2e_kit.gd,res://tests/e2e/test_e2e_designed_rooms.gd,res://tests/e2e/test_e2e_frozen_shore.gd,res://tests/e2e/test_e2e_starfall.gd,res://tests/e2e/test_e2e_void.gd,res://tests/e2e/test_e2e_loading_cover.gd,res://tests/e2e/test_e2e_arrival.gd,res://tests/e2e/test_e2e_dev_master_panel.gd -gexit
godot --headless --path . -s scripts/content/build_credits.gd
# before (in the 53a39d9 copy) and after (here), each biome:
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --audio-driver Dummy --resolution 1280x720 -s scripts/shots/walls_n10.gd -- biome=<b> spots=small,corner mask=1 \
  tag=<n15_before|n15_after>      # the before copy also took walls=a
python3 -I scripts/shots/n15_busyness.py n15_before n15_after
python3 -I scripts/shots/n15_sheet.py && cp build/shots/n15_sheet/*.jpg docs/roadmap/v0.8.0/evidence/n15_shots/
```
The tries took `set=<field>:<value>,…` on `walls_n10.gd` (the mood's fields for that run only).

## Raw output
`n15_busyness.py n15_before n15_after`:
```
n15_before frozen_shore_corner    edge=0.0229 contrast=0.0598 luma=0.339 rel_edge=0.068 rel_contrast=0.176 area= 197455 ink=0.111
n15_before frozen_shore_small     edge=0.0251 contrast=0.0670 luma=0.347 rel_edge=0.072 rel_contrast=0.193 area= 323280 ink=0.127
n15_before night_rocks_corner     edge=0.0278 contrast=0.0464 luma=0.074 rel_edge=0.376 rel_contrast=0.628 area= 197050 ink=0.111
n15_before night_rocks_small      edge=0.0305 contrast=0.0533 luma=0.092 rel_edge=0.331 rel_contrast=0.579 area= 323262 ink=0.126
n15_before red_canyon_corner      edge=0.0087 contrast=0.0197 luma=0.069 rel_edge=0.126 rel_contrast=0.286 area= 197539 ink=0.111
n15_before red_canyon_small       edge=0.0107 contrast=0.0270 luma=0.086 rel_edge=0.124 rel_contrast=0.313 area= 320011 ink=0.126
n15_before ruins_corner           edge=0.0186 contrast=0.0348 luma=0.105 rel_edge=0.177 rel_contrast=0.330 area= 197480 ink=0.113
n15_before ruins_small            edge=0.0201 contrast=0.0399 luma=0.119 rel_edge=0.169 rel_contrast=0.337 area= 319933 ink=0.127
n15_before starfall_corner        edge=0.0401 contrast=0.0697 luma=0.169 rel_edge=0.237 rel_contrast=0.411 area= 198598 ink=0.113
n15_before starfall_small         edge=0.0412 contrast=0.0754 luma=0.192 rel_edge=0.215 rel_contrast=0.392 area= 324851 ink=0.128
n15_before frozen_shore (mean)    edge=0.0240 contrast=0.0634 luma=0.343 rel_edge=0.070 rel_contrast=0.185 area= 260367 ink=0.119
n15_before night_rocks (mean)     edge=0.0291 contrast=0.0499 luma=0.083 rel_edge=0.354 rel_contrast=0.604 area= 260156 ink=0.118
n15_before red_canyon (mean)      edge=0.0097 contrast=0.0234 luma=0.078 rel_edge=0.125 rel_contrast=0.300 area= 258775 ink=0.119
n15_before ruins (mean)           edge=0.0193 contrast=0.0374 luma=0.112 rel_edge=0.173 rel_contrast=0.333 area= 258706 ink=0.120
n15_before starfall (mean)        edge=0.0407 contrast=0.0725 luma=0.181 rel_edge=0.226 rel_contrast=0.402 area= 261724 ink=0.121
n15_after frozen_shore_corner    edge=0.0151 contrast=0.0505 luma=0.343 rel_edge=0.044 rel_contrast=0.147 area= 198447 ink=0.109
n15_after frozen_shore_small     edge=0.0171 contrast=0.0556 luma=0.356 rel_edge=0.048 rel_contrast=0.156 area= 327529 ink=0.112
n15_after night_rocks_corner     edge=0.0162 contrast=0.0322 luma=0.087 rel_edge=0.185 rel_contrast=0.368 area= 197917 ink=0.102
n15_after night_rocks_small      edge=0.0185 contrast=0.0393 luma=0.108 rel_edge=0.172 rel_contrast=0.365 area= 326978 ink=0.115
n15_after red_canyon_corner      edge=0.0087 contrast=0.0198 luma=0.069 rel_edge=0.126 rel_contrast=0.286 area= 197544 ink=0.111
n15_after red_canyon_small       edge=0.0107 contrast=0.0270 luma=0.086 rel_edge=0.124 rel_contrast=0.313 area= 319994 ink=0.126
n15_after ruins_corner           edge=0.0186 contrast=0.0348 luma=0.105 rel_edge=0.177 rel_contrast=0.330 area= 197481 ink=0.113
n15_after ruins_small            edge=0.0201 contrast=0.0399 luma=0.119 rel_edge=0.169 rel_contrast=0.337 area= 319923 ink=0.127
n15_after starfall_corner        edge=0.0230 contrast=0.0486 luma=0.192 rel_edge=0.120 rel_contrast=0.253 area= 199539 ink=0.105
n15_after starfall_small         edge=0.0249 contrast=0.0562 luma=0.217 rel_edge=0.115 rel_contrast=0.259 area= 328486 ink=0.117
n15_after frozen_shore (mean)    edge=0.0161 contrast=0.0531 luma=0.349 rel_edge=0.046 rel_contrast=0.152 area= 262988 ink=0.110
n15_after night_rocks (mean)     edge=0.0173 contrast=0.0357 luma=0.098 rel_edge=0.179 rel_contrast=0.367 area= 262447 ink=0.109
n15_after red_canyon (mean)      edge=0.0097 contrast=0.0234 luma=0.078 rel_edge=0.125 rel_contrast=0.300 area= 258769 ink=0.119
n15_after ruins (mean)           edge=0.0194 contrast=0.0374 luma=0.112 rel_edge=0.173 rel_contrast=0.333 area= 258702 ink=0.120
n15_after starfall (mean)        edge=0.0239 contrast=0.0524 luma=0.205 rel_edge=0.117 rel_contrast=0.256 area= 264012 ink=0.111
```
(The Ruins mean prints 0.0193 before and 0.0194 after from the same per-shot values 0.0186 / 0.0201: rounding.)

`n15_repeat` (the after tree at N13's values, before the data changed):
```
n15_repeat night_rocks (mean)     shots=2 edge=0.0291 contrast=0.0499 luma=0.083 rel_edge=0.354 rel_contrast=0.604
n15_repeat starfall (mean)        shots=2 edge=0.0407 contrast=0.0725 luma=0.181 rel_edge=0.226 rel_contrast=0.402
```
`walls_n10.gd` stage lines, after:
```
walls_n10: biome=ruins wall_meshes=148 wall_tris=170396 proc_build_ms=1283.4
walls_n10: biome=night_rocks wall_meshes=148 wall_tris=168890 proc_build_ms=1429.0
walls_n10: biome=red_canyon wall_meshes=148 wall_tris=170396 proc_build_ms=1564.2
walls_n10: biome=frozen_shore wall_meshes=148 wall_tris=168530 proc_build_ms=1647.5
walls_n10: biome=starfall wall_meshes=148 wall_tris=168890 proc_build_ms=1342.3
```
(before, every biome: `wall_meshes=148 wall_tris=170396`.)

`test_procedural_wall.gd` (inside the `tests/unit/presentation` run):
```
    seed 77: 132924 triangles, 1966 m of face, 67.6 per metre
    seed 501: 136804 triangles, 2208 m of face, 62.0 per metre
    seed 1234: 142766 triangles, 2168 m of face, 65.8 per metre
    ruins seed 77: 67.6 -> 67.6 triangles per metre; pillars 50; fill 1527 m2 at 0.42 m, rim at 0.82 m
    ruins seed 501: 62.0 -> 62.0 triangles per metre; pillars 112; fill 1146 m2 at 0.44 m, rim at 0.84 m
    ruins seed 1234: 65.8 -> 65.8 triangles per metre; pillars 102; fill 1129 m2 at 0.44 m, rim at 0.84 m
    night_rocks seed 77: 67.6 -> 67.2 triangles per metre; pillars 50; fill 1527 m2 at 0.43 m, rim at 0.84 m
    night_rocks seed 501: 62.0 -> 61.8 triangles per metre; pillars 112; fill 1146 m2 at 0.46 m, rim at 0.85 m
    night_rocks seed 1234: 65.8 -> 65.4 triangles per metre; pillars 102; fill 1129 m2 at 0.44 m, rim at 0.85 m
    red_canyon seed 77: 67.6 -> 67.6 triangles per metre; pillars 50; fill 1527 m2 at 0.42 m, rim at 0.82 m
    red_canyon seed 501: 62.0 -> 62.0 triangles per metre; pillars 112; fill 1146 m2 at 0.44 m, rim at 0.84 m
    red_canyon seed 1234: 65.8 -> 65.8 triangles per metre; pillars 102; fill 1129 m2 at 0.44 m, rim at 0.84 m
    frozen_shore seed 77: 67.6 -> 67.1 triangles per metre; pillars 50; fill 1527 m2 at 0.43 m, rim at 0.83 m
    frozen_shore seed 501: 62.0 -> 61.5 triangles per metre; pillars 112; fill 1146 m2 at 0.45 m, rim at 0.85 m
    frozen_shore seed 1234: 65.8 -> 65.4 triangles per metre; pillars 102; fill 1129 m2 at 0.44 m, rim at 0.85 m
    starfall seed 77: 67.6 -> 67.2 triangles per metre; pillars 50; fill 1527 m2 at 0.43 m, rim at 0.84 m
    starfall seed 501: 62.0 -> 61.8 triangles per metre; pillars 112; fill 1146 m2 at 0.46 m, rim at 0.85 m
    starfall seed 1234: 65.8 -> 65.4 triangles per metre; pillars 102; fill 1129 m2 at 0.44 m, rim at 0.85 m
```
Suites (Run Summary lines):
```
tests/unit/presentation:            Tests 775, Passing Tests 775 (900.972 s)
tests/content, tests/arch, tests/unit/debug: Scripts 33, Tests 153, Passing Tests 153
e2e (the ten files above):          Scripts 10, Tests 16, Passing Tests 16 (257.375 s)
```
