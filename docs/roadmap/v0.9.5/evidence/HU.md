# v0.9.5 Step HU: the ability squares (design A), the HP plate 15 % bigger, the Skill on the left trigger

Owner lines (verbatim): "The UI for spells has to change ... the HP looks fine for now, let's make it jsut a 15% bigger and we are
moving the abilities with cooldown to the right, blink, dash, attack and L2 shot, these now will have a bigger square that help you
visualizy the cooldown better, the small blue cooldown trackers that have been there from the beggining have to go and create a
professional looking ones, you can look for inspiratio nfrom risk of rain UI." Q9: the four squares are Attack (RT), Skill (the Gun's
Scatter Blast, moved from Y to L2/LT), Dash (RB), Blink (LB); Vent beside the heat meter. G2: design A. Later (2026-10-26): "match the
spells to the same height as the health bar, but lower both about 2 cm".

- **Build SHA:** the tree is `ec587f61` (the `claude/v095-feedback` head merged into `v095-hu`) plus this step's changes, which were not yet
  committed when the tests below ran; the commit is the step's one commit.
- **Machine:** the owner's PC (RTX 3060, Vulkan Forward+, Godot 4.7.2), several runs in parallel, each with its own `APPDATA`.

## What was built

- `src/presentation/hud/ability_squares.gd` (`AbilitySquares`, all look numbers as consts) and `ability_square_icons.gd` (the drawn
  symbols HM made, now shared; `scripts/shots/mock_hud.gd` uses them too). Four 76 px squares, 6 px apart, 24 px from the right edge:
  Attack, Skill, Dash, Blink (the Blade: the Lunge Cleave in the Skill slot, the guard in the Blink slot; a slot the build lacks is
  hidden and the rest close up toward the right edge). Plate `#1A1D24` 88 %, 2 px border `#C8CCD4` 30 % (ready: `#E8EAEE`), a
  `#000` 65 % cover from the top whose height is the share still cooling, the seconds (30 px, 3 px outline; one decimal under 10 s,
  whole seconds above), a 0.15 s white flash when it becomes ready (none under reduced motion), the binding in a dark pill at the
  bottom-left corner, Blink's charges in a small circle at the top right above 1.
- The glyph follows the last device used (a key, mouse or pad event, as `PlayerInput` tracks it), not "a pad is connected"; a
  PlayStation pad (by the joypad name) reads R2 / L2 / R1 / L1. `KitHud.key_spec_for(action, pad)` is the shared lookup.
- Removed: the HP plate's blue dash/utility pips (`Hud._pip`, `_set_pip`), the 52 px `AbilityHud` row and `AbilitySlot` (the
  Vent plate's wedge now uses `AbilitySquares.draw_sweep`), and `KitHud`'s Skill pip. The six auto abilities are retired (WAND.md),
  so the row had nothing else to show. Card flights: Blink and Aegis cards fly to the Blink square.
- HP plate: bar 300 x 10 to 345 x 12 (`Hud.BAR`), type 14 to 16 pt, same left anchor.
- **The owner's later line (same bottom line):** the plate and the squares share one bottom edge, 20 px above the screen's bottom edge
  at 1080p (`Hud.BOTTOM_LINE` = `AbilitySquares.MARGIN_BOTTOM`; the HUD scales with the UI scale like the rest). The plate was 160 px up,
  so it moves down 140 px (about 3.7 cm at a 24 inch 1080p screen; the owner said "about 2 cm", and the coordinator's pick was 20 px).
  The plate is shorter than a square (a test asserts it), so the squares are bottom-aligned with it, not centred on the bar row.
  Things placed relative to the plate follow it (the build row above it); the carried-item row and the combo badges at the bottom
  right moved up (`Hud.ITEMS_LIFT`, 108 px) to clear the squares. The heat meter (centre, 22 px up) and the Vent plate are unchanged.
- Input: the Gun's Skill is `JOY_AXIS_TRIGGER_LEFT` by default (Q stays on the keyboard); pad Y is free (a test asserts no default binds
  it). Only the defaults changed: a saved binding is kept (test). No hint or tutorial string names Y for the Skill (grepped
  `locale/strings.csv`: none), so no string changed.

## Tests (raw)

Commands use `APPDATA=<own folder> Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=... -gexit --language en`.

| Run | Result |
|---|---|
| `tests/unit/presentation/test_ability_squares.gd` (new, 7 tests) | 7/7 passed, 40 asserts |
| `test_hud_style.gd` (a new test for the plate and the shared bottom line, one threshold 10 to 12) | 16/16 passed, 407 asserts |
| `test_kit_views.gd`, `test_input_rebind.gd` (two new tests) with the squares file | 21/21 passed (183 asserts) before the bottom-line test; the 6 that failed first were my test sizing a full-rect node, fixed |
| e2e `test_e2e_kit.gd`, `hud_style`, `input`, `pad_aim`, `hints`, `options` | 15/15 passed, 158 asserts |
| e2e `ui_polish`, `abilities`, `utility`, `run_flow`, `heat` | 10/10 passed, 154 asserts |
| `tests/arch` + `tests/unit/application` (locale coverage included) | 145/145 passed, 18946 asserts, 171 s |
| Whole `tests/unit/presentation` folder | NOT COMPLETE: 759 tests ran through `test_stage_dresser.gd` (alphabetical) with no failure line in the log (`Failed` count 0); the run was still inside the slow world-generation files `test_shard_dressing.gd` and `test_stage_dresser.gd` when I stopped waiting, so the files after them (none touched by this step except `test_ui_polish.gd`, run on its own) have no result here; GitHub runs the full suite |
| `test_ui_polish.gd` (unit), e2e `reward_cards`, e2e `final_approach` | 17/17 passed, 1462 asserts, 86 s |

Lint: `gdformat` then `gdlint` on every touched `.gd`: no problems (after fixing two over-long comment lines).

Not run (per the step): `test_five_floors`, `test_curse_room`, `test_modifier_smoke`, `test_event_rarity`, `test_event_rooms`,
`test_purple_rooms`; `tests/content` (no data changed); `seams.sh`.

## Tests changed or deleted

- Deleted (the widget is gone): `test_build_views.gd::test_the_ability_hud_follows_the_slots` (AbilityHud);
  `test_kit_views.gd::test_the_hud_shows_the_skill_with_its_key_and_cooldown` (the Skill pip; replaced by
  `test_the_vent_hint_is_hidden_without_heat` and the squares tests); `test_ui_polish.gd::test_the_weapon_slot_names_its_key_in_full_in_both_languages`
  (AbilitySlot; the glyph is covered in `test_ability_squares.gd` and e2e `ui_polish`).
- Changed: `test_ui_polish.gd::test_every_slot_key_name_fits_its_slot_in_both_languages` (the pill's width against the 76 px square, no
  `fit_key`), `test_hud_style.gd` (BAR height bound), `test_e2e_kit.gd` (the Skill square, and the Gun's Skill on the left trigger
  with its square cooling), `test_e2e_abilities.gd`, `test_e2e_run_flow.gd`, `test_e2e_ui_polish.gd`, `test_e2e_utility.gd` (squares
  instead of `ability_hud`).
- Added: `test_ability_squares.gd`; two in `test_input_rebind.gd` (the default on LT with Y free; a saved Y binding still loads Y); one in
  `test_hud_style.gd`.

## Shots

`APPDATA=<own> Godot_v4.7.2-stable_win64.exe --path . --resolution 1920x1080 -s scripts/shots/hu_hud.gd` (renderer `forward_plus`),
output `build/shots/v0.9.5/hu/en.png` and `es.png` (1920 x 1080, untracked). A Gun run with Blink granted (2 charges), the Skill cooling
(3.2 s) and the Dash cooling (7.4 s). Verdict (agent's reading, not the owner's): matches design A: four 76 px squares at the bottom
right, cover and 30 px seconds on the cooling two, lit border and `RT` on Attack, `LB` and the "2" charges on Blink; the HP plate and
the squares end on the same line; the Vent plate stays beside the heat meter. Pad glyphs show (RT, LT, RB, LB) because a pad was
connected on this PC. Owner-only: whether it looks right and feels right.

## Not done / caveats

- OWNER ONLY: the look, the size and the feel, and the "about 2 cm" lowering on the owner's screen.
- The ready flash is code-driven by real time (`_process`), so it is covered by a unit test, not seen in a still shot.
- The Blade's guard (Aegis) has no cooldown: its square is always lit and shows no seconds.
- The six auto abilities (Bomb Lobber and the rest) have no HUD slot any more; they are retired and never offered.
