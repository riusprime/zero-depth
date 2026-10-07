# v0.3.0 MM — a minimap revealed as you enter rooms, and a full map on Tab / Select (evidence)

- **Status:** RUN (agent). Feel, readability on the owner's screen and "does it stop the going in circles":
  `OWNER ONLY`.
- **Build:** the working tree of this step on top of `177a45a` (branch `worktree-agent-a6a8123788db22044`), before
  it was committed. Godot `4.7.2.stable.official.ed1daf0bf`, Linux; renders on llvmpipe (software Vulkan) under
  xvfb.
- **Date:** 2026-10-07
- **Who ran it:** agent

## What was built (owner L30)
- **Discovery** (`src/presentation/hud/minimap_state.gd`, presentation-side; nothing is saved yet so nothing goes
  into the sim). Each tick it reads `WorldReader`: the player's position → room (`floor_room_of`). The start hall is
  known from the floor's first tick; a room becomes known the tick the player stands in its interior; standing in
  a doorway keeps the last room as the current one. A new floor (another seed / floor number / room count) starts
  the state over. A `revision` grows only when the picture changes (a room found, the current room changes, a
  reward taken or turning affordable, the portal opening, the boss door sealing).
- **Read-only accessors** appended to `WorldReader`: `floor_room_of`, `floor_start_room`, `floor_portal_room`,
  `floor_door_count`, `floor_door_rooms`, `floor_door_rect`, `floor_door_angle`, `floor_boss_door`. The file passed
  gdlint's 1000-line limit, so its header now also disables `max-file-lines` (it already disabled
  `max-public-methods`; the facade is wide on purpose).
- **Corner map** (`minimap_view.gd`, one Control, one `_draw()`): top right, under the shard counter (300 × 300 at
  the 1920 × 1080 base; the boss bar is centred and 640 wide, so they never meet). A window centred on you that
  scrolls with you at a fixed 5 px/m, clipped to its panel. Known rooms are filled dim grey with thin glowing
  outlines broken where their doorways open, the doorway passages drawn between rooms; the room you are in is
  cyan; you are a cyan arrow pointing where you face. **A doorway from a known room into one you haven't entered
  gets an amber arrow stub pointing into the unknown** — the "where haven't I been" cue; the boss door is a red bar
  with a red stub. Unknown rooms are not drawn. Icons in known rooms: altar (gold diamond), chest (orange block;
  a dim outline while you can't pay), the portal gate (grey ring sealed, blue ring + dot open). An altar or chest
  disappears when it is taken.
- **Orientation:** the map turns with the iso camera, so up on the map is up on screen and pushing the stick up
  moves your arrow up (a north-up map would put the world's axes at 45° to your controls). The vertical is
  squashed to 0.72 (the camera's true squash is about 0.58) so rooms keep a readable shape. Starting value.
- **Full map:** hold **Tab** (keyboard) or **Select / Back** (pad) — a new `map` action in `InputDefaults`, so the
  bindings store remaps it like the others. A large centred map of the whole floor (scale fitted to every room,
  known or not, so it never jumps as you explore; unknown rooms still hidden) with a legend and "Rooms found: n /
  total". Letting go returns the corner map. It decides nothing (EI-07).
- **Gamble shrine icon:** not drawn — the shrine (workstream EG) is not on this branch, so there is nothing to read.
  The icon set lives in `MinimapView.draw_icon`; adding one is a `match` arm plus a reader accessor.
- **Performance:** two Controls in all (corner, full), no node per room. A view redraws only when the state's
  revision changes, the player moves a pixel at its scale, the facing changes, or its size changes
  (`test_the_views_draw_once_per_change`).
- **Style in one place:** `src/presentation/hud/minimap_style.gd` holds every colour, width, size and scale (the
  HUD restyle can retheme it there). `hud_style.gd` (workstream UI) is not on this branch.
- **Strings:** `MAP_TITLE`, `MAP_LEGEND_*` (7), `MAP_ROOMS`, en + es.

## Starting values (all tuning defaults, not measurements)
| What | Value |
|---|---|
| Corner map size / position | 300 × 300 px, 84 px from the top, 28 px from the right (1920 × 1080 base) |
| Corner scale | 5.0 px per metre |
| Vertical squash | 0.72 |
| Unexplored stub | 5 m past the doorway, drawn 14–34 px, arrowhead 2 m (≤ 13.6 px) |
| Full map | up to 86 % of the screen, legend 400 px wide |
| Panel | rgba(0.02, 0.04, 0.07, 0.93), cyan edge at 35 % |

## Tests
New: `tests/unit/presentation/test_minimap.gd` (5) and `tests/e2e/test_e2e_minimap.gd` (1). The e2e boots
`main.tscn`, plays from the menu with Enter, checks only the hall is known and its one exit is flagged, walks
through it with the left stick (`Input.parse_input_event` only) until 2 m inside the next room, checks that room
(and only it) was revealed, then holds Tab (full map up, corner map hidden), lets go, and does the same with pad
Select.

```
$ bash scripts/verify.sh
[… import and per-test lines trimmed …]
res://tests/e2e/test_e2e_minimap.gd
* test_walking_into_a_room_reveals_it_and_tab_shows_the_full_map
1/1 passed.
[…]
res://tests/unit/presentation/test_minimap.gd
* test_the_start_hall_is_known_and_nothing_else
* test_entering_a_room_reveals_it_and_flags_its_doors
* test_reward_icons_show_in_known_rooms_and_leave_when_taken
* test_a_new_floor_starts_over
* test_the_views_draw_once_per_change
5/5 passed.
[…]
Totals
------
Scripts              89
Tests               488
Passing Tests       488
Asserts           402894
Time              283.944s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (488 passing, minimum 488)
```

```
$ gdformat --check src scripts tests && gdlint src scripts tests
277 files would be left unchanged
Success: no problems found
```

```
$ bash scripts/ci/export_smoke.sh
[… 8 lines trimmed …]
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
[…]
  ok    tests are not shipped
0 miss(es)
```
Goldens: none changed (no sim behaviour changed; the reader accessors only read).

## Renders
```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/minimap.gd -- lang=en
minimap: res://build/shots/v0.3.0/minimap/en/early.png (frame 73, tick 232, rooms 1/11)
minimap: heading for room 1
minimap: heading for room 3
minimap: res://build/shots/v0.3.0/minimap/en/mid.png (frame 201, tick 744, rooms 3/11)
minimap: heading for room 4
minimap: heading for room 7
minimap: heading for room 2
minimap: heading for room 9
minimap: heading for room 5
minimap: heading for room 6
minimap: res://build/shots/v0.3.0/minimap/en/late.png (frame 545, tick 2120, rooms 9/11)
minimap: full map showing = true
minimap: res://build/shots/v0.3.0/minimap/en/full.png (frame 550, tick 2140, rooms 9/11)
minimap: res://build/shots/v0.3.0/minimap/en/minimap_sheet.png 1200x1055
```
The script walks with the left stick only and holds Tab with a real key event. SHOT HELPER (labelled in the
script): it switches the dev panel's god mode on so the walk isn't cut short by a death; that changes nothing on
the map. The same run with `lang=es` was checked by eye: the Spanish legend fits its panel.

[`minimap.png`](minimap.png) (313 KB, a hand copy of `minimap_sheet.png`): top row, the corner map (top-right
crops at 1600 × 900) — at floor start (only the hall, its one exit an amber stub); after 3 rooms (an altar, a
chest you can't pay for yet, three stubs); after 9 rooms (the boss door in red with its red stub, beside you).
Bottom, the full map held on Tab at the same moment, with its legend.

## Interpretation
Proven here: discovery and the stubs follow the player's room as the sim reports it, icons follow the reward store
and the portal, the state resets per floor, and the full map is reachable from the real game by Tab and pad
Select. Not proven: that it stops the "going in circles" — that's the owner's playtest (`OWNER ONLY`). Open choices
for the owner: the iso-turned orientation versus a plain north-up grid, the corner scale (a fixed 5 px/m window
versus fitting the floor), and whether the "Rooms found: n / total" line gives away too much.
