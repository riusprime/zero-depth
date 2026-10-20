# v0.8.0 FL: floor-paced loot (evidence)

Owner line O91 ([`../BALANCE_PASS.md`](../BALANCE_PASS.md) "FL"). Contract: SIM_CONTRACTS §8m; schema:
CONTENT_SCHEMA (`LootPacingDefinition`, `ItemDefinition.loot_category`, `LegendaryDefinition.upgrade_choice` /
`card_categories`). Branch `v080-fl` from RM's WIP `360daca0`.

## Status

| Check | Status |
|---|---|
| `gdformat --check src scripts tests` + `gdlint src scripts tests` | passed locally (phase 1) |
| Godot import, the touched tests and their e2e | run (below); FL's own tests all pass; 3 failures that come from the merged base, reported |
| `scripts/checks/rarity_odds.gd` | run, shipped pacing and `pacing=0` (below) |
| `scripts/checks/card_pool.gd` | run: 2 problems, both the base's pool size (below) |
| Whether builds feel like they develop; the jackpot's rarity in play | OWNER ONLY |

## The category mapping (`loot_category` in `data/items/*.tres`)

Rule used: **form** changes the attack's shape or path on its own; **element** is a shared status card (S1–S7);
**advanced** multiplies, repeats, or builds on other cards or on a play pattern (the remnant cards, the legendary ×2
triggers); **trigger** is T1–T4; **mutation** is a mutation. Stat cards are their own category (an `Offers` STAT code,
weights unchanged). Every other live item (the v0.3–v0.5 passives: Bulwark, Cold Snap, Executioner, Heat Sink, Kinetic
Dash, Meltdown, Momentum, Phase Strike, Swift Feet, Thermal Edge, Thorn Mantle, Vampiric Core, Wildfire) and every
retired card is `other` (× 1 everywhere).

| Pool | form | advanced |
|---|---|---|
| Gun | Big Shot, Rapid Fire, Spread, Pierce, Ricochet, Homing, Boomerang, Orbit, Spiral, Mine, Backfire, Ring, Swirl | Twin, Split, Charge, Echo, Halo, Threadline |
| Blade | Wide Arc, Wave, Whirl, Thrust, Heavy, Flurry, Fissure, Chain Cut, Parry Edge, Lunge Step, Orbit Blades, Counter | Split Wave, Double Slash, Dodge Imprint, Fracture Bank, Blade Storm, Riposte Chain |
| Shared | — | Chain Blast (Legendary), Faultline, Gravity Stitch, Stress Mark |

- **element:** Fire (`ember_core`), Lightning (`storm_core`), Frost (`frost_core`), Venom (`venom_core`), Bleed
  (`shared_bleed`), Void (`gravity_well`), Explosive (`shared_explosive`).
- **trigger:** On Hit, On Kill, On End, On Finisher / On Crit.
- **advanced (legendary triggers):** On Hit ×2, On Kill ×2, On End ×2.
- **mutation:** Double Exposure, Grand Finale.

Judgement calls, for the owner to change in the data if they read otherwise:
- **Spread** is `form` (BALANCE_PASS's table lists it there), though it multiplies like Twin and Halo.
- **Ring** and **Swirl** (v0.8.0 AO, rare) are `form`: each turns the shot into a new shape on its own.
- **Dodge Imprint** is `advanced`: it acts only with a dash pattern, and it is one of RM's reworked remnant-era cards.
- **Gravity Stitch, Stress Mark** (shared, S9–S10) are `advanced` as remnant cards, not elements.
- **Chain Blast** (Legendary, "your attack and its splits all explode") is `advanced`.

## Starting values (`data/rewards/pacing.tres`)

| Stage | form | element | advanced | trigger | mutation | ceiling | guaranteed altars |
|---|---|---|---|---|---|---|---|
| Floor 1 | 1400 | 1400 | 400 | 600 | 20 | 2 | 2 |
| Floor 2 | 1000 | 1000 | 1000 | 1200 | 100 | 3 | 0 |
| Floor 3 | 900 | 900 | 1200 | 1200 | 300 | 5 | 0 |
| Deep floors and loops ≥ 2 | 800 | 800 | 1300 | 1200 | 600 | 5 | 0 |

`jackpot_permille` 15. Weights are per mille of the card's weight before FL; integer math rounds down, so a mutation on
floor 1 (legendary tier 20 × its own 150 ‰ = 3, × 20 ‰) weighs 0 at an altar: on floor 1 it comes only by a jackpot.

## Where each source meets the rule

| Source | How |
|---|---|
| Altars, chests | `Offers.draw` → `ItemPool.available` (ceiling) + `card_weight` (× category); `Offers.roll` adds the guarantee (regular altars) and the jackpot (regular altars and chests) |
| Shop restock, reroll | `Offers.draw(w, true, n)`; buying checks `Shop.can_apply` (ceiling) |
| Events | `Events._mod`: `ItemPool.available` + weights × category; the choice's block is `Shop.can_apply` |
| Stolen cores, Marked | `CoreTheft.draw_card`: `ItemPool.available` + weights × category; at the drop `Shop.can_apply` re-checks and redraws |
| Boss's altar | `Offers.roll_legendary`: upgrade to the next stage's ceiling, an advanced / trigger card, legendary stats |
| Overrun, Deep epic altar | ability cards and epic stat cards only: no wand card, nothing to pace |
| Dev panel grants | exempt (`CardLevels.can_take(..., MAX_LEVEL)`) |

## Measurements

Build: merge `f44b410f` (FL `0f2b1322` + `claude/balance-pass-v080` at `67e42a30`), with only test files edited after
it (the count and wording fixes below); `src/`, `data/` and `scripts/` as in the final commit. Cloud machine, 4 CPUs.

### Tests (phase 2, local)
Command form: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> -gexit` (or
`-gdir=<dirs> -ginclude_subdirs`).

| Run | Result |
|---|---|
| `test_loot_pacing.gd`, `test_loot_rewards.gd` | `Tests 20 / Passing Tests 20 / Asserts 1041` |
| sim: test_wand_migration, test_rarity, test_offers, test_rewards, test_shop, test_core_theft, test_gun_pool_order, test_wand_blade_order, test_wand_shared_order, test_wand_shared, test_card_pool, test_card_pool_reach, test_events, test_world_snapshot, test_items, test_items_j, test_blade_combos, test_heat, test_mx4_engine, test_player_builds | `Tests 266 / Passing 262 / Failing 4`. Fixed after: test_items (2) and test_items_j (2) were the item counts RM's six cards moved (107 items; pool 61 / 60); re-run green below. **Not fixed:** `test_card_pool_reach::test_each_builds_pool_holds_40_to_50_distinct_cards`: `[66] expected to be between [40] and [63]: blade`, `[65] … gun`: RM's new cards push both pools past `CardPoolSurvey.POOL_MAX`; the files are unchanged from `67e42a30`; widening the bound is the owner's call, so it is left failing |
| dirs tests/content, tests/arch, tests/golden, tests/unit/application, tests/unit/app, tests/unit/debug | `Tests 262 / Passing 261 / Failing 1`: `tests/arch/test_layering.gd`: `res://src/presentation/world_view/remnant_views.gd (presentation) uses RemnantRule (sim)` (×5) and `… uses Engines (sim)`: RM's file, unchanged from `67e42a30`; not fixed here. Goldens, content validation, saves and dev panel pass |
| presentation test_card_level_views, test_rarity_views, test_shop_views; test_items, test_items_j; e2e reward_cards, rewards, card_levels, shop, arenas, combo, old_save | `Tests 66 / Passing 65 / Failing 1`: test_rarity_views expected "Mod ·", the card says "Modifier ·" (a wand card's kind word); test fixed, re-run `Tests 3 / Passing 3 / Asserts 120` |
| test_event_rooms, test_curses, test_trade_off_curses, test_after_boss, test_arenas, test_event_views (EventLab / SaveLab now load the pacing) | `Tests 56 / Passing 56 / Asserts 5428` |

Not run locally: seams, the full suite (GitHub), `test_curse_room` (skipped as told).

### `rarity_odds`, shipped pacing
`godot --headless --path . -s scripts/checks/rarity_odds.gd` (build/rarity_odds.txt):
```
rarity_odds: runs=4000 loops=5 overrides={  }
weights per mille of a common card: altar rare 1000 epic 500 legendary 20; chest/shop rare 3000 epic 1500 legendary 50; boss Legendary chance loop1..5 [125, 175, 225, 275, 325]; boss picks loop1..5 [1, 2, 3, 4, 4]
== blade: 4000 runs ==
runs offered >= 1 Legendary card in loop 1: 1364 (34.10 %)
broken build held by loop 1 floor 1 (run floor 1): 19 (0.47 %)
broken build held by loop 1 floor 2 (run floor 2): 54 (1.35 %)
broken build held by loop 1 floor 3 (run floor 3): 143 (3.58 %)
broken build held by loop 2 floor 1 (run floor 4): 446 (11.15 %)
broken build held by loop 2 floor 2 (run floor 5): 912 (22.80 %)
broken build held by loop 2 floor 3 (run floor 6): 1351 (33.77 %)
broken build held by loop 3 floor 1 (run floor 7): 2139 (53.48 %)
broken build held by loop 3 floor 2 (run floor 8): 2756 (68.90 %)
broken build held by loop 3 floor 3 (run floor 9): 3200 (80.00 %)
broken build held by loop 4 floor 1 (run floor 10): 3624 (90.60 %)
broken build held by loop 4 floor 2 (run floor 11): 3858 (96.45 %)
broken build held by loop 4 floor 3 (run floor 12): 3939 (98.47 %)
broken build held by loop 5 floor 1 (run floor 13): 3980 (99.50 %)
broken build held by loop 5 floor 2 (run floor 14): 3998 (99.95 %)
broken build held by loop 5 floor 3 (run floor 15): 3999 (99.97 %)
expected Legendary cards held at the end of loop 1: 0.385
expected Legendary cards held at the end of loop 2: 1.384
expected Legendary cards held at the end of loop 3: 2.810
expected Legendary cards held at the end of loop 4: 3.756
expected Legendary cards held at the end of loop 5: 3.970
Legendary cards taken over 5 loops: 15702 from bosses (98.7 %), 199 from altars/chests/shop
first broken recipe: chain_blast + double_slash + on_hit|on_hit_x2: 2262
first broken recipe: on_hit_x2 + explosive|chain + double_slash: 211
first broken recipe: on_kill_x2 + explosive|chain: 1001
first broken recipe: on_end_x2 + explosive|chain + split_wave|double_slash: 525
== gun: 4000 runs ==
runs offered >= 1 Legendary card in loop 1: 1376 (34.40 %)
broken build held by loop 1 floor 1 (run floor 1): 18 (0.45 %)
broken build held by loop 1 floor 2 (run floor 2): 76 (1.90 %)
broken build held by loop 1 floor 3 (run floor 3): 196 (4.90 %)
broken build held by loop 2 floor 1 (run floor 4): 523 (13.07 %)
broken build held by loop 2 floor 2 (run floor 5): 996 (24.90 %)
broken build held by loop 2 floor 3 (run floor 6): 1434 (35.85 %)
broken build held by loop 3 floor 1 (run floor 7): 2210 (55.25 %)
broken build held by loop 3 floor 2 (run floor 8): 2779 (69.47 %)
broken build held by loop 3 floor 3 (run floor 9): 3203 (80.08 %)
broken build held by loop 4 floor 1 (run floor 10): 3625 (90.62 %)
broken build held by loop 4 floor 2 (run floor 11): 3828 (95.70 %)
broken build held by loop 4 floor 3 (run floor 12): 3936 (98.40 %)
broken build held by loop 5 floor 1 (run floor 13): 3981 (99.53 %)
broken build held by loop 5 floor 2 (run floor 14): 3996 (99.90 %)
broken build held by loop 5 floor 3 (run floor 15): 3998 (99.95 %)
expected Legendary cards held at the end of loop 1: 0.391
expected Legendary cards held at the end of loop 2: 1.394
expected Legendary cards held at the end of loop 3: 2.812
expected Legendary cards held at the end of loop 4: 3.772
expected Legendary cards held at the end of loop 5: 3.974
Legendary cards taken over 5 loops: 15728 from bosses (98.8 %), 189 from altars/chests/shop
first broken recipe: chain_blast + split + spread|twin: 2100
first broken recipe: on_hit_x2 + explosive|chain + spread|twin|split: 962
first broken recipe: on_kill_x2 + explosive|chain: 674
first broken recipe: on_end_x2 + explosive|chain + spread|twin: 262
```

### `rarity_odds`, `pacing=0` (the same tree; the boss's FL choices stay, the level-5 grant is gone from the code)
`godot --headless --path . -s scripts/checks/rarity_odds.gd -- pacing=0`:
```
rarity_odds: runs=4000 loops=5 overrides={ "pacing": 0.0 }
weights per mille of a common card: altar rare 1000 epic 500 legendary 20; chest/shop rare 3000 epic 1500 legendary 50; boss Legendary chance loop1..5 [125, 175, 225, 275, 325]; boss picks loop1..5 [1, 2, 3, 4, 4]
== blade: 4000 runs ==
runs offered >= 1 Legendary card in loop 1: 1369 (34.23 %)
broken build held by loop 1 floor 1 (run floor 1): 5 (0.12 %)
broken build held by loop 1 floor 2 (run floor 2): 36 (0.90 %)
broken build held by loop 1 floor 3 (run floor 3): 121 (3.02 %)
broken build held by loop 2 floor 1 (run floor 4): 419 (10.47 %)
broken build held by loop 2 floor 2 (run floor 5): 869 (21.73 %)
broken build held by loop 2 floor 3 (run floor 6): 1349 (33.73 %)
broken build held by loop 3 floor 1 (run floor 7): 2154 (53.85 %)
broken build held by loop 3 floor 2 (run floor 8): 2734 (68.35 %)
broken build held by loop 3 floor 3 (run floor 9): 3205 (80.12 %)
broken build held by loop 4 floor 1 (run floor 10): 3629 (90.72 %)
broken build held by loop 4 floor 2 (run floor 11): 3834 (95.85 %)
broken build held by loop 4 floor 3 (run floor 12): 3925 (98.12 %)
broken build held by loop 5 floor 1 (run floor 13): 3974 (99.35 %)
broken build held by loop 5 floor 2 (run floor 14): 3992 (99.80 %)
broken build held by loop 5 floor 3 (run floor 15): 3999 (99.97 %)
expected Legendary cards held at the end of loop 1: 0.395
expected Legendary cards held at the end of loop 2: 1.423
expected Legendary cards held at the end of loop 3: 2.830
expected Legendary cards held at the end of loop 4: 3.758
expected Legendary cards held at the end of loop 5: 3.973
Legendary cards taken over 5 loops: 15683 from bosses (98.6 %), 227 from altars/chests/shop
first broken recipe: chain_blast + double_slash + on_hit|on_hit_x2: 2198
first broken recipe: on_hit_x2 + explosive|chain + double_slash: 189
first broken recipe: on_kill_x2 + explosive|chain: 1062
first broken recipe: on_end_x2 + explosive|chain + split_wave|double_slash: 550
== gun: 4000 runs ==
runs offered >= 1 Legendary card in loop 1: 1374 (34.35 %)
broken build held by loop 1 floor 1 (run floor 1): 10 (0.25 %)
broken build held by loop 1 floor 2 (run floor 2): 39 (0.97 %)
broken build held by loop 1 floor 3 (run floor 3): 137 (3.42 %)
broken build held by loop 2 floor 1 (run floor 4): 468 (11.70 %)
broken build held by loop 2 floor 2 (run floor 5): 918 (22.95 %)
broken build held by loop 2 floor 3 (run floor 6): 1412 (35.30 %)
broken build held by loop 3 floor 1 (run floor 7): 2185 (54.62 %)
broken build held by loop 3 floor 2 (run floor 8): 2750 (68.75 %)
broken build held by loop 3 floor 3 (run floor 9): 3181 (79.53 %)
broken build held by loop 4 floor 1 (run floor 10): 3627 (90.67 %)
broken build held by loop 4 floor 2 (run floor 11): 3832 (95.80 %)
broken build held by loop 4 floor 3 (run floor 12): 3926 (98.15 %)
broken build held by loop 5 floor 1 (run floor 13): 3977 (99.42 %)
broken build held by loop 5 floor 2 (run floor 14): 3993 (99.83 %)
broken build held by loop 5 floor 3 (run floor 15): 4000 (100.00 %)
expected Legendary cards held at the end of loop 1: 0.393
expected Legendary cards held at the end of loop 2: 1.407
expected Legendary cards held at the end of loop 3: 2.814
expected Legendary cards held at the end of loop 4: 3.752
expected Legendary cards held at the end of loop 5: 3.974
Legendary cards taken over 5 loops: 15749 from bosses (99.0 %), 159 from altars/chests/shop
first broken recipe: chain_blast + split + spread|twin: 2009
first broken recipe: on_hit_x2 + explosive|chain + spread|twin|split: 983
first broken recipe: on_kill_x2 + explosive|chain: 727
first broken recipe: on_end_x2 + explosive|chain + spread|twin: 281
```

**Read (numbers, not a judgement):** with the pacing, a broken build by the end of loop 1 floor 1 is 0.47 % (Blade) /
0.45 % (Gun) against 0.12 % / 0.25 % without it, and by floor 3 3.58 % / 4.90 % against 3.02 % / 3.42 %. The
recipes need Explosive (an element, ×1.4 on floor 1) plus a form or advanced card, so floor 1's favour for elements
raises them; from loop 2 on the two runs agree within 1 point. Legendary cards held barely move (0.385 vs 0.395 at
the end of loop 1, Blade). The model leaves out the jackpot, events, cores, rerolls and shards. Not retuned: the
owner decides (BV measures the exceptional-build share against the 10–20 % target).

### `card_pool`
`godot --headless --path . -s scripts/checks/card_pool.gd` (exit 1). Its worlds have no pacing table
(`CardPoolSurvey.world`), so it measures the pool, unchanged by FL:
```
blade pool: 66 in the data + 0 planned [] = 66
blade: 1200 altar rolls, 3600 chest rolls, 7197 cards
gun pool: 65 in the data + 0 planned [] = 65
gun: 1200 altar rolls, 3600 chest rolls, 7200 cards
card_pool: 2 problems
```
The 2 problems are the pool sizes past 63 (the same as `test_card_pool_reach` above, from RM's cards).
