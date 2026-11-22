# v0.12.0 Step 66: the Wire Weaver into the native enemy batch

Branch `v0120-s66`, cut from `0d589730`. Machine: the owner's PC (i7-10700K, RTX 3060), Windows 11, Godot
4.7.2.stable.official.ed1daf0bf. One Godot process of this step at a time; the count before each run is printed.

## What changed

- `WireWeaverAvatar` joins `EnemyBatch.KINDS`. On the VAT path it reads nothing of the tree: its turn and its walk's
  heading are its facing node's (`get_parent().rotation.y`, the batch's `Frame.facing_yaw` natively), its death's timer
  is the batch's (`EnemyBatch.drop`). Its events and reads go through `_touch` / `_peek` like the other batched kinds
  (`carrying`, `vat_drives` and `glow_energy` read through `drives()` / `spark_energy()`, which peek, so the file stays
  at the 1,000-line cap with the same results). Nothing of its clips, glows, materials or nodes changed.
- It has no variant kind. A VAT Weaver has no node part: its two carried posts are joints of its VAT rig (POST0..
  drives), its post tops' glow is the instance's accent glow and its visor's the flat VISOR drive, as before.
- The planted posts and the cables are not the Weaver's avatar and are untouched: a planted post (`KIND_WIRE_POST`) is
  a `RuinsRocksAvatar`, a code-made node body (boxes, a rod, a glowing top; no VAT, no model), and the cable between
  two posts is a `MeshInstance3D` line per live cable in `RuinsRocksViews._sync_cables` (with the pack's storm spark).
  Neither is a solo-VAT avatar with a node tree, so there was nothing to report or move there.
- Native class 24, `WIRE_WEAVER` (`native/src/zd_avatar_wire_weaver.cpp`): its sync, frame step and pose (the gait,
  idle, tell, plant and reload, hurt, rise-in, death, the drum's turn, the post tops' and the visor's glows) ported line
  by line in the GDScript's float widths. Its row fields are 43..94 (`WW_*`), so `STRIDE` stays 124; its 31 drives fit
  `MAX_DRIVES` 32. Its HP rides in the slot's first MORE input.
- `BatchWireWeaver` (`batch_wire_weaver.gd`) holds its row copy and its GDScript-path sync; `BatchRows`,
  `BatchScriptSync`, `BatchAvatars`, `EnemyBatch.KINDS` and `zd_avatar.{h,cpp}` get one additive branch each (the
  dispatch lines only in `zd_avatar.cpp`).
- `tests/unit/native/test_native_crowd_wire_weaver.gd`: every drawn buffer of 14+2 Weavers, native against GDScript,
  over 300 frames (the Frost Spitter's test on the Weaver's kind, through `CrowdTwins`).

## The build

```
GODOT="$GODOT" bash scripts/native/ensure.sh
```
Exit code 0 (`build/native_build.log`: `Compiling shared src\zd_avatar_wire_weaver.cpp ...`, the debug library
linked; imported).

## The equality test (on `0d589730` + this step)

Godot processes before: 0.
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_wire_weaver.gd -gexit
```
Exit code 0. Raw output (colour codes stripped):
```
res://tests/unit/native/test_native_crowd_wire_weaver.gd
* test_the_native_wire_weavers_draw_the_script_ones_bodies
    weaver states seen (actor-frames): { 0: 560, 1: 2448, 2: 552, 4: 363 }; kills 5 (3 mid-attack)
1/1 passed.
Totals
------
Scripts               1
Tests                 1
Passing Tests         1
Asserts             107
Time              3.066s
---- All tests passed! ----
```
Spawn 0, move 1, windup 2 and recover 4 seen; the Weaver's ACTIVE (3) lasts a tick and falls between the test's
syncs, so the plant starts from the recover-after-windup path (`skipped` in `apply_state`), which the failure below
shows is exercised. Kills mid-attack, spawns, hits, flinches, holds and a stretch of reduced motion, all compared bit
for bit; `a.batch.avatars.on` true (the native class ran).

## Shown able to fail

A tiny change to the GDScript reference's plant clip (`_plant_pose`: `d[POST0 + 3 * q + 1] = 0.35 + 0.8 * fly +
0.00001`), the same command, Godot processes before: 0. Exit code 1:
```
* test_the_native_wire_weavers_draw_the_script_ones_bodies
    [Failed]:  frame 80: _looks 43|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 3 at 21: 0.6836288 vs 0.6836326
      at line 109
0/1 passed.
```
Reverted (the file copied back; `git diff` holds no `0.00001`).

## Lint

```
gdformat --check src scripts tests && gdlint src scripts tests
```
gdformat: `1993 files would be left unchanged`. gdlint: `Success: no problems found` (exit 0).

## Not run here

Per the owner (2026-11-22: the tests run once with every kind moved), these are left to the lead:
- the twin probe (`frame_probe.gd -- --twin`): NOT YET RUN (run once with every kind moved)
- `tests/arch`, `tests/golden` (the sim kernels' fixtures, `native_kernels_hash.txt`, `DETERMINISM_PROBE`), the rest of
  `tests/unit/native`, `tests/unit/presentation/test_wire_weaver_avatar.gd` and the e2e: NOT YET RUN (run once with
  every kind moved). The sim and its kernels are untouched (`git diff 0d589730 -- src/sim native/src/zd_ai*
  native/src/zd_collide* native/src/zd_strike* native/src/zd_shots* native/src/zd_nav* native/src/zd_world*` is
  empty).
- timing: none (owner: the lead measures once with every kind moved).
