# v0.9.5 Step MM: the main menu, after the owner's pictures

Owner (2026-10-26): "make the main menu look closer to this" (`docs/art/reference/v0.9.5_main_menu.webp`), then
"Forget about the ingame render, use the image I sent this will be the logo for the game"
(`docs/art/reference/v0.9.5_logo.png`). A first live-3D scene was built and then dropped on that change; none of it is
in the commit.

## What was built
- `src/presentation/menus/stone_button.gd` (`StoneButton`, a `Button` drawn in `_draw`): hexagonal-ended plate, dark
  stone fill from one shared value-noise texture made in code, 2-4 cracks per button (seeded by its index), a bevelled
  rim, crystal shards at the right end (both ends when lit). Focused or hovered: blue rim, a soft glow of five
  expanding outlines, bigger shards. Pressed: a brief brighter flash. Disabled: dimmed, no blue. Label: the UI font,
  uppercase, `FontVariation.spacing_glyph` 5 px at 24 px (0.2 em). A mouse hover also takes the focus. It stays a
  BaseButton, so hover/disabled/focus work as the cursor (MC) reads them.
- `src/presentation/menus/main_menu.gd`: Continue, Play, Options, Credits, Exit (the `Quit` node and `UI_QUIT` key are
  kept; the English text is now "Exit", as the owner's picture), 24 px gap, plate 420 x 84 on the 1920 x 1080 base (the
  canvas stretch scales it). The logo sits above the column (640 px wide at 1080p; accessible name `tr("UI_TITLE")`).
  The ember `MenuBackdrop` is gone from the main menu; the owner's picture is behind (`TextureRect`, cover, anchored
  right, a drift of at most 1.2 % over 20 s, still under reduced motion). Hint and version label are subdued.
- `scripts/art/cut_menu_backdrop.py`: cuts both pictures (below). Outputs `assets/ui/menu/backdrop.png` (1920 x 1080)
  and `assets/ui/menu/logo.png` (1720 x 906, RGBA).
- Backdrop: everything left of x = 40 % is black and fades in over the next 10 %, so the picture's own buttons do not
  show. Logo: the near-white background is found by flood fill from the border (plus enclosed near-white areas over
  1500 px, the letter counters); highlights inside the letters stay opaque; round the logo the alpha comes from the
  distance to white and the blue glow is un-premultiplied.
- `tests/unit/presentation/test_ember_stone.gd`: the "no UI art" guard allows `assets/ui/menu` for `main_menu.gd` only
  (and expects `assets/ui` to hold `cursors` and `menu`); the main-menu backdrop check follows the new look.

## Commands
```
python -I scripts/art/cut_menu_backdrop.py          # venv python with Pillow, numpy, scipy
godot --path . --language en|es --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mm.gd -- lang=en|es
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch -ginclude_subdirs -gexit
```
Machine: the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2.

## Results
- Arch: 2 scripts, 4 tests, 4 passing (18283 asserts).
- Shot frame (en, no save): draw calls 220, objects 346, primitives 2646 (`Performance` monitors at frame 120). These are
  the 2D draws (five plates with many `draw_*` calls each, the logo, the picture); there is no 3D scene any more. The
  es shot reads 220 / 364 / 2682. Frame rate printed by the shot script is noise (screenshot run, busy machine).
- Shots: `build/shots/v0.9.5/mm/en.png` and `es.png`, 1920 x 1080 (not tracked).
- Logo checked on black at full size and at 640 px: no white fringe; a faint cyan edge on a few crystal tips (the
  un-premultiplied glow); the white-hot core of the central beam reads as soft blue rather than white.

## Deviations from the reference picture
- Order is Continue, Play, Options, Credits, Exit (today's order, Continue first), the picture shows Play first.
- The plates are code-drawn, not the picture's art: the stone is a noise fill, the shards are flat polygons.
- The column is lower than the picture's (the logo is above it) and the plates are 420 px wide at the base.

## OWNER ONLY
- Whether the menu looks right: the plates against your picture, the logo's edge, the drift.

## Finished by the lead (2026-10-26)

The agent's logo cut kept failing (owner: "the logo has something going on that's badly rendered not as I shared"), so
the owner sent a transparent PNG and asked: "can you kill it and add the simple png image I shared as the logo?". The
agent was stopped and the lead finished the step:
- **Logo:** the owner's transparent PNG, used as sent (1728 x 910 RGBA): `docs/art/reference/v0.9.5_logo.png` =
  `assets/ui/menu/logo.png`. The white-background cut is gone from `scripts/art/cut_menu_backdrop.py`, which now makes
  only the backdrop. The lines above about flood fill and the cyan edge describe the dropped cut.
- **Owner:** "make buttons like 30% smaller as well": plates 294 x 59 at 1080p (the 420 px above is the old size).
  Then "make it 30% smaller and move it up a bit (the logo)": the logo is 448 px wide (from 640), with a 56 px gap
  under it (`MainMenu.LOGO_LIFT`).
- **Exit:** the menu's last button reads "Exit" (`UI_QUIT` en "Quit" → "Exit"; es "Salir" unchanged), as in the
  owner's reference.
- **Machine and build:** the owner's PC, Godot 4.7.2 console build, `--language en`, own `APPDATA`.
- **Shots** (renderer, 1920 x 1080, untracked): `build/shots/v0.9.5/mm/en.png` and `es.png`:
  `godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mm.gd -- lang=en` (and `lang=es`).
  The en shot printed `mm: draw calls 220.0 objects 346.0 primitives 2574.0`.
- **Tests:**

| Run | Result |
|---|---|
| lint (gdformat --check + gdlint) on the menu files, the shot script and the tests | clean |
| test_stone_button, test_ember_stone | 3/3, 8/8 |
| e2e main_menu, credits, options, pad_menus, hub, saves, old_save | 3/3, 1/1, 2/2, 5/5, 9/9, 3/3, 1/1 |
| tests/unit/application (locale coverage) | 173/173 |
