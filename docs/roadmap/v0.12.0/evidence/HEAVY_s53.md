# The Needle into the native enemy batch (step 53)

Build SHA: base `5fae8de9` plus this commit's tree (the runs were on the uncommitted worktree, the same files as committed).
Machine: the owner's PC (i7-10700K, RTX 3060). Base `5fae8de9` (`lead-v0120`), worktree `wt-s53`, branch `v0120-s53`.
Other agents' and the lead's Godot ran beside these runs (Godot process counts are by `tasklist | grep -ci godot`;
one Godot run shows as 2 lines). Raw logs: `C:/Users/extri/Desktop/zerodepth/appdata-s53/` (not tracked).

## What changed

- `EnemyBatch.KINDS` takes `KIND_NEEDLE`. Its avatar reads nothing of the tree on the VAT path: its turn is its facing
  node's `rotation.y` (a plain object's, set by `EnemyBatch.update`), its glows its own materials, its death timer the
  batch's (`DEATH_SECONDS`), its pose its own clocks and the sim's state. Its root, facing and avatar leave the tree;
  its disc, ring and bar become the batch's instances.
- `ZdCrowd` runs the Needle's sync, frame step and pose (`native/src/zd_avatar_needle.cpp`: `apply_state`, `advance`,
  `_pose` and its clips, `_body_xf`, `_gem`, `_muzzle`, `vat_drives`), line by line in the GDScript's float widths
  (doubles for its floats; floats for its `_vd` with every `+=` rounded back, its `_foot` and `_dir`, its transforms;
  the engine's sin, cos, atan2 and acos). `LeggedRig`'s reach, stride cycle, clip clock, scan, twitch, replant, hash
  and turn rate are ported on their own, with nothing of the Needle in them (`native/src/zd_legged_rig.{h,cpp}`).
- The native class is 11 (`NEEDLE`). The row grows from 113 to 124 doubles (`STRIDE`): the Needle's 25 state fields
  and 20 raw drives from 43 to 87, then its legs' rest hips, knees and feet (36 floats, set once: they depend on the
  model's scale) to 123. `apply_sync`'s `in_more` carries its HP (its first value): the flinch on a hit reads it.
- GDScript: `BatchNeedleRow` (`batch_needle_row.gd`) holds the Needle's row export and import; `BatchAvatars` adds the
  class, the HP input and the script fallback's sync; the avatar's events `_touch()` and its reads `_peek()`. The
  GDScript stays the reference and the fallback.
- The Dim Needle (Night Rocks' variant) uses `NeedleAvatar` but is not on the VAT path (`VatCrowd.supports` takes base
  kinds only: a variant draws on its own nodes), so the batch, which draws through VatCrowd, cannot take it. Moving it
  to VAT would change how it is drawn; not done (PRESENTATION_CONTRACTS §11.3 row added).

## The look

- Bit for bit: `tests/unit/native/test_native_crowd.gd` `test_the_native_needles_draw_the_script_ones_bodies`:
  14 Needles round an invulnerable hero (two far out: the catch-up), 300 frames of 0, 1, 1, 2 ticks, a reduced-motion
  stretch (frames 200-229), HP drops every 7 frames (the hit flinch from the sync), hits with flashes, flinches,
  knocks, holds and tints, two spawns, a kill every 40 frames picked mid-attack (windup or burst) when one is; the
  furniture and every VAT set's instance and drive buffers native against GDScript, equal every frame. It asserts
  windups and bursts were compared, a kill mid-attack, flinches > 10, holds > 3.
  - Run (the whole file, 7 tests): exit 0, `7/7 passed`, 340 asserts.
  - Able to fail, then put back (`-gunit_test_name=needles`, exit 1 each):
    - `needle_avatar.gd` walk roll `0.045` to `0.0450001`:
      `frame 36: _looks 4|...|3a6bd4ff,2a50a0ff,5f5551ff,ff2a22ff field 3 at 37: 0.46524256 vs 0.46524253`
    - `legged_rig.gd` reach `(a + b) * 0.998` to `0.9980001`:
      `frame 4: _looks 4|...|3a6bd4ff,2a50a0ff,5f5551ff,ff2a22ff field 3 at 68: 0.5772066 vs 0.5772061`
- The twin probe (`frame_probe.gd -- --biome=night_rocks --enemies=42 --secs=20 --warm=5 --size=2560x1440
  --kinds=needle --twin`, off screen):
```
batched, native (4 / 4 Godot lines):
twin: 789 frames compared, 30341 body instances, 74260 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bar_basis max 0.000000 over 0, bar_new_basis max 0.541451 over 108, bar_new_pos max 0.155674 over 86, bar_pos max 0.000002 over 0, bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 3.475580 over 462, body_drives max 3.464782 over 2210, body_pos max 0.013442 over 1282, chunks_drawn max 0.000000 over 0, disc_basis max 0.000000 over 0, disc_pos max 0.000002 over 0, ring_basis max 0.000000 over 0, ring_pos max 0.000002 over 0
nodes against nodes (--ab=no_batch, 4 / 4):
twin: 901 frames compared, 33579 body instances, 0 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 3.556963 over 510, body_drives max 3.497749 over 2564, body_pos max 0.013537 over 1462, chunks_drawn max 0.000000 over 0
```
  The body rows are the harness's own spread for this kind: two node views of Needles differ by as much (3.50 drives,
  3.56 colour, 0.0135 m) with no batch at all, and
  the batched run sits at or under it (3.46, 3.48, 0.0134; 2210 over 789 frames against 2564 over 901). The examples
  in both logs are the same pair at the same clock (`t 1.4014 vs 1.4014`, a body's lift 0.0006 m apart): two views
  built at different moments. `bar_new` is a bar's first two frames shown, kept apart by the twin on purpose
  (`batch_twin.gd`). Every other row is 0 or under the 0.0005 tolerance. Both runs exit 0 (the no-batch one prints the
  engine's usual leak lines at exit).
- The sim kernels' fixtures: `tests/golden` and `tests/unit/native` (`test_native_fixtures`) below;
  `tests/golden/fixtures/native_kernels_hash.txt` untouched (no sim file changed).

## Timing

NOT YET RUN (measured once with every kind moved; owner, 2026-11-22, through the lead: "let's do the test when all are
moved").

## Tests (the new library built: `bash scripts/native/build.sh debug`, exit 0; then `scripts/native/ensure.sh`, exit 0)

```
-gtest= the Needle's and the batch's presentation files (22: test_needle_avatar, test_enemy_batch, test_enemy_vat,
  test_enemy_vat_more, test_view_wake, test_stone_thrower_avatar, test_charger_avatar, test_sniper_avatar,
  test_mine_layer_model, test_damage_flash, test_enemy_versions, test_spawn_reuse, test_windup_tells,
  test_crowd_view, test_enemy_shadows, test_hit_impact, test_screen_cull, test_telegraph_parity, test_variant_views,
  test_enemy_palettes, test_enemy_fireball_views, test_boss_challenge_views)
                                                     -> exit 0, 180/180 tests, 80354 asserts (Godot 2 / 4)
-gdir=tests/arch,tests/golden,tests/unit/native -ginclude_subdirs
                                                     -> exit 0, 47/47 tests, 28252 asserts (Godot 4 / 6)
gdformat --check src scripts tests && gdlint src scripts tests   -> 1968 unchanged; no problems
```
No e2e run (owner, through the lead: the lead runs the seams once every kind is moved).

## Not measured / left

- The timings above, and the merged tree on a quiet machine: NOT YET RUN (the lead's).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI). The float atan2 (`rig::angle`) takes the engine's
  double function rounded on Windows and the system's `atan2f` elsewhere, as `fsin`/`fcos` do; the equality test on
  Linux is what proves that choice there.
- The Dim Needle stays on its nodes (above).
