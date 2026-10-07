# v0.4.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3). Starts when v0.3.5 wave 1 is
merged.

## Owner decisions (2026-10-07)
- The build direction F7–F11, F13 (verbatim in `../v0.3.0/PLAYTEST_RUN_2.md`).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| BO | A second boss in every pool: the Warlord (floor 1), the Hive Lens (floor 2, splits into three Lens Drones), the Foundry (floor 3); the `flood` move; sounds, strings, image prompts ([`evidence/BOSSES_2.md`](evidence/BOSSES_2.md), [`../../art/BOSSES_2.md`](../../art/BOSSES_2.md)) | `v0.4.0 Step BO` |

## Goldens changed on purpose
- none yet (BO: none; replay and export-smoke hashes unchanged)

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
- 2026-10-07 — Step BO: three new bosses, two per pool; fight-length bands unchanged and met (melee 29.1-34.3 s, near
  59.7-68.3 s, far >= 2.8x melee); readable cause 0 violations over 12 seeds; `MIN_TEST_COUNT` 769. The Warlord's
  arena is OPEN (CROSS walled the player out of the fight on a real floor).
- 2026-10-07 — PLAN drafted from the owner's direction while v0.3.5 wave 1 runs.
- 2026-10-07 — Owner: "skip the rule, keep going to v0.5.0". ROADMAP §0.3 waived once: v0.5.0 follows v0.4.0
  without a v0.4.0 playtest; both are played together afterwards.
