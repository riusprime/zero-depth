# v0.0.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: _not cut yet_ (cut it from `origin/main`; see PLAN Step 0, O3).

## Owner decisions (2026-10-06)
- **Engine:** Godot 4 3D with a fixed orthographic iso camera. The simulation is a flat 2D plane.
- **Floors:** procedural. 3 biomes first (Ruins, Night Rocks, Red Canyon); more are added during balancing,
  before content complete.
- **Platform:** Windows, with mouse+keyboard and twin-stick gamepad parity from day one.
- **Kickoff deliverable:** the starter doc kit.
- **Design sources:** the reference image is in the repo (`docs/art/biomes_reference.png`). The audit framework
  is committed verbatim (`docs/design/ROGUELIKE_AUDIT_FRAMEWORK.md`).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Starter doc kit (all docs; no code) | `1e1a046` |
| — | Reference image (owner upload) | `566e3cb` |
| — | Kit review fixes, audit framework, sampled palette | see `git log` |

## Goldens changed on purpose
- None. The replay golden and the export-smoke hash are created in Step 4.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Renderer pick (Forward+ / Compatibility) | after Step 7 | pending | |
| Camera pitch (30° / 35.26° / 45°) | after Step 7 | pending | |
| Occlusion technique (fade / X-ray / both) | after Step 7 | pending | |
| Bench reading (O5) | with the Step 7 gates | pending | |
| Player-kit starting values | with the Step 7 gates | pending | |
| Owner Windows check | after Step 13 | pending | |

## Open
- O1 the gap analysis report for `docs/design/ROGUELIKE_GAP_ANALYSIS_v0.1.md`, or the owner's word that the audit
  framework is all there is (owner).
- O3 `main` branch exists (owner).
- O4 the owner's credit line (owner).
- O5 the bench reading: which scene the "≥ 15× real time" target applies to (owner).
- The Godot `4.7.x` pin and the `gdtoolkit` pin, recorded here when chosen.

## Blockers
- None.

## History
- 2026-10-06 — Starter doc kit committed, then reviewed by two read-only reviewers and corrected. The owner
  added the reference image and the audit framework. Next: Step 0 (repo hygiene, the Deathventory port map).
