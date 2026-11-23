# The Cinder Priest into the native enemy batch (step 62)

Machine: the owner's PC (i7-10700K, RTX 3060). Base `4a1bd835` (`lead-v0120`), worktree `wt-s62`, branch `v0120-s62`.
The port is commit `db83246b` (parent `4a1bd835`). `lead-v0120` was then merged at `cc740a31` (the Kiln Beetle and
step 68's split of `batch_avatars.gd`) in `7b0cd832`, and its two docs commits after (`bf9d78c2`) in `95f14fad`; the
equality test and the lint were run again on the merged tree. Each run's `tasklist | grep -ci godot` before and after
is given where it was taken (one Godot run shows as 2 lines; the counts taken inside a background chain came out 0,
which is not a real count). No timing runs (owner: the lead times every kind once, all moved). Raw logs:
`C:/Users/extri/Desktop/zerodepth/appdata-s62/` (not tracked).

## What changed

- `EnemyBatch.KINDS` takes `KIND_CINDER_PRIEST`. On the VAT path its avatar read nothing of the tree already: its turn
  to the vent is reckoned in the sim's facing (`SimPlane.yaw_of(actor_facing)`), its glide from the sim's velocity,
  and its death's timer is the batch's (`EnemyBatch.drop`). No new batch API was needed.
- `ZdCrowd` runs its sync, frame step and pose (`native/src/zd_avatar_cinder_priest.cpp`: `apply_state`, `advance`,
  `_pose`, `_idle`, `_glide_pose`, `_death`, `_add`, `vat_drives`), line by line: doubles for its clocks, lift and
  glows, floats for its `_vd` (each `d[j] += x` a float read, a double add, a float store), the glide's direction a
  float `Vector2` and the velocity's turn into the facing's frame a float `Basis`, the engine's sin/cos/exp. Native
  class 20. Its fields are 43..74 of the row: `STRIDE` stays 124 (no growth).
- Its sync's `MORE` inputs (4 of the 6): the vent's pulse (0..1000), the ticks since its own vent erupted (-1: none),
  the vent's direction in the facing's frame (NAN: none), the facing's yaw. `BatchCinderPriest.note` works them out
  in GDScript with the very statements of `CinderPriestAvatar.sync` (the `lava_vents` scan, `atan2`, `wrapf`), so the
  native side needs no atan2.
- Its row export and import, its sync inputs and its fallback sync are in `batch_cinder_priest.gd`
  (`BatchCinderPriest`); after the merge its dispatch lines sit in `BatchRows._export_solo` / `_import_solo` and
  `BatchScriptSync.apply`, and its class, `CLASS_OF` entry, `class_of` and `note_sync` lines in `batch_avatars.gd`
  (551 lines). The avatar's events `_touch()` (apply_state, advance, die) and its reads `_peek()` (dying, vat_lift,
  vat_drives, glow_energy).
- The crystal's and the visor's glows are kept as they were: the crystal's energy is the instance's accent glow
  (`glow_energy`), the visor's the `VISOR` drive, and `take()` writes both materials' `emission_energy_multiplier`
  when they change, as the avatar's `_pose` did. It has no light node and no particles.
- No biome variant of the Cinder Priest exists (`LOOKS` holds `KIND_CINDER_PRIEST` only; `ActorViews` builds it for
  that kind only), so none is left on its nodes.

## Bit for bit: `tests/unit/native/test_native_crowd_cinder_priest.gd`

14 priests in a ring round the hero at 3, 5, 7 and 9 m, two of them 30 m further out (the catch-up), 300 frames of 0,
1, 1, 2 ticks, a reduced-motion stretch (frames 200-229), hurts, flashes, flinches with and without knock, holds,
tints, two spawns, a kill every 40 frames (mid-raise, its vent's pulse running, when one is). Every VAT set's instance
and drive buffers and the furniture, native against GDScript, every frame (`CrowdTwins`). The priests plant their own
vents in the sim, so the raise, the slam and the recoil all run.

On the port alone (`db83246b`), godot 2 / 2:
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_cinder_priest.gd -gexit
exit=0
    priest-frames raising 457, vent-frames erupting 202; kills 5 (3 mid-raise)
Tests                 1
Passing Tests         1
Asserts             109
```

Shown able to fail: `_vd[HOOD_S] += 0.05 * s * ...` to `0.0500001` in `cinder_priest_avatar.gd` (`_idle`), godot 2 / 0:
```
exit=1
    [Failed]:  frame 37: _looks 49|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 3 at 37: 0.50239694 vs 0.502397
Passing Tests      none
```
then put back (`grep -c 0.0500001` gives 0).

On the merged tree (`7b0cd832`, the library rebuilt with `bash scripts/native/ensure.sh`, exit 0), godot 2 / 2:
```
exit=0
    priest-frames raising 457, vent-frames erupting 202; kills 5 (3 mid-raise)
Tests                 1
Passing Tests         1
Asserts             109
```

## The twin probe (the port alone, before the owner's instruction to stop)

```
"$GODOT" --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=42 --secs=20 --warm=5 --size=2560x1440 --kinds=cinder_priest --twin [--ab=no_batch]
```
```
batched, native (exit 0):
twin: 647 frames compared, 24224 body instances, 59735 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bar_basis max 0.000000 over 0, bar_new_basis max 0.220764 over 105, bar_new_pos max 0.139715 over 77, bar_pos max 0.000001 over 0, bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.000000 over 0, body_drives max 0.000000 over 0, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0, disc_basis max 0.000000 over 0, disc_pos max 0.000002 over 0, ring_basis max 0.000000 over 0, ring_pos max 0.000002 over 0
nodes against nodes (--ab=no_batch, exit 0):
twin: 671 frames compared, 25894 body instances, 0 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.000000 over 0, body_drives max 0.000000 over 0, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0
```
The bodies match exactly in both runs (every body row 0.000000; in this probe's fight the priests did not reach a
vent cycle that the two views saw a frame apart). The `bar_new_*` rows are the twin's known first frames of a new bar.
One run of each.

## Tests

On the port alone (`db83246b`), before the owner's instruction that each kind runs only its own equality test:
```
-gdir=res://tests/arch,res://tests/golden,res://tests/unit/native -ginclude_subdirs   -> exit 0, 56/56 tests, 29302 asserts
  (test_native_fixtures: the sim kernels' fixtures unchanged; tests/golden untouched)
-gtest=test_cinder_priest_avatar, test_canyon_shore_views, test_enemy_batch, test_enemy_vat, test_view_wake
                                                                                       -> exit 0, 44/44 tests, 56970 asserts
```
Lint on the merged tree: `gdformat --check src scripts tests && gdlint src scripts tests` -> 1988 files unchanged,
no problems found.

## Not run / left

- `tests/arch`, `tests/golden`, `tests/unit/native` and the avatar tests on the merged tree: NOT YET RUN (run once
  with every kind moved).
- The twin probe on the merged tree: NOT YET RUN (run once with every kind moved).
- Timing: NOT YET RUN (the lead's, every kind moved).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI).
- e2e and seams: NOT YET RUN (run once with every kind moved).
