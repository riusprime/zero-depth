# SEAMS_TIMING: where does the seams run spend its time?

- **Status:** RUN (before: `ee42eafa`; after: `060e883b`, at the end of this page)
- **Build:** `ee42eafa` on `claude/v0110` (clean worktree `wt-seams`); Godot `4.7.2.stable.official.ed1daf0bf`;
  Windows 11 Pro 10.0.26200
- **Machine:** the owner's PC (i7-10700K, RTX 3060). No other Godot process ran during the run.
- **Date:** 2026-11-10
- **Who ran it:** agent (the lead)

## Command
```
cd C:/Users/extri/Desktop/zerodepth/wt-seams
export PATH="/c/Users/extri/Desktop/zerodepth/gbin:/c/Users/extri/AppData/Local/Python/pythoncore-3.14-64/Scripts:$PATH"
export APPDATA="C:/Users/extri/Desktop/zerodepth/wt-seams/build/appdata"
S=$(date +%s); bash scripts/ci/seams.sh > build/seams_timing_run.log 2>&1; echo "exit=$? seconds=$(( $(date +%s)-S ))"
```
The per-file and per-test seconds are the `time` attributes of `build/seams.xml` (GUT's JUnit file, added to
`seams.sh` in step 1), summed per `testsuite`.

## Raw output
```
exit=0 seconds=3442 sha=ee42eafa
```
```
Totals
Scripts             114
Tests               669
Passing Tests       669
Asserts           91036
Time              3185.246s
---- All tests passed! ----
```
The 25 slowest of the 114 files (seconds, share of the 3,180.7 s the tests sum to, tests in the file):
```
 1619.0 s   50.9%   10 tests  tests/unit/sim/test_five_floors.gd
  181.4 s    5.7%    7 tests  tests/unit/sim/test_modifier_smoke.gd
  152.0 s    4.8%   16 tests  tests/unit/sim/test_world_snapshot.gd
  124.4 s    3.9%    3 tests  tests/e2e/test_e2e_ascension.gd
   59.4 s    1.9%   14 tests  tests/unit/application/test_old_saves.gd
   57.6 s    1.8%    1 tests  tests/e2e/test_e2e_damage_soak.gd
   49.4 s    1.6%    3 tests  tests/e2e/test_e2e_saves.gd
   48.8 s    1.5%    1 tests  tests/e2e/test_e2e_final_boss.gd
   46.4 s    1.5%    5 tests  tests/unit/sim/test_boss_pace.gd
   44.8 s    1.4%   16 tests  tests/unit/sim/test_final_pace.gd
   42.5 s    1.3%    3 tests  tests/e2e/test_e2e_run_flow.gd
   41.6 s    1.3%    8 tests  tests/e2e/test_e2e_builds.gd
   38.1 s    1.2%    5 tests  tests/e2e/test_e2e_pad_menus.gd
   36.0 s    1.1%    5 tests  tests/unit/application/test_balance_tools.gd
   31.1 s    1.0%    4 tests  tests/e2e/test_e2e_boss_signatures_2.gd
   29.6 s    0.9%    2 tests  tests/e2e/test_e2e_arrival.gd
   29.1 s    0.9%    3 tests  tests/e2e/test_e2e_boss_signatures.gd
   28.8 s    0.9%    4 tests  tests/e2e/test_e2e_wand_build.gd
   25.6 s    0.8%    8 tests  tests/unit/app/test_training_room.gd
   24.4 s    0.8%    2 tests  tests/unit/app/test_floor_plan.gd
   22.8 s    0.7%    1 tests  tests/e2e/test_e2e_loading_cover.gd
   21.9 s    0.7%    4 tests  tests/unit/sim/test_readable_cause.gd
   20.5 s    0.6%    3 tests  tests/e2e/test_e2e_bosses_2.gd
   20.3 s    0.6%   11 tests  tests/unit/application/test_runic_triggers.gd
   20.2 s    0.6%    1 tests  tests/e2e/test_e2e_boss_strikes.gd
```
Inside the three slowest files (seconds per test):
```
tests/unit/sim/test_five_floors.gd
    1549.9  test_generation_holds_for_every_floor_over_a_thousand_seeds
      44.7  test_loot_follows_the_floor_size
      17.0  test_a_built_floor_spawns_its_biomes_roster
       6.4  test_a_run_goes_through_five_floors_to_the_ascension_portal
       0.6  test_every_floor_spawns_only_its_biomes_roster_over_a_thousand_seeds
tests/unit/sim/test_modifier_smoke.gd
     115.0  test_every_pair_of_modifiers_runs
      31.6  test_every_modifier_alone_on_each_weapon_runs_and_replays
      21.3  test_the_ability_modifiers_carry_every_modifier_and_replay
tests/unit/sim/test_world_snapshot.gd
      43.2  test_round_trip_on_many_seeds_floors_and_ticks
      19.5  test_round_trip_in_a_boss_fight
      15.3  test_round_trip_while_the_flood_is_built
```
```
e2e files total 697.4 s over 59 tests
```

## Target bands
None set. This is a baseline; step 11 reports the same numbers after Wave 1.

## Result
| Metric | Measured |
|---|---|
| Wall time, import + lint + tests | 3,442 s |
| GUT time | 3,185.2 s, 669 of 669 passing |
| One test, `test_generation_holds_for_every_floor_over_a_thousand_seeds` | 1,549.9 s (48.7 % of the tests' time) |
| The 29 e2e files | 697.4 s, 59 tests: 11.8 s a test |

## Interpretation
- **Half the seams run is one test that is not a seam.** `test_five_floors.gd` is in `seams.sh` for its roster
  test, which takes 0.6 s. The 1,000-seed generation test in the same file takes 1,549.9 s. Step 2 (run seam tests,
  not whole files) removes it from seams; steps 3 and 4 make it cheaper where it still runs (GitHub).
- **The e2e tests cost 11.8 s each here,** lower than the audit's estimate of about 20 s, which came from a
  different group of files in an older log. Steps 5 to 7 work on this.
- **What this does not show:** the files outside seams. The GitHub shards record their own JUnit files.

---

## After Waves 1 and 2 (step 11)

- **Build:** `060e883b` on `claude/v0110` (clean worktree `wt-seams`); the same machine, Godot and command as above;
  no other Godot process ran. 2026-11-10, the lead.
- **What is in it:** Wave 1 (steps 1–5, 7–10), step 45, and Wave 2 except step 18 (comments only, committed after
  this run) and the test floor builder's opt-in (timed separately below).

### Raw output
```
exit=0 seconds=1606 sha=060e883b
```
```
Scripts             117
Tests               674
Passing Tests       674
Asserts           89310
Time              1395.816s
---- All tests passed! ----
```
Per file, seconds before → after (the 22 slowest of the before run):
```
files before 114 after 117 | tests before 669 after 674 | seconds before 3180.7 after 1391.3
e2e files before 697.4 after 614.5
unit/sim/test_five_floors.gd                     1619.0 ->     21.7
unit/sim/test_modifier_smoke.gd                   181.4 ->    148.7
unit/sim/test_world_snapshot.gd                   152.0 ->    147.3
e2e/test_e2e_ascension.gd                         124.4 ->    115.5
unit/application/test_old_saves.gd                 59.4 ->     54.6
e2e/test_e2e_damage_soak.gd                        57.6 ->     53.3
e2e/test_e2e_saves.gd                              49.4 ->     42.2
e2e/test_e2e_final_boss.gd                         48.8 ->     46.1
unit/sim/test_boss_pace.gd                         46.4 ->     41.0
unit/sim/test_final_pace.gd                        44.8 ->     41.7
e2e/test_e2e_run_flow.gd                           42.5 ->     37.9
e2e/test_e2e_builds.gd                             41.6 ->     36.0
e2e/test_e2e_pad_menus.gd                          38.1 ->     35.1
unit/application/test_balance_tools.gd             36.0 ->     20.8
e2e/test_e2e_boss_signatures_2.gd                  31.1 ->     24.4
e2e/test_e2e_arrival.gd                            29.6 ->     28.8
e2e/test_e2e_boss_signatures.gd                    29.1 ->     24.5
e2e/test_e2e_wand_build.gd                         28.8 ->     22.4
unit/app/test_training_room.gd                     25.6 ->     23.2
unit/app/test_floor_plan.gd                        24.4 ->     13.5
e2e/test_e2e_loading_cover.gd                      22.8 ->     22.2
unit/sim/test_readable_cause.gd                    21.9 ->     20.0
```
The test floor builder opted into step 45's single flow-field build (`26bdbb20`, measured after this run on the
same quiet machine; ten files in one process, 96 of 96 passing):
```
unit/sim/test_world_snapshot.gd              seams run   147.3 -> with the test builder opted in   103.2
unit/application/test_old_saves.gd           seams run    54.6 -> with the test builder opted in    32.7
unit/application/test_run_saves.gd           seams run    10.3 -> with the test builder opted in     5.1
unit/sim/test_intensity_director.gd          seams run     8.0 -> with the test builder opted in     6.4
unit/app/test_floor_plan.gd                  seams run    13.5 -> with the test builder opted in    13.3
unit/sim/test_boss_pace.gd                   seams run    41.0 -> with the test builder opted in    41.1
```

### Result
| Metric | Before (`ee42eafa`) | After (`060e883b`) |
|---|---|---|
| Wall time, import + lint + tests | 3,442 s (57 min) | 1,606 s (27 min) |
| GUT time | 3,185.2 s | 1,395.8 s |
| Tests | 669 of 669 | 674 of 674 |
| The 26 e2e files | 697.4 s | 614.5 s |

### Interpretation
- **The seams run is 2.1 times faster.** 1,597 s of the 1,790 s saved is one change: the 5,000-floor generation
  test is no longer in seams (step 2). The rest is spread: the duplicate smoke test (step 8), the floor build (step
  45) and the direct e2e start (step 5).
- **The e2e files are 12 % faster** (697.4 s → 614.5 s). Step 5 alone had shown no measurable gain
  ([`E2E_FIXED_COST.md`](E2E_FIXED_COST.md)); the difference here is step 45's shorter floor build.
- **Not in these numbers:** the test floor builder's opt-in. It takes about 70 s more off the floor-heavy files
  above, so the next seams run should be near 1,330 s of tests. That is an expectation until it is run.
- **What is left in seams:** `test_modifier_smoke.gd` (149 s, the every-card seam itself), `test_world_snapshot.gd`
  (103 s) and `test_e2e_ascension.gd` (116 s, three runs to the final arena) are the three biggest.
