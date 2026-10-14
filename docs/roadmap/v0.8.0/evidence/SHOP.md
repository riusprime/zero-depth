# SHOP: the shop room per biome (v0.8.0 Step SR)

- **Status:** RUN (tests and shots); the look and the feel are **OWNER ONLY**
- **Build:** the working tree of the commit `v0.8.0 Step SR` on `v080-sr` (parent `b988819`); the code and data that ran
  are the ones committed (everything ran before the commit, so the commit cannot name its own SHA); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`; shots on llvmpipe (Mesa 25.2.8, LLVM 20.1.2) under
  `xvfb-run` with `--rendering-driver opengl3` (the Compatibility renderer, as asked for this step: no SSAO/SSIL)
- **Date:** 2026-10-14
- **Who ran it:** agent

## The owner's line (O13)
> "this shop room that is gonna be designed in a way for each biome that will have like its own vendor like with a
> model and it will be like in a tent shop with some stuff I will give you a model for that"

## What was built
- **Data.** `ShopRoomDefinition` (category `shop_room`, extends `RoomLayoutDefinition`) and
  `data/shop_rooms/{ruins,night_rocks,red_canyon,frozen_shore,starfall}.tres`, written by
  `scripts/content/shop_rooms.py` (a separate script that imports `room_layouts.py`'s prefab helpers;
  `room_layouts.py` is unchanged). Each: the stall (a solid `shop_counter` 4.0 × 0.9 m in front of a solid
  `shop_tent` 4.0 × 2.5 m: the owner's stall's footprint), 15 spots to try, a 6 × 3 m walk-up kept clear, and 17
  dressing groups (biome mixes of crates with goods, sacks, lantern posts, a scavenger's wreck, rocks and dead trees,
  braziers, mesa slabs, fire barrels; grass and rubble fringes) kept or dropped whole. CONTENT_SCHEMA §5 "Shop rooms".
- **Sim.** `ShopRoom.furnish` (no draw) after `ShopPlacement.pick`, whose rule is unchanged (the same room, so arenas,
  routes, the Overrun room and the event rooms don't move): the room's old interior goes, the stall faces the room's
  first doorway (a quarter turn), the dressing follows the designed rooms' checks; `shop_pos` is the counter's
  centre, so buying and selling work exactly as before at the counter. SIM_CONTRACTS "Shop rooms".
  `FloorScenario.add_shop(w, shop, biome, map)`; `ShopTable.rooms`; `FloorLayout.shop_layout / shop_solids /
  shop_props`; `WorldReader.shop_stall / shop_piece* / shop_front`. When no spot fits, the room is untouched and the
  terminal stands (none in the test's 120 floors; one in 30 other floors probed during the step, a 12.8 × 8.9 m room
  whose reward stood in the walk-up lane; the test bounds it at 3 %).
- **Saves.** `RunState.FLOOR_RULES` 4 → 5 (`FLOOR_RULES_V080_RT` = 4); a floor saved under rules 1-4 is rebuilt with
  its terminal (`RunState.shop_rooms`, `RunSaver.floor_tables` leaves `ShopTable.rooms` empty), so its snapshot fits.
  Nothing new is hashed or saved. **Merge note:** RT2 may bump `FLOOR_RULES` too; the lead orders the two.
- **Presentation.** `ShopStallView` (the stall, the lantern's warm light, goods, sacks, lantern posts with lights),
  `ShopVendor` (five code-made vendors: Ruins scavenger with goggles and a junk backpack 1.6 m, Night Rocks lantern
  hermit 1.7 m, Red Canyon trader with a wide hat 1.7 m, Frozen Shore fur-wrapped fisher with a hook pole 1.7 m,
  Starfall floating astral merchant with orbiting crystals 1.8 m): breathes, looks round, turns to you within 7 m (up
  to ±77°), nods on a sale, shakes its head on a refusal; reduced motion: no idle motion, an instant turn, a glow
  (warm / red) instead of the nod and the shake. `ShopModels`: a model listed in the manifest replaces its stand-in.
  `WorldViewRoot` draws the stall when the floor has one, else the terminal.
- **The owner's model (delivered during the step).** The desert merchant stall (a Tripo file: one mesh, no rig,
  10,558 triangles) is installed as `assets/models/shop/shop_tent.glb` (manifest with sha256; credits rebuilt). Its
  connected pieces: the main body (9,282 triangles), a pole (194), three tiny bits (140, 134, 20) and a loose crate
  pile (788) in front of one end of the counter; `scripts/art/shop_stall.py` leaves the crate pile out (it stood in
  the walk-up lane) and centres the rest. **The vendor is fused into the main body** (shot `stall_pieces_front.png`:
  every piece in its own colour, the vendor grey with the body), so it can't be cut out to move: the code vendor is
  hidden over this stall (it still runs) and the stall's lantern shows the reactions (×1.6 brighter on a sale, red on a
  refusal). It is the stall in every biome until their own arrive; no biome tint (the presentation has no tint for
  owner models). In game: 2.55 m to the awnings, 4.0 m across, 3.3 m front to back, front +X as delivered.
- **Shop refusals in real play:** the shop panel disables an action the shop would refuse, so a refusal reaches the
  vendor only when the sim refuses one (the head shake and the red lantern are proved on the sim's refusal in the unit
  tests; the e2e proves the walk-up, the turn and the nod through real input).

## Commands and raw output

### Source scripts
```
$ python3 -I scripts/content/shop_rooms.py .
== shop_ruins groups 17 solids 38 drawn 108 slits []
== shop_night_rocks groups 17 solids 40 drawn 88 slits []
== shop_red_canyon groups 17 solids 39 drawn 109 slits []
== shop_frozen_shore groups 17 solids 40 drawn 96 slits []
== shop_starfall groups 17 solids 39 drawn 85 slits []
```
The raw stall is `unprocessed_images/shop/shop_stall_desert_raw.glb` at `32f3424` (sha256 `722d05d0…c6f9`, the same
bytes as the copy the script read: `git show 32f3424:unprocessed_images/shop/shop_stall_desert_raw.glb | sha256sum`
and `sha256sum` of the copy both print `722d05d0b96f168e9295705cc8ac485e4e3ea303c71e7e239e3110f18ec7c6f9`):
```
$ python3 -I scripts/art/shop_stall.py <the raw stall> assets/models/shop/shop_tent.glb
piece:    20 tris  min [0.017, 0.232, 0.449]  max [0.026, 0.251, 0.457]
piece:   194 tris  min [-0.013, -0.079, 0.402]  max [0.044, 0.295, 0.498]
piece:   134 tris  min [0.073, -0.171, -0.373]  max [0.081, -0.156, -0.355]
piece:   140 tris  min [0.071, -0.206, -0.375]  max [0.085, -0.185, -0.353]
piece:  9282 tris  min [-0.498, -0.318, -0.488]  max [0.33, 0.318, 0.5]
piece:   788 tris  min [0.304, -0.295, -0.5]  max [0.498, -0.062, -0.298]  <- left out
kept: 9770 tris, size (x front-to-back, y height, z across) [0.8278, 0.636, 0.9883]
wrote assets/models/shop/shop_tent.glb 7252860 bytes
$ sha256sum assets/models/shop/shop_tent.glb
dc4fdbc02b69c1fdba3986b3cbf0a92ab030a81aca7274df8ed8bb71a6a48b57  assets/models/shop/shop_tent.glb
```
(run twice; the second run into `build/` wrote the same hash.)
```
$ godot --headless --path . -s scripts/content/build_credits.gd
wrote res://data/credits/licences.tres (4 entries)
```

### Tests
Lint:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
876 files would be left unchanged
Success: no problems found
```
`tests/content` (new `test_shop_room_validation.gd` 4; `test_model_manifest.gd` now checks `assets/models/shop`):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Totals
------
Scripts              25
Tests               125
Passing Tests       125
Asserts            8337
Time              21.638s
```
(`test_model_manifest.gd` was reformatted by gdformat after this run: one line wrapped, no change in what it runs.)

`tests/arch` + `tests/golden` (goldens unchanged):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
Totals
------
Scripts               3
Tests                 6
Passing Tests         6
Asserts           10118
Time              8.986s
```
The map, generator and shop sim tests by name (new `test_shop_rooms.gd`: every biome's room, same seed same room, only
the shop room changes, the property test over 120 run floors in all five biomes, as Main builds it the counter is the
shop, no shop room means the terminal):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_shop_rooms.gd,res://tests/unit/sim/test_shop_placement.gd,res://tests/unit/sim/test_shop.gd,res://tests/unit/sim/test_room_layouts.gd,res://tests/unit/sim/test_floor_generator.gd,res://tests/unit/sim/test_room_themes.gd,res://tests/unit/sim/test_boss_room_builder.gd,res://tests/unit/sim/test_arenas.gd,res://tests/unit/sim/test_overrun.gd,res://tests/unit/sim/test_routes.gd,res://tests/unit/sim/test_event_rooms.gd,res://tests/unit/sim/test_ice_patches.gd,res://tests/unit/sim/test_starglow_patches.gd,res://tests/unit/sim/test_run_flow.gd,res://tests/unit/sim/test_ascension.gd -gexit
res://tests/unit/sim/test_shop_rooms.gd
    shop rooms: 120 floors, 0 stalls failed, 9 room footprints, 1788 shop pieces, 62662 ms
6/6 passed.
res://tests/unit/sim/test_shop_placement.gd
5/5 passed.
res://tests/unit/sim/test_shop.gd
19/19 passed.
res://tests/unit/sim/test_room_layouts.gd
    designed rooms: 157 of 675 rooms over 40 floors; 7549 of 9679 layout blockers kept (78%)
5/5 passed.
res://tests/unit/sim/test_floor_generator.gd
10/10 passed.
res://tests/unit/sim/test_room_themes.gd
3/3 passed.
res://tests/unit/sim/test_boss_room_builder.gd
4/4 passed.
res://tests/unit/sim/test_arenas.gd
14/14 passed.
res://tests/unit/sim/test_overrun.gd
7/7 passed.
res://tests/unit/sim/test_routes.gd
12/12 passed.
res://tests/unit/sim/test_event_rooms.gd
3/3 passed.
res://tests/unit/sim/test_ice_patches.gd
6/6 passed.
res://tests/unit/sim/test_starglow_patches.gd
6/6 passed.
res://tests/unit/sim/test_run_flow.gd
18/18 passed.
res://tests/unit/sim/test_ascension.gd
13/13 passed.
Totals
------
Scripts              15
Tests               131
Passing Tests       131
Asserts           1851043
Time              3631.781s
```
(slow: the machine was shared with the shot renders and other agents.)

`tests/unit/application` (saves; new `test_a_save_from_before_the_shop_rooms_keeps_its_terminal`) and
`tests/unit/debug` (the dev panel's folder list gains `shop_rooms`):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/application,res://tests/unit/debug -ginclude_subdirs -gexit
Totals
------
Warnings              1
Scripts              15
Tests               105
Passing Tests       105
Asserts            1088
Time              68.662s
```
(the warning is a save test's deliberately damaged file.)

Presentation (new `test_shop_stall_view.gd` 6: every biome's stall and vendor, the turn to you, the nod and the shake,
idle and reduced motion, the owner's stall as the tent with its fused vendor and the lantern's reactions, the model
hook with a test manifest):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_shop_views.gd,res://tests/unit/presentation/test_shop_stall_view.gd,res://tests/unit/presentation/test_stage_dresser.gd -gexit
Totals
------
Scripts               3
Tests                16
Passing Tests        16
Asserts           1620754
Time              51.783s
```
e2e (`test_e2e_shop.gd` now: the shop is the biome's stall, no terminal; walk up to the counter with the stick, the
vendor turned to you, E opens, buy with the keyboard, the vendor nods; salvage with the pad):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_shop.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_old_save.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_designed_rooms.gd -gexit
res://tests/e2e/test_e2e_shop.gd
3/3 passed.
res://tests/e2e/test_e2e_saves.gd
2/2 passed.
res://tests/e2e/test_e2e_old_save.gd
1/1 passed.
res://tests/e2e/test_e2e_run_flow.gd
3/3 passed.
res://tests/e2e/test_e2e_designed_rooms.gd
1/1 passed.
Totals
------
Scripts               5
Tests                10
Passing Tests        10
Asserts             167
Time              124.551s
---- All tests passed! ----
```
Not run locally: the full suite (CLAUDE.md: once per version, on GitHub), the rest of the e2e shard.

### Shots
One biome at a time:
```
$ XDG_DATA_HOME=<empty dir> timeout 2400 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/shop_rooms.gd -- biome=<biome>
```
Raw log lines (`build/sr/logs/shots_<biome>.txt`; engine warnings left out: the Compatibility renderer has no SSIL):
```
OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
shop_rooms: shop_red_canyon floor=1 room=9 cells=(2, 1) size=26.5x9.8 m layout=shop_red_canyon counter=(-14.75, 13.18) facing=0 shop_pieces=13
shop_rooms: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=red_canyon seed=20261015
shop_rooms: res://build/shots/v0.8.0/sr/shop_red_canyon_room.png
shop_rooms: res://build/shots/v0.8.0/sr/shop_red_canyon_close.png
shop_rooms: shop_frozen_shore floor=1 room=9 cells=(2, 1) size=26.5x9.8 m layout=shop_frozen_shore counter=(-14.75, 13.18) facing=0 shop_pieces=14
shop_rooms: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=frozen_shore seed=20261015
shop_rooms: res://build/shots/v0.8.0/sr/shop_frozen_shore_room.png
shop_rooms: res://build/shots/v0.8.0/sr/shop_frozen_shore_close.png
shop_rooms: shop_ruins floor=1 room=9 cells=(2, 1) size=26.5x9.8 m layout=shop_ruins counter=(-14.75, 13.18) facing=0 shop_pieces=15
shop_rooms: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=ruins seed=20261015
shop_rooms: res://build/shots/v0.8.0/sr/shop_ruins_room.png
shop_rooms: res://build/shots/v0.8.0/sr/shop_ruins_close.png
shop_rooms: shop_night_rocks floor=1 room=9 cells=(2, 1) size=26.5x9.8 m layout=shop_night_rocks counter=(-14.75, 13.18) facing=0 shop_pieces=12 tent=owner model
shop_rooms: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=night_rocks seed=20261015
shop_rooms: res://build/shots/v0.8.0/sr/shop_night_rocks_room.png
shop_rooms: res://build/shots/v0.8.0/sr/shop_night_rocks_close.png
shop_rooms: shop_starfall floor=1 room=9 cells=(2, 1) size=26.5x9.8 m layout=shop_starfall counter=(-14.75, 13.18) facing=0 shop_pieces=12 tent=owner model
shop_rooms: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=starfall seed=20261015
shop_rooms: res://build/shots/v0.8.0/sr/shop_starfall_room.png
shop_rooms: res://build/shots/v0.8.0/sr/shop_starfall_close.png
```
(the `tent=` field was added to the log line while the batch ran; the first three runs are the same build otherwise,
all with the owner's stall.)
The code stand-ins (no model read: `-- biome=starfall standins`):
```
shop_rooms: shop_starfall_standin floor=1 room=9 cells=(2, 1) size=26.5x9.8 m layout=shop_starfall counter=(-14.75, 13.18) facing=0 shop_pieces=12 tent=stand-in
shop_rooms: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080) biome=starfall seed=20261015
shop_rooms: res://build/shots/v0.8.0/sr/shop_starfall_standin_room.png
shop_rooms: res://build/shots/v0.8.0/sr/shop_starfall_standin_close.png
```
A second stand-in run (`biome=ruins standins`) was stopped by the agent before it wrote a shot, to free the shared
machine; no ruins stand-in shot is claimed. An earlier Ruins stand-in render (an older build of this step: the 3.0 ×
2.2 m stall before the owner's model arrived) is not kept as evidence.

SHOT CHOICE (labelled, also in the script's header): the first run seed from 20261014 whose floor-1 shop room is at
least 2 cells (20261015, a 2×1 room 26.5 × 9.8 m), the same room for every biome, its shop room furnished as the
named biome's. SHOT STAGING (labelled): the player is put at the counter's front (the walk there is the e2e's). The
world is never stepped.

| Shot | What it shows |
|---|---|
| [`sr_shots/shop_red_canyon_room.png`](sr_shots/shop_red_canyon_room.png) | Red Canyon: the shop room with the owner's stall |
| [`sr_shots/shop_red_canyon_close.png`](sr_shots/shop_red_canyon_close.png) | the same, closer: the counter, its hooded vendor, the lanterns |
| [`sr_shots/shop_frozen_shore_room.png`](sr_shots/shop_frozen_shore_room.png) | Frozen Shore, the same stall in another biome |
| [`sr_shots/shop_frozen_shore_close.png`](sr_shots/shop_frozen_shore_close.png) | Frozen Shore, closer |
| [`sr_shots/shop_ruins_close.png`](sr_shots/shop_ruins_close.png), [`…night_rocks_close`](sr_shots/shop_night_rocks_close.png), [`…starfall_close`](sr_shots/shop_starfall_close.png) | the other three biomes, closer |
| [`sr_shots/shop_starfall_standin_close.png`](sr_shots/shop_starfall_standin_close.png) | the code stand-in tent in Starfall (what a biome without a stall model would draw); its dark astral merchant does not read behind the counter at this distance |
| [`sr_shots/stall_pieces_front.png`](sr_shots/stall_pieces_front.png) | not a game shot: the raw stall from its front, each connected piece in its own colour (`python3 -I scripts/art/shop_stall_pieces.py <the raw stall> <png>`, a Python/PIL flat render): the vendor is part of the grey main body; the red crate pile is the piece left out |

The other `_room` shots are in `build/shots/v0.8.0/sr/` (not copied, to keep the evidence small).

## What the agent sees in the shots (not the owner's judgement)
- The owner's stall reads clearly from the iso camera: awning, poles, counter with goods, the hooded vendor with
  glowing eyes behind it, lanterns lit; the player stands at the counter.
- In this 2×1 room only part of the dressing stands (the room is 9.8 m deep, the stall 3.4 m and its walk-up 3 m);
  larger shop rooms keep more of it (the property test's 120 floors: 1,788 shop pieces).
- The stall's own colours are the same in every biome (no tint), so it reads warm and red in Frozen Shore and Starfall.
- The stand-in tent reads as a stall, but the Starfall stand-in vendor (dark cloak) is not visible behind the counter
  in the close shot; the stand-in vendors show only where no stall model is listed (none today).

## Not done here
- Vendors and goods as models of their own (`shop_vendor_<biome>`, `shop_wares`): stand-ins until they arrive.
- A tint of the stall per biome; biome-specific stalls.
- Look and feel on the owner's PC: **OWNER ONLY**.

## The damage soak's node-count failure after SR (agent `v080-leak`, 2026-10-14) — not a leak: the stall's size per floor

Build: `5bd7616` (branch `claude/lucid-fermat-9wv2tf`, which holds the failing merge `d476908`), Godot 4.7.2.

The seams on `d476908` failed `tests/e2e/test_e2e_damage_soak.gd`: `[136] expected to be < than [135]: after 2 deaths the
node count (1495) is back near the first fight's (1359)`. The soak counts every node outside `main.view.stage`; SR's
`ShopStallView` is a child of `WorldViewRoot`, outside the stage, so the stall's nodes count, and they vary per floor
with how many dressing groups the shop room keeps (stand-in wares, sacks and lantern posts; only `shop_tent` is a model).

**Temporary diagnostic (not committed)**: a copy of the soak with `DEATHS := 4`, printing after fight 1 and after each
restart the nodes outside the stage, each `WorldViewRoot` child's subtree size, the reader's shop room and
`shop_piece_count()`:

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/tmp_diag_soak.gd -gexit
DIAG fight 1:       total=5357 outside_stage=1363 stall=true pieces=8  layout=shop_night_rocks  ShopStall=39
DIAG after death 1: total=6627 outside_stage=1463 stall=true pieces=15 layout=shop_red_canyon   ShopStall=103
DIAG after death 2: total=6388 outside_stage=1499 stall=true pieces=22 layout=shop_night_rocks  ShopStall=149
DIAG after death 3: total=6351 outside_stage=1544 stall=true pieces=25 layout=shop_starfall     ShopStall=187
DIAG after death 4: total=7778 outside_stage=1532 stall=true pieces=26 layout=shop_ruins        ShopStall=187
```

(Excerpt of the DIAG lines; the other view children are equal across the five rows except Rewards 139/167/153/153/153,
Arenas 22/29/22/29/28, EventPedestals 14/14/25/25/14; main's Audio 8 then 9; UI 393 throughout.) Outside the stage
minus the stall: 1324, 1360, 1350, 1357, 1345. The total doesn't accumulate (the stage dominates it), and the orphan
check stays at 0. The stall's count follows the sim's `shop_piece_count`, which is the floor's.

**History-free per seed** (temporary test, not committed): floor 1 of seeds 1–12 built with `SaveLab.floor_world`, then
again in reverse order, each with a fresh `ShopStallView` counted and freed:

```
SEED 12: first [&"shop_starfall", 26, 187] again [&"shop_starfall", 26, 187]
SEED 11: first [&"shop_red_canyon", 20, 153] again [&"shop_red_canyon", 20, 153]
SEED 10: first [&"shop_ruins", 10, 59] again [&"shop_ruins", 10, 59]
SEED 9: first [&"shop_ruins", 22, 162] again [&"shop_ruins", 22, 162]
SEED 8: first [&"shop_frozen_shore", 14, 86] again [&"shop_frozen_shore", 14, 86]
SEED 7: first [&"shop_ruins", 15, 105] again [&"shop_ruins", 15, 105]
SEED 6: first [&"shop_ruins", 6, 25] again [&"shop_ruins", 6, 25]
SEED 5: first [&"shop_night_rocks", 6, 25] again [&"shop_night_rocks", 6, 25]
SEED 4: first [&"shop_starfall", 14, 93] again [&"shop_starfall", 14, 93]
SEED 3: first [&"shop_red_canyon", 28, 218] again [&"shop_red_canyon", 28, 218]
SEED 2: first [&"shop_frozen_shore", 6, 25] again [&"shop_frozen_shore", 6, 25]
SEED 1: first [&"shop_night_rocks", 15, 100] again [&"shop_night_rocks", 15, 100]
Passing Tests         1
```

The stall alone spans 25–218 nodes across 12 floors; the soak's bound is 10% of ~1360 (135). The soak itself, unchanged,
three runs (deterministic):

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_damage_soak.gd -gexit
run 1: soak: 2 deaths, 42 hits, 6005 frames; nodes 1363 -> 1499   [Failed]: [136] expected to be < than [136]
run 2: soak: 2 deaths, 42 hits, 6005 frames; nodes 1363 -> 1499   [Failed]: [136] expected to be < than [136]
run 3: soak: 2 deaths, 42 hits, 6005 frames; nodes 1363 -> 1499   [Failed]: [136] expected to be < than [136]
```

`test_e2e_shop.gd`: 3/3 passing (68 asserts). `test_e2e_run_flow.gd`: 3/3 passing (56 asserts). Lint: `gdformat --check`
902 files unchanged, `gdlint` no problems. No code changed; the bound is untouched. Open for the lead and the owner: how
the soak should treat the shop stall (e.g. exclude it as the stage is excluded, or a fixed seed) — **NOT YET DECIDED**.

**Decided by the lead (2026-10-14):** the soak leaves the shop stall's nodes out of its leak count, the rule it already
applies to the stage (floor dressing that changes with each floor). Everything else is still counted. After the change,
`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_damage_soak.gd -gexit`,
twice: `soak: 2 deaths, 42 hits, 6005 frames; nodes 1324 -> 1350`, Passing Tests 1 (both runs).
