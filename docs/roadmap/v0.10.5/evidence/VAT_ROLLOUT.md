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

## V4b: the other horde kinds (`horde_avatar.gd`)

- Machine: the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2 stable, Forward+, Windows. V4a ran beside it in its own
  worktree. No frame timing here (the lead measures V4d alone).
- Build: commit `7d966626` (`v0.10.5 W3-V4b: …`, branch `v0105-vat-b`, cut from `55e83be6`). The bake report, the
  sheets and the motion check ran on that commit. The tests ran on the working tree just before it, with the same
  code (no edit between the test runs and the commit).
- Raw outputs (not tracked): `build/vat/7d966626_bake.txt`, `build/vat/motion_check.txt`,
  `build/shots/v0.10.5/vat/vat_sheet_<kind>.png` and `vat_diff_<kind>.txt` (and the Swarmer's `vat_sheet.png`,
  `vat_diff.txt`, re-run as a check), `build/tmp/tests_unit.txt`, `build/tmp/tests_e2e.txt`.

### What was built

Every kind is on VAT. None was left on the old path.

| Kind | Body | Baked parts (drives) | Grids (stance, gait) |
|---|---|---|---|
| Splitter | owner's model (textured) | halves, claws (windup raise, strike, death); legs (stride) | 9 x 17 x 9, 48 |
| Splitling | the Splitter's model at 0.62 | the same | 9 x 17 x 9, 48 |
| Shield Bearer | owner's model (textured) | shield (raise, strike); legs (stride) | 9 x 9 x 2, 48 |
| Mender | owner's model (textured) | crystal raised while healing (0 / 1); cross's turn (one turn a loop) | 2 x 2 x 2, 48 |
| Mine Layer | code body | hopper (windup); mine shown (0 / 1) | 2 x 2 x 2, none |
| Sniper | code body | barrel angle; muzzle size | 17 x 2 x 2, none |

How it works:
- **The body is the instance.** For these kinds, the body's whole move is the crowd's per-instance transform
  (`HordeAvatar.vat_offset`). That covers the pivot's place and lean, the rise-in, the idle bob, the crouch, the
  Splitling's 0.62 scale, the walk's bounce, the Mender's float and sway, and the death's tip, lift and shrink. The
  avatar's own pose code works it out with the same arithmetic as the node path. `_pose` and `_pose_model` were split
  into the body (`_place_body`) and the parts (`_pose_parts(drives)`). The node path and the bake both pose the parts
  through `_pose_parts`, so the parts' pose code cannot drift from the bake.
- **Only the moving parts are baked.** Each grid axis drives one part's pose, so a 3D stance grid is enough
  (`HordeVat`).
- **The walking legs.** The models' leg swing, sin(stride) x walk pace, is sent as the phase asin(swing) / 2π of a
  full-stride loop. Sampling that loop gives sin(asin(swing)), which is the swing itself.
- **Visibility toggles:**
  - The Mine Layer's dropped mine is a joint folded to a point (zero basis) at the grid's "hidden" rows. Its triangles
    have no area, so nothing is drawn.
  - The Sniper's muzzle glows from per-instance data: mesh mode 2, its energy in `INSTANCE_CUSTOM.w`.
  - The Mender's crystal flare and the seam/eye/scope glow use the instance's accent glow, as on the Swarmer.
  - The Mender's cross is always shown. It turns on the gait loop.
- **The textured models.** The owner's models are textured, so VatLooks has a textured variant: each plate's albedo
  is multiplied by the model's colour map at the mesh's UV, as `EnemyLooks.body` does. The map is sampled outside the
  branch.
- **Deaths.** `die()` works on a VAT model (`_is_model`). ActorViews keeps the actor for the 0.4 s fall, and the crowd
  draws it until the node is freed. The code bodies still go at once.
- **A missing model file.** If a model kind's GLB is missing, its code-built stand-in stays on the old path
  (`VatCrowd.supports`).
- **Shared files.** The changes are small and additive:
  - `VatBake`: per-kind joints, grids and bake pose; `GRID_NONE` root joints; hidden joints folded; UVs; mode 2;
    `eval_vertices_at`; `pose_error_full`.
  - `VatCrowd`: the `KINDS` list; `supports`; drives and offset taken from the avatar.
  - `VatLooks`: the textured variant and the second glow.
  - `actor_views.gd`: untouched.
  - The Swarmer's path is unchanged. Its drives and lift are now read through `vat_drives` and `vat_offset`, with the
    same values.

### 1. Pose error (the bake against the live pose)

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-b Godot_v4.7.2-stable_win64_console.exe --headless --path . -s scripts/checks/vat_bake_report.gd
```
The kinds past the Swarmer were posed by `pose_with` from every input at once, over 4,000 random sets each:
- the windup raise, the strike, the crouch, the clock and the rise-in;
- the death (about a third of samples dying);
- the walk pace and stride;
- the heal, the tell and winding.

Each set was posed on both avatars. The VAT side was posed through the baked texture at its own drives and instance
transform. Raw lines (the `worst at` lines are cut here; they are in the file):
```
vat bake report  sha=7d966626  godot=4.7.2-stable (official)
kind 11: 9 joints, 1380 vertices, 464 triangles, pose texture 18x453 RGBAF (127 KiB), grids [(9, 9, 5), 48]
  reduced_motion=false samples=4000 vertices/sample=1380  max_error_m=0.000455  mean_error_m=0.0000702
kind 12: 7 joints, 15204 vertices, 5068 triangles, pose texture 12x1425 RGBAF (267 KiB), grids [(9, 17, 9), 48]
  bake ms (this machine, once a session): poses 29.1, mesh 10.5
  reduced_motion=false samples=4000 vertices/sample=15204  max_error_m=0.001126  mean_error_m=0.0001307
kind 13: 7 joints, 15204 vertices, 5068 triangles, pose texture 12x1425 RGBAF (267 KiB), grids [(9, 17, 9), 48]
  bake ms (this machine, once a session): poses 28.7, mesh 10.2
  reduced_motion=false samples=4000 vertices/sample=15204  max_error_m=0.000698  mean_error_m=0.0000811
kind 14: 4 joints, 15033 vertices, 5011 triangles, pose texture 6x210 RGBAF (19 KiB), grids [(9, 9, 2), 48]
  bake ms (this machine, once a session): poses 2.1, mesh 9.7
  reduced_motion=false samples=4000 vertices/sample=15033  max_error_m=0.000248  mean_error_m=0.0000267
kind 15: 3 joints, 15039 vertices, 5013 triangles, pose texture 3x56 RGBAF (2 KiB), grids [(2, 2, 2), 48]
  bake ms (this machine, once a session): poses 0.6, mesh 10.0
  reduced_motion=false samples=4000 vertices/sample=15039  max_error_m=0.000194  mean_error_m=0.0000020
kind 16: 3 joints, 756 vertices, 256 triangles, pose texture 6x9 RGBAF (0 KiB), grids [(2, 2, 2), 0]
  bake ms (this machine, once a session): poses 1.1, mesh 1.5
  reduced_motion=false samples=4000 vertices/sample=756  max_error_m=0.000000  mean_error_m=0.0000000
    hidden vertices (all samples): 191328, folded to within 0.0000000 m
kind 17: 3 joints, 816 vertices, 276 triangles, pose texture 6x69 RGBAF (6 KiB), grids [(17, 2, 2), 0]
  bake ms (this machine, once a session): poses 1.7, mesh 1.9
  reduced_motion=false samples=4000 vertices/sample=816  max_error_m=0.000038  mean_error_m=0.0000024
```
The reduced-motion runs gave the same max and mean for every kind.

| Kind | Max error | In px at the game camera (15.7 mm/px) | Mean error |
|---|---|---|---|
| Splitter (12) | 1.126 mm | 0.07 | 0.131 mm |
| Splitling (13) | 0.698 mm | 0.04 | 0.081 mm |
| Shield Bearer (14) | 0.248 mm | 0.016 | 0.027 mm |
| Mender (15) | 0.194 mm | 0.012 | 0.002 mm |
| Mine Layer (16) | 0 (the hopper is linear) | 0 | 0 |
| Sniper (17) | 0.038 mm | 0.002 | 0.002 mm |

Every kind is sub-pixel.
- **The Splitter's grid.** It started at 9 x 9 x 5, which gave 1.915 mm on a 500-sample run. The 9 x 17 x 9 grid
  gave 1.123 mm on the same 500 samples, so it was kept. Its error is in the claws' three-axis rotation.
- **The Mine Layer's mine.** The hidden vertices fold onto one point exactly, so they draw nothing.

### 2. Side-by-side sheets, old path (left) vs VAT (right): for the owner (G2)

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-b-<kind> Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/shots/vat_sheet.gd -- --kind=<kind> --version-dir=v0.10.5
```
The seven kinds ran at once, each with its own APPDATA. Sheets: `build/shots/v0.10.5/vat/vat_sheet_<kind>.png` for
`splitter`, `splitling`, `shield_bearer`, `mender`, `mine_layer` and `sniper`. Each cell is 220 x 220 px, MSAA 4x, and
the camera is framed to the kind's height, so these cells are about 2x the game's zoom for these kinds.

New column: the largest vertex distance between the two avatars at the drives that cell was drawn with (the shader's
arithmetic on the CPU).

Raw, per kind (state | max channel diff 0-255 | pixels off by > 8 | share | max vertex error mm):
```
splitter: idle 28|1|0.0000|0.000; walking 1|0|0.0000|0.000; windup 31 % 108|160|0.0033|0.735; windup 90 % 45|1|0.0000|0.000;
  strike snap 1|0|0.0000|0.000; strike out 1|0|0.0000|0.000; easing back 1|0|0.0000|0.000; death 0.1 s 70|58|0.0012|0.281;
  death 0.3 s 1|0|0.0000|0.000; flinch 1|0|0.0000|0.000; knock 1|0|0.0000|0.000; flash 0|0|0.0000|0.000;
  burn 23|1|0.0000|0.000; rise-in 1|0|0.0000|0.000; biome cast 9|1|0.0000|0.000; calm 1|0|0.0000|0.000
splitling: idle 1|0; walking 8|0; windup 31 % 80|105|0.0022|0.455; windup 90 % 1|0; snap 1|0; out 4|0; back 1|0;
  death 0.1 s 45|20|0.0004|0.081; death 0.3 s 1|0; flinch 1|0; knock 1|0; flash 1|0; burn 1|0; rise-in 1|0; cast 1|0; calm 1|0
shield_bearer: windup 31 % 17|3|0.0001|0.092; easing back 6|0|0.0000|0.000; every other state 1|0 or 0|0, error 0.000
mender: idle 1|0|0.096; 1.3 s later 1|0|0.006; walking 23|1|0.131; healing 1|0|0.096; healing later 46|1|0.006;
  death 0.1 s 32|2|0.128; death 0.3 s 1|0|0.100; flinch 1|0|0.064; knock 1|0|0.064; flash 0|0|0.096; burn 1|0|0.096;
  rise-in 47|4|0.191; cast 1|0|0.096; calm 1|0|0.064
mine_layer: idle 55|4; windup 31 % 15|2; windup 90 % 14|2; mine dropped 82|4; active 0.15 s 15|2; recovering 55|2;
  flinch 76|3; knock 76|3; flash 118|3; burn 39|4; rise-in 39|3; cast 36|4; calm 76|3 (error 0.000 in every state)
sniper: idle 2|0|0.018; windup 31 % 8|0|0.036; windup 90 % 2|0|0.000; shot 0.05 s 1|0; shot 0.15 s 2|0;
  easing back 60|1|0.018; flinch 2|0|0.018; knock 2|0; flash 0|0; burn 1|0; rise-in 2|0; cast 2|0; calm 2|0
```
The Swarmer's sheet was re-run as a check of the shared path's change. Every state has at most 25 pixels off and a
vertex error of at most 0.177 mm, the same picture as the pilot.

Reading the sheets:
- **All but two cells** have at most 6 of 48,400 pixels off by more than 8/255.
- **Two Splitter and Splitling cells** have more:
  - windup 31 %: 160 and 105 pixels;
  - death 0.1 s: 58 and 20 pixels.

  Both are poses between grid points. The geometric error there is 0.74 mm at most, about 0.1 px at this zoom.

  An amplified difference image (`build/tmp/diff_splitter_windup.png`, made from the first run's sheet) shows scattered
  speckles on the claws' busy texture. It shows no shape change.

Whether these are "the same look" is the owner's call: `OWNER ONLY`.

### 3. Moving check

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-b Godot_v4.7.2-stable_win64_console.exe --path . --windowed --position -10000,-10000 -s scripts/checks/vat_motion_check.gd
```
```
physics interpolation: true  kinds: 7  instances compared: 4193  fps ~439  fraction buckets seen: 11
instance x vs this frame's interpolated place: max 0.00000 m, mean 0.00000 m
instance x vs the last tick's place: max 0.04983 m, mean 0.02488 m
```
There is one avatar of each of the seven kinds. Every instance sits at its actor's interpolated place on the same frame.

### 4. Tests

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-b-t1 Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<12 files>
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat-b-t2 Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<3 files>
```
- **Unit files:** test_enemy_vat, test_horde_avatars, test_melee_strikes, test_windup_tells, test_hit_impact,
  test_enemy_shadows, test_rig_merge, test_enemy_palettes, test_shader_warmup, test_first_use_warm, test_colour_modes,
  arch/test_layering.

  Result: `Tests 97, Passing 97, Asserts 28889, Orphans 6`. The pilot's run of the same files also reported 6 orphans
  (BarChunks); their source was not traced again here.
- **E2E and dev files:** e2e/test_e2e_horde_enemies, e2e/test_e2e_heat, application/test_dev_panel.

  Result: `Tests 6, Passing 6, Asserts 98`.

New tests in test_enemy_vat:
- every other kind bakes within 2 mm (`pose_error_full`) and folds its hidden pieces to a point;
- the dropped mine draws nothing;
- each kind's VAT pose follows the old one within 2 mm through `advance()`, over 150 ticks. The ticks cover a walk, a
  windup, a strike, a heal and, for the models, a death. The glow and the muzzle are compared exactly;
- ActorViews draws all six kinds through the crowd, one MultiMesh per kind with their proxy shadows. When the sim kills
  them, the Shield Bearer's model keeps drawing while it falls, and the Sniper's code body goes at once.

During the work, `test_vat_kinds_keep_the_old_drives…` first failed for the Mine Layer at 0.12 m. The test was
comparing the hidden mine's vertices: it checked `mi.visible` instead of `is_visible_in_tree()`. The test was fixed,
not the code.

Not run:
- the e2e tests with the switch on: GUT rejects `-- --enemy-vat=on` ("Unknown arguments"). With the switch on,
  ActorViews is covered by the unit tests above;
- the full suite: GitHub runs it on the PR;
- frame timing: the lead's V4d.

### 5. Finding: the proxy shadows of these kinds also sit under the floor

The sheet prints each kind's shadow stand-in box. The top y of each stand-in is:

| Kind | Top y (m) |
|---|---|
| Splitter | 0.000 |
| Splitling | 0.000 |
| Shield Bearer | 0.000 |
| Mender | -0.080 |
| Mine Layer | -0.130 |
| Sniper | -0.320 |

None is above the floor. The stand-in is merged right after `setup()`, which poses the body fully sunk for the rise-in.
This is the pilot's Swarmer finding (VAT_PILOT §5), now confirmed for every horde kind. On the old path and on VAT
alike, these kinds cast no proxy shadow. Not fixed (out of scope; `OWNER ONLY` whether they should).

### Owner

- Are the six kinds the same look on VAT (the sheets)? `OWNER ONLY`
- Should the horde kinds cast a shadow (§5)? `OWNER ONLY`

### After merging V4a (`931ff6a2`) into V4b: the six kinds on the general rig

The merge commit is `9033db86`.

**How the six kinds were moved onto V4a's rig API:**
- `VatBake.horde_rig` hands any horde kind but the Swarmer to `HordeVat.rig`. That rig has the key `horde<kind>` and
  4 drives. Its grids are the stance grid over drives 0–2 and, when the kind has one, a gait loop over drive 3. Its
  joints are `HordeVat.joint_spec`'s.
  - The body is the root joint. It sits on the stance grid but is always baked as the identity, because its moves are
    the instance's `vat_offset`.
  - A hidden joint is baked with a zero basis.
  - The rig carries the model's colour map (`albedo_tex`).
- `VatBake.drives_of` reads these kinds' four drives from `HordeAvatar.vat_grid_drives()`. The old
  `vat_drives(pose)` was renamed so it no longer clashes with V4a's no-argument `vat_drives` hook.
- `VatCrowd` moves a `HordeAvatar` instance by `vat_offset()`. For the Swarmer that is its lift, the same transform
  as before.
- `VatLooks` adds the textured variant.

**Mode 2 reconciled:** V4a's mode 2 (a plain plate: no flash, no glow) is unchanged. The Sniper's muzzle, which glows
at the instance's drive 3, moved to **mode 3**. The shader takes `zd_glow` from `INSTANCE_CUSTOM.w` when the mode is
above 2.5. Emission is then:
- mode 1 or 3: glow;
- mode 2: none;
- mode 0: the flash mix.

**Bake report at `9033db86`, all nine kinds** (same command, 4,000 samples):
```
vat bake report  sha=9033db86  godot=4.7.2-stable (official)
kind 11 (rig horde11): 9 joints, 4 drives, 1380 vertices, 464 triangles, pose texture 18x455 RGBAF (127 KiB)
  reduced_motion=false samples=4000 vertices/sample=1380  max_error_m=0.000455  mean_error_m=0.0000702
kind 2 (rig charger): 78 joints, 12 drives, 3219 vertices, 1073 triangles, pose texture 78x5006 RGBAF (6101 KiB)
  reduced_motion=false samples=4000 vertices/sample=3219  max_error_m=0.004157  mean_error_m=0.0002325
  reduced_motion=true samples=4000 vertices/sample=3219  max_error_m=0.004162  mean_error_m=0.0002324
kind 5 (rig charger): (the same as kind 2)
kind 12 (rig horde12): 7 joints, 4 drives, 15204 vertices, 5068 triangles, pose texture 15x1427 RGBAF (334 KiB)
  reduced_motion=false samples=4000 vertices/sample=15204  max_error_m=0.001126  mean_error_m=0.0001307
kind 13 (rig horde13): 7 joints, 4 drives, 15204 vertices, 5068 triangles, pose texture 15x1427 RGBAF (334 KiB)
  reduced_motion=false samples=4000 vertices/sample=15204  max_error_m=0.000698  mean_error_m=0.0000811
kind 14 (rig horde14): 4 joints, 4 drives, 15033 vertices, 5011 triangles, pose texture 6x212 RGBAF (19 KiB)
  reduced_motion=false samples=4000 vertices/sample=15033  max_error_m=0.000248  mean_error_m=0.0000267
kind 15 (rig horde15): 3 joints, 4 drives, 15039 vertices, 5013 triangles, pose texture 6x58 RGBAF (5 KiB)
  reduced_motion=false samples=4000 vertices/sample=15039  max_error_m=0.000194  mean_error_m=0.0000020
kind 16 (rig horde16): 3 joints, 4 drives, 756 vertices, 256 triangles, pose texture 9x10 RGBAF (1 KiB)
  reduced_motion=false samples=4000 vertices/sample=756  max_error_m=0.000000  mean_error_m=0.0000000
    hidden vertices (all samples): 191328, folded to within 0.0000000 m
kind 17 (rig horde17): 3 joints, 4 drives, 816 vertices, 276 triangles, pose texture 9x70 RGBAF (9 KiB)
  reduced_motion=false samples=4000 vertices/sample=816  max_error_m=0.000038  mean_error_m=0.0000024
```
- **Reduced motion:** the same as the normal run for every horde kind. The Charger's reduced-motion line is shown
  above.
- **Unchanged numbers:** every error equals its pre-merge value.
  - The Swarmer: 0.455 mm.
  - The Charger: 4.157 mm; the Hatchling: 4.157 mm in its own space, which is 2.74 mm on screen. These match V4a's
    section.
  - The six kinds: the numbers in §1 above.
- **Texture sizes:** they grew by a table row and, for some kinds, a few texels, because of V4a's joint and grid
  tables.

**Motion check, all nine kinds** (V4a's `--kind=charger` is kept):
```
physics interpolation: true  kinds: 9  instances compared: 5391  fps ~495  fraction buckets seen: 11
instance x vs this frame's interpolated place: max 0.00000 m, mean 0.00000 m
instance x vs the last tick's place: max 0.04994 m, mean 0.02472 m
worst per kind (m, vs the interpolated place): { 11: 0.00000011997223, 2: 0.00000011997223, 5: 0.00000011997223, 12: 0.00000011997223, 13: 0.00000011997223, 14: 0.00000011997223, 15: 0.00000011997223, 16: 0.00000011997223, 17: 0.00000011997223 }
```
The motion check ran on the resolved tree just before the merge commit, with the same code.

**Tests on the resolved tree** (V4a's 23 files, plus `test_e2e_heat`), in two runs at once, each with its own APPDATA:
- run A (13 unit/presentation files): `Tests 106, Passing 106, Asserts 9169, Orphans 7`. V4a also reported 7.
- run B (the other 11): `Tests 40, Passing 40, Asserts 27328`.

**Sheets:** all eight were re-drawn into `build/tmp/sheets_merge/`.
- The CPU vertex-error column is unchanged for the Splitter, Splitling, Shield Bearer, Mine Layer, Sniper and
  Swarmer.
- The Mender's column varies run to run. It also varied between the pre-merge runs: idle was 0.140 mm, then
  0.096 mm, and is 0.173 mm now. Every value stays within its bake maximum of 0.194 mm.
- The pixel counts vary run to run by a few edge pixels.
- No sheet's numbers moved because of the merge, so the sheets in `build/shots/v0.10.5/vat/` stay the `7d966626` ones.
- One fix: the sheet now prints "—" for the vertex-error column of the Charger's sheet, which has none, instead of a
  number.
