# MENU_G2: which style replaces the crystal-shard cards and the Cold glass menus? (v0.8.0 Step MU, G2)

- **Status:** RUN (shots rendered); the pick is OWNER ONLY
- **Build:** the working tree of `v080-mu` (base `34742a1` on `claude/lucid-fermat-9wv2tf`) with this step's shot
  scripts, before its commit (the Step MU commit is that tree plus this file, the shot copies and the PROGRESS row);
  Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`; renderer `gl_compatibility` (Mesa llvmpipe,
  software GL under xvfb). This is not the owner's hardware.
- **Date:** 2026-10-14
- **Who ran it:** agent

The owner, O14 (verbatim in [`../PLAN.md`](../PLAN.md)): "we are also reworking the menu we're just throwing away the
shard cards we're gonna be using a different style that matches more the game fine I found that that's not exactly
aligned with the game". The world they should match: [`../../../art/look_reference.webp`](../../../art/look_reference.webp)
(dark weathered low-poly ruins, worn concrete, rusted metal and stone, warm fire light in a dark scene, chunky
faceted shapes).

**Nothing shipped changed.** The mockups are drawn by tool scripts only (`scripts/shots/mu_kit.gd`, its shaders
`mu_shaders.gd`, the driver `mu_shots.gd`, and one script per screen `mock_main_menu.gd`, `mock_pick.gd`,
`mock_build.gd`), all in code (canvas shaders and `_draw`), no new art, no new strings.

## The three directions (one line each on the trade-off)
| | Direction | Cards | Trade-off |
|---|---|---|---|
| **A** | **Salvage**: weathered gunmetal plates, rivets, scratches, rust creeping from the edges, spray-stencil capitals (Atkinson Bold, spaced and eroded), hazard-amber stripes and focus | a riveted metal tag with a punched hole, the family colour as worn paint on its top band, the rarity on a stamped strip with a painted tab; an epic or legendary card adds a hazard strip | The loudest match to the Ruins' wrecks and barrels, and the strongest focus (amber rim + glow); but the most texture behind text, and it reads "scrapyard" on the cold biomes (Frozen Shore, Starfall) |
| **B** | **Ember stone**: dark carved stone slabs with chipped bevelled edges, lit warm from below by embers, a few sparks rising in the backdrop | a stone tablet: a glowing inlay ring round the icon in the card's element colour, a groove under the title, a carved rarity gem; an epic or legendary card gets a gold rim inlay | One look with the shipped HUD (already "Ember stone", v0.5.5 A5) and the fire light of the reference; the element colour is the most visible of the three; but the stone is busy behind long sentences and the warm glow is close to the Hot heat colour |
| **C** | **Field kit**: minimal charcoal panels cut on two corners like kit pieces, a thin warm-orange edge light, a soft vignette, light spaced titles | a dark faceted plaque with the family colour as a slanted two-tone top band, a faceted hexagon icon frame in the element colour, a thin rarity rule and gem | The calmest and most readable (long Spanish sentences fit best), the cheapest to build and to keep consistent across screens; but the least "of the world": the ruins show only through the warm light and the facets |

Readability kept in all three: the rarity colour (PickSlot's common / rare / ability / epic / legendary colours) on the
rarity gem and words, the card level badge ("Lv 1"), the element colour on the icon (and B's inlay), the family colour
(CardFrames' table) on the band / paint / title, and focus as a lift plus the direction's rim and glow, the others
dimmed. Controller focus is the same mark (the pages are driven by focus, not the mouse).

## Art that would make each better (none needed to build it)
- **A:** a tileable painted-gunmetal texture with rust (CC0, e.g. ambientCG metal plates) to replace the shader noise;
  a stencil display font under the OFL (a real stencil face, e.g. from Google Fonts) for titles only; bolt and rivet
  decals.
- **B:** a dark slate or basalt texture with cracks (CC0) for the slabs; an ember particle sprite (the VFX atlases may
  already serve); per-element inlay glyphs.
- **C:** none. Optional: a faceted icon-frame mesh rendered to a sprite, and a fine grain texture.

## Shots (1920 × 1080, fixed seed, real data)
All from the same paused frame: a Blade run on seed `20261010` (the first seed from `Main.STAGE_SEED` 20261006 whose
first floor is the Ruins), floor 3's wand posed with the eight cards of the v0.7.0 Build page shots (two triggers).
The pick shows Frost Nova (a new ability), Ember Edge (common mod) and Cold Snap (rare mod) through
`PickPanel.card_face`, Ember Edge focused, with the HUD; the Build page the live `WorldReader.wand()` and its game-made
read-back, tile 3 focused; the main menu the shipped rows for a fresh profile (this debug build shows Playground and
Galleries), Play focused. The main menu stands over a blurred floor; the shipped main menu has an empty screen
behind it, so the picked direction would get a menu backdrop of its own.

Copies in [`mu_shots/`](mu_shots/) (A/B/C × 3 screens in English, plus Spanish of one screen per direction):

| | Main menu | Card pick | Build page | Spanish |
|---|---|---|---|---|
| A Salvage | [en](mu_shots/a_salvage_main_menu_en.png) | [en](mu_shots/a_salvage_pick_en.png) | [en](mu_shots/a_salvage_build_en.png) | [pick es](mu_shots/a_salvage_pick_es.png) |
| B Ember stone | [en](mu_shots/b_ember_stone_main_menu_en.png) | [en](mu_shots/b_ember_stone_pick_en.png) | [en](mu_shots/b_ember_stone_build_en.png) | [Build es](mu_shots/b_ember_stone_build_es.png) |
| C Field kit | [en](mu_shots/c_field_kit_main_menu_en.png) | [en](mu_shots/c_field_kit_pick_en.png) | [en](mu_shots/c_field_kit_build_en.png) | [main menu es](mu_shots/c_field_kit_main_menu_es.png) |

The other Spanish shots are in `build/shots/v0.8.0/mu/` (not copied).

## Command
Run from the project folder, one per screen (they ran in parallel):
```
XDG_DATA_HOME=<empty folder> timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 \
  -s scripts/shots/mock_<main_menu|pick|build>.gd
```

## Raw output
`mock_main_menu.gd` (the `mu:` lines; the engine's warnings, e.g. SSIL unavailable on the compatibility renderer, trimmed):
```
mu: renderer=gl_compatibility
mu: run seed 20261010
mu: posed 8 cards in 8 slots
mu: res://build/shots/v0.8.0/mu/a_salvage_main_menu_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/a_salvage_main_menu_es.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/b_ember_stone_main_menu_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/b_ember_stone_main_menu_es.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/c_field_kit_main_menu_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/c_field_kit_main_menu_es.png (1920, 1080)
mu: done
```
Exit code 0.

`mock_pick.gd` (the `mu:` lines; the engine's warnings, e.g. SSIL unavailable on the compatibility renderer, trimmed):
```
mu: renderer=gl_compatibility
mu: run seed 20261010
mu: posed 8 cards in 8 slots
mu: res://build/shots/v0.8.0/mu/a_salvage_pick_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/a_salvage_pick_es.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/b_ember_stone_pick_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/b_ember_stone_pick_es.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/c_field_kit_pick_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/c_field_kit_pick_es.png (1920, 1080)
mu: done
```
Exit code 0.

`mock_build.gd` (the `mu:` lines; the engine's warnings, e.g. SSIL unavailable on the compatibility renderer, trimmed):
```
mu: renderer=gl_compatibility
mu: run seed 20261010
mu: posed 8 cards in 8 slots
mu: res://build/shots/v0.8.0/mu/a_salvage_build_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/a_salvage_build_es.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/b_ember_stone_build_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/b_ember_stone_build_es.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/c_field_kit_build_en.png (1920, 1080)
mu: res://build/shots/v0.8.0/mu/c_field_kit_build_es.png (1920, 1080)
mu: done
```
Exit code 0.

## Known limits of the mockups
- Software GL in a container: the frame is a still taken once the run is paused (the 3D world stops drawing while the
  mockups are laid over it); colours and glow on the owner's GPU (Forward+) will differ a little.
- B: the longest sentence (Frost Nova, an ability) runs down to the rarity gem; a built B card would grow or step the
  text down further.
- The title is the `{{TITLE}}` placeholder (the game is untitled).

## Owner pick
| Screen | Pick (A / B / C or a mix) | Date |
|---|---|---|
| Menus, cards, Build page | OWNER ONLY | |
