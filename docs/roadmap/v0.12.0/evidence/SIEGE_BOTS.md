# SIEGE_BOTS: does ignoring the Siege Engine's cover and Doom Shell cost clearly more than playing them?

- **Status:** RUN. **The expectation is MET for the Gun and NOT MET for the Blade** (see "Result"): the numbers are
  below, nothing was retuned.
- **Build:** the tree of the commit that adds this file (`v0.12.0 Step 9`; its parent is `99d6a022`) on `v0120-s9`,
  run before the commit was made; Godot `4.7.2` (`Godot_v4.7.2-stable_win64_console.exe`); Windows 11 Pro
  10.0.26200 (the owner's PC), debug native library built from this tree
- **Date:** 2026-11-15
- **Who ran it:** agent

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_siege_bots.gd -gexit
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. Exit code 0: 2 tests, 1
passing, 1 pending (the unmet line), 98 asserts.)

## What the bots do
`tests/unit/sim/test_siege_bots.gd`: the real compiled Siege Engine (2,250 HP, the data's numbers, **no floor
scaling**) in a 24 m walled room, a hero with the starting Gun or Blade and no items. The hero has its real max HP
(100; the siege's costs are shares of it) and is refilled every tick, so no fight ends early; `hp_lost` is the damage
it took. `shell`, `shock`, `doom`, `blast` are the HP lost to the Target Lock's shells, the Shockwaves under the cover
rule, the Doom Shells and the cart's blasts; `other` is everything else (turrets, mortars, barrages, rails, rocks,
adds, which neither bot dodges).
- **plays:** while a lock follows it, stands 3.8 m out from the Engine's edge and steps out once the circle locks;
  breaks a cart close to the Engine (the Gun from 8 m of the Engine's edge, out of the blast; the Blade within 4 m);
  hides behind the nearest boulder while a Shockwave under the cover rule winds up or a Doom Shell it did not stop
  comes. Otherwise holds its weapon's distance and attacks.
- **ignores:** holds its weapon's distance (Gun 4–6 m from the Engine's centre, Blade 1.2 m from its edge) and
  attacks.

## Raw output
```
SIEGEBOT| weapon=gun bot=plays seed=5 dead=true ticks=5698 seconds=95.0 max_hp=100 hp_lost=1594 biggest=50 shell=70 shock=0 doom=80 blast=0 other=1444 locks=5 boulders=2 shock_hits=0 shock_covered=0 doom_taken=2 doom_covered=0 carts=2 carts_broken=0 strips=0 shell_cost=35 shock_cost=0 doom_cost=40 blast_cost=0
SIEGEBOT| weapon=gun bot=ignores seed=5 dead=true ticks=8083 seconds=134.7 max_hp=100 hp_lost=2286 biggest=50 shell=70 shock=40 doom=40 blast=0 other=2136 locks=7 boulders=3 shock_hits=1 shock_covered=0 doom_taken=1 doom_covered=1 carts=2 carts_broken=0 strips=0 shell_cost=35 shock_cost=40 doom_cost=40 blast_cost=0
SIEGEBOT| weapon=gun bot=plays seed=6 dead=true ticks=5887 seconds=98.1 max_hp=100 hp_lost=1521 biggest=50 shell=35 shock=0 doom=40 blast=0 other=1446 locks=5 boulders=2 shock_hits=0 shock_covered=0 doom_taken=1 doom_covered=0 carts=2 carts_broken=0 strips=0 shell_cost=35 shock_cost=0 doom_cost=40 blast_cost=0
SIEGEBOT| weapon=gun bot=ignores seed=6 dead=true ticks=8117 seconds=135.3 max_hp=100 hp_lost=2565 biggest=50 shell=245 shock=0 doom=80 blast=0 other=2240 locks=7 boulders=3 shock_hits=0 shock_covered=0 doom_taken=2 doom_covered=0 carts=2 carts_broken=0 strips=0 shell_cost=35 shock_cost=0 doom_cost=40 blast_cost=0
SIEGEBOT| weapon=gun bot=plays seed=7 dead=true ticks=6168 seconds=102.8 max_hp=100 hp_lost=1495 biggest=40 shell=35 shock=0 doom=80 blast=0 other=1380 locks=5 boulders=2 shock_hits=0 shock_covered=0 doom_taken=2 doom_covered=0 carts=2 carts_broken=0 strips=0 shell_cost=35 shock_cost=0 doom_cost=40 blast_cost=0
SIEGEBOT| weapon=gun bot=ignores seed=7 dead=true ticks=8100 seconds=135.0 max_hp=100 hp_lost=2103 biggest=40 shell=105 shock=40 doom=40 blast=0 other=1918 locks=7 boulders=3 shock_hits=1 shock_covered=0 doom_taken=1 doom_covered=0 carts=2 carts_broken=0 strips=0 shell_cost=35 shock_cost=40 doom_cost=40 blast_cost=0
SIEGEBOT| weapon=gun over 3 seeds: plays { "ticks": 17753, "hp_lost": 4610, "shell": 140, "shock": 0, "doom": 200, "blast": 0, "other": 4270, "shock_hits": 0, "strips": 0 }, ignores { "ticks": 24300, "hp_lost": 6954, "shell": 420, "shock": 80, "doom": 160, "blast": 0, "other": 6294, "shock_hits": 2, "strips": 0 }
SIEGEBOT| weapon=blade bot=plays seed=5 dead=true ticks=3633 seconds=60.5 max_hp=100 hp_lost=518 biggest=38 shell=0 shock=30 doom=0 blast=0 other=488 locks=3 boulders=2 shock_hits=1 shock_covered=0 doom_taken=0 doom_covered=1 carts=2 carts_broken=0 strips=0 shell_cost=0 shock_cost=30 doom_cost=0 blast_cost=0
SIEGEBOT| weapon=blade bot=ignores seed=5 dead=true ticks=2806 seconds=46.8 max_hp=100 hp_lost=395 biggest=38 shell=26 shock=0 doom=30 blast=0 other=339 locks=2 boulders=0 shock_hits=0 shock_covered=0 doom_taken=1 doom_covered=0 carts=2 carts_broken=0 strips=0 shell_cost=26 shock_cost=0 doom_cost=30 blast_cost=0
SIEGEBOT| weapon=blade bot=plays seed=6 dead=true ticks=3036 seconds=50.6 max_hp=100 hp_lost=485 biggest=38 shell=26 shock=0 doom=30 blast=0 other=429 locks=2 boulders=1 shock_hits=0 shock_covered=0 doom_taken=1 doom_covered=0 carts=2 carts_broken=0 strips=0 shell_cost=26 shock_cost=0 doom_cost=30 blast_cost=0
SIEGEBOT| weapon=blade bot=ignores seed=6 dead=true ticks=2913 seconds=48.5 max_hp=100 hp_lost=413 biggest=38 shell=26 shock=0 doom=0 blast=0 other=387 locks=2 boulders=0 shock_hits=0 shock_covered=0 doom_taken=0 doom_covered=1 carts=2 carts_broken=0 strips=0 shell_cost=26 shock_cost=0 doom_cost=0 blast_cost=0
SIEGEBOT| weapon=blade bot=plays seed=7 dead=true ticks=3910 seconds=65.2 max_hp=100 hp_lost=644 biggest=38 shell=0 shock=0 doom=60 blast=0 other=584 locks=3 boulders=2 shock_hits=0 shock_covered=0 doom_taken=2 doom_covered=0 carts=2 carts_broken=0 strips=0 shell_cost=0 shock_cost=0 doom_cost=30 blast_cost=0
SIEGEBOT| weapon=blade bot=ignores seed=7 dead=true ticks=2778 seconds=46.3 max_hp=100 hp_lost=347 biggest=38 shell=26 shock=0 doom=30 blast=0 other=291 locks=2 boulders=0 shock_hits=0 shock_covered=0 doom_taken=1 doom_covered=0 carts=1 carts_broken=0 strips=0 shell_cost=26 shock_cost=0 doom_cost=30 blast_cost=0
SIEGEBOT| weapon=blade over 3 seeds: plays { "ticks": 10579, "hp_lost": 1647, "shell": 26, "shock": 30, "doom": 90, "blast": 0, "other": 1501, "shock_hits": 1, "strips": 0 }, ignores { "ticks": 8497, "hp_lost": 1155, "shell": 78, "shock": 0, "doom": 60, "blast": 0, "other": 1017, "shock_hits": 0, "strips": 0 }
    [Pending]:  NOT MET, ignoring the siege costs at least 30 % more HP: blade: the siege cost the bot that ignores it 138 HP, the one that plays it 146 HP
```

## Result
| Line | Gun | Blade |
|---|---|---|
| Siege HP lost (shell + shock + doom + blast), plays / ignores, 3 seeds | 340 / 700 | 146 / 138 |
| All HP lost, plays / ignores | 4,610 / 6,954 | 1,647 / 1,155 |
| Fight length, plays / ignores (ticks) | 17,753 / 24,300 | 10,579 / 8,497 |
| Biggest single hit of the siege (max HP 100) | 40 | 30 |
| Expectation: ignoring costs ≥ 30 % more siege HP | **met** (2.06×) | **NOT MET** (0.95×) |

- **No single mistake kills from full:** every shell, Shockwave and Doom Shell cost at most 40 of 100 (the Blade's
  starting armour takes them to 26, 30, 30); no tick killed a hero at full HP.
- **Read from the numbers, not traced:**
  - **No bot ever broke a cart** (`carts_broken=0` in all 12 fights), so the armour strip was never seen in a whole
    fight and the bots' "plays" never exercised the cart's best answer. The unit tests prove the cart's three
    outcomes; why the bots' shots and swings did not break it was not traced.
  - The Blade kills the unscaled Engine in 46–65 s, so its fights see only 2–3 locks and 1–2 carts; the Blade that
    ignores stands at the Engine's edge, where no boulder fits (the gap to the Engine's body), so it gets no boulders
    at all and the Shockwave mostly waits for one. Playing the locks costs the Blade time at the Engine (10,579
    ticks against 8,497) and so more of everything else.
  - The Gun that ignores takes 37 % longer, mostly through more locks (7 against 5) and HP lost to everything else.
- **Not measured:** the fight at floor-3 scaling.

## After step 12 (2026-11-15)
Enemies no longer deny a boulder (`v0.12.0 Step 12`, built on `d456a21c` in `wt-x12`, the same machine and Godot).
Same command's file, run on the step's tree before its commit inside a 21-file GUT run (that run exited 1 for three
tests in other files, fixed and re-run after; `test_siege_bots.gd` itself: 2 tests, 1 passing, 1 pending, no
failure). Every `SIEGEBOT|` line and the pending line are **identical** to the raw output above; why no bot fight
changed was not traced. Nothing was retuned. The Result table stands.
