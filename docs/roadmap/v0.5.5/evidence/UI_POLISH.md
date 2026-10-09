# UI_POLISH: small UI polish on the A5 restyle (v0.6.0 Step UP)

- **Status:** RUN (built; full suite and export smoke green; screenshots partly taken, see below). Feel and fit on the
  owner's screen: **OWNER ONLY**
- **Build:** the suite and export smoke ran on `62aa597` (the Step UP commit `122a7bb` merged with
  `claude/lucid-fermat-9wv2tf` at `77dc6fe`: MX2, MX3, MX4, the right-trigger / facing / ground_b changes). The step is
  committed as one commit on top of `77dc6fe` with the same `src/`, `tests/`, `locale/` and `data/` as `62aa597`; it
  adds this file, the screenshots, the PROGRESS row and a guard in `scripts/shots/ui_polish.gd` (it now quits by
  itself after 285 s or if the run never starts). Godot `4.7.2.stable.official.ed1daf0bf`, Linux cloud container,
  lavapipe (`llvmpipe`) under Xvfb for the shots.
- **Date:** 2026-10-09
- **Who ran it:** agent

Presentation and locale only (`src/presentation/hud`, `src/presentation/menus`, `locale/strings.csv`). No file under
`src/presentation/world_view/` or `src/sim/` changed; nothing of the v0.5.9 look touched.

## What was fixed
| Ask | Fix |
|---|---|
| 1. The weapon slot's key read "Left clic" (cut off) | The ability slots name a binding by a short HUD name: `InputLabels.short_text` with `HUD_KEY_*` strings (en / es): mouse "LMB" / "Clic izq.", "RMB" / "Clic der.", "MMB" / "Clic cen.", wheel, M4 / M5; pad "A", "RT", "LB", "D-up" / "Cr. arr.", "LS up" / "SI arr."…; long keyboard names get symbols or abbreviations ("Kp *", "PgDn", "Bksp", "[", "'"). A name that is still too wide shrinks from 12 px down to 9 px (`AbilitySlot.fit_key`); clipping stays only as a last resort. The Options Controls list keeps the full names. The skill and vent hints ("[Q] LUNGE CLEAVE") are on slabs that size to their text and keep the full names. With the pad's attack now on the right trigger, the melee slot reads "RT". |
| 2. "Shrine stats" on the pause screen was in the old look | `GambleStatsPanel` and `ThreatPanel` take the menus' Cold glass (`MenuStyle.glass_panel`, cold title) when they are added to a `MenuPanel` (the pause menu), and on the HUD they are Ember stone slabs with their colour along the top (`HudStyle.side_panel_box` / `draw_side_panel`). A long curse line wraps at 560 px, so the threat panel no longer runs under the top plate in Spanish. |
| 3. "New: Charger" stayed English in the Spanish HUD | Cause: `PhaseHud` translated the banner when it was queued and kept the text. It now keeps translation keys and words the line on every sync and on `NOTIFICATION_TRANSLATION_CHANGED`. The same cached-text bug was found and fixed in: the floor card, the boss bar's name, the threat and shrine panel rows (rebuilt only when the curses / stats changed), the pause menu's run line and its two panels (synced once on open; a language switch from the pause menu's own Options left them English), the Options binding cells ("Left click" stayed English after choosing Spanish) and the Swap panel ("Skip", the card, the tiles). |
| 4. Options "Back" centred under the sidebar | Left-aligned like the category rows (SIDEBAR layout). |
| 5. Others found | MX2's `BuildHud` row (weapon · utility · six pips) now sits on an Ember stone slab, with stone-rimmed pips; MX2's `SwapPanel` wears Cold glass (blurred game behind, glass tiles with the family colour along the top, the focused tile with a cold rim; the incoming card keeps the pick cards' look and no longer shows a stray "1" under it). |

## Tests (added on purpose; none removed)
- `tests/unit/presentation/test_ui_polish.gd` (14): every slot key name fits its slot in en and es (every mouse
  button, pad button, stick direction, letters, digits, F1–F12, keypad, navigation and punctuation keys; the HUD is
  laid out on the 1920 × 1080 base canvas with `canvas_items` / `expand` stretch, so the same fit holds at 1280 × 720);
  every short name has en and es; the weapon slot reads "LMB" / "Clic izq." at full size; the shrine stats and threat
  panels are Ember stone on the HUD and Cold glass in the pause menu; the floor card, the banner line, the threat and
  shrine rows, the pause run line and panels, the Options binding cells and the Swap's Skip follow a language switch;
  the threat panel stays clear of the top plate with five curses in both languages; the Options Back row is
  left-aligned; the build row sits on an Ember slab and its widest weapon + utility text stays under 700 px; the
  Swap panel is Cold glass and every word of every ability and item name (the 30 MX4 modifiers included) fits a swap
  tile at 15 px in both languages.
- `tests/e2e/test_e2e_ui_polish.gd` (1, main.tscn and input only): a run shows its first banner in English; Spanish
  chosen in Options from the pause menu (Esc, Down, Down, Enter, Down ×4, Right, Right) turns the banner on screen into
  Spanish at once; back in the run the weapon slot reads "Clic izq.".
- The 30 MX4 modifier cards' pick-card text is covered by the existing
  `tests/unit/presentation/test_card_frames.gd::test_every_card_fits_in_english_and_spanish` (every `data/items` card,
  en and es, at the pick and shop scales, with the minimum readable sizes for 1280 × 720); it passed in the run below.
- `tests/MIN_TEST_COUNT` 1333 → 1348.

## Commands and raw output
Full suite (lint, import, `scripts/verify.sh`) on `62aa597`:
```
$ bash /tmp/claude-0/vd.sh /home/user/zero-depth/.claude/worktrees/agent-a5bfe1c4c5dce4870 up
verify exit 0
Tests              1348
Passing Tests      1348
check_gut_log: ok (1348 passing, minimum 1348)
```
From `/tmp/claude-0/vd_up.clean.log`: `Asserts 1256126`, `Time 2632.225s`; `grep -c "SCRIPT ERROR"` → 0,
`grep -c "Ignoring script"` → 0.

Export smoke:
```
$ cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh      # exit 0; tail:
  ok    content validates inside the pack (0 errors)
  ok    manifest hash c315e054fd34 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is Play / Jugar
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 87
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```

Screenshots (`scripts/shots/ui_polish.gd`, a tool, not a test; it poses HP at 72 %, Hot heat, Blink, two shrine stats
and two curses, and later fills the six modifier slots and grants a seventh through the dev panel's `DebugApi`):
```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json XDG_DATA_HOME=<empty dir> xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/ui_polish.gd
polish: renderer=forward_plus
polish: posed hp 77 / 108, abilities 2, gamble true, curses 2
polish: res://build/shots/v0.5.5/polish/ui_polish_hud_en_1920x1080.png
polish: banner en = 'New: Charger'
polish: banner es = 'Nuevo: Embestidor'
polish: res://build/shots/v0.5.5/polish/ui_polish_hud_es_1920x1080.png
polish: res://build/shots/v0.5.5/polish/ui_polish_pause_es_1920x1080.png
polish: res://build/shots/v0.5.5/polish/ui_polish_pause_en_1920x1080.png
polish: res://build/shots/v0.5.5/polish/ui_polish_options_audio_en_1920x1080.png
...  (display, controls, accessibility, language; en and es)
polish: res://build/shots/v0.5.5/polish/ui_polish_pause_switched_es_1920x1080.png
polish: queued 6 modifiers
polish: res://build/shots/v0.5.5/polish/ui_polish_hud_build_en_1920x1080.png
exit 143
```
(That run was on the merged build, before the 285 s guard; it ran 37 min under the load of the concurrent suite and
was killed by the lead, so `hud_build_es` and the Swap shots of this build were not taken.)
```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json XDG_DATA_HOME=<empty dir> timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/ui_polish.gd
polish: renderer=forward_plus
polish: posed hp 77 / 108, abilities 2, gamble true, curses 2
polish: res://build/shots/v0.5.5/polish/ui_polish_hud_en_1280x720.png
polish: banner en = 'New: Charger'
polish: banner es = 'Nuevo: Embestidor'
polish: res://build/shots/v0.5.5/polish/ui_polish_hud_es_1280x720.png
polish: stopped at frame 149 (time or start limit); shots so far are kept
exit 2
```
Copied by hand into this folder: `ui_polish_hud_es_1920x1080.png` (Spanish banner "Nuevo: Embestidor" after a live
switch, "Clic izq." key, threat slab in Ember stone, build row slab), `ui_polish_hud_en_1280x720.png`,
`ui_polish_hud_es_1280x720.png`, `ui_polish_hud_build_en_1920x1080.png`, `ui_polish_pause_es_1920x1080.png` (shrine
stats and threat in Cold glass), `ui_polish_pause_switched_es_1920x1080.png` (the pause screen after choosing Spanish
in its Options: run line and panels in Spanish), `ui_polish_options_controls_es_1920x1080.png` (binding cells in
Spanish), `ui_polish_options_display_es_1920x1080.png` ("Volver" left-aligned).

**NOT YET RUN on the final build:** the Swap panel shots (both sizes) and the 1280 × 720 pause / Options shots. A
Swap shot of the earlier MX2-only build (`122a7bb`'s parent code, before MX3 / MX4) was looked at during the step; it
was not kept, so no Swap image is in this folder.

## Not done / open (bigger than this step)
- The HUD's combo badges (`ComboIconView` tiles) and the build picker's grid backdrop keep their older card look (the
  owner kept the cards; a restyle would be a G2 question).
- The pick, shop and event card panels opened before a language switch keep their text until they close (a switch is
  only possible from the pause menu, over an open pick); not fixed here.
- The Options Controls list in Spanish: the pad column's long names ("Stick izquierdo a la izquierda") push the
  columns; nothing is clipped, but the list is tight next to its scroll bar.
- The Swap hint's "←→" glyphs are not in Atkinson Hyperlegible; they render through the engine's font fallback on
  this machine (seen in the MX2-build shot); on other systems that is **NOT YET RUN**.
- Feel and readability on the owner's screen: **OWNER ONLY**.
