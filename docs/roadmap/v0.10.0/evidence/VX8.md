# VX8: the Blade's swings in the VFX pack's style

Branch `v0100-vx8` (from `claude/v0100-vfx` ef2be210). Presentation only: no sim, golden or content-schema change.
Build SHA: the commit that carries this file (`git log -1 --format=%h` on `v0100-vx8`).

## Rows done (VFX_PACK N3)

| What | Where | New look |
|---|---|---|
| The swing trail | `kit_view.gd` | The same ribbon geometry (kept), with `ShaderMaterial` `assets/vfx_zd/blade/blade_trail.gdshader` (adapted from the beam pack's `beam_outer.gdshader`: scrolling noise mixed between primary and secondary colour; its axis turned into the ribbon's, UV.x along the swing, UV.y across it, vertex alpha keeps the tail fade). Colour: the heat tier's from Hot up, else the step's element, else the blade's own. The thrust's fan carries UVs too |
| Hit-stop | `kit_view.gd` | The noise's scroll (`phase`) only advances in `_process` after the hold check, so the ribbon and its noise hold together. The mesh already held (`_hold`) |
| The cut's spark | `blade_swing_fx.gd` | `vx8_cut` -> `vfx_hit_04`, gold or the element's colour, on the blade's tip at the cut (finisher bigger); the old flare stays at 40% beside it |
| Crescents, ghost slashes | `blade_form_view.gd` | Baked shapes kept; their material is a copy of `rim_area_04_ground` (`assets/vfx_zd/blade/blade_rim.tres`, vendor shader and textures referenced, not edited), recoloured to the hero's core; the bands carry UVs as the rim of a disc |
| Fissure eruption | `blade_form_view.gd` | `vx8_erupt` -> `vfx_impact_02`, one per 1.6 m of the line (at most 3), the old spikes skipped when it plays; the lit floor line stays |
| Parry spark | `blade_form_view.gd` | `vx8_parry` -> `vfx_hit_04` (the old star skipped) |
| Counter and finisher rings | `blade_form_view.gd` | `vx8_counter` -> `pulse_area_vfx_02`, `vx8_finisher` -> `pulse_area_vfx_01`, scaled to the ring's radius (a pulse area is 4.5 m across at 1), recoloured |
| Orbit blades | `blade_form_view.gd` | Kept |
| Lunge Cleave | `skill_visuals.gd` | The sweep ribbon takes the same ribbon material (UV along the sweep), tinted by the heat tier; the hit adds `vx8_cleave_flash` -> `big_flash_02` on the fan's front; the fan flash stays |

Table `data/vfx/pack_fx_vx8.tres` (`pack_fx_vx8`): `vx8_cut`, `vx8_parry` (hit), `vx8_erupt`, `vx8_cleave_flash` (impact),
`vx8_counter`, `vx8_finisher` (area). Each effect with a pooled scene starts once per swing/form (`BladeFormView._packed`
remembers per effect whether the pack or the old look draws it, so a look never swaps half way).

New helper `src/presentation/world_view/blade_pack.gd` (`BladePack`, in `src/`, not `assets/`, because it is code): finds the
`PackFx` on an ancestor (`WorldViewRoot.pack_fx`, so no wiring in `world_view_root.gd` was needed), builds the ribbon and rim
materials, and counts ribbon slots against the `trail` family cap (x Effects density). A ribbon slot is claimed when a swing
starts and returned when it ends or the view leaves the tree.

Old looks stay behind `PACK_BLADE := true` in `kit_view.gd`, `blade_swing_fx.gd`, `blade_form_view.gd`, `skill_visuals.gd`.
Fallback: no pack above the view, or `trail` / `hit` / `impact` / `area` full, gives the old look for that instance.

## Tests

All run `--headless`, `--fixed-fps 60`, on the owner's PC.

| Run | Result |
|---|---|
| `tests/unit/presentation/test_vx8_blade.gd` (new) | 11/11 passed, 46 asserts |
| That file plus `test_kit_view`, `test_kit_views`, `test_blade_form_view`, `test_blade_feel`, `test_four_slash_view`, `test_heat_attack_colours`, `test_heat_views`, `test_item_visuals`, `test_skill_animations`, `test_movement_vfx`, `test_pack_fx` (12 scripts) | 97/97 passed, 607 asserts |
| `tests/content`, `tests/arch`, `tests/golden` (34 scripts) | 172/172 passed, 32186 asserts |
| e2e: `blade_feel`, `combo`, `four_slash`, `sword_unbound`, `wand_blade`, `kit`, `abilities`, `heat` (8 scripts) | 11/11 passed, 168 asserts, 318 s |

After the last tuning (shader constants, spark and flash scales, eruption scale) only `test_vx8_blade`, `test_blade_form_view`,
`test_kit_view` and `test_skill_animations` were re-run (29/29). The content/arch/golden and e2e runs above were before
that tuning; the tuning changed no ids or code paths.
Lint: `gdformat --check` and `gdlint` clean on every touched `.gd`.

## Shots

`scripts/shots/vx8_blade.gd`, run off screen on the RTX 3060 (`--position -10000,-10000`). Old left, new right, early frame
on top and a later one below. Written to `build/shots/v0.10.0/vx8/` (not tracked): `swing.png`, `forms.png`, `cleave.png`.
It was run twice: once, then again after tuning (the ribbon's noise was too faint, the spark and flash scales off).

```
godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx8_blade.gd
vx8_blade: res://build/shots/v0.10.0/vx8/swing.png
vx8_blade: res://build/shots/v0.10.0/vx8/forms.png
vx8_blade: res://build/shots/v0.10.0/vx8/cleave.png
```

What the agent saw (not the owner's judgement; look and feel is OWNER ONLY):
- cleave: the new sweep ribbon shows the pack's noise over the fan, and the flash reads at the fan's front;
- swing: the ribbon's noise is subtle at the trail's short length (6 ticks); the gold cut spark is small and sits at the blade's tip at the cut tick, which is
  beside the hero's front, not on the target;
- forms: the eruption and crescents were not judged closely.

## Not done / open

- The laser blade's core and glow capsules keep their look (optional in the brief).
- Frame time and hitch were not measured (owner hardware).
- The swing sheet's camera zoom (`3.2`) did not visibly apply: the rig overrides it.
- Scales (`PACK_CUT_SCALE`, `FLASH_PER_M`, `ERUPT_PER_M`, `PULSE_M`) are starting values.
