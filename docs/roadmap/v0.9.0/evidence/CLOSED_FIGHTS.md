# v0.9.0 Step CF: closed fights sized to their room

Owner (PLAN "Owner decisions", row CF): "one small note, for closed fights arenas overrun, etc, lets never make it a 1x1
it is too small and so many enemies appear, the enemies that spawn at the same time should be proportional to the room
size, where smaller rooms are a challenge but not impossible crazy"

Build: `28a839f3` (branch `v090-cf`, from `claude/world-combat-v090` at `64e12d93`). Machine: the owner's PC
(i7-10700K, RTX 3060), Godot 4.7.2, headless.

## What changed

- **Rooms.** Arenas (`ArenaRooms.mark`), the Overrun room (`OverrunRooms.mark`) and Lockdowns, the Elite Lockdown
  included (`LockdownRooms.mark`), skip rooms with fewer than their data's `min_cells` grid cells (starting value 2:
  never a 1 x 1). The Chaos kind is not drawn for a shrine whose room has fewer than `chaos_min_cells` (2) cells: the
  same draw on `map:shrine_kind` then picks Fortune or Blood (Chaos weighs 0 there; a bigger room's draw is as
  before). No room fits: that fight is not on the floor. The arena target still counts every candidate (only the
  pick skips small rooms). `data/special_rooms/{arena,overrun,lockdown}.tres` carry `min_cells = 2`, cross-checked
  against the kinds' data, and the RG property test now fails a sealed kind in a room under its `min_cells`.
- **Enemies at once** (`ClosedFights`). A fight's members are drawn as before (same streams, same order), but only
  `cap = max(1, floor(room area m2 / area_per_enemy_m2))` of them (by weight; an elite counts `elite_weight` = 3) come
  out together; the rest wait (`later_kinds`, `later_pos` in ArenaState, LockdownState, ShrineState) and come in, in
  order, as earlier ones die (not while a Splitling's halves are still arriving). A member always comes out when
  nothing is out (a heavy elite in a small room comes alone). Totals and clear rules are unchanged: the next arena
  wave / Lockdown formation waits for the whole one; the Chaos challenge is won when none is alive and none waits.
  - Arena waves and the Overrun: the first members at their drawn spots; a waiting one at its own spot, or the room's
    spawn point nearest it when the hero is within 2.5 m.
  - Lockdowns: a capped formation is drawn as a formation of the at-once count; the rest come in at their full
    formation's spots (fitted as before). The 90 s cap opens the room with any waiting members dropped.
  - Chaos: the elite (when drawn) is last in the queue, as it was last to spawn.
  - Starting values: `area_per_enemy_m2 = 30.0` (arena, overrun, lockdown), `chaos_area_per_enemy_m2 = 30.0`,
    `elite_weight = 3` (data/elites/rules.tres).
- **Floor rules.** `RunState.FLOOR_RULES` 15 -> 16 (`FLOOR_RULES_V090_EL` = 15). A floor saved under rules 1-15
  rebuilds with the rooms it had (`ClosedFights.legacy_rooms`: the kinds' min_cells read as 0 in
  `RunSaver.floor_tables` and `FloorPlan.add_secrets`). The at-once cap applies to every floor in play.
- **Saves / hash.** The waiting members are snapshotted (WorldSnapshot `ADDED_SINCE_V05` for the three states: an older
  save has none) and hashed only while any wait, so a fight that never waits hashes as before.

## Numbers

Command (each run of 1,000 run seeds x floors 1-5, built as Main builds them, SaveLab.build_floor):

```
godot --headless --path . -s scripts/balance/closed_fights.gd -- seeds=1000 rules=15
godot --headless --path . -s scripts/balance/closed_fights.gd -- seeds=1000
```

"Before" is floor rules 15, the path a floor saved before CF rebuilds through. Cross-check: a run of the same census
on the unchanged code (`64e12d93`, arenas only, an earlier version of the script that miscounted the other kinds)
gave arena 4973 / 2208, the same as rules 15 below.

Raw output, rules 15 (before):

```
CLOSED_FIGHTS| seeds=1000 floors=1-5 (5000 floors) floor_rules=15

| kind | floors with one | floors with one in a 1 x 1 room |
|---|---|---|
| arena | 4973 | 2208 |
| overrun | 5000 | 1740 |
| lockdown | 4000 | 1534 |
| elite_lockdown | 639 | 223 |
| chaos | 638 | 118 |

At once on floor 5 (weight; an elite counts 3): cap / today's whole wave
| cells | rooms | mean m2 | arena | overrun | lockdown | elite_lockdown | chaos |
|---|---|---|---|---|---|---|---|
| 1x1 | 6161 | 125 | 4 / 7 | 4 / 12 | 4 / 6 | 4 / 6 | 4 / 10 |
| 1x2 | 2737 | 285 | 7 / 7 | 9 / 12 | 6 / 6 | 6 / 6 | 9 / 10 |
| 2x1 | 2754 | 278 | 7 / 7 | 9 / 12 | 6 / 6 | 6 / 6 | 9 / 10 |
| 1x3 | 1147 | 445 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 3x1 | 1237 | 430 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 2x2 | 1533 | 634 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 2x3 | 727 | 991 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 3x2 | 689 | 981 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 3x3 | 383 | 1545 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 3x4 | 124 | 2111 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 4x3 | 117 | 2094 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 4x4 | 91 | 2808 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
```

Raw output, rules 16 (today's):

```
CLOSED_FIGHTS| seeds=1000 floors=1-5 (5000 floors) floor_rules=16

| kind | floors with one | floors with one in a 1 x 1 room |
|---|---|---|
| arena | 4604 | 0 |
| overrun | 4990 | 0 |
| lockdown | 2618 | 0 |
| elite_lockdown | 437 | 0 |
| chaos | 486 | 0 |

At once on floor 5 (weight; an elite counts 3): cap / today's whole wave
| cells | rooms | mean m2 | arena | overrun | lockdown | elite_lockdown | chaos |
|---|---|---|---|---|---|---|---|
| 1x2 | 3453 | 285 | 7 / 7 | 9 / 12 | 6 / 6 | 6 / 6 | 9 / 10 |
| 2x1 | 3556 | 278 | 7 / 7 | 9 / 12 | 6 / 6 | 6 / 6 | 9 / 10 |
| 1x3 | 1460 | 446 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 3x1 | 1558 | 430 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 2x2 | 2004 | 633 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 2x3 | 922 | 990 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 3x2 | 900 | 978 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 3x3 | 493 | 1541 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 3x4 | 162 | 2116 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 4x3 | 152 | 2095 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
| 4x4 | 114 | 2809 | 7 / 7 | 12 / 12 | 6 / 6 | 6 / 6 | 10 / 10 |
```

Reading it:
- Closed fights in a 1 x 1 room: 2208 / 1740 / 1534 / 223 / 118 floors before, 0 after, per kind.
- **Fewer floors have each fight** where no bigger room fitted: arenas 4973 -> 4604, Overrun 5000 -> 4990, Lockdowns
  4000 -> 2618, Elite Lockdowns 639 -> 437, Chaos shrines 638 -> 486 (those floors draw Fortune or Blood). The
  Lockdown drop is the largest: its candidates were already narrowed by every other room kind. For the owner to judge
  (OWNER ONLY: whether 2,618 of 5,000 floors with a Lockdown is enough).
- The cap bites only in 1 x 2 / 2 x 1 rooms, and only for the Overrun (9 of 12 at once on floors 3-5) and a Chaos
  challenge with its elite (9 of 10). Rooms of 3 cells or more fight exactly as before. Arena waves (max 7) and
  Lockdown formations (max 6, the Elite Lockdown's 3 + 3) fit every room a fight can now take.

## Tests (owner's PC, build 28a839f3 working tree, own APPDATA)

Lint: `gdformat --check src scripts tests` -> `1259 files would be left unchanged`; `gdlint src scripts tests` ->
`Success: no problems found`.

| Run | Result |
|---|---|
| `-gtest=res://tests/unit/sim/test_closed_fights.gd` (new) | Tests 8, Passing 8, Asserts 64, 135.85 s |
| test_arenas, test_overrun, test_lockdowns, test_shrines, test_elites, test_elite_rooms, test_old_saves, test_world_snapshot, test_state_hasher, test_layering, test_sim_purity | Tests 101, Passing 99, Failing 2, 2288.75 s (the two below) |
| test_arenas + test_shrines, after the two fixes | Tests 26, Passing 26, Asserts 2420, 867.87 s |
| `-gdir=res://tests/content,res://tests/unit/debug` | Tests 166, Passing 166, Asserts 11881, 49.60 s |
| e2e: test_e2e_arena, test_e2e_lockdown, test_e2e_shrines, test_e2e_run_flow, test_e2e_old_save | Tests 10, Passing 10, Asserts 140, 137.10 s |
| test_special_room_rules (the RG property test, once) | Tests 3, Passing 3, Asserts 107, 607.28 s; `RG_RULES| floors=1000 timed_doors=234 worst_walk_permille_of_timer=622 lockdowns=704` |

The two failures of the first batch, both from the room change, and the change made:
- `test_arenas: test_rewards_fill_the_arenas_first_and_keep_two_altars`: `[29] expected to be > than [30]: nearly
  every floor's arenas hold rewards`. Of its 40 floor-1 floors, 29 have an arena now (39 under rules 15: the others'
  fitting rooms were all 1 x 1). The test now asserts every floor with an arena holds its rewards, and more than 25
  of the 40 have one.
- `test_shrines: test_a_floor_saved_before_sh_is_rebuilt_as_it_was`: `[VECTOR2(24.06, -12.69)] expected to equal
  [VECTOR2(-0.065, 31.95)]`. The shrine's site keeps out of arenas, which moved; the test now compares the SH-era
  floor with a floor under rules 15 (the last before CF) instead of today's.

New tests (`tests/unit/sim/test_closed_fights.gd`): no closed fight in a 1 x 1 over 200 floors and every room of 4+
cells holding each fight whole (`CF_ROOMS| floors=200 fights={ arena: 227, overrun: 200, lockdown: 131, chaos: 18 }
bad=0`); the cap and the elite weight; a rules-15 floor keeps its 1 x 1 fights while today's has none on the same
rooms; a squeezed arena (cap 2): two out, the rest come in, the same kinds in the same order and the same total as
uncapped, cleared; a squeezed Lockdown (cap 2): a formation of 2, reinforcements, the same 15 members, opened by
the clear; an Elite Lockdown (cap 4): the elite and one escort first, then the rest; a squeezed Chaos challenge
(cap 2): won with every member; a save with members waiting round-trips (hash equal, equal after 400 ticks; the
waiting members are hashed).

Not run locally: the full suite and `tests/golden` (NOT YET RUN; GitHub runs them on the PR, the lead's seams run
covers golden). No golden file was changed; the hash adds nothing for a fight that never waits, but floors built
under the new rules place their fights differently, so a golden that builds a run floor would move.

Owner only: whether small-room fights feel like "a challenge but not impossible crazy" — OWNER ONLY.
