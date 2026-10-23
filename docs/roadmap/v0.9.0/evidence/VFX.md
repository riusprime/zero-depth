# v0.9.0 VX: the VFX pass (evidence)

The owner-approved G1 is [`../VFX_AUDIT.md`](../VFX_AUDIT.md); the answers are the PLAN's "Owner decisions" row `VX`
(2026-10-23). Branch `v090-vx` from `claude/world-combat-v090` at `ea16d8f7`. Code at `3a4a51dc` (first piece
`26f22a51`). Machine: the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2, local agent session.

## What was built, per approved row

| Row | Built |
|---|---|
| V1 | `ElementLooks` (`src/presentation/world_view/attack_forms/element_looks.gd`): one table of hot, core and deep tones, the effects-layer kind and the Laser look per element. `AttackFormLooks.ELEMENT_CORE` is `ElementLooks.CORE`; `BeamLooks.core/edge` read it; `ImpactFx` reads it through `AttackFormLooks.element_color`. Bleed is dark red `#A8102A` everywhere (the Orbs' tinted cyan is gone) |
| V2 | The beam forms take the first element's look, centre and accent and the second element's edge (`ElementLooks.pair`, `BeamLooks.colors`); no fixed precedence. `FormLook` carries it to the Laser, Bomb, Lance, Scatter, Glaive, Seekers, Wave and Wisps |
| V3 | A muzzle spark per Orbs volley (`AttackFormView._sync_volley`, `HeroFx.muzzle`): a white-hot core star, a glow in the element's colour, two sparks streaking out; 6 ticks, no light, none at Low |
| V4 | `ImpactFx` records each bolt hit's element kind and adds `HeroFx.impact` for the newest (FULL) impacts: Fire embers, a hot glow and smoke; Lightning a forked bolt that flickers; Frost the frost-burst flake, glints and ice shards; Venom a splash and droplets; Bleed a splash, droplets and a splatter mark. None at Low |
| V6 | Every live Orb with an element carries `HeroFx.accent` from the layer's pools (capped by `LIVE_BOLTS_MAX`): a halo in the element's colour plus Fire a flame tongue, the owner's comet ember streak and embers; Lightning re-striking crackles; Frost ice shards, a glint and cold mist; Venom and Bleed a trailing splash spray and glossy drops. None at Low |
| V8 | The Laser's impact plays the V4 extra every 30 ticks (twice a second) for 18 ticks, never on every damage tick. The beam shader gained a third tone (the element's deep tone as the outer glow) |
| V10 | The Bomb's blast ring colours go through `AttackFormLooks.ground_safe` |
| V11 | Kept: a no-element bomb draws the fire explosion; its fuse sheds embers |
| V12 | The Void lens and core grow from a point over their first 6 ticks |
| V14 | A Void shot that ends collapses where it was (its own pool of 6: core and lens shrink to a point over 8 ticks) with a violet `HeroFx.flash` |
| V15 | The element tints the Void's bent-light rim and dust trail (the body and dark core stay violet) and adds its accent along the trail from Medium up |
| V17 | The Lance's camera kick is removed (`rig` and `KICK_M` gone; WorldViewRoot no longer hands it the rig) |
| V18 | A live bolt drawn 1.8x its look or more (the Lance near full charge) takes the 9-segment trail |
| V19 | LanceView tracks its balls; one that leaves with a wall just ahead (its own nearest-point test against the reader's walls) plays a flash and the element's extra there, 18 ticks |
| V22 | `HeroFx.spray` over each live Scatter cone: a glow, then Fire embers, Lightning a crackle across the fan, Frost shards and glints, Venom and Bleed droplets (5 pieces); none at Low |
| V25 | Each Glaive disc's rim sheds the element's accent |
| V26 | A disc coming back that leaves within 1.6 m of the hero flashes at the hand (4 ticks) |
| V27 | The Seekers' volley gets three muzzle sparks fanned 0.55 rad apart |
| V29 | With the effects layer on and an element, the Seekers' round motes hide and each becomes the element's own sprite (`HeroFx.mote`): same count |
| V30 (AF3 merged) | The Wave unrolls from the hero over 4 ticks, takes the V2 colours, and at its foot draws the element's accent or a skim of dust (Medium and High). **Not built:** "it fades over its last metre": `WorldReader.wave_shots` gives no range left |
| V31 (AF3 merged) | The Wisps take the V2 colours, each carries its element's accent along its orbit and flashes as it fires (6 ticks, no light) |
| V33 | A Halo volley (pattern all round) draws a quick ground ring (0.8 m, 8 ticks) in a ground-safe colour (`HeroFx.ground_ring`) instead of a muzzle spark |
| V35 | Backfire adds a muzzle spark at the back |
| V36 | A Spiral bolt (the helix cue) takes the 9-segment trail |
| V37 | No Swirl cue (owner) |
| V43 | `fire_patch` hooked up: a floor decal under Fire's flames once the PNG is installed (`VfxCore.MARK_TEX`, tint `VfxLayer.FIRE_PATCH_TINT`) |
| V45 | `assets/textures/vfx/manifest.json`: every effect texture id the code asks for, its use, tint and fallback, installed or fallback; `tests/content/test_vfx_manifest.gd` checks both ways |
| V46 | The hero's side moved: Frost core `#B5F2FF` to `#9AF5DC` (greener), the Bleed centre `#FF7080` to `#E84256` (darker). The test covers every element's hot and core, every two-element pair and every BeamLooks colour against every hostile fireball core (distance over 0.2) |
| V47 | Low: the Void keeps its core, lens and ring (dust disc and trail puffs go), the Glaive drops its afterimages, the Seekers keep 2 motes a dart, the Lance's circle halves its motes, the Laser ribbon, impact star, Scatter cone and bomb ring stay, and every HeroFx accent and extra goes. Reduced motion stills the Void's dust and the Lance's circle |
| V48 | `FormLook` reads the Gun shot's spec once per build (`attack_digest`) in every form view; Scatter, Glaive and Seekers reuse their buffers (no Dictionary or slice a disc or dart a sync); every new piece goes through VfxCore's pools and frame cap |
| V49 | The Bomb ring, the Void ring (`ground_safe(VIOLET)`), the Halo ring and the fire patch tint are tested out of the hostile hues for every element and pair |
| V52 | `scripts/shots/vx_shots.gd`: 9 sheets asked (8 forms x 6 element looks, the patterns on the Orbs) plus the Wave and the Wisps |

Also: VfxCore gained the pools `glow` and `ring` (code-made sheets until `fx_soft_glow` / `fx_energy_ring` arrive), `ember`
(the owner's ember sparks, drawn as unshaded colour over 1 so they read on light floors) and `flake` (the owner's frost
burst as additive light), and the optional pools `shard`, `drop`, `fork`, `muzzle`, made only once their requested PNG
is installed. The canvas's particle helpers moved to `FormParticles` unchanged (the canvas's 1,000-line limit).

## Texture requests

`docs/art/requests/v0.9.0_ART_LIST.md` §7c: `fx_frost_shards`, `fx_blood_drops`, `fx_lightning_fork`, `fx_muzzle_flash`
(1024 x 1024, 2 x 2), `fx_energy_ring` (512), `fx_soft_glow` (256, optional). Each is in the VFX manifest as `fallback`.

## Lint

```
$ files=$(git diff --name-only claude/world-combat-v090 -- '*.gd'); gdformat --check $files; gdlint $files
27 files would be left unchanged
Success: no problems found
```

## Tests (code of 3a4a51dc)

```
$ godot --headless --path . --editor --import --quit
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<36 files: test_vx_looks,
  test_vfx_manifest, test_laser_view, test_bomb_view, test_void_view, test_lance_view, test_scatter_view,
  test_glaive_view, test_seekers_view, test_wave_wisps_view, test_gun_looks, test_attack_forms_live,
  test_attack_form_looks, test_attack_forms, test_hit_impact, test_vfx_layer, test_vfx_budget, test_vfx_pressure,
  test_vfx_interpolation, test_gun_pulse, test_boss_fight_views, test_biome_interaction_looks, test_fx_textures,
  test_blade_feel, test_wand_views, test_wand_cast_view, test_blade_form_view, arch/test_layering,
  content/test_model_manifest, content/test_assets, e2e/test_e2e_lance_scatter, test_e2e_glaive_seekers,
  test_e2e_wave_wisps, test_e2e_void, test_e2e_laser, test_e2e_bomb>
Tests               249
Passing Tests       249
Asserts           19868
Time              89.789s
```

Tests changed on purpose: `test_attack_form_looks` (Bleed is dark red, not MX1's tint); `test_vfx_interpolation` (the
optional pools exist only once installed). New: `tests/unit/presentation/test_vx_looks.gd` (18 tests),
`tests/content/test_vfx_manifest.gd` (4). Not run here: the known reds (test_final_pace; the Spanish-locale
test_frozen_shore, test_starfall, test_deep_bite, test_deep_look) and the rest of the suite (GitHub runs it).

## Performance: the horde probe, heaviest form (Void + Twin Lv 5, Fire), 60 Chargers, CPU side (headless)

```
$ godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde=60 \
    --cards=gun_void,gun_twin,ember_core --level=5 --seconds=10 --tag=vx_<before|after>
```

Before (ea16d8f7):
```
sim_ms            2.965     4.772     8.502
sync_ms           5.352     7.215    16.452
frame_ms          3.502     4.270     6.555
total_ms         11.818    15.501    25.965
sprites_drawn   193.997   303.000   339.000
lights_on         4.767     7.000     7.000
  AttackFormView              1.352
world hash at tick 660: feab078b76ae215d0008287ed73e96ab6907308dae7d31014eab5e1d238747f9
verdict: avg 11.82 ms per tick+frame against 12.0 ms -> within
```

After (code of 3a4a51dc):
```
sim_ms            2.898     4.610     8.097
sync_ms           4.988     6.637    16.578
frame_ms          3.733     4.535     7.244
total_ms         11.619    15.397    26.685
sprites_drawn   271.922   382.000   426.000
lights_on         5.447     9.000    10.000
  AttackFormView              1.696
world hash at tick 660: feab078b76ae215d0008287ed73e96ab6907308dae7d31014eab5e1d238747f9
verdict: avg 11.62 ms per tick+frame against 12.0 ms -> within
```

Columns: avg, p95, max. The frame's CPU side rose 0.23 ms avg (AttackFormView +0.34 ms; 78 more sprites a tick on
average); the total stayed within the 12 ms budget (one run each; the sync and sim moved by run-to-run noise). The world
hash is the same: no sim change. The GPU side is not in a headless probe: `NOT YET RUN (owner hardware, in play)`.

## Shots (V52)

```
$ godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx_shots.gd
Vulkan 1.4.351 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 3060
vx_shots: res://build/shots/v0.8.0/vx/1_orbs.jpg … 11_wisps.jpg
```

Copied to [`vx_shots/`](vx_shots/): `1_orbs`, `2_laser`, `3_bomb`, `4_void`, `5_lance`, `6_scatter`, `7_glaive`,
`8_seekers`, `9_patterns` (Twin, Halo, Ring / Backfire, Spiral, Swirl, all Fire), `10_wave`, `11_wisps`. Each sheet:
no element, Fire, Lightning (top) / Frost, Venom, Bleed (bottom), the element's swatch in each tile's corner; Ruins with
its lit mood, Effects density Medium. The Halo's ground ring lasts 8 ticks and is not in the frame the sheet grabs.

Looked at by the agent from the game camera (and closer with `-- --only=<sheet> --cam=3.5`): the first pass read flat
on the Orbs: the first VX run, copied from `void_shots.gd`, never gave the view its biome mood, so the effects layer was
off in its frames; the VX script now sets it as main.gd does. Fixed before hand-back: Fire got the comet streak and a bigger flame
tongue, Venom and Bleed a trailing splash spray and brighter glossy drops, the Laser a third tone, the Lance's burst glow
was too wide and was cut, the Scatter spray grew. **OWNER ONLY:** whether each element now reads as high quality in
play.
