# v0.0.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: _not cut yet_ (cut it from `origin/main`; see PLAN Step 0, O3).

## Owner decisions (2026-10-06)
- **Engine:** Godot 4 3D with a fixed orthographic iso camera. The simulation is a flat 2D plane.
- **Floors:** procedural. 3 biomes first (Ruins, Night Rocks, Red Canyon); more are added during balancing,
  before content complete.
- **Platform:** Windows, with mouse+keyboard and twin-stick gamepad parity from day one.
- **Kickoff deliverable:** the starter doc kit.
- **The audit framework is the only design source** (no gap-analysis report). GA numbers are owner decisions; see
  `LOCKED_DECISIONS.md`.
- **Bench:** stress scene mean ≤ 2 ms, p99 ≤ 4 ms; reference encounter ≥ 15× real time.
- **Start building:** the owner asked to start v0.0.1 now, on `claude/lucid-fermat-9wv2tf` (no `main` yet).
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
| Bench reading (O5) | 2026-10-06 | 15× applies to the reference scene | 2026-10-06 |
| Player-kit starting values | with the Step 7 gates | pending | |
| Owner Windows check | after Step 13 | pending | |

## Open
- O3 `main` branch exists (owner).
- O4 the owner's credit line (owner).
- The Godot `4.7.x` pin and the `gdtoolkit` pin, recorded here when chosen.

## Blockers
- None.

## History
- 2026-10-06 — Starter doc kit committed, then reviewed by two read-only reviewers and corrected. The owner
  added the reference image and the audit framework. Next: Step 0 (repo hygiene, the Deathventory port map).
