# N1_FIXES: a new run every time, the fire sprites and the lights, role colours apart, the Blade's hit-stop and damage reduction, the spare glyphs, the credit (v0.8.0 Step N1)

Owner lines (verbatim in [`../PLAN.md`](../PLAN.md)): O53 (the same run every launch), O46 / O55 (fire drawings popping
across the screen; check the lighting), O39 (yellow, orange and red close under room light), O48 (the Blade's hit-stop
20 % more noticeable), O43 / D39 (the Blade's damage reduction, −25 % while held), O54 / D42 (the crossed blades and
the star burst), and the credit line.

- **Status:** RUN (agent): probes, tests, shots. How it feels and looks in play on the owner's PC: **OWNER ONLY**.
- **Build:** the working tree of the commit `v0.8.0 Step N1` on `v080-n1` (base `46d5c35` on
  `claude/lucid-fermat-9wv2tf`); the runs were made on that tree before it was committed, so the commit cannot name
  its own SHA. "Before" runs use the same tree with the change switched off by a probe flag (named in each section),
  except the base-commit checks, which ran on an export of `46d5c35` (`git archive 46d5c35`, imported in the
  scratchpad). Godot `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 (cloud container shared with other agents,
  load average 10-22, no GPU: Vulkan on **llvmpipe** under xvfb).
- **Date:** 2026-10-16
- **Who ran it:** agent

## 1. O53: the same run every launch (bug, fixed)
**Cause (confirmed):** `src/app/main.gd` started `_stage_seed` at the constant `STAGE_SEED` (20261006) at every launch
and only added 1 on Restart, so the first run of every session was the same run (same biome order, floors, offers).
A second Play from the main menu even reused the last run's seed.

**Fix:** `src/app/run_seeds.gd` (`RunSeeds`, app layer): every new run (the build picker's pick, Restart from the pause
menu, the end panel's next run after a death) takes `RunSeeds.next()` before it starts: in the game a fresh random
31-bit seed (`RandomNumberGenerator.randomize()`, never in `src/sim`; the sim only receives the number). Saves keep
their stored seed (Continue), the dev panel's seed field still sets one (`Main._reseed`). Determinism on purpose:
`Main.fixed_seed` (set by `E2e.boot`: every e2e test keeps `STAGE_SEED` and its +1 order exactly as before), else
`--seed=N` on the command line, else a tool run (`godot -s …`: GUT, the shot and check scripts) keeps `STAGE_SEED`.

Proof, `tests/e2e/test_e2e_run_seed.gd` (driven through main.tscn with key presses), in the e2e run of section 8:
```
    first-run seeds of two launches: [1300824661, 595793621]
* test_restart_and_the_next_run_draw_new_seeds
    seeds of four runs in one launch: [298218521, 896979218, 1750707167, 10955893]
* test_a_set_seed_is_honoured_in_order
```
(plus: a set seed 4242 gives 4242 then 4243; `E2e.boot` keeps `STAGE_SEED`; a tool run resolves to `STAGE_SEED`;
50 random draws are all different and inside 1..2^31−1.)

## 2. O46 / O55: fire drawings flashing across the screen (bug, fixed)
**Cause:** physics interpolation. The project interpolates every 3D node between physics ticks
(`physics/common/physics_interpolation = true`). The effect layer (`VfxCore` / `VfxLayer`: the fire props' flames, the
embers, every element sprite pool, the 10 pooled effect lights, the floor marks) lays its pieces out again **every
frame** on frame time, and a pool slot holds a different piece from one frame to the next: when a fire light hides
or shows (P3's far-light fades, as you walk), every flame after it moves to other slots; when any other effect's
flames are drawn first (a burning enemy, a Flame Trail), all the prop flames shift. Every other per-frame pool in the
game already turned interpolation off (`AttackFormPool`, `BakedMeshPools`, `BossStrikeViews`, …); `VfxCore` did not,
so the renderer drew each re-used slot between its last two physics ticks' places: for a frame a flame or an ember
stood somewhere between two unrelated fires, anywhere on screen, and a slot that had been empty streaked from a stale
place (the vertical streak in the shot). It began with the lighting pass's prop flames (2026-10-12) and got much more
frequent with P3's fades.

**Fix:** `VfxCore._init`: `physics_interpolation_mode = OFF` (its pools, lights and decals inherit it). Also turned off,
from the audit below, on `BossSignatureViews` (its scorch and ricochet-spark pools and the Gaze lights, all laid out
in `_draw` on frame time) and `FinalBossViews` (its ring light jumped from the ring to a burst over a tick).
`tests/unit/presentation/test_vfx_interpolation.gd` (no pool, light or mark of the layer, the boss signature views or
the final boss views is interpolated, under an interpolated parent; a prop flame is placed at its fire).

**Reproduced and measured** with the game's own `VfxLayer`, drawn on a black stage by an iso camera at 60 Hz physics
(`scripts/checks/fire_flash_probe.gd`, new): 12 fire props drawn the way `WorldViewRoot._draw_prop_fires` does; every
6 frames one fire light hides or shows again (shuffle=1: the order changes every frame, the worst case); it counts the
bright pixels outside every visible fire's own box. "Before" = `interp=inherit` (the layer follows the scene's
interpolation: the code before N1, which set no mode).
```
xvfb-run -a godot --path . --audio-driver Dummy --resolution 640x360 -s scripts/checks/fire_flash_probe.gd -- frames=240 toggle=6 shot=1 interp=inherit tag=before
xvfb-run -a godot --path . --audio-driver Dummy --resolution 640x360 -s scripts/checks/fire_flash_probe.gd -- frames=240 toggle=6 shot=1 tag=after
xvfb-run -a godot --path . --audio-driver Dummy --resolution 640x360 -s scripts/checks/fire_flash_probe.gd -- frames=240 shuffle=1 interp=inherit tag=before_shuffle
xvfb-run -a godot --path . --audio-driver Dummy --resolution 640x360 -s scripts/checks/fire_flash_probe.gd -- frames=240 shuffle=1 tag=after_shuffle
```
```
fire_flash_probe: fires=12 frames=240 toggle=6 shuffle=false layer_interpolation=inherit (scene: on) renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
frames counted=241  frames with stray flame pixels=25  stray pixels total=1055  worst frame=118 (every 2nd px)
first frames: 0 0 0 0 80 0 0 0 0 0 0 0 0 0 0 0 39 0 0 0 0 0 11 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 8 0 0 0 0 0 0 0 0 0 0 0 0 0
fire_flash_probe: fires=12 frames=240 toggle=6 shuffle=false layer_interpolation=off renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
frames counted=241  frames with stray flame pixels=0  stray pixels total=0  worst frame=0 (every 2nd px)
first frames: 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
fire_flash_probe: fires=12 frames=240 toggle=6 shuffle=true layer_interpolation=inherit (scene: on) renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
frames counted=241  frames with stray flame pixels=213  stray pixels total=11505  worst frame=128 (every 2nd px)
first frames: 47 65 0 39 128 27 42 26 77 48 71 8 48 11 61 59 14 0 63 61 55 0 2 0 35 0 27 67 55 63 0 69 72 63 80 78 46 77 13 19 31 25 53 62 101 0 39 68 45 27 0 70 48 54 4 52 0 87 58 51
fire_flash_probe: fires=12 frames=240 toggle=6 shuffle=true layer_interpolation=off renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
frames counted=241  frames with stray flame pixels=0  stray pixels total=0  worst frame=0 (every 2nd px)
first frames: 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
```
Before: stray flame pixels on exactly the frames a light hid or showed (25 of 241), and on 213 of 241 with the order
changing every frame; after: **0** in both. Shot (frame 7, a light just hid; blue boxes = where fires burn; left
before, right after): [`n1_shots/fire_flash_frame7_before_after.jpg`](n1_shots/fire_flash_frame7_before_after.jpg).

## 3. O55: the lighting audit (walking a real floor)
`scripts/checks/light_walk_probe.gd` (new, headless): one real generated floor (`SaveLab.floor_world(20261008, 1)`, 62
fire props) drawn by the game's `WorldViewRoot` in a biome, the camera walked at 6 m/s (0.1 m a frame) through the
start room and 5 more rooms, 1,869 frames checked; it reads the fire lights (StageKit), the hero's light, the effect
layer's pools and lights each frame (the flames' places through `VfxCore.record`, since a headless renderer keeps no
instance transforms). "Before" = `interp=inherit`.
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/light_walk_probe.gd -- biome=ruins tag=before interp=inherit
godot --headless --fixed-fps 60 --path . -s scripts/checks/light_walk_probe.gd -- biome=<b> tag=after   (the five biomes)
```
```
light_walk_probe: biome=ruins seed=20261008 floor=1 rooms=6 physics_interpolation=true
frames                     1869
kit_hidden_on_screen       0
kit_toggles_on_screen      0
kit_toggles_off_screen     86
kit_energy_step_max        0.060
shadow_toggles_visible     0
shadow_casters_max         4
flames_far                 0
flames_drawn_max           60
flame_slot_changes         1272
frames_with_slot_changes   61
pools_interpolated         21
hero_light_missing         0
vfx_lights_on_max          0
```
```
light_walk_probe: biome=ruins seed=20261008 floor=1 rooms=6 physics_interpolation=true
frames                     1869
kit_hidden_on_screen       0
kit_toggles_on_screen      0
kit_toggles_off_screen     86
kit_energy_step_max        0.060
shadow_toggles_visible     0
shadow_casters_max         4
flames_far                 0
flames_drawn_max           60
flame_slot_changes         1272
frames_with_slot_changes   61
pools_interpolated         0
hero_light_missing         0
vfx_lights_on_max          0
light_walk_probe: biome=night_rocks seed=20261008 floor=1 rooms=6 physics_interpolation=true
frames                     1869
kit_hidden_on_screen       0
kit_toggles_on_screen      0
kit_toggles_off_screen     86
kit_energy_step_max        0.060
shadow_toggles_visible     0
shadow_casters_max         4
flames_far                 0
flames_drawn_max           60
flame_slot_changes         1272
frames_with_slot_changes   61
pools_interpolated         0
hero_light_missing         0
vfx_lights_on_max          0
light_walk_probe: biome=red_canyon seed=20261008 floor=1 rooms=6 physics_interpolation=true
frames                     1869
kit_hidden_on_screen       0
kit_toggles_on_screen      0
kit_toggles_off_screen     86
kit_energy_step_max        0.060
shadow_toggles_visible     0
shadow_casters_max         4
flames_far                 0
flames_drawn_max           60
flame_slot_changes         1272
frames_with_slot_changes   61
pools_interpolated         0
hero_light_missing         0
vfx_lights_on_max          0
light_walk_probe: biome=frozen_shore seed=20261008 floor=1 rooms=6 physics_interpolation=true
frames                     1869
kit_hidden_on_screen       0
kit_toggles_on_screen      0
kit_toggles_off_screen     88
kit_energy_step_max        0.060
shadow_toggles_visible     0
shadow_casters_max         4
flames_far                 0
flames_drawn_max           69
flame_slot_changes         1443
frames_with_slot_changes   65
pools_interpolated         0
hero_light_missing         0
vfx_lights_on_max          0
light_walk_probe: biome=starfall seed=20261008 floor=1 rooms=6 physics_interpolation=true
frames                     1869
kit_hidden_on_screen       0
kit_toggles_on_screen      0
kit_toggles_off_screen     88
kit_energy_step_max        0.060
shadow_toggles_visible     0
shadow_casters_max         4
flames_far                 0
flames_drawn_max           69
flame_slot_changes         1443
frames_with_slot_changes   65
pools_interpolated         0
hero_light_missing         0
vfx_lights_on_max          0
```
What was checked and found:
- **Fire lights (StageKit, P3's fades):** never hidden while on screen (0), never switched on or off on screen (0;
  86-88 switches, all off screen), the biggest energy change in one frame 6 % of full (the flicker plus the 0.4 s fade,
  no pop), shadows never switched while visible (0), never more than 4 casting. Nothing to fix.
- **The flames:** never placed away from a visible fire (0), but their pool slots changed hands on 61-65 frames of
  the walk (1,272-1,443 slot changes): with the pools interpolated (21 pieces before) each of those frames drew flames
  between fires: the owner's bug. After: 0 interpolated.
- **The hero's light:** present and lit on every frame in every biome (0 missing).
- **Pooled effect lights (VfxCore's 10):** no effect burns on this still floor (0 on); they now jump to their request
  each frame instead of sliding from the last one (no interpolation, unit test above).
- **Boss lights:** the Gaze's eye and impact lights and the final boss's ring light were interpolated while placed on
  frame time; now off (above). Not run in a fight: covered by the unit test and the e2e of section 8.
- **Biome moods:** one mood per floor (`StageView.apply_mood` at floor start, the dev panel's live edits); nothing
  switches between rooms, so no room-to-room change to check. Not changed.

## 4. O39: role colours apart under every biome's lighting
**Cause:** the role colours are plain lit albedo, so a room's warm fire light (orange) and the biome's grade multiply
into every surface: in Ruins every kind measured at hue 1-32° (red-orange), the Bomb Drone's yellow at 31.6°, the
Charger at L* 7.

**Fix:** `ActorViews.role_glow` (presentation): a normal kind's role-coloured plates (EnemyPalettes' body and trim,
saturation at or over 0.3) also emit their own colour × `ROLE_GLOW` **0.45** (a starting value), so the hue still
shows where the room light pulls everything warm; greys, eyes, bosses and the hero are untouched; the hit flash and
the status tints still win while they last, then the glow comes back (the rest state is kept on the material).

**Measured** with the EC line-up script (`scripts/shots/mock_enemy_colours.gd`, new options: `fire=1` two of the
room's fire lights (StageKit's: the mood's warm colour, energy and range at a barrel's height) either side of the
line-up; `measure=1` each kind's body plate on screen (the mean of its coloured pixels in a box at its body mesh's
centre: colour, hue, CIE L*, chroma) and the closest ΔE (CIE76) across roles and between the melee reds / oranges and
the bomber yellows; `glow=` the role glow, 0 = before). One biome per process (a five-biome process ran out of memory
twice in the shared container), palette A, 960 × 540:
```
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 960x540 -s scripts/shots/mock_enemy_colours.gd -- palettes=a biomes=<b> modes=off fire=1 measure=1 glow=0 tag=before
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 960x540 -s scripts/shots/mock_enemy_colours.gd -- palettes=a biomes=<b> modes=off fire=1 measure=1 glow=0.45 tag=after
```
| biome | closest ΔE across roles, before → after | closest melee red/orange vs bomber yellow, before → after | Bomb Drone hue before → after |
|---|---|---|---|
| Ruins | 7.8 → 15.2 | 13.7 → 23.4 | 31.6° → 41.6° |
| Night Rocks | 10.0 → 27.0 | 29.7 → 29.8 | 46.1° → 42.7° |
| Red Canyon | 7.6 → 14.9 | 14.1 → 27.3 | 15.3° → 39.5° |
| Frozen Shore | 6.5 → **8.9** | 8.4 → 21.2 | 230.9° → 42.3° |
| Starfall | 14.1 → 16.4 | 30.3 → **18.3** | 35.4° → 42.6° |

Reading: the closest pair across roles is further apart in every biome, and the red / orange vs yellow gap the owner
named is at least 18.3 everywhere after (was 8.4-30.3). Two numbers to report plainly: **Frozen Shore's** closest pair
across roles is still only ΔE 8.9 (the Splitling's orange vs the Warden's bronze, both pale in its bright, foggy
light), and **Starfall's** red/orange vs yellow gap went down from 30.3 to 18.3 (now the Splitling vs the Mine Layer;
before, the Bomb Drone vs the Splitter): the smallest of the five biomes after. No target was set
before the runs; the value 0.45 was not tuned against these numbers (one value, measured once). Owner question D43.
Shots (left before, right after): [`roles_ruins`](n1_shots/roles_ruins_before_after.jpg),
[`roles_night_rocks`](n1_shots/roles_night_rocks_before_after.jpg),
[`roles_red_canyon`](n1_shots/roles_red_canyon_before_after.jpg),
[`roles_frozen_shore`](n1_shots/roles_frozen_shore_before_after.jpg),
[`roles_starfall`](n1_shots/roles_starfall_before_after.jpg).

Raw output (the printed lines of the ten runs):
```
exit=0 ruins before
measure: palette=a biome=ruins mode=off fire=true glow=0.00_before
  needle        ranged   4f4443 hue   1.0  L*  29.8  chroma   5.4  (59 px)
  arc_caster    ranged   833726 hue  11.0  L*  33.4  chroma  41.5  (81 px)
  sniper        ranged   2d1c1f hue 349.4  L*  12.5  chroma   9.0  (66 px)
  lens_drone    ranged   3c1526 hue 333.3  L*  13.5  chroma  21.2  (72 px)
  bomb_drone    bomber   422300 hue  31.6  L*  17.3  chroma  28.0  (77 px)
  mine_layer    bomber   b35f16 hue  27.8  L*  49.4  chroma  59.9  (81 px)
  mender        support  5a610e hue  65.1  L*  39.2  chroma  44.2  (81 px)
  charger       melee    300801 hue   9.0  L*   7.2  chroma  22.6  (81 px)
  hatchling     melee    300700 hue   8.8  L*   7.2  chroma  23.1  (81 px)
  swarmer       melee    5d0d06 hue   4.8  L*  18.5  chroma  43.0  (81 px)
  splitter      melee    77290d hue  15.8  L*  28.3  chroma  47.7  (81 px)
  splitling     melee    531a04 hue  16.8  L*  18.4  chroma  36.5  (79 px)
  warden        tank     3a1604 hue  20.4  L*  12.6  chroma  23.9  (90 px)
  shield_bearer tank     2c1203 hue  21.5  L*   8.7  chroma  17.1  (74 px)
  closest across roles: ΔE 7.8 (charger / shield_bearer)
  closest red/orange vs yellow (melee vs bombers): ΔE 13.7 (bomb_drone / splitling)
  warm hues (deg): charger 9.0, splitter 15.8, splitling 16.8, bomb_drone 31.6, mine_layer 27.8
exit=0 ruins after
measure: palette=a biome=ruins mode=off fire=true glow=0.45_after
  needle        ranged   525b7e hue 227.2  L*  39.2  chroma  21.4  (81 px)
  arc_caster    ranged   8e484f hue 354.4  L*  39.5  chroma  31.8  (81 px)
  sniper        ranged   34355b hue 238.3  L*  23.9  chroma  24.9  (81 px)
  lens_drone    ranged   703e71 hue 298.5  L*  34.0  chroma  36.8  (81 px)
  bomb_drone    bomber   866212 hue  41.6  L*  44.0  chroma  47.3  (81 px)
  mine_layer    bomber   be7625 hue  31.8  L*  56.2  chroma  57.8  (81 px)
  mender        support  697f34 hue  77.6  L*  50.2  chroma  42.8  (81 px)
  charger       melee    812417 hue   7.6  L*  29.4  chroma  50.0  (81 px)
  hatchling     melee    811e01 hue  13.3  L*  28.5  chroma  57.6  (81 px)
  swarmer       melee    8e2024 hue 357.4  L*  31.5  chroma  52.4  (81 px)
  splitter      melee    9c4213 hue  20.3  L*  39.6  chroma  56.4  (81 px)
  splitling     melee    9d5635 hue  19.1  L*  44.5  chroma  41.2  (81 px)
  warden        tank     6f3b16 hue  24.5  L*  30.7  chroma  37.4  (90 px)
  shield_bearer tank     532e11 hue  26.5  L*  23.3  chroma  28.9  (81 px)
  closest across roles: ΔE 15.2 (splitling / warden)
  closest red/orange vs yellow (melee vs bombers): ΔE 23.4 (mine_layer / splitter)
  warm hues (deg): charger 7.6, splitter 20.3, splitling 19.1, bomb_drone 41.6, mine_layer 31.8
exit=0 night_rocks before
measure: palette=a biome=night_rocks mode=off fire=true glow=0.00_before
  needle        ranged   434b76 hue 230.7  L*  33.0  chroma  26.9  (65 px)
  arc_caster    ranged   9d3435 hue 359.5  L*  37.7  chroma  50.0  (79 px)
  sniper        ranged   171442 hue 243.4  L*   9.6  chroma  33.8  (75 px)
  lens_drone    ranged   161169 hue 243.5  L*  13.3  chroma  59.9  (72 px)
  bomb_drone    bomber   423404 hue  46.1  L*  22.4  chroma  29.7  (34 px)
  mine_layer    bomber   d86911 hue  26.4  L*  56.8  chroma  73.2  (81 px)
  mender        support  5b740b hue  74.4  L*  45.2  chroma  53.4  (81 px)
  charger       melee    1c0009 hue 341.6  L*   2.4  chroma  11.3  (10 px)
  hatchling     melee    1b0000 hue   0.0  L*   2.1  chroma   9.8  (5 px)
  swarmer       melee    580014 hue 346.7  L*  16.2  chroma  40.9  (81 px)
  splitter      melee    881f0c hue   9.1  L*  30.0  chroma  57.0  (81 px)
  splitling     melee    4d0d01 hue   9.5  L*  14.8  chroma  36.6  (79 px)
  warden        tank     000000 hue   0.0  L*   0.0  chroma   0.0  (0 px)
  shield_bearer tank     000000 hue   0.0  L*   0.0  chroma   0.0  (0 px)
  closest across roles: ΔE 10.0 (hatchling / warden)
  closest red/orange vs yellow (melee vs bombers): ΔE 29.7 (bomb_drone / splitling)
  warm hues (deg): charger 341.6, splitter 9.1, splitling 9.5, bomb_drone 46.1, mine_layer 26.4
exit=0 night_rocks after
measure: palette=a biome=night_rocks mode=off fire=true glow=0.45_after
  needle        ranged   40619f hue 218.9  L*  41.4  chroma  37.8  (81 px)
  arc_caster    ranged   a3455c hue 345.6  L*  42.6  chroma  41.6  (81 px)
  sniper        ranged   1e337f hue 226.8  L*  24.3  chroma  49.9  (80 px)
  lens_drone    ranged   6e389a hue 273.3  L*  35.0  chroma  61.0  (81 px)
  bomb_drone    bomber   98700d hue  42.7  L*  49.8  chroma  54.2  (81 px)
  mine_layer    bomber   e38521 hue  30.9  L*  64.4  chroma  70.2  (81 px)
  mender        support  6c9436 hue  85.7  L*  56.7  chroma  52.6  (81 px)
  charger       melee    971513 hue   0.8  L*  32.2  chroma  63.3  (81 px)
  hatchling     melee    9d0e00 hue   5.3  L*  32.8  chroma  71.1  (81 px)
  swarmer       melee    aa0e2f hue 347.5  L*  36.1  chroma  63.9  (81 px)
  splitter      melee    bf3d0f hue  15.8  L*  44.9  chroma  72.5  (81 px)
  splitling     melee    bf5a37 hue  15.4  L*  50.4  chroma  54.5  (79 px)
  warden        tank     71371b hue  19.7  L*  30.3  chroma  37.0  (90 px)
  shield_bearer tank     4a2812 hue  23.8  L*  20.3  chroma  25.3  (81 px)
  closest across roles: ΔE 27.0 (arc_caster / swarmer)
  closest red/orange vs yellow (melee vs bombers): ΔE 29.8 (mine_layer / splitling)
  warm hues (deg): charger 0.8, splitter 15.8, splitling 15.4, bomb_drone 42.7, mine_layer 30.9
exit=0 red_canyon before
measure: palette=a biome=red_canyon mode=off fire=true glow=0.00_before
  needle        ranged   5c474c hue 347.3  L*  32.6  chroma   9.4  (65 px)
  arc_caster    ranged   a53729 hue   7.1  L*  39.5  chroma  55.7  (81 px)
  sniper        ranged   321720 hue 340.5  L*  12.0  chroma  14.8  (53 px)
  lens_drone    ranged   2e0111 hue 339.2  L*   5.7  chroma  23.4  (70 px)
  bomb_drone    bomber   4e1400 hue  15.3  L*  16.2  chroma  36.0  (59 px)
  mine_layer    bomber   dc6b12 hue  26.4  L*  57.8  chroma  73.9  (81 px)
  mender        support  6b7607 hue  66.0  L*  47.1  chroma  53.7  (81 px)
  charger       melee    210000 hue   0.0  L*   2.9  chroma  13.7  (81 px)
  hatchling     melee    270000 hue   0.0  L*   3.9  chroma  18.5  (81 px)
  swarmer       melee    750000 hue   0.0  L*  23.1  chroma  57.0  (81 px)
  splitter      melee    97240d hue  10.0  L*  33.7  chroma  62.2  (81 px)
  splitling     melee    680f00 hue   8.6  L*  21.1  chroma  49.1  (79 px)
  warden        tank     570700 hue   4.7  L*  16.3  chroma  42.5  (90 px)
  shield_bearer tank     390200 hue   2.5  L*   8.3  chroma  29.4  (81 px)
  closest across roles: ΔE 7.6 (hatchling / lens_drone)
  closest red/orange vs yellow (melee vs bombers): ΔE 14.1 (bomb_drone / splitling)
  warm hues (deg): charger 0.0, splitter 10.0, splitling 8.6, bomb_drone 15.3, mine_layer 26.4
exit=0 red_canyon after
measure: palette=a biome=red_canyon mode=off fire=true glow=0.45_after
  needle        ranged   566090 hue 229.3  L*  41.9  chroma  29.1  (81 px)
  arc_caster    ranged   ad4a57 hue 352.0  L*  44.8  chroma  43.4  (81 px)
  sniper        ranged   2f326e hue 236.4  L*  23.7  chroma  39.1  (81 px)
  lens_drone    ranged   79327f hue 295.5  L*  33.8  chroma  51.7  (81 px)
  bomb_drone    bomber   a06c07 hue  39.5  L*  49.8  chroma  57.0  (81 px)
  mine_layer    bomber   e58622 hue  30.9  L*  64.9  chroma  70.2  (81 px)
  mender        support  799536 hue  77.7  L*  57.8  chroma  51.6  (81 px)
  charger       melee    9c180a hue   5.9  L*  33.5  chroma  67.2  (81 px)
  hatchling     melee    a41200 hue   6.5  L*  34.6  chroma  73.3  (81 px)
  swarmer       melee    b5111c hue 356.1  L*  38.5  chroma  72.7  (81 px)
  splitter      melee    c4430f hue  17.2  L*  46.7  chroma  72.9  (81 px)
  splitling     melee    c05c33 hue  17.4  L*  50.7  chroma  55.7  (81 px)
  warden        tank     953904 hue  21.6  L*  36.6  chroma  59.2  (90 px)
  shield_bearer tank     6b2a01 hue  23.0  L*  26.1  chroma  45.4  (81 px)
  closest across roles: ΔE 14.9 (splitling / warden)
  closest red/orange vs yellow (melee vs bombers): ΔE 27.3 (bomb_drone / splitling)
  warm hues (deg): charger 5.9, splitter 17.2, splitling 17.4, bomb_drone 39.5, mine_layer 30.9
exit=0 frozen_shore before
measure: palette=a biome=frozen_shore mode=off fire=true glow=0.00_before
  needle        ranged   7c7f9b hue 233.7  L*  53.7  chroma  16.2  (70 px)
  arc_caster    ranged   b18491 hue 342.9  L*  59.8  chroma  19.0  (81 px)
  sniper        ranged   44557e hue 222.9  L*  36.3  chroma  26.0  (80 px)
  lens_drone    ranged   515590 hue 235.7  L*  38.3  chroma  36.3  (81 px)
  bomb_drone    bomber   5b5d67 hue 230.9  L*  39.5  chroma   6.5  (51 px)
  mine_layer    bomber   d9a68e hue  19.3  L*  72.1  chroma  25.2  (81 px)
  mender        support  8a9c7a hue  92.1  L*  62.2  chroma  20.1  (81 px)
  charger       melee    685a6d hue 282.8  L*  40.1  chroma  13.1  (81 px)
  hatchling     melee    6a5f76 hue 270.5  L*  42.0  chroma  14.6  (81 px)
  swarmer       melee    815375 hue 315.9  L*  41.4  chroma  26.9  (81 px)
  splitter      melee    8a6172 hue 335.2  L*  46.0  chroma  19.8  (81 px)
  splitling     melee    69556b hue 293.8  L*  38.9  chroma  15.7  (81 px)
  warden        tank     736b7b hue 270.7  L*  46.5  chroma   9.8  (18 px)
  shield_bearer tank     776a76 hue 305.0  L*  46.3  chroma   8.6  (23 px)
  closest across roles: ΔE 6.5 (hatchling / warden)
  closest red/orange vs yellow (melee vs bombers): ΔE 8.4 (bomb_drone / charger)
  warm hues (deg): charger 282.8, splitter 335.2, splitling 293.8, bomb_drone 230.9, mine_layer 19.3
exit=0 frozen_shore after
measure: palette=a biome=frozen_shore mode=off fire=true glow=0.45_after
  needle        ranged   8490b5 hue 225.1  L*  60.1  chroma  21.0  (81 px)
  arc_caster    ranged   b58ca1 hue 328.5  L*  62.6  chroma  20.2  (81 px)
  sniper        ranged   4c659d hue 221.6  L*  43.1  chroma  34.0  (80 px)
  lens_drone    ranged   7d6bb0 hue 255.7  L*  49.6  chroma  40.9  (81 px)
  bomb_drone    bomber   978b6f hue  42.3  L*  58.2  chroma  16.4  (81 px)
  mine_layer    bomber   deb092 hue  23.9  L*  75.4  chroma  25.3  (81 px)
  mender        support  90a985 hue 101.4  L*  66.6  chroma  22.2  (81 px)
  charger       melee    9a6674 hue 343.3  L*  49.1  chroma  23.3  (81 px)
  hatchling     melee    a36a79 hue 343.2  L*  51.1  chroma  25.1  (81 px)
  swarmer       melee    a65d7f hue 332.2  L*  48.7  chroma  34.9  (81 px)
  splitter      melee    ab7076 hue 353.9  L*  53.5  chroma  25.3  (81 px)
  splitling     melee    aa7c7f hue 356.8  L*  56.6  chroma  18.8  (81 px)
  warden        tank     998084 hue 352.1  L*  56.0  chroma  10.1  (90 px)
  shield_bearer tank     89777b hue 346.7  L*  51.7  chroma   7.8  (80 px)
  closest across roles: ΔE 8.9 (splitling / warden)
  closest red/orange vs yellow (melee vs bombers): ΔE 21.2 (bomb_drone / splitling)
  warm hues (deg): charger 343.3, splitter 353.9, splitling 356.8, bomb_drone 42.3, mine_layer 23.9
exit=0 starfall before
measure: palette=a biome=starfall mode=off fire=true glow=0.00_before
  needle        ranged   667bcc hue 227.8  L*  53.3  chroma  46.6  (81 px)
  arc_caster    ranged   b582e9 hue 269.9  L*  63.0  chroma  59.6  (81 px)
  sniper        ranged   283fb6 hue 230.2  L*  32.7  chroma  73.2  (81 px)
  lens_drone    ranged   573099 hue 262.3  L*  30.4  chroma  66.0  (81 px)
  bomb_drone    bomber   794f12 hue  35.4  L*  37.2  chroma  41.9  (79 px)
  mine_layer    bomber   de8975 hue  11.3  L*  65.4  chroma  38.9  (81 px)
  mender        support  6c8597 hue 205.2  L*  54.1  chroma  13.4  (81 px)
  charger       melee    5b153c hue 326.2  L*  20.3  chroma  36.2  (81 px)
  hatchling     melee    5e143f hue 324.9  L*  20.9  chroma  37.9  (81 px)
  swarmer       melee    931546 hue 336.9  L*  32.2  chroma  52.7  (81 px)
  splitter      melee    8d2e25 hue   4.9  L*  33.3  chroma  48.3  (81 px)
  splitling     melee    762933 hue 352.3  L*  28.6  chroma  36.9  (81 px)
  warden        tank     6e3954 hue 329.8  L*  31.6  chroma  27.8  (90 px)
  shield_bearer tank     4d2b4e hue 298.8  L*  23.3  chroma  26.8  (81 px)
  closest across roles: ΔE 14.1 (charger / warden)
  closest red/orange vs yellow (melee vs bombers): ΔE 30.3 (bomb_drone / splitter)
  warm hues (deg): charger 326.2, splitter 4.9, splitling 352.3, bomb_drone 35.4, mine_layer 11.3
exit=0 starfall after
measure: palette=a biome=starfall mode=off fire=true glow=0.45_after
  needle        ranged   7593d8 hue 221.8  L*  61.2  chroma  39.4  (81 px)
  arc_caster    ranged   c090ee hue 270.8  L*  67.4  chroma  54.5  (81 px)
  sniper        ranged   3959c8 hue 226.5  L*  41.6  chroma  66.3  (81 px)
  lens_drone    ranged   9056bc hue 273.8  L*  47.3  chroma  61.9  (81 px)
  bomb_drone    bomber   b18b2d hue  42.6  L*  59.8  chroma  53.2  (81 px)
  mine_layer    bomber   e6a07c hue  20.3  L*  71.7  chroma  36.5  (81 px)
  mender        support  7a9f9d hue 175.4  L*  62.9  chroma  13.6  (81 px)
  charger       melee    ac334a hue 348.4  L*  40.5  chroma  52.5  (81 px)
  hatchling     melee    b72e46 hue 349.6  L*  42.1  chroma  58.8  (81 px)
  swarmer       melee    c22c5a hue 341.5  L*  44.3  chroma  61.8  (81 px)
  splitter      melee    be4d2d hue  13.4  L*  47.6  chroma  60.2  (81 px)
  splitling     melee    c3705b hue  11.9  L*  56.1  chroma  40.1  (81 px)
  warden        tank     a15d5d hue 360.0  L*  47.2  chroma  30.6  (90 px)
  shield_bearer tank     774855 hue 343.9  L*  36.4  chroma  22.0  (81 px)
  closest across roles: ΔE 16.4 (splitling / warden)
  closest red/orange vs yellow (melee vs bombers): ΔE 18.3 (mine_layer / splitling)
  warm hues (deg): charger 348.4, splitter 13.4, splitling 11.9, bomb_drone 42.6, mine_layer 20.3
```

## 5. O48: the Blade's hit-stop about 20 % stronger
- Sim (`data/player/runner.tres`, and `PlayerTable.default_combo` for the kernel worlds, which must agree with the
  data): the four steps' `hitstop_seconds` 3, 3, 4, 7 → **4, 4, 5, 8 ticks** (17 → 21 ticks over a combo, +24 %;
  whole ticks, so per step +33 / +33 / +25 / +14 %).
- View (`HitStop`): the hold 2 → **2.4 frames** of frame time, the camera kick 0.06 → **0.072 m** (finisher 0.1 →
  0.12 m): +20 %.
- **What it costs (for the lead and the owner):** the sim's hit-stop freezes the whole world, so in a fixed number of
  ticks the Blade lands fewer hits. The modifier-equivalence golden (re-recorded, below) shows it over its fixed
  scenario: Blade plain 165 → 131 hits (−21 %), 3,208 → 2,757 damage (−14 %). Enemies freeze with the hero, so in
  enemy time nothing changes; in seconds the Blade kills ~14 % slower. Not retuned (not asked); owner question D43.

## 6. O43 / D39: the Blade takes 25 % less damage
`BuildDefinition.damage_taken_permille` (new field, validated 100..1000; `data/builds/blade.tres` 750, the Gun 1000)
compiled into `PlayerTable.damage_taken_permille`; `PlayerBuild.taken_permille` reads it for a one-weapon run (the
Blade holds the Blade the whole run; a kernel world with both weapons keeps 1000). Applied in the one damage-taken
path (`Damage.hit`, where Armour already applied): multiplied with Armour and rounded once (Armour −10 % × Blade
−25 % = 0.675; a hit never drops to 0). DoT ticks keep ignoring armour as before, so they ignore this too. Hashed only
when not 1000 (`PlayerBuild.hash_into`). The build picker's Blade card shows a new line "Damage taken −25 %" /
"Daño recibido −25 %" (`BUILD_TAKEN`, en and es) above its damage factor:
[`n1_shots/build_picker_taken_line_en.jpg`](n1_shots/build_picker_taken_line_en.jpg) (from `scripts/shots/mu2_shots.gd
-- --lang=en`, opengl3). `tests/unit/sim/test_blade_damage_taken.gd` (40 → 30, 22 → 17, 1 → 1, the Gun and a kernel
world full, 100 → 68 with Armour, the hero's own hits unchanged); `test_stats.gd`'s Armour line now expects 34 (50 ×
0.9 × 0.75), on purpose.

## 7. O54 / D42: the spare glyphs, and the credit
- `ElementGlyphs.glyph_of`: the **star burst** on a Legendary card (the 7 items of rarity Legendary, and any card
  offered at the reward pick's legendary tier: `StoneCard`), over its element; the card's element otherwise; the
  **crossed blades** on a Blade card (requires the Blade) with no element (26 cards). `InlaySocket` shows it, so the
  wand, the plaques and the reward cards all wear it. `test_element_glyphs.gd` keeps both lists in step with the
  content. Shots: [`n1_shots/glyphs_blades_star.jpg`](n1_shots/glyphs_blades_star.jpg) (`scripts/shots/n1_glyphs.gd`,
  new), [`n1_shots/wand_crossed_blades_en.jpg`](n1_shots/wand_crossed_blades_en.jpg) (the Build page, mu2).
  A lead's call to check: a Legendary elemental card (Inferno Core, Tempest Core, Chain Blast) shows the star, not its
  element's glyph (its ring keeps the element's colour): D43.
- `CREDITS_OWNER` = "Rius" (en and es): `test_e2e_credits.gd` passed (section 8).

## 8. Tests (the owner's rule: lint, the folders touched and their e2e; no full suite)
```
gdformat --check src scripts tests && gdlint src scripts tests && bash scripts/ci/gut_shard.sh --check
971 files would be left unchanged
Success: no problems found
gut_shard: ok (351 test files in 6 shards)
```
- content, arch, golden, application, app, debug (`-gdir=res://tests/content,res://tests/arch,res://tests/golden,
  res://tests/unit/application,res://tests/unit/app,res://tests/unit/debug -ginclude_subdirs`): **255/255**, no script
  errors (a first run is void: it ran before the import registered `RunSeeds`, so its log had parse errors; re-run
  after `godot --headless --editor --import --quit`).
- `bash scripts/ci/gut_shard.sh sim_a`: **699/699**, `check_gut_log: ok (699 passing, minimum 1)`, 3436 s.
- `bash scripts/ci/gut_shard.sh sim_b`: **517/521, 4 failing**, 3365 s:
  - `test_modifier_equivalence.gd` (2 tests): the Blade cases' outcome digests: the hit-stop (section 5). Re-recorded
    on purpose (`godot --headless --path . -s tests/golden/generate_modifier_equivalence.gd`), then 3/3 pass.
  - `test_items.gd` `test_ember_stacks_cap_at_five_and_scale_the_tick`: it idled 31 ticks for one 30-tick burn, which
    caught two once the hit-stop moved the burn's phase; now one period exactly (30), 3/3 ember tests pass. Caused by
    N1, fixed.
  - `test_items.gd` `test_the_pool_never_repeats_and_skips_owned_and_placed` (57 ≠ 55) and `test_nemesis.gd`
    `test_the_strongest_cards_are_picked_by_level_then_rarity_then_slot` (Twin first): **they fail the same way on
    the base commit `46d5c35`** (run on its export: `test_items.gd` 18/19, `test_nemesis.gd` + equivalence 28/29),
    so not N1's; not fixed here (card counts and tiers from RR / BL, for the lead).
- `bash scripts/ci/gut_shard.sh presentation`: 711/712; the one failure was `test_blade_feel.gd`'s 2-frame hold (now
  2.4 frames: the test holds 2 whole frames and releases on the third); `test_blade_feel.gd` then 19/19.
- e2e (`-gtest=` run_seed, run_flow, saves, old_save, credits, shell, pad_menus, builds, blade_feel, wand_blade,
  dev_master_panel, damage_soak, nemesis): **36/36**, 496 s, no script errors.
- `bash scripts/ci/gut_shard.sh sim_c` (the heavy smoke files): **34/34**, `check_gut_log: ok (34 passing, minimum 1)`,
  1843 s.
- After the fixes: `-gtest=res://tests/unit/sim/test_modifier_equivalence.gd,res://tests/unit/sim/test_items.gd`
  21/22 (the one failure the base commit's pool count above); `test_blade_feel.gd` 19/19.
No bot tests, no full suite.

## Goldens changed on purpose
`tests/golden/fixtures/modifier_equivalence.json` (the hit-stop): the 12 cases that hold the Blade changed, the 10
Gun-only cases are identical. `tests/golden` (the replay) 2/2 unchanged.

| case | digest | hits | damage | kills |
|---|---|---|---|---|
| blade_all | changed | 135 → 121 | 4160 → 4160 | 14 → 14 |
| blade_conductor | changed | 233 → 197 | 3935 → 3383 | 10 → 8 |
| blade_ember_edge | changed | 131 → 111 | 4096 → 3430 | 11 → 9 |
| blade_glacial_edge | changed | 165 → 131 | 3208 → 2757 | 2 → 2 |
| blade_long_edge | changed | 189 → 162 | 3723 → 3473 | 8 → 3 |
| blade_overcharge | changed | 160 → 138 | 4160 → 3662 | 14 → 9 |
| blade_plain | changed | 165 → 131 | 3208 → 2757 | 2 → 2 |
| blade_serrated_edge | changed | 152 → 131 | 4063 → 3350 | 11 → 8 |
| blade_twin_arc | changed | 276 → 235 | 4077 → 3485 | 11 → 10 |
| blade_wildfire_rider | changed | 125 → 111 | 4160 → 3848 | 14 → 10 |
| both_all | changed | 209 → 188 | 4160 → 4160 | 14 → 14 |
| both_plain | changed | 169 → 140 | 2820 → 2455 | 1 → 1 |
| gun_all | same | 442 → 442 | 4160 → 4160 | 14 → 14 |
| gun_barbed_bolts | same | 88 → 88 | 601 → 601 | 0 → 0 |
| gun_cinder_shot | same | 70 → 70 | 680 → 680 | 0 → 0 |
| gun_frost_core | same | 70 → 70 | 388 → 388 | 0 → 0 |
| gun_glacial_rider | same | 70 → 70 | 434 → 434 | 0 → 0 |
| gun_plain | same | 70 → 70 | 388 → 388 | 0 → 0 |
| gun_rapid_coil | same | 94 → 94 | 523 → 523 | 0 → 0 |
| gun_ricochet_core | same | 74 → 74 | 414 → 414 | 0 → 0 |
| gun_splinter_shot | same | 165 → 165 | 583 → 583 | 0 → 0 |
| gun_static_chain | same | 89 → 89 | 516 → 516 | 0 → 0 |
