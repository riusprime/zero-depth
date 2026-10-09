# v0.6.1 Step SD2 — denser, uneven shard dressing (evidence)

Owner answer A3 (2026-10-09, PLAN "Owner answers"): "Very frequent on the starting room and be an element of all
rooms, but disparity not all equally distributid some zones have more density than others, specially walls at
smaller rooms". The SD shots (`shards_start_room.png`, `shards_room.png`) were too sparse and too small.

Build: the agent's working tree on `3dafbea` (`claude/lucid-fermat-9wv2tf`) with this step's changes, committed as
the `v0.6.1 Step SD2` commit. Local machine: headless Godot 4.7.2; shots through xvfb on llvmpipe (software Vulkan).

## What was built (presentation only)

`src/presentation/world_view/shard_dressing.gd` (placement, still a pure function on its own cosmetic stream,
floor seed × 7919 + 9241):
- **A vein field per floor.** 3–5 major veins (radius 6–10 m, strength 1) sit on a random room's wall, plus 4–7 minor
  ones (radius 3–5 m, strength 0.45) anywhere on a room's floor. A vein adds `strength × (1 − (d/r)²)²` inside its
  radius, clamped to 0..1: smooth and deterministic per seed. These are the stream's first draws, so
  `ShardDressing.floor_veins(f)` returns the same field for tests and tools.
- **A walk along every wall.** Each room's four walls are walked with one candidate every 1.1 m (0.8 m in the start
  room), plus the back corner. A candidate gets a cluster with chance
  `(0.12 + 0.85 × vein) × size factor × theme factor`, capped at 0.92. The size factor is `250 m² / room area`,
  clamped to 0.55–2.5, so smaller rooms' walls get more. The theme factor is ×1.25 for Ruined hall and Overgrown and
  ×0.6 for Camp. The start room's chance is 0.9 everywhere. All are starting values.
- **Bigger and brighter in the veins.** With vein v, a cluster has 3 + round(3v) (+0–1) tall crystals. Heights scale by
  1 + 0.7v, radii by 0.95 + 0.45v and the spread along the wall by 0.9 + 0.9v. It gets more low shards and fragments.
  Each crystal's glow factor is 1 + 0.35v. Start-room clusters take mixed sizes (v at least 0.3–0.9, drawn), two more
  low shards and two more fragments. The hero cluster is bigger than SD's (7–9 crystals, the tallest 2.3–2.8 m) and
  keeps its cold light.
- **All walls, low on the camera-side ones.** Back walls (-X, +Y) take full clusters. Front walls (+X, -Y) are the
  walls between the room and the camera that occlusion fades: `Occlusion.select` fades a wall when it hides the hero.
  A faded wall would leave the baked crystals standing, so front-wall crystals:
  - are capped at `FRONT_MAX_HEIGHT` 1.4 m, a tip over the 1 m wall;
  - lean away from the room (half SD's tilt);
  - get no floating fragments.
- **Every room but the boss arena has crystals.** If the walk leaves a room empty, a finer walk (0.5 m) tries a tight
  cluster (0.42 m foot), back walls and stronger veins first. If that also fails, it tries a wall-only cluster.
- **Wall-only clusters.** When a cluster with a foot breaks a rule at a spot (mostly the slab gap to cover), the same
  spot tries crystals that stay in the wall top only. They lean away from the room, have no low shards and use foot
  radius 0 at the wall face, so every clearance is measured from the wall itself.
- **Boss arenas: still none (my call).** The arena's v0.6.0 look (veil, boss avatars, barriers) stays as it is.
- **Spacing kept:** doorways and arena barriers 1.8 m, rewards / gates / shop / shrine / events / light props 1.5 m,
  spawn spots 0.6 m, the start 2.0 m, cover 2.2 m (the slab gap). Each is measured from the cluster's foot plus its
  radius. Changed on purpose: SD's 3.0 m between clusters becomes a 0.3 m gap between feet (`CLUSTER_GAP`), so
  clusters can line a wall.

`src/presentation/world_view/shard_cluster.gd` (drawing):
- Each crystal's glow factor is baked into its vertex colour's green channel (factor / 2), and the shader multiplies
  the emission by it. A room is still one baked mesh plus its outline pass, and its fragments are still one MultiMesh.
- The room-level glow energy is 0.45 everywhere. SD lit the whole start room at 0.7; now only the hero cluster's
  crystals carry ×1.55 (≈ 0.7, as in SD). Vein crystals peak at 0.45 × 1.35 ≈ 0.61. Fragments stay at ×1.3.

`scripts/shots/shard_dressing.gd`: the shots are now the whole start room, the hero cluster's wall, the small room
(< 250 m²) with the most clusters per wall metre, and the large room with the most clusters.

`tests/unit/presentation/test_shard_dressing.gd`: 13 tests (was 9). New: every room but the boss arena has
crystals and the start room is rich; smaller rooms get more per wall metre; density follows the veins unevenly and
vein clusters are bigger and brighter; the vein field is smooth and seeded; the glow bakes into the vertex colour.
Updated: spacing (any wall, the new gap; counted per rule instead of one assert per pair); front walls stay low with
no fragments; the view test checks every non-boss room has a mesh on real floors. Dropped: SD's per-theme caps and
"Ruined hall holds more than Camp" (the theme is now a ×1.25 / ×0.6 nudge on a size- and vein-driven chance). The
60 generated floors are cached per script.

The sim, collision, spawn points and replay goldens are untouched. No sim file changed in this step.

## Lint

```
$ gdformat --check src scripts tests ; gdlint src scripts tests
627 files would be left unchanged
Success: no problems found
```

## Tests (targeted, not the full suite, per the owner's testing rule)

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_shard_dressing.gd,res://tests/unit/presentation/test_stage_dresser.gd,res://tests/unit/presentation/test_deep_look.gd,res://tests/unit/presentation/test_stage_mood.gd,res://tests/arch/test_layering.gd,res://tests/arch/test_sim_purity.gd,res://tests/golden/test_replay_ground_plane.gd,res://tests/e2e/test_e2e_floor.gd -gexit
exit 0
res://tests/unit/presentation/test_shard_dressing.gd
* test_the_same_seed_gives_the_same_clusters
* test_tall_crystals_grow_from_walls_and_the_rest_stays_low
* test_clusters_keep_the_spacing_rules
* test_every_room_has_crystals_and_the_start_room_is_rich
    clusters per wall metre: start room 0.451, other rooms 0.052
* test_smaller_rooms_get_more_per_wall_metre
    clusters per wall metre: small rooms 0.076, large rooms 0.039
* test_density_follows_the_veins_unevenly
    clusters per wall metre: in a vein 0.150 (1622 m of wall), out of every vein 0.037 (31552 m)
    tallest crystal per cluster: in a vein 1.99 m, out of one 1.51 m
* test_the_vein_field_is_smooth_and_seeded
* test_a_crystal_glow_bakes_into_the_vertex_colour
* test_no_cluster_in_a_boss_arena_and_the_sim_is_untouched
* test_the_view_builds_the_clusters_with_outline_glow_and_bobbing_fragments
* test_tints_and_the_deep_violet
* test_a_deep_floor_tints_its_shards_violet
* test_the_unit_crystal_is_closed_and_faces_out
13/13 passed.
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
Tests                31
Passing Tests        31
Asserts           663772
Time              97.137s
---- All tests passed! ----
```

The log has no `SCRIPT ERROR` line (grep count 0). The replay's final hash is the same as in SD's evidence. The
full suite was not run: the lead runs it once for the wave.

## Placement numbers (60 generated floors, seeds 1100–1159)

These come from a throwaway scratch script that isn't committed. It calls `ShardDressing.place` on
`FloorGenerator.generate` floors with the test's input, then `ShardCluster.bake` on each room's crystals, and times
both with `Time.get_ticks_usec`.

"Free wall length" is the wall length where a cluster could stand: every 0.25 m, a spot with a wall behind it that
passes every spacing rule except the gap to other clusters, measured from the wall face. "Covered" means a tall
crystal of a start-room cluster stands within 0.9 m of the spot.

```
$ godot --headless --path . -s <scratchpad>/sd2_stats.gd
floors 60 clusters total 6507 per floor min 68 median 110 max 139 crystals 38321
place ms per floor: mean 30.4 median 30.1 max 41.6
bake ms per floor (headless, all rooms' meshes): median 38.7 max 63.6; triangles per floor median 13012 max 16248
rooms (no boss) 662 empty 0 heroes 60/60 front clusters 3189 max crystals in one room 616
start room clusters min 41 median 73 max 100; covered share of the free wall length median 0.99 min 0.96
per wall metre: small rooms (<250 m2) 0.076, large rooms 0.039
```

Compared with SD on the same seeds (SD's evidence): 446 small clusters plus 60 heroes and 4 ms of placement per floor,
against 110 clusters per floor (median) and about 30 ms now. Each floor now also bakes about 39 ms of meshes. Both
costs are paid once, when the floor's stage is built. Draws per room are unchanged: one baked mesh, its outline pass
and one fragment MultiMesh. No target was set; these are the measured numbers.

A second scratch diagnostic walked 30 floors (seeds 1100–1129) every 1.1 m with a 0.7 m foot. In the start rooms,
2348 of 4106 wall spots (57 %) broke the 2.2 m slab gap from cover. That's why the start room's covered share is
measured against the free length. Wall-only clusters can stand closer to cover, because their clearance is measured
from the wall face.

## Screenshots

```
$ XDG_DATA_HOME=<empty scratch dir> timeout 300 xvfb-run -a godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/shard_dressing.gd
exit 0
shard_dressing: seed=7 floor=1 biome=ruins clusters=88 (hero true) start_room=0
shard_dressing: res://build/shots/v0.6.0-dev/shards/1_start_room.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/2_hero_wall.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/3_small_room_8.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/4_large_room_6.png
```

The shots were copied by hand into this folder:
- [`shards2_start_room.png`](shards2_start_room.png): the whole start room, wide (view 30 m). The back walls are lined
  in stretches, and the front walls show low crystal tips.
- [`shards2_start_wall.png`](shards2_start_wall.png): the hero cluster's wall, close.
- [`shards2_small_room.png`](shards2_small_room.png): small room 8, with a dense vein stretch on its back wall and
  low tips on its front walls.
- [`shards2_large_room.png`](shards2_large_room.png): large room 6, mostly sparse with a few small groups. This is
  the uneven distribution the owner asked for.

The folder name says `v0.6.0-dev` because `GameVersion.label()` hasn't been bumped for v0.6.1.

## Not done / open

- Owner look check: OWNER ONLY (density, sizes, the start room, the dense and sparse balance, the front-wall tips).
- Only the Ruins tint was screenshotted. Night Rocks, Red Canyon and Deep with the brighter vein glow: NOT YET RUN
  (covered by tests, not shots).
- The fade with a front wall faded, while the hero stands behind it, was not shot: NOT YET RUN. The height cap
  (≤ 1.4 m, leaning outward, no fragments) is the guard, and the tests check it.
- The density numbers are starting values (chances, vein counts and radii, size factor, sizes).
- SW's `shard_mesh.gd` is still not used here (SW2 owns the portal clusters). The two crystal builders stay separate.
