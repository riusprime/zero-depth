# HIT_FEEL: impacts, flinch, white flash, thrown damage numbers, shaking crits (v0.8.0 Step GF2)

- **Status:** RUN (tests, shots); the feel is **OWNER ONLY**
- **Build:** the working tree of `v080-gf2` (base `bc2df91` on `claude/lucid-fermat-9wv2tf`) with this step's changes,
  before its commit (the Step GF2 commit is that tree plus this file and the PROGRESS/PLAN rows); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`
- **Date:** 2026-10-15
- **Who ran it:** agent

Owner O20, O21 (verbatim in [`../PLAN.md`](../PLAN.md), third message): "the enemies, when hit by a bullet, should
have particles where it hit and coming behind, so we have an impact, a clear impact of it. And the enemy should
flinch. That doesn't mean to move, so to flinch. And we keep the very short, just a couple of frames, that the enemy
is highlighted in white every time an enemy is hit … the damage numbers, a little bit bigger, just a bit, and they
should come out like they are thrown from the enemy in a curve that goes up and out. And the crit should be a number
that spawns bigger, it has a little shake, and then it vanishes."

## What was built (presentation only; nothing in `src/sim/` changed)
| Owner line | Built | Where |
|---|---|---|
| "particles where it hit and coming behind" | Every hit the player lands on an enemy (DAMAGE owned by the player, not a DoT tick) throws an impact into the effects layer: a flash and sparks back out of the hit point, and a spray of spark streaks out of the far side of the body along the hit's direction. A bolt's is the full one (plus two debris chunks and a puff of smoke); a slash's 0.6 of it; any other hit (area, ability, chain) 0.45, flash and sparks only; a crit ×1.25. Tinted by the hit's first element (`AttackFormLooks.element_color`), none: the hero's blue-white `#BDE0FF`. Direction: a bolt's velocity at the last sync (a bolt fired and landed in one tick: hit point → body centre); a melee or other hit: hero → body | `ImpactFx` (new), `HitFeel`, `VfxCore.streak` (new helper) |
| Budget (PF) | Owner atlases only (`fx_spark_shapes`, `fx_debris_chunks`, `fx_smoke_puffs` through VfxCore's pools and its 2,000-sprite frame cap). At most 32 impacts live (the oldest goes); a hit within 0.45 m of a live impact that began ≤ 3 ticks before merges into it (nothing new drawn); the 8 newest draw at the frame's density, the rest at 0.35 of it; no lights, no decals. Effects density Low (VfxCore.density 0.25, set by the canvas) thins them | `ImpactFx.MAX_LIVE/MERGE_*/FULL/THIN` |
| "the enemy should flinch. That doesn't mean to move" | A pose recoil on the avatar node only: a lean away from the hit (0.3 rad at full) and a squash (−16 % height, +8 % width), peaking at a quarter of 0.2 s and snapping back with a small overshoot; the node's own transform comes back exactly; the sim body and the actor node never move. A new hit restarts it only after 0.12 s, so steady fire keeps it twitching instead of holding it bent. Every normal kind (Charger, Hatchling, Warden, Needle, Arc Caster, Bomb Drone, Lens Drone, the seven horde kinds) through one helper; the drones lean about their hover height. Reduced motion: 0.4 of it | `AvatarBase.flinch / advance_flinch` (Lens Drone now extends AvatarBase) |
| Bosses | The existing BA `flinch` clip (additive layer) now plays on each player hit and on an HP drop, rate-limited: it restarts only once the last one has faded to 0.4 (before, every hit restarted it at t=0, so steady fire held it at its rest key); over an attack's clip it plays at weight 0.5 so it never fights the strike | `BossAvatar.flinch`, `FLINCH_RETRIGGER`, `FLINCH_ATTACK_WEIGHT` |
| "the enemy is highlighted in white" | Unchanged (3 frames, `ActorViews.flash_frames`); checked on every normal kind, the six boss models and the final boss's three bodies, palette A active | test below |
| "damage numbers, a little bit bigger … thrown … up and out" | 15 % bigger (32 → 37, crit 60 → 69). Thrown along the screen to alternating sides (0.9 m out, 0.75 m up at 45 % of the life, both spread 80-120 % by the view's own RNG, never the sim's streams), falling past the start and fading from the peak on (0.75 s). Colours unchanged | `DamageNumbers` |
| "the crit … spawns bigger, it has a little shake, and then it vanishes" | Spawns 1.6× (settling fast), shakes (±0.05 m, 0.22 s, fading), drifts up 0.35 m, then shrinks and fades over its last 30 % (0.8 s life). Reduced motion: no shake, no arc, a short straight rise (0.6 m) for every number | `DamageNumbers` |
| Pool | 40 labels, the oldest reused (the existing rule for rapid hits: there was no merging rule to keep; none was added) | `DamageNumbers.POOL` |

All numbers are starting values. The look and the feel are **OWNER ONLY**.

## Tests
New `tests/unit/presentation/test_hit_impact.gd` (15 tests): every normal kind flinches away from a real
`Damage.hit` read through `HitFeel`, flashes, leans away, settles to its exact rest transform, and neither the sim
position nor the node position moves; the retrigger time and steady fire (twitching, not frozen); reduced motion
×0.4; all nine boss bodies flinch through the clip, rate-limited under steady fire, weight 0.5 over an attack; a real
hit on the Gatekeeper flashes and flinches it; the white flash on every normal kind and boss body with palette A; a
real bolt hit throws one impact along the flight, with its spray beyond the body's far side, drawn into the spark,
debris and smoke pools, and gone after its life; bolt > slash > other; merging (100 hits on one spot → 1), the
MAX_LIVE cap, the thinning past FULL, the pools' caps, Effects density Low; numbers 15 % bigger, thrown to alternating
sides, peaking and falling, fading; a crit big, shaking, then gone; reduced motion (no arc, no shake, a short rise);
the pool of 40.

```
$ gdformat --check src scripts tests && gdlint src scripts tests
928 files would be left unchanged
Success: no problems found

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Warnings              2
Deprecated            1
Scripts              94
Tests               651
Passing Tests       651
Asserts           1941543
Time              556.53s
---- All tests passed! ----

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch -ginclude_subdirs -gexit
Scripts               2
Tests                 4
Passing Tests         4
Asserts           11180
Time              1.162s
---- All tests passed! ----

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/golden -ginclude_subdirs -gexit
Scripts               1
Tests                 2
Passing Tests         2
Asserts               4
Time              6.76s
---- All tests passed! ----

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_damage_soak.gd,res://tests/e2e/test_e2e_enemies.gd,res://tests/e2e/test_e2e_horde_enemies.gd,res://tests/e2e/test_e2e_new_enemies.gd,res://tests/e2e/test_e2e_bosses.gd,res://tests/e2e/test_e2e_bosses_2.gd,res://tests/e2e/test_e2e_final_boss.gd,res://tests/e2e/test_e2e_playground.gd,res://tests/e2e/test_e2e_abilities.gd -gexit
Scripts               9
Tests                13
Passing Tests        13
Asserts             719
Time              148.393s
---- All tests passed! ----
```

After the presentation folder run, the impact's flash, streak widths and spray reach were raised (the first shots
read too faint), so the files that cover them were run again:

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_hit_impact.gd,res://tests/unit/presentation/test_vfx_budget.gd,res://tests/unit/presentation/test_vfx_layer.gd,res://tests/unit/presentation/test_hit_feel.gd -gexit
Scripts               4
Tests                43
Passing Tests        43
---- All tests passed! ----
```

Goldens: none changed (presentation only; `tests/golden` 2/2 unchanged). Not run locally: the full suite and the
seams (the lead's, CLAUDE.md).

## Shots
`scripts/shots/hit_feel.gd` (new): the real game view (WorldViewRoot, Ruins with its lighting mood and effects layer,
the iso camera) of a real World, the Gun build holding fire on one held enemy (speed 0, no attacks). For the crit
shot only, the player's crit chance is raised (the sim caps it at 75 %); nothing else is staged. Rendered one run at a
time (llvmpipe, `--fixed-fps 60` so the frame-time flinch and numbers run at the game's 60 fps pace):

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 -s scripts/shots/hit_feel.gd
hit_feel: res://build/shots/v0.7.5-dev/gf2/1_bolt_impact_spray.jpg (tick 14, impacts 1, flinches 1, numbers 1)
hit_feel: res://build/shots/v0.7.5-dev/gf2/2_bolt_impact_spray_b.jpg (tick 14, impacts 1, flinches 1, numbers 1)
hit_feel: res://build/shots/v0.7.5-dev/gf2/3_flinch_charger.jpg (tick 11, impacts 1, flinches 1, numbers 1)
hit_feel: res://build/shots/v0.7.5-dev/gf2/4_flinch_swarmer.jpg (tick 11, impacts 1, flinches 1, numbers 1)
hit_feel: res://build/shots/v0.7.5-dev/gf2/5_thrown_numbers.jpg (tick 25, impacts 3, flinches 2, numbers 3)
hit_feel: res://build/shots/v0.7.5-dev/gf2/6_crit_number.jpg (tick 14, impacts 1, flinches 1, numbers 1)
```

The script names its folder by `GameVersion.label()` (`v0.7.5-dev` on this branch); the files were copied by hand to
`build/shots/v0.8.0/gf2/` and to [`gf_shots/`](gf_shots/):
1. [`1_bolt_impact_spray.jpg`](gf_shots/1_bolt_impact_spray.jpg): a bolt landing on a Warden: the flash on its near
   side, the spray out of its back.
2. [`2_bolt_impact_spray_b.jpg`](gf_shots/2_bolt_impact_spray_b.jpg): the same on a Charger at another angle.
3. [`3_flinch_charger.jpg`](gf_shots/3_flinch_charger.jpg), [`4_flinch_swarmer.jpg`](gf_shots/4_flinch_swarmer.jpg):
   the frame the flinch is past 0.6 (a still shows the lean; the motion is OWNER ONLY).
4. [`5_thrown_numbers.jpg`](gf_shots/5_thrown_numbers.jpg): three numbers in the air on their arcs to both sides, the
   Warden in its white flash with the impact's chunks and spray.
5. [`6_crit_number.jpg`](gf_shots/6_crit_number.jpg): a crit's big yellow number three ticks after it spawned (in its
   shake), the impact's flash and spray.

The Gun's damage here is the starting build's (3-4 a bolt), so the numbers are small; GF1 changes the Gun's damage and
its bolt look in parallel (not in these shots).

## Owner only
- Do the impacts read as "a clear impact"? Is the spray behind the body visible enough, too much?
- Does the flinch read as a flinch without looking like movement? Bosses: is the clip's flinch enough under fire?
- Numbers: size, the throw's height and reach, the crit's shake.
