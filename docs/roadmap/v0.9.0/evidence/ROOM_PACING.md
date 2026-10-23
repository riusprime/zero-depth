# v0.9.0 Step RG: how often and where the special rooms come, floors 1-5 over 1,000 runs (evidence)

- **Status:** RUN
- **Build:** branch `v090-rg` at `ac54f8ca` (the session branch `claude/world-combat-v090` at `ea16d8f7` merged in,
  plus the fountain fix) with Step RG's files in the working tree; the Step RG commit is the one that adds this file.
  Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 (the owner's PC), Git Bash.
- **Date:** 2026-10-23
- **Who ran it:** agent

## Command
```
godot --headless --path . -s scripts/balance/room_pacing.gd -- seeds=1000
```
(it prints the tables below and writes `build/balance/room_pacing.txt`; the output was copied here by hand)

## Raw output
```
ROOM_PACING| seeds=1000 floors=1-5 (each run's floors in order, as Main builds them)

Per floor, rooms of each kind a floor: mean (min-max), % of floors with none
| kind | floor 1 | floor 2 | floor 3 | floor 4 | floor 5 |
|---|---|---|---|---|---|
| arena | 0.97 (0-1), 2.7 % none | 1.00 (1-1), 0.0 % none | 1.00 (1-1), 0.0 % none | 1.36 (1-2), 0.0 % none | 2.00 (2-2), 0.0 % none |
| overrun | 1.00 (1-1), 0.0 % none | 1.00 (1-1), 0.0 % none | 1.00 (1-1), 0.0 % none | 1.00 (1-1), 0.0 % none | 1.00 (1-1), 0.0 % none |
| lockdown | 0.59 (0-2), 44.7 % none | 1.03 (0-2), 14.9 % none | 1.23 (0-2), 6.8 % none | 1.42 (0-2), 1.2 % none | 1.44 (0-2), 0.7 % none |
| shop | 1.00 (1-1), 0.0 % none | 0.00 (0-0), 100.0 % none | 1.00 (1-1), 0.0 % none | 0.00 (0-0), 100.0 % none | 1.00 (1-1), 0.0 % none |
| curse | 0.39 (0-1), 60.4 % none | 0.38 (0-1), 61.5 % none | 0.39 (0-1), 60.6 % none | 0.39 (0-1), 60.1 % none | 0.41 (0-1), 58.3 % none |
| event | 1.50 (1-2), 0.0 % none | 1.50 (1-2), 0.0 % none | 1.48 (1-2), 0.0 % none | 1.48 (1-2), 0.0 % none | 1.50 (1-2), 0.0 % none |
| shrine | 0.36 (0-1), 63.2 % none | 0.36 (0-1), 63.6 % none | 0.40 (0-1), 59.6 % none | 0.42 (0-1), 57.4 % none | 0.42 (0-1), 57.8 % none |
| fountain | 0.00 (0-0), 100.0 % none | 0.28 (0-1), 72.0 % none | 0.23 (0-1), 76.6 % none | 0.24 (0-1), 75.6 % none | 0.27 (0-1), 72.3 % none |
| timed_door | 0.01 (0-1), 98.9 % none | 0.26 (0-1), 73.8 % none | 0.17 (0-1), 82.5 % none | 0.34 (0-1), 65.6 % none | 0.20 (0-1), 79.6 % none |
| rune_puzzle | 0.00 (0-0), 100.0 % none | 0.08 (0-1), 91.5 % none | 0.05 (0-1), 94.1 % none | 0.15 (0-1), 84.3 % none | 0.10 (0-1), 89.4 % none |
| cracked_wall | 0.00 (0-1), 99.4 % none | 0.13 (0-1), 86.6 % none | 0.08 (0-1), 91.4 % none | 0.19 (0-1), 80.5 % none | 0.10 (0-1), 89.2 % none |
| purple_runes | 0.00 (0-0), 100.0 % none | 0.49 (0-1), 51.0 % none | 0.51 (0-1), 49.0 % none | 0.00 (0-0), 100.0 % none | 0.00 (0-0), 100.0 % none |
| any_secret | 0.01 (0-1), 98.3 % none | 0.48 (0-2), 53.9 % none | 0.32 (0-2), 70.1 % none | 0.69 (0-3), 41.3 % none | 0.41 (0-3), 62.4 % none |

Share of rooms (all rooms, start hall and boss room included), pooled over the floors
| floor | rooms a floor | special | special combat | puzzles and secrets | services and events |
|---|---|---|---|---|---|
| 1 | 11.01 | 53.2 % | 23.3 % | 0.2 % | 29.7 % |
| 2 | 13.98 | 46.0 % | 21.7 % | 6.9 % | 17.4 % |
| 3 | 15.96 | 46.9 % | 20.2 % | 5.2 % | 21.4 % |
| 4 | 18.02 | 39.1 % | 21.0 % | 3.9 % | 14.2 % |
| 5 | 19.49 | 43.5 % | 22.8 % | 2.1 % | 18.6 % |

Along the critical path (start hall to boss room)
| floor | path rooms: mean (min-max) | gap between special rooms: mean (max) | longest dry stretch: mean (max) |
|---|---|---|---|
| 1 | 6.59 (5-10) | 0.14 (3) | 2.41 (6) |
| 2 | 7.26 (5-11) | 0.24 (4) | 2.70 (6) |
| 3 | 7.69 (6-13) | 0.25 (4) | 2.73 (6) |
| 4 | 7.97 (5-12) | 0.32 (3) | 2.86 (7) |
| 5 | 8.20 (6-13) | 0.26 (3) | 2.88 (7) |

ROOM_PACING| done floors=5000 wall_s=2710
```
`time` gave `real 45m15.332s` (other agents' Godot processes were running on the machine at the same time, so this is
not a clean timing).

## What it counts

- Each run seed's floors 1-5 are built in order as Main builds them (`SaveLab.build_floor`: `FloorScenario`, the shop,
  the events, `FloorPlan.add_secrets`), the purple-rune history carried from floor to floor (one a loop). The flow
  field is not built (`NavField.skip_build`; no placement reads it, `test_special_room_rules` proves the rooms match
  with it built).
- A kind's rooms are read from the built world by `tests/support/room_census.gd` (the ids of `data/special_rooms`).
  `any_secret` is the timed door, rune puzzle and cracked wall rooms together.
- Shares: a room holding several kinds counts once, in the first band that holds it (special combat, then puzzles
  and secrets, then services and events).
- Critical path: the shortest doorway path from the start hall to the boss room. Each special room is counted at the
  path room nearest it (doorway hops); "gap" is the path rooms between two such points in a row, "dry" the longest
  run of path rooms with none.

## Result
No target bands are set for this report (PLAN W72/W74 ask for it; the owner reads it). What the numbers say:

| Observation | Measured |
|---|---|
| Overrun room | on every floor (100 %) |
| Arenas | 1 a floor on floors 1-3 (2.7 % of floor 1s have none), 1.36 on floor 4, 2 on floor 5 |
| Lockdowns | 0.59 a floor on floor 1 with 44.7 % of floor 1s holding none, rising to 1.44 on floor 5 (0.7 % none); the data's 1..2 a floor is a target, a floor with no room that fits gets none |
| Shop | floors 1, 3, 5 only, always there |
| Fountain | none on floor 1 (it starts on floor 2), then 23-28 % of floors |
| Purple runes | floors 2-3 only, about half each (one a loop) |
| Secrets (timed door, rune puzzle, cracked wall) | almost none on floor 1 (1.7 %), 0.32-0.69 a floor on floors 2-5 |
| Special rooms' share of a floor's rooms | 53.2 % on floor 1 down to 39.1-46.9 % on floors 2-5; special combat about 20-23 % on every floor |
| Longest stretch of the critical path with no special room nearest it | 2.4-2.9 rooms on average, 7 at most |

## Interpretation
The report describes today's placement; it changes nothing. The puzzle-and-secret band is thin (0.2-6.9 % of rooms,
none on most floor 1s), and Lockdowns are often missing on floor 1 because its small floors rarely have a room that
fits every rule. Whether either should change is the owner's call (OWNER ONLY: pacing feel).
