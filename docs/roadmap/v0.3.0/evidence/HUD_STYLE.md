# v0.3.0 Step UI — HUD style evidence

Workstream UI (owner lines L21, L23, L24): a techno/echo HUD style (G2: three directions, one ships), the danger
level as a visual meter with no numbers, and a red low-HP warning. Godot 4.7.2.stable.official, Linux cloud
container, software Vulkan (llvmpipe) for the renders; timings are the container's, not the owner's hardware.

Owner-only fields (which style fits, whether the warning reads in a fight, feel): **OWNER ONLY**.

## G2: three directions (owner picks)

`hud_mockups.png` (1920 × 680): the same posed game frame (floor 1, 02:15 into the floor, tier 5 of 6 half-way,
HP 24 / 100, 147 shards, three items, floor 1's title card) with a real `Hud` built in each style, left to right;
under each frame, the top plate and the HP corner at 1:1.

| | A. TERMINAL | B. HOLO_ECHO (shipped default) | C. INDUSTRIAL |
|---|---|---|---|
| Type | condensed (×0.86), wide-tracked caps | slightly extended (×1.06), tracked caps | heavy slanted caps |
| Echo | a red/cyan chromatic split; on change it spreads and jitters | two cyan ghosts trailing down-right; on change they spread out and fade back | a stencil shadow; on change it slides sideways |
| Plates | dark box, corner brackets, scanlines | translucent cyan panel, bright top edge, end caps, scan rows, ticks | chamfered gunmetal plate, hazard-amber strip, bolts |
| Danger chevrons | outlined `>` chevrons | filled chevrons with an echo copy | slanted blocks |
| HP bar | bracketed, scan gaps | translucent with tick marks | 20 blocks |

**Shipped: B, HOLO_ECHO** (lead's pick, owner to confirm): it is the one that is literally "echoey", the cyan ties
to the hero's visor and the portal, and it stays legible on the sand and red-canyon floors. Swapping is one line:
`HudStyle.DEFAULT` in `src/presentation/hud/hud_style.gd` (`Style.TERMINAL`, `Style.HOLO_ECHO`,
`Style.INDUSTRIAL`).

Fonts: only the bundled Atkinson Hyperlegible (OFL, `assets/fonts/OFL.txt`) through `FontVariation` (tracking,
transform, embolden). Nothing was downloaded.

## What ships

- **Top plate** (`Hud._build_top`): `FLOOR 01 // RUINS` (accent) over the run time `02:15`, the danger meter and
  the kills. `HUD_FLOOR` is now `Floor %02d // %s` / `Piso %02d // %s`; `HUD_TIME_TIER` ("· Danger %d") is
  replaced by `HUD_TIME` (`%02d:%02d`), so no danger number is shown anywhere. Every value is an `EchoLabel`: when
  its text changes, its ghosts spread and settle over 0.45 s (the clock echoes every second, kills on each kill).
- **Floor-title card**: `FLOOR 02` in 76 px with the echo, the biome on a style plate under it; it echoes in on
  arrival and fades as before (2.6 s, last 0.7 s).
- **Danger meter (L23)** (`DangerMeter`): 6 chevrons, one lit per tier reached (tier 1 lights one); 10 segments
  under them fill toward the next tier (`WorldReader.tier_progress()`, i.e. `run_ticks % tier_ticks`, 30 s per
  tier); colours run cyan → yellow → orange → red with the tier; a rise flashes the chevrons and sends a ring out
  (0.8 s); past the 6th chevron every chevron flickers red ("overdrive"). The meter has no Label.
- **Low HP (L24)**: below 30 % of max HP (`hp * 100 < max * 30`, integer maths; 0 HP excluded) the HP text turns
  red, the bar's fill and the plate's edge pulse red at 2 Hz, and a red glow hugs the screen edges (alpha
  0.12–0.38, 16 % of the short side deep). At 30 % or more it all stops. A damage echo (the lost part of the bar,
  white, catching up at 0.6 bar/s) shows each hit.
- **Restyled with the helper**: the HP plate, dash/utility pips, the shard counter plate, the gate/boss/portal
  note and the altar/chest prompt. Not touched: the boss bar (BX), the pick panel, the start screen (P), the heat
  meter (H); the item/combo icon rows keep their own frames.
- **Calm mode**: `HudStyle.reduced_motion` (no setting exists yet; the options workstream can wire one) holds the
  pulses steady and stops the glitches.

All numbers above are starting values.

## Shared helper (for P, H, BX and the pick panel to adopt)

`src/presentation/hud/hud_style.gd` (`HudStyle`): `style_label(label, size, bold)`, `font(bold)`, the colour
tokens `accent() / text_color() / dim() / panel_bg() / warn_color()`, `danger_color(heat)`, `low_hp(hp, max)`,
`pulse(t)`, and the pieces `HudFrame` (a styled `PanelContainer`), `HudBar` (a styled fill bar with a damage echo
and `warn`) and `EchoLabel` (a `Label` with the style's ghosts and the change glitch). Every piece takes the
current style when it is built.

## Shipped style in play

`hud_style.png` (1920 × 540): the game's own HUD (HOLO_ECHO) on floor 1. Left: full HP, 00:51 (tier 2, 2 chevrons
lit, the bar 7/10 toward tier 3). Right: HP 22 / 100 with the warning on (red HP plate, red edge glow) and the
floor card echoing in.

Both images come from `scripts/shots/hud_style.gd` (a tool, not a test: it poses the clock, HP, shards and items
directly), copied by hand from `build/shots/v0.3.0/hud_style/`:

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/hud_style.gd
hud_style: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
hud_style: res://build/shots/v0.3.0/hud_style/mock_terminal.png
hud_style: res://build/shots/v0.3.0/hud_style/mock_holo_echo.png
hud_style: res://build/shots/v0.3.0/hud_style/mock_industrial.png
hud_style: res://build/shots/v0.3.0/hud_style/play_full_hp.png
hud_style: res://build/shots/v0.3.0/hud_style/play_low_hp.png
hud_style: sheets (1920, 680) (1920, 540)
```

Sizes: `hud_mockups.png` 377 608 B, `hud_style.png` 335 288 B.

## Tests

- `tests/unit/presentation/test_hud_style.gd` (10): chevrons per tier (capped, overdrive), segments per progress,
  cool-to-hot, `WorldReader.tier_progress`, the rise pulse (not on the first reading or a floor reset) and no text
  in the meter, the 30 % threshold (30/100 off, 29/100 on, 0 off, 35/120 on, 36/120 off), the HUD warning on and
  off around it, calm mode, every style building every piece, the echo on a value change.
- `tests/e2e/test_e2e_hud_style.gd` (1): main.tscn from the menu with real input only; the meter shows the
  tier/progress the reader gives, the top plate has exactly floor, time and kills, then the left stick walks into
  the enemies until HP drops under 30 % and the warning comes on (run log: `hp 20 / 100`).

## Full suite, lint, export smoke

From the working tree of the Step UI commit (parent `5e24bf7`):

```
$ bash scripts/verify.sh
...
Scripts              89
Tests               493
Passing Tests       493
Asserts           402830
Time              398.791s
---- All tests passed! ----
check_gut_log: ok (493 passing, minimum 493)
```

`tests/MIN_TEST_COUNT` 482 → 493 (+10 unit, +1 e2e). The e2e's `hp 20 / 100` line is from the targeted run
(`-gtest=res://tests/unit/presentation/test_hud_style.gd,res://tests/e2e/test_e2e_hud_style.gd`: 11/11 passed).

```
$ gdformat --check src scripts tests && gdlint src scripts tests
279 files would be left unchanged
Success: no problems found
```

```
$ bash scripts/ci/export_smoke.sh
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
  ok    manifest hash de8d3c967621 matches the project's
...
0 miss(es)
```

Goldens: none changed (the sim gained only the read-only `SpawnTable.tier_progress` and
`WorldReader.tier_progress`).

## Open

- The owner picks A, B or C (G2); B ships until then.
- No reduced-motion option exists yet; `HudStyle.reduced_motion` is the hook.
- The boss bar, pick panel, start screen and heat meter still use their own look; they can adopt `HudStyle`.
