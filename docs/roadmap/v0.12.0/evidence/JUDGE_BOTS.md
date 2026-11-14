# JUDGE_BOTS: does ignoring the Clockwork Judge's time mechanics cost clearly more than playing them?

- **Status:** RUN
- **Build:** the tree of the commit that adds this file (`v0.12.0 Step 2`; its parent is `dd2634a5`) on `v0120-j2`,
  run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200 (the owner's PC,
  i7-10700K), debug native library built from this tree
- **Date:** 2026-11-14
- **Who ran it:** agent

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_judge_bots.gd,res://tests/unit/sim/test_world_snapshot.gd,res://tests/content/test_boss_pace.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. The two other files were
in the same process because they had just been fixed; only the first prints the lines below.)

## What the bots do
`tests/unit/sim/test_judge_bots.gd`: the real compiled Judge (2,500 HP, the data's damage, **no floor scaling**) in a
24 m walled room, a hero with the starting Gun or Blade and no items. The hero's HP is refilled every tick, so no
fight ends early; `hp_lost` is the damage it took.
- **plays:** walks to the nearest hour orb (round the gears) while it has attack speed to win back; while the Rewind
  is on, steps out of a Verdict square it stands in. Otherwise holds its weapon's distance and attacks.
- **ignores:** holds its weapon's distance and attacks. Never walks to an orb, never leaves a square.

Neither dodges the Gavel Slam, the echo or the spirals.

## Raw output
```
[… 10 lines trimmed …]
JUDGEBOT| weapon=gun bot=plays seed=5 dead=true ticks=6266 seconds=104.4 hp_lost=450 biggest=50 biggest_in=gavel_slam waves=4 orbs=12 snaps=4 snaps_in_verdict=1 verdict_hits=1 verdict_hits_after_snap=0 verdict_cost=30
JUDGEBOT| weapon=gun bot=ignores seed=5 dead=true ticks=15956 seconds=265.9 hp_lost=1432 biggest=50 biggest_in=gavel_slam waves=9 orbs=0 snaps=15 snaps_in_verdict=3 verdict_hits=17 verdict_hits_after_snap=3 verdict_cost=30
JUDGEBOT| weapon=gun bot=plays seed=6 dead=true ticks=6187 seconds=103.1 hp_lost=316 biggest=30 biggest_in=verdict waves=3 orbs=9 snaps=4 snaps_in_verdict=0 verdict_hits=1 verdict_hits_after_snap=0 verdict_cost=30
JUDGEBOT| weapon=gun bot=ignores seed=6 dead=true ticks=16204 seconds=270.1 hp_lost=1424 biggest=50 biggest_in=gavel_slam waves=10 orbs=0 snaps=15 snaps_in_verdict=1 verdict_hits=11 verdict_hits_after_snap=1 verdict_cost=30
JUDGEBOT| weapon=gun bot=plays seed=7 dead=true ticks=7180 seconds=119.7 hp_lost=490 biggest=50 biggest_in=gavel_slam waves=4 orbs=12 snaps=6 snaps_in_verdict=0 verdict_hits=2 verdict_hits_after_snap=0 verdict_cost=30
JUDGEBOT| weapon=gun bot=ignores seed=7 dead=true ticks=15932 seconds=265.5 hp_lost=1494 biggest=50 biggest_in=gavel_slam waves=9 orbs=0 snaps=15 snaps_in_verdict=0 verdict_hits=15 verdict_hits_after_snap=0 verdict_cost=30
JUDGEBOT| weapon=gun over 3 seeds: plays { "ticks": 19633, "hp_lost": 1256, "orbs": 33 }, ignores { "ticks": 48092, "hp_lost": 4350, "orbs": 0 }
JUDGEBOT| weapon=blade bot=plays seed=5 dead=true ticks=4808 seconds=80.1 hp_lost=72 biggest=38 biggest_in=gavel_slam waves=3 orbs=9 snaps=3 snaps_in_verdict=0 verdict_hits=0 verdict_hits_after_snap=0 verdict_cost=0
JUDGEBOT| weapon=blade bot=ignores seed=5 dead=true ticks=7610 seconds=126.8 hp_lost=396 biggest=38 biggest_in=gavel_slam waves=4 orbs=0 snaps=8 snaps_in_verdict=0 verdict_hits=4 verdict_hits_after_snap=0 verdict_cost=23
JUDGEBOT| weapon=blade bot=plays seed=6 dead=true ticks=3940 seconds=65.7 hp_lost=38 biggest=38 biggest_in=gavel_slam waves=2 orbs=6 snaps=4 snaps_in_verdict=0 verdict_hits=0 verdict_hits_after_snap=0 verdict_cost=0
JUDGEBOT| weapon=blade bot=ignores seed=6 dead=true ticks=7724 seconds=128.7 hp_lost=267 biggest=38 biggest_in=gavel_slam waves=4 orbs=0 snaps=7 snaps_in_verdict=1 verdict_hits=5 verdict_hits_after_snap=1 verdict_cost=23
JUDGEBOT| weapon=blade bot=plays seed=7 dead=true ticks=3895 seconds=64.9 hp_lost=165 biggest=38 biggest_in=gavel_slam waves=2 orbs=6 snaps=3 snaps_in_verdict=0 verdict_hits=0 verdict_hits_after_snap=0 verdict_cost=0
JUDGEBOT| weapon=blade bot=ignores seed=7 dead=true ticks=7887 seconds=131.4 hp_lost=290 biggest=38 biggest_in=gavel_slam waves=5 orbs=0 snaps=8 snaps_in_verdict=0 verdict_hits=6 verdict_hits_after_snap=0 verdict_cost=23
JUDGEBOT| weapon=blade over 3 seeds: plays { "ticks": 12643, "hp_lost": 275, "orbs": 21 }, ignores { "ticks": 23221, "hp_lost": 953, "orbs": 0 }
[… 43 lines trimmed …]
Scripts               3
Tests                24
Passing Tests        24
Asserts            6719
Time              132.323s
[… 2 lines trimmed …]
---- All tests passed! ----
```
The process's exit code was 0. (The terminal colour codes round the last line are left out.)

Fields: `biggest` = the most HP one tick cost and `biggest_in` the Judge's attack on that tick; `snaps` = Bell throws;
`snaps_in_verdict` = throws that landed inside a Verdict square while it wound up; `verdict_hits_after_snap` = Verdict
hits in a Verdict the hero was thrown during; `verdict_cost` = the most HP the tick of a Verdict hit cost.

## Target bands
| Metric | Target | Source |
|---|---|---|
| "ignores" against "plays", per weapon, summed over the seeds | clearly longer and/or clearly more HP lost (the test asks for at least 30 % on one of the two) | PLAN step 2; the lead's step brief |
| One miss of the signature (a Verdict hit after a throw) | about 40 % of max HP at most, never a kill from full HP | BOSS_BRIEF §1 (B3), SG-CJ |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Gun, fight length (3 seeds summed) | plays 19,633 ticks (327.2 s), ignores 48,092 (801.5 s): 2.45 times as long | Yes |
| Gun, HP lost | plays 1,256, ignores 4,350: 3.46 times as much | Yes |
| Blade, fight length | plays 12,643 ticks (210.7 s), ignores 23,221 (387.0 s): 1.84 times as long | Yes |
| Blade, HP lost | plays 275, ignores 953: 3.47 times as much | Yes |
| A Verdict hit (the cost of a throw into the square) | 30 with the Gun build, 23 with the Blade build, of the base hero's 100 HP; one hit per Verdict | Yes, at the data's damage |
| The most one tick cost | 50 (Gun) and 38 (Blade), both the Gavel Slam, which this step did not change | Not the signature |

## Interpretation
- Ignoring the orbs is what makes the fight long: the weapon stays at a quarter of its rate from the first wave (8 s)
  to the end. The bot that plays took every orb placed (33 of 33 and 21 of 21).
- A longer fight is where most of the extra HP goes: the "ignores" bot stands through 2-3 times as many Gavel Slams,
  echoes and spirals. The Verdict adds to it: 43 hits against 4 for the Gun, 15 against 0 for the Blade. Most of
  those are **not** throws: a hero that barely moves has its copy on top of it, so the copy's square is on the hero
  too. Throws into a square were rare: 4 of 45 for the Gun bot that ignores, 1 of 23 for the Blade one, and
  only 4 and 1 Verdict hits followed a throw.
- What this does not prove:
  - Nothing about feel or fairness (`OWNER ONLY`): whether the throw reads, whether the gears annoy, whether 25 s
    between waves is right.
  - Nothing at floor 5's scaling. This room has no floor scaling. `RunState.scale_bosses` multiplies boss damage by
    `1000 + boss_damage_per_floor_permille × (floor − 1)` per mille, and `data/run/five_floors.tres` has
    `boss_damage_per_floor = 0.1`: by that formula a floor-5 Verdict is 30 × 1.4 = 42, against a hero whose max HP
    is whatever the run built (100 at the base). That is a reading of the code and the data, not a measurement:
    NOT YET RUN in a floor-5 world.
  - The bots do not dodge, and a real player's Gun does not hold a 4-6 m band. The fight lengths are a comparison
    between the two bots, not a forecast of a player's time.
- For the owner or the lead to decide: the throw alone seldom lands the hero in a square (see above). If the Rewind
  should bite more often, the Bell and the Verdict would have to be timed together; this step did not do that.

---

## After step 2b (2026-11-14): each toll brings its own Verdict

- **Status:** RUN
- **Build:** the tree of the commit `v0.12.0 Step 2b` (its parent is `8188ee6f`) on `v0120-j2b`, run before the
  commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200 (the owner's PC, i7-10700K),
  debug native library built from this tree
- **Who ran it:** agent
- The numbers above this line are step 2's and are kept as they were.

### What changed
- The sim: the Judge's ordinary Verdict follows the hero in every phase again; each Bell toll locks a Verdict square
  of its own where the copy stands and drops it 0.45 s (27 ticks) after the throw (SIM_CONTRACTS §10o).
- The bots: "plays" no longer steps out of the Judge's ordinary Verdict (that square is on the hero again and is not
  a time mechanic); it steps out of a **locked Bell's Verdict square** it stands in. "ignores" is unchanged.
- Three new fields: `bell_verdicts` = the Bell's Verdicts that dropped, `bell_hits` = those that hit, `bell_cost` =
  the most HP one cost. The 40 % assert now covers `bell_cost` too.

### Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_judge_bots.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`.)

### Raw output
```
[… 10 lines trimmed …]
JUDGEBOT| weapon=gun bot=plays seed=5 dead=true ticks=6897 seconds=115.0 hp_lost=548 biggest=50 biggest_in=gavel_slam waves=4 orbs=12 snaps=6 snaps_in_verdict=0 verdict_hits=3 verdict_hits_after_snap=0 verdict_cost=30 bell_verdicts=6 bell_hits=1 bell_cost=30
JUDGEBOT| weapon=gun bot=ignores seed=5 dead=true ticks=16088 seconds=268.1 hp_lost=1820 biggest=50 biggest_in=gavel_slam waves=9 orbs=0 snaps=15 snaps_in_verdict=4 verdict_hits=17 verdict_hits_after_snap=4 verdict_cost=30 bell_verdicts=15 bell_hits=12 bell_cost=30
JUDGEBOT| weapon=gun bot=plays seed=6 dead=true ticks=6335 seconds=105.6 hp_lost=406 biggest=30 biggest_in=verdict waves=3 orbs=9 snaps=4 snaps_in_verdict=0 verdict_hits=3 verdict_hits_after_snap=0 verdict_cost=30 bell_verdicts=4 bell_hits=1 bell_cost=30
JUDGEBOT| weapon=gun bot=ignores seed=6 dead=true ticks=16112 seconds=268.5 hp_lost=1770 biggest=50 biggest_in=gavel_slam waves=10 orbs=0 snaps=15 snaps_in_verdict=1 verdict_hits=12 verdict_hits_after_snap=1 verdict_cost=30 bell_verdicts=15 bell_hits=12 bell_cost=30
JUDGEBOT| weapon=gun bot=plays seed=7 dead=true ticks=5908 seconds=98.5 hp_lost=582 biggest=50 biggest_in=gavel_slam waves=3 orbs=9 snaps=5 snaps_in_verdict=0 verdict_hits=4 verdict_hits_after_snap=0 verdict_cost=30 bell_verdicts=5 bell_hits=2 bell_cost=30
JUDGEBOT| weapon=gun bot=ignores seed=7 dead=true ticks=16096 seconds=268.3 hp_lost=1892 biggest=50 biggest_in=gavel_slam waves=9 orbs=0 snaps=15 snaps_in_verdict=0 verdict_hits=15 verdict_hits_after_snap=0 verdict_cost=30 bell_verdicts=15 bell_hits=14 bell_cost=30
JUDGEBOT| weapon=gun over 3 seeds: plays { "ticks": 19140, "hp_lost": 1536, "orbs": 30 }, ignores { "ticks": 48296, "hp_lost": 5482, "orbs": 0 }
JUDGEBOT| weapon=blade bot=plays seed=5 dead=true ticks=4923 seconds=82.0 hp_lost=133 biggest=38 biggest_in=gavel_slam waves=3 orbs=9 snaps=4 snaps_in_verdict=0 verdict_hits=0 verdict_hits_after_snap=0 verdict_cost=0 bell_verdicts=4 bell_hits=1 bell_cost=23
JUDGEBOT| weapon=blade bot=ignores seed=5 dead=true ticks=7642 seconds=127.4 hp_lost=580 biggest=38 biggest_in=gavel_slam waves=4 orbs=0 snaps=8 snaps_in_verdict=0 verdict_hits=4 verdict_hits_after_snap=0 verdict_cost=23 bell_verdicts=8 bell_hits=8 bell_cost=23
JUDGEBOT| weapon=blade bot=plays seed=6 dead=true ticks=3949 seconds=65.8 hp_lost=84 biggest=38 biggest_in=gavel_slam waves=2 orbs=6 snaps=4 snaps_in_verdict=0 verdict_hits=1 verdict_hits_after_snap=0 verdict_cost=23 bell_verdicts=4 bell_hits=1 bell_cost=23
JUDGEBOT| weapon=blade bot=ignores seed=6 dead=true ticks=7748 seconds=129.1 hp_lost=405 biggest=38 biggest_in=gavel_slam waves=4 orbs=0 snaps=7 snaps_in_verdict=1 verdict_hits=5 verdict_hits_after_snap=1 verdict_cost=23 bell_verdicts=7 bell_hits=6 bell_cost=23
JUDGEBOT| weapon=blade bot=plays seed=7 dead=true ticks=3943 seconds=65.7 hp_lost=211 biggest=38 biggest_in=gavel_slam waves=2 orbs=6 snaps=3 snaps_in_verdict=0 verdict_hits=1 verdict_hits_after_snap=0 verdict_cost=23 bell_verdicts=3 bell_hits=1 bell_cost=23
JUDGEBOT| weapon=blade bot=ignores seed=7 dead=true ticks=7915 seconds=131.9 hp_lost=451 biggest=38 biggest_in=gavel_slam waves=5 orbs=0 snaps=7 snaps_in_verdict=0 verdict_hits=6 verdict_hits_after_snap=0 verdict_cost=23 bell_verdicts=7 bell_hits=7 bell_cost=23
JUDGEBOT| weapon=blade over 3 seeds: plays { "ticks": 12815, "hp_lost": 428, "orbs": 21 }, ignores { "ticks": 23305, "hp_lost": 1436, "orbs": 0 }
[… 12 lines trimmed …]
Scripts               1
Tests                 2
Passing Tests         2
Asserts              42
Time              44.261s
[… 2 lines trimmed …]
---- All tests passed! ----
```
The process's exit code was 0. (The terminal colour codes round the last line are left out.)

### Result
| Metric | Measured | In band? |
|---|---|---|
| Bell's Verdicts that hit the bot that ignores | Gun 38 of 45, Blade 21 of 22: 59 of 67 (88 %) | Yes: "a hit after most throws" (the step's brief) |
| Bell's Verdicts that hit the bot that plays | Gun 4 of 15, Blade 3 of 11: 7 of 26 (27 %) | For the lead to judge against "few": at least one in every fight |
| One miss of the signature (`bell_cost`) | 30 with the Gun build, 23 with the Blade build, of the base hero's 100 HP; once per toll | Yes (40 % at most, never a kill from full HP) |
| Gun, fight length (3 seeds summed) | plays 19,140 ticks (319.0 s), ignores 48,296 (804.9 s): 2.52 times as long | Yes |
| Gun, HP lost | plays 1,536, ignores 5,482: 3.57 times as much | Yes |
| Blade, fight length | plays 12,815 ticks (213.6 s), ignores 23,305 (388.4 s): 1.82 times as long | Yes |
| Blade, HP lost | plays 428, ignores 1,436: 3.36 times as much | Yes |

### Interpretation
- The Rewind now costs the bot that ignores it: 59 of its 67 throws ended in a Verdict hit, against 5 of 68 in
  step 2. The 8 misses are throws after which holding its weapon's distance happened to walk it out of the square.
- The bot that plays is still hit by 7 of 26. Why was not looked into (the step's brief: paste and do not retune).
  The base hero walks 6 m/s (`PlayerDefinition.move_speed_mps`), so 0.45 s is 2.7 m against the 1.5 m half-square
  plus its own radius; that is a reading of the data, and it does not say what stopped the bot those 7 times (a
  gear, a wall, the Judge's body, a slow, or the bot's own steering are all possible). NOT YET RUN: a trace of
  those 7 drops.
- Both bots lose more HP than in step 2 (Gun plays 1,256 → 1,536, ignores 4,350 → 5,482; Blade plays 275 → 428,
  ignores 953 → 1,436). Part of it is the Bell's Verdict; part is that the bot that plays no longer leaves the
  ordinary Verdict, which is on the hero again in phases 2-3 (`verdict_hits` 4 → 10 for the Gun, 0 → 2 for the
  Blade).
- Still not proven: feel and fairness of 0.45 s (`OWNER ONLY`), and anything at floor 5's scaling (NOT YET RUN).
