# VX7: bleed, Glaive, Wave, void, water and floor marks in the VFX pack's style

Branch `v0100-vx7` (from `claude/v0100-vfx` ef2be210). Presentation only: no sim, golden or content-schema change.
Build SHA: the commit that carries this file (`git log -1 --format=%h` on `v0100-vx7`).

## What was built

| Row | What | Where | How |
|---|---|---|---|
| N2 bleed status | Dark red drips held on a bleeding enemy; a short splatter (1.5 s) at its feet each 120-tick cycle | `vfx/gap_pack.gd` (moved from `vfx_layer.gd` `status()`), `assets/vfx_zd/bleed/drips.tscn` | New scene: the poison bubble 03 splat particles' material (copy `drips_material.tres`), recoloured bleed, gravity, ~4 a second. Ids `vx7_bleed_drips` (status), `vx7_bleed_splat` (= `poison_puddle_vfx_01`, family mark). The old floor decal stays |
| N2 splatter on hits and kills | Already the pack's since VX3 (`burst_bleed` + `burst_puddle` = `poison_puddle_vfx_01`) | `vfx_pack_views.gd` | Not changed |
| N4 Glaive | Pack ring held on each disc, turning with it; disc and afterimages kept | `attack_forms/glaive_view.gd` | `vx7_glaive_ring` = `pulse_area_vfx_03`, disc colours, `RING_PER_M` 0.4 |
| N4 Wave | Crest wears a copy of `pillar_area_01_pillar_01`; the ground wash is a held `ripple_area_vfx_02` | `attack_forms/wave_view.gd` | `vx7_wave_wash`; crest mesh UV v flipped to the pillar's way |
| N4 nemesis_crescent | Same shape (UVs added), copy of `rim_area_04_upward` in its own colours | `fireball_views.gd` (`_make_set`, that look only) | `PACK_CRESCENT` |
| N5 void rift | Patch rift and blast rift are `pulse_area_vfx_03` in void violet (`ElementLooks` core #8B55FF); the rift along a beam and all tendrils keep their sprites | `vfx/gap_pack.gd` (moved from `vfx_layer.gd`) | `vx7_void_rift`, held in a patch, once in a blast |
| N5 void shot | Small violet sparks (`magic_orb_flash_vfx_03`) along the dust trail, one every 9 ticks a shot, with the dust (not at Low) | `attack_forms/void_view.gd` | `vx7_void_spark`; the lens stays |
| N8 water | Tide disc = held `ripple_area_vfx_02` (its speed negative on a pull so the rings run in); the push's swell = `pulse_area_vfx_02` once; spray = `poison_bubble_vfx_05` pops in blue, ~5 a second | `tide_views.gd` | `vx7_tide_disc`, `vx7_tide_swell`, `vx7_tide_bubble`. Toll rings, light, hit areas, telegraphs and `tide_wave_views.gd` untouched |
| N9 floor marks | Frost (`frost`, `frost_burst`) and splat (`splat0..3`) decals carry a pack effect frozen at 60 % of its animation for the mark's life, scaled down over the last 90 ticks and up over the first 6 | `vfx/vfx_core.gd` (`_lay_pack_marks`) | `vx7_mark_frost` = `ice_area_vfx_04`, `vx7_mark_splat` = `poison_puddle_vfx_05` (decal colour); family mark (48) |

Table: `data/vfx/pack_fx_vx7.tres` (id `pack_fx_vx7`, 11 rows, all `vx7_`). Fallbacks: no PackFx, or no room in the family, draws the old look for that
instance (consts `PACK_BLEED`, `PACK_RIFT` in `gap_pack.gd`; `PACK_MARKS`, `vfx_core.gd`; `PACK_RING`, `PACK_WAVE`, `PACK_SPARKS`,
`PACK_WATER`, `PACK_CRESCENT` in their views). The views find the pack through their parent (`GapPack.pack_of`), so `world_view_root.gd` is untouched.
`vfx_layer.gd` went from 996 to 905 lines.

## Not done, and why

- **Scorch and fire_patch marks (`fire_area_05`): left as decals.** `fire_area` scenes have no animation: a flame shader plus sparks. Frozen, it is a
  still orange flame on the floor, which reads as live fire for 7 s on ground that is only burnt. Reported as the brief allows; the id was dropped from the table.
- **Bleed drips are hard to see in the still shot** (small streaks; the old drips are small too). The held effect and its fall are tested, not judged by eye.
- **The pull tile's first frame:** shown after the current is running (strength above 0.5); the old disc is much larger than the pack ripple.
- The rift along a beam (`_void_line`) keeps its ribbon: the pack's pulse is a ring, not a line.
- The crest colours were changed after the shot (primary the edge colour lightened, was the core, which came out flat white). That change is NOT in the shots.

## Tests

Lint: `gdformat` and `gdlint` clean on every touched `.gd`.
`test_vx7_gaps.gd`: 24 tests (table, drips scene, bleed held/splatter/fallbacks, void patch and blast, marks, Glaive, Wave, crescent, void sparks, tide disc, spray and fallbacks).
Run (headless, godot 4.7.2, one command): `test_vx7_gaps`, `test_vx3_zones`, `test_vx4_shots`, `test_glaive_view`, `test_wave_wisps_view`, `test_void_view`,
`test_tidecaller_views`, `test_tide_wave_views`, `test_vfx_layer`, `test_vfx_budget`, `test_vfx_pressure`, `test_nemesis_views`, `test_e2e_glaive_combos`,
`test_e2e_nemesis`, `test_e2e_tidecaller`, `test_e2e_void`, `test_e2e_wave_combos`, `test_e2e_wave_wisps`, `test_pack_fx_scenes`: 19 scripts, 146 tests, 146 passing (340 s).
Earlier (before the scorch removal and the crest colours): `tests/content`, `tests/arch`, `tests/golden`: 34 scripts, 172 tests, all passing (87 s). Not re-run after those two small changes.

Existing tests changed: `test_vx3_zones.gd` (a mark's pack effect no longer counts in its spawn counts; bleed now has the VX7 drips),
`test_pack_fx_scenes.gd` (a table row may point at `res://assets/vfx_zd/`, our scenes in the pack's style).

## Shots

`scripts/shots/vx7_gaps.gd`, run once more than asked (three runs: the first had the tide tile never starting and the old tiles secretly packed, the second the sim
starting while PackFx's warm-up held the family full). Old left, new right, written to `build/shots/v0.10.0/vx7/` (not tracked):
`bleed_void.png` (bleed, void patch and blast, void shot), `forms.png` (Glaive, Wave, crescent), `water.png` (pull, push), `marks.png` (fresh, fading).
The crescent tile shows no shot (the hostile shot did not appear in the frame): the crescent's material is covered by a test, not seen.

```
godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx7_gaps.gd
```

Agent's reading, not an owner judgement: the Wave's ripple wash, the tide's ripple disc, the void's pulse rings, the frost and blood marks and the Glaive's
ring read well; the Wave's pack crest was a flat white sheet (colours then changed, unseen).
