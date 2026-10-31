# VX2 evidence: the hero's shots and forms use the VFX pack

Branch `v0100-vx2` (from `claude/v0100-vfx` 2aeb4b5c). Machine: the owner's PC (Windows). Build SHA: see the commit.

## Rows done
R1 Orbs in flight, R2 Seekers' javelins, R3 Wisps (orbs and flare), R4 Laser, R5 Lance (MagicArea charge circle, muzzle
burst, big orb in flight), R7 Void (body and collapse), R8 Rune Explosion (dome, MagicArea floor ring, hit flash), R9
(orbiters, bomb body, rings and zones with no element), R12 crit and bounce flashes, R13 trigger sigil.

## Id to scene (data/vfx/pack_fx_vx2.tres, 42 rows)
- `vx2_bolt_<e>`: ember fire_ball_01, frost ice_ball_vfx_01, venom m_projectile_basic_vfx_05, storm (and plain)
  mprojectile_basic_vfx_02, bleed mprojectile_basic_vfx_04.
- `vx2_jav_<e>`, `vx2_small_<e>`, `vx2_big_<e>`, `vx2_flare_<e>`: scene 04 ember and bleed, 01 frost (pale), 05 venom,
  02 storm and plain (javelin 05 and the basic 05 are named `m_projectile_...` in the pack).
- `vx2_laser_<e>`: storm 02, frost 04, ember 06, bleed 01, void 05 (beam_vfx laser_vfx_*), venom beam/beam_vfx_07.
- `vx2_muzzle_big` big_flash_02; `vx2_void_body` magic_orb_huge_03; `vx2_void_collapse` magic_orb_flash_03;
  `vx2_rune_dome` fire_forcefield_02; `vx2_hit_rune`, `vx2_hit_bounce` vfx_hit_02; `vx2_hit_crit` vfx_hit_04;
  `vx2_zone_basic` basic_area_02; `vx2_zone_ripple` ripple_area_02 (row only, unused); `vx2_ring_pulse` pulse_area_02;
  `vx2_lob_body` fire_ball_01.
Old paths kept as fallbacks behind `PACK_BOLTS`, `PACK_FORMS`/`FormPack.ENABLED`, `PACK_LASER`, `PACK_DARTS`,
`PACK_WISPS`, `PACK_LANCE`, `PACK_VOID`, `PACK_RUNES`.

## Findings for the lead
1. PackFx releases a scene when its `main` animation ends (about 1 s), also a life-0 (held) one. Held bolts would vanish.
   Workaround in `PackHold.loop`: the scene's `main` Animation is set to LOOP_LINEAR once. Better fixed in PackFx.
2. Fire pack scenes (fire_ball_01, forcefield) have no `primary_color`; the dome is recoloured by setting the shared
   forcefield material (`RuneExplosionView._violet`, only the dome uses it). Their GPU particles are one-shot in PackFx.
3. Scenes share ShaderMaterials per scene (lead's note): colours of two live instances of one id can overwrite each other.
4. `PackHold` cannot tell that PackFx recycled a node to another caller (only a hidden one); wants `PackFx.is_live`.
5. Ring and zone: only forms with no effects-layer element take the pack (element ones still go through
   `VfxLayer.ring/field`, VX3's). The Ring card in the data always carries lightning, so the shots do not show the
   pack ring; its code path is covered by a unit test only. The orbit-blade, bomb-round and ring tiles in sheet 3 do
   not visibly differ (their forms did not appear in that scene): NOT verified in shots.
6. Wiring touched `world_view_root.gd` (`_hand_pack_to_hero_views`). `test_pack_fx.gd` uses `warm_ids().size()`.
7. Not done: R9 ZONE with `ripple_area` (row exists, no caller), Lance ball colour mapping uses the element's `big` scene.

## Shots (Effects density High, game camera, old left, new right of each pair; swatch = element)
`build/shots/v0.10.0/vx2/1_orbs_seekers.png`, `2_seekers_wisps_laser.png`, `3_lance_void_rune_forms.png`
Command (off screen, once): `godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy
--resolution 1280x720 -s scripts/shots/vx2_forms.gd`. Scales were tuned by eye from these (constants in PackLooks,
SeekersView, WispsView, LaserView, VoidView, HeroPulseViews). Ember bolts show square flame particles (the fire ball's).

## Tests (all `--headless --fixed-fps 60`, Godot 4.7.2)
- `tests/unit/presentation/test_vx2_forms.gd`: 15 tests, 15 pass (colours, rows, hold follows/releases/loops, full
  family fallback, bolts, seekers, laser, void, rune, wisps, flashes, ground_safe, sigil, orbiter).
- 25 presentation test files (attack forms, lance, laser, rune, seekers, void, wisps, pulses, vfx, pack, bomb, glaive,
  scatter, vx2): `Scripts 25, Tests 220, Passing 218`; the 2 failures were `test_pack_fx.gd`'s hard-coded 4 ids (fixed).
- e2e (attack_order, attacks, glaive_seekers, lance_halo, laser, void, wave_wisps, wisp_combos, rune_combos,
  seeker_combos): `Tests 14, Passing 14`.
- tests/content, tests/arch, tests/golden: `Tests 172, Passing 172`.
- Lint: gdformat and gdlint clean on every touched file.
- Not run: the whole `tests/unit/presentation` folder (a runaway `_hash` script error loop in
  `test_procedural_wall.gd`'s neighbourhood filled the log; not my files, not investigated), no timing.
