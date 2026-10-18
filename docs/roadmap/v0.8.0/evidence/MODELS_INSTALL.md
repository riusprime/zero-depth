# MODELS_INSTALL: the owner's v0.8.0 models in game, each only in the biome it fits (v0.8.0 Step MI)

- **Status:** RUN (agent: offline preparation, llvmpipe shots and probes under xvfb, the tests listed below; not the
  owner's hardware). How it looks and plays: **OWNER ONLY** (D58).
- **Build:** branch `v080-mi`: the models, pools and enemies in `622ae45` (from `a6f0732`), merged with
  `claude/lucid-fermat-9wv2tf` at `0a10c28` (N17, N18, the raw Ascension portal) in `c2a5561`; the Ascension portal
  and the model warm-up in `bbf8bad`; these docs after it. "Before": `git archive
  a6f0732` unpacked in a scratch folder with its own import cache. Godot `4.7.2.stable.official.ed1daf0bf`; Linux
  6.18.44 (cloud container, 4 cores, no GPU; llvmpipe 20.1.2). The machine was shared with other agents' runs (load
  average 7-10 on 4 cores during the probes): **frame times and load times are not comparable between runs**;
  draw calls, triangles and node counts are.
- **Date:** 2026-10-18
- **Who ran it:** agent

Owner (verbatim in [`../PLAN.md`](../PLAN.md), O77-O79 and O81): "ground star is currently a rectangle on the ground I
created this texture but I want you to not make it a random rectangle but give it a crack shape, use the image there
is no 3d object"; "enemies are not animated and will need to be animated if needed"; "the moss island goes in Night
Rocks …"; "the ones that not fit by context like the car should not go in every biome,, let's keep car just for
ruins"; "we need to redo the template basic rooms where we generate each biomes with the new assets right? …"; "Also
cap the observatory max to 1 per floor in starfall …"; "this is the ascension portal to replace, but it has no light
beam, you have to place a new nice light purple violet beam of light …".

## 1. Preparing the models offline
```
python3 -I scripts/assets/mi_prep.py            # every model and ground_star (re-runnable; raw files untouched)
python3 -I scripts/assets/mi_prep.py <id> ...   # only those
```
(needs numpy, Pillow, `meshoptimizer==0.2.30a0`, `xatlas==0.0.11`, scipy; an offline tool, nothing shipped). Per
model: turned into the game's frame (a kit piece's long side on +X; an enemy's and a device's front on +X, read from
`scripts/shots/mi_models.gd` renders of the raw files), centred, scaled evenly to its request row's height; welded
and simplified (meshoptimizer, positions only) to its role's budget; a new UV atlas (xatlas) and the owner's colour map
baked onto it (each texel the colour of the raw surface nearest it, facing the same way), padded, brightened toward a
mean of 0.5 by at most 2.2× for room pieces (the raw maps average about 0.25 and read black under the night moods,
as the kit's did, `kit_prep.py`); normals smooth within 40°. The raw roughness and normal maps are dropped. Raw files
stay in `unprocessed_images/models_v080/`.

Budgets: small decoration 1,000 triangles and 512 px; cover and props 3,000 / 1024 px; big set pieces (building
corner, stone arch, mesa chunk, wagon wreck, boat wreck, observatory) 6,000 / 1024 px; floating islands 3,000 (many
of them drift in a void at once); void spikes 1,000 / 512 px; enemies 5,000 / 1024 px (the Lens Drone 3,000 / 512);
the Loop device and the Ascension portal 8,000 / 1024 px. All 34 meet their budget (the enemies' parts and glow
surfaces are simplified apart with locked borders: up to +1.4 % over).

Raw → in game (triangles, and file sizes: the `.glb` with its embedded map; the import also writes the map as
`<id>_albedo.jpg` beside it):

| id | raw file | raw triangles | raw size | triangles in game / budget | file | map |
|---|---|---|---|---|---|---|
| `building_corner` | | 31,200 | 3.8 MB | 5,998 / 6,000 | 753 KB | 1024 px |
| `ladder_frame` | | 32,401 | 3.8 MB | 2,999 / 3,000 | 444 KB | 1024 px |
| `column_broken` | | 34,019 | 3.7 MB | 2,994 / 3,000 | 423 KB | 1024 px |
| `pipe_bundle` | | 35,077 | 4.5 MB | 2,993 / 3,000 | 537 KB | 1024 px |
| `barricade` | | 32,452 | 4.2 MB | 2,997 / 3,000 | 502 KB | 1024 px |
| `tire_stack` | | 25,333 | 6.4 MB | 2,999 / 3,000 | 445 KB | 1024 px |
| `boulder_small` | | 27,904 | 3.2 MB | 1,000 / 1,000 | 132 KB | 512 px |
| `rock_spire` | | 27,970 | 3.4 MB | 2,995 / 3,000 | 400 KB | 1024 px |
| `stone_arch` | | 33,011 | 4.2 MB | 6,000 / 6,000 | 755 KB | 1024 px |
| `mushroom_cluster` | | 32,695 | 4.5 MB | 997 / 1,000 | 161 KB | 512 px |
| `bone_pile` | | 33,001 | 6.4 MB | 995 / 1,000 | 165 KB | 512 px |
| `floating_island_moss` | | 32,304 | 4.9 MB | 2,998 / 3,000 | 460 KB | 1024 px |
| `mesa_chunk` | | 27,267 | 3.5 MB | 6,000 / 6,000 | 734 KB | 1024 px |
| `dry_shrub` | | 32,056 | 4.3 MB | 1,000 / 1,000 | 160 KB | 512 px |
| `cactus` | | 28,820 | 4.3 MB | 2,995 / 3,000 | 470 KB | 1024 px |
| `wagon_wreck` | | 34,170 | 5.8 MB | 5,997 / 6,000 | 821 KB | 1024 px |
| `cattle_skull_post` | | 32,800 | 4.5 MB | 2,996 / 3,000 | 491 KB | 1024 px |
| `snow_drift` | | 27,830 | 3.2 MB | 1,000 / 1,000 | 131 KB | 512 px |
| `ice_shard` | | 27,502 | 7.2 MB | 1,000 / 1,000 | 153 KB | 512 px |
| `ice_rock` | | 28,996 | 5.5 MB | 2,993 / 3,000 | 465 KB | 1024 px |
| `boat_wreck` | `ice_floe.glb` (it holds a frozen boat) | 32,390 | 5.5 MB | 6,000 / 6,000 | 821 KB | 1024 px |
| `fish_rack` | | 36,782 | 4.7 MB | 2,971 / 3,000 | 540 KB | 1024 px |
| `star_crystal` | | 27,827 | 7.7 MB | 998 / 1,000 | 149 KB | 512 px |
| `meteorite` | | 27,235 | 6.5 MB | 1,000 / 1,000 | 157 KB | 512 px |
| `star_monolith` | | 26,440 | 4.9 MB | 2,998 / 3,000 | 469 KB | 1024 px |
| `floating_island_starfall` | | 33,130 | 9.8 MB | 2,983 / 3,000 | 496 KB | 1024 px |
| `void_spike` | | 25,852 | 6.8 MB | 1,000 / 1,000 | 163 KB | 512 px |
| `ruined_observatory` | | 34,291 | 5.1 MB | 5,996 / 6,000 | 803 KB | 1024 px |
| `loop_device` | | 58,707 | 8.8 MB | 8,000 / 8,000 | 1,079 KB | 1024 px |
| `ascension_portal` | | 97,574 | 9.9 MB | 7,992 / 8,000 | 1,085 KB | 1024 px |
| `mender` | | 14,553 | 4.6 MB | 5,013 / 5,000 | 719 KB | 1024 px |
| `shield_bearer` | | 14,205 | 3.0 MB | 5,011 / 5,000 | 672 KB | 1024 px |
| `splitter` | | 28,590 | 4.8 MB | 5,068 / 5,000 | 837 KB | 1024 px |
| `lens_drone` | | 14,181 | 7.1 MB | 3,001 / 3,000 | 402 KB | 512 px |

Raw total (the 34 files): 189.5 MB of `.glb`; in game 17.4 MB of `.glb` (and about as much again in the extracted
maps). Textures are one map per model (each Tripo file has its own atlas, so none can be shared across models); an
enemy's parts share their model's one map, and the Splitling draws the Splitter's model at 62 %.

`ground_star.webp` (1536 × 1024) → `assets/textures/kit/ground_star.png`: the middle square, made seamless by an
offset cross-fade (as `kit_prep.py`'s ground), 1024 px, imported with mipmaps (VRAM compressed). Its crack masks,
`ground_star_cracks.png` (1024 px, four 512 px shapes; R the crack, G its soft halo), are drawn by the same script
(jagged branching polylines from near the middle out to all four sides, tapering, soft-edged; seed 80018).

## 2. Where each piece went: the per-biome pools (owner O78, O79)
Every footprint is dressed by its role and each biome draws a role from its own pool (`BiomeLook.pools`,
`data/biomes/*.tres`); the city kit is Ruins' only. Weights in each cell; "—" keeps the Ruins kit's piece (only Ruins
has that: its decoration is the kit's).

| role | Ruins | Night Rocks | Red Canyon | Frozen Shore | Starfall |
|---|---|---|---|---|---|
| cover_square | crate_stack 6, rock_large 2, tire_stack 1, column_broken 1 | rock_large 3, rock_spire 2, dead_tree 1 | mesa_chunk 3, rock_large 1, cactus 1 | ice_rock 3, rock_large 1, dead_tree 1 | star_monolith 2, rock_large 2 |
| cover_block | slab_concrete 5, building_corner 1 | rock_large 1 | mesa_chunk 1 | ice_rock 1 | star_monolith 2, ruined_observatory 1 |
| cover_long | slab_wide 3, slab_concrete 2, barricade 1, pipe_bundle 1 | rock_large 1 | mesa_chunk 1 | ice_rock 1 | star_monolith 1 |
| cover_wall | wall_broken 3, barricade 1 | rock_large 1 | mesa_chunk 1 | ice_rock 1 | star_monolith 1 |
| cover_post | wall_pillar 2, column_broken 1 | rock_spire 2, dead_tree 1 | cactus 2, cattle_skull_post 1 | ice_rock 1, dead_tree 1 | star_monolith 1 |
| cover_deep | car_wreck 1 | stone_arch 1, rock_large 2 | wagon_wreck 3, mesa_chunk 1 | boat_wreck 3, ice_rock 1 | star_monolith 1 |
| landmark | building_corner 3, slab_concrete 1 | stone_arch 2, rock_large 1 | wagon_wreck 1, mesa_chunk 1 | boat_wreck 1, ice_rock 1 | ruined_observatory 2, star_monolith 1 |
| wall_prop | ladder_frame 1 | — | cattle_skull_post 1 | fish_rack 1 | — |
| decor_grass | — (grass_tuft) | grass_tuft 3, mushroom_cluster 1 | dry_shrub 1 | snow_drift 1 | star_crystal 1 |
| decor_rubble | — (rubble_small) | boulder_small 2, rubble_small 1 | rubble_small 1 | ice_shard 1 | meteorite 1 |
| decor_debris | — (debris_low: scrap) | bone_pile 1 | dry_shrub 1, rubble_small 1 | snow_drift 1 | meteorite 1 |
| void_island | — | floating_island_moss 1 (`edge = islands`) | — | — | floating_island_starfall 1 |
| void_spike | — | — | — | — | void_spike 1 |

**Caps a floor (`max_per_floor`):** ruined_observatory **1** (the owner's), stone_arch 2, wagon_wreck 3, boat_wreck 3,
building_corner 4 (the lead's starting values: D58). Every pool keeps an uncapped piece (validated), so a capped
landmark gives way to its pool's other piece. `tests/unit/presentation/test_stage_dresser.gd`
`test_a_capped_landmark_never_repeats_on_a_floor`: 24 Starfall run floors with the designed rooms, none draws two
observatories, and some draw one.

**Shared across biomes on purpose:** rock_large (a plain faceted boulder) in all five and dead_tree in Night Rocks and
Frozen Shore (the biome reference's bare trees in the snow). Light props are unchanged: the rusty oil drum
(`fire_barrel`) and the iron brazier still light every biome. **Listed, not redesigned:** the oil drum reads as a city
prop outside Ruins (visible in the Starfall and Frozen Shore shots below) (D58).

**How a role is drawn:** a pool piece goes only where it fits the footprint's shorter side (`min_foot` /
`max_foot` in `KitModels.SPECS`: the building corner and the observatory only on blocks 1.8 / 1.9 m or more, the
cactus, skull post, tyres, column and spire only on small footprints); a footprint much longer than the chosen piece's
own proportions is tiled with it (`StageDresser.TILE_ASPECT` 1.8, up to 8 copies), so a mesa or an ice rock is never
stretched into a 5 m wall; the owner's pieces keep their own colours (KitModels `tint` 0) and their own height (the
designed rooms' heights were set for the Ruins kit). Rule 1 holds: every tall piece stays in its sim footprint (the
dresser tests, every biome). Wall props stand in a niche the procedural wall leaves, inside the wall, front to the
room (`test_wall_props_stand_inside_their_wall`).

**Designed rooms (O79):** `scripts/content/room_layouts.py` now writes roles into the 24 layouts
(`data/room_layouts/*.tres`): crate stacks, rocks and trees → `cover_square`, concrete slabs 1.4 m+ both ways →
`cover_block`, the rest and wide slabs → `cover_long`, broken walls → `cover_wall`, pillars → `cover_post`, car wrecks
→ `cover_deep`, grass / rubble / debris → `decor_grass` / `decor_rubble` / `decor_debris`; each layout's biggest block
of 5 m² or more is its `landmark` (17 of 24 layouts have one). Footprints, solids and heights are unchanged (the sim
reads no piece name; its room tests pass unchanged: `test_room_layouts`, `test_room_themes`, `test_shop_rooms`, 14/14).
The generator's own vignettes (`RoomThemes`, sim code) still carry kit names; the dresser maps them onto the same roles
(`StageDresser.ROLE_OF`).

## 3. The enemies: parts cut offline, animated in code (owner O77)
No rig: `mi_prep.py` cuts each model into the parts that move (one glTF node each, its origin at its pivot) and, in
each part, into surfaces by what the colour map shows there: `base` (charcoal frame, bone: as delivered), `role` (the
plates: greyscale in the map, tinted in the kind's role colour, `EnemyPalettes`, so the shipped palette A and the
others still apply: the owner's violet Mender reads green, his red Lens Drone the palette's violet) and `glow` (eyes,
seam, crystals: the avatar's accent material, which the windup's tell already pulses). Parts (renders:
`scripts/shots/mi_models.gd -- parts=1`):
- **Shield Bearer:** the tower shield (its own connected piece), two legs (below the hips, by side), the body;
- **Splitter / Splitling:** the two halves (by side of the seam), two arms with their claws (past the shoulders), two
  legs;
- **Mender:** the cross over the hood (a height band), the arms holding the crystals (a side band), the robe;
- **Lens Drone:** the ring of little feet under the pod, the pod.

`HordeAvatar` / `LensDroneAvatar` build from `EnemyModels` when the file is there (the code bodies stay as the
fallback, tested) and pose the parts from the same inputs as before: the walk from how fast the node moves (legs
swing, a small bob); the windup's raise-and-hold (O25: the Shield Bearer's shield lifted and drawn back, the
Splitter's claws up and out, held to the hit), the strike's snap (the bash, the chop and swipe), the Mender's float,
sway, turning cross and crystals raised and lit while it heals, the Lens Drone's spinning feet and flaring eye, the hit
flash (ActorViews' flash on the two body materials), and a 0.4 s death (tips back and shrinks; the Splitter's halves
fly apart as its Splitlings appear). No drawn outline (as the owner asked for his boss models); the X-ray twin stays.
Tests: `test_horde_avatars.gd` (14 cases, 6 new).

## 4. The Loop device, the Ascension portal and the ground_star cracks
- **Loop device:** the owner's pad replaces the code-made stone disc, sized to the sim's pad; the rim glow, the upright
  ring with its chasing arrowheads, the veil and the green light stay on top as before. N18 removed its label.
- **Ascension portal (O81):** the owner's dais, pillars and crystals replace the code-made dais and spire, its circle
  under the walk-in; the beam is new code after the reference image: three soft additive shafts (haze, body, core;
  soft toward their silhouettes, fading up), narrow streaks pulsing up them, a glow and a glowing violet ring on the
  dais, the model's nine floating crystals bobbing and turning, small violet shards rising in the beam, one violet
  omni light (no shadow). Reduced motion: no scrolling, bobbing or rising shards. Its colours `#E2D2FF` / `#9F78FF`
  are violet like the Deep gate's `#8B3DFF` (RGB distance 0.68 for the core, 0.24 for the edge; 0.73 / 0.66 from the
  Loop device's green `#3DE0A8`): the portal's other constants and its loading cover are unchanged; it reads apart from
  the green Loop device beside it (shots).
- **ground_star:** Starfall's starglow pools are drawn as cracks: one quad over each sim pool, one of the four crack
  shapes turned or mirrored (eight ways) from the cosmetic stream, the owner's texture sampled in world space showing
  through the crack with a violet halo, and a faint wash (alpha 0.16) over the rest of the rect. One mesh and one
  material for every pool of a floor (it was two: the faceted sheet and its rim). **The speed area is still the sim's
  rectangle**: the cracks reach its four sides, but the rect itself now reads only faintly (D58).

## 5. Measured
### Commands
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --audio-driver Dummy --resolution 1280x720 -s scripts/checks/biome_probe.gd -- biome=<id> frames=20 spots=2 tag=<before|after>
godot --headless --fixed-fps 60 --path . -s scripts/checks/load_probe.gd
```
Each in the after tree (this branch before the merge, `622ae45`) and the before tree (`a6f0732`). Floor
`SaveLab.floor_world(20261008, 1)`, two spots, 20 frames each.

### Per biome (biome_probe; draws, objects and prims are the frame's draw calls, objects and primitives, shadow
passes included; average of the 40 frames)
| biome | draws before → after | objects before → after | prims (triangles drawn) before → after | wall meshes' triangles before → after | frame_ms avg before / after (not comparable) | cpu_ms avg before / after |
|---|---|---|---|---|---|---|
| Ruins | 636.5 → 735.5 (+15.6 %) | 689.5 → 783.0 | 7,123,785 → 8,060,700 (+13.2 %) | 170,396 → 176,176 | 6671 / 2590 | 5142 / 5152 |
| Night Rocks | 646.5 → 782.0 (+21.0 %) | 698.5 → 865.5 | 6,885,126 → 6,310,230 (−8.4 %) | 168,890 → 168,890 | 3908 / 4544 | 4831 / 4670 |
| Red Canyon | 672.0 → 639.0 (−4.9 %) | 727.0 → 737.0 | 7,187,807 → 2,934,849 (−59.2 %) | 170,396 → 178,444 | 2220 / 2600 | 5265 / 3714 |
| Frozen Shore | 719.0 → 724.5 (+0.8 %) | 776.5 → 812.5 | 958,560 → 798,309 (−16.7 %) | 168,530 → 173,876 | 1733 / 2515 | 3703 / 3651 |
| Starfall | 720.5 → 720.0 (−0.1 %) | 777.0 → 813.0 | 959,116 → 2,194,164 (+128.8 %) | 168,890 → 168,890 | 2055 / 2712 | 3783 / 3957 |

Raw lines (after; the before tree's are in the same form, `probe_ruins_before` re-run alone because the first before
pass's Ruins run was killed):
```
biome_probe: biome=ruins seed=20261008 floor=1 spots=2 frames=20 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
walls: wall_meshes=148 wall_tris=176176 proc_build_ms=1465.7 build_ms=14697.3
scene: nodes=4488 omni_lights=105 (kit fire lights 62) spot_lights=0 particles=3
metric          avg       p95       max
frame_ms       2590.195  3872.418  4212.083
cpu_ms         5151.500  7170.000  7210.000
draws           735.500   820.000   820.000
objects         783.000   883.000   883.000
prims          8060700.000  10032178.000  10032178.000
[… night_rocks, red_canyon, frozen_shore, starfall: the table's numbers …]
before (ruins): walls: wall_meshes=148 wall_tris=170396 proc_build_ms=2405.4 build_ms=18998.4
frame_ms 6671.289 9183.805 · cpu_ms 5142.250 6870.000 · draws 636.500 650.000 · objects 689.500 694.000 · prims 7123785.000 8145075.000
```
The wall meshes' triangles change where a wall prop's niche is cut (Ruins' ladders, Red Canyon's skull posts, Frozen
Shore's fish racks). Targets: none were set for this step; the budgets are the per-model triangle caps of §1 (met).
**Two biomes draw more:** Ruins (+15.6 % draws, +13.2 % triangles: its new pieces) and Starfall (+129 % triangles:
the void's islands and spikes are now the owner's models: islands 3 k, spikes 1 k triangles each, many of them; still
about a quarter of Ruins'); Night Rocks +21 % draw calls (more piece kinds and tiled pieces, the moss islands). Not
retuned (no target; reported).

### Loads (load_probe, headless: the cover's longest frame, the load's total, the models' read phase)
| load | longest frame before → after (ms) | covered total before → after (ms) | models read before → after (ms) |
|---|---|---|---|
| new run (floor 1, Night Rocks; the session's first: the models are read) | 62.5 → 106.8 | 13,997.5 → 17,713.9 | 8,861.7 → 12,072.9 |
| gate (floor 2) | 45.0 → 63.6 | 4,903.7 → 4,745.5 | 23.1 → 14.7 |
| continue | 48.0 → 164.4 | 4,309.6 → 4,724.6 | 11.6 → 27.1 |
| deep (floor 3, Ruins) | 55.3 → 408.6 | 5,881.9 → 5,635.5 | 20.1 → 55.5 |
| ascension (final arena) | 38.6 → 51.5 | 5,412.2 → 3,545.6 | 4,339.9 → 2,623.0 |
| restart | 45.9 → 210.8 | 7,993.5 → 5,762.2 | 33.2 → 36.2 |
| loop device | 42.4 → 128.0 | 6,075.5 → 5,250.7 | 19.6 → 15.9 |

Raw (after; each load's first line; the before tree's are in the same form):
```
load_probe: new_run   covered 471593 frames, 17713.9 ms; longest frame  106.8 ms; still mark frames 0; after-60 longest    6.8 ms; floor=1 hash=124d6c9ba31c
load_probe: gate      covered 92462 frames,  4745.5 ms; longest frame   63.6 ms; still mark frames 1; after-60 longest    5.8 ms; floor=2 hash=a33b90d81650
load_probe: continue  covered 84415 frames,  4724.6 ms; longest frame  164.4 ms; still mark frames 0; after-60 longest    5.5 ms; floor=2 hash=a33b90d81650
load_probe: deep      covered 84748 frames,  5635.5 ms; longest frame  408.6 ms; still mark frames 1; after-60 longest    6.8 ms; floor=3 hash=c3f5631fba9f
load_probe: ascension covered 58984 frames,  3545.6 ms; longest frame   51.5 ms; still mark frames 0; after-60 longest    5.9 ms; floor=3 hash=2bf9e5547f33
load_probe: restart   covered 105333 frames,  5762.2 ms; longest frame  210.8 ms; still mark frames 0; after-60 longest    6.7 ms; floor=1 hash=124d6c9ba31c
load_probe: loop      covered 77029 frames,  5250.7 ms; longest frame  128.0 ms; still mark frames 0; after-60 longest    6.5 ms; floor=1 hash=c389059dd356
load_probe: new_run   frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 51267:60cw, 75130:83cv, 445198:62cv, 445833:107cv
load_probe: continue  frames over 50 ms (…): 13051:164cw, 34302:74cv
load_probe: deep      frames over 50 ms (…): 18320:59cw, 51044:50cv, 51857:59cv, 59250:126cv, 59390:409cv
load_probe: restart   frames over 50 ms (…): 44720:211cw, 45119:76cw, 45467:143cw, 71210:80cv
load_probe: loop      frames over 50 ms (…): 88:127cw, 61470:128cv
load_probe: done; load average 7.60 8.66 7.83 8/158 18861
```
**A missed target, reported:** N12's rule is that a load never stalls the cover; the longest frames under the cover
grew (up to 409 ms in the Deep load, 211 ms in Restart), while the machine ran other agents' renders and tests (load
average 7.6-8.7: "cw" frames are the World building on its worker, which this step does not touch, so part of it is
the machine). The ones marked "cv" happen while the view builds; the after run predates the warm-up of the enemy and
device models (`ViewWarmup`, added after it: in that run the Loop device read its file in a view job, and each enemy
model was read at its kind's first spawn). **Not re-measured on a quiet machine** (NOT YET RUN): it should be, before the owner's look at it.

**Re-run on the final tree** (`bbf8bad`: the merge with N17/N19's sim changes, the portal and the model warm-up; the
same command, twice, load average 5.6-6.8; floor 1's hash differs from the runs above because N17/N19 changed the
floors):

| load | longest frame run 1 (ms) | longest frame run 2 (ms) | the view's longest job, run 2 (ms) |
|---|---|---|---|
| new run | 100.7 | 112.2 | 29.5 |
| gate | 147.1 | 155.8 | 27.3 |
| continue | 445.1 | 140.3 | 24.1 |
| deep | 131.1 | 615.4 | 50.4 |
| ascension | 55.0 | 47.6 | 46.5 |
| restart | 654.5 | 76.4 | 32.1 |
| loop | 189.0 | 124.7 | 28.5 |

```
load_probe: continue  covered 98452 frames,  5418.5 ms; longest frame  445.1 ms; still mark frames 0; after-60 longest    5.3 ms; floor=2 hash=a33b90d81650
load_probe: continue  frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 67976:445cv
load_probe: restart   covered 92108 frames,  5499.1 ms; longest frame  654.5 ms; still mark frames 0; after-60 longest    6.5 ms; floor=1 hash=163692b46115
load_probe: restart   frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 6805:55cw, 7560:124cw, 27595:61cw, 32678:73cw, 69333:654cv, 69660:57cv, 72765:109cv
load_probe: done; load average 6.78 5.57 5.72 8/155 23569
[run 2]
load_probe: deep      covered 90046 frames,  6858.2 ms; longest frame  615.4 ms
load_probe: deep      phases … view:dress=2404.6 … view_longest_job=50.4
```
**Missed, not explained:** the before tree's longest frames were 38-62 ms; after, single frames of 100-650 ms appear
while the view builds ("cv"), but no view job runs longer than 50 ms, and the same load's worst frame moves between
runs (restart 654 → 76 ms, deep 131 → 615 ms). So the stall is outside the view's jobs (a frame waiting on the
workers: the dressing (`view:dress`, a worker, about 2.4 s now) or a resource lock), on a machine shared with other
agents' renders. Not fixed here; it needs a quiet re-measure and a look at what the main thread waits on (D51's
load rule). Reported to the lead.

## 6. Shots
In [`mi_shots/`](mi_shots/) (JPEG copies by hand of `build/shots/...`): per biome the same designed room (layout
`room_2x2_1`, run seed 20261031, room 2) whole and close, and before/after of the close view (`<biome>_room.jpg`,
`<biome>_close.jpg`, `<biome>_before_after.jpg`; `scripts/shots/room_layouts.gd -- biome=<id> only=room_2x2_1`);
Night Rocks' moss islands past the floor's edge (`night_rocks_moss_islands.jpg`, `scripts/shots/starfall.gd --
biome=night_rocks`), Starfall's cracks, islands and spikes, Frozen Shore's edge; each enemy in six poses
(`enemy_<kind>.jpg`: idle, walking, windup at 70 % (raised and held), strike, hit flash, death half-way;
`scripts/shots/mi_enemies.gd`); the Loop device close, the Ascension portal beside it and close, next to the owner's
reference image (`scripts/shots/ascension.gd`).

## 7. Tests
On this branch (the merged tree with the Ascension portal), headless, `godot --headless --fixed-fps 60 --path . -s
addons/gut/gut_cmdln.gd …`:

| run | result |
|---|---|
| `gdformat --check src scripts tests && gdlint src scripts tests` | 1033 files unchanged; `Success: no problems found` |
| `-gdir=res://tests/content -ginclude_subdirs` | 134 / 134 passing |
| `-gdir=res://tests/arch -ginclude_subdirs` | 4 / 4 passing |
| `-gdir=res://tests/unit/presentation -ginclude_subdirs` | 789 tests: 786 passing, **3 failing** (`test_enemy_palettes` ×2: the palette test read the code bodies' trim, grey and eye slots and their eye slits; `test_bosses_2_views` the Lens Drone's body-material count: all three expected the code-made bodies). Fixed in the tests (an owner's model is checked for its body colour and its own eyes; two body materials); those files re-run below |
| re-run: `-gdir=res://tests/content -gtest=…test_enemy_palettes.gd,…test_bosses_2_views.gd,…test_ascension_views.gd,…test_portal_transit_view.gd,…test_loading_cover.gd,…tests/e2e/test_e2e_final_boss.gd` | 169 / 169 passing |
| e2e: `test_e2e_{run_flow, floor, kit, designed_rooms, frozen_shore, starfall, void, enemies, horde_enemies, new_enemies, ascension, arrival, loading_cover}.gd` (13 files) | 20 / 20 passing (335.5 s) |
| sim, the designed rooms' data: `test_room_layouts.gd`, `test_room_themes.gd`, `test_shop_rooms.gd` | 14 / 14 passing |
| `-gdir=res://tests/golden` | 2 / 2 passing (no golden changed) |

The presentation folder ran while `loop_device.gd` and `view_warmup.gd` gained the model warm-up (the e2e and the
re-runs ran after it). No full suite, no bot tests (owner rule).

## Interpretation
The owner's pieces now dress every biome and the city kit stays in Ruins. Red Canyon draws far fewer triangles (the
kit's 10-13 k-triangle grass and debris gave way to 1 k shrubs); Starfall draws more (its void's islands and spikes
were a few dozen code triangles each; they are now the owner's 3 k / 1 k models), still under Ruins. Frame times on
this shared software renderer say nothing about the owner's GPU (OWNER ONLY). The loads' longest frames grew and are
not explained yet (§5): the one missed rule of this step. The first load of a session reads more
models now (the 28 new kit pieces, the four enemies and the two devices, on the load's worker behind the black cover);
a spawn never reads a model. What the owner should decide is in D58.
