# Shot scripts

Scripts that render pictures of the real game for the owner. They need a renderer (not `--headless`) and write
under `build/shots/`. Run one off screen:

```bash
godot --path . --position -10000,-10000 -s scripts/shots/<name>.gd -- lang=en
```

**Keep this folder small.** A shot script written for one step is deleted when that step's version ships, unless a
workflow, a test, another script or a living doc (CLAUDE.md, `docs/process/`, `docs/architecture/`, `docs/art/`,
`docs/balance/`, the active version's folder) still names it. The scripts removed on 2026-11-10 (163 of them) are
in the tag `archive/scripts-2026-11`.

## Used by CI

| Script | What it renders |
|---|---|
| `tour.gd` | The screenshot tour: boots `main.tscn` and drives it with input (PRESENTATION_CONTRACTS §10) |
| `galleries.gd` | The gallery scenes |

## Named by a doc, a test or another tool

| Script | What it renders |
|---|---|
| `boss_signatures.gd`, `bosses.gd` | Each boss and its signature mechanic |
| `o5_twin_wardens.gd`, `quake_pillars.gd`, `nb_lantern_shade.gd` | The Twin Wardens, the Gatekeeper's pillars, the Lantern Shade's dark |
| `o13a_variants.gd`, `o13b_signatures.gd`, `o13c_signatures.gd`, `o13d_starfall.gd` | The v0.11.0 enemy variants and signature enemies |
| `o17_priest_clips.gd`, `vat_sheet.gd`, `mi_models.gd` | Animation clip sheets and model contact sheets |
| `o10_spells.gd` | The auto-spells |
| `o15_purpose_floor.gd`, `o15_purpose_rooms.gd`, `room_layouts.gd` | Rooms with a purpose and the designed layouts |
| `starfall.gd`, `mock_look.gd` | Biome looks |
| `hud_style.gd`, `card_pool.gd`, `shop.gd`, `rewards.gd`, `gamble.gd` | HUD, cards, shop, rewards and the shrine |
| `loading_cover.gd`, `portal_transit.gd` | The loading cover and the portal |
| `vfx_gallery.gd`, `mock_vfx.gd` | Effect contact sheets |
| `cvd_sim.py` | Python helpers that combine or analyse shots |
