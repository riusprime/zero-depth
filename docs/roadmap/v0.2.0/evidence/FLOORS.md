# v0.2.0 B — floor generator evidence

Build SHA: `40f99362e82ecd29e3fb4590828b6b006fc74799` (branch `worktree-agent-a5a415024d9c888fd`), Godot 4.7.2,
Linux cloud container, headless. Timings are from that container, not the owner's hardware.

## Top-down render of seeds 1, 2, 3

Command (from the repo root):

```bash
godot --headless --path . -s scripts/shots/floor_map.gd -- 1 2 3
```

Raw output:

```
seed 1: 9 rooms, 9 doorways, 8 slabs, start room 0, portal room 2 (4 hops), 8 item spots, 78 spawn points, generated in 27.0 ms
seed 2: 9 rooms, 9 doorways, 12 slabs, start room 6, portal room 2 (4 hops), 8 item spots, 69 spawn points, generated in 34.9 ms
seed 3: 9 rooms, 9 doorways, 9 slabs, start room 2, portal room 8 (6 hops), 8 item spots, 74 spawn points, generated in 31.4 ms
wrote res://build/floors/floor_layouts.png (1420x424): OK
```

The script wrote `build/floors/floor_layouts.png`; it was copied by hand to
[`floor_layouts.png`](floor_layouts.png).

What the image shows (left to right: seeds 1, 2, 3; +X right, +Y down; 10 px per metre): grey room floors, dark
outer walls and partitions broken by doorways (blue dots on the wall line), brown interior slabs, a green dot at the
start position, yellow item spots (one in every room but the start), small red spawn points, and the magenta gate
against a wall of the portal room with its clear 3 × 3 m front square outlined in magenta. In all three floors the
gate sits in a corner room opposite or beside the start, no slab stands in a doorway, the start area or the gate's
front.

## Tests

Command:

```bash
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_floor_generator.gd -gexit
```

Raw output (filtered with `grep -aE "floor generation|^Tests|^Passing|Failing|Asserts"`):

```
    floor generation: 50 floors, mean 35.0 ms, 521 slabs (1.16 per room)
Tests                 6
Passing Tests         6
Asserts           14657
```

The 50 floors are seeds 1000 + 7919·k, k = 0..49. The mean includes the per-room flood checks; it is reported, not
asserted.
