# v0.3.0 O — the Options screen (evidence)

Build: the working tree of workstream O on `5e24bf7`, before it was committed. Godot `4.7.2.stable.official.ed1daf0bf`,
headless on Linux; renders on llvmpipe (software Vulkan). Owner-only fields (feel, layout preference, results on
the owner's hardware): `OWNER ONLY`.

## What was built
- **Reachable** from the main menu (Options) and from the pause menu (Resume, Restart run, **Options**, Main menu).
  From the pause menu it opens over the paused floor; Back returns to the pause menu with Options focused.
- **Sections:** Audio (Master, Sound effects, Ambience: 0–100 in steps of 5, keys `audio/master`, `audio/sfx`,
  `audio/ambience`, applied to the buses `Master`, `SFX`, `Ambience` when they exist — the audio workstream adds
  the last two); Display (window/fullscreen, VSync, frame cap, resolution scale 50/67/75/85/100 % =
  `scaling_3d_scale`, outline style); Controls (every action, one keyboard/mouse and one pad binding each);
  Accessibility (screen shake, reduced motion, colour-blind mode, sound captions `captions`); Language (en/es).
- **Every device:** choices are cyclers (‹ value ›: left/right or press), volumes are sliders that left/right step
  (Godot 4.7's slider let the d-pad's left leave it), a binding cell waits for the next key/click or pad
  button/stick/trigger (Esc or pad Back cancels). Esc, pad B or the pause button steps back: from a section to its
  category, from a category out of Options. Right from a category always lands on its section's first row.
- **Remap conflicts:** a key already used by another action on the same device swaps the two (“Swapped with
  Interact”), so no input is left doing two things or nothing. Reset controls restores the defaults. Bindings
  persist through the existing remap store (`InputRemap`, the profile's `bindings`).
- **Reduced motion:** no camera shake at all (even with shake on) and hit bursts throw half the sparks.
- **Colour-blind modes:** protanopia and deuteranopia share a blue player / amber enemy / white telegraph / yellow
  shot / violet hazard set; tritanopia a teal / red / pink / white / magenta set (ThemePalette.MODES, starting
  values). Views read colours when they are built, so a change shows from the next floor (the screen says so).
- **Live:** shake, outline, reduced motion and the palette follow a change at once where the view allows; volumes,
  window, VSync, frame cap, resolution scale and language apply on change. Settings save when you leave Options.

## G2: layouts (`options_mockups.png`)
Rendered by `scripts/shots/options_mockups.gd` (command in its header) over a paused floor at 1600 × 900:
**A** sidebar (categories left, one section at a time) — **shipped default**; **B** tabs across the top; **C** one
scrolling list; and A's Controls section. All three are the same `OptionsMenu` with `layout` set, so any of them
can ship by changing one argument.

| Question | Answer |
|---|---|
| Which layout should ship? | OWNER ONLY |
| Are the colour-blind palettes readable for you / your testers? | OWNER ONLY |

## Colour modes, measured
`tests/unit/presentation/test_colour_modes.gd` simulates each deficiency (Machado, Oliveira and Fernandes 2009,
severity 1.0, linear RGB) and requires every role pair that must read apart (player/enemy, player/telegraph,
player/shot, enemy/telegraph, telegraph/shot, enemy/shot, hazard/telegraph, the two HP bars) to stay at least
ΔE 25 apart (CIE76). The values below came from a throwaway Python version of the same maths, run while picking
the palettes (not committed); the test itself asserts the ≥ 25 bar for each mode and that the default palette
falls under it with deuteranopia and tritanopia. Closest pair per case:

| Palette | Simulation | Closest pair | ΔE |
|---|---|---|---|
| Default | none | enemy body / telegraph | 18.8 |
| Default | deuteranopia | hazard / telegraph | 4.4 |
| Default | tritanopia | enemy body / telegraph | 3.2 |
| Red-green set | protanopia | enemy body / shot | 36.0 |
| Red-green set | deuteranopia | enemy body / shot | 29.2 |
| Tritanopia set | tritanopia | hazard / telegraph | 26.1 |

## Tests
- `tests/e2e/test_e2e_options.gd`: from a floor, pad Start → d-pad to Options → A; d-pad into Audio, left lowers
  Master 80 → 75 and the bus follows; B back to the category, down to Accessibility, A turns shake off and the
  running camera's shake is off at once; then the keyboard: Esc, up to Controls, down to Dash's key, Enter, J;
  Esc, Esc, up to Resume, Enter; in play Space no longer dashes and J does. Second test: the mouse opens Language
  and a click switches to Spanish.
- `tests/unit/application/test_input_rebind.gd` (swap, devices, profile round trip, reset, labels),
  `tests/unit/presentation/test_colour_modes.gd`, the updated settings, locale and pad-menu tests.
