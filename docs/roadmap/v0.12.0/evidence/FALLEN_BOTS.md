# FALLEN_BOTS: is ignoring The Fallen's remembered mechanics clearly slower or clearly costlier than playing them?

- **Status:** RUN. **NOT MET with either weapon** (see "Result"): the numbers are below, nothing was retuned.
- **Build:** the tree of the commit that adds this file (`v0.12.0 Step 7a`; its parent is `2d1d6339`) on
  `v0120-h7`, run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200
  (the owner's PC, i7-10700K), debug native library built from this tree. Another agent ran Godot tests in another
  worktree at the same time: no timing is taken from this run.
- **Date:** 2026-11-15
- **Who ran it:** agent

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_fallen_bots.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_fallen_remembered.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. The bots: exit code 0; 2
tests, 1 passing, 1 pending, the line below. The second command prints the scripted fights' lines.)

## What the bots do
`tests/unit/sim/test_fallen_bots.gd`: the real final arena (FallenLab: the run's world jumped to its last body, as
the dev panel and the Playground do; its mimic windows as shipped), the run having killed the Clockwork Judge, the
Tidecaller, the Gatekeeper and the Twin Wardens (the pool holds all four), a hero with the starting Gun or Blade and
no cards. The hero has its real max HP (160; the mechanics' costs are shares of it) and is refilled every tick, so no
fight ends early; `hp_lost` is the damage it took. `rip`, `quake` and `shade` are the HP lost to Riptide, the quake
pulses and the ward's shade (its touch and its burst); `other` is everything else (The Fallen's own attacks, which
neither bot dodges). `stuns` counts pillar stuns and ward breaks, `orbs` the hour orbs taken, `slowed_s` the seconds
the weapon was slowed, `busy` the seconds of each of the first three minutes a remembered mechanic or a mimic
window ran.
- **plays:** in a Time Wave walks to the nearest hour orb; in a row of Riptide into the safe strip; among the quake
  pillars to the spot behind the pillar nearest it from The Fallen; under the ward onto The Fallen's line from the
  shade, 3 m past it, until the aim locks. Otherwise holds its weapon's distance and attacks.
- **ignores:** holds its weapon's distance (Gun 4–6 m, Blade 1.2 m from the body's edge) and attacks.

## Raw output
```
FALLENBOT| weapon=gun bot=plays seed=5 dead=true ticks=7231 seconds=120.5 max_hp=160 hp_lost=1903 biggest=54 rip=0 quake=45 shade=0 other=1858 mechanics=3 time=1 riptide=1 quake_n=1 ward=0 orbs=3 stuns=1 breaks=0 shatters=1 slowed_s=5.4 busy=[39.0, 27.8, 0.5]
FALLENBOT| weapon=gun bot=ignores seed=5 dead=true ticks=7388 seconds=123.1 max_hp=160 hp_lost=2138 biggest=54 rip=96 quake=18 shade=80 other=1944 mechanics=3 time=0 riptide=1 quake_n=1 ward=1 orbs=0 stuns=0 breaks=0 shatters=0 slowed_s=0.0 busy=[37.7, 33.9, 0.0]
FALLENBOT| weapon=gun bot=plays seed=6 dead=true ticks=7141 seconds=119.0 max_hp=160 hp_lost=1989 biggest=54 rip=0 quake=45 shade=0 other=1944 mechanics=3 time=1 riptide=0 quake_n=1 ward=1 orbs=3 stuns=2 breaks=1 shatters=1 slowed_s=5.7 busy=[35.9, 30.1, 0.0]
FALLENBOT| weapon=gun bot=ignores seed=6 dead=true ticks=7722 seconds=128.7 max_hp=160 hp_lost=1961 biggest=48 rip=96 quake=0 shade=80 other=1785 mechanics=4 time=1 riptide=1 quake_n=1 ward=1 orbs=0 stuns=0 breaks=0 shatters=0 slowed_s=12.0 busy=[37.6, 39.7, 8.1]
FALLENBOT| weapon=gun bot=plays seed=7 dead=true ticks=7610 seconds=126.8 max_hp=160 hp_lost=2230 biggest=54 rip=0 quake=36 shade=40 other=2154 mechanics=3 time=1 riptide=0 quake_n=1 ward=1 orbs=3 stuns=3 breaks=1 shatters=3 slowed_s=4.5 busy=[38.8, 26.5, 6.8]
FALLENBOT| weapon=gun bot=ignores seed=7 dead=true ticks=7546 seconds=125.8 max_hp=160 hp_lost=2039 biggest=48 rip=96 quake=18 shade=0 other=1925 mechanics=3 time=1 riptide=1 quake_n=1 ward=0 orbs=0 stuns=0 breaks=0 shatters=0 slowed_s=12.0 busy=[38.4, 31.9, 0.8]
FALLENBOT| weapon=gun over 3 seeds: plays { "ticks": 21982, "hp_lost": 6122, "rip": 0, "quake": 126, "shade": 40, "other": 5956, "stuns": 6, "breaks": 2, "orbs": 9 }, ignores { "ticks": 22656, "hp_lost": 6138, "rip": 288, "quake": 36, "shade": 160, "other": 5654, "stuns": 0, "breaks": 0, "orbs": 0 }
FALLENBOT| weapon=blade bot=plays seed=5 dead=true ticks=6265 seconds=104.4 max_hp=160 hp_lost=2072 biggest=36 rip=72 quake=0 shade=30 other=1970 mechanics=3 time=1 riptide=1 quake_n=0 ward=1 orbs=3 stuns=1 breaks=1 shatters=0 slowed_s=4.7 busy=[37.9, 20.4, 0.0]
FALLENBOT| weapon=blade bot=ignores seed=5 dead=true ticks=6327 seconds=105.5 max_hp=160 hp_lost=1892 biggest=36 rip=36 quake=0 shade=30 other=1826 mechanics=3 time=1 riptide=1 quake_n=0 ward=1 orbs=0 stuns=1 breaks=1 shatters=0 slowed_s=12.0 busy=[38.0, 22.2, 0.0]
FALLENBOT| weapon=blade bot=plays seed=6 dead=true ticks=6397 seconds=106.6 max_hp=160 hp_lost=1907 biggest=36 rip=36 quake=45 shade=0 other=1826 mechanics=3 time=1 riptide=1 quake_n=1 ward=0 orbs=3 stuns=0 breaks=0 shatters=0 slowed_s=4.2 busy=[37.4, 23.6, 0.0]
FALLENBOT| weapon=blade bot=ignores seed=6 dead=true ticks=6817 seconds=113.6 max_hp=160 hp_lost=2042 biggest=36 rip=0 quake=0 shade=0 other=2042 mechanics=3 time=2 riptide=0 quake_n=1 ward=0 orbs=1 stuns=0 breaks=0 shatters=0 slowed_s=24.0 busy=[41.0, 26.8, 0.0]
FALLENBOT| weapon=blade bot=plays seed=7 dead=true ticks=6093 seconds=101.6 max_hp=160 hp_lost=1619 biggest=36 rip=0 quake=45 shade=0 other=1574 mechanics=3 time=1 riptide=0 quake_n=1 ward=1 orbs=3 stuns=1 breaks=1 shatters=0 slowed_s=4.2 busy=[34.5, 23.6, 0.0]
FALLENBOT| weapon=blade bot=ignores seed=7 dead=true ticks=6703 seconds=111.7 max_hp=160 hp_lost=1826 biggest=36 rip=72 quake=0 shade=0 other=1754 mechanics=3 time=2 riptide=1 quake_n=0 ward=0 orbs=1 stuns=0 breaks=0 shatters=0 slowed_s=24.1 busy=[39.1, 23.0, 0.0]
FALLENBOT| weapon=blade over 3 seeds: plays { "ticks": 18755, "hp_lost": 5598, "rip": 108, "quake": 90, "shade": 30, "other": 5370, "stuns": 2, "breaks": 2, "orbs": 9 }, ignores { "ticks": 19847, "hp_lost": 5760, "rip": 108, "quake": 0, "shade": 30, "other": 5622, "stuns": 1, "breaks": 1, "orbs": 2 }
    [Pending]:  NOT MET, ignoring is at least 10 % slower or costs at least 30 % more HP: gun: ignoring took 22656 ticks and lost 6138 HP (484 to the mechanics), playing 21982 ticks, 6122 HP (166); blade: ignoring took 19847 ticks and lost 5760 HP (138 to the mechanics), playing 18755 ticks, 5598 HP (228)
Tests                 2
Passing Tests         1
Risky/Pending         1
Asserts              38
```
The scripted fights of `test_fallen_remembered.gd` (no bot: the hero walks a small circle round the centre, held
invulnerable; the world's own hits take The Fallen to 65 % at 50 s and to 32 % at 110 s; windows as shipped; the
pool of all four):
```
FALLEN rhythm: mechanics [cast, end, kind, gate] [[1414, 2404, 3, 0], [3247, 3895, 2, 1], [5905, 6895, 3, 0], [7744, 8291, 4, 1], [10296, 11286, 3, 0], [13315, 13963, 2, 0]]; windows [warn, close] [[750, 1176], [2584, 3010], [4075, 4501], [5275, 5701], [7075, 7501], [8471, 8897], [9671, 10097], [11466, 11892], [12666, 13092], [14143, -1]]
FALLEN per minute: seconds a remembered mechanic or a mimic window runs [38.6, 37.7, 36.7]
FALLEN pace floor: died 3660 ticks after its rise (floor 3600)
```
(kinds: 1 Time Wave, 2 Riptide, 3 quake pillars, 4 the ward; ticks from the world's start; a window's close is its
first tick off.)

## Target bands
| Metric | Target | Source |
|---|---|---|
| Ignoring vs playing | ignoring at least 10 % slower, or at least 30 % more HP lost in all and to the mechanics | step 7a brief ("clearly slower and/or clearly more HP") |
| One hit of a remembered mechanic | at most 40 % of max HP | owner B3, step 7a brief item 4 |
| A body's time | 60–180 s (the pace) | SIM_CONTRACTS §10i |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Gun: time, ignores / plays | 22,656 / 21,982 ticks (+3.1 %) | **no** |
| Gun: HP lost in all, ignores / plays | 6,138 / 6,122 (+0.3 %) | **no** |
| Gun: HP lost to the mechanics, ignores / plays | 484 / 166 (2.9 times) | yes, but the whole is not |
| Blade: time, ignores / plays | 19,847 / 18,755 ticks (+5.8 %) | **no** |
| Blade: HP lost in all, ignores / plays | 5,760 / 5,598 (+2.9 %) | **no** |
| Blade: HP lost to the mechanics, ignores / plays | 138 / 228 (less) | **no** |
| Biggest single tick, any bot | 54 of 160 (34 %; The Fallen's own attacks: `other`) | yes |
| Fight length, every fight | 101.6–128.7 s | yes |
| Scripted 4-minute fight: a mechanic in a window or its warning | never (checked every tick) | yes |
| Scripted fight: calm between a mechanic and a window, either way | at least 180 ticks each time | yes |
| Scripted 3-minute fight: seconds a minute a mechanic or a window runs | 38.6, 37.7, 36.7 | — (no band set) |
| The Fallen hit for 999,999 every tick: its death after its rise | 3,660 ticks (floor 3,600) | yes |

## Interpretation
The expectation is **not met**: over 3 seeds the bot that ignores the mechanics is 3 % (Gun) and 6 % (Blade)
slower and loses 0.3 % and 2.9 % more HP. Why, from these numbers only (not traced further):
- **Three mechanics a fight.** The pace holds the body to about two minutes; the first comes after 12 s and its
  first mimic window, then the two HP gates. Each costs little next to The Fallen's own attacks, which neither bot
  dodges: `other` is 91–100 % of the HP lost (10 to 14 times the hero's max HP a fight). The mechanics' share is what
  the "plays" bot avoids, and it is small.
- **Playing the quake costs HP.** Standing behind a pillar is standing inside its 7 m ring: the bot that plays takes
  the pulses (Gun 126, Blade 90), the bot that ignores mostly does not. That is the brief's trade (stand by a pillar
  to earn a stun), but these bots get it without making it pay in time: one stun (3 s at ×1.5) does not shorten a
  fight the rate cap holds.
- **The ward is broken by chance too** (a likely reason, not traced). The shade starts at the edge across the room's
  centre from the hero, so when The Fallen stands near the centre the hero is on its line already: the Blade bot that
  ignores broke it once.
- **The Time Wave costs time, not HP.** The bot that ignores the orbs keeps its weapon slowed 12–24 s a fight
  (`slowed_s`), but the rate cap and the mimic windows' nerf hold the body's death near its floor, so the slow
  barely shows in the fight's length.
- **Busy time.** In the bots' fights a mechanic or a window runs 34.5–41.0 s of the first minute and 20.4–39.7 s
  of the second (`busy`); the third minute is the fight's end.
- **One at a time holds, but the room is seldom quiet.** In the scripted fights a remembered mechanic or a mimic
  window runs about 37–39 s of every minute: never two at once, always 3 s apart, but the windows alone are 7.1 s
  of every 20 s and a quake is 16.5 s with its cast. Whether that is the rhythm the owner asked for is `OWNER ONLY`.
The tuning (more mechanics, a costlier miss, a pillar ring that leaves a safe spot behind it, a ward the shade's start
cannot break by itself) is the lead's and the owner's call. `OWNER ONLY`: whether the fight is fun, readable and
"difficult but learnable".

## After step 7b (2026-11-15): the theft

Build: worktree `v0120-h7b` on `b1548436` plus the uncommitted step 7b change (Windows, owner's PC; no timing taken).
Command (one Godot process with the step's other sim and save tests):

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<...>,res://tests/unit/sim/test_fallen_bots.gd,<...> -gexit
```

The existing lines (no cards) are unchanged: the sums are the same as above (Gun plays 21982 ticks, ignores 22656;
Blade plays 18755, ignores 19847), and the `pending` is the same. A new variant, the bot that plays, holding four
wand cards (test_nemesis's Gun and Blade builds), raw:

```
FALLENBOT| theft weapon=gun bot=plays seed=5 dead=true seconds=71.9 taken=0 returned=0 mark_hits=0 seconds_without_a_card=0.0 held_at_end=0
FALLENBOT| theft weapon=gun bot=plays seed=6 dead=true seconds=73.0 taken=0 returned=0 mark_hits=0 seconds_without_a_card=0.0 held_at_end=0
FALLENBOT| theft weapon=gun bot=plays seed=7 dead=true seconds=98.6 taken=2 returned=2 mark_hits=4 seconds_without_a_card=33.0 held_at_end=0
FALLENBOT| theft weapon=blade bot=plays seed=5 dead=true seconds=88.3 taken=1 returned=1 mark_hits=0 seconds_without_a_card=5.0 held_at_end=0
FALLENBOT| theft weapon=blade bot=plays seed=6 dead=true seconds=80.7 taken=0 returned=0 mark_hits=0 seconds_without_a_card=0.0 held_at_end=0
FALLENBOT| theft weapon=blade bot=plays seed=7 dead=true seconds=82.5 taken=0 returned=0 mark_hits=0 seconds_without_a_card=0.0 held_at_end=0
```

- **The theft seldom gets its turn in these fights.** In 4 of 6 fights no card was taken: the theft waits behind the
  remembered mechanic of the same HP gate, its calm and the mimic windows, and these bots kill The Fallen in 72–99 s,
  so by the time the rhythm is free the fight is over (a likely reason, not traced tick by tick). The variant keeps
  this visible as a `pending` ("NOT MET, a card is taken in every fight").
- **Every card came back.** `held_at_end` is 0 in every fight; with these bots the cards come back by The Fallen's
  death (Blade seed 5: 0 mark hits), or after a few hits on its back (Gun seed 7: 4 counted hits, 33 s with a card
  held). The bots never try to get behind it.
- **The pace's scripted fights** (`tests/unit/sim/test_final_pace.gd`, the same run): the strong Blade build's
  Fallen now lasts 229.4 s and 225.6 s (seeds 21, 22; the test's ceiling is 185 s) and 213.3 s on the mean against
  the base build's 140.0 s: the theft takes its best cards and the scripted hero never wins them back. FAILED, not
  retuned.
Nothing was retuned. `OWNER ONLY`: whether the theft is felt, learnable and fair.
