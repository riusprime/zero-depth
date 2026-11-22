# The Lens Drone into the native enemy batch (step 59)

Build SHA: the step commit `e1920b67` (parent `0fbcbb40`) merged with `lead-v0120` at `5d1ed045` (the Arc Caster); the
mutation runs were on `e1920b67`'s tree before the merge, every other run below on the merged tree before its commit
(the same files as committed; the probe prints `sha=e1920b67`, the HEAD then).
Machine: the owner's PC (i7-10700K, RTX 3060). Worktree `wt-s59`, branch `v0120-s59`. Other agents' Godot ran beside
some runs (Godot process lines by `tasklist | grep -ci godot`; one Godot run shows as 2 lines). Raw logs:
`C:/Users/extri/Desktop/zerodepth/appdata-s59/` (not tracked).

## Where the Lens Drone spawns

Only in the Hive Lens's fight: `grep -rln lens_drone data src/sim` gives `data/bosses/hive_lens.tres`,
`data/enemies/lens_drone.tres` (its definition, in no biome's roster), its pattern and death cue, and
`src/sim/ai/boss_lens.gd`. Its avatar is a solo VAT kind (`VatCrowd.KINDS`, `SoloVat`), so it is batched the same way.
It has no biome variant (no other kind's body is `LENS_DRONE`).

## What changed

- `EnemyBatch.KINDS` takes `KIND_LENS_DRONE`. On the VAT path its avatar reads nothing of the tree (its sync reads the
  state, its frame step its own clocks; it has no death, so its slot goes at once, as its node did). Its events
  `_touch()`, its reads `_peek()`.
- `ZdCrowd` runs its sync, frame step and pose (`native/src/zd_avatar_lens.cpp`: `apply_state`, `advance`, `_pose`,
  `vat_drives` with the ring's looping turn), line by line in the GDScript's float widths (doubles for its numbers;
  floats for its `_vd` and the eye's material energy; the engine's sin, `fposmod`, `move_toward`).
- Its flinch leans about its hover height (`_flinch_pivot`, 1.3 m): the native flinch took 0 for every batched kind,
  now `flinch_pivot(cls)` in `zd_avatar.cpp` (1.3 for the Lens Drone, 0 for the others: no other kind's numbers move).
- Native class 17 (`LENS_DRONE`). Its fields are 43..52 (`LD_*`): the eye's energy, state, rise, charge, lift, the
  shadow's size, whether it is the owner's model, three raw drives. `STRIDE` stays 124.
- Its soft ground shadow (a disc node under the avatar, `SoloVat.LIVE`: the one part of a VAT drone drawn as a node)
  hangs in the tree from the batch's anchor through a copy of the facing and of the avatar's transform
  (`BatchLensDrone.hold`, the pattern of `BatchWarden.hold`), so the engine draws it where it drew the node's, with the
  avatar's flinch; its size is set from the row each frame (`BatchLensDrone.show`). The anchor is physics-interpolated
  as the root was, the avatar copy not, as the avatar was not.
- GDScript: `BatchLensDrone` (`batch_lens_drone.gd`) holds the row export and import, the shadow's holder and the
  script fallback's sync; `BatchAvatars` adds the class and an `elif` in `_export_solo` / `_import_solo`. The GDScript
  stays the reference and the fallback.

## The look

- Bit for bit: `tests/unit/native/test_native_crowd_lens.gd`:
  - `test_the_native_lens_drones_draw_the_script_ones_bodies`: 12 Lens Drones round an invulnerable hero (two far out:
    the catch-up), 300 frames of 0, 1, 1, 2 ticks, reduced motion on frames 200-229, HP drops every 7 frames, hits with
    flashes, flinches, knocks, holds and tints, two spawns, a kill every 40 frames picked mid-attack when one is; the
    furniture, every VAT set's instance and drive buffers, and each drone's shadow (its transform, its holders'
    transforms, its anchor's place, shown or not) native against GDScript, equal every frame. Its print:
    `lens drone states seen (frames): { 0: 490, 1: 1685, 2: 655, 3: 204, 4: 289 }, { "flinched": 75, "held": 33, "killed": 5, "killed_attacking": 3, "shadows": 3330 }`
  - `test_the_batched_shadows_stand_where_the_nodes_ones_do`: 6 drones, a native batched view against a view of nodes
    (batching off), both stepped by hand by the same on-screen switch, flinches every 5 frames: each shadow's global
    transform and visibility equal over 120 frames. Print: `lens drone shadows compared: 720`.
  - Able to fail, then put back (`-gunit_test_name=script_ones`, exit 1 each):
    - `lens_drone_avatar.gd` bob rate `0.8` to `0.8000001`:
      `frame 1: _looks 21|00000000|0.4500|1a1a22ff|a855c8ff,7e3e96ff,5f5551ff,ff2a22ff field 2 at 7: 0.4645304 vs 0.46453044`
    - `lens_drone_avatar.gd` `_flinch_pivot` `HOVER_Y` to `HOVER_Y + 0.000001`:
      `frame 1: _looks 21|00000000|0.4500|1a1a22ff|a855c8ff,7e3e96ff,5f5551ff,ff2a22ff field 2 at 47: 0.5493423 vs 0.5493424`
  - The shadow test's first run failed (`frame 0: drone 2's shadow ... 0.562779 vs the node's 0.561282`): the test's
    fault, not the batch's: ActorViews turns a node avatar's processing back on each sync (its on-screen test), so the
    tree stepped the node drones with the real frame time. The test now takes that switch and steps them by hand.
- The twin probe (`frame_probe.gd -- --biome=night_rocks --enemies=42 --secs=20 --warm=5 --size=2560x1440
  --kinds=lens_drone --twin [--ab=no_batch]`, off screen, exit 0 both):
```
batched, native (0 Godot lines before, 4 after):
actor view nodes (last frame): total=233 direct_children=5 batched_enemies=35  Node3D=140, MeshInstance3D=70, Label3D=8, Sprite3D=8, MultiMeshInstance3D=6, OmniLight3D=1
twin: 512 frames compared, 15314 body instances, 37089 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bar_basis max 0.000000 over 0, bar_new_basis max 0.429857 over 98, bar_new_pos max 0.223106 over 72, bar_pos max 0.000002 over 0, bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.350000 over 1254, body_drives max 0.954257 over 1254, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0, disc_basis max 0.000000 over 0, disc_pos max 0.000002 over 0, ring_basis max 0.000000 over 0, ring_pos max 0.000002 over 0
nodes against nodes (--ab=no_batch, 4 / 4):
actor view nodes (last frame): total=453 direct_children=44 batched_enemies=0  Node3D=235, MeshInstance3D=196, Label3D=9, Sprite3D=9, MultiMeshInstance3D=3, OmniLight3D=1
twin: 721 frames compared, 28196 body instances, 0 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.350000 over 1735, body_drives max 0.983229 over 1735, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0
```
  Body places and bases are 0 in both. Colour and drives differ in both runs at the same rate (1254 over 512 frames,
  2.4 a frame, against 1735 over 721, 2.4 a frame) and to the same largest values (colour 0.35 in both; drives 0.95
  against 0.98), so the batched run's spread is the node views' own (the harness's tick skew between its two views:
  the eye's charge, and the ring's looping turn near its wrap, read a sync apart). I did not trace the single largest
  examples as step 56 did. Every other row is 0, under the 0.0005 tolerance, or `bar_new` (a bar's first two frames,
  kept apart by the twin on purpose). The probe does not compare the shadow node: the second equality test above does.
- The sim kernels' fixtures: no file under `src/sim/` or `tests/golden/` changed (`git diff --stat lead-v0120 --
  tests/golden` empty); `tests/golden` and `tests/unit/native` pass below.

## Timing

NOT YET RUN (measured once with every kind moved; owner, 2026-11-22, through the lead).

## Tests (merged tree; `scripts/native/ensure.sh` rebuilt the library: exit 0, no compiler warning or error)

```
-gtest=res://tests/unit/native/test_native_crowd_lens.gd (on e1920b67)   -> exit 0, 2/2 tests, 113 asserts (2 Godot lines before)
-gdir=res://tests/arch,res://tests/golden,res://tests/unit/native -ginclude_subdirs
  -gtest=test_bosses_2_views, test_lens_views, test_enemy_batch, test_enemy_vat_more, test_horde_avatars
                                                               -> exit 0, 106/106 tests, 32855 asserts (2 Godot lines before)
gdformat --check src scripts tests && gdlint src scripts tests   -> 1978 files unchanged; Success: no problems found
```
No e2e or seams (the lead runs them with every kind moved).

## Not measured / left

- The timings and the merged tree on a quiet machine: NOT YET RUN (the lead's).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI).
- The Bomb Drone (class 16, ported in parallel) has its own hover pivot (`bomb_drone_avatar.gd` `_flinch_pivot`): its
  merge adds its class to `flinch_pivot` in `zd_avatar.cpp`.
