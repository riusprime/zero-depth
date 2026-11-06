# v0.9.5 Step SQ: no lit square around additive effects

Base build: d33bc82a (origin/main) plus this step's commit on branch `v095-sq`. Machine: owner PC (RTX 3060, Vulkan Forward+).

## Changes
- `fog_disabled` added to the render_mode of every additive spatial shader in `src/presentation` that lacked it (attack_forms bomb/glaive/lance/laser/scatter/seekers, boss_signature_shaders, fx_textures FLARE/SIGIL, hero_pulse_views, judge_views, star_void, twin_views), and to the shared `%s`-blend shaders in vfx_core.gd, boss_strike_meshes.gd (GLOW) and fireball_shaders.gd (trail); these also serve blend_mix, where it is harmless.
- laser_view.gd IMPACT_SHADER: `discard` at r >= 1, star term clamped with max(0, 1 - r), output times `1 - smoothstep(0.8, 1.0, r)`. Same edge mask on bomb_view.gd ring and spark, hub_props.gd halo, seekers_view.gd mote.
- `FxTextures.soft_dot()` (64 px radial, cached); stage_atmosphere.gd uses it (its own copy removed); set as albedo_texture (alpha, linear filter) on the particle quads in portal_gate.gd (rim motes), portal_transit_view.gd, altar_stage.gd (buildup motes), floor_receiver.gd. lantern_shade_avatar.gd's gradient is a different profile, so it was left alone.
- 34 `assets/textures/vfx/*.png.import` changed from compress/mode=2 to mode=0 (lossless), mipmaps kept. 1024x1024: acid_splat, beam, beam_impact, bubbles, cast_sigils, crystal_shatter, debris_chunks, dust_ring, explosion_burst, flame_shapes, frost_burst, frost_mark, ground_cracks, lightning_bolts, liquid_splash, rock_burst, scorch_mark, skid_marks, smoke_puffs, spark_shapes, splatter_mark, steam_puffs, trails, void_rift, void_tendrils. 512x512: aim_lines, electric_noise, fire_noise, lava_flow, light_ring, orb_cores, orb_cores_2, orb_cores_final, void_noise. (fx_ember_sparks and fx_star_motes were already lossless.)

## Commands and results
- `gdformat --check` and `gdlint src/presentation`: clean.
- `APPDATA=<own dir> Godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<test_portal_gate, test_portal_oval, test_portal_transit_view, test_laser_view, test_fx_textures, test_vfx_budget, test_vfx_layer, test_stage_atmosphere, test_altar_stage, test_vfx_manifest, test_assets, test_e2e_portal, test_e2e_laser> -gexit`: Tests 78, Passing 78, Asserts 1987.
- `... -gdir=res://tests/arch -ginclude_subdirs -gexit`: Tests 4, Passing 4, Asserts 16366.
- No test assertion changed.

## Shots (frozen_shore, 2026-10-25, RTX 3060)
- Laser tip: `build/shots/v0.9.5/sq/sq_frozen_laser_frost.jpg` (a copy of scripts/shots/laser_bomb.gd with the biome set to frozen_shore and the plan cut to the frost laser). No square border visible at the tip or muzzle.
- Portal: `build/shots/v0.9.5/sq/sq_frozen_portal_facing_camera_open.png` (a copy of scripts/shots/portal.gd, frozen_shore palette, open gate, frame 90). No square border visible.
- scripts/shots/portal_oval.gd (the real-game flow) gave up in step boot on this PC, so the isolated gate stage was used. No before/after pair was taken.
- OWNER ONLY: whether the square is gone on his hardware in every biome.
