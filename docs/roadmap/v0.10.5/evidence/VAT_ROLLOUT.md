# VAT_ROLLOUT: every regular enemy drawn from baked poses (W3-V4)

Owner, 2026-11-06: "animations looks fine … I think this is a way to go, can we apply it to the rest of the enemies
and test it?" (PLAN W3-V4). Presentation only (EI-07): no sim change, no golden change. The switch stays off by
default (the old path) until the owner signs the look off again. The bar per kind is the pilot's
([`VAT_PILOT.md`](VAT_PILOT.md)): the bake's max pose error, a side-by-side sheet, the tests and e2e that reach it.
The mixed-horde frame_probe is V4d's (the lead, alone).

## V4a: the Charger, the Hatchling, and the general path

- Machine: the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2 stable, Forward+, Windows. Other agents ran on the PC at
  the same time, so nothing here is a timing (no frame_probe; the bake times below are only a size check).
- Build: the working tree of branch `v0105-vat-a` on top of `55e83be6`; the reports print `sha=55e83be6`. All of it
  is in the step's commit (`v0.10.5 W3-V4a: …`, the commit that adds this file).
- Raw outputs (in the worktree, not tracked): `build/vat/55e83be6_bake.txt`, `build/vat/motion_check.txt`,
  `build/vat/motion_check_charger.txt`, `build/vat/tests_v4a.txt`, `build/shots/v0.10.5/vat/vat_sheet_charger.png`,
  `vat_diff_charger.txt`, `vat_sheet.png` and `vat_diff.txt`.

### What was built

- **The general path.** `VatBake` now bakes any avatar from its **rig** (`VatBake.rig_of`): a Dictionary of its
  drives (how many continuous numbers its pose is made of, each 0..1), its grids (per grid 1 to 3 axes, each
  `[drive, samples, loops]`), its joints (`{grid, parent, frame}`: any depth, a parent before its children) and a
  `row(grid, drives)` callable that poses the avatar with its own code and returns that grid's joint transforms. The
  plain lift of the whole body stays the avatar's `vat_lift()`, sent with the instance (exact). The texture now carries
  a joint table (row 0) and a grid table (row 1); the shader (`VatLooks`) follows each vertex's joint chain up to 32
  joints and samples each joint's grid multilinearly (a loop wraps). The first four drives go in `INSTANCE_CUSTOM`; a
  rig with more sends the rest in a per-look drive texture, one row per instance (`INSTANCE_ID`), written by
  `VatCrowd` with the buffer. A rig whose joints scale turns its normals by the inverse transpose; a mesh with
  two-sided pieces draws `cull_disabled` and drops the back faces of its one-sided ones; a plain
  `StandardMaterial3D` piece (the Charger's face) is mode 2 (no flash, no glow).
- **The Swarmer** keeps the pilot's rig, now built by `VatBake.horde_rig` from the same `joint_spec` / `gait_period`
  (V4b adds its kinds there). `horde_avatar.gd` is not touched.
- **The Charger** (`ChargerVat`, read by `ChargerAvatar.vat_rig()`): 12 drives (wind-up, lunge less the daze, daze,
  the legs' phase, the walk, the crouch, the eased rise, the body's height, the fidget's clock and amount, the
  twitch's clock) and 6 grids (stance 17 x 17 x 9 over wind x lunge x daze; gait 128 (loop) x 5 over phase x walk;
  rise 33; body height 177 x crouch 2; fidget 256 (loop) x 5; twitch 32 (loop) x daze 3). Its legs are not nested
  nodes: each segment sits at the end of the one before and is turned by absolute angles, and each angle is a sum of
  terms from different drives. Turns about one axis add, so the rig nests the segments (a segment relative to the one
  before is `T(length) Rz(-pitch) Ry(yaw difference) Rz(next pitch)`) and gives each term its own joint on the grid of
  its drives: 2 body joints + 19 per leg = 78 joints, the composed chain being the pose itself for any mix of the
  drives, so only each grid's sampling is approximate. The pose code was split into the functions the rig calls
  (`leg_angles`, `leg_sweep`, `leg_lift`, `leg_fidget`, `leg_hold`, `leg_twitch`, `body_x`, `body_basis`,
  `body_drop`); the old path calls the same functions, and `test_charger_pose_hv` (exact equality with the old
  formula) still passes.
- **The talon sockets were not baked.** Nothing in the game reads `ChargerAvatar.leg_tips()` (no caller in `src/`,
  `scripts/` or `tests/`); a VAT Charger returns none. The hood, face and visor stay one body joint whose transform
  scales on the lunge; the shader's inverse-transpose normals stand for the PF5 note's separate nodes.
- **The Hatchling** is the same `ChargerAvatar` in its own colours, scaled 0.66 on its avatar node (the crowd
  multiplies by the avatar's transform), so it shares the Charger's bake (rig key `charger`).
- **The switch** turns VAT on for every `VatCrowd.KINDS` kind (Swarmer, Charger, Hatchling). The dev button reads
  "Enemy VAT" / "VAT de enemigos" (`UI_DEV_ENEMY_VAT`). Off by default.
- Size: the Charger's pose texture is 78 x 5006 RGBA32F (6,101 KiB, once for both kinds); its bake took about 280 ms
  on this machine while other agents ran (once a session: behind the loading cover when the switch is on, or with
  the first VAT Charger when the switch is flipped in the dev panel).

### 1. Pose error (the bake against the live pose)

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-a Godot_v4.7.2-stable_win64_console.exe --headless --path . -s scripts/checks/vat_bake_report.gd
```
Before the change (the same command on `55e83be6` untouched), the Swarmer:
```
kind 11: 9 joints, 1380 vertices, 464 triangles, pose texture 18x453 RGBAF (127 KiB)
  reduced_motion=false samples=4000 vertices/sample=1380  max_error_m=0.000455  mean_error_m=0.0000702
    worst at { "wind": 0.560407102108, "strike": 0.93703556060791, "crouch": 0.39855268597603, "t": 15.0157308578491, "rise": 0.41414001584053, "vertex": 344 }
```
After:
```
vat bake report  sha=55e83be6  godot=4.7.2-stable (official)
horde grids: stance (9, 9, 5) (wind x strike x crouch), gait 48 samples a loop
charger grids [[drive, samples, loops], ...]: [[[0, 17, false], [1, 17, false], [2, 9, false]], [[3, 128, true], [4, 5, false]], [[6, 33, false]], [[7, 177, false], [5, 2, false]], [[8, 256, true], [9, 5, false]], [[10, 32, true], [2, 3, false]]]
kind 11 (rig horde11): 9 joints, 4 drives, 1380 vertices, 464 triangles, pose texture 18x455 RGBAF (127 KiB)
  bake ms (this machine, once a session): poses 12.3, mesh 2.1
  reduced_motion=false samples=4000 vertices/sample=1380  max_error_m=0.000455  mean_error_m=0.0000702
    worst at { "wind": 0.560407102108, "strike": 0.93703556060791, "crouch": 0.39855268597603, "t": 15.0157308578491, "rise": 0.41414001584053, "vertex": 344 }
  reduced_motion=true samples=4000 vertices/sample=1380  max_error_m=0.000455  mean_error_m=0.0000702
    worst at { "wind": 0.560407102108, "strike": 0.93703556060791, "crouch": 0.39855268597603, "t": 15.0157308578491, "rise": 0.41414001584053, "vertex": 344 }
kind 2 (rig charger): 78 joints, 12 drives, 3219 vertices, 1073 triangles, pose texture 78x5006 RGBAF (6101 KiB)
  bake ms (this machine, once a session): poses 274.2, mesh 3.1
  reduced_motion=false samples=4000 vertices/sample=3219  max_error_m=0.004157  mean_error_m=0.0002325
    worst at { "phase": 18.5548233985901, "t": 32.0935082435608, "walk": 0.08995121717453, "wind": 0.8467510342598, "lunge": 0.11178523302078, "daze": 0.72805559635162, "rise": 0.33141624927521, "windup": true, "tell": 0.49202185869217, "vertex": 1480 }
  reduced_motion=true samples=4000 vertices/sample=3219  max_error_m=0.004162  mean_error_m=0.0002324
    worst at { "phase": 18.5548233985901, "t": 32.0935082435608, "walk": 0.08995121717453, "wind": 0.8467510342598, "lunge": 0.11178523302078, "daze": 0.72805559635162, "rise": 0.33141624927521, "windup": true, "tell": 0.49202185869217, "vertex": 1480 }
kind 5 (rig charger): 78 joints, 12 drives, 3219 vertices, 1073 triangles, pose texture 78x5006 RGBAF (6101 KiB)
  bake ms (this machine, once a session): poses 287.3, mesh 3.0
  reduced_motion=false samples=4000 vertices/sample=3219  max_error_m=0.004157  mean_error_m=0.0002325
    worst at { "phase": 18.5548233985901, "t": 32.0935082435608, "walk": 0.08995121717453, "wind": 0.8467510342598, "lunge": 0.11178523302078, "daze": 0.72805559635162, "rise": 0.33141624927521, "windup": true, "tell": 0.49202185869217, "vertex": 1480 }
  reduced_motion=true samples=4000 vertices/sample=3219  max_error_m=0.004162  mean_error_m=0.0002324
    worst at { "phase": 18.5548233985901, "t": 32.0935082435608, "walk": 0.08995121717453, "wind": 0.8467510342598, "lunge": 0.11178523302078, "daze": 0.72805559635162, "rise": 0.33141624927521, "windup": true, "tell": 0.49202185869217, "vertex": 1480 }
```
(The Hatchling is measured in its own space, before the 0.66 its avatar node is scaled by: the same geometry as the
Charger's, so the same numbers.)

| Kind | max error | mean | in pixels at the game camera (15.7 mm a pixel) |
|---|---|---|---|
| Swarmer | 0.455 mm (unchanged) | 0.070 mm (unchanged) | 0.03 px |
| Charger | 4.16 mm | 0.23 mm | 0.27 px |
| Hatchling | 4.16 mm in its own space; x 0.66 on screen = 2.74 mm | 0.15 mm on screen | 0.17 px |

The Charger's sample mixes every drive freely (reachable or not: a dazed, half-risen Charger winding up), so it is
the worst case over the whole drive space. The target (sub-pixel) is met.

### 2. Side-by-side sheet, old path (left) vs VAT (right): for the owner (G2)

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-a Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1920x1300 --windowed --position -10000,-10000 -s scripts/shots/vat_sheet.gd -- --kind=charger --out=res://build/shots/v0.10.5/vat
```
Sheet: `build/shots/v0.10.5/vat/vat_sheet_charger.png`. The 18 states are driven by the same calls on both avatars
(sim states and positions one a tick, as ActorViews.sync gives them). Per-pair image difference (220 x 220 px, MSAA
4x), raw:
```
vat sheet: old (left) vs VAT (right), 220x220 px each, msaa 4x
kind 2 shadow proxy aabb (avatar space, m): [P: (-0.64, 0.000673, -0.43132), S: (0.929075, 0.859327, 0.86264)] (top y 0.860; the floor is y 0)
state | max channel diff (0-255) | pixels off by > 8 | share
idle (t 1.5 s) | 74 | 6 | 0.0001
idle fidget (t 3.9 s) | 72 | 6 | 0.0001
run 3 m/s | 54 | 6 | 0.0001
windup 31 % | 56 | 22 | 0.0005
windup 90 % (flash) | 67 | 2 | 0.0000
lunge snap (0.05 s) | 63 | 53 | 0.0011
charge 15 m/s | 37 | 11 | 0.0002
recovery (0.2 s in) | 49 | 7 | 0.0001
dazed (1 s in) | 41 | 7 | 0.0001
flinch at its peak | 74 | 7 | 0.0001
Blade knock | 74 | 7 | 0.0001
hit flash | 59 | 1 | 0.0000
status tint (burn) | 62 | 6 | 0.0001
rise-in, half way | 39 | 1 | 0.0000
biome cast + role glow | 72 | 6 | 0.0001
reduced motion + windup | 67 | 2 | 0.0000
Hatchling, run | 37 | 5 | 0.0001
Hatchling, charge | 34 | 8 | 0.0002
```
At most 53 of 48,400 pixels per state differ by more than 8/255 (the lunge snap, mid-stretch); the others 1 to 22.
An earlier run at 1080 px high (the Hatchling row cut off the png, the numbers are the sub-viewports') gave 2 to 38
for the same states: edge pixels move between runs. Whether that is "the same look" is the owner's call: `OWNER ONLY`.

The Swarmer's sheet with the new path (the pilot's command, `--out=res://build/shots/v0.10.5/vat`), raw:
```
state | max channel diff (0-255) | pixels off by > 8 | share
idle | 9 | 1 | 0.0000
scuttle (t 1.37 s) | 9 | 1 | 0.0000
windup 31 % | 14 | 5 | 0.0001
windup 90 % (flash) | 129 | 1 | 0.0000
strike snap (0.05 s) | 10 | 1 | 0.0000
strike out (0.15 s) | 21 | 1 | 0.0000
strike easing back | 9 | 1 | 0.0000
flinch at its peak | 1 | 0 | 0.0000
Blade knock | 1 | 0 | 0.0000
hit flash | 115 | 1 | 0.0000
status tint (burn) | 18 | 1 | 0.0000
rise-in, half way | 9 | 1 | 0.0000
biome cast + role glow | 8 | 0 | 0.0000
reduced motion + flinch | 1 | 0 | 0.0000
```
At most 5 pixels off per state (the pilot's run: at most 11).

### 3. Moving check (is the instance where the engine draws its actor on this frame?)

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-a Godot_v4.7.2-stable_win64_console.exe --path . --position -10000,-10000 -s scripts/checks/vat_motion_check.gd -- --kind=charger
```
```
physics interpolation: true  frames compared: 599  fps ~1  fraction buckets seen: 11
instance x vs this frame's interpolated place: max 0.00000 m, mean 0.00000 m
instance x vs the last tick's place: max 0.04996 m, mean 0.02502 m
```
The VAT Charger's instance follows the actor's interpolated place on the same frame. (The fps column is the engine's
counter read on the last frame; both runs, Swarmer and Charger, took about 10 s for 600 frames on a shared machine:
it is not a timing. The Swarmer's run with the same command and no flag: max 0.00000 m, last tick's 0.04993 m.)

### 4. Tests

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-a Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<23 files>
```
Files: unit/presentation test_enemy_vat, test_charger_pose_hv, test_charger_avatar, test_horde_avatars,
test_melee_strikes, test_windup_tells, test_hit_impact, test_enemy_shadows, test_rig_merge, test_enemy_palettes,
test_shader_warmup, test_first_use_warm, test_colour_modes, test_crowd_view, test_damage_flash, test_health_bars,
test_telegraph_parity; unit/application test_dev_panel; arch/test_layering; content/test_locale_coverage;
e2e/test_e2e_horde_enemies, test_e2e_enemies, test_e2e_training_room.
```
Totals
Tests               141
Passing Tests       141
Asserts           34503
Orphans               7
Time              137.568s
```
New in test_enemy_vat: the Charger's and the Hatchling's bake against the live pose (60 samples each, under 8 mm),
a VAT Charger's drives, lift, visor and raise equal to the old Charger's over 180 ticks of spawn / move / windup /
charge / recover, and ActorViews drawing two Chargers and a Hatchling through the crowd (two looks, the Hatchling at
0.66, all twelve drives sent, the flash reaching the instance). The pilot's ActorViews test now counts the Charger in
the crowd (4 drawn, 2 looks). The orphans are in files this step does not touch: test_charger_avatar (1; also 1 on
`55e83be6` untouched, checked), test_hit_impact, test_shader_warmup, test_first_use_warm (the pilot's BarChunks) and
test_e2e_training_room (its HUD panels). Not run: the full suite (GitHub runs it on the PR).

### Not done / could not match

- No frame_probe (V4d: the lead, alone).
- No e2e drives main.tscn with the switch on (the pilot added none either): the switch is a developer setting. The
  e2e below run with it off, on the refactored old Charger pose; `test_enemy_vat` covers ActorViews with it on.
- The ink outline pass of the VAT material is still not compiled anywhere (`ActorLooks.OUTLINES` is false).
- The talon sockets are not baked (nothing reads them).

### Owner

- Is the VAT Charger (and Hatchling) the same look as the old one (the sheet)? `OWNER ONLY`
