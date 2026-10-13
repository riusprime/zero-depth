# CODEX: does the Codex fill from play, open from both menus, persist, and fit en / es at 1080p and 720p?

- **Status:** RUN (tests, lint, screenshots); the owner's look and feel: OWNER ONLY
- **Build:** tests and lint on `00ccc9a` on `v075-cx` (the code as committed in `v0.7.5 Step CX`, which adds only
  docs and these PNGs); screenshots on `8cdf494` (the one code change after it sets the focus neighbours between the
  top tile row and the page's tab: no visual change);
  Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114` (cloud container)
- **Date:** 2026-10-12
- **Who ran it:** agent

## What was built (owner N6, PLAN "CX")
- `src/application/codex_store.gd` (`CodexStore`): the profile's `codex` section and its counter API (below).
- `src/application/codex_catalog.gd` (`CodexCatalog`): every entry from the content: cards by pool (retired v0.6
  cards, starting weapons and curse cards left out), every enemy, boss and biome definition.
- `src/application/codex_recorder.gd` (`CodexRecorder`): reads each floor's `WorldReader` and `SimEvent`s after
  every tick (wired in `Main`), writes the profile only; off in a run with the dev panel's balance tweaks.
- `src/presentation/menus/codex_view.gd`, `codex_tile.gd`, `codex_icon.gd`, `codex_glyphs.gd`: the page.
- Menus: a Codex row on the main menu (after Credits) and the pause menu (after Options).
- Content: `desc_key` on `EnemyDefinition`, `BossDefinition`, `BiomeDefinition` (the Codex line), set on the 14
  enemies, 6 bosses and 3 biomes, en + es in `locale/strings.csv` (48 new rows in all).

## Counter API (for AC, local achievements)
`CodexStore` (application layer; `Main.codex` holds the game's one, built on `ProfileStore.shared()`):

| Call | What it does |
|---|---|
| `CodexStore.new(profile: ProfileStore)` | A view on `profile`'s `codex` section (created on first use; an old profile without it reads as empty) |
| `is_unlocked(page, id) -> bool` | The entry was met |
| `unlock(page, id) -> bool` | Marks it met; true when it was new |
| `add(page, id, counter, by := 1) -> int` | Counts up (and unlocks); returns the new value |
| `raise_to(page, id, counter, value) -> int` | Keeps the highest (card levels); returns the counter after |
| `count(page, id, counter) -> int` | One counter (0 when never written) |
| `total(page, counter) -> int` | A counter summed over a page (e.g. every enemy killed) |
| `unlocked_ids(page) -> Array[StringName]`, `unlocked_count(page) -> int` | What was met |
| `signal unlocked(page, id)` | On an entry's first meeting |
| `signal changed(page, id, counter, value)` | After every counter write that changed it |
| `dirty: bool` | A write not yet saved (Main saves the profile at the end of each floor) |

Pages (`CodexStore.PAGES`) and counters (`CodexStore.COUNTERS`):

| Page | Counters | Written when |
|---|---|---|
| `cards` | `offered`, `taken`, `level` | a pick / the shop / an event shows it; its `PICKUP`; the wand's or the ability slots' level after a pick |
| `enemies` | `kills`, `deaths` | its `KILL` (not a boss's); the run's end when it was `killer_kind` |
| `bosses` | `fights`, `kills`, `deaths` | it rose within 18 m (once per boss per floor); `BOSS_DEFEATED`; the run's end |
| `biomes` | `visits` | a floor of it starts (not when Continue resumes one) |

Stored as `{"version": 1, "cards": {id: {counter: n}}, "enemies": {…}, "bosses": {…}, "biomes": {…}}` in
`user://profile.json`. AC can add its own section (or page) beside it and listen to `unlocked` / `changed`, or read
`count` / `total` when a run ends. `ProfileStore.PROFILE_VERSION` was not bumped: the section carries its own
`version`, and a missing section is an empty Codex.

## Command
```
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/application,res://tests/unit/presentation,res://tests/content,res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_codex.gd,res://tests/e2e/test_e2e_shell.gd,res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_ui_polish.gd,res://tests/e2e/test_e2e_wand_build.gd,res://tests/e2e/test_e2e_credits.gd,res://tests/e2e/test_e2e_options.gd,res://tests/e2e/test_e2e_spanish.gd,res://tests/e2e/test_e2e_lighting.gd,res://tests/e2e/test_e2e_dev_master_panel.gd -gexit
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/codex.gd -- lang=en size=1920x1080
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/codex.gd -- lang=es size=1920x1080
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/codex.gd -- lang=es size=1280x720
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/codex.gd -- lang=en size=1280x720
```

## Raw output
Lint (exit 0):
```
699 files would be left unchanged
Success: no problems found
```

Unit, content, arch and golden folders (exit 0; the run summary, `[… earlier lines trimmed …]`):
```
Totals
------
Deprecated            1

Scripts             101
Tests               585
Passing Tests       585
Asserts           650896
Time              310.81s


---- All tests passed! ----
```

The e2e files (exit 0; the run summary, `[… earlier lines trimmed …]`):
```
Totals
------
Scripts              12
Tests                24
Passing Tests        24
Asserts             312
Orphans              60
Time              87.227s


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

Screenshots (lavapipe under xvfb, Forward+; the script's own lines, the worktree path shortened to `<worktree>`):
```
codex: renderer=forward_plus lang=en size=1920x1080
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1920x1080_cards_locked.png (1920, 1080)
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1920x1080_cards.png (1920, 1080)
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1920x1080_enemies.png (1920, 1080)
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1920x1080_bosses.png (1920, 1080)
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1920x1080_biomes.png (1920, 1080)
codex: renderer=forward_plus lang=es size=1920x1080
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1920x1080_cards_locked.png (1920, 1080)
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1920x1080_cards.png (1920, 1080)
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1920x1080_enemies.png (1920, 1080)
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1920x1080_bosses.png (1920, 1080)
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1920x1080_biomes.png (1920, 1080)
codex: renderer=forward_plus lang=es size=1280x720
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1280x720_cards_locked.png (1280, 720)
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1280x720_cards.png (1280, 720)
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1280x720_enemies.png (1280, 720)
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1280x720_bosses.png (1280, 720)
codex: shot <worktree>/build/shots/v0.7.5/codex/es_1280x720_biomes.png (1280, 720)
codex: renderer=forward_plus lang=en size=1280x720
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1280x720_cards_locked.png (1280, 720)
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1280x720_cards.png (1280, 720)
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1280x720_enemies.png (1280, 720)
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1280x720_bosses.png (1280, 720)
codex: shot <worktree>/build/shots/v0.7.5/codex/en_1280x720_biomes.png (1280, 720)

[exited with code 0]
```

## Screenshots
Copied by hand from `build/shots/v0.7.5/codex/` (shot setup: a memory-only profile with a few entries met; the menus
reached by key presses):
- [`shots/codex/en_1920x1080_cards.png`](shots/codex/en_1920x1080_cards.png): the Cards page, a met Gun card
  focused (its crystal card, its sentence, Offered 3 · Taken 2 · Highest level —), locked tiles as "???".
- [`shots/codex/es_1920x1080_bosses.png`](shots/codex/es_1920x1080_bosses.png): Spanish, the Bosses page, the
  Warlord met.
- [`shots/codex/en_1920x1080_biomes.png`](shots/codex/en_1920x1080_biomes.png): the Biomes page (the landscapes
  in each biome's palette).
- [`shots/codex/es_1280x720_cards.png`](shots/codex/es_1280x720_cards.png),
  [`shots/codex/en_1280x720_enemies.png`](shots/codex/en_1280x720_enemies.png): 1280 × 720.

## Tests added or changed
- `tests/unit/application/test_codex.gd` (12): the store (unlock, add, highest level, totals, signals), the file
  round trip, an old profile without the section, a broken section repaired; the catalog (pools, retired cards
  out, starting weapons out, every enemy / boss / biome from the data, kind maps); the recorder (an enemy met within
  range and not beyond, its kill, a death to it counted once, a taken card's count and level, biome visits, a
  tweaked run records nothing, another floor's reader ignored).
- `tests/unit/presentation/test_codex_view.gd` (3): silhouettes and met entries, up from the top row to the page's own tab, (the game's name key, sentence,
  counts), pages from the data, the page and every entry's detail inside 1920 × 1080 in en and es, tile names in at
  most two lines.
- `tests/content/test_codex_content.gd` (2): every Codex key exists; every shipped enemy, boss and biome has its line.
- `tests/e2e/test_e2e_codex.gd` (1): through `main.tscn` by input only (keyboard, pad, mouse): the main menu's Codex
  (all locked; RB, B), a Gun run (the biome visited), an altar's first card taken, an enemy shot dead, the pause
  menu's Codex showing the card met and taken once, the Enemies page by E with the kill, Esc back to the pause menu,
  then the main menu's Codex still holding them; a tab click, the Biomes page, Back by mouse.
- Updated for the new pause row: `test_e2e_shell.gd`, `test_e2e_pad_menus.gd`, `test_e2e_saves.gd`,
  `tests/unit/presentation/test_run_recap.gd`.

## Interpretation
- The Codex fills from play only through the app layer's reading of the sim (no sim file changed; the replay golden
  ran in the units run above).
- Not run by the agent: the full suite and the bot sims (the lead's, once per wave). `tests/MIN_TEST_COUNT` was not
  changed (the lead sets it after the wave's full run).
- **OWNER ONLY:** whether the Codex reads well and is worth opening; the lead's readings in PLAN "CX" (what unlocks
  an entry, the 18 m "met" range, the sections, the Codex lines written for enemies, bosses and biomes).
- Known limits: the wand cards that have no symbol of their own (most G / B cards) show the card gem in their frame
  colour, as they do in the game; enemy and boss pictures are code-drawn emblems, not their models (an art request).
  A new biome, enemy or boss from NB1 / NB2 appears automatically; `test_codex_content.gd` then asks for its
  `desc_key` line.
