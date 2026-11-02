# HORDE_PERF: the sim's cost in big hordes (nav flood, AI, movement)

Why: PERF_PLAYLOG_1 has hordes of 41–60 enemies at 28.1 ms a frame (p99 52.7) against 14.7 ms at 21–40, with
`sim_step` up to 25.4 ms and `phase.nav_flood` up to 17.7 ms in single frames.

Machine: the owner's PC (i7-10700K), local agent session, **while other agents ran Godot in other worktrees**: the
per-tick timings below are noisy (the max column especially). The flood-alone line (min of 60 runs) is the least
noisy number. Base `f33df41c`; "after" is the working tree of this step's commit (the only sim change:
`src/sim/ai/nav_field.gd`).

## The probe

`scripts/checks/horde_phases.gd` (new, writes nothing tracked): floor 3 as `sim_bench.gd` builds it, its horde spots
(the start hall and its neighbours), N real enemies kept alive (Charger, Needle, Warden, Arc Caster, Bomb Drone in
turn), FightBot playing, the hero's HP topped up, 1800 ticks. Per tick it times `World.step` and its phases through
`World.phase_probe` (probe-only; no outcome reads it). Each count also prints a hash chain of `World.state_hash()`
every 60 ticks (`outcome_hash`) and the last tick's hash, then times `NavField.flood` alone, from scratch, 60 times on
the world as the run left it (hero cell, the enemies' cells as targets), with a hash of the distances.

```
G=".../Godot_v4.7.2-stable_win64_console.exe"
git stash push src/sim/ai/nav_field.gd      # before (f33df41c's nav_field.gd)
APPDATA=$(mktemp -d) "$G" --headless --path . -s scripts/checks/horde_phases.gd
git stash pop                               # after
APPDATA=$(mktemp -d) "$G" --headless --path . -s scripts/checks/horde_phases.gd
```

Run back to back on 2026-11-02 (raw output, the `enemies=` and indented lines only):

### Before (f33df41c)

```
enemies=20 ticks=1800 mean_alive=20.0 spawned=32
  step        mean   1.584  p99   6.654  max  19.974 ms
  nav_flood   mean   0.351  p99   3.302  max  11.023 ms
  ai          mean   0.377  p99   2.061  max   5.017 ms
  ai.grid     mean   0.016  p99   0.048  max   0.155 ms
  ai.plan     mean   0.164  p99   0.982  max   3.834 ms
  move        mean   0.422  p99   1.403  max   4.746 ms
  move.steer  mean   0.103  p99   0.342  max   1.732 ms
  move.walls  mean   0.149  p99   0.514  max   3.869 ms
  move.grid   mean   0.030  p99   0.078  max   0.989 ms
  move.pairs  mean   0.089  p99   0.325  max   1.765 ms
  actions     mean   0.070  p99   0.629  max   3.710 ms
  resolve     mean   0.068  p99   0.282  max   1.386 ms
  proj        mean   0.091  p99   0.367  max   5.342 ms
  outcome_hash 4a1a32645f2d3b2330744027583126c1782f5bf39e78f40b824f14158598c26e  final_tick_hash 723c2d7a74a70d94469be1b35deeb11ee202f9a37ac91be6812f79f10de6bd7b
  flood_alone min 2.948  median 3.072 ms  work 5211  cells 90455  targets 20  dist_hash b77f9a47fc0415da05bc9abd15a27dc5b1bdc43a93880983122b62453a107a53
enemies=40 ticks=1800 mean_alive=40.0 spawned=57
  step        mean   3.034  p99  17.307  max  88.210 ms
  nav_flood   mean   0.629  p99   5.447  max  69.997 ms
  ai          mean   0.762  p99   3.983  max  32.903 ms
  ai.grid     mean   0.035  p99   0.127  max   1.250 ms
  ai.plan     mean   0.338  p99   1.773  max  32.063 ms
  move        mean   0.836  p99   4.296  max  34.391 ms
  move.steer  mean   0.222  p99   0.942  max  31.673 ms
  move.walls  mean   0.267  p99   1.289  max  25.557 ms
  move.grid   mean   0.076  p99   0.263  max   9.527 ms
  move.pairs  mean   0.208  p99   0.925  max  11.456 ms
  actions     mean   0.085  p99   0.856  max   3.433 ms
  resolve     mean   0.179  p99   0.604  max  57.139 ms
  proj        mean   0.240  p99   1.964  max  24.531 ms
  outcome_hash a1c13c69efc72ddaf3bc74842a9c4dbf3ae49781f74886dd19488550579a061e  final_tick_hash c7a635b2e571d7526841be4da3e357b0fb7a1b97976f2df15e61df1e18ea9190
  flood_alone min 7.846  median 9.398 ms  work 13515  cells 90455  targets 40  dist_hash b901b8941c4a4df45c811369d9088b6667f94832acb24f1632d60770b55a9ecf
enemies=60 ticks=1800 mean_alive=60.0 spawned=74
  step        mean   3.436  p99  10.281  max 466.870 ms
  nav_flood   mean   0.351  p99   3.489  max   7.923 ms
  ai          mean   1.356  p99   5.347  max 462.888 ms
  ai.grid     mean   0.047  p99   0.190  max   1.843 ms
  ai.plan     mean   0.769  p99   2.492  max 450.103 ms
  move        mean   0.963  p99   3.846  max   7.129 ms
  move.steer  mean   0.290  p99   1.078  max   2.862 ms
  move.walls  mean   0.252  p99   1.232  max   5.055 ms
  move.grid   mean   0.093  p99   0.331  max   2.647 ms
  move.pairs  mean   0.267  p99   1.307  max   3.758 ms
  actions     mean   0.096  p99   0.836  max   3.864 ms
  resolve     mean   0.185  p99   0.804  max  29.789 ms
  proj        mean   0.208  p99   1.081  max   3.239 ms
  outcome_hash 4e7d577d0fa17e17970f745ea49914c4a27de8e21eeb1b8d915b48578806078c  final_tick_hash f3baade1b8c94695b09e3fd49d41622c852db0deecbfd986328aab0dfdffe195
  flood_alone min 2.731  median 3.007 ms  work 4697  cells 90455  targets 60  dist_hash 09627505723bb0b7cd06ef5023a98b69f7ad5fd8d00e6e0a7392701c054e81e4
```

(The 40-enemy run's 70–88 ms and the 60-enemy run's 450–467 ms maxima are single ticks in phases that don't scale
that way anywhere else in the run: the machine stalling under the other agents' jobs, not the sim.)

### After

```
enemies=20 ticks=1800 mean_alive=20.0 spawned=32
  step        mean   1.658  p99   7.946  max  17.690 ms
  nav_flood   mean   0.301  p99   3.764  max   9.619 ms
  ai          mean   0.393  p99   2.231  max   5.037 ms
  ai.grid     mean   0.018  p99   0.061  max   0.633 ms
  ai.plan     mean   0.170  p99   0.976  max   4.063 ms
  move        mean   0.468  p99   2.743  max   6.758 ms
  move.steer  mean   0.118  p99   0.803  max   3.146 ms
  move.walls  mean   0.167  p99   0.919  max   6.328 ms
  move.grid   mean   0.031  p99   0.104  max   0.831 ms
  move.pairs  mean   0.098  p99   0.579  max   2.957 ms
  actions     mean   0.077  p99   0.726  max   3.618 ms
  resolve     mean   0.076  p99   0.448  max   2.502 ms
  proj        mean   0.099  p99   0.610  max   2.589 ms
  outcome_hash 4a1a32645f2d3b2330744027583126c1782f5bf39e78f40b824f14158598c26e  final_tick_hash 723c2d7a74a70d94469be1b35deeb11ee202f9a37ac91be6812f79f10de6bd7b
  flood_alone min 2.238  median 2.392 ms  work 5211  cells 90455  targets 20  dist_hash b77f9a47fc0415da05bc9abd15a27dc5b1bdc43a93880983122b62453a107a53
enemies=40 ticks=1800 mean_alive=40.0 spawned=57
  step        mean   2.537  p99   9.302  max  23.945 ms
  nav_flood   mean   0.383  p99   4.375  max   7.643 ms
  ai          mean   0.741  p99   3.878  max   6.060 ms
  ai.grid     mean   0.037  p99   0.165  max   2.311 ms
  ai.plan     mean   0.319  p99   1.606  max   3.866 ms
  move        mean   0.761  p99   3.472  max   7.450 ms
  move.steer  mean   0.207  p99   1.128  max   5.351 ms
  move.walls  mean   0.248  p99   1.294  max   3.536 ms
  move.grid   mean   0.066  p99   0.315  max   1.686 ms
  move.pairs  mean   0.185  p99   0.898  max   3.771 ms
  actions     mean   0.088  p99   0.970  max   3.829 ms
  resolve     mean   0.128  p99   0.684  max   4.021 ms
  proj        mean   0.181  p99   1.001  max   4.252 ms
  outcome_hash a1c13c69efc72ddaf3bc74842a9c4dbf3ae49781f74886dd19488550579a061e  final_tick_hash c7a635b2e571d7526841be4da3e357b0fb7a1b97976f2df15e61df1e18ea9190
  flood_alone min 5.905  median 7.029 ms  work 13515  cells 90455  targets 40  dist_hash b901b8941c4a4df45c811369d9088b6667f94832acb24f1632d60770b55a9ecf
enemies=60 ticks=1800 mean_alive=60.0 spawned=74
  step        mean   2.971  p99   9.688  max  18.175 ms
  nav_flood   mean   0.279  p99   3.312  max   7.786 ms
  ai          mean   1.021  p99   4.758  max   6.423 ms
  ai.grid     mean   0.047  p99   0.263  max   1.849 ms
  ai.plan     mean   0.451  p99   1.923  max   4.321 ms
  move        mean   0.948  p99   4.114  max  10.021 ms
  move.steer  mean   0.287  p99   1.248  max   5.032 ms
  move.walls  mean   0.251  p99   1.330  max   6.195 ms
  move.grid   mean   0.096  p99   0.443  max   4.457 ms
  move.pairs  mean   0.259  p99   1.105  max   4.311 ms
  actions     mean   0.094  p99   0.969  max   5.324 ms
  resolve     mean   0.161  p99   0.651  max   2.176 ms
  proj        mean   0.202  p99   1.080  max   5.477 ms
  outcome_hash 4e7d577d0fa17e17970f745ea49914c4a27de8e21eeb1b8d915b48578806078c  final_tick_hash f3baade1b8c94695b09e3fd49d41622c852db0deecbfd986328aab0dfdffe195
  flood_alone min 2.014  median 2.093 ms  work 4697  cells 90455  targets 60  dist_hash 09627505723bb0b7cd06ef5023a98b69f7ad5fd8d00e6e0a7392701c054e81e4
```

### Summary

| enemies | flood alone, min (ms) | nav_flood mean / p99 a tick (ms) | ai mean (ms) | move mean (ms) | step mean (ms) |
|---|---|---|---|---|---|
| 20 | 2.948 → 2.238 (−24 %) | 0.351 → 0.301 / 3.302 → 3.764 | 0.377 → 0.393 | 0.422 → 0.468 | 1.584 → 1.658 |
| 40 | 7.846 → 5.905 (−25 %) | 0.629 → 0.383 / 5.447 → 4.375 | 0.762 → 0.741 | 0.836 → 0.761 | 3.034 → 2.537 |
| 60 | 2.731 → 2.014 (−26 %) | 0.351 → 0.279 / 3.489 → 3.312 | 1.356 → 1.021 | 0.963 → 0.948 | 3.436 → 2.971 |

- **Outcomes unchanged:** every `outcome_hash`, `final_tick_hash` and `dist_hash` is the same before and after, at
  20, 40 and 60.
- The flood alone is the clean comparison: about a quarter cheaper. The per-tick columns move by less than the
  machine's noise; ai and move were not changed (their differences are noise).
- The flood's cost follows its work (cells taken from the buckets: 4697–13515 here), which follows how far the
  farthest enemy stands from the hero, not the enemy count itself (the 40 run ended with enemies farther off).
- At 60 enemies this bench's whole tick is about 3 ms on average. The playlog's 41–60 frames (28 ms) are mostly not
  the sim: its own summary has sim at 10 % of the frame and engine + draw at 67 %.

## What changed (`src/sim/ai/nav_field.gd`, `NavField._run`)

The flood's plain case (no standing pillars, away from the bound) is the same Dijkstra with the same steps pushed in
the same order into the same buckets, so its distances, its work count (which decides the build's slices) and its
stop are the same; only the per-step bookkeeping is cheaper:
- a step's cost and bucket are worked out once per bucket (side steps go to cur + ORTHO's, diagonals to cur + DIAG's;
  two buckets, never cur's, as RING > DIAG), and those two buckets' lengths are kept in locals while the bucket empties;
- a cell with all 8 steps (open floor) takes its neighbours by offset (W, E, N, S, NW, NE, SW, SE, the adjacency's
  order) instead of reading the list; other cells read the list, split at the new `_adj_mid` (where its diagonals start).

The near-bound / pillar case is unchanged. `flood_reference` (the parity oracle) is unchanged.

## Proposals not built (they change outcomes; for the owner)

- **More slices** (`NavField.SLICES` 3 → 6): the same flood spread over 6 ticks instead of 3: each tick's flood share
  roughly halves (60 enemies here, from the flood-alone min of 2.014 ms: about 0.34 ms a slice instead of 0.67), but the
  field enemies follow is swapped in 3 ticks later, so paths and every later hash change. NOT YET RUN as a build.
- **A tighter flood bound** (`WORLD_FLOOD_STEPS` 160, or `TARGET_MARGIN`): the flood's cost follows the farthest enemy;
  a smaller bound cuts the far rooms' cells, but the enemies past it walk straight. Changes outcomes. NOT YET RUN.
- AI and movement: at 60 enemies `ai` is about 1.0–1.4 ms and `move` about 1.0 ms a tick here, spread over plan,
  steer, walls, grid and pairs (each 0.05–0.8 ms). Earlier passes (v0.4.0 SC, v0.8.0 HS) already took the cheap wins;
  what's left is float arithmetic whose order fixes the hashes. No quick outcome-safe win found; not changed.

## Tests

`G=... ; APPDATA=$(mktemp -d) "$G" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <dir or tests> -gexit`,
on the after tree (raw GUT totals):

```
-gdir=res://tests/golden -ginclude_subdirs
Tests 2 / Passing Tests 2 / Asserts 4 / ---- All tests passed! ----
-gdir=res://tests/arch -ginclude_subdirs
Tests 4 / Passing Tests 4 / Asserts 19284 / ---- All tests passed! ----
-gtest=tests/unit/sim/{test_chase_field,test_enemy_ai,test_horde,test_horde_enemies,test_collision,
       test_movement_feel,test_world_snapshot,test_closed_fights}.gd
Scripts 8 / Tests 91 / Passing Tests 91 / Asserts 17443 / Time 468.136s / ---- All tests passed! ----
-gtest=res://tests/unit/sim/test_floor_generator.gd   (the fast flood against flood_reference on generated floors)
Tests 10 / Passing Tests 10 / Asserts 442741 / Time 126.883s / ---- All tests passed! ----
```

Lint: `gdformat --check src scripts tests && gdlint src scripts tests` → "1579 files would be left unchanged",
"Success: no problems found".
