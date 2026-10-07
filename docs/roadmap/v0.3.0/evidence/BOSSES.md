# v0.3.0 Step C: the three bosses (evidence)

Build: `a8a1caa` (the bosses workstream merged with `claude/lucid-fermat-9wv2tf` at `f13bcfb`). The suite run below
was made on that tree before `tests/MIN_TEST_COUNT` was raised from 362 to 403 in the same commit.

## What was built

| Boss (floor pool) | Sheet name | HP | Radius | Arena (cells, template) | Phase 1 | Phase 2 (at 50 % HP) |
|---|---|---|---|---|---|---|
| Gatekeeper (floor 1) | Stone Sentinel | 1400 | 1.3 m | 3 x 3, pillars | Fist Slam (spike ring 2.1-4.0 m), Shock Lanes x3, Sweep (180°, 2.4 m) | opens with a Charge (18 m lane); Shock Lanes x5; +15 % speed, cooldowns x0.8 |
| Brood Mother (floor 2) | Crawler Queen | 1600 | 1.2 m | 2 x 2, scatter | Leap (2.4 m disc on your spot), Burrow (ripple tracks you 1.6 s, then a 2.2 m eruption marked 0.6 s), Brood (3 eggs, up to 6 hatchlings alive) | Leaps chain twice, Brood of 4 with a shorter windup; cooldowns x0.8 |
| Siege Engine (floor 3) | Fortress Turret | 1800 | 1.4 m | 3 x 1, lines | Barrage (5 shells, 1.6 m), Rail Sweep (110° beam, 13 m), Bolt Fan (7 bolts x 3 volleys) | plants (speed 0) and opens with Deploy (two Needle turrets); Barrage of 7; cooldowns x0.65 |

- Every telegraph is at least 24 ticks (validation, plus the runtime test below). Stagger: Gatekeeper 220 points
  (decay 12/s), Brood Mother 260 (14/s), Siege Engine 300 (15/s); a full meter staggers for 2.5 s (150 ticks).
- Armour: the Gatekeeper takes 80 % from the front 120° and 110 % from the rear 120°, as the Warden. The other two
  have none (the PLAN gives armour only to the Gatekeeper).
- The Gatekeeper's arena uses the generator's PILLARS template: the pillars are normal cover, not breakable
  (breakable pillars would need a destructible-wall system in the sim; left for the owner to decide). The Siege
  Engine's cover lines are not destroyable either, for the same reason.
- Every number is a starting value.

## Commands and raw output

Full suite (`bash scripts/verify.sh`, run in the worktree at the tree above):

```
REPLAY| final=5171fdadd6442c3e5c568273b2fcb361fa5f19fddd3e922231fe6c4bb3d841ae
BOSSFIGHT| gatekeeper ticks=3379 seconds=56.3
BOSSFIGHT| brood_mother ticks=4307 seconds=71.8
BOSSFIGHT| siege_engine ticks=3310 seconds=55.2
Tests               403
Passing Tests       403
check_gut_log: ok (403 passing, minimum 362)
```

Fight length (`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd
-gtest=res://tests/unit/sim/test_boss_fights.gd -gexit`, at `a8a1caa`):

```
BOSSFIGHT| gatekeeper ticks=3379 seconds=56.3
BOSSFIGHT| brood_mother ticks=4307 seconds=71.8
BOSSFIGHT| siege_engine ticks=3310 seconds=55.2
```

The bot has no items, never stops shooting (4 damage per 0.12 s, about 33/s) from 4-6 m, and can't die. That is a
perfect-uptime floor; the test's band is 30-90 s. A real player who spends part of the fight dodging will take
longer; whether that lands in the PLAN's 60-120 s with a few items is `NOT YET RUN` (it needs the owner's playtest
or a bot that dodges).

Renders (`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot
--path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/bosses.gd -- mode=sheet`, then the same with
`mode=compare`, at `a8a1caa`):

```
bosses: res://build/shots/v0.2.0-dev/bosses/bosses.png cells=gatekeeper idle, gatekeeper fist_slam, gatekeeper shock_lanes_5, brood_mother idle, brood_mother leap, brood_mother brood_4, siege_engine idle, siege_engine barrage_7, siege_engine rail_sweep
bosses: res://build/shots/v0.2.0-dev/bosses/boss_gatekeeper_compare.png
bosses: res://build/shots/v0.2.0-dev/bosses/boss_brood_mother_compare.png
bosses: res://build/shots/v0.2.0-dev/bosses/boss_siege_engine_compare.png
```

The PNGs here are those files, quantised to 256 colours by hand (the compares also scaled to 75 %):
`bosses.png` 145,737 bytes, `boss_gatekeeper_compare.png` 222,701, `boss_brood_mother_compare.png` 212,531,
`boss_siege_engine_compare.png` 216,774.

- [`bosses.png`](bosses.png): the game's view (Ruins stage, iso camera, ActorViews, TelegraphViews) of a real
  World: each boss idle, then two attacks two thirds into their windups.
- `boss_<id>_compare.png`: the sheet's row on top; below, the code model in the sheet's FRONT, RIGHT-FRONT and RIGHT
  views and an iso inset with the player for scale.

## How close the models are to the sheet (agent's reading, not the owner's)

- Stone Sentinel: the red crystal crown, visor slot, boulder shoulders, stacked fists, back shell with glowing
  cracks and short legs read. Still off: the sheet's crown is one chunky faceted mass that frames the visor; ours is
  separate spikes. The sheet's fists hang wider and lower.
- Crawler Queen: the hood with the hex visor, the egg sac with spikes behind and eight legs with pale talons read.
  Still off: the sheet's sac is larger and glossier, its legs are thicker with more joints and curl inward.
- Fortress Turret: red box hull, slit eyes, long vented cannon, back mortars with red glow, four heavy legs read.
  Still off: the sheet's hull is longer front to back and its leg armour heavier.
- Owner's verdict: `OWNER ONLY`.

## C2: the owner's models replace the code-built bodies (PLAN L13)

Build: the working tree on top of the merge of `claude/lucid-fermat-9wv2tf` at `b7fdd9e`, committed as
`v0.3.0 Step C2`. This file is part of that commit, so its SHA is in the hand-off report rather than here.

- Installed: `assets/models/bosses/stone_sentinel.glb`, `crawler_queen.glb`, `fortress_turret.glb` (`git mv` from
  the owner's upload), `assets/models/manifest.json` (id, path, sha256), and the `.import` files and extracted
  textures that the import created at the new path. `tests/content/test_model_manifest.gd` checks the manifest
  both ways.
- Orientation, read from renders of the raw models turned 0/90/180/270° (a scratch render under `build/`): all three
  are Y-up. The Stone Sentinel and the Fortress Turret face +X already (yaw 0); the Crawler Queen faces -Z (yaw
  -90°).
- Size: scaled so the height is the code body's (Sentinel 2.95 m, Turret 2.5 m), and 2.4 m for the Queen (2.1 m
  read small beside the sheet). Feet sit at y = 0, centred in x and z. The meshes are rebuilt once per type in our
  frame (`BossModels`, cached) and preloaded when the stage is built (`WorldViewRoot.setup`), never on a spawn.
- Material: the model's own material, duplicated (the albedo texture is kept; the Sentinel also keeps its normal
  map), made flashable (`ActorViews.flashable`), outlined like the other actors, with shadows on, plus an X-ray
  twin with the X-ray technique.
- Motion is whole-body:
  - breath, and a walk bob and sway;
  - a windup lean and crouch;
  - a lunge and squash on the attack, or a recoil for the turret;
  - a sag in recovery and a wobble when staggered.

  A red additive `material_overlay` glows: its alpha rises in the windup, on the hit, and stays up in the last
  phase. Nothing changes a shader at run time.
- Export: `bash scripts/ci/export_smoke.sh` (exit 0) now also checks that each model loads from the pack:

```
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
0 miss(es)
```

- Suite: `bash scripts/verify.sh` (exit 0) printed `Tests 445`, `Passing Tests 445` and
  `check_gut_log: ok (445 passing, minimum 436)`. `MIN_TEST_COUNT` is raised to 445.
- Renders: `scripts/shots/bosses.gd` with `mode=compare` and `mode=sheet` (the same commands as above) →
  [`boss_models.png`](boss_models.png). It shows each sheet row over the model in the same three views, with the
  iso inset next to the hero, then the game-camera sheet (idle and two windups for each boss). The file is 478,151
  bytes: 960 px wide, 192 colours, scaled and quantised by hand.
- Agent's reading: the models match the sheet far better than the code bodies did, because they are the sheet's
  designs. The windup glow over the whole body reads strong in the game view, and the owner may want it lower.
  Verdict: `OWNER ONLY`.

## C3: the owner's models are rigged in code and animate limb by limb

Build: the working tree on top of `b5afd8d` (C2 `6063cad` merged with B's run flow), committed as
`v0.3.0 Step C3`. This file is part of that commit, so its SHA is in the hand-off report rather than here.

- **How the rig is built (`BossRig`, once per boss type, cached in `BossModels`):** bone pivots and vertex regions
  come from vertex histograms of each model in our frame (a scratch probe under `build/`, not shipped). Every
  vertex gets at most 4 bones, with weights normalised to 1. The weights blend over 0.1-0.3 m across each seam,
  so the mesh bends instead of tearing. The rig is written as `ARRAY_BONES` and `ARRAY_WEIGHTS` into the cached
  mesh, with a `Skin`. Each avatar makes its own `Skeleton3D`.
  - **Stone Sentinel (9 bones):** root, torso, head and crown, upper arm × 2, forearm and fist × 2, leg × 2. The
    arms are everything beyond |z| ≈ 1 m (a little further out near the ground, so the feet stay with the legs).
    The fists are the part of each arm below about 1.15 m.
  - **Crawler Queen (11 bones):** root, body and hood, egg sac, and 8 legs. The legs are the vertices outside the
    body-and-sac outline below 1.4 m, clustered by their angle round the body: 4 per side (1-D k-means). Each hip
    is the mean of that leg's vertices nearest the body.
  - **Fortress Turret (13 bones):** root, hull, main cannon (everything forward of x ≈ 0.95 m and above 1.35 m), two
    mortar tubes (back top, split left/right with a blend across the middle), and 4 legs. Each leg has a thigh
    and a shin. The front legs stand at x ≈ 0.65 m and the back legs at x ≈ -1.95 m, measured from the feet.
- **How the bones move** (`_pose_rig` on each avatar, on top of the C2 whole-body motion):
  - Sentinel: the fists rise overhead for the slam and the lanes and come down in front, the right arm draws back
    and sweeps with a torso twist, the arms swing back for the charge, arms and legs swing in the walk, the crown
    nods, and the arms hang when staggered.
  - Queen: the legs scuttle in alternating sets, the front legs rear up with the body before a leap, the legs tuck
    in the air, the sac swells before a brood, and the legs splay when staggered.
  - Turret: the legs step in diagonal pairs, the cannon recoils with each bolt volley and lifts as the rail
    charges, the mortars tilt up and kick for a barrage, the hull squats to deploy and stays low once planted (the
    last phase), and it lurches when staggered.
- **Fixed along the way:**
  - The X-ray twin of a skinned mesh shares its surface and z-fought with the body. On the Sentinel it hid the
    texture entirely. The twin now shrinks along its normals instead (`grow`, -0.04 m, set when built).
  - The C2 glow overlay was additive. Additive blending washed the bodies pink, because alpha doesn't scale it.
    It is now a mix overlay at a low alpha (0.045 × windup, 0.04 × hit, 0.02-0.03 steady in the last phase).
    Only the alpha changes at run time.
- **Renders** (`scripts/shots/bosses.gd -- mode=rigs`, the same command form as above) →
  [`boss_rigs.png`](boss_rigs.png). Each row shows the hero, then the boss in four poses from the iso camera:
  - Sentinel: walk, slam windup, slam, sweep.
  - Queen: walk, leap windup, leap (airborne), brood windup.
  - Turret: walk, barrage windup, bolt fan recoil, planted with the deploy windup.

  The file is 174,151 bytes, cropped and quantised by hand. I also re-rendered the compare views and the
  game-camera sheet: nothing tears in the rest pose.
- **Suite:** `bash scripts/verify.sh` (exit 0) printed `Tests 482`, `Passing Tests 482` and
  `check_gut_log: ok (482 passing, minimum 475)`. `MIN_TEST_COUNT` is raised to 482.
  `bash scripts/ci/export_smoke.sh` exited 0 with 0 misses.
- **Tests (`tests/unit/presentation/test_boss_rigs.gd`):**
  - bone counts;
  - every vertex weighted, normalised, and pointing at real bones;
  - every bone carries vertices;
  - the Queen has 4 legs a side;
  - each rig is built once per type;
  - the mesh is skinned to the avatar's skeleton;
  - the slam raises the fist above 1.6 m;
  - the Queen's legs move while walking and her body rears before a leap;
  - the cannon kicks back on a bolt volley.
- **Agent's reading of the renders:**
  - The Sentinel's arm poses read clearly.
  - The Queen's leg motion reads, but her rear-up is small at this camera distance.
  - The Turret's mortar tilt and recoil are subtle from the iso camera. They are visible in motion but hard to see
    in a still.
  - At the extremes there is some stretching at the seams: the Sentinel's raised arm shows a thin dark sliver at
    the shoulder. Nothing tears open.
  - Where the squatting turret pushes a foot below the ground, the X-ray twin shows as a small red patch.
  - Verdict: `OWNER ONLY`.
