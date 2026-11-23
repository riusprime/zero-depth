# WARLORD_BOTS: does playing the Warlord's charge, banner and duel win clearly sooner, or ignoring them cost clearly more?

- **Status:** RUN. **Met with the Blade; NOT MET with the Gun** (see "Result"): the numbers are below, nothing was
  retuned.
- **Build:** the tree of the commit that adds this file (`v0.12.0 Step 8`; its parent is `a1754dba`) on `v0120-l8`,
  run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200 (the owner's
  PC), debug native library built from this tree
- **Date:** 2026-11-15
- **Who ran it:** agent

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -ginclude_subdirs -gexit -gtest=res://tests/unit/sim/test_warlord_bots.gd
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. Exit code 0; 3 tests, 2
passing, 1 pending: the Gun's line below.)

## What the bots do
`tests/unit/sim/test_warlord_bots.gd`: the real compiled Warlord (1,750 HP, the data's numbers, **no floor scaling**)
in a 24 m walled room, a hero with the starting Gun or Blade and no items. The hero has its real max HP (100) and is
refilled every tick, so no fight ends early; `hp_lost` is the damage it took. `burst`, `fence` and `recall` are the
HP lost to the charge's end burst, the cage's fence and the recall; `other` is everything else. `front` is the damage
dealt to the Warlord from its front arc while its cage stood (the shield is down only then). Neither bot dashes.
- **plays:** steps out of a charge's end circle while it winds up and until it bursts; walks into a standing banner;
  in the cage keeps 1.2 m off the fence and, from 1.5 s before the recall's warning, stands between the centre zone
  and the fence. Otherwise holds its weapon's distance (Gun 4–6 m, Blade 1.2 m from the edge) and attacks.
- **ignores:** holds its weapon's distance and attacks; walks out of a banner it stands in; in the cage backs away
  from the Warlord (into the fence) and stands in the centre through the recall's warning.

## Output (raw)
```
WARLORDBOT| weapon=gun bot=plays seed=5 dead=true ticks=9025 seconds=150.4 max_hp=100 hp_lost=1162 biggest=32 burst=0 fence=0 recall=0 other=1162 banners=1 charge_falls=0 seconds_in_banner=15.6 banner_lost=116 duels=1 front=370 fence_hits=0 fence_cost=0 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=gun bot=ignores seed=5 dead=true ticks=9100 seconds=151.7 max_hp=100 hp_lost=1150 biggest=32 burst=0 fence=200 recall=0 other=950 banners=1 charge_falls=0 seconds_in_banner=15.6 banner_lost=116 duels=1 front=327 fence_hits=20 fence_cost=10 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=gun bot=plays seed=6 dead=true ticks=6981 seconds=116.3 max_hp=100 hp_lost=851 biggest=32 burst=0 fence=0 recall=0 other=851 banners=1 charge_falls=0 seconds_in_banner=16.4 banner_lost=148 duels=1 front=245 fence_hits=0 fence_cost=0 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=gun bot=ignores seed=6 dead=true ticks=7112 seconds=118.5 max_hp=100 hp_lost=879 biggest=32 burst=0 fence=150 recall=0 other=729 banners=1 charge_falls=0 seconds_in_banner=16.4 banner_lost=148 duels=1 front=224 fence_hits=15 fence_cost=10 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=gun bot=plays seed=7 dead=true ticks=6229 seconds=103.8 max_hp=100 hp_lost=893 biggest=32 burst=0 fence=0 recall=0 other=893 banners=1 charge_falls=0 seconds_in_banner=16.5 banner_lost=116 duels=1 front=415 fence_hits=0 fence_cost=0 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=gun bot=ignores seed=7 dead=true ticks=6298 seconds=105.0 max_hp=100 hp_lost=947 biggest=40 burst=0 fence=200 recall=40 other=707 banners=1 charge_falls=0 seconds_in_banner=16.5 banner_lost=116 duels=1 front=354 fence_hits=20 fence_cost=10 recall_cost=40 burst_cost=0
WARLORDBOT| weapon=gun over 3 seeds: plays { "ticks": 22235, "hp_lost": 2906, "burst": 0, "fence": 0, "recall": 0, "other": 2906, "in_banner": 2908, "front": 1030 }, ignores { "ticks": 22510, "hp_lost": 2976, "burst": 0, "fence": 550, "recall": 40, "other": 2386, "in_banner": 2908, "front": 905 }
WARLORDBOT| weapon=blade bot=plays seed=5 dead=true ticks=4052 seconds=67.5 max_hp=100 hp_lost=372 biggest=24 burst=0 fence=0 recall=0 other=372 banners=1 charge_falls=0 seconds_in_banner=2.7 banner_lost=44 duels=1 front=258 fence_hits=0 fence_cost=0 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=blade bot=ignores seed=5 dead=true ticks=4550 seconds=75.8 max_hp=100 hp_lost=382 biggest=24 burst=0 fence=32 recall=0 other=350 banners=1 charge_falls=0 seconds_in_banner=7.4 banner_lost=18 duels=1 front=106 fence_hits=4 fence_cost=8 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=blade bot=plays seed=6 dead=true ticks=2944 seconds=49.1 max_hp=100 hp_lost=304 biggest=24 burst=0 fence=0 recall=0 other=304 banners=1 charge_falls=0 seconds_in_banner=3.4 banner_lost=44 duels=1 front=23 fence_hits=0 fence_cost=0 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=blade bot=ignores seed=6 dead=true ticks=3862 seconds=64.4 max_hp=100 hp_lost=380 biggest=24 burst=0 fence=24 recall=0 other=356 banners=1 charge_falls=0 seconds_in_banner=8.2 banner_lost=0 duels=1 front=87 fence_hits=3 fence_cost=8 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=blade bot=plays seed=7 dead=true ticks=3446 seconds=57.4 max_hp=100 hp_lost=300 biggest=24 burst=0 fence=0 recall=0 other=300 banners=1 charge_falls=0 seconds_in_banner=4.7 banner_lost=0 duels=1 front=36 fence_hits=0 fence_cost=0 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=blade bot=ignores seed=7 dead=true ticks=4319 seconds=72.0 max_hp=100 hp_lost=476 biggest=38 burst=0 fence=16 recall=0 other=460 banners=1 charge_falls=0 seconds_in_banner=9.2 banner_lost=72 duels=1 front=22 fence_hits=2 fence_cost=8 recall_cost=0 burst_cost=0
WARLORDBOT| weapon=blade over 3 seeds: plays { "ticks": 10442, "hp_lost": 976, "burst": 0, "fence": 0, "recall": 0, "other": 976, "in_banner": 652, "front": 317 }, ignores { "ticks": 12731, "hp_lost": 1238, "burst": 0, "fence": 72, "recall": 0, "other": 1166, "in_banner": 1492, "front": 215 }
    [Pending]:  NOT MET, playing wins at least 10 % sooner or ignoring costs at least 30 % more HP: gun: playing 2906 HP in 22235 ticks, ignoring 2976 HP in 22510 ticks
WARLORDBOT| phase=1 big_mechanic_seconds_per_minute=0.0 begun=0
WARLORDBOT| phase=2 big_mechanic_seconds_per_minute=35.0 begun=5
WARLORDBOT| phase=3 big_mechanic_seconds_per_minute=19.4 begun=5
```
The last three lines: one scripted 3-minute fight per phase (the "plays" Gun bot, seed 5, the Warlord's HP held
inside the phase): the seconds a minute a banner or a duel runs, its cast included, and how many began.

## Result
- **Blade: met** (sooner): over 3 seeds "plays" took 10,442 ticks, "ignores" 12,731 (18 % longer), and lost 1,238 HP
  against 976 (27 % more; under the 30 % line on its own).
- **Gun: NOT MET.** 22,235 against 22,510 ticks (1 % apart) and 2,906 against 2,976 HP (2 % apart). Each Gun fight
  saw one banner and one duel; the fence cost "ignores" 150–200 HP a duel, but "plays" took more of everything else.
- In every fight the charge's burst cost 0 to both bots (`burst_cost=0`), and the Gun bots stood the same seconds
  in the banner whether they played or ignored it (15.6 / 16.4 / 16.5 s): their "ignores" walk-out did not change
  where they stood. Neither was traced further.
- The largest single hit of the new mechanics: fence 10 (10 %), recall 40 (40 %). The charge's burst is the
  charge's own 50 damage (none landed here).

## Owner-only
Whether the fight feels right, how often a first meeting is lost: `OWNER ONLY`.
