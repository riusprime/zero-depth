# SMALL_THINGS: do the card levels show, do the first-run hints show once, are the credits generated, do the options reach the new screens, and where does the release checklist stand?

- **Status:** RUN (lint, the folders touched and their e2e, the menu / options / HUD / pick e2e, `tests/content`,
  `tests/arch`; screenshots at 1280×720 in en and es; 1920×1080: NOT YET RUN). Not run by the agent: the full suite
  and the bot sims (the lead's, once per wave). The owner's look and feel, the hint wording and placement: OWNER ONLY
- **Build:** three rounds, each named below: the first runs (content / arch, the units, the 31 e2e) on the tree of
  `5e93c3c` plus the new test files and a `CreditsView` compile fix (all in `49dbaed`); a re-run on `49dbaed`; the
  final re-run, lint and screenshots on `191dbcd` (the `v0.7.5 Step SM` commit after it adds only this file and the
  PROGRESS / PLAN lines); Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114` (cloud container)
- **Date:** 2026-10-13
- **Who ran it:** agent

## What was built (owner N8, PLAN "SM")

### 1. Card levels shown
- `PickPanel.card_face` (shared by the altar and chest pick, the shop's stock, the event panel and the Swap) adds
  `level_text` and `held_level` for a card that levels: a wand card (`card_info.wand`, CardLevels 1–5) and an ability
  card. "Lv 1" not held; "Lv N → N+1" held; `legendary_face` "Lv N → 5" (the legendary tier's `wand_level`; "Lv 5"
  not held). `PickPanel.held_level` reads the level from `WorldReader.build()`'s slots.
- `CrystalCard` draws it as a small badge centred just above its text panel (on the frame, clear of the title);
  `PickSlot` passes it. The rarity line is unchanged.
- `BuildHud` (the HUD's wand pips) and `WandRow` (the Build page) show a wand card's level as they showed an ability
  modifier's. `Wand.read`'s cards carry `wand` (a read key, nothing hashed).
- Strings: `UI_CARD_LEVEL_UP` "Lv %d → %d" / "Nv %d → %d" (the "Lv %d" / "Nv %d" key `UI_WAND_LEVEL` already existed).

### 2. Onboarding: first-run hints
- `src/application/hint_store.gd` (`HintStore`): the profile's `hints` section `{"seen": [ids]}` (in
  `ProfileStore.fresh()` since v0.0.1, unused until now), the `hints` setting, `due` / `mark` / `reset`, `dirty`.
- `src/presentation/hud/onboarding_hints.gd` (`OnboardingHints`, on Main's UI layer beside the achievement toast):
  ten hints, each once: `move` (move and aim), `attack`, `dash` at a first run's start, each closing when you do it;
  `vent` when the heat first reads Hot; `pick` (the wand reads left to right) when the first card pick opens; `build`
  (pause → Build) after the first card joins the wand; `trigger` when the wand first holds a trigger card; `shop`;
  `portal` (the first open portal); `codex` (pause → Codex) at the second floor's start. Non-blocking (mouse ignored,
  no focus, the game never waits), 2–9 s, fades only; at the top centre, and low (its bottom 82 px above the screen's,
  over the heat meter) while a pick, Swap, shop or event panel is open, so it never covers the panel's title or cards
  (the first screenshot round showed the top slab over the pick's title; fixed in `191dbcd`); waits under the pause
  menu, Options, the Build page, the Codex and the recap. The keys named are the live bindings of the device used last (`InputRebind`, `InputLabels`).
- `Main`: wires it (begin / end of a floor, observe after every tick, covered by the pause menu and the recap) and
  saves the profile at a floor's end when a hint was marked.
- Options → Accessibility: "Show hints" (`hints`: on / off, on by default) and "Reset hints" (with "They will show
  again").
- Strings: 14 `HINT_*` keys and 7 option keys (`UI_UI_SCALE`, `UI_OPT_90`, `UI_OPT_110`, `UI_SHOW_HINTS`,
  `UI_RESET_HINTS_LABEL`, `UI_RESET_HINTS`, `UI_HINTS_RESET_DONE`), en + es, written by the agent; with the level key
  and the 4 credits keys, 26 new rows in `locale/strings.csv`.

### 3. Credits and licences
- `src/content/defs/licence_list_definition.gd` (`LicenceListDefinition`, category `licences`) and
  `data/credits/licences.tres`, written by `scripts/content/build_credits.gd` from the repo: every
  `assets/**/manifest.json` licence line and file count (5 manifests), every font licence in `assets/fonts` (named
  from the font files: "Atkinson Hyperlegible"), every addon's licence (`addons/gut`: "Gut 9.7.1", marked not shipped
  because `export_presets.cfg`'s exclude filter has `addons/gut/*`). `tests/content/test_credits_licences.gd` fails
  while the committed copy differs from a fresh build.
- `assets/models/manifest.json` had no licence line; it now has one that cites the docs saying whose the models and
  textures are (ART_DIRECTION §5.2 "owner-supplied models", KIT_REQUESTS "made by the owner with an AI 3D generator",
  VFX_REQUESTS "the owner generates the textures"). Nothing else in a manifest changed (the asset tests pass).
- `CreditsView` shows the app icon (`application/config/icon`, `res://icon.svg`) beside the title, then the generated
  list ("Art, models and sound", the font, the addon), then Godot's licence and notices from the engine.
- The owner's own credit line (`CREDITS_OWNER`, "…" since v0.0.1, owner action O4) is left for the owner.
- `data/credits/licences.tres` as built (`godot --headless --path . -s scripts/content/build_credits.gd`):

```
wrote res://data/credits/licences.tres (7 entries)
```

| Kind | Title | Source | Licence line (from the repo) |
|---|---|---|---|
| assets | assets/audio | assets/audio/manifest.json | Original work generated for this project by scripts/audio/generate_sfx.py (no third-party audio) · 88 files |
| assets | assets/models | assets/models/manifest.json | Supplied by the owner (Rius; docs/art/ART_DIRECTION.md §5.2, owner-supplied models): the kit pieces made by the owner with an AI 3D generator (docs/art/KIT_REQUESTS.md), the VFX textures generated by the owner (docs/art/VFX_REQUESTS.md) · 39 files |
| assets | assets/ui/build_picker | assets/ui/build_picker/manifest.json | The owner's own art (Rius, delivered 2026-10-09 for v0.6.1 R2b); no third-party art · 8 files |
| assets | assets/ui/cards | assets/ui/cards/manifest.json | The owner's own art (Rius, delivered 2026-10-08 for v0.5.5 A4); no third-party art · 12 files |
| assets | assets/ui/plaques | assets/ui/plaques/manifest.json | The owner's own art (Rius, delivered 2026-10-09 for v0.6.1 R1); no third-party art · 12 files |
| font | Atkinson Hyperlegible | assets/fonts/OFL.txt | SIL Open Font License 1.1 (full text) |
| addon (not shipped) | Gut 9.7.1 | addons/gut/LICENSE.md | MIT (full text) |

### 4. Accessibility pass (findings)
Each option already there, checked against the v0.7.x screens by reading their code and, where noted, a test.

| Option | Screen | Finding | Done |
|---|---|---|---|
| Reduced motion | Build page (`BuildPage`, `WandRow`) | No animation: nothing to reduce | — |
| Reduced motion | Codex and its Achievements page | No animation (no `_process`, no tween) | — |
| Reduced motion | Achievement toast | It **slid in 24 px** whatever the setting | **Fixed:** a fade only under reduced motion (`AchievementToast._process`) |
| Reduced motion | Build picker (v0.6.1 cards) | The cards **rose 120 px** whatever the setting (its comment said "reduced motion later") | **Fixed:** settled at once under reduced motion (`BuildPicker._ready`) |
| Reduced motion | Frozen Shore edge, portal transit | Already honoured (`BiomeEdge` motion 0, `PortalTransitView.calm`) | — |
| Reduced motion | The new hints | Fade only, no slide | built that way |
| Colour-blind modes | Codex enemy emblems | Drawn in a **fixed hostile red** whatever the mode | **Fixed:** an enemy emblem wears the mode's `enemy_body` colour (`CodexGlyphs.color`); bosses keep their gold |
| Colour-blind modes | Frozen Shore enemy tint | Only the grey and bone parts take the cold cast; the enemy red, rings and bars stay the role tokens (NB1) | — |
| Colour-blind modes | Achievements, card badges, hints | No role colour carries meaning there (gold, frame tints) | — |
| Remap | HUD (skill, vent), new hints | Live bindings of the active device | the hints follow the device used last |
| Remap | Codex (Q E / LB RB), Build page (1–8, arrows), pick (1–3) | Fixed menu keys, not remappable actions (the Controls list never had them), as in every menu | no change; noted |
| Shake | Build page, Codex, toast | Camera only; no new screen shakes | — |
| Captions | Frozen Shore | Its only new sound is an ambience loop (`data/audio/cues/frozen_shore.tres`); ambience loops have no caption (v0.3.0 AU) | — |
| Text size / UI scale | everything | **Missing** | **Added:** Accessibility "Interface size" 90 / 100 / 110 % (`ui_scale`, the window's `content_scale_factor`): every menu, the HUD and their text, not the 3D view. **125 % was built first and dropped:** at 1280×720 the pick panel (laid out for 1080 px) overflowed the 864 px it gets: its title met the top plate, its cards ran over the left HUD and its key line onto the heat meter (first screenshot round, `first_run_ui125/en_1280x720_pick_levels_ui125.png`); Options fitted. A size above 110 % needs the 1080-built panels to adapt (open). 110 %: see the screenshots |
| (new) Hints | — | — | Accessibility "Show hints" / "Reset hints" |

### 5. Release checklist (ROADMAP §0.4): the code part, and the status of the rest
- **Dev panel (F10) locked for a public release:** built as one switch. `DevGate` (application) reads
  `game/dev/panel_enabled` = **true** in project.godot; project.godot also holds
  `game/dev/panel_enabled.public_release=false`, so an export preset that adds the custom feature `public_release`
  ships with F10 and the debug ` panel locked, and ignores any saved `user://dev_tuning.json`. No preset has the
  feature: **the switch stays ON** for the owner's playtest builds (owner, 2026-10-12: "All builds, hidden key").
  `tests/unit/application/test_hint_store.gd` checks the setting, the override and that no preset has the feature.

| §0.4 item | Status |
|---|---|
| Every PLAN step Done | Open: NB2, AP (parallel agents); SM: this step |
| Full suite, export smoke, hitch probe, goldens on the release commit | NOT YET RUN (the lead's, on the merged wave and the PR) |
| `tests/MIN_TEST_COUNT` raised | NOT YET RUN (the lead's, from the full suite's count) |
| Version bumped in `project.godot` | Not done: still `0.7.0-dev` (the lead's, at the PR) |
| Patch notes v0.7.5 en + es, README index row, What's New rebuilt | Not written (needs every step Done) |
| Spanish for every new key, locale coverage green | Done for SM's 26 keys: `test_locale_coverage.gd` passed in the content runs and the final re-run below |
| Screenshot tour en + es | NOT YET RUN (`scripts/shots/tour.gd`); SM's own shots below |
| §4 row and History, README status line, CLAUDE.md re-read | Not done (the lead's, at the PR) |
| `PLAYTEST.md` | Not written (the lead's, at the PR) |
| Public releases only: dev panel removed or locked | **Built as a switch, left ON** (above) |
| (v0.9.x) Final credits and licences | Generated from the repo (above); the owner's credit line is OWNER ONLY |
| (ROADMAP §5) App icon | Present: `application/config/icon = res://icon.svg` (`test_credits_licences.gd`). The Windows preset has `application/icon=""` and `application/modify_resources=false`, so the **.exe itself carries no icon**; turning `modify_resources` on is a Windows-export change only the Windows job can check: left for the lead (open item) |

## Tests (raw output)

Lint on `191dbcd` (the last code edit):
```
$ gdformat --check src scripts tests && gdlint src scripts tests
741 files would be left unchanged
Success: no problems found
```

Content and arch, first run (before the new tests existed):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch -ginclude_subdirs -gexit
Tests               122
Passing Tests       122
Asserts           16284
Time              27.224s
```

The presentation units touched (card_frames, wand_views, shop_views, event_views, ui_polish, hud_style, codex_view,
achievements_view, colour_modes, card_level_views, onboarding_hints, item_cards, reward_views):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<those 13 files> -gexit
Tests                88
Passing Tests        88
Asserts            5752
Time              57.539s
```

Content, arch, unit/application, unit/app (the new `test_credits_licences.gd` and `test_hint_store.gd` among them):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/unit/application,res://tests/unit/app -ginclude_subdirs -gexit
Tests               193
Passing Tests       193
Asserts           16983
Time              103.853s
```

31 e2e files (credits, options, pad_menus, rewards, shop, events, swap, wand_build, wand_shared, wand_blade,
gun_pool, run_flow, ui_polish, hud_style, achievements, codex, dev_master_panel, dev_panel, shell, spanish, input,
saves, arenas, curses, portal, floor, the new hints and card_levels, card_pool, kit, heat):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<those 31 files> -gexit
Tests                61
Passing Tests        61
Asserts            1018
Time              544.926s
```

The new e2e, from their own lines in that run:
```
res://tests/e2e/test_e2e_hints.gd
* test_first_run_hints_show_once_and_options_reset_them
* test_show_hints_off_shows_none
* test_the_move_hint_names_the_pad_once_a_pad_is_used
3/3 passed.
res://tests/e2e/test_e2e_card_levels.gd
* test_a_held_card_shows_its_level_up_on_the_pick_and_its_pip
    altar 3 offers [1000, 2151, 2050]; card 1000 (aegis)
* test_a_held_wand_card_shows_lv_n_to_n_plus_1_and_its_pip
    reward 1 offers [43, 49, 2091]; wand card halo_shot
2/2 passed.
```
(The first floor's free altar offers Aegis and two stat cards on the fixed stage seed, so the wand-card case opens
the nearest chest, its price granted as shards: a labelled TEST HELPER, as `test_e2e_rewards.gd` does.)

Re-run on `49dbaed` (after `OnboardingHints.observe` stopped reading the heat once the vent hint was seen): the
hints e2e and unit, the credits content test and the heat e2e (the vent hint's moment):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_hints.gd,res://tests/unit/presentation/test_onboarding_hints.gd,res://tests/content/test_credits_licences.gd,res://tests/e2e/test_e2e_heat.gd -gexit
Tests                14
Passing Tests        14
Asserts             227
Time              27.937s
```

The release switch through real input (`tests/e2e/test_e2e_dev_gate.gd`, on the tree that became `191dbcd`): switch
OFF, F10 and ` open nothing; switch ON, F10 opens and closes the master panel:
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_dev_gate.gd -gexit
Tests                 1
Passing Tests         1
Asserts               6
Time              7.51s
```

Final re-run on `191dbcd` (the hints sit low over a panel, the one-line pick and shop hints, Interface size 90–110):
the hints, card-level, hint-store and settings units, locale coverage, the credits test, both arch tests and the e2e
for the hints, Options, card levels, the dev switch, rewards, the shop, events and the Swap (16 files):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<those 16 files> -gexit
Tests                52
Passing Tests        52
Asserts           12448
Time              99.976s
```
Its first try on the same files had one failure, fixed before `191dbcd` (`OnboardingHints._place` read the box's
height after moving one of its offsets):
```
[Failed]: [1770.00000000000000000000] expected to equal [1838.0] +/- [0.5]:  low over a panel: clear of its title
Tests                52
Passing Tests        51
Failing Tests         1
```

## Screenshots

Screenshots (lavapipe / llvmpipe under xvfb, Forward+), on `191dbcd`, two runs, each run's own lines:
```
$ xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s scripts/shots/small_things.gd -- lang=en size=1280x720
small_things: renderer=forward_plus lang=en size=1280x720
small_things: shot <worktree>/build/shots/v0.7.5/small_things/en_1280x720_move_hint.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/en_1280x720_pick_levels.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/en_1280x720_options_accessibility.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/en_1280x720_credits.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/en_1280x720_pick_levels_ui110.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/en_1280x720_options_ui110.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/en_1280x720_codex_ui110.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/en_1280x720_build_page_ui110.png (1280, 720)
exit 0
$ xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s scripts/shots/small_things.gd -- lang=es size=1280x720
small_things: renderer=forward_plus lang=es size=1280x720
small_things: shot <worktree>/build/shots/v0.7.5/small_things/es_1280x720_move_hint.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/es_1280x720_pick_levels.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/es_1280x720_options_accessibility.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/es_1280x720_credits.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/es_1280x720_pick_levels_ui110.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/es_1280x720_options_ui110.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/es_1280x720_codex_ui110.png (1280, 720)
small_things: shot <worktree>/build/shots/v0.7.5/small_things/es_1280x720_build_page_ui110.png (1280, 720)
exit 0
```
The PNGs are in `build/` (not tracked; the lead can regenerate them with the commands above). What the agent saw in
them (the look is OWNER ONLY):
- `move_hint`: the TIP slab at the top centre under the top plate, "Move with [W A S D] · aim with the mouse" /
  "Muévete con [W A S D] · apunta con el ratón", clear of the floor title, the minimap and the achievement toast.
- `pick_levels`: Wide Arc held at 2 reads "Lv 2 → 3" / "Nv 2 → 3", Double Slash "Lv 1" / "Nv 1", the stat card no
  badge; the badges sit on the frames above the titles; the pick hint sits low between the key line and the heat
  meter, one line in both languages; the HUD's wand pip shows "2".
- `options_accessibility`: Interface size, Show hints and Reset hints under the old rows, nothing cut in es.
- `credits`: the app icon beside the title, the "Art, models and sound" lines from the manifests, then the font.
- At 110 %: the pick fits between the top plate and the heat meter, but the skill plate (bottom left) **covers card
  1's number key "1"**, and the achievement toast, while one shows, **covers card 3's title**; the Codex's detail
  panel **reaches the screen's right edge** (its text fits); Options and the Build page fit. These are recorded as
  findings, not fixed (the HUD's and the Codex's layouts are other steps' screens).
- An earlier round (on the tree before `191dbcd`, the hint at the top over the pick and the 125 % step) showed the
  top hint covering the pick's title and, at 125 %, the pick overflowing; both are fixed / dropped above. Its PNGs are
  kept in `build/shots/v0.7.5/small_things/first_run_ui125/`. The 1920×1080 shots: NOT YET RUN.

## Goldens
None changed. No sim outcome changed: the only sim edit is a read key (`Wand.read`'s `wand`), nothing hashed.
`tests/golden` was not run by the agent (not in the touched folders; the lead's full suite runs it).

## Open (for the lead and the owner)
- OWNER ONLY: the hints' wording, placement and timing; the level badge's look; the Interface size steps.
- OWNER ONLY: the credit line (`CREDITS_OWNER`, O4), and confirming the AI 3D generator's terms cover shipping the
  kit models (the manifest's line cites the docs, not a licence).
- Lead / owner: at 110 % the skill plate covers the pick's "1" key, a toast can cover card 3's title and the Codex's
  detail panel reaches the right edge (screenshots above).
- Lead / owner: an Interface size above 110 % needs the pick panel (and any other panel laid out for 1080 px) to
  adapt to a shorter screen.
- Lead: the Windows .exe icon (`application/modify_resources`), checked by the Windows job.
- Lead: AP adds the Ascension portal; the `portal` hint reads `portal_active()` (the blue portal). If AP's portal is
  read elsewhere, a hint for it is a one-line addition to `OnboardingHints.CONTEXT`.
