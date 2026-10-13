# STARFALL: is Biome 5 (owner N3) built, in the run's draw, fair, and proved by tests and shots?

- **Status:** RUN (tests and shots); feel and look on the owner's hardware: OWNER ONLY
- **Build:** branch `v075-nb2`, cut from `fa70fcb` (CX and NB1 merged). The folder runs and the e2e ran on the tree of
  `898fd20` / `6f2700c` (same code; `6f2700c` adds docs only). One presentation test failed there (below); the fix
  (`star_crystal` down to three prisms) is in the Step NB2 commit, and `tests/unit/presentation` and the shots were
  re-run on that tree. Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18.44 (cloud container; llvmpipe, Vulkan
  1.4.318, Forward+, for the shots)
- **Date:** 2026-10-13
- **Who ran it:** agent

## What was built
- **Data** `data/biomes/starfall.tres`: palette = ART_DIRECTION §2's Starfall column (all *proposal*: no reference
  panel); a starry mood (pale lavender starlight, energy 0.7, pitch −52°, near-black violet void, **no fog**, teal /
  magenta-white grade, violet flames on the fire props); a surface (`BiomeSurface`, kind `starglow`); a look
  (`BiomeLook`, edge `stars`). Ambience cue `data/audio/cues/starfall.tres` and its loop
  `assets/audio/ambience/starfall.wav` (`python3 scripts/audio/generate_sfx.py`, re-run, not hand-edited: only the new
  file and its manifest entry changed; `--check` reports 0 differences). Locale `BIOME_STARFALL` en "Starfall", es
  "Caída Estelar"; `BIOME_STARFALL_DESC` (the Codex line) en + es. Appended last to `data/run/three_floors.tres`
  `biomes`: a run draws its 3 floors from 5 biomes, never one twice.
- **Sim (gameplay touch):** starglow pools, laid by NB1's `IcePatches` rules from the new `map:starglow` sub-stream
  (`IcePatches.stream_of(kind)`; ice keeps `map:ice`) into `World.ice` (an `IceField` with `kind = &"starglow"`,
  `speed_permille = 1250`). On a pool the hero's target walking velocity is ×1.25 and they ease 0.1 s up / 0.2 s down.
  Never in the start hall, boss, portal or shop room; nothing hurts; the dash, skills and enemies unchanged. Not hashed
  itself (loadout). Ice's `speed_permille` is 1000 and the scale is skipped then, so Frozen Shore is unchanged.
  `BiomeCompiler.compile_surface` (any kind) is what Main and `SaveLab` call now; `compile_ice` still answers for ice.
- **Look (presentation only; the first four biomes untouched):** `square_cover` (`rock_large` 3 : code-made
  `star_monolith` 1), `decor_swap` (grass -> code-made `star_crystal`, rubble and debris -> code-made `meteorite`,
  `CodeProps`), `edge = stars` (`BiomeEdge._build_stars` with `StarVoid`: the floor's rock underside and hanging
  spikes, twinkling stars, nebula clouds, drifting rock islands with crystal clusters, all under the ground's level and
  clear of the floor; twinkle and drift still with reduced motion), `enemy_tint` violet on grey and bone parts;
  `StarglowViews` draws the sim's pools exactly (deep violet facets, twinkling stars inside, a bright lavender rim);
  `ShardCluster.TINTS.starfall` nebula magenta-pink crystals. The dev gallery gained a `starfall` palette row.
- **Art request:** [`../../../art/requests/v0.7.5_starfall.md`](../../../art/requests/v0.7.5_starfall.md).
- **Tests added:** `tests/unit/sim/test_starglow_patches.gd`, `tests/unit/presentation/test_starfall.gd`,
  `tests/e2e/test_e2e_starfall.gd`; biome counts 4 -> 5 in `test_content_valid.gd`, `test_stage_mood.gd`,
  `test_run_flow.gd`.

## Commands
```
gdformat --check src scripts tests && gdlint src scripts tests
python3 scripts/audio/generate_sfx.py && python3 scripts/audio/generate_sfx.py --check
bash build/run_nb2_e2e.sh    # godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<the 12 e2e scripts below> -gexit
bash build/run_nb2.sh        # one godot per folder, in order: tests/content, tests/arch, tests/golden,
                             # tests/unit/debug, tests/unit/application, tests/unit/presentation, tests/unit/sim
                             # each: godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=<dir> -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit   # re-run after the fix
xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/starfall.gd
```
The full suite and bot sims were not run (lead's instruction; one full run per wave by the lead).

## Raw output
```
$ gdformat --check src scripts tests
717 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
$ python3 scripts/audio/generate_sfx.py --check
...
  same  assets/audio/ambience/frozen_shore.wav
  same  assets/audio/ambience/starfall.wav
  same  assets/audio/manifest.json
0 difference(s)
```
E2e (`build/run_nb2_e2e.sh`, GUT totals, colour codes stripped):
```
res://tests/e2e/test_e2e_starfall.gd           1/1 passed.
res://tests/e2e/test_e2e_frozen_shore.gd       1/1 passed.
res://tests/e2e/test_e2e_codex.gd              1/1 passed.
res://tests/e2e/test_e2e_run_flow.gd           3/3 passed.
res://tests/e2e/test_e2e_lighting.gd           1/1 passed.
res://tests/e2e/test_e2e_audio.gd              2/2 passed.
res://tests/e2e/test_e2e_saves.gd              2/2 passed.
res://tests/e2e/test_e2e_dev_master_panel.gd   1/1 passed.
res://tests/e2e/test_e2e_kit.gd                2/2 passed.
res://tests/e2e/test_e2e_floor.gd              2/2 passed.
res://tests/e2e/test_e2e_shell.gd              2/2 passed.
res://tests/e2e/test_e2e_routes.gd             1/1 passed.
    starfall e2e: run seed 20261009, 1 pools, fastest on a pool 0.1199 m/tick (own top 0.1000)
Scripts              12
Tests                19
Passing Tests        19
Asserts             331
Time              121.416s
exit 0
```
Per folder (`build/run_nb2.sh`):
```
== content: -gdir=res://tests/content -ginclude_subdirs
Scripts              23
Tests               114
Passing Tests       114
Asserts            7404
exit 0
== arch: -gdir=res://tests/arch -ginclude_subdirs
Scripts               2
Tests                 4
Passing Tests         4
Asserts            8170
exit 0
== golden: -gdir=res://tests/golden -ginclude_subdirs
Scripts               1
Tests                 2
Passing Tests         2
Asserts               4
exit 0
== unit/debug: -gdir=res://tests/unit/debug -ginclude_subdirs
Scripts               2
Tests                10
Passing Tests        10
exit 0
== unit/application: -gdir=res://tests/unit/application -ginclude_subdirs
Scripts               8
Tests                44
Passing Tests        44
exit 0
== unit/presentation: -gdir=res://tests/unit/presentation -ginclude_subdirs
    [Failed]:  [216] expected to be < than [200]:  star_crystal stays low-poly
Scripts              69
Tests               438
Passing Tests       437
Failing Tests         1
Asserts           772369/772370
Time              338.407s
exit 1
== unit/sim: -gdir=res://tests/unit/sim -ginclude_subdirs
    ice over 1000 floors: 4274 patches, 987 floors with ice (218219 ms)
    starglow over 1000 floors: 4262 pools, 989 floors with pools (244834 ms)
Scripts              88
Tests               921
Passing Tests       921
Asserts           681835
Time              4167.617s
exit 0
```
The failure was NB1's low-poly cap (`test_frozen_shore.gd` checks every `CodeProps` piece under 200 vertices): the
first `star_crystal` had four six-sided prisms (216). Fixed to three (162); re-run of the folder:
```
== unit/presentation (re-run)
Scripts              69
Tests               438
Passing Tests       438
Asserts           772352
Time              516.542s
exit 0
```
Shots:
```
starfall: seed=20261008 floor=1 pools=4 stars=3819 islands=113 crystals=53 spikes=541 nebula=16
starfall: res://build/shots/v0.7.0-dev/starfall/1_start_room.png
starfall: res://build/shots/v0.7.0-dev/starfall/2_starglow_pool.png
starfall: res://build/shots/v0.7.0-dev/starfall/3_void_edge.png
starfall: res://build/shots/v0.7.0-dev/starfall/4_wide.png
exit 0
```
Committed copies (resized to 1280 × 720 JPEG):
[start room](shots/starfall/1_start_room_1280x720.jpg), [a starglow pool](shots/starfall/2_starglow_pool_1280x720.jpg),
[the void edge](shots/starfall/3_void_edge_1280x720.jpg), [wide](shots/starfall/4_wide_1280x720.jpg).

## Result
| Check | Measured | OK? |
|---|---|---|
| Lint and format | clean | yes |
| Pool placement rules over 1,000 seeds (rooms, doorways, walls, spots, sizes, overlap) | 0 rules broken; 4262 pools; 989/1000 floors with pools | yes |
| `map:starglow` apart from `map:ice` and the floor streams; ice unchanged (`speed_permille` 1000, `map:ice`) | `test_starglow_patches.gd` 6/6; `test_ice_patches.gd` in the sim folder | yes |
| Faster on a pool, still stops; dash unchanged | ×1.25 at full run (unit); e2e: 0.1199 m/tick on a pool against an own top of 0.1000 | yes |
| Goldens | `tests/golden` 2/2, no golden file changed | yes |
| Codex line in en + es | `tests/content` 114/114 (incl. `test_codex_content.gd`) | yes |
| Reachable from the real game | `test_e2e_starfall.gd`: Play + Restart run via the pause menu reaches a Starfall floor 1 (run seed 20261009), its mood, look, void, crystals, ambience and pools; the stick runs the hero across a pool faster than their top speed | yes |
| Frozen Shore still reached with 5 biomes | `test_e2e_frozen_shore.gd` 1/1 | yes |

## Interpretation
- Starfall is in the game and in the draw; the other four biomes' looks and sims are unchanged (every existing
  presentation, sim and golden test passes; Frozen Shore's ice is untouched).
- What the shots show (agent's reading, not the owner's): the floor as a floating slab of violet stone with spikes
  hanging under its rim, over a near-black void of white and coloured stars, soft violet / teal / magenta nebula
  clouds and small rock islands, some with glowing crystals; pink-magenta wall crystals, violet flames, starry pools
  with a lavender rim. In the wide, zoomed-out shot the far side is cut by the camera's short far plane (as NB1 noted);
  at play zoom the void fills the screen past the edge. The ink pass outlines the small stars, so some read as tiny
  diamonds with a dark rim (and a few as dark dots on the pools).
- Known, not fixed: enemy red against the Starfall ground is about 1.2:1 in luminance (identity by rings and
  outlines, as on Red Canyon).
- **OWNER ONLY:** feel (is ×1.25 a fun step or too much), fun, the name, the look on the owner's GPU.
- Flag for the owner: `map:starglow` is a sub-stream of `map` not named in EI-05's list (as `map:ice`); see PLAN
  "NB2 decisions".

## For the merge
- **Audio manifest:** one entry added (`starfall`); if another branch adds sounds, re-run
  `python3 scripts/audio/generate_sfx.py` after merging rather than hand-merging the JSON.
- **Biome counts in tests** (5 now): `tests/content/test_content_valid.gd`, `tests/unit/presentation/test_stage_mood.gd`,
  `tests/unit/sim/test_run_flow.gd` (`biome_count`).
- **A fifth biome changes every run seed's biome draw.** Any test or shot that assumes which biome a seed draws must
  loop or force the biome (the Frozen Shore e2e loops; the Frozen Shore shot forces its look). `STAGE_SEED + 3`
  (20261009) draws Starfall on floor 1 today.
- **AP (the Ascension loop)** draws "from all five" (PLAN N4): `three_floors.tres` now lists five.
- Untracked `.uid` files from CX (`scripts/shots/codex.gd.uid`, `tests/content/test_codex_content.gd.uid`,
  `tests/e2e/test_e2e_codex.gd.uid`, `tests/unit/application/test_codex.gd.uid`,
  `tests/unit/presentation/test_codex_view.gd.uid`) appear after an import on this base; not staged here (not NB2's).
