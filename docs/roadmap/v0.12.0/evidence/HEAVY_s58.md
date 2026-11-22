# The Bomb Drone into the native enemy batch (step 58)

Machine: the owner's PC (i7-10700K, RTX 3060). Base `ab4b110c`, merged forward to `lead-v0120` at `21c95adf` (the
Sniper, the Arc Caster and the Lens Drone in) before the commit; worktree `wt-s58`, branch `v0120-s58`. Every run
below was on the working tree that became this step's commit. The final tests ran on the tree merged to `21c95adf`.
The equality and the twin probe runs before that ran on the trees merged to `0fbcbb40` and `5d1ed045`. Each run's
`tasklist | grep -ci godot` before / after is given (one Godot run shows as 2 lines; another agent's Godot ran beside
some). No timing runs (owner: the lead times every kind once, all moved). Raw logs: `C:/Users/extri/Desktop/zerodepth/
s58_*.log` (not tracked).

## What changed

- `EnemyBatch.KINDS` takes `KIND_BOMB_DRONE` (no variant of it exists). Its avatar read nothing of the tree but its
  facing node's turn (its parent, which a batched avatar keeps) and its death went through the batch's `drop` timer
  already; the one thing left was its ground disc (`shadow`, `SoloVat.LIVE`: the one node a VAT drone draws as a node).
  `BatchBombDrone.hold` moves it into the tree:
  - under a node of the batch's, not interpolated, put each frame at `EnemyBatch.origin(id)`: where the batch draws the
    drone's contact disc, which the twin probe measures equal to the node root's drawn place;
  - then a copy of the facing (interpolated, as the facing was) and of the avatar's transform (not interpolated, as
    the avatar was not), so a flinch leans the disc with the body.

  The batch's anchor (`BatchWarden`'s and `BatchLensDrone`'s parent) was tried first. The twin probe measured its
  interpolated place a part of a tick behind the node root's: `ground_disc_pos` max 0.297 m, over the threshold on
  17,388 of the drone-frames. See the probe below; the debug lines showed the anchor's interpolated x halfway between
  the root's current and interpolated places.
- The disc's scale (`Vector3(sh, 1, sh)`, `sh` stored as a float) is the row's `BD_SHADOW`, set after every frame step
  (`BatchBombDrone.show`) and after each sync's flush (`EnemyBatch.flush_avatars`). The flush covers a batch made in
  this sync, which first steps next frame: without it, the first frame's discs kept their pre-sync scale
  (`ground_disc_basis` 0.0347 on frame 1 for all 42).
- `ZdCrowd` runs its sync, frame step and pose (`native/src/zd_avatar_bomb_drone.cpp`: `apply_state`, `advance`,
  `_turning` through `rig::turning`, `_pose`, `_glide_pose`, `_lob_pose`, `_hurt_pose`, `_death_pose`, `vat_drives`).
  They are ported line by line:
  - doubles for the clocks, spins and glows;
  - floats for `_vd` (each `+=` a float read, a double add, a float store) and for the glide's direction and the
    velocity turned into the facing's frame (`axis_angle`, the engine's float sine);
  - floats for the visor's glow and the disc's scale (what the material and the node store).

  Native class 16. Its fields are 43..75 of the row: `STRIDE` stays 124. Its sync's HP is the first `MORE` value, as
  the Needle's. `flinch_pivot(cls)` (`zd_avatar.cpp`) gives it its `_flinch_pivot`, `HOVER_Y` 1.8: its flinch leans
  about the hull.
- The fuse's glow (`_fuse_mat`) is not reckoned natively. On a VAT avatar the bomb is the crowd's baked mesh and that
  material belongs to no node, so nothing drawn reads it. The object gets it back from its own pose once the rows are
  off.
- The avatar's events `_touch()` (`apply_state`, `advance`, `die`) and its reads `_peek()`. Its row copy is in
  `batch_bomb_drone.gd`, the row's dispatch in `BatchAvatars._export_solo` / `_import_solo`.
- `scripts/checks/batch_twin.gd` also compares a Bomb Drone's ground disc (shown, interpolated global transform).

## Bit for bit: `tests/unit/native/test_native_crowd_bomb_drone.gd`

The test runs for 300 frames:
- the crowd: 12 drones in a ring round the hero at 4 to 8.8 m, two of them 30 m further out (the catch-up), and two
  spawns;
- the frames: 0, 1, 1, 2 ticks, with a reduced-motion stretch;
- the events: hits (the HP sag), flashes, flinches with and without knock, holds, tints, and a kill every 40 frames
  (mid-lob when one is).

Every frame it compares, native against GDScript:
- every VAT set's instance and drive buffers;
- the furniture;
- each drone's ground disc (in the tree, shown, global transform), falling ones too.
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_bomb_drone.gd -gexit
exit 0   (godot 0 / 0)
    bomb drone states seen (actor-frames): { 0: 490, 1: 1371, 2: 800, 3: 355, 4: 307 }, { "flinched": 62, "held": 31, "killed": 5, "killed_lobbing": 4, "spawned": 2, "hurt": 1689, "gliding": 1730, "turning": 907, "lobbing": 582, "dying": 322 }
Tests                 1
Passing Tests         1
Asserts             105
```
(States: 0 spawn, 1 move, 2 windup, 3 active, 4 recover; the counts after are drone-frames in each clip.)

Shown able to fail, each change then put back (`grep -c` gives 0 after):
- the claws' quiver `d[CLAW] += 0.06 * k * free` to `0.0600001` in `bomb_drone_avatar.gd`:
  ```
  exit 1
  [Failed]:  frame 0: _looks 10|00000000|0.4500|1a1a22ff|e8c22eff,b09222ff,5f5551ff,ff2a22ff field 3 at 5: 0.0370825 vs 0.037082564
  Passing Tests      none
  ```
- the disc's scale `(1.0 - bob * 0.8)` to `0.80001`:
  ```
  exit 1
  [Failed]:  frame 0: id 2 disc at [X: (-0.56387, 0.0, 0.0), ... O: (4.0, 0.012, 0.0)] vs [X: (-0.56387, 0.0, 0.0), ... O: (4.0, 0.012, 0.0)]
  Passing Tests      none
  ```
  (The printed transforms round to the same digits; the floats differ.)

## The twin probe

```
"$GODOT" --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=night_rocks --enemies=42 --secs=20 --warm=5 --size=2560x1440 --kinds=bomb_drone --twin [--ab=no_batch]
```
The rows the step touches. In every run, every other row is 0 or under 0.0005, except `bar_new_*` (a bar's first
frames, kept apart on purpose).

| Run | Godot lines before / after | Frames, body instances | `ground_disc_pos` | `ground_disc_basis` | `body_drives` |
|---|---|---|---|---|---|
| batched, native, the disc on the anchor (first try) | 2 / 2 | 728, 27713 | 0.297177, over on 17388 | 0.034745, over on 42 | 0.111841, over on 1206 |
| nodes against nodes (`--ab=no_batch`) | 2 / 0 | 924, 34519 | 0.193349, over on 14292 | 0 | 0.105597, over on 1067 |
| batched, native, the disc at `origin` | 4 / 2 | 790, 28999 | 0.000002, over on 0 | 0.034745, over on 42 (frame 1) | 0.108765, over on 1605 |
| batched, native, plus the scale after the flush (the commit) | 0 / 2 | 733, 27176 | 0.000002, over on 0 | 0 | 0.111396, over on 1236 |

Reading:
- The committed disc is drawn where and as large as the twin's node disc, to float rounding.
- The nodes-against-nodes run differs by 0.19 m because of the harness: the live roots are started from the tick
  before and the twin's are not (HEAVY_s54's crust reading).
- `body_drives`: its largest difference is the harness's spread (0.106 nodes against nodes, 0.109 to 0.112 batched).
  The examples are the claws' and the bomb's drives, a lob started a frame apart between two views built at different
  moments, with every other drive equal.
- `body_pos`, `body_basis`, `body_color`, `bodies_drawn`: 0.

## Tests

```
-gdir=tests/arch,tests/golden,tests/unit/native -ginclude_subdirs
  + -gtest=test_bomb_drone_avatar, test_damage_flash, test_enemy_batch, test_enemy_fireball_views, test_enemy_shadows,
    test_enemy_vat, test_enemy_vat_more, test_hit_impact, test_new_enemy_avatars, test_shader_warmup, test_view_wake,
    test_lens_drone_avatar (tests/unit/presentation), one process, on the tree merged to 21c95adf
                                                    -> exit 0 (godot 0 / 2), 142/142 tests, 105764 asserts
  (test_native_fixtures: the kernels' fixtures unchanged; tests/golden untouched)
gdformat --check src scripts tests && gdlint src scripts tests   -> 1980 files unchanged; no problems found
```
The native library built with `bash scripts/native/ensure.sh` (MSVC): exit 0, no warning from the new file.

## Not run / left

- Timing: NOT YET RUN (the lead's, every kind moved).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI).
- e2e and seams: not run (the lead's, at the end; `test_e2e_new_enemies` reads `bomb_armed()`, which now peeks).
