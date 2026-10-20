# BALANCE_BV: does the balance pass give developing builds, with exceptional builds in roughly 10–20 % of runs?

Owner line O91 ([`../BALANCE_PASS.md`](../BALANCE_PASS.md) "BV: validation"). Owner's words: "Measure actual offers,
purchases and rerolls; weights are not run-completion probabilities. Initial target: exceptional builds in roughly
10–20% of representative completed normal-route runs, usually assembled late; early jackpots much rarer. Treat this as
a playtest target. … Track damage, projectile rate, proc rate and time-to-kill; distinguish 60 projectiles/sec from
60 weapon casts/sec. Audit CatchUp.power after changing stat semantics; hidden enemy scaling must not cancel earned
synergy. … Use seeded reward sampling plus scripted fights, then report what still requires human playtesting."

- **Status:** RUN (agent, cloud machine); the owner's questions stay OWNER ONLY
- **Build:** `a53a484f` on `v080-bv` (BV's tools merged with `claude/balance-pass-v080` at `be0b16ba`: SG + MR + RM +
  FL final); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux (cloud container)
- **Date:** 2026-10-20
- **Who ran it:** agent
- **Budget cut (lead, usage limit):** the loot sampling ran `seeds=100` per weapon, not the planned 200. A 5-seed
  sizing run took 64 s on this machine, so 200 would have taken about half an hour.

## Status

| Check | Status |
|---|---|
| `gdformat --check` + `gdlint` on the new files | passed locally |
| Godot import, `tests/unit/application/test_balance_tools.gd` | RUN: `Tests 5`, `Passing Tests 5`, `Asserts 21`, `Time 20.271s` |
| `scripts/checks/loot_sample.gd -- seeds=100 weapon=both` | RUN (section 1; 100 seeds, cut from 200) |
| `scripts/checks/build_fights.gd -- seconds=20` | RUN (section 2) |
| `scripts/checks/build_fights.gd -- from_loot=build/loot_wands.txt` | RUN twice: the default pack HP (45, which caps the DPS) and `pack_hp=2000` (section 3) |
| CatchUp P and m before / after SG | after SG only (this tree has SG); before: NOT YET RUN (it needs a tree without SG) |
| Replay goldens, old-save fixtures, the every-card × every-slot smoke, launch caps, one horde perf probe | NOT YET RUN (the lead's seams / GitHub's full suite) |
| What only the owner can say (below) | OWNER ONLY |

## The tools and their model

- `scripts/checks/loot_sample.gd` over `tests/support/loot_sampler.gd` (`LootSampler`): each seed is a real run built
  floor by floor through `FloorPlan` (as Main builds it: the carry, slots 4 → 6 → 8, the catch-up, the shop's
  cadence, the events, `data/rewards/pacing.tres`, the floor-1 guarantee and the jackpots). Normal route only. Per
  floor: every altar and chest the floor placed (rolled and taken through `Offers.roll` / `Rewards._take`), every
  event pedestal placed (`Events.roll` / `Events.take`; fights and defences taken as won), the shop on its cadence
  (`Shop.restock` / `Shop.buy` / `Shop.reroll`), the boss's altar with every pick it gives.
  - **Assumptions, not measurements:** `income=200` shards added at each floor's entry (kills are not simulated; the
    economy is unchanged; the carry keeps the run's shard share); `cores=1` elite core stolen a floor
    (`CoreTheft.draw_card`); at most `rerolls=2` shop rerolls, only when no unsold card fits; the shop buys pick
    ranks ≤ `shop_rank=3`. Not modelled: Overrun's and ambushes' extra rewards, boss cores, Marked's card, the gamble
    shrine, Deep floors, deaths (every sampled run completes its normal route).
  - **The pick** (deterministic, both weapons): a held wand card's level-up first, then a new wand card that
    `LootPacing.compatible` accepts / a mutation / the weapon's level, then a trigger, then a stat card or another
    ability, then a passive; a new wand card with the slots full is passed over (no swap).
- `scripts/checks/build_fights.gd` over `tests/support/build_fight.gd` (`BuildFight`): the Playground's room, the hero
  unhurtable; a pack of 12 dummies (Charger floor-1 HP, a dead one back at its spot 1 s later; the reference fight)
  and a single boss dummy (the first boss table's floor-1 HP). The Gun holds Shoot at the nearest dummy and stands;
  the Blade presses Primary and walks at the nearest one; Dodge Imprint's build dashes every 1.5 s. Projectiles a
  second (new player projectile ids) and weapon casts a second (Gun: `shot_cd` set; Blade: a new `swing_root`) are
  counted apart; procs a second are status applications + remnant activations + child hits (HIT at depth ≥ 1).
  CatchUp: P, the floor's m and the boss's m on floors 1–3 for the loadout, and the boss dummy's time to kill × the
  boss's m (what the hidden scaling leaves of the gain).
- **Exceptional** (BALANCE_PASS.md): a sampled build's pack-fight DPS ≥ 2.5 × the median of the same weapon, loop and
  floor.
- **Determinism:** each tool runs its first case twice and compares `World.state_hash()` (MATCH / MISMATCH).

## 1. Seeded reward sampling

### Command
```
godot --headless --path . -s scripts/checks/loot_sample.gd -- seeds=100 weapon=both
```

### Raw output
`build/loot_sample.txt`, the whole file:
```
loot_sample: seeds=100 weapons=[&"blade", &"gun"] loops=1 income=200 cores=1 rerolls=2 shop_rank=3
== blade: 100 runs ==
-- blade loop 1 floor 1 (100 runs; per-run means unless a total) --
offers opened (mean): altar 2.00, boss 1.00, chest 2.76, core 1.00, event 1.89, reroll 0.41, shop 1.00
cards seen by category (mean): ability 3.72, advanced 1.09, curse 0.50, element 1.32, form 3.72, mutation 0.10, passive 1.86, stat 8.37
cards taken by category (mean): ability 0.85, advanced 0.43, element 1.01, form 2.79, mutation 0.10, passive 0.48, stat 2.51
level-ups taken 1.30  purchases 0.46  shards spent 25.8  rerolls 0.41  chests left shut 0.15
jackpots seen 8 taken 8 (runs with one taken by now: 7)  mutations seen 10 taken 10 (totals)
wand card levels at floor end (totals L1..L5): [202, 102, 9, 0, 0]
shards at entry (carry + income) median 200, at end median 15
catch-up: P at entry median 1000, P at end median 1885 (p90 2272), m at entry median 1000, boss m median 1000
  run 1 wand: venom_core:2 parry_edge:1 flurry:1 gravity_well:1
  run 2 wand: blade_orbit:2 parry_edge:2 gravity_well:1 lunge_step:1
  run 3 wand: blade_orbit:2 shared_explosive:1 parry_edge:1 echo_slash:1
-- blade loop 1 floor 2 (100 runs; per-run means unless a total) --
offers opened (mean): altar 2.00, boss 1.00, chest 2.01, core 1.00, event 1.62
cards seen by category (mean): ability 2.36, advanced 1.57, element 0.55, form 1.20, mutation 0.10, passive 1.22, stat 6.63
cards taken by category (mean): ability 1.73, advanced 0.73, element 0.47, form 1.11, mutation 0.09, passive 0.59, stat 2.28
level-ups taken 1.16  purchases 0.00  shards spent 0.0  rerolls 0.00  chests left shut 1.04
jackpots seen 6 taken 5 (runs with one taken by now: 11)  mutations seen 10 taken 9 (totals)
wand card levels at floor end (totals L1..L5): [248, 145, 41, 3, 0]
shards at entry (carry + income) median 207, at end median 57
catch-up: P at entry median 1885, P at end median 2909 (p90 3883), m at entry median 1000, boss m median 1000
  run 1 wand: venom_core:3 parry_edge:1 flurry:1 gravity_well:1 shared_faultline:1
  run 2 wand: blade_orbit:3 parry_edge:2 gravity_well:1 lunge_step:1 wide_arc:1 trigger_on_kill:1
  run 3 wand: blade_orbit:2 shared_explosive:2 parry_edge:1 echo_slash:1 ember_core:1
-- blade loop 1 floor 3 (100 runs; per-run means unless a total) --
offers opened (mean): altar 2.00, boss 1.00, chest 1.98, core 1.00, event 1.59, reroll 0.28, shop 1.00
cards seen by category (mean): ability 1.99, advanced 2.10, curse 0.40, element 0.71, form 1.55, mutation 0.14, passive 1.68, stat 10.52
cards taken by category (mean): ability 0.91, advanced 0.72, element 0.52, form 1.06, mutation 0.14, passive 0.53, stat 3.05
level-ups taken 1.22  purchases 0.01  shards spent 6.8  rerolls 0.28  chests left shut 0.91
jackpots seen 10 taken 10 (runs with one taken by now: 21)  mutations seen 14 taken 14 (totals)
wand card levels at floor end (totals L1..L5): [297, 187, 61, 12, 3]
shards at entry (carry + income) median 228, at end median 25
catch-up: P at entry median 2909, P at end median 3996 (p90 5542), m at entry median 1000, boss m median 1000
  run 1 wand: venom_core:3 parry_edge:1 flurry:2 gravity_well:1 shared_faultline:1 storm_core:1 shared_bleed:1
  run 2 wand: blade_orbit:3 parry_edge:2 gravity_well:2 lunge_step:1 wide_arc:1 trigger_on_kill:1 mut_grand_finale:1 riposte_chain:2
  run 3 wand: blade_orbit:2 shared_explosive:2 parry_edge:1 echo_slash:1 ember_core:1 double_slash:1 gravity_well:2
determinism blade seed 1, 3 floors run twice: MATCH (last hash 791672b123fed4340dfc519afebe5508807adfd1da75942b148217ff87e99203)
== gun: 100 runs ==
-- gun loop 1 floor 1 (100 runs; per-run means unless a total) --
offers opened (mean): altar 2.00, boss 1.00, chest 2.76, core 1.00, event 1.89, reroll 0.35, shop 1.00
cards seen by category (mean): ability 3.66, advanced 1.14, curse 0.50, element 1.43, form 4.05, mutation 0.08, passive 1.36, stat 8.22
cards taken by category (mean): ability 0.86, advanced 0.42, element 1.10, form 2.86, mutation 0.08, passive 0.45, stat 2.40
level-ups taken 1.40  purchases 0.41  shards spent 23.8  rerolls 0.35  chests left shut 0.15
jackpots seen 9 taken 9 (runs with one taken by now: 8)  mutations seen 8 taken 8 (totals)
wand card levels at floor end (totals L1..L5): [204, 106, 10, 0, 0]
shards at entry (carry + income) median 200, at end median 20
catch-up: P at entry median 1000, P at end median 2080 (p90 2696), m at entry median 1000, boss m median 1019
  run 1 wand: gun_spiral:1 gun_rapid_fire:1 shared_bleed:2 gun_ring:1
  run 2 wand: gun_swirl:1 gun_rapid_fire:1 ember_core:1 gun_threadline:2
  run 3 wand: boomerang:1 gun_ring:2 gun_spread:1 gun_spiral:1
-- gun loop 1 floor 2 (100 runs; per-run means unless a total) --
offers opened (mean): altar 2.00, boss 1.00, chest 2.00, core 1.00, event 1.62
cards seen by category (mean): ability 2.37, advanced 1.45, element 0.66, form 1.27, mutation 0.08, passive 1.21, stat 6.58
cards taken by category (mean): ability 1.73, advanced 0.61, element 0.59, form 1.15, mutation 0.06, passive 0.58, stat 2.28
level-ups taken 1.24  purchases 0.00  shards spent 0.0  rerolls 0.00  chests left shut 1.05
jackpots seen 5 taken 3 (runs with one taken by now: 10)  mutations seen 8 taken 6 (totals)
wand card levels at floor end (totals L1..L5): [234, 163, 33, 7, 0]
shards at entry (carry + income) median 210, at end median 60
catch-up: P at entry median 2080, P at end median 3263 (p90 4559), m at entry median 1019, boss m median 1000
  run 1 wand: gun_spiral:1 gun_rapid_fire:1 shared_bleed:2 gun_ring:2 gun_twin:1
  run 2 wand: gun_swirl:1 gun_rapid_fire:1 ember_core:2 gun_threadline:3 gravity_well:1 storm_core:1
  run 3 wand: boomerang:1 gun_ring:2 gun_spread:1 gun_spiral:1 shared_stress_mark:2
-- gun loop 1 floor 3 (100 runs; per-run means unless a total) --
offers opened (mean): altar 2.00, boss 1.00, chest 1.98, core 1.00, event 1.59, reroll 0.23, shop 1.00
cards seen by category (mean): ability 1.98, advanced 2.09, curse 0.40, element 0.55, form 1.88, mutation 0.10, passive 1.61, stat 10.28
cards taken by category (mean): ability 0.91, advanced 0.89, element 0.40, form 1.15, mutation 0.09, passive 0.54, stat 2.94
level-ups taken 1.23  purchases 0.01  shards spent 5.8  rerolls 0.23  chests left shut 0.91
jackpots seen 9 taken 8 (runs with one taken by now: 18)  mutations seen 10 taken 9 (totals)
wand card levels at floor end (totals L1..L5): [292, 195, 63, 16, 1]
shards at entry (carry + income) median 230, at end median 27
catch-up: P at entry median 3263, P at end median 4593 (p90 6784), m at entry median 1000, boss m median 1000
  run 1 wand: gun_spiral:1 gun_rapid_fire:1 shared_bleed:2 gun_ring:3 gun_twin:1 boomerang:1 halo_shot:1
  run 2 wand: gun_swirl:1 gun_rapid_fire:2 ember_core:2 gun_threadline:3 gravity_well:2 storm_core:1 gun_big_shot:2
  run 3 wand: boomerang:2 gun_ring:2 gun_spread:1 gun_spiral:1 shared_stress_mark:3 venom_core:1 trigger_on_kill:1
determinism gun seed 1, 3 floors run twice: MATCH (last hash c3cb0bf629976e56857dd156070ed74ea17bfe35a1c4bd70d1d898b0ad2f2129)
```

### Target bands
| Metric | Target | Source |
|---|---|---|
| Floor 1: a compatible modifier in the first two regular rewards | always (the guarantee) | O91 pacing table; BALANCE_PASS.md "FL" |
| Early jackpots (floor 1) | "much rarer" than late ones | O91 |
| Mutations on floor 1 | "exceptionally rare" | O91 pacing table |
| Determinism | MATCH | EI-05 |

### Result
| Metric | Measured | In band? |
|---|---|---|
| Offers per floor (mean per run) | 2 altars; 2.8 / 2.0 / 2.0 chests; 1.9 / 1.6 / 1.6 event pedestals; 1 core; 1 boss altar; the shop on floors 1 and 3 (its cadence) | — |
| Purchases, rerolls (mean per run, Blade / Gun) | floor 1: 0.46 / 0.41 buys, 0.41 / 0.35 rerolls; floor 3: 0.01 buys, 0.28 / 0.23 rerolls; floor 2 has no shop | — (no target) |
| Jackpots taken (200 runs) | floor 1: 17; floor 2: 8; floor 3: 18 | no: floor 1 is not "much rarer" (O91) |
| Mutations taken (200 runs) | floor 1: 18; floor 2: 15; floor 3: 23 | not "exceptionally rare" on floor 1 (about 9 % of runs) |
| Wand card levels at floor 3's end (totals L1..L5, Blade / Gun) | [297, 187, 61, 12, 3] / [292, 195, 63, 16, 1] | — |
| CatchUp: median P at floor 3's end; median enemy m at entry | 3996 / 4593; m 1000 on floors 1–3 (1019 once) | the hidden scaling is 1 for the median build |
| Determinism | MATCH for both weapons | yes |

## 2. Scripted fights of the named builds

### Command
```
godot --headless --path . -s scripts/checks/build_fights.gd -- seconds=20
```

### Raw output
`build/build_fights.txt`, the whole file:
```
build_fights: 17 builds x levels [1, 3], 20 s a fight, 60 Hz headless
columns: build L | pack dmg, DPS | boss DPS | proj/s casts/s proj/cast | procs/s (status remnant child) | pack TTK s | boss TTK s | peak proj | LIMITs | P | m f1-3 | boss m f1-3 | boss TTK x m f1-3 s
gun_baseline           L1 | 938, 46.9 | 33.0 | 6.30 6.30 1.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 3 | none | 1000 | [1000, 1000, 1000] | [1000, 1000, 1000] | 60.7 60.7 60.7
determinism gun_baseline L1 pack fight run twice: MATCH (d5ffcd5ef0a409a98b9b4acc7f7a083546b384c8aeaf353350d53b9e67605f21)
gun_baseline           L3 | 938, 46.9 | 33.0 | 6.30 6.30 1.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 3 | none | 1000 | [1000, 1000, 1000] | [1000, 1000, 1000] | 60.7 60.7 60.7
gun_multiplication     L1 | 328, 16.4 | 12.4 | 99.90 5.55 18.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 52 | none | 1600 | [1264, 1000, 1000] | [1000, 1000, 1000] | 161.3 161.3 161.3
gun_multiplication     L3 | 763, 38.1 | 12.4 | 217.50 4.35 50.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 146 | none | 2320 | [1500, 1077, 1000] | [1077, 1000, 1000] | 173.7 161.3 161.3
gun_charged            L1 | 384, 19.2 | 22.2 | 0.85 0.85 1.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 1 | none | 1240 | [1113, 1000, 1000] | [1000, 1000, 1000] | 90.1 90.1 90.1
gun_charged            L3 | 405, 20.2 | 28.8 | 0.85 0.85 1.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 1 | none | 1720 | [1311, 1000, 1000] | [1000, 1000, 1000] | 69.6 69.6 69.6
gun_remnant            L1 | 2367, 118.3 | 82.9 | 6.30 6.30 1.00 | 10.20 (0.00 10.20 0.00) | not killed in 20 s | not killed in 20 s | 5 | none | 1960 | [1400, 1000, 1000] | [1000, 1000, 1000] | 24.1 24.1 24.1
gun_remnant            L3 | 2575, 128.8 | 101.9 | 6.65 6.65 1.00 | 10.00 (0.00 10.00 0.00) | 17.72 | 19.63 | 5 | none | 2920 | [1500, 1208, 1000] | [1208, 1000, 1000] | 23.7 19.6 19.6
gun_returning          L1 | 2718, 135.9 | 62.8 | 5.95 5.95 1.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 6 | none | 1240 | [1113, 1000, 1000] | [1000, 1000, 1000] | 31.8 31.8 31.8
gun_returning          L3 | 2994, 149.7 | 74.5 | 5.95 5.95 1.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 6 | none | 1480 | [1216, 1000, 1000] | [1000, 1000, 1000] | 26.8 26.8 26.8
gun_status             L1 | 4987, 249.3 | 129.2 | 6.30 6.30 1.00 | 59.60 (59.60 0.00 0.00) | 3.48 | 15.48 | 4 | none | 1360 | [1166, 1000, 1000] | [1000, 1000, 1000] | 15.5 15.5 15.5
gun_status             L3 | 4947, 247.3 | 129.2 | 6.30 6.30 1.00 | 58.70 (58.70 0.00 0.00) | 3.48 | 15.48 | 4 | none | 1840 | [1356, 1000, 1000] | [1000, 1000, 1000] | 15.5 15.5 15.5
gun_twin               L1 | 933, 46.6 | 36.5 | 11.10 5.55 2.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 6 | none | 1240 | [1113, 1000, 1000] | [1000, 1000, 1000] | 54.8 54.8 54.8
gun_twin               L3 | 1279, 64.0 | 50.4 | 11.20 5.60 2.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 7 | none | 1480 | [1216, 1000, 1000] | [1000, 1000, 1000] | 39.7 39.7 39.7
gun_echo               L1 | 1142, 57.1 | 43.4 | 11.00 5.55 1.98 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 7 | none | 1120 | [1058, 1000, 1000] | [1000, 1000, 1000] | 46.1 46.1 46.1
gun_echo               L3 | 1385, 69.2 | 49.4 | 11.60 5.80 2.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 8 | none | 1360 | [1166, 1000, 1000] | [1000, 1000, 1000] | 40.5 40.5 40.5
gun_rapid_fire         L1 | 1250, 62.5 | 44.8 | 10.45 10.45 1.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 5 | none | 1456 | [1206, 1000, 1000] | [1000, 1000, 1000] | 44.6 44.6 44.6
gun_rapid_fire         L3 | 1250, 62.5 | 44.8 | 10.45 10.45 1.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 5 | none | 1768 | [1329, 1000, 1000] | [1000, 1000, 1000] | 44.6 44.6 44.6
blade_baseline         L1 | 3418, 170.9 | 41.5 | 0.00 2.45 0.00 | 0.00 (0.00 0.00 0.00) | 3.52 | not killed in 20 s | 0 | none | 1000 | [1000, 1000, 1000] | [1000, 1000, 1000] | 48.1 48.1 48.1
blade_baseline         L3 | 3418, 170.9 | 41.5 | 0.00 2.45 0.00 | 0.00 (0.00 0.00 0.00) | 3.52 | not killed in 20 s | 0 | none | 1000 | [1000, 1000, 1000] | [1000, 1000, 1000] | 48.1 48.1 48.1
blade_multiplication   L1 | 5023, 251.2 | 105.4 | 12.65 2.45 5.16 | 0.00 (0.00 0.00 0.00) | 2.65 | 18.98 | 9 | none | 1360 | [1166, 1000, 1000] | [1000, 1000, 1000] | 19.0 19.0 19.0
blade_multiplication   L3 | 7232, 361.6 | 447.8 | 86.30 2.50 34.52 | 0.00 (0.00 0.00 0.00) | 1.23 | 4.47 | 78 | none | 2080 | [1442, 1019, 1000] | [1019, 1000, 1000] | 4.6 4.5 4.5
blade_charged          L1 | 2823, 141.2 | 50.3 | 0.00 1.75 0.00 | 0.00 (0.00 0.00 0.00) | not killed in 20 s | not killed in 20 s | 0 | none | 784 | [1000, 1000, 1000] | [1000, 1000, 1000] | 39.8 39.8 39.8
blade_charged          L3 | 3370, 168.5 | 61.0 | 0.00 1.95 0.00 | 0.00 (0.00 0.00 0.00) | 3.48 | not killed in 20 s | 0 | none | 1088 | [1043, 1000, 1000] | [1000, 1000, 1000] | 32.8 32.8 32.8
blade_remnant          L1 | 4888, 244.4 | 66.1 | 0.00 2.45 0.00 | 3.80 (0.00 3.80 0.00) | 2.65 | not killed in 20 s | 0 | none | 1720 | [1311, 1000, 1000] | [1000, 1000, 1000] | 30.3 30.3 30.3
blade_remnant          L3 | 5043, 252.2 | 72.5 | 0.00 2.45 0.00 | 4.40 (0.00 4.40 0.00) | 2.65 | not killed in 20 s | 0 | none | 2440 | [1500, 1104, 1000] | [1104, 1000, 1000] | 30.4 27.6 27.6
blade_returning        L1 | 4249, 212.4 | 81.5 | 4.90 2.45 2.00 | 0.00 (0.00 0.00 0.00) | 3.52 | not killed in 20 s | 6 | none | 1240 | [1113, 1000, 1000] | [1000, 1000, 1000] | 24.5 24.5 24.5
blade_returning        L3 | 5512, 275.6 | 1081.1 | 9.80 2.45 4.00 | 0.00 (0.00 0.00 0.00) | 1.63 | 1.85 | 12 | none | 1480 | [1216, 1000, 1000] | [1000, 1000, 1000] | 1.9 1.9 1.9
blade_status           L1 | 5637, 281.9 | 91.2 | 0.00 2.45 0.00 | 36.40 (36.40 0.00 0.00) | 1.07 | not killed in 20 s | 0 | none | 1360 | [1166, 1000, 1000] | [1000, 1000, 1000] | 21.9 21.9 21.9
blade_status           L3 | 5623, 281.1 | 98.7 | 0.00 2.45 0.00 | 27.35 (27.35 0.00 0.00) | 1.07 | not killed in 20 s | 0 | none | 1840 | [1356, 1000, 1000] | [1000, 1000, 1000] | 20.3 20.3 20.3
blade_flurry           L1 | 2970, 148.5 | 35.1 | 0.00 2.55 0.00 | 0.00 (0.00 0.00 0.00) | 10.85 | not killed in 20 s | 0 | none | 1120 | [1058, 1000, 1000] | [1000, 1000, 1000] | 56.9 56.9 56.9
blade_flurry           L3 | 3135, 156.8 | 36.3 | 0.00 2.60 0.00 | 0.00 (0.00 0.00 0.00) | 10.65 | not killed in 20 s | 0 | none | 1360 | [1166, 1000, 1000] | [1000, 1000, 1000] | 55.1 55.1 55.1
blade_dodge_imprint    L1 | 3062, 153.1 | 60.1 | 2.40 2.45 0.98 | 0.35 (0.00 0.35 0.00) | 3.22 | not killed in 20 s | 2 | none | 1240 | [1113, 1000, 1000] | [1000, 1000, 1000] | 33.3 33.3 33.3
blade_dodge_imprint    L3 | 4499, 224.9 | 124.2 | 7.20 2.40 3.00 | 0.35 (0.00 0.35 0.00) | 5.10 | 16.10 | 7 | none | 1720 | [1311, 1000, 1000] | [1000, 1000, 1000] | 16.1 16.1 16.1
pack HP 45, boss dummy HP 2000 (BuildFight doc)
```

### Target bands
| Metric | Target | Source |
|---|---|---|
| Twin / Echo / attack speed | "viable without dominating most runs" (no number set) | O91 |
| Projectiles a second vs casts a second | reported apart | O91 |
| Hidden scaling vs earned synergy | the boss dummy's time to kill × m still falls as the build grows | O91; BALANCE_PASS.md "SG" 6 |
| Determinism | MATCH | EI-05 |

### Result
| Metric | Measured | In band? |
|---|---|---|
| Pack DPS L1 → L3 (Gun) | baseline 46.9; multiplication 16.4 → 38.1; charged 19.2 → 20.2; remnant 118.3 → 128.8; returning 135.9 → 149.7; status 249.3 → 247.3; Twin 46.6 → 64.0; Echo 57.1 → 69.2; Rapid Fire 62.5 → 62.5 | see Interpretation |
| Pack DPS L1 → L3 (Blade) | baseline 170.9; multiplication 251.2 → 361.6; Heavy 141.2 → 168.5; remnant 244.4 → 252.2; Blade Storm 212.4 → 275.6; status 281.9 → 281.1; Flurry 148.5 → 156.8; Dodge Imprint 153.1 → 224.9 | — |
| Projectiles/s vs casts/s | Gun multiplication L3: 217.5 projectiles/s from 4.35 casts/s (50 a cast); Twin 11.2 / 5.6; Rapid Fire 10.45 / 10.45; Blade multiplication L3: 86.3 / 2.5 | counted apart |
| Procs/s | status applications: Gun status 59.6, Blade status 36.4; remnant activations: Gun 10.2, Blade 3.8–4.4; child hits 0 everywhere (no named build has a trigger) | — |
| Boss dummy (2000 HP) killed within 20 s | Gun remnant L3 19.63 s, Gun status 15.48 s, Blade multiplication 18.98 / 4.47 s, Blade Storm L3 1.85 s, Dodge Imprint L3 16.10 s; every other fight: not killed | — |
| Peak projectiles, LIMIT events | peak 146 (Gun multiplication L3); no LIMIT event in any fight | — |
| CatchUp P; m on floors 1 / 2 / 3; boss m | P 784–2920; m above 1000 only on floor 1 (at most 1500) and floor 2 (at most 1208), 1000 on floor 3; boss m 1000 except 1019–1208 on floor 1 | the hidden scaling doesn't cancel these builds past floor 1 |
| Determinism | MATCH | yes |

## 3. The sampled builds' fights (the exceptional share)

### Command
```
godot --headless --path . -s scripts/checks/build_fights.gd -- from_loot=build/loot_wands.txt seconds=6
godot --headless --path . -s scripts/checks/build_fights.gd -- from_loot=build/loot_wands.txt seconds=6 pack_hp=2000
```

### Raw output
Run (a), the default pack HP (45, the Charger's floor-1 HP); `build/build_fights_sampled.txt`:
```
determinism sampled seed 1 blade floor 1 run twice: MATCH (4cb1b33cdab1c616af7e208fc314cd4cfd3b7e0adff7068cc5b0cde3182fc195)
build_fights sampled: 600 builds from build/loot_wands.txt, pack fight 6 s each; exceptional = DPS >= 2.5 x the median of the same weapon, loop and floor
blade loop 1 floor 1: 100 builds, DPS min 136.2 p10 213.8 median 315.8 p90 371.3 max 398.0; exceptional 0 (0.0 %), of which 0 took a jackpot, 0 an early card; tokens not granted 0
blade loop 1 floor 2: 100 builds, DPS min 213.2 p10 281.3 median 360.0 p90 442.5 max 540.0; exceptional 0 (0.0 %), of which 0 took a jackpot, 0 an early card; tokens not granted 0
blade loop 1 floor 3: 100 builds, DPS min 257.7 p10 337.5 median 412.5 p90 467.8 max 540.0; exceptional 0 (0.0 %), of which 0 took a jackpot, 0 an early card; tokens not granted 0
gun loop 1 floor 1: 100 builds, DPS min 10.5 p10 47.5 median 134.2 p90 354.2 max 466.3; exceptional 12 (12.0 %), of which 0 took a jackpot, 0 an early card; tokens not granted 0
gun loop 1 floor 2: 100 builds, DPS min 0.0 p10 51.3 median 195.0 p90 360.0 max 540.0; exceptional 1 (1.0 %), of which 0 took a jackpot, 0 an early card; tokens not granted 0
gun loop 1 floor 3: 100 builds, DPS min 0.0 p10 68.7 median 246.0 p90 369.7 max 517.5; exceptional 0 (0.0 %), of which 0 took a jackpot, 0 an early card; tokens not granted 0
exceptional at floor 3: 0; of them already exceptional at floor 1 or 2: 0 (needs floors=1,2,3)
```
Run (b), `pack_hp=2000`; `build/build_fights_sampled.txt`. I ran it because run (a) caps the DPS: 12 dummies of 45 HP
that come back after 1 s give at most about 540 DPS, and run (a)'s maxima are exactly 540.0.
```
determinism sampled seed 1 blade floor 1 run twice: MATCH (84b2a6831023d4b0d7529e806809a595ef3b08990ae5d834f2a2e09cdac730bd)
build_fights sampled: 600 builds from build/loot_wands.txt, pack fight 6 s each; exceptional = DPS >= 2.5 x the median of the same weapon, loop and floor
blade loop 1 floor 1: 100 builds, DPS min 131.7 p10 191.2 median 396.8 p90 762.8 max 1429.8; exceptional 3 (3.0 %), of which 0 took a jackpot, 0 an early card; tokens not granted 0
blade loop 1 floor 2: 100 builds, DPS min 166.8 p10 324.5 median 663.7 p90 1463.0 max 4979.8; exceptional 7 (7.0 %), of which 0 took a jackpot, 0 an early card; tokens not granted 0
blade loop 1 floor 3: 100 builds, DPS min 184.2 p10 431.0 median 1159.5 p90 2938.3 max 5499.5; exceptional 11 (11.0 %), of which 2 took a jackpot, 0 an early card; tokens not granted 0
gun loop 1 floor 1: 100 builds, DPS min 10.5 p10 55.8 median 159.8 p90 1016.0 max 1943.2; exceptional 27 (27.0 %), of which 1 took a jackpot, 1 an early card; tokens not granted 0
gun loop 1 floor 2: 100 builds, DPS min 0.0 p10 55.8 median 279.3 p90 1185.2 max 2149.7; exceptional 27 (27.0 %), of which 3 took a jackpot, 1 an early card; tokens not granted 0
gun loop 1 floor 3: 100 builds, DPS min 0.0 p10 83.2 median 445.7 p90 1273.8 max 2344.3; exceptional 15 (15.0 %), of which 1 took a jackpot, 1 an early card; tokens not granted 0
exceptional at floor 3: 26; of them already exceptional at floor 1 or 2: 16 (needs floors=1,2,3)
```

### Target bands
| Metric | Target | Source |
|---|---|---|
| Exceptional builds at a completed normal route's end (floor 3) | roughly 10–20 % (a playtest target) | O91 |
| Assembled late | most floor-3 exceptional builds not yet exceptional at floor 1 or 2 | O91 |
| Early jackpots among exceptional builds | rare | O91 |

### Result
| Metric | Measured | In band? |
|---|---|---|
| Exceptional share at floor 3 (Blade / Gun), run (b) | 11 % / 15 % (26 of 200, 13 %) | yes: inside 10–20 % (a playtest target, in this tool's model) |
| Exceptional share at floors 1 and 2, run (b) | Blade 3 % / 7 %; Gun 27 % / 27 % | Gun: no, exceptional builds come early |
| Floor-3 exceptional builds with a jackpot / an early card, run (b) | 3 / 1 of 26 | yes, rare |
| Floor-3 exceptional builds already exceptional at floor 1 or 2, run (b) | 16 of 26 | no: most are not "assembled late" |
| Run (a), the default pack HP | 0 % at floor 3 for both weapons | not a valid reading (the 540 DPS cap) |

## Interpretation

- **The 10–20 % target:** met at the end of a normal route (floor 3) in run (b): Blade 11 %, Gun 15 %. Run (a), at the
  tool's default pack HP, reads 0 %, but that reading is broken. Its pack caps the DPS at about 540 (12 × 45 HP, 1 s
  respawn), and no build can reach 2.5 × a median of 316–413 under that cap. I report run (b) and didn't change the
  tool's default. Picking the reference fight's pack HP is a call for the lead or owner.
- **"Usually assembled late": not met.** 16 of the 26 builds exceptional at floor 3 were exceptional at floor 1 or 2
  already. Most of that is the Gun, at 27 % on floors 1 and 2. Its DPS spread is very wide (floor 1: p10 55.8,
  median 159.8, p90 1016.0), and some sampled Gun builds deal 0 DPS in this fight (min 0.0 on floors 2–3), so the
  Gun's median is low and 2.5 × median is easy to reach early.
- **Early jackpots are not "much rarer":** 17 were taken on floor 1, against 8 on floor 2 and 18 on floor 3 (200
  runs). Mutations come almost only through jackpots, about 9 % of runs on floor 1. Still, only 1 of the 26 floor-3
  exceptional builds had an early card. Data unchanged, no retuning (CLAUDE.md: report the numbers and stop).
- **Twin / Echo / attack speed:** viable but not dominant. Pack DPS at L3: Twin 64.0, Echo 69.2, plain Gun 46.9.
  Rapid Fire reads 62.5 at both levels: its per-level ramp changed nothing in this fight. Flurry reads 148.5 → 156.8,
  under a plain Blade's 170.9 here.
- **Findings for the lead (nothing was tuned):**
  - The Gun multiplication build (Twin · Spread · Halo) deals *less* pack damage than a plain Gun at L1: 16.4 vs 46.9.
    Its boss DPS is 12.4 at both levels, from 99.9–217.5 projectiles/s on 4.35–5.55 casts/s. The shares (60 % × 55 %
    × 40 %) and Halo's ×0.5 range, against dummies 4.5–8.1 m out, leave little to land. Check it in the Playground at
    close range before reading it as a balance result.
  - Gun Charge · Big Shot: 0.85 casts/s, 19–20 pack DPS.
  - No LIMIT event fired in any named fight.
- **CatchUp after SG:** for the named loadouts, the enemy m tops out at 1500 on floor 1 and 1208 on floor 2, and is
  1000 on floor 3. For the sampled builds the median m is 1000 on every floor. So the hidden scaling doesn't cancel
  earned synergy past floor 1. The before-SG comparison wasn't run.
- **Not covered here:** the replay goldens, old-save fixtures, the every-card × every-slot smoke and the horde perf
  probe. They belong to the lead's seams and GitHub's full suite.

What the numbers cannot prove: the sampled runs never fight, so a build's power never changes which rooms are cleared
or which shards are earned; the shard income is an assumption; the reference fight is a still dummy pack (no
movement, no dodging, no enemy pressure), so builds that pay off under movement (Onrush) or against moving crowds read
low here and should be checked in play.

## OWNER ONLY

| Question | Answer |
|---|---|
| Does a build develop over a run (floor 1 identity → floor 3 complete)? | OWNER ONLY |
| Do Twin, Echo and attack speed still feel good? | OWNER ONLY |
| How rare do jackpots feel in play? | OWNER ONLY |
| Are the remnants (Faultline, Gravity Stitch, Stress Mark, Grand Finale, Threadline) readable in a fight? | OWNER ONLY |
