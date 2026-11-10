# v0.11.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0110` (shared with v0.11.0), from `c339458a`.

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-10.)

- **Wave 1 under way (owner, 2026-11-10: "go for the full plan until finished").** Steps 1, 9 and 10 are done.
  Steps 3, 5 and 7 are merged; steps 2 and 4 are with an agent (worktree `wt-s4`).
- **The baseline:** seams took 3,442 s at `ee42eafa` (669/669); one test that is not a seam,
  `test_generation_holds_for_every_floor_over_a_thousand_seeds`, is 1,549.9 s of it.
- **Next:** merge 2 and 4; then step 8 and the re-measure (11). Step 6 (one boot
  per e2e file) is decided from a quiet re-time of the e2e files after step 5.
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
| 7 | Walking out of a locked Leap or Barrage circle is checked in the sim. **The rest of step 7 was measured and not merged** (see History) | `8b0320ba` |
| 5 | e2e tests start a run directly through `Main.quick_start` (false in the game); the tests about the hub, the portal, the arrival and the run flow (18 files) keep the full path; a test proves both starts land on the same world hash | `95178c70`, merge `65b7f76d` |
| (v0.11.0 F15) | Five e2e tests that were already red on the branch match the game again | `e5ca5a26`, merge `3c89a227` |
| (v0.11.0 F16) | God mode stays on until it is unticked (owner, 2026-11-10) | `e8e12cb7`, `6dcd9965` |
| 3 | Tests take the game's content from one shared repository per run (`SharedContent`); the per-seed map compiles are hoisted. 608 of 608 in its runs. The gain was not measurable on a busy machine: step 11 measures it | `94060a2f`, merge `130c0b15` |

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
- 2026-11-10 (lead): **step 7 measured, mostly not merged.** The boss e2e files, narrowed to one move through the
  dev panel, got slower (signatures 29.1 s → 62.7 s, signatures_2 31.1 s → 52.0 s; the after times on a busy
  machine). The baseline shows the audit's T5 was wrong about the cost: the 9,000–18,000-frame numbers are limits
  the fixed seeds never reach; those tests already ran in about 10 s each. Kept: the new sim test. The rework stays
  on branch `v0111-s7` (`f3b9bfc3`), unmerged.
- 2026-11-10 (lead): step 5 merged (`65b7f76d`). Its full e2e run (257 tests) found 5 tests already red on the
  branch; the lead reproduced them at `8b0320ba`. Fixed as v0.11.0 F15 (`3c89a227`): all five tests were stale.
  `main.gd` is 981 lines after step 5, by moving the hub entry into `hub_flow.gd` (an overflow helper: step 44
  replaces it).
- 2026-11-10 (lead): found by F15, for the owner: the e2e walks rely on God mode from the dev panel, but closing the
  panel turns God off (`main.gd`, since `3454ed0f`), so those walks were never protected (OWNER_TODO D71).
- 2026-11-10 (lead): the owner answered D71 ("until you untick it"): built as v0.11.0 F16. All 88 test files that
  click God were run (136 tests): 3 failed, all fixed (one was a bug in the change itself: reopening the panel
  replaced the kept debug state; two tests relied on God ending when the panel closed). Re-run of the three files:
  7 of 7.
- 2026-11-10 (lead): step 3 merged (`130c0b15`). Its own finding: the hoist is not where `test_five_floors` spends its
  time (1,987 s after it, on a busy machine, against 1,619 s before on a quiet one); the time is the 5,000 floor
  generations, which steps 2 and 4 take on.
