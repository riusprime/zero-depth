# TEXTURES_3: the owner's menu, glyph and ambient textures (v0.8.0 TX3)

The owner sent the v0.8.0 textures on 2026-10-16 (FX.zip, TEX.zip; [`../PROGRESS.md`](../PROGRESS.md) History). TX3 is
the menus, the element glyphs and the ambient motes from the request
[`docs/art/requests/v0.8.0_textures.md`](../../../art/requests/v0.8.0_textures.md). The Ember stone menu stays
style B (G2 pick, 2026-10-14); the owner says it is OK but not final, so TX3 only swaps the code-made surfaces for the
owner's pictures and keeps the layout, colours and type.

- **Status:** RUN (agent: headless tests and software-rendered shots). How it looks on the owner's screen, whether the
  wall and grain feel right, whether the glyph badge reads at a glance: **OWNER ONLY**.
- **Build:** branch `v080-tx3`, commit `d4ee403` (`v0.8.0 Step TX3`, parent `ab51a15`). The tests ran on that tree
  before the commit; after the last test-file run only two comment lines in `element_glyphs.gd` changed (lint was
  re-run after them, and the e2e run below came after them too). The shots ran on `ce6b72e` (`d4ee403` merged with
  `claude/lucid-fermat-9wv2tf`, docs only). The "before" shots ran on a `git archive` of `ab51a15` (the same scripts).
  Godot `4.7.2.stable.official.ed1daf0bf`; shots on `gl_compatibility` (Mesa llvmpipe, software GL under xvfb), not
  the owner's hardware. A shared cloud container, so the times are slow and noisy.
- **Date:** 2026-10-16. **Who ran it:** agent.

## What each texture replaced

| id | File (as installed) | Replaced (the code-made look) | Where it shows | Code |
|---|---|---|---|---|
| `tex_menu_stone` | `assets/textures/ui/tex_menu_stone.png` (512, grey) | the noise grain (`FastNoiseLite`) the slabs multiply their colour by | every Ember stone slab, card, plaque, the Build page | `EmberStone.grain()` |
| `tex_menu_stone_wall` | `assets/textures/ui/tex_menu_stone_wall.png` (1024, colour) | the shader's stone floor (mottled slabs, seams, cracks) | the main menu's own backdrop; the code glow still breathes over it, dimmed (`WALL_GAIN` 0.62, starting value) | `MenuBackdrop`, `EmberStone.wall()` |
| `fx_ember_sparks` | `assets/textures/vfx/fx_ember_sparks.png` (512, 2 × 2) | the round code sparks | the menus' rising sparks (the same one shader pass) | `MenuBackdrop.sparks_texture()` |
| `ui_element_glyphs`, `ui_element_glyphs_2` | `assets/textures/ui/` (512 each, 2 × 2, cutout) | nothing: before TX3 only the ring's colour named the element | a small carved badge on an elemental card's socket ring (sockets of 40 px and up) | `ElementGlyphs`, `InlaySocket` |
| `fx_star_motes` | `assets/textures/vfx/fx_star_motes.png` (512, 2 × 2) | the tiny octahedron stars | the starry void (Starfall, the final arena): camera-facing sprite quads, still one MultiMesh | `StarVoid` |

If a file is not installed, the code-made look stays (each loader checks `ResourceLoader.exists`).
`scripts/assets/tx3_prep.py` makes all six from `unprocessed_images/v080_tex/` and `unprocessed_images/vfx/`.
`assets/models/manifest.json` lists them with their sha256, and `data/credits/licences.tres` was rebuilt: the owner's
files went from 46 to 52.

The glyphs: 23 cards name an element (`ElementGlyphs.ELEMENT_OF`; an ELEMENT op inside a HOOK op's `hook_ops` counts,
as with `chain_blast`, `ember_trail`, `phase_dash` and `shared_explosive`). The crossed blades and the star burst on
`ui_element_glyphs_2` are sliced and named, but no element uses them: OWNER_TODO D42.

## Shots (`tx_shots/`, before | after, side by side)

| File | What |
|---|---|
| [`tx3_main_menu_backdrop_en.jpg`](tx_shots/tx3_main_menu_backdrop_en.jpg) | the main menu: the code floor → the owner's wall; the slab's grain |
| [`tx3_menu_slab_en.jpg`](tx_shots/tx3_menu_slab_en.jpg), [`tx3_menu_slab_es.jpg`](tx_shots/tx3_menu_slab_es.jpg) | the menu slab with its text, en and es (crop) |
| [`tx3_card_glyph_en.jpg`](tx_shots/tx3_card_glyph_en.jpg), [`tx3_card_glyph_es.jpg`](tx_shots/tx3_card_glyph_es.jpg) | the reward pick: Frost Nova gets the snowflake, Ember Edge the flame; Cold Snap names no element, so no badge |
| [`tx3_menu_sparks_en.jpg`](tx_shots/tx3_menu_sparks_en.jpg) | the backdrop's right side at full resolution (crop): the sparks. They are a few px across in a still frame; motion is OWNER ONLY |
| [`tx3_starfall_void_stars.jpg`](tx_shots/tx3_starfall_void_stars.jpg) | Starfall's void edge: the octahedron stars → the owner's twinkles, round stars and comets |

Commands (one empty `XDG_DATA_HOME` per run; the before tree at `<before>`, the after tree the worktree; the
before/after pairs were composed with Pillow from `build/shots/`, by hand):
```
XDG_DATA_HOME=<empty folder> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path <tree> \
  --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mu2_shots.gd -- --lang=en
```
(then `--lang=es`, then `-s scripts/shots/starfall.gd` with no `--lang`). Raw output (engine warnings and GDScript
backtraces, which appear the same on both trees, trimmed). After:
```
mu2: renderer=gl_compatibility lang=en
mu2: res://build/shots/v0.8.0/mu2/main_menu_en.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/build_picker_en.png (1920, 1080)
mu2: posed 8 cards in 8 slots
mu2: res://build/shots/v0.8.0/mu2/pick_en.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/pause_en.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/build_en.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/codex_en.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/achievements_en.png (1920, 1080)
mu2: done
exit 0
```
(`--lang=es`: the same lines with `_es`, `exit 0`.)
```
starfall: seed=20261008 floor=1 pools=10 stars=5371 islands=172 crystals=80 spikes=891 nebula=16
starfall: res://build/shots/v0.7.5-dev/starfall/1_start_room.png
starfall: res://build/shots/v0.7.5-dev/starfall/2_starglow_pool.png
starfall: res://build/shots/v0.7.5-dev/starfall/3_void_edge.png
starfall: res://build/shots/v0.7.5-dev/starfall/4_wide.png
exit 0
```
Before (`ab51a15`): both `mu2_shots.gd` runs printed the same lines and `exit 0`. The before `starfall.gd` run was
**killed** after its third shot (two software-GL runs were going at once; likely memory), so there is no before
`4_wide`. The void-edge pair still shows the stars:
```
starfall: seed=20261008 floor=1 pools=10 stars=5371 islands=172 crystals=80 spikes=891 nebula=16
starfall: res://build/shots/v0.7.5-dev/starfall/1_start_room.png
starfall: res://build/shots/v0.7.5-dev/starfall/2_starglow_pool.png
starfall: res://build/shots/v0.7.5-dev/starfall/3_void_edge.png
exit 137
```

## Tests

Lint, after the last code change:
```
$ gdformat --check src scripts tests
964 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
```

The two touched folders, run first (before the two fixes below):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Scripts             103
Tests               707
Passing Tests       706
Failing Tests         1
Asserts           1945349/1945354
Time              548.211s
```
The failure was `test_element_glyphs.gd`: the test read only top-level ELEMENT ops, so it missed four cards whose
element sits in a HOOK op's `hook_ops` (the table was right):
```
[Failed]:  [STRING_NAME(ember)] expected to equal [STRING_NAME()]:  chain_blast wears its modifiers' element
[Failed]:  [STRING_NAME(ember)] expected to equal [STRING_NAME()]:  ember_trail wears its modifiers' element
[Failed]:  [STRING_NAME(void)] expected to equal [STRING_NAME()]:  phase_dash wears its modifiers' element
[Failed]:  [STRING_NAME(ember)] expected to equal [STRING_NAME()]:  shared_explosive wears its modifiers' element
[Failed]:  [19] expected to equal [23]:  the table lists only elemental cards
```
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Scripts              26
Tests               132
Passing Tests       131
Failing Tests         1
Asserts           9256/9257
Time              30.487s
```
The failure was `test_credits_licences.gd` `test_the_committed_list_matches_a_fresh_build`: the owner's file count
changed with the six new manifest entries. Rebuilt with
`godot --headless --path . -s scripts/content/build_credits.gd` (`wrote res://data/credits/licences.tres (4 entries)`;
46 → 52 files).

After the fixes, the failing and touched files:
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_element_glyphs.gd,res://tests/content/test_credits_licences.gd,res://tests/content/test_model_manifest.gd,res://tests/unit/presentation/test_tx3_textures.gd -gexit
res://tests/unit/presentation/test_element_glyphs.gd       3/3 passed.
res://tests/content/test_credits_licences.gd               4/4 passed.
res://tests/content/test_model_manifest.gd                 5/5 passed.
res://tests/unit/presentation/test_tx3_textures.gd         3/3 passed.
Scripts               4
Tests                15
Passing Tests        15
Asserts            4510
Time              1.807s
```
The e2e tests that reach the change (main menu and pad menus, the reward pick, the card pool, the final arena,
Starfall):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_rewards.gd,res://tests/e2e/test_e2e_card_pool.gd,res://tests/e2e/test_e2e_final_boss.gd,res://tests/e2e/test_e2e_starfall.gd,res://tests/unit/presentation/test_element_glyphs.gd -gexit
res://tests/e2e/test_e2e_pad_menus.gd                      5/5 passed.
res://tests/e2e/test_e2e_rewards.gd                        3/3 passed.
res://tests/e2e/test_e2e_card_pool.gd                      1/1 passed.
res://tests/e2e/test_e2e_final_boss.gd                     1/1 passed.
res://tests/e2e/test_e2e_starfall.gd                       1/1 passed.
res://tests/unit/presentation/test_element_glyphs.gd       3/3 passed.
Scripts               6
Tests                14
Passing Tests        14
Asserts             317
Time              104.83s
```
(Per-file lines condensed from GUT's per-test listing; the totals are verbatim.)

Not run locally: `bash scripts/ci/seams.sh` (the lead's, after the merge) and the full suite (GitHub, once per
version).
