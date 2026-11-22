# The Rock Lurker into the native enemy batch (step 55)

Machine: the owner's PC (i7-10700K, RTX 3060). Base `1bf5e52c` (`lead-v0120`), worktree `wt-s55`, branch `v0120-s55`.
Every run below was on the working tree that became this step's commit (the base plus this step's changes). Other
agents' Godot ran beside some runs: each run's `tasklist | grep -ci godot` before and after is given (one Godot run
shows as 2 lines). No timing runs (owner: the lead times every kind once, all moved). Raw logs:
`C:/Users/extri/Desktop/zerodepth/appdata-s55/` (not tracked).

## What changed

- `EnemyBatch.KINDS` takes `KIND_ROCK_LURKER`. Its avatar's two tree uses on the batch path are gone:
  - its disguise hid its root's disc and ring nodes (`_show_rings`, from its `sync`). A batched Lurker has no such
    nodes: `EnemyBatch.update` calls the new `EnemyBatch.show_rings(id, on)` with `RockLurkerAvatar.disguised`
    (hidden, or still arriving: the same test its sync used), which takes the slot's disc and ring out of their sets
    (set index -1, which both writers already skip) and puts them back when it comes out. A hidden one that dies keeps
    them hidden through its fall, as its nodes did. The node path is unchanged (`_show_rings` runs when not
    `detached`). The bar and the blob were never touched by `_show_rings` in effect (the bar is a `Node3D`; the blob
    was set back the same sync), so they keep the batch's rules.
  - its `fall()` (the tree's timer) is only ActorViews' node path; a batched Lurker dies through `EnemyBatch.drop`
    (its `die()`, the batch's timer, the bar and blob gone at once), as every batched kind.
- `ZdCrowd` runs its sync, frame step and pose (`native/src/zd_avatar_lurker.cpp`: `apply_state`, `advance`,
  `_pose`, `_about_feet`, `_blend_tucked`, `_rear_at`, AvatarBase's strike clock, line by line, doubles for its clocks
  and glows, floats for its `_vd` (each `v[d] += x` a float read, a double add, a float store) and the hind feet's
  `Vector2`, the engine's sin/cos/exp). Native class 13. Its fields are 43..82 of the row: `STRIDE` stays 113 (no
  growth). Its sync inputs use two of the six `MORE` values (disguised, rumbling); its windup is read in any state, as
  its sync does. Its row export and import are in `batch_lurker.gd` (`BatchLurker`), out of `batch_avatars.gd`.
- The avatar's events `_touch()` (apply_state, die, advance) and its reads `_peek()`, like the Stone Thrower's.

## Bit for bit: `test_the_native_rock_lurkers_draw_the_script_ones_bodies`

14 Lurkers in a ring round the hero at 2.4, 4, 5.5 and 7 m (woken at once, rumbling, still), two of them 30 m further
out (the catch-up), 300 frames of 0, 1, 1, 2 ticks, a reduced-motion stretch, hits (waking waiting ones), flashes,
flinches with and without knock, holds, tints, two spawns, a kill every 40 frames (alternately one still waiting and
one mid-slam). Every VAT set's instance and drive buffers and the furniture, native against GDScript, every frame.

```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd.gd -gunit_test_name=rock_lurkers -gexit
exit 0
    lurker states seen (actor-frames): { "hidden": 975, "rumbling": 349, 0: 560, 1: 2508, 2: 380, 4: 468, 3: 7 }; kills 5 (2 mid-slam, 3 waiting)
Tests                 1
Passing Tests         1
Asserts             104
```
(States: 0 spawn, 1 move, 2 windup, 3 active, 4 recover.)

Shown able to fail: `v[BY] += 0.022 * ru` to `0.0220001 * ru` in `rock_lurker_avatar.gd` (the rumble's lift):
```
exit 1
    [Failed]:  frame 38: _looks 46|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 2 at 37: 0.09517857 vs 0.09517859
Passing Tests      none
```
then put back (`grep -c 0.0220001` gives 0).

The disc and ring against the node path: `test_rock_lurker_avatar.gd`
`test_on_the_vat_crowd_it_is_batched_its_disc_and_ring_hidden_while_it_waits_as_its_nodes_were`: a batched view and a
view with `batching = false` on the same world, 240 ticks (waiting, then woken by a hit): the batch's disc and ring
drawn exactly when the node view's disc and ring nodes are visible, every tick.

## The twin probe

```
"$GODOT" --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=night_rocks --enemies=42 --secs=20 --warm=5 --size=2560x1440 --kinds=rock_lurker --twin [--ab=...]
```
```
batched, native (4 / 6):  twin: 754 frames compared, 30694 body instances, 14652 furniture instances against the twin's nodes
  bar_basis 0, bar_new_basis max 0.229202 over 44, bar_new_pos max 0.123080 over 26, bar_pos 0.000001, bodies_drawn 0, body_basis 0, body_color 0,
  body_drives max 1.592209 over 1143, body_pos 0, chunks_drawn 0, disc_basis 0, disc_pos max 0.123080 over 32, ring_basis 0, ring_pos max 0.123080 over 32
batched, GDScript (--ab=no_native_crowd, 2 / 2):  twin: 752 frames compared, 29556 body instances, 20476 furniture instances
  bar_new_basis max 0.257104 over 47, bar_new_pos max 0.071283 over 21, bar_pos 0.000001, body_drives max 1.622042 over 1464,
  disc_pos max 0.161806 over 31, ring_pos max 0.161806 over 31, every other row 0
nodes against nodes (--ab=no_batch, 6 / 4):  twin: 764 frames compared, 30558 body instances, 0 furniture instances
  body_drives max 1.462300 over 798, every other row 0
nodes against nodes again (--ab=no_batch, 2 / 2):  twin: 856 frames compared, 34836 body instances
  body_drives max 1.525274 over 858, every other row 0
```
No `disc_shown` or `ring_shown` row: the batch showed the disc and ring on exactly the frames the twin's nodes were
visible. The `disc_pos` / `ring_pos` rows (the same size as `bar_new_pos`) come from a disc's first frames after it
is shown again (a Lurker coming out), the twin's own `bar_new` case. A run with the twin script changed for that run
only (discs and rings on their first two shown frames counted apart, the same rule as bars; then restored, not
committed), native, 4 / 2:
```
twin: 891 frames compared, 34775 body instances, 23222 furniture instances against the twin's nodes
  disc_new_pos max 0.082061 over 29, disc_pos max 0.000002 over 0, ring_new_pos max 0.082061 over 29, ring_pos max 0.000002 over 0,
  body_drives max 1.544518 over 2033, (ring_new_basis max 0.92: that run's change skipped the ring's flattening), every other row 0
```
`body_drives`: its largest difference is the harness's spread (1.46-1.53 nodes against nodes, 1.54-1.62 batched),
the same kind of example (a strike started a frame apart between two views built at different moments). The number
of frames over the threshold is higher in the batched runs (1143, 1464, 2033) than in the two node runs (798, 858).
The scenario is not the same twice (the hero's strafe and the refills run on the wall clock, so how many Lurkers are
out and slamming varies), and the GDScript batch shows it as well as the native one (which is bit for bit the
GDScript, above), so it is not the port; whether batching itself shifts a strike's frame more often for this kind
than two node views do is NOT YET SETTLED by these runs.

## Tests

```
-gdir=tests/arch,tests/golden,tests/unit/native -ginclude_subdirs   -> exit 0, 47/47 tests, 28254 asserts
  (test_native_fixtures: the kernels' fixtures unchanged; tests/golden untouched)
-gtest=test_rock_lurker_avatar, test_enemy_batch, test_stone_thrower_avatar, test_view_wake, test_enemy_vat,
  test_charger_avatar                                               -> exit 0, 59/59 tests, 57641 asserts
gdformat --check src scripts tests && gdlint src scripts tests      -> 1968 files unchanged; no problems found
```
The native library built with `bash scripts/native/ensure.sh` (MSVC), exit 0.

## Not run / left

- Timing: NOT YET RUN (the lead's, every kind moved).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI).
- e2e and seams: not run (the lead's, at the end).
