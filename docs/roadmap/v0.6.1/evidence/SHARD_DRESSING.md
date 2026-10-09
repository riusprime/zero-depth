# v0.6.1 Step SD — shard dressing (evidence)

Owner line R4 (2026-10-09): "we could also add to the generation map or the initial room the shard looks".
Build: the agent's working tree on `c684ed2` (`claude/lucid-fermat-9wv2tf`) with this step's changes, committed as
the `v0.6.1 Step SD` commit. Local machine: headless Godot 4.7.2; shots through xvfb on llvmpipe (software Vulkan).

## What was built

- `src/presentation/world_view/shard_cluster.gd` (`ShardCluster`): code-built crystals. The unit crystal is a
  faceted 6-, 5- or 4-sided prism with a pointed top and a short bottom point (flat facets, two bright highlight
  facets, a darker base). Its shader adds a soft inner glow on the faces toward the camera, and an inverted-hull
  outline pass draws it in ink. Each room's crystals are baked into one mesh, so there is one draw plus the outline
  and the camera culls whole rooms. Each room's floating fragments are one MultiMesh that bobs on the GPU (none with
  reduced motion). Only the hero cluster has a light: a small cold omni light, no shadow. Tints (starting values):
  pale cyan / teal by default and in Ruins, icy blue in Night Rocks, pale amber in Red Canyon, and the Deep violet on
  Deep floors.
- `src/presentation/world_view/shard_dressing.gd` (`ShardDressing`): where the clusters go. A pure function on its
  own cosmetic stream (floor seed × 7919 + 9241, never a sim stream). Rules (starting values):
  - Tall crystals grow out of a structural wall, with the base inside the wall's footprint (StageDresser rule 1).
    On the floor there are only low shards (≤ `DECOR_MAX_HEIGHT` 0.4 m). Fragments float ≥ 1.1 m up.
  - Clusters go on the room's back walls (-X / +Y, the ones the iso camera never fades), first at the back corner.
  - Each cluster's foot keeps:
    - 2.2 m from cover (the v0.5.9 slab gap);
    - 3.0 m from other clusters;
    - 1.8 m from doorways and arena barriers;
    - 1.5 m from rewards, gates, the shop, the shrine, events and the dresser's light props;
    - 0.6 m from enemy spawn spots;
    - 2.0 m from the hero's start.
  - Density by theme: Ruined hall / Overgrown 0–3, Camp 0–1, other rooms 0–2. The start room gets one hero cluster
    (crystals 1.6–2.2 m tall, plus the cold light). No clusters in the boss arena.
- `src/presentation/world_view/stage_view.gd`: `_build_shards` runs after the kit (only with a mood and the kit,
  i.e. the v0.5.9 look). It adds a `Shards` node and changes nothing else in the stage. Lighting moods, the kit,
  chest, shrine and themed rooms are untouched.
- `src/sim/world/world_reader.gd`: three read-only getters for presentation: `floor_room_theme(i)`,
  `floor_start_pos()` and `spawn_spots()`. No sim state, step or hash changes. The replay golden is identical (below).
- `tests/unit/presentation/test_shard_dressing.gd` (9 tests) and `scripts/shots/shard_dressing.gd`.

## Lint

```
$ gdformat --check src scripts tests ; gdlint src scripts tests
617 files would be left unchanged
Success: no problems found
```

## Tests (targeted, not the full suite, per the owner's testing rule)

The first run of this set failed `tests/arch/test_layering.gd`:
`shard_dressing.gd (presentation) uses FloorLayout (sim)` (×3). Fixed by having the reader return theme names
(`floor_room_theme`). The run after the fix:

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_shard_dressing.gd,res://tests/unit/presentation/test_stage_dresser.gd,res://tests/unit/presentation/test_deep_look.gd,res://tests/unit/presentation/test_stage_mood.gd,res://tests/arch/test_layering.gd,res://tests/arch/test_sim_purity.gd,res://tests/golden/test_replay_ground_plane.gd,res://tests/e2e/test_e2e_floor.gd -gexit
res://tests/unit/presentation/test_shard_dressing.gd
* test_the_same_seed_gives_the_same_clusters
* test_tall_crystals_grow_from_walls_and_the_rest_stays_low
* test_clusters_keep_the_spacing_rules
* test_density_follows_the_theme_and_the_start_room_gets_its_hero
    clusters per room: ruined hall 1.09, camp 0.27
* test_no_cluster_in_a_boss_arena_and_the_sim_is_untouched
* test_the_view_builds_the_clusters_with_outline_glow_and_bobbing_fragments
* test_tints_and_the_deep_violet
* test_a_deep_floor_tints_its_shards_violet
* test_the_unit_crystal_is_closed_and_faces_out
9/9 passed.
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
Tests                27
Passing Tests        27
Asserts           761807
Time              88.783s
---- All tests passed! ----
```

The full suite was not run (the lead runs it once for the wave).

## Placement numbers (60 generated floors, seeds 1100–1159)

These come from a throwaway scratch script that isn't committed. It calls `ShardDressing.place` on
`FloorGenerator.generate` floors with the same input the test uses.

```
$ godot --headless --path . -s <scratchpad>/sd_stats.gd
heroes 60/60 small 446 rooms 662 total ms 11150 place ms 246
```

That is a hero cluster in all 60 start rooms and 446 small clusters over 662 rooms. Placement took 246 ms for 60
floors (about 4 ms a floor). The rest of the time is floor generation.

## Screenshots

```
$ XDG_DATA_HOME=<empty scratch dir> timeout 300 xvfb-run -a godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/shard_dressing.gd
exit 0
shard_dressing: seed=7 floor=1 biome=ruins clusters=9 (hero true) start_room=0
shard_dressing: res://build/shots/v0.6.0-dev/shards/1_start_room.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/2_hero_cluster.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/3_room_2.png
shard_dressing: res://build/shots/v0.6.0-dev/shards/4_room_3.png
```

The shots are in `build/` (untracked, so not committed). They show:
- the start room;
- a close-up of the hero cluster (teal crystals out of the back wall, low shards at its foot, floating fragments);
- two ordinary rooms with small clusters on their back walls.

Two earlier shot runs were used to tune sizes: small clusters were barely visible behind the 1 m walls, and crystals
sat too deep in thick walls. The values above are the result. The folder name says `v0.6.0-dev` because
`GameVersion.label()` hasn't been bumped for v0.6.1.

## Not done / open

- Owner look check: OWNER ONLY (sizes, tints, density, the hero cluster's place).
- Only the Ruins tint was screenshotted. Night Rocks, Red Canyon and Deep are covered by tests, not shots: NOT YET RUN.
- The hero cluster goes to the back corner when the corner is clear, otherwise along a back wall (seed 7 lands on
  the wall).
- With the "low" lighting quality, small clusters cast no shadows.
- SW's `shard_mesh.gd` is not used. The lead may unify the two crystal builders after merging.
