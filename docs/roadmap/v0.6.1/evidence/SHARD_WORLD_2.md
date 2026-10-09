# v0.6.1 Step SW2: portal shards and the build picker's title (evidence)

Owner answers (PLAN, 2026-10-09):
- A1: "the shop terminal is fine, the portals could have some of them around matching the color of the portal";
- A5: "yes, choose weapon".

Build: the step's working tree on top of `3dafbeadc9f77d2a76267d1be4f5cc154f588efb` (`claude/lucid-fermat-9wv2tf`).
The commit SHA is the step's own commit (`v0.6.1 Step SW2: …`). Godot `4.7.2.stable.official.ed1daf0bf`, Linux cloud
container, lavapipe (`llvmpipe`) for the shots. Presentation and strings only: no file under `src/sim/` changed.

## What was done
| Piece | Where |
|---|---|
| Portal shards (A1). Clusters of outlined, lit `ShardMesh` shards: one at each pillar's foot (7 shards, 1.15 m), a small one in front of each pillar (4 shards, 0.5 m), and one on each end of the lintel (5 and 3 shards). Four floating fragments bob beside the pillars. Each foot cluster has a soft additive glow. All of them share one material in the portal's own colour: `visor_blue()` (the gate's swirl, light and floor glow), then `DEEP_VIOLET` after `set_deep()` (the Deep gate). The colour comes from the same calls the gate uses, so the shards always match it. The material is lit by the scene, with emission on from creation: 0.35 while sealed, 0.8 when open, plus up to 0.9 during the gate's flare (energies only). Every solid shard below the lintel stays at least `SHARD_CLEAR_Z` = 1.6 m from the centre line (the opening is 2.4 m and the walk-in square 3.0 m wide). Nothing goes behind the wall line (x ≥ −0.4 m). The stone, the swirl, its light and glow, the Deep gate's red frame, the sealed/open states and the flare are unchanged | `src/presentation/world_view/portal_gate.gd` |
| The arrival column (v0.3.5 PT, `PortalTransitView`) gets **no** clusters. It is a 0.8 s beam of light on the hero's own spot, with no fixed place in the room, so it does not read as a portal. The way-in and arrival animations are untouched | — |
| Build picker title (A5): `UI_CHOOSE_BUILD` is now "CHOOSE YOUR WEAPON" / "ELIGE TU ARMA". The picker's existing all-caps style is kept; the owner's words are "Choose your weapon" / "Elige tu arma". Same key, so the picker's code is unchanged | `locale/strings.csv` (+ the re-imported `strings.en/.es.translation`) |
| Audit rows marked with the owner's answers: W10 and W11 applied in SW2; W8 (shop terminal) and the other awaiting rows kept; W2 stays violet (A2) | [`SHARD_AUDIT.md`](SHARD_AUDIT.md) |
| Shot script | `scripts/shots/portal_shards.gd` |

Not touched: `shard_dressing.gd` and `shard_cluster.gd` (step SD2), the shop terminal, the other audit rows, the
transit view, anything from v0.5.9/v0.6.0, and the sim.

## Tests
- New `tests/unit/presentation/test_portal_shards.gd` (5 tests):
  - both gates have ≥ 4 clusters, ≥ 3 fragments and ≥ 20 outlined shards, all on one lit material with emission;
  - the shards wear the gate's own colour: the visor blue, equal to the gate light's colour and the swirl's
    `color_mid`; on the Deep gate, `DEEP_VIOLET`; the glows match too;
  - no solid shard vertex (crystal or outline shell, measured in the gate's frame) below the lintel is nearer the
    centre line than 1.6 m, which is wider than both the 2.4 m opening and the 3.0 m walk-in square; none is behind
    the wall line, and the glows stay off the opening;
  - the 14 stone blocks and the opening's quad are unchanged; the shards are brighter open than sealed and brighter
    in the flare, return to the open level after it, and their emission is never toggled; the gate's own flare
    still runs;
  - the fragments bob near their spots.
- `tests/unit/presentation/test_plaques.gd`: new `test_the_build_picker_title_is_choose_your_weapon` checks the en and es
  text. The existing check that the title fits the plaque in en and es still passes with the new words.
- Unchanged and passing: `test_portal_gate.gd` (opening clear, visor blue, sealed toggle), `test_routes_view.gd`
  (the Deep gate reads apart), `test_portal_transit_view.gd`; e2e `test_e2e_portal.gd`, `test_e2e_routes.gd`,
  `test_e2e_builds.gd`, `test_e2e_floor.gd`; arch `test_layering.gd`, `test_sim_purity.gd`.
- `tests/MIN_TEST_COUNT` is not raised here. Another wave-2 agent adds tests too, so the lead sets it after the merge.

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_portal_shards.gd,res://tests/unit/presentation/test_portal_gate.gd,res://tests/unit/presentation/test_plaques.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_portal.gd,res://tests/e2e/test_e2e_routes.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_floor.gd,res://tests/arch/test_layering.gd,res://tests/arch/test_sim_purity.gd -gexit
XDG_DATA_HOME=<empty folder> timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy \
  --resolution 1280x720 -s scripts/shots/portal_shards.gd
cp build/shots/v0.6.1/portal_shards/gate_crop.png docs/roadmap/v0.6.1/evidence/portal_shards_gate.png   # by hand
cp build/shots/v0.6.1/portal_shards/deep_crop.png docs/roadmap/v0.6.1/evidence/portal_shards_deep.png   # by hand
```
The full suite was not run. Per CLAUDE.md, agents run lint and the tests of what they touched, and the lead runs one
full suite after the wave.

## Raw output
Import: `exit 0`.

Lint:
```
628 files would be left unchanged
Success: no problems found
```

The new and touched test files:
```
Scripts               3
Tests                22
Passing Tests        22
Asserts            9442
---- All tests passed! ----
exit 0
```

`tests/unit/presentation`, the folder of the new and touched tests. The log has 0 "SCRIPT ERROR" lines:
```
Scripts              61
Tests               372
Passing Tests       372
Asserts           771254
Time              154.833s
---- All tests passed! ----
exit 0
```

E2e and arch. The log has 0 "SCRIPT ERROR" lines:
```
res://tests/e2e/test_e2e_portal.gd
res://tests/e2e/test_e2e_routes.gd
res://tests/e2e/test_e2e_builds.gd
res://tests/e2e/test_e2e_floor.gd
res://tests/arch/test_layering.gd
res://tests/arch/test_sim_purity.gd
Scripts               6
Tests                16
Passing Tests        16
Asserts            7578
Time              44.752s
---- All tests passed! ----
exit 0
```

Screenshot run (renderer, 1280 × 720):
```
portal_shards: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1280, 720)
portal_shards: frame 20 step boot
portal_shards: res://build/shots/v0.6.1/portal_shards/gate.png (frame 31, tick 64) gate_pos=(-33.295, 0.0, 79.45) deep=false sealed=true shard_colour=2bc4e2 clusters=6 mood=true
portal_shards: frame 40 step deep
portal_shards: res://build/shots/v0.6.1/portal_shards/deep.png (frame 41, tick 104) gate_pos=(-38.095, 0.0, 79.45) deep=true sealed=true shard_colour=8b3dff clusters=6 mood=true
portal_shards: done
exit 0
```
- `shard_colour=2bc4e2` is the visor blue, and `8b3dff` is `DEEP_VIOLET`.
- `mood=true` means the floor's v0.5.9 lighting mood is on (Ruins).

The shots (crops round each gate, ×2 nearest):
- [`portal_shards_gate.png`](portal_shards_gate.png) (sha256 `2af208dc…16dbe7e`): the gate, sealed, with light-blue
  clusters at the pillars' feet and on the lintel. The Deep gate stands 4.8 m to its left.
- [`portal_shards_deep.png`](portal_shards_deep.png) (sha256 `13375c26…6e3f469`): the Deep gate, sealed, with violet
  clusters.

On this seed both gates stand against the room's wall nearest the camera, so the iso camera sees them from behind
the wall. The wall hides part of the foot clusters, while the lintel clusters and fragments show.

SHOT HELPER (labelled in the script): the hero is placed at the clear spot in front of each gate
(`ActorStore.set_pos`) instead of walked there.

A first run of the script also tried to show the gates open by calling `PortalGate.set_sealed(false)` on the view.
The view re-syncs the seal from the sim every tick, and its log printed `sealed=true` for those shots, so that helper
was dropped and the script re-run (the run above). No open-gate shot exists. The open state is covered by the unit
test only.

## Owner
- How the portal shards read in play (their size and brightness, and whether the two gates' clusters, which nearly
  meet between them, look right): **OWNER ONLY**.
- The title in caps ("CHOOSE YOUR WEAPON" / "ELIGE TU ARMA"), matching the picker's previous style: **OWNER ONLY**.
