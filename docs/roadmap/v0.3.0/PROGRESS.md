# v0.3.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | `0c44b40`, `0ea126b` |
| A | Walls 0.6–3.0 m thick (two drawn halves per partition); a blink crosses a wall only when the free landing beyond it is within range, never into void, wall, gate or a sealed pocket; doors 2.2–3.4 m anywhere along the shared wall; cell size per floor; parametrised templates + colonnade and diagonals ([WALLS](evidence/WALLS.md)) | `435b0dd`, merge `54cf6d1` |
| N | The blade is a four-slash combo: slash, backhand, thrust, spinning finisher (10/10/12/24); per-step shapes drawn from the hit's own arc/reach; Overcharge = the finisher; Twin Arc echoes the step ([FOUR_SLASHES](evidence/FOUR_SLASHES.md)) | `880c48a`, merge `7014a75` |

## Goldens changed on purpose
- **N** (`World.echo_step` hashed; the scripted input never swings — the old golden passes with the field un-hashed):
  replay final `c798f9e5…a309df` → `5171fdad…d841ae`; export-smoke `921997d9…5e4234` → `9c324d3d…81fa17f2`.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Design questions (run, combos, items, blink walls) | 2026-10-07 | answered (PLAN "Owner answers") | 2026-10-07 |
| Boss reference sheets (from the PLAN's prompts) | 2026-10-07 | received: `docs/art/first-three-bosses-concept.png` | 2026-10-07 |
| G2: 3-card pick screen, run recap | — | not yet asked | |
| Blink vs thick walls | 2026-10-07 | "Thicker room walls" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.

## Blockers
- none

## History
- 2026-10-07 — Owner closed v0.2.0 and directed a full run (three floors, bosses, economy, pick-1-of-3, engines +
  combos, wall thickness for blink). PLAN committed before code. Workstreams A, B, C, E, G run in parallel.
- 2026-10-07 — Owner uploaded the boss sheet (`docs/art/first-three-bosses-concept.png`, L10; sent to workstream C as the 1:1 reference) and asked for a 4-slash melee combo with a stronger 4th (L11, workstream N).
- 2026-10-07 — A and N merged (one comment conflict in PlayerKit). 318 tests pass. A found that from close up a blink (5.0 m range) still crosses walls up to 4.3 m thick, i.e. every wall: asked the owner (shorter range or thicker walls). The PLAN said blink range 4.5 m; the data has 5.0 m since v0.1.0 — the PLAN line was wrong and is corrected.
- 2026-10-07 — Owner chose "Thicker room walls" (L12). B finished (7cfcaa2) but was built before A: merging gives parse errors (the boss room builder uses the removed `wall_half`). Merge aborted; B is adapting to A's wall model, applying L12 (walls up to 5 m) and sealing the boss room against blink.
