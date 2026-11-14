# E2E_FIXED_COST: what does every e2e test pay before its own work starts?

- **Status:** RUN
- **Build:** `130c0b15` on `claude/v0110` (clean worktree `wt-seams`); Godot `4.7.2.stable.official.ed1daf0bf`;
  Windows 11 Pro 10.0.26200
- **Machine:** the owner's PC (i7-10700K, RTX 3060). Run 1 was on a quiet machine. Runs 2 to 5 had another agent's
  Godot processes running (2 to 6 of them), so their milliseconds are rough: read them as proportions.
- **Date:** 2026-11-10
- **Who ran it:** agent (the lead)

## Commands
Run 1, the 26 e2e files of `seams.sh`, against the baseline in [`SEAMS_TIMING.md`](SEAMS_TIMING.md):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<the e2e files in scripts/ci/seams.sh> -gjunit_xml_file=build/e2e_after5.xml -gexit
```
Runs 2 to 5 were scratch GUT tests (not committed) that read `Time.get_ticks_msec()` around `E2e.boot()`,
`E2e.start_from_menu()`, `E2e.landed()`, that print `main.loads.phases` (the game's own load timings), and that
time `ContentRepository.load_all()`, the compilers and `FloorPlan.build()`. For run 5 a scratch copy of
`src/app/floor_plan.gd` and `floor_scenario.gd` had a lap timer after each stage; it was restored afterwards.

## Raw output
Run 1 (quiet machine), seconds per file before step 5 → after it:
```
Tests                59
Passing Tests        59
Time              793.575s
test_e2e_ascension.gd              before  124.4  after  136.1  (3 tests)
test_e2e_damage_soak.gd            before   57.6  after   88.0  (1 tests)
test_e2e_saves.gd                  before   49.4  after   55.5  (3 tests)
test_e2e_final_boss.gd             before   48.8  after   55.6  (1 tests)
test_e2e_run_flow.gd               before   42.5  after   48.7  (3 tests)
test_e2e_builds.gd                 before   41.6  after   48.2  (8 tests)
test_e2e_pad_menus.gd              before   38.1  after   45.4  (5 tests)
test_e2e_boss_signatures_2.gd      before   31.1  after   32.9  (4 tests)
test_e2e_arrival.gd                before   29.6  after   34.4  (2 tests)
test_e2e_boss_signatures.gd        before   29.1  after   32.0  (3 tests)
test_e2e_wand_build.gd             before   28.8  after   27.4  (4 tests)
test_e2e_loading_cover.gd          before   22.8  after   24.8  (1 tests)
test_e2e_bosses_2.gd               before   20.5  after   23.0  (3 tests)
test_e2e_boss_strikes.gd           before   20.2  after   22.0  (1 tests)
test_e2e_horde_enemies.gd          before   19.4  after   20.2  (2 tests)
test_e2e_dev_master_panel.gd       before   14.1  after   15.4  (2 tests)
test_e2e_combo.gd                  before   12.8  after   11.4  (1 tests)
test_e2e_codex.gd                  before   11.4  after   14.9  (3 tests)
test_e2e_curse_room.gd             before   11.4  after   11.5  (1 tests)
test_e2e_achievements.gd           before    8.4  after    7.2  (1 tests)
test_e2e_attack_order.gd           before    7.1  after    7.9  (1 tests)
test_e2e_element_pairs.gd          before    7.1  after    5.9  (1 tests)
test_e2e_health_bars.gd            before    6.3  after    6.5  (1 tests)
test_e2e_shell.gd                  before    5.8  after    6.5  (2 tests)
test_e2e_pad_aim.gd                before    5.4  after    7.0  (1 tests)
test_e2e_old_save.gd               before    3.6  after    4.5  (1 tests)
TOTAL before 697.4 after 793.2
```
Run 2, one e2e start by phase, four starts in one process (ms):
```
PROBE first quick boot=196 start_to_floor=33033 landed=0 sixty_frames=334
PROBE second quick boot=178 start_to_floor=5984 landed=0 sixty_frames=344
PROBE third real boot=194 start_to_floor=6384 landed=1235 sixty_frames=346
PROBE fourth quick boot=199 start_to_floor=5805 landed=0 sixty_frames=358
```
Run 3, the load's own phases on three starts (ms; phases of 40 ms or more):
```
PROBE first start_to_floor=26846 | view_frames=121877 total=25845 view=23018 view:models=7330 world=2439 view:dress=1019 view_longest_step=732 view_longest_job=732 view:shader_warmup=732 view:effects=332 view_parts=327 view:shards_place=176 view:devices=125 view:pack_prefill_explosion_fire_a=57 view:first_sync=57 view:shards=49 view:pack_prefill_p10l_star_hit=45 view:pack_prefill_vx1_hit_ember=41 view_parts_frames=14
PROBE second start_to_floor=5844 | view_frames=20039 total=4948 world=2477 view=2166 view:dress=999 view:models=273 view_longest_step=271 view:effects=271 view_longest_job=271 view_parts=254 view:shards_place=180 view:shards=49 view_parts_frames=11
PROBE third start_to_floor=5978 | view_frames=20398 total=5079 world=2509 view=2249 view:dress=1015 view:models=313 view_longest_step=290 view:effects=290 view_longest_job=290 view_parts=271 view:shards_place=183 view:shards=46 view_parts_frames=12
```
Run 4, the content load and the compilers, three passes in one process (ms):
```
BPROBE load_all=915  enemies=1  bosses=6  items=5  combos=0  abilities=0  stat_cards=0  spells=0  relics=0  starbound=0  room_layouts=16  plan.build (all)=2217  plan.build (repo given)=1907
BPROBE load_all=30  enemies=2  bosses=6  items=6  combos=0  abilities=0  stat_cards=0  spells=1  relics=0  starbound=0  room_layouts=24  plan.build (all)=1508  plan.build (repo given)=1454
BPROBE load_all=29  enemies=1  bosses=7  items=6  combos=0  abilities=0  stat_cards=0  spells=0  relics=0  starbound=0  room_layouts=15  plan.build (all)=2920  plan.build (repo given)=1752
```
Run 5, `FloorPlan.build()` by stage for six seeds (ms; stages of 10 ms or more; `#n` is the n-th call site):
```
BPROBE total=2085 :: EventCompiler.setup #1=416 | boss room+overrun+arenas+lockdowns+routes #1=233 | FloorGenerator.generate #1=232 | set_walls #1=205 | set_walls #3=201 | set_walls #2=195 | prepare_wall #1=194 | prepare_wall #3=187 | prepare_wall #2=179 | floor_tables #1=18 |
BPROBE total=958 :: FloorGenerator.generate #1=234 | set_walls #2=178 | prepare_wall #2=150 | prepare_wall #1=145 | set_walls #1=144 | boss room+overrun+arenas+lockdowns+routes #1=57 | floor_tables #1=17 | compile player+enemies+bosses #1=13 |
BPROBE total=4073 :: FloorGenerator.generate #1=944 | EventCompiler.setup #1=741 | set_walls #2=472 | set_walls #3=402 | prepare_wall #2=378 | prepare_wall #3=357 | set_walls #1=349 | prepare_wall #1=320 | boss room+overrun+arenas+lockdowns+routes #1=66 | floor_tables #1=17 |
BPROBE total=1501 :: EventCompiler.setup #1=384 | FloorGenerator.generate #1=251 | prepare_wall #2=211 | set_walls #1=209 | set_walls #2=195 | prepare_wall #1=189 | floor_tables #1=22 | (before generate) #1=12 | boss room+overrun+arenas+lockdowns+routes #1=10 |
BPROBE total=1937 :: FloorGenerator.generate #1=594 | set_walls #2=497 | set_walls #1=284 | prepare_wall #1=235 | prepare_wall #2=227 | boss room+overrun+arenas+lockdowns+routes #1=54 | floor_tables #1=16 |
BPROBE total=1904 :: FloorGenerator.generate #1=387 | set_walls #2=320 | prepare_wall #2=309 | set_walls #1=298 | prepare_wall #1=289 | boss room+overrun+arenas+lockdowns+routes #1=250 | floor_tables #1=20 |
```

## Target bands
None set.

## Result
| Question | Measured |
|---|---|
| Did step 5 (the direct start) make the seams e2e files faster? | No measurable gain: 697.4 s before, 793.2 s after. The files it changes got about 1.3 s a test faster (combo 12.8 → 11.4, element pairs 7.1 → 5.9, achievements 8.4 → 7.2); the files it does not change came out 5–15 % slower in this run than in the baseline run, which is run-to-run noise larger than the gain |
| What does booting `main.tscn` cost? | 0.2 s |
| What do the hub walk and the arrival cost? | About 0.4 s and 1.2 s (third start against the others) |
| What does a run start cost? | About 6 s once warm; 27–33 s for the first one in a process |
| Where do the warm 6 s go? | The world build about 2.5 s; the view build about 2.2 s (dressing 1.0 s) |
| Is the world build the content load and compile? | No: `load_all` is 30 ms once warm and all compilers together are under 50 ms |
| Where does the world build go? | The walls and paths are built two or three times per floor (`set_walls` + `prepare_wall`: 300–800 ms a pair), 55–65 % of the build; then floor generation (230–940 ms) and `EventCompiler.setup` (0–740 ms) |

## Interpretation
- **Three audit findings were wrong about cost.** T1 put about 20 s a test on the boot, the hub walk and the
  arrival: together they are under 2 s. U3 called the per-floor content load and compile the load-time problem: it
  is under 100 ms. T5 (see PROGRESS) took frame limits for waits. Each was read from the code, not measured.
- **So step 6 (one boot per e2e file) is dropped:** a boot is 0.2 s. Step 30 shrinks to its cheap parts.
- **The real fixed cost of every test that builds a floor, and of every floor the player loads, is the floor
  build itself,** and more than half of it is the same wall and path structures rebuilt two or three times. That is
  step 45.
- **The first run start in a process costs 27–33 s** (models 7.3 s, and 121,877 frames spent waiting in the view
  build). Paid once per Godot process, so it matters to an agent that runs one e2e file at a time: batch them.
- **What this does not show:** quiet-machine milliseconds for runs 2 to 5; step 45 re-measures on a quiet machine.
