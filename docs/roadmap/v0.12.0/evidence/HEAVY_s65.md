# v0.12.0 Step 65: the Gravity Node into the native enemy batch

Branch `v0120-s65`, cut from `f3e2d184`, merged with `lead-v0120` three times (step 68's `BatchHeld` at `0d589730`
before the work; after the step commit `96913293`, the Glacier Turtle at `0c8a5c4a`, merge `59396d5f`, and the Wire
Weaver at `05997249`, merge `a2a2eb65`). Each merge kept every class's dispatch: `git diff lead-v0120 --
native/src/zd_avatar.cpp` shows only the Gravity Node's lines. Machine: the
owner's PC (i7-10700K, RTX 3060), Windows 11, Godot 4.7.2. One Godot process of this step at a time; another
agent's Godot ran beside it (the count before each run is printed).

## What changed

- `GravityNodeAvatar` joins `EnemyBatch.KINDS`. On the VAT path it reads nothing of the tree: its turn is its facing
  node's (`get_parent().rotation.y`, the batch's `Frame.facing_yaw` natively), its death's timer is the batch's
  (`EnemyBatch.drop`, `DEATH_SECONDS`). It has no variant kind.
- Its one node-drawn part on the VAT path, the ground disc (`SoloVat.LIVE`), hangs in the tree from the shared
  `BatchHeld` holder (the root's place at `EnemyBatch.origin`, a copy of the facing, the avatar's transform), its
  scale set from its row each frame (`BatchGravityNode.hold` / `show`), as the Bomb Drone's. The floor swirl is
  `StarfallViews`' (read from the sim, not the avatar) and is untouched. Nothing of its glows, rings, disc,
  materials or clips changed: the core's glow is the instance's accent glow, the gem's its flat VISOR drive, as before.
- Native class 23, `GRAVITY_NODE` (`native/src/zd_avatar_gravity_node.cpp`): its sync, frame step and pose (hover,
  pull and beats, turn, hit wobble, rise-in, death, the two glows, the disc's scale) ported line by line in the
  GDScript's float widths. Its row fields are 43..76 (`GN_*`), so `STRIDE` stays 124; its 17 drives fit `MAX_DRIVES`
  32. Its HP and its draw on the hero (`WorldReader.gravity_hero_pull`) ride in the slot's first two MORE inputs.
- `BatchGravityNode` (`batch_gravity_node.gd`) holds its row copy, its sync inputs, its GDScript-path sync and its
  disc's hold; `BatchRows`, `BatchScriptSync`, `BatchAvatars`, `EnemyBatch` (the KINDS line and three hold/show
  branches beside the Bomb Drone's) and `zd_avatar.{h,cpp}` get additive branches.
- `tests/unit/native/test_native_crowd_gravity_node.gd`: every drawn buffer and every ground disc of 12+2 nodes,
  native against GDScript, over 300 frames (the hero walked round them and their facings set toward it, so the turn
  clip plays: the sim's own node does not turn in this fixture).

## The build (after the last merge)

```
GODOT="$GODOT" bash scripts/native/ensure.sh
```
`ensure_exit=0` on `59396d5f` and again on `a2a2eb65` (no `error C` line in `build/native_build.log`; it lists
`Compiling shared src\zd_avatar_gravity_node.cpp ...`).

## The equality test (on `a2a2eb65`)

Godot processes before: 0. After: 0. (On `59396d5f` it gave the same line, exit code 0, with 2 other Godot processes
running.)
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/native/test_native_crowd_gravity_node.gd -gexit
```
Exit code 0. Raw output (colour codes stripped):
```
res://tests/unit/native/test_native_crowd_gravity_node.gd
* test_the_native_gravity_nodes_draw_the_script_ones_bodies
    gravity node states seen (actor-frames): { 0: 490, 1: 2833 }, { "flinched": 66, "held": 29, "killed": 5, "spawned": 2, "hurt": 1625, "drawing": 704, "beating": 1055, "turning": 2660, "rising": 1418, "dying": 365 }
1/1 passed.
Totals
------
Scripts               1
Tests                 1
Passing Tests         1
Asserts             102
Time              2.169s
---- All tests passed! ----
```

## Shown able to fail

On `96913293`'s tree, one constant of `GravityNodeAvatar._hover_pose` changed (`d[ROLL] += k * 0.06 * ...` to
`0.0601`), the test run, the file put back (`grep -c 0.0601` 0 after). Godot processes before: 2.
Exit code 1:
```
    [Failed]:  frame 0: _looks 53|00000000|0.4500|1a1a22ff|ff00ffff,ff00ffff,ff00ffff,ff00ffff field 2 at 16: 0.49139133 vs 0.49140078
Passing Tests      none
Failing Tests         1
```

## Lint

```
gdformat --check src scripts tests && gdlint src scripts tests
```
Before the step commit: `1993 files would be left unchanged`, `Success: no problems found`. After the Glacier
Turtle's merge: `1996 files would be left unchanged`, `Success: no problems found`. After the Wire Weaver's, on the
seven files this step touches in `src/` and `tests/`: `7 files would be left unchanged`, `Success: no problems
found`.

## Not run (the owner's test rule for the kinds, 2026-11-22)

The twin probe, `tests/arch`, `tests/golden`, `tests/unit/native`, the avatar tests and the e2e: NOT YET RUN (the
lead runs everything once, with every kind moved). No timing.
