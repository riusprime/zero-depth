# v0.3.0 Step A evidence: walls have thickness, blink by thickness vs range, more varied floors

Build: the working tree of the commit `v0.3.0 Step A: walls have thickness; blink crosses a wall only within range;
more varied floors` (parent `0c44b40`), Godot 4.7.2.stable.official.ed1daf0bf, Linux cloud container, headless.
Timings come from that container, not the owner's hardware.

Owner lines: L1 ("you can't just blink every single wall", Q4 "By thickness vs range") and L2 ("more randomness").

## What changed

- **Wall thickness.** Each room side draws its own *half* from 0.3–1.5 m (map stream): how far its face lies inside
  its grid line. A partition is the two halves beside it, so 0.6–3.0 m thick; an outer wall is its room's half on
  both sides of the grid line (0.6–3.0 m). Room interiors stay rectangles (each side pulled in by its own half), and
  grid lines lie `cell size + 1.8 m` apart, so a one-cell room's interior averages the cell size. A wall's
  thickness can change along its length where the room beside it changes. Note: "drawn per wall" is implemented
  as two halves per partition (a sum of two draws), not one uniform draw per wall; that is what keeps every room a
  rectangle.
- **Walls in the sim.** Every room is framed by four boxes from its faces out to its grid lines (the frames of
  neighbours meet at the line, so there is never a hole), plus an outer skin on each outer stretch. Doorways cut
  both frames, so a doorway is a passage through the full thickness (`FloorLayout.door_rect`, `door_depths`).
  Cover slabs and pillars stay thin (0.5 m slabs).
- **Doorways.** Width drawn per doorway from 2.2–3.4 m; position drawn anywhere along the stretch where both rooms'
  faces overlap, kept 0.6 m from either room's corners.
- **Cell size** drawn per floor: 11–14 m × 9–11 m.
- **Templates.** Existing ones draw parameters: pillars (spacing, size, square or stretched along x/y, checker by
  chance), centre (block or ring size, openings), cross (gap; outside the hall a 50 % chance one arm is left out,
  making a T turned any way), lines (count 2–3 in wide rooms, which lines start late, segment and gap lengths, way
  they run in near-square rooms), bunkers (depth, per-corner chance 65–90 %). Two new ones: **colonnade** (two rows
  of pillars along the long axis, inset and stagger drawn) and **diagonals** (slabs at 45°, mirrored, optional
  herringbone, on a staggered grid).
- **Blink.** Up to `blink_range_m` along the move (or aim) direction; it passes through a wall only when a free spot
  beyond the wall lies within range, else it ends at the last free spot before the wall. Free = the player's circle
  touches no wall (sealed gate included) and the spot lies in the NavField region the player walks in, so it never
  ends in a wall, in the void outside the floor, or in a sealed pocket. It may end in another room. (The previous
  "never outside the room" wording is dropped; the farthest-free-sample algorithm is unchanged.)
- **Stage.** Ground is drawn over the floor's footprint (`FloorLayout.ground` via `WorldReader.floor_ground`: each
  room's cells, so its thick walls and doorway passages, plus the outer skins), and over any room or structural
  wall the footprint doesn't enclose. Walls are drawn at their real thickness (unchanged code: boxes from the OBBs).

## Generation over 50 seeds, walls and doorways, blink cases

Command:

```bash
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

(run through `bash scripts/verify.sh`; lines from `build/gut.log`, raw):

```
    floor generation: 50 floors, mean 111.7 ms, max 269.6 ms, 11.14 rooms, 13.74 item spots, 49.2 interior pieces per floor; templates seen: bunkers, centre, colonnade, cross, diagonals, lines, open, pillars, scatter; footprints seen: 9
    nav field on 5 floors: mean 44181 cells, build 107.1 ms, flood 7.2 ms
    walls and doorways over 50 floors (576 doorways): wall thickness at doorways 0.72-2.96 m, door width 2.20-3.40 m, 418 doorways more than 1 m off the middle of the shared stretch; cell size x 11.00-13.97 m, y 9.01-10.95 m
    blink 5.0 m crosses a wall of thickness: 0.5 m: face <= 4.1 m; 0.6 m: face <= 4.0 m; 1.0 m: face <= 3.6 m; 1.5 m: face <= 3.1 m; 2.0 m: face <= 2.6 m; 2.5 m: face <= 2.1 m; 3.0 m: face <= 1.6 m
    blinks on floors: 3608, through a room wall 124, through cover only 428, stopped short 1140
```

Before this step (parent `0c44b40`, same container, `-gtest=res://tests/unit/sim/test_floor_generator.gd`):

```
    floor generation: 50 floors, mean 80.7 ms, max 135.2 ms, 10.96 rooms, 13.32 item spots, 40.8 interior pieces per floor; templates seen: bunkers, centre, cross, lines, open, pillars, scatter; footprints seen: 9
    nav field on 5 floors: mean 32988 cells, build 73.3 ms, flood 5.8 ms
```

Reading the numbers:

- Generation got slower: mean 80.7 → 111.7 ms, max 135.2 → 269.6 ms (more interior pieces per floor, 40.8 → 49.2,
  each tested for room wholeness). It runs once per floor, before play. The NavField grew (32 988 → 44 181 cells)
  because floors are larger on average (wider cells plus outer skins); its build is once per floor, its flood
  (every 10 ticks) went 5.8 → 7.2 ms.
- `test_fast_nav_field_matches_the_reference` still passes: the bounded build and adjacency flood equal the
  reference build and flood on a new floor (blocked cells, regions, distances).
- **Blink table:** the far side is reachable when face distance + thickness + 0.35 m (radius) ≤ 5.0 m. So with
  today's numbers a 3.0 m wall is crossed only from within 1.6 m of its face, a 0.5 m slab from up to 4.1 m.
  **Open for the owner:** pressed against any wall (face 0.36 m away), every wall up to 4.3 m thick is crossable, so
  every wall of 0.6–3.0 m can still be blinked from close up. The PLAN says "Blink range stays 4.5 m" but the data
  (`UtilityDefinition.blink_range_m` default, `data/utilities/blink.tres` doesn't override it) is 5.0 m; this step
  changed neither. Making thick walls uncrossable even from close up needs a shorter range or thicker walls: an
  owner tuning call.
- **Blinks on floors:** from every spawn point of seeds 3, 41 and 2026, 8 directions each: every landing was clear
  of every wall and the gate, in the start's NavField region, in a room or a doorway passage, within range and on
  its line (asserted). 124 went through a room wall, 428 through cover only, 1140 stopped short of a wall.

Blink unit tests (`tests/unit/sim/test_utility.gd`): crosses thin cover at normal range; stops at a 2.8 m wall whose
far side is out of range; crosses a 3.0 m wall from close up but not from 1.8 m away; the table above; never lands
in the void (arena outer wall); never lands in a sealed pocket; the floor sweep above; determinism (two runs of 600
ticks with blinks on floor 77 give the same hash and path).

## Top-down render (seeds 1, 2, 3)

Command:

```bash
godot --headless --path . -s scripts/shots/floor_map.gd -- 1 2 3
```

Raw output:

```
seed 1: cell 13.16 x 10.43 m, 11 rooms, 12 doorways, 86 walls, 61 interior pieces, 107.7 x 88.6 m, portal room 8 (4 hops), 12 item spots, 131 spawn points, generated in 191.4 ms
  rooms (cells): 3x3, 1x2, 2x1, 1x1, 1x1, 1x1, 2x3, 2x2, 1x1, 1x1, 3x1
  templates: cross, colonnade, lines, diagonals, centre, cross, centre, pillars, pillars, pillars, lines
  doorways (width x wall thickness, m): 3.26 x 1.96, 2.92 x 1.09, 2.35 x 1.80, 2.37 x 2.59, 2.23 x 1.91, 2.63 x 1.94, 2.93 x 2.52, 2.89 x 1.94, 3.38 x 2.49, 2.62 x 2.89, 2.80 x 2.73, 2.42 x 1.86
seed 2: cell 13.05 x 9.29 m, 12 rooms, 12 doorways, 97 walls, 53 interior pieces, 121.8 x 80.6 m, portal room 9 (5 hops), 16 item spots, 128 spawn points, generated in 111.5 ms
  rooms (cells): 3x3, 1x3, 2x1, 1x1, 2x1, 2x1, 1x1, 1x2, 1x1, 2x1, 2x2, 1x2
  templates: scatter, colonnade, scatter, open, bunkers, pillars, scatter, pillars, diagonals, diagonals, bunkers, centre
  doorways (width x wall thickness, m): 2.42 x 1.11, 2.78 x 1.29, 3.22 x 1.62, 2.54 x 1.88, 2.30 x 2.24, 2.43 x 2.36, 2.26 x 2.65, 3.34 x 1.41, 3.05 x 1.62, 3.31 x 1.80, 2.57 x 2.46, 3.26 x 2.06
seed 3: cell 13.85 x 10.41 m, 10 rooms, 11 doorways, 85 walls, 91 interior pieces, 112.6 x 100.7 m, portal room 5 (4 hops), 9 item spots, 143 spawn points, generated in 363.9 ms
  rooms (cells): 3x3, 1x2, 3x1, 1x1, 1x1, 1x2, 1x1, 2x1, 1x2, 3x3
  templates: diagonals, diagonals, lines, open, colonnade, colonnade, open, centre, centre, diagonals
  doorways (width x wall thickness, m): 3.22 x 2.79, 2.61 x 1.56, 3.18 x 1.89, 3.34 x 1.54, 3.09 x 2.90, 3.27 x 2.07, 2.73 x 1.98, 3.21 x 1.29, 2.60 x 2.12, 2.20 x 2.27, 2.23 x 1.83
floor tints: open = light grey, scatter = sand, pillars = blue, centre = pink, cross = green, lines = yellow, bunkers = teal, colonnade = salmon, diagonals = lavender
wrote res://build/floors/floor_layouts.png (2986x853): OK
```

`build/floors/floor_layouts.png` copied by hand to [`walls_floor_map.png`](walls_floor_map.png) (8 px per metre).
Key: dark grey walls at their real thickness, light-grey doorway passages through them, room floors tinted by
template, brown interior pieces, green start, yellow item spots, red spawn points, magenta gate and front square,
white 5 m bar (the blink range) under each floor.

## Goldens

Unchanged. The replay golden and the export-smoke world are the kernel arena with no utility, so neither the
map nor the blink change touches them:

```
$ godot --headless --path . -s tests/golden/generate_export_smoke_hash.gd
GOLD| export_smoke_hash=921997d9e01c215971c7def66deb8e6664cbb66739689b8bbe5a0475285e4234
```

(identical to `tests/golden/fixtures/export_smoke_hash.txt`; `git status` showed no change). The replay fixture
(final `c798f9e56d5435adf0789ec087874678600b02dbc614501638598e6be3a309df`) was not regenerated;
`test_replay_matches_every_checkpoint` passes against it.

## Verification

```
$ godot --headless --path . --editor --import --quit          # rc 0
$ gdformat --check src scripts tests && gdlint src scripts tests
197 files would be left unchanged
Success: no problems found
$ bash scripts/verify.sh
Tests               287
Passing Tests       287
---- All tests passed! ----
check_gut_log: ok (287 passing, minimum 279)
$ godot --headless --path . -s scripts/checks/hitch_probe.gd
hitch_probe: ticks after a 250 ms stall = 4 (limit 4, max seen 4), dash starts = 1 -> ok
```

`tests/MIN_TEST_COUNT` 279 → 287.

Owner fields (how blinking through walls feels, whether thick walls read as thick in the game view): OWNER ONLY.
