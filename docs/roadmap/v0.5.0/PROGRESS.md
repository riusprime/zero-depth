# v0.5.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Owner decisions (2026-10-07)
- "skip the rule, keep going to v0.5.0" (ROADMAP §0.3 waived once).
- The 40–50 card pool moves here and is built now; counted **per build** (owner pick: "Per build").

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| CP | Five new stat cards that force choices (Glass Cannon, Onrush, Overkill, Hoarder, Fast Hands) and four ability mods (Cluster Payload, Overclocked Drone, Razor Orbit, Afterimage), offered only with their ability; pool per build Blade 50 / Gun 48 (58 in all); no dead cards over 300 seeds per build ([`evidence/CARD_POOL.md`](evidence/CARD_POOL.md)) | `2f7951f`, merge `1dbd7fb` |

## Goldens changed on purpose
- none

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Card pool count: per build or whole game | 2026-10-07 | "Per build" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.

## Blockers
- none

## History
- 2026-10-07 — CP built (on v0.4.0 BS) and merged on top of v0.4.0 EN + BO: 864 tests pass; goldens unchanged. The
  brief's "≈8 stat cards + ≈6–8 mods" would have overshot 50 per build; CP added 5 + 4 to fit. Owner: count per
  build. PLAN written for the rest of v0.5.0.
- 2026-10-08 — `main` now exists (from `55a895d`); Windows/Shots CI run only on `main`. Owner: PRs into `main` only for a
  playable version ("only push to main when we get something"): the next PR is the v0.4.0 + v0.5.0 build.
