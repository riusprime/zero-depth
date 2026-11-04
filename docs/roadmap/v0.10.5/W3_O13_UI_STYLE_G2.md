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

## Round 2 (W3-O13b): four styles after the owner's references

Round 1 was rejected. The owner, 2026-11-04: "the new UIs you built are ugly, look built badly, like a kid that just
started programming, we should discard all these childish rounded gradient boxes AI slop that you build. i am
attaching some mock up UI references for you to know the actual style to follow, this does not mean that you have to
exactly copy it … the objective is to achieve something layered, structured, polished and not AI slop. the hp bar
should be a continuous bar not split in parts, it should be like the fourth picture 'runic observatory'. make 4 new
mock ups." The references are in [`ui_refs/`](ui_refs/). **Decide:** Slate, Eclipse, Astral, Observatory, or a mix.
Nothing here is built. The game UI is unchanged.

**How the shots were made.** `scripts/shots/mock_ui_refs.gd` is a prototype, not game code. Its kit is in
`scripts/shots/mock_ui2/`: `kit.gd` (type, lines, shapes, panels, cards), `parts.gd` (buttons, bars, controls),
`screens.gd` (the layouts) and `glass2.gd` (the blur behind panels). It reuses round 1's plumbing: the dev stage run
(fixed seed, floor 1, 120 shards, half HP) and the real shop opened with E, so the stock and prices are the sim's.
Then it hides the game's own CanvasLayers and draws each style over the same frame. Nothing of round 1's look is
reused: no rounded rectangles, no gradient fills on panels, no glow strokes. Straight lines are 1 px rects on whole
pixels; only diagonals and curves are antialiased. Titles are Cinzel (`assets/fonts/cinzel/`, weight axis 500–700,
letter-spaced uppercase); body text is Atkinson Hyperlegible. Icons are the game's own (`ItemIcons`,
`AbilitySquareIcons`, `ElementGlyphs`, the Futhark strokes of `RunicGlyphs`). Ornaments (diamonds, four-point stars,
compass stars, crescents, ticks, astrolabe arcs) are vector strokes drawn at full resolution. The Eclipse stone grain
is a `FastNoiseLite` texture made in code. Every word is an existing translated key. The heat (46%), the danger (×2,
62%) and the 2.4 s cooldown on Q are set for the shot; the minimap is a sketch of rooms in each style's frame.
1920×1080, English, plus the shop in Spanish. Run on the owner's PC (RTX 3060) from base `c3ae338f` plus this step's
scripts:

```
godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/mock_ui_refs.gd
```

Files (in `build/shots/v0.10.5/w3o13b/`, not tracked): `<style>_hud.png`, `<style>_shop.png`, `<style>_pause.png`,
`<style>_pick.png`, `<style>_shop_es.png`, `<style>_comp.png` (the component strip, 1920×200), `<style>_sheet.png`
(the four screens 2×2 at half size, HUD and shop on top, pause and pick below, the strip under them), and
`compare_shops.png` (the four shops side by side: Slate, Eclipse, Astral, Observatory). The strip shows, left to
right: the HP bar, buttons (primary, secondary, focus, disabled), ability medallions (ready, cooling, ready), a
tooltip, a slider, a toggle, and a focused card's top-left corner at 2.2×.

**Shared by all four**, so the choice is about the look, not the layout:
- **Grid and type scale.** 8 px grid. Cinzel 44 / 40 / 34 / 26 / 21 / 19 / 15 / 13 / 11 (screen title, altar
  title, panel title, options title, menu, card title, plate and tab, field label, small caps). Atkinson 16 / 15 /
  14 / 13 / 12 (card sentence, hints and buys left, gain line, key caps, rarity line). Tracking about 0.3 em on
  titles and 0.2 em on labels.
- **Palette family.** Deep slate/navy fills, silver ornaments, one moon-blue accent; no brown, no saturated cyan or
  mint, no rainbow. Heat is the only warm colour (a muted amber), and a price you can't pay is a muted rose. Rarity
  is a small diamond before the rarity line (common grey `#8C98A8`, rare blue `#8FB8E8`, epic lilac `#B4A2E6`, ability
  `#C9D8EE`, legendary pale gold `#E2CB8E`), not a coloured frame.
- **Card.** Name on top, the icon in a medallion, the gain line and sentence, a separator, the rarity line, the price
  at the bottom. **Focus:** the card lifts 10 px, its fill brightens, its edge turns silver-white and the style's
  focus ornament appears. Unfocused cards stay recessed: a darker fill, a dim edge, text at 82%.
- **Plates.** Long slim plates: the icon at the left, a letter-spaced label, the price at the right.
- **HUD, unboxed.** At the top: the floor line between two stars, the timer, a danger hairline with a diamond marker,
  the wallet over a thin-framed minimap. At the bottom left: a **continuous** HP bar (one unbroken fill on an ink bed
  in a hairline frame, a bright tick at the fill's end) with a medallion at its left end, and the slim heat bar after
  it. At the bottom right: three ability medallions with a cooldown arc. A faint ink wash under the top and bottom
  rows keeps them readable over the lit floor.

### Slate (after 01 Moonlit Slate)

**What it is.** The quietest. Flat, square-cornered slate panels at 86% over a soft blur of the world, one hairline
border, a recessed inner shadow, a 1 px highlight on the top edge. No ornaments beyond a small Futhark rune before each
title. Icons stand bare on the card with a short rule under them. Ability slots are framed squares.

| Token | Hex | Use |
|---|---|---|
| fill / fill_hi | `#101824` 86% / `#1A2536` 95% | panels, cards / focused card, plate |
| line / line_hi | `#33435A` / `#AFC3DC` | borders / focused borders |
| accent | `#8FB8E8` | focus bar, slider fill, shard |
| metal | `#A7B4C6` | ornaments, medallions |
| text / dim | `#E3E9F1` / `#8593A8` | body / secondary |
| HP / heat / too poor | `#8DB4E2` / `#CFA06E` / `#D07C86` | meters, prices |

- **Lines and ornaments.** One 1 px border per panel, an inner shadow 5–6 px deep, vertical hairline dividers.
- **Focus.** A 3 px moon-blue bar down the left edge, a lighter fill, a pale border (cards, menu lines). The primary
  button has a blue wash inside its frame.
- **HP medallion.** A diamond with the rune inside; the bar ends in a short tick.
- **Build cost (whole UI).** Low. Nearly all of it is a `StyleBoxFlat` with a 1 px border, plus one extra draw for the
  left focus bar and the inner shadow (or a 9-slice), and one blur shader. About 2–3 steps.
- **Honest gaps.** It is the closest to a "default dark UI": clean, but the least runic of the four. The bare icons are
  the game's flat icons, so the cards look emptier than 01's.

### Eclipse (after 02 Carved Eclipse)

**What it is.** Carved stone tablets. Every panel, card and plate is a slightly chipped polygon (uneven corner cuts,
small breaks along the edges) filled with a fine stone grain, its inner edge bevelled (lit top-left, shaded
bottom-right). Plates are arrow-ended. Card medallions are carved hollows with an eclipse ring and a bright crescent
arc. Ability icons stand free on a faint disc with a chevron under them.

| Token | Hex | Use |
|---|---|---|
| fill / fill_hi | `#141920` 93% / `#1C222B` 96%, grain 10% | tablets / focused |
| line / line_hi | `#6A7686` / `#DCE8F7` | edges / focused edge |
| accent | `#A9C7EC` | sliders, gain line, shard |
| metal | `#B9C4D2` | ornaments |
| text / dim | `#E9EDF2` / `#8E97A4` | body / secondary |
| HP / heat / too poor | `#9CC0E8` / `#D4A26C` / `#D07C86` | meters, prices |

- **Lines and ornaments.** A 1 px edge, a 1 px bevel 3 px in, a faint second contour 7–9 px in.
- **Focus.** A 2 px icy edge, a 1 px halo contour 5 px outside, and two small four-point sparks at opposite corners.
  Menu focus is a double chevron and a fading underline.
- **HP medallion.** A small carved stone with the rune; a diamond end cap.
- **Build cost (whole UI).** Medium-high. The tablets need 9-slice textures (grain, bevel and chips baked in) or a
  panel shader; the arrow plates need their own textures; the chipped outline must not stretch on resize. About 4
  steps.
- **Honest gaps.** The ref's tablets are thick, illustrated rock with depth; this is a flat, subtle version (grain and
  a 1 px bevel). Getting closer needs painted 9-slice art. The focused card's edge can look jagged at the chipped
  corners.

### Astral (after 03 Astral Veil)

**What it is.** The most ornamental and the least boxed. Panels have no border, only a light ink veil between two
fading hairlines. Cards are crests: the top shoulders sweep up to a point under a small crescent finial, the sides are
straight, the bottom ends in a keel. A dotted inner ring in each medallion, four-point stars as markers, long lozenge
buttons with a star at each tip. Lilac-tinted silver.

| Token | Hex | Use |
|---|---|---|
| fill / fill_hi | `#0D1120` 84% / `#141A2F` 92% | cards / focused |
| line / line_hi | `#6E76A0` / `#E4E6FF` | contours / focused |
| accent | `#B5BDF0` | sliders, gain line, shard |
| metal | `#C9CCE6` | ornaments |
| text / dim | `#ECEEFA` / `#9095B4` | body / secondary |
| HP / heat / too poor | `#B4BFF0` / `#D6A878` / `#D88A9A` | meters, prices |

- **Lines and ornaments.** A 1 px contour and an inner contour 6 px in at 22–35%; crescents and four-point stars.
- **Focus.** The contour brightens (1.4 px), a second contour sits 6 px outside at 25%, the finial lights, four small
  stars ring the medallion, and two sparks mark the card's shoulder and foot. Menu focus is a star and a tapered
  streak.
- **HP medallion.** A ring with a four-point star; the bar ends in a star.
- **Build cost (whole UI).** High. The crest shape can't be a `StyleBoxFlat`: it needs a custom-drawn panel, or a
  9-slice that takes care at the crest; every button is a lozenge texture. About 5 steps.
- **Honest gaps.** The ref's light wisps and glowing edges were left out on purpose (the owner rejected glow), so it is
  plainer than 03. Without a panel border, the options rows depend on the darker world under them.

### Observatory (after 04 Runic Observatory)

**What it is.** An instrument. Double-line frames (an outer 1 px line, an inner line 5 px in) with cut corners, a
diamond and a short bracket at each corner, engraved astrolabe arcs with a degree scale in the panel corners, compass
stars, and medallions with two rings and a tick scale. Plates are pointed at both ends, with a double outline and a
diamond off each tip.

| Token | Hex | Use |
|---|---|---|
| fill / fill_hi | `#0E1523` 88% / `#152034` 95% | panels, cards / focused |
| line / line_hi | `#53627B` / `#CBD9EE` | frames / focused frames |
| accent | `#8DB6E6` | the focus jewel, sliders, shard |
| metal | `#A3AEBF` | ornaments, ticks, astrolabe (at 16%) |
| text / dim | `#E2E8F1` / `#7E8BA0` | body / secondary |
| HP / heat / too poor | `#93BCEA` / `#D0A06C` / `#D07C86` | meters, prices |

- **Lines and ornaments.** Two 1 px frames 5 px apart (the inner one at 30–50%), corners cut 10–12 px; ticks every
  7.5°, long ticks at the cardinal points.
- **Focus.** Both frames turn silver-white, a jewel (a diamond with a blue core) sits on the top edge between two
  short rules, and a small diamond sits on the bottom edge. Menu focus is a jewel in a ring and a framed row.
- **HP medallion.** As in 04: a double ring with a tick scale and a compass star; the bar ends in a diamond and a rule.
- **Build cost (whole UI).** Medium. The double frame and cut corners are one 9-slice (or a small `StyleBox` script);
  the corner diamonds and the focus jewel are two small textures; the medallions and the astrolabe are drawn once into
  textures. About 3–4 steps.
- **Honest gaps.** The ref's illustrated icons (crystal, vortex, ring) are richer than the game's flat icons in the
  medallions; matching them needs new icon art (an art request), not code. The astrolabe is engraved line work, not
  the ref's brass instrument.

### What all four do worse than the refs

- **Icons.** The refs' icons are painted illustrations; these use the game's own flat icons (two shop cards even share
  one). Every style would look closer to its ref with a set of line-art icons drawn for the medallions.
- **Depth.** The refs fake light and material (glow, metal, polished stone). These stay flat on purpose (no glow, no
  big gradients), so they read cleaner and plainer.
- **The world.** Night Rocks is bright orange under the menus. The vignette darkens it, but the refs' scenes are darker
  to start with.
- **Not checked:** the other biomes, 1280×720, a pad, TV distance, the colour-blind modes. Feel and taste are the
  owner's.

### Lead's recommendation (round 2)

**Observatory**, the one the owner pointed at for the HP bar. It is the most layered (two frames, corner ornaments,
instrument scales) while staying readable, its focus is the clearest (frame plus jewel), and its cost is medium. Two
borrowings are worth considering: Slate's left focus bar on menu lines (the quickest focus to read), and Astral's crest
shape for the altar's cards only, so a free pick feels different from a purchase. Eclipse is the most atmospheric, but
it needs painted 9-slice art to reach its ref. Whichever wins, a set of line-art medallion icons is the biggest single
gain over these shots.

Owner's pick: OWNER ONLY
