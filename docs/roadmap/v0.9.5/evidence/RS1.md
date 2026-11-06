# v0.9.5 Step RS1: the Runic Stone (RUNIC_STONE.md rows S1-S5, R1-R3)

Machine: owner PC (i7-10700K, RTX 3060), Windows, Godot 4.7.2, headless tests with `--language en`, one `APPDATA` folder per job.

## What changed
- **S1:** the hub's credits stone is the **Runic Stone** (`HUB_RUNIC_STONE` en "Runic Stone" / es "Piedra rúnica", prompt `HUB_PROMPT_RUNIC_READ`
  "[E / X] Read" / "[E / X] Leer"). Station id and panel are `runic` in `data/hub/rune_ring.tres`. The Credits are a main-menu item between
  Options and Quit (`MENU_CREDITS` en "Credits" / es "Créditos"), opening the existing Credits screen; Esc / pad B returns to the menu. The stone no longer opens Credits.
- **Storage:** profile section `runes` = `{"learned": ["r1", ...]}` in learn order, created on the first write (`RunicStone.learn`); reading creates nothing, so an old profile loads and saves as it was. No version bump.
- **`RunicStone`** (`src/application/runic_stone.gd`): `learned()`, `learn(id)` (idempotent, true when new, unknown ids refused), `is_awake()` (has r1), `newest_first()`, `pending_pulse`, `sync(purple, deaths)` / `sync_from(stores)`, `press(tick)` (R3), `read_next()` (newest first, cycles), `walked_away()`.
- **Lines as data:** `data/hub/runic_lines.tres` (`RunicLinesDefinition` + `RunicLineEntry`, category `runic_lines`, validated: ids `rN`, no duplicates, English only A-Z and single spaces). r1-r3 hold the spec's English. RS2 adds R4-R10 as rows plus a trigger in `RunicStone.sync`.
- **R1 / S3:** `AchievementTracker.observe` reports the stat `runes:purple` the first tick `WorldReader.purple_lit()` turns true (also off in a tweaked run, like every tracker stat). The hub entry (`HubRunic.setup`) runs `sync_from`, learns r1, saves the profile, lights the veins and pulses once (S5).
- **R2:** the hub entry learns r2 when the Codex's deaths (`enemies.deaths` + `bosses.deaths`, i.e. deaths with a known killer) reach 10; this also covers a profile that already holds 10 on load.
- **R3:** pressing the woken stone 7 times in a row, each within 180 ticks (3 s) of the last, with no walk-away in between, learns r3; the bubble then shows it.
- **S2 locked:** no halo or light, a dark tint on the model; walking up shows no prompt (the name "Runic Stone" still shows) and a faint "..." bubble; a press plays the hum and nothing else.
- **S4 awake:** `[E / X] Read`; a press opens `RuneBubble` (`src/presentation/hub/rune_bubble.gd`, a Control drawn in code) with the newest line in violet glyphs, each fading in 0.05 s after the last; pressing again shows the next learned line (cycling); walking away closes it. Rows wrap at 14 glyphs on word breaks.
- New files: `src/app/hub_runic.gd` (the hub-side controller; keeps `main.gd` at 1000 lines: +2 lines, -2 lines), `src/application/rune_cipher.gd`, `src/application/runic_stone.gd`, `src/presentation/hub/runic_glyphs.gd`, `rune_bubble.gd`, `src/content/defs/runic_line_entry.gd`, `runic_lines_definition.gd`, `scripts/shots/rs1_shots.gd`.
  (`RuneGlyphs` already exists in `world_view/`, so the stroke table is `RunicGlyphs`.)

## The cipher table (RuneCipher.LETTER_GLYPH; glyph id = Futhark order, 0 fehu .. 23 othala)
| Letter | Rune (id) | Letter | Rune (id) | Letter | Rune (id) |
|---|---|---|---|---|---|
| A | ansuz 3 | J | jera 11 | S | sowilo 15 |
| B | berkana 17 | K | kaunan 5 | T | tiwaz 16 |
| C | thurisaz 2 (spare rune) | L | laguz 20 | U | uruz 1 |
| D | dagaz 22 | M | mannaz 19 | V | ingwaz 21 (spare rune) |
| E | ehwaz 18 | N | nauthiz 9 | W | wunjo 7 |
| F | fehu 0 | O | othala 23 | X | algiz 14 (shared with Z) |
| G | gebo 6 | P | perthro 13 | Y | eihwaz 12 (spare rune) |
| H | hagalaz 8 | Q | kaunan 5 (shared with K) | Z | algiz 14 |
| I | isa 10 | R | raido 4 | space | a gap |

All 24 runes are used; only Q and X share (decode reads them as K and Z). No line uses Q or X; the three spare runes (thurisaz, eihwaz, ingwaz) go to C, Y and V so every letter in the current lines is unique. This is also documented in the `RuneCipher` header comment.

## The hum cue
`void_hum` (existing `data/audio/cues/void_hum.tres`, sfx bus) played at pitch 0.55 through `AudioDirector.play(id, null, pitch)` (`HubRunic.HUM_CUE`, `HUM_PITCH`). Main connects `hub.cue_requested` to `audio.play`.

## The veins
`hub_credits_stone` is a single surface (`ShopModels` takes the first surface of the glb), so there is no second surface to put emission on. The veins are the fallback: a thin code-drawn violet ring (`TorusMesh`, emissive #9B6BFF, energy 2.2 awake) at the stone's base plus a small violet OmniLight, both off while locked. `HubView.set_runic(awake)` and `pulse_runic()` (1.2 s flare, then settle). This is a ring on the floor, not the model's own carved lines lighting up.

## Commands and raw totals
Lint: `gdformat` then `gdlint` on every changed and new .gd file: `Success: no problems found`; `src/app/main.gd` is 1000 lines.

Import: `godot --headless --language en --path . --editor --import --quit` (no errors; regenerated `locale/strings.*.translation`).

Job A (first run, before test fixes), `-gtest=` test_runic_stone, test_hub, test_hub_view, test_hub_editor:
`Tests 37, Passing 34, Failing 3` (wrap row count 2 vs 3, a stale glow-layer test, a stale menu-row test). The three tests were updated to the new design.

Job B `-gdir=res://tests/unit/application,res://tests/content,res://tests/arch,res://tests/unit/presentation,res://tests/unit/tools -ginclude_subdirs` (after the fixes):
`Scripts 210, Tests 1392, Passing 1391, Failing 1`. The one failure is `tests/unit/presentation/test_status_visuals.gd::test_hud_shows_the_combo_card_and_a_badge_when_a_combo_unlocks` (lines 139, 144: badge count 0 expected 1). Re-run alone with test_e2e_hub: `Scripts 2, Tests 16, Passing 15, Failing 1`, the same test. I did not check it against a baseline tree; nothing in this step touches combo badges, so it is probably older, but that is NOT VERIFIED.

Job C (e2e: runic_stone, credits, hub, pad_menus, shell, options, old_save, saves, achievements, codex, collectibles, wardrobe, rune_fragments, spanish): `Scripts 14, Tests 38, Passing 37, Failing 1`. The failure was `test_e2e_hub.gd::test_the_small_menu` (still expected four rows); fixed to Play, Options, Credits, Quit. The re-run of test_e2e_hub above passed its tests (the only failure in that run is the status_visuals one). `test_e2e_runic_stone.gd` 4/4 passed, `test_e2e_credits.gd` 1/1.

Shot: `godot --path . --language en --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/rs1_shots.gd` -> `build/shots/v0.9.5/rs1/en.png` (not committed; `build/`). It shows the awake stone with its violet ring, the three-row bubble in glyphs, and "Runic Stone / [E / X] Read". Looked at it: all 24 glyphs drawn.

No seed-loop tests and no `seams.sh` were run.

## Tests added or changed
- New `tests/unit/application/test_runic_stone.gd`: lines valid and broken, every line round-trips (encode -> glyph ids -> decode), 24 runes covered with only K/Q and Z/X shared, wrap at 14, learn order / idempotence / pulse flag, reading cycle, old profile without `runes` (loads, reading creates nothing, first write creates it), R1 stat, R2 at 10 including from the Codex on load, R3 (six then a gap resets, seven learn, walk-away resets).
- New `tests/e2e/test_e2e_runic_stone.gd` (main.tscn, input events): locked: no prompt, "..." bubble, press hums and opens nothing; the purple stat recorded, hub re-entered: veins lit, prompt "Read", press shows the line's glyphs fading in, walking away closes it; seven presses learn r3 and show it; Credits reachable from the main menu.
- Changed: `test_e2e_credits` (through the menu), `test_e2e_hub` (menu rows; the stone opens no Credits), `test_e2e_pad_menus` (pad to Credits in the menu), `test_hub`, `test_hub_view` (id `runic`, no halo, a veins test, menu rows), `test_hub_editor` (id `runic`).

## Deviations
- Station id and panel renamed `credits` -> `runic` (data, tests).
- The purple trigger is an achievement stat (`runes:purple`) saved with the profile at the end of a floor / run exit like the other stats, not a direct write at the activation tick. A run killed before that save would not wake the stone.
- R2 counts only deaths whose killer is an enemy or boss in the Codex (there is no other total-deaths stat); a death by a hazard with no killer kind is not counted.
- The locked stone still shows its name "Runic Stone" in the HUD; only the prompt is absent.
- The stone's veins are a code ring, not the model (one surface).
- The bubble is clamped to 8 px from the top of the screen when a tall line would leave it.

## OWNER ONLY
- Does the dark locked stone read as cold and dead? Do the violet ring and the pulse feel like "waking"?
- Are the hand-drawn glyph strokes good enough as Futhark runes, and is the bubble size and placement right?
- Is the hum (the Void's, slowed) the right low sound?
- Whether R2's death count is the one you meant (deaths with a known killer).
