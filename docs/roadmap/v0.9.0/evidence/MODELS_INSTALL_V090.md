# MODELS_INSTALL_V090: the owner's v0.9.0 models and textures in game (v0.9.0 Step MI2)

- **Status:** RUN (agent, on the owner's PC: Windows 11, i7-10700K, RTX 3060; Godot `4.7.2.stable.official.ed1daf0bf`;
  shots on the GPU, Vulkan Forward+). How it looks and plays: **OWNER ONLY**.
- **Build:** branch `v090-mi2` from `c8d41c90` (the step's commit; its SHA is in the report and PROGRESS).
- **Date:** 2026-10-22
- **Who ran it:** agent

Owner, 2026-10-22 (verbatim): "here are new models and textures, enemies are not animted, you will have to do it
manually, some models have 2 which you will also have to split, it is marked in the name"; on simplifying without
meshoptimizer (no Windows build): "Use Godot's simplifier (Recommended)".

## 1. The simplifier without meshoptimizer
`scripts/assets/mi_prep.py`'s `simplify()` keeps meshoptimizer (the Python package) as its backend where it imports
(the cloud/Linux pipeline is unchanged). Without it, it writes the triangles' positions and indices to a temporary
binary file and runs `scripts/assets/gd_simplify.gd` headless (`$GODOT --headless --path . -s
scripts/assets/gd_simplify.gd -- <in> <out> <target>`), which hands them to Godot's embedded meshoptimizer through
`SurfaceTool.generate_lod(1e9, target * 3)` (deprecated in 4.7.2, still present; the script falls back to
`ImporterMesh.generate_lods`' LOD chain, closest level not above the target, if a later Godot drops it).

Measured (`scratchpad/mi2/gdtest.py`: a 60 × 60 open grid, 6,962 triangles):
```
['gd_simplify: route=lod in=6962 target=500 out=500'] 0
tris 500 border verts kept share 1.0
['gd_simplify: route=lod in=6962 target=1234 out=1234'] 0
tris 1234 border verts kept share 1.0
['gd_simplify: route=lod in=6962 target=5000 out=5000'] 0
tris 5000 border verts kept share 1.0
```
- **How close to the target:** exact on the grid; on the 29 models every part lands within 1 % of its share, the whole
  within the budget (+0.2 % on the Rift Hunter: its locked part borders keep a few more, as v0.8.0's enemies did).
- **lock_border:** this route **always locks open borders** (every border vertex kept above). A caller's
  `lock_border=False` is not honoured; for the welded single-piece models that changes little (few open borders), and
  for the parted models (the elites, the arena pillar) it is what mi_prep asks anyway.
- Each call starts Godot headless (the altar alone, one call: `real 0m17.005s` end to end, bake included); the whole
  batch was not timed.

## 2. Preparing the models
```
export GODOT="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
$S/venv311/Scripts/python -I scripts/assets/mi2_prep.py              # every model and the 3 textures
$S/venv311/Scripts/python -I scripts/assets/mi2_prep.py elite_conduit # re-run after its staff cut was refitted
```
`scripts/assets/mi2_prep.py` (new; reuses mi_prep's read, weld, simplify, bake and glb writer): per model the raw piece
(the two "(2models)" files split into their two connected pieces by the side of x; the stone spike file's tallest of
three clusters), turned (raw front +Z kept for props the views turn; onto +X for the elites; the gate's face to -X,
the wall segment's concave face -X), scaled (to a height, a width, a length, or to fill a box: the altar 6.6 × 0.45 ×
6.6 m, ShopModels' box from SA), simplified to its role's budget, re-atlased (xatlas) and baked (1024 px; 512 for the
spike and the pedestals). Colour maps are brightened toward a mean of 0.5 (at most 2.2×) as v0.8.0's room pieces,
except the final arena's pieces and the spike (`dark`: their violet stone keeps its own colour) and the elites. The
27 raw files (not 28: 8 + 9 + 7 + 3 in `new_assets_1..4`) give 29 models. Raw files untouched.

| id | raw triangles | piece picked | in game / budget | size (m, x × y × z) | file | map px | where |
|---|---|---|---|---|---|---|---|
| `arrival_altar` | 29,510 |  | 6,000 / 6,000 | 6.60 × 0.45 × 6.60 | 804 KB | 1024 | floor 1's altar (AltarStage) and, tinted purple, the final approach's |
| `approach_stairs` | 28,776 |  | 3,000 / 3,000 | 3.00 × 0.50 × 6.00 | 469 KB | 1024 | the final approach's causeway: flights repeated down it (replacing the code treads) |
| `arena_wall_segment` | 28,642 |  | 3,000 / 3,000 | 1.32 × 1.57 × 3.00 | 491 KB | 1024 | every ring segment of the final arena / plateau; tiled along the causeway's walls |
| `arena_pillar` | 29,328 |  | 2,996 / 3,000 | 2.06 × 5.00 × 2.22 | 487 KB | 1024 | the arena's far pillars (near ones stay low code stumps); part `shard` turns and bobs |
| `arena_brazier` | 28,115 |  | 2,993 / 3,000 | 0.93 × 1.40 × 0.94 | 475 KB | 1024 | the arena's braziers (his flames; the code light stays) |
| `arena_gate` | 28,267 |  | 5,989 / 6,000 | 3.10 × 5.42 × 7.60 | 805 KB | 1024 | the arena's sealed gate |
| `elite_breaker` | 28,639 |  | 4,995 / 5,000 | 2.18 × 2.60 × 2.61 | 714 KB | 1024 | manifest only (EL): parts below |
| `elite_rift_hunter` | 29,024 |  | 5,010 / 5,000 | 1.26 × 2.10 × 1.72 | 705 KB | 1024 | manifest only (EL): parts below |
| `elite_conduit` | 28,140 |  | 4,996 / 5,000 | 1.16 × 2.30 × 1.85 | 706 KB | 1024 | manifest only (EL): parts below |
| `timed_door` | 28,768 |  | 2,996 / 3,000 | 0.50 × 3.00 × 3.00 | 664 KB | 1024 | TD: the slab that sinks (TimedDoorView) |
| `rune_switch` | 28,963 |  | 2,997 / 3,000 | 1.10 × 1.30 × 0.93 | 599 KB | 1024 | TD: both switches (the lit rune disc on his slanted top) |
| `rune_pillar` | 28,470 |  | 2,994 / 3,000 | 1.76 × 2.20 × 1.66 | 625 KB | 1024 | manifest only (RA) |
| `rune_mural` | 27,664 |  | 2,996 / 3,000 | 3.62 × 1.60 × 0.56 | 636 KB | 1024 | manifest only (RA) |
| `cracked_wall` | 28,564 | 11,912 (x−) | 2,996 / 3,000 | 4.06 × 3.00 × 1.11 | 568 KB | 1024 | manifest only (DX) |
| `cracked_wall_broken` | 28,564 | 16,652 (x+) | 2,996 / 3,000 | 4.31 × 3.00 × 2.26 | 581 KB | 1024 | manifest only (DX) |
| `healing_fountain` | 29,298 |  | 3,000 / 3,000 | 1.19 × 1.40 × 1.13 | 574 KB | 1024 | manifest only (HF) |
| `shrine_blood` | 9,612 |  | 2,982 / 3,000 | 2.72 × 2.00 × 2.13 | 612 KB | 1024 | manifest only (SH) |
| `shrine_chaos` | 29,500 |  | 2,990 / 3,000 | 1.83 × 2.20 × 1.79 | 592 KB | 1024 | manifest only (SH) |
| `shrine_fortune` | 25,948 |  | 3,000 / 3,000 | 1.33 × 2.00 × 1.16 | 562 KB | 1024 | manifest only (SH) |
| `purple_rune_dais` | 28,864 |  | 2,982 / 3,000 | 3.00 × 0.49 × 2.81 | 614 KB | 1024 | manifest only (DP) |
| `stone_spike` | 29,584 | 13,100 (tallest of 3) | 600 / 600 | 0.64 × 1.00 × 0.66 | 111 KB | 512 | the Gatekeeper's and the Colossus's stone spikes (StoneSpikeViews) |
| `floor_receiver` | 29,208 |  | 2,990 / 3,000 | 2.20 × 1.32 × 2.15 | 536 KB | 1024 | manifest only: no floor uses the receiver since PT (not re-added) |
| `hub_portal_machine` | 495,598 |  | 7,982 / 8,000 | 8.44 × 6.00 × 7.04 | 1,143 KB | 1024 | manifest only (HB) |
| `hub_archive` | 9,062 |  | 2,974 / 3,000 | 3.45 × 3.50 × 2.38 | 512 KB | 1024 | manifest only (HB) |
| `hub_wardrobe` | 8,697 |  | 2,985 / 3,000 | 2.08 × 2.40 × 1.68 | 538 KB | 1024 | manifest only (HB) |
| `hub_station` | 9,095 |  | 2,981 / 3,000 | 3.49 × 1.60 × 1.99 | 573 KB | 1024 | manifest only (HB) |
| `hub_trophy_pedestal` | 9,168 |  | 1,000 / 1,000 | 0.99 × 1.10 × 0.94 | 145 KB | 512 | manifest only (HB) |
| `hub_collectible_pedestal` | 9,628 | 4,010 (x+, the slim one with the cradle) | 1,000 / 1,000 | 0.59 × 1.00 × 0.61 | 179 KB | 512 | manifest only (HB) |
| `hub_collectible_pedestal_b` | 9,628 | 5,618 (x−, the wide one with a plaque) | 1,000 / 1,000 | 0.92 × 1.00 × 0.88 | 180 KB | 512 | manifest only (HB) |

Files: `assets/models/{devices,arena,enemies,fx,hub}/<id>.glb` (the import writes `<id>_albedo.jpg` beside each), all
listed in `assets/models/manifest.json` with their sha256 (`tests/content/test_model_manifest.gd` now also scans
`arena`, `fx`, `hub`, and checks every v0.9.0 id is listed within its budget).

Textures (`assets/textures/kit/`, listed in the manifest's textures; imported VRAM-compressed with mipmaps, as
`ground_b`):
| id | raw | prepared | where |
|---|---|---|---|
| `ground_arena` | 1254 × 1254 PNG | the middle square made seamless (mi_prep's offset cross-fade), 1024 px | the final arena / plateau floor (FinalArenaStage, light palette tint) |
| `ground_snow` | 1254 × 1254 PNG | the same, 1024 px | Frozen Shore's ground (StageView.GROUND_TEXTURES) |
| `rune_marking` | 1254 × 1254 RGBA | resized to 512 px, alpha kept | manifest only (the RA/DX marking decal) |

### The split pieces
- `cracked_wall_and_cracked_wall_broken(2models).glb`: two connected pieces; x− (11,912 triangles, 0.15 deep, no
  hole) = `cracked_wall`; x+ (16,652, rubble at its foot, a hole) = `cracked_wall_broken`.
- `hub_collectible_pedestal(2models).glb`: x+ (slim, round cradle, rune band: the art list's prompt) =
  `hub_collectible_pedestal`; x− (wide square, plaque recess) = `hub_collectible_pedestal_b`.
- `stone_spike.glb` (not marked): three spike clusters side by side; the tallest (x > 0.13, 13,100 triangles) is the
  game's spike; the two smaller clusters are not installed.
- `timed_door.glb`: a gate of iron bars with spikes and rune bands, **no frame** (it reads like the art list's
  `lockdown_seal` prompt). Nothing to cut: the whole gate is the slab that sinks; TimedDoorView keeps its code stone
  frame round it.

### The elites: parts for code animation (EL poses them; no AI or views here)
Front onto +X, Y up, +Z the figure's right; each part one glTF node, its origin at its pivot (metres, model frame).
Materials per part: `base`, and `glow` where the map is very bright and saturated (GLOW_THRESHOLDS): almost none was
found (Breaker 2 triangles in the head, Rift Hunter 26 in the body, Conduit 0), so EL should draw the eye glows in code.
| elite | part: triangles (pivot) |
|---|---|
| `elite_breaker` (2.6 m) | `body` 1,683 (torso, 0,0,0); `head` 375 (0.10, 1.72, 0); `arm_r` 665: the huge stone fist (0, 1.82, 0.70); `arm_l` 839: the smaller hand (0, 1.77, −0.65); `back_slab` 443 (−0.39, 1.61, 0); `leg_r` 647 / `leg_l` 343 (0, 0.68, ±0.26) |
| `elite_rift_hunter` (2.1 m) | `body` 1,714 (torso, upper arms, cloak above the hips); `head` 195 (crescent, 0, 1.68, 0); `blade_r` 498 / `blade_l` 580 (forearm blades, 0, 1.51, ±0.42); `leg_r` 660 / `leg_l` 817 (0, 0.95, ±0.17; the cloak strips below the hips go with the legs); `shards` 546 (the floating shoulder shards, 0, 1.68, 0) |
| `elite_conduit` (2.3 m) | `body` 3,490 (robe); `head` 466 (hood, 0, 1.66, 0); `ring` 517 (the chest ring, 0, 1.33, 0); `staff` 325 (the rod and its crystal cage, fitted to the raw rod, pivot at the hands 0.25, 1.27, −0.28); `shards` 198 (floating rune shards, 0, 1.61, 0) |

Part renders: `godot --path . --resolution 1500x400 -s scripts/shots/mi_models.gd -- src=assets/models/enemies
ids=elite_breaker,elite_rift_hunter,elite_conduit parts=1 fit=1` (mi_models gained `fit=1`, scaling by the largest
side, for flat models).

Raw summary lines (`scratchpad/logs/mi2_prep_all.log`, 32 lines; three shown, the conduit's from its re-run):
```
{"id": "arrival_altar", "raw": "new_assets_1/arrival_altar.glb", "raw_tris": 29510, "picked_tris": 29510, "raw_bytes": 4887576, "tris": 6000, "budget": 6000, "tex": 1024, "gain": 1.17, "backend": "godot", "size": [6.6, 0.45, 6.6], "path": "assets/models/devices/arrival_altar.glb", "bytes": 823844, "sha256": "26a56e8fe2229397e6de1d39f3d4cbbc8ab9a757f3d5aafb7e66a59a4c3e73e3", "parts": {"body": [6000, 0, [0.0, 0.0, 0.0]]}}
{"id": "elite_breaker", "raw": "new_assets_1/elite_breaker.glb", "raw_tris": 28639, "picked_tris": 28639, "raw_bytes": 3643320, "tris": 4995, "budget": 5000, "tex": 1024, "gain": 1.0, "backend": "godot", "size": [2.178, 2.6, 2.614], "path": "assets/models/enemies/elite_breaker.glb", "bytes": 731292, "sha256": "510a101b278a0351f53bf5491d3a821ca32b1bf62ba983ec3480304d318a2d84", "parts": {"arm_l": [839, 0, [0.0, 1.768, -0.65]], "arm_r": [665, 0, [0.0, 1.82, 0.702]], "back_slab": [443, 0, [-0.39, 1.612, 0.0]], "body": [1683, 0, [0.0, 0.0, 0.0]], "head": [375, 2, [0.104, 1.716, 0.0]], "leg_l": [343, 0, [0.0, 0.676, -0.26]], "leg_r": [647, 0, [0.0, 0.676, 0.26]]}}
{"id": "elite_conduit", "raw": "new_assets_2/elite_conduit.glb", "raw_tris": 28140, "picked_tris": 28140, "raw_bytes": 3280504, "tris": 4996, "budget": 5000, "tex": 1024, "gain": 1.0, "backend": "godot", "size": [1.162, 2.3, 1.848], "path": "assets/models/enemies/elite_conduit.glb", "bytes": 723428, "sha256": "4e06f74fa7adfb68868ed0c67241cdf4c1261f8d8346ad94b5d158e9b3a1bc43", "parts": {"body": [3490, 0, [0.0, 0.0, 0.0]], "head": [466, 0, [0.0, 1.656, 0.0]], "ring": [517, 0, [0.0, 1.334, 0.0]], "shards": [198, 0, [0.0, 1.61, 0.0]], "staff": [325, 0, [0.253, 1.265, -0.276]]}}
```

## 3. Wired (presentation only; the sim is unchanged)
- **AltarStage:** the owner's stone (ShopModels `arrival_altar`, his model filling the 6.6 × 0.45 × 6.6 m box); the
  landing, swirl and particles on his top (0.45 m); a code jewel in each of his **six** sockets (measured from the
  prepared mesh: angles −146°, −83°, −17°, 35°, 97°, 161°, radius 2.4 m), so the arrival altar has 6 jewels (was 8);
  the floating runes stay code objects (his carved panels are not lit: their positions could not be read reliably from
  the mesh). The final approach's altar is the same model with its stone tinted `#9A86B8`.
- **FinalArenaStage:** every ring segment's block is his wall segment (tiled along the causeway's walls), drawn in the
  walls' own solid / faded materials (his texture), so the occlusion fade still works; his far pillars (the floating
  crystal turns and bobs), braziers (no code flame cone; the light stays) and gate; on the approach his stair flights
  (one per ~3 m, climbing toward the ring, 0.25 m sunk: the sim is flat) replace the code treads; his `ground_arena`
  paves the floor. Positions, the wall nodes' count and order (the occlusion's) are unchanged.
- **TimedDoorView:** his gate is the slab that sinks (ShopModels `timed_door`, 0.5 × 3 × 3 m, stretched to the
  doorway); his switches (`rune_switch`, 1.3 m, own proportions) with the lit rune disc moved onto his slanted top.
- **StoneSpikeViews:** his spike (one unit tall, its own proportions: a spike, not squashed to the code spike's width),
  drawn in his colour map, the map's red veins the hot cracks that glow on the strike.
- **StageView:** Frozen Shore's ground is his `ground_snow`.

## 4. Tests
```
APPDATA=<own> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>
```
| files | result |
|---|---|
| test_model_manifest, test_altar_stage, test_final_approach_view, test_final_boss_views, test_timed_door_view, test_attack_visuals, test_floor_receiver | `Tests 59 · Passing Tests 59 · Asserts 19407` |
| test_e2e_arrival, test_e2e_final_approach, test_e2e_timed_door, test_e2e_frozen_shore, test_e2e_final_boss, test_stage_ground, test_credits_licences, test_assets | `Tests 14 · Passing Tests 14 · Asserts 310` |
| test_frozen_shore (presentation) | `Tests 8 · Passing 7 · Failing 1`: `["Costa Helada"] expected to equal ["Frozen Shore"]` at line 32: the Spanish OS locale (the biome's name translated), not this step |

`data/credits/licences.tres` rebuilt (`godot --headless --path . -s scripts/content/build_credits.gd`) for the models
manifest's new licence line and file count. Lint: `gdformat` / `gdlint` clean on every changed .gd.

## 5. Shots (game camera, GPU)
`docs/roadmap/v0.9.0/evidence/mi2_shots/` (JPEG copies of the tools' PNG/JPG output):
| shot | tool |
|---|---|
| `1_floor1_altar.jpg` (runes lit) | `scripts/shots/altar_safa.gd` (altar_2_lit) |
| `2_final_approach_causeway.jpg`, `3_final_approach_plateau.jpg` | `scripts/shots/approach_fa.gd` (1, 2) |
| `4_final_arena.jpg` | `scripts/shots/final_boss.gd -- 0` (1_arena_overview) |
| `5_timed_door_one_switch_on.jpg` | `scripts/shots/timed_door_mi2.gd` (new; 2: one switch pressed) |
| `6_gatekeeper_spikes.jpg` | `scripts/shots/attack_visuals.gd` (15_gatekeeper_spikes_close) |
| `7_frozen_shore_ground.jpg` | `scripts/shots/frozen_shore.gd` (1_start_room) |

Seen in them (not judged: OWNER ONLY): in the timed-door shot the camera looks at the door from the room side, so the
gate sits dark inside its code frame; the switches read. Running five shot tools at once ran the GPU out of memory
(`VkResult error -2`); the altar and spike tools were re-run alone.

## 6. Not done
- The two smaller stone-spike clusters are not installed.
- The altar's carved rune panels are not lit (only the jewels are aligned to his sockets).
- Brazier flames are static mesh (the code flicker applied to the code cone only).
- Timing / load probes: not run (no target set for this step).
