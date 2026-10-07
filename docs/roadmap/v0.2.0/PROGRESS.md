# v0.2.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | `39d7b35` |
| D | A stone gate with a swirling green portal, sealed ([PORTAL](evidence/PORTAL.md)); placed in the floor in F | `85e99c7`, merge `c3caa19` |
| C | Enemies arrive continuously; cap, pace, mix and HP step up every 30 s (sim + data; wired into the floor in F) | `97e3387`, merge `6d85d36` |

## Goldens changed on purpose
- **C** (spawner state hashed: run ticks, spawn cooldown, kills): replay golden final `815b1648…91f4e6` →
  `6e73b137…010326`; export-smoke hash `39e66d22…d3756c` → `e011ccdd…a17af8`. Kernel behaviour unchanged.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Floor build check | after F | pending | |

## Open
- O3 `main`. O4 credit line.

## History
- 2026-10-07 — Owner directed the first floor (verbatim in `../v0.1.0/PLAYTEST_FIGHT_2.md`). PLAN committed.
  Workstreams A–D run in parallel (subagents in separate worktrees), then E and F.
- 2026-10-07 — C merged (15 new tests; subagent report: tiers, cap/interval formulas, mix unlocks, ≥ 8 m spawns,
  HP scale, no spawns after death, determinism). Goldens re-recorded once for it; 154 tests pass locally,
  export smoke 0 misses. Not yet applied: "spawn in the player's room or a neighbour" (needs B's rooms; in F).
- 2026-10-07 — D merged (portal gate, 5 tests; renders in evidence/PORTAL.md: reads well facing the camera and
  at ±45°, edge-on only a pillar shows, so the integrator avoids edge-on placement). 159 tests pass locally.
