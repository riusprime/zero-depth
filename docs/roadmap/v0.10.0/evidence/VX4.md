# VX4: enemy shots use the VFX pack (R31-R35)

Branch `v0100-vx4` (from `claude/v0100-vfx` 2aeb4b5c). Machine: owner PC (Windows). Presentation only; goldens unchanged.

## Looks done (17 of 18; id = `shot_<look>`, table `data/vfx/pack_fx_vx4.tres`, family `enemy_shot`)
| Look | Scene (under `assets/BinbunVFX/`) | Table scale |
|---|---|---|
| ember_stone | fire_effects/effects/Fire/fire_ball_01 | 0.35 |
| cannon_ember | .../fire_ball_03 | 0.4 |
| molten_drop | .../fire_ball_05 | 0.35 |
| bomb_cinder | .../fire_ball_06 | 0.35 |
| warden_amber_ember | .../fire_ball_04 | 0.35 |
| spear_ember, nemesis_bolt | magic_projectiles/effects/mprojectile_javelin/mprojectile_javelin_vfx_04 | 0.5 |
| crown_bolt | .../mprojectile_javelin_vfx_01 | 0.5 |
| arc_plasma | mprojectile_basic/mprojectile_basic_vfx_01 | 0.5 |
| gear_spark | same scene | 0.35 |
| lens_orb | magic_orbs/effects/magic_orb_basic/magic_orb_basic_vfx_01 | 0.4 |
| prism_orb | magic_orb_big/magic_orb_big_vfx_06 (Flare hidden) | 0.24 |
| crown_orb | magic_orb_big/magic_orb_big_vfx_01 (Flare hidden) | 0.24 |
| tide_bubble | magic_orb_basic/magic_orb_basic_vfx_02 | 0.4 |
| acid_glob | mprojectile_basic/m_projectile_basic_vfx_05 | 0.5 |
| shade_wisp | magic_orb_flare/magic_orb_flare_vfx_03 | 0.28 |
| warden_violet_ember | mprojectile_basic/mprojectile_basic_vfx_03 | 0.5 |

Spawn scale = table scale x (shot radius / 0.18). Colours passed: primary = look core, secondary = look trail, tertiary = trail darkened. Lobbed and raining drops use the same effects (tokens `lob:` / `rain:`).

## Looks not done
- nemesis_crescent: stays as today (gap N4).
- Fire balls (5 looks) have no colour exports, so they keep the scene's own colours (bomb_cinder is not violet).
- Big orbs: the star-burst "Flare" ignores node scale (about 230 px against a 30 px gem), so it is hidden for prism_orb/crown_orb; they lose the crystal trail.
- shade_wisp draws a bright blue ring round a dark core (the scene's Glow), brighter than the old dim wisp.

## Behaviour notes
- `PACK_SHOTS := true` (const) in `fireball_views.gd`; false restores the old look everywhere. Full family: that shot draws the old core and trail. The dark edge MultiMesh is always drawn.
- Held scenes end by themselves in PackFx (animation_finished; fire balls get one_shot particles): `_keep_playing` loops the "main" animation (shared Animation resource) and clears one_shot.
- Flame particles don't follow node scale in world space: the node's own copy of the process material is scaled and the particle lifetime shortened for small shots.
- `ball_count(key)` now counts shots drawn (pack or MultiMesh); new `core_count` (MultiMesh cores) and `edge_count`.
- Shared ShaderMaterials: spear_ember/nemesis_bolt share a scene, as do arc_plasma/gear_spark, so they recolour each other until the lead's per-instance material fix lands. My material-copy workaround was removed on the lead's word; the shots below were taken with it and need one re-run after the fix.
- `test_pack_fx.gd` hard-codes 4 ids (3 assertions fail with the joined table); not edited here (VX1/VX3 changed it to `warm_ids().size()`).

## Shots (off-screen window, once)
`build/shots/v0.10.0/vx4/sheet_1.png`, `sheet_2.png` (old on top, pack below).
```
godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx4_shots.gd
```

## Tests (all `--headless --fixed-fps 60`, GUT `-gtest=`)
- `tests/unit/presentation/test_vx4_shots.gd`: 8 tests (rows exist, each look spawns its id and keeps its edge, follows/faces/released, held outlives the animation, full-family fallback, no pack, crescent, colours).
- 11 existing presentation files (enemy_fireball_views, vx_looks, attack_visuals, boss_fight_views 1-3, fx_textures, gun_pulse, nemesis_views, prism_views) + e2e enemy_fireballs and boss_dodge 1-3: 107 passing / 0 failing (last combined run, before removing the material workaround; the 4 relevant files re-run after: 18/18).
- `tests/content`, `tests/arch`, `tests/golden`: 172 / 172 passing (34 scripts).
- `test_pack_fx.gd`: 3 failing assertions from the 4-id hard-code (see above).
- Lint: gdformat + gdlint clean on the touched files.
