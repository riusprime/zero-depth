# v0.11.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0110` (shared with v0.11.0), from `c339458a`.

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-10.)

- **Wave 1 under way (owner, 2026-11-10: "go for the full plan until finished").** Steps 1, 9 and 10 are done.
  Steps 3, 5 and 7 are with agents (worktrees `wt-s3`, `wt-s5`, `wt-s7`).
- **The baseline:** seams took 3,442 s at `ee42eafa` (669/669); one test that is not a seam,
  `test_generation_holds_for_every_floor_over_a_thousand_seeds`, is 1,549.9 s of it.
- **Next:** merge 3, 5, 7; then step 2 (seams runs seam tests only), 4, 6, 8 and the re-measure (11).
- **v0.11.0 playtest feedback goes first** whenever a round arrives.
- **Waiting on the owner:** which devices get aim assist (step 33; a default is planned). The golden reset is
  approved.

## Owner decisions (2026-11-10)
- Tests: speed them up; some are unnecessary.
- The four brainstorm HUD styles go; the Astral look stays and becomes the only one, menus included.
- Dead code and history comments are cleaned up.
- The line cap: the lead decides → 1,000 stays; no splits just to fit; exemptions listed and tested.
- Old run saves: refused from this version on ("old saves don't really matter until the release").
- e2e tests may skip the hub walk through a test-only switch.
- Seeds: 200 if that is enough → 200 locally, 1,000 in the GitHub full suite.
- Aim assist: wired in, "10% or so".
- Repo size: the owner asked for the implications; answered in the PLAN with the lead's recommendation (leave it).
- The golden reset: "Yes, reset once" (after reading the implications in the PLAN): steps 37–38 are approved.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| 0 | Audit, plan and docs | `17be5d16`, `927aba13` |
| 1 | The seams run records each test file's time; the baseline is measured ([`evidence/SEAMS_TIMING.md`](evidence/SEAMS_TIMING.md)) | `ee42eafa` |
| 10 | Only the live shot and check tools remain in `scripts/` (163 shot scripts and 3 checks removed; tag `archive/scripts-2026-11`) | `95189001` |
| 9 | CI lints first and imports the assets once (not run locally: it runs on the PR; `MIN_TEST_COUNT` waits for that green total) | `06f4b90e` |

## Goldens changed on purpose
- None.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| The golden reset (steps 37–38) | PLAN "The golden reset" | "Yes, reset once" | 2026-11-10 |
| Aim assist devices (step 33) | PLAN "Open items" | pending (default: mouse and gamepad, on) | |
| Feel of aim assist | after step 33 | OWNER ONLY | |
| Feel of enemies on the crowd | after each batch of step 39 | OWNER ONLY | |

## Open
- See PLAN "Open items".

## Blockers
- None.

## History
- 2026-11-10 — Audit run (read-only), plan written, the owner's decisions recorded. Next: step 1.
- 2026-11-10 (lead): the owner said to build the whole plan. Steps 1, 9, 10 done. Seams on `ee42eafa`: 669/669
  (3,185 s of tests, 3,442 s wall). Step 10 removed more than the plan's 131: scripts named only by other dead
  scripts or by the docs of shipped versions went too (163 shots, 3 checks); the import is clean after it.
