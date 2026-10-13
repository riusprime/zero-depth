# FROZEN_SHORE: is Biome 4 (owner N2) built, in the run's draw, fair, and proved by tests and shots?

- **Status:** RUN (tests and shots); feel and look on the owner's hardware: OWNER ONLY
- **Build:** `fb3c04b` on `v075-nb1` (cut from `6381fcb`, the v0.7.0 head); the Step NB1 commit adds only docs on top.
  Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18.44 (cloud container, llvmpipe for the shots)
- **Date:** 2026-10-12 / 2026-10-13
- **Who ran it:** agent

## What was built
- **Data** `data/biomes/frozen_shore.tres`: palette = ART_DIRECTION §2's sampled Frozen Shore column; a cold mood (pale
  blue moon, energy 0.6, pitch −48°, navy void, icy fog 0.006, blue/white grade, warm fire light kept); a surface
  (`BiomeSurface`, ice); a look (`BiomeLook`). Ambience cue `data/audio/cues/frozen_shore.tres` and its loop
  `assets/audio/ambience/frozen_shore.wav` (`scripts/audio/generate_sfx.py`; no existing sound changed). Locale
  `BIOME_FROZEN_SHORE` en "Frozen Shore", es "Costa Helada". Added to `data/run/three_floors.tres` `biomes` (last, so
  stored biome orders in saves keep their biomes): a run now draws its 3 floors from 4 biomes, never one twice.
- **Sim (gameplay touch):** ice patches (`src/sim/map/ice_patches.gd`, `ice_field.gd`) laid from the new `map:ice`
  sub-stream on Frozen Shore floors only; on ice the hero eases with 0.35 s / 0.6 s instead of 0.1 s / 0.083 s (a
  slide). Dash, skills and enemies unchanged; never in the start hall, boss, portal or shop room; nothing hurts. Not
  hashed itself (loadout, like the layout); kept from the base on restore. `BiomeCompiler` compiles it; Main and
  `SaveLab` lay it after the shop.
- **Look (presentation only, the first three biomes untouched):** `BiomeLook.square_cover` (slate `rock_large` 3 :
  `dead_tree` 1), `decor_swap` (grass and debris -> code-made `snow_drift`, rubble -> code-made `ice_shard`,
  `CodeProps`), `edge = water` (`BiomeEdge`: a dark frozen sea, a snow bank under the floor, 563 floes on the shot
  floor), `enemy_tint` (grey and bone parts only, `ActorViews.tint_greys`); `IceViews` draws the sim's patches exactly
  (faceted pale sheet, bright rim, cracks); `ShardCluster.TINTS.frozen_shore` icy crystals.
- **Art request:** [`../../../art/requests/v0.7.5_frozen_shore.md`](../../../art/requests/v0.7.5_frozen_shore.md).
- **Dev panel:** the lighting group lists `frozen_shore.tres`'s mood by reflection (no panel change); `tests/unit/debug`
  green below.

## Commands
```
gdformat --check src scripts tests && gdlint src scripts tests
bash build/run_nb1.sh        # one godot per folder, in order: tests/content, tests/arch, tests/golden,
                             # tests/unit/debug, tests/unit/application, tests/unit/presentation, tests/unit/sim
                             # each: godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=<dir> -ginclude_subdirs -gexit
bash build/run_nb1_e2e.sh    # godot ... -gtest=<the 10 e2e scripts below> -gexit
xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/frozen_shore.gd
```
The full suite and bot sims were not run (lead's instruction; one full run per wave by the lead).

## Raw output
```
$ gdformat --check src scripts tests
699 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
```
Per folder (GUT totals, colour codes stripped):
```
== content: -gdir=res://tests/content -ginclude_subdirs
Scripts              22
Tests               112
Passing Tests       112
Asserts            6971
exit 0
== arch: -gdir=res://tests/arch -ginclude_subdirs
Scripts               2
Tests                 4
Passing Tests         4
Asserts            7987
exit 0
== golden: -gdir=res://tests/golden -ginclude_subdirs
Scripts               1
Tests                 2
Passing Tests         2
Asserts               4
exit 0
== debug: -gdir=res://tests/unit/debug -ginclude_subdirs
Scripts               2
Tests                10
Passing Tests        10
exit 0
== application: -gdir=res://tests/unit/application -ginclude_subdirs
Scripts               7
Tests                32
Passing Tests        32
exit 0
== presentation: -gdir=res://tests/unit/presentation -ginclude_subdirs
Scripts              67
Tests               426
Passing Tests       426
Asserts           695995
Time              291.803s
exit 0
== sim: -gdir=res://tests/unit/sim -ginclude_subdirs
    ice over 1000 floors: 4274 patches, 987 floors with ice (207039 ms)
Scripts              87
Tests               915
Passing Tests       915
Asserts           681797
Time              3372.266s
exit 0
```
E2e (`build/run_nb1_e2e.sh`):
```
res://tests/e2e/test_e2e_frozen_shore.gd          1/1 passed.
res://tests/e2e/test_e2e_run_flow.gd              3/3 passed.
res://tests/e2e/test_e2e_lighting.gd              1/1 passed.
res://tests/e2e/test_e2e_audio.gd                 2/2 passed.
res://tests/e2e/test_e2e_saves.gd                 2/2 passed.
res://tests/e2e/test_e2e_dev_master_panel.gd      1/1 passed.
res://tests/e2e/test_e2e_kit.gd                   2/2 passed.
res://tests/e2e/test_e2e_floor.gd                 2/2 passed.
res://tests/e2e/test_e2e_shell.gd                 2/2 passed.
res://tests/e2e/test_e2e_routes.gd                1/1 passed.
Scripts              10
Tests                17
Passing Tests        17
Asserts             269
Time              85.083s
exit 0
```
Shots:
```
frozen_shore: seed=20261008 floor=1 ice_patches=5 floes=563
frozen_shore: res://build/shots/v0.7.0-dev/frozen_shore/1_start_room.png
frozen_shore: res://build/shots/v0.7.0-dev/frozen_shore/2_ice_patch.png
frozen_shore: res://build/shots/v0.7.0-dev/frozen_shore/3_shore_edge.png
frozen_shore: res://build/shots/v0.7.0-dev/frozen_shore/4_wide.png
exit 0
```
(The PNGs are in `build/`, untracked; re-run the command to see them. The version label is still `v0.7.0-dev` on this
base.)

## Result
| Check | Measured | OK? |
|---|---|---|
| Lint and format | clean | yes |
| Ice placement rules over 1,000 seeds (rooms, doorways, walls, spots, sizes, overlap) | 0 rules broken; 4274 patches; 987/1000 floors with ice | yes |
| Ice slides, dash unchanged, map stream untouched | `test_ice_patches.gd` 6/6 | yes |
| Goldens | `tests/golden` 2/2, no golden file changed | yes |
| Reachable from the real game | `test_e2e_frozen_shore.gd`: Play + Restart run via the pause menu reaches a Frozen Shore floor 1, the stick walks onto ice, the hero still slides 8 ticks after letting go | yes |

## Interpretation
- Frozen Shore is in the game and in the draw; the first three biomes' looks and sims are unchanged (their content
  has no `surface` or `look`, every existing presentation, sim and golden test passes).
- What the shots show (agent's reading, not the owner's): pale snow ground under slate walls and rocks, icy crystals,
  snow drifts and ice shards, warm fire pools, pale ice sheets with a bright rim, and the floor standing in a dark sea
  with floes. In the zoomed-out wide shot the sea's far edge is cut by the camera's short far plane; at play zoom it is
  out of view.
- Not proved here: whether the slide feels good or the ice reads at a glance at speed; that is the owner's
  playtest. **OWNER ONLY:** feel, fun, look on the owner's GPU.
- Flag for the owner: `map:ice` is a sub-stream of `map` not named in EI-05's list (as `map:overrun` already is);
  see PLAN "NB1 decisions".

## For the merge
- **Codex `desc_key` (from CX, `v075-cx`):** Frozen Shore needs one; suggested key and lines:
  - `BIOME_FROZEN_SHORE_DESC` — en: "A moonlit shore locked in ice: snow, slate and frozen sea. The ice patches make
    you slide." — es: "Una costa helada bajo la luna: nieve, pizarra y mar congelado. Las placas de hielo te hacen
    resbalar."
  - No new enemies or bosses in NB1.
- **Audio manifest:** `assets/audio/manifest.json` gained one entry; if NB2 adds a loop too, re-run
  `python3 scripts/audio/generate_sfx.py` after merging rather than hand-merging the JSON.
- **Biome counts in tests** (4 now): `tests/content/test_content_valid.gd`, `tests/unit/presentation/test_stage_mood.gd`,
  `tests/unit/sim/test_run_flow.gd` (`biome_count`).

## Notes for NB2 (the cosmic biome): what to reuse
- A biome is data plus its look: `data/biomes/<id>.tres` (palette with the 7 tokens, `mood`, optional `surface`,
  `look`), its id appended to `three_floors.tres` `biomes` (append, never insert: saves store indices), an ambience
  cue + an `AMBIENCE` entry in `generate_sfx.py`, `BIOME_<ID>` in `locale/strings.csv`, a `ShardCluster.TINTS` row
  (off `#2BC4E2`), and the Codex `desc_key` once CX is merged. The three test counts above go to 5.
- `BiomeLook`: reuse `square_cover`, `decor_swap` and `enemy_tint` as they are. For a star field / void edge add a style
  to `BiomeLook.EDGES` and `BiomeEdge.STYLES` and one `_build_<style>` builder in `BiomeEdge` (the `water` one shows
  the shape: it gets the floor's ground rects, bounds, the `edge` colour and the seed; cosmetic RNG only).
- Code-made pieces (floating rocks, crystal islands): add rows to `CodeProps.SPECS` and a mesh builder; `StageKit` and
  the dresser pick them up by id (`StageKit.piece_of`), decoration height stays capped at 0.4 m.
- A gameplay surface: `BiomeSurface.KINDS` + `BiomeCompiler` (today ice only, via `IceField`); keep it off the start,
  boss, portal and shop rooms and draw it from its own `map:<name>` sub-stream.
- `tests/e2e/test_e2e_frozen_shore.gd` restarts until a Frozen Shore floor 1 comes up (up to 12), so a 5th biome in
  the draw does not break it; `scripts/shots/frozen_shore.gd` defaults to seed 20261008 (re-check it after NB2).
