# CHASE_AND_STRIKES: do enemies chase by the shortest way, and do the melee strikes read? (v0.8.0 Step P1)

- **Status:** RUN (tests, probes, bench, screenshots); the feel is OWNER ONLY
- **Build:** the working tree of `v080-p1` (base `6da58e4` on `claude/lucid-fermat-9wv2tf`) with this step's changes,
  before its commit (the Step P1 commit is that tree plus this file and the PROGRESS/PLAN rows). The "base" runs
  below are the same tree with `src/sim/ai/nav_field.gd`, `src/sim/world/world.gd` and `src/sim/ai/boss_signatures.gd`
  checked out from `6da58e4` (the chase code as it was), then restored. Godot `4.7.2.stable.official.ed1daf0bf`;
  OS `Linux 6.18.44-fc-v139`, 4 cores shared with other agents (load average 2-13 over the session; the bench pairs
  were run back to back at load ~2)
- **Date:** 2026-10-16
- **Who ran it:** agent

Owner lines (verbatim in [`../PLAN.md`](../PLAN.md)): O23 "Enemies don't consistently find the shortest valid path
toward the player, sometimes getting stuck behind walls or in adjacent rooms instead of pursuing"; O25 "The large
ground-smashing enemy no longer displays its red circular attack warning. The large enemy also needs a visible
ground-smash animation"; O26 "Some other enemies have unclear attack animations. Their arm movements don't communicate
attacks properly"; O32 (efficiency).

## O23: what was wrong, what changed

There already was one shared distance-to-the-player field (`NavField`, since v0.1.0; 0.5 m cells, walls grown by
0.6 m), flooded every 10 ticks and skipped when the player kept its cell; an enemy uses it whenever the straight line
to the player is blocked (`EnemyAi.plan`). Three faults, found by probes on real floors:

1. **A player against a wall or in a doorway emptied the field.** The flood started from the player's cell; when that
   cell is blocked (its centre within 0.6 m of a wall: 4.8 % of the spots the player can stand on in the start room and
   its neighbours, more along walls and in doorways), it has no steps, so the flood reached nothing and every enemy out
   of sight walked straight into the walls until the player moved off. Now the flood seeds the free cells within 2
   cells that the player reaches by side steps through cells 0.25 m clear of every wall (never through a wall).
2. **Not the shortest way.** The flood was an 8-way breadth-first count: a diagonal cost the same as a side, so a door
   45 degrees off looked as near as one straight ahead, and the descent kinked. Now it is an exact octile shortest
   path in integers (a side 5, a diagonal 7; a bucketed Dijkstra), and an enemy steps to the neighbour on a shortest
   way (least distance + step, no corner cut).
3. **Cost (O32).** A floor's flood ran to 80 m of path every 10 ticks while the player moved. Now the world's flood
   (`World.flood_nav`) takes the live enemies' cells as targets and stops 4 m past the last of them; it floods again
   when the player changes cell or an enemy stands outside the field, and not at all with no enemy alive.

Deterministic: integer distances, fixed tick, from hashed state only; the field is derived (not hashed) and a resume
save keeps its last flood (dist + key) as before.

### Probe: the player stands against a wall, one Splitter starts in the next room (base vs P1)
`build/probe_wall_hug.gd` (untracked probe): 5 seeds x floors 1-3, the player held at a spot 0.36 m off a wall of the
start room whose field cell is blocked, a Splitter at the centre of each neighbouring room, 1800 ticks (30 s);
"reached" = within 3 m of path of the player, judged by a copy of P1's field (`build/judge_nav_field.gd`) in both
runs.

```
$ godot --headless --path . -s res://build/probe_wall_hug.gd        # base chase code (6da58e4)
not reached: seed 0 floor 1 room 1: path to the player 62.3 m at the start, 60.6 m at the end
not reached: seed 0 floor 2 room 1: path to the player 61.1 m at the start, 62.9 m at the end
not reached: seed 0 floor 3 room 1: path to the player 75.1 m at the start, 54.3 m at the end
not reached: seed 1 floor 1 room 1: path to the player 29.5 m at the start, 27.9 m at the end
not reached: seed 1 floor 2 room 1: path to the player 60.0 m at the start, 56.8 m at the end
not reached: seed 1 floor 3 room 1: path to the player 30.1 m at the start, 18.4 m at the end
not reached: seed 2 floor 2 room 1: path to the player 35.1 m at the start, 11.6 m at the end
not reached: seed 2 floor 3 room 1: path to the player 37.5 m at the start, 30.7 m at the end
not reached: seed 3 floor 1 room 1: path to the player 53.1 m at the start, 37.1 m at the end
not reached: seed 3 floor 2 room 1: path to the player 62.5 m at the start, 67.9 m at the end
not reached: seed 3 floor 3 room 1: path to the player 36.0 m at the start, 27.2 m at the end
not reached: seed 4 floor 1 room 1: path to the player 31.4 m at the start, 31.0 m at the end
not reached: seed 4 floor 2 room 1: path to the player 48.5 m at the start, 45.7 m at the end
not reached: seed 4 floor 3 room 1: path to the player 47.2 m at the start, 33.4 m at the end
wall-hug: 15 enemies, 1 reached the player (mean 1502 ticks)

$ godot --headless --path . -s res://build/probe_wall_hug.gd        # P1
not reached: seed 0 floor 3 room 1: path to the player 75.1 m at the start, 4.7 m at the end
wall-hug: 15 enemies, 14 reached the player (mean 1127 ticks)
```

Base: 1 of 15 (most stand still against a wall; some end farther than they started). P1: 14 of 15; the last was
4.7 m away and closing after a 75 m path.

### Probe: a standing player in the open (base only, for the record)
`build/probe_chase.gd` (untracked): with the player in a free cell, every Splitter / Warden placed in a room up to two
doors away reached it on the base code: `total 138 reached 138 slow(>2x) 0 mean ratio 1.10  ms 169913`. The fault is
the blocked goal cell, not the standing case.

### Unit tests (`tests/unit/sim/test_chase_field.gd`, new)
- an enemy in the next room takes the nearer of two doorways and walks about the shortest way (< 19 m; the shortest
  through that door to 2 m short of the player is ~17 m);
- an enemy behind a wall reaches a player pressed against that wall (blocked cell; precondition asserted), through
  the doorway, and ends on the player's side;
- a blocked goal seeds only its own side of a 0.4 m wall (the far side is reached only round through the doorway);
- the field is the octile distance (a cell 6 across and 3 down = 3 diagonals + 3 sides) and equals
  `flood_reference` (a plain label-correcting oracle) over the whole room;
- the world's flood stops past the enemies (a far room unflooded), floods again for a new enemy outside the field
  while the player keeps its cell, and is skipped when nothing changed;
- floods and chases are deterministic (two worlds, the same hash and field).

The behind-a-wall case fails on the base code (the same test body, run against `6da58e4`'s three files; the door case
passed on the base in these layouts too: 8-way ties happened to pick the right door here):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://build/oldcheck/test_chase_old_api.gd -gexit
* test_an_enemy_in_the_next_room_takes_the_nearer_door
* test_an_enemy_behind_a_wall_reaches_a_player_standing_against_it
    [Failed]:  [nan.0] expected to be > than [4.0]:  through the doorway (x 6)
      at line 82
    [Failed]:  [-1.15137267112732] expected to be > than [0.0]:  on the player's side
      at line 84
1/2 passed.
```

### O32: the flood's cost, base vs P1 on the same recorded states
`build/flood_bench.gd` (untracked): FightBot plays 1800 ticks; at every flow-field tick with enemies the player's
position and the enemies' cells are recorded; then each state is flooded by a copy of the base `NavField`
(`build/old_nav_field.gd`), by P1's with the enemy stop, and by P1's without it, interleaved (forced: no skip).
```
$ godot --headless --path . -s res://build/flood_bench.gd           # load average 1.9
horde_floor3: 180 floods (every flow-field tick with enemies, forced), cells 90455; mean ms: base BFS 7.654, P1 5.922 (P1 without the enemy stop 9.193); worst ms: base 12.497, P1 9.908
floor1_spawner: 166 floods (every flow-field tick with enemies, forced), cells 138659; mean ms: base BFS 9.161, P1 5.410 (P1 without the enemy stop 12.901); worst ms: base 19.343, P1 13.836
```
The exact octile flood alone costs ~1.2-1.4x the breadth-first one; stopping past the enemies brings it under the base:
-23 % (horde) and -41 % (floor 1 as played) mean, -21 % / -28 % worst.

### The sim bench, base vs P1 (two back-to-back pairs)
`godot --headless --path . -s scripts/bench/sim_bench.gd`, each pair run back to back at load average ~2 (the JSON
fields as printed; the table is transcribed from the four outputs):

| run | scene | mean_ms | p99_ms | max_ms | realtime_x | over_4ms_on_flow_field_ticks |
|---|---|---|---|---|---|---|
| base 1 | stress | 3.894 | 7.796 | 14.26 | 4.3 | 93 |
| base 1 | reference | 0.619 | 1.067 | 4.703 | 26.9 | 0 |
| base 1 | stress_ai | 3.168 | 13.945 | 40.075 | 5.3 | 265 |
| base 1 | reference_floor | 1.404 | 12.414 | 21.932 | 11.9 | 285 |
| base 1 | reference_boss | 0.772 | 8.372 | 24.173 | 21.6 | 173 |
| base 1 | horde | 6.824 | 23.81 | 85.557 | 2.4 | 278 |
| P1 1 | stress | 3.607 | 7.603 | 27.932 | 4.6 | 61 |
| P1 1 | reference | 0.548 | 1.207 | 4.993 | 30.4 | 0 |
| P1 1 | stress_ai | 3.334 | 16.841 | 36.746 | 5.0 | 273 |
| P1 1 | reference_floor | 1.156 | 11.44 | 17.699 | 14.4 | 258 |
| P1 1 | reference_boss | 0.482 | 3.422 | 8.964 | 34.6 | 29 |
| P1 1 | horde | 6.41 | 20.276 | 25.823 | 2.6 | 285 |
| base 2 | stress | 3.739 | 7.404 | 35.966 | 4.5 | 80 |
| base 2 | reference | 0.556 | 1.1 | 6.634 | 30.0 | 0 |
| base 2 | stress_ai | 3.248 | 14.775 | 36.202 | 5.1 | 266 |
| base 2 | reference_floor | 1.454 | 12.768 | 35.767 | 11.5 | 285 |
| base 2 | reference_boss | 0.825 | 9.943 | 19.344 | 20.2 | 173 |
| base 2 | horde | 6.483 | 21.35 | 36.427 | 2.6 | 278 |
| P1 2 | stress | 3.723 | 7.575 | 31.97 | 4.5 | 68 |
| P1 2 | reference | 0.584 | 1.157 | 5.946 | 28.5 | 0 |
| P1 2 | stress_ai | 3.204 | 15.341 | 35.995 | 5.2 | 275 |
| P1 2 | reference_floor | 1.13 | 11.784 | 17.054 | 14.7 | 255 |
| P1 2 | reference_boss | 0.449 | 2.686 | 9.546 | 37.1 | 30 |
| P1 2 | horde | 6.182 | 18.254 | 42.061 | 2.7 | 285 |

- Faster in both pairs: reference_floor (mean -18 % / -22 %), reference_boss (-38 % / -46 %, p99 8.4 → 3.4 /
  9.9 → 2.7 ms), horde (-6 % / -5 %, p99 -15 % / -15 %).
- **Not faster: stress_ai** (floor 3's sealed boss room, ~60 enemies inside it): mean +5 % / -1 %, p99 +21 % / +4 %.
  Every enemy is in the room, so the stop past them saves little and the exact flood's extra cost per cell shows.
  Reported, not tuned away. The stress scenes (dummy movers, no flow field) move by noise only.
- The bands are unchanged by this step: stress, stress_ai and horde were out of band before and still are (this
  container); reference, reference_floor (P1: 14.4-14.7x, base 11.5-11.9x, band 15x: still under), reference_boss in.

## O25: the Warden ("the large ground-smashing enemy")
The owner's "Smasher" is the Warden (data/enemies/warden.tres: a 2.4 m slam round itself). `EnemyAi.telegraph()`
gives its slam disc `"ground": true` again, so TelegraphViews draws the red circle through the windup (the third
exception to O4's rule with the Arc Caster's rune and the Mine Layer's mines; elites follow their kind). Its model
(`WardenAvatar`): the fists climb overhead and the chest heaves back by 35 % of the windup's progress and hold there,
trembling, to the hit tick; then they come down hard over 0.07 s, the chest pitching forward and the hips dropping,
stay on the ground through the first part of the recovery, and a light dust ring runs out from 0.3 to the full slam
radius (read from the telegraph) over 0.45 s from the impact, fading. Presentation only.

## O26: every melee kind's strike
Shared in `AvatarBase` (starting values): `strike_raise(p)`: full by `STRIKE_RAISE_BY` 0.35 of the windup's progress
(the sim's telegraph progress), then held; the strike starts when a sync first sees the sim's ACTIVE state, snaps out
over `STRIKE_SNAP_S` 0.07 s (accelerating), stays out while active and `STRIKE_HOLD_S` 0.12 s after, then eases back
over `STRIKE_BACK_S` 0.35 s. Frame time only animates what the sim's state started; a windup held at full progress
never strikes by itself (tested).
| Kind | Raised and held | The strike |
|---|---|---|
| Charger, Hatchling | talons raised, body reared (was a 6/s ease) | the talons thrown out ahead as the charge starts, held through the run |
| Swarmer | body rears, mandibles gape | lunge, mandibles bite shut |
| Splitter, Splitling | claws (now hung from the shoulders, out past the body, so they read from the iso camera) lifted high and back | claws chop down through the front |
| Shield Bearer | shield drawn back and tipped up, body leaning in behind it | shield slams out |
| Warden | fists overhead (above) | the overhead slam and dust ring (above) |
The TG tells (crouch, eye glow and flash) stay on top.

## Tests (lint, the folders touched, the e2e that reach the change)
```
$ gdformat --check src scripts tests && gdlint src scripts tests
941 files would be left unchanged
Success: no problems found
$ bash scripts/ci/gut_shard.sh --check
gut_shard: ok (334 test files in 6 shards)
```
- `tests/unit/presentation` (whole folder): `Scripts 97, Tests 689, Passing Tests 689, Asserts 1942779, Time 1070.64s,
  ---- All tests passed! ----`.
- `tests/unit/sim` (whole folder), in three runs because the first hit its 3000 s timeout on a loaded machine:
  run 1 (`-gdir=res://tests/unit/sim`) finished 41 files, 483/484 tests passing; the one failure,
  `test_enemy_fireballs.gd` `test_the_needle_the_sniper_and_the_melee_kinds_keep_their_shapes_off_the_ground`
  ("`[Failed]: kind 3: its body tells the windup`"), was the Warden's circle coming back on purpose: the test now
  expects `"ground": true` for the Warden only. The other 69 files and the two re-run ones in two halves:
  `Scripts 37, Tests 392, Passing Tests 392, ---- All tests passed! ----` and
  `Scripts 34, Tests 339, Passing Tests 339, ---- All tests passed! ----`.
- after the last code change, `tests/golden` + the step's files: `-gdir=res://tests/golden -gtest=...test_chase_field,
  test_horde, test_floor_generator, test_enemy_ground_marks, test_enemy_fireballs, test_melee_strikes,
  test_world_snapshot`: `Scripts 8, Tests 56, Passing Tests 56, ---- All tests passed! ----`
  (`test_replay_ground_plane.gd 2/2`).
- `tests/arch`: `Tests 4, Passing Tests 4, ---- All tests passed! ----`.
- e2e: `test_e2e_enemies, test_e2e_horde_enemies, test_e2e_run_flow, test_e2e_saves, test_e2e_old_save`:
  `Tests 9, Passing Tests 9, Asserts 618, Time 176.541s, ---- All tests passed! ----`.
- Not run locally: the full suite (the PR's shards run it), the bot / balance sims (owner rule).

## Screenshots (`p1_shots/`)
```
$ XDG_DATA_HOME=<empty folder> VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 600 \
    xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1600x900 \
    -s scripts/shots/melee_strikes.gd
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
cell: res://build/shots/v0.7.5-dev/enemies/warden_windup.png
cell: res://build/shots/v0.7.5-dev/enemies/warden_slam.png
cell: res://build/shots/v0.7.5-dev/enemies/splitter_windup.png
cell: res://build/shots/v0.7.5-dev/enemies/splitter_strike.png
cell: res://build/shots/v0.7.5-dev/enemies/shield_bearer_windup.png
cell: res://build/shots/v0.7.5-dev/enemies/charger_windup.png
melee_strikes: res://build/shots/v0.7.5-dev/enemies/melee_strikes.png
```
Copied by hand into `p1_shots/`: `melee_strikes.png` (the sheet) and the six cells: the Warden's held overhead
wind-up over its red circle, the Warden's slam with the dust ring out at its circle, the Splitter's raised claws and
its chop, the Shield Bearer's drawn-back shield, the Charger's raised talons. Software rendering (llvmpipe): the look
on the owner's hardware is OWNER ONLY.

## Goldens changed on purpose
None: `tests/golden` 2/2 passed unchanged (the kernel replays hold no flow field use), the saves fixtures' e2e
(`test_e2e_old_save`, `test_e2e_saves`) pass. Enemy paths on run floors change on purpose (O23).

## Owner only
- Whether chasing now feels right in play, the slam's and the strikes' read and timing: OWNER ONLY.
