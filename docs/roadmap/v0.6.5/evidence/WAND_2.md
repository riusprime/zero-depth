# WAND_2: can the player rearrange the wand (Build page, Swap panel) with keyboard, mouse and pad, and does the sim get it as input?

- **Status:** RUN (agent: lint and the tests of the touched folders and their e2e; NOT the full suite, which is the
  lead's one run per wave). Screenshots: NOT YET RUN (see below).
- **Build:** the agent's session branch, cut from `claude/lucid-fermat-9wv2tf` at `fb7dab3` (WN1); WIP commit
  `e46995a`, then the step's commit; Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18 (cloud container)
- **Date:** 2026-10-12
- **Who ran it:** agent

Design: [`../../../design/WAND.md`](../../../design/WAND.md) rule 4. Contracts:
[`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §3, §8e ("How the views' moves reach the sim"). PLAN row
W3.

## What was built
- **The Build page** (`src/presentation/menus/build_page.gd`, `BuildPage`): a new row **Build** under Resume in the
  pause menu opens it (Cold glass: `MenuStyle`, `MenuBackdrop`, left-aligned like the menus' list). The wand as a row
  of slots (`src/presentation/menus/wand_row.gd`, `WandRow`, 4 / 6 / 8 by floor): each card a glass tile with its
  family's frame colour along the top (`CardFrames`), its icon (`ItemIcons`), its name and level ("Lv 2"; items no
  level); empty slots dim ("Empty"). A trigger card cuts the row: a cold-glass divider with an arrow head after it,
  and brackets under the row name the parts: "the shot you fire", then "cast on hit →" (on kill, where it ends, on
  the finisher, on a crit; "too deep to cast" past the compile's depth). Under it the plain-words read-back
  (`Wand.describe` / `render` through `WorldReader`, en + es), which follows every move live.
  - Keyboard: ←/→ (↑/↓) or 1–8 choose, Enter picks up, ←/→ carry, Enter puts down, Esc puts it back (Esc with
    nothing held: back). Mouse: drag a card onto a slot, or click a card then click its new slot; a Back button.
    Pad: d-pad / left stick choose, A picks up, d-pad carries, A drops, B puts back / goes back, Start goes back.
- **How a move reaches the sim** (EI-03, EI-04, EI-07). The pause stops the ticks, so the page moves a preview with
  the sim's own pure rule (`Wand.moved_order` / `moved_read`, called by `Wand.move` itself; exposed as
  `WorldReader.wand_moved`). When the page closes, Main queues the fewest moves that give the page's order
  (`Wand.plan_moves`, at most one per slot) with `InputLatch.queue_wand_move`; the latch delivers one pick per frame,
  after a pick already latched, and a pick noted while moves wait goes after them. They land on the first ticks after
  the pause. Re-opening the page in the same pause starts from the sim's wand with the waiting moves applied
  (`InputLatch.pending_picks`). Rejected: stepping a tick per move while paused (a tick moves the whole world). The
  pause also drops button presses latched while it was open (`InputLatch.drop_presses`), so a click on the page is
  not a swing on resume.
- **The Swap panel rebuilt** (`src/presentation/hud/swap_panel.gd`) on the same `WandRow`: at 8 slots its content is
  1,238 × 809 px (measured below), inside the 1920 × 1080 base (so 1280 × 720, canvas_items stretch); it was ~1,430
  px wide with fixed 150 px tiles. Replace as before (1–8 / ←→ + Enter, a click, d-pad + A; Esc / B skip). **Insert:**
  I (pad X; or drag the new card onto a slot) puts the new card in the row (nine tiles), ←/→ choose where, Enter,
  then the card that leaves, Enter; sent as the answer `PICK_SWAP_BASE + leave` then the move `leave → at`
  (`Wand.swap_picks`). **Reorder:** R (pad Y) picks up a card, ←/→ carry, R / Enter put down; or drag a card onto a
  slot; sent as wand moves while the panel is open (the sim ticks while it waits). The read-back under the row
  forecasts the answer focused (`Wand.swapped_read`, BuildSlots.take's rule then `moved_order`).
  `WorldReader.wand()["incoming"]` is the offered card while a swap waits.
- **HUD pips** (`BuildHud`): the wand's slots in order; a trigger card's pip wears "›" and a thin ember cut stands
  after it.
- **Driver:** `SimDriver.last_frame` (read only), so an e2e can record the frames it stepped and replay them.
- **Strings:** 18 new keys, en + es (`UI_BUILD*`, `UI_WAND_*`, `UI_SWAP_PLACE / LEAVE / CARRY / HINT_MORE`).
- **Tests and scripts that walk the pause menu** pass one more row now (Build sits under Resume): `test_e2e_saves`,
  `test_e2e_run_flow`, `test_e2e_pad_menus`, `test_e2e_shell`, `test_e2e_ui_polish`, `test_run_recap`; the tools
  `scripts/shots/ui_restyle.gd`, `ui_polish.gd`, `tour.gd`, `scripts/checks/hit_soak.gd` (one more Down; not run).
- Nothing in `src/presentation/world_view/` changed; the HUD's Ember stone, the menus' Cold glass, the pick cards and
  plaques are as they were (the Swap's tiles keep its v0.6.0 UP glass look and focus rim).

## Commands and raw outputs
Lint (final tree):
```
gdformat --check src scripts tests && gdlint src scripts tests
649 files would be left unchanged
Success: no problems found
```

The new e2e alone (on the WIP tree before the Swap's `TILE` constant and the shell / ui_polish test edits):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_wand_build.gd -gexit
* test_the_build_page_opened_twice_in_one_pause_keeps_the_first_change
* test_the_swap_at_eight_slots_fits_the_screen_and_inserts_with_the_pad
    swap at 8 slots: [P: (341.0, 555.0), S: (1238.0, 809.0)] on [P: (0.0, 0.0), S: (1920.0, 1920.0)]
Tests                 3
Passing Tests         3
Asserts              65
Time              12.846s
```
(The headless viewport is 1920 × 1920 under `aspect=expand`; the check is the content's size against 1920 × 1080 and
that it sits inside the viewport.)

The e2e files that reach what changed (`e46995a`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_wand_build.gd,res://tests/e2e/test_e2e_swap.gd,res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_options.gd,res://tests/e2e/test_e2e_modifiers_mx4.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_hud_style.gd,res://tests/e2e/test_e2e_spanish.gd,res://tests/e2e/test_e2e_events.gd,res://tests/e2e/test_e2e_shell.gd,res://tests/e2e/test_e2e_lighting.gd,res://tests/e2e/test_e2e_input.gd,res://tests/e2e/test_e2e_ui_polish.gd -gexit
Tests                42
Passing Tests        40
Failing Tests         2
Time              138.81s
```
The two failures, pasted (both walked the pause menu by count and landed one row short, on the new Build row):
```
res://tests/e2e/test_e2e_shell.gd
* test_menu_play_pause_and_back
    [Failed]:  Main menu ends the stage
      at line 28
    [Failed]:  Expected [<null>] to be anything but NULL:
      at line 29
res://tests/e2e/test_e2e_ui_polish.gd
* test_a_language_switch_words_the_live_banner_again
    [Failed]:  ["en"] expected to equal ["es"]:  Spanish chosen in Options
      at line 39
    [Failed]:  [STRING_NAME(New: Charger)] expected to not equal ["New: Charger"]:  the Spanish line differs
SCRIPT ERROR: Invalid access to property or key 'phase_hud' on a base object of type 'previously freed'.
    [Failed]:  Unexpected Errors:
```
Fixed (one more Down in each) and the two files run again:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_shell.gd,res://tests/e2e/test_e2e_ui_polish.gd -gexit
Tests                 3
Passing Tests         3
Time              8.039s
```

Unit tests touched (presentation, application, the new sim preview test, `test_wand`, arch):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/application/test_input_latch.gd,res://tests/unit/presentation/test_run_recap.gd,res://tests/unit/presentation/test_ui_polish.gd,res://tests/unit/presentation/test_hud_style.gd,res://tests/unit/presentation/test_reward_views.gd,res://tests/unit/presentation/test_wand_views.gd,res://tests/unit/sim/test_wand_preview.gd,res://tests/unit/sim/test_wand.gd -gdir=res://tests/arch -gexit
Scripts              10
Tests                75
Passing Tests        75
Time              9.766s
```

Content, arch, golden and application (the locale coverage, the layering lint, the replay golden):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/application -ginclude_subdirs -gexit
Tests               141
Passing Tests       141
Time              28.64s
```

The wand's sim tests (`wand.gd` changed: `move` now calls `moved_order`; `read` gained `incoming`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_wand_smoke.gd,res://tests/unit/sim/test_wand.gd,res://tests/unit/sim/test_wand_order_fight.gd,res://tests/unit/sim/test_wand_compile.gd,res://tests/unit/sim/test_wand_preview.gd -gexit
    wand smoke: 960 runs (60 cards × 8 slots × 2 weapons)
Tests                40
Passing Tests        40
Time              125.896s
```
The whole `tests/unit/sim` and `tests/unit/presentation` folders were NOT run (only the files above).

Unit-test measurements (`test_wand_views.gd`, gut.p output): the Build page's content at 8 slots with 3 cuts
1,262 × 527 px at x 180 (en and es); the Swap at 8 slots 1,262 × 809 px, with the new card placed (9 tiles)
1,412 × 809 px.

## What the tests assert
- `tests/e2e/test_e2e_wand_build.gd` (3; main.tscn, `Input.parse_input_event` only):
  - the dev panel's clicks fill floor 1's four slots; Esc, Down ("Build" under Resume), Enter opens the page; a move
    with the keyboard (Enter → → Enter), a mouse drag (slot 4 onto slot 1), a mouse click-click (slot 2, then slot 3)
    and the pad (d-pad, A, d-pad, A), each checked on the page's order; the read-back changes; 10 frames on the page:
    no tick and the sim's wand unchanged; B back to the pause menu, Esc resumes; after 12 frames the sim's
    `mod_slots` is the page's order and its read-back is the page's last preview; the change arrived as 1–3 wand
    moves; the snapshot taken before the pause plus the frames the driver stepped (`last_frame`) replay to the same
    order, tick and state hash.
  - the page opened twice in one pause starts on the change not yet delivered; the Back button (mouse) closes it;
    pad Start resumes; both changes reach the sim in order.
  - a run continued on floor 3 (a save on disk built with `SaveLab`: eight cards, two triggers) opens the Swap at 8
    slots on a ninth card (dev panel GrantMod): the panel fits the screen and the 1920 × 1080 base; the HUD shows the
    cuts after slots 2 and 5; an insert with the pad (X, → →, A, then the last card, A) puts the new card in slot 3
    and drops the last card, and the panel's forecast read-back equals the sim's read-back after.
- `tests/unit/sim/test_wand_preview.gd` (4): every one of the 64 moves of a full 8-slot wand previews (cards, cuts,
  read-back) what the sim reads after the move arrives as an InputFrame; refused moves preview no change; 40 random
  orders are reached through `plan_moves` frames (≤ 7 moves); every (leave, at) of a Swap at 8 slots previews what the
  sim holds after `swap_picks` arrive one per tick.
- `tests/unit/presentation/test_wand_views.gd` (6): the row's dividers and brackets (en, es), levels and empty slots;
  the Build page and the Swap (also with nine tiles) fit 1920 × 1080 in both languages; every slot card's name (the
  wand's items and the six ability modifiers) fits a tile in two lines, each word in its width, en and es; the HUD
  pips' cuts.
- `tests/unit/application/test_input_latch.gd` (+2): the queue's order (a latched pick first, a pick noted while moves
  wait after them, one per frame); dropped presses.

## Goldens
None changed. The replay golden passed in the content / arch / golden run above.

## Screenshots: NOT YET RUN
`scripts/shots/wand_build.gd` (new tool; Build page en / es, a carried card, the Swap at 8 slots en / es, the insert
step) was started twice under xvfb with lavapipe (`timeout 300`, empty `XDG_DATA_HOME`, 1920 × 1080 then
1280 × 720); both runs were stopped by the timeout (exit 124) after printing only:
```
wand: renderer=forward_plus
wand: posed 8 cards in 8 slots
```
The container's load average was ~7.9 on 4 cores (other agents' test runs), and the software renderer reached about
20 frames in 2 minutes, short of the first shot. No image was produced.

## Known limits (honest list)
- No trigger card is offered yet (WN5), so in real play the dividers and brackets show only once WN5 offers them; the
  tests reach them through a save and the unit worlds.
- The Build page's and Swap's names and read-back were measured with the fonts in tests, not seen on screen
  (screenshots NOT YET RUN).
- Pad Y / X in the Swap are also the Skill / Interact buttons; the world waits on the swap, so their presses do
  nothing there (not separately tested).
- The insert drag (mouse: the incoming card onto a slot) is built but not driven by an e2e; the insert e2e uses the
  pad.
- Export smoke, the full suite: NOT RUN. `tests/MIN_TEST_COUNT` not raised (the lead's, after the full run).

## Owner only
Feel, the key choices (I / R, pad X / Y in the Swap), the Build row's place under Resume, the words ("cast on hit →",
"Construcción"): `OWNER ONLY`.
