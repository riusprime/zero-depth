# ROOMS: designed rooms, part 1 (the system and the first three layouts, for the owner's G2)

- **Status:** RUN (tests and shots); the G2 pick is **OWNER ONLY**
- **Build:** the working tree of the commit `v0.8.0 Step RT1` on `v080-rt` (parent `96cbbbd`); the code and data
  that ran are the ones committed (everything ran before the commit, so the commit cannot name its own SHA);
  Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`; shots on llvmpipe (Mesa's software Vulkan,
  LLVM 20.1.2) under `xvfb-run`, Forward+
- **Date:** 2026-10-14
- **Who ran it:** agent

## The owner's line (O12)
> "design maybe two, three rooms of each size and have them like nicely looking like the image we use for reference,
> like a little bit more populated and feel more real … we use procedural generation to place them as templates, but
> every floor and every loop in every game is different because of how they are placed. So we could like make a room
> that could be in different directions, that size has three variations and we place them randomly"

## What was built
- **Data.** `RoomLayoutDefinition` (category `room_layout`) in `src/content/defs/` with `RoomLayoutGroup` and
  `RoomLayoutPiece`; files `data/room_layouts/2x2_1.tres`, `3x2_1.tres`, `3x3_1.tres`, found by `ContentScanner`,
  validated (CONTENT_SCHEMA §5 "Designed rooms"). A layout is drawn in its own frame (x along the room's long side);
  each group sits at a fraction of the room and keeps its shape in metres; each piece is a sim blocker (`solid`) or
  drawn only (decoration anywhere, anything taller inside one of its group's blockers). The `.tres` files are written
  by `scripts/content/room_layouts.py` from prefab clusters (corner clusters, wall clusters, free-standing clusters).
- **Sim.** `RoomLayouts` (key, turns, draw, transform) and `RoomLayoutTable` in `src/sim/map/`; `FloorGenerator` draws
  a layout, a turn and a mirror per room from the `map` stream (start hall and portal room excluded; sizes without a
  layout keep `RoomInterior` + `RoomThemes`), settles the turn and mirror on the way round with the fewest blockers in
  doorway boxes (no draw), and furnishes the room group by group with the vignettes' checks plus the doorway boxes
  (SIM_CONTRACTS "Designed rooms"). `FloorLayout` gains `room_layout`, `room_turn`, `room_mirror`, `layout_props`,
  `piece_heights` (presentation and tools only; nothing hashed or saved). `RunState.FLOOR_RULES` 3 → 4;
  `RunState.designed_rooms()`; `RunSaver.floor_tables` adds the layouts only for rules ≥ 4.
- **Presentation.** `WorldReader.wall_layout_height`, `layout_prop_count`, `layout_prop`, `floor_room_layout`;
  `StageView` passes them to `StageDresser`, which draws a designed room's blockers at the layout's heights after the
  biome's swap (square cover → `BiomeLook.square_cover`, Night Rocks rocks and dead trees) and its drawn pieces
  (decoration through `decor_swap`, kept out of doorways and off rewards and the portal; a piece whose blocker the boss
  door removed is not drawn).
- **Shots.** `scripts/shots/room_layouts.gd` (below).

## The three layouts (numbers from `scripts/content/room_layouts.py` and the tests; starting values)
| Layout | Groups | Blockers | Drawn pieces | Blocking, typical room | Dressed (decoration as 1 m² a piece) | Open lane |
|---|---|---|---|---|---|---|
| `room_2x2_1` "crossroads": four different corners (blocks, wreck + fire, broken walls, crate dump), four clusters round an open centre | 8 | 43 | 58 | 16.1 % of 27.8 × 22.8 m | 29.0 % | centre 26 × 28 % |
| `room_3x2_1` "the yard": wreck and fire at one end, ruins at the other, wall clusters, two rows of free clusters | 14 | 75 | 102 | 16.5 % of 43.1 × 22.8 m | 30.9 % | centre 16 × 40 % |
| `room_3x3_1` "the ruined square": four corners, four mid-wall clusters, an inner ring (a building's remains, a block and wreck pair, camps) | 17 | 95 | 151 | 14.7 % of 43.1 × 35.6 m | 27.2 % | centre 22 × 22 % |

"Typical room": the middle of the drawn cell sizes and wall halves. The dresser's own grass along the walls, the
rubble on open floor and the grass round every blocker come on top. On real floors the doorways drop some groups:
over 40 run floors 78 % of the layouts' blockers stand (test below); over the 60 floor-1 rooms searched by the shot
script, 73 % (2×2), 74 % (3×2) and 89 % (3×3) on average.

## Commands and raw output

### Layout numbers
```
$ python3 -I scripts/content/room_layouts.py .
```
(writes the three `.tres` files and `build/room_layouts/*_mid.png`; output saved to `build/rt_logs/room_layouts_py.txt`)
```
== 2x2_1 groups 8 slits []
  mid  27.8 x  22.8 kept  8/8 block 16.1% dressed 29.0%  []
  ext  22.6 x  18.6 kept  5/8 block 15.7% dressed 29.3%  
  ext  22.6 x  27.0 kept  8/8 block 16.7% dressed 30.2%  
  ext  33.0 x  18.6 kept  6/8 block 12.0% dressed 22.3%  
  ext  33.0 x  27.0 kept  8/8 block 11.5% dressed 20.7%  
  mid  22.8 x  27.8 kept  8/8 block 16.1% dressed 29.0%  []
  ext  18.6 x  22.6 kept  6/8 block 21.2% dressed 37.4%  
  ext  18.6 x  33.0 kept  7/8 block 15.7% dressed 27.8%  
  ext  27.0 x  22.6 kept  8/8 block 16.7% dressed 30.2%  
  ext  27.0 x  33.0 kept  8/8 block 11.5% dressed 20.7%  
== 3x2_1 groups 14 slits []
  mid  43.1 x  22.8 kept 14/14 block 16.5% dressed 30.9%  []
  ext  36.4 x  18.6 kept  8/14 block 16.0% dressed 29.9%  [(8, 'gap to group 4 1.48'), (9, 'gap to group 5 1.92'), (9, 'gap to group 7 1.39'), (10, 'gap to group 2 1.64')]
  ext  36.4 x  27.0 kept 14/14 block 16.5% dressed 30.9%  
  ext  49.8 x  18.6 kept  9/14 block 12.5% dressed 23.3%  
  ext  49.8 x  27.0 kept 14/14 block 12.0% dressed 22.6%  
  mid  35.6 x  27.8 kept 14/14 block 16.4% dressed 30.7%  []
  ext  30.4 x  22.6 kept 10/14 block 18.1% dressed 33.0%  
  ext  30.4 x  33.0 kept 12/14 block 14.4% dressed 26.3%  
  ext  40.8 x  22.6 kept 13/14 block 16.2% dressed 30.3%  
  ext  40.8 x  33.0 kept 14/14 block 12.0% dressed 22.6%  
== 3x3_1 groups 17 slits []
  mid  43.1 x  35.6 kept 17/17 block 14.7% dressed 27.2%  []
  ext  36.4 x  30.4 kept 12/17 block 12.9% dressed 24.1%  
  ext  36.4 x  40.8 kept 16/17 block 14.7% dressed 26.7%  
  ext  49.8 x  30.4 kept 15/17 block 14.2% dressed 25.8%  
  ext  49.8 x  40.8 kept 17/17 block 11.1% dressed 20.5%  
  mid  35.6 x  43.1 kept 17/17 block 14.7% dressed 27.2%  []
  ext  30.4 x  36.4 kept 12/17 block 12.3% dressed 23.1%  
  ext  30.4 x  49.8 kept 14/17 block 13.4% dressed 24.2%  
  ext  40.8 x  36.4 kept 17/17 block 15.2% dressed 28.1%  
  ext  40.8 x  49.8 kept 17/17 block 11.1% dressed 20.5%
```
"mid" rows: a typical room in the layout's two orientations; "ext" rows: the corners of the size range a floor can
draw (smallest and largest cell sizes and wall halves), where the generator's spacing rules drop groups that no
longer fit.

### Tests
Lint:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
810 files would be left unchanged
Success: no problems found
```
`tests/content` (validation of the layouts, `test_room_layout_validation.gd`, and every other content test):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Totals
------
Scripts              27
Tests               136
Passing Tests       136
Asserts            8817
Time              21.824s
---- All tests passed! ----
```
`tests/arch` + `tests/golden` (unchanged goldens):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
Totals
------
Scripts               3
Tests                 6
Passing Tests         6
Asserts            8986
Time              9.142s
---- All tests passed! ----
```
The map and generator sim tests by name (the new `test_room_layouts.gd`: turns and mirrors, every group of every
layout in a typical room in every turn and mirror, the property test over 40 run floors with the layouts, the same
seed the same floor, no layouts no draw). The first run hit its `timeout 3000` inside `test_starglow_patches.gd`
(`exit 124`) after 10 scripts passed; the last two were run again on their own:
```
$ timeout 3000 godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_floor_generator.gd,res://tests/unit/sim/test_room_themes.gd,res://tests/unit/sim/test_room_layouts.gd,res://tests/unit/sim/test_boss_room_builder.gd,res://tests/unit/sim/test_shop_placement.gd,res://tests/unit/sim/test_arenas.gd,res://tests/unit/sim/test_overrun.gd,res://tests/unit/sim/test_routes.gd,res://tests/unit/sim/test_event_rooms.gd,res://tests/unit/sim/test_ice_patches.gd,res://tests/unit/sim/test_starglow_patches.gd,res://tests/unit/sim/test_run_flow.gd -gexit
10/10 passed.
3/3 passed.
    room_2x2_1 turn 0 mirror 0 in 27.8 x 22.8 m: 8 groups, 43 blockers (16.1% of the floor), 58 drawn pieces
    room_3x2_1 turn 0 mirror 0 in 43.1 x 22.8 m: 14 groups, 75 blockers (16.5% of the floor), 102 drawn pieces
    room_3x3_1 turn 0 mirror 0 in 43.1 x 35.6 m: 17 groups, 95 blockers (14.7% of the floor), 151 drawn pieces
    designed rooms: 157 of 675 rooms over 40 floors; 7549 of 9679 layout blockers kept (78%)
5/5 passed.
4/4 passed.
5/5 passed.
14/14 passed.
7/7 passed.
12/12 passed.
3/3 passed.
6/6 passed.
exit 124
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_run_flow.gd,res://tests/unit/sim/test_starglow_patches.gd -gexit
Totals
------
Scripts               2
Tests                24
Passing Tests        24
Asserts             531
Time              500.011s
---- All tests passed! ----
exit 0
```
`tests/unit/application` (saves, old saves: `test_a_save_from_before_the_designed_rooms_keeps_its_rooms`) and
`tests/unit/debug` (the dev panel's folder list: `room_layouts` is not balance):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/application,res://tests/unit/debug -ginclude_subdirs -gexit
Totals
------
Warnings              1
Scripts              14
Tests               103
Passing Tests       103
Asserts            1040
Time              39.741s
---- All tests passed! ----
exit 0
```
(the 1 warning is a save test's deliberately damaged file.)
Presentation (`test_stage_dresser.gd` gains the designed rooms drawn solid where solid and restyled by Frozen Shore):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_stage_dresser.gd,res://tests/unit/presentation/test_frozen_shore.gd,res://tests/unit/presentation/test_starfall.gd,res://tests/unit/presentation/test_shard_dressing.gd -gexit
Totals
------
Scripts               4
Tests                36
Passing Tests        36
Asserts           1871338
Time              425.555s
---- All tests passed! ----
exit 0
```
e2e: saves, old save, run flow and the new `test_e2e_designed_rooms.gd` (Play by input events: floor 1 has designed
rooms, their blockers are world walls, their drawn pieces reach the kit, the start hall keeps its rules):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_old_save.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_designed_rooms.gd -gexit
Totals
------
Scripts               4
Tests                 7
Passing Tests         7
Asserts              99
Time              59.676s
---- All tests passed! ----
exit 0
```
Every run floor changes, so the whole e2e shard (every e2e walks a run floor) was run too, as GitHub runs it:
```
$ bash scripts/ci/gut_shard.sh e2e
Totals
------
Scripts              70
Tests               127
Passing Tests       127
Asserts            2309
Time              801.871s
---- All tests passed! ----
check_gut_log: ok (127 passing, minimum 1)
```
Not run locally: the full suite (CLAUDE.md: once per version, on GitHub).

### Shots
```
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_2x2_1
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x2_1
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x3_1
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=night_rocks only=room_3x2_1
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=frozen_shore only=room_2x2_1
```
Raw log lines (per run; `build/rt_logs/shots_<biome>_<layout>.txt`, frame counters and engine warnings left out):
```
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_2x2_1: best kept share 100% (seed 20261020 room 10); mean 73% over 88 rooms
room_layouts: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins targets=[[&"room_2x2_1", 20261020, 10]] missing=[]
room_layouts: room_2x2_1_ruins seed=20261020 floor=1 room=10 cells=(2, 2) size=30.8x23.0 m turn=1 mirror=0 props=316
room_layouts: res://build/shots/v0.8.0/rt/room_2x2_1_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt/room_2x2_1_ruins_close.png
exit 0
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x2_1: best kept share 100% (seed 20261029 room 15); mean 74% over 91 rooms
room_layouts: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins targets=[[&"room_3x2_1", 20261029, 15]] missing=[]
room_layouts: room_3x2_1_ruins seed=20261029 floor=1 room=15 cells=(3, 2) size=45.8x24.4 m turn=2 mirror=0 props=242
room_layouts: res://build/shots/v0.8.0/rt/room_3x2_1_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt/room_3x2_1_ruins_close.png
exit 0
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x3_1: best kept share 100% (seed 20261035 room 6); mean 89% over 19 rooms
room_layouts: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins targets=[[&"room_3x3_1", 20261035, 6]] missing=[]
room_layouts: room_3x3_1_ruins seed=20261035 floor=1 room=6 cells=(3, 3) size=47.4x33.5 m turn=3 mirror=0 props=248
room_layouts: res://build/shots/v0.8.0/rt/room_3x3_1_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt/room_3x3_1_ruins_close.png
exit 0
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x2_1: best kept share 100% (seed 20261029 room 15); mean 74% over 91 rooms
room_layouts: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=night_rocks targets=[[&"room_3x2_1", 20261029, 15]] missing=[]
room_layouts: room_3x2_1_night_rocks seed=20261029 floor=1 room=15 cells=(3, 2) size=45.8x24.4 m turn=2 mirror=0 props=242
room_layouts: res://build/shots/v0.8.0/rt/room_3x2_1_night_rocks_room.png
room_layouts: res://build/shots/v0.8.0/rt/room_3x2_1_night_rocks_close.png
exit 0
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_2x2_1: best kept share 100% (seed 20261020 room 10); mean 73% over 88 rooms
room_layouts: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=frozen_shore targets=[[&"room_2x2_1", 20261020, 10]] missing=[]
room_layouts: room_2x2_1_frozen_shore seed=20261020 floor=1 room=10 cells=(2, 2) size=30.8x23.0 m turn=1 mirror=0 props=316
room_layouts: res://build/shots/v0.8.0/rt/room_2x2_1_frozen_shore_room.png
room_layouts: res://build/shots/v0.8.0/rt/room_2x2_1_frozen_shore_close.png
exit 0
```
SHOT CHOICE (labelled, also in the script's header): for each layout the floor-1 rooms of 60 run seeds from
20261014 were searched and the room that kept the largest share of its layout's blockers is shown (100 % for each),
so the shots show each layout whole; the means above say how much a typical room keeps. The world is never stepped
(no enemies). The other biomes draw the same rooms, as their biome (whatever biome the run drew there).

| Shot | What it shows |
|---|---|
| [`rt_shots/room_2x2_1_ruins_room.png`](rt_shots/room_2x2_1_ruins_room.png) | 2×2 "crossroads", Ruins, seed 20261020 room 10 (30.8 × 23.0 m, turn 1) |
| [`rt_shots/room_3x2_1_ruins_room.png`](rt_shots/room_3x2_1_ruins_room.png) | 3×2 "the yard", Ruins, seed 20261029 room 15 (45.8 × 24.4 m, turn 2) |
| [`rt_shots/room_3x3_1_ruins_room.png`](rt_shots/room_3x3_1_ruins_room.png) | 3×3 "the ruined square", Ruins, seed 20261035 room 6 (47.4 × 33.5 m, turn 3) |
| [`rt_shots/room_3x3_1_ruins_close.png`](rt_shots/room_3x3_1_ruins_close.png) | the same, closer (14 m view) |
| [`rt_shots/room_3x2_1_night_rocks_room.png`](rt_shots/room_3x2_1_night_rocks_room.png) | 3×2 in Night Rocks (crates become rocks and dead trees) |
| [`rt_shots/room_2x2_1_frozen_shore_room.png`](rt_shots/room_2x2_1_frozen_shore_room.png) | 2×2 in Frozen Shore (square cover from its look, snow drifts and ice shards for grass and rubble) |

The `_close` shots of the other rooms are in `build/shots/v0.8.0/rt/` (not copied).

## What the agent sees in the shots (not the owner's judgement)
- The free-standing clusters read as the reference's blocks: tall concrete blocks with crate stacks at their feet, a
  wreck with crates, a fire barrel camp lighting the floor, broken walls with pillars. The 3×3 reads closest to the
  reference.
- The corner and wall clusters sit against the room's thick structural walls and are drawn from the same dark stone,
  so they merge with the walls more than in the reference; the open floor between clusters still reads wide in the
  2×2 (the central lane and the dodging room are on purpose).
- The kit's grass tufts and rubble are small at this camera distance.
- Options for the owner's pick (any mix): more or bigger free-standing clusters in the open floor (less dodging
  room); lighter or taller blocks so the corners stand apart from the walls; denser decoration; or the direction as is
  for the other 21.

## Not done here
- The other 21 layouts (1×1, 2×1, 3×1, 4×3, 4×4, and two more of each size): after the owner's G2 pick.
- The owner's new pieces (ART_LIST) and per-biome models for wrecks, slabs and walls.
- Feel and look on the owner's PC: **OWNER ONLY**.


---

# RT2: the other 21 layouts (every room size has three)

- **Status:** RUN (tests, shots); the look and the feel on the owner's PC are **OWNER ONLY**
- **Build:** the working tree of the commit `v0.8.0 Step RT2` on `v080-rt2` (parent `3cd8b4a`); the code and data that
  ran are the ones committed (the commit cannot name its own SHA); Godot `4.7.2.stable.official.ed1daf0bf`; OS
  `Linux 6.18.44-fc-v114`; shots on llvmpipe (Mesa, LLVM 20.1.2) with `--rendering-driver opengl3` (gl_compatibility)
  under `xvfb-run`, one render at a time
- **Date:** 2026-10-14
- **Who ran it:** agent

## The owner's line (G2 RT)
> "New rooms are fine in density don't need anything else, follow the line of those to create the rest"

## What was built
- **21 layouts** (`data/room_layouts/<x>x<y>_<n>.tres`, written by `scripts/content/room_layouts.py`, never by hand):
  1×1, 2×1 and 3×1 three each; 2×2, 3×2 and 3×3 two more each; 4×3 and 4×4 three each. With RT1's three, 24: three
  per size. Each size's three are built differently: corner clusters, a heavy centre with lanes round it, and a
  diagonal line of cover or a ruined building. New prefabs in the script: `nook_corner`, `camp_corner`,
  `rubble_corner`, `crates_corner`, `wall_short`, `wall_camp`, `wall_spur` and `wall_spur_big` (a broken wall jutting
  from the wall, a pillar at its end), `free_crates`, `free_pillar`, `free_barricade`, `wreck_island`, `ruin_house` (a
  9 × 7 m building outline: corner pillars, broken walls, three 2.4-3 m gaps, crates and a fire barrel inside),
  `ruin_ell` (its broken corner), `central_block`, `stair` (a diagonal band of blocks touching corner to corner).
  RT1's prefabs and its three files are unchanged (byte-identical, checked with `cmp` after each regeneration).
- **How they were placed:** by hand from the prefabs, then nudged and filled with two scratch helpers (not committed;
  they only print or rewrite anchors in the script): one moves a failing group's anchor by up to 0.08 to the nearest
  spot that passes the script's checks in both orientations of a typical room, the other suggests a free-standing
  prefab for the largest open hole until a target share. Their output is the plain anchors in the script.
- **The script's checks** (as RT1's: no slit in a group; groups flush with a wall or 2.2 m from walls and each other;
  open lanes; kept groups at the size range's corners) gain: the 1-cell sizes (RT1's table had them wrong; x
  8.8-16.2 m, y 6.8-13.2 m), the open floor's regions at an enemy's 0.6 m clearance, solids 0.6-2.0 m off a wall they
  face, and a 3 cm margin on the spacing rules. The margin came from a failure: groups of `room_4x4_1` and
  `room_4x4_2` sat on a 2.2 m edge, the game's whole-cm placement put them a hair inside, and the typical-room test
  failed for both ("the open lane is open", "every blocker kept": 128 of 132); they were moved and the test passed.
  With the margin the script now prints one of RT1's `room_3x2_1` groups 2.21-2.23 m from its neighbour as dropped;
  the game keeps it (the typical-room test keeps every RT1 blocker). The wall-slit check flags RT1's `crate_corner`
  rock (1.3 m off the wall, its crate stack filling all but a 0.1 m strip), in RT1's layouts as in the new ones that
  use it; no new prefab is flagged.
- **Generator:** no code change was needed to use layouts for every size: RT1's generator draws a layout for any room
  whose size has one (the "limit" was the data). The start hall and the portal room keep their rules; the boss room is
  built by `BossRoomBuilder` after generation and never draws a layout (the 4×4 layouts furnish ordinary 4×4 rooms).
- **Saves: floor rules 5.** A v0.8.0-RT1 save (rules 4) would rebuild differently under RT2: its 1×1, 2×1, 3×1, 4×3
  and 4×4 rooms would now draw a layout from the `map` stream, which moves every later draw on the floor. v0.8.0 has
  not shipped, but the owner may hold a save from an RT1 build and keeping it is cheap, so: `RunState.FLOOR_RULES` 5,
  `FLOOR_RULES_V080_RT1` 4, `RunState.rt1_rooms()`; `RunSaver.floor_tables` gives a rules-4 floor only
  `RunSaver.RT1_LAYOUTS` (`room_2x2_1`, `room_3x2_1`, `room_3x3_1`). Checked against RT1's own code below (90 floors,
  identical). New test `test_old_saves.gd::test_a_save_from_the_first_designed_rooms_keeps_its_rooms`.

## The 21 layouts (numbers from the script and `test_room_layouts.gd`; starting values)
| Layout | Reads as | Groups | Blockers | Drawn pieces, typical room | Blocking, typical room (both ways round) | Dressed |
|---|---|---|---|---|---|---|
| `room_1x1_1` | the nook: three corners round an open middle (corners) | 3 | 10 | 9 | 14.7 % (12.5 × 10.0 m) / 14.7 % (10.0 × 12.5 m) | 29.1 % |
| `room_1x1_2` | the pillar: one block in the middle, lanes either side (centre) | 4 | 12 | 12 | 14.8 % (12.5 × 10.0 m) / 14.8 % (10.0 × 12.5 m) | 34.0 % |
| `room_1x1_3` | the spurs: two broken walls jutting from opposite walls on a diagonal (diagonal) | 4 | 14 | 16 | 12.1 % (12.5 × 10.0 m) / 12.1 % (10.0 × 12.5 m) | 32.9 % |
| `room_2x1_1` | the depot: four corners, a cluster on each long wall (corners) | 6 | 19 | 19 | 13.4 % (27.8 × 10.0 m) / 13.0 % (22.8 × 12.5 m) | 25.6 % |
| `room_2x1_2` | the wreck: a wreck island in the middle, lanes along both long walls (centre) | 5 | 17 | 29 | 14.0 % (27.8 × 10.0 m) / 13.7 % (22.8 × 12.5 m) | 25.5 % |
| `room_2x1_3` | the slalom: three broken walls jutting from alternate walls (diagonal) | 5 | 21 | 29 | 14.1 % (27.8 × 10.0 m) / 13.7 % (22.8 × 12.5 m) | 29.2 % |
| `room_3x1_1` | the street: corners and small wall clusters, a lane down the middle (corners) | 8 | 25 | 27 | 11.2 % (43.1 × 10.0 m) / 10.9 % (35.6 × 12.5 m) | 21.7 % |
| `room_3x1_2` | the barricades: a block, a wreck island, a barricade down the middle (centre) | 7 | 25 | 37 | 11.5 % (43.1 × 10.0 m) / 11.2 % (35.6 × 12.5 m) | 23.8 % |
| `room_3x1_3` | the slalom: four jutting broken walls, alternate sides (diagonal) | 7 | 29 | 41 | 12.0 % (43.1 × 10.0 m) / 11.6 % (35.6 × 12.5 m) | 25.0 % |
| `room_2x2_2` | the block: a ruined block between two block clusters (centre) | 9 | 39 | 55 | 15.7 % (27.8 × 22.8 m) / 15.7 % (22.8 × 27.8 m) | 26.5 % |
| `room_2x2_3` | the diagonal: two diagonal bands of blocks round an open middle (diagonal) | 10 | 43 | 62 | 14.2 % (27.8 × 22.8 m) / 14.2 % (22.8 × 27.8 m) | 25.7 % |
| `room_3x2_2` | the ruin: a ruined building outline at one end, a wreck at the other (building) | 16 | 73 | 116 | 14.0 % (43.1 × 22.8 m) / 13.9 % (35.6 × 27.8 m) | 28.4 % |
| `room_3x2_3` | the convoy: two wreck islands on a diagonal, wreck corners (diagonal) | 12 | 60 | 104 | 15.4 % (43.1 × 22.8 m) / 15.3 % (35.6 × 27.8 m) | 28.6 % |
| `room_3x3_2` | the keep: a ruined building in the middle, blocks on four sides, open quarters (centre) | 15 | 87 | 132 | 13.5 % (43.1 × 35.6 m) / 13.5 % (35.6 × 43.1 m) | 23.6 % |
| `room_3x3_3` | the diagonal: block bands and blocks corner to corner, a building off it (diagonal) | 19 | 99 | 157 | 13.3 % (43.1 × 35.6 m) / 13.3 % (35.6 × 43.1 m) | 25.2 % |
| `room_4x3_1` | the depot: corners, clusters on every wall, two rows of free cover (corners) | 21 | 117 | 176 | 14.0 % (58.4 × 35.6 m) / 13.9 % (48.4 × 43.1 m) | 24.7 % |
| `room_4x3_2` | the compound: two ruined buildings on a diagonal, ruined blocks (building) | 20 | 120 | 194 | 13.1 % (58.4 × 35.6 m) / 13.1 % (48.4 × 43.1 m) | 24.1 % |
| `room_4x3_3` | the convoy: block bands and wreck islands corner to corner, two buildings (diagonal) | 22 | 123 | 227 | 13.4 % (58.4 × 35.6 m) / 13.4 % (48.4 × 43.1 m) | 25.2 % |
| `room_4x4_1` | the quarter: corners, two clusters a wall, inner and outer rings (corners) | 34 | 168 | 264 | 13.9 % (58.4 × 48.4 m) / 13.9 % (48.4 × 58.4 m) | 25.2 % |
| `room_4x4_2` | the citadel: a building walled by blocks, lanes round it (centre) | 27 | 132 | 240 | 11.8 % (58.4 × 48.4 m) / 11.8 % (48.4 × 58.4 m) | 20.7 % |
| `room_4x4_3` | the crossing: eight bands of blocks on the two diagonals, the middle open, ruined buildings and blocks at the walls (diagonal) | 24 | 154 | 260 | 12.2 % (58.4 × 48.4 m) / 12.2 % (48.4 × 58.4 m) | 21.8 % |

"Typical room": the middle of the drawn cell sizes and wall halves, as in RT1; "both ways round": the layout's frame in
the room's two orientations; "dressed": blockers plus the layout's grass, rubble and debris counted as 1 m² a piece.
For comparison RT1's three block 14.7-16.5 % and dress 27-31 %. The new 2×1, 2×2, 3×2, 3×3 and 4×3 layouts block
13.0-15.7 %; the small rooms less on purpose ("fewer, smaller groups"): the 1×1s 12.1-14.8 %, the 3×1s 10.9-12.0 %;
the 4×4s 11.8-13.9 %: `room_4x4_2` (11.8 %) and `room_4x4_3` (12.2 %) are below RT1's range (reported, not widened).
Dressed 20.7-34.0 %.

## Kept share over many floors (doorways drop groups)
From `test_room_layouts.gd::test_run_floors_with_designed_rooms_are_whole` (60 run floors; every room checked whole at
an enemy's clearance and the player's, doorways and their approach boxes clear, start, gate, items and spawns clear):
```
    designed rooms: 888 of 1008 rooms over 60 floors; 21894 of 27689 layout blockers kept (79%)
      1 x 1: 269 rooms, 2213 of 3184 blockers kept (70%); 65 rooms kept under half
      2 x 1: 249 rooms, 3429 of 4691 blockers kept (73%); 41 rooms kept under half
      2 x 2: 107 rooms, 3557 of 4485 blockers kept (79%); 8 rooms kept under half
      3 x 1: 122 rooms, 2530 of 3190 blockers kept (79%); 7 rooms kept under half
      3 x 2: 85 rooms, 4626 of 5897 blockers kept (78%); 1 rooms kept under half
      3 x 3: 30 rooms, 2431 of 2802 blockers kept (87%); 0 rooms kept under half
      4 x 3: 16 rooms, 1720 of 1932 blockers kept (89%); 0 rooms kept under half
      4 x 4: 10 rooms, 1388 of 1508 blockers kept (92%); 0 rooms kept under half
```
The rooms keeping under half of their layout (mostly 1×1 and 2×1 rooms with doorways on most sides) passed every
check like the others. All 24 layouts, all four turns of a square layout and both mirrors were drawn. The rooms not
designed (120 of 1008) are the start halls and portal rooms.

## Commands and raw output

### Layout numbers
```
$ python3 -I scripts/content/room_layouts.py .
```
(writes the 24 `.tres` files and `build/room_layouts/*_mid*.png`; output kept in `build/rt2_py.txt`). The "mid" rows of
the 21 new layouts:
```
== 1x1_1 groups 3 slits []
  mid  12.5 x  10.0 kept  3/3 block 14.7% dressed 29.1%  [] regions 1 [] wall slits []
  mid  10.0 x  12.5 kept  3/3 block 14.7% dressed 29.1%  [] regions 1 [] wall slits []
== 1x1_2 groups 4 slits []
  mid  12.5 x  10.0 kept  4/4 block 14.8% dressed 34.0%  [] regions 1 [] wall slits []
  mid  10.0 x  12.5 kept  4/4 block 14.8% dressed 34.0%  [] regions 1 [] wall slits []
== 1x1_3 groups 4 slits []
  mid  12.5 x  10.0 kept  4/4 block 12.1% dressed 32.9%  [] regions 1 [] wall slits []
  mid  10.0 x  12.5 kept  4/4 block 12.1% dressed 32.9%  [] regions 1 [] wall slits []
== 2x1_1 groups 6 slits []
  mid  27.8 x  10.0 kept  6/6 block 13.4% dressed 25.6%  [] regions 1 [] wall slits []
  mid  22.8 x  12.5 kept  6/6 block 13.0% dressed 25.0%  [] regions 1 [] wall slits []
== 2x1_2 groups 5 slits []
  mid  27.8 x  10.0 kept  5/5 block 14.0% dressed 25.5%  [] regions 1 [] wall slits []
  mid  22.8 x  12.5 kept  5/5 block 13.7% dressed 24.9%  [] regions 1 [] wall slits []
== 2x1_3 groups 5 slits []
  mid  27.8 x  10.0 kept  5/5 block 14.1% dressed 29.2%  [] regions 1 [] wall slits []
  mid  22.8 x  12.5 kept  5/5 block 13.7% dressed 28.5%  [] regions 1 [] wall slits []
== 3x1_1 groups 8 slits []
  mid  43.1 x  10.0 kept  8/8 block 11.2% dressed 21.7%  [] regions 1 [] wall slits []
  mid  35.6 x  12.5 kept  8/8 block 10.9% dressed 21.0%  [] regions 1 [] wall slits []
== 3x1_2 groups 7 slits []
  mid  43.1 x  10.0 kept  7/7 block 11.5% dressed 23.8%  [] regions 1 [] wall slits []
  mid  35.6 x  12.5 kept  7/7 block 11.2% dressed 23.1%  [] regions 1 [] wall slits []
== 3x1_3 groups 7 slits []
  mid  43.1 x  10.0 kept  7/7 block 12.0% dressed 25.0%  [] regions 1 [] wall slits []
  mid  35.6 x  12.5 kept  7/7 block 11.6% dressed 24.2%  [] regions 1 [] wall slits []
== 2x2_2 groups 9 slits []
  mid  27.8 x  22.8 kept  9/9 block 15.7% dressed 26.5%  [] regions 1 [] wall slits []
  mid  22.8 x  27.8 kept  9/9 block 15.7% dressed 26.5%  [] regions 1 [] wall slits []
== 2x2_3 groups 10 slits []
  mid  27.8 x  22.8 kept 10/10 block 14.2% dressed 25.7%  [] regions 1 [] wall slits []
  mid  22.8 x  27.8 kept 10/10 block 14.2% dressed 25.7%  [] regions 1 [] wall slits []
== 3x2_2 groups 16 slits []
  mid  43.1 x  22.8 kept 16/16 block 14.0% dressed 28.4%  [] regions 1 [] wall slits [(4, 4, 1.3)]
  mid  35.6 x  27.8 kept 16/16 block 13.9% dressed 28.2%  [] regions 1 [] wall slits [(4, 4, 1.3)]
== 3x2_3 groups 12 slits []
  mid  43.1 x  22.8 kept 12/12 block 15.4% dressed 28.6%  [] regions 1 [] wall slits []
  mid  35.6 x  27.8 kept 12/12 block 15.3% dressed 28.4%  [] regions 1 [] wall slits []
== 3x3_2 groups 15 slits []
  mid  43.1 x  35.6 kept 15/15 block 13.5% dressed 23.6%  [] regions 1 [] wall slits [(7, 4, 1.3)]
  mid  35.6 x  43.1 kept 15/15 block 13.5% dressed 23.6%  [] regions 1 [] wall slits [(7, 4, 1.3)]
== 3x3_3 groups 19 slits []
  mid  43.1 x  35.6 kept 19/19 block 13.3% dressed 25.2%  [] regions 1 [] wall slits []
  mid  35.6 x  43.1 kept 19/19 block 13.3% dressed 25.2%  [] regions 1 [] wall slits []
== 4x3_1 groups 21 slits []
  mid  58.4 x  35.6 kept 21/21 block 14.0% dressed 24.7%  [] regions 1 [] wall slits [(2, 4, 1.3)]
  mid  48.4 x  43.1 kept 21/21 block 13.9% dressed 24.6%  [] regions 1 [] wall slits [(2, 4, 1.3)]
== 4x3_2 groups 20 slits []
  mid  58.4 x  35.6 kept 20/20 block 13.1% dressed 24.1%  [] regions 1 [] wall slits [(8, 4, 1.3)]
  mid  48.4 x  43.1 kept 20/20 block 13.1% dressed 24.0%  [] regions 1 [] wall slits [(8, 4, 1.3)]
== 4x3_3 groups 22 slits []
  mid  58.4 x  35.6 kept 22/22 block 13.4% dressed 25.2%  [] regions 1 [] wall slits []
  mid  48.4 x  43.1 kept 22/22 block 13.4% dressed 25.1%  [] regions 1 [] wall slits []
== 4x4_1 groups 34 slits []
  mid  58.4 x  48.4 kept 34/34 block 13.9% dressed 25.2%  [] regions 1 [] wall slits [(2, 4, 1.3)]
  mid  48.4 x  58.4 kept 34/34 block 13.9% dressed 25.2%  [] regions 1 [] wall slits [(2, 4, 1.3)]
== 4x4_2 groups 27 slits []
  mid  58.4 x  48.4 kept 27/27 block 11.8% dressed 20.7%  [] regions 1 [] wall slits []
  mid  48.4 x  58.4 kept 27/27 block 11.8% dressed 20.7%  [] regions 1 [] wall slits []
== 4x4_3 groups 24 slits []
  mid  58.4 x  48.4 kept 24/24 block 12.2% dressed 21.8%  [] regions 1 [] wall slits []
  mid  48.4 x  58.4 kept 24/24 block 12.2% dressed 21.8%  [] regions 1 [] wall slits []
```

### Rules-4 floors are RT1's floors
A scratch script (not committed; it only prints) builds floors 1-3 of run seeds 20261100-20261129 under floor rules 4
and prints a hash of each floor's walls, layout ids, turns, mirrors, drawn pieces and item spots:
```gdscript
var run := SaveLab.run_state(20261100 + s, fl)
run.floor_rules = 4
var map: FloorParams = RunSaver.floor_tables(run, repo)[&"map"]
var f := FloorGenerator.generate(run.floor_seed(), map)
# prints hash(str([walls, f.room_layout, f.room_turn, f.room_mirror, f.layout_props, f.item_spots]))
```
Run in a copy of `3cd8b4a` (RT1; `git archive 3cd8b4a`, imported) and in the RT2 tree:
```
$ godot --headless --path . -s <scratch>/rt1_floors.gd      # in each tree, filtered to its lines
rt1_floors: 20261100/1 3904924490 [&"room_3x3_1", &"room_3x2_1", &"room_2x2_1", &"room_3x2_1", &"room_2x2_1"]
rt1_floors: 20261100/2 911993671 [&"room_3x3_1", &"room_3x3_1", &"room_3x2_1", &"room_2x2_1", &"room_3x2_1"]
rt1_floors: 20261100/3 2349837557 [&"room_3x2_1", &"room_3x2_1", &"room_3x2_1", &"room_2x2_1"]
...
$ cmp rt1_floors_rt1.txt rt1_floors_rt2.txt && echo IDENTICAL
IDENTICAL
$ md5sum rt1_floors_rt*.txt
547275f8009499174c92dd4f4e5577e4  rt1_floors_rt1.txt
547275f8009499174c92dd4f4e5577e4  rt1_floors_rt2.txt
```
(90 lines each.)

### Tests
Raw logs in `build/rt2_logs/`. Lint:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
842 files would be left unchanged
Success: no problems found
```
`tests/content` (the 24 layouts valid, three per size, dense and dressed; every other content test):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Totals
------
Scripts              27
Tests               136
Passing Tests       136
Asserts            8954
Time              27.534s
---- All tests passed! ----
exit 0
```
`tests/arch` + `tests/golden` (goldens unchanged):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
Totals
------
Scripts               3
Tests                 6
Passing Tests         6
Asserts            9374
Time              9.087s
---- All tests passed! ----
exit 0
```
The map and generator sim tests by name. Under the shared machine's load the run hit its `timeout 3000` inside
`test_ice_patches.gd` (`exit 124`) after the other nine scripts passed (`test_room_layouts.gd`: the typical-room test of
all 24 in every turn and mirror, the 60-floor property test above, determinism, no layouts no draw);
`test_event_rooms.gd` and `test_ice_patches.gd` were then run on their own, `test_run_flow.gd` and
`test_starglow_patches.gd` too:
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_floor_generator.gd,res://tests/unit/sim/test_room_themes.gd,res://tests/unit/sim/test_room_layouts.gd,res://tests/unit/sim/test_boss_room_builder.gd,res://tests/unit/sim/test_shop_placement.gd,res://tests/unit/sim/test_arenas.gd,res://tests/unit/sim/test_overrun.gd,res://tests/unit/sim/test_routes.gd,res://tests/unit/sim/test_event_rooms.gd,res://tests/unit/sim/test_ice_patches.gd -gexit
res://tests/unit/sim/test_floor_generator.gd
10/10 passed.
res://tests/unit/sim/test_room_themes.gd
3/3 passed.
res://tests/unit/sim/test_room_layouts.gd
5/5 passed.
res://tests/unit/sim/test_boss_room_builder.gd
4/4 passed.
res://tests/unit/sim/test_shop_placement.gd
5/5 passed.
res://tests/unit/sim/test_arenas.gd
14/14 passed.
res://tests/unit/sim/test_overrun.gd
7/7 passed.
res://tests/unit/sim/test_routes.gd
12/12 passed.
res://tests/unit/sim/test_event_rooms.gd
3/3 passed.
res://tests/unit/sim/test_ice_patches.gd
exit 124
```
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_event_rooms.gd -gexit
Totals
------
Scripts               1
Tests                 3
Passing Tests         3
Asserts             515
Time              680.194s
---- All tests passed! ----
exit 0
```
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_ice_patches.gd -gexit
Totals
------
Scripts               1
Tests                 6
Passing Tests         6
Asserts              23
Time              582.44s
---- All tests passed! ----
exit 0
```
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_run_flow.gd -gexit
Totals
------
Scripts               1
Tests                18
Passing Tests        18
Asserts             500
Time              32.105s
---- All tests passed! ----
exit 0
```
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_starglow_patches.gd -gexit
Totals
------
Scripts               1
Tests                 6
Passing Tests         6
Asserts              31
Time              486.068s
---- All tests passed! ----
exit 0
```
`tests/unit/application` (saves; old saves, with the new rules-4 test) and `tests/unit/debug` (the dev panel's folder
list); the 1 warning is a save test's deliberately damaged file:
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/application,res://tests/unit/debug -ginclude_subdirs -gexit
Totals
------
Warnings              1
Scripts              14
Tests               104
Passing Tests       104
Asserts            1071
Time              61.512s
---- All tests passed! ----
exit 0
```
Presentation (the dresser on designed floors, biome swaps):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_stage_dresser.gd,res://tests/unit/presentation/test_frozen_shore.gd,res://tests/unit/presentation/test_starfall.gd,res://tests/unit/presentation/test_shard_dressing.gd -gexit
Totals
------
Scripts               4
Tests                36
Passing Tests        36
Asserts           1871389
Time              441.675s
---- All tests passed! ----
exit 0
```
e2e: saves, old save, run flow, designed rooms (Play by input events):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_old_save.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_designed_rooms.gd -gexit
Totals
------
Scripts               4
Tests                 7
Passing Tests         7
Asserts              99
Time              73.64s
---- All tests passed! ----
exit 0
```
Every run floor changes, so the whole e2e shard was run too, as GitHub runs it. One test failed:
```
$ bash scripts/ci/gut_shard.sh e2e
Totals
------
Scripts              71
Tests               128
Passing Tests       127
Failing Tests         1
Asserts           2797/2798
Time              1011.667s
---- 1 failing tests ----
exit 1
```
```
res://tests/e2e/test_e2e_bosses_2.gd
- test_the_warlord_is_reached_through_the_dev_panel
    [Failed]:  warlord: its telegraph is drawn
          at line -1
```
It fails on its own too:
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_bosses_2.gd -gexit
Totals
------
Scripts               1
Tests                 3
Passing Tests         2
Failing Tests         1
Asserts           29/30
Time              28.409s
---- 1 failing tests ----
exit 1
```
and the same on the base without RT2 (a copy of `3cd8b4a`, imported, same command), so RT2 did not cause it (the boss is
spawned by the dev panel in the start hall, which keeps its rule-built interior; not investigated further here, left
open for the lead in PROGRESS):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_bosses_2.gd -gexit   # in the 3cd8b4a copy
    [Failed]:  warlord: its telegraph is drawn
    [Failed]:  warlord: its telegraph is drawn
Passing Tests         2
Failing Tests         1
exit 1
```
Not run locally: the full suite (CLAUDE.md: once per version, on GitHub).

### Shots
One render at a time (the shared machine OOM-killed parallel renders before):
```
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_1x1_1 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_1x1_2 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_1x1_3 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_2x1_1 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_2x1_2 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_2x1_3 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x1_1 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x1_2 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x1_3 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_2x2_2 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_2x2_3 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x2_2 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x2_3 out=rt2 search=60
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x3_2 out=rt2 search=150
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_3x3_3 out=rt2 search=150
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_4x3_1 out=rt2 search=150
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_4x3_2 out=rt2 search=150
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_4x3_3 out=rt2 search=150
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_4x4_1 out=rt2 search=150
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_4x4_2 out=rt2 search=150
$ XDG_DATA_HOME=<empty dir> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins only=room_4x4_3 out=rt2 search=150
```
Raw log lines per run (`build/rt2_logs/shots_<layout>.txt`; engine warnings and frame counters left out: V-Sync, SSIL
only in Forward+, and MultiMesh interpolation outside the physics process, as in RT1):
```
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_1x1_1: best kept share 100% (seed 20261014 room 11); mean 65% over 92 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_1x1_1_ruins seed=20261014 floor=1 room=11 cells=(1, 1) size=12.4x11.0 m turn=0 mirror=1 props=573
room_layouts: res://build/shots/v0.8.0/rt2/room_1x1_1_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_1x1_1_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_1x1_2: best kept share 100% (seed 20261014 room 17); mean 73% over 100 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_1x1_2_ruins seed=20261014 floor=1 room=17 cells=(1, 1) size=12.5x10.8 m turn=2 mirror=0 props=573
room_layouts: res://build/shots/v0.8.0/rt2/room_1x1_2_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_1x1_2_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_1x1_3: best kept share 100% (seed 20261018 room 16); mean 68% over 93 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_1x1_3_ruins seed=20261018 floor=1 room=16 cells=(1, 1) size=10.9x11.4 m turn=3 mirror=1 props=591
room_layouts: res://build/shots/v0.8.0/rt2/room_1x1_3_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_1x1_3_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_2x1_1: best kept share 100% (seed 20261021 room 7); mean 66% over 92 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_2x1_1_ruins seed=20261021 floor=1 room=7 cells=(1, 2) size=13.2x24.9 m turn=1 mirror=0 props=762
room_layouts: res://build/shots/v0.8.0/rt2/room_2x1_1_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_2x1_1_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_2x1_2: best kept share 100% (seed 20261014 room 16); mean 77% over 86 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_2x1_2_ruins seed=20261014 floor=1 room=16 cells=(1, 2) size=12.8x24.2 m turn=3 mirror=0 props=573
room_layouts: res://build/shots/v0.8.0/rt2/room_2x1_2_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_2x1_2_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_2x1_3: best kept share 100% (seed 20261015 room 8); mean 77% over 83 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_2x1_3_ruins seed=20261015 floor=1 room=8 cells=(2, 1) size=27.1x10.2 m turn=2 mirror=0 props=337
room_layouts: res://build/shots/v0.8.0/rt2/room_2x1_3_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_2x1_3_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x1_1: best kept share 88% (seed 20261020 room 11); mean 67% over 35 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_3x1_1_ruins seed=20261020 floor=1 room=11 cells=(3, 1) size=46.6x9.2 m turn=0 mirror=1 props=701
room_layouts: res://build/shots/v0.8.0/rt2/room_3x1_1_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_3x1_1_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x1_2: best kept share 100% (seed 20261014 room 13); mean 76% over 45 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_3x1_2_ruins seed=20261014 floor=1 room=13 cells=(3, 1) size=40.0x11.4 m turn=2 mirror=1 props=573
room_layouts: res://build/shots/v0.8.0/rt2/room_3x1_2_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_3x1_2_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x1_3: best kept share 100% (seed 20261024 room 9); mean 84% over 42 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_3x1_3_ruins seed=20261024 floor=1 room=9 cells=(1, 3) size=12.9x35.5 m turn=3 mirror=0 props=511
room_layouts: res://build/shots/v0.8.0/rt2/room_3x1_3_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_3x1_3_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_2x2_2: best kept share 100% (seed 20261020 room 10); mean 80% over 33 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_2x2_2_ruins seed=20261020 floor=1 room=10 cells=(2, 2) size=30.8x23.0 m turn=1 mirror=1 props=701
room_layouts: res://build/shots/v0.8.0/rt2/room_2x2_2_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_2x2_2_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_2x2_3: best kept share 100% (seed 20261016 room 15); mean 78% over 26 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_2x2_3_ruins seed=20261016 floor=1 room=15 cells=(2, 2) size=31.5x21.8 m turn=0 mirror=1 props=363
room_layouts: res://build/shots/v0.8.0/rt2/room_2x2_3_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_2x2_3_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x2_2: best kept share 96% (seed 20261020 room 15); mean 83% over 29 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_3x2_2_ruins seed=20261020 floor=1 room=15 cells=(3, 2) size=48.1x22.7 m turn=0 mirror=1 props=701
room_layouts: res://build/shots/v0.8.0/rt2/room_3x2_2_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_3x2_2_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x2_3: best kept share 100% (seed 20261019 room 10); mean 77% over 38 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_3x2_3_ruins seed=20261019 floor=1 room=10 cells=(2, 3) size=29.2x33.7 m turn=3 mirror=1 props=581
room_layouts: res://build/shots/v0.8.0/rt2/room_3x2_3_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_3x2_3_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x3_2: best kept share 100% (seed 20261051 room 12); mean 89% over 23 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_3x3_2_ruins seed=20261051 floor=1 room=12 cells=(3, 3) size=44.0x34.3 m turn=3 mirror=1 props=552
room_layouts: res://build/shots/v0.8.0/rt2/room_3x3_2_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_3x3_2_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_3x3_3: best kept share 100% (seed 20261021 room 11); mean 90% over 18 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_3x3_3_ruins seed=20261021 floor=1 room=11 cells=(3, 3) size=42.1x37.2 m turn=3 mirror=0 props=762
room_layouts: res://build/shots/v0.8.0/rt2/room_3x3_3_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_3x3_3_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_4x3_1: best kept share 96% (seed 20261122 room 15); mean 86% over 25 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_4x3_1_ruins seed=20261122 floor=1 room=15 cells=(4, 3) size=58.8x34.1 m turn=0 mirror=1 props=666
room_layouts: res://build/shots/v0.8.0/rt2/room_4x3_1_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_4x3_1_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_4x3_2: best kept share 95% (seed 20261021 room 6); mean 87% over 17 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_4x3_2_ruins seed=20261021 floor=1 room=6 cells=(3, 4) size=41.3x50.8 m turn=1 mirror=1 props=762
room_layouts: res://build/shots/v0.8.0/rt2/room_4x3_2_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_4x3_2_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_4x3_3: best kept share 100% (seed 20261103 room 9); mean 86% over 21 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_4x3_3_ruins seed=20261103 floor=1 room=9 cells=(4, 3) size=58.5x37.7 m turn=2 mirror=0 props=780
room_layouts: res://build/shots/v0.8.0/rt2/room_4x3_3_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_4x3_3_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_4x4_1: best kept share 83% (seed 20261024 room 3); mean 82% over 2 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_4x4_1_ruins seed=20261024 floor=1 room=3 cells=(4, 4) size=56.7x46.6 m turn=0 mirror=0 props=511
room_layouts: res://build/shots/v0.8.0/rt2/room_4x4_1_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_4x4_1_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_4x4_2: best kept share 100% (seed 20261070 room 7); mean 83% over 7 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_4x4_2_ruins seed=20261070 floor=1 room=7 cells=(4, 4) size=58.7x51.8 m turn=2 mirror=0 props=633
room_layouts: res://build/shots/v0.8.0/rt2/room_4x4_2_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_4x4_2_ruins_close.png
exit 0
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
room_layouts: room_4x4_3: best kept share 100% (seed 20261111 room 2); mean 93% over 9 rooms
room_layouts: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins
room_layouts: room_4x4_3_ruins seed=20261111 floor=1 room=2 cells=(4, 4) size=64.1x46.0 m turn=0 mirror=0 props=822
room_layouts: res://build/shots/v0.8.0/rt2/room_4x4_3_ruins_room.png
room_layouts: res://build/shots/v0.8.0/rt2/room_4x4_3_ruins_close.png
exit 0
```
SHOT CHOICE (labelled, as RT1): for each layout the floor-1 rooms of 60 run seeds from 20261014 (150 for the 3×3, 4×3
and 4×4 layouts: such rooms are rarer) were searched and the room keeping the largest share of the layout's blockers is
shown; the means say what a typical room keeps. The world is never stepped (no enemies). All 42 images (a `_room` and a
`_close` per layout) are in `build/shots/v0.8.0/rt2/`; one per size is copied:

| Shot | What it shows |
|---|---|
| [`rt_shots/room_1x1_2_ruins_room.png`](rt_shots/room_1x1_2_ruins_room.png) | `room_1x1_2`, Ruins, seed 20261014 room 17 (1×1 cells, 12.5 × 10.8 m, turn 2, mirror 0); keeps 100 % of its blockers (mean 73 % over 100 rooms) |
| [`rt_shots/room_2x1_3_ruins_room.png`](rt_shots/room_2x1_3_ruins_room.png) | `room_2x1_3`, Ruins, seed 20261015 room 8 (2×1 cells, 27.1 × 10.2 m, turn 2, mirror 0); keeps 100 % of its blockers (mean 77 % over 83 rooms) |
| [`rt_shots/room_3x1_2_ruins_room.png`](rt_shots/room_3x1_2_ruins_room.png) | `room_3x1_2`, Ruins, seed 20261014 room 13 (3×1 cells, 40.0 × 11.4 m, turn 2, mirror 1); keeps 100 % of its blockers (mean 76 % over 45 rooms) |
| [`rt_shots/room_2x2_3_ruins_room.png`](rt_shots/room_2x2_3_ruins_room.png) | `room_2x2_3`, Ruins, seed 20261016 room 15 (2×2 cells, 31.5 × 21.8 m, turn 0, mirror 1); keeps 100 % of its blockers (mean 78 % over 26 rooms) |
| [`rt_shots/room_3x2_2_ruins_room.png`](rt_shots/room_3x2_2_ruins_room.png) | `room_3x2_2`, Ruins, seed 20261020 room 15 (3×2 cells, 48.1 × 22.7 m, turn 0, mirror 1); keeps 96 % of its blockers (mean 83 % over 29 rooms) |
| [`rt_shots/room_3x3_2_ruins_room.png`](rt_shots/room_3x3_2_ruins_room.png) | `room_3x3_2`, Ruins, seed 20261051 room 12 (3×3 cells, 44.0 × 34.3 m, turn 3, mirror 1); keeps 100 % of its blockers (mean 89 % over 23 rooms) |
| [`rt_shots/room_4x3_2_ruins_room.png`](rt_shots/room_4x3_2_ruins_room.png) | `room_4x3_2`, Ruins, seed 20261021 room 6 (3×4 cells, 41.3 × 50.8 m, turn 1, mirror 1); keeps 95 % of its blockers (mean 87 % over 17 rooms) |
| [`rt_shots/room_4x4_2_ruins_room.png`](rt_shots/room_4x4_2_ruins_room.png) | `room_4x4_2`, Ruins, seed 20261070 room 7 (4×4 cells, 58.7 × 51.8 m, turn 2, mirror 0); keeps 100 % of its blockers (mean 83 % over 7 rooms) |

## What the agent sees in the shots (not the owner's judgement)
Of the shots it opened (`room_1x1_1`, `room_2x2_2`, `room_2x2_3`, `room_3x3_2`, `room_4x4_2`, `room_4x4_3`):
- `room_1x1_1` keeps most of its small floor open, with blocks and crates in its corners and a lit fire barrel.
- The ruined building outline reads as a roofless house with a fire barrel lit inside (`room_3x3_2`, `room_4x4_2`,
  `room_4x4_3`); the diagonal bands read as staggered stacks of blocks (`room_2x2_3`, `room_4x4_3`); `room_2x2_2`'s
  middle block stands between two block clusters with open floor either side.
- As in RT1, the clusters against the room walls merge with the walls' dark stone more than the free-standing ones.

## Not done here
- The owner's new pieces (ART_LIST) and per-biome models for wrecks, slabs and walls (unchanged from RT1).
- Shots in other biomes (the biome swaps are RT1's; `test_stage_dresser.gd` covers them on designed floors).
- Feel and look on the owner's PC: **OWNER ONLY**.
