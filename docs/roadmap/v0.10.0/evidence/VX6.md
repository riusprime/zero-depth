# VX6: lightning in the VFX pack's style (N1)

Branch `v0100-vx6` (from `claude/v0100-vfx` ef2be210). Presentation only: no sim, golden or content-schema change.
Build SHA: the commit that carries this file (`git log -1 --format=%h` on `v0100-vx6`).

## What was built

Storm had no pack effect, so it is built from the pack's parts (our own scenes under `assets/vfx_zd/lightning/`):

- `bolt_ribbon.gdshader`: the beam shaders' look (`beam_core`: hot centre and pulse; `beam_outer`: scrolling noise
  shell, with the pack's `shared/texture/noise/pingpong/pingpong_01`). `bolt_core.tres` and `bolt_outer.tres` are its
  two materials; the vendor files are not edited.
- `bolt.gd` (`ZdBolt`) and `bolt.tscn`: a jagged ribbon from `set_ends(a, b, seed, width)`: 6-10 segments, sideways
  jitter up to 12 % of the length, 0-2 thin forks chosen by seed, all a hash of the seed and the flicker count (no
  randomness). It re-jitters every 0.06 s, faces the camera, and either fades out over `fade_time` (a strike, 0.2 s) or
  is held at the caller's `strength`. Colours come in through PackFx (`primary_color`, `secondary_color`,
  `tertiary_color`) as for every pack scene.
- `data/vfx/pack_fx_vx6.tres`: `vx6_bolt` (family bolt, cap 48), `vx6_field` (`ripple_area_02`), `vx6_ring`
  (`rim_area_02`) and `vx6_burst` (`pulse_area_02`), all family area. Storm colours: `ElementLooks.hot/core/deep(&"storm")`.
- `src/presentation/world_view/vfx/storm_pack.gd` (`StormPack`): the layer's storm looks moved out of `vfx_layer.gd`
  (the layer is now 875 lines; it was 996), each with the pack version first and the old sprite look kept for the instance
  whose family has no room, behind `StormPack.PACK_STORM := true`.

## Where it draws

| Look | Source | Pack version | Past the cap |
|---|---|---|---|
| Strikes, chain jumps, beams, ring arcs (`attack_form_view.gd` RING_ARCS goes through `VfxLayer.line`), `status_visuals.gd` discharge and strike | `VfxLayer.line(&"storm")` | a held `vx6_bolt` per line (keyed by seed and by how many lines that seed drew first), plus `vx1_hit_storm` at the end once | old sprite bolt, with its light |
| Storm field | `VfxLayer.field` | held `vx6_field` and 2-4 short bolts striking inside it every 24 ticks | old arcing sprites |
| Storm ring | `VfxLayer.ring` | held `vx6_ring` and 3-8 bolts along the rim | old sprite ring |
| Storm blast (and the strike payoff's blast) | `VfxLayer.burst` | `vx6_burst` once and 3-5 radial bolts | six sprite bolts |
| Shock on an enemy | `VfxLayer.status` | 2 short forks (0.5 m, from the body's middle outwards), a new strike every 18 ticks | old arc over the body |
| Arc Field and Storm Bombs bolts | `element_visuals.gd` `_bolt` | a one-shot bolt, 0.2 s, with the storm spark | box bolts |
| Arc Field's shock field | `element_visuals.gd` `_sync_fires` | held `vx6_field` and a bolt every 0.4 s | the pale disc |

The layer's lights are unchanged. Edits to `vfx_layer.gd` are the delegating calls, one new var (`_storm`) and one line
each in `begin()` and `finish()`.

## Tests

Lint: `gdformat` and `gdlint` clean on every touched `.gd`. All runs `--headless`, on the owner's PC.

| Run | Result |
|---|---|
| `tests/unit/presentation/test_vx6_lightning.gd` (new) | 16/16 passed (562 asserts) |
| `test_vfx_layer`, `test_vfx_pressure`, `test_vfx_budget`, `test_status_visuals`, `test_vx3_zones`, `test_attack_forms`, `test_attack_forms_live`, `test_vx6_lightning`, `tests/content/test_pack_fx_scenes` (final run) | 117/117 passed |
| `test_vfx_interpolation`, `test_glaive_view`, `test_seekers_view` | passed in the first run (108/109 then; the one failure is fixed below) |
| `tests/content`, `tests/arch`, `tests/golden` | 171/172: the failure was `test_pack_fx_scenes` (below); it passes now |
| `tests/e2e/test_e2e_abilities_ab.gd` | 2/2 passed after the fix below |
| `test_e2e_attack_order`, `test_e2e_wand_build` | passed |
| `test_e2e_element_pairs` | FAILED, not from this step: it loads `res://tests/e2e/test_e2e_bomb.gd`, which is not tracked in the repo (line 59). Not re-run after |
| `test_e2e_old_save` | not seen to finish in the run (not re-run) |

Existing tests changed because their rule moved:
- `test_vx3_zones.gd` `test_bleed_and_shock_stay_as_they_were` is now `test_bleed_stays_as_it_was` (shock is the pack's).
- `test_pack_fx_scenes.gd` `test_the_pack_table_is_valid` accepts scenes under `res://assets/vfx_zd/` as well as the vendor
  root. VX7 and VX8 will need the same change (a merge point).
- `test_e2e_abilities_ab.gd` counts the chain as drawn when PackFx has a live bolt (the box bolts no longer draw).

## Shots

`scripts/shots/vx6_lightning.gd`, off screen, on the RTX 3060 (`build/shots/v0.10.0/vx6/`, not tracked): `strikes.png`,
`zones.png`, `shock.png`; the sprite bolts on the left, the pack's on the right.

What the shots showed (agent's reading, not an owner judgement):
- `zones.png` and `shock.png` are framed alike on both sides. The new field, ring and blast are a faint ripple or rim with
  jagged white-blue bolts over it; the sprite version is denser and thinner. The shock forks are small (about 0.5 m) and
  read as short white squiggles at the body's edge.
- `strikes.png`: the left (old) tile is mis-framed (the first build's camera was not at the arena when grabbed), so it shows
  no bolts; compare with the old look in `zones.png`. The new tile shows the strike and chain bolts with large white
  starbursts at their ends. Those did not change when `StormPack.SPARK_SCALE` went from 0.2 to 0.045 to 0.0001, so they are
  probably the old light's flares (kept as the brief says), not the VX1 spark; the spark scale (now 0.09) was not tuned
  from the pictures. OWNER ONLY: whether the starbursts are too big.
- Not measured: frame time, a 20-enemy shock fight (up to 48 forks plus bolts; past the 48 cap the old arcs draw).
