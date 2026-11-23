# The Arc Caster into the native enemy batch (step 57)

Machine: the owner's PC (i7-10700K, RTX 3060). Base `d2ed8e89` (`lead-v0120`), worktree `wt-s57`, branch `v0120-s57`.
The port is commit `e783d97a` (parent `d2ed8e89`). `lead-v0120` was then merged twice (the Warden at `ab4b110c`, the
Sniper at `0fbcbb40`), and the tests below were run again on the merged tree. Each run's `tasklist | grep -ci godot`
before and after is given where it was taken (one Godot run shows as 2 lines; the counts inside the background twin
loop came out 0, which is not a real count). No timing runs (owner: the lead times every kind once, all moved). Raw
logs: `C:/Users/extri/Desktop/zerodepth/appdata-s57/` (not tracked).

## What changed

- `EnemyBatch.KINDS` takes `KIND_ARC_CASTER`. On the VAT path its avatar read only one thing of the tree: its facing
  node's `rotation.y` (`_turning`, and AvatarBase's flinch), which the batch keeps as the slot's facing yaw, as for
  the Needle. Its death's timer is the batch's (`EnemyBatch.drop`). No new batch API was needed.
- `ZdCrowd` runs its sync, frame step and pose (`native/src/zd_avatar_arc_caster.cpp`: `apply_state`, `advance`,
  `_turning` (LeggedRig's `turning`, the same formula), `_pose`, `_idle`, `_glide_pose`, `_turn_pose`, `_death`,
  `_add`, `vat_drives`), line by line: doubles for its clocks, lift and glows, floats for its `_vd` (each `d[j] += x`
  a float read, a double add, a float store), the glide's direction a float `Vector2` and the velocity's turn into the
  facing's frame a float `Basis`, the engine's sin/cos/exp. Native class 15. Its fields are 43..81 of the row:
  `STRIDE` stays 124 (no growth). It reads the common sync inputs only (no `MORE`).
- Its row export and import are in `batch_arc_caster.gd` (`BatchArcCaster`). The avatar's events `_touch()`
  (apply_state, advance, die) and its reads `_peek()`.
- After the merges, `BatchAvatars._export` / `_import` had one return too many for the lint (`max-returns`, 6), so the
  solo model kinds' row copies (Needle, Rock Lurker, Warden, Sniper, Arc Caster) moved into `_export_solo` /
  `_import_solo`, the same calls in the same order.
- No biome variant of the Arc Caster exists (`ActorViews` builds it for `KIND_ARC_CASTER` only), so none is left on
  its nodes.

## Bit for bit: `tests/unit/native/test_native_crowd_arc_caster.gd`

14 casters in a ring round the hero at 2.5, 4.5, 6.5 and 8.5 m, two of them 30 m further out (the catch-up), 300
frames of 0, 1, 1, 2 ticks, a reduced-motion stretch (frames 200-229), hurts, flashes, flinches with and without
knock, holds, tints, two spawns, a kill every 40 frames (mid-cast when one is). Every VAT set's instance and drive
buffers and the furniture, native against GDScript, every frame. It uses `CrowdTwins` (`tests/support/crowd_twins.gd`).

Before the merges (the test then in `test_native_crowd.gd`), godot 4 / 2:
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd.gd -gunit_test_name=arc_casters -gexit
exit 0
    caster states seen (actor-frames): { 0: 560, 1: 1957, 2: 721, 4: 669, 3: 16 }; kills 5 (2 mid-cast)
Tests                 1
Passing Tests         1
Asserts             109
```
(States: 0 spawn, 1 move, 2 windup (the gather), 3 active (the cast), 4 recover.)

On the merged tree, godot 2 / 2:
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_arc_caster.gd -gexit
exit 0
    caster states seen (actor-frames): { 0: 560, 1: 1957, 2: 721, 4: 669, 3: 16 }; kills 5 (2 mid-cast)
Tests                 1
Passing Tests         1
Asserts             109
```

Shown able to fail: `d[HOOD_S] += 0.05 * s * ...` to `0.0500001` in `arc_caster_avatar.gd` (`_idle`), godot 2 / 0:
```
exit 1
    [Failed]:  frame 42: _looks 9|00000000|0.4500|1a1a22ff|8a50d8ff,6a3ca8ff,5f5551ff,ff2a22ff field 3 at 7: 0.50728977 vs 0.5072898
Passing Tests      none
```
then put back (`grep -c 0.0500001` gives 0).

## The twin probe

Before the merges (the port alone on `d2ed8e89`):
```
"$GODOT" --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=night_rocks --enemies=42 --secs=20 --warm=5 --size=2560x1440 --kinds=arc_caster --twin [--ab=no_batch]
```
```
batched, native (exit 0):
twin: 735 frames compared, 28364 body instances, 68103 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bar_basis max 0.000000 over 0, bar_new_basis max 0.240750 over 75, bar_new_pos max 0.123340 over 48, bar_pos max 0.000002 over 0, bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 8.916916 over 2802, body_drives max 0.622547 over 2765, body_pos max 0.049232 over 2632, chunks_drawn max 0.000000 over 0, disc_basis max 0.000000 over 0, disc_pos max 0.000002 over 0, ring_basis max 0.000000 over 0, ring_pos max 0.000002 over 0
nodes against nodes (--ab=no_batch, exit 0):
twin: 920 frames compared, 33859 body instances, 0 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 9.179889 over 3015, body_drives max 0.622478 over 2983, body_pos max 0.049171 over 2836, chunks_drawn max 0.000000 over 0
```
The body rows are the harness's own spread: two node views show the same largest differences (body_color 9.18,
body_drives 0.62, body_pos 0.049) as the batch against nodes (8.92, 0.62, 0.049), over a similar share of the body
instances (8.9 % of 33859 node-vs-node, 9.9 % of 28364 batched). Its examples are a cast seen to start a frame apart in
the two views (the crystal's flare, the staff thrust and the cast's dip of the lift: `body_pos` is only y). The
`bar_new_*` rows are the twin's known first frames of a new bar. One run of each (no second pair).

## Tests

On the merged tree:
```
-gdir=res://tests/arch,res://tests/golden,res://tests/unit/native -ginclude_subdirs   -> exit 0, 51/51 tests, 28771 asserts (godot 2 / 2)
  (test_native_fixtures: the sim kernels' fixtures unchanged; tests/golden untouched)
-gtest=test_arc_caster_avatar, test_enemy_batch, test_sniper_avatar, test_rock_lurker_avatar, test_view_wake,
  test_enemy_vat                                                                       -> exit 0, 70/70 tests, 58391 asserts (godot 2 / 0)
```
Lint: `gdformat --check src scripts tests && gdlint src
scripts tests` -> unchanged, no problems found. The native library built with `bash scripts/native/ensure.sh` (MSVC),
exit 0, before and after each merge.

## Not run / left

- Timing: NOT YET RUN (the lead's, every kind moved).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI).
- e2e and seams: not run (the lead's, at the end).
- The twin probe on the merged tree: not run (the port's code did not change in the merge).
