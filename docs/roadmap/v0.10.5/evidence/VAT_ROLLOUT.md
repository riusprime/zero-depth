# VAT_ROLLOUT: every regular enemy drawn from baked poses (W3-V4)

Owner, 2026-11-06: "animations looks fine … I think this is a way to go, can we apply it to the rest of the enemies
and test it?" (PLAN W3-V4). Presentation only (EI-07): no sim change, no golden change. The switch
(`ViewPrefs.enemy_vat`) stays off by default. The bar is W3-V1's ([`VAT_PILOT.md`](VAT_PILOT.md)).

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
