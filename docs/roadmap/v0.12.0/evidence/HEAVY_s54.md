# The Warden (and the Rubble Warden) into the native enemy batch (step 54)

Machine: the owner's PC (i7-10700K, RTX 3060). Base `1bf5e52c` (`lead-v0120`), worktree `wt-s54`, branch `v0120-s54`;
everything below ran on the tree of this step's commit. Other agents' Godot ran beside some runs (each run's
`tasklist | grep -ci godot` before and after is given; one Godot run shows as 2 lines). No timing runs (owner: the lead
times every kind moved at once). Raw logs: `C:/Users/extri/Desktop/zerodepth/appdata-s54/` (not tracked).

## What changed

- `EnemyBatch.KINDS` takes `KIND_WARDEN` and `KIND_RUBBLE_WARDEN` (the Rubble Warden is the Warden's avatar in its
  biome's colours, already drawn by the VAT crowd: `WardenAvatar.attach` marks it VAT as a Warden).
  `ActorViews._batches` asks `VatCrowd.supports` of the body kind (`WorldReader.body_kind`), so the Rubble Warden is
  batched; no other kind changes (no other variant is in `EnemyBatch.KINDS`).
- The avatar reads nothing of the tree on the batch path: its turn rate reads its parent's (the facing's) own
  `rotation.y`, which a batched root keeps outside the tree, and its death timer is the batch's (`EnemyBatch.drop`).
  The one node a VAT Warden draws as a node, the slam's dust ring (`SoloVat.LIVE`), moved to its own class
  (`warden_dust.gd`, `WardenDust`: the same mesh, material and fade, split out of `warden_avatar.gd` by
  responsibility); for a batched Warden it hangs in the tree from the batch's anchor for it (moved and interpolated as
  the root was) through a copy of the facing's transform (interpolated as the facing was) and the avatar's transform
  (not interpolated, as the avatar was not): `batch_warden.gd`, `BatchWarden.hold/follow/show`. The Rubble Warden's
  crust (`VariantLooks.dress`, a node under the facing) hangs from the facing's copy the same way, shown by
  `VariantLooks.show_crust` on each sync as before.
- `ZdCrowd` runs the Warden's sync, frame step and pose (`native/src/zd_avatar_warden.cpp`: `apply_state`, `advance`,
  `_turning`, the dust ring's clock, `_pose` and its clips, `_body_xf`, `_reach_all`, `_reach`, `vat_drives`), line by
  line: doubles for the GDScript's floats, floats for its `_vd`, Vector2s, Vector3s and transforms, the engine's
  sin/cos/exp/acos/atan2 (`Vector2.angle`'s float atan2 as the engine's double atan2 rounded, on Windows, as `fsin`
  does). `zd_avatar.cpp` exposes AvatarBase's strike clock and tell to it (additive). The batch row grew from 113 to
  122 doubles (`BatchAvatars.STRIDE`, `zd_avatar.h`: the Warden's 23 fields, its 11 pivots and 23 drives from 43);
  its sync uses 3 of the 6 `MORE` inputs (HP, the telegraph's radius and whether it gave one) and the windup column
  (the telegraph's progress in any state, as `WardenAvatar.sync` reads it). Its row export and import are in
  `BatchWarden` (`batch_avatars.gd` keeps one-line hooks). Native class 12.
- The Warden does not use `LeggedRig` (its limbs reach through its own two-bone `_reach`), so no `zd_legged_rig` was
  ported here: that is the Needle's (step 53).

## The look

### Bit for bit (native against GDScript)

`tests/unit/native/test_native_crowd.gd` `test_the_native_wardens_draw_the_script_ones_bodies`: 12 enemies (9 Wardens,
3 Rubble Wardens; two far out, the catch-up), 300 frames of 0, 1, 1, 2 ticks, a reduced-motion stretch, hurts (the
jolt), hits with flashes, flinches, knocks, holds and tints, two spawns, a kill every 40 frames (mid-tell or mid-slam
when one is), the furniture, every VAT set's instance and drive buffers, and each Warden's dust ring and crust (shown,
global transform, colour) native against GDScript, equal every frame.
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd.gd \
  -gunit_test_name=test_the_native_wardens -gexit      -> exit 0, 1/1 passed, 110 asserts
    wardens: 300 frames, tells 541, slams 19, dust 205, walking 1168, turning 623, jolts 1211, flinches 69, holds 32, kills 5 (5 mid-attack), spawns 2, crust 620, shed 122
```
Shown able to fail (Wardens only, before the Rubble Wardens joined the test; each change put back after):
- the walk's roll `g * k * 0.045` to `0.0450001` in `warden_avatar.gd`: exit 1,
  `frame 36: _looks 3|00000000|0.4500|1a1a22ff|9a6232ff,744a26ff,6e5b53ff,ff2a22ff field 3 at 82: 0.49790558 vs 0.49790555`;
- the dust ring's clock `_dust_t += dt` to `dt * 1.0001`: exit 1, `frame 74: id 2 dust at [X: (-0.862215, ...)] vs
  [X: (-0.862228, ...)]`.

### The twin probe (batched against a node view)

`godot --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=night_rocks
--enemies=42 --secs=20 --warm=5 --size=1920x1080 --kinds=<kinds> --twin [--ab=no_batch]`. `batch_twin.gd` now also
compares a Warden's dust ring (shown, interpolated global transform, colour) and a Rubble Warden's crust.
```
--kinds=warden, batched native (Godot lines before / after each run in brackets)
  native   (4 / 2):  twin: 711 frames compared, 27593 body instances, 71323 furniture instances
    bar_basis 0, bar_pos 0.000002 over 0, bodies_drawn 0, body_basis 0, body_color max 0.966838 over 183, body_drives max 2.578234 over 2729,
    body_pos max 0.074031 over 2049, chunks_drawn 0, disc_basis 0, disc_pos 0.000002 over 0, dust_basis 0, dust_color 0,
    dust_pos max 0.027708 over 89, dust_shown over 279, ring_basis 0, ring_pos 0.000002 over 0 (bar_new: a bar's first frames, apart on purpose)
  native2  (2 / 2):  twin: 509 frames, 18815 body instances, 48007 furniture instances
    body_color max 0.696429 over 115, body_drives max 1.857143 over 1168, body_pos max 0.067919 over 783,
    dust_pos max 0.052371 over 42, dust_shown over 199, every other row 0 or under 0.0005
nodes against nodes (--ab=no_batch, the harness's own spread)
  nobatch  (2 / 0):  twin: 818 frames, 31943 body instances
    body_color max 0.964609 over 198, body_drives max 2.572292 over 2169, body_pos max 0.078078 over 1758,
    dust_basis 0, dust_color 0, dust_pos max 0.055835 over 94, dust_shown over 277
  nobatch2 (2 / 2):  twin: 786 frames, 30788 body instances
    body_color max 0.967646 over 184, body_drives max 2.580389 over 2258, body_pos max 0.075326 over 1961,
    dust_pos max 0.090768 over 101, dust_shown over 277
--kinds=warden,rubble_warden
  native   (4 / 4):  twin: 734 frames, 28585 body instances, 90073 furniture instances
    body_color max 0.955110 over 177, body_drives max 2.546960 over 2251, body_pos max 0.073321 over 1802, crust_basis 0,
    crust_pos max 0.291630 over 12839, dust_pos max 0.027039 over 28, dust_shown over 275, disc/ring/bar 0.000002 or 0
  no_batch (4 / 0):  twin: 707 frames, 27243 body instances
    body_color max 0.965445 over 180, body_drives max 2.574520 over 2416, body_pos max 0.077794 over 2015, crust_basis 0,
    crust_pos max 0.236790 over 13360, dust_pos max 0.039568 over 67, dust_shown over 280
```
Reading: every row the batch adds a difference to is at the nodes-against-nodes floor, on as many frames for as many
compared. The Warden's floor is far larger than the Stone Thrower's (body_drives 2.57 against 0.70): its slam is one
tick ACTIVE, which the live views read through their latched reader (`LatchedReader`: a one-tick ACTIVE is shown to the
next sync) and the twin may not, so one view starts the slam (`strike 0.05 vs -1.0` in the examples) and its pose,
glow, lift and dust ring a frame or more before the other, whether the Warden is batched or not. The crust's position
differs on most frames between two node views too (the twin's roots are not started from the tick before, as the live
ones are). Disc, ring, bar, the bodies' bases and the dust's basis and colour: 0 or under 0.0005.

## Tests (the new library built: `bash scripts/native/build.sh debug`, exit 0, no warning from the new file)

On the step's own commit (parent `1bf5e52c`):
```
-gtest=test_warden_avatar, test_warden_views, test_twin_warden_views, test_melee_strikes, test_enemy_vat_more,
  test_enemy_vat, test_enemy_batch, test_view_wake, test_shader_warmup, test_damage_flash, test_enemy_shadows,
  test_rig_merge, test_variant_views, test_enemy_versions, test_spawn_reuse, test_telegraph_parity, test_windup_tells,
  test_stone_thrower_avatar, test_charger_avatar, test_enemy_palettes (tests/unit/presentation)
  + -gdir=tests/arch,tests/golden,tests/unit/native -ginclude_subdirs   (one process)
                                                         -> exit 0, 31 scripts, 201/201 tests, 93394 asserts
  (test_native_fixtures: the kernels' fixtures unchanged; native_kernels_hash.txt untouched)
gdformat --check src scripts tests                       -> 1969 files would be left unchanged
gdlint src scripts tests                                 -> Success: no problems found
```
After merging `lead-v0120` (the Needle and the Rock Lurker): see the merge section below.

## Not done / left

- Timing (the 42-Warden fight, before and after): NOT YET RUN (owner: the lead times every kind moved at once).
- Linux (gcc) equality of the new native code (`::atan2f` there, as the engine's): NOT YET RUN (CI).
- e2e and seams: NOT YET RUN (the lead's, at the end).
