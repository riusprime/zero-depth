# v0.12.0 Step 63: the Frost Spitter into the native enemy batch

Branch `v0120-s63`, cut from `cc740a31`. Machine: the owner's PC (i7-10700K, RTX 3060), Windows 11, Godot
4.7.2.stable.official.ed1daf0bf. One Godot process of this step at a time; the count before each run is printed.

## What changed

- `FrostSpitterAvatar` joins `EnemyBatch.KINDS`. On the VAT path it reads nothing of the tree: its turn is its facing
  node's (`get_parent().rotation.y`, the batch's `Frame.facing_yaw` natively), its death's timer is the batch's
  (`EnemyBatch.drop`). It has no variant kind and no node-drawn part on the VAT path (the sac's and the visor's glows
  are the instance's accent glow and its flat VISOR drive, as before); nothing of its frost, glow or nodes changed.
- Native class 21, `FROST_SPITTER` (`native/src/zd_avatar_frost_spitter.cpp`): its sync, frame step and pose (the
  clips, the legs' reach, the glows) ported line by line in the GDScript's float widths. Its row fields are 43..119
  (`FS_*`), so `STRIDE` stays 124; its 22 drives fit `MAX_DRIVES` 32. Its HP rides in the slot's first MORE input.
- `BatchFrostSpitter` (`batch_frost_spitter.gd`) holds its row copy and its GDScript-path sync; `BatchRows`,
  `BatchScriptSync`, `BatchAvatars` and `zd_avatar.{h,cpp}` get one additive branch each.
- `tests/unit/native/test_native_crowd_frost_spitter.gd`: every drawn buffer of 14+2 spitters, native against
  GDScript, over 300 frames.

## The build

```
GODOT="$GODOT" bash scripts/native/ensure.sh
```
Exit code 0 (the debug library rebuilt with `zd_avatar_frost_spitter.cpp`, imported twice).

## The equality test (on `cc740a31` + this step)

Godot processes before: 0.
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_frost_spitter.gd -gexit
```
Exit code 0. Raw output (colour codes stripped):
```
res://tests/unit/native/test_native_crowd_frost_spitter.gd
* test_the_native_frost_spitters_draw_the_script_ones_bodies
    spitter states seen (actor-frames): { 0: 560, 1: 1909, 2: 902, 3: 105, 4: 447 }; kills 5 (3 mid-attack)
1/1 passed.
Totals
------
Scripts               1
Tests                 1
Passing Tests         1
Asserts             107
Time              2.395s
---- All tests passed! ----
```
Every state seen (spawn 0, move 1, windup 2, active 3, recover 4), kills mid-attack, spawns, hits, flinches, holds and
a stretch of reduced motion, all compared bit for bit; `a.batch.avatars.on` true (the native class ran).

## Shown able to fail

A tiny change to the GDScript reference (`_reach`: `d[LEG0 + 3 * j] = yaw + 0.00001`), the same command, Godot
processes before: 0. Exit code 1:
```
* test_the_native_frost_spitters_draw_the_script_ones_bodies
    [Failed]:  frame 0: _looks 50|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 3 at 5: 0.4520244 vs 0.45203152
      at line 109
0/1 passed.
Passing Tests      none
Failing Tests         1
Asserts             0/1
```
Reverted (the file copied back; `git diff` holds no `0.00001`).

## Lint

```
gdformat --check src scripts tests && gdlint src scripts tests
```
gdformat: `1988 files would be left unchanged` (exit 0). gdlint: `Success: no problems found` (exit 0).

## Not run here

Per the owner (2026-11-22: the tests run once with every kind moved), these are left to the lead:
- the twin probe (`frame_probe.gd -- --twin`): NOT YET RUN (run once with every kind moved)
- `tests/arch`, `tests/golden` (the sim kernels' fixtures, `native_kernels_hash.txt`, `DETERMINISM_PROBE`), the rest of
  `tests/unit/native` and the avatar test files: NOT YET RUN (run once with every kind moved). The sim and its kernels
  are untouched (`git diff cc740a31 -- src/sim native/src/zd_ai* native/src/zd_collide* native/src/zd_strike*
  native/src/zd_shots* native/src/zd_nav* native/src/zd_world*` is empty).
- timing: none (owner: the lead measures once with every kind moved).
