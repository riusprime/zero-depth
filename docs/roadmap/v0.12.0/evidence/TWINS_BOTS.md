# TWINS_BOTS: does ignoring the Twin Wardens' new mechanics cost clearly more than playing them?

- **Status:** RUN. **Met with the Gun, NOT MET with the Blade** (see "Result"): the numbers are below, nothing was
  retuned, and the test's assert was left as written, so `test_twins_bots.gd` fails on the Blade.
- **Build:** the tree of the commit that adds this file (`v0.12.0 Step 6`; its parent is `278b6b78`) on `v0120-w6`,
  run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200 (the owner's
  PC, i7-10700K), debug native library built from this tree
- **Date:** 2026-11-14
- **Who ran it:** agent

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_twins_bots.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. Two other Godot test
processes of this worktree ran at the same time; no timing is taken from this run. The process exited 1: the Blade's
assert, below.)

## What the bots do
`tests/unit/sim/test_twins_bots.gd`: the real compiled Twin Wardens (3,000 HP in one pool, the data's numbers, **no
floor scaling**) in a 24 m walled room, a hero with the starting Gun or Blade and no items. The hero has its real max
HP (100) and is refilled every tick and cannot die, so every fight runs to the Wardens' death; `hp_lost` is the
damage it took. `phases` is each phase's length in ticks. `reflected` counts shots the Mirror Ward sent back and
`reflected_hits` those that then hit the hero; `blocks` swings the ward pushed back; `ward_breaks` phase-3 wards
broken by a charge; `bursts` / `burst_hits` charge bursts and those that hit; `rifts` Through the Rift casts;
`rift_cost` the most HP one tick cost while its exit charge ran or its burst was pending.
- **plays:** holds its attack while inside the Mirror Ward's arc and walks round it; in phase 3, while the amber
  Warden winds a charge up at the violet one's standing ward, walks (round her) to 2.5 m behind her on his line;
  otherwise steps out of a charge's lane and end circle, an armed burst's circle and the rift's marked exit lane.
  Else holds its weapon's distance from the body to hit and attacks.
- **ignores:** holds its weapon's distance (Gun 4-6 m, Blade 1.2 m from the body's edge) from the body to hit and
  attacks.
- Both back away in a circle (back and toward the room's middle). Neither dodges the sword combo, the overhead, the
  Sword Lane, the fans, the swords or their rifts.

## Raw output
```
TWINSBOT| weapon=gun bot=plays seed=5 dead=true ticks=7391 seconds=123.2 phases=[3118, 1966, 2307] hp_lost=1341 biggest=50 reflected=1 reflected_hits=0 blocks=0 ward_breaks=1 bursts=11 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=gun bot=ignores seed=5 dead=true ticks=7158 seconds=119.3 phases=[2688, 2177, 2293] hp_lost=1717 biggest=50 reflected=24 reflected_hits=5 blocks=0 ward_breaks=1 bursts=11 burst_hits=0 rifts=1 rift_cost=8
TWINSBOT| weapon=gun bot=plays seed=6 dead=true ticks=7425 seconds=123.8 phases=[3118, 2046, 2261] hp_lost=1285 biggest=50 reflected=2 reflected_hits=0 blocks=0 ward_breaks=1 bursts=11 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=gun bot=ignores seed=6 dead=true ticks=6841 seconds=114.0 phases=[2452, 2230, 2159] hp_lost=1815 biggest=50 reflected=36 reflected_hits=8 blocks=0 ward_breaks=0 bursts=10 burst_hits=1 rifts=1 rift_cost=40
TWINSBOT| weapon=gun bot=plays seed=7 dead=true ticks=6797 seconds=113.3 phases=[2494, 2078, 2225] hp_lost=1282 biggest=50 reflected=3 reflected_hits=0 blocks=0 ward_breaks=2 bursts=9 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=gun bot=ignores seed=7 dead=true ticks=7126 seconds=118.8 phases=[2410, 2225, 2491] hp_lost=1871 biggest=50 reflected=37 reflected_hits=9 blocks=0 ward_breaks=0 bursts=11 burst_hits=1 rifts=1 rift_cost=40
TWINSBOT| weapon=gun over 3 seeds: plays { "ticks": 21613, "hp_lost": 3908 }, ignores { "ticks": 21125, "hp_lost": 5403 }
TWINSBOT| weapon=blade bot=plays seed=5 dead=true ticks=3515 seconds=58.6 phases=[1015, 902, 1598] hp_lost=404 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=0 bursts=2 burst_hits=0 rifts=1 rift_cost=8
TWINSBOT| weapon=blade bot=ignores seed=5 dead=true ticks=3094 seconds=51.6 phases=[994, 994, 1106] hp_lost=390 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=1 burst_hits=1 rifts=1 rift_cost=30
TWINSBOT| weapon=blade bot=plays seed=6 dead=true ticks=3367 seconds=56.1 phases=[1124, 984, 1259] hp_lost=244 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=2 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=blade bot=ignores seed=6 dead=true ticks=3290 seconds=54.8 phases=[1100, 1014, 1176] hp_lost=262 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=2 burst_hits=1 rifts=1 rift_cost=0
TWINSBOT| weapon=blade bot=plays seed=7 dead=true ticks=3370 seconds=56.2 phases=[1028, 1045, 1297] hp_lost=310 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=2 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=blade bot=ignores seed=7 dead=true ticks=3493 seconds=58.2 phases=[1012, 1180, 1301] hp_lost=520 biggest=38 reflected=0 reflected_hits=0 blocks=11 ward_breaks=0 bursts=4 burst_hits=3 rifts=1 rift_cost=30
TWINSBOT| weapon=blade over 3 seeds: plays { "ticks": 10252, "hp_lost": 958 }, ignores { "ticks": 9877, "hp_lost": 1172 }
    [Failed]:  blade: ignoring them takes at least 30 % longer or costs at least 30 % more HP
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| "ignores" against "plays", per weapon, 3 seeds summed | at least 30 % longer, or at least 30 % more HP lost | the step's brief ("clearly slower and/or loses clearly more"; the 30 % is the Judge's test's) |
| "ignores" still wins | every fight ends with the Wardens dead | the step's brief (one HP pool) |
| One hit of Through the Rift | at most 40 % of the hero's max HP | BOSS_BRIEF §5b |

## Result

| | Gun plays | Gun ignores | Blade plays | Blade ignores |
|---|---|---|---|---|
| Fight length, 3 seeds (ticks) | 21,613 | 21,125 | 10,252 | 9,877 |
| HP lost, 3 seeds | 3,908 | 5,403 | 958 | 1,172 |
| Shots sent back / of those, hit the hero | 6 / 0 | 97 / 22 | 0 / 0 | 0 / 0 |
| Swings pushed back | 0 | 0 | 0 | 11 |
| Ward breaks | 4 | 1 | 2 | 2 |
| Charge bursts / hit the hero | 31 / 0 | 32 / 2 | 6 / 0 | 7 / 5 |
| Through the Rift cast (of 3 fights) | 3 | 3 | 3 | 3 |
| Most one tick cost during the rift's exit | 0 | 40 | 8 | 30 |

| Metric | Measured | In band? |
|---|---|---|
| Gun: HP lost, ignores against plays | 5,403 against 3,908: 38 % more (2 % shorter) | Yes |
| Blade: HP lost, ignores against plays | 1,172 against 958: 22 % more (4 % shorter) | **No** |
| Every fight won, both bots, both weapons | 12 of 12 | Yes |
| One hit of Through the Rift | 40 at most (of 100) | Yes |

- **NOT MET with the Blade.** The assert stands and fails; nothing was retuned.
- **What the numbers show** (read from the raw lines, not traced tick by tick):
  1. A Blade fight lasts under a minute and each phase about 17 s, so the new mechanics appear a few times at most:
     the Mirror Ward met a swing in one fight of six (11 blocks, seed 7, ignores), six or seven charges were thrown
     in three fights, Through the Rift once a fight.
  2. The Blade bot that plays loses less (958 against 1,172) but takes longer in phase 3 (4,154 ticks against
     3,583): walking behind the violet Warden takes it off the amber one it was hitting, and it broke the ward
     no more often than the bot that ignores (2 each: a charge aimed at a hero in melee often crosses her anyway).
  3. With the Gun the difference is the Mirror Ward (97 shots sent back against 6, 22 of them hitting) and the
     bursts; the playing bot's fights are slightly longer because it stops firing to walk round the ward.
  4. Breaking the ward is a reward (5 s at 150 %), not a cost: a bot that ignores it only gives the reward up, so
     it shows in fight length, where the two bots are within 4 %.

## Earlier runs of this harness (same day, superseded)
- **Run 1** (before the bots backed away in a circle): the Gun bot that ignores backed into a corner in phase 1,
  the amber Warden then stood back beside it (inside the corner, between it and the violet one) and blocked every
  shot; all three of its fights hit the 900 s cap in phase 2 with the Wardens alive
  (`ticks=54000 … phases=[1581, 52419, 0]`, seed 5). The pinning is real behaviour of the fight (a body standing
  back can body-block a hero in a corner); the bots were changed to circle so the comparison measures the
  mechanics, and the pin is listed for the lead in PROGRESS.
- **Run 2** (circling bots; the rift then needed both Wardens free and opened in only 2 of 12 fights; the playing
  bot walked straight at the spot behind her): Gun plays 22,020 ticks / 3,966 HP, ignores 20,899 / 5,466; Blade
  plays 9,935 / 928, ignores 9,446 / 1,132. After it, the rift's trigger was changed to need only the amber Warden
  free (a rule fix, not a number), and the playing bot walks round her body.
- **Run 3** (before two guards were added: a side dash ends when its Warden is no longer free, a held-up run to
  the rift ends after 2 s): the same lines as the run above except Blade ignores seed 7
  (`ticks=3294 … hp_lost=437`), total Blade ignores 9,678 ticks / 1,089 HP.

## Not measured
- The Wardens at floor-4 scaling (the bots fight them unscaled), and a real boss room (larger than 24 m, maybe with
  pillars: the rifts' ring and the charge's lanes were only run in the open square).
- Which hits make up `hp_lost` (no split by attack was printed), and why the Gun bot that plays still loses about
  1,300 HP a fight.
- Feel, difficulty, whether 0.4 s of locked aim and 1.4 s of wind-up are right (the brief's TW8): `OWNER ONLY`.

## After step 13 (the owner's playtest, PLAN rows F1-F9)
- **Status:** RUN. **Met with both weapons** (ignoring costs more than 30 % more HP with each; the Gun's also takes
  about 50 % longer). Nothing was retuned to reach it; the bots are unchanged (they still read the phase-1 charge's
  lane from `WorldReader.boss_wardens()["charge"]`, which the views no longer draw, and walk out of it).
- **Build:** the tree of the commit that adds this section (`v0.12.0 Step 13`; its parent is `ee030910`) on
  `v0120-s13`, run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200
  (the owner's PC, i7-10700K), the debug native library copied from the main checkout (no native change).
- **Date:** 2026-11-18. **Who ran it:** agent. Two other Godot test processes of this worktree ran at the same time;
  no timing is taken from this run.

### Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_twins_bots.gd -gexit
```
Exit code 0; 2 of 2 tests passed (26 asserts).

### Raw output
```
TWINSBOT| weapon=gun bot=plays seed=5 dead=true ticks=7434 seconds=123.9 phases=[2067, 2076, 3291] hp_lost=1469 biggest=50 reflected=1 reflected_hits=0 blocks=0 ward_breaks=2 bursts=3 burst_hits=0 rifts=1 rift_cost=40
TWINSBOT| weapon=gun bot=ignores seed=5 dead=true ticks=13032 seconds=217.2 phases=[2048, 1927, 9057] hp_lost=3678 biggest=50 reflected=0 reflected_hits=0 blocks=0 ward_breaks=0 bursts=14 burst_hits=0 rifts=1 rift_cost=40
TWINSBOT| weapon=gun bot=plays seed=6 dead=true ticks=7304 seconds=121.7 phases=[2127, 1982, 3195] hp_lost=1392 biggest=50 reflected=1 reflected_hits=0 blocks=0 ward_breaks=2 bursts=3 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=gun bot=ignores seed=6 dead=true ticks=13205 seconds=220.1 phases=[1923, 2138, 9144] hp_lost=3831 biggest=50 reflected=24 reflected_hits=6 blocks=0 ward_breaks=0 bursts=14 burst_hits=1 rifts=1 rift_cost=40
TWINSBOT| weapon=gun bot=plays seed=7 dead=true ticks=8007 seconds=133.4 phases=[2000, 2050, 3957] hp_lost=1766 biggest=50 reflected=2 reflected_hits=0 blocks=0 ward_breaks=2 bursts=4 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=gun bot=ignores seed=7 dead=true ticks=7974 seconds=132.9 phases=[2000, 2267, 3707] hp_lost=1869 biggest=50 reflected=38 reflected_hits=9 blocks=0 ward_breaks=1 bursts=5 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=gun over 3 seeds: plays { "ticks": 22745, "hp_lost": 4627 }, ignores { "ticks": 34211, "hp_lost": 9378 }
TWINSBOT| weapon=blade bot=plays seed=5 dead=true ticks=3218 seconds=53.6 phases=[1244, 1042, 932] hp_lost=359 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=1 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=blade bot=ignores seed=5 dead=true ticks=3123 seconds=52.0 phases=[1141, 1073, 909] hp_lost=424 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=1 burst_hits=1 rifts=1 rift_cost=30
TWINSBOT| weapon=blade bot=plays seed=6 dead=true ticks=3148 seconds=52.5 phases=[1240, 902, 1006] hp_lost=241 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=1 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=blade bot=ignores seed=6 dead=true ticks=2957 seconds=49.3 phases=[1140, 885, 932] hp_lost=336 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=1 burst_hits=1 rifts=1 rift_cost=30
TWINSBOT| weapon=blade bot=plays seed=7 dead=true ticks=3196 seconds=53.3 phases=[1248, 1012, 936] hp_lost=287 biggest=38 reflected=0 reflected_hits=0 blocks=0 ward_breaks=1 bursts=1 burst_hits=0 rifts=1 rift_cost=0
TWINSBOT| weapon=blade bot=ignores seed=7 dead=true ticks=5386 seconds=89.8 phases=[1141, 1310, 2935] hp_lost=964 biggest=38 reflected=0 reflected_hits=0 blocks=11 ward_breaks=0 bursts=4 burst_hits=2 rifts=1 rift_cost=30
TWINSBOT| weapon=blade over 3 seeds: plays { "ticks": 9562, "hp_lost": 887 }, ignores { "ticks": 11466, "hp_lost": 1724 }
```

### Reading it
- Gun: ignoring 34,211 ticks / 9,378 HP against playing 22,745 / 4,627 (+50 % time, +103 % HP). Blade: 11,466 /
  1,724 against 9,562 / 887 (+20 % time, +94 % HP). The 30 % target is met on HP with both.
- The ignoring Gun bot's phase 3 runs 9,057 and 9,144 ticks on seeds 5 and 6 (no ward break: it focuses the amber
  Warden at 25 %). The playing Gun bot's phase 3 grew too (2,307 → 3,291 ticks on seed 5).
- `rift_cost=40` for the **playing** Gun bot on seed 5 (it was 0 in every playing fight before): one hit of 40, at
  the cap (40 % of the base HP), not over it.
- Its 120 s and more: the Gun fights playing run 122-133 s, past the owner's 1-2 minutes (Q29); the
  `test_twin_wardens_roles.gd` pace tests passed in this tree (they use their own scripted players).
