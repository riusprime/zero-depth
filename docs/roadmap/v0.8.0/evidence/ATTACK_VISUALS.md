# ATTACK_VISUALS: do the boss and enemy orbs draw as 3D bodies, and do the Gatekeeper's shock lanes strike as stone spikes? (v0.8.0 AV part 1)

- **Status:** RUN (tests, lint, shots). The look and the feel: **OWNER ONLY**.
- **Build:** the `v0.8.0 Step AV1` commit on branch `v080-av` (parent `deb87b4`); every run below was on that
  working tree before it was committed. Godot `4.7.2.stable.official.ed1daf0bf`; OS Ubuntu 24.04.5 LTS (cloud
  container; shots on software Vulkan, llvmpipe, under xvfb: not the owner's hardware).
- **Date:** 2026-10-14
- **Who ran it:** agent

## What changed (presentation only; the sim and its timings are untouched)
- **O8, the orbs** (`fireball_views.gd`, new `projectile_meshes.gd`, `fireball_shaders.gd`): each look is still three
  MultiMeshes (core, dark edge, trail; one draw each, any count of shots). The core is a lit 3D body with a spatial
  shader: a noise swirl and flicker inside, glowing veins where the look is stone or crust, a fresnel fall-off from
  the bright core to the look's dark edge colour, its own turn (spin about the flight, tumble) and wobble. The dark
  shell turns with it. The trail is a tapered strip that faces the camera about its length (glowing and additive,
  grey smoke, or broken drips). Bodies per source: Gatekeeper `ember_stone` tumbling faceted rock with ember veins;
  Warlord `spear_ember` long four-sided spear heads; Brood Mother `acid_glob` wobbling see-through green globs with
  drips; Hive Lens `prism_orb` faceted gems with glints; Siege Engine `cannon_ember` rock with a smoke trail; Foundry
  `molten_drop` teardrops with a crust and drips; Arc Caster `arc_plasma`, Lens Drone `lens_orb`, Bomb Drone
  `bomb_cinder` smooth swirling orbs. The colour table (bright core, dark edge, off the hero's colours) is unchanged.
  Effects density Low: every other trail, shorter and narrower (the balls stay). Reduced motion: no swirl, turn or
  wobble. Lights: a lobbed fireball and a raining drop each ask VfxCore for one, a boss's signature shots for at most
  3 (merged); they go through VfxCore's existing 10-light pool (the brightest requests win).
- **O7, the spikes** (new `stone_spike_views.gd`; `telegraph_views.gd`): the Gatekeeper's `row_lanes` telegraph
  (shock_lanes, shock_lanes_2) is drawn as cracked ground: faint glowing cracks under the dull outline while it
  tracks, charred ground and wide hot cracks pulsing under the bright edge once locked (steady with reduced motion).
  On the strike tick, which the view reads from `WorldReader.telegraph` (a lanes marker shows locked at progress 1000
  on exactly `BossDodge.mark_state` 2), stone spikes rise along the same lanes: faceted grey stone with red-hot
  cracks, staggered heights, taller where the lanes cross, a quick thrust (overshoot, none with reduced motion), a
  hold, then they sink by 36 ticks (0.6 s). With the effects layer: debris (`fx_debris_chunks`) and dust
  (`fx_smoke_puffs`) thrown up, a hot light flash, crack marks (`fx_scorch_mark` tinted dark). Pooled: one MultiMesh
  of at most 512 spikes, at most 8 strikes alive. Hook: an owner model `stone_spike` listed in
  `assets/models/manifest.json` at `assets/models/fx/stone_spike.glb` replaces the code spike (normalised to the
  same unit spike; the first mesh in the file is used); without it, the code spike.
- `vfx_core.gd`: two public helpers only (`light_merged`, `sprite`), appended at the end for the drawers above.
- `world_view_root.gd`: adds `spikes`, syncs it, and hands the layer to both views as drawers.

## Textures and licences (owner Q5)
- **Procedural, nothing downloaded.** The CC0 sites were blocked from this machine (raw output below). The noise is a
  `FastNoiseLite` simplex `NoiseTexture2D` made in code (`ProjectileMeshes.noise()`), the cracks are a cellular
  pattern in the shaders. No file was added to `assets/`, so `assets/models/manifest.json` and
  `data/credits/licences.tres` are unchanged (`tests/content`, which holds `test_model_manifest.gd` and
  `test_credits_licences.gd`, passes below). The owner's generator or CC0 images can replace the noise later.

```
$ curl -sS -o /dev/null -w "%{http_code}\n" --max-time 15 https://ambientcg.com/ ; curl -sS -o /dev/null -w "%{http_code}\n" --max-time 15 https://dl.polyhaven.org/
curl: (56) CONNECT tunnel failed, response 403
000
curl: (56) CONNECT tunnel failed, response 403
000
- dl.polyhaven.org:443 — connect_rejected (the egress proxy denied the CONNECT (organization policy) or could not reach the destination)
- ambientcg.com:443 — connect_rejected (the egress proxy denied the CONNECT (organization policy) or could not reach the destination)
$ curl -sS -o /dev/null -w "%{http_code}\n" --max-time 15 https://kenney.nl/ ; curl -sS -o /dev/null -w "%{http_code}\n" --max-time 15 https://polyhaven.com/
curl: (56) CONNECT tunnel failed, response 403
000
curl: (56) CONNECT tunnel failed, response 403
000
- polyhaven.com:443 — connect_rejected (the egress proxy denied the CONNECT (organization policy) or could not reach the destination)
- kenney.nl:443 — connect_rejected (the egress proxy denied the CONNECT (organization policy) or could not reach the destination)
```

## Commands and raw output

Lint:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
809 files would be left unchanged
Success: no problems found
```

The presentation tests touched and related (fireballs, telegraphs, bosses, VFX):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_attack_visuals.gd,res://tests/unit/presentation/test_boss_fight_views.gd,res://tests/unit/presentation/test_boss_fight_views_3.gd,res://tests/unit/presentation/test_boss_fights_2_views.gd,res://tests/unit/presentation/test_enemy_fireball_views.gd,res://tests/unit/presentation/test_boss_views.gd,res://tests/unit/presentation/test_boss_telegraph_parity.gd,res://tests/unit/presentation/test_telegraph_parity.gd,res://tests/unit/presentation/test_vfx_layer.gd -gexit
[… trimmed …]
Tests                72
Passing Tests        72
Asserts           17392
Time              92.78s
```
(`test_attack_visuals.gd` alone, earlier the same day: `Tests 15`, `Passing Tests 15`, `Asserts 1765`.)

Content (manifest, credits), arch, golden:
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Tests               133
Passing Tests       133
Asserts            8789
Time              46.964s
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch -ginclude_subdirs -gexit
Tests                 4
Passing Tests         4
Asserts            8973
Time              2.159s
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/golden -ginclude_subdirs -gexit
Tests                 2
Passing Tests         2
Asserts               4
Time              12.366s
```

The e2e that reach boss fights and fireballs (with the new `test_e2e_stone_spikes.gd`: through `main.tscn`, dev
panel clicks, the Gatekeeper's shock lanes crack the ground, strike as spikes, and sink back into the pool):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_stone_spikes.gd,res://tests/e2e/test_e2e_boss_dodge.gd,res://tests/e2e/test_e2e_boss_dodge_2.gd,res://tests/e2e/test_e2e_boss_dodge_3.gd,res://tests/e2e/test_e2e_bosses.gd,res://tests/e2e/test_e2e_bosses_2.gd,res://tests/e2e/test_e2e_enemy_fireballs.gd,res://tests/e2e/test_e2e_new_enemies.gd,res://tests/e2e/test_e2e_boss_challenge.gd -gexit
[… trimmed …]
Tests                11
Passing Tests        11
Asserts             490
Time              60.484s
```

Shards:
```
$ bash scripts/ci/gut_shard.sh --check
gut_shard: ok (295 test files in 6 shards)
```

Not run locally: the full suite (CLAUDE.md: it runs once per version on GitHub).

## Screenshots
```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/attack_visuals.gd
attack_visuals: res://build/shots/v0.7.5-dev/av/1_gatekeeper_ember_stones.jpg (tick 110)
attack_visuals: res://build/shots/v0.7.5-dev/av/2_warlord_spear_embers.jpg (tick 90)
attack_visuals: res://build/shots/v0.7.5-dev/av/3_brood_acid_globs.jpg (tick 150)
attack_visuals: res://build/shots/v0.7.5-dev/av/4_hive_prism_orbs.jpg (tick 164)
attack_visuals: res://build/shots/v0.7.5-dev/av/5_siege_cannon_embers.jpg (tick 150)
attack_visuals: res://build/shots/v0.7.5-dev/av/6_foundry_molten_drops_raining.jpg (tick 80)
[shots 7–12 written; then the process was killed (exit 137, "Killed") while other agents' renders filled the
 machine's memory; two retries from shot 13 were killed the same way; the third, sampled at a steady ~3.1 GB RSS,
 finished:]
$ ... -s scripts/shots/attack_visuals.gd -- from=13
attack_visuals: res://build/shots/v0.7.5-dev/av/13_gatekeeper_spikes_erupting.jpg (tick 99)
attack_visuals: res://build/shots/v0.7.5-dev/av/14_gatekeeper_spikes_standing.jpg (tick 106)
attack_visuals: res://build/shots/v0.7.5-dev/av/15_gatekeeper_spikes_close.jpg (tick 106)
attack_visuals: res://build/shots/v0.7.5-dev/av/16_gatekeeper_spikes_sinking.jpg (tick 124)
attack_visuals: res://build/shots/v0.7.5-dev/av/17_gatekeeper_cracks_left.jpg (tick 140)
```
The script names the folder after `GameVersion.label()` (`v0.7.5-dev` on this branch); the 17 images were copied to
`build/shots/v0.8.0/av/`, and these into [`av_shots/`](av_shots/): ember stones, spear embers, prism orbs, Arc
Caster plasma, the shock lanes tracking and locked, the spikes standing (wide and close) and sinking. The Ruins
mood (the game's lit look). The camera stays on the hero in these shots (the framing argument did not take), so the
orbs are seen at play distance, not close up.

## Result
| Check | Measured | In band? |
|---|---|---|
| Every content fireball look has its own 3D look | `test_every_fireball_source_has_its_own_3d_look` passes | yes |
| Pools bounded (3 MultiMeshes a look; ≤ 512 spikes, ≤ 8 strikes) | `test_each_look_is_three_pooled_multimeshes`, `test_the_spike_pool_is_bounded` pass | yes |
| Spikes on the strike tick only, inside the lanes hit, back in the pool | `test_the_shock_lanes_strike_as_spikes_that_sink_back_into_the_pool`, `test_only_the_shock_lanes_raise_spikes` pass | yes |
| Low density thins trails; reduced motion stills | the two tests pass | yes |
| Lights within VfxCore's budget | `test_the_big_ones_ask_for_light_within_the_budget` passes | yes |
| Goldens | `tests/golden` 2/2, unchanged | yes |
| The look, the feel, frame time on the owner's PC | — | **OWNER ONLY** |

## Interpretation
The orbs and the Gatekeeper's lanes are now 3D in the game, drawn from what the sim already exposes; nothing the sim
decides changed (goldens pass unchanged). Not measured: frame cost on real hardware (the PF step owns the frame
budget; the spikes add one MultiMesh draw with shadows, the fireballs the same three draws a look as before, with
heavier shaders). For the owner: whether the looks read right in play, whether the acid globs should be greener and
the cannon smoke lighter (on dark floors it is faint), and whether to send the `stone_spike` model and any texture.
Part 2 of AV (the other bosses' ground attacks) is not started.

---

# Part 2: do the other bosses' ground attacks keep a readable marker in their own look and strike as 3D effects? (v0.8.0 AV part 2)

- **Status:** RUN (tests, lint, shots). The look and the feel: **OWNER ONLY**.
- **Build:** the `v0.8.0 Step AV2` commit on branch `v080-av2` (parent `0dfa2c7`); every run below was on that
  working tree before it was committed. Godot `4.7.2.stable.official.ed1daf0bf`; cloud container; shots on software
  Vulkan (llvmpipe) under xvfb, not the owner's hardware.
- **Date:** 2026-10-14
- **Who ran it:** agent

## What changed (presentation only; the sim and its timings are untouched)
- **The looks** (new `boss_strike_looks.gd`): per boss kind and move (WorldReader `KIND_*` / `MOVE_*`), a ground
  pattern and a strike kind. Every ground attack in `data/bosses` has one (the test derives the list from the data);
  the Gatekeeper's `row_lanes` stay part 1's cracked ground and spikes.
- **The markers** (`telegraph_views.gd`): a boss marker with a look keeps the dull outline and no fill while it
  tracks and the bright edge once locked (the lock flash is still the dodge cue), but its fill is the look's pattern
  (`BossStrikeLooks.MARK_SHADER`: Gatekeeper stone cracks, Warlord steel scratches, Brood Mother bubbling acid, Hive
  Lens gold light shimmering over violet, Siege Engine amber hazard stripes, Foundry molten seams), hot and pulsing
  once locked (steady, and no flow, with reduced motion); an untracked windup's fill warms as it fills. The edges keep
  the palette's `telegraph_hostile` colour, so the colour-blind modes still apply to the cue.
- **The strikes** (new `boss_strike_views.gd`, with `boss_strike_shapes.gd`, `boss_strike_meshes.gd`,
  `boss_strike_fx.gd`): drawn on the tick the sim strikes, read from WorldReader only: a marker or grid circle shows
  locked at progress 1000 (mark_state / grid_state 2), a windup turns active (the hit resolves on that tick), a leap's
  `boss_leap` reaches 1.0 (its landing tick), a burrow's `boss_hidden` turns false; the geometry is the telegraph's.
  Gatekeeper fist slam: a crater (rocks thrown, a dust shockwave, a hot cracked bowl); sweep: a dust arc with rocks.
  Warlord spear lines / spear wall: rows of spears thrust up the lanes (standing while the lanes do, then retracting);
  lunge: a scorched skid behind it with sparks at its feet; shield bash: a steel arc with sparks; javelin rain:
  javelins thrown into the circles. Brood Mother eggs: the egg's shadow grows on its circle as it falls, then an acid
  splat (shell fragments, `VfxLayer.burst` venom); leap: a cracked impact with dust; burrow: a ring of dirt and rock
  erupting; brood: acid splats. Hive Lens focus beam: a 3D beam (a tube with a scrolling noise core and a gold halo)
  down each locked lane, a scorched line under it; lens flare: a ring of light; dive and split: bursts of light.
  Siege Engine mortar grid and barrage: the shell falls into its locked circle (a shadow, then the shell), then an
  explosion (`VfxLayer.burst` fire: fireball, smoke, sparks, light, scorch), shrapnel, a crater; rail: a white-hot
  streak with a lingering haze and a scorched line; shockwave: a dust wall rolling out (16 m at most); deploy: shell
  drops. Foundry molten flood: molten metal pours down the lanes, then cools from hot seams to a dark crust over 100
  ticks; vent blast: a ring of steam and heat; firestorm: burning lanes with flames; bomb launch: explosions.
- **Pools and budgets:** six MultiMeshes (rocks 384, blades 384, glowing bands 64, dust bands 48, beams 32, ground
  quads 160; one draw each), two rebuilt arc meshes, at most 24 strikes alive. Sprites from VfxCore's pools (inside
  the 2,000), lights through the 10-light pool (merged per strike), marks through the 64 decals, explosions and splats
  through `VfxLayer.burst` (v0.8.0 PF's frame budget) and `BurstBudget.admit` for the live ones. Effects density thins
  the rocks and the sprites (the blades and the ground marks stay); reduced motion stills the tumbling, the overshoot
  and the shaders' flow. No camera shake is added.
- **Colours:** the instance colour rides in the MultiMesh custom data (`BossStrikeMeshes.pack`, six bits a channel).
  The glows are 60°+ of hue from the hero's `player_core` (test below).
- `world_view_root.gd`: adds `strikes`, syncs it, hands it the layer and adds its drawer. No edit to the boss avatars
  (another agent's files) or to VfxCore.
- Procedural, nothing downloaded (the CC0 sites were refused in part 1); no file added to `assets/`.

## Commands and raw output

Lint:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
831 files would be left unchanged
Success: no problems found
```

The new unit tests (`test_attack_visuals_2.gd`: every content ground attack has a look that fits its shape; each one
strikes on the sim's strike tick with its look, and no hit on the player lands without its strike drawn; markers dull
and unfilled while tracking, styled once locked or filling; the lock flash hotter and steady with reduced motion; pools
fixed and capped; spears stand while the flood does and retract into the pool; an egg's shadow before the splat; Low
density thins the rocks; the effects through the layer's budgets; colours off the hero's; the shock lanes stay the
spikes):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_attack_visuals_2.gd -gexit
Tests                11
Passing Tests        11
Asserts           17377
Time              26.567s
```

The presentation set (telegraph, fireball, boss, VFX and attack-visuals files; part 1's fist-slam test now checks the
styled flash):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_attack_visuals.gd,res://tests/unit/presentation/test_attack_visuals_2.gd,res://tests/unit/presentation/test_boss_challenge_parity.gd,res://tests/unit/presentation/test_boss_challenge_views.gd,res://tests/unit/presentation/test_boss_fight_views.gd,res://tests/unit/presentation/test_boss_fight_views_3.gd,res://tests/unit/presentation/test_boss_fights_2_views.gd,res://tests/unit/presentation/test_boss_models.gd,res://tests/unit/presentation/test_boss_models_2.gd,res://tests/unit/presentation/test_boss_rigs.gd,res://tests/unit/presentation/test_boss_telegraph_parity.gd,res://tests/unit/presentation/test_boss_views.gd,res://tests/unit/presentation/test_bosses_2_views.gd,res://tests/unit/presentation/test_enemy_fireball_views.gd,res://tests/unit/presentation/test_movement_vfx.gd,res://tests/unit/presentation/test_telegraph_parity.gd,res://tests/unit/presentation/test_vfx_budget.gd,res://tests/unit/presentation/test_vfx_layer.gd -gexit
Tests               148
Passing Tests       148
Asserts           35854
Time              81.991s
```

Arch, golden, content:
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch -ginclude_subdirs -gexit
Tests                 4
Passing Tests         4
Asserts            9221
Time              1.34s
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/golden -ginclude_subdirs -gexit
Tests                 2
Passing Tests         2
Asserts               4
Time              9.068s
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Tests               133
Passing Tests       133
Asserts            8790
Time              29.36s
```

The boss e2e (with the new `test_e2e_boss_strikes.gd`: through `main.tscn`, dev panel clicks, each of the Warlord,
Brood Mother, Hive Lens, Siege Engine and Foundry in turn: a ground attack drawn in its look, a strike in 3D with that
boss's look, drawn; KillBoss; the strikes end):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_after_boss.gd,res://tests/e2e/test_e2e_boss_challenge.gd,res://tests/e2e/test_e2e_boss_dodge.gd,res://tests/e2e/test_e2e_boss_dodge_2.gd,res://tests/e2e/test_e2e_boss_dodge_3.gd,res://tests/e2e/test_e2e_boss_strikes.gd,res://tests/e2e/test_e2e_bosses.gd,res://tests/e2e/test_e2e_bosses_2.gd,res://tests/e2e/test_e2e_stone_spikes.gd -gexit
Tests                11
Passing Tests        11
Asserts             444
Time              93.743s
$ bash scripts/ci/gut_shard.sh --check
gut_shard: ok (300 test files in 6 shards)
```

Not run locally: the full suite (CLAUDE.md: it runs once per version on GitHub).

## Screenshots (part 2)
Rendered one at a time (the machine is shared), on the final code after the fixes listed below. The first run hit its
`timeout` after shot 21 (exit 124) and was resumed with `from=22`:
```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 4000 xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/attack_visuals_2.gd
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/1_gatekeeper_fist_slam_locked.jpg (tick 80, -1 after the strike, 0 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/2_gatekeeper_fist_slam_crater.jpg (tick 101, 5 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/3_gatekeeper_sweep_dust_arc.jpg (tick 40, 4 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/4_warlord_spear_lines.jpg (tick 104, 8 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/5_warlord_lunge_skid.jpg (tick 96, 12 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/6_warlord_shield_bash.jpg (tick 39, 3 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/7_warlord_javelin_rain.jpg (tick 101, 5 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/8_brood_egg_shadows.jpg (tick 88, -1 after the strike, 0 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/9_brood_acid_splat.jpg (tick 100, 4 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/10_brood_leap_impact.jpg (tick 128, 3 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/11_brood_burrow_eruption.jpg (tick 210, 6 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/12_hive_focus_beam_locked.jpg (tick 80, -1 after the strike, 0 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/13_hive_focus_beam.jpg (tick 101, 5 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/14_hive_lens_flare.jpg (tick 46, 4 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/15_siege_mortar_grid_locked.jpg (tick 80, -1 after the strike, 0 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/16_siege_mortar_shells.jpg (tick 100, 4 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/17_siege_barrage_shells.jpg (tick 100, 4 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/18_siege_rail_streak.jpg (tick 92, 2 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/19_siege_shockwave.jpg (tick 82, 10 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/20_foundry_molten_flood_locked.jpg (tick 80, -1 after the strike, 0 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/21_foundry_molten_flood_pouring.jpg (tick 112, 16 after the strike, 1 strikes)
exit 124
$ ... -s scripts/shots/attack_visuals_2.gd -- from=22
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/22_foundry_molten_flood_cooling.jpg (tick 256, 160 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/23_foundry_vent_blast.jpg (tick 53, 5 after the strike, 1 strikes)
attack_visuals_2: res://build/shots/v0.7.5-dev/av2/24_foundry_firestorm.jpg (tick 112, 16 after the strike, 1 strikes)
```
The script names the folder after `GameVersion.label()` (`v0.7.5-dev` on this branch); the 24 images were copied to
`build/shots/v0.8.0/av2/`, and twelve into [`av_shots/`](av_shots/) with an `av2_` prefix: the fist slam's crater,
the spear lines, the javelin rain, the acid splat, the burrow's eruption, the focus beam, the lens flare, the mortar
grid locked and its shells exploding, the rail streak, the molten flood pouring, the vent blast. The Ruins mood; the
camera is framed per shot and the player held still at one spot (some strikes land behind a ruin wall, or the boss
lands on the player and covers the strike).

What the shots changed (found by looking at them, then fixed and re-rendered):
- The MultiMesh instance colours came through white in these shaders on this renderer (a forced-blue test showed the
  quads drawn, a probe printed the right colours on the CPU side): the dust bands, beams, rocks and ground quads were
  white or tan. The colour now rides in the custom data (`BossStrikeMeshes.pack`), which is proven to arrive.
- A wide molten bed above 1.0 turned cream under the stage's exposure: the bed is now dim orange with a dark crust,
  only the seams hot; the strike's ground quads draw over the telegraph's fill (`render_priority` 1).
- The first framing put a ruin wall between the camera and the player (drawn dithered); the player stands elsewhere.

## Result (part 2)
| Check | Measured | In band? |
|---|---|---|
| Every content ground attack has a look that fits its shape | `test_every_boss_ground_attack_in_the_content_has_a_look` passes | yes |
| Each strikes on the sim's strike tick, with its look; no hit lands undrawn | `test_each_ground_attack_strikes_on_the_sims_strike_tick_with_its_look` passes | yes |
| Markers dull and unfilled while tracking, styled once locked or filling | `test_markers_are_styled_dull_while_tracking_and_hot_once_locked` passes | yes |
| Pools fixed and capped; at most 24 strikes; live explosions within `BurstBudget.MAX_LIVE` | `test_strikes_draw_from_pools_with_fixed_caps` passes | yes |
| Lights within 10, decals within 64, explosions through the frame's burst budget, sprites thinned by density | `test_the_effects_go_through_the_layers_budgets` passes | yes |
| Low density thins the rocks; reduced motion stills the flow | `test_low_density_thins_the_rocks_and_reduced_motion_stills_the_flow` passes | yes |
| Glows off the hero's hue | `test_the_looks_stay_off_the_heros_colours` passes (more than 60 degrees) | yes |
| Reaches the real game | `test_e2e_boss_strikes.gd` 1/1 (five bosses) | yes |
| Goldens | `tests/golden` 2/2, unchanged | yes |
| The look, the feel, frame time on the owner's PC | — | **OWNER ONLY** |

## Interpretation (part 2)
Every boss ground attack in the content now has its own marker fill and a 3D strike, drawn from what the sim already
exposes, on the tick the sim strikes; nothing the sim decides changed (goldens unchanged). Not measured: frame cost on
real hardware (six more MultiMesh draws at most, plus sprites inside VfxCore's existing budgets). For the owner:
whether each look reads as its attack, whether the patterned fills keep the lock flash readable enough, and whether
the beam, the molten metal and the dust should be brighter or calmer. The lunge's skid is short in its shot (the
charge stopped at a wall).
