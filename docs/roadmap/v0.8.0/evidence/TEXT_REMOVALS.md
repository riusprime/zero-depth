# v0.8.0 N18: the game stops explaining; English boss names; long names fit (evidence)

Owner (O76, 2026-10-18, on [`docs/text/REMOVALS_PROPOSAL.md`](../../../text/REMOVALS_PROPOSAL.md)): "Apply them
all"; boss names in Spanish: "Keep English names"; "Electromagnetismo" too long for the tiles: "Shrink long words to
fit"; the combo renamed "Whirling Steel" / "Torbellino de acero": "OK".

Agent, branch `v080-n18` from `9de6f4f`. Build SHA of the runs below: `9de6f4f` + this step's working tree (the
commit is this step's own).

## Counts

| | Rows |
|---|---|
| Proposal rows | 73 |
| Removed (text and the code that showed it; the key deleted from `locale/strings.csv`) | 10 |
| Shortened (the proposed en / es wording) | 48 |
| Kept unchanged (`HUD_FALLEN_WARN` kept as "a warning"; `WAND_READ_FIRE` and the wand read-out kept) | 15 |
| Spanish boss names set to the English name, and the Spanish sentences that name them | 75 (9 names + 66 sentences) |
| `locale/strings.csv` rows changed / deleted (only existing rows edited, none appended) | 123 / 10 |

## What was removed, with its code

| Key(s) | Where it showed | Code removed |
|---|---|---|
| `HINT_PICK`, `HINT_TRIGGER`, `HINT_SHOP`, `HINT_PORTAL` | The TIP box: the first pick, the first trigger card, the first shop, the first open portal | `OnboardingHints`: the `pick` / `shop` / `portal` moments and the `trigger` enqueue after a pick (`CONTEXT` is `[vent]` now); `HintStore.IDS` lost the four ids (an older profile's seen list may still name them: harmless) |
| `WORLD_LOOP_NAME` | The floating "Loop" Label3D over the Loop device | `LoopDevice`: the `label` Label3D, its build and its show-on-open |
| `WORLD_ASCENSION_NAME` | The floating "Ascension" Label3D over the Ascension portal | `AscensionPortal`: the `label` Label3D, `_build_label()` and its show-on-open |
| `HUD_ASCENSION_OPEN`, `HUD_LOOP_DEVICE_OPEN` | The HUD note after a loop's last boss | `Hud._gate_note`: on an Ascension floor the note is empty now |
| `HUD_EXPLORE_AFTER_BOSS` | The note's second line in the boss room after a boss | `Hud._gate_note`: the note is the one portal line ("The portal is open." / "Two portals are open.") |
| `UI_GAMBLE_ODDS` | N14's line under the shrine prompt (wins and the chance to fail) | `GambleHud`: the `GambleOdds` label, `odds_line()`, `odds_text()`; `UI_GAMBLE_BLOCKED` lost its `%d` with its shortening ("Spent") |

No panel line is left empty: the gamble prompt keeps its place and the odds label under it is gone (no slot left);
the gate note is a single label whose text is now one line or nothing. `grep` for the ten keys over `src`, `tests`,
`scripts`, `data` after the change: no hit (only the regenerated `.translation` files and the docs).

## Boss names in Spanish

`BOSS_GATEKEEPER`, `BOSS_BROOD_MOTHER`, `BOSS_SIEGE_ENGINE`, `BOSS_WARLORD`, `BOSS_HIVE_LENS`, `BOSS_FOUNDRY`,
`BOSS_COLOSSUS`, `BOSS_PRISM`, `BOSS_NEMESIS` have the English name in the `es` column (The Gatekeeper … The Fallen;
Hollow Crown was N16's). Every Spanish sentence that named them (the end screen's causes, the boss telegraph
captions, `HUD_FALLEN_WARN`, the Hatchling and Lens Drone Codex lines) uses the English name, the Spanish contraction
dropped before it ("El puñetazo de The Gatekeeper te aplastó.", "The Brood Mother cayó sobre ti.", "Pisaste la lava
de The Foundry."). The achievements name a boss through `ACH_BOSS_DESC` ("Derrota a este jefe: %s.") with the name
key, so they follow. Enemy names (non-boss) unchanged. After the change, `grep` of the `es` column for "Guardián de la
Puerta", "Madre de la Prole", "Máquina de Asedio", "Señor de la Guerra", "Lente Enjambre", "Fundición", "Coloso",
"Prisma", "Caído": no hit.

## The shrink rule (long words fit)

`TextFit.word_fit_size(font, text, width, s)`: a name laid out in a fixed tile wraps by word; when its widest word is
wider than the tile, the size steps down a pixel at a time until it fits, never under `TextFit.WORD_FLOOR` (0.75) of
`s`. Applied where card names sit in fixed tiles: `WandRow` (the Build page's row and the Swap panel's), `CodexTile`,
and `StoneCard`'s title (the pick panel's and the shop's cards: after its line fit, the size is lowered further if a
word would still be broken). `ShopTile` and `BuildCard` already fit the whole name on one line (`fit_width`).
"Electromagnetismo" (es, Arc Field) in a wand tile: 13 px instead of 15 (the tile's 124 px; 138 px at 15). The two
tests that failed in N16 now check every name at the size its tile draws it (not skipping the word), that the size
stays at or over the floor, and (wand views) that the label wears the fitted size and that Arc Field's Spanish name
does shrink.

## The achievements e2e (pre-existing failure, N16)

`test_e2e_achievements` failed at line 79 ("its toast shows"). Cause, measured: the biome's achievement unlocks in
`Main._floor_nodes`, at the start of the floor's load, behind the shut loading cover; N12 builds the floor over
many frames (the probe: 447,601 process frames, 26.7 s of wall clock headless, the cover shut for all but one), and
the toast's 4 s clock ran on those frames, so it was over before the cover opened (N11's arrival hold then added its
own wait). A player would not see it either on a slow load. Fix (game): `AchievementToast.hold` (Main: the new
`LoadingCover.shut()`, the cover closing or closed) stops the toast's clock and keeps it hidden while the screen is
shut; it shows over the fade-in, as v0.7.5 meant. The test is unchanged; it is in `scripts/ci/seams.sh` with a line.

## Tests whose expectations changed (each follows O76)

- `test_onboarding_hints`: the "moment first" test uses the vent hint (the pick hint is gone); every hint fits two
  lines (no one-line rule for the removed pick/shop hints).
- `test_hint_store`: the save round-trip marks `vent` (not the removed `pick`).
- `test_ascension_views`, `test_e2e_ascension`: no Label3D on the Loop device or the Ascension portal; the HUD note on
  an Ascension floor after the boss is empty.
- `test_e2e_after_boss`, `test_e2e_run_flow`: the note is the portal line alone (no "explore" line).
- `test_gamble_views`, `test_e2e_gamble`: no `GambleOdds` node; a spent shrine's prompt is "Spent" / "Agotado".
- `test_ui_polish`, `test_wand_views`: the fit is checked at the shrunk size (above).
- `test_e2e_nemesis`: the mirror line's prefix is cut at "%" (the shortened "Mirrored · %d s" has no "("); below.

## Shots

`docs/roadmap/v0.8.0/evidence/n18_shots/` (Xvfb, llvmpipe, Spanish):

- `wand_row_electromagnetismo_es.png`: the wand row (the Build page's and the Swap panel's tiles), Arc Field first:
  "Electromagnetismo" at 13 px, inside its tile;
- `boss_bars_es.png`: The Warlord's bar ("Fase 1 / 3") and the final bar on The Fallen mid-mirror ("Imitado · 7 s");
- `codex_bosses_es.jpg`: the Codex's Bosses page, English names, The Warlord's one look line;
- `loop_device_and_ascension_no_labels_es.jpg`, `loop_device_close_no_label_es.jpg`: the open Ascension portal and
  Loop device, no floating names.

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
    --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/text_n18.gd -- lang=es
n18: renderer=forward_plus lang=es
n18: tile 0 'Electromagnetismo' at 13 px
n18: tile 1 'Nova de escarcha' at 15 px
n18: tile 2 'Danza de espadas' at 15 px
n18: tile 3 'Compidron' at 15 px
n18: wrote …/build/shots/v0.7.5-dev/n18/es/1_wand_row.png
n18: bars 'The Warlord' / 'Hollow Crown'
n18: wrote …/build/shots/v0.7.5-dev/n18/es/2_boss_bars.png
n18: codex bosses/warlord name 'The Warlord' at 14 px
n18: wrote …/build/shots/v0.7.5-dev/n18/es/3_codex_boss.png
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" godot --path . \
    --audio-driver Dummy --resolution 1600x900 -s scripts/shots/ascension.gd -- lang=es
ascension: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) seed=20261013 lang=es
ascension: floor 3 biome ruins portal (-108.125, -44.9)
ascension: portal (-108.125, -44.9) loop device (-106.225, -40.1)
ascension: res://build/shots/v0.7.5-dev/ascension/es/2_open_both_devices.png
ascension: res://build/shots/v0.7.5-dev/ascension/es/3_loop_device_close.png
```

Cropped / re-encoded by hand from `build/shots/` into the evidence folder. Arc Field is an ability, not a Codex card
entry, so no Codex tile shows "Electromagnetismo" (the Codex tile carries the same rule).

## Workbook

`python3 scripts/content/text_review.py` → `wrote build/TEXT_REVIEW.xlsx (1125 strings, 65 screens)`; copied to
`docs/TEXT_REVIEW.xlsx`.

## Test results (raw, on `9de6f4f` + this step's working tree)

No full suite and no bot tests (owner rule). Lint:

```
$ gdformat --check src scripts tests
1024 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
```

`tests/content`:

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Scripts              26
Tests               133
Passing Tests       133
Asserts            9441
```

`tests/unit/presentation` (775 tests at `9de6f4f` too: N16's 777 was counted on `b21c313`):

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Scripts             111
Tests               775
Passing Tests       775
Asserts           1953637
Orphans               9
```

`tests/unit/application` (the hint store's test changed):

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/application -ginclude_subdirs -gexit
Tests                99
Passing Tests        99
Asserts            1021
```

e2e (spanish, codex, achievements, hints, ascension (the Loop device too), final_boss, gamble, routes, portal,
arenas, arena, abilities_ab (the Overrun), shell, pad_menus, rewards, reward_cards, after_boss, run_flow, nemesis,
events), first run:

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_spanish.gd,…,res://tests/e2e/test_e2e_events.gd -gexit
res://tests/e2e/test_e2e_nemesis.gd
- test_the_nemesis_mimics_a_blade_run_in_the_playground
    [Failed]:  the window's line
- test_the_nemesis_mimics_a_gun_run_in_the_playground
    [Failed]:  the window's line
- test_beating_the_nemesis_on_a_later_loop_is_the_true_ending
    [Failed]:  the window's line
Scripts              20
Tests                41
Passing Tests        38
Failing Tests         3
Asserts           5105/5108
```

Every other file passed (`test_e2e_achievements` 1/1). The three failures: the test cut `HUD_FALLEN_WINDOW` at its
"(" to get the line's prefix; the shortened line ("Mirrored · %d s", O76) has no "(", so the prefix still held the
`%d`. The test now cuts at "%" and checks the seconds end the line (its expectation follows the owner's shortening):

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_nemesis.gd -gexit
Tests                 3
Passing Tests         3
Asserts            4196
```

Not run locally: the seams (the lead's, after merging) and the full suite (the PR's, on GitHub).
