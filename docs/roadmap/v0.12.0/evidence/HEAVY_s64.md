# v0.12.0 Step 64: the Glacier Turtle into the native enemy batch

Branch `v0120-s64`, cut from `75a5fa97`; the step's commit `bd30583e`, then `lead-v0120` (`0d589730`: step 68's
`BatchHeld`, the Frost Spitter) merged in as `3951f678`. Machine: the owner's PC (i7-10700K, RTX 3060), Windows 11,
Godot 4.7.2.stable.official.ed1daf0bf. One Godot process of this step at a time; the count of every Godot process on
the machine before each run is printed (the others are other agents').

## What changed

- `GlacierTurtleAvatar` joins `EnemyBatch.KINDS`. On the VAT path it reads nothing of the tree: its turn is its facing
  node's (`get_parent().rotation.y`, the batch's `Frame.facing_yaw` natively), its death's timer is the batch's
  (`EnemyBatch.drop`). Its events call `_touch`, its reads `_peek`. It has no variant kind and no node part on the VAT
  path: the shield is its SHIELD_ON drive (size 0 when gone), the visor's glow the instance's accent glow, as before;
  so it needs no `BatchHeld`.
- Native class 22, `GLACIER_TURTLE` (`native/src/zd_avatar_glacier_turtle.cpp`): its sync, frame step and pose (the
  clips, the brace, the break, bare, `_body_xf`, the legs' reach, the shield's size, the visor) ported line by line in
  the GDScript's float widths. Its row fields are 43..114 (`GT_*`): `STRIDE` stays 124. The legs' hips and knees are
  in the row; its feet are `FEET` at the model's scale (one field, `GT_SCALE`, from the avatar's new `_scale`), since
  the feet too would pass the stride. Its 24 drives fit `MAX_DRIVES` 32. Its HP and its shield's HP ride in the slot's
  first two MORE inputs. Its clips' helpers (the Frost Spitter's `_hash`, `_scan`, `_twitch`, `_clip`) are the same
  statements as LeggedRig's, so it calls `zd_legged_rig`'s.
- `BatchGlacierTurtle` (`batch_glacier_turtle.gd`) holds its row copy and its GDScript-path sync; `BatchRows`,
  `BatchScriptSync`, `BatchAvatars`, `EnemyBatch.KINDS` and `zd_avatar.{h,cpp}` get one additive branch each.
- The avatar would have passed 1,000 lines (1,009): its node body build (`_frame_of`, `_build_model`, `_build_code`,
  `_piece`, `_glow_box`, `_rod`) moved, the same statements, into `GlacierTurtleBody` (`glacier_turtle_body.gd`). It is
  924 lines now.
- `tests/unit/native/test_native_crowd_glacier_turtle.gd`: every drawn buffer of 14+2 turtles on the owner's model,
  native against GDScript, over 300 frames, with shield hits (braces) and breaks added to the beetle's pattern.

## The build (after the merge)

```
GODOT="$GODOT" bash scripts/native/ensure.sh
```
Exit code 0; `build/native_build.log` shows `Compiling shared src\zd_avatar_glacier_turtle.cpp ...`, no warning or
error from it.

## The equality test (on `3951f678`)

Godot processes before: 4.
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_glacier_turtle.gd -gexit
```
Exit code 0. Raw output (colour codes stripped):
```
res://tests/unit/native/test_native_crowd_glacier_turtle.gd
* test_the_native_glacier_turtles_draw_the_script_ones_bodies
    turtle states seen (actor-frames): { 0: 560, 1: 2474, 2: 522, 3: 9, 4: 358 }; kills 5 (5 mid-attack); shields braced 16, broken 2
1/1 passed.
...
Scripts               1
Tests                 1
Passing Tests         1
Asserts             109
---- All tests passed! ----
```
The same result before the merge, on `75a5fa97` + the step (Godot processes before: 2 and 0).

## Shown able to fail

`_bare_pose`'s `d[BACK_UP] -= 0.018 * b` changed to `0.0181` in the GDScript only, the test run once (on `75a5fa97` +
the step), then the line restored:
```
    [Failed]:  frame 214: _looks 51|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 3 at 142: 0.5039218 vs 0.5038922
Tests                 1
Passing Tests      none
Failing Tests         1
Asserts           70/71
```
Exit code 1. (Frame 214 is the first frame a broken shield's bareness reaches the drawn pose.)

## Lint

```
gdformat --check src scripts tests && gdlint src scripts tests
1994 files would be left unchanged
Success: no problems found
```

## Not run (by the owner's rule for these steps)

The twin probe, `tests/arch`, `tests/golden`, `tests/unit/native`, the avatar tests and the e2e: NOT YET RUN (the lead
runs everything once with every kind moved). No timing runs.
