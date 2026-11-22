# CPU_AVERAGE_A: the 3.6 ms of nodes' `_process` the perf log cannot name (Step 48)

- **Status:** RUN, indications only: two other agents ran Godot on the machine during most runs (the `tasklist` counts
  below, 0-4 Godot lines besides the run), so the quiet-machine protocol (`PERF_TOOLS.md` §2) was not met. The lead
  measures the merged tree once on a quiet machine.
- **Build:** base `0f298c3d` (branch `lead-v0120`); after: the working tree of `v0.12.0 Step 48` on parent `0f298c3d`
  (branch `v0120-s48`); the debug native library copied from the main checkout (no native change); Godot
  `4.7.2.stable.official.ed1daf0bf`, Forward+, Windows 11 Pro 10.0.26200.
- **Machine:** the owner's PC (i7-10700K, RTX 3060), driven by an agent. **Date:** 2026-11-22. **Who ran it:** agent.
- **Base runs** were made in the same worktree with this step's `src/` changes taken out (a patch, `git checkout --
  src`, the new file moved aside) and put back after; the probe scripts were the same in both.
- Owner-only: whether anything looks or feels different in play (OWNER ONLY).

## The scenarios

The frame probe (`scripts/checks/frame_probe.gd`), 2560 × 1440 off screen, 30 live enemies, the Playground room:
- **RC Gun:** `--biome=red_canyon` (the Gun, the default build: Glaive, Ring, Split, the fire and lightning cores at L3);
- **NR Blade:** `--biome=night_rocks --weapon=blade --cards=split_wave,echo_slash,whirl,ember_core,storm_core`.

New probe options (tools only): `--weapon=<build id>` (the Playground build the hero holds; the report's scenario line
names it; the "build: Gun + ..." line is the old fixed label) and `--proc-census` (`scripts/checks/process_census.gd`:
counts, once halfway through the measure, every node class with its process / internal process / physics flags on,
the animation mixers, skeletons and particle nodes).

## 1. What the 3.6 ms is

The owner's log (`perf_20261122_122528`): the rest of the nodes' `_process` 3.60 ms a frame, of which the perf
recorder is about 0.55 ms (its own line: mean 549 µs). **About 3.05 ms is the game.**

**Script nodes against the engine's own processing.** With `--spans --process` every script node's `_process` is
called from the probe instead of the tree, so what is left in the `nodes_process` span is the views' sync (its own
bucket), the HUD's frame listener and the engine's own per-node work:

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-s48 "$GODOT" --path . --position -10000,-10000 --resolution 2560x1440 \
  --windowed -s scripts/checks/frame_probe.gd -- <scenario> --enemies=30 --secs=20 --warm=3 --size=2560x1440 --spans --process
```
| run (base) | `span.nodes_process` | − `frame.world_view_root.gd.sync` | − `frame.main.gd._on_playground_tick` | = engine's own + other listeners |
|---|---:|---:|---:|---:|
| RC Gun, base 1 | 4,819 | 4,060 | 609 | **150 µs** |
| NR Blade, base 1 | 3,988 | 3,268 | 587 | **133 µs** |

So the engine's own processing (animation players, particle nodes' internal process, audio players) is at most
about 0.15 ms a frame here; nearly all of the 3.05 ms is script `_process`. It was not split further with a toggle
run (`--ab=no_anim`, `--ab=no_particles`): NOT YET RUN; the bound above is the whole of it.

**What the engine processes** (`--proc-census`, RC Gun, the live tree mid-fight; base build, a `--spans --breakdown`
run, nodes / process / internal process / physics / internal physics):
```
  GPUParticles3D                 81      0     64      0     81
  Node3D                        438    120      0      0      0
  Control                       213     31      0      0      0
  AnimationPlayer                22      0     16      0      0
  ...
  mixers: 22 in the tree, 22 active, 16 AnimationPlayers playing
    active mixers under vfx_controller.gd: 22
  skeletons: 0 in the tree, 0 visible
  CPUParticles3D: 2 in the tree, 0 emitting, 0 emitting and visible
  GPUParticles3D: 81 in the tree, 58 emitting, 57 emitting and visible
```
(NR Blade: 32 mixers, 30 playing, 40 GPU particle nodes, 29 emitting.) **No skeleton** in the tree (the enemies are the
VAT crowd and rigid pieces, the hero is posed nodes); every animation player belongs to a pack effect
(`vfx_controller.gd`) and every particle node emitting is visible. No node was found processing for nothing: every
script node with processing on had a `_process` that ran (171 and 162 of them).

**The script `_process` split** (`--process`; the probe's calls add their own cost, so proportions only, PERF_TOOLS
§4.3; base 1 of each scenario, µs a frame):

| part | RC Gun | share | NR Blade | share |
|---|---:|---:|---:|---:|
| the effects layer (`attack_form_view.gd`: the forms, `VfxCore.finish` and every drawer, the pack spawns) | 1,270 | 27 % | 649 | 21 % |
| the avatars (`*_avatar.gd`: the hero and each enemy's frame-time pose) | 1,415 | 30 % | 983 | 31 % |
| `vat_crowd.gd` (one instance per VAT enemy a frame) | 736 | 16 % | 565 | 18 % |
| `empty_draw_cull.gd` | 210 | 5 % | 164 | 5 % |
| `shard_views.gd` (the drops' turn) | 124 | 3 % | 4 | 0 % |
| `critter_crowd.gd` + `enemy_batch.gd` | 99 | 2 % | 171 | 5 % |
| the HUD scripts' own `_process` (minimap, meters, bars, cards; step 49's) | 259 | 6 % | 170 | 5 % |
| `dps_meter.gd` (the Playground only, not in a run) | 86 | 2 % | 29 | 1 % |
| `pack_fx.gd` | 28 | 1 % | 22 | 1 % |
| the rest (about 90 scripts, each under 20 µs: atmosphere, audio, hit feel, backdrop, telegraphs, ...) | 440 | 9 % | 382 | 12 % |
| **all script nodes** | **4,667** | | **3,139** | |

The probe's frame here is 16–22 ms against the owner's 12, so the µs are larger than the owner's; the shares are the
reading. Scaled onto the owner's 3.05 ms, roughly: the avatars 0.9 ms, the effects layer 0.65–0.8, the VAT crowd 0.5,
the culling 0.15, the HUD parts 0.15, the rest 0.3–0.4; the engine's own up to 0.15. **Unnamed: nothing beyond the
rest's long tail** (no single script over 20 µs).

**Inside the three big parts** (temporary `PerfMarks` buckets, removed again; `--breakdown`, RC Gun; one run each):
- The avatars: `advance` 1,205–1,361 µs of all of them; the hero 222 (of it the cloak's rebuild 156–169: building the
  arrays in GDScript 95, the new surface 45, clearing the old 11; the pose 25, the cloak springs 13, the arms 7); the
  Stone Thrower 360 for its three (its pose code in dictionaries, `grip_points` working out the whole arm chain while
  it lifts), the Warden 126, the Glacier Turtle 92, the Wire Weaver 88, the others 40–70 each.
- `vat_crowd.gd`: 31–33 enemies a frame drawn by the GDScript writer (the owner's models, `SoloVat`, are not batched:
  `EnemyBatch.KINDS`), 545–694 µs of it, about 16 µs an enemy; the batched kinds' native writer 114–143. Per enemy:
  the drives (`vat_drives` → `SoloVat.normalized`, 29 drives unpacked spec by spec: 6.0 µs alone, measured in a
  bench) the largest part, then the transform, the colour and the buffer writes; per set the drive texture's upload.
  4–5 sets a frame had no enemy left and were written again anyway (22–39 µs).
- The effects layer: as step 40 found (§8 of `CPU_FRAME_TIME.md`), mostly the drawers inside `VfxCore.finish`; in the
  RC Gun base run `vfx.status_visuals._draw_vfx` 211, `canyon_shore_views` 130, `fireball_views.draw_lights` 124,
  `finish_rest` 116, `variant_views` 106, `glaive_view` 87, `impact_fx` 83 µs.
- `empty_draw_cull.gd`: a bench (270 pools four nodes deep, 1/3 empty): the loop 205 µs, of it `is_empty` 155 (the
  static call about 60, reading the MultiMesh, its mesh and its count the rest), the visibility 21, the tree check 17.

## 2. What changed (nothing the player sees)

- **The hero's cloak** (`PlayerAvatar._rebuild_cloak`, every frame): its triangles are written in place into arrays of
  their final size (the new `player_cloak_mesh.gd`, which holds the poncho's geometry: the facets and the collar)
  instead of appending a temporary array per point. The same sums in the same order and the same vertices, normals and
  colours in the same places. Proof: a throwaway script (`build/s48/cloak_check.gd`: the hero advanced 600 frames
  through walking, dashing, guarding, swings and death, the cloak mesh's vertices, normals and colours hashed every
  frame) gives `f770b80e0943a014311d69e1b95972f5d5a33a71a8860abfce6cb2ced294fac4` before and after; one `advance`
  103.0–103.6 µs before, 70.2–77.4 after (headless, 2,000 calls).
- **`SoloVat.normalized`** (every drawn owner's-model enemy, every frame): each avatar's constant drive table is
  unpacked once (low end, span, how: as it is, over the span, wrapped) and kept, instead of unpacking every spec of
  every drive every frame. The same float64 sums. Proof (`build/s48/norm_bench.gd`): 10,000 random drive sets over
  five avatars' tables, old against new, **0 differing** (byte-compared); 6.05 µs → 4.09 µs a call.
- **`VatCrowd`**: a set with no enemy left that already shows none is not written again (it showed 0 instances and
  would be told 0 again); a drive texture's floats are copied out only when the buffer is longer than the texture.
- **`EmptyDrawCull`**: the empty test is inline in its loop and reads the MultiMesh's count first, the mesh only when
  some are shown. The same answer for every pool (no MultiMesh, no mesh, none shown, or all of none: empty), so the
  same pools are hidden and shown. Bench: 213 → 143 µs a frame for 270 pools.

Not touched: the sim (`src/sim/`, `native/`), any visible rate, interpolation or particle count.

## 3. Before and after (`--spans --process`, µs a frame from the same probe; alternated)

| run (in order) | Godot lines before / after | avg frame ms | `player_avatar.gd` | `vat_crowd.gd` | `empty_draw_cull.gd` | `attack_form_view.gd` | all scripts |
|---|---|---:|---:|---:|---:|---:|---:|
| RC after 1 | 2 / 0 | 20.484 | 170 | 635 | 153 | 1,089 | 4,295 |
| RC base 1 | 2 / 2 | 21.676 | 210 | 736 | 210 | 1,270 | 4,667 |
| RC after 2 | 2 / 2 | 19.847 | 168 | 686 | 159 | 892 | 4,002 |
| RC base 2 | 2 / 2 | 21.366 | 207 | 736 | 222 | 1,057 | 4,346 |
| NR after 1 | 0 / 2 | 15.712 | 169 | 554 | 127 | 650 | 3,044 |
| NR base 1 | 2 / 2 | 15.902 | 213 | 565 | 164 | 649 | 3,139 |
| NR after 2 | 2 / 2 | 16.111 | 175 | 568 | 134 | 654 | 3,111 |
| NR base 2 | 2 / 2 | 16.224 | 216 | 560 | 163 | 661 | 3,125 |

(The order the runs were made: RC after 1, NR after 1, RC base 1, NR base 1, RC after 2, NR after 2, RC base 2, NR base 2.)
- The hero: 207–216 → 168–175 µs (about −40 µs, every run).
- The culling: 163–222 → 127–159 µs (about −30 to −60 µs, every run).
- The VAT crowd: RC 736 → 635–686 (about −50 to −100 µs); NR inside the spread (554–568 against 560–565: fewer
  owner's-model enemies drawn in that roster).
- The effects layer and the frame's average: **inside the spread** (not changed by this step; the scenario differs run
  to run).
- In all, about 0.1–0.2 ms of the probe's script time, a frame; on the owner's frame likely 0.1–0.15 ms. The lead's
  quiet run is the measure.

## 4. Still frames

`--fixed-fps 60 --shot-at=600:<png>` (the scenario's 600th frame), base twice, after once, each scenario:
```
"$GODOT" --fixed-fps 60 --path . --position -10000,-10000 --resolution 2560x1440 --windowed -s scripts/checks/frame_probe.gd \
  -- <scenario> --enemies=30 --secs=12 --warm=1 --size=2560x1440 --shot-at=600:res://build/s48/shots/<tag>_<sc>_600.png
python build/s48/pixdiff.py <a> <b> ...
baseA_rc_600.png vs baseB_rc_600.png: differing px 183694 (5.050 %), over 8/255: 55741 (1.532 %), max channel diff 220
baseA_rc_600.png vs after_rc_600.png: differing px 162763 (4.474 %), over 8/255: 56365 (1.549 %), max channel diff 222
baseB_rc_600.png vs after_rc_600.png: differing px 198652 (5.461 %), over 8/255: 60383 (1.660 %), max channel diff 225
baseA_nr_600.png vs baseB_nr_600.png: differing px 466705 (12.829 %), over 8/255: 251945 (6.926 %), max channel diff 255
baseA_nr_600.png vs after_nr_600.png: differing px 453856 (12.476 %), over 8/255: 251636 (6.917 %), max channel diff 255
baseB_nr_600.png vs after_nr_600.png: differing px 263119 (7.233 %), over 8/255: 42115 (1.158 %), max channel diff 250
```
Godot lines: 2 before and after each of the six runs (0 after the last). **Before against after differs no more than
the base against itself** (the same build twice differs by 5 % of pixels in RC and 13 % in NR: the pack effects' GPU
particles and the enemies' spawns are not frame-exact between runs). So the shots cannot show a one-pixel change; the
proof of "the same" is the exact checks of §2 (the cloak's hash, the drives' 10,000 byte comparisons, the culling's
identical test).

## 5. Tests

Lint: `gdformat --check src scripts tests` (1,966 files unchanged) and `gdlint src scripts tests` ("Success: no problems
found"). Each run `--headless --fixed-fps 60`, one process at a time (Godot lines 2 before, 0 after the set):

| run | tests | passing | failing | exit |
|---|---:|---:|---:|---:|
| the 76 unit files that name the changed classes (`tests/unit/**`, VatCrowd, EmptyDrawCull, SoloVat, PlayerAvatar, the cloak, the drives), one process | 798 | 793 | 2 (3 pending) | 1 |
| the same 76 files on the base build (this step's `src/` taken out), one process | 798 | 793 | 2 | 1 |
| `test_spawn_reuse.gd` alone, after / base | 5 / 5 | 5 / 5 | 0 / 0 | 0 / 0 |
| `tests/arch` + `tests/golden` | 13 | 13 | 0 | 0 |
| e2e: `test_e2e_blade_feel.gd`, `test_e2e_kit.gd`, `test_e2e_wardrobe.gd`, one process | 6 | 6 | 0 | 0 |

The 2 failures are `test_spawn_reuse.gd` (`test_a_second_wave_of_the_same_kinds_makes_no_mesh_or_material`,
`test_the_shared_pieces_keep_each_actors_look`), **the same on the base build**, and only in a batch: alone the file
passes on both. Raw:
```
SCRIPT ERROR: Cannot call method 'get_child' on a null value.
   at: _pieces (res://tests/unit/presentation/test_spawn_reuse.gd:43)
ERROR: The object does not have any 'meta' values with the key 'bar'.
```
An enemy built earlier in the process is batched (it has no `bar` node then): a test that depends on what ran
before it, not this step's. Not fixed here (the actors' view is step 49's). No golden moved.

## 6. Cuts not made (they would change the look, or are larger work)

| cut | likely saving (owner's frame) | why not |
|---|---:|---|
| The enemies' frame-time poses (`advance`) at the sim's 60 Hz, interpolated or not, instead of every frame | ~0.4–0.5 ms at 144 fps | a lower animation rate: changes the look |
| The effects layer laid out once a tick (the shader carrying the motion between ticks) | ~0.3–0.4 ms | the sprites' frame-to-frame motion would differ (step 40's note) |
| The owner's-model enemies batched (`EnemyBatch.KINDS` without them now) so their VAT instances are written natively | ~0.3–0.4 ms (the 16 µs an enemy of the GDScript writer) | no look change, but it needs their pose state in the batch's native columns (`native/`, not this step's) |
| The avatars' pose code without dictionaries (the Stone Thrower's, the Warden's, ...: typed arrays, the same sums) | ~0.2–0.4 ms | no look change; a rewrite of about fifteen pose files with an equality test each: too big for this step |
| The cloak's vertex buffer updated in place (`mesh_surface_update_vertex_region`) instead of a new surface a frame | ~0.03 ms | `RenderingServer.mesh_create_surface_data_from_arrays` is not exposed to scripts; encoding Godot's vertex format by hand is a risk to the exact look |
| A native drawer for the effects layer | ~0.5 ms | no look change; a large native port (the lead decides) |

## What is left

The avatars (~0.9 ms of the owner's 3.05), the effects layer's drawers (~0.7), the VAT crowd's GDScript writer for the
owner's-model enemies (~0.45), then a long tail of about 90 scripts under 20 µs each. The engine's own per-node work is
at most about 0.15 ms (not split by toggles: NOT YET RUN).

## Incident

During the base runs this step's `git stash pop` popped another step's stash (the stash list is shared by every
worktree of the repository; step 49 had pushed one between this step's push and pop): step 49's changes landed in this
worktree. They were put back on the stash list at once, unchanged (`stash@{0}`, "WIP (step 49's stash, re-pushed by
step 48: it was popped into the wrong worktree)"; a copy as a patch: `wt-s48/build/s48/step49_stash.patch`), and this
step's own stash was applied by its SHA and dropped. The later base runs used a patch instead of the stash.
