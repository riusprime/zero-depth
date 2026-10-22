# v0.9.0 Step PT: oval portals that grow and collapse (evidence)

Machine: the owner's PC (Windows 11, i7-10700K, RTX 3060), Godot 4.7.2, Git Bash. Branch `v090-pt`. The step
commit is b6e520da; the merge of 1214f0bf (SA + FA) came after it, and the post-merge runs below were on the merged tree.

Each GUT run used its own `APPDATA` folder:
`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>`

## Lint

`gdformat --check` and `gdlint` on every touched file: `Success: no problems found`.

## Tests before the merge (step commit b6e520da)

| Files | Raw summary |
|---|---|
| sim: test_portal_transit, test_routes, test_run_flow, test_world_snapshot, test_ascension, golden test_replay_ground_plane | `Tests 67 / Passing Tests 67` (an earlier sim change; the new transit test was re-run below) |
| test_portal_transit, test_boss_room_builder, arch test_layering + test_sim_purity, golden test_replay_ground_plane, test_modifier_equivalence | `Tests 19 / Passing 18 / Failing 1`: the new form-time test asserted `< 1.0` on the tick it formed (the reader reads 1.0 one tick before the walk-in tick). The assertion was fixed to `<= 1.0`; the walk-in tick is still asserted to be exactly PORTAL_FORM_TICKS |
| sim placement after the wall-clearance change: test_routes, test_floor_generator, test_boss_room_builder, test_room_layouts, test_ascension, test_ice_patches, test_starglow_patches | `Tests 58 / Passing 55 / Failing 3`: the old "the gate's back is against a wall" checks. They now check that the gate backs onto a wall GATE_WALL_CLEAR behind it, with floor between. Re-run of test_floor_generator + test_boss_room_builder: `Tests 14 / Passing Tests 14` |
| test_world_snapshot, test_run_flow, test_portal_transit, test_final_boss, golden test_replay_ground_plane, test_modifier_equivalence, arch (2), test_content_valid | `Tests 77 / Passing Tests 77` |
| test_portal_clearance (new, 200 seeds) | `Tests 2 / Passing Tests 2` |
| presentation: test_portal_oval, test_portal_gate, test_floor_receiver, test_routes_view, test_portal_transit_view, test_ascension_views, test_loading_cover, test_final_boss_views, test_frozen_shore, test_procedural_wall, test_shard_dressing, test_stage_dresser, test_starfall | `Tests 101 / Passing 99 / Failing 2`: test_frozen_shore and test_starfall assert the English biome name and got "Costa Helada" / "Caída Estelar". They fail the same way when run alone, so the cause looks like this PC's Spanish locale. This step does not touch them |
| e2e: test_e2e_portal, test_e2e_arrival, test_e2e_routes, test_e2e_floor | `Tests 6 / Passing Tests 6` |
| e2e: test_e2e_run_flow, test_e2e_after_boss, test_e2e_ascension, test_e2e_loading_cover | `Tests 7 / Passing Tests 7` |
| e2e: test_e2e_difficulty, test_e2e_final_boss, test_e2e_nemesis | `Tests 5 / Passing Tests 5` |

## Tests after merging 1214f0bf

| Files | Raw summary |
|---|---|
| test_portal_oval, test_portal_gate, test_floor_receiver, test_altar_stage, test_routes_view, test_portal_transit_view, test_ascension_views, test_loading_cover, test_final_boss_views | `Tests 62 / Passing 61 / Failing 1`: test_portal_oval still expected floor 1's receiver, but floor 1 is now SA's altar. The test was updated; re-run of test_portal_oval: `Tests 8 / Passing Tests 8` |
| test_portal_clearance, test_portal_transit, test_routes, test_floor_generator, test_boss_room_builder, test_room_layouts, test_ascension, test_world_snapshot, test_run_flow, golden test_replay_ground_plane, test_modifier_equivalence, arch (2) | `Tests 96 / Passing 95 / Failing 1`: test_ascension `test_a_loop_one_floor_hashes_without_the_loop_fields`. The bug is already in 1214f0bf: in `World.state_hash`, the FA block `if approach != null:` was inserted between `boss_flow.hash_into(h)` and the floor/loop fields, so those fields were hashed only on the approach. Fixed by moving the FA block after them |
| test_ascension, test_final_approach, test_final_boss, test_world_snapshot, golden test_replay_ground_plane, test_e2e_final_approach (after the fix) | `Tests 62 / Passing Tests 62` |
| e2e: test_e2e_arrival, test_e2e_portal, test_e2e_routes | `Tests 4 / Passing Tests 4` |
| e2e: test_e2e_ascension, test_e2e_final_approach, test_e2e_run_flow, test_e2e_after_boss | `Tests 7 / Passing Tests 7` |

## Goldens

- `tests/golden/test_replay_ground_plane.gd` (fixture `replay_ground_plane.json`) passed unchanged: it has no floor or boss
  flow.
- `test_modifier_equivalence` passed unchanged.
- `export_smoke_hash.txt`: NOT YET RUN. Its scenario (KernelScenario.golden) has no BossFlow and no floor layout, so
  this step's changes do not reach it.

No golden fixture changed.

## Shots (game camera, `scripts/shots/portal_oval.gd`, before the merge)

`godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/portal_oval.gd -- biome=<id>`
(renderer `forward_plus`, device `NVIDIA GeForce RTX 3060`). Raw lines:

```
portal_oval: res://build/shots/v0.9.0/pt/ruins_formed.png (frame 2754, tick 420) form_progress=1.00 gate_form=1.00 deep_form=1.00 motes=true
portal_oval: wall clearance (m) gate=1.45 deep=1.45
portal_oval: res://build/shots/v0.9.0/pt/night_rocks_formed.png (frame 3460, tick 420) form_progress=1.00 gate_form=1.00 deep_form=1.00 motes=true
portal_oval: res://build/shots/v0.9.0/pt/red_canyon_formed.png (frame 3907, tick 423) form_progress=1.00 gate_form=1.00 deep_form=1.00 motes=true
portal_oval: res://build/shots/v0.9.0/pt/frozen_shore_formed.png (frame 5483, tick 420) form_progress=1.00 gate_form=1.00 deep_form=1.00 motes=true
portal_oval: res://build/shots/v0.9.0/pt/starfall_formed.png (frame 5826, tick 420) form_progress=1.00 gate_form=1.00 deep_form=1.00 motes=true
```

The clearance line is printed only by the Ruins run; it was added after the other runs. It reads in 0.05 m steps, so
1.45 means the nearest wall is between 1.45 and 1.5 m from the oval. Copies are in `pt_shots/`: `<biome>_formed.png`
for each biome, and `ruins_growing.png` at half growth. Look and feel: OWNER ONLY.
