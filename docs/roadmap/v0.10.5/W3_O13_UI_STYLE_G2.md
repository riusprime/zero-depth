# v0.10.5 W3-O13 G2: three UI styles

Follows the W3-O9 shop G2 ([`W3_O9_SHOP_G2.md`](W3_O9_SHOP_G2.md)). The owner, 2026-11-04: "For the shop I like mock
up A, in shape, but colors and how it shows still ugly, the brown background, buttons are not visible, it doesn't
quite match the rune ethereal kind of theme of the game, we need to work on a UI rework, can you make 3 new mockups
that would also apply to the rest of UI elements that changes this, the brown background is not the way to go, these
3 different new UI mockups should differ in style so we have real options, don't present really close to each other
styles." **Decide:** Veil, Obsidian, Sigil, or a mix (for example one style's panels with another's focus rule).
Nothing here is built. The game UI is unchanged.

**How the shots were made.** `scripts/shots/mock_ui_styles.gd` (a prototype, not game code; its drawing kit is in
`scripts/shots/mock_ui/`) starts the dev stage run (fixed seed `Main.STAGE_SEED`, floor 1, 120 shards, half HP) and
opens the real shop by the stall with E, so the sim's stock and prices are real. Then it hides every game
`CanvasLayer` (the real HUD, hints and panels) and draws each style's screen over the same game frame. Every piece is
drawn with CanvasItem calls from the game's own parts: the Atkinson Hyperlegible font, `ItemIcons`,
`AbilitySquareIcons`, `ElementGlyphs`, the Futhark strokes of `RunicGlyphs` with `RuneCipher`, and the shard. Two
small shaders are written in the script: the glass blur and the sigil vignette. No new texture files. Every word is
an existing translated key. The HUD's heat (46%) and danger (×2, 62%) are set for the shot. The minimap is a sketch
of rooms inside each style's frame, not the real map. 1920×1080, English, plus the shop in Spanish:

```
godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/mock_ui_styles.gd
```

Files (in `build/shots/v0.10.5/w3o13/`, not tracked): `<style>_hud.png`, `<style>_shop.png`, `<style>_pause.png`,
`<style>_pick.png`, `<style>_shop_es.png`, `<style>_sheet.png` (the four screens in a 2×2 grid: HUD and shop on top,
pause and pick below), and `styles_compare.png` (the three shops side by side, in the order Veil, Obsidian, Sigil).
Styles: `veil`, `obsidian`, `sigil`. Each shop keeps layout A's shape: a header with the title, buys left and the
wallet; the 4 cards in a row, each with a price tag; wide Heal and Reroll buttons with big prices; and the hint line.
The first card is focused.

## Veil: dark glass and rune light

**What it is.** Panels are dark, see-through blue-black glass that blurs the world behind it. Thin cyan light lines
with a soft glow run round them, and a violet light sits on each panel's lower edge. Shapes are soft: rounded
rectangles, pill buttons, round pad glyphs. Headings are white, uppercase and widely spaced. Body text is plain
white. It reads as cool, light and modern, like light seen through ice. The runes stay in the world and the hub; the
UI carries their light, not their letters.

| Token | Hex | Use |
|---|---|---|
| glass fill | `#0A1322` at 55% over the blur | panels, cards, slots |
| line | `#6FE7FF` | panel and button borders, buys-left pips |
| line 2 | `#A98BFF` | lower-edge light, cooldown sweep, the title's underline |
| text / dim | `#EAF6FF` / `#93ADC6` | body / secondary |
| focus | `#8FF6FF` | the focus glow and fill |
| HP / heat | `#FF5D78` / `#FF9F5A` | meters |
| gain / too poor | `#8CF5C0` / `#FF6B7A` | the gain line / a price you can't pay |

- **Materials and shaders.** One full-screen backbuffer blur (the screen texture at mip 4 to 4.5, tinted) masked to
  the rounded panel rectangles. Glow lines are three stacked strokes. The game would need one blur shader and one
  rounded-rect panel `StyleBox` (or a 9-slice), so it is cheap per frame.
- **Buttons and focus.** Every button is a pill, filled with its own colour at 16% and outlined in that colour (Heal
  is green, Reroll violet), so it reads as a button before it has focus. **Focus:** the outline turns to bright
  cyan, three times as thick, with a strong glow and a cyan fill. A focused card lifts 12 px. A menu item gains a dot
  on its left. Hover and pad focus use the same rule.
- **Readability.** The best of the three for body text: the dark glass gives every sentence a calm backing, even over
  the lit Night Rocks floor. Risk: on very bright biomes (Ruins, Frozen Shore) the blur lets more light through, so
  the tint may need to darken per biome. The thin lines can get lost at small sizes on a TV.
- **Build cost (whole UI).** Medium. One shader and one panel style replace the stone plate across the HUD, the
  panels and the menus. The cards need a new face (a rounded rect, the icon in a ring); the layout stays the same.
  About 3–4 steps: theme and panel, cards, HUD, menus. Also re-shoot every UI shot.

## Obsidian: carved obsidian and gold leaf

**What it is.** Panels are opaque, near-black obsidian with a faint violet tint and sharp 45° chamfered corners. Two
gold-leaf lines run round each frame, with heavy gold corner brackets. Engraved rune bands (the cipher of the game's
name) sit on the top and bottom edges of the big frames. Type is bold and uppercase, in gold or ivory, with a hard
drop shadow. Meters are segmented blocks. Slots and pad glyphs are diamonds. It reads as a carved relic: the most
contrast and weight of the three, and the closest to "a polished video game store".

| Token | Hex | Use |
|---|---|---|
| obsidian | `#0B0A10` → `#1A1722` (gradient) | panels, cards, buttons |
| gold | `#E3B65A` | frames, titles, borders, pips |
| pale gold | `#FFE3A1` | corner brackets, focus outline, focused fill (top) |
| deep gold | `#7A5A24` | meter segment edges |
| ivory / dim | `#F4ECD8` / `#A39882` | body / secondary |
| HP / heat | `#C8384A` / `#E8742C` | meters |
| gain / too poor | `#9BD88A` / `#FF5A4D` | as above |

- **Materials and shaders.** No shader needed: gradient polygons, gold strokes and rune strokes. In the game it would
  be a 9-slice obsidian frame (a small new texture, or drawn) and a rune-band strip.
- **Buttons and focus.** Unfocused buttons are raised obsidian slabs with a gold border and a coloured service line
  on top, so they read as buttons by shape. **Focus inverts:** the button fills with gold, its text turns black, and
  gold arrows point at it from both sides (menus). A focused card's title band fills with gold, its outline gets
  thicker and paler, and gold brackets stand beside it. This is the strongest focus of the three: it is visible
  from across a room and in greyscale.
- **Readability.** Very high contrast. The opaque panels hide the world completely, so text never fights the floor.
  Risk: it is the heaviest style. The HUD plates cover more of the playfield, and gold everywhere can crowd out the
  rarity colours (Epic violet, Rare blue) unless the inner card line keeps them.
- **Build cost (whole UI).** Medium to low. It is closest to today's structure (framed plates, just restyled), with no
  shader. Frame, buttons, segmented meters, diamond slots, the rune band and the new card face: about 3 steps.

## Sigil: light sigils, no panels

**What it is.** No boxes. Each screen dims the world with a radial vignette (darker at the edges). Every element is
drawn as glowing aurora-mint lines: a light rule with end nodes above and below a screen, cards as tall hexagons
pointed top and bottom, and buttons as wide pointed lozenges. The icons sit inside rune rings: the card's own name in
Futhark runes, round its icon. The HUD loses its plates. HP is a ring gauge with the number inside, heat a wide arc
of light at the bottom, danger a row of runes that light by tier, the slots are rings, and the minimap sits inside a
rune ring. Text glows faintly in its own colour. It reads as magic written on the air, the most "rune / ethereal" of
the three.

| Token | Hex | Use |
|---|---|---|
| aurora | `#8CFFE0` | all lines, rings, runes, titles |
| rose | `#FF9BD2` | cooldown sweep, second accent |
| text / dim | `#F5FFFC` / `#A6DCCF` | body / secondary |
| focus | `#D9FFF5` | the focus contour and node |
| HP / heat | `#FF7A9C` / `#FFC26B` | ring gauge / heat arc |
| vignette | `#000508` at 66% (centre) → 90% (edge) | behind every menu and panel screen |
| too poor | `#FF6B7A` | a price you can't pay |

- **Materials and shaders.** One vignette shader for the menu screens. Everything else is line work: glow strokes,
  rune rings, gradient fills inside the hex cards (dark, 84% at the top). In the game it would be mostly custom
  `_draw` code, not a theme.
- **Buttons and focus.** A button is a pointed lozenge with a light outline and a fill in its colour (Heal green,
  Reroll violet) that brightens toward the bottom. **Focus:** the contour turns white-mint with double glow. A card
  gets a second outer contour and a beam of light under it, and its rune ring brightens. A menu item's node becomes a
  ring, and a light bar runs under its text. Unfocused items are 60–75% bright, so focus reads by brightness, not
  colour.
- **Readability.** The weakest of the three. With no panel, a sentence sits on a dimmed but still busy world. The
  cards needed an 84% dark fill to stay legible, and small text (the hint line, tier lines) is the hardest to read.
  The HUD is the lightest on screen (it covers the least floor), but the ring HP gauge is less exact at a glance than
  a bar. The rune rings are decoration only: never the only carrier of meaning (PRESENTATION_CONTRACTS readability).
- **Build cost (whole UI).** High. Almost every widget becomes custom drawing (ring gauge, arc meter, hex cards,
  lozenge buttons, rune rings). Godot's `Theme` helps little, focus and hover need their own drawing, and the menus
  need a new spine layout. About 5–6 steps, plus more e2e and shot churn.

## Lead's recommendation

**Veil**, taking the focus rule from Obsidian. Veil drops the brown, fits the rune/ethereal world (cyan and violet
light are the hero's own `player_core` family and the shard's violet), and keeps every text on a calm backing. Its
buttons read as buttons when unfocused (each is filled in its own colour) at a medium cost. Obsidian's inverted gold
focus is the clearest focus of the three, and a Veil version of it (the focused button filled with bright cyan, dark
text) would make focus unmistakable on pad. Sigil is the most striking and the most "runic", but it costs the most and
reads the worst for card text; its rune ring round a card's icon could be borrowed as a detail on the Veil card.

## What none of them changes

The sim, the shop's rules and prices, layout A's shape and its focus order (cards row, then Heal and Reroll), the
keys (1-4, Enter or A, Esc or B, X and Y), hover and click, and the translated strings. The game's real UI is
untouched by this step.
