# CARD_POOL: does step CP grow the pool to 40–50 distinct candidate cards, every one reachable?

- **Status:** RUN
- **Build:** the CP worktree branch, cut from `claude/lucid-fermat-9wv2tf` at `68e7f8f`; the runs below are of the
  working tree committed as `v0.5.0 Step CP: a 40–50 card pool` (the commit's own SHA is in `git log`); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS Linux (cloud container), screenshots under Xvfb with Vulkan on llvmpipe
- **Date:** 2026-10-07
- **Who ran it:** agent
- **Scope:** owner 2026-10-07 "okay let's bove the bigger card pool to v0.5 and make it in this current development
  sprint"; ROADMAP v0.5.0 "A 40–50 card candidate pool (abilities, stat cards, mods)"; owner F9 and F13 (v0.4.0
  PLAN).

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash scripts/verify.sh
godot --headless --path . -s scripts/checks/card_pool.gd -- seeds=300
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan -s scripts/shots/card_pool.gd
```

## How the pool is counted (read this first)
A **distinct card** is an ability (a new one and its level-ups are one card), a stat-card kind (its common, rare
and epic are one card) or a mod. A run's **candidate pool** is what its build can ever be offered: every ability
but the other build's start weapon, every stat card with a weight, every mod whose weapon the build has
(`tests/support/card_pool_survey.gd`, `CardPoolSurvey.pool`). The three abilities of step AB (Arc Field, Frost
Nova, Flame Trail, PLAN v0.4.0) count as planned until their data exists, so the test keeps holding after AB.

| | Abilities | Stat kinds | Mods | Pool |
|---|---|---|---|---|
| Before CP, Blade | 6 + 3 planned | 12 | 20 (9 blade + 11 any) | 41 |
| Before CP, Gun | 6 + 3 planned | 12 | 18 (7 gun + 11 any) | 39 |
| **After CP, Blade** | 6 + 3 planned | 17 | 24 | **50** |
| **After CP, Gun** | 6 + 3 planned | 17 | 22 | **48** |

**Open question for the owner (not resolved here):** the whole content set is larger than one run's pool: 10
abilities (with AB) + 17 stat kinds + 31 mods = 58 distinct cards across both builds. Counted that way the pool
was already 49 before CP (with AB's three) and almost nothing could be added inside 50. The step brief asked for
≈8 stat kinds and ≈6–8 mods *and* a 40–50 test; both can't hold, so CP built 5 stat kinds + 4 mods, the most that
keeps each build's run pool at ≤ 50, and counts per build. If the owner means the global count, v0.6.0's pruning
(ROADMAP) has to remove 8+ cards, or the band moves.

## The cards added
Rule stat cards (each a `StatCardDefinition` in `data/stat_cards/`; amounts common / rare / epic):

| Card | Amounts | Rule | Cap / limit | Weight |
|---|---|---|---|---|
| Glass Cannon | +15 / 25 / 40 % damage, −8 / 10 / 12 % max HP | both stats move | damage ×3, max HP ≥ ×0.4 | 6 |
| Onrush | +10 / 18 / 30 % damage | only while the move input is held | +90 % | 8 |
| Overkill | 40 / 70 / 100 % | a direct kill's excess splashes onto the nearest other enemy within 3 m, once | 150 % | 7 |
| Hoarder | +4 / 6 / 10 % damage per 100 shards held, +10 / 15 / 25 % shards | whole hundreds, ≤ 1000 shards count | +20 % per 100 | 6 |
| Fast Hands | −8 / 14 / 20 % | auto abilities' cooldowns and periods only | −60 % | 8 |

Ability mods (each an `ItemDefinition` in `data/items/`, rare, tag `ability`, offered only while you own the
ability):

| Mod | Ability | Effect |
|---|---|---|
| Cluster Payload | Bomb Lobber | each thrown bomb splits into 3 bomblets at its edge, 0.25 s later, 40 % damage, half radius; bomblets never split |
| Overclocked Drone | Drone Buddy (and heat) | +0.8 % drone fire rate per heat point |
| Razor Orbit | Orbit Blades | each blade touch adds 1 bleed (the bleed engine) |
| Afterimage | Blink | a blink leaves an echo where it began: 18 in 1.8 m, 0.4 s later |

Offers: the composition rules from BS are unchanged (a free altar's first card a new ability while a slot is free;
card-type weights [ability, stat, mod] altar 15/75/10, chest 15/55/30). One change: a stat card is now drawn by its
`weight` (it was uniform), so the trade-off cards (weight 6–8) come up a little less than the core stats (8–12).

## Raw output
Import (`build/import.log`): exit 0, 0 lines starting `ERROR` or `SCRIPT ERROR`.

Lint:
```
405 files would be left unchanged
Success: no problems found
```

`bash scripts/verify.sh` (tail):
```
Totals
------
Scripts             133
Tests               795
Passing Tests       795
Asserts           422403
Time              503.924s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (795 passing, minimum 795)
```

Pool sizes (`tests/unit/sim/test_card_pool_reach.gd`, and the script):
```
blade pool: 47 in the data + 3 planned ["ability:arc_field", "ability:flame_trail", "ability:frost_nova"] = 50
gun pool: 45 in the data + 3 planned ["ability:arc_field", "ability:flame_trail", "ability:frost_nova"] = 48
```

Offer frequencies, `scripts/checks/card_pool.gd -- seeds=300` (`build/card_pool.txt`): per build, 300 seeds × 4
reachable states (no card yet; slots filled with Bomb + Drone + Orbit, Blink + Bomb + Orbit, Aegis + Drone + Bomb)
× one altar and one chest, each on a fresh world with heat on, as `main.gd` builds a run (last line printed, not in
the file):
```
blade pool: 47 in the data + 3 planned ["ability:arc_field", "ability:flame_trail", "ability:frost_nova"] = 50
blade: 1200 altar rolls, 1200 chest rolls, 7200 cards
card                           altar   chest   total   share
ability:aegis                    114      47     161   2.24%
ability:blink                    112      56     168   2.33%
ability:bomb_lobber              176     106     282   3.92%
ability:combo_sword              107     113     220   3.06%
ability:drone_buddy              135      93     228   3.17%
ability:orbit_blades             130      77     207   2.88%
mod:afterimage                     1      26      27   0.38%
mod:bulwark                        1      25      26   0.36%
mod:cluster_payload               11      71      82   1.14%
mod:cold_snap                     17      80      97   1.35%
mod:conductor                     31      90     121   1.68%
mod:ember_edge                    18      25      43   0.60%
mod:executioner                   14      40      54   0.75%
mod:glacial_edge                  11      23      34   0.47%
mod:heat_sink                      9      28      37   0.51%
mod:kinetic_dash                  23      37      60   0.83%
mod:long_edge                     23      36      59   0.82%
mod:meltdown                      10      94     104   1.44%
mod:momentum                      17      27      44   0.61%
mod:overcharge                     9      33      42   0.58%
mod:overclocked_drone              6      42      48   0.67%
mod:phase_strike                  17      23      40   0.56%
mod:razor_orbit                    8      35      43   0.60%
mod:serrated_edge                 10      42      52   0.72%
mod:swift_feet                    15      28      43   0.60%
mod:thermal_edge                  15      39      54   0.75%
mod:thorn_mantle                  10      33      43   0.60%
mod:twin_arc                      16      36      52   0.72%
mod:vampiric_core                 21      47      68   0.94%
mod:wildfire                      22      92     114   1.58%
stat:area                        134      88     222   3.08%
stat:armour                      150     120     270   3.75%
stat:attack_speed                233     196     429   5.96%
stat:cooldowns                   168     144     312   4.33%
stat:crit_chance                 180     148     328   4.56%
stat:crit_damage                 172     136     308   4.28%
stat:damage                      191     160     351   4.88%
stat:fast_hands                  129     112     241   3.35%
stat:glass_cannon                103      76     179   2.49%
stat:hoarder                     124     104     228   3.17%
stat:max_hp                      164     160     324   4.50%
stat:move_speed                  124     100     224   3.11%
stat:onrush                      153     128     281   3.90%
stat:overkill                    132     112     244   3.39%
stat:pickup_range                 65      48     113   1.57%
stat:regen                       150     108     258   3.58%
stat:shard_gain                  119     116     235   3.26%
card_pool: ok
gun pool: 45 in the data + 3 planned ["ability:arc_field", "ability:flame_trail", "ability:frost_nova"] = 48
gun: 1200 altar rolls, 1200 chest rolls, 7200 cards
card                           altar   chest   total   share
ability:aegis                    114      47     161   2.24%
ability:blink                    112      56     168   2.33%
ability:bomb_lobber              176     106     282   3.92%
ability:drone_buddy              135      81     216   3.00%
ability:orbit_blades             128      96     224   3.11%
ability:pulse_gun                109     106     215   2.99%
mod:afterimage                     7      25      32   0.44%
mod:barbed_bolts                  19      46      65   0.90%
mod:cinder_shot                   16      44      60   0.83%
mod:cluster_payload               14      73      87   1.21%
mod:cold_snap                     16     108     124   1.72%
mod:executioner                   14      41      55   0.76%
mod:frost_core                    19      37      56   0.78%
mod:heat_sink                     20      30      50   0.69%
mod:kinetic_dash                  19      32      51   0.71%
mod:meltdown                      21     108     129   1.79%
mod:overclocked_drone             10      41      51   0.71%
mod:phase_strike                  20      26      46   0.64%
mod:rapid_coil                    18      42      60   0.83%
mod:razor_orbit                   10      51      61   0.85%
mod:ricochet_core                 12      29      41   0.57%
mod:splinter_shot                 17      43      60   0.83%
mod:static_chain                  17      45      62   0.86%
mod:swift_feet                    17      36      53   0.74%
mod:thermal_edge                  17      26      43   0.60%
mod:thorn_mantle                  12      38      50   0.69%
mod:vampiric_core                  8      37      45   0.62%
mod:wildfire                      12      94     106   1.47%
stat:area                        134      88     222   3.08%
stat:armour                      150     120     270   3.75%
stat:attack_speed                233     196     429   5.96%
stat:cooldowns                   168     144     312   4.33%
stat:crit_chance                 180     148     328   4.56%
stat:crit_damage                 172     136     308   4.28%
stat:damage                      191     160     351   4.88%
stat:fast_hands                  129     112     241   3.35%
stat:glass_cannon                103      76     179   2.49%
stat:hoarder                     124     104     228   3.17%
stat:max_hp                      164     160     324   4.50%
stat:move_speed                  124     100     224   3.11%
stat:onrush                      153     128     281   3.90%
stat:overkill                    132     112     244   3.39%
stat:pickup_range                 65      48     113   1.57%
stat:regen                       150     108     258   3.58%
stat:shard_gain                  119     116     235   3.26%
```

The e2e through `main.tscn` (input only; the dev panel's buttons clicked with the mouse to fill the slots):
```
res://tests/e2e/test_e2e_card_pool.gd
* test_open_altars_until_a_new_card_is_offered_and_take_it
    offered hoarder: Hoarder / +4% damage per 100 shards held, +10% shards
1/1 passed.
```

Screenshots (`build/shots_cp.log`):
```
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
card_pool: renderer=forward_plus
card_pool: offer [2122, 2151, 2140]
card_pool: shot …/build/shots/v0.5.0/card_pool/01_rule_cards.png
card_pool: offer [2131, 2162, 4]
card_pool: shot …/build/shots/v0.5.0/card_pool/02_rule_and_mod.png
card_pool: offer [20, 0, 17]
card_pool: shot …/build/shots/v0.5.0/card_pool/03_ability_mods.png
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Pool | 40 ≤ distinct cards ≤ 50 per build, AB's three counted | ROADMAP v0.5.0; step brief |
| No dead cards | every pool card offered from some reachable state | step brief |
| Suite | all pass, ≥ the committed minimum | CLAUDE.md "Testing before a push" |
| Readable cause, replay golden | unchanged | step brief |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Pool | Blade 50, Gun 48 | yes |
| No dead cards | 0 dead in both builds (`card_pool: ok`; `test_every_card_in_the_pool_is_offered_from_some_reachable_state`) | yes |
| Rarest card | Bulwark 26 and Afterimage 27 of 7200 (Blade): each needs its utility ability first | yes (reachable) |
| Ability mods mostly from chests | e.g. Cluster Payload 11 altar / 71 chest (Blade) | yes |
| Suite | 795 / 795 (was 777; `tests/MIN_TEST_COUNT` raised to 795) | yes |
| Readable cause, replay golden | `test_readable_cause.gd` and `test_replay_ground_plane.gd` pass; no golden regenerated | yes |

## Interpretation
The pool is bigger in each run (Blade 41 → 50, Gun 39 → 48) without crossing the ROADMAP's 50, and every card can
come up. Nothing here measures balance or fun: whether Glass Cannon or Hoarder is a real choice, and every number
in the tables above, are starting values for the owner (OWNER ONLY: feel, fun, balance). The counting rule is an
open question (above).

## Screenshots
Shot setup (not play): the script grants Bomb Lobber, Drone Buddy and Orbit Blades, sets the altar's offer to the
cards shown and places the hero by it; the input path is the e2e above.
- [`card_pool_rule_cards.png`](card_pool_rule_cards.png): Glass Cannon (epic: +40 % damage, −12 % max HP),
  Hoarder (rare), Overkill (common), each with its own symbol and both numbers.
- [`card_pool_rule_and_mod.png`](card_pool_rule_and_mod.png): Onrush, Fast Hands and the Cluster Payload mod.
- [`card_pool_ability_mods.png`](card_pool_ability_mods.png): Razor Orbit, Afterimage, Overclocked Drone
  ("Mod · Rare").
