# v0.7.5 BM: the owner's Warlord, Hive Lens and Foundry models (owner N14, N18)

Build: branch `v075-bm` from `67c9af9`. The code and tests below were run at `3b7e190` (the WIP commit with the
N18 scale), and the raw renders at `0f5a90d` (the raw models don't depend on the scale). This file is part of the
`v0.7.5 Step BM` commit, so that commit's SHA is in the hand-off report rather than here.

## What was installed
- `assets/models/bosses/warlord.glb`, `hive_lens.glb`, `foundry.glb`, copied byte for byte from the owner's
  upload. The `.import` files and the textures the import extracted sit next to them, as for the first three:
  `warlord_Color_…jpg`, `hive_lens_…_BaseColor.jpg` + `_Normal_Bake.jpg`, `foundry_Color_…jpg`. The textures are
  kept as delivered.
- `assets/models/manifest.json`: three rows (id, path, sha256):

| id | sha256 |
|---|---|
| warlord | `68652dd80f2a952a99eb3957474e06404532f37b067a21b5f2e477646d4d4bfa` |
| hive_lens | `0225a4a4161c64036332568e576e48ccccd2387d1e2c2e94b89879d9a62fd93d` |
| foundry | `8fee2116e7502a9c8454e8d56950bfa7b8fa61274661fe52cf5ca85386954db1` |

  (`sha256sum` of the upload; `tests/content/test_model_manifest.gd` checks the files against them.)
- `data/credits/licences.tres` was regenerated (`godot --headless --path . -s scripts/content/build_credits.gd` →
  `wrote res://data/credits/licences.tres (7 entries)`). The models line now counts 42 files (it was 39), because
  `test_credits_licences` compares the committed list to a fresh build.

## The render path behind SPECS (yaw and height)
The first three were measured with a scratch render that wasn't committed (v0.3.0 evidence/BOSSES.md C2). This
step commits the render as `scripts/shots/boss_models.gd mode=raw`:

```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1800x400 -s scripts/shots/boss_models.gd -- mode=raw
boss_models: renderer=forward_plus mode=raw
boss_models: warlord raw mesh bounds [P: (-0.204501, 0.0, -0.345401), S: (0.409002, 1.0, 0.690803)] (skin: true)
boss_models: res://build/shots/v0.7.5-dev/boss_models/raw_warlord.png (views: yaw 0, 90, 180, 270 degrees, then from above)
boss_models: hive_lens raw mesh bounds [P: (-0.260274, -0.0, -0.456947), S: (0.520548, 1.0, 0.913894)] (skin: true)
boss_models: res://build/shots/v0.7.5-dev/boss_models/raw_hive_lens.png (views: yaw 0, 90, 180, 270 degrees, then from above)
boss_models: foundry raw mesh bounds [P: (-0.437378, -0.5, -0.496086), S: (0.874755, 0.998043, 0.992172)] (skin: false)
boss_models: res://build/shots/v0.7.5-dev/boss_models/raw_foundry.png (views: yaw 0, 90, 180, 270 degrees, then from above)
```

[`shots/boss_models/raw_models.jpg`](shots/boss_models/raw_models.jpg) shows, top to bottom, the Warlord, the Hive
Lens and the Foundry. Each row has the yaw 0, 90, 180 and 270° views, then a view from above. The red stick is
the file's +X and the blue its +Z.

**Agent's reading of the renders:**
- All three are Y-up, and their fronts face the file's +X, so **yaw 0** for all three.
  - The Warlord's T visor and the Hive Lens's slit-pupil eye are seen when +X faces the camera (the 270° view).
  - The Foundry's door and grate are on +X.
  - The Warlord's shield is on its left (-Z) and its toes point +X.
- **Warlord:** 2.7 m to the spear's tip.
  - The skin's 41 Tripo joints place the mesh 1:1, since rest × bind is the identity for every bone.
  - The spear is weighted to `R_Hand` and the shield to `L_ForearmTwist02`.
- **Hive Lens:** 1.9 m across its two side pods (2.08 m tall). Its lowest point is 0.62 m up, so the sphere's centre
  sits 1.75 m up.
  - The skin's 23 joints sit under an `Armature` 0.5 up, with bind poses that undo that offset.
  - The sphere is about 0.52 raw units wide.
  - Reading: "1.9 m across" is the model's whole width, which also matches the sim body's 2 m (`radius_m = 1.0`).
    With the sphere alone at 1.9 m, the cable tails would hang 0.24 m under the floor.
- **Foundry:** 2.6 m. It is one static mesh, so it is rigged in code.
- The anchor points (the core, the spear tip, the shield face, the eye, the door, the chimneys, the launcher) come
  from vertex queries on the raw meshes: the extreme vertices in a band, scaled to metres. They are constants in
  each avatar.

`BossModels.SPECS`: `warlord {yaw 0, height 2.7, skinned}`, `hive_lens {yaw 0, height 2.08, lift 0.62, skinned}`,
`foundry {yaw 0, height 2.6}`.

## N18: every boss 1.3× bigger
Owner, 2026-10-13: "Bosses could be a bit bigger so we could see the model better". Sent by the lead.

- The scale lives in one place: **`BossModels.SIZE_SCALE = 1.3`**. `BossAvatar.setup` scales its whole `Model`
  node by it.
- It applies to all six bosses, whether the owner's model or the code-built fallback draws.
- Everything under the model node scales with it: the weak point's core and halo, the hit-flash material, the
  Hive Lens's hover and ground shadow, and `anchor()`.
- SPECS keep the heights measured on the renders. Drawn heights are now:

| Boss | Drawn |
|---|---|
| Sentinel | 3.84 m |
| Queen | 3.12 m |
| Turret | 3.25 m |
| Warlord | 3.51 m |
| Hive Lens | 2.47 m across, its centre 2.28 m up |
| Foundry | 3.38 m |

- `ActorViews` boss height: 2.6 × 1.3.
- Not touched: the sim radius ×1.3 and the 4×4 boss rooms (BF1, `data/bosses`).

## How the models move (presentation only, EI-07)
- **Rigged models kept as delivered.** `BossModels` instances the Warlord's and the Hive Lens's own scenes under a
  `Normalise` node that turns, scales and lifts them. `BonePoser` applies turns given in the model frame (+X front,
  +Z right), whatever each Tripo bone's own axes are, and writes each bone once per frame.
- **Foundry cut** (`BossRig._foundry`): six bones, `root`, `body`, `leg_fl`, `leg_fr`, `leg_bl`, `leg_br`.
  - A leg is a vertex outside the body's middle in both x (beyond 0.22–0.36 m) and z (beyond 0.28–0.40 m) and below
    the hip band (fully leg under 0.36 m, fully body over 0.54 m), with the weight blended across the band.
  - Each hip is above the mean of that foot's vertices.
- **One function per pose layer.** Every avatar has `_pose_rig`, and the pose hooks below are its functions.
  - Warlord:
    - `_pose_idle`: breath and sway.
    - `_pose_walk`: thighs, knees and flat feet from its speed, hip roll, counter-swinging arms.
    - `_pose_shield`: the shield carried turned to the front, drawn back then thrust for the bash, lifted up and
      aside while the weak point is open.
    - `_pose_spear`: raised and planted (spear lines), couched and thrust (lunge), drawn and thrown (javelins).
    - `_pose_lunge`: the forward lean.
    - `_pose_shielded`, `_pose_flinch`, `_pose_stagger`, `_pose_death`.
  - Hive Lens:
    - `_pose_hover`: bob, roll, crown spin, the dive's pitch, the glare's swell.
    - `_pose_aim`: the eye turns toward the player, at most 0.6 rad past its facing, with a lag.
    - `_pose_tails`: each segment sways later than the one above it and trails the local velocity, more toward the
      tip.
    - `_pose_open`: the crown tips back and the pods spread while the weak point is open.
    - `_pose_split`: the pods spread and lift through the deploy and stay apart after it.
    - `_pose_shielded`: the closed pose. The crown folds over the eye, the pods draw in, the tails curl.
    - `_pose_flinch`, `_pose_stagger`. Its tips, rolls and swells turn about the sphere's centre.
  - Foundry:
    - `_pose_steps`: diagonal pairs from its speed, with body bob and roll.
    - `_pose_attack`: the pour's tip, the mortar's squat and kick, the vent's crouch and blow, the launch's rock.
    - `_pose_shielded`: hunkered on splayed legs.
    - `_pose_flinch`, `_pose_stagger`.
    - A warm `GrateLight` at the door follows the heat.
- **Reads.** These are the same attack-phase reads the code bodies used (state, move, windup, phase, weak point).
  Three were added to `sync()`, all reads:
  - the HP, where a drop flinches;
  - the player's bearing from the facing (`BossAvatar.bearing`);
  - the facing, used for the local velocity.
- **`"shielded"`.** This `apply_state` key drives each `_pose_shielded`. Nothing sets it from the sim yet; BF's step
  reads the shield into it.
- **The Warlord's death fall.** The sim removes a boss on the tick it dies. `ActorViews._drop_missing` calls
  `BossAvatar.die()`: the Warlord with its model returns true, keeps drawing for `DEATH_SECONDS` (1.6 s) and is then
  freed. The others, and the code bodies, go at once as before.
- **The weak point's core rides its bone:** the Warlord's on `Spine01`, the Hive Lens's on `tripo__Spine_1`, the
  Foundry's on `body`.
- **Anchors.** `anchor(name)` gives points on the posed body: `weak`; the Warlord's `spear_tip` and `shield`; the
  Hive Lens's `eye`; the Foundry's `door`, `chimney_l`, `chimney_r` and `launcher`. The avatars had no telegraph
  anchors before this; the telegraphs are still drawn from the sim.
- **Reduced motion.** The Hive Lens's idle roll, crown spin and tail sway stop. The moves still pose. The existing
  boss avatars had no reduced-motion handling.
- **Outline and flash.** The model's own material is duplicated, outlined and made flashable (`ActorViews.flashable`),
  with the glow overlay and an X-ray twin on the same skeleton. The twin shrinks 4 cm in metres. No shader changes
  at run time (`test_posing_changes_no_shader`).
- **Fallback.** Without a file, the code bodies draw as before. Their unused nodes are freed when the model draws,
  so there are no orphans.

## Tests
New: `tests/unit/presentation/test_boss_models_2.gd`, 18 tests:
- each model loads, normalises to its height and faces +X;
- the Hive Lens is 1.9 m across;
- the rigged skeletons are kept, with left/right and front checks on bone pivots;
- the Foundry cut gives four legs and a body (bones, corners, weights);
- material, texture, X-ray twin and normal map;
- the code nodes are freed, and the fallback works;
- bone poses change with velocity (Warlord thigh, Foundry leg lift, Hive tail trail with reduced motion on), with
  the shield state (left arm, shield anchor up), with the attack phase (spear raised, planted at the floor, couched
  ahead and low, lunge lean), and with open, closed and aim;
- split, crown spin, and calm with reduced motion;
- flinch on an HP drop, and the shielded hook for each boss;
- the death fall, and ActorViews keeping the Warlord 1.6 s while it frees the Foundry at once;
- the core rides its bone;
- `sync()` from a real WorldReader writes nothing back;
- no shader changes;
- anchors;
- the 1.3× scale for all six bosses and the fallback.

Changed:
- `test_bosses_2_views.gd` pins the code bodies by pointing `BossModels.dir` at a missing folder (they are the
  fallback now).
- `test_boss_models.gd` counts all six loaded models.

Runs, at `3b7e190`:

```
gdformat --check src scripts tests && gdlint src scripts tests
767 files would be left unchanged
Success: no problems found

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation,res://tests/content -ginclude_subdirs -gexit
exit 0
Tests               610
Passing Tests       610
Asserts           1897407
Time              513.357s

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_bosses.gd,res://tests/e2e/test_e2e_bosses_2.gd,res://tests/e2e/test_e2e_boss_challenge.gd,res://tests/e2e/test_e2e_after_boss.gd -gexit
exit 0
Tests                 6
Passing Tests         6
```

Earlier run, at `0f5a90d` (before N18):
- `tests/content`: 124 tests, 123 passing. The failure was `test_credits_licences.gd`
  `test_the_committed_list_matches_a_fresh_build`: the models' file count changed. The list was regenerated, and
  that file plus the manifest test then passed 9/9.
- `tests/unit/presentation`: 485/485.

**Not run by the agent:**
- the full suite (the lead's seams and the PR's shards);
- `scripts/ci/export_smoke.sh`, whose boss-model check now covers six models;
- `tests/golden`, since no sim file changed.

## Screenshots
Taken under xvfb + llvmpipe (`Vulkan 1.4.318 - Forward+ - llvmpipe`) at `3b7e190`. JPGs are converted from the PNGs
under `build/` with `convert -quality 80–82`.
- [`poses_warlord.jpg`](shots/boss_models/poses_warlord.jpg): `scripts/shots/boss_models.gd -- mode=poses`
  (`--resolution 1600x840`), from the game's iso camera next to the hero.
  - Row 1: walk; shield lifted (weak point open); spear raised (spear lines windup); spear planted.
  - Row 2: spear couched (lunge windup); javelin drawn; the shielded hook; the death fall.
- [`poses_hive_lens.jpg`](shots/boss_models/poses_hive_lens.jpg).
  - Row 1: idle; moving (tails trail); open (weak point); closed (shielded hook).
  - Row 2: split (deploy windup); dive windup; glare (ring windup); staggered.
- [`poses_foundry.jpg`](shots/boss_models/poses_foundry.jpg).
  - Row 1: idle; walk (diagonal steps); pour; vent crouch.
  - Row 2: launch; weak point open; the shielded hook; staggered.
- [`game_view.jpg`](shots/boss_models/game_view.jpg): `scripts/shots/bosses.gd -- mode=sheet set=2`
  (`--resolution 1600x900`). This is the real game view (`WorldViewRoot`, a real World, the Ruins stage) with each
  boss idle and in two attacks with their telegraphs.
  - Warlord: spear lines, lunge.
  - Hive Lens: lens sweep, split at half HP.
  - Foundry: molten flood, bomb launch.
- [`raw_models.jpg`](shots/boss_models/raw_models.jpg): the raw renders above.
- `view=side` and `view=front` (close-up cameras) were used to check the poses. They are not committed.

**Agent's reading of the shots:**
- The models read clearly at the bigger size.
- The spear and shield poses read in the side view.
- The Foundry's legs step with no tearing at the hip band.
- The Hive Lens's split is subtle: the pods are one bone (`bone_22`) shared with part of the upper shell, so they
  spread together and can't fly off or vanish the way the code body's pods did.
- The windup glow overlay washes the textured bodies pinker than it does the first three.
- Verdict: `OWNER ONLY`.

## Open items
- The Hive Lens's pods stay on its body after the split. A separate pod object, or the optional Lens Drone model,
  would let them leave.
- The Hive Lens's ground shadow is under the model node, so it dips with the stagger's slump. The code body behaved
  the same way.
- BF: read the sim's shield into `apply_state`'s `"shielded"`, and use `anchor()` for the markers and fireballs.
