# LENS_BOTS: is ignoring the Hive Lens's drones and Lattice clearly slower or clearly costlier than playing them?

- **Status:** RUN. **NOT MET with the Gun nor with the Blade** (see "Result"): the bot that ignores is faster with
  both weapons and loses less HP (Gun) or about the same (Blade). The numbers are below; nothing was retuned.
- **Build:** the tree of the commit that adds this file (`v0.12.0 Step 11`; its parent is `8c547d6a`) on
  `v0120-n11`, run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200 (the
  owner's PC), debug native library built from this tree (`scripts/native/ensure.sh`)
- **Date:** 2026-11-15
- **Who ran it:** agent

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_lens_bots.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. Exit code 0; 2 tests, 1
passing, 1 pending: the line under "Result".)

## What the bots do
`tests/unit/sim/test_lens_bots.gd`: the real compiled Hive Lens (2,063 HP, the data's numbers, **no floor scaling**)
in a 24 m walled room, a hero with the starting Gun or Blade and no items. The hero has its real max HP (100; a
strand's cost is a share of it) and is refilled every tick, so no fight ends early; `hp_lost` is the damage it took.
`strand` and `glass` are the HP lost to the Lattice's strands and to the burnt glass; `other` is everything else
(the Lens's older attacks and the drones' orbs, which neither bot dodges). `cuts` are drones the Lens's own Focus
Beam cut down; `fed_seconds` the time the Lens took less for its drones.
- **plays:** the Gun shoots any drone alive first; the Blade goes for the web's drones while a web stands (they hold
  their orbit then; outside it they keep away from the hero). Through a Lattice it walks to the spot nearby farthest
  from every strand and strip (the gap it opened, or the cell it stands in as the web turns), and off the burnt glass.
  Otherwise it holds its weapon's distance and attacks the Lens.
- **ignores:** holds its weapon's distance (Gun 4–6 m, Blade 1.2 m from the boss's edge) and attacks only the Lens.
- Neither sets up a beam cut on purpose (no bot stands with a drone between itself and the Lens); the cuts are the
  ones that happened.

## Output (raw)
```
LENSBOT| weapon=gun bot=plays seed=5 dead=true ticks=7024 seconds=117.1 max_hp=100 hp_lost=1160 strand=0 glass=0 other=1160 strand_hits=0 strand_cost=0 lattices=2 cuts=0 fed_seconds=47.2
LENSBOT| weapon=gun bot=ignores seed=5 dead=true ticks=6072 seconds=101.2 max_hp=100 hp_lost=914 strand=0 glass=0 other=914 strand_hits=0 strand_cost=0 lattices=2 cuts=0 fed_seconds=77.3
LENSBOT| weapon=gun bot=plays seed=6 dead=true ticks=6871 seconds=114.5 max_hp=100 hp_lost=1028 strand=0 glass=0 other=1028 strand_hits=0 strand_cost=0 lattices=2 cuts=0 fed_seconds=45.2
LENSBOT| weapon=gun bot=ignores seed=6 dead=true ticks=6138 seconds=102.3 max_hp=100 hp_lost=914 strand=40 glass=72 other=802 strand_hits=2 strand_cost=20 lattices=2 cuts=0 fed_seconds=71.0
LENSBOT| weapon=gun bot=plays seed=7 dead=true ticks=6902 seconds=115.0 max_hp=100 hp_lost=1002 strand=0 glass=12 other=990 strand_hits=0 strand_cost=0 lattices=2 cuts=0 fed_seconds=60.2
LENSBOT| weapon=gun bot=ignores seed=7 dead=true ticks=5934 seconds=98.9 max_hp=100 hp_lost=964 strand=40 glass=72 other=852 strand_hits=2 strand_cost=20 lattices=2 cuts=0 fed_seconds=71.2
LENSBOT| weapon=gun over 3 seeds: plays { "ticks": 20797, "hp_lost": 3190, "strand": 0, "glass": 12, "other": 3178, "strand_hits": 0, "cuts": 0, "fed_ticks": 9154 }, ignores { "ticks": 18144, "hp_lost": 2792, "strand": 80, "glass": 144, "other": 2568, "strand_hits": 4, "cuts": 0, "fed_ticks": 13175 }
LENSBOT| weapon=blade bot=plays seed=5 dead=true ticks=5062 seconds=84.4 max_hp=100 hp_lost=423 strand=0 glass=0 other=423 strand_hits=0 strand_cost=0 lattices=2 cuts=0 fed_seconds=65.7
LENSBOT| weapon=blade bot=ignores seed=5 dead=true ticks=3779 seconds=63.0 max_hp=100 hp_lost=494 strand=300 glass=0 other=194 strand_hits=20 strand_cost=15 lattices=2 cuts=0 fed_seconds=44.3
LENSBOT| weapon=blade bot=plays seed=6 dead=true ticks=4373 seconds=72.9 max_hp=100 hp_lost=377 strand=15 glass=6 other=356 strand_hits=1 strand_cost=15 lattices=2 cuts=1 fed_seconds=52.6
LENSBOT| weapon=blade bot=ignores seed=6 dead=true ticks=2984 seconds=49.7 max_hp=100 hp_lost=248 strand=120 glass=0 other=128 strand_hits=8 strand_cost=15 lattices=2 cuts=1 fed_seconds=33.2
LENSBOT| weapon=blade bot=plays seed=7 dead=true ticks=5072 seconds=84.5 max_hp=100 hp_lost=379 strand=0 glass=12 other=367 strand_hits=0 strand_cost=0 lattices=2 cuts=1 fed_seconds=66.4
LENSBOT| weapon=blade bot=ignores seed=7 dead=true ticks=3632 seconds=60.5 max_hp=100 hp_lost=418 strand=270 glass=0 other=148 strand_hits=18 strand_cost=15 lattices=2 cuts=0 fed_seconds=42.4
LENSBOT| weapon=blade over 3 seeds: plays { "ticks": 14507, "hp_lost": 1179, "strand": 15, "glass": 18, "other": 1146, "strand_hits": 1, "cuts": 2, "fed_ticks": 11086 }, ignores { "ticks": 10395, "hp_lost": 1160, "strand": 690, "glass": 0, "other": 470, "strand_hits": 46, "cuts": 1, "fed_ticks": 7196 }
[Pending]: NOT MET, ignoring is 20 % slower or costs 30 % more HP: gun: ignoring took 18144 ticks and 2792 HP, playing 20797 ticks and 3190 HP; blade: ignoring took 10395 ticks and 1160 HP, playing 14507 ticks and 1179 HP
```

## The rhythm: seconds a minute a big mechanic runs
`tests/unit/sim/test_lens_lattice.gd` `test_the_lattice_and_the_gaze_never_meet_over_long_fights`: the real fight
(nothing hushed), the hero standing still and too tough to die, the boss's HP held in one phase, 3 minutes per phase,
seed 5. A big mechanic runs while a Lattice is cast or its web stands, or while the Gaze winds up or burns. From a
batch run of the Hive Lens's sim tests on the final sim tree (`-gtest=` with `test_lens_lattice.gd` among 14 files):
`test_lens_lattice.gd` 21 of 21 passed; the batch's one failure was `test_bosses_2.gd` (a strand hit the readability
check did not know yet, fixed in `tests/support/readable_cause.gd`; that file then 23 of 23 with
`test_readable_cause.gd`, exit code 0).
```
LENSRHYTHM| phase=1 minutes=3 lattice_s=0.0 gaze_s=78.0 big_s_per_min=26.0 lattices=0 gazes=6
LENSRHYTHM| phase=2 minutes=3 lattice_s=48.1 gaze_s=26.6 big_s_per_min=24.9 lattices=4 gazes=2
LENSRHYTHM| phase=3 minutes=3 lattice_s=48.0 gaze_s=38.6 big_s_per_min=28.9 lattices=4 gazes=3
```
In those runs the two never overlapped and every start was at least 3 s after the other ended (asserted).

## Result
- **Expectation:** ignoring the drones and the Lattice is clearly slower (here: at least 20 % more ticks) and/or
  costs clearly more HP (at least 30 % more). **NOT MET with either weapon.**
- **Gun:** ignoring took 18,144 ticks and 2,792 HP; playing 20,797 ticks and 3,190 HP. The bot that ignores is 13 %
  faster and loses 12 % less. Shooting the drones first costs more time than their 15 % a drone saves; the strands
  cost the bot that ignores 40 HP in two of three fights (two touches).
- **Blade:** ignoring took 10,395 ticks and 1,160 HP; playing 14,507 ticks and 1,179 HP. The bot that ignores is 28 %
  faster and loses about the same; it takes 690 HP from 46 strand touches (15 HP each after armour), the bot that
  plays 15. So the web hurts the Blade that walks through it, but its 10 s each 45 s are not enough to make ignoring
  it costlier in all.
- **Beam cuts:** 0 with the Gun, 1–2 in three fights with the Blade: a bot that does not set up the line seldom gets
  one. Whether players do is for the playtest.
- Not traced: why the Gun that plays is fed 45–60 s of a 115 s fight (the drones keep away from it and are sent back
  12 s after the last dies; the share of its shots that miss them was not measured).
- **For the owner** (`OWNER ONLY`): whether the fight is "difficult and memorable"; whether the web reads and is
  worth opening a gap in. The tuning is the lead's and the owner's call.
