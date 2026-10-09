# v0.6.1 Step SD3: crystals grow from the floor (evidence)

Owner answer A3b (2026-10-09, after SD2's shots; PLAN "Owner answers"): "yeah but not on top of the walls it should
be floor closed to the walls, corners of some rooms, and other obstacle like they grow from the ground".

Build: the agent's working tree on `664ab82` (`claude/lucid-fermat-9wv2tf`, which has SD2 merged) with this step's
changes, committed as the `v0.6.1 Step SD3` commit. Local machine: headless Godot 4.7.2; shots through xvfb on
llvmpipe (software Vulkan).

## What changed from SD2 (presentation only)

`src/presentation/world_view/shard_dressing.gd` has a new placement. SD2's vein field, room-size factor, theme
nudge, the crystal-rich start room and "every room but the boss arena ≥ 1" stay.

- **Removed:** crystals embedded in walls, SD/SD2's "tall crystals grow out of a wall's footprint", and SD2's
  wall-top-only clusters. No crystal base is ever inside a wall or an obstacle.
- **From the floor:** every crystal's base disc is on open floor in its room. Each crystal hugs the nearest wall
  or cover piece:
  - its far edge is within `HUG` 0.7 m of it;
  - a crystal taller than the 0.4 m decoration limit is within `TALL_HUG` 0.55 m;
  - it leans away from that surface and gets lower the further out it stands (up to −45 %).

  The base disc tapers (`ShardCluster.BASE_TAPER` 0.82), so 0.8 × its radius must clear every structure.
- **Where:**
  - **Wall bases:** each room wall is walked every 1.1 m (0.8 m in the start room); a doorway has no wall behind it,
    so it gets nothing.
  - **Corners:** the corners of some rooms get a fuller cluster, with two arms along the walls (0.7 m + 0.7 × vein
    each) and two more tall crystals. A corner rolls `(0.4 + 0.85 × vein) × room factor`, so most rooms skip most
    corners.
  - **Round obstacles:** each face of the sim's cover pieces is walked; the kit dresses those pieces as rocks,
    crates, wrecks, slabs and dead trees.
- **Chance per candidate:** `(base + 0.85 × vein) × room factor`, capped at 0.92. The base is 0.12 for walls, 0.08
  for obstacles and 0.4 for corners. The start room uses 0.9 for walls and corners and 0.5 for obstacles. The start
  room's hero cluster stands in its back corner first (8–10 tall crystals, 2.3–2.8 m, arms 1.4 m), with its cold
  light. All values are starting values.
- **Camera-side faces** (`_cap`): the sim's direction toward the camera is (0.707, −0.707), so `TO_CAMERA` uses it.
  The cap depends on how a face's floor side points:
  - away from the camera (dot < −0.25): nothing taller than `LOW_HEIGHT` 0.6 m (under the 1 m wall);
  - side-on (dot under 0.25): 0.9 m;
  - with a cap, no floating fragments.

  The room's crystals are one baked mesh, so they can't fade with an occluded wall; capping them is the guard.
  Back-wall bases (the -X and +Y walls) and the back corner take full height.
- **Clearances:** every crystal's base keeps 1.8 m from doorways and arena barriers, 1.5 m from rewards, gates and
  the other keep-clear spots, 0.6 m from spawn spots and 2.0 m from the start. Paths: straight out past a cluster's
  footprint, `PATH_CLEAR` 1.4 m of free floor (no structure, no other cluster) at its middle and both ends, so a
  passage never closes up. Cluster feet stay 1.2 m apart. SD/SD2's 2.2 m gap from cover is replaced by growing
  round cover plus this path rule (owner A3b: "and other obstacle").
- **Speed:** each room's walls carry their bounding rects, a cheap test before the exact box test, and the path
  check only looks at nearby clusters.

`shard_cluster.gd` (drawing) is unchanged from SD2: per-room baked mesh, per-crystal glow in the vertex colour, one
fragment MultiMesh per room. `scripts/shots/shard_dressing.gd` renames the hero shot to `2_hero_corner`.

`tests/unit/presentation/test_shard_dressing.gd` has 14 tests (SD2 had 13). New or rewritten:
- every crystal grows from the floor and hugs a wall or obstacle; it is never in one, stays under its face's cap,
  and camera-side clusters have no fragments; clusters appear along walls, in corners and round obstacles;
- the camera-side cap per face direction;
- clearances and paths, checked per crystal.

The density, start room, vein and view tests carry over from SD2.

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
    clusters by kind: { &"wall": 6367, &"obstacle": 2966, &"corner": 271 }
* test_camera_side_faces_get_the_low_cap
* test_clusters_keep_the_clearances_and_the_paths
* test_every_room_has_crystals_and_the_start_room_is_rich
    clusters per wall metre: start room 0.610, other rooms 0.087
* test_smaller_rooms_get_more_per_wall_metre
    clusters per wall metre: small rooms 0.115, large rooms 0.073
* test_density_follows_the_veins_unevenly
    clusters per wall metre: in a vein 0.162 (1622 m of wall), out of every vein 0.058 (31552 m)
    tallest crystal per cluster: in a vein 1.11 m, out of one 0.83 m
* test_the_vein_field_is_smooth_and_seeded
* test_a_crystal_glow_bakes_into_the_vertex_colour
* test_no_cluster_in_a_boss_arena_and_the_sim_is_untouched
* test_the_view_builds_the_clusters_with_outline_glow_and_bobbing_fragments
* test_tints_and_the_deep_violet
* test_a_deep_floor_tints_its_shards_violet
* test_the_unit_crystal_is_closed_and_faces_out
14/14 passed.
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
Tests                32
Passing Tests        32
Asserts           622654
Time              139.046s
---- All tests passed! ----
```

The log has no `SCRIPT ERROR` line (grep count 0). The replay's final hash is the same as in SD and SD2. The full
suite was not run: the lead runs it once for the wave.

## Placement numbers (60 generated floors, seeds 1100–1159)

These come from a throwaway scratch script that isn't committed. It runs `ShardDressing.place` on
`FloorGenerator.generate` floors with the test's input, then `ShardCluster.bake` on each room, timed with
`Time.get_ticks_usec`.

How the footprint and tip checks were measured:
- Each crystal's base disc and leaning tip were checked against the nearest structure (a wall or cover box) on the
  whole floor.
- A tip is the unit crystal's top under the crystal's transform, projected to the floor.
- "In a structure" means the base centre is inside one, or the tapered disc (0.8 × radius) overlaps one.

```
$ godot --headless --path . -s <scratchpad>/sd3_stats.gd
floors 60 clusters total 9526 per floor min 130 median 159 max 185 crystals 94013 kinds { &"corner": 252, &"wall": 6267, &"obstacle": 3007 }
place ms per floor: mean 137.3 median 137.8 max 169.0
bake ms per floor (headless): median 92.7 max 110.3; triangles per floor median 31124 max 37364
rooms (no boss) 662 empty 0 heroes 60/60 camera-side (low) clusters 4868
crystal bases (centre, or the tapered disc 0.8 r) in a structure 0; footprint beyond 0.7 m of a wall/obstacle 0 of 94013 (max reach 0.000); tall ones beyond 0.55 m 0 of 36792
crystal tips (leaning) beyond 0.7 m of a wall/obstacle 983 of 94013 (max 0.793 m)
start room clusters min 82 median 95 max 116; covered share of the free wall base median 0.96 min 0.91
per wall metre: small rooms (<250 m2) 0.115, large rooms 0.073
```

- **Walkable intrusion (the lead's check):** no crystal footprint reaches into the floor beyond 0.7 m of a wall or
  obstacle (0 of 94 013), and no tall crystal's beyond 0.55 m. Leaning tips (above the floor) pass 0.7 m for 983
  crystals (1.0 %), by at most 0.09 m (max 0.793 m).
- **Start room:** "free wall base" means spots every 0.25 m, 0.35 m in from a wall, on open floor and keeping every
  clearance. In 96 % of that length (median; 91 % at worst) a tall start-room crystal stands within 0.9 m.
- **Cost:** placement is about 137 ms per floor and baking about 93 ms per floor (headless). Both are paid once, when
  the floor's stage is built. SD2 measured about 30 + 39 ms; SD measured about 4 ms of placement. Draws per room are
  unchanged: one baked mesh, its outline pass and one fragment MultiMesh. No target was set; these are the
  measured numbers.
- The ordinary rooms average about 6 clusters each (159 per floor minus the start room's about 95, over 10 rooms).
  Only 252 of the floors' corners got a cluster, which is "corners of some rooms".

## Screenshots

```
$ XDG_DATA_HOME=<empty scratch dir> timeout 300 xvfb-run -a godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/shard_dressing.gd
exit 0
shard_dressing: seed=7 floor=1 biome=ruins clusters=153 (hero true) start_room=0
shard_dressing: res://build/shots/v0.6.0-dev/shards/1_start_room.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/2_hero_corner.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/3_small_room_8.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/4_large_room_5.png
```

The shots were copied by hand over SD2's files, under the same names:
- [`shards2_start_room.png`](shards2_start_room.png): the whole start room (view 30 m). Crystals line the floor at
  the back walls' base and stand round the rocks and crates; the front walls have short ones.
- [`shards2_start_wall.png`](shards2_start_wall.png): the hero cluster's area, close (`2_hero_corner`, framed from the
  hero cluster's foot). Crystals grow from the floor against the back wall and round the wreck and crates.
- [`shards2_small_room.png`](shards2_small_room.png): small room 8, with clusters at the wall bases, by the crates
  and round the dead tree.
- [`shards2_large_room.png`](shards2_large_room.png): large room 5, with a rock ringed by crystals, clusters at a few
  wall bases, and sparse stretches.

## Not done / open

- Owner look check: OWNER ONLY.
- A shot of a faded camera-side wall with the hero behind it was not taken: NOT YET RUN. The 0.6 m / 0.9 m caps are
  the guard, and the tests check them.
- Shots of other biome tints: NOT YET RUN.
- The crystals have no collision (presentation only, as asked). The hero can walk through a crystal standing within
  0.7 m of a wall or obstacle.
- Placement plus baking is now about 230 ms per floor on this machine (headless). If floor transitions hitch, the
  next step is baking per room lazily or moving placement off the main thread; neither was done.
