# MAPS: do floors have up to 20 rooms with bigger rooms, a cursed chest at most every two floors, 20 % fewer challenge rooms and a shop every two floors? (v0.7.5 MG, owner N9-N12)

- **Status:** RUN
- **Build:** before `68d8300` (the v0.7.0 head `6381fcb` plus only `scripts/checks/map_stats.gd`); after `1e79bc8`
  (the step's code; the step commit adds only these docs). Branch `v075-mg`. Godot `4.7.2.stable.official.ed1daf0bf`;
  OS Linux 6.18.44 (cloud container, 4 cores shared with two other agents: the timings are loaded-machine numbers)
- **Date:** 2026-10-13
- **Who ran it:** agent

## Command
```
godot --headless --path . -s scripts/checks/map_stats.gd -- seeds=1000 runs=200
```
Run once with `68d8300` checked out (before) and once at `1e79bc8` (after), each after
`godot --headless --path . --editor --import --quit`. The layout lines are 1,000 floor seeds (`1000 + k × 7919`),
each built as `FloorScenario.build` does (generate with the map data, boss room, Overrun room, arenas with the
data's share, shop pick). The curse lines are 200 runs (`5000 + r × 104729`) × 3 floors built as Main builds them,
every chest's offer rolled as if opened (`Offers.roll` + `Curses.on_offer_rolled`). The script writes
`build/map_stats.txt`; the output below is pasted by hand.

## Raw output: before (`68d8300`)
```
MAP| floors=1000 params rooms=10..12 max_span=8
MAP| rooms (hall included, boss room not): 10: 345 (34.5%), 11: 305 (30.5%), 12: 350 (35.0%)
MAP| rooms with the boss room: 11: 345 (34.5%), 12: 305 (30.5%), 13: 350 (35.0%)
MAP| footprints after the hall: 1x1: 4049, 1x2: 1499, 1x3: 671, 2x1: 1460, 2x2: 813, 2x3: 341, 3x1: 705, 3x2: 321, 3x3: 146
MAP| floor box: mean area 16554 m2, largest side 189.6 m
MAP| layout build (generate+boss+overrun+arenas+shop pick): mean 198.65 ms, p50 192.67 ms, p99 342.39 ms, max 429.30 ms
MAP| challenge rooms per floor (Overrun + arenas, arena share 330 permille): mean 3.231 (Overrun 1.000, arenas 2.231); 1: 4 (0.4%), 2: 61 (6.1%), 3: 635 (63.5%), 4: 300 (30.0%)
MAP| floors where no room takes the shop: 0
SHOP| floors with a shop (1..12): 1,2,3,4,5,6,7,8,9,10,11,12; in a 3-floor run: 3
CURSE| runs=200 floors=600 chests=1792 cursed=449 (0.748 per floor; floor 1/2/3: 152/159/138)
CURSE| cursed chests per floor: 0: 260 (43.3%), 1: 245 (40.8%), 2: 81 (13.5%), 3: 14 (2.3%)
CURSE| cursed chests per run: 0: 14 (7.0%), 1: 45 (22.5%), 2: 63 (31.5%), 3: 45 (22.5%), 4: 24 (12.0%), 5: 7 (3.5%), 6: 2 (1.0%)
CURSE| a cursed chest on a floor right after one with a cursed chest: 126
real	5m42.392s
```
(A first before-run on `6381fcb` with the then-uncommitted script gave the same counts and a 190.88 ms mean build.)

## Raw output: after (`1e79bc8`)
```
MAP| floors=1000 params rooms=15..19 max_span=11
MAP| rooms (hall included, boss room not): 15: 171 (17.1%), 16: 212 (21.2%), 17: 198 (19.8%), 18: 217 (21.7%), 19: 202 (20.2%)
MAP| rooms with the boss room: 16: 171 (17.1%), 17: 212 (21.2%), 18: 198 (19.8%), 19: 217 (21.7%), 20: 202 (20.2%)
MAP| footprints after the hall: 1x1: 4845, 1x2: 2430, 1x3: 1082, 2x1: 2397, 2x2: 1624, 2x3: 816, 3x1: 1160, 3x2: 788, 3x3: 463, 3x4: 155, 4x3: 165, 4x4: 142
MAP| floor box: mean area 27395 m2, largest side 238.9 m
MAP| layout build (generate+boss+overrun+arenas+shop pick): mean 363.41 ms, p50 351.39 ms, p99 607.63 ms, max 676.77 ms
MAP| challenge rooms per floor (Overrun + arenas, arena share 110 permille): mean 2.419 (Overrun 1.000, arenas 1.419); 2: 581 (58.1%), 3: 419 (41.9%)
MAP| floors where no room takes the shop: 0
SHOP| floors with a shop (1..12): 1,3,5,7,9,11; in a 3-floor run: 2
CURSE| runs=200 floors=600 chests=1792 cursed=222 (0.370 per floor; floor 1/2/3: 115/0/107)
CURSE| cursed chests per floor: 0: 378 (63.0%), 1: 222 (37.0%)
CURSE| cursed chests per run: 0: 37 (18.5%), 1: 104 (52.0%), 2: 59 (29.5%)
CURSE| a cursed chest on a floor right after one with a cursed chest: 0
real	10m8.460s
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Rooms per floor | up to 20 (boss room included), bigger rooms, a new extra-large size | PLAN N9 |
| Cursed chests | at most one every two floors | PLAN N10 |
| Challenge rooms (Overrun + arenas) per floor | 20 % fewer than v0.7.0 (≤ 2.585) | PLAN N11 |
| Shop | every two floors; a 3-floor run has at least one | PLAN N12 |
| Generation properties | connectivity, reachability, boss room last, spawn safety over 1,000 seeds stay green | task brief, ROADMAP v0.4.0 |

## Result
| Metric | Before | After | In band? |
|---|---|---|---|
| Rooms per floor, boss room included | 11-13 (mean 12.0) | 16-20 (mean 18.1) | yes |
| Footprints | 9, up to 3×3 | 12: adds 4×3, 3×4 and the extra-large 4×4 (142 of 16,067 rooms) | yes |
| Floor box | 16,554 m² mean, 189.6 m largest side | 27,395 m² mean, 238.9 m | — (bigger, as asked) |
| Layout build per floor (loaded machine) | mean 198.7 ms, p99 342.4 ms, max 429.3 ms | mean 363.4 ms, p99 607.6 ms, max 676.8 ms | no target set; +83 % mean, reported |
| Challenge rooms per floor | 3.231 | 2.419 (−25.1 %) | yes (≤ 2.585) |
| Cursed chests per floor / per 3-floor run | 0.748 / up to 6 | 0.370 / up to 2; never two floors in a row (0 of 600 floors) | yes |
| Shops in a 3-floor run | 3 (every floor) | 2 (floors 1 and 3) | yes |

## Interpretation
- N9: floors now draw 15-19 rooms before the boss room, so 16-20 in all, with more weight on the big footprints and the
  new 4×3, 3×4 and 4×4 sizes. Every number is in `data/map/floor.tres` (F10, Difficulty). The generator draws from the
  same `map` stream in the same order, so every seed's floor is new but deterministic.
- N10: the 25 % chance per chest stays (the owner's number); it now counts only on floors 1, 3, 5 … and at most once a
  floor. Floor 2 has none. The "which floors" reading is the lead's (the owner asked for no interventions).
- N11: the arena share went from 0.33 to 0.11. A share sweep over 300 seeds (a scratch script, not kept) gave means of
  2.433 at 0.11 and 2.650 at 0.12; 0.12 would be only 18 % fewer, so 0.11 was chosen. On 1,000 seeds it is 25.1 %
  fewer. The Overrun room stays one per floor.
- N12: the shop stands on floors 1, 3, 5 …, so a 3-floor run has two.
- Floor build time nearly doubled. It runs once per floor, at load, behind the portal transit. The real-time cost on
  the owner's PC (load hitch, frame rate on a larger floor with more props) is **OWNER ONLY**. The per-tick nav flood is
  bounded (`NavField.WORLD_FLOOD_STEPS`), so it doesn't grow with the floor. The save snapshot copies the nav field,
  which grows with the floor's area; its cost was **NOT YET RUN** (`scripts/bench/save_bench.gd`).
- This proves frequencies over seeds. It says nothing about feel: whether the bigger floors are fun or too long to
  cross is the owner's call at the playtest.
