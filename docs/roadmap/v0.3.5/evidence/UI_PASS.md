# UI_PASS: v0.3.5 Step UI: straight heat bar, calmer HUD, restyled cards, minimap fix, quieter sword

- **Status:** RUN (agent). Owner-only fields: **OWNER ONLY** (G2 picks, how it feels, how it sounds on their
  hardware).
- **Build:** working tree on top of `66124b6` (branch `worktree-agent-ab722371d2b1428c1`, to merge into
  `claude/lucid-fermat-9wv2tf`); the commit is `v0.3.5 Step UI: calmer HUD, straight heat bar, restyled cards,
  minimap fix, quieter sword`. Godot `4.7.2.stable.official.ed1daf0bf`; Linux cloud container; renders on software
  Vulkan (llvmpipe) under xvfb.
- **Date:** 2026-10-07
- **Who ran it:** agent

Owner lines (PLAN v0.3.5): F2, F14, F15, F16, F17.

## F14: the minimap was mirrored top to bottom (root cause)

`MinimapView._turn` drew a sim offset `v` at screen `((v.x + v.y)·c, (v.y − v.x)·c·squash)`. The iso camera
(`IsoRig`: yaw +45° about +Y; sim `(x, y)` is 3D `(x, −y)`) shows screen right as sim `(+1, +1)/√2` (that part
was right) and screen **up** (away from the camera) as sim `(−1, +1)/√2`. Screen y grows downward, so the
vertical must be `(v.x − v.y)`: the old sign put every room above you on screen below you on the map, a mirror
across the horizontal axis (left/right were right, which is why it read as "inverted" rather than "rotated").
The fix is the sign in one static `MinimapView.turn` used by everything the map draws (rooms, doors, stubs,
icons, the player's facing arrow). The style comment that said the camera looks along "+X+Y" was also wrong
(it looks along sim `(−X, +Y)`); corrected.

New test `tests/unit/presentation/test_minimap_orientation.gd` projects points through a real `IsoRig` camera
(`Camera3D.unproject_position`) and through the minimap: 16 directions, the two screen axes, and every room of a
real floor (seed 11); left/right and up/down must agree on both axes, and directions must match (dot > 0.95).
The e2e `test_e2e_minimap.gd` now also checks, in `main.tscn` after a real walk, that the next room lies on the
full map the way the game's own camera shows it.

The same test against the old formula (the line reverted by hand for this run, then restored):

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -gselect=test_minimap_orientation -gexit
```
```
    [Failed]:  dir 0: up/down agree (screen (409.8533, 193.4536), map (7.741671, -4.557466))
    [Failed]:  [0.56276667118073] expected to be > than [0.95]:  dir 0: the same direction
    [Failed]:  dir 1: up/down agree (screen (506.8953, 88.18365), map (9.574686, -2.077471))
[… trimmed …]
    [Failed]:  room 1: up/down agree (screen (1036.203, -550.6432), map (97.86357, 64.86148))
    [Failed]:  room 2: up/down agree (screen (1791.829, -1016.896), map (169.2283, 119.7825))
[… trimmed …]
0/3 passed.
Passing Tests      none
Failing Tests         3
Asserts           41/84
```

With the fix:

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -gselect=test_minimap -gexit
```
```
res://tests/unit/presentation/test_minimap_orientation.gd
* test_the_turn_matches_the_camera_in_every_direction
* test_screen_up_and_right_are_the_same_sim_directions_on_both
* test_a_real_floors_rooms_sit_in_the_same_screen_quadrants_on_the_map
    rooms: 3 left, 9 right, 12 up, 0 down
3/3 passed.
[…]
Tests                 8
Passing Tests         8
```

e2e (`-gdir=res://tests/e2e -gselect=test_e2e_minimap`):

```
    next room from the hall: screen (-3920.0, -921.8302), map (-277.3069, -81.33282)
1/1 passed.
```

## F2: the straight heat bar

`src/presentation/hud/heat_meter.gd`: the arc, its 25 segments, glow, steam puffs and labelled notches are gone. A
360 × 5 px bar at the bottom centre; its fill takes the heat colour of the current heat (red, pulsing, while
overheated); two 2 px ticks at Hot and Overclock (dim until reached); a short red cap at the overheat end (pulses
past 88 %); a small zone word over the left end and `VENT: DASH` over the middle. The tick and cap positions are
`x_of(heat)` from `WorldReader.heat_state()` (the sim's heat table), never numbers of the meter's own; the new
test `test_the_straight_bar_places_its_ticks_from_the_sim_table` checks them against the table (Hot at 40 of
100, the end at max). The steam test became `test_overheating_turns_the_bar_red`. Space is left to the right of
the zone word / around the VENT prompt for workstream K's key hint.

## F15: calmer HUD (G2, default ships)

`HudStyle` now has three calm styles, one constant (`HudStyle.DEFAULT`). Gone in all of them: the echo/ghost
labels (`echo_label.gd` deleted), glitch flicker, scanlines, brackets, end caps, bar tick rows, chevron echoes,
wide tracking and slanted type. Plain Atkinson Hyperlegible, no forced caps, a soft outline and shadow for
legibility on the light biomes; HP bar 300 × 8; danger meter = six short marks (tier, no numbers) over a 2 px
progress line; boss bar 560 × 8 with a 3 px stagger line; smaller dash/utility squares; the floor label reads
`Floor 1 · Ruins` (strings `HUD_FLOOR`, `HUD_FLOOR_CARD`, en + es). Low-HP pulse (bar + edge glow) and the regen
pulse are kept.

`hud_mockups.png` (1920 × 790): the same posed frame (floor 1, 02:15, tier 5 of 6, HP 24 / 100, 147 shards,
Overclock heat 58 = Hot) with a real `Hud` in each style; under each: the top group, the HP corner, and the heat
bar at 1:1. `hud_style.png`: the shipped HUD in play (full HP; low HP with the floor card).

| | A. LINE (shipped default) | B. BARE | C. SLATE |
|---|---|---|---|
| Groups | one hairline under each | nothing | flat square translucent plates |
| Why / why not | calmest that still groups things | lightest, loosest on bright floors | most legible on sand, heaviest |

**Ships: A. LINE.** Owner pick: **OWNER ONLY** (PROGRESS gate "G2: HUD (calmer) mockups").

## F16: pick cards in the game's style (G2, default ships)

`CardStyle` (one constant, `CardStyle.DEFAULT`) styles every card: the 3-card pick (`PickSlot`), the item card,
the combo card and the gamble card. No rounded corners, no shadow, no coloured side bar; a flat dark panel with a
1 px neutral outline (2 px and brighter when focused). Rarity is a small two-facet diamond (`CardMark`) with the
rarity's name, not the frame; the item keeps its colour in its name. The item card inside a pick slot draws no
panel of its own (no nested frames). Icon tiles, the shrine stats panel and the minimap panel lost their rounded
corners too. `test_reward_views` checks every pick card is square, unshadowed and side-bar free with a neutral
outline; `test_status_visuals` checks the combo card's outline is even.

`card_mockups.png` (2250 × 525): the same frame with a real pick (second card focused, rare), an item card and a
combo card in each look, left to right:

| | A. FLAT (shipped default) | B. FACET | C. RULE |
|---|---|---|---|
| Panel | square, 1 px outline | two opposite corners cut | square, no outline, a top rule in the card's colour |

**Ships: A. FLAT** (the PLAN's "square corners" read literally). Owner pick: **OWNER ONLY**.

Commands (both renders):

```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/hud_style.gd
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/card_mockups.gd
```
```
hud_style: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
hud_style: res://build/shots/v0.3.5/hud_style/mock_line.png
hud_style: res://build/shots/v0.3.5/hud_style/mock_bare.png
hud_style: res://build/shots/v0.3.5/hud_style/mock_slate.png
hud_style: res://build/shots/v0.3.5/hud_style/play_full_hp.png
hud_style: res://build/shots/v0.3.5/hud_style/play_low_hp.png
hud_style: sheets (1920, 790) (1920, 540)

cards: renderer=forward_plus
cards: res://build/shots/v0.3.5/cards/card_flat.png
cards: res://build/shots/v0.3.5/cards/card_facet.png
cards: res://build/shots/v0.3.5/cards/card_rule.png
cards: sheet (2250, 525)
```

Copies into `evidence/` were made by hand (`cp`).

## F17: quieter sword

- Generator (`scripts/audio/generate_sfx.py`, `GENERATOR_VERSION` 1 → 2): every blade swing is one layer (the
  whoosh; the metal ping, and the spin's chord and thud, removed), the whoosh and echo tail roughly halved.
- Cues: blade slashes and thrust −4 → −12 dB, spin −2 → −10 dB, `enemy_hit` (the melee hit) −10 → −18 dB and 4 →
  2 voices: −8 dB each (starting value; files are peak-normalised, so the level lives in the cues).
- New `AudioCueDefinition.voice_group`: the five swing cues share `blade_swing` with `max_voices = 2`, so two
  swing sounds at most overlap even when the combo alternates cues (`SfxMixer` counts voices per group).
- Test `test_blade_swings_share_a_two_voice_limit_and_are_quieter` (levels vs v0.3.0 − 8, group, stream < 0.45 s,
  alternating cues stop at 2).

Lengths from `assets/audio/manifest.json` (v1 → v2): slash_1 0.42 → 0.21 s, slash_2 0.42 → 0.21, slash_3 0.5 →
0.25, thrust 0.372 → 0.18, spin 1.03 → 0.4.

```
python3 scripts/audio/generate_sfx.py           # → "49 files, 5839436 bytes, generator v2"
python3 scripts/audio/generate_sfx.py --check   # → "  same  assets/audio/manifest.json" … "0 difference(s)"
```

How it sounds: **OWNER ONLY**.

## Full suite and lint

```
bash scripts/verify.sh
```
```
[… trimmed …]
Scripts             114
Tests               669
Passing Tests       669
Asserts           414634
Time              414.377s

---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (669 passing, minimum 664)
```

`tests/MIN_TEST_COUNT` 664 → 669.

```
gdformat --check src scripts tests && gdlint src scripts tests
```
```
356 files would be left unchanged
Success: no problems found
```

## What this doesn't prove

- Legibility, calm and "fits the game" are the owner's call (G2 picks pending; defaults ship).
- The −8 dB and the shorter tails are starting values; the mix was not listened to.
- Renders are llvmpipe at 1600 × 900; nothing measured on the owner's hardware.
