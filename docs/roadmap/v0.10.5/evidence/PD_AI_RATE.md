# PD_AI_RATE: enemies plan and re-path at half rate

Why: PERF_PLAYLOG_2 (fights of 41+ enemies: the sim at 3.6 ms a frame, a late frame running 1.3+ ticks). The owner
approved option 9 of perf wave 2 ("let's do it"); it changes outcomes.

Machine: the owner's PC (i7-10700K), local agent session; other agents may have run Godot in other worktrees at the
same time, so the per-tick columns carry noise (the max column most). Base `1f309fd5`; "after" is this step's commit.

## What changed

| Cadence | Before | After |
|---|---|---|
| `EnemyAi.PLAN_PERIOD` (each enemy's walk plan: direction, spread off its neighbours, the flow field when blocked; staggered by `id % PLAN_PERIOD`; elites use the same `plans_now`) | 4 ticks | 8 ticks |
| The plan's wall check (`_blocked`, the line sweep that decides "follow the flow field") | every other plan = every 8 ticks | every plan = every 8 ticks (unchanged rate) |
| `NavField.SLICES` (the periodic flood, every `PERIOD` = 12 ticks, built over this many ticks, then swapped in) | 3 | 6 |

Unchanged, every tick: think's state machine (the attack check and start, windups, aim tracking, active and recover,
cooldowns), `move` (walking along the last plan), the hits, the slow turners' turn, `PERIOD` 12.

Why the wall check stays at 8 ticks: a first build halved it too (every 16 ticks); its play check had the longest far
idle at 24 ticks against 13 before (below, "variant A"). Keeping the sweep's rate brought it back to 14.

## Per-phase ms (scripts/checks/horde_phases.gd)

```
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
APPDATA=$(mktemp -d) "$G" --headless --path . -s scripts/checks/horde_phases.gd     # before (1f309fd5), then after
```

Means a tick (p99 in brackets for the flood), from the raw output below:

| enemies | ai | ai.plan | nav_flood mean [p99] | ai + nav_flood | move | step |
|---|---|---|---|---|---|---|
| 20 | 0.291 → 0.225 | 0.123 → 0.077 | 0.216 → 0.156 [1.778 → 0.748] | 0.507 → 0.381 | 0.340 → 0.317 | 1.139 → 0.995 |
| 40 | 0.686 → 0.455 | 0.302 → 0.165 | 0.343 → 0.272 [3.982 → 1.239] | 1.029 → 0.727 | 0.745 → 0.583 | 2.351 → 1.729 |
| 60 | 0.815 → 0.665 | 0.358 → 0.249 | 0.218 → 0.218 [1.763 → 0.952] | 1.033 → 0.883 | 0.761 → 0.767 | 2.322 → 2.214 |

- `ai.plan` falls by 30–45 %. Not a full half: the wall sweep keeps its rate.
- More slices spread the same flood over more ticks: its mean a tick is about the same, its p99 (the flood ticks)
  roughly halves. The flood's own cost (flood_alone) did not change; its work follows where the enemies stand.
- The outcome hashes change (on purpose: the plans and the field differ); the run is still deterministic (the golden
  replays below pass, re-run from the regenerated fixtures).
- move and step move with the run (different paths, different crowds); read them as noise.

### Raw output

```
### phases_before
enemies=20 ticks=1800 mean_alive=20.0 spawned=32
  step        mean   1.139  p99   3.298  max  16.218 ms
  nav_flood   mean   0.216  p99   1.778  max   6.567 ms
  ai          mean   0.291  p99   0.580  max   0.769 ms
  ai.grid     mean   0.013  p99   0.037  max   0.107 ms
  ai.plan     mean   0.123  p99   0.306  max   0.377 ms
  move        mean   0.340  p99   0.633  max   1.396 ms
  move.steer  mean   0.086  p99   0.172  max   0.230 ms
  move.walls  mean   0.121  p99   0.230  max   0.925 ms
  move.grid   mean   0.025  p99   0.065  max   0.101 ms
  move.pairs  mean   0.076  p99   0.143  max   0.197 ms
  actions     mean   0.045  p99   0.381  max   1.866 ms
  resolve     mean   0.053  p99   0.122  max   0.193 ms
  proj        mean   0.070  p99   0.212  max   0.523 ms
  outcome_hash 4a1a32645f2d3b2330744027583126c1782f5bf39e78f40b824f14158598c26e  final_tick_hash 723c2d7a74a70d94469be1b35deeb11ee202f9a37ac91be6812f79f10de6bd7b
  flood_alone min 2.136  median 2.194 ms  work 5211  cells 90455  targets 20  dist_hash b77f9a47fc0415da05bc9abd15a27dc5b1bdc43a93880983122b62453a107a53
enemies=40 ticks=1800 mean_alive=40.0 spawned=57
  step        mean   2.351  p99  13.197  max 117.238 ms
  nav_flood   mean   0.343  p99   3.982  max  20.430 ms
  ai          mean   0.686  p99   1.909  max  41.180 ms
  ai.grid     mean   0.040  p99   0.073  max   9.379 ms
  ai.plan     mean   0.302  p99   0.722  max  40.436 ms
  move        mean   0.745  p99   1.778  max  80.934 ms
  move.steer  mean   0.175  p99   0.461  max   2.160 ms
  move.walls  mean   0.296  p99   0.543  max  79.865 ms
  move.grid   mean   0.075  p99   0.159  max  28.986 ms
  move.pairs  mean   0.161  p99   0.390  max   3.717 ms
  actions     mean   0.065  p99   0.716  max   3.029 ms
  resolve     mean   0.102  p99   0.291  max   1.235 ms
  proj        mean   0.159  p99   0.561  max   8.806 ms
  outcome_hash a1c13c69efc72ddaf3bc74842a9c4dbf3ae49781f74886dd19488550579a061e  final_tick_hash c7a635b2e571d7526841be4da3e357b0fb7a1b97976f2df15e61df1e18ea9190
  flood_alone min 5.760  median 11.123 ms  work 13515  cells 90455  targets 40  dist_hash b901b8941c4a4df45c811369d9088b6667f94832acb24f1632d60770b55a9ecf
enemies=60 ticks=1800 mean_alive=60.0 spawned=74
  step        mean   2.322  p99   5.119  max  20.600 ms
  nav_flood   mean   0.218  p99   1.763  max   5.848 ms
  ai          mean   0.815  p99   1.666  max  17.409 ms
  ai.grid     mean   0.037  p99   0.093  max   0.127 ms
  ai.plan     mean   0.358  p99   0.799  max   3.478 ms
  move        mean   0.761  p99   1.530  max   8.604 ms
  move.steer  mean   0.237  p99   0.468  max   1.213 ms
  move.walls  mean   0.194  p99   0.438  max   1.302 ms
  move.grid   mean   0.075  p99   0.186  max   0.392 ms
  move.pairs  mean   0.215  p99   0.459  max   0.913 ms
  actions     mean   0.058  p99   0.599  max   1.369 ms
  resolve     mean   0.128  p99   0.297  max   1.420 ms
  proj        mean   0.164  p99   0.619  max   1.829 ms
  outcome_hash 4e7d577d0fa17e17970f745ea49914c4a27de8e21eeb1b8d915b48578806078c  final_tick_hash f3baade1b8c94695b09e3fd49d41622c852db0deecbfd986328aab0dfdffe195
  flood_alone min 2.062  median 2.807 ms  work 4697  cells 90455  targets 60  dist_hash 09627505723bb0b7cd06ef5023a98b69f7ad5fd8d00e6e0a7392701c054e81e4
   at: cleanup (core/object/object.cpp:2536)
   at: clear (core/io/resource.cpp:822)
   at: ~PagedAllocator (./core/templates/paged_allocator.h:170)
   at: ~PagedAllocator (./core/templates/paged_allocator.h:170)
### phases_after_b
enemies=20 ticks=1800 mean_alive=20.0 spawned=32
  step        mean   0.995  p99   1.953  max  12.500 ms
  nav_flood   mean   0.156  p99   0.748  max   4.585 ms
  ai          mean   0.225  p99   0.385  max   0.504 ms
  ai.grid     mean   0.012  p99   0.025  max   0.085 ms
  ai.plan     mean   0.077  p99   0.170  max   0.282 ms
  move        mean   0.317  p99   0.518  max   0.645 ms
  move.steer  mean   0.082  p99   0.137  max   0.186 ms
  move.walls  mean   0.109  p99   0.181  max   0.254 ms
  move.grid   mean   0.023  p99   0.047  max   0.074 ms
  move.pairs  mean   0.071  p99   0.118  max   0.150 ms
  actions     mean   0.044  p99   0.416  max   1.370 ms
  resolve     mean   0.051  p99   0.135  max   0.199 ms
  proj        mean   0.077  p99   0.200  max   0.357 ms
  outcome_hash a4ac5c68feebf63b3f89593d398fda7fb079044520aabe0e7605731aa2b5f870  final_tick_hash cb132ea9b8f86e3194288bc4787f63290bce40383d5f3827b9b199a2ebb6d58e
  flood_alone min 1.946  median 2.139 ms  work 4617  cells 90455  targets 20  dist_hash 7129b1d78a9b3b1a23042e9d09611e0c67ef2e87fe22ca06dc2684d5cf0f4fb0
enemies=40 ticks=1800 mean_alive=40.0 spawned=59
  step        mean   1.729  p99   3.251  max  14.728 ms
  nav_flood   mean   0.272  p99   1.239  max   5.127 ms
  ai          mean   0.455  p99   0.828  max   2.412 ms
  ai.grid     mean   0.024  p99   0.052  max   0.078 ms
  ai.plan     mean   0.165  p99   0.354  max   0.683 ms
  move        mean   0.583  p99   1.039  max   1.307 ms
  move.steer  mean   0.157  p99   0.296  max   0.472 ms
  move.walls  mean   0.202  p99   0.367  max   0.474 ms
  move.grid   mean   0.045  p99   0.094  max   0.118 ms
  move.pairs  mean   0.144  p99   0.254  max   0.384 ms
  actions     mean   0.055  p99   0.575  max   1.397 ms
  resolve     mean   0.092  p99   0.196  max   0.241 ms
  proj        mean   0.112  p99   0.268  max   0.368 ms
  outcome_hash b397baaaf9bd3ec6d78ff226774d428b0c490765f599f21d2c1103f528abf94b  final_tick_hash 19d7f5389b4a0947346a2afea30539f4e9052d2572934547ad36beec24329618
  flood_alone min 5.501  median 5.720 ms  work 12549  cells 90455  targets 40  dist_hash b107be9419917de66a49cbdc2f478c1a7ca73c803f74d9daf0aef9513381982f
enemies=60 ticks=1800 mean_alive=60.0 spawned=71
  step        mean   2.214  p99   4.036  max  13.830 ms
  nav_flood   mean   0.218  p99   0.952  max   4.525 ms
  ai          mean   0.665  p99   1.261  max   1.848 ms
  ai.grid     mean   0.037  p99   0.075  max   0.101 ms
  ai.plan     mean   0.249  p99   0.495  max   0.626 ms
  move        mean   0.767  p99   1.457  max   1.707 ms
  move.steer  mean   0.241  p99   0.459  max   0.674 ms
  move.walls  mean   0.193  p99   0.396  max   0.586 ms
  move.grid   mean   0.072  p99   0.144  max   0.228 ms
  move.pairs  mean   0.221  p99   0.425  max   0.643 ms
  actions     mean   0.064  p99   0.570  max   1.420 ms
  resolve     mean   0.129  p99   0.253  max   0.647 ms
  proj        mean   0.178  p99   0.488  max   0.740 ms
  outcome_hash 3e01d7012de0acd7aa16ed3662c64cf1e666a915a5df591e8c8ecc5c01928dde  final_tick_hash 217d4120735c2779c04d038cc9987865fa0e7a57e38dffc6bafb6b3986d6d724
  flood_alone min 1.953  median 2.009 ms  work 4668  cells 90455  targets 60  dist_hash 5aa46bf9acdd0b61b06d22003bd05c8956ddd2102653b8d9ce6bbc1a0176d3bb
   at: cleanup (core/object/object.cpp:2536)
   at: clear (core/io/resource.cpp:822)
   at: ~PagedAllocator (./core/templates/paged_allocator.h:170)
   at: ~PagedAllocator (./core/templates/paged_allocator.h:170)
```

## Play check (scripts/checks/horde_play_check.gd)

The horde_phases setup (floor 3, its horde spots, FightBot, hero HP topped up, 20 horde enemies kept alive), seeds
20261007, 11 and 777, 1800 ticks (30 s) each. Attacks started = entries into WINDUP; mean distance = every live
enemy, every tick; far idle = an enemy in MOVE, more than its attack range + 1 m from the hero, that moved < 0.01 m
that tick (keep-away kinds holding their band and enemies queued behind a crowd count too), and the longest such run
of one enemy.

```
APPDATA=$(mktemp -d) "$G" --headless --path . -s scripts/checks/horde_play_check.gd
```

(The before run used the same script from `build/pd_play_check.gd`, before it was moved into `scripts/checks/`.)

| | attacks started (3 seeds) | mean distance (m, mean of seeds) | far idle enemy-ticks | longest far idle (ticks) |
|---|---|---|---|---|
| before (PLAN 4, wall check 8, SLICES 3) | 352 | 10.92 | 3451 | 13 |
| variant A (PLAN 8, wall check 16, SLICES 6), not kept | 360 | 10.63 | 3263 | 24 |
| after (PLAN 8, wall check 8, SLICES 6) | 349 | 10.68 | 3910 | 14 |

- Enemies still reach and attack the hero: attacks about the same (−1 %), distance about the same (−0.2 m).
- Far idle enemy-ticks +13 % (3451 → 3910), the longest run 13 → 14 ticks (0.23 s); one 30-s run per seed, so each
  seed's number moves a lot between builds (seed 11: 1703 / 1213 / 1772). No enemy stands far off longer than about a
  quarter second in any of the runs.
- Feel (do the crowds look slower to react, stick on corners): OWNER ONLY.

### Raw output

```
### play_before
PLAY| seed=20261007 spawned=32 attacks_started=106 mean_dist=12.209 m far_idle_ticks=1212 longest_idle=13 final=723c2d7a74a70d94469be1b35deeb11ee202f9a37ac91be6812f79f10de6bd7b
PLAY| seed=11 spawned=29 attacks_started=113 mean_dist=11.691 m far_idle_ticks=1703 longest_idle=5 final=d2543b202f2ab6f7f46c9b646e90413d8767bbb245dd1287a164ad44bbb28da6
PLAY| seed=777 spawned=29 attacks_started=133 mean_dist=8.862 m far_idle_ticks=536 longest_idle=8 final=36876c990315074a40f5241cc92dde62ec66051ff0de2f94cf7d15ecb43ac7e2
### play_after
PLAY| seed=20261007 spawned=28 attacks_started=101 mean_dist=12.553 m far_idle_ticks=1339 longest_idle=8 final=a4eab404381a29e7cf08631f3fbabd3db7202dcd5105a4f944cdb197b550e91f
PLAY| seed=11 spawned=29 attacks_started=124 mean_dist=10.382 m far_idle_ticks=1213 longest_idle=24 final=903b215f2fe133efddee394554930f71911ff1174d13eb67badacd7b87146fb4
PLAY| seed=777 spawned=28 attacks_started=135 mean_dist=8.943 m far_idle_ticks=711 longest_idle=13 final=d847c6e71678b9545712ed005002a25b681f9572268ef2a32db1ac96e0209b3a
### play_after_b
PLAY| seed=20261007 spawned=32 attacks_started=115 mean_dist=11.185 m far_idle_ticks=1290 longest_idle=7 final=cb132ea9b8f86e3194288bc4787f63290bce40383d5f3827b9b199a2ebb6d58e
PLAY| seed=11 spawned=31 attacks_started=110 mean_dist=11.515 m far_idle_ticks=1772 longest_idle=14 final=7c282503bd26740f2171dec21a1709e7a4acc1cac8d3d4b8e185b36f789d1ec9
PLAY| seed=777 spawned=31 attacks_started=124 mean_dist=9.328 m far_idle_ticks=848 longest_idle=11 final=ed5666ebeb8ef2f5f5c97adc04f1e1f191d7d8d6bb57d1657dbd38972a178bb2
```

## Goldens

Regenerated with the project's tools (`tests/golden/generate_replay_ground_plane.gd`,
`generate_modifier_equivalence.gd`, `generate_export_smoke_hash.gd`):

```
GOLD| final=70ac7ca24761c818e8e103b4281da76358e98e880d80ff54754adefa0bfd0add checkpoints=166 (6706 ms)
GOLD| blade_plain 38bbd00d8084d0bf2828a7c026b609b26377ab2987676aa461215c7dc999943f hits=181 damage=4002 kills=10
GOLD| gun_plain f1a7270159f8496d1c64977d19228544f964191b83966b540b2902f096d80349 hits=82 damage=449 kills=0
GOLD| both_plain 646ea5f5de91bcb116af36e14ff9d5a7791b449d5eb0a826b6888bcfe2e6ff05 hits=210 damage=3716 kills=5
GOLD| blade_wildfire_rider d0e25aa413b2e8caa472462de8b36eaff140558b1d4b72b391ab1c024bd2b659 hits=131 damage=4160 kills=14
GOLD| gun_frost_core 8d95d2c2147af0c91982d96e81b630a469b21d20b5b5aba3fa0e40264e56a521 hits=82 damage=449 kills=0
GOLD| export_smoke_hash=e5365ddb6dcb34ea26a29e09fed8cc9e4325d3d89881d590b2a7c4210d9d7391
```

**No golden file changed** (`git status` clean for `tests/golden/fixtures/` after the regeneration): the replay's
`final` and the export smoke hash are the old ones. These scenarios have no walking enemies (training dummies), so
the plan and flood cadence never reach them.

## Tests

`APPDATA=$(mktemp -d) "$G" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <dir or tests> -gexit`, raw
GUT totals:

```
-gtest=tests/unit/sim/{test_chase_field,test_enemy_ai,test_horde,test_horde_enemies,test_collision,
       test_movement_feel,test_world_snapshot,test_closed_fights,test_elites,test_floor_generator}.gd
Tests 122 / Passing Tests 121 / Failing Tests 1 / Asserts 460453/460454 / Time 646.763s
  res://tests/unit/sim/test_horde.gd - test_plans_are_spread_evenly_over_the_ticks
    [Failed]: Unexpected Errors: Out of bounds get index '4' (on base: 'Array')
```

The failure: the test pinned 4 phases (`[10, 10, 10, 10]`). It now sizes its phases by `EnemyAi.PLAN_PERIOD` and
expects an even share (5 of 40 on each of 8 phases). Only that file re-run:

```
-gtest=res://tests/unit/sim/test_horde.gd
Tests 6 / Passing Tests 6 / Asserts 11067 / ---- All tests passed! ----
-gdir=res://tests/golden -ginclude_subdirs   (after the regeneration)
Tests 2 / Passing Tests 2 / Asserts 4 / ---- All tests passed! ----
-gdir=res://tests/arch -ginclude_subdirs     (with scripts/checks/horde_play_check.gd in the tree)
Tests 4 / Passing Tests 4 / Asserts 19360 / ---- All tests passed! ----
gdformat --check src scripts tests  ->  1588 files would be left unchanged
gdlint src scripts tests            ->  Success: no problems found
```

Not run here: the full suite, the e2e, the seed-loop tests (test_curse_room.gd); the seams are the lead's.
