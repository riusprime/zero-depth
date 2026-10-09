# CARDS: do the altar, chest and shop picks wear the owner's crystal frames, legibly, in en and es? (PLAN v0.5.5 A4)

- **Status:** RUN
- **Build:** code commit `a97cd28` on `worktree-agent-a7c40463ca6fd0251` (this file is added in the amended Step CD
  commit; no code changed after the suite run); Godot `4.7.2.stable.official.ed1daf0bf`; Linux (screenshots:
  lavapipe Vulkan under Xvfb, Forward+)
- **Date:** 2026-10-08
- **Who ran it:** agent. Whether the cards look right and read well on the owner's screen: **OWNER ONLY**.

## What was built
- **Frames.** `scripts/art/crop_card_frames.py` cuts the 12 frames from
  [`../refs/card_templates_empty.webp`](../refs/card_templates_empty.webp) (sha256
  `7eb503cc4dca6264faad110941adc693496b505db600631167aa00df4c720f88`). The delivered webp already carries a transparent
  background (alpha 0 around the frames; it shows white only in a viewer), so the white flood fill in the script is
  not used on it; the script still cleans webp alpha noise (below 24 → 0, above 232 → 255), erodes light edge
  pixels and defringes the partly transparent rim, cuts each frame by its connected parts (loose crystals included),
  and centres all 12 on one 251 × 505 canvas, bottom-aligned. Output `assets/ui/cards/frame_<colour>.png` +
  `manifest.json` (source hash, licence "the owner's own art", per frame id, path, sha256, size, dark panel box).
- **Cards.** `CrystalCard` (`src/presentation/hud/crystal_card.gd`): the frame, then inside one shared text box
  (`CONTENT`, inside every frame's dark panel) the title in the frame's colour in capitals, a hairline, the sentence,
  a hairline and a bottom row: the card's own icon, the rarity line ("Rare", "New ability", "Mod · Common"…) and a
  rarity gem in the rarity's colour. A glow behind the frame shows rarity (none on a common card; rare 0.26, epic
  0.40, ability 0.26, +0.14 on the focused card). The focused card lifts 8 px and its frame brightens. Title and
  sentence step down in size until they fit (title: one line first, then two).
- **Families.** `src/presentation/hud/card_frames.gd` is the one table to remap: `FRAME` (family → frame) and
  `FAMILY_OF` (every mod, stat card and ability → family). Rules: an epic card wears gold, a cursed offer wears
  violet. A missing card falls back on its type; `test_card_frames.gd` fails on any content card missing from the
  table. The starting mapping (the owner may remap any row):

| Family → frame | Cards |
|---|---|
| damage → red | bulwark, executioner, overcharge, razor_orbit, serrated_edge, damage, glass_cannon, onrush, overkill, combo_sword, orbit_blades |
| projectile / frost → blue | barbed_bolts, cold_snap, frost_core, glacial_edge, overclocked_drone, rapid_coil, ricochet_core, splinter_shot, static_chain, thorn_mantle, drone_buddy, frost_nova, pulse_gun |
| economy / stats → amber | armour, attack_speed, hoarder, pickup_range, shard_gain |
| dash / void → purple | afterimage, kinetic_dash, momentum, phase_strike, swift_feet, move_speed, blink |
| healing → green | vampiric_core, max_hp, regen, lifesprout (Step EC's D9 card, if it lands with that id) |
| time / slow → silver | twin_arc, cooldowns, fast_hands, aegis |
| crit → pink | crit_chance, crit_damage |
| area → cyan | cluster_payload, conductor, long_edge, area, arc_field, bomb_lobber |
| fire → orange | cinder_shot, ember_edge, heat_sink, meltdown, thermal_edge, wildfire, flame_trail |
| curse → violet | any cursed offer |
| epic → gold | any epic card |
| trinket → indigo | none yet (reserved for MX trinkets) |

- **Wiring.** `PickSlot` (altar and chest pick, scale 1.2) and the shop stock (`ShopPanel.CARD_SCALE` 0.92) now
  hold a `CrystalCard`; `PickPanel.card_face` adds the card's type. Keyboard (←/→, 1–4, Enter, Esc), pad and mouse
  are unchanged (PickPanel / ShopPanel input code is untouched). The item, combo, gamble and event cards keep the
  `CardStyle` FACET look until the A5 pick.

## Command
```
python3 scripts/art/crop_card_frames.py --check
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/presentation/test_card_frames.gd,res://tests/content/test_card_frame_assets.gd,res://tests/unit/presentation/test_reward_views.gd,res://tests/unit/presentation/test_shop_views.gd -gexit
bash /tmp/claude-0/vd.sh <worktree> cd          # import + gdformat/gdlint + scripts/verify.sh (full suite + guards)
cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh
# screenshots (renderer needed), then copied by hand into this folder:
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/crystal_cards.gd   # and 1280x720
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/shop.gd            # and 1280x720
```

## Raw output
```
$ python3 scripts/art/crop_card_frames.py --check
check: 0 file(s) differ

$ godot ... -gtest=...test_card_frames.gd,...test_card_frame_assets.gd,...test_reward_views.gd,...test_shop_views.gd
res://tests/unit/presentation/test_card_frames.gd
5/5 passed.
res://tests/content/test_card_frame_assets.gd
6/6 passed.
res://tests/unit/presentation/test_reward_views.gd
8/8 passed.
res://tests/unit/presentation/test_shop_views.gd
6/6 passed.
Tests                25
Passing Tests        25
Asserts            1207
---- All tests passed! ----

$ bash /tmp/claude-0/vd.sh <worktree> cd        (on a97cd28)
verify exit 0
Tests              1097
Passing Tests      1097
check_gut_log: ok (1097 passing, minimum 1086)
[… /tmp/claude-0/vd_cd.clean.log tail …]
Scripts             173
Tests              1097
Passing Tests      1097
Asserts           484745
Time              1548.729s
---- All tests passed! ----

$ cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh
[… earlier lines trimmed …]
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 87
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
smoke exit 0

$ godot ... -s scripts/shots/crystal_cards.gd   (1920x1080; the 1280x720 run prints the same lines)
cards: renderer=forward_plus
cards: altar 0 at (1.965001, -9.370001)
cards: altar open true, title 'Altar · choose one'
cards: res://build/shots/v0.5.5/cards/01_altar_en_1920x1080.png
cards: res://build/shots/v0.5.5/cards/01_altar_es_1920x1080.png
cards: res://build/shots/v0.5.5/cards/02_kinds_en_1920x1080.png
cards: res://build/shots/v0.5.5/cards/02_kinds_es_1920x1080.png
cards: res://build/shots/v0.5.5/cards/03_frames_1920x1080.png
cards: res://build/shots/v0.5.5/cards/00_game_no_hud_1920x1080.png

$ godot ... -s scripts/shots/shop.gd   (each resolution)
shop: renderer=forward_plus
shop: room 8 at (-37.93499, 34.85)
shop: stock [28, 12, 2051, 6]
```
A first full run (before the fix below) failed one test, pasted as it was:
```
res://tests/unit/presentation/test_hud_style.gd
- test_the_calm_hud_has_plain_labels_and_thin_bars
    [Failed]:  Title is plain type
          at line 142
```
The v0.3.5 F15 test forbids capitals in every HUD label; the owner's A4 reference shows the card titles in
capitals. The test now exempts exactly the `CrystalCard` title and keeps the rule for every other HUD label.
**Flagged for the owner/lead** as a rule change (owner reference vs the older calm-HUD rule), not resolved quietly.

## Screenshots
| File | What |
|---|---|
| [`cards_01_altar_en_1920x1080.png`](cards_01_altar_en_1920x1080.png) | A real altar opened with the interact key (shot setup places the hero at it): an ability, a rare stat, a common stat |
| [`cards_01_altar_es_1920x1080.png`](cards_01_altar_es_1920x1080.png), [`cards_01_altar_es_1280x720.png`](cards_01_altar_es_1280x720.png) | The same in Spanish (the longest strings) |
| [`cards_02_kinds_en_1920x1080.png`](cards_02_kinds_en_1920x1080.png), [`…_es_1920x1080`](cards_02_kinds_es_1920x1080.png), [`…_es_1280x720`](cards_02_kinds_es_1280x720.png) | A pick filled directly: Blink (ability, the longest Spanish sentence, 219 characters), an epic crit card (gold), a cursed Wildfire (violet, curse line under it) |
| [`cards_03_frames_1920x1080.png`](cards_03_frames_1920x1080.png) | All twelve frames, labelled colour / family |
| [`cards_04_shop_en_1920x1080.png`](cards_04_shop_en_1920x1080.png), [`…_1280x720`](cards_04_shop_en_1280x720.png) | The real shop opened with the interact key: four stock cards, services and salvage still fit |

## Result
| Check | Measured |
|---|---|
| 12 frames, alpha, 251 × 505, hashes, no white fringe, manifest both ways | pass (`test_card_frame_assets.gd`) |
| Every mod, stat card and ability has a family; 12 families, one frame each | pass (`test_card_frames.gd`) |
| Every card's title and sentence fit the panel, en + es, pick and shop sizes; title ≥ 13 × scale px, sentence ≥ 12 × scale px | pass (`test_card_frames.gd`) |
| e2e: the altar opened by pad input shows each card in its family frame, text fitting; d-pad and A still pick | pass (`test_e2e_floor.gd`) |
| Full suite | 1097 / 1097 passing |
| Export smoke | 0 misses |

## Interpretation
- The longest ability sentences (Blink, Aegis in Spanish) step down toward the smallest sentence size (14 px in the
  1080p layout of the pick, so about 9 px on a 1280 × 720 window; sizes per card were not logged): legible on the
  720p screenshot, but small. If the owner finds them too small, the options are a
  shorter ability line on the card (the long text in a tooltip) or larger pick cards. **OWNER ONLY** to judge.
- `violet` (curse) and `purple` (dash) are close in hue in the owner's art; they differ by shape (a plain crystal
  crown vs a swirl). The owner may want to remap.
- The epic gem stays the old epic purple while the epic frame is gold.
- The mapping is a starting value; `lifesprout` is pre-mapped to healing for Step EC (D9); if EC names it
  differently, `test_card_frames.gd` will name the card to add.
