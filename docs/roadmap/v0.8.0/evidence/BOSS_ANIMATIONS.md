# v0.8.0 BA: boss animation rework (owner O6, Q4)

Owner, 2026-10-14: "the animations they do are a shit, actually. So we have to work on animations from there, like we
did with the actual attacks of the player." Q4: "Code first, yours replace (Recommended)".

Build: branch `v080-ba` from `0dfa2c7`. Every command below was run on that branch's working tree before the
`v0.8.0 Step BA` commit (the commit's SHA is in the hand-off report, not here). Machine: a shared cloud container,
Godot 4.7.2.stable, renders on llvmpipe (software GL) under xvfb, not the owner's hardware.

## What was built
- **`src/presentation/world_view/boss_anim/boss_clip.gd` (BossClip):** one keyframed clip. Tracks move a bone or
  the whole body (`BODY`, the model's pivot) by a turn (radians about a model-frame axis), a shift (metres) or a
  stretch (a bone's scale; on the body a volume-keeping squash), or set a named parameter the avatar maps onto its
  parts (a spider's leg sets, the Hive Lens's tails, the Foundry's heat). Keys carry an ease: LINEAR, IN, IN3, OUT,
  OUT3, IN_OUT, BACK (overshoot), HOLD. Keys flagged SETTLE are overshoots and settling bounces. Values are offsets
  from rest, so clips add up. Sampling allocates nothing.
- **`boss_animator.gd` (BossAnimator):** plays the clips in additive layers, in this order:
  - idle, a loop in seconds;
  - walk, whose time is the gait's phase, so the steps match the speed;
  - the action, the attack's clip, crossfaded from the previous attack in 0.1 s and faded out in 0.22 s;
  - the shielded hold, a flinch, the stagger, the gate roar, the rise and the death.

  It writes bones through the avatar's BonePoser and the body onto its pivot.
- **Timing from the sim (EI-03: nothing here decides an outcome).** `BossAvatar.clip_time` maps the attack's phase
  onto the clip:
  - the windup fills 0..`strike` (0.5);
  - the first active tick is exactly `strike`: the tick the hit resolves;
  - the active ticks run `strike`..`hold` (0.62);
  - the recovery runs `hold`..1.

  A `marks` / `row_lanes` attack with several markers cycles `strike`..`hold` once per marker, so each marker's tick
  shows the strike pose. Impact clips keep the same pose at `strike` and `hold`.

  The first frame after each sync shows that tick exactly. Faster displays run on between ticks.

  New read-only reads:
  - `WorldReader.boss_attack_ticks(i)`: windup, active and recover ticks, and the gap between strikes;
  - `WorldReader.STATE_GATE`;
  - `sync()` also passes the gate's progress and the intro's progress.

  The rise now follows the boss bar's intro (L22) instead of starting after it.
- **The owner's clips (Q4).** If a model's scene ships an AnimationPlayer, each animation whose name is a clip name
  (`idle`, `walk`, `marks`, `pattern`, `death` …) replaces that code clip at the same time and weight
  (`BossAnimator.bind_owner`, `apply_owner`; bones matched by name).

  An attack animation may carry the markers `strike` (the pose on the active tick) and `recover` (the end of the
  active part); without them, its length maps onto 0..1.

  None of today's six files has an AnimationPlayer: checked with a scratch script (`build/tmp/bones.gd`, not committed): `anim players: 0` for the
  Warlord and the Hive Lens. The other four are single meshes rigged in code, so the hook is for the owner's rigged
  replacements.
- **Death for all six.** Every owner's model now plays a collapse after the sim removes it. Before, only the Warlord
  fell. ActorViews keeps the body `DEATH_SECONDS` (1.6 s), as it did for the Warlord. The code-built fallback bodies
  still go at once.
- **The avatars.**
  - The six `_pose_rig` functions lose their per-move pose code for the owner's models. Each keeps only what follows
    the clips:
    - the Warlord's shield lift while the weak point is open;
    - the Hive Lens's crown spin, eye aim, lagging tails, open pose and split;
    - the Brood Mother's, Siege Engine's and Foundry's legs mapped from the clips' parameters;
    - the Foundry's grate light from the `heat` parameter.
  - The code-built fallback bodies (`_pose`) are unchanged.
- **Reduced motion.**
  - SETTLE keys are skipped and BACK eases become OUT3: the same strike and hold poses, no overshoot.
  - The `tremble` shake and the stagger's `daze` sway are off.
  - The Hive Lens's idle roll and pitch are SETTLE keys, so they stop; its crown's idle spin stops as before.
- **Outline / X-ray twin.** Unchanged. The owner's models still have no drawn outline (thickness 0), the twin stays
  on the same skeleton, and no shader changes at run time (tested for all six through every move clip, the roar, the
  stagger and the death).
- **Cost.** The libraries are built once per boss type (static). Sampling walks packed arrays.

  Per frame, the layer arrays and the parameter dictionary are reused. BonePoser's per-bone dictionaries are written
  as before.

  Not measured: frame time on the owner's PC, which is **OWNER ONLY**.

## Clips per boss (from `data/bosses/*.tres`; `*` = a shielded attack)
Scratch dump of the libraries (`build/tmp/cliplist.gd`, not committed), raw. The number in brackets is the clip's
track count.
```
gatekeeper: 13 clips, 760 keys: idle(11), walk(14), marks(14), row_lanes(17), pattern(13), pattern_shielded(13), sweep(11), shielded(8), flinch(5), stagger(11), roar(11), rise(9), death(12) | data moves: pattern*, pattern, marks, row_lanes, sweep
warlord: 13 clips, 621 keys: idle(13), walk(16), pattern(9), sweep(12), flood(14), charge(13), barrage(10), shielded(10), flinch(5), stagger(12), roar(9), rise(10), death(11) | data moves: pattern*, pattern, sweep, flood, charge, barrage
brood_mother: 13 clips, 428 keys: idle(7), walk(9), marks(7), pattern(7), leap(7), burrow(7), brood(6), shielded(4), flinch(4), stagger(6), roar(7), rise(5), death(6) | data moves: marks*, pattern, leap, burrow, brood
hive_lens: 13 clips, 359 keys: idle(5), walk(4), pattern(7), lanes(8), slam_ring(7), leap(7), deploy(4), shielded(6), flinch(3), stagger(5), roar(7), rise(5), death(7) | data moves: pattern*, pattern, lanes, slam_ring, leap, deploy
siege_engine: 14 clips, 459 keys: idle(6), walk(7), pattern(7), grid(8), marks(8), lanes(8), deploy(6), slam_ring(7), shielded(5), flinch(3), stagger(6), roar(6), rise(4), death(7) | data moves: pattern*, grid, marks, lanes, deploy, slam_ring
foundry: 13 clips, 333 keys: idle(4), walk(7), pattern(6), row_flood(5), slam_ring(6), brood(6), flood(7), shielded(3), flinch(3), stagger(6), roar(5), rise(4), death(7) | data moves: pattern*, pattern, row_flood, slam_ring, brood, flood
```
(The dump was taken before two later tweaks: the Brood Mother's sac hoist was softened, because the seam opened in
the render, and the Foundry's pour got a rock back and a deeper pitch. The track counts above are unchanged except
`foundry row_flood`, which gained one body-tilt track, 6 tracks.)

What each move does, in short; the doc comment at the top of each `*_clips.gd` says more:
- **Gatekeeper.**
  - Fist Slam (`marks`): both fists hauled overhead, then hammered down once per marker, with a squash and a tremble.
  - Shock Lanes (`row_lanes`): one fist wound far back, then a twisting ground punch.
  - Cross Quake (`pattern`): arms flung wide in a T, then fists punched into the ground and held, pumping.
  - Rock Rings (`pattern_shielded`): curled into a boulder behind its crossed arms.
  - `sweep`: a whole-body backhand.
- **Warlord.**
  - Javelin Fan (`pattern`): the spear raised, then thrust and jabbed with each wave. The Shield Wall adds the
    braced `shielded` hold.
  - Shield bash (`sweep`): the shield drawn back, then rammed forward with a step.
  - Spear Lines (`flood`): the spear hoisted overhead, then planted in the floor on one knee.
  - Lunge (`charge`): the spear couched low on the back leg, then thrust at full stretch.
  - Javelin Rain (`barrage`): the spear drawn back over the shoulder, then hurled with a full follow-through.
- **Brood Mother.**
  - Egg Storm (`marks`): the sac hoisted and swollen, then whipped forward once per egg.
  - Web Spiral (`pattern`): it rears, then jerks side to side spewing.
  - `leap`: a coiled crouch, the launch, tucked in flight, a splayed squash on landing.
  - `burrow`: alternating front-leg digs, a nose-first dive, then a rearing eruption.
  - `brood`: the sac swells and heaves.
- **Hive Lens.**
  - Patterns: it pulls back and swells, then snaps forward and pulses with each wave. The Prism Spiral adds the
    closed `shielded` pose.
  - Focus Beam (`lanes`): the eye narrows with a charging tremble, then the shot recoils it.
  - Lens Flare (`slam_ring`): it contracts, then bursts open with its tails flung out.
  - Dive (`leap`): it rises high, dives head first with tails streaming, and squashes as it lands.
  - Split (`deploy`): a shudder and a swell.
- **Siege Engine.**
  - Turret Cross (`pattern`): braced in a wide squat, kicking back with each volley as the hull turns.
  - Mortar Grid (`grid`): back legs kneel, then the tubes crank up and thump.
  - Barrage (`marks`): the tubes thump once per marker.
  - Rail (`lanes`): it kneels with the cannon levelled, then a huge recoil.
  - `deploy`: it squats flat, then a pop.
  - Shockwave (`slam_ring`): it rears up, then stamps down.
- **Foundry.**
  - Patterns: a crouch, then a heave and pumping eruptions.
  - Molten Flood (`row_flood`): it rocks back, then tips forward over folded front legs to pour.
  - Vent Blast (`slam_ring`): a splayed crouch, then a hop.
  - Bomb launch (`brood`): it rocks back on its back legs, then kicks forward.
  - Firestorm (`flood`): it rears, then slams down.
- **All six**: `idle`, `walk`, `shielded`, `flinch`, `stagger` (a reel, then a slump), `roar` (the phase gate),
  `rise` (with the intro, then a flourish), `death` (a collapse, then it sinks).

## Tests
New: `tests/unit/presentation/test_boss_animations.gd`, 15 tests:
- sampling, eases, wrap; reduced motion drops overshoots;
- every boss has every clip its data's moves need, the shielded pose, and the common clips;
- clips only move bones the model has, and attack clips end at rest;
- each attack's anticipation and strike are big poses;
- **from a real world through WorldReader** (one attack per boss: fist_slam, shield_bash, brood, lens_flare,
  shockwave, vent_blast), the clip time is exactly `strike` on the first active tick, below it in the windup, and at
  least `hold` in recovery;
- the Gatekeeper's 3-marker Fist Slam strikes on each marker's tick (counted once per tick through hitstop);
- crossfade; shielded variants and holds; the gate roar, the rise with the bar, the flinch;
- all six collapse;
- outline, X-ray twin and no shader change;
- reduced motion: the same strike pose, no shake or sway;
- an owner AnimationPlayer clip replaces the code clip, with strike/recover markers mapped;
- `boss_attack_ticks`, and sync writes nothing back (state hash unchanged).

Changed on purpose:
- `test_boss_models_2.gd`: the Hive Lens and the Foundry now die with a collapse, and ActorViews keeps both a moment.
- `test_boss_rigs.gd` and `test_boss_models.gd`: drive the moves the data uses now. The Gatekeeper's `marks` was
  `slam_ring`; the Siege Engine's `pattern` / `lanes` were `bolt_fan`, which no shipped boss uses since v0.7.5 BF.

Runs (final, after the last clip tweaks):
```
$ gdformat --check src scripts tests && gdlint src scripts tests
833 files would be left unchanged
Success: no problems found

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<the 20 files tests/unit/presentation/test_*{boss,avatar,windup,damage_flash}*.gd> -gexit
exit 0
Tests               158
Passing Tests       158
Asserts            7106
Time              53.541s

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
exit 0
Tests                 6
Passing Tests         6

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_after_boss.gd,res://tests/e2e/test_e2e_boss_challenge.gd,res://tests/e2e/test_e2e_boss_dodge.gd,res://tests/e2e/test_e2e_boss_dodge_2.gd,res://tests/e2e/test_e2e_boss_dodge_3.gd,res://tests/e2e/test_e2e_bosses.gd,res://tests/e2e/test_e2e_bosses_2.gd -gexit
exit 0
Tests                 9
Passing Tests         9

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_boss_markers.gd,res://tests/unit/sim/test_bosses_2.gd -gexit
exit 0
Tests                30
Passing Tests        30
```
The arch/golden, e2e and sim runs were taken before the last two clip tweaks, which only changed key values in
`brood_mother_clips.gd` and `foundry_clips.gd` and the Hive Lens's shadow clamp. The animation and model tests (46/46)
and the 158-test set were rerun after them.

**Not run locally:** the full suite, which runs on GitHub for the PR (CLAUDE.md), and `scripts/ci/seams.sh` (the
lead's step).

## Shots
`scripts/shots/boss_anims.gd`, one boss per run (the machine is shared):
```
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 1600x840 -s scripts/shots/boss_anims.gd -- boss=<id>
boss_anims: renderer=gl_compatibility
boss_anims: <id> row 0: idle, windup (anticipation), strike (first active tick), recovery
boss_anims: <id> row 1: shielded pattern, staggered, phase gate roar, death (collapse)
boss_anims: res://build/shots/v0.8.0/ba/<id>.png
```
Each of the six ran with exit 0 and printed those lines. The PNGs were converted with `convert -quality 82` to
[`ba_shots/`](ba_shots/): `gatekeeper.jpg`, `warlord.jpg`, `brood_mother.jpg`, `hive_lens.jpg`, `siege_engine.jpg`,
`foundry.jpg`.

Each sheet is two rows of four, from the game's iso camera with the hero for scale:
- Row 1: idle; late windup (clip time 0.46); the first active tick; a quarter into the recovery.
- Row 2: its shielded pattern just after the strike; staggered; the gate roar; the collapse at about 75 %. The
  collapse is turned away from the camera, so it stays in its cell.

Each sheet's attack:
- Gatekeeper: Fist Slam.
- Warlord: Spear Lines.
- Brood Mother: Egg Storm.
- Hive Lens: dive.
- Siege Engine: shockwave.
- Foundry: Molten Flood.

Agent's reading of the shots (not a verdict):
- Each boss's windup, strike and roar change its outline from the iso camera.
- The Foundry's moves are the smallest: it is a squat body with stub legs.
- Shapes worth watching:
  - The Siege Engine's legs stretch at the hip when squatting (the code rig's weights).
  - The Gatekeeper's Rock Rings curl reads as a wide, flattened crouch more than a ball.
- An earlier Brood Mother render opened the seam between the body and the sac at the full hoist. The hoist was
  softened, and the committed sheet is the re-render.

**The feel (weight, timing, whether it reads in a fight) is OWNER ONLY.**

## Open
- The owner's clips replace these when they come: name them as the clips above. Attack clips can carry the
  `strike` / `recover` markers.
- The single-mesh models (Gatekeeper, Brood Mother, Siege Engine, Foundry) have code rigs, so owner clips for them
  need a rigged model first.
- Camera shake and VFX on the strike tick are not part of BA. Other steps own fireball, telegraph, spike and VFX.
