# ACHIEVEMENTS: do local achievements unlock from play, toast, persist, and show on the Codex's page in en / es?

- **Status:** RUN (tests, lint, screenshots); the owner's look and feel, and the list itself: OWNER ONLY
- **Build:** tests, lint and screenshots on `adaa317` on `v075-ac` (the `v0.7.5 Step AC` commit after it adds only
  docs and these PNGs); Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114` (cloud container)
- **Date:** 2026-10-13
- **Who ran it:** agent

## What was built (owner N7, PLAN "AC")
- `src/content/defs/achievement_definition.gd` (`AchievementDefinition`, category `achievements`) and 29 files in
  `data/achievements/`, found by `ContentScanner` and validated (CONTENT_SCHEMA "Achievements").
- `src/application/achievement_store.gd` (`AchievementStore`): the profile's `achievements` section
  `{"version": 1, "unlocked": {id: n}, "stats": {key: value}}`; `ProfileStore.fresh()` carries it.
- `src/application/achievement_book.gd` (`AchievementBook`): every achievement (the per-boss and per-biome ones
  expanded from the Codex's entries) and each condition's progress and goal.
- `src/application/achievement_tracker.gd` (`AchievementTracker`): reads each floor's `WorldReader` and `SimEvent`s
  after every tick (wired in `Main` beside `CodexRecorder`), listens to `CodexStore`'s `changed` / `unlocked`,
  unlocks, emits `achieved`; off in a tweaked dev-panel run (`Main._tweaked_run_check`).
- `src/presentation/hud/achievement_toast.gd` (`AchievementToast`, on Main's UI layer),
  `src/presentation/menus/achievements_page.gd`, `achievement_row.gd`, `achievement_icon.gd`,
  `achievement_glyphs.gd`; `CodexView` takes an optional `AchievementBook` and shows a fifth page.
- 72 rows in `locale/strings.csv` (14 `UI_ACH_*`, 58 `ACH_*`), en + es, written by the agent.
- No sim file changed.

## The list (37 achievements from 29 definitions)
Kinds: STAT = a run counter (below); TOTAL / MAX = a Codex counter summed / highest over a page; EACH = one per
Codex entry; EVERY = every Codex entry of a scope. "Hidden": "???" until unlocked.

| Group | Id | Name (en / es) | Needs | Kind |
|---|---|---|---|---|
| The run | `clear_floor_1` | First Steps Down / Primeros pasos | clear floor 1 (take its portal) | STAT `floors:cleared_1` ≥ 1 |
| The run | `clear_floor_2` | Halfway Down / A medio camino | clear floor 2 | STAT `floors:cleared_2` ≥ 1 |
| The run | `win_run` | Bottom of the World / El fondo del mundo | win a run | STAT `runs:won` ≥ 1 |
| The run | `win_gun` | Steady Aim / Pulso firme | win with the Gun | STAT `runs:won_gun` ≥ 1 |
| The run | `win_blade` | Clean Cut / Corte limpio | win with the Blade | STAT `runs:won_blade` ≥ 1 |
| The run | `win_5` | Old Hand / Veterano | win 5 runs | STAT `runs:won` ≥ 5 |
| Bosses | `boss_brood_mother`, `boss_foundry`, `boss_gatekeeper`, `boss_hive_lens`, `boss_siege_engine`, `boss_warlord` | Victory: %s / Victoria: %s | defeat that boss once | EACH bosses `kills` ≥ 1 |
| Bosses | `bosses_all` | Monster Hunter / Cazamonstruos | defeat every boss | EVERY bosses `kills` ≥ 1 |
| Biomes | `biome_frozen_shore`, `biome_night_rocks`, `biome_red_canyon`, `biome_ruins` | Footprints: %s / Huellas: %s | enter a floor of that biome | EACH biomes `visits` ≥ 1 |
| Biomes | `biomes_all` | World Walker / Trotamundos | enter a floor of every biome | EVERY biomes `visits` ≥ 1 |
| The wand | `wand_full` | Full Wand / Varita completa | hold 8 cards in the wand | STAT `wand:cards_max` ≥ 8 |
| The wand | `card_level_5` | Mastered / Maestría | a card at level 5 | MAX cards `level` ≥ 5 |
| The wand | `trigger_kill` | Chain Reaction / Reacción en cadena | a child spell's kill | STAT `kills:child_spell` ≥ 1 |
| The wand | `trigger_kills_100` | Clockwork / Mecanismo de relojería | 100 child-spell kills | STAT `kills:child_spell` ≥ 100 |
| Combat | `kills_1` | First Blood / Primera sangre | kill an enemy | TOTAL enemies `kills` ≥ 1 |
| Combat | `kills_100` | Culling / Escabechina | 100 kills | TOTAL enemies `kills` ≥ 100 |
| Combat | `kills_1000` | Legion's End / El fin de la legión | 1,000 kills | TOTAL enemies `kills` ≥ 1000 |
| Combat | `no_hit_room` | Untouched / Intacto | clear a sealed room without losing HP | STAT `rooms:no_hit` ≥ 1 |
| Combat | `sealed_rooms_10` | Gatecrasher / Revientapuertas | clear 10 sealed rooms | STAT `rooms:sealed_cleared` ≥ 10 |
| Combat | `overrun_cleared` | Hold the Line / Resistir el asedio | clear an Overrun room | STAT `overruns:cleared` ≥ 1 |
| Risk and reward | `cursed_card` | Devil's Bargain / Pacto con el diablo | take a cursed chest's card | STAT `curses:chest_card` ≥ 1 |
| Risk and reward | `core_stolen` | Heist / Golpe maestro | steal a core | STAT `cores:stolen` ≥ 1 |
| Risk and reward | `shards_500` | Big Spender / A lo grande | spend 500 shards in shops | STAT `shards:spent` ≥ 500 |
| The Codex | `codex_gun` | Gunsmith's Ledger / Libro del armero | see every Gun-pool card | EVERY cards / gun, met |
| The Codex | `codex_blade` | Bladesmith's Ledger / Libro del espadero | see every Blade-pool card | EVERY cards / blade, met |
| The Codex | `codex_triggers` | Every Trigger / Todos los disparadores | see every trigger card | EVERY cards / triggers, met |
| The Codex | `codex_enemies` | Field Guide / Guía de campo | meet every enemy | EVERY enemies, met |
| Ascension (hidden) | `ascend_1` | Ascension / Ascensión | Ascend once | STAT `runs:ascended` ≥ 1 |
| Ascension (hidden) | `ascend_5` | Endless / Sin fin | Ascend 5 times | STAT `runs:ascended` ≥ 5 |

A 5th biome (NB2) or a new boss adds its own `biome_<id>` / `boss_<id>` and joins `biomes_all` / `bosses_all` with
no new file (`AchievementBook.build` expands from `CodexCatalog`); its name key is its own, so the entry needs only
the biome's or boss's `name_key`.

## Run counters (`AchievementDefinition.STATS`, recorded by `AchievementTracker`)
| Counter | Recorded when |
|---|---|
| `floors:cleared_N` | the floor's outcome turns 3 (its portal taken) or 1 (the run won on it), once per floor |
| `runs:won`, `runs:won_gun` / `runs:won_blade` | outcome 1; the weapon is `WorldReader.wand()["weapon"]` |
| `wand:cards_max` | the most cards `WorldReader.wand()["cards"]` held (read after a PICKUP / SHOP_BUY, and every 30 ticks) |
| `kills:child_spell` | a player KILL whose DAMAGE's HIT carried `proc_pct` under 100 (a hook's attack: a trigger card's child spell, a split, an echo) |
| `rooms:sealed_cleared`, `rooms:no_hit` | `WorldReader.arenas()` gains a cleared room (arenas and the Overrun); clean when no DAMAGE to the hero with HP lost since it sealed |
| `overruns:cleared` | `WorldReader.overrun()["cleared"]` turns true |
| `curses:chest_card` | a PICKUP whose card is a curse card (`CARD_CURSE`: only a cursed chest's card is) |
| `cores:stolen` | `WorldReader.steal_tick()` moves |
| `shards:spent` | each SHOP_BUY's `amount` |
| `runs:ascended` | **reported by the Ascension portal (AP)**: `main.achievement_tracker.report(&"runs:ascended")` once per Ascend; nothing in AC writes it |

## Command
```
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/application,res://tests/unit/presentation,res://tests/content,res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_achievements.gd,res://tests/e2e/test_e2e_codex.gd,res://tests/e2e/test_e2e_shell.gd,res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_ui_polish.gd,res://tests/e2e/test_e2e_wand_build.gd,res://tests/e2e/test_e2e_credits.gd,res://tests/e2e/test_e2e_options.gd,res://tests/e2e/test_e2e_spanish.gd,res://tests/e2e/test_e2e_lighting.gd,res://tests/e2e/test_e2e_dev_master_panel.gd,res://tests/e2e/test_e2e_frozen_shore.gd -gexit
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1920x1080 -s scripts/shots/achievements.gd -- lang=en size=1920x1080
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1920x1080 -s scripts/shots/achievements.gd -- lang=es size=1920x1080
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s scripts/shots/achievements.gd -- lang=en size=1280x720
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s scripts/shots/achievements.gd -- lang=es size=1280x720
```

## Raw output
Lint (exit 0):
```
725 files would be left unchanged
Success: no problems found
```

Unit, content, arch and golden folders (exit 0; the run summary, `[… earlier lines trimmed …]`):
```
Totals
------
Deprecated            1

Scripts             105
Tests               616
Passing Tests       616
Asserts           713745
Time              359.218s


---- All tests passed! ----
```

The e2e files (exit 0; the run summary, `[… earlier lines trimmed …]`):
```
Totals
------
Scripts              14
Tests                26
Passing Tests        26
Asserts             370
Orphans              60
Time              135.001s


---- All tests passed! ----

WARNING: 60 RIDs of type "CanvasItem" were leaked.
   at: _free_rids (servers/rendering/renderer_canvas_cull.cpp:2735)
WARNING: 1921 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 63 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
ERROR: 14 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit.
ERROR: 80 RID allocations of type 'PN18TextServerAdvanced22ShapedTextDataAdvancedE' were leaked at exit.
ERROR: 1 RID allocations of type 'PN18TextServerAdvanced12FontAdvancedE' were leaked at exit.
```
(The same 60 orphans and exit-time leak lines as CX's run of the same e2e files without the new one.)

Screenshots (lavapipe under xvfb, Forward+; each run's own lines, the worktree path shortened to `<worktree>`):
```
achievements: renderer=forward_plus lang=en size=1920x1080
achievements: shot <worktree>/build/shots/v0.7.5/achievements/en_1920x1080_page.png (1920, 1080)
achievements: shot <worktree>/build/shots/v0.7.5/achievements/en_1920x1080_page_scrolled.png (1920, 1080)
achievements: shot <worktree>/build/shots/v0.7.5/achievements/en_1920x1080_toast.png (1920, 1080)
achievements: renderer=forward_plus lang=es size=1920x1080
achievements: shot <worktree>/build/shots/v0.7.5/achievements/es_1920x1080_page.png (1920, 1080)
achievements: shot <worktree>/build/shots/v0.7.5/achievements/es_1920x1080_page_scrolled.png (1920, 1080)
achievements: shot <worktree>/build/shots/v0.7.5/achievements/es_1920x1080_toast.png (1920, 1080)
achievements: renderer=forward_plus lang=en size=1280x720
achievements: shot <worktree>/build/shots/v0.7.5/achievements/en_1280x720_page.png (1280, 720)
achievements: shot <worktree>/build/shots/v0.7.5/achievements/en_1280x720_page_scrolled.png (1280, 720)
achievements: shot <worktree>/build/shots/v0.7.5/achievements/en_1280x720_toast.png (1280, 720)
achievements: renderer=forward_plus lang=es size=1280x720
achievements: shot <worktree>/build/shots/v0.7.5/achievements/es_1280x720_page.png (1280, 720)
achievements: shot <worktree>/build/shots/v0.7.5/achievements/es_1280x720_page_scrolled.png (1280, 720)
achievements: shot <worktree>/build/shots/v0.7.5/achievements/es_1280x720_toast.png (1280, 720)
```
Each run exited 0.

## Screenshots
Copied by hand from `build/shots/v0.7.5/achievements/` (shot setup: a memory-only profile with 4 achievements and a
few counters; the menus reached by key presses; the run started by `Main.start_stage`, its first floor's biome
raising the toast by play):
- [`shots/achievements/en_1920x1080_page.png`](shots/achievements/en_1920x1080_page.png): the Achievements page,
  lit (gold) and dimmed rows with their sentences, "0 / 5", "1 / 6".
- [`shots/achievements/es_1280x720_page_scrolled.png`](shots/achievements/es_1280x720_page_scrolled.png): Spanish
  at 1280 × 720, scrolled to the Bosses and Biomes groups.
- [`shots/achievements/es_1920x1080_toast.png`](shots/achievements/es_1920x1080_toast.png),
  [`shots/achievements/en_1280x720_toast.png`](shots/achievements/en_1280x720_toast.png): the toast under the
  minimap on floor 1 ("Footprints: Red Canyon" / "Huellas: Cañón Rojo").

## Tests added or changed
- `tests/unit/application/test_achievements.gd` (14): the store (once, in order, run counters), the file round
  trip, an old profile without the section (empty; its Codex still loads), a broken section repaired; the book (one
  per boss and biome from the data, unique ids, groups), each condition kind (STAT, TOTAL, MAX, EACH, EVERY over a
  page and over a section); the tracker: a floor cleared and a won run with the weapon, a child spell's kill vs a
  root attack's, a sealed room clean vs hurt, Overrun / core / cursed card / shards / a full wand, Codex writes
  unlocking (once), a profile that already meets one unlocking at a floor's start, a tweaked run recording nothing,
  the `runs:ascended` hook, another floor's reader ignored.
- `tests/unit/presentation/test_achievements_view.gd` (5): the fifth tab, lit / dimmed (name, sentence, "2 / 5") /
  hidden ("???") rows, focus between the tab and the first line; no tab without a book; the page and every row fit
  1920 × 1080 in en and es (names in one line, sentences in two); the toast's queue, its translated line, every
  achievement's toast inside the screen in en and es (name in two lines, sentence in three at most); it fades out on
  its own and never takes the mouse or the focus.
- `tests/content/test_achievement_content.gd` (4): scanned and valid, keys in en and es with `%s` exactly on the
  per-entry ones, pages / counters / sections agree with the Codex, bad definitions are errors.
- `tests/e2e/test_e2e_achievements.gd` (1): through `main.tscn` by input only: a Gun run's biome achievement and its
  toast, an enemy shot dead unlocking First Blood and its toast (the game not paused), the pause menu's Codex, E to
  the Achievements page (First Blood lit, a locked one dimmed with its sentence, a hidden one "???", arrows move),
  Esc back; the main menu's Codex, its Achievements tab by mouse (still there: the profile), LB / RB, pad B out.

## Interpretation
- Achievements unlock from play only through the app layer's reading of the sim and the Codex (no sim file
  changed; the replay golden ran in the units run above).
- Not run by the agent: the full suite and the bot sims (the lead's, once per wave). `tests/MIN_TEST_COUNT` was not
  changed (the lead sets it after the wave's full run).
- **OWNER ONLY:** whether the list is the right one and fun to chase, the names and sentences (en and es), the
  toast's place and time on screen, the page's look; the lead's readings in PLAN "AC".
- Known limits: `kills:child_spell` counts every hook's kill (a split, an echo), not only a trigger card's child
  spell: the sim's events carry the hook level (`proc_pct`), not which card made the hook. `win_*` and the floor
  counters read the floor's outcome, so how the Ascension portal's "End the run" reports a win is AP's to keep
  (outcome 1 counts as a win here). The glyphs are code-drawn placeholders, not art.
