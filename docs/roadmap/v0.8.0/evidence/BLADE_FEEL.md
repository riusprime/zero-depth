# BLADE_FEEL: the Blade's swing, impact, flinch and hit-stop (v0.8.0 Step GF3, owner O22)

- **Status:** RUN (tests, shots); the feel is **OWNER ONLY**
- **Build:** the working tree of `v080-gf3` (base `05c3b8c` on `claude/lucid-fermat-9wv2tf`) with this step's changes,
  before its commit (the Step GF3 commit is that tree plus this file and the PROGRESS/PLAN rows); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`, a cloud container shared with other agents
- **Date:** 2026-10-15
- **Who ran it:** agent

Owner O22 (verbatim in [`../PLAN.md`](../PLAN.md)): "we have to do the exact same exercise to the blade, animations,
hit enemy, flinch, hit animation, what we did to the gun but applied to the blade, also for the blade and flinch we add
a 2 frame or so freeze to make the hit feel better". Owner, v0.6 VFX_REQUESTS: "sword animation stays as is for now I
like it": the laser blade, its trail, the slash forms (BladeFormView, AttackFormView) are kept and the new looks are
layered on them.

## Found: the sim already has a Blade hit-stop (for the lead and the owner)
Every swing that lands adds its step's `hitstop_ticks` to `World.freeze_ticks` (`PlayerKit._resolve_swing`,
`src/sim/combat/player_kit.gd:162-163`), and a frozen tick holds the whole sim (`World.step` phase 1, SIM_CONTRACTS §2).
The four steps' values (`data/player/runner.tres`): **3, 3, 4 and 7 ticks** (50, 50, 67 and 117 ms), already longer
than the "2 frame or so" asked. The shot script's output shows it: the first slash's grab printed "swing tick 3" at
world tick 4, 5 and 6 in three runs (the final run's line is below): the swing stood still in the sim while its clock
ran on. PRESENTATION_CONTRACTS §6 (rank 3) says "Hit-stop is sim state … The view shows it; it never creates
it."; O22's lead's reading (PLAN, rank 1 once written there) puts the asked freeze in the view.

What GF3 does, as briefed: the view's hold (below) is built and sits inside the sim's own freeze; it holds what the sim
freeze did not (the frame-time animation: the struck enemy's model and its GF2 flinch, the hero model's pose, the white
flash's frame count). Not resolved here (CLAUDE.md "Authority": never quietly): whether to keep both, drop the view's,
or make the view show the sim's freeze instead (and amend PRESENTATION §6) is a question for the owner. Nothing in the
sim, its data or the Blade's numbers changed.

## What was built (presentation only; nothing in `src/sim/` changed)
| Owner line | Built | Where |
|---|---|---|
| "animations" (the swing) | Every combo step accents the hero model, timed to the sim's swing ticks (`swing_tick`, `swing_active_tick`, `swing_sweep_ticks`, `swing_ticks`, `is_finisher`; run on in frame time up to one tick past the last sync): a **wind-up** up to the hit tick (the hips drop 0.05 m, the body draws back 0.12 rad, the head and poncho wind 0.32 rad further back, the hood tips back), the **swing** from the hit through the sweep (the body drives 0.2 rad into the aim, the hood pitches in 0.16 rad, the visor flares ×1.8), a **follow-through** over the recovery (the head carries on 0.36 rad past the arc's end, then settles). The finisher's is ×1.6. Reduced motion: no follow-through (no overshoot). Added on top of the existing swing pose, not replacing it. The sim's steps hit on tick 2, 3, 4 and 7, so the wind-up is 1-6 ticks long | `PlayerAvatar.swing_accent`, `WIND_*`, `STRIKE_*`, `FOLLOW_*`, `ACCENT_FINISHER` |
| the slash trail | A bright slash **edge** over the existing trail (the tip's band, 0.84-1.03 of the blade's span, peak opacity 0.95, the finisher's ×1.25), in the hero's blue-white `#BDE0FF`; the step's first element tints it (`AttackFormLooks.element_color`), the heat tier from Hot up. One ImmediateMesh built once, rebuilt with the trail; the thrust gets a narrow bright fan at its tip | `KitView` (`_build_edge`, `edge_color`) |
| the edge spark | A light spark rides the blade's tip through the sweep (`KitView.blade_tip_point`, the blade as drawn this frame) and flares on the hit tick (the cut, 0.62 m; the finisher's 0.85 m), fading as the blade settles. Pooled: 3 built once, one a swing | `BladeSwingFx` (new; the Gun's cast-spark shader) |
| "hit enemy … hit animation" (the impact) | Every slash hit throws its own impact: a **cut** along the swing's tangent where it struck (a thrust's along its aim), drawn out in its first moment, over a hot spark; **sparks thrown along the tangent** (13 at strength 1), not the bolt's spray out of the back; two chips back off the body. Strength **1.1** (a bolt's is 1.0; GF2's 0.6 share is gone), the finisher's ×1.3, a crit's ×1.25. Drawn on the struck body's side toward the camera (65 % of the way from the blade's way in to the camera's direction, 1.35 body radii out), so the body doesn't hide it. Tinted by the step's element, the hero's blue-white otherwise. Within GF2's budget: the same MAX_LIVE 32, merging (0.45 m, 3 ticks), FULL 8 / THIN 0.35, Effects density, VfxCore pools and frame cap | `ImpactFx` (`_draw_slash`, `slash_tangent`, `slash_spark_at`) |
| "flinch" | A slash's flinch is ×1.35 a bolt's (lean and squash) and **knocks the pose** up to 0.09 m (×0.8 a step, ×1.0 the finisher) away from the swing (the hit's way in leaned 0.6 along the tangent); the node only, back to rest exactly; the sim body and the actor node never move. Reduced motion ×0.4. Bosses: their BA flinch clip on each Blade hit, rate-limited as in GF2 | `AvatarBase.flinch(away, strength, knock)`, `ImpactFx.FLINCH_SLASH`, `KNOCK_*`, `BossAvatar.flinch` |
| "a 2 frame or so freeze" | On a Blade hit (a player DAMAGE event tagged MELEE), the view holds for **2/60 s of frame time**: the hero model's pose, the laser blade and its trail (the syncs inside the hold are caught up when it ends), each struck enemy's model (jumped to its flinch's peak: the impact pose) and its white flash (lit, its frames not counted). Each held view drops only the held share of its frame time and runs on from where it stopped (no pop). A **0.06 m camera kick** along the swing (0.1 m on the finisher), easing out over 0.09 s; none with shake off or reduced motion. **Shared:** one swing's hits join the running freeze (a second struck enemy is held for what is left), never stacked or lengthened; a later hit of the same swing makes no second freeze. **Rate-limited:** a new freeze starts only 9 ticks (0.15 s) after the last began. **Off** with Options → Accessibility → "Hit-stop" (`UI_HIT_STOP`, en "Hit-stop", es "Pausa de impacto"; on by default) or reduced motion. The sim keeps its 60 Hz clock and the input stays live: nothing in `src/sim`, `src/application`, `src/presentation/input` or `SimDriver` reads it (a test scans them) | `HitStop` (new), `AvatarBase.hold`, `BossAvatar.hold`, `KitView.hold`, `ActorViews.hold_flash`, `IsoRig.kick`, `ViewPrefs.hit_stop`, `GameSettings` "hit_stop", `OptionsMenu` |

All numbers are starting values. The look and the feel are **OWNER ONLY**.

## Tests
New `tests/unit/presentation/test_blade_feel.gd` (19 tests): every combo step's accent winds up before its hit,
swings through on it, follows through past the arc and is gone by the swing's end, reduced motion with no overshoot; a
real combo read by the hero model each tick (all four steps, the finisher ×1.6, nothing left after); the slash edge
drawn over the trail in the hero's blue-white (heat and element tint it), gone with the blade, one layer; the edge
spark pooled (one a swing, a flare on each hit tick, nothing built per swing); a real slash hit throws one SLASH impact
along the swing's tangent with its sparks flying on along it, within the pools, gone after its life; the tangent per
motion; a slash's impact at least a bolt's in pieces and strength, past 0.6; slash impacts merge and stay in budget; a
slash flinches harder than a bolt and knocks the pose (a bolt doesn't), all back at rest, the sim body and node
unmoved, reduced motion smaller; a boss flinches through its clip on a Blade hit, rate-limited, and is held; a real
slash hit holds the hero's pose, the blade, the struck enemy (at its flinch's peak) and its flash for 2 frames, then all
let go and run on from the peak; **the hit-stop never touches the sim** (240 ticks of combos on an enemy with it on and
off: same tick, same `World.state_hash()`, freezes > 0 only when on); nothing in the sim, the application or the input
reads it; one swing shares one freeze and fast swings are limited; two enemies struck by one slash share one freeze; the
option and reduced motion turn it off (via `ViewPrefs.apply_settings`); the Accessibility row; the camera kick (tiny,
brief, off with shake off or reduced motion).

New `tests/e2e/test_e2e_blade_feel.gd` (2 tests, main.tscn and real input only): the Playground from the main menu with
the Blade, a dummy placed with F1's click, left clicks swing at it: slash impacts, freezes, held frames, the sim ticking
once a physics frame through every held frame, the hero model swinging, the game never paused; and Options →
Accessibility → Hit-stop with the keyboard turns it off: the slashes still land, nothing is held.

Changed on purpose: `tests/unit/presentation/test_hit_impact.gd::test_a_slash_is_smaller_and_an_area_hit_smaller_still`
→ `test_a_slash_is_at_least_a_bolt_s_and_an_area_hit_smaller` (O22: the slash's impact is now at least a bolt's).

Changed on purpose too: `tests/unit/presentation/test_player_avatar.gd::test_visor_faces_the_movement_and_turns_to_swing`:
eight ticks into a slash the follow-through carries the head on past the arc's end, so its tolerance is 0.6 +
`PlayerAvatar.FOLLOW_TWIST` (0.36). Its failure in the folder run, before that change, is below as it printed.

```
$ gdformat --check src scripts tests && gdlint src scripts tests
938 files would be left unchanged
Success: no problems found

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
    [Failed]:  [0.70639546690172572152] expected to equal [0.0] +/- [0.6]:  a swing turns it to the swing (the twist of the slash adds its own turn)
res://tests/unit/presentation/test_player_avatar.gd
- test_visor_faces_the_movement_and_turns_to_swing
Warnings              2
Deprecated            1
Scripts              96
Tests               684
Passing Tests       683
Failing Tests         1
Asserts           1941885/1941886
Time              556.903s

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_player_avatar.gd -gexit
Scripts               1
Tests                10
Passing Tests        10
Asserts              60
Time              0.67s

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Scripts              25
Tests               126
Passing Tests       126
Asserts            8710
Time              28.849s
---- All tests passed! ----

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch -ginclude_subdirs -gexit
Scripts               2
Tests                 4
Passing Tests         4
Asserts           11254
Time              1.249s
---- All tests passed! ----

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/golden -ginclude_subdirs -gexit
Scripts               1
Tests                 2
Passing Tests         2
Asserts               4
Time              8.371s
---- All tests passed! ----

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/application -ginclude_subdirs -gexit
Scripts              13
Tests                98
Passing Tests        98
Asserts            1012
Time              71.045s
---- All tests passed! ----

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_blade_feel.gd,res://tests/e2e/test_e2e_wand_blade.gd,res://tests/e2e/test_e2e_damage_soak.gd,res://tests/e2e/test_e2e_enemies.gd,res://tests/e2e/test_e2e_options.gd,res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_playground.gd,res://tests/e2e/test_e2e_hints.gd,res://tests/e2e/test_e2e_shake_option.gd,res://tests/e2e/test_e2e_combo.gd,res://tests/e2e/test_e2e_four_slash.gd,res://tests/e2e/test_e2e_kit.gd,res://tests/e2e/test_e2e_spanish.gd -gexit
    soak: 2 deaths, 42 hits, 6005 frames; nodes 1408 -> 1434
Scripts              13
Tests                25
Passing Tests        25
Asserts             750
Time              202.41s
---- All tests passed! ----
```
`tests/content` holds the locale coverage (`UI_HIT_STOP` in en and es). The presentation folder run includes the new
`test_blade_feel.gd` (19) and the changed `test_hit_impact.gd`.

Goldens: none changed (presentation only; `tests/golden` 2/2 unchanged). Not run locally: the full suite and the
seams (the lead's, CLAUDE.md).

## Shots
`scripts/shots/blade_feel.gd` (new): the real game view (WorldViewRoot, Ruins with its lighting mood and effects layer,
the iso camera at 6 m) of a real World with the Blade build; the hero swings by its own input frames at one held enemy
(speed 0, no attacks, its back to the blade). Nothing else is staged. Rendered one run at a time (llvmpipe,
`--fixed-fps 60`):

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 -s scripts/shots/blade_feel.gd
blade_feel: res://build/shots/v0.8.0/gf3/1_swing_trail.jpg (tick 4, step 0, swing tick 4, impacts 0, flinches 0, pieces 0, freezes 0, held false)
blade_feel: res://build/shots/v0.8.0/gf3/2_blade_impact.jpg (tick 6, step 0, swing tick 3, impacts 1, flinches 1, pieces 18, freezes 1, held false)
blade_feel: res://build/shots/v0.8.0/gf3/3_flinch_held.jpg (tick 3, step 0, swing tick 3, impacts 1, flinches 1, pieces 18, freezes 1, held false)
blade_feel: res://build/shots/v0.8.0/gf3/4_finisher.jpg (tick 67, step 3, swing tick 8, impacts 4, flinches 4, pieces 24, freezes 4, held false)
blade_feel: res://build/shots/v0.8.0/gf3/5_thrust_impact.jpg (tick 42, step 2, swing tick 5, impacts 3, flinches 3, pieces 18, freezes 3, held false)
```
Copied by hand to [`gf_shots/`](gf_shots/) as `gf3_*` (byte-identical):
1. [`gf3_1_swing_trail.jpg`](gf_shots/gf3_1_swing_trail.jpg): the first slash on its 4th tick (the enemy out of reach):
   the trail with the bright edge along its tip and the edge spark on the blade's tip.
2. [`gf3_2_blade_impact.jpg`](gf_shots/gf3_2_blade_impact.jpg): a Warden struck, grabbed 3 ticks after the impact was
   read (world tick 6, the swing still on its tick 3: the sim's own freeze): the cut and its sparks on its camera side
   read small and faint (owner question).
3. [`gf3_3_flinch_held.jpg`](gf_shots/gf3_3_flinch_held.jpg): a Charger, grabbed two frames after the freeze began
   (world tick 3): white, leaned back and knocked away from the swing at its flinch's peak, the cut's star by its side.
   "held false": the 2-frame hold had just run out when the frame was grabbed (the still shows the held pose; the
   motion is OWNER ONLY).
4. [`gf3_4_finisher.jpg`](gf_shots/gf3_4_finisher.jpg): the finisher's spin on a Warden, grabbed 3 ticks after its
   impact was read: the spin's circular trail with its edge, the blade, the Warden flashing white, the cut's star low on
   its side.
5. [`gf3_5_thrust_impact.jpg`](gf_shots/gf3_5_thrust_impact.jpg): the third step's thrust on a Charger, 2 ticks after
   its impact: the thrust's fan with its bright edge at the tip, the cut's flash and sparks at the Charger's near end.

Debug renders made while tuning (a closer camera, written under `build/dbg/`, deleted, not evidence) showed the cut
mostly hidden by the bigger bodies; the cut was moved to the camera side, made longer and given the round atlas cell
(the diagonal cell thinned to nothing when drawn out), and these final shots were rendered after that.

## Owner only
- The swing: do the wind-up, the swing and the follow-through read on each step, the finisher bigger? Too much, too
  little? (The sim's wind-up is 1-6 ticks: the first step hits on its tick 2.)
- The slash edge and the edge spark: bright enough, too bright?
- The impact: does the cut read along the slash? **In the software-rendered shots it reads faint**, mostly hidden by the
  struck body and washed out on the pale sand and on the white hit flash (additive sparks on white add nothing). On
  your PC: enough, or bigger?
- The flinch: stronger than a bolt's, with its knock; does it read as a hit without looking like movement?
- **The hit-stop:** does the 2-frame hold feel better? And the decision above: the sim already holds the whole world
  3-7 ticks on every Blade hit; keep both, keep only one, or retune the sim's (`hitstop_seconds` in
  `data/player/runner.tres`)?
- The camera kick (0.06 m, 0.1 m on the finisher): felt, too much?
