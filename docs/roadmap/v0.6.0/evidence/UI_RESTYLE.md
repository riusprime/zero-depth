# UI_RESTYLE: the A5 pick built (PLAN v0.5.5 A5, Step UI; ships as v0.6.0)

- **Status:** RUN (built, suite and export smoke green; screenshots from the real game). Feel and fit: **OWNER ONLY**
- **Build:** worktree branch `worktree-agent-ae2ddaaae6cfd1e0b`, the Step UI changes on top of `0544483` (the WIP
  commit `0c03059` merged with `claude/lucid-fermat-9wv2tf`: DS, LK, AR); Godot `4.7.2.stable`; Linux (lavapipe Vulkan
  under Xvfb for the shots)
- **Date:** 2026-10-09
- **Who ran it:** agent

The owner's pick (verbatim, PROGRESS "Gates"): "Menu from C (we don't need to have those crystal those there, or what
is the purpose? but ingame UI, heat, health and minimap  from B(we should remove the black background tho)".

## What was built
- **HUD in B "Ember stone"** (`HudStyle.DEFAULT = EMBER`, `HudStyle.draw_plate`): chipped dark stone slabs under the
  top plate (floor, time, danger, kills), the shards, the HP plate, the skill hint, the vent hint, the heat meter and
  the boss bar; the warm ember line and glow under the HP, top, heat and boss slabs; warm type; HP is a red bar
  (`HP_RED`), and the low-HP pulse still shows on it (it pulses toward a hot pale tone; the slab edge and the screen
  edge still glow red). The danger marks are ember teeth. Ability slots are stone with the ability's colour as a
  line along the bottom, still 52 px (v0.3.5 owner line kept).
- **Heat bar:** the same straight bar (F2), the Hot / Overclock ticks and the overheat cap from the sim's heat table,
  and the colours of `HeatLooks` (unchanged values; Step LK reads them), now set inside a slab; the bar is 7 px.
- **Minimap without the black background:** the corner map draws no panel (`MinimapStyle.CORNER_PANEL = false`).
  Every line and the player arrow draw over a dark halo, rooms over a faint dark wash, and four small ember corner
  ticks mark the window. The orientation (`MinimapView.turn`) is untouched. The held full map keeps its backdrop.
- **Menus in C "Cold glass"** (`MenuStyle`, one Theme on each menu root; `MenuBackdrop`, a screen-texture blur
  shader): main menu, pause, Options, credits, the run recap and death screen, and the build picker's Back. The game
  blurred and dimmed behind (darker on the left), a left-aligned title and list, plain type, the focused row lit by
  a cold cyan wash fading right over a bright hairline with a small glass diamond beside it. The pause menu adds the
  run's line ("Floor 1 · 00:08 · 0 kills · 0 shards") and a small key hint. **No build cards and no crystal frames
  beside any menu.** Menu buttons are plain sentence case now ("Resume", "Main menu"; titles such as PAUSED stay
  capitals, as in the mockup).
- Kept: the crystal pick cards (`CrystalCard`, `CardFrames`), the item / combo / event / shop cards, everything in the
  world view (v0.5.9 Embers lighting, kit, rooms, models: no file under `src/presentation/world_view/` changed).

## Tests changed on purpose (no coverage removed)
- `tests/unit/presentation/test_hud_style.gd`: `DEFAULT` is now `EMBER` (the A5 pick); four new tests: the Ember stone
  HUD (ember slabs, red HP bar, the warning still changes the fill, chamfered slab), the corner minimap draws no
  backdrop while the full map does, the heat colours keep their values, the Cold glass pause menu (theme, backdrop,
  no crystal or build cards, left-aligned rows, the hint, the run line, the focus diamond).
- `tests/unit/presentation/test_heat_views.gd`: the Hot tick's x now adds the bar's inset (`bar.position.x`).
- `tests/e2e/test_e2e_saves.gd`, `tests/e2e/test_e2e_spanish.gd`, `tests/export/export_smoke.gd`: the expected menu
  strings are sentence case ("Continue", "Jugar").
- `tests/MIN_TEST_COUNT` 1159 → 1163.

## Commands and raw output
Full suite (import, lint, `scripts/verify.sh`), from the worktree:
```
$ bash /tmp/claude-0/vd.sh /home/user/zero-depth/.claude/worktrees/agent-ae2ddaaae6cfd1e0b ui
verify exit 0
Tests              1163
Passing Tests      1163
check_gut_log: ok (1163 passing, minimum 1163)
```
(An earlier run on the same code before the three string tests were updated failed 2 of 1163:
`test_e2e_saves.gd` `["Continue"] expected to equal ["CONTINUE"]` and `test_e2e_spanish.gd`
`["Jugar"] expected to equal ["JUGAR"]`; those assertions were updated to the new sentence case, and the run above
is after that.)

Export smoke:
```
$ cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh      # exit 0; tail:
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    manifest hash d99a80c5802a matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is Play / Jugar
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```

Screenshots (`scripts/shots/ui_restyle.gd`; a tool, not a test: it starts a run with Enter, Enter, then poses HP at
72 %, Overclock heat at Hot and grants Blink; the pause menu is opened with Esc and Options with Down, Down, Enter):
```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/ui_restyle.gd
ui: renderer=forward_plus
ui: posed hp 72 / 100, abilities 2
ui: res://build/shots/v0.5.5/ui/ui_hud_en_1920x1080.png
ui: res://build/shots/v0.5.5/ui/ui_hud_es_1920x1080.png
ui: res://build/shots/v0.5.5/ui/ui_pause_es_1920x1080.png
ui: res://build/shots/v0.5.5/ui/ui_pause_en_1920x1080.png
ui: res://build/shots/v0.5.5/ui/ui_options_en_1920x1080.png
ui: res://build/shots/v0.5.5/ui/ui_menu_en_1920x1080.png
ui: res://build/shots/v0.5.5/ui/ui_menu_es_1920x1080.png
exit 0
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/ui_restyle.gd
ui: renderer=forward_plus
ui: posed hp 72 / 100, abilities 2
ui: res://build/shots/v0.5.5/ui/ui_hud_en_1280x720.png
...
ui: res://build/shots/v0.5.5/ui/ui_menu_es_1280x720.png
exit 0
```
The 1280×720 set was taken with the script's first timing (fixed frame numbers); the 1920×1080 set with the
current one (frames counted from the run's start, after a first 1080 run posed nothing because the run had not
started by frame 40). Only the timing differs. Copied by hand into this folder: `ui_hud_*`, `ui_pause_*`,
`ui_options_en_*`, `ui_menu_*` (en and es, both sizes; Options in English only).

## Not done / open
- Feel, readability on the owner's screen, and whether the minimap halo is enough on the brightest floors:
  **OWNER ONLY**.
- The Options "Back" row stays centred under the sidebar (the category rows are left-aligned).
- The phase banner "New: Charger" shows in English in the Spanish HUD shots: it appeared before the script switched
  the language, and this step did not touch it (not checked further).
- The death screen and the credits are restyled through `MenuPanel` / `MenuStyle` but were not screenshotted.
