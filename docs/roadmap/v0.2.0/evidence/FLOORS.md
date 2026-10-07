# v0.2.0 floor generator evidence (v2: PLAN L14–L15, task I)

Build SHA: `c8575b6176a4042aad281a1553f992d46a4cca55` (branch `worktree-agent-a82f409ad9869ac61`), Godot 4.7.2,
Linux cloud container, headless. Timings come from that container, not the owner's hardware. The v1 evidence (a 3 × 3
grid of equal rooms) was at `40f99362`; it is replaced here.

## What a floor is now

- A **start hall** of 3 × 3 cells: one room with no partitions inside it. A cell is 12 × 10 m, so the hall is
  37.6 × 31.6 m. Its interior is one of scatter, pillars, centre (always a ring of four L corners around the start),
  cross, lines or bunkers. It is never open.
- The hall has **one exit**, on a side drawn from the map stream. Across 50 seeds all four sides occur (tested).
- **9–11 more rooms** (10–12 rooms in all). Footprints are drawn by weight from 1×1, 2×1, 1×2, 3×1, 1×3, 2×2, 3×2,
  2×3 and 3×3 (weights 30/14/14/8/8/10/5/5/3). Rooms are placed on the cell grid without overlap, and each one
  connects through a doorway to a room already placed, which makes a tree. Then 1–2 extra doorways join rooms that
  touch but aren't joined yet; the hall is never one of them. The whole floor fits in 8 × 8 cells and is centred
  on the origin.
- **Interior templates**, one per room, drawn by weight from the map stream. Weights depend on the room's shape:
  long 3×1 and 1×3 rooms favour lines. The seven templates are open, scatter (the v1 random slabs, 1–2 per cell),
  pillars (a grid, checkerboard in big rooms), centre (a block with a walkway, or a ring of L corners), cross (a
  broken cross with a centre gap), lines (staggered broken cover lines along the long axis) and bunkers (an L in
  each corner, some skipped). A piece or group is kept only if it stays inside the room, keeps clear of doorways,
  the start and the gate zone, keeps 2.2 m from every other wall, and leaves the room one region. So a template can
  lose pieces, but it never blocks a door or splits a room.
- **Items:** a 1×1 room gets exactly 1 spot. A bigger room gets 1 or 2: the chance of 2 is 300 + 100 per cell
  permille, capped at 800, and two spots are at least 4 m apart. The start hall gets **none**.
  `FloorScenario` fills each room's first spot before any second spot. When the item pool runs out (it has 8 items
  today), the remaining spots stay empty.
- The portal room is still the room farthest from the hall by doorway hops. The gate stands against a wall with a
  clear 3 × 3 m front, faces into the room, and its angle is a multiple of 1024.

## Top-down render of seeds 1, 2, 3

Command (from the repo root):

```bash
godot --headless --path . -s scripts/shots/floor_map.gd -- 1 2 3
```

Raw output:

```
seed 1: 10 rooms, 10 doorways, 43 interior pieces, 103.2 x 87.2 m, portal room 8 (7 hops), 12 item spots, 125 spawn points, generated in 109.4 ms
  rooms (cells): 3x3, 2x1, 2x1, 3x2, 1x1, 3x1, 1x1, 1x3, 1x1, 1x1
  templates: cross, cross, bunkers, scatter, centre, lines, scatter, bunkers, cross, bunkers
seed 2: 12 rooms, 13 doorways, 55 interior pieces, 103.2 x 65.6 m, portal room 11 (5 hops), 14 item spots, 135 spawn points, generated in 122.0 ms
  rooms (cells): 3x3, 1x2, 2x1, 2x1, 1x1, 3x1, 1x1, 1x1, 1x1, 1x3, 1x2, 1x1
  templates: pillars, bunkers, bunkers, cross, scatter, lines, centre, bunkers, scatter, lines, lines, bunkers
seed 3: 11 rooms, 11 doorways, 43 interior pieces, 103.2 x 87.2 m, portal room 9 (4 hops), 12 item spots, 141 spawn points, generated in 89.3 ms
  rooms (cells): 3x3, 2x3, 3x1, 1x1, 1x2, 1x3, 1x2, 2x1, 1x1, 1x1, 1x1
  templates: scatter, centre, lines, lines, scatter, scatter, scatter, bunkers, centre, pillars, scatter
floor tints: open = light grey, scatter = sand, pillars = blue, centre = pink, cross = green, lines = yellow, bunkers = teal
wrote res://build/floors/floor_layouts.png (1921x555): OK
```

The script wrote `build/floors/floor_layouts.png`, which was copied by hand to
[`floor_layouts.png`](floor_layouts.png).

How to read the image:

- Left to right: seeds 1, 2, 3. +X is right, +Y is down, 6 px per metre.
- Room floors are tinted by template (see the legend line above).
- Dark lines are the outer walls and partitions, broken at doorways (blue dots on the wall line). Brown shapes are
  interior pieces.
- Green dot: the start, in the middle of the hall. Yellow dots: item spots. Small red dots: spawn points.
- Magenta: the gate, against a wall of the portal room, with its clear front square outlined.

Seen in the image:

- Each hall is one big room with a single doorway.
- Seed 1's hall has a cross with a wide gap at the centre. Seed 2's has a checkerboard of pillars. Seed 3's has
  scattered slabs.
- Long 3×1 rooms carry staggered cover lines. Seed 3's 2×3 room has a ring of four L corners.
- No piece stands in a doorway.

## Tests

Command:

```bash
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_floor_generator.gd -gexit
```

Raw output, filtered with `grep -aE "floor generation|nav field|^Tests|^Passing|Failing|Asserts"`:

```
    floor generation: 50 floors, mean 82.7 ms, max 150.9 ms, 10.96 rooms, 13.32 item spots, 40.8 interior pieces per floor; templates seen: bunkers, centre, cross, lines, open, pillars, scatter; footprints seen: 9
    nav field on 5 floors: mean 32988 cells, build 69.9 ms, flood 5.5 ms
Tests                 8
Passing Tests         8
Asserts           89531
```

The 50 floors are seeds 1000 + 7919·k, for k = 0..49. Each floor is checked for:

- 10–12 rooms. The hall is 3 × 3 cells, has no structural wall inside it, and has exactly one exit.
- Allowed footprints, no overlaps, and an extent of at most 8 × 8 cells.
- Every room walled all round except at its doorways, and every doorway open.
- Every room's open floor in the start's region, at enemy clearance (0.6 m) and at player radius (0.35 m).
- The item-count rule.
- Item spots, spawn points and the gate front reachable and clear.
- The portal room farthest from the start.

Across the 50 floors, the test also checks:

- at least 3 templates appear (all 7 did);
- the hall's exit appears on all 4 sides;
- at least 6 footprints appear (all 9 did).

The timings are reported by the test, not asserted.

## NavField on the bigger floors

A floor's NavField grid grew from about 7,400 cells (v1) to about 33,000. Measured before this change, on the v1
floor (at `1a02ecb`, before this change; seeds 1–10, with a scratch script that timed `NavField.build`/`flood`): build
155.9 ms, flood 15.9 ms, mean 7,360 cells.

On the v2 floors, the original every-wall-at-every-cell build would take about 1.5 s. So `NavField.build` now
rasterises each wall only over its own bounds grown by the clearance, and `flood` walks an adjacency list built
once with the field. The original loops are kept as `build_reference`/`flood_reference`.
`test_fast_nav_field_matches_the_reference` asserts that blocked cells, regions and distances are identical on a
generated floor and on an arena with rotated slabs.

That comparison was timed with a scratch script, not tracked, kept under `build/tmp/navref.gd`. It generates seeds
1–5, then times `build`/`build_reference` and `flood`/`flood_reference` from the start. Command:

```bash
godot --headless --path . -s build/tmp/navref.gd
```

Raw output:

```
build fast 73.7 ms ref 1538.8 ms; flood fast 5.7 ms ref 35.0 ms; identical true
```

## Limits and open points

- **Ground outside the rooms.** The bounding box contains empty cells outside the outer walls. The view's ground
  plane (from `floor_bounds`) still covers them, so they look like floor that can't be reached. Hiding them is
  presentation work and was not done here.
- **Unfilled pedestals.** A floor has about 13 item spots and the pool has 8 items today. Until the pool grows
  (L16), the later rooms' spots stay empty.
- **Starting values.** The cell size (12 × 10 m), footprint weights, template weights and item chances are
  starting values. How the bigger floor feels is OWNER ONLY.
