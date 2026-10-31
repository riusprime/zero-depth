# v0.10.0 Step VX1: hits, impacts and flashes use the VFX pack

Machine: the owner's PC (Windows 11, Godot 4.7.2 console build, GPU shots). Branch `v0100-vx1`, cut from
`claude/v0100-vfx` (`2aeb4b5c`) plus this step's tree. No frame-time measurement (other agents were running).
**Owner to judge (OWNER ONLY):** whether the pack's hits look right and are the right size.

## 1. Rows done

All drawing goes through PackFx scenes (`HitPack`, new, `src/presentation/world_view/vfx/hit_pack.gd`). The old paths
stay behind `PACK_HITS` (ImpactFx, HeroFx), `PACK_MUZZLE`, `PACK_FLASH` (HeroFx), `PACK_CAST` (HeroCastFx),
`PACK_SPARKS` (HitFeel). A full family (`has_room`) draws the old look for that instance.

| Row | Where | Id -> scene (under `assets/BinbunVFX/`) |
|---|---|---|
| R14 bolt impact | `ImpactFx._draw_one` (bolt), `HeroFx.impact` (Lance, Laser) | `vx1_hit_ember` `impact_explosions/.../hit/vfx_hit_05`; `vx1_hit_frost` `vfx_hit_09`; `vx1_hit_storm` `vfx_hit_01`; `vx1_hit_venom` `poison_effects/.../poison_bubble_vfx_01`; `vx1_hit_bleed` `poison_bubble_vfx_03`; `vx1_hit_plain` `vfx_hit_02`. All recoloured (core, hot, deep of the element; none: energy) |
| R15 heavy impact | same call, strength >= 1.2 (a crit 1.25; a finisher 1.43) | `vx1_impact_ember` `.../impact/vfx_impact_01` (ember, plain); `vx1_impact_frost` `vfx_impact_07`; `vx1_impact_other` `vfx_impact_05` (rest) |
| R16 slash | `ImpactFx._draw_slash` | `vx1_slash` `vfx_hit_08`, yaw to the cut's tangent; a finisher adds the heavy impact |
| R17 sparks | `HitFeel._spark` (replaces `_burst` in the HIT cases and the finisher) | `vx1_guard` `vfx_hit_02` (block, guard, armour, finisher, tinted with today's colour); `vx1_weak` `vfx_hit_06` (weak spot, exposed boss point); `vx1_deflect` `vfx_hit_07` |
| R10 muzzle | `HeroFx.muzzle` (volley), `HeroCastFx._pack_spark` (every shot, at the hand) | `vx1_muzzle_01..06` `muzzle_flash/.../short_flash/short_flash_01..06`: ember 01, storm 02, frost 03, venom 04, bleed 06, none 05 |
| R11 heavy flash | `HeroFx.flash` with size >= 1.0 (the light call is kept) | `vx1_flash_big` `big_flash/big_flash_02` |
| R43 death pop | `HitFeel._death_pack`, added to the lit chunks | `vx1_death_smoke` `smoke_effects/.../smoke_vfx_02` (scale 0.18); `vx1_death_pop` `vfx_hit_02` tinted `enemy_body` |

Table: `data/vfx/pack_fx_vx1.tres` (22 rows, `id = pack_fx_vx1`). Families: hit, impact (heavy impacts and the big flash).
Scales are per scene (shot-tuned): `HIT_SCALE` 0.35, `IMPACT_SCALE` 0.3, `SLASH_SCALE` 0.5, `MUZZLE_SCALE` 0.8,
`FLASH_PER_M` 0.8, plus `SCENE_K` (Storm hit 0.4, Ember impact 0.6, Frost impact 0.5) and HitFeel's `SCALE_*`.

Mechanism: the old draws are per-frame functions of `u`; `HitPack.state` remembers (layer, tag, seed) so a scene is
spawned once, and a seed that comes again (`u` went back) or a gap over 30 ticks is a new instance.
Kept from the old look when packed: the bolt's sparks, spray and chunks; the slash's sparks and chips. Replaced: the
flash, the element extra and the puff (bolt); the cut and its flash (slash); the box bursts (R17).

Hand-over edit outside the listed files (minimal): `world_view_root.gd` sets `cast_fx.pack_fx` and `hit_feel.pack_fx`.

## 2. Shots (`scripts/shots/vx1_hits.gd`, old on top, pack below)

Run: `godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx1_hits.gd`
Written to `build/shots/v0.10.0/vx1/`: `1_bolt_hits.png`, `2_heavy_slash.png`, `3_sparks.png`, `4_casts.png`.
Seen: the pack's hits, impacts and sparks are larger and brighter than the old sprites (the heavy Ember and Frost
impacts read as big spheres); the muzzle flashes are small leaf shapes; a hard horizontal cut shows across effects at
one screen height in both the old and new renders (a viewport artifact, not this step's).

## 3. Tests (raw pass lines)

- `test_vx1_hits.gd`: `17/17 passed.` (new)
- Selected existing (hit feel/impact, blade feel, four slash, gun pulse, vx looks, lance, laser, void, glaive, rune
  explosion, wave/wisps, wand cast, attack forms, damage flash, vfx layer, pack explosion, `test_e2e_blade_feel`):
  `Tests 195, Passing 193, Failing 2` -> both failures were `test_pack_fx.gd` hard-coding the VX0 table's 4 ids
  (PackFx joins every table file). Fixed to read `warm_ids().size()`: `test_pack_fx.gd` `14/14`, with
  `test_vx1_hits.gd` `Tests 31, Passing 31, Asserts 195`.
- `tests/content` + `tests/arch` + `tests/golden`: `Scripts 34, Tests 172, Passing Tests 172, Asserts 31720`.
- Lint: `gdformat` + `gdlint` on every touched .gd: `Success: no problems found`.
- Not run: the full `tests/unit/presentation` folder (a run was started and stopped: the machine was shared and it
  was minutes per file); other e2e beyond blade feel.

## 4. Not done / notes

- R12 (crit and bounce flashes) and R13 (sigils) are not in the brief's VX1 rows; not touched.
- `wide_flash_03` unused: no fan-shaped flash found among the `HeroFx.flash` callers (Lance 1.2, Void 1.1 use the big flash).
- Flashes smaller than 1 m (Glaive, Rune Explosion, Wisps) and OTHER-kind hits (areas, chains: strength 0.45) keep the old look.
- The cast spark at the hand uses the energy colours (neutral `short_flash_05`), not the gun's element: HeroCastFx has no
  element source. The volley muzzle (`HeroFx.muzzle`) picks the element from its colour.
- Impacts and slashes are coloured by the first element only (secondary = that element's hot).
- `test_pack_fx.gd` was edited; other VX steps adding rows will hit the same lines (merge by keeping `warm_ids().size()`).
