# v0.4.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3). Starts when v0.3.5 wave 1 is
merged.

## Owner decisions (2026-10-07)
- The build direction F7–F11, F13 (verbatim in `../v0.3.0/PLAYTEST_RUN_2.md`).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| SC | Enemies scale per floor (HP ×1.9, damage ×1.4) and every 30 s danger tier (×1.10, ×1.05); hordes grow from 14/30/50 to 120 alive in packs at the room edges; the sim carries 120 enemies + 200 shots at 3.66 ms a tick (evidence/HORDES.md) | this commit |

## Goldens changed on purpose
- SC: `tests/golden/fixtures/replay_ground_plane.json` (final `5171fdad…41ae` → `70ac7ca2…0add`, first different
  checkpoint tick 420) and `tests/golden/fixtures/export_smoke_hash.txt` (`9c324d3d…17f2` → `e5365ddb…7391`). Why:
  the broadphase changed from 1 m Dictionary cells to `DenseGrid` (2 m cells; actors listed by centre). Collision
  resolves each body against its candidate walls and neighbours one after another, positions updating in between, so
  a different candidate set lets a body pushed by one wall be resolved against another in the same pass. Bisected:
  with the old grids and every other SC change the old fixture matched through tick 1200. The kernel scenario has no
  enemies, so staggering and scaling don't touch it.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1 Echoes / Core theft / Depth descent in the new direction | 2026-10-07 | pending | |
| Q2 v0.5.0 before a v0.4.0 playtest | 2026-10-07 | "skip the rule, keep going to v0.5.0" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.

## Blockers
- none

## History
- 2026-10-07 — SC: scaling tables (run + spawning data), packs at room edges, staggered AI plans, DenseGrid,
  bounded flood, view pooling/bars/occlusion focus; horde bench 14.13 → 3.66 ms, `stress_ai` 6.38 → 1.73 ms;
  kernel `stress` still 2.22 ms (> 2 ms, reported). Scorecard sims against the new scaling are TU's.
- 2026-10-07 — PLAN drafted from the owner's direction while v0.3.5 wave 1 runs.
- 2026-10-07 — Owner: "skip the rule, keep going to v0.5.0". ROADMAP §0.3 waived once: v0.5.0 follows v0.4.0
  without a v0.4.0 playtest; both are played together afterwards.
