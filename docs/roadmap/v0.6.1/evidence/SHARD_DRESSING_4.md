# v0.6.1 Step SD4 — a fifth of a room, mostly corners, only on stone; crystal rooms (evidence)

Owner answer A3c (2026-10-09, after SD3's shots; PLAN "Owner answers"): "okay you sent an image of a big room full of
crystals, that should be not happening only about a 20% of the room should have, and mostly corners, the only items
that should be touching these are rock materials, no cars, barrels, or wood, just stone, the small room I was
talking about was a themed one, where there is a noticable higher percentage with bigger cristals, size of the 1x1
rock stones that are in some rooms as walls and smaller ones, but always close to the walls". The "big room full of
crystals" was SD3's start-room shot.

Build: the agent's working tree on `d9f780d` (`claude/lucid-fermat-9wv2tf`) with this step's changes, committed as
the `v0.6.1 Step SD4` commit. Local machine: headless Godot 4.7.2; shots through xvfb on llvmpipe (software Vulkan).

## What changed from SD3 (presentation only)

`src/presentation/world_view/shard_dressing.gd`:
- **A share of the wall base.**
  - `wall_spots(f, room)` lists the room's free wall base. It walks the walls every 0.5 m and keeps a spot 0.35 m
    in from a wall when:
    - a wall stands behind it (no doorway);
    - a crystal could stand there by every rule: open floor, the clearances, stone only, free path out.
  - `coverage(f, room, placed)` is the share of those spots with a tall crystal within 0.6 m.
  - Each room gets a target. Ordinary rooms, the start room included, aim for 0.20 ± 0.05; crystal rooms for
    0.70 ± 0.10. Placing stops when the target is met.
  - The start room is no longer crystal-rich: it keeps its hero cluster, which counts toward its share.
- **Mostly corners.** A room's four corners are tried in a random order. Each corner gets a corner cluster plus runs
  along its two walls (one cluster every 1.1 m, up to 3 m). Only if the share is still short do the runs extend to
  6 m, and then the whole wall (big rooms).
- **Only stone.**
  - `STONE` lists the kit's stone pieces: `wall_1m`, `wall_2m`, `wall_broken`, `wall_pillar`, `slab_concrete`,
    `slab_wide`, `rock_large`.
  - StageView now passes the dresser's placements. A cover box dressed with any other piece is "soft": crates, car
    wrecks, dead trees. So are the light props (fire barrels, brazier poles).
  - Every crystal keeps `NON_STONE_CLEAR` 0.5 m from a soft piece, and only stone cover gets obstacle clusters
    (25 % of them in an ordinary room, 60 % in a crystal room).
  - In Ruins many room corners hold crate stacks: 498 crate-stack placements within 2 m of a room corner over
    20 floors (scratch count). Those corners now stay bare.
- **Crystal rooms.**
  - `floor_crystal_rooms(f)`: 1 or 2 rooms per floor (2 with chance 0.5). The pick is the cosmetic stream's first
    draws, so the sim is untouched.
  - It is weighted by free stone wall base per m² of floor, so smaller rooms with bare stone walls come first.
  - It never picks the start room, the boss arena, a room with the shop, the shrine or an event (StageView passes
    their positions as `special`), or a room with less than 8 m of free wall base.
  - Clusters there carry 1–2 big crystals (one more in a corner): radius 0.30–0.45 m, 1.2–1.8 m tall, about the 1 × 1 m
    stone blocks. Smaller ones stand round them, with more low shards and fragments and a slightly brighter glow
    (×1.2). The big ones keep their far edge within `BIG_HUG` 1.0 m of the stone ("always close to the walls").
- **Removed:** the SD2 vein field and the room-size factor. Variation now comes from the per-room share jitter,
  which corners and runs fit, and the crystal rooms.
- **Kept from SD3:**
  - crystals grow from the floor and hug stone (0.7 m; tall ones 0.55 m);
  - camera-side faces are capped at 0.6 m (0.9 m side-on) with no fragments;
  - the clearances: doorways 1.8 m, keep-clear 1.5 m, spawns 0.6 m, the start 2.0 m, a 1.4 m path out;
  - every room but the boss arena gets at least one cluster;
  - the boss arena stays bare, and the hero cluster sits in the back corner first.

`stage_view.gd` passes `pieces` (the dresser's placements) and `special` (the shop, shrine and event positions) to
ShardDressing. It no longer passes room themes. `shard_cluster.gd` is unchanged. `scripts/shots/shard_dressing.gd`
now shoots the start room, the hero cluster, an ordinary room (the one with the most clusters, up to 400 m²) and a
crystal room.

`tests/unit/presentation/test_shard_dressing.gd` has 15 tests. New:
- about a fifth of the free wall base in ordinary rooms and the start room, and far more in crystal rooms;
- mostly corners;
- crystals touch only stone;
- crystal rooms are few, smaller and hold the big crystals;
- a crystal room is never a special room.

The view test also checks that, on real floors, a crystal room never holds the shop, the shrine or an event. The
floor-grown, cap, clearance and view tests carry over from SD3; the vein tests are gone.

## Lint

```
$ gdformat --check src scripts tests ; gdlint src scripts tests
629 files would be left unchanged
Success: no problems found
```

## Tests (targeted, not the full suite)

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_shard_dressing.gd,res://tests/unit/presentation/test_stage_dresser.gd,res://tests/unit/presentation/test_deep_look.gd,res://tests/unit/presentation/test_stage_mood.gd,res://tests/arch/test_layering.gd,res://tests/arch/test_sim_purity.gd,res://tests/golden/test_replay_ground_plane.gd,res://tests/e2e/test_e2e_floor.gd -gexit
exit 0
res://tests/unit/presentation/test_shard_dressing.gd
* test_the_same_seed_gives_the_same_clusters
* test_crystals_grow_from_the_floor_hugging_walls_and_obstacles
    clusters by kind: { &"wall": 5347, &"obstacle": 747, &"corner": 333 }
* test_camera_side_faces_get_the_low_cap
* test_clusters_keep_the_clearances_and_the_paths
* test_a_fifth_of_a_room_and_the_crystal_rooms_far_more
    covered share of the free wall base: ordinary 0.239, start room 0.201, crystal rooms 0.716
* test_mostly_in_the_corners
    ordinary rooms' tall wall crystals within 6 m of a corner: 0.982 of 12974
* test_crystals_touch_only_stone
* test_crystal_rooms_are_few_small_and_hold_the_big_crystals
    mean room area: crystal rooms 281 m², all rooms 322 m²; big crystals 2118
* test_a_crystal_room_is_never_the_shop_the_shrine_or_an_event_room
* test_a_crystal_glow_bakes_into_the_vertex_colour
* test_no_cluster_in_a_boss_arena_and_the_sim_is_untouched
* test_the_view_builds_the_clusters_with_outline_glow_and_bobbing_fragments
* test_tints_and_the_deep_violet
* test_a_deep_floor_tints_its_shards_violet
* test_the_unit_crystal_is_closed_and_faces_out
15/15 passed.
res://tests/unit/presentation/test_stage_dresser.gd
* test_the_same_seed_gives_the_same_floor
* test_every_wall_and_slab_is_dressed_and_tall_pieces_stay_in_their_footprint
* test_decoration_keeps_clear_and_lights_avoid_doorways
3/3 passed.
res://tests/unit/presentation/test_deep_look.gd
* test_a_deep_floor_layers_a_violet_haze_on_the_biomes_mood
* test_the_haze_also_works_without_a_mood
* test_the_phase_gate_shows_a_shell_and_phase_shift
3/3 passed.
res://tests/unit/presentation/test_stage_mood.gd
* test_every_shipped_biome_has_a_valid_mood
* test_a_biome_without_a_mood_or_with_a_bad_one_is_reported
* test_no_mood_keeps_the_old_look
* test_a_mood_lights_the_stage_and_quality_toggles_ssao_and_ssil
4/4 passed.
res://tests/arch/test_layering.gd
* test_no_reference_crosses_a_layer_the_wrong_way
* test_rules
2/2 passed.
res://tests/arch/test_sim_purity.gd
* test_sim_sources_are_pure
* test_the_lint_catches_planted_tokens
2/2 passed.
res://tests/golden/test_replay_ground_plane.gd
* test_replay_matches_every_checkpoint
REPLAY| final=70ac7ca24761c818e8e103b4281da76358e98e880d80ff54754adefa0bfd0add
* test_two_runs_in_one_process_agree
2/2 passed.
res://tests/e2e/test_e2e_floor.gd
* test_the_floor_has_altars_chests_and_a_gate
* test_walk_to_an_altar_and_take_the_second_card_with_the_pad
2/2 passed.
Totals
Scripts               8
Tests                33
Passing Tests        33
Asserts           623660
Time              154.278s
---- All tests passed! ----
```

The log has no `SCRIPT ERROR` line (grep count 0). The replay's final hash is the same as in SD–SD3. The full suite
was not run: the lead runs it once for the wave. The coverage test uses seeds 1100–1129 (30 floors).

## Numbers (60 generated floors, seeds 1100–1159)

These come from a throwaway scratch script that isn't committed. It uses the test's floor input plus
`StageDresser.dress` pieces for the Ruins biome, with no special rooms (the floor generator has no shop or event
positions). It times `ShardDressing.place` and `ShardCluster.bake` per room with `Time.get_ticks_usec`. Coverage is
`ShardDressing.coverage` per room.

```
$ godot --headless --path . -s <scratchpad>/sd4_stats.gd
clusters per floor: n=60 mean 105.350 median 109.000 min 69.000 max 159.000 kinds { &"corner": 331, &"wall": 5288, &"obstacle": 702 } crystals 43859 big 2118
place ms per floor: n=60 mean 123.140 median 124.222 min 77.125 max 174.056
bake ms per floor (headless): n=60 mean 40.364 median 39.250 min 25.478 max 68.524
rooms (no boss) 662 empty 0 heroes 60/60 crystal rooms 91
coverage of the free wall base: ordinary n=511 mean 0.235 median 0.232 min 0.155 max 0.455
coverage of the free wall base: start room n=60 mean 0.205 median 0.203 min 0.161 max 0.263
coverage of the free wall base: crystal rooms n=91 mean 0.719 median 0.719 min 0.609 max 0.847
room area: crystal rooms n=91 mean 280.810 median 233.274 min 81.901 max 1079.764 | all rooms n=662 mean 432.976 median 277.178 min 81.901 max 1830.812
wall-base clusters: corner 331, wall runs 5288
bases in a structure 0; footprint beyond the hug (0.7 m, big 1.0 m) 0; touching non-stone (< 0.5 m) 0; of 43859
```

A second scratch run over seeds 1100–1119 measured how close the ordinary rooms' wall crystals stand to a corner.
It counted tall crystals and left out the crystal rooms and the obstacle clusters:

```
$ godot --headless --path . -s <scratchpad>/sd4_prof.gd
total ms 2298.6, local ms 42.7, spots ms 697.7 (20 floors)
ordinary rooms: tall crystals within 3 m of a room corner 1565, within 6 m 4276, of 4525
```

- **Coverage:** ordinary rooms 0.235 (median 0.232, range 0.155–0.455); start rooms 0.205; crystal rooms 0.719
  (0.609–0.847). Placing stops once the target is met, but the last cluster can cover more than what remained,
  so a room can overshoot (the 0.455 maximum). Which room that was was not checked.
- **Mostly corners:** 35 % of the ordinary rooms' tall wall crystals stand within 3 m of a room corner, and 94 %
  within 6 m. Corners count as "used" only when they are stone: corners with crate stacks stay bare (rule 2).
- **Stone only:** no crystal is within 0.5 m of a crate, wreck, dead tree or light prop (0 of 43 859).
- **Footprint:** no crystal reaches past 0.7 m of a wall or stone piece, nor past 1.0 m for the big crystal-room
  ones (0 of 43 859).
- **Crystal rooms:** 91 over 60 floors. Their median area is 233 m², against 277 m² for all rooms.
- **Clusters:** 105 per floor on average, down from SD3's 159.
- **Cost:** placement about 123 ms per floor, of which about 35 ms is `wall_spots`; baking about 40 ms (headless).
  Both are paid once, when the floor is built. SD3 was about 137 + 93 ms. No target was set.

## Screenshots

```
$ XDG_DATA_HOME=<empty scratch dir> timeout 300 xvfb-run -a godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/shard_dressing.gd
exit 0
shard_dressing: seed=7 floor=1 biome=ruins clusters=92 (hero true) start_room=0
shard_dressing: res://build/shots/v0.6.0-dev/shards/1_start_room.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/2_hero_corner.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/3_ordinary_room_6.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/4_crystal_room_2.png
```

The shots were copied by hand. They replace the earlier `shards2_*` files; `shards2_small_room.png` and
`shards2_large_room.png` were removed:
- [`shards2_start_room.png`](shards2_start_room.png): the whole start room (view 30 m). A few corner groups and the
  hero cluster stand on bare stone walls; most of the wall base is empty.
- [`shards2_start_wall.png`](shards2_start_wall.png): the hero cluster's area, close.
- [`shards2_ordinary_room.png`](shards2_ordinary_room.png): ordinary room 6, with small groups near its corners.
- [`shards2_crystal_room.png`](shards2_crystal_room.png): crystal room 2, with big crystals along its stone back wall
  and smaller ones round them. Its crate-dressed stretches stay bare.

## Not done / open

- Owner look check: OWNER ONLY. This covers the share, the corners, which room types should be crystal rooms, and
  the big crystals' size.
- The crystal room is picked by free stone wall base per m², not by the room's template or theme. The owner's "a
  themed one" may mean a specific template: an owner question.
- Shots of a faded camera-side wall with the hero behind it, and of other biome tints: NOT YET RUN.
- The crystals still have no collision (presentation only).
