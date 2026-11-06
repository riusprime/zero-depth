# S15: do cracked walls spawn, and can you see them? (check only)

Owner (2026-11-01): "i've never seen in game a cracked wall are you sure they spawn and are visible? we should keep them tho".
Run by a Sonnet agent on branch `v0105-s15` (base `48f5c616`, commit `fae62444`), on the owner's PC. Copied here by
the lead from the agent's report; the raw output file (`build/cracked_wall_count.txt`) was in the agent's removed
worktree.

## Command
`godot --headless --path . -s scripts/checks/cracked_wall_count.gd` (200 run seeds, the real floor build
`SaveLab.build_floor` + `FloorPlan.add_secrets`).

## Result
| Floor | Floors with a cracked wall |
|---|---|
| 1 | 6 / 200 (3.0 %) |
| 2 | 40 / 200 (20 %) |
| 3 | 15 / 200 (7.5 %) |

55 of 200 seeds have one on any of floors 1–3. The 25 % roll is cut hard by the candidates
(`src/sim/map/cracked_rooms.gd:30-36`: dead-end rooms left after `avoid`, taken and busy rooms), so floor 1 (10–12 rooms)
almost never has one. Always a dead-end room's only doorway; the hidden room is mostly ~12 × 10 m.

## Why you don't see one
1. **The cracks are nearly invisible:** bars 2 × 4 cm at alpha 0.12 (`breakables_view.gd:30, 87-89`; drawn at
   `:150-158`), darker only per Skill hit. The slab is the biome cover colour darkened 15 % (`:65`) or the model tinted
   (`:131-133`): a dark plain slab, no glow, outline or accent.
2. **Cracks are only on the two faces along the doorway** (`breakables_view.gd:148-149`): seen edge-on, none show.
3. **The slab isn't in the wall cutaway** (`stage_view.gd:592, 915-916`): never faded or cut away.
4. **Other clues are faint or absent:** a floor rune marking at alpha 0.22 (`rune_markings_view.gd:23`); nothing on the
   minimap (`minimap_state.gd:88-91`); only the Astral affinity pulses a hint (`astral_sense_view.gd`).

Shot (seed 15, floor 1, hero 3 m away, game camera): a dark slab in a gap between wall runs, no visible cracks.
Re-take with `godot --path . --position -10000,-10000 -s scripts/shots/cracked_wall.gd -- seed=15`.
