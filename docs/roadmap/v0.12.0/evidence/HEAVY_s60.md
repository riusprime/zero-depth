# The Scrap Hound into the native enemy batch (step 60)

Machine: the owner's PC (i7-10700K, RTX 3060). Base `5d1ed045` (`lead-v0120`), worktree `wt-s60`, branch `v0120-s60`.
The port is commit `6a45c021` (parent `5d1ed045`). `lead-v0120` was then merged twice (the Lens Drone at `6e86ffd8`,
then the Bomb Drone in the merge commit that carries this file), and the tests below were run again on the merged
tree. Each run's `tasklist | grep -ci godot` before and after is given (one Godot run shows as 2 lines; another agent
ran Godot at the same time). No timing runs (owner: the lead times every kind once, all moved). Raw logs:
`C:/Users/extri/Desktop/zerodepth/appdata-s60/` (not tracked).

## What changed

- `EnemyBatch.KINDS` takes `KIND_SCRAP_HOUND`. On the VAT path its avatar read only its facing node's `rotation.y`
  (`_steer`, and AvatarBase's flinch), which the batch keeps as the slot's facing yaw, and wrote its body's yaw into its
  own transform (or its flinch's rest while a flinch runs), which is the row's `XF` / `REST_XF`. Its death's timer is
  the batch's (`EnemyBatch.drop`). No new batch API was needed, and it keeps no node part.
- It does not use `LeggedRig`: its legs are its own two-joint table (`_gait_legs`, `_leg_cycle`), ported with the rest.
  Its idle's `_scan` and `_hash` and its clips' clock are the same formulas as LeggedRig's `scan`, `hash01` and `clip`,
  so the port calls those (`zd_legged_rig.h`).
- `ZdCrowd` runs its sync, frame step and pose (`native/src/zd_avatar_scrap_hound.cpp`: `apply_state`, `advance`,
  `_steer`, `stride_hz`, `_pose`, `_gait_legs`, `_leg_cycle`, `_flick`, `_tell_pose`, `_dart_pose`, `_bite_envelope`,
  `_bite_pose`, `_yelp_pose`, `_hurt_pose`, `_rise_pose`, `_death_pose`, `_visor`, `vat_drives`), line by line:
  doubles for its clocks, speeds, turn, bank, lift and glow, floats for its `_vd` (each `d[j] += x` a float read, a
  double add, a float store), a leg's cycle a float `Vector2`, `GALLOP_SWING` / `GALLOP_FOLD` float `Vector2`
  constants, the yaw a float `Basis`, the engine's sin/cos/exp/atan2 and `wrapf`. Native class 18. Its fields are
  43..80 of the row: `STRIDE` stays 124. Its sync's `MORE` inputs are its HP and whether a hit stopped it (the yelp).
- `batch_scrap_hound.gd` (`BatchScrapHound`) holds its row export and import, its sync inputs (`note`) and its GDScript
  fallback sync (`apply_in_script`). The shared files have the dispatch lines only. The avatar's events `_touch()`
  (apply_state, advance, die) and its reads `_peek()`. It does not override `_flinch_pivot`.
- No biome variant of the Scrap Hound exists (`ActorViews` builds it for `KIND_SCRAP_HOUND` only).
- `batch_avatars.gd` is at 1,000 lines after the second merge (the hound's lines kept to the dispatch).

## Bit for bit: `tests/unit/native/test_native_crowd_scrap_hound.gd`

12 hounds in a ring round the hero at 3, 5, 7 and 9 m, two of them 30 m further out (the catch-up), 300 frames of 0,
1, 1, 2 ticks, the hero swinging (held attack 30 frames in 50, its aim turning: the hounds go for its back, tell and
dart), a reduced-motion stretch (frames 200-229), hurts (a hurt on a tell or dart is a yelp), flashes, flinches with
and without knock, holds, tints, two spawns, a kill every 40 frames (mid-attack when one is). Every VAT set's
instance and drive buffers and the furniture, native against GDScript, every frame (`CrowdTwins`).

On the port alone (`6a45c021`'s tree), godot 2 / 2:
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_scrap_hound.gd -gexit
exit=0
    hound states seen (actor-frames): { 0: 490, 1: 2274, 2: 214, 4: 240, 3: 105 }; yelps 2, bites 4; kills 5 (5 mid-attack)
Tests                 1
Passing Tests         1
Asserts             103
```
(States: 0 spawn, 1 move, 2 windup (the tell), 3 active (the dart), 4 recover (the bite or the yelp).)

Shown able to fail: `const YAW_RATE := 9.0` to `9.000001` in `scrap_hound_avatar.gd` (`_steer`: the body's yaw on its
own transform), godot 2 / 2:
```
exit=1
    [Failed]:  frame 38: _looks 45|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 2 at 2: -0.27711523 vs -0.27711526
Passing Tests      none
```
then put back (`grep -c 9.000001` gives 0).

## The twin probe

On the port alone:
```
"$GODOT" --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=night_rocks --enemies=42 --secs=20 --warm=5 --size=2560x1440 --kinds=scrap_hound --twin [--ab=no_batch]
```
```
batched, native (exit 0, godot 2 / 0):
twin: 729 frames compared, 25735 body instances, 66084 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bar_basis max 0.000000 over 0, bar_new_basis max 0.358768 over 220, bar_new_pos max 0.793279 over 208, bar_pos max 0.000002 over 0, bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 3.200000 over 337, body_drives max 0.445850 over 2949, body_pos max 0.058425 over 2597, chunks_drawn max 0.000000 over 0, disc_basis max 0.000000 over 0, disc_pos max 0.000002 over 0, ring_basis max 0.000000 over 0, ring_pos max 0.000002 over 0
nodes against nodes (--ab=no_batch, exit 0, godot 0 / 0):
twin: 855 frames compared, 31308 body instances, 0 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 2.590812 over 223, body_drives max 0.403458 over 2442, body_pos max 0.049287 over 2156, chunks_drawn max 0.000000 over 0
```
The body rows are of the harness's own spread's size: two node views show body_color 2.59, body_drives 0.40,
body_pos 0.049 at the largest; the batch against nodes 3.20, 0.45, 0.058. The share of body instances over the
threshold is higher in the batched run (drives 11.5 % of 25735, against 7.8 % of 31308 node-vs-node; pos 10.1 %
against 6.9 %). `body_basis` (the hound's yaw) is 0 in both. One run of each (no second pair), so the share's gap is
not separated from the run's own variation; the bit-for-bit test above is the proof of the same numbers. The
`bar_new_*` rows are the twin's known first frames of a new bar.

## Tests

On the merged tree (both merges), the native library rebuilt with `bash scripts/native/ensure.sh` (MSVC), exit 0:
```
-gdir=res://tests/arch,res://tests/golden,res://tests/unit/native -ginclude_subdirs   -> exit 0, 55/55 tests, 29169 asserts (godot 4 / 4)
  (test_native_fixtures: the sim kernels' fixtures unchanged; tests/golden untouched)
-gtest=test_scrap_hound_avatar, test_enemy_batch, test_enemy_vat, test_view_wake        -> exit 0, 37/37 tests, 56493 asserts (godot 4 / 4)
```
After the first merge only: the same `-gdir` run, exit 0, 54/54 tests, 29032 asserts (godot 2 / 2).
Lint: `gdformat --check src scripts tests && gdlint src scripts tests` on the port: no problems found; on the merged
files (`src/presentation/world_view`, `tests/unit/native`, `tests/support`): no problems found.

## Not run / left

- Timing: NOT YET RUN (the lead's, every kind moved).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI).
- e2e and seams: not run (the lead's, at the end).
- The twin probe on the merged tree: not run (the port's code did not change in the merges).
