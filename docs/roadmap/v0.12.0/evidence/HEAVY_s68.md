# The held parts and the shared files' split (step 68)

Branch `v0120-s68`, from `828760f6`. Owner's PC (i7-10700K, RTX 3060); one other agent ran Godot at the same time.
No timing was taken (the owner: one before/after with every kind moved).

## 1. The shared files' split (commit `8cb7b329`, then the merge `ee706045`)

`batch_avatars.gd` was 986 lines (1,020 on `lead-v0120` with the Scrap Hound and the Kiln Beetle). It is split by
responsibility, with the same statements in the same order:
- `batch_avatars.gd` (545 lines after the merge): the slots' bookkeeping, the sync inputs and the native calls.
- `batch_rows.gd`, `BatchRows` (410): the rows' layout (the `zd_avatar.h` field numbers, `STRIDE`), the row array the
  native calls take and give back, and the copies between a row and its avatar's fields (AvatarBase's, HordeAvatar's,
  ChargerAvatar's, StoneThrowerAvatar's here; the solo kinds' through their row files: `_export_solo`/`_import_solo`).
- `batch_script_sync.gd`, `BatchScriptSync` (120): the GDScript fallback's per-class sync, used when the rows are
  turned off with syncs pending.

The merge of `lead-v0120` (`8cacd12d`) put the Scrap Hound's and the Kiln Beetle's row copies into `BatchRows` and
their fallback syncs into `BatchScriptSync`. `BatchScrapHound.apply_in_script` read BatchAvatars' private columns. It
now takes the noted inputs `(a, tick, pos, state, windup, more, o)`, as the other kinds' do, and passes the same values
to the same `apply_state`.

The library copied from the main checkout (Nov 20) was older than `828760f6` (`apply_sync`: "Expected 12
argument(s)"). It was rebuilt from the tree: `bash scripts/native/ensure.sh`, exit 0, on the split and again on the
merge. `native/` is unchanged by this step.

Tests on `8cb7b329`, one process each:
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/native -gtest=<T>/test_warden_avatar.gd,<T>/test_warden_views.gd,<T>/test_twin_warden_views.gd,<T>/test_lens_views.gd,<T>/test_bomb_drone_avatar.gd,<T>/test_enemy_batch.gd,<T>/test_view_wake.gd -gexit
exit=0  Scripts 17  Tests 119  Passing Tests 119  Asserts 56253
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
exit=0  Scripts 5  Tests 13  Passing Tests 13  Asserts 27360
```
On `ee706045` (the same list, plus `test_scrap_hound_avatar.gd` and `test_kiln_beetle_avatar.gd`; `tests/unit/native`
now holds the Scrap Hound's and the Kiln Beetle's crowd tests):
```
exit=0  Scripts 21  Tests 144  Passing Tests 144  Asserts 57701
tests/arch + tests/golden: exit=0  Scripts 5  Tests 13  Passing Tests 13
```

## 2. The held parts

### The twin probe, before (on `ee706045`: every part on the batch's anchor except the Bomb Drone's disc)

```
bash twin.sh <tag> <biome> <kinds> [ab]  # runs:
"$GODOT" --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=<biome> --enemies=42 --secs=20 --warm=5 --size=2560x1440 --kinds=<kinds> --twin [--ab=no_batch]
```
`batch_twin.gd` gained a `lens_shadow` row: the Lens Drone's ground shadow, whether it shows and its interpolated global
transform (place and basis). It shares one function, `_held_part`, with the Bomb Drone's `ground_disc` row.

The Godot process counts (`tasklist | grep -ci godot`, before / after each run) printed `0/0` on several runs while
Godot was running. Those counts are wrong; the printed values are kept as they came.

| Run (sha `ee706045`) | Godot before/after | Frames, bodies | The part's rows |
|---|---|---|---|
| `night_rocks`, `lens_drone`, batched | 0/0 | 664, 24880 | `lens_shadow_pos` max 0.207471 over 15109; `lens_shadow_basis` max 0.035462 over 42 (frame 1, every drone) |
| `night_rocks`, `lens_drone`, `--ab=no_batch` | 0/0 | 702, 25270 | `lens_shadow_pos` max 0.168148 over 13757; `lens_shadow_basis` 0 over 0 |
| `ruins`, `warden,rubble_warden`, batched | 0/0 | 727, 28915 | `crust_pos` max 0.117732 over 13007; `crust_basis` 0; `dust_pos` max 0.059894 over 111; `dust_basis` 0; `dust_color` 0; `dust_shown` over 401 |

No Warden nodes-against-nodes run was made this step (the owner: the fewest runs). HEAVY_s54's is the floor, at
1920x1080 on night_rocks: `crust_pos` max 0.236790 over 13360, `dust_pos` max 0.039568 over 67, `dust_shown` over 280.

An earlier pair on `8cb7b329` (the split alone) read the same: batched `lens_shadow_pos` 0.186163 over 16072,
`lens_shadow_basis` 0.035462 over 42; no_batch `lens_shadow_pos` 0.171771 over 14204 (Godot 4/2 and 2/0).

Reading: the nodes-against-nodes rows are not a floor the batch must sit on. The twin's node parts are where the engine
draws a node part. On the anchor, the batch's parts sit a part of a tick from them, and so do the live node view's
parts (the live roots are started from the tick before). The Bomb Drone's disc, held at `EnemyBatch.origin`, measured
0.000002.

### The change

`BatchHeld` (`batch_held.gd`) is the one holder all three kinds use: the Bomb Drone's, moved out of
`BatchBombDrone`:
- a node at the root's place, not interpolated, put each frame (and after each sync's flush) at `EnemyBatch.origin`;
- a copy of the facing, interpolated;
- a copy of the avatar's transform, not interpolated.

The parts hang from it:
- the Warden's dust ring and the Lens Drone's shadow from the avatar's copy, as the disc does;
- the Rubble Warden's crust from the facing's copy.

`BatchWarden.follow` became `BatchHeld.follow`. EnemyBatch frees every holder's place node with its slot. The Lens
Drone's shadow is also sized from the row after each sync's flush, as the Bomb Drone's disc already was: that fixes
the frame-1 `lens_shadow_basis`. The batch's anchor stays for the status marks.

### After (working tree on `ee706045`, before its commit)

| Run | Godot before/after | Frames, bodies | The part's rows |
|---|---|---|---|
| `night_rocks`, `lens_drone`, batched | 0/2 | 514, 16778 | `lens_shadow_pos` max 0.000002 over 0; `lens_shadow_basis` 0 over 0 |
| `ruins`, `warden,rubble_warden`, batched | 2/2 | 588, 21356 | `crust_pos` max 0.000001 over 0; `crust_basis` 0; `dust_pos` max 0.038584 over 3; `dust_basis` 0; `dust_color` 0; `dust_shown` over 338 |

In both runs every other row is 0 or under 0.0005, except the ones apart on purpose or at the harness's spread:
- `bar_new_*` (a bar's first frames);
- `body_color`/`body_drives`/`body_pos`: the Warden's one-tick slam, HEAVY_s54; the Lens Drone's eye, HEAVY_s59.

The remaining `dust_shown` and its 3 `dust_pos` frames are the slam started a frame apart between the two views
(HEAVY_s54's reading: its one-tick ACTIVE, which the live views read through their latched reader and the twin may
not). The first examples: `frame 29 dust_shown id 42 batch true twin false`, the same frame as `body_drives ... strike
0.1 0.05 vs -1.0 -1.0`.

Each run also printed 4 engine `ERROR` lines at exit (leaked RIDs and resources at quit), before and after alike.

### Tests (after the change)

```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<N>/test_native_crowd.gd,<N>/test_native_crowd_lens.gd,<N>/test_native_crowd_bomb_drone.gd,<T>/test_warden_avatar.gd,<T>/test_warden_views.gd,<T>/test_twin_warden_views.gd,<T>/test_lens_views.gd,<T>/test_bomb_drone_avatar.gd,<T>/test_enemy_batch.gd,<T>/test_view_wake.gd -gexit
exit=1  Scripts 10  Tests 90  Passing Tests 89  Failing Tests 1
[Failed]: frame 36: drone 2's shadow [[X: (-0.648561, 0.0, -0.005969), Y: (0.0, 1.0, 0.0), Z: (0.005969, 0.0, -0.648561), O: (4.0, 0.012, 0.0)], true] vs the node's [[X: (-0.648561, 0.0, -0.005969), Y: (0.0, 1.0, 0.0), Z: (0.005969, 0.0, -0.648561), O: (4.0, 0.012, 0.034)], true]
```
`test_the_batched_shadows_stand_where_the_nodes_ones_do` compared the batched shadow's global transform, not
interpolated, with a hand-stepped node view's. That holds only for the anchor, whose un-interpolated place is the
root's latest. The shadow now hangs from `EnemyBatch.origin`.

Two other criteria were tried first and failed, because the hand-stepped node view's interpolation does not run as
the game's does:
- the interpolated global transforms on both sides failed at frame 0, the shadow's scale;
- the node root's interpolated offset failed at frame 36 again: the hand-stepped root draws at its raw place.

The test now takes the node's shadow transform to the batch's `origin` and compares the rest: the facing and avatar
copies, the size and the lean, and whether it shows. That the place equals the engine's drawn root is the twin
probe's proof (`lens_shadow_pos` 0.000002 above). The test's comment says so.
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_lens.gd -gexit
exit=0  Tests 2  Passing Tests 2   (lens drone shadows compared: 720)
```
After merging `lead-v0120` at `75a5fa97` (the Cinder Priest, whose row lines were already in BatchRows and
BatchScriptSync), the library was rebuilt (`ensure.sh`, exit 0) and the ten files above ran again:
```
exit=0  Scripts 10  Tests 90  Passing Tests 90  Asserts 55320
```
Lint (`gdformat --check src scripts tests && gdlint src scripts tests`): clean.
