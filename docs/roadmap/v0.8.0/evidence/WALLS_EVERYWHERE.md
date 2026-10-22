# WALLS_EVERYWHERE: every biome's exterior walls are the procedural ruin (v0.8.0 Step N13, D50 = A)

- **Status:** RUN (agent: builder tests, headless load probe, llvmpipe frame probes and shots under xvfb; not the
  owner's hardware). How it looks and feels, fps on the owner's PC: **OWNER ONLY** (D53).
- **Build:** branch `v080-n13` from `3bfda29` (the working tree before the Step N13 commit; only these docs and the
  PLAN/PROGRESS/OWNER_TODO rows were written after the runs; the commit's SHA is in PROGRESS's Done row). "Before"
  for the load probe: an untouched `git archive 3bfda29` copy (N10's "auto": Ruins A, the other biomes the kit) with
  its own import cache. "Before" for the frame probes and shots: today's tree with the dev toggle on `old` (the kit
  pieces as before N10). Godot `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 (cloud container, 4 cores, no GPU),
  shared with other agents' Godot runs (load average 5-7 during the probes, printed per run).
- **Date:** 2026-10-17
- **Who ran it:** agent

Owner (O71, verbatim in [`../PLAN.md`](../PLAN.md)): "Walls should be 100% new with the textures and the 21M less
triangles, that gives a lot more room for fps to not drop during heavy animations, I'll test the floors later tho and
give you feedback". So D50 = A everywhere.

## What changed
1. **Option A is every biome's walls.** `ViewPrefs.wall_style` is `a` (the default), `old` or `b`; "auto" is gone
   (an unknown value draws A). `StageView.resolved_wall_style`: `old` → the kit, `b` → option B, anything else → A.
   F10 → Tools → **Walls** cycles a → old → b → a (then Restart floor). Each biome draws its own `tex_wall_<biome>` /
   `tex_wall_top_<biome>` at its own tile size, now written in each biome's data (`BiomeMood.wall_texture_m` /
   `wall_top_texture_m`: Ruins, Night Rocks, Frozen Shore, Starfall 4.0 / 4.5 m; Red Canyon 5.0 / 5.0 m, its strata
   wider; the look is unchanged, the four were the defaults).
2. **100 % new: no kit piece on a structural wall** (`StageDresser._dress_wall_proc` keeps only the light props, in
   their niches). N10's decimated grey kit pillars (53-115 a floor, 2,835 triangles each) became the builder's own
   pillars, `WallPillars` (`src/presentation/world_view/wall_pillars.gd`): on a wall 9 m or longer and 1.4 m or
   thinner, one every 8-12 m (from 4-6 m in, never within 2 m of its ends), kept 1.4 m from a light's niche, only
   where a face is open ground 0.8 m either side (no join; a wall backed by another keeps its pillar on its open
   face): a pier 0.62-0.78 m wide through the wall's depth, flush with its faces (inside the footprint: looks solid =
   is solid), 1.3-1.55 m tall and at least 0.2 m over the wall's top there, laid in courses (plinth and cap 6 cm
   wider along the wall, the shaft's courses alternately 7 cm narrower, a worn cap), in the wall's own textures and
   surface (one mesh per wall still). The faces' courses, pilasters and rebar stop at it. Light props keep their
   niches; crystals keep their wall spots (they read the footprints); interior cover and designed-room blockers are
   dressed as before (the same cover walls, test below).
3. **Thick walls' tops** (N10's note: "read from above as a field of laid stones, a ruined platform more than a
   wall"): only the rim is laid stones, the cells within 0.75 m of the union's edge (`WallGrid.edge_dist`, the
   distance along the grid's rows and columns); deeper in, the top is a rubble fill: 1.2 m lumps (the rim's stones
   are 0.45-1.05 × 0.6 m) sunk 0.36-0.6 m below the top there (some 0.15 m more), never under 0.25 m, darker
   (vertex colour 0.66 vs 0.97). From above a thick wall reads as two ruined skins with broken fill between (shots
   below). Walls up to ~1.4 m have no cell that deep and are all rim, as before. Not done: an inward slope of the
   rim's tops (the step faces between stones assume flat tops; a slope would open slits at the joins).
   Triangles per metre stay at N10's (below).
4. **Edges:** everything the builder draws stays inside the walls' footprints (only low fallen chunks lie on a
   room's floor; tested), so the outer walls' faces stand flush on Frozen Shore's snow bank (its lip 0.14 m wider than
   the ground) and on Starfall's floating rock (its lip 0.12 m): nothing of the walls overhangs the sea or the
   void. Red Canyon keeps its wider 5 m tiles (its strata). Shots below; the
   agent's read, the owner judges.

`load_probe.gd` prints a `stage:` line per load (the biome, its wall style, structural wall meshes / triangles) and
takes `walls=`. `scripts/shots/n13_sheet.py` joins the pairs (writes under `build/`; copied into `n13_shots/` by
hand).

## Numbers
### The builder (generated floors, `test_procedural_wall.gd`'s `gut.p` lines)
| seed | triangles | face (m) | per metre (N10) | pillars | top rim m² at mean h | fill m² at mean h |
|---|---|---|---|---|---|---|
| 77 | 132,924 | 1,966 | 67.6 (69.6) | 264 on the three seeds | 1,402 at 0.82 m | 1,527 at 0.42 m |
| 501 | 136,804 | 2,208 | 62.0 (62.0) | | 1,470 at 0.84 m | 1,146 at 0.44 m |
| 1234 | 142,766 | 2,168 | 65.8 (66.3) | | 1,419 at 0.84 m | 1,129 at 0.44 m |

Kit wall pieces on structural walls, kit → A, seed 77, every biome: 1,402 → 0 (N10: → 53 pillar accents).

### The game's view (`biome_probe.gd walls=`, the floor `SaveLab.floor_world(seed, 1)`, start room + 2 rooms, 6 frames each at 640 × 360, llvmpipe)
`wall_tris` counts the structural walls' meshes at full detail; `prims` and `draws` are RenderingServer's, the whole
frame (shadow passes included). frame_ms is wall time on a shared 4-core machine at load 5-7: compare within a row.
N10's Ruins A (with its kit pillar accents), for reference: seed 20261008 288 meshes / 568,346 triangles; seed 7 242 /
453,182 (PROCEDURAL_WALLS.md; not re-run).

| biome, seed | wall meshes kit → A | wall triangles kit → A | frame_ms avg / p95 kit → A | draws avg kit → A | prims avg kit → A |
|---|---|---|---|---|---|
| Ruins 20261008 | 1,827 → 148 | 21,528,542 → 170,396 | 2,347 / 3,395 → 1,531 / 2,146 | 519 → 531 | 6,364,856 → 5,111,412 |
| Night Rocks 20261008 | 1,827 → 148 | 21,528,542 → 170,396 | 2,281 / 3,032 → 1,454 / 1,973 | 519 → 526 | 6,152,998 → 4,806,879 |
| Red Canyon 20261008 | 1,827 → 148 | 21,528,542 → 170,396 | 2,453 / 3,517 → 1,366 / 1,835 | 561 → 577 | 7,100,115 → 5,397,114 |
| Frozen Shore 20261008 | 1,827 → 148 | 21,528,542 → 170,396 | 1,719 / 2,275 → 813 / 1,011 | 596 → 589 | 2,229,626 → 724,756 |
| Starfall 20261008 | 1,827 → 148 | 21,528,542 → 170,396 | 1,708 / 2,456 → 787 / 1,008 | 584 → 599 | 2,155,878 → 718,683 |
| Ruins 7 | 1,814 → 144 | 21,420,831 → 170,056 | 2,283 / 3,160 → 1,436 / 1,763 | 633 → 628 | 6,726,328 → 5,571,324 |
| Night Rocks 7 | 1,814 → 144 | 21,420,831 → 170,056 | 2,336 / 3,074 → 1,374 / 2,104 | 641 → 639 | 6,815,936 → 5,744,567 |
| Red Canyon 7 | 1,814 → 144 | 21,420,831 → 170,056 | 2,600 / 4,054 → 1,681 / 2,224 | 647 → 638 | 6,898,107 → 5,655,976 |
| Frozen Shore 7 | 1,814 → 144 | 21,420,831 → 170,056 | 1,850 / 2,767 → 979 / 1,316 | 677 → 649 | 2,386,955 → 802,458 |
| Starfall 7 | 1,814 → 144 | 21,420,831 → 170,056 | 1,837 / 3,018 → 847 / 1,524 | 658 → 653 | 2,291,814 → 733,799 |

Read: the walls' triangles fall ~126× (21.4-21.5 M → 0.17 M a floor; vs N10's A another 2.7-3.3× fewer, the kit
pillars gone), the meshes ~12×; the frame's primitives 17-24 % fewer in Ruins, Night Rocks and Red Canyon and ~66-68 %
fewer in Frozen Shore and Starfall; frames on the software renderer 1.4-2.2× faster. **Draw calls did not fall**
(within ±3 %, as N10 found: one mesh per wall is drawn whole whenever any of it shows, each shadow pass again).
`proc_build_ms` (the builder, on a worker in the game since N12): 1.21-1.37 s here; in the shot runs 1.37-1.84 s.

### Loads (`load_probe.gd`, headless; before `3bfda29` at load 2.6, after at load 5-8)
| Load | biome (after) | longest frame before → after (ms) | covered before → after (ms) | after: wall meshes / triangles |
|---|---|---|---|---|
| New run | Night Rocks | 57.1 → **63.5** | 10,891 → 12,839 | 135 / 152,006 |
| Gate | Red Canyon | 44.8 → 48.4 | 2,473 → 4,551 | 138 / 161,470 |
| Continue | Red Canyon | 44.4 → 43.2 | 2,283 → 3,767 | 138 / 161,470 |
| Deep gate | Ruins (A before too) | 35.3 → 35.1 | 4,421 → 4,401 | 131 / 150,500 |
| Ascension | final arena (no walls) | 35.4 → 48.7 | 3,172 → 3,134 | — |
| Restart | Night Rocks | 35.9 → 42.5 | 2,796 → 4,472 | 135 / 152,006 |
| Loop | Night Rocks | 35.9 → 44.8 | 2,177 → 3,690 | 136 / 159,500 |

The walls build on N12's worker (`view:dress` 1,445-1,600 ms on every walled load after; 22-35 ms before, except the
Deep gate's Ruins, 1,453 ms) and go in 8 walls a job (`view:kit_proc_walls` 39-42 ms in total); the longest
main-thread view step 24-48 ms (before 24-45). So every load but the Deep gate and the arena now spends ~1.5 s more
behind the cover, and the screen keeps moving through it. **Target (no frame over ~50 ms headless): missed on the
new run, one frame of 63.5 ms** (before 57.1 ms: missed before N13 too; N12 measured 60.5 ms), the rest 35-49 ms. The
after run had a load average of 5-8 against 2.6 before (other agents' Godot runs): the longer frames and covered
times are not all N13's; not re-run on a quiet machine. Hashes of all seven loads equal the before tree's.

## Shots (`n13_shots/`, the game's camera, view size 17, 1280 × 720 scaled to 640 wide; left kit, right A)
`<biome>_small.jpg` (the smallest room), `<biome>_big.jpg` (the biggest), `<biome>_corner.jpg` (a corner of the
biggest room), for `ruins`, `night_rocks`, `red_canyon`, `frozen_shore`, `starfall`. The agent's read (the owner
judges): the stacked, overlapping kit blocks are gone in every biome; the thick partitions now show a rim along each
face with a darker sunken fill (clearest in `ruins_small`, `frozen_shore_small`, `starfall_small`); Frozen Shore's
outer walls stand flush on the snow bank and Starfall's on the rock lip, nothing over the water or the void. Still
off: the night biomes' (Night Rocks, Starfall) wall textures read busy at this camera; the big rooms' shots are
mostly interior cover (kit pieces, unchanged on purpose); the pillars are small at the game's camera (1.3-1.55 m
against a 0.55-1.4 m top).

## Tests
`tests/unit/presentation/test_procedural_wall.gd` (15, was 13): changed `the_dresser_puts_far_fewer_kit_pieces…` →
`test_no_kit_pieces_on_the_exterior_walls_in_any_biome` (five biomes × three seeds, each with its BiomeLook's cover
and decoration swaps: 0 kit pieces on structural walls, every light has its niche, the same cover walls dressed as
with the kit); new `test_the_pillars_are_the_builders_own` (inside their footprint, lips included, clear of the
niches, standing over the wall's top under them, more than 9 on three floors) and
`test_a_thick_walls_top_is_a_rim_round_a_sunken_fill` (fill below the rim by > 0.15 m on three floors; a 1.2 m wall
all rim); `test_one_top_over_every_point_inside_corners_included` skips points within 0.1 m of a pillar (its
courses stack); the toggle tests: A by default in all five biomes, each biome's face tile 3-6 m, `old` → kit, `b` →
B, "auto" → A; the Walls button cycles a → old → b → a. No other test changed; no count changed elsewhere
(`test_stage_dresser.gd` and the shard tests use the dresser's own default, the kit).

## Commands
```
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_procedural_wall.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/unit/debug -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_floor.gd,res://tests/e2e/test_e2e_kit.gd,res://tests/e2e/test_e2e_designed_rooms.gd,res://tests/e2e/test_e2e_frozen_shore.gd,res://tests/e2e/test_e2e_starfall.gd,res://tests/e2e/test_e2e_void.gd,res://tests/e2e/test_e2e_loading_cover.gd,res://tests/e2e/test_e2e_arrival.gd,res://tests/e2e/test_e2e_dev_master_panel.gd -gexit
godot --headless --fixed-fps 60 --path . -s scripts/checks/load_probe.gd          # before: in the 3bfda29 copy
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --audio-driver Dummy --resolution 640x360 -s scripts/checks/biome_probe.gd -- biome=<b> seed=<20261008|7> \
  frames=6 settle=6 spots=3 cpu=1 walls=<old|a> tag=n13_<walls>_<b>_<seed>
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --audio-driver Dummy --resolution 1280x720 -s scripts/shots/walls_n10.gd -- walls=<old|a> biome=<b> \
  spots=small,big,corner tag=n13_<walls>
python3 scripts/shots/n13_sheet.py && cp build/shots/n13_sheet/*.jpg docs/roadmap/v0.8.0/evidence/n13_shots/
```

## Raw output
`test_procedural_wall.gd` (inside the `tests/unit/presentation` run):
```
    seed 77: 132924 triangles, 1966 m of face, 67.6 per metre
    seed 501: 136804 triangles, 2208 m of face, 62.0 per metre
    seed 1234: 142766 triangles, 2168 m of face, 65.8 per metre
    ruins seed 77: kit wall pieces 1402 -> 0
    night_rocks seed 77: kit wall pieces 1402 -> 0
    red_canyon seed 77: kit wall pieces 1402 -> 0
    frozen_shore seed 77: kit wall pieces 1402 -> 0
    starfall seed 77: kit wall pieces 1402 -> 0
    pillars: 264 on seeds [77, 501, 1234]
    seed 77: top rim 1402 m2 at 0.82 m, fill 1527 m2 at 0.42 m
    seed 501: top rim 1470 m2 at 0.84 m, fill 1146 m2 at 0.44 m
    seed 1234: top rim 1419 m2 at 0.84 m, fill 1129 m2 at 0.44 m
    ruins: face tile 4.0 m, top tile 4.5 m
    night_rocks: face tile 4.0 m, top tile 4.5 m
    red_canyon: face tile 5.0 m, top tile 5.0 m
    frozen_shore: face tile 4.0 m, top tile 4.5 m
    starfall: face tile 4.0 m, top tile 4.5 m
```
`load_probe.gd`, before (`3bfda29` copy):
```
load_probe: idle      menu 448360 frames, 5000 ms; longest frame    5.2 ms; frames over 50 ms 0
load_probe: new_run   covered 359707 frames, 10891.0 ms; longest frame   57.1 ms; still mark frames 0; after-60 longest   13.0 ms; floor=1 hash=be343c47a7e0
load_probe: new_run   frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 78569:57cv
load_probe: gate      covered 46131 frames,  2472.8 ms; longest frame   44.8 ms; still mark frames 1; after-60 longest    7.8 ms; floor=2 hash=48b12e5e40a9
load_probe: continue  covered 60313 frames,  2283.3 ms; longest frame   44.4 ms; still mark frames 0; after-60 longest   14.7 ms; floor=2 hash=48b12e5e40a9
load_probe: deep      covered 101505 frames,  4421.3 ms; longest frame   35.3 ms; still mark frames 1; after-60 longest    6.8 ms; floor=3 hash=92161518eb63
load_probe: ascension covered 72064 frames,  3171.7 ms; longest frame   35.4 ms; still mark frames 0; after-60 longest    5.3 ms; floor=3 hash=2bf9e5547f33
load_probe: restart   covered 73781 frames,  2796.1 ms; longest frame   35.9 ms; still mark frames 0; after-60 longest    4.3 ms; floor=1 hash=be343c47a7e0
load_probe: loop      covered 39948 frames,  2177.1 ms; longest frame   35.9 ms; still mark frames 0; after-60 longest    5.5 ms; floor=1 hash=5fc49b6032ed
load_probe: done; load average 2.63 1.81 1.55 3/131 8565
```
(phases, the parts that matter: new_run view:dress=21.7; gate 34.7; continue 26.2; deep 1452.8 with
view:kit_proc_walls=50.9; restart 26.4; loop 27.4; view_longest_step 24.2-44.6.)

`load_probe.gd`, after (`v080-n13` working tree):
```
load_probe: idle      menu 459345 frames, 5000 ms; longest frame    2.3 ms; frames over 50 ms 0
load_probe: new_run   covered 420747 frames, 12838.6 ms; longest frame   63.5 ms; still mark frames 0; after-60 longest    3.9 ms; floor=1 hash=be343c47a7e0
load_probe: new_run   stage: biome=night_rocks walls=proc wall_meshes=135 wall_tris=152006
load_probe: new_run   frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 82193:63cv
load_probe: gate      covered 84477 frames,  4551.4 ms; longest frame   48.4 ms; still mark frames 1; after-60 longest    5.9 ms; floor=2 hash=48b12e5e40a9
load_probe: gate      stage: biome=red_canyon walls=proc wall_meshes=138 wall_tris=161470
load_probe: continue  covered 97117 frames,  3767.4 ms; longest frame   43.2 ms; still mark frames 0; after-60 longest    5.1 ms; floor=2 hash=48b12e5e40a9
load_probe: continue  stage: biome=red_canyon walls=proc wall_meshes=138 wall_tris=161470
load_probe: deep      covered 103298 frames,  4400.9 ms; longest frame   35.1 ms; still mark frames 1; after-60 longest    6.5 ms; floor=3 hash=92161518eb63
load_probe: deep      stage: biome=ruins walls=proc wall_meshes=131 wall_tris=150500
load_probe: ascension covered 75475 frames,  3133.8 ms; longest frame   48.7 ms; still mark frames 0; after-60 longest    5.9 ms; floor=3 hash=2bf9e5547f33
load_probe: ascension stage: biome=hollow_arena walls= wall_meshes=0 wall_tris=0
load_probe: restart   covered 113699 frames,  4472.3 ms; longest frame   42.5 ms; still mark frames 0; after-60 longest    3.9 ms; floor=1 hash=be343c47a7e0
load_probe: restart   stage: biome=night_rocks walls=proc wall_meshes=135 wall_tris=152006
load_probe: loop      covered 77682 frames,  3690.3 ms; longest frame   44.8 ms; still mark frames 0; after-60 longest    6.6 ms; floor=1 hash=5fc49b6032ed
load_probe: loop      stage: biome=night_rocks walls=proc wall_meshes=136 wall_tris=159500
load_probe: done; load average 4.97 7.31 7.82 3/155 19320
```
(phases: view:dress new_run 1528.8, gate 1569.6, continue 1600.1, deep 1445.2, restart 1485.2, loop 1499.9;
view:kit_proc_walls 39.1-41.6; view_longest_step 23.9-48.3.)

`biome_probe.gd` (per run: the walls line and the metrics; `load:` is /proc/loadavg after the run):
```
=== biome=ruins seed=20261008 walls=old
walls: style=kit (pref old) wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0 build_ms=12050.6
frame_ms       2347.165  3394.806  3394.806
cpu_ms         4122.222  5690.000  5690.000
draws           518.778   777.000   777.000
objects         876.278  1255.000  1255.000
prims          6364855.778  9876352.000  9876352.000
load: 5.85 6.74 7.53 5/146 19600
=== biome=ruins seed=20261008 walls=a
walls: style=proc (pref a) wall_meshes=148 wall_tris=170396 proc_build_ms=1248.7 build_ms=12674.2
frame_ms       1530.797  2145.856  2145.856
cpu_ms         2621.667  3780.000  3780.000
draws           531.167   706.000   706.000
objects         578.889   742.000   742.000
prims          5111411.778  7235757.000  7235757.000
load: 5.36 6.34 7.30 4/146 19760
=== biome=night_rocks seed=20261008 walls=old
walls: style=kit (pref old) wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0 build_ms=11622.4
frame_ms       2280.510  3031.848  3031.848
cpu_ms         3995.556  5360.000  5360.000
draws           519.389   781.000   781.000
objects         876.556  1258.000  1258.000
prims          6152998.278  9161891.000  9161891.000
load: 5.56 6.10 7.09 6/141 19947
=== biome=night_rocks seed=20261008 walls=a
walls: style=proc (pref a) wall_meshes=148 wall_tris=170396 proc_build_ms=1249.9 build_ms=12858.3
frame_ms       1453.574  1972.851  1972.851
cpu_ms         2472.778  3460.000  3460.000
draws           525.778   655.000   655.000
objects         573.833   692.000   692.000
prims          4806879.111  5841706.000  5841706.000
load: 5.27 5.84 6.90 6/142 20097
=== biome=red_canyon seed=20261008 walls=old
walls: style=kit (pref old) wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0 build_ms=11587.5
frame_ms       2452.921  3517.181  3517.181
cpu_ms         4465.000  6010.000  6010.000
draws           561.111   834.000   834.000
objects        1039.278  1507.000  1507.000
prims          7100115.111  11195144.000  11195144.000
load: 6.02 5.81 6.74 3/135 20300
=== biome=red_canyon seed=20261008 walls=a
walls: style=proc (pref a) wall_meshes=148 wall_tris=170396 proc_build_ms=1265.3 build_ms=13571.6
frame_ms       1366.090  1835.079  1835.079
cpu_ms         2708.333  3920.000  3920.000
draws           576.500   773.000   773.000
objects         632.222   827.000   827.000
prims          5397114.111  7964820.000  7964820.000
load: 5.14 5.54 6.57 4/135 21064
=== biome=frozen_shore seed=20261008 walls=old
walls: style=kit (pref old) wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0 build_ms=11580.1
frame_ms       1719.147  2274.764  2274.764
cpu_ms         3077.222  4120.000  4120.000
draws           596.000   821.000   821.000
objects         962.111  1332.000  1332.000
prims          2229625.944  3440405.000  3440405.000
load: 5.03 5.31 6.37 3/138 22208
=== biome=frozen_shore seed=20261008 walls=a
walls: style=proc (pref a) wall_meshes=148 wall_tris=170396 proc_build_ms=1341.6 build_ms=13210.8
frame_ms        813.339  1010.667  1010.667
cpu_ms         1458.889  1880.000  1880.000
draws           588.556   705.000   705.000
objects         637.167   743.000   743.000
prims          724755.833  874250.000  874250.000
load: 5.58 5.39 6.32 5/148 22387
=== biome=starfall seed=20261008 walls=old
walls: style=kit (pref old) wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0 build_ms=11913.8
frame_ms       1708.488  2456.125  2456.125
cpu_ms         2957.778  3840.000  3840.000
draws           583.722   807.000   807.000
objects         939.333  1292.000  1292.000
prims          2155877.722  3338392.000  3338392.000
load: 5.99 5.50 6.26 3/145 22631
=== biome=starfall seed=20261008 walls=a
walls: style=proc (pref a) wall_meshes=148 wall_tris=170396 proc_build_ms=1373.3 build_ms=13628.0
frame_ms        787.333  1007.552  1007.552
cpu_ms         1415.000  1850.000  1850.000
draws           599.389   726.000   726.000
objects         647.333   765.000   765.000
prims          718682.833  827266.000  827266.000
load: 5.26 5.37 6.16 3/144 22741
=== biome=ruins seed=7 walls=old
walls: style=kit (pref old) wall_meshes=1814 wall_tris=21420831 proc_build_ms=0.0 build_ms=11765.6
frame_ms       2282.969  3160.079  3160.079
cpu_ms         3927.222  5300.000  5300.000
draws           632.500   775.000   775.000
objects         986.889  1108.000  1108.000
prims          6726328.056  9242913.000  9242913.000
load: 6.18 5.56 6.12 4/141 22906
=== biome=ruins seed=7 walls=a
walls: style=proc (pref a) wall_meshes=144 wall_tris=170056 proc_build_ms=1300.6 build_ms=12856.3
frame_ms       1435.738  1763.072  1763.072
cpu_ms         2393.333  2990.000  2990.000
draws           627.611   730.000   730.000
objects         664.833   753.000   753.000
prims          5571323.667  7502733.000  7502733.000
load: 5.84 5.53 6.05 5/140 23040
=== biome=night_rocks seed=7 walls=old
walls: style=kit (pref old) wall_meshes=1814 wall_tris=21420831 proc_build_ms=0.0 build_ms=12196.5
frame_ms       2335.955  3073.621  3073.621
cpu_ms         4013.333  5200.000  5200.000
draws           641.167   777.000   777.000
objects         998.389  1109.000  1109.000
prims          6815936.056  9052086.000  9052086.000
load: 5.16 5.34 5.91 6/146 23227
=== biome=night_rocks seed=7 walls=a
walls: style=proc (pref a) wall_meshes=144 wall_tris=170056 proc_build_ms=1221.6 build_ms=12777.0
frame_ms       1374.347  2104.380  2104.380
cpu_ms         2402.222  3060.000  3060.000
draws           638.833   697.000   697.000
objects         676.111   720.000   720.000
prims          5744567.222  7269157.000  7269157.000
load: 5.19 5.23 5.82 3/131 23990
=== biome=red_canyon seed=7 walls=old
walls: style=kit (pref old) wall_meshes=1814 wall_tris=21420831 proc_build_ms=0.0 build_ms=11672.0
frame_ms       2599.961  4054.015  4054.015
cpu_ms         4032.778  5240.000  5240.000
draws           646.500   776.000   776.000
objects        1026.556  1097.000  1097.000
prims          6898107.056  9201432.000  9201432.000
load: 5.65 5.32 5.77 6/143 24242
=== biome=red_canyon seed=7 walls=a
walls: style=proc (pref a) wall_meshes=144 wall_tris=170056 proc_build_ms=1274.9 build_ms=13738.4
frame_ms       1681.114  2224.289  2224.289
cpu_ms         2406.667  2960.000  2960.000
draws           637.611   695.000   695.000
objects         673.556   714.000   714.000
prims          5655975.889  6954575.000  6954575.000
load: 6.03 5.53 5.79 5/142 24387
=== biome=frozen_shore seed=7 walls=old
walls: style=kit (pref old) wall_meshes=1814 wall_tris=21420831 proc_build_ms=0.0 build_ms=11936.9
frame_ms       1849.825  2767.206  2767.206
cpu_ms         2958.889  3680.000  3680.000
draws           676.667   702.000   702.000
objects        1045.278  1125.000  1125.000
prims          2386954.667  2926407.000  2926407.000
load: 6.21 5.67 5.81 4/139 24499
=== biome=frozen_shore seed=7 walls=a
walls: style=proc (pref a) wall_meshes=144 wall_tris=170056 proc_build_ms=1213.4 build_ms=12999.2
frame_ms        979.202  1315.776  1315.776
cpu_ms         1403.333  1670.000  1670.000
draws           648.556   727.000   727.000
objects         686.611   752.000   752.000
prims          802457.778  964491.000  964491.000
load: 5.90 5.66 5.80 4/135 24586
=== biome=starfall seed=7 walls=old
walls: style=kit (pref old) wall_meshes=1814 wall_tris=21420831 proc_build_ms=0.0 build_ms=12569.4
frame_ms       1836.895  3017.974  3017.974
cpu_ms         3091.111  4040.000  4040.000
draws           658.000   712.000   712.000
objects        1011.833  1108.000  1108.000
prims          2291813.611  2857517.000  2857517.000
load: 6.70 5.85 5.84 5/140 24749
=== biome=starfall seed=7 walls=a
walls: style=proc (pref a) wall_meshes=144 wall_tris=170056 proc_build_ms=1253.0 build_ms=13405.1
frame_ms        847.242  1524.123  1524.123
cpu_ms         1327.222  1610.000  1610.000
draws           653.056   698.000   698.000
objects         686.333   721.000   721.000
prims          733799.167  849253.000  849253.000
load: 6.19 5.82 5.83 3/129 25267
```
`walls_n10.gd` (the shot runs' stats lines):
```
walls_n10: biome=ruins walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=ruins walls=a style=proc wall_meshes=148 wall_tris=170396 proc_build_ms=1373.4
walls_n10: biome=night_rocks walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=night_rocks walls=a style=proc wall_meshes=148 wall_tris=170396 proc_build_ms=1529.9
walls_n10: biome=red_canyon walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=red_canyon walls=a style=proc wall_meshes=148 wall_tris=170396 proc_build_ms=1541.8
walls_n10: biome=frozen_shore walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=frozen_shore walls=a style=proc wall_meshes=148 wall_tris=170396 proc_build_ms=1638.4
walls_n10: biome=starfall walls=old style=kit wall_meshes=1827 wall_tris=21528542 proc_build_ms=0.0
walls_n10: biome=starfall walls=a style=proc wall_meshes=148 wall_tris=170396 proc_build_ms=1841.9
```
Suites: `tests/unit/presentation` 775/775 passing (827.9 s); `tests/content` + `tests/arch` + `tests/unit/debug`
152/152; the 10 e2e files (run_flow, floor, kit, designed_rooms, frozen_shore, starfall, void, loading_cover, arrival,
dev_master_panel) 16/16; lint: gdformat --check "1024 files would be left unchanged", gdlint "Success: no problems
found". Not run locally: the full suite, the seams, the bot sims (the owner's rule).
