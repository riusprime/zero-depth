# BOSS_ROOM: does the Siege Engine fight in a 3×3 arena, and does the fight still work there? (v0.6.5 BR, W2)

- **Status:** RUN (tests, lint, probe); screenshot NOT YET RUN
- **Build:** `edd2187` on `claude/lucid-fermat-9wv2tf` plus this step's working-tree diff (committed as
  `v0.6.5 Step BR: the cannon boss fights in a 3×3 arena`); Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`
- **Date:** 2026-10-12
- **Who ran it:** agent

## The change
- `data/bosses/siege_engine.tres`: `arena_cells = Vector2i(3, 1)` → `Vector2i(3, 3)` (owner pick "3×3"). Template stays
  `lines` (5); every attack, the closing band and the hazard values are unchanged.
- Nothing else needed a fix. What was checked:
  - **Floor generation:** `BossRoomBuilder` is size-generic (the Gatekeeper is already 3×3); the boss room and its
    host fit on every seed of the 200-seed builder property, the 1,000-seed shop and event-room properties, the
    300-seed arena property and the Deep-gate property, which all draw the real boss specs.
  - **The `lines` template:** `RoomInterior._lines` sizes itself from the room (2–3 broken lines across the long
    axis); a 3×3 `lines` case was added to `test_other_sizes_and_templates`.
  - **Attacks:** none assume the corridor. `rail_sweep` is an arc (110°, 13 m reach) aimed at the player; the
    bolts (16 m) and the barrage (30 m) are aimed too; the boss walks in to `keep_distance_m` 7 m; the gap-closer
    (bolts after 2 s beyond 12 m) and the punish (shockwave, 40 m radius, after 4 s beyond 9 m) cover a far player.
    The probe below: the farthest interior corner from the boss's spawn is 32.37 m at most over 40 seeds, inside
    the shockwave's 40 m.
  - **The closing band:** `BossChallenge.band_depth` already scales per axis with the arena (the boss room's
    interior) and stops `arena_safe_half_m` (5 m) short of the centre. In the 3×1 room the short side
    (8.37–13.15 m) left the band 0 m deep across it on some seeds; in 3×3 it closes at least 10.86 m on both axes.
  - **View / dressing, seal, after-boss portals:** all read the room rect (`f.rooms[boss_room]`, the door, the
    seal, `Routes.place_deep_gate`); no 3×1 assumption. Their tests pass below.
- **Goldens:** none changed. The replay golden runs a boss-free kernel world (`KernelScenario.golden`);
  `test_replay_ground_plane.gd` passes unchanged.

## Commands
```
gdformat --check src scripts tests
gdlint src scripts tests
godot --headless --path . --editor --import --quit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_bosses.gd,res://tests/unit/sim/test_bosses_2.gd,res://tests/unit/sim/test_boss_room_builder.gd,res://tests/unit/sim/test_floor_generator.gd,res://tests/unit/sim/test_room_themes.gd,res://tests/unit/sim/test_after_boss.gd,res://tests/unit/sim/test_boss_challenge.gd,res://tests/unit/sim/test_boss_fights.gd,res://tests/unit/sim/test_boss_gates.gd,res://tests/unit/sim/test_boss_pressure.gd,res://tests/unit/sim/test_arenas.gd,res://tests/unit/sim/test_event_rooms.gd,res://tests/unit/sim/test_routes.gd,res://tests/unit/sim/test_run_flow.gd,res://tests/unit/sim/test_shop_placement.gd,res://tests/unit/sim/test_portal_transit.gd,res://tests/unit/application/test_run_saves.gd,res://tests/content/test_boss_validation.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_bosses.gd,res://tests/e2e/test_e2e_bosses_2.gd,res://tests/e2e/test_e2e_boss_challenge.gd,res://tests/e2e/test_e2e_after_boss.gd,res://tests/e2e/test_e2e_floor.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_arena.gd,res://tests/e2e/test_e2e_arenas.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_portal.gd,res://tests/e2e/test_e2e_routes.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_boss_views.gd,res://tests/unit/presentation/test_boss_challenge_views.gd,res://tests/unit/presentation/test_boss_challenge_parity.gd,res://tests/unit/presentation/test_boss_telegraph_parity.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/golden/test_replay_ground_plane.gd,res://tests/content/test_content_valid.gd -gexit
godot --headless --path . -s <scratchpad>/br_probe.gd      # untracked probe, source below
```

## Raw output
Lint:
```
633 files would be left unchanged
Success: no problems found
```

Sim, application and content tests (GUT output, trimmed to the per-script lines and the summary; ANSI colours removed):
```
res://tests/unit/sim/test_bosses.gd
16/16 passed.
res://tests/unit/sim/test_bosses_2.gd
19/19 passed.
res://tests/unit/sim/test_boss_room_builder.gd
    boss rooms: 200 seeds, 261.1 ms per floor (generate + attach + checks), 8 hosted off another room
4/4 passed.
res://tests/unit/sim/test_floor_generator.gd
9/9 passed.
res://tests/unit/sim/test_room_themes.gd
3/3 passed.
res://tests/unit/sim/test_after_boss.gd
9/9 passed.
res://tests/unit/sim/test_boss_challenge.gd
25/25 passed.
res://tests/unit/sim/test_boss_fights.gd
2/2 passed.
res://tests/unit/sim/test_boss_gates.gd
6/6 passed.
res://tests/unit/sim/test_boss_pressure.gd
6/6 passed.
res://tests/unit/sim/test_arenas.gd
14/14 passed.
res://tests/unit/sim/test_event_rooms.gd
3/3 passed.
res://tests/unit/sim/test_routes.gd
12/12 passed.
res://tests/unit/sim/test_run_flow.gd
18/18 passed.
res://tests/unit/sim/test_shop_placement.gd
3/3 passed.
res://tests/unit/sim/test_portal_transit.gd
5/5 passed.
res://tests/unit/application/test_run_saves.gd
10/10 passed.
res://tests/content/test_boss_validation.gd
8/8 passed.
Scripts              18
Tests               172
Passing Tests       172
Asserts           538066
Time              1294.394s
---- All tests passed! ----
```

e2e (same trimming):
```
res://tests/e2e/test_e2e_bosses.gd
1/1 passed.
res://tests/e2e/test_e2e_bosses_2.gd
3/3 passed.
res://tests/e2e/test_e2e_boss_challenge.gd
1/1 passed.
res://tests/e2e/test_e2e_after_boss.gd
1/1 passed.
res://tests/e2e/test_e2e_floor.gd
2/2 passed.
res://tests/e2e/test_e2e_saves.gd
2/2 passed.
res://tests/e2e/test_e2e_arena.gd
3/3 passed.
res://tests/e2e/test_e2e_arenas.gd
2/2 passed.
res://tests/e2e/test_e2e_run_flow.gd
3/3 passed.
res://tests/e2e/test_e2e_portal.gd
1/1 passed.
res://tests/e2e/test_e2e_routes.gd
1/1 passed.
Scripts              11
Tests                20
Passing Tests        20
Asserts             686
Time              148.137s
---- All tests passed! ----
```

Boss views (same trimming):
```
res://tests/unit/presentation/test_boss_views.gd
8/8 passed.
res://tests/unit/presentation/test_boss_challenge_views.gd
5/5 passed.
res://tests/unit/presentation/test_boss_challenge_parity.gd
5/5 passed.
res://tests/unit/presentation/test_boss_telegraph_parity.gd
9/9 passed.
Scripts               4
Tests                27
Passing Tests        27
Asserts             779
Time              47.051s
---- All tests passed! ----
```

Golden and content (same trimming):
```
res://tests/golden/test_replay_ground_plane.gd
2/2 passed.
res://tests/content/test_content_valid.gd
6/6 passed.
Scripts               2
Tests                 8
Passing Tests         8
Asserts              91
Time              8.448s
---- All tests passed! ----
```

Probe (40 floor seeds, `7000 + s * 31`, the Siege Engine's spec at the old 3×1 and at its data size):
```
data arena_cells=(3, 3) template=5 safe_half_m=5.0
cells=(3, 1) seeds=40 short_side_m=8.37..13.15 min_band_depth(short,long)=(0.00, 11.66) far_corner_m=39.62
cells=(3, 3) seeds=40 short_side_m=31.73..40.09 min_band_depth(short,long)=(10.86, 14.76) far_corner_m=32.37
```
The probe's loop (prints only; not committed): for each size, `FloorGenerator.generate(seed)`,
`BossRoomBuilder.attach(f, BossArenaSpec.make(cells, t.arena_template, k))`, then the boss room interior's short
side, `BossChallenge.band_depth(room, t, 1000)` and the largest distance from `f.boss_spawn` to an interior corner.

Screenshot: NOT YET RUN. No shot script renders a floor with the Siege Engine's real arena (`floor_map.gd` uses the
default 3×3 open spec), and writing one wasn't a quick job.

## Target bands
| Metric | Target | Source |
|---|---|---|
| Siege Engine room size | 3×3 cells | PLAN W2 (owner pick "3×3") |
| Generation properties | all pass | TEST_MATRIX (floor / boss room properties) |
| Closing band | closes on both axes, centre safe | BossDefinition `arena_*` (BX, L17) |
| Attacks reach | punish shockwave covers the room from the spawn | PLAN W2 ("attacks still reach the player") |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Room size | 3×3 on all 40 probe seeds and in `test_the_siege_engine_fights_in_a_3x3_room` | yes |
| Generation properties | 172/172 sim/application/content tests, 20/20 e2e | yes |
| Band depth, short axis | ≥ 10.86 m (was 0.00 m on some seeds at 3×1) | yes |
| Farthest corner from spawn | ≤ 32.37 m vs 40 m shockwave | yes |

## Interpretation
The bigger room needs only the data change; the generator, the closing band and the after-boss pieces were already
size-generic. Whether the fight *feels* right in the bigger room is OWNER ONLY (playtest).
