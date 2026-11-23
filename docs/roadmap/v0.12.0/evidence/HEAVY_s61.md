# v0.12.0 Step 61: the Kiln Beetle into the native enemy batch

Owner's PC (i7-10700K, RTX 3060), worktree `wt-s61`. Step commit `41a11f0b` (parent `21c95adf`), then merged with
`lead-v0120` at `4a1bd835` (the Bomb Drone and the Scrap Hound); the tests below ran on the merged tree, the library rebuilt.
No timing runs (the lead measures once with every kind moved).

## What moved
- `KilnBeetleAvatar` joins `EnemyBatch.KINDS`. On the VAT path it read nothing of the tree but its facing node's
  turn (`get_parent().rotation.y`, the facing copy the batch keeps), and its death's timer is the batch's `drop`
  (`DEATH_SECONDS`). It gained `_touch` / `_peek` only.
- Native class 19 (`KILN_BEETLE`), `native/src/zd_avatar_kiln_beetle.cpp`: `apply_state`, `advance`, `_turning`, `_pose`
  and every clip, `leg_cycle`, the heat and visor glows, ported line by line in the GDScript's float widths. Row fields
  43..100 (`BatchKilnBeetle`); STRIDE stays 124. `MAX_DRIVES` grows from 29 to 32 (the beetle's 32 drives; the
  native writer's drive buffer). Its HP and full HP ride in the slot's MORE inputs (0, 1).
- Glows: the heat glow is the instance's accent glow and the visor the flat VISOR drive, as on the node path; the
  materials still take the same energies on import. A VAT beetle builds no node (setup returns before the rig), so there
  is no node part to hang. No variant kind uses this avatar.

## Proofs
- Equality test: `"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/native -ginclude_subdirs -gexit`
  (test_native_crowd_kiln_beetle among them): every drawn buffer of a native view against a GDScript one, 300 frames,
  0/1/2-tick frames, hits, flinches, holds, tints, spawns at 90 and 190, kills (5, 3 mid-attack), reduced motion
  frames 200..229, two far-off slots.
```
    beetle states seen (actor-frames): { 0: 560, 1: 1868, 2: 321, 3: 5, 4: 299 }; kills 5 (3 mid-attack)
Scripts              12
Tests                43
Passing Tests        43
Asserts            1896
```
  exit 0.
- Shown able to fail (before the merge): `_heat_pose`'s `0.02 * pow(h, 1.5)` changed to `0.0201` in the GDScript only,
  the test then failed (exit 1), reverted:
```
[Failed]:  frame 4: _looks 48|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 3 at 309: 0.33547792 vs 0.33556736
```
- Twin probe: `frame_probe.gd -- --biome=night_rocks --enemies=42 --secs=20 --warm=5 --size=2560x1440 --kinds=kiln_beetle --twin [--ab=no_batch]`,
  off screen, exit 0 each. Godot processes on the machine (`tasklist | grep -ci godot`) before / after: 4 / 4 (batched),
  4 / 2 (nodes against nodes), 2 / 4 (batched, merged tree).
```
batched, native (before the merge):
actor view nodes (last frame): total=98 direct_children=5 batched_enemies=37  Node3D=43, MeshInstance3D=34, Label3D=7, Sprite3D=7, MultiMeshInstance3D=6, OmniLight3D=1
twin: 737 frames compared, 26290 body instances, 62905 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bar_basis max 0.000000 over 0, bar_new_basis max 0.682032 over 110, bar_new_pos max 0.074012 over 99, bar_pos max 0.000001 over 0, bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.000000 over 0, body_drives max 0.000000 over 0, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0, disc_basis max 0.000000 over 0, disc_pos max 0.000001 over 0, ring_basis max 0.000000 over 0, ring_pos max 0.000001 over 0
nodes against nodes (--ab=no_batch):
actor view nodes (last frame): total=169 direct_children=16 batched_enemies=0  Node3D=90, MeshInstance3D=67, Label3D=4, Sprite3D=4, MultiMeshInstance3D=3, OmniLight3D=1
twin: 836 frames compared, 30367 body instances, 0 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.000000 over 0, body_drives max 0.000000 over 0, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0
batched, native (merged tree):
actor view nodes (last frame): total=96 direct_children=5 batched_enemies=32  Node3D=44, MeshInstance3D=33, MultiMeshInstance3D=6, Label3D=6, Sprite3D=6, OmniLight3D=1
twin: 605 frames compared, 21481 body instances, 51960 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bar_basis max 0.000000 over 0, bar_new_basis max 0.689968 over 104, bar_new_pos max 0.072969 over 97, bar_pos max 0.000002 over 0, bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.000000 over 0, body_drives max 0.000000 over 0, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0, disc_basis max 0.000000 over 0, disc_pos max 0.000002 over 0, ring_basis max 0.000000 over 0, ring_pos max 0.000002 over 0
```
  The batched spread is 0 on every body row, as is the nodes-against-nodes floor; `bar_new` is a bar's first two
  frames, kept apart by the twin on purpose.
- `tests/arch` (3 scripts, 8/8, exit 0) and `tests/golden` (2 scripts, 5/5, exit 0, the native kernel fixtures
  unmoved; no file under `src/sim/` or `tests/golden/` changed).
- Lint: `gdformat --check src scripts tests` clean; `gdlint src scripts tests` clean before the merge. After the merge
  gdlint reports `batch_avatars.gd:1020: max-file-lines`: the three kinds' dispatch lines together pass the cap; the
  lead's step 68 splits that file (lead's instruction: not split here).
