# MINIMAP_CACHE: the minimap's rooms, doors and icons drawn once per change (W3-V3, 2026-11-06)

Why: [DRAW_GROWTH](DRAW_GROWTH.md). Each room found added about 470 drawn objects to every frame, and by the end of a
floor the corner minimap was 85 to 88 % of the frame's objects. Owner V4: "Yes" to drawing it into a texture.

## What changed

- `src/presentation/hud/minimap_view.gd`:
  - The static part of the map goes into a texture, a `SubViewport` rendered with `UPDATE_ONCE`. That part is the
    rooms, the doors, the icons and, on the full map, the backdrop, the panel and the legend.
  - The texture is rendered again only when one of these changes: `MinimapState.revision`, the view's size, its
    screen scale, or the language.
  - Each frame the view draws the texture (one object), the hero's arrow and the corner ticks.
  - The corner scrolls the texture under the hero.
- **Pixel density.** The texture is rendered at the screen's own density: the window's stretch scale times the
  parents' scales. It is placed on whole screen pixels and drawn with nearest filtering, so it is never scaled or
  blurred. That holds at the 1920 × 1080 base and at 1600 × 900 (stretch 0.833); both are shot below.
  - The corner texture covers every room of the floor, hidden ones included, so its size stays fixed for the floor.
    A 48 px margin around the rooms holds the stubs, glows and icons.
  - A floor bigger than 8192 px on either side falls back to the old direct draw. So does a corner panel, which is
    off (`MinimapStyle.CORNER_PANEL = false`).
- **Compositing.** The texture holds premultiplied colour, which is what Godot's 2D mix blend leaves in a transparent
  viewport. It is drawn with a `BLEND_MODE_PREMULT_ALPHA` material, so it composites as the shapes did when they were
  drawn straight onto the screen. Only 8-bit rounding remains (≤ 2/255, below).
- **Sub-pixel placement.** The texture is rendered at the sub-pixel phase the map had at that moment.
  - While the hero stands where the layer was last rendered, the map sits exactly where the direct draw put it.
  - While the hero walks, the map is up to half a screen pixel from where the direct draw would put it. The hero's
    arrow stays exactly at the window's centre. The old view also redrew only when the hero's rounded map pixel
    changed, so it lagged by a similar amount.
- **Draw order on the full map.** The legend now draws under the hero's arrow (before, it drew over it). They never
  overlap: the legend sits 40 px right of the floor's rectangle.
- `src/presentation/hud/minimap_state.gd`: the revision now also grows when any of these change:
  - the Overrun is cleared;
  - an event is spent;
  - the Deep gate opens;
  - the shrine site comes or goes;
  - Astral's secrets are found.

  The icons show these. Before, they reached the screen on the hero's next pixel, because the view redrew anyway.
  With a cached layer they need a revision of their own.
- `scripts/checks/draw_growth.gd`: the node census adds what `MinimapState` holds (rooms held, hidden rooms,
  revision) and the corner layer's renders.
- `scripts/shots/minimap_cache.gd` (new): the before/after shots, the sheet and the pixel diff.
- `tests/unit/presentation/test_minimap.gd`: a new test. The layer renders once for the floor, not on the hero's
  steps, and once again when a room is found.
- Presentation only (EI-07): no sim change, no golden change.

Build: `87fba9c6` plus this step's changes, uncommitted when it ran (the reports' `sha=` reads HEAD, which was
`87fba9c6`). Committed as the W3-V3 commit on `v0105-minimap`.
Machine: the owner's PC (i7-10700K, RTX 3060). Counts only; nothing is timed. Frame time: `NOT YET RUN (owner hardware)`.

`G=C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`, with
`APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-minimap` (the tests: `appdata-minimap/tests`).

## draw_growth: before and after (seed 4404, red_canyon, 3 floors, dwell 240)

```
"$G" --headless --path . --editor --import --quit
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed \
  -s scripts/checks/draw_growth.gd -- --biome=red_canyon --floors=3 --dwell=240 --tag=v3before   # src/ stashed
→ build/perf/draw_growth_red_canyon_v3before.txt; exit 0
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed \
  -s scripts/checks/draw_growth.gd -- --biome=red_canyon --floors=3 --dwell=240 --tag=v3after
→ build/perf/draw_growth_red_canyon_v3after.txt; exit 0
```

Both runs printed the census tool's own 2 `SCRIPT ERROR: Trying to assign invalid previously freed instance.` at
`draw_census.gd:432`, as DRAW_GROWTH noted. That error is in the existing tool, before and after alike.

Raw rows, verbatim. The `hud: Minimap` rows are what hiding the minimap removes. The other rows are everything shown.

Before (`v3before.txt`):
```
checkpoint                                       f10%    f125%    f150%    f175%   f1100%     f20%    f225%    f250%    f275%   f2100%     f30%    f325%    f350%    f375%   f3100%
objects (total)                                  1352     3443     3830     4943     5867     1443     2749     4770     5387     6563     1255     3803     5280     6380     7525
draws (total)                                     357      400      402      423      433      397      458      520      527      573      321      371      414      432      448
cv_obj (2D canvas)                               1195     3279     3666     4779     5703     1120     2402     4369     5006     6150     1131     3672     5122     6223     7367
cv_dc (2D canvas)                                 212      248      250      271      281      203      241      279      275      290      207      254      266      285      300
objects:  hud: Minimap                            486     2502     2946     4042     4966      486     1577     3379     4257     5401      486     2943     4469     5566     6710
draws:    hud: Minimap                             36       63       74       95      105       36       52       80       95      110       36       74       95      114      129
prims:    hud: Minimap                            713     2754     3459     4878     5808      713     1882     3944     5029     6245      713     3439     5168     6473     7691
minimap: corner redraws so far                      2      134      244      507      549        2      202      552      964     1311       24       86      448      804      810
```

After (`v3after.txt`):
```
checkpoint                                       f10%    f125%    f150%    f175%   f1100%     f20%    f225%    f250%    f275%   f2100%     f30%    f325%    f350%    f375%   f3100%
objects (total)                                   917      992      932      952      952     1008     1220     1439     1178     1213      817      908      859      865      866
draws (total)                                     352      368      359      359      359      392      437      471      463      494      316      328      350      349      350
cv_obj (2D canvas)                                760      828      768      788      788      685      873     1038      797      800      693      777      701      708      708
cv_dc (2D canvas)                                 207      216      207      207      207      198      220      230      211      211      202      211      202      202      202
objects:  hud: Minimap                             51       51       51       51       51       51       51       51       51       51       51       51       51       51       51
draws:    hud: Minimap                             31       31       31       31       31       31       31       31       31       31       31       31       31       31       31
prims:    hud: Minimap                            276      276      276      276      276      276      276      276      276      276      276      276      276      276      276
minimap: corner layer renders so far                2        8       13       19       22        2        6       14       21       28        2        6       16       24       28
minimap: corner redraws so far                      2      134      234      453      496        2      102      362      734     1081        2       64      387      787      793
```

- **The minimap's objects are flat at 51 at every checkpoint.** Before, they were 486 on arrival and 4,966 / 5,401 /
  6,710 at 100 % on floors 1 to 3.
- **Its draw calls are flat at 31.** Before, they were 36 on arrival and 105 / 110 / 129 at 100 %.
- **The frame's objects at 100 %** went from 5,867 / 6,563 / 7,525 to 952 / 1,213 / 866 (−84 %, −82 %, −88 %).
- **The layer was rendered 22 / 28 / 28 times on each floor**, about once per revision. The view itself still redrew
  496 / 1,081 / 793 times, now just the arrow and the texture's place.
- Read point by point, the "everything shown" rows after the change still move by tens to a few hundred objects:
  - 992 → 932 on floor 1;
  - 1,008 → 1,439 → 1,213 on floor 2.

  These rows are a median of readings that include enemies, drops and other things near the start room, as
  DRAW_GROWTH says. The minimap's own row is exactly flat.
- Not measured: the frame the layer renders again. A SubViewport's render is not in the root viewport's
  `viewport_get_render_info`, which these rows read. It happens once per revision, not per frame.

## Shots: before / after / diff (floor 3, the start room's centre)

```
git stash push -- src/
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed \
  -s scripts/shots/minimap_cache.gd -- --tag=before --floor=3                   # exit 0
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1600x900 --windowed \
  -s scripts/shots/minimap_cache.gd -- --tag=before_1600 --floor=3              # exit 0
git stash pop
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed \
  -s scripts/shots/minimap_cache.gd -- --tag=after --floor=3                    # exit 0
"$G" --path . ... --resolution 1920x1080 ... -- --tag=after2 --floor=3          # a second "after" run: the noise floor
"$G" --path . ... --resolution 1600x900  ... -- --tag=after_1600 --floor=3
"$G" --headless --path . -s scripts/shots/minimap_cache.gd -- --sheet --a=before --b=after
"$G" --headless --path . -s scripts/shots/minimap_cache.gd -- --sheet --a=before_1600 --b=after_1600
"$G" --headless --path . -s scripts/shots/minimap_cache.gd -- --sheet --a=after --b=after2
```

Sheets (untracked, under `build/`):
- `build/shots/v0.10.5/minimap/sheet_before_vs_after.png`
- `build/shots/v0.10.5/minimap/sheet_before_1600_vs_after_1600.png`

Each row is before | after | |difference| × 8. The rows are arrival, all rooms known and the full map, each in two
versions:
- `iso`: the minimap alone, with the world view and the HUD's other parts hidden;
- `scene`: as the game shows it.

Shot helpers, labelled in the script: the hero is placed, the sim paused, every room marked known in the minimap's
own state, and the map action pressed with `Input.action_press`.

Raw diff lines, verbatim. "differ" counts pixels with any channel off by at least 1/255:
```
before vs after (1920 x 1080):
minimap_cache: diff arrival_iso: 348 x 348 px, 25322 differ, 0 by more than 2/255 (within [P: (0, 0), S: (0, 0)]), largest 2/255
minimap_cache: diff arrival_scene: 348 x 348 px, 23442 differ, 110 by more than 2/255 (within [P: (107, 0), S: (240, 262)]), largest 66/255
minimap_cache: diff all_iso: 348 x 348 px, 31287 differ, 0 by more than 2/255 (within [P: (0, 0), S: (0, 0)]), largest 2/255
minimap_cache: diff all_scene: 348 x 348 px, 29971 differ, 73 by more than 2/255 (within [P: (107, 0), S: (240, 262)]), largest 65/255
minimap_cache: diff full_iso: 1920 x 1080 px, 1801692 differ, 0 by more than 2/255 (within [P: (0, 0), S: (0, 0)]), largest 2/255
minimap_cache: diff full_scene: 1920 x 1080 px, 916826 differ, 545 by more than 2/255 (within [P: (29, 0), S: (1889, 713)]), largest 30/255
before_1600 vs after_1600 (stretch 0.833):
minimap_cache: diff arrival_iso: 298 x 298 px, 17520 differ, 5 by more than 2/255 (within [P: (50, 146), S: (202, 26)]), largest 3/255
minimap_cache: diff arrival_scene: 298 x 298 px, 16699 differ, 132 by more than 2/255 (within [P: (98, 0), S: (198, 211)]), largest 51/255
minimap_cache: diff all_iso: 298 x 298 px, 21668 differ, 5 by more than 2/255 (within [P: (50, 146), S: (202, 26)]), largest 3/255
minimap_cache: diff all_scene: 298 x 298 px, 19900 differ, 85 by more than 2/255 (within [P: (98, 0), S: (198, 212)]), largest 56/255
minimap_cache: diff full_iso: 1600 x 900 px, 1250245 differ, 0 by more than 2/255 (within [P: (0, 0), S: (0, 0)]), largest 2/255
minimap_cache: diff full_scene: 1600 x 900 px, 632636 differ, 206 by more than 2/255 (within [P: (233, 0), S: (1365, 858)]), largest 21/255
after vs after2 (the same code twice: the noise floor):
minimap_cache: diff arrival_iso: 348 x 348 px, 0 differ, 0 by more than 2/255 (within [P: (0, 0), S: (0, 0)]), largest 0/255
minimap_cache: diff arrival_scene: 348 x 348 px, 772 differ, 106 by more than 2/255 (within [P: (81, 0), S: (266, 347)]), largest 31/255
minimap_cache: diff all_iso: 348 x 348 px, 0 differ, 0 by more than 2/255 (within [P: (0, 0), S: (0, 0)]), largest 0/255
minimap_cache: diff all_scene: 348 x 348 px, 5636 differ, 60 by more than 2/255 (within [P: (81, 0), S: (266, 347)]), largest 38/255
minimap_cache: diff full_iso: 1920 x 1080 px, 0 differ, 0 by more than 2/255 (within [P: (0, 0), S: (0, 0)]), largest 0/255
minimap_cache: diff full_scene: 1920 x 1080 px, 7412 differ, 348 by more than 2/255 (within [P: (12, 0), S: (1904, 999)]), largest 30/255
```

What the diff shows:
- **The minimap alone (`iso`)** differs by at most 2/255 at 1920 × 1080, and at most 3/255 at 1600 × 900 (5 pixels).
  - Nothing moved, blurred or changed colour: rooms, doors, stubs, icons, glow, the legend's text, the arrow.
  - What remains is the 8-bit rounding of the intermediate texture. It shows as faint outlines in the × 8 diff
    column, and over the full map's dimmed backdrop as many pixels off by 1 or 2.
- **The `scene` versions** differ by up to 65/255 in 73 to 132 pixels. These sit in a band starting at the crop's top
  edge, which is the world under the map. The same code shot twice differs there too (up to 38/255, 60 to 348
  pixels): the 3D view's own frame-to-frame changes (particles, animated materials) while the sim is paused.
  - The before/after peak (65) is above the after/after peak (38), at the same spot under the map. That spot can't be
    told apart from world noise with these shots.
  - The `iso` pair, which has no world in it, is the evidence that the map itself is the same.
- Not shot: the sub-pixel offset of up to half a pixel while walking. It is a moving view, so a still shot can't
  show it. Also not shot: the Astral frame, other biomes, and a 4K (stretch 2) window.

## The tests

```
APPDATA=…/appdata-minimap/tests "$G" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/presentation/{test_minimap,test_minimap_orientation,test_hud_perf_marks,test_hud_style,
  test_shop_views,test_affinity_runes,test_timed_door_view,test_rune_alignment_view,test_breakables_view}.gd -gexit
Totals
Tests                54
Passing Tests        54
Asserts            1106
Time              83.038s

APPDATA=…/appdata-minimap/tests "$G" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/e2e/{test_e2e_minimap,test_e2e_curses,test_e2e_routes,test_e2e_saves,test_e2e_shop}.gd -gexit
Totals
Tests                11
Passing Tests        11
Asserts             194
Time              171.472s
```

(The comma list was passed in full; braces above only shorten it.) The unit run ended with 3 Godot `RID allocations
… leaked at exit` lines: font, shaped text and 4 dummy textures. They were not compared against a run without the
change. Lint: `gdformat --check` and `gdlint` were clean on the touched files.

## The lead's question: do later floors have more rooms, or does the map keep earlier floors?

**Later floors have more rooms, by design. Nothing carries over.**

- **The room count.** `data/map/floor.tres` (15 to 19 rooms) is not what a five-floor run uses.
  - `data/run/five_floors.tres` sets `rooms_min_by_floor = (9, 12, 14, 16, 18)` and
    `rooms_max_by_floor = (11, 14, 16, 18, 19)`.
  - `FloorShape.size_floor` (`src/sim/run/floor_shape.gd`) puts that range on each floor by its number within the
    loop. Loops reuse the same sizes.
  - This is the owner's v0.9.0 FV decision (Q24; LOCKED_DECISIONS, 2026-10-22, PD-03 changed): "about 10, 13, 15,
    17 and 19 rooms plus the boss room".
  - draw_growth's floor room counts match it: 11 / 13 / 15 here and 11 / 13 / 15 / 17 / 20 in DRAW_GROWTH. Each is
    the drawn range plus the boss room.
- **`MinimapState` on arrival holds exactly the current floor's rooms.**
  - It holds 11 / 13 / 15 entries on floors 1 / 2 / 3, equal to `floor_room_count`.
  - One room is discovered, and the revision is 1 (both runs above, "state rooms held", "rooms discovered",
    "state revision").
  - "state hidden rooms" is that floor's own secret room (1 on floor 2, 0 on floors 1 and 3).
  - `MinimapState.update` resets on every new floor key (seed, floor index, room count).
- **The view kept nothing either.** Before the change, the minimap drew 486 objects on arrival on every floor, the
  same figure each time. Anything kept from an earlier floor would have raised it.
- So the owner's end-of-floor climb (6,125 / 6,505 / 7,955 / 9,281 / 9,830) matches about 470 objects per room times the
  rooms each floor has. It went away with this step, because the minimap no longer grows with the rooms found.
