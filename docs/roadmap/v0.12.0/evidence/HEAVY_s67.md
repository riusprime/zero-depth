# v0.12.0 Step 67: the Star Warper into the native enemy batch

Branch `v0120-s67`, cut from `0c8a5c4a`; the step's commit `242db904`, then `lead-v0120` merged in twice: the Wire
Weaver as `9bb446bd`, the Gravity Node (`d1e848bd`) as `a26e0512`. Machine: the owner's PC (i7-10700K, RTX 3060),
Windows 11, Godot 4.7.2.stable.official.ed1daf0bf. One Godot process of this step at a time; the count of every Godot
process on the machine before each run is printed.

## What changed

- `StarWarperAvatar` joins `EnemyBatch.KINDS`. On the VAT path it reads nothing of the tree: its turn is its facing
  node's (`get_parent().rotation.y`, the batch's `Frame.facing_yaw` natively), its death's timer is the batch's
  (`EnemyBatch.drop`). Its events call `_touch`, its reads `_peek`.
- Its ground disc (`shadow`, `SoloVat.LIVE`: the one node a VAT Warper draws) hangs in the tree through `BatchHeld`
  (`BatchStarWarper.hold` / `show`, the Bomb Drone's pattern): the root's place at `EnemyBatch.origin`, copies of the
  facing and the avatar's transform, its scale from the row each frame.
- Native class 25, `STAR_WARPER` (`native/src/zd_avatar_star_warper.cpp`): its sync, frame step and pose (the hover,
  glide, turn, the tell and its break into shards, the blink's strike, the stun's reel, a hit, the death, the
  rise-in, the shards' and the visor's glows, the disc's scale) ported line by line in the GDScript's float widths.
  Its row fields are 43..85 (`SW_*`): `STRIDE` stays 124. Its 21 drives fit `MAX_DRIVES` 32. Its HP and its stun
  (`warper_stunned`) ride in the slot's first two MORE inputs (`BatchStarWarper.note`).
- Height (`HOVER_LIFT` and the lift's clips), blink and every glow unchanged. It has no variant kind
  (`EnemyAi.VARIANT_BASE` has none) and does not override `_flinch_pivot`.

## The build (after both merges)

```
GODOT="$GODOT" bash scripts/native/ensure.sh
```
Exit code 0; `build/native_build.log` shows `Compiling shared src\zd_avatar_star_warper.cpp ...`, no error.
`git diff lead-v0120 -- native/src/zd_avatar.cpp` shows only the Star Warper's five branches (15 added lines).

## The equality test (on `a26e0512`)

Godot processes before: 0.
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_star_warper.gd -gexit
```
Exit code 0.
```
    star warper states seen (actor-frames): { 0: 490, 1: 1763, 2: 710, 4: 314, 3: 46 }, { "flinched": 71, "held": 31, "killed": 5, "killed_blinking": 4, "spawned": 2, "hurt": 1644, "gliding": 1271, "turning": 1067, "striking": 396, "shards": 1283, "stunned": 168, "onto_star": 6, "dying": 322 }
Tests                 1
Passing Tests         1
Asserts             111
```
(The same numbers on `242db904` before the merges and on `9bb446bd` after the first.)

## Shown able to fail (on `242db904`)

`_turn_pose`'s `d[ROLL] += 0.1 * w * s` changed to `0.1001`, then reverted. Godot processes before: 0. Exit code 1.
```
    [Failed]:  frame 38: _looks 52|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 2 at 16: 0.5170779 vs 0.51707745
Tests                 1
Passing Tests      none
Failing Tests         1
```

## Lint

`gdformat --check src scripts tests && gdlint src scripts tests`: "2000 files would be left unchanged", "Success: no
problems found".

## Not run (owner, 2026-11-22: the lead runs everything once with every kind moved)

The twin probe, `tests/arch`, `tests/golden`, `tests/unit/native`, the avatar tests, e2e and seams: NOT YET RUN.
No timing.
