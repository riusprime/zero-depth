# BLADE: the Blade's cards multiply like the Gun's; the Gun's top end stops multiplying (v0.8.0 BL, owner O10 / O9 / O11)

G1: [`../BLADE_AUDIT.md`](../BLADE_AUDIT.md) (owner, 2026-10-14: "blade audit … OK", rows B1–B7 as proposed). Sim side:
[`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §8j; content: CONTENT_SCHEMA "v0.8.0 BL".

- **Status:** RUN (agent, headless). Feel, and whether the Blade now "gets a good combination": **OWNER ONLY**.
- **Build:** before = `48c5bf9` (`claude/lucid-fermat-9wv2tf`) plus only the probe's DPS tally and its `--weapon` /
  `--cards` / `--tag` options (`scripts/checks/perf_probe.gd`; no sim or view change), run from a copy of that tree;
  after = the tree of the `v0.8.0 Step BL` commit on branch `v080-bl` (the runs were made on that tree before it was
  committed; only these docs were written after them). Godot `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 cloud
  container, no GPU.
- **Date:** 2026-10-14. **Who ran it:** agent.

## What changed, row by row
| Row | Change | Where |
|---|---|---|
| B1 | **Double Slash**: `repeats` = its level (1–5 repeats), each at 70 % (was one repeat at 60 % + 10 %/level); the first is the step's echo, the rest queued 5 ticks apart, so the next swing doesn't cancel them. **Wave**: +1 crescent a level (child `count` +1, fan +15° a level). **Split Wave**: already +1 split a level in the data since WN4 (3 → 7; the audit's "fixed count" was not the data's); kept, tested, and its text says so now | `data/modifiers/double_slash.tres`, `echo_slash.tres`; `AttackSpec.repeats`; `ModifierRuntime.queue_echoes` / `queue_repeat`; `ItemEffects.after_swing` |
| B2 | `ModifierOpDefinition.per_level_after` (the step counts above that level). **Heavy** −30 % swing speed at L1–2, −20 / −10 / 0 % at L3 / 4 / 5. **Flurry** damage ×0.75 at L1–2, ×0.833 / ×0.917 / ×1.0 at L3 / 4 / 5. **Thrust** arc ×0.4 at L1–2, ×0.6 / ×0.8 / ×1.0 at L3 / 4 / 5. Their other level steps unchanged | `heavy.tres`, `flurry.tres`, `thrust.tres`; `ModifierOp.at_level`; `ModifierCompiler.compile_op` |
| B3 | On a Blade run a slash's hit triggers (On Hit, On Kill, On Finisher, and the legendary ×2 ones) cast twice, the second 0.1 s later (`WandTable.blade_hit_casts` 2, `blade_cast_gap_seconds` 0.1). Gun, On End, On Crit: once | `WandCompile._cut`; `data/wand/wand.tres` |
| B4 | **Blade Storm** (`blade_storm`, rare): each slash throws 1 + level returning blades (2 at L1, 6 at L5), 45 % each. **Riposte Chain** (`riposte_chain`, common): a slash kill slashes on to the next enemy within 4 m, 1 + level in the chain (2 at L1, 6 at L5), 80 %. Blade pool, levels 1–5, en + es names and texts, icons (`BladeCardIcons`), card frames; the Codex and the "every Blade card" achievement read the data (no list to edit). `ItemDefinition.index_wave` 1: their item indices come after every earlier card, so no saved index moves | `data/items/`, `data/modifiers/`; `ModifierCompiler.item_defs`; `locale/strings.csv` |
| B5 | A mod draw weighs the run's own weapon's wand cards ×1.5 against shared cards, triggers and passives (`RewardsDefinition.own_weapon_card_permille` 1500, `data/rewards/floor.tres`: the F10 panel's Economy page) | `ItemPool.card_weight`, `ItemPool.draw_weighted`, `Offers.draw` |
| B6 | `WandTable.once_per_line` (`split_shot`, `shared_explosive`): a spec whose lineage holds one of them takes neither hook again, so Split's splits (and anything cast from a split or a blast) neither split nor explode; the shot itself does both. Past `blast_merge_after` (8) Explosive blasts in one tick, a blast within its radius of one already set off that tick merges into it (doesn't go off); one farther away still does | `WandCompile.once_more`; `Attacks.merged`; `World.blast_*` (per tick, not hashed, `ADDED_SINCE_V05`) |
| B7 | Kept (the shared element cards are unchanged) | — |

Card texts (≤ 60 characters, the content test's limit): Double Slash, Wave, Split Wave, Heavy, Flurry, Thrust, Split,
Explosive, On Hit, On Kill, On Finisher, On Hit ×2, On Kill ×2 describe the new per-level effects; the level badge
("Lv 2 → 3") is unchanged.

**Readings the lead may want to confirm with the owner:**
- B1 "up to 5 slashes at L5, each 70 %" read as **5 repeats** at level 5 (+1 repeat a level from 1 at level 1), each
  at 70 %; the other reading (5 slashes in all) can't be +1 every level.
- B6 "Explosive's blasts from one trigger merge past 8": every bolt is its own root in the sim, so "one trigger" is
  read as **one tick** (a volley's bolts land and blast together); past 8 an overlapping blast is dropped, not added
  to another (the area already exploded). "Split shots and hook children can't split or explode again" is read as
  the line rule above: a trigger's cast (On Hit · Explosive) still explodes, since nothing before it split or exploded.

## Commands
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10 --twin
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10 --weapon=blade --cards=double_slash,echo_slash,split_wave,trigger_on_hit,shared_explosive --tag=blade
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10 --weapon=blade --cards=heavy,flurry,thrust --tag=blade_trade
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10 --weapon=blade --cards=double_slash,blade_storm,echo_slash,split_wave,trigger_on_hit,shared_explosive --tag=blade_storm   # after only
```
The Gun runs three times each side (timings vary run to run on this container; the damage is deterministic and was
identical in all three). The probe is PF's: the Playground's World, the cards at level 5, 6 endless dummies (4-7 m
for the Gun, 1.4-2.3 m for the Blade), 10 s of held Shoot / Primary pressed every tick after 60 warm-up ticks. New in
BL: "damage" is DpsTally's count (the Playground DPS meter's, from the event log: every player DAMAGE event's
`amount_applied` on the dummies) over the 10 measured seconds. Floor-1 numbers, no stat cards, no loops: the
owner's 50K-150K per enemy came from a run's stats and loops on top of the same cards.

## Damage per second on the dummies (run 1 of each; DpsTally)
| Build (level 5) | Before: per s | per s per dummy | After: per s | per s per dummy |
|---|---|---|---|---|
| Gun: Spread + Split + Explosive, L5 | 1431.6 | 238.6 | 778.1 | 129.7 |
| Gun: + Twin, L5 | 1694.0 | 282.3 | 1014.8 | 169.1 |
| Blade: Double Slash, Wave, Split Wave, On Hit, Explosive, L5 | 1869.6 | 311.6 | 10303.5 | 1717.2 |
| Blade: Heavy, Flurry, Thrust, L5 | 56.7 | 9.5 | 87.5 | 14.6 |
| Blade: Double Slash, Blade Storm, Wave, Split Wave, On Hit, Explosive, L5 | — (Blade Storm is new) | — | 13691.1 | 2281.8 |

## Timing (avg / p95 / max, ms; the probe's own output)
| Run | sim | total (sim + sync + frame) |
|---|---|---|
| before base 1 | 3.212 / 9.054 / 30.397 | 12.199 / 28.277 / 86.219 |
| before base 2 | 2.655 / 7.051 / 13.143 | 10.095 / 19.258 / 27.694 |
| before base 3 | 3.116 / 8.673 / 46.045 | 11.419 / 24.933 / 61.132 |
| before twin 1 | 3.203 / 11.182 / 23.837 | 11.504 / 25.794 / 51.840 |
| before twin 2 | 2.936 / 10.081 / 38.006 | 10.285 / 22.481 / 54.126 |
| before twin 3 | 2.668 / 9.088 / 22.019 | 9.570 / 20.814 / 38.512 |
| after base 1 | 1.825 / 5.109 / 11.047 | 7.259 / 13.967 / 21.047 |
| after base 2 | 1.557 / 3.631 / 8.774 | 6.157 / 11.097 / 16.531 |
| after base 3 | 1.650 / 3.921 / 8.152 | 6.555 / 12.088 / 17.503 |
| after twin 1 | 1.649 / 4.610 / 10.849 | 6.757 / 12.794 / 28.704 |
| after twin 2 | 1.585 / 4.353 / 11.651 | 6.548 / 12.780 / 19.984 |
| after twin 3 | 1.694 / 5.001 / 11.605 | 7.046 / 14.368 / 23.489 |

## Raw output: before
```
grant gun_spread L5 -> ok
grant split_shot L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            3.212     9.054    30.397
sync_ms           4.389    10.605    76.045
frame_ms          4.598     9.385    31.929
total_ms         12.199    28.277    86.219
projectiles     104.532   237.000   250.000
launches          8.097    24.000    32.000
events           26.260    77.000    99.000
shots_capped      0.033     0.000     1.000
bursts_asked     30.920    32.000    32.000
bursts_drawn     26.773    32.000    32.000
sprites_asked   379.860   449.000   449.000
sprites_drawn   368.180   417.000   417.000
lights_asked     12.000    12.000    12.000
lights_on        10.000    10.000    10.000
decals           20.677    22.000    22.000
form_effects     35.352    43.000    47.000
form_meshes     249.840   473.000   487.000
frame cost by node (ms per tick, avg):
  AttackFormView              4.094
  PlayerAvatar                0.258
  HeatVisuals                 0.061
  DamageNumbers               0.057
  StageKit                    0.018
  BossChallengeView           0.014
  HordeVisuals                0.011
  TelegraphViews              0.009
  PickupViews                 0.009
  DashTrail                   0.009
  CoreViews                   0.008
  IsoRig                      0.008
damage: 14316 over 10.0 s -> 1431.6 per s (238.6 per s per dummy; DpsTally overall 1431.6)
  shared_explosive               9106   63.6 %
  split_shot                     2792   19.5 %
  basic                          2418   16.9 %
verdict: avg 12.20 ms per tick+frame against 12.0 ms -> OVER
```

```
grant gun_spread L5 -> ok
grant split_shot L5 -> ok
grant shared_explosive L5 -> ok
grant gun_twin L5 -> ok
perf_probe: gun + gun_spread, split_shot, shared_explosive, gun_twin, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            3.203    11.182    23.837
sync_ms           4.225     8.859    14.840
frame_ms          4.077     7.010    42.066
total_ms         11.504    25.794    51.840
projectiles     113.220   252.000   256.000
launches          8.505    30.000    42.000
events           28.045   125.000   222.000
shots_capped      0.217     1.000     1.000
bursts_asked     29.442    32.000    32.000
bursts_drawn     21.648    26.000    28.000
sprites_asked   331.560   395.000   413.000
sprites_drawn   329.102   381.000   393.000
lights_asked     11.862    12.000    12.000
lights_on         9.962    10.000    10.000
decals           20.820    24.000    24.000
form_effects     33.952    43.000    49.000
form_meshes     220.905   487.000   496.000
frame cost by node (ms per tick, avg):
  AttackFormView              3.614
  PlayerAvatar                0.237
  DamageNumbers               0.051
  HeatVisuals                 0.051
  BossChallengeView           0.018
  StageKit                    0.015
  IsoRig                      0.011
  TelegraphViews              0.011
  ActorViews                  0.006
  HordeVisuals                0.005
  AbilityVisuals              0.005
  BlinkFlash                  0.005
damage: 16940 over 10.0 s -> 1694.0 per s (282.3 per s per dummy; DpsTally overall 1694.0)
  shared_explosive              11160   65.9 %
  basic                          2986   17.6 %
  split_shot                     2794   16.5 %
verdict: avg 11.50 ms per tick+frame against 12.0 ms -> within
```

```
grant double_slash L5 -> ok
grant echo_slash L5 -> ok
grant split_wave L5 -> ok
grant trigger_on_hit L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: blade + double_slash, echo_slash, split_wave, trigger_on_hit, shared_explosive, level 5, 6 dummies, 10 s of Primary pressed (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            0.849     2.568    17.797
sync_ms           2.068     3.795     6.248
frame_ms          2.236     3.672     5.567
total_ms          5.153     9.161    26.847
projectiles       0.887     7.000     7.000
launches          1.023    10.000    14.000
events           15.760    77.000    81.000
shots_capped      0.000     0.000     0.000
bursts_asked     11.280    14.000    16.000
bursts_drawn     10.872    12.000    13.000
sprites_asked   224.438   260.000   266.000
sprites_drawn   224.438   260.000   266.000
lights_asked     10.372    12.000    12.000
lights_on         9.177    10.000    10.000
decals            1.783     3.000     3.000
form_effects     26.958    41.000    57.000
form_meshes     102.305   195.000   362.000
frame cost by node (ms per tick, avg):
  AttackFormView              1.797
  PlayerAvatar                0.201
  KitView                     0.063
  DamageNumbers               0.052
  HitFeel                     0.021
  BossChallengeView           0.013
  StageKit                    0.011
  IsoRig                      0.009
  TelegraphViews              0.008
  HeatVisuals                 0.007
  ActorViews                  0.006
  ItemVisuals                 0.005
damage: 18696 over 10.0 s -> 1869.6 per s (311.6 per s per dummy; DpsTally overall 1869.6)
  shared_explosive               5247   28.1 %
  trigger_on_hit                 4833   25.9 %
  split_wave                     3809   20.4 %
  basic                          1985   10.6 %
  twin_arc                       1951   10.4 %
  echo_slash                      871    4.7 %
verdict: avg 5.15 ms per tick+frame against 12.0 ms -> within
```

```
grant heavy L5 -> ok
grant flurry L5 -> ok
grant thrust L5 -> ok
perf_probe: blade + heavy, flurry, thrust, level 5, 6 dummies, 10 s of Primary pressed (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            0.806     0.990    12.467
sync_ms           1.557     2.654     5.276
frame_ms          0.641     0.872     4.077
total_ms          3.004     4.708    14.708
projectiles       0.000     0.000     0.000
launches          0.082     1.000     1.000
events            0.300     2.000     4.000
shots_capped      0.000     0.000     0.000
bursts_asked      0.000     0.000     0.000
bursts_drawn      0.000     0.000     0.000
sprites_asked     5.000     5.000     5.000
sprites_drawn     5.000     5.000     5.000
lights_asked      0.000     0.000     0.000
lights_on         0.000     0.000     0.000
decals            0.000     0.000     0.000
form_effects      0.965     2.000     2.000
form_meshes      17.048    24.000    25.000
frame cost by node (ms per tick, avg):
  AttackFormView              0.283
  PlayerAvatar                0.239
  BossChallengeView           0.014
  StageKit                    0.013
  DamageNumbers               0.013
  IsoRig                      0.011
  TelegraphViews              0.009
  HordeVisuals                0.005
  CoreViews                   0.004
  HitFeel                     0.004
  BlinkFlash                  0.004
  AbilityVisuals              0.004
damage: 567 over 10.0 s -> 56.7 per s (9.5 per s per dummy; DpsTally overall 59.5)
  basic                           567  100.0 %
verdict: avg 3.00 ms per tick+frame against 12.0 ms -> within
```

## Raw output: after
```
grant gun_spread L5 -> ok
grant split_shot L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            1.825     5.109    11.047
sync_ms           3.039     6.758    17.432
frame_ms          2.395     5.176     8.392
total_ms          7.259    13.967    21.047
projectiles     104.532   237.000   250.000
launches          1.783     8.000    10.000
events           15.673    53.000    75.000
shots_capped      0.033     0.000     1.000
bursts_asked     21.655    32.000    32.000
bursts_drawn     13.692    17.000    18.000
sprites_asked   265.732   305.000   308.000
sprites_drawn   265.732   305.000   308.000
lights_asked     11.753    12.000    12.000
lights_on         9.887    10.000    10.000
decals           10.132    11.000    11.000
form_effects     23.558    33.000    36.000
form_meshes      76.137   192.000   209.000
frame cost by node (ms per tick, avg):
  AttackFormView              2.004
  PlayerAvatar                0.219
  DamageNumbers               0.040
  HeatVisuals                 0.040
  BossChallengeView           0.015
  StageKit                    0.012
  TelegraphViews              0.010
  IsoRig                      0.007
  ActorViews                  0.006
  HordeVisuals                0.004
  BlinkFlash                  0.003
  AbilityVisuals              0.003
damage: 7781 over 10.0 s -> 778.1 per s (129.7 per s per dummy; DpsTally overall 778.1)
  split_shot                     2807   36.1 %
  shared_explosive               2586   33.2 %
  basic                          2388   30.7 %
verdict: avg 7.26 ms per tick+frame against 12.0 ms -> within
```

```
grant gun_spread L5 -> ok
grant split_shot L5 -> ok
grant shared_explosive L5 -> ok
grant gun_twin L5 -> ok
perf_probe: gun + gun_spread, split_shot, shared_explosive, gun_twin, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            1.649     4.610    10.849
sync_ms           2.686     5.256    10.244
frame_ms          2.422     3.772     7.611
total_ms          6.757    12.794    28.704
projectiles     113.220   252.000   256.000
launches          2.032     8.000    12.000
events           16.965    68.000   104.000
shots_capped      0.217     1.000     1.000
bursts_asked     21.383    32.000    32.000
bursts_drawn     13.900    17.000    18.000
sprites_asked   265.765   299.000   311.000
sprites_drawn   265.765   299.000   311.000
lights_asked     11.583    12.000    12.000
lights_on         9.908    10.000    10.000
decals           10.367    12.000    12.000
form_effects     23.522    33.000    36.000
form_meshes     218.533   478.000   487.000
frame cost by node (ms per tick, avg):
  AttackFormView              2.119
  PlayerAvatar                0.168
  DamageNumbers               0.031
  HeatVisuals                 0.030
  BossChallengeView           0.010
  StageKit                    0.010
  TelegraphViews              0.007
  IsoRig                      0.006
  ActorViews                  0.004
  HordeVisuals                0.003
  BlinkFlash                  0.003
  AbilityVisuals              0.003
damage: 10148 over 10.0 s -> 1014.8 per s (169.1 per s per dummy; DpsTally overall 1014.8)
  shared_explosive               4358   42.9 %
  basic                          2988   29.4 %
  split_shot                     2802   27.6 %
verdict: avg 6.76 ms per tick+frame against 12.0 ms -> within
```

```
grant double_slash L5 -> ok
grant echo_slash L5 -> ok
grant split_wave L5 -> ok
grant trigger_on_hit L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: blade + double_slash, echo_slash, split_wave, trigger_on_hit, shared_explosive, level 5, 6 dummies, 10 s of Primary pressed (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            3.179     9.826    20.166
sync_ms           4.100     7.343    11.889
frame_ms          3.767     5.548     7.828
total_ms         11.046    20.927    35.720
projectiles      26.410    67.000   104.000
launches          6.950    22.000    38.000
events           68.797   161.000   262.000
shots_capped      0.000     0.000     0.000
bursts_asked     12.997    16.000    21.000
bursts_drawn     11.793    12.000    12.000
sprites_asked   243.853   254.000   260.000
sprites_drawn   243.853   254.000   260.000
lights_asked     11.427    12.000    12.000
lights_on         9.900    10.000    10.000
decals            1.757     3.000     3.000
form_effects    101.108   145.000   186.000
form_meshes     634.700   968.000  1024.000
frame cost by node (ms per tick, avg):
  AttackFormView              3.417
  PlayerAvatar                0.159
  KitView                     0.048
  DamageNumbers               0.037
  HitFeel                     0.018
  BossChallengeView           0.011
  StageKit                    0.010
  TelegraphViews              0.007
  IsoRig                      0.007
  ActorViews                  0.007
  HeatVisuals                 0.006
  ItemVisuals                 0.004
damage: 103035 over 10.0 s -> 10303.5 per s (1717.2 per s per dummy; DpsTally overall 10303.5)
  split_wave                    35975   34.9 %
  trigger_on_hit                28500   27.7 %
  shared_explosive              20828   20.2 %
  echo_slash                     9389    9.1 %
  twin_arc                       6296    6.1 %
  basic                          2047    2.0 %
verdict: avg 11.05 ms per tick+frame against 12.0 ms -> within
```

```
grant heavy L5 -> ok
grant flurry L5 -> ok
grant thrust L5 -> ok
perf_probe: blade + heavy, flurry, thrust, level 5, 6 dummies, 10 s of Primary pressed (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            0.565     0.699    11.237
sync_ms           1.100     1.644     6.974
frame_ms          0.440     0.612     4.506
total_ms          2.105     3.324    13.200
projectiles       0.000     0.000     0.000
launches          0.092     1.000     1.000
events            0.387     2.000     8.000
shots_capped      0.000     0.000     0.000
bursts_asked      0.000     0.000     0.000
bursts_drawn      0.000     0.000     0.000
sprites_asked     5.000     5.000     5.000
sprites_drawn     5.000     5.000     5.000
lights_asked      0.000     0.000     0.000
lights_on         0.000     0.000     0.000
decals            0.000     0.000     0.000
form_effects      0.953     2.000     2.000
form_meshes      17.077    24.000    24.000
frame cost by node (ms per tick, avg):
  AttackFormView              0.188
  PlayerAvatar                0.165
  DamageNumbers               0.017
  BossChallengeView           0.009
  IsoRig                      0.008
  StageKit                    0.007
  TelegraphViews              0.006
  HitFeel                     0.004
  HordeVisuals                0.003
  BlinkFlash                  0.003
  AbilityVisuals              0.002
  ItemVisuals                 0.002
damage: 875 over 10.0 s -> 87.5 per s (14.6 per s per dummy; DpsTally overall 97.0)
  basic                           875  100.0 %
verdict: avg 2.10 ms per tick+frame against 12.0 ms -> within
```

```
grant double_slash L5 -> ok
grant blade_storm L5 -> ok
grant echo_slash L5 -> ok
grant split_wave L5 -> ok
grant trigger_on_hit L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: blade + double_slash, blade_storm, echo_slash, split_wave, trigger_on_hit, shared_explosive, level 5, 6 dummies, 10 s of Primary pressed (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            7.123    18.234    71.541
sync_ms          10.291    18.230    32.402
frame_ms          9.152    14.777    37.989
total_ms         26.566    46.105   139.195
projectiles     103.343   155.000   202.000
launches         12.643    37.000    47.000
events          118.613   263.000   424.000
shots_capped      0.000     0.000     0.000
bursts_asked     10.462    13.000    15.000
bursts_drawn     10.352    12.000    12.000
sprites_asked   231.942   269.000   269.000
sprites_drawn   231.942   269.000   269.000
lights_asked     10.352    12.000    12.000
lights_on         9.027    10.000    10.000
decals            1.760     3.000     3.000
form_effects    229.270   256.000   256.000
form_meshes    1023.932  1024.000  1024.000
frame cost by node (ms per tick, avg):
  AttackFormView              8.660
  PlayerAvatar                0.222
  KitView                     0.061
  DamageNumbers               0.048
  HitFeel                     0.029
  BossChallengeView           0.016
  StageKit                    0.015
  IsoRig                      0.014
  TelegraphViews              0.011
  HeatVisuals                 0.008
  ActorViews                  0.008
  ItemVisuals                 0.006
damage: 136911 over 10.0 s -> 13691.1 per s (2281.8 per s per dummy; DpsTally overall 13691.1)
  trigger_on_hit                47135   34.4 %
  split_wave                    36024   26.3 %
  shared_explosive              20899   15.3 %
  blade_storm                   15103   11.0 %
  echo_slash                     9374    6.8 %
  twin_arc                       6344    4.6 %
  basic                          2032    1.5 %
verdict: avg 26.57 ms per tick+frame against 12.0 ms -> OVER
```

## Interpretation
- **The Gun's top end (B6): about half, not "roughly an order".** Spread + Split + Explosive: 1,431.6 → 778.1 per s
  (−46 %); with Twin 1,694.0 → 1,014.8 (−40 %). Explosive's share fell from 9,106 to 2,586 (base) and 11,160 to 4,358
  (Twin): the splits' blasts are gone and the volley's past 8 merge. The basic shot and the splits' own hits are
  unchanged. The audit's "drops by roughly an order" was a guess; the measured drop is about ×0.5 on these cards
  alone. Reported, not retuned (the stats and loops that made 150K are not in the probe).
- **The Blade's combo (B1 + B3): ×5.5.** Double Slash + Wave + Split Wave + On Hit + Explosive at level 5: 1,869.6 →
  10,303.5 per s, now above the Gun's build on the same dummies. The trade-off build (Heavy + Flurry + Thrust, L5):
  56.7 → 87.5 per s. With Blade Storm added: 13,691.1 per s.
- **Frame cost:** the Gun builds' average tick + frame fell (sim 2.6-3.2 → 1.6-1.8 ms avg; the explosions' events and
  bursts fewer). The Blade combo without Blade Storm: 11.05 ms avg (within ~12 ms), p95 20.9 ms. **With Blade Storm
  it is over: 26.57 ms avg, p95 46.1 ms** (AttackFormView 8.7 ms: 1,024 form meshes, the view's cap; sim 7.1 ms avg).
  B6's line rule covers Split and Explosive, not Split Wave on Blade Storm's and Wave's projectiles. Reported as
  missed; not retuned blind. A fix to consider (lead / owner): Split Wave in `once_per_line`, or a cap on returning
  blades, then the probe again.
- What this doesn't show: how the Blade feels to play, how often the cards are offered in a run (B5 is a weight, no
  bot sims), fps on the owner's PC. **OWNER ONLY.**

## Tests (run locally)
- Lint: `gdformat --check src scripts tests && gdlint src scripts tests`: 859 files unchanged, no problems.
- New `tests/unit/sim/test_blade_combos.gd`: 20/20 (B1 repeats and hits per level, 70 %, queued repeats survive the
  next swing; Wave and Split Wave counts per level; B2 Heavy / Flurry / Thrust per level; B3 twice on a Blade slash,
  once on the Gun and On End, two child slashes in play; B4 both cards' hooks per level, in play, Blade-only, last
  indices; B5 weights; B6 no re-split / no re-explode, cast rule, merge past 8, merges in play).
- `tests/content` + `tests/arch` + `tests/golden`: 126/126.
- `tests/unit/application` + `tests/unit/debug` + `tests/golden`: 105/105 (the old saves among them).
- Sim files by name: `test_wand`, `test_wand_blade_order`, `test_wand_compile`, `test_wand_migration`,
  `test_wand_order_fight`, `test_wand_preview`, `test_wand_shared`, `test_wand_shared_order`, `test_wand_smoke`,
  `test_combos`: 97/97; then `test_wand_blade` … `test_blade_combos` (21 files): 271/277, the 6 failures were counts and
  lists that grew by the two cards and one bound (below), fixed and re-run: 86/86.
- Presentation (icons, frames, cards, plaques, reward views, blade forms): 55/55.
- e2e: wand_blade, wand_shared, wand_build, gun_pool, damage_soak, old_save, playground, card_levels, codex,
  achievements: 13/13.
- Tests changed on purpose: item / modifier counts (+2), the Blade-only list and the rare list (+ the new cards), the
  draw-everything counts (+2), `CardPoolSurvey.POOL_MAX` 61 → 63 (the Blade pool with the two approved cards), Double
  Slash's 600 → 700, and `test_modifier_smoke_mx4`'s queued-launch bound 64 → 96 (B3 queues the second cast: Blade +
  Gravity Well + On Hit ×2 measured 68).
- Not run locally: the full suite (CLAUDE.md: once per version on GitHub), seams (the lead's), bot sims (none).

## Goldens
None changed: `tests/golden` 2/2 and `test_modifier_equivalence.gd` 3/3 pass on the old fixtures. `AttackSpec.repeats`
hashes only when set, the B6 marks aren't hashed, and no golden case holds the Blade pool's cards or draws a mod
offer.
