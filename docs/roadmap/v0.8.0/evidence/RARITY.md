# RARITY: card tiers, Legendaries from bosses, and how often a run breaks (v0.8.0 RR)

- **Status:** RUN (the odds computation and the card shots); feel and "rare and exciting" OWNER ONLY
- **Build:** the RR working tree on `f1e2ab1` (`v080-rr`, before its commit; the commit is `v0.8.0 Step RR`); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18.44 (cloud container)
- **Date:** 2026-10-16
- **Who ran it:** agent

Owner lines (O33): "Extremely overpowered builds, like the previously nerfed explosion builds, should still be possible.
Game-breaking combinations should occur approximately once every 10–15 runs, making them rare and exciting. Normal runs
should still offer fun and powerful builds without regularly becoming completely broken. Consider adding item rarity
levels, similar to the existing spell levels. Legendary items and spells could be obtained from bosses, enabling
particularly powerful combinations. Overpowered builds should depend on lucky drops and specific combinations. Infinite
loops should eventually allow players to accumulate extremely powerful combinations." Built from the lead's proposal
(O38).

## What changed

- **Four tiers on every mod card:** Common, Rare, Epic, Legendary (`ItemDefinition.Rarity`; `EPIC` appended as 3 so
  no shipped value moves; `ItemTable.tier()` reads them in order). Stat cards already rolled common / rare / epic per
  offer and legendary at the boss; abilities keep their own card ("New ability", "Level N").
- **The old `data/legendary` folder** is the boss's tier (`LegendaryDefinition`, the altar a boss leaves: level-5 wand
  cards and 1.6× legendary stat cards). It is kept and folded in: it now also holds the Legendary chance and the extra
  picks per loop (below). Its `mods` list (the three ×2 triggers) is emptied: the Legendary cards come only through the
  chance (and rarely from altars, chests and the shop), so a boss's **core** now gives legendary stat cards only
  (OWNER_TODO D32).
- **The build-breaking cards are Legendary:** the three ×2 triggers (On Hit, On Kill, On End; already the boss's
  legendary tier) and a new card, **Chain Blast** (`chain_blast`, both weapons, a wand card Lv 1–5): Explosive with the
  rules from before BL's B6 nerf, the same numbers (a 1.4 m ember blast at 60 % +10 % a level where the spell ends):
  the shot's splits and every spell it casts explode too (it is not in `WandTable.once_per_line`) and its blasts never
  merge (not in `blast_merge_ids`). The common Explosive keeps its nerf.
- **Epic:** the multipliers Split, Twin (Gun), Blade Storm, Riposte Chain (Blade).
- **Where each tier drops** (`data/rewards/floor.tres`, `data/legendary/boss.tres`):

  | Source | Common | Rare | Epic | Legendary |
  |---|---|---|---|---|
  | Altar (weight against a common card's 1) | 1 | 1 | 0.5 | 0.02 |
  | Chest and the shop's stock | 1 | 3 | 1.5 | 0.05 |
  | Boss altar | its level-5 cards and legendary stat cards; then a **Legendary card** as its first card at 12.5 % on loop 1, +5 % each loop after (`legendary_chance`, `legendary_chance_per_loop`) | | | |
  | Events, elites' cores, a boss's core | never a Legendary card | | | |

  Common and rare draws use the same integers as before (`ItemPool.card_weight`: base per mille × the weapon's own
  ×1.5 / 1000), so a pool without epic or legendary cards draws exactly as before RR.
- **Loops pile them up:** a boss altar gives one more pick each loop past the first (`extra_picks_per_loop` 1, at most
  3 more: loop 1 one pick, loop 2 two, loop 3 three, loop 4+ four). After a pick the altar stays with its offer cleared;
  the next open rolls a fresh offer with its own Legendary chance (`World.legendary_picks`, saved; an older save loads
  with 0: `WorldSnapshot.ADDED_SINCE_V05`).
- **Shop price:** a fourth `rarity_prices` entry for a Legendary card (150 on floor 1); salvage refunds at most the epic
  price, so the old saves' refunds don't move.

## Every card's tier

The 62 mod cards still offered (retired v0.6 cards left out; `python3 scripts/checks/rarity_table.py` over `data/items`):
Common 45, Rare 9, Epic 4, Legendary 4.

| Tier | Card | id | Weapon | Kind |
|---|---|---|---|---|
| Common | Chain Cut | `chain_cut` | blade | wand card (Lv 1-5) |
| Common | Counter | `counter` | blade | wand card (Lv 1-5) |
| Common | Double Slash | `double_slash` | blade | wand card (Lv 1-5) |
| Common | Wave | `echo_slash` | blade | wand card (Lv 1-5) |
| Common | Finisher+ | `finisher_plus` | blade | wand card (Lv 1-5) |
| Common | Fissure | `fissure` | blade | wand card (Lv 1-5) |
| Common | Flurry | `flurry` | blade | wand card (Lv 1-5) |
| Common | Heavy | `heavy` | blade | wand card (Lv 1-5) |
| Common | Lunge Step | `lunge_step` | blade | wand card (Lv 1-5) |
| Common | Momentum | `momentum` | blade | passive |
| Common | Parry Edge | `parry_edge` | blade | wand card (Lv 1-5) |
| Common | Split Wave | `split_wave` | blade | wand card (Lv 1-5) |
| Common | Thrust | `thrust` | blade | wand card (Lv 1-5) |
| Common | Whirl | `whirl` | blade | wand card (Lv 1-5) |
| Common | Wide Arc | `wide_arc` | blade | wand card (Lv 1-5) |
| Common | Fire | `ember_core` | both | wand card (Lv 1-5) |
| Common | Executioner | `executioner` | both | passive |
| Common | Frost | `frost_core` | both | wand card (Lv 1-5) |
| Common | Void | `gravity_well` | both | wand card (Lv 1-5) |
| Common | Heat Sink | `heat_sink` | both | passive |
| Common | Kinetic Dash | `kinetic_dash` | both | passive |
| Common | Phase Strike | `phase_strike` | both | passive |
| Common | Bleed | `shared_bleed` | both | wand card (Lv 1-5) |
| Common | Explosive | `shared_explosive` | both | wand card (Lv 1-5) |
| Common | Lightning | `storm_core` | both | wand card (Lv 1-5) |
| Common | Swift Feet | `swift_feet` | both | passive |
| Common | Thermal Edge | `thermal_edge` | both | passive |
| Common | Thorn Mantle | `thorn_mantle` | both | passive |
| Common | On End | `trigger_on_end` | both | trigger |
| Common | On Finisher | `trigger_on_finisher` | both | trigger |
| Common | On Hit | `trigger_on_hit` | both | trigger |
| Common | On Kill | `trigger_on_kill` | both | trigger |
| Common | Vampiric Core | `vampiric_core` | both | passive |
| Common | Venom | `venom_core` | both | wand card (Lv 1-5) |
| Common | Backfire | `gun_backfire` | gun | wand card (Lv 1-5) |
| Common | Big Shot | `gun_big_shot` | gun | wand card (Lv 1-5) |
| Common | Charge | `gun_charge` | gun | wand card (Lv 1-5) |
| Common | Echo | `gun_echo` | gun | wand card (Lv 1-5) |
| Common | Homing | `gun_homing` | gun | wand card (Lv 1-5) |
| Common | Mine | `gun_mine` | gun | wand card (Lv 1-5) |
| Common | Pierce | `gun_pierce` | gun | wand card (Lv 1-5) |
| Common | Rapid Fire | `gun_rapid_fire` | gun | wand card (Lv 1-5) |
| Common | Ricochet | `gun_ricochet` | gun | wand card (Lv 1-5) |
| Common | Spiral | `gun_spiral` | gun | wand card (Lv 1-5) |
| Common | Spread | `gun_spread` | gun | wand card (Lv 1-5) |
| Rare | Orbit Blades | `blade_orbit` | blade | wand card (Lv 1-5) |
| Rare | Bulwark | `bulwark` | blade | passive |
| Rare | Afterimage | `long_shadow` | blade | wand card (Lv 1-5) |
| Rare | Cold Snap | `cold_snap` | both | passive |
| Rare | Meltdown | `meltdown` | both | passive |
| Rare | Wildfire | `wildfire` | both | passive |
| Rare | Boomerang | `boomerang` | gun | wand card (Lv 1-5) |
| Rare | Halo | `halo_shot` | gun | wand card (Lv 1-5) |
| Rare | Orbit | `orbit_rounds` | gun | wand card (Lv 1-5) |
| Epic | Blade Storm | `blade_storm` | blade | wand card (Lv 1-5) |
| Epic | Riposte Chain | `riposte_chain` | blade | wand card (Lv 1-5) |
| Epic | Twin | `gun_twin` | gun | wand card (Lv 1-5) |
| Epic | Split | `split_shot` | gun | wand card (Lv 1-5) |
| Legendary | Chain Blast | `chain_blast` | both | wand card (Lv 1-5) |
| Legendary | On End ×2 | `trigger_on_end_twice` | both | trigger |
| Legendary | On Hit ×2 | `trigger_on_hit_twice` | both | trigger |
| Legendary | On Kill ×2 | `trigger_on_kill_twice` | both | trigger |

AO's new Ring / Triple / Swirl cards come
after this step and default to Rare (lead's instruction).

## What counts as broken

A run is **broken** when the build holds every group of one recipe (any card of a group; levels ignored; the player is
assumed to order the wand right). These are the "lucky drop + specific combination" builds: each needs a Legendary card
(Chain Blast is in the explosive groups too).

| Weapon | Recipe |
|---|---|
| Gun | Chain Blast + Split + (Spread or Twin): the pre-nerf "Spread × Split × Explosive" build (BLADE_AUDIT B6's "≈ 100 explosions") |
| Gun | On Hit ×2 + (Explosive or Chain Blast) + (Spread, Twin or Split) |
| Gun | On Kill ×2 + (Explosive or Chain Blast): a kill casts two blasts, which kill and cast again |
| Gun | On End ×2 + (Explosive or Chain Blast) + (Spread or Twin) |
| Blade | Chain Blast + Double Slash + (On Hit or On Hit ×2) |
| Blade | On Hit ×2 + (Explosive or Chain Blast) + Double Slash |
| Blade | On Kill ×2 + (Explosive or Chain Blast) |
| Blade | On End ×2 + (Explosive or Chain Blast) + (Split Wave or Double Slash) |

The list is the agent's reading (OWNER_TODO D29); no fight was simulated to prove each is "game-breaking".

## Model

`scripts/checks/rarity_odds.gd` (pure: it calls the game's own `Offers.draw` for altars, chests and the shop and
`Offers.roll_legendary` for the boss altar, on worlds built from the shipped content as `CardPoolSurvey.world` builds
them, with the wand and the legendary tier; the loot stream as in play). Not the bot balance suite: no fight is
simulated.

- A loop is 3 floors. Each floor: `altars_min..altars_max` altars (capped at `altars_cap`, the rest chests) and
  `chests_min..chests_max` chests, each opened once; the shop's stock on the floors `FloorCadence` gives it (run floors
  1, 3, 5 …), every wanted card bought (up to `max_buys`); the boss altar with its picks for the loop.
- **An upper bound on access:** shards are not modelled (every chest is opened, every wanted shop card bought), and
  every run reaches the end of the loop. A run that dies early, skips chests or can't pay sees fewer cards.
- **The player chases a broken build:** takes a Legendary card whenever offered; else a recipe piece it lacks; else a
  card that takes no wand slot; else the first. With the wand full, a new card replaces a slot holding no recipe piece,
  or is passed over.
- Left out (none of them can offer a Legendary card): events, elites' and bosses' cores, the Deep floors' epic altar,
  rerolls. They can add Explosive, Split or Spread, so the real odds of completing a recipe once the Legendary is held
  can be a little higher.

## Command
```
godot --headless --path . -s scripts/checks/rarity_odds.gd -- runs=3000 loops=5
```
(about 18 minutes on the shared 4-core container; it writes `build/rarity_odds.txt`, copied below by hand.)

## Raw output
```
rarity_odds: runs=3000 loops=5 overrides={  }
weights per mille of a common card: altar rare 1000 epic 500 legendary 20; chest/shop rare 3000 epic 1500 legendary 50; boss Legendary chance loop1..5 [125, 175, 225, 275, 325]; boss picks loop1..5 [1, 2, 3, 4, 4]
== blade: 3000 runs ==
runs offered >= 1 Legendary card in loop 1: 1034 (34.47 %)
broken build held by loop 1 floor 1 (run floor 1): 11 (0.37 %)
broken build held by loop 1 floor 2 (run floor 2): 70 (2.33 %)
broken build held by loop 1 floor 3 (run floor 3): 183 (6.10 %)
broken build held by loop 2 floor 1 (run floor 4): 529 (17.63 %)
broken build held by loop 2 floor 2 (run floor 5): 1005 (33.50 %)
broken build held by loop 2 floor 3 (run floor 6): 1428 (47.60 %)
broken build held by loop 3 floor 1 (run floor 7): 2071 (69.03 %)
broken build held by loop 3 floor 2 (run floor 8): 2462 (82.07 %)
broken build held by loop 3 floor 3 (run floor 9): 2720 (90.67 %)
broken build held by loop 4 floor 1 (run floor 10): 2902 (96.73 %)
broken build held by loop 4 floor 2 (run floor 11): 2964 (98.80 %)
broken build held by loop 4 floor 3 (run floor 12): 2991 (99.70 %)
broken build held by loop 5 floor 1 (run floor 13): 3000 (100.00 %)
broken build held by loop 5 floor 2 (run floor 14): 3000 (100.00 %)
broken build held by loop 5 floor 3 (run floor 15): 3000 (100.00 %)
expected Legendary cards held at the end of loop 1: 0.405
expected Legendary cards held at the end of loop 2: 1.495
expected Legendary cards held at the end of loop 3: 3.110
expected Legendary cards held at the end of loop 4: 3.919
expected Legendary cards held at the end of loop 5: 3.996
Legendary cards taken over 5 loops: 11749 from bosses (97.6 %), 290 from altars/chests/shop
first broken recipe: chain_blast + double_slash + on_hit|on_hit_x2: 903
first broken recipe: on_hit_x2 + explosive|chain + double_slash: 392
first broken recipe: on_kill_x2 + explosive|chain: 1092
first broken recipe: on_end_x2 + explosive|chain + split_wave|double_slash: 613
== gun: 3000 runs ==
runs offered >= 1 Legendary card in loop 1: 1044 (34.80 %)
broken build held by loop 1 floor 1 (run floor 1): 10 (0.33 %)
broken build held by loop 1 floor 2 (run floor 2): 97 (3.23 %)
broken build held by loop 1 floor 3 (run floor 3): 281 (9.37 %)
broken build held by loop 2 floor 1 (run floor 4): 705 (23.50 %)
broken build held by loop 2 floor 2 (run floor 5): 1261 (42.03 %)
broken build held by loop 2 floor 3 (run floor 6): 1725 (57.50 %)
broken build held by loop 3 floor 1 (run floor 7): 2276 (75.87 %)
broken build held by loop 3 floor 2 (run floor 8): 2617 (87.23 %)
broken build held by loop 3 floor 3 (run floor 9): 2812 (93.73 %)
broken build held by loop 4 floor 1 (run floor 10): 2933 (97.77 %)
broken build held by loop 4 floor 2 (run floor 11): 2980 (99.33 %)
broken build held by loop 4 floor 3 (run floor 12): 2994 (99.80 %)
broken build held by loop 5 floor 1 (run floor 13): 2999 (99.97 %)
broken build held by loop 5 floor 2 (run floor 14): 2999 (99.97 %)
broken build held by loop 5 floor 3 (run floor 15): 3000 (100.00 %)
expected Legendary cards held at the end of loop 1: 0.409
expected Legendary cards held at the end of loop 2: 1.502
expected Legendary cards held at the end of loop 3: 3.127
expected Legendary cards held at the end of loop 4: 3.927
expected Legendary cards held at the end of loop 5: 3.995
Legendary cards taken over 5 loops: 11730 from bosses (97.5 %), 304 from altars/chests/shop
first broken recipe: chain_blast + split + spread|twin: 1125
first broken recipe: on_hit_x2 + explosive|chain + spread|twin|split: 823
first broken recipe: on_kill_x2 + explosive|chain: 637
first broken recipe: on_end_x2 + explosive|chain + spread|twin: 415
```

How the boss chance was picked (same script, `loops=1 runs=1500`, the loop-1 numbers only, overrides on the
command line; the shipped altar 0.02 / chest 0.05 weights unless named):

| `boss=` | other overrides | Blade broken by the end of loop 1 | Gun |
|---|---|---|---|
| 0.15 | — | 121 (8.07 %) | 177 (11.80 %) |
| 0.12 | — | 98 (6.53 %) | 142 (9.47 %) |
| 0.12 | `altar=0.01 chest=0.03` | 85 (5.67 %) | 123 (8.20 %) |

The shipped 0.125 sits between the first two rows; the 3000-run table above is the shipped data with no override.

## Target bands
| Metric | Target | Source |
|---|---|---|
| A complete broken build by the end of a run (loop 1) | about 1 run in 10–15 (7–10 %) | O33; PLAN RR |
| Legendary cards mostly from bosses | "mostly" | O33; lead's proposal |
| Legendaries pile up over loops | rising each loop | O33 |

## Result
| Metric | Measured (3000 runs per weapon) | In band? |
|---|---|---|
| Broken by the end of loop 1, **Gun** | 281 / 3000 = **9.37 %** (1 run in 10.7) | yes |
| Broken by the end of loop 1, **Blade** | 183 / 3000 = **6.10 %** (1 run in 16.4) | **no: under 7 %** (95 % interval about 5.2–7.0 %) |
| Both weapons together | 464 / 6000 = 7.73 % (1 run in 12.9) | yes |
| Runs offered at least one Legendary card in loop 1 | 34.5 % (Blade), 34.8 % (Gun) | — (no target) |
| Legendary cards taken from bosses | 97.6 % (Blade), 97.5 % (Gun), over 5 loops | yes |
| Expected Legendary cards held, end of loop 1 / 2 / 3 / 4 / 5 | Blade 0.405 / 1.495 / 3.110 / 3.919 / 3.996; Gun 0.409 / 1.502 / 3.127 / 3.927 / 3.995 | rising (capped by the 4 Legendary cards there are) |
| Broken by the end of loop 2 / 3 | Blade 47.6 % / 90.7 %; Gun 57.5 % / 93.7 % | — (no target; "eventually") |

## Interpretation
- **The Blade misses the band low (6.1 %); the Gun is in it (9.4 %).** One boss chance can't put both in 7–10 %
  with these recipes: the 1500-run sweep shows the Blade needs about 0.14 and the Gun stays under 10 % only up to
  about 0.13. Reported, not retuned: the knobs are a per-weapon Legendary pool, a different recipe list (D29), or a
  wider band. The numbers are an **upper bound on access** (every chest opened, every run reaching the loop's end, a
  player chasing the pieces), so real runs that die early or skip chests break less often than this.
- About one run in three is offered a Legendary card in loop 1, but holding one is not yet broken: the recipe's other
  pieces still have to come.
- Loops: loop 2 already breaks about half the runs that reach its end, and loop 3 nine in ten. That is the "infinite
  loops accumulate" line, but faster than "eventually" may mean (D35). Only 4 Legendary cards exist, so the count
  stops at 4 by loop 5.
- Feel, "rare and exciting", and whether these builds actually break the game: OWNER ONLY.

## Not measured
- Chain Blast's frame cost: its blasts never merge (the pre-nerf rule), and PF's budget was measured with Explosive's
  merging. A Chain Blast + Split + Spread build may lag as the pre-PF build did. `scripts/checks/perf_probe.gd` was not
  run with it (NOT YET RUN; D34).
- The damage of each recipe (no fight simulated; D29).

## v0.8.0 N7: a chest deals one card (re-run, 2026-10-17)

Owner O61 (D48): a chest gives one random card by its odds, no choice; altars keep their pick of 3. The odds above are
RR's (a chest offered three cards and the modelled player took the best). `scripts/checks/rarity_odds.gd` now draws a
chest's one card (`Offers.CHEST_CARDS`) and takes it when it fits the wand (the same rule as any take); altars, the
shop and the boss altar are unchanged. Loop 1 only (the band's metric).

- **Build:** the working tree on `6475075` (branch `v080-n78`) before the N7 commit: N7, plus N8's uncommitted work (the
  presentation, and the forecast's sim helpers `Stats.stepped` / `max_hp_at` / `total_at`, `CardLevels.level_after`,
  `Abilities.level_after`, `BossReward.level_after`, which the takes now call: the same steps); Godot `4.7.2.stable.official.ed1daf0bf`
- **Who ran it:** agent

```
godot --headless --path . -s scripts/checks/rarity_odds.gd -- runs=3000 loops=1
```
```
rarity_odds: runs=3000 loops=1 overrides={  }
weights per mille of a common card: altar rare 1000 epic 500 legendary 20; chest/shop rare 3000 epic 1500 legendary 50; boss Legendary chance loop1..5 [125, 175, 225, 275, 325]; boss picks loop1..5 [1, 2, 3, 4, 4]
== blade: 3000 runs ==
runs offered >= 1 Legendary card in loop 1: 1024 (34.13 %)
broken build held by loop 1 floor 1 (run floor 1): 6 (0.20 %)
broken build held by loop 1 floor 2 (run floor 2): 44 (1.47 %)
broken build held by loop 1 floor 3 (run floor 3): 133 (4.43 %)
expected Legendary cards held at the end of loop 1: 0.397
Legendary cards taken over 1 loops: 1130 from bosses (94.8 %), 62 from altars/chests/shop
first broken recipe: chain_blast + double_slash + on_hit|on_hit_x2: 15
first broken recipe: on_hit_x2 + explosive|chain + double_slash: 11
first broken recipe: on_kill_x2 + explosive|chain: 77
first broken recipe: on_end_x2 + explosive|chain + split_wave|double_slash: 30
== gun: 3000 runs ==
runs offered >= 1 Legendary card in loop 1: 1011 (33.70 %)
broken build held by loop 1 floor 1 (run floor 1): 4 (0.13 %)
broken build held by loop 1 floor 2 (run floor 2): 54 (1.80 %)
broken build held by loop 1 floor 3 (run floor 3): 165 (5.50 %)
expected Legendary cards held at the end of loop 1: 0.394
Legendary cards taken over 1 loops: 1137 from bosses (96.1 %), 46 from altars/chests/shop
first broken recipe: chain_blast + split + spread|twin: 25
first broken recipe: on_hit_x2 + explosive|chain + spread|twin|split: 38
first broken recipe: on_kill_x2 + explosive|chain: 81
first broken recipe: on_end_x2 + explosive|chain + spread|twin: 21
```

| Metric | RR (3-card chests) | N7 (1-card chests) | Band (O33) | In band? |
|---|---|---|---|---|
| Broken by the end of loop 1, Blade | 6.10 % | **4.43 %** (133 / 3000) | 7–10 % | **no** (was no) |
| Broken by the end of loop 1, Gun | 9.37 % | **5.50 %** (165 / 3000) | 7–10 % | **no** (was yes) |
| Both | 7.73 % | 4.97 % (298 / 6000) | 7–10 % | **no** |
| Legendary cards from bosses (loop 1) | — | 94.8 % / 96.1 % | "mostly" | yes |

**The band is missed now** (fewer chest cards reach the build: a chest no longer lets the player pick the recipe piece).
Reported, not retuned (OWNER_TODO D49): the knobs are the boss's Legendary chance, the chest's Epic/Legendary weights,
or the band. The loops 2–5 rows above were not re-run (NOT YET RUN under N7).

## UI
Every mod card says its tier in words on its foot ("Mod · Rare", "Mod · Level 5 · Legendary") on top of its colour:
Common grey, **Rare blue** (was amber: too close to the Legendary gold; D31), Epic purple with the gold rim, Legendary
bright gold. The boss's altar shows each card's own tier (a level-5 Common card says "Level 5 · Common") and its title
reads "The boss's reward", "The boss left a Legendary card" when one is there, and on a later loop "… · N more picks
here" (D30). The shop prices a Legendary card at 150 × the floor step. The Codex's Cards page says each mod card's tier
on the card and in its section line. Strings in `en` and `es`.

Shots (`xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy
--resolution 1600x1000 -s scripts/shots/rarity_cards.gd -- --lang=en`, then `--lang=es`; llvmpipe; cropped and
palette-reduced by hand into `rr_shots/`): the four tiers (Explosive, Wildfire, Twin, Chain Blast) and the boss altar's
faces (Spread at level 5, Chain Blast, a legendary Power card).

- [`rr_shots/tiers_en.png`](rr_shots/tiers_en.png), [`rr_shots/tiers_es.png`](rr_shots/tiers_es.png)
- [`rr_shots/boss_en.png`](rr_shots/boss_en.png), [`rr_shots/boss_es.png`](rr_shots/boss_es.png)
