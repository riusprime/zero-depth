# VX5: boss strikes, beams, shields and sigils use the VFX pack

Branch `v0100-vx5` (from `claude/v0100-vfx` 2aeb4b5c). Presentation only: no sim, golden or content-schema change.
Build SHA: the commit that carries this file (`git log -1 --format=%h` on `v0100-vx5`).

## Rows done

| Row | What | Where | Pack id (`data/vfx/pack_fx_vx5.tres`) -> scene |
|---|---|---|---|
| R27 beams | Hive Gaze, Prism Cross, Mender heal beam: held while the beam shows; Conduit: one beam for `BEAM_S` | `boss_signature_views.gd`, `prism_views.gd`, `horde_visuals.gd`, `elite_views.gd` | `bx_beam_01`..`08` -> `beam_vfx/effects/beam/beam_vfx_01..08` (picked by `PackHold.beam_id`: the scene whose hue is nearest the beam's colour; near-white = 08) |
| R27 rail | The boss rail's blast along each lane for its first 10 ticks | `boss_strike_fx.gd` | `bx_rail` -> `beam_vfx/effects/blast/blast_vfx_01` |
| R36 | Crater / eruption / crack impact: burst + short dust per disc | `boss_strike_fx.gd` | `bx_impact_a` -> `vfx_impact_03` (crater, eruption), `bx_impact_b` -> `vfx_impact_04` (crack impact); `bx_smoke_big` -> `smoke_big_vfx_01` (1.1 s). Rocks, debris, cracks, lights untouched |
| R37 | Light burst, light ring, the Fallen's eruptions | `boss_strike_fx.gd`, `interphase_views.gd` | `bx_pillar_light` -> `pillar_area_vfx_01`, `bx_pulse_light` -> `pulse_area_vfx_01`, `bx_pillar_fallen` -> `pillar_area_vfx_03` (violet) |
| R38 | Shock ring, steam ring, dust arc, skid | `boss_strike_fx.gd` | `bx_pulse_shock` -> `pulse_area_vfx_02`, `bx_pulse_steam` -> `pulse_area_vfx_06` (+ `bx_smoke_thin` -> `smoke_thin_vfx_01`), `bx_smoke_dust` -> `smoke_vfx_05` |
| R39 | Fire lanes: a row of flames about every 1 m, at most 8 a lane | `boss_strike_fx.gd` | `bx_fire_lane_a` -> `fire_02`, `bx_fire_lane_b` -> `fire_05` (alternating) |
| R21 | Foundry molten floor (blobs along each piece) and meltdown (10 round the melting edge, off the bridge) | `boss_signature_views.gd` | `bx_lava_a` -> `fire_area_06`, `bx_lava_b` -> `fire_area_07` |
| R40 | Aether Shell barrier, held while the shell is up, in the shell's green | `modifier_overlays.gd` | `bx_shell` -> `fire_forcefield_02` |
| R42 | Blink flash (own light kept) | `blink_flash.gd` | `bx_flash` -> `magic_orb_flash_vfx_02` |
| R13 | Elite arrival sigil (shadow, r 1.6 m); Nemesis cast sigil (blood, r 1.1 m) | `elite_views.gd`, `nemesis_views.gd` | `MagicArea` (`addons/magic_circles/magic_area.gd`, kind circle), no pack id; `light = false` (the old sigils had none) |
| R19 | Final boss shatter in `GLOW` | `final_boss_views.gd` | `bx_shatter` -> `vfx_explosion_07` |

New file `src/presentation/world_view/pack_hold.gd` (`PackHold`): the keyed owner the views use (one-shot per key, held
while asked each frame, released the frame it stops, the family-full answer remembered per key so a strike never swaps
look half way). Every replaced old path sits behind a const: `PACK_STRIKES` (`boss_strike_fx.gd`), `PACK_BEAMS`
(`prism_views.gd`, `elite_views.gd`, `horde_visuals.gd`), `PACK_GAZE`, `PACK_LAVA` (`boss_signature_views.gd`),
`PACK_SHELL`, `PACK_FLASH`, `PACK_SIGILS` (`elite_views.gd`), `PACK_SIGIL` (`nemesis_views.gd`), `PACK_PILLARS`,
`PACK_SHATTER`.

Fallback when a family is full: the old look for that instance (beams: the two cylinders / the box / the bar; strikes:
the dust sprites or flame sprites; shell: the sphere; blink: the column, pool and sparks; shatter: the crystal
sprites). The pack effects added on top of a strike (the burst, the pillar, the pulse) are simply skipped.

## Shots

`scripts/shots/vx5_bosses.gd` (run without `--headless`, on the RTX 3060 of the owner's PC). Old left, new right; a
green ring or box marks the strike's hit area. Written to `build/shots/v0.10.0/vx5/` (not tracked):

- `strikes.png`: crater, light burst, light ring, shock ring, steam ring, dust arc.
- `beams.png`: fire lanes, rail, Prism Cross, Hive Gaze, Mender, Conduit.
- `shields.png`: Aether Shell, Blink, final boss shatter, molten floor, the Fallen's pillar.
- `sigils.png`: elite arrival, Nemesis cast.

```
godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx5_bosses.gd
vx5_bosses: res://build/shots/v0.10.0/vx5/strikes.png
vx5_bosses: res://build/shots/v0.10.0/vx5/beams.png
vx5_bosses: res://build/shots/v0.10.0/vx5/shields.png
vx5_bosses: res://build/shots/v0.10.0/vx5/sigils.png
```

What the shots showed (agent's reading, not an owner judgement): the pulses sit inside the strike's hit ring; the pack
beams were too thick at first and were narrowed (`BEAM_FACTOR`); the rail's blast now fits its lane; the pack fire
lane is a row of flame rings (fire_02/05 read as ring flames from the iso camera); the molten floor's flames are subtle
over the lava texture; the Aether Shell is the pack's forcefield in the shell's green. Beam colour matching is by hue,
so the Prism's pink-red and the Gaze's pink pick `beam_vfx_05` (pink-white with violet start); the owner decides
whether that is the right red.

## Tests

Lint: `gdformat` and `gdlint` clean on every touched `.gd`.

All runs `--headless --fixed-fps 60` (APPDATA under `build/`), after the final code:

- New `tests/unit/presentation/test_vx5_bosses.gd` + `test_vx5_bosses_views.gd` (26 tests), run with 15 existing
  view/pack test files: `Scripts 17, Tests 146, Passing 146, Asserts 24295`.
- `tests/e2e` (boss_strikes, boss_signatures, boss_signatures_2, bosses_2, final_boss, elites, prism, nemesis,
  horde_enemies, modifiers_mx4): `Tests 20, Passing 19, Failing 1`: the Gaze test read `GazeBeam.visible`. The test now
  also accepts the pack beam (`_gaze_packed`); rerun of that file: `Tests 4, Passing 4`.
- `tests/content`: `Tests 166, Passing 166`. `tests/arch`: `Tests 4, Passing 4`. `tests/golden`: `Tests 2, Passing 2`.
- `test_pack_fx.gd`: two hard-coded "4 ids" tests fail with VX5's table (VX1/VX3 changed them to
  `warm_ids().size()`; not repeated here).
- The shot script ran windowed (four runs while tuning) before the off-screen rule arrived; not rerun since.

## Not done / notes

- **Fallen "violet rays":** read as the Fallen's ground eruptions (the pillar spawns where an eruption strikes).
  Its sweeping beams (`_draw_beams`) are not in R27's list and keep the old cylinders. Say if the rays should be the
  beams instead.
- **Boss `beam` strike (lanes)** is not in the brief's list (only the rail): old look kept.
- **Javelins, steel arc, spears** keep their old dust/sparks (not in R36-R38).
- **`smoke_big`/`smoke_thin`/`smoke_vfx_05` are family `cloud` (cap 4):** busy fights fall back to the old dust sprites
  often. Their family is the lead's call (a table edit).
- **`tests/unit/presentation/test_pack_fx.gd`** (lead's): `test_warm_all_spawns_every_id_once_and_leaves_none_live` and
  `test_warm_one_id_at_a_time_for_a_queue` hardcode "4 ids" and fail once any other table file joins `pack_fx.tres`
  (VX5's 26 ids now do). Not edited here; every VX step will hit it, so it needs one fix (compare with the table's id
  count).
- **Reads `PackFx._live`** (a private array) in `PackHold._live` to know whether a held node is still the instance
  PackFx started (it can be reused when a family is full). A public `is_live(node)` on PackFx would replace it.
- **Held effects:** `PackHold.hold` sets the particles of a held node to non-one-shot, since PackFx plays an animation-
  less scene once; a fire lane or the molten flames burn until released.
- **Shared sub-resources:** the beam, fire and forcefield scenes share their meshes and materials between instances, so
  beams are not recoloured or resized per instance (the scene is chosen by colour; width is the node's scale); the
  forcefield's colours are set on its material (`PackHold.tint_field`: fire effects have no colour exports).
- Not measured: no frame-time or hitch measurement (the lead measures).
