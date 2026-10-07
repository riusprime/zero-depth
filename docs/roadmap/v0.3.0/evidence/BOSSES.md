# v0.3.0 Step C: the three bosses (evidence)

Build: `a8a1caa` (the bosses workstream merged with `claude/lucid-fermat-9wv2tf` at `f13bcfb`). The suite run below
was made on that tree before `tests/MIN_TEST_COUNT` was raised from 362 to 403 in the same commit.

## What was built

| Boss (floor pool) | Sheet name | HP | Radius | Arena (cells, template) | Phase 1 | Phase 2 (at 50 % HP) |
|---|---|---|---|---|---|---|
| Gatekeeper (floor 1) | Stone Sentinel | 1400 | 1.3 m | 3 x 3, pillars | Fist Slam (spike ring 2.1-4.0 m), Shock Lanes x3, Sweep (180°, 2.4 m) | opens with a Charge (18 m lane); Shock Lanes x5; +15 % speed, cooldowns x0.8 |
| Brood Mother (floor 2) | Crawler Queen | 1600 | 1.2 m | 2 x 2, scatter | Leap (2.4 m disc on your spot), Burrow (ripple tracks you 1.6 s, then a 2.2 m eruption marked 0.6 s), Brood (3 eggs, up to 6 hatchlings alive) | Leaps chain twice, Brood of 4 with a shorter windup; cooldowns x0.8 |
| Siege Engine (floor 3) | Fortress Turret | 1800 | 1.4 m | 3 x 1, lines | Barrage (5 shells, 1.6 m), Rail Sweep (110° beam, 13 m), Bolt Fan (7 bolts x 3 volleys) | plants (speed 0) and opens with Deploy (two Needle turrets); Barrage of 7; cooldowns x0.65 |

- Every telegraph is at least 24 ticks (validation, plus the runtime test below). Stagger: Gatekeeper 220 points
  (decay 12/s), Brood Mother 260 (14/s), Siege Engine 300 (15/s); a full meter staggers for 2.5 s (150 ticks).
- Armour: the Gatekeeper takes 80 % from the front 120° and 110 % from the rear 120°, as the Warden. The other two
  have none (the PLAN gives armour only to the Gatekeeper).
- The Gatekeeper's arena uses the generator's PILLARS template: the pillars are normal cover, not breakable
  (breakable pillars would need a destructible-wall system in the sim; left for the owner to decide). The Siege
  Engine's cover lines are not destroyable either, for the same reason.
- Every number is a starting value.

## Commands and raw output

Full suite (`bash scripts/verify.sh`, run in the worktree at the tree above):

```
REPLAY| final=5171fdadd6442c3e5c568273b2fcb361fa5f19fddd3e922231fe6c4bb3d841ae
BOSSFIGHT| gatekeeper ticks=3379 seconds=56.3
BOSSFIGHT| brood_mother ticks=4307 seconds=71.8
BOSSFIGHT| siege_engine ticks=3310 seconds=55.2
Tests               403
Passing Tests       403
check_gut_log: ok (403 passing, minimum 362)
```

Fight length (`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd
-gtest=res://tests/unit/sim/test_boss_fights.gd -gexit`, at `a8a1caa`):

```
BOSSFIGHT| gatekeeper ticks=3379 seconds=56.3
BOSSFIGHT| brood_mother ticks=4307 seconds=71.8
BOSSFIGHT| siege_engine ticks=3310 seconds=55.2
```

The bot has no items, never stops shooting (4 damage per 0.12 s, about 33/s) from 4-6 m, and can't die. That is a
perfect-uptime floor; the test's band is 30-90 s. A real player who spends part of the fight dodging will take
longer; whether that lands in the PLAN's 60-120 s with a few items is `NOT YET RUN` (it needs the owner's playtest
or a bot that dodges).

Renders (`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot
--path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/bosses.gd -- mode=sheet`, then the same with
`mode=compare`, at `a8a1caa`):

```
bosses: res://build/shots/v0.2.0-dev/bosses/bosses.png cells=gatekeeper idle, gatekeeper fist_slam, gatekeeper shock_lanes_5, brood_mother idle, brood_mother leap, brood_mother brood_4, siege_engine idle, siege_engine barrage_7, siege_engine rail_sweep
bosses: res://build/shots/v0.2.0-dev/bosses/boss_gatekeeper_compare.png
bosses: res://build/shots/v0.2.0-dev/bosses/boss_brood_mother_compare.png
bosses: res://build/shots/v0.2.0-dev/bosses/boss_siege_engine_compare.png
```

The PNGs here are those files, quantised to 256 colours by hand (the compares also scaled to 75 %):
`bosses.png` 145,737 bytes, `boss_gatekeeper_compare.png` 222,701, `boss_brood_mother_compare.png` 212,531,
`boss_siege_engine_compare.png` 216,774.

- [`bosses.png`](bosses.png): the game's view (Ruins stage, iso camera, ActorViews, TelegraphViews) of a real
  World: each boss idle, then two attacks two thirds into their windups.
- `boss_<id>_compare.png`: the sheet's row on top; below, the code model in the sheet's FRONT, RIGHT-FRONT and RIGHT
  views and an iso inset with the player for scale.

## How close the models are to the sheet (agent's reading, not the owner's)

- Stone Sentinel: the red crystal crown, visor slot, boulder shoulders, stacked fists, back shell with glowing
  cracks and short legs read. Still off: the sheet's crown is one chunky faceted mass that frames the visor; ours is
  separate spikes. The sheet's fists hang wider and lower.
- Crawler Queen: the hood with the hex visor, the egg sac with spikes behind and eight legs with pale talons read.
  Still off: the sheet's sac is larger and glossier, its legs are thicker with more joints and curl inward.
- Fortress Turret: red box hull, slit eyes, long vented cannon, back mortars with red glow, four heavy legs read.
  Still off: the sheet's hull is longer front to back and its leg armour heavier.
- Owner's verdict: `OWNER ONLY`.
