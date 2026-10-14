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
