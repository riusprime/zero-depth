# v0.9.5 G1: the new VFX pack replaces the attack effects (VFX_PACK)

**Owner (2026-10-31):** "there is a new folder called "new VFX" in this project, it is a pack of premade assets I want
to include in the game to replace what we have attack related, all the VFX there are great and we could even modify
color a bit if we needed them to match any kind of element or element combination so first of all can you see them
individually? i'd like you to go through them and assign them to an effect to replace it and see which one we don't
have a replacement for, make a small test and see how much we take"

**How to answer:** row by row ("I1 yes, R4 use hit_07 instead, N1 buy a lightning pack, …"). Nothing is built before
the answers.

**See every effect:** `build/vfx_lab/index.html` on the owner's PC (291 effects, each alone, from the game's camera).
The cost numbers and how they were measured are in [evidence/VFX_PACK.md](evidence/VFX_PACK.md).

## The pack (`newVFX/`, 20 zips, 14 MB, untracked)
- **Attack packs (Binbun VFX, Godot 4 scenes):**
  - Fire (32);
  - Beam (18: thick beams, lasers, a blast);
  - Ice (20);
  - Magic Orbs (36);
  - Magic Projectiles ("GreenExtra", 15);
  - Impact (24: explosions, hits, impacts);
  - Magic Area (36: basic, lift, pillar, pulse, rim, ripple);
  - Muzzle Flash (24);
  - Poison (30);
  - Smoke (24).
- **How the Binbun scenes work:** each effect is one scene with a `VFXController` script, an AnimationPlayer, 0–4
  GPUParticles3D, 1–6 meshes and usually one OmniLight3D. Its `primary_color`, `secondary_color`, `tertiary_color`
  and `speed_scale` are settings, so a recolour is a setting, not new art.
- **Magic Circles 3D Free** (heyheythere, **CC BY 4.0**): circles and ripples on the ground in 8 elements, built in
  code by one `MagicArea` node.
- **Not attack-related (not reviewed here):** Portal, Loot, Card FX, Hologram, Glass UI, Grass, Skies, Transitions,
  UltimateToon. Portal and Loot fit the ascension portal and the rarity glows on cards and pickups; that would be a
  separate request.

## Today (live code)
The catalog below is from a read of `src/presentation/world_view/` (written `W/`) on `17de13e3`.
- **No attack effect uses GPUParticles.** Attack effects are drawn four ways:
  - MultiMesh pools: `VfxCore` sprites `W/vfx/vfx_core.gd:13-61`, `AttackFormPool`, `FireballViews`,
    `HeroPulseViews`, `BossStrikeViews`;
  - pooled shader quads (the v0.9.0 form views in `W/attack_forms/`);
  - ImmediateMesh (telegraphs, blade trails);
  - small pools of plain meshes.

  A pool is one draw call.
- **Element looks:**
  - `ElementLooks` `W/attack_forms/element_looks.gd:17-68` sets each element's colours (ember, storm, frost, venom,
    bleed; void only on Phase Dash). Two elements: the first one's core plus the second one's rim (`:142`).
  - `VfxLayer` draws each element's field, ring, line, burst and status (`W/vfx/vfx_layer.gd:47-207`).
- **Hits:** `ImpactFx` `W/impact_fx.gd:244`; hero extras `W/vfx/hero_fx.gd:301`.
- **Budgets:**
  - 10 lights in VfxCore's pool (`vfx_core.gd:63-88`);
  - at most 2,000 GPU particles and 24 hit-spark emitters (PRESENTATION_CONTRACTS §7);
  - attack forms: 1,024 meshes and 1,200 particles (`W/attack_forms/attack_form_canvas.gd:7-21`);
  - bursts: 12 drawn in full, 32 a frame (`W/vfx/vfx_layer.gd:39-42`).
- **Rules that bind any replacement:**
  - presentation reads the sim, never writes (EI-07);
  - no animation decides an outcome (EI-03);
  - flashes are additive light, while debris and vapour are lit by the scene (ART_DIRECTION A3);
  - **player ground marks never take a hostile hue** (red-orange to magenta, PRESENTATION_CONTRACTS §4,
    `AttackFormLooks.ground_safe`);
  - no runtime toggling of `emission_enabled` (the damage-lag rule);
  - the 144 fps target on the owner's PC (PLAN PF).

## The small test (summary of the evidence)
24 copies of each effect family, 1080p, the owner's RTX 3060. The base scene costs 0.9 ms GPU.

| Finding | Number |
|---|---|
| **Freeze the first time an effect appears** (shader compile, cold) | 50–420 ms for most; **1.7 s ice ball, 1.6 s smoke** |
| The effects' own lights (24 areas) | +2.0 to +4.4 ms GPU, on top of the effects themselves |
| Projectiles, orbs, hits, muzzle flashes (no lights) | +0.2 to +0.6 ms GPU |
| Areas / beams (no lights) | +1 to +1.5 ms / +1.7 ms |
| Explosions, big impacts (no lights) | +2.4 to +3.7 ms |
| Smoke and poison clouds | grow over time; 24 full clouds read 13–23 ms (overdraw) |
| CPU render time, 24 copies | 0.13–0.33 ms |
| Particles per effect | 0–128 (24 beams = 3,072, over the 2,000 limit) |
| Draw calls per effect | about 3–6, where today's bolts and sparks share one MultiMesh draw per pool |
| Size | about 15 MB of source for the attack packs |

## Integration rules (how any replacement is built)
| ID | Rule | Why | Proposal |
|---|---|---|---|
| I1 | Install only the attack packs, at the paths their scenes expect; the zips stay out of the repo | Scenes load by path | **I1:** install as `assets/BinbunVFX/` (the paths the scenes expect) + `addons/magic_circles/`; asset tests cover them |
| I2 | **Warm-up:** every pack effect the game uses is spawned once, off screen, behind the loading screen | 0.05–1.7 s freeze on first use | **I2:** a warm-up list in the content data; the hitch probe checks a run start |
| I3 | **Lights off** in every pack scene; the light, if any, comes from VfxCore's 10-light pool | +3–4 ms for 24 lit areas; the game caps lights at 10 | **I3:** yes |
| I4 | **Pack scenes only for big, rarer effects** (explosions, impacts, areas, beams, status on a few enemies, shields, boss strikes), pooled and capped. **Every-shot effects** (bolts, hit sparks, muzzle flashes) reuse the pack's shaders and textures inside our existing MultiMesh pools | Draw calls: one scene per shot would multiply them | **I4:** yes |
| I5 | Caps: the pack's particles count toward the 2,000 limit; live pack scenes capped per family (starting values: 24 hits, 12 explosions, 16 areas, 8 beams, 4 clouds) | Contracts §7; clouds' overdraw | **I5:** yes, starting values |
| I6 | Colours: each effect is recoloured to the element's colours from `ElementLooks` (ART_DIRECTION §4); two elements = first element primary, second element secondary | One look per element and per pair | **I6:** yes |
| I7 | **Player ground effects stay out of the hostile hues.** The pack's fire areas, red puddles and orange rings would be on the floor in the telegraphs' red-orange band | Readability rule (Contracts §4) | **I7:** player fire and bleed zones go through `ground_safe` (they lean cooler); enemy and boss zones keep the warm hues. Or: change the rule (owner's call) |
| I8 | Pack effects are cosmetic: they read sim events, follow hit-stop and pause through `speed_scale`, and decide nothing | EI-03, EI-07 | **I8:** yes |
| I9 | Effects density (low / medium / high) also scales the pack effects | Options already promise it | **I9:** yes |
| I10 | **Licence:** the Binbun packs ship with no licence file. Magic Circles Free needs a credits line: "Magic Circles 3D Free by heyheythere - https://heyheythere.itch.io/magic-circles-3d-free - CC BY 4.0" | Legal | **I10:** owner confirms the Binbun licence; the credits line goes in |

## Replacements (game effect → pack effect)
"Fit": Full = replaces it as is (after recolour); Partial = replaces part of it, the rest stays ours.

| ID | Game effect today | File | Pack effect | Fit | Proposal |
|---|---|---|---|---|---|
| R1 | Hero shot (orbs) in flight, per element | `W/hero_pulse_views.gd`, `W/attack_forms/live_bolt_look.gd:80` | ember `fire_ball_01`/`05` · frost `ice_ball_vfx_01` · venom `mprojectile_basic_vfx_05` · storm and plain `mprojectile_basic_vfx_02` · bleed `mprojectile_basic_vfx_04` recoloured red | Full | **R1:** yes (shaders into the HeroPulse pools, I4) |
| R2 | Seekers needles and trail | `W/attack_forms/seekers_view.gd` | `mprojectile_javelin_vfx_01–05` | Full | **R2** |
| R3 | Wisps orbs, firing flare | `W/attack_forms/wisps_view.gd` | `magic_orb_small_*`, `magic_orb_flare_*` | Full | **R3** |
| R4 | Laser beam, muzzle, impact star | `W/attack_forms/laser_view.gd`, `beam_looks.gd:43` | `laser_vfx_*`: storm 02, frost 04, ember 06/07, void 05, bleed 01; venom `beam_vfx_07` | Full | **R4** |
| R5 | Lance charge circle, muzzle burst, ball | `W/attack_forms/lance_view.gd` | `MagicCircles circle_<element>` · `big_flash_*` · `magic_orb_big_*` | Full | **R5** |
| R6 | ~~Bomb blast~~ (moot: the Bomb form was removed, owner 2026-10-31, PLAN BR) | `W/attack_forms/bomb_view.gd`, `W/vfx/vfx_layer.gd:344` | ember/plain `vfx_explosion_01`/`04` · frost `vfx_explosion_07` · bleed `vfx_explosion_02` · others recoloured | Partial | **R6** |
| R7 | Void shot body and collapse (the screen-distortion lens stays) | `W/attack_forms/void_view.gd` | `magic_orb_huge_vfx_03` recoloured violet · `magic_orb_flash_vfx_03` | Partial | **R7** |
| R8 | Rune Explosion dome, rune ring, hit flash | `W/attack_forms/rune_explosion_view.gd` | `fire_forcefield_02` recoloured violet · `MagicCircles circle_arcane` · `vfx_hit_*` | Full | **R8** |
| R9 | Spec forms ZONE, RING, BURST, ORBITER, LOB | `W/attack_forms/attack_form_canvas.gd:448-760` | `basic_area`/`ripple_area` · `pulse_area` · `vfx_impact_*` · `magic_orb_small` · `fire_ball_*` | Full | **R9** |
| R10 | Gun cast spark, volley muzzle spark | `W/hero_cast_fx.gd`, `W/attack_forms/attack_form_view.gd:496` | `short_flash_01–06` (all warm; recoloured for storm, frost, venom) | Full | **R10** |
| R11 | Heavy cast flash (Lance, bursts) | `W/vfx/hero_fx.gd:360,381` | `big_flash_*`, `wide_flash_*` | Full | **R11** |
| R12 | Crit and bounce flash | `attack_form_canvas.gd:251`, `attack_form_view.gd:467` | `vfx_hit_04` (gold star), `vfx_hit_02` (white) | Full | **R12** |
| R13 | Trigger cast sigil, elite arrival sigil, Nemesis cast sigil | `attack_form_view.gd:560`, `W/elite_views.gd:115`, `W/nemesis_views.gd` | `MagicCircles circle_*` | Full | **R13** |
| R14 | Bolt impact, per element | `W/impact_fx.gd:244`, `W/vfx/hero_fx.gd:301` | ember `vfx_hit_05`/`08` · frost `vfx_hit_09`/`10` · storm `vfx_hit_01` recoloured blue · venom `poison_bubble_vfx_01` pop · bleed `poison_bubble_vfx_03` recoloured red | Full | **R14** (shaders into the VfxCore pools, I4) |
| R15 | Heavy-hit impacts and landings | `W/impact_fx.gd` | `vfx_impact_01–06`, frost `vfx_impact_07` | Full | **R15** |
| R16 | Slash impact | `W/impact_fx.gd:335` | `vfx_hit_08` (flat fan, turned to the cut) | Partial | **R16** |
| R17 | Guard, block, deflect, weak-spot sparks (box bursts today) | `W/hit_feel.gd:86-96` | `vfx_hit_02`, `06`, `07` recoloured per tag | Full | **R17** |
| R18 | Fire explosion (VfxLayer) | `W/vfx/vfx_layer.gd:344` | `vfx_explosion_01/03/04`, then `smoke_vfx_*` | Full | **R18** |
| R19 | Frost burst, shatter, final boss shatter | `vfx_layer.gd:599`, `W/final_boss_views.gd` | `vfx_explosion_07`, `ice_area_vfx_*` | Full | **R19** |
| R20 | Venom and bleed liquid burst | `vfx_layer.gd:700` | `poison_bubble_*` + `poison_puddle_*` (red for bleed) | Partial | **R20** |
| R21 | Fire patch, molten floor, Foundry meltdown, Wildfire | `vfx_layer.gd:47`, `W/boss_signature_views.gd` | `fire_area_01–08` (06/07 read as molten); I7 applies to the hero's patches | Full | **R21** |
| R22 | Frost field | `W/vfx/vfx_layer.gd:535` | `ice_area_vfx_01–04` + `ice_mist_vfx_*` | Full | **R22** |
| R23 | Venom field, acid splat | `vfx_layer.gd:639`, boss `acid_splat` | `poison_puddle_vfx_01/02`, `poison_area_vfx_01/02` | Full | **R23** |
| R24 | Toxic Fumes cloud (X2) | `W/element_visuals.gd:239` | `poison_cloud_vfx_01/02`, capped at 4 (overdraw) | Full | **R24** |
| R25 | Bleed pool | `vfx_layer.gd` | `poison_puddle_*` recoloured red | Partial | **R25** |
| R26 | Element rings, Frost Nova, Ember Ward | `vfx_layer.gd:66`, `W/element_visuals.gd` | `rim_area_*`, `pulse_area_*` | Full | **R26** |
| R27 | Boss beams (Hive Gaze, Prism Cross, Conduit, Mender heal beam, rail) | `W/boss_signature_views.gd`, `W/prism_views.gd`, `W/elite_views.gd:139`, `W/horde_visuals.gd:144` | `beam_vfx_01–08`, `blast_vfx_01` | Full | **R27** |
| R28 | Burn status | `W/vfx/vfx_layer.gd:146-170` | `fire_01–11` (small flames, the right size for a body) | Full | **R28** |
| R29 | Poison status | `vfx_layer.gd:196` | `stink_small_vfx_01/02` + `poison_bubble` | Full | **R29** |
| R30 | Frost status (frozen cage stays ours) | `vfx_layer.gd:201` | `ice_mist_vfx_02/03` (crystals at the feet) | Partial | **R30** |
| R31 | Enemy shots: ember_stone, cannon_ember, molten_drop, bomb_cinder, warden_amber_ember | `W/fireball_views.gd:31-344` | `fire_ball_01–07` | Full | **R31** |
| R32 | Enemy shots: spear_ember, crown_bolt, nemesis_bolt | same | `mprojectile_javelin_*`, warm recolours | Full | **R32** |
| R33 | Enemy shots: arc_plasma, gear_spark | same | `mprojectile_basic_vfx_01` | Full | **R33** |
| R34 | Enemy shots: lens_orb, prism_orb, crown_orb, tide_bubble | same | `magic_orb_basic_*`, `magic_orb_big_*`, `magic_orb_basic_vfx_02` | Full | **R34** |
| R35 | Enemy shots: acid_glob, shade_wisp, warden_violet_ember | same | `poison_bubble_vfx_01` · `magic_orb_flare_vfx_03` · `mprojectile_basic_vfx_03` | Full | **R35** |
| R36 | Boss strikes: crater, eruption, crack impact (rocks and spikes stay our models) | `W/boss_strike_fx.gd`, `W/boss_strike_shapes.gd` | `vfx_impact_03/04` + `smoke_big_*` | Partial | **R36** |
| R37 | Boss light burst, light ring, Fallen violet rays | `W/boss_strike_looks.gd`, `W/interphase_views.gd` | `pillar_area_01`, `pulse_area_01`, `pillar_area_03` recoloured violet | Full | **R37** |
| R38 | Boss shock ring, steam ring, dust arc, skid | `W/boss_strike_shapes.gd:391,437,601` | `pulse_area_*` + `smoke_thin_*`; `smoke_vfx_*` | Partial | **R38** |
| R39 | Boss fire lanes | `W/boss_strike_looks.gd` | `fire_02`/`05` in rows | Full | **R39** |
| R40 | Aether Shell barrier | `W/modifier_overlays.gd` | `fire_forcefield_02`/`04` recoloured | Full | **R40** |
| R41 | Bulwark guard orbs | `W/status_visuals.gd:272` | `magic_orb_small_*` | Full | **R41** |
| R42 | Blink flash | `W/blink_flash.gd` | `magic_orb_flash_*` | Full | **R42** |
| R43 | Enemy death pop (box chunks, a node per shard today) | `W/hit_feel.gd:97,146` | `smoke_vfx_02` puff + `vfx_hit_*` (no debris in the pack; the chunks stay) | Partial | **R43** |

## No replacement in the pack
| ID | Game effect | File | Proposal (pick one) |
|---|---|---|---|
| N1 | **Storm / lightning:** bolts, chain lines, forks, shock status, ring arcs, storm bursts, Arc Field | `vfx_layer.gd:171,410-515`, `attack_form_view.gd:290` | **a)** keep ours; **b)** the owner gets a lightning pack (same vendor style); **c)** make one in the pack's style from its shaders |
| N2 | **Bleed liquid:** drips, splatter, floor splat marks | `vfx_layer.gd:186`, `W/vfx/hero_fx.gd:301` | **a)** keep ours; **b)** recolour the poison pack (pools and pops only) and keep our drips |
| N3 | **Melee / blade:** swing trails, crescents, ghost slashes, fissure crack, parry ring, Lunge Cleave | `W/kit_view.gd`, `W/blade_form_view.gd`, `W/skill_visuals.gd` | **a)** keep ours (the Blade's forms wait for v0.10.0 anyway); **b)** a slash pack later |
| N4 | Glaive disc, Wave crest, enemy `nemesis_crescent` | `W/attack_forms/glaive_view.gd`, `wave_view.gd`, `W/fireball_views.gd` | **a)** keep ours (the wave's ground wash could take `ripple_area`) |
| N5 | Void lens (screen distortion), rift tendrils | `W/attack_forms/void_view.gd`, `vfx_layer.gd:788` | **a)** keep ours |
| N6 | **Gameplay telegraphs** (rings, lanes, arcs, sweeps, fills) | `W/telegraph_views.gd` | **a)** keep ours: they must match the hit shape and never drop. The paid Magic Circles pack has a `telegraph` kind if the owner wants a decorative layer later |
| N7 | Solid objects: bomb, javelins, spears, rocks, stone spikes, eggs, shields | various | **a)** keep our models; the pack only adds trails and impacts around them |
| N8 | Water: Tidecaller disc, swell, crossing waves | `W/tide_views.gd`, `W/tide_wave_views.gd` | **a)** keep ours |
| N9 | Lasting floor marks (scorch, frost, splat decals) | `W/vfx/vfx_core.gd` decals | **a)** keep ours (the pack's areas fade out) |
| N10 | Hit flash, hit-stop, damage numbers, dash trail | `W/hit_feel.gd`, `W/damage_numbers.gd`, `W/dash_trail.gd` | **a)** keep ours (not pack material) |

## Pack effects with no attack use
`fire_candle`; most of `smoke_big_*` (8 near-identical greys); `stink_big_*`; `ice_cloud_*` (very faint at game zoom);
`lift_area_*` (fits shrines, altars, pickups); `magic_orb_huge_*` beyond the void shot.

## How it is built (once approved)
- **Steps:**
  - **VX0:** install (I1), warm-up (I2), lights off and the light pool (I3), caps (I5), density (I9), credits (I10).
    One family in game first, the bomb blast (R6, R18), so the owner can judge the look and the cost before the rest.
  - **VX1:** hits and muzzle flashes into the pools (R10–R17).
  - **VX2:** the hero's projectiles and forms (R1–R9).
  - **VX3:** zones, rings and status (R20–R30).
  - **VX4:** enemy shots (R31–R35).
  - **VX5:** bosses, shields and death (R36–R43).
  - **VX6:** lightning in the pack's style (N1).
  - **VX7:** bleed, water, floor marks, the Glaive, Wave and void looks (N2, N4, N5, N8, N9).
  - **VX8:** blade trails and slashes, with the Blade's forms (N3).
- **Each step:**
  - one shot per thing the owner will look at;
  - the hitch probe after the warm-up;
  - a 20-enemy fight frame time on the owner's PC (PF's 144 fps target);
  - the e2e that reaches the effect.
- **Order:** after PF (the owner put performance last in v0.9.5), or as its own version. That's question I0 below.

| ID | Question | Proposal |
|---|---|---|
| I0 | Where does this land? | **I0:** v0.9.5, after PF5, steps VX0–VX5. Or move it to v0.10.0. **Answered: v0.10.0** |

## Gaps built in the pack's style (owner, 2026-10-31)
The owner asked: "the ones that dont have could be replaced with something you make based on what the new effects? like
take that style and how they are built and build something new with that looks".

It works: the Binbun effects are built from parts we can reuse rather than painted art:
- a few shaders (`transparent.gdshader`, the dissolve, `alpha.gdshaderinc`);
- tileable noise and gradient textures (`shared/texture/noise/*`, `gradient/*`);
- GPUParticles3D with those materials;
- simple meshes (quads, rings, cylinders, half-spheres) moved by an AnimationPlayer.

A new effect is a new arrangement of those parts.

**Built new, in the pack's style:**

| Gap | How it's made |
|---|---|
| N1 lightning | Bolts, chains and forks: the laser shader on a jagged strip mesh rebuilt each strike, plus the `vfx_hit` spark. Shock status: small forks round the body |
| N2 bleed | Drips: `poison_bubble` particles, red and falling. Splatter: the `poison_puddle` shader as a short-lived mark |
| N3 blade trails and slashes | A ribbon mesh along the swing with the beam's scrolling noise. Lands with the Blade's forms, also v0.10.0 |
| N4 Glaive disc, Wave crest, `nemesis_crescent` | `pulse_area`/`rim_area` materials on our shapes |
| N5 void | The pack's rim and orb look round our body; the screen distortion stays ours (the pack has no distortion effect) |
| N8 water | `ripple_area` and `pulse_area` shaders recoloured, plus `poison_bubble` spray in blue |
| N9 floor marks | `fire_area`/`poison_puddle`/`ice_area` materials frozen at their last frame and faded slowly |

**Stay ours** (the pack's style doesn't fit these):
- N6 telegraphs: they must match the hit shape exactly and never drop. A later restyle of their fill with the ripple shader is possible.
- N7 solid models.
- N10 hit-stop, damage numbers, the dash trail.

## Decisions (owner, date)
| ID | Answer | Built in |
|---|---|---|
| I0 | **v0.10.0** (owner, 2026-10-31: "This is v0.10.0") | |
| I1–I6, I8, I9 | As proposed (owner, 2026-10-31: "all as proposed works") | |
| R1–R43 | As proposed (owner, 2026-10-31) | |
| I7 | The player's fire patches shift cooler through `ground_safe`; enemy and boss zones keep the warm hues (owner, 2026-10-31: "fire patches shift cooler") | |
| I10 | The owner holds purchased licences for the Binbun packs (2026-10-31: "I do have a licences I purchased it"); the Magic Circles credits line goes in | |
| N1–N10 | Built in the pack's style where it works (owner, 2026-10-31); the split is in "Gaps built in the pack's style" above | |
