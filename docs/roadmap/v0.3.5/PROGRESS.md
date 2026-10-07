# v0.3.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3), from `08f7295`.

## Owner decisions (2026-10-07)
- The finishing-build feedback, F1–F22 in the PLAN (verbatim in `../v0.3.0/PLAYTEST_RUN_2.md`).
- At most 4 agents at a time; each wave merged before the next.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| PT | The portal glows the visor's light blue; going in draws, spins and dissolves the hero into light (~1.0 s, sim-held); floor 2+ opens on a light-blue arrival column (~0.8 s, sim-held); reduced motion fades instead. Evidence [`evidence/PORTAL.md`](evidence/PORTAL.md) | `c6fe6f4`, merge (this commit) |

## Goldens changed on purpose
- none (PT: `BossFlow` now hashes its transit fields, which changes the state hash of generated floors only; no
  golden fixture runs one)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| G2: HUD (calmer) mockups | — | not yet asked | |
| G2: pick card mockups | — | not yet asked | |
| v0.5.0 start before a v0.4.0 playtest (F21 vs ROADMAP §0.3) | 2026-10-07 | "skip the rule, keep going to v0.5.0" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.

## Blockers
- none

## History
- 2026-10-07 — Owner played the v0.3.0 finishing build and sent F1–F22. v0.3.0 closed as played. PLAN committed
  before code; wave 1 (K, AI, UI, PT) starts; the build-system direction (F7–F11, F13) goes to v0.4.0.
- 2026-10-07 — Owner: "skip the rule, keep going to v0.5.0". ROADMAP §0.3 waived once: v0.5.0 follows v0.4.0
  without a v0.4.0 playtest; both are played together afterwards.
- 2026-10-07 — PT: portal entry and floor arrival animations (F19, F20); `BossFlow.ENTERING` + arrival hold in
  ticks; the optional room scan reveal not built (minimap is UI's this wave). Suite 674 passing; MIN_TEST_COUNT 674.
