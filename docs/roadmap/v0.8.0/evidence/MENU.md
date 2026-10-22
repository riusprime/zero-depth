# MENU: direction B "Ember stone" shipped; the crystal-shard cards retired (v0.8.0 Step MU)

- **Status:** RUN (tests and shots below); how it looks and feels is **OWNER ONLY**
- **Build:** the working tree of `v080-mu2` (cut from `claude/lucid-fermat-9wv2tf` at `bace713`) before the Step MU
  commit (the commit is that tree plus this file, the shot copies and the PLAN / PROGRESS rows); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`; shots on renderer `gl_compatibility` (Mesa llvmpipe,
  software GL under xvfb). This is not the owner's hardware.
- **Date:** 2026-10-14
- **Who ran it:** agent

The owner, O14 (verbatim in [`../PLAN.md`](../PLAN.md)): "we're just throwing away the shard cards…"; G2 pick
"menu style B" ([`MENU_G2.md`](MENU_G2.md), Ember stone).

## What changed (player-facing)
- **Cards.** Every pick card (altar, chest, the shop's stock, the Swap's card, the Codex's card) is a carved stone
  tablet (`StoneCard`, replaces `CrystalCard`): the icon in a round socket with a glowing inlay ring in its element's
  colour, the level badge top right, the title in capitals in its family's colour over a glowing groove, the
  sentence, a carved rarity gem over the rarity words, a gold rim inlay on epic and legendary cards, and the ember
  glow under the tablet (stronger for rarer cards). The focused card lifts, its glow grows, its lower edge lights up;
  the others are a little dimmer.
- **Plaques** (the item, combo, shrine, event, Ascension, shop and banner plaques; `PlaqueBox`) are stone slabs with
  a glowing groove in their colour (gold rim on the gold plaque); the **wand tiles** (Build page, Swap), the **HUD wand
  pips** (a ring in the family's colour), the **Codex tiles** (the picture in a ringed socket), the **achievement rows**
  and **toast** (gold rim when unlocked) and the **build picker** (stone tablets with the Blade's / Gun's symbol in a
  ringed socket, a stone title plaque) share the same slab (`StoneBox`).
- **Menus** (main menu, pause, Options, credits, Codex + Achievements, Build page, run recap, build picker; all
  through `MenuStyle`): the list sits on a chipped stone slab; the title has a glowing ember groove; the focused (or
  pressed) row is an ember-lit slab with a groove and an ember diamond beside it, a hovered row half lit; warm type.
  Panels (Options, credits, the Codex detail, the pause menu's shrine and threat panels) are slabs.
- **Backdrops** (`MenuBackdrop`): over the game, the game blurred into a warm dark with a low ember glow; the **main
  menu has its own backdrop**: a dark ember-lit stone wall/floor (slabs with seams and cracks, a warm glow breathing up
  from below, a vignette). Sparks drift up from the embers on both. **Reduced motion** stops the backdrop's clock:
  no moving sparks, no flicker or breathing. One full-screen shader pass, only while a menu shows.
- **Retired:** the owner's crystal frames, plaques and build-picker art (`assets/ui/cards`, `assets/ui/plaques`,
  `assets/ui/build_picker`, their manifests, crop scripts and asset tests, `CrystalCard`, `BuildArt`, the old
  Cold-glass highlight). They remain in git history. The credits' licence list was rebuilt
  (`scripts/content/build_credits.gd`: 4 entries, the three UI-art entries gone). World `ShardMesh` pieces (altars,
  orbs, shard gems, cores) and the shard currency icon are unchanged (out of scope).
- No new strings; fonts are the project's Atkinson Hyperlegible only.

## The mockup's known issues, fixed
| MENU_G2 issue | Fix | Checked by |
|---|---|---|
| A long sentence (Frost Nova in Spanish) ran into the rarity gem | The sentence's box ends 10 px above the gem; text steps down (`TextFit`); a sentence that still doesn't fit reflows the card (a smaller socket, the title higher) | `test_card_frames.gd`: every card en + es at ×1.2 (pick), ×0.92 (shop), ×1.0 (Codex), ×0.8 (Swap): fits, sentence above the gem, below the socket; `test_frost_nova_in_spanish_reflows_clear_of_the_gem` (its last line too) |
| The warm glow was close to the Hot heat colour | The ember is `#EBAE72` (saturation 0.51 vs Hot `#FFA63A` 0.77; value apart; hue 17° from Overclock) | `test_ember_stone.gd` `test_the_ember_glow_is_apart_from_the_heat_colours` |
| Focus for mouse and controller | Focus = lift + glow + lit lower edge + brighter face (not colour alone); rows: focus slab + ember diamond, hover half lit | `test_focus_is_visible_for_mouse_and_pad_under_every_colour_mode` (off, protanopia, deuteranopia, tritanopia) |
| Interface size | Layouts stay in the 1920 × 1080 base | `test_the_screens_fit_at_interface_size_110` (3 Spanish Frost Nova cards; the longest main menu) |
| Reduced motion | Backdrop clock held | `test_reduced_motion_stops_the_sparks_and_the_flicker` |

## Tests (run locally; no full suite, per CLAUDE.md)
```
gdformat --check src scripts tests && gdlint src scripts tests
```
```
843 files would be left unchanged
Success: no problems found
```
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
```
```
Scripts              86
Tests               577
Passing Tests       577
Asserts           1919400
Time              562.802s
```
(An earlier run of the same folder, made while the shot renders and a second Godot import ran on the same machine,
had 2 failures in `test_attack_visuals.gd` and `test_boss_signature_views.gd` (the Gatekeeper's stone spikes:
"one cluster a pillar" 0 vs 20). Both files pass alone (15/15) and in their folder order with the files before them
(62/62), on this tree and on `bace713`; the clean rerun above is 577/577. Reported, not fixed: not this step's code.)
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch -ginclude_subdirs -gexit
```
```
Tests               123
Passing Tests       123
```
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_achievements.gd,res://tests/e2e/test_e2e_arenas.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_codex.gd,res://tests/e2e/test_e2e_credits.gd,res://tests/e2e/test_e2e_events.gd,res://tests/e2e/test_e2e_floor.gd,res://tests/e2e/test_e2e_options.gd,res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_shell.gd,res://tests/e2e/test_e2e_shop.gd,res://tests/e2e/test_e2e_swap.gd,res://tests/e2e/test_e2e_wand_blade.gd,res://tests/e2e/test_e2e_wand_build.gd,res://tests/e2e/test_e2e_wand_shared.gd,res://tests/e2e/test_e2e_card_levels.gd,res://tests/e2e/test_e2e_hud_style.gd -gexit
```
```
Scripts              17
Tests                40
Passing Tests        40
Asserts             555
Time              225.062s
```
Not run locally: the full suite (CI shards on the PR). Tests removed with the retired art: the three asset tests
(`test_card_frame_assets.gd`, `test_plaque_assets.gd`, `test_build_art_assets.gd`); the suite's count drops by about
8 net, so `tests/MIN_TEST_COUNT` (1904) is the lead's to check against the next green verify.

## Shots (1920 × 1080, real screens, real input)
`scripts/shots/mu2_shots.gd` boots `main.tscn` (empty profile, no save) and walks the real game with key presses:
the main menu, the build picker, a Blade run on floor 1 with floor 3's eight-card wand posed (shot setup, as
`wand_build.gd`), the room's first reward opened on Frost Nova / Ember Edge / Cold Snap through the sim's own choice
state (shot setup), Right; Esc, Esc (pause); the Build row (Right ×2); the Codex row (shot setup: most of the Cards
page's first two sections met), Right ×2; E ×4 (Achievements). The world is held as a still under the live UI.
```
XDG_DATA_HOME=<empty folder> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mu2_shots.gd -- --lang=en
```
(then `--lang=es`), raw output (the engine's warnings, e.g. SSIL unavailable on the compatibility renderer, trimmed):
```
mu2: renderer=gl_compatibility lang=en
mu2: res://build/shots/v0.8.0/mu2/main_menu_en.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/build_picker_en.png (1920, 1080)
mu2: posed 8 cards in 8 slots
mu2: res://build/shots/v0.8.0/mu2/pick_en.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/pause_en.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/build_en.png (1920, 1080)
ERROR: Must be an ancestor of the control.
mu2: res://build/shots/v0.8.0/mu2/codex_en.png (1920, 1080)
ERROR: Must be an ancestor of the control.
ERROR: Must be an ancestor of the control.
ERROR: Must be an ancestor of the control.
mu2: res://build/shots/v0.8.0/mu2/achievements_en.png (1920, 1080)
mu2: done
mu2: renderer=gl_compatibility lang=es
mu2: res://build/shots/v0.8.0/mu2/main_menu_es.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/build_picker_es.png (1920, 1080)
mu2: posed 8 cards in 8 slots
mu2: res://build/shots/v0.8.0/mu2/pick_es.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/pause_es.png (1920, 1080)
mu2: res://build/shots/v0.8.0/mu2/build_es.png (1920, 1080)
ERROR: Must be an ancestor of the control.
mu2: res://build/shots/v0.8.0/mu2/codex_es.png (1920, 1080)
ERROR: Must be an ancestor of the control.
ERROR: Must be an ancestor of the control.
ERROR: Must be an ancestor of the control.
mu2: res://build/shots/v0.8.0/mu2/achievements_es.png (1920, 1080)
mu2: done
```
Exit code 0 both. The "Must be an ancestor" lines come with the Codex's page rebuild (the shot's re-open after the
setup, and Q/E paging): a focus-neighbour path set on a tile being rebuilt; not investigated in this step.

Copies in [`mu_shots/`](mu_shots/) (the G2 mockups stay beside them):

| Screen | English | Spanish |
|---|---|---|
| Main menu (its own ember backdrop) | [shipped_main_menu_en](mu_shots/shipped_main_menu_en.png) | [shipped_main_menu_es](mu_shots/shipped_main_menu_es.png) |
| Pick (Frost Nova, Ember Edge focused, Cold Snap) | [shipped_pick_en](mu_shots/shipped_pick_en.png) | [shipped_pick_es](mu_shots/shipped_pick_es.png) |
| Build page | [shipped_build_en](mu_shots/shipped_build_en.png) | [shipped_build_es](mu_shots/shipped_build_es.png) |
| Codex (Cards) | [shipped_codex_en](mu_shots/shipped_codex_en.png) | [shipped_codex_es](mu_shots/shipped_codex_es.png) |
| Pause | [shipped_pause_en](mu_shots/shipped_pause_en.png) | `build/shots/v0.8.0/mu2/pause_es.png` |
| Build picker | [shipped_build_picker_en](mu_shots/shipped_build_picker_en.png) | `build/shots/v0.8.0/mu2/build_picker_es.png` |

The Achievements page shots are in `build/shots/v0.8.0/mu2/` (not copied).

## Known limits
- Software GL in a container; colours, glow and the backdrop's speed on the owner's GPU (Forward+) will differ.
- The world under the pick in the shots is the Night Rocks biome (the run seed's first floor), so it reads blue.
- The look, the readability of the stone behind long sentences and the feel of the sparks: **OWNER ONLY**.

## Owner check
| Question | Answer | Date |
|---|---|---|
| Does the shipped Ember stone match the B you picked (menus, cards, Build page, Codex)? | OWNER ONLY | |
| The main menu's own backdrop (an ember-lit stone wall, sparks): keep, change? | OWNER ONLY | |
