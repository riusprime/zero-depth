# Step SS: the Fortune shrine says clearly what happened (v0.9.5)

Owner line: "The animation on the shire should be clearer and more visual when it fails, adding a sound, and the reward
should be shown over it in a little icon, we already have the details on the top corner when you get them, so let's
spice this shrine a bit".

Build base: `d33bc82a` (branch `v095-ss`; the step's commit is the branch head). Machine: owner PC (RTX 3060, Windows,
Godot 4.7.2). Presentation and audio only: no sim, no gameplay timing.

## What changed

- **Sounds** (`scripts/audio/generate_sfx.py`, GENERATOR_VERSION unchanged at 2: no existing recipe changed):
  `gamble_fail` 0.700 s (FM sweep 420 to 110 Hz, low thud, filtered crackle, bitcrushed) and `gamble_win` 0.600 s
  (two chimes a fifth apart, the second 0.12 s later, shimmer tail). Both peak -1.00 dBFS (manifest).
- **Cues** `data/audio/cues/gamble_fail.tres`, `gamble_win.tres` (-6 dB, jitter 0.04, 1 voice, captions
  `CAPTION_GAMBLE_FAIL` / `CAPTION_GAMBLE_WIN`, en + es rows in `locale/strings.csv`).
- **AudioEvents**: `GAMBLE_FAIL` plays `gamble_fail` (was `vent_cold` at 0.8); `gamble_win` plays when
  `WorldReader.gamble_tick()` changes (the tick the card starts its spin), positioned at the shrine.
- **GambleShrineView fail** (FIZZLE_S 1.18 s): white flash 0.08 s, gutter to DENY red and dim to 20 % over 0.6 s, recover
  over 0.5 s; 5 cracks (a billboard drawn in code with an ImageTexture, fading over 1.0 s); 12 dark smoke puffs rising
  0.8 m, drawn into the existing VfxCore `smoke` pool through a drawer (count follows Effects density: 12 / 8 / 4);
  body drops 0.06 m and springs back. Reduced motion: no jolt and no 90 Hz flicker, cracks still show.
- **GambleShrineView win**: when the spin lands (the card's landing, so the icon does not spoil the reel), the won stat's
  icon floats 1.4 to 2.0 m over 2.0 s (scale 0.6 to 1.0 in 0.2 s, fades in the last 0.5 s), `Sprite3D` billboard,
  `no_depth_test`, 0.45 m wide. The icon is the **existing GambleIcons glyph** (the one the result card and stats panel
  draw), rendered once into a 64 px SubViewport; no new art. A gold ring (`ring` pool, 0.3 s) pulses on the foot at the
  same moment.
- The HUD's centred "It failed" line is unchanged.

## Not as asked / notes

- Running `generate_sfx.py` over the whole set also rewrote six existing files (`barrel_blast`, `barrel_fuse`,
  `bomb_throw`, `container_break`, `pillar_turn`, `wall_break`) and their manifest rows: that drift predates this step
  (those recipes were not touched). They were restored with `git checkout`; only the two new wavs and their two manifest
  rows are in this commit (the rows were merged into the old manifest by hand). Whoever owns those six should check the
  generator against the committed bytes.
- The win icon appears at the landing, not at the spin's start.

## Commands and results

```
godot --headless --path . --editor --import --quit
gdformat --check / gdlint on the 5 touched .gd files: unchanged / no problems
python scripts/audio/generate_sfx.py   -> gamble_fail 0.700 s 61784 bytes, gamble_win 0.600 s 52964 bytes
godot --headless --fixed-fps 60 ... -gtest=test_gamble_views, test_shrines_view, test_audio_director,
  test_audio_assets, test_locale_coverage, test_e2e_gamble   -> Tests 44, Passing 44, Asserts 7050
godot ... -gtest=test_gamble_validation, test_e2e_audio (first run, with test_audio_assets, test_locale_coverage,
  test_e2e_gamble) -> Tests 19, Passing 19, Asserts 6699
```

New tests: `test_gamble_views.gd` (fail within 1.2 s and back at rest; reduced motion; prize icon placement, timing and
removal), `test_audio_director.gd` (`gamble_fail` replaces `vent_cold`, `gamble_win` once per win).

## Shots (renderer: Vulkan, RTX 3060; Ruins, a Fortune shrine floor via ShrineLab; HUD hidden; SHOT HELPER: shards and
odds set directly, the use goes through `Gamble.interact`)

- `build/shots/v0.9.5/ss/crack.png`: 0.45 s into a fail: red cracks across the wheel, the core red, dark smoke rising
  above the shrine.
- `build/shots/v0.9.5/ss/prize.png`: a win just landed: the melee-damage glyph in its tile floats over the shrine's face.

Not run: sim tests (no sim change), the full suite, in-game listening to the two sounds (OWNER ONLY).
