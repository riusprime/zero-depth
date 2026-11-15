# FOUNDRY_BOTS: is ignoring the Foundry's forge clearly slower and clearly costlier than playing it?

- **Status:** RUN. **Met with the Gun; NOT MET with the Blade** (see "Result"): the numbers are below, nothing was
  retuned.
- **Build:** the tree of the commit that adds this file (`v0.12.0 Step 10`; its parent is `c6299738`) on
  `v0120-f10`, run before the commit was made; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200
  (the owner's PC, i7-10700K), debug native library built from this tree
- **Date:** 2026-11-15
- **Who ran it:** agent

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/unit/sim/test_foundry_bots.gd
```
(`godot` = `Godot_v4.7.2-stable_win64_console.exe`; `APPDATA` pointed at `build/appdata`. Exit code 0; 2 tests, 1
passing, 1 pending: the Blade's line below.)

## What the bots do
`tests/unit/sim/test_foundry_bots.gd`: the real compiled Foundry (2,375 HP, the data's numbers, **no floor scaling**)
in a 24 m walled room, a hero with the starting Gun or Blade and no items. The hero has its real max HP (100; the
forge's costs are shares of it) and is refilled every tick, so no fight ends early; `hp_lost` is the damage it took.
`over` and `scald` are the HP lost to Overpressure and to the scald's burn; `other` is everything else (the Foundry's
older attacks, its lava and pools, the drones' bombs, which neither bot dodges). `biggest` is the most lost in one
tick from anything (50 = the existing Vent Blast's 50 damage on a 100 HP hero); `forge_biggest` the largest single
step of the forge's own.
- **plays:** while the Foundry is plated, stands right by it (the drones throw their bombs at the hero, so they land
  against the Foundry); through an Overpressure stands on the nearest safe slab; with the gauge at 600 or more walks
  to the nearest slab and stays until it is empty. Otherwise holds its weapon's distance and attacks.
- **ignores:** holds its weapon's distance (Gun 4–6 m, Blade 1.2 m from the boss's edge) and attacks.

## Output (raw)
```
FORGEBOT| weapon=gun bot=plays seed=5 dead=true ticks=4735 seconds=78.9 max_hp=100 hp_lost=1050 biggest=50 over=0 scald=14 other=1036 plates=3 blown=3 seconds_plated=4.7 seconds_burning=3.5 overs=1 forge_biggest=2
FORGEBOT| weapon=gun bot=ignores seed=5 dead=true ticks=8929 seconds=148.8 max_hp=100 hp_lost=2216 biggest=50 over=72 scald=348 other=1796 plates=2 blown=1 seconds_plated=96.6 seconds_burning=86.9 overs=3 forge_biggest=3
FORGEBOT| weapon=gun bot=plays seed=6 dead=true ticks=4953 seconds=82.5 max_hp=100 hp_lost=858 biggest=50 over=0 scald=12 other=846 plates=3 blown=2 seconds_plated=5.9 seconds_burning=3.0 overs=1 forge_biggest=2
FORGEBOT| weapon=gun bot=ignores seed=6 dead=true ticks=8275 seconds=137.9 max_hp=100 hp_lost=1816 biggest=50 over=72 scald=240 other=1504 plates=2 blown=1 seconds_plated=82.8 seconds_burning=59.8 overs=3 forge_biggest=3
FORGEBOT| weapon=gun bot=plays seed=7 dead=true ticks=5176 seconds=86.3 max_hp=100 hp_lost=1096 biggest=50 over=24 scald=44 other=1028 plates=3 blown=3 seconds_plated=7.6 seconds_burning=11.0 overs=1 forge_biggest=3
FORGEBOT| weapon=gun bot=ignores seed=7 dead=true ticks=8205 seconds=136.8 max_hp=100 hp_lost=1848 biggest=50 over=48 scald=200 other=1600 plates=2 blown=1 seconds_plated=80.7 seconds_burning=49.7 overs=2 forge_biggest=3
FORGEBOT| weapon=gun over 3 seeds: plays { "ticks": 14864, "hp_lost": 3004, "over": 24, "scald": 70, "other": 2910, "blown": 8, "plated_ticks": 1094 }, ignores { "ticks": 25409, "hp_lost": 5880, "over": 192, "scald": 788, "other": 4900, "blown": 3, "plated_ticks": 15601 }
FORGEBOT| weapon=blade bot=plays seed=5 dead=true ticks=3194 seconds=53.2 max_hp=100 hp_lost=315 biggest=23 over=0 scald=2 other=313 plates=2 blown=1 seconds_plated=8.7 seconds_burning=0.2 overs=0 forge_biggest=2
FORGEBOT| weapon=blade bot=ignores seed=5 dead=true ticks=3104 seconds=51.7 max_hp=100 hp_lost=297 biggest=23 over=0 scald=6 other=291 plates=2 blown=2 seconds_plated=6.0 seconds_burning=1.1 overs=0 forge_biggest=2
FORGEBOT| weapon=blade bot=plays seed=6 dead=true ticks=3162 seconds=52.7 max_hp=100 hp_lost=286 biggest=38 over=0 scald=14 other=272 plates=2 blown=2 seconds_plated=3.7 seconds_burning=3.4 overs=1 forge_biggest=2
FORGEBOT| weapon=blade bot=ignores seed=6 dead=true ticks=3162 seconds=52.7 max_hp=100 hp_lost=286 biggest=38 over=0 scald=14 other=272 plates=2 blown=2 seconds_plated=3.7 seconds_burning=3.4 overs=1 forge_biggest=2
FORGEBOT| weapon=blade bot=plays seed=7 dead=true ticks=3793 seconds=63.2 max_hp=100 hp_lost=440 biggest=23 over=0 scald=0 other=440 plates=2 blown=2 seconds_plated=5.5 seconds_burning=0.0 overs=1 forge_biggest=0
FORGEBOT| weapon=blade bot=ignores seed=7 dead=true ticks=3646 seconds=60.8 max_hp=100 hp_lost=446 biggest=23 over=24 scald=28 other=394 plates=2 blown=2 seconds_plated=2.1 seconds_burning=7.0 overs=1 forge_biggest=3
FORGEBOT| weapon=blade over 3 seeds: plays { "ticks": 10149, "hp_lost": 1041, "over": 0, "scald": 16, "other": 1025, "blown": 5, "plated_ticks": 1073 }, ignores { "ticks": 9912, "hp_lost": 1029, "over": 24, "scald": 48, "other": 957, "blown": 6, "plated_ticks": 712 }
    [Pending]:  NOT MET, ignoring the forge is clearly slower and costs clearly more: blade: ignoring took 9912 ticks, playing 10149 ticks
```

## Result
| Line | Gun | Blade |
|---|---|---|
| "ignores" is clearly slower (the test's bar: 10 % more ticks) | **Met**: 25,409 against 14,864 ticks (1.71×) | **Not met**: 9,912 against 10,149 (ignoring was 2 % faster) |
| "ignores" loses clearly more HP to the forge (bar: 30 % more) | **Met**: 980 against 94 HP (over + scald) | Met on the bar, but tiny: 72 against 16 HP |
| "ignores" loses clearly more HP in all | **Met**: 5,880 against 3,004 | **Not met**: 1,029 against 1,041 |
| No single mistake kills from full | Met: no tick killed; the forge's largest step 3 HP (3 %) | Met: largest step 3 HP |

What the numbers say (read from them, not measured further):
- With the Gun the plate is the forge: the bot that ignores it fights the plated Foundry for 81–97 s of each fight
  (one plate blown by chance), and its last phase lasts long enough for 2–3 Overpressures and 50–87 s of burning.
- With the Blade the bot already stands by the Foundry, so the drones' bombs blow the plate off for both bots (2 of
  2 plates nearly every fight), and its fight is short (52–63 s): the last phase sees 0–1 Overpressure and a few
  seconds of burning. On seed 6 the two bots played exactly the same fight. The forge asks the Blade for nothing it
  does not already do.
- `biggest` = 50 with the Gun is the existing Vent Blast (50 damage) on a 100 HP hero, not a forge mechanic.

Nothing was retuned. The Blade line is the lead's and the owner's call.
