# v0.9.5 Step PR: short prompts under the hero, with the button drawn in code

Owner line L15: "Short prompts ("Press X", with a cost only when needed), 3-5 cm under the hero, controller button sprites."
Q10 (a): the prompt sits under the hero (about 40 px below the feet at 1080p), reads "[button] Open" or just the button; a cost shows
only when there is one ("[X] -30 % HP", "[X] 40 ◆"); sprites drawn in code to match the pad in use (Xbox A/B/X/Y in colour, PlayStation
✕ ○ □ △), the keyboard a key cap.

- **Build SHA:** the tree is `b184a307` (`claude/v095-feedback` head merged into this branch) plus this step's changes, which were not
  yet committed when the tests below ran; the commit is the step's one commit.
- **Machine:** the owner's PC (RTX 3060, Godot 4.7.2), runs in parallel, each with its own `APPDATA`.

## What was built

- `src/presentation/hud/interact_prompt.gd` (`InteractPrompt`): the one prompt widget. Anchored to the hero's feet on screen (camera
  `unproject_position` of the hero's sim position), 40 px below at 1080p and scaled with the viewport height, centred, one line: the
  button glyph, the verb, and (only when the text has one) a cost after it. Text 18 pt at 1080p, 6 px dark outline. Fades in over 0.12 s
  when shown and out when hidden. Hidden when the hero is dead; the menus and the pick panel were already gated by each HUD's
  own conditions (`choosing`, `shop_open`, `event_open`).
- A line splits at its first " · " into verb and tail (the cost, or a short name); the tail draws after the verb. Red (`POOR`) when
  you cannot pay.
- The glyph (`InteractPrompt.glyph_spec`, drawn by `GlyphView._draw`): the bound `interact` action is read from the `InputMap`
  (`KitHud.key_spec_for`), never hardcoded. Keyboard: a key cap with the bound key's short name. Pad: Xbox (A green, B red, X blue, Y
  yellow, a coloured letter in a dark disc) unless the pad's name reads as PlayStation (`PS`, `DualSense`, `DualShock`, `Sony`, `PS3/4/5`,
  `Wireless Controller`; case-insensitive), then ✕ blue, ○ red, □ pink, △ green drawn as shapes. A rebound button that is not a face
  button draws as a name cap (PlayStation names for RB/LB/RT/LT).
- Device tracking is reused, not copied: `AbilitySquares.pad_after(event, was)` (the HU rule, extracted from its `_input`) decides "pad
  or keyboard" for both.
- Every prompt now goes through the widget: the reward chest/altar/drop (`Hud`), the shared interactables (`InteractPromptHud`: pylons,
  switches, levers, pillars, shrines, fountain), the shop, the boss door, the event pedestals and curse altar, the gamble shrine and the
  hub stations (`HubHud.show_station` takes the reader to place it). The old long `[E / X] ...` strings in `locale/strings.csv` are
  now short verbs (en + es). `REWARD_TOO_POOR` is no longer shown anywhere (a chest you cannot afford shows its price in red); the key is
  left in the CSV, unused.

## Every prompt kind, before -> after (en)

| Kind | Before | After |
|---|---|---|
| Altar / epic altar | `[E / X] Open the altar` / `... epic altar` | `[E] Open` |
| Card drop | `[E / X] Take the card` | `[E] Take` |
| Chest | `[E / X] Open the chest · 40 shards` | `[E] Open · 40 ◆` |
| Chest, too poor | `Not enough shards · 12 / 40` (red) | `[E] Open · 40 ◆` (red) |
| Shop terminal | `[E / X] Open the shop` | `[E] Shop` |
| Boss door | `[E / X] Open the door` | `[E] Open` |
| Rune pylon / purple dais | `[E / X] Awaken` | `[E] Awaken` |
| Timed-door switch | `[E / X] Activate` | `[E] Activate` |
| Timed lever | `[E / X] Pull the lever` | `[E] Pull` |
| Rune pillar | `[E / X] Turn` | `[E] Turn` |
| Blood Shrine | `[E / X] Blood Shrine · give 20 HP for an upgrade` | `[E] Pray · −20 HP` |
| Blood Shrine, too weak | `Blood Shrine · too weak (needs 20 HP)` | `Too weak · needs 20 HP` (no button) |
| Chaos Shrine | `[E / X] Chaos Shrine · fight 6 enemies for an upgrade` | `[E] Challenge · 6 foes` |
| Fountain | `[E / X] Healing Fountain · drink (+30 HP · one use)` | `[E] Drink · +30 HP` |
| Fountain, full health | `Healing Fountain · you are at full health` | `Full health` (no button) |
| Gamble shrine | `[E / X] Tempt fortune · 25 shards` (too poor: `Not enough shards · 0 / 25`) | `[E] Gamble · 25 ◆` (red when too poor) |
| Gamble shrine, spent | `Spent` (red) | `Spent` (red, no button) |
| Event pedestal | `[E / X] Inspect: Wandering Drone` | `[E] Inspect · Wandering Drone` |
| Curse altar | `[E / X] Touch the altar` | `[E] Touch` |
| Hub: portal / archive / trophy / wardrobe / station / credits | `[E / X] Start a run` / `Open the Archive` / `See the achievements` / `Open the wardrobe` / `Use the station` / `Read the credits` | `[E] Start` / `Open` / `View` / `Open` / `Use` / `Read` |
| Hub: collectible toast | `Keystone · Added to the Rune Archive` | unchanged, no button |

(The numbers in "before" are examples; the strings are the CSV's before this step.)

**Information that was only in a prompt and is kept after the verb:** the event pedestal's name (`Inspect · <name>`, shown only here;
the curse altar still hides its name by owner O75). The Blood Shrine's "for an upgrade", the Chaos Shrine's "fight N enemies", the
fountain's "one use" and the shrine's name were dropped: the shrine/fountain models and the HUD result line (`ShrineHud`) already say
what happened, and the owner asked for the verb and the cost only. If the owner wants the shrine's name back, it is one string each.

## Tests

- New: `tests/unit/presentation/test_interact_prompt.gd` (pad names -> style, Xbox letter + colour, PlayStation shape + colour, keyboard
  -> the bound key, verb only vs verb + cost, placement 40 px / scaled, every prompt string short and in en + es) and
  `tests/e2e/test_e2e_prompt.gd` (boots `main.tscn`, walks to a chest, reads `Open · N ◆` and the red state, the glyph is the Xbox X after
  a stick walk and the key cap after a key event, placement under the feet from the camera, then pays and opens it with E and the prompt
  goes).
- Updated (strings only, coverage kept): `test_e2e_gamble`, `test_e2e_hub` (es), `test_e2e_rewards`, `test_reward_views`,
  `test_shrines_view`, `test_timed_door_view`.

## Commands and raw totals

Lint: `gdformat` + `gdlint` on the 18 touched files: `Success: no problems found`.

All with `--headless --language en --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<file> -gexit` (or `-gdir=<folder>
-ginclude_subdirs`), `APPDATA` per run:

| Run | Result |
|---|---|
| `tests/unit/presentation/test_interact_prompt.gd` | 7/7 passed, 101 asserts |
| `tests/e2e/test_e2e_prompt.gd` | 1/1 passed, 17 asserts |
| `tests/unit/application` (locale coverage) | 141 passed, 1372 asserts (`-gdir`, 169.7 s) |
| `tests/arch` | 4 passed, 18094 asserts |
| e2e that check prompts, one file at a time: `collectibles` 2, `curses` 2, `curse_room` 1, `events` 1, `final_approach` 1, `floor` 1, `gamble` 1, `hub` 9, `purple_portal` 1, `rewards` 3, `rune_alignment` 1, `run_flow` 3, `shop` 3, `shrines` 2, `timed_door` 1, `timed_lever` 1, `hud_style` 1, `kit` 2 | every file all passed |
| `tests/unit/presentation` (whole folder) | 1077 of 1078 passed (159 scripts, 1965666 of 1965668 asserts, 964.6 s). The one failure, `test_status_visuals.gd::test_hud_shows_the_combo_card_and_a_badge_when_a_combo_unlocks` (`combo_badge_count()` is 0, expected 1, lines 139 and 144), is in the item-row combo badge, code this step did not touch (the diff of `hud.gd` has no badge or combo line); re-run alone it fails the same. NOT run on a clean baseline, so whether it predates this branch is `NOT YET RUN` |

Not run: `tests/unit/sim` shrine/interactable tests (the sim is untouched, the prompt keys are the same), seed-loop tests, `seams.sh`
(the lead runs it).

## Shots

At 1920x1080 on the GPU, beside a chest, in a throwaway test (not committed; the GUT runner panel covers the right side of the frame):
`build/shots/v0.9.5/pr/en.png` and `build/shots/v0.9.5/pr/es.png`. Read: the key cap `E`, then `Open 60 ◆` (`Abrir 60 ◆` in
Spanish) in red (60 shards needed, the hero has fewer), about 40 px below the hero's feet, readable on the red canyon floor.

## Deviations and notes

- The shard icon in the cost is the text glyph `◆`, which the default font draws. The shop and chest price labels use the drawn
  `ShardIcon`; swapping it into the prompt is a follow-up if the owner wants the same icon.
- A pad whose name is empty (headless, or a driver that gives none) counts as Xbox style.
- The cost text colour is the verb's colour, slightly darker; no separate cost style.

## OWNER ONLY

Whether 40 px under the feet feels like "3-5 cm" on your monitor, whether the key cap / Xbox / PlayStation shapes read well and the
fade feels right, and whether the shortened shrine lines lose anything you wanted: `OWNER ONLY`, not judged here.
