# Step SB (v0.9.5): models that look solid are solid

Owner line: "Some models you can just go through they have no 3D box, like the arrival portal or at the last boss ...
make sure ... you can't just go through them".

Build base: origin/main d33bc82a, branch `v095-sb`. Machine: owner PC (Windows, Godot 4.7.2). Commit SHA: see the
step report (a commit cannot name itself).

## What was built

- `src/sim/world/solids.gd` (`Solids`, `World.solids`): each prop's footprint is registered, and joins `World.walls`
  (`add_barrier`) once the hero is 0.5 m clear of it; it leaves with its owner. Active only under floor rules 18
  (`RunState.FLOOR_RULES_V095_SB`) and on worlds built with a run; a floor saved before SB builds none (old saves keep
  their walls). Snapshot: `Solids` is a state class, `solids` is in ADDED_SINCE_V05, placed footprints count as barriers.
- Reward altars, chests, boss/secret/shrine/Overrun/Lockdown altars (everything through `World.add_reward`, except
  DROP): 1.2 m square; interact reach measured to the surface (+ half-extent). Removed when the pick is taken.
- Event pedestals (1.2 m; the furnished curse altar already had a collider), rune pillars, the purple-rune dais: 1.2 m
  squares, reach + 0.6 m.
- Final approach pylons: 1 m squares, reach + 0.5 m. Plateau altar: left as is, the Colossus rises from it in the fight.
- Loop device: 1 m square at its spot/facing; entering = the hero's body within 0.15 m of its surface
  (`Ascension.touching_loop_device`).
- Reward spots near doorways: `Solids.clear_of_doors` nudges a prop so a 0.6 m circle stays free at its room's door
  centres and approaches (best effort; the property test checks a 0.45 m circle).

## Findings

- Arrival portal (floors 2+): the world is held (`BossFlow.holds_world`, `arrive_left`) for the whole step-out
  animation; the portal collapses to a point by the end of that hold, before the hero can move. Nothing to add.
- Ascension portal on the last floor is the floor's gate (`FloorScenario.gate_collider`), already solid; entering
  checked by `test_the_ascension_portal_is_solid_and_walking_into_it_still_enters`. The exit gate/Deep gate unchanged.
- The "rune mural" has no sim object (view dressing only): no collider added.
- Breakables, barrels, biome edge props: untouched, as instructed.

## Boss radius table (model AABB from BossModels.get_model x SIZE_SCALE 1.3, `scripts/checks/boss_footprints.gd`)

half = larger of the horizontal half-extents (the lateral span, arms included).

| model | boss | radius_m before | half | ratio | after |
|---|---|---|---|---|---|
| stone_sentinel | gatekeeper | 1.70 | 2.648 | 0.64 | 2.25 |
| crawler_queen | brood_mother | 1.55 | 2.453 | 0.63 | 1.55 NOT RAISED (see below) |
| fortress_turret | siege_engine | 1.80 | 3.308 | 0.54 | 2.81 |
| warlord | warlord | 1.45 | 1.212 | 1.20 | 1.45 |
| hive_lens | hive_lens | 1.30 | 1.236 | 1.05 | 1.30 |
| foundry | foundry | 1.95 | 1.680 | 1.16 | 1.95 |
| boss_tidecaller | tidecaller | 1.60 | 2.080 | 0.77 | 1.60 |
| twin_warden_amber / violet | twin_wardens | 1.00 | 1.273 / 1.293 | 0.79 / 0.77 | 1.00 |
| boss_clockwork_judge | clockwork_judge | 1.40 | 1.794 | 0.78 | 1.40 |
| boss_lantern_shade | lantern_shade | 1.20 | 1.760 | 0.68 | 1.50 |
| final_boss_colossus | colossus | 1.60 | 2.269 | 0.71 | 1.93 (owner step: 85 % set explicitly) |
| final_boss_prism | prism | 1.50 | 2.490 | 0.60 | 2.12 |
| final_boss_nemesis | nemesis | 0.70 | 0.824 | 0.85 | 0.70 |

Brood Mother: raised to 2.09 it broke `test_e2e_boss_dodge_2` (no Leap ever locked in 4800 frames; passes at 1.55), and
its burrow eruption (radius 2.0) then missed a hero shoved out of the larger body. Reverted to 1.55 / 2.0; needs a
decision (a raise needs the Leap range and burrow disc retuned together).

## Tests (raw)

Commands are in the step report; every run used its own APPDATA. `NOT YET RUN` entries are listed honestly.

Run: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> -gexit` (APPDATA per run).

- tests/golden + tests/arch + tests/unit/application (142 tests): 142 passing (run before the later test edits; no
  golden or hash file changed).
- Sim set after the fixes (after_boss, arenas, boss_door_press, purple_runes, routes, run_flow, overrun, lantern_shade,
  boss_fights 1-3, final_approach, final_boss, colossus, bosses 1-2, solids, lockdowns, rewards, world_snapshot,
  interactables, ascension, events, prism, timed_door, rune_alignment): 312/312 passing.
- Earlier wider runs (sim a-h subset 770 tests, sim i-z subset 363 tests) found only the failures fixed above plus:
  test_final_pace "strong blade body 2: no slower than the base build" (138.8 vs 150.3 s; a bot pace test, body 2 of
  the final fight; NOT re-run after the radius change was final, owner/lead decision: retune or revert the Prism's
  2.12), and test_deep_bite "Abismo susurrante" (this PC is Spanish; run with --language en).
- Full tests/e2e folder: 196/198 passing. Failing: test_e2e_glaive_seekers `every disc hit it both ways` (an odd hit
  count with an altar beside the hero) and test_e2e_combo (`opened reward 2`: the walk to a chest next to a placed altar
  stalls; the altar panel then opens a press late). Both pass with the solids off. NOT RESOLVED.
- test_solids.gd (new, 9 tests): altar, pylon, Loop device and Ascension portal frame cannot be walked through (the
  centre never closer than radius + half-extent - 0.05 m over 120 ticks), the Loop device and the portal still enter,
  placed-on-clear rule, removal with the owner, floor-rules gate, and a 40-seed x 3-floor doorway property (484
  props, none blocks a 0.45 m circle at a doorway or its approach) all passing.
- Not run locally: tests/unit/presentation, test_five_floors, test_curse_room (CI).

Test helpers changed (not goldens): tests/support/e2e.gd (walk_to stops at a prop's surface; the walk plans round props),
clear_spot in test_e2e_bomb/laser/void, wall-count helpers in the sim tests listed in the commit.
