# v0.0.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: _not cut yet_ (cut it from `origin/main`; see PLAN Step 0, O3).

## Owner decisions (2026-10-06)
- **Engine:** Godot 4 3D with a fixed orthographic iso camera. The simulation is a flat 2D plane.
- **Floors:** procedural. 3 biomes first (Ruins, Night Rocks, Red Canyon); more are added during balancing,
  before content complete.
- **Platform:** Windows, with mouse+keyboard and twin-stick gamepad parity from day one.
- **Kickoff deliverable:** the starter doc kit.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Starter doc kit (all docs; no code) | see `git log` (first commit) |

## Goldens changed on purpose
- None. The replay golden and the export-smoke hash are created in Step 4 and Step 3.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Renderer pick (Forward+ / Compatibility) | after Step 8 | pending | |
| Camera pitch (30° / 35.26° / 45°) | after Step 8 | pending | |
| Occlusion technique (fade / X-ray / both) | after Step 8 | pending | |
| Owner Windows check | after Step 13 | pending | |

## Open
- O1 gap analysis text pasted into `docs/design/ROGUELIKE_GAP_ANALYSIS_v0.1.md` (owner).
- O2 reference image at `docs/art/reference/biomes_reference.png` (owner).
- O3 `main` branch exists (owner).
- O4 the owner's credit line (owner).
- The Godot `4.7.x` pin and the `gdtoolkit` pin, recorded here when chosen.

## Blockers
- None.

## History
- 2026-10-06 — Starter doc kit committed. Next: Step 0 (setup, Deathventory ports).
