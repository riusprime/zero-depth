# SHOP: does step SH put one reachable shop on every floor, with buying, the heal, the reroll and salvage working in the sim and through the real game?

- **Status:** RUN
- **Build:** the SH worktree branch, cut from `claude/lucid-fermat-9wv2tf` at `ac62796`; the runs below are of the
  tree at `85ac9aa` (code, tests and data as committed in `v0.5.0 Step SH: shops and salvage`, whose own SHA is in
  `git log`; only this file and PROGRESS were added after the run); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux
  (cloud container), screenshots under Xvfb with Vulkan on llvmpipe
- **Date:** 2026-10-08
- **Who ran it:** agent
- **Scope:** v0.5.0 PLAN R1 ("Shops") and R2 ("salvage"); the step brief's starting values.

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash scripts/verify.sh
python3 scripts/audio/generate_sfx.py --check
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan -s scripts/shots/shop.gd
```

## What was built
- **Placement** (`src/sim/map/shop_placement.gd`, a pass of its own after `FloorGenerator.generate` and
  `BossRoomBuilder.attach`; stream `shop_room`, never `map`, so the rest of the floor is unchanged): never the start
  hall, the boss room or the room before the boss door; dead ends first (in a drawn order), then any other room; the
  spot is the room's centre or its spawn point nearest the centre that is clear of walls, 3 m from item spots and
  2.5 m from doorways, and leaves the room one region with the terminal in it. `FloorScenario.add_shop` turns the
  terminal's footprint into a wall and drops spawn points within 1.6 m of it.
- **Sim** (`Shop`, `ShopState`, `ShopTable`; `data/shop/terminal.tres`): interact opens the shop and the world waits
  (phase 1b′, SIM_CONTRACTS §2); actions ride on `InputFrame.pick`. Stock: 4 cards by a chest's rules
  (`Offers.draw`, the same pools; slot rules and mod-with-ability hold). Prices 30 / 55 / 90 × 1, 1.5, 2; heal 30 %
  max HP once for 40 × floor step; reroll 20, +50 % per use. Salvage: a mod or a stat card for 40 % of its price (a
  stat card is one stack; `World.stat_cards` records every stat card taken, and the stat values are rebuilt from the
  ones left, so the caps hold); an ability but the weapon for 25 shards per level, freeing its slot. Events
  `SHOP_BUY`, `SHOP_SALVAGE` (plus `PICKUP` for a bought card, `HEAL` for the heal); the shop state and
  `stat_cards` are hashed; `stat_cards` is carried between floors.
- **View**: `ShopTerminalView` (a low-poly console on a hex plinth, slanted violet screen, a turning shard gem;
  flash-safe), `ShopPanel` + `ShopTile` (the pick's `PickSlot` cards in `CardStyle.current` = FACET, prices with the
  shard icon, disabled and red when unaffordable, the salvage list; mouse, keyboard and pad focus), `ShopHud` (the
  prompt), the minimap's shop icon and legend row, three sounds (`shop_open`, `shop_buy`, `shop_sell`; a refusal
  reuses `chest_refuse`), 14 strings in en and es.

## Raw output
Import (`build/import.log`): exit 0, 0 lines starting `ERROR` or `SCRIPT ERROR`.

Lint:
```
434 files would be left unchanged
Success: no problems found
```

`bash scripts/verify.sh` (`build/verify2.log`, tail):
```
Totals
------
Scripts             143
Tests               891
Passing Tests       891
Asserts           433386
Time              764.861s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (891 passing, minimum 891)
```

The generation property test, in that run:
```
res://tests/unit/sim/test_shop_placement.gd
* test_same_seed_same_shop
* test_the_pick_draws_no_map_numbers
* test_one_reachable_shop_in_a_side_room_over_1000_seeds
    shops: 1000 floors, 1000 with a shop, 963 in a dead end, 9 room footprints, 153984 ms
3/3 passed.
```

The rules, in that run:
```
res://tests/unit/sim/test_shop.gd
* test_the_data_compiles_to_the_starting_values
* test_prices_by_rarity_and_floor
* test_interact_opens_it_and_the_world_waits
* test_out_of_reach_nothing_opens
* test_the_stock_follows_the_chest_rules_and_the_slot_rules
* test_a_bought_card_applies_exactly_as_a_picked_card
* test_unaffordable_changes_nothing
* test_the_heal_restores_thirty_percent_once
* test_the_reroll_draws_a_new_stock_at_a_rising_price
* test_sell_a_mod_for_forty_percent_and_lose_its_combos
* test_sell_a_stat_card_removes_one_stack_and_rebuilds
* test_selling_at_the_cap_frees_the_stat_again
* test_salvage_an_ability_frees_its_slot
* test_the_weapon_is_never_salvaged
* test_same_inputs_same_hash_and_the_shop_is_hashed
* test_a_world_without_a_shop_is_unchanged
* test_the_stat_cards_carry_to_the_next_floor
17/17 passed.

res://tests/unit/presentation/test_shop_views.gd
* test_the_terminal_glows_and_pulses_without_changing_a_shader
* test_the_panel_shows_the_stock_in_card_style_with_prices
* test_the_panel_navigates_and_sends_actions
* test_the_panel_follows_the_sim_and_closes
* test_every_shop_string_has_en_and_es
* test_the_minimap_lists_the_shop
6/6 passed.
```

The e2e through `main.tscn` (input only: the dev panel's God, Next ability and Grant clicked with the mouse, the
walk on the left stick, E, arrows and Enter on the keyboard, d-pad, A and B on the pad; the shards granted directly,
labelled in the test, as in `test_e2e_gamble.gd`):
```
res://tests/e2e/test_e2e_shop.gd
* test_walk_to_the_shop_buy_a_card_and_salvage_an_ability
    bought twin_arc for 30
1/1 passed.
```

The replay golden and the readable cause, in that run (no golden regenerated; `git diff ac62796 -- tests/golden`
is empty):
```
res://tests/golden/test_replay_ground_plane.gd ... 2/2 passed.
res://tests/unit/sim/test_readable_cause.gd ... 4/4 passed.
```

Sounds (`python3 scripts/audio/generate_sfx.py`, then `--check`):
```
sfx       shop_open                     0.510 s    45026 bytes
sfx       shop_buy                      0.810 s    71486 bytes
sfx       shop_sell                     0.560 s    49436 bytes
77 files, 7639066 bytes, generator v2
0 difference(s)
```
Before writing them, `--check` reported only the three new files and the manifest as different: every existing
sound is byte-identical.

Screenshots (`build/shots_shop.log`):
```
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
shop: renderer=forward_plus
shop: room 8 at (-37.93499, 34.85)
shop: shot …/build/shots/v0.5.0/shop/01_terminal.png
shop: shot …/build/shots/v0.5.0/shop/02_shop_panel.png
shop: stock [28, 12, 2051, 6]
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Shops per floor | exactly 1, reachable, never the start hall, boss room or the room before the boss door, over 1,000 seeds | PLAN R1; step brief |
| Prices | common 30 / rare 55 / epic 90 × 1, 1.5, 2; heal 40 × step, 30 % max HP, once; reroll 20, +50 % per use | step brief (starting values) |
| Salvage | mod / stat card 40 % of its price; ability (not the weapon) 25 per level, slot freed | PLAN R2; step brief |
| Suite | all pass, ≥ the committed minimum | CLAUDE.md "Testing before a push" |
| Readable cause, goldens | unchanged | step brief |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Shops per floor | 1000 / 1000 floors have one; every assertion (room rules, terminal in its room and clear, front reachable from every doorway at the player's radius, and from the start on the whole floor every 25th seed) held | yes |
| Side room | 963 / 1000 in a dead end (one doorway); the rest in another allowed room | yes |
| Prices | floor 1/2/3: cards 30 / 55 / 90, 45 / 83 / 135, 60 / 110 / 180; heal 40 / 60 / 80; rare sale 22 / 33 / 44; rerolls 20, 30, 45, 68, 102 (`test_prices_by_rarity_and_floor`) | yes |
| Buy = pick | 30 seeds: the bought card leaves items, slots, levels, stat values and max HP equal to `Offers.apply` of the same card | yes |
| Salvage | Drone Buddy L3 refunds 75; the slot frees and Blink can take it; a sold stat card's values equal a world that never took it | yes |
| Suite | 891 / 891 (was 864; `tests/MIN_TEST_COUNT` raised to 891) | yes |
| Readable cause, golden | pass, unchanged | yes |

## Interpretation
Shops and salvage are in the sim, deterministic, hashed and reachable from the real game. Nothing here measures
balance or feel: every price and share is a starting value (OWNER ONLY: whether the shop is worth the walk, whether
prices feel fair, whether salvage gets used). Lead calls the owner may change, all in PROGRESS: ability cards are
priced by their rarity like the rest; the reroll's price doesn't rise by floor; the heal is refused at full HP; a
salvaged ability's mods stay owned (inert) and can be sold; a stat card's sale rebuilds the stat values from the
cards left in the order taken, then the gamble shrine's stat wins (so a sale can move a value by a rounding step
against the original order). Not measured: the extra flow-field builds when a floor loads (the terminal's footprint
is added after the floor is built, so its nav fields are rebuilt once more); the generation test's 154 s is mostly
floor generation (1,000 floors).

## Screenshots
Shot setup (not play): the script grants Bomb Lobber and two stat cards, gives 120 shards, halves HP and places the
hero in front of the terminal; the input path is the e2e above.
- [`shop_terminal.png`](shop_terminal.png): the terminal in a dead-end room, its violet screen and shard gem lit
  (the hero in reach), the prompt "[E / X] Open the shop".
- [`shop_panel.png`](shop_panel.png): the panel: four FACET cards (Twin Arc and Kinetic Dash 30, Reach rare 55,
  Conductor 55) with prices and the shard icon, Heal +30 HP for 40, Reroll for 20, and the salvage list (Power rare
  +22, Reach common +12, Bomb Lobber "Frees the slot · level 1" +25).
