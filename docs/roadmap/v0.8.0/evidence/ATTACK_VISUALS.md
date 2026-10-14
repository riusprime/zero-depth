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
