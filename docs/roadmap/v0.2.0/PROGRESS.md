# v0.2.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | `39d7b35` |
| E | Eight items that change the attacks, pickups to walk over, a no-repeat pool (sim + content; visuals and pedestals in F) | `d684c37`, merge (this commit) |
| B | A seeded floor: 3×3 rooms joined by doorways, cover slabs, item spots, spawn points, a gate spot ([FLOORS](evidence/FLOORS.md)); placed in the game in F | `40f9936`, `ee24b66`, merge `eb32d61` |
| D | A stone gate with a swirling green portal, sealed ([PORTAL](evidence/PORTAL.md)); placed in the floor in F | `85e99c7`, merge `c3caa19` |
| C | Enemies arrive continuously; cap, pace, mix and HP step up every 30 s (sim + data; wired into the floor in F) | `97e3387`, merge `6d85d36` |

## Goldens changed on purpose
- **C** (spawner state hashed: run ticks, spawn cooldown, kills): replay golden final `815b1648…91f4e6` →
  `6e73b137…010326`; export-smoke hash `39e66d22…d3756c` → `e011ccdd…a17af8`. Kernel behaviour unchanged.
- **E** (item, pickup, burn, echo, dash-hit, bounce state hashed; direct DAMAGE now carries proc_pct 100): replay
  golden `6e73b137…010326` → `cc3595c1…54c565`; export-smoke hash `e011ccdd…a17af8` → `d18fc1dc…42d4cb`.

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
- 2026-10-07 — B merged (6 tests over 50 seeds: deterministic, every room/spot/spawn/gate reachable; ~33 ms per
  floor). Notes for F: the gate isn't a wall (add a collider); slabs average ~1.2 per room (a 2.2 m spacing rule
  removed sealed pockets found in 7/50 seeds); the floor is ~45 × 39 m. 165 tests pass locally.
- 2026-10-07 — E merged (22 tests; each item's effect checked numerically). Conflicts were two append-only
  blocks (strings.csv, world_reader.gd) kept from both sides; translations reimported and checked in en/es.
  Subagent's calls for the owner: Overcharge shockwave 2.0 m / 50% (invented starting values), one shared burn
  timer refreshed per stack, Twin Arc echoes every swing (the PLAN's wording). 187 tests pass; goldens
  re-recorded.
