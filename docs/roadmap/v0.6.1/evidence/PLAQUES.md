# PLAQUES: do the old card looks wear the owner's crystal plaques, and does the build picker wear the owner's art, legibly, in en and es? (PLAN v0.6.1 R1, R2, R2b)

- **Status:** RUN (tests, lint, crop checks); screenshots partly RUN (the build picker only; the plaque shots NOT YET RUN, below)
- **Build:** working tree on `745fc69` (`worktree-agent-a7bd29f8961ef860e`), committed as the `v0.6.1 Step PQ` commit right
  after these runs (no code changed after the last test run); Godot `4.7.2.stable.official.ed1daf0bf`; Linux
  (screenshots: lavapipe Vulkan under Xvfb, Forward+)
- **Date:** 2026-10-09
- **Who ran it:** agent. Whether the plaques and the build picker look right and read well on the owner's screen:
  **OWNER ONLY**.

## What was built
- **Plaques (R1).** `scripts/art/crop_plaques.py` cuts the 12 plaques from
  [`../refs/plaque_templates_empty.webp`](../refs/plaque_templates_empty.webp) (1984 × 793, a 4 × 3 grid). The sheet
  already carries a transparent background (alpha 0 around the plaques; most opaque pixels sit at alpha 249–253,
  which the card frames' clean-up lifts to 255). It reuses the card frames' cropper as it is (`crop_card_frames.py`:
  alpha clean, light-edge erode, defringe, cut by connected parts) and centres all 12 on one 488 × 201 canvas. The
  manifest (`assets/ui/plaques/manifest.json`, licence "the owner's own art") records per plaque its hash, the dark
  panel, the clear text box and the nine-slice margins (the margins stop where every column to the centre has the
  centre column's opaque top and bottom).
- **Nine-slice.** `PlaqueBox` (`src/presentation/hud/plaque_box.gd`, a StyleBox) draws nine pieces at a scale (plaque
  height / 201): the corners and the end-clusters keep their shape, the plain middle stretches across, a 6 px band in
  the middle of the dark panel stretches down only if content is taller. One set of margins for all 12
  (`Plaques.SLICE_*` = 167 / 101 / 144 / 94 px, covering every plaque's own margins), one text box
  (`Plaques.CONTENT` = 162, 58, 175 × 92, inside every plaque's clear panel). The PNGs import with mipmaps and the
  hosts draw with linear-mipmap filtering (they are shown at 0.4–0.9 scale).
- **Colours: one table.** `Plaques.of_family` is `CardFrames.frame_of`: a plaque's colour is the card frame of the
  same colour. A card's plaque uses `CardFrames.family` (epic gold, cursed violet). Things that aren't cards:
  `Plaques.USE_FAMILY` (heal → healing/green, reroll → economy/amber, cleanse → curse/violet, Leave → time/silver,
  shards and chest → economy, overclock → fire, cleanse reward → healing, banner → epic/gold) and
  `Plaques.GAMBLE_FAMILY` (the shrine's stats). A combo has only its own colour: `Plaques.nearest` picks the plaque
  whose tint is closest.
- **Where they are used.** The item / pickup pop-up (`ItemCard`, 600 × 132; a long ability sentence grows the plaque
  in steps to at most 960 × 164, uniformly, nothing stretched), the combo pop-up (`ComboCard`, placed above the item
  plaque), the HUD combo badges (a 96 px plaque around each pair icon), event choices (`EventPanel`: stacked 1060 × 180
  plaques, title and cost on the left, reward and curse on the right; lines step down together until they fit), the
  shop's heal / reroll / cleanse and salvage rows (`ShopTile`, 90 px plaques; the stock keeps the crystal card frames),
  the shrine's result (`GambleCard`, 560 × 140), the phase / "New: X" banner (`PhaseHud`, a 96 px plaque that grows
  with its line). The crystal pick cards are unchanged.
- **Not done:** the boss bar's "PHASE SHIFT" stays a plain label beside the stagger meter (a plaque there would sit on
  top of the boss bar's slab); the owner may ask for it.
- **Build picker (R2, then R2b).** The owner's art arrived during the step (lead message, PLAN R2b), so the Cold-glass
  stand-in was replaced by it: `scripts/art/crop_build_art.py` cuts
  [`build_title_plaque.webp`](../refs/build_title_plaque.webp), [`build_card_frames.webp`](../refs/build_card_frames.webp)
  and [`build_emblems.webp`](../refs/build_emblems.webp) (all transparent) the same way into
  `assets/ui/build_picker/` (the folder is not `build/`: the repo's `.gitignore` ignores every `build/`). `BuildArt`
  (`src/presentation/menus/build_art.gd`) is the one table to remap (weapon → frame, emblem, accent; the emblem and
  text boxes inside the frames' dark panel; the title box in the plaque). The picker: the menus' Cold-glass theme
  and backdrop (`MenuStyle`, `MenuBackdrop`), the title ("UI_CHOOSE_BUILD") inside the title plaque, each `BuildCard`
  = its frame (scale 0.6, 417 × 588) + its emblem + name, hairline, description and damage drawn by the game, each
  line stepping down to fit. Appear: rise and fade in, staggered. Focus: the card lifts 12 px, frame and emblem
  brighten, the emblem grows 6 %. The cyan/magenta echo trail, landing glitch, grid backdrop and title glitch are
  gone. Keyboard / mouse / pad code is untouched.

## Commands
```
python3 scripts/art/crop_plaques.py --check
python3 scripts/art/crop_build_art.py --check
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/presentation/test_plaques.gd,res://tests/content/test_plaque_assets.gd,res://tests/content/test_build_art_assets.gd,res://tests/content/test_card_frame_assets.gd,res://tests/unit/presentation/test_event_views.gd,res://tests/unit/presentation/test_status_visuals.gd,res://tests/unit/presentation/test_item_cards.gd,res://tests/unit/presentation/test_gamble_views.gd,res://tests/unit/presentation/test_ui_polish.gd,res://tests/unit/presentation/test_hud_style.gd,res://tests/unit/presentation/test_shop_views.gd,res://tests/unit/presentation/test_card_frames.gd,res://tests/unit/presentation/test_reward_views.gd,res://tests/e2e/test_e2e_events.gd,res://tests/e2e/test_e2e_shop.gd,res://tests/e2e/test_e2e_gamble.gd,res://tests/e2e/test_e2e_combo.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_difficulty_curve.gd,res://tests/e2e/test_e2e_ui_polish.gd,res://tests/e2e/test_e2e_abilities_ab.gd,res://tests/e2e/test_e2e_hud_style.gd,res://tests/e2e/test_e2e_spanish.gd,res://tests/e2e/test_e2e_floor.gd,res://tests/e2e/test_e2e_rewards.gd \
  -gexit
# screenshots (renderer needed), empty XDG_DATA_HOME, each under timeout 300:
XDG_DATA_HOME=<empty dir> VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 300 xvfb-run -a \
  -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/plaques.gd
# and the same with 1280x720
```
The full suite was not run (CLAUDE.md: agents run lint and the tests of what they touched; the lead runs one full
suite per wave).

## Raw output
```
$ python3 scripts/art/crop_plaques.py --check
check: 0 file(s) differ
$ python3 scripts/art/crop_build_art.py --check
check: 0 file(s) differ

$ gdformat --check src scripts tests && gdlint src scripts tests
620 files would be left unchanged
Success: no problems found

$ godot ... -gtest=<the 26 files above> -gexit      (ANSI colours stripped)
res://tests/unit/presentation/test_plaques.gd
10/10 passed.
res://tests/content/test_plaque_assets.gd
8/8 passed.
res://tests/content/test_build_art_assets.gd
3/3 passed.
res://tests/content/test_card_frame_assets.gd
6/6 passed.
res://tests/unit/presentation/test_event_views.gd
6/6 passed.
res://tests/unit/presentation/test_status_visuals.gd
4/4 passed.
res://tests/unit/presentation/test_item_cards.gd
6/6 passed.
res://tests/unit/presentation/test_gamble_views.gd
5/5 passed.
res://tests/unit/presentation/test_ui_polish.gd
14/14 passed.
res://tests/unit/presentation/test_hud_style.gd
14/14 passed.
res://tests/unit/presentation/test_shop_views.gd
6/6 passed.
res://tests/unit/presentation/test_card_frames.gd
5/5 passed.
res://tests/unit/presentation/test_reward_views.gd
8/8 passed.
res://tests/e2e/test_e2e_events.gd
1/1 passed.
res://tests/e2e/test_e2e_shop.gd
2/2 passed.
res://tests/e2e/test_e2e_gamble.gd
1/1 passed.
res://tests/e2e/test_e2e_combo.gd
1/1 passed.
res://tests/e2e/test_e2e_builds.gd
8/8 passed.
res://tests/e2e/test_e2e_pad_menus.gd
5/5 passed.
res://tests/e2e/test_e2e_difficulty_curve.gd
1/1 passed.
res://tests/e2e/test_e2e_ui_polish.gd
1/1 passed.
res://tests/e2e/test_e2e_abilities_ab.gd
2/2 passed.
res://tests/e2e/test_e2e_hud_style.gd
1/1 passed.
res://tests/e2e/test_e2e_spanish.gd
2/2 passed.
res://tests/e2e/test_e2e_floor.gd
2/2 passed.
res://tests/e2e/test_e2e_rewards.gd
3/3 passed.
Scripts              26
Tests               125
Passing Tests       125
Asserts            5576
Time              133.835s
---- All tests passed! ----

(test_plaques.gd's log line)
    item plaques grown for a long sentence (height px): ["en aegis 148", "en arc_field 156", "en blink 148",
    "en bomb_lobber 164", "en combo_sword 140", "en drone_buddy 164", "en flame_trail 140", "en frost_nova 164",
    "en orbit_blades 156", "es aegis 164", "es arc_field 164", "es blink 164", "es bomb_lobber 164",
    "es combo_sword 140", "es drone_buddy 164", "es flame_trail 148", "es frost_nova 164", "es orbit_blades 164",
    "es pulse_gun 148"]
```
Failures on the way, pasted as they were and fixed before the run above:
```
[Failed]: [707.477600097656] expected to be < than [420.0]:  a small card      (test_item_cards: the plaque's
[Failed]: [489.320983886719] expected to be < than [130.0]:  a small card       minimum size was added twice)
[Failed]: ARRAY(["en aegis", "en arc_field", "en blink", ...]) != ARRAY([]).     (ability sentences too long for
                                                                                  the 600 x 132 item plaque)
[Failed]: es heal 'Tienes la vida al máximo'                                     (service tiles 300 px → 360 px)
[Failed]: es reroll 'No queda nada que renovar'
[Failed]: en aether_shell / Mod fits  (and every salvage row)                    (tile 84 px → 90 px, title size
                                                                                  also limited by height)
```

Screenshots:
```
$ ... --resolution 1920x1080 -s scripts/shots/plaques.gd     (first run, while the test run above shared the CPU)
exit 124
plaques: renderer=forward_plus
plaques: res://build/shots/v0.6.1/plaques/01_build_en_1920x1080.png
plaques: res://build/shots/v0.6.1/plaques/01_build_es_1920x1080.png
$ ... --resolution 1920x1080 -s scripts/shots/plaques.gd     (second and third runs)
exit 124
plaques: renderer=forward_plus
$ ... --resolution 1280x720 -s scripts/shots/plaques.gd
exit 124
plaques: renderer=forward_plus
plaques: res://build/shots/v0.6.1/plaques/01_build_en_1280x720.png
plaques: res://build/shots/v0.6.1/plaques/01_build_es_1280x720.png
```
Every run hit the 300 s timeout (exit 124) before the HUD, event and shop shots: lavapipe on a CPU shared with other
agents' test and screenshot runs. The 1920 × 1080 build shots are from the first run, taken while the art lived
in `assets/ui/build/` (the same bytes: the crop `--check` above); the 1280 × 720 ones from the final script.

| File | What |
|---|---|
| [`plaques_01_build_en_1920x1080.png`](plaques_01_build_en_1920x1080.png) | The real build picker, opened with Enter from the main menu: the title plaque, Blade focused (lifted, bright), Gun idle |
| [`plaques_01_build_es_1920x1080.png`](plaques_01_build_es_1920x1080.png), [`plaques_01_build_es_1280x720.png`](plaques_01_build_es_1280x720.png) | The same in Spanish |
| 02_hud, 03_event, 04_shop (en, es; 1920 × 1080 and 1280 × 720) | **NOT YET RUN** (renderer too slow here, above); `scripts/shots/plaques.gd` writes them |

## Result
| Check | Measured |
|---|---|
| 12 plaques, alpha, 488 × 201, hashes, no white fringe, manifest both ways; shared nine-slice covers every plaque's clusters; the stretched middle columns are plain; the text box inside every clear panel | pass (`test_plaque_assets.gd`, 8 tests) |
| Build art: 5 pieces, hashes, alpha, sizes, the text / emblem / title boxes inside the dark panels | pass (`test_build_art_assets.gd`, 3 tests) |
| Nine-slice: corners and clusters at the plaque's scale, the middle stretches; colours from the card frames' table | pass (`test_plaques.gd`) |
| Text fits, en + es: every item, stat card and ability on the item plaque (19 of them on a grown plaque, list above), every combo, every shrine line, every salvage name and detail, heal / reroll / cleanse, every event choice of all 8 events (and the stack under 1080 px), both build cards, the title | pass (`test_plaques.gd`) |
| e2e through `main.tscn`: events, shop, shrine, combo, build picker (keyboard, pad, stick, mouse), pad menus, Spanish, floor, rewards | pass (13 e2e files) |
| Full suite | not run (agent rule; the lead's wave run) |

## Interpretation
- The layout is the 1920 × 1080 base stretched as a whole (`canvas_items`), so one fit check covers 1280 × 720; the
  smallest size a plaque's text may step down to is 10–11 px at the base (about 7 px on a 720p window: event lines,
  salvage details); the sizes each text actually got were not logged. Legibility at 720p: **OWNER ONLY**.
- Ability sentences are long for a pop-up: the item plaque grows to 960 × 164 for most of them. A shorter pickup line
  for abilities would keep it at 600 × 132; the owner's call.
- Colour mapping, flagged: the plaque sheet's last row is gold, violet, slate, orange; the slate one is filed as
  `indigo` (the trinket family, whose card frame is blue-violet). Measured crystal hues: purple 268°, violet 270°
  (curse vs dash read alike), amber 29°, orange 15°, silver 214° / indigo 208° (both low saturation). The owner may
  remap in `CardFrames.FRAME` (one table for frames and plaques).
- Event choices changed from a row of cards to a stack of wide plaques (keys 1–3, arrows and pad unchanged; up/down
  already moved the focus).
- Look and feel of all of it: **OWNER ONLY**.
