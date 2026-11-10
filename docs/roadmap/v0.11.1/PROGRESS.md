# v0.11.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0110` (shared with v0.11.0), from `c339458a`.

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-10.)

- **Wave 1 done except its re-measure** (owner, 2026-11-10: "go for the full plan until finished"): steps 1, 2, 3, 4,
  5, 7, 8, 9, 10 merged; 6 dropped (measured). Step 11 (the seams re-measure) runs at the next quiet point.
- **Wave 2 under way:** steps 12, 14, 15 (sim, application, content half), 16 (first half), 17, 19 and 20 are done.
  With agents: step 13 (menus in Astral, `wt-s13`), steps 15b and 16b (3D-view dead code; the VAT bake verifier out of
  the game, `wt-s15b`) and step 45 (a floor builds its walls and paths once, `wt-s45`).
- **Left in Wave 2:** 18 (the comment tags), and the HUD and menu half of the dead code after step 13.
- **The baseline:** seams took 3,442 s at `ee42eafa` (669/669). No seams run since: every merge was checked by its
  own tests, an import and lint. **Run seams before pushing.**
- **What the measurements say:** the e2e fixed cost is the floor build (about 2.5 s world + 2.2 s view per run
  start), not the boot, the hub or the content compile ([`evidence/E2E_FIXED_COST.md`](evidence/E2E_FIXED_COST.md)).
- **Not pushed yet:** everything since `c339458a` is local on `claude/v0110`.
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
| 2 | The seams run no longer generates five thousand floors: the generation and loot tests moved to `test_five_floors_soak.gd` (GitHub's `sim_c` shard). `test_five_floors.gd`: 1,619.0 s → 28.8 s (the after time with three Godot processes running) | `4200f6bf`, merge `9645f5a4` |
| 4 | Seed loops run 200 seeds here and 1,000 in the GitHub full suite (`Seeds.count`, `ZD_FULL_SEEDS`). 14 loop files; every count threshold was already a share of the seed count, so it scales exactly; no test had to stay at 1,000; three files also passed at 1,000 | `47caac3f`, merge `9645f5a4` |
| 8 | The modifier smoke no longer repeats itself (21.3 s of seams); the e2e tests share one dev-panel click helper (`E2e.click_dev`, 81 files, 199 call sites; 120 of 120). The other copied helpers (`_walk`, `_focused`, `_take_at_altar`) differ between files and stay until next touched | `bca5cb87`, `9abea87b` |
| 12 | The HUD has one style: LINE, BARE, SLATE and EMBER are gone (987 lines out, 348 in, 34 files). 1,515 of 1,515 presentation tests; a before/after shot compared by HUD region shows no bar, plate, frame or text changed. 18 asserts about the removed styles went. The Astral key labels have no fit test yet (the old one measured a removed pill) | `40d2fea3`, merge `a70e0dee` |
| 16 | The fight bot, the lab-room scenario and the combo card live in `tests/support`. Left in `src/`: `KernelScenario` and `ScriptedInput` (the export smoke runs them inside the pack); left in `data/`: the combat-lab encounter and the patch notes (moving either changes the content manifest hash) | `35176162`, merge `d8362cd8` |
| 15 (a) | Unreferenced sim, application and content code is gone: 34 functions, 34 constants, 25 translation keys (249 lines). Left: names that stand for stored values, and `HeartRoom.take_tick` (hashed, read nowhere: for step 36) | `62d24bee`, merge `0ef222b0` |
| 19 | The line cap can't be switched off quietly: `tests/arch/test_line_cap.gd` lists the ten exempt files with reasons; the rule is in CLAUDE.md | `63ce6be5` |
| 20 | Walls fade again when the floor's wall list changes: the wall-fade index counted itself, so only a camera tilt rebuilt it (a latent bug; no symptom was confirmed). A regression test | `da22a46e` |
| 17 | A local export no longer packs the raw-art folders (export smoke: 0 misses). The duplicate final-boss texture needs model prep and is left (PLAN row 17) | `8d91809b` |
| 14 | The avatars carry no outline or X-ray plumbing (894 lines out, 456 in, 87 files; `technique` 139 → 0). 1,516 of 1,516 presentation tests. Proof of an unchanged look: a dump of every avatar's pieces, meshes and material values is byte-identical before and after (935 lines). The shot scripts could not prove it: they differ as much between two runs of the same code. **For the owner's eye in the next playtest** | `e8828f65`, merge `4437fd20` |
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
- 2026-11-10 (lead): **measured, and the plan changed.** A quiet re-time of the seams e2e files after step 5 showed no
  measurable gain (697.4 s → 793.2 s; the quick start saves about 1.3 s a test, under the run-to-run noise). Probes
  then showed a boot is 0.2 s, the hub walk 0.4 s, the arrival 1.2 s, and a run start's load about 6 s: the world
  build 2.5 s and the view build 2.2 s. The content load and compile are under 100 ms. More than half the world
  build is the walls and paths rebuilt two or three times. So: step 6 dropped, step 30 cut down, step 45 added.
  Audit findings T1, T5 and U3 overestimated their costs.
- 2026-11-10 (lead): steps 2 and 4 merged (`9645f5a4`), step 8 done (`bca5cb87`, `9abea87b`). Seams not re-run yet:
  it waits for step 45, so one quiet run measures the whole wave (step 11).
- 2026-11-10 (lead): Wave 2 steps 12, 14, 15a, 16, 19 merged (`4437fd20`); the merged tree imports with no script
  error and lints clean. No seams run yet on the merged tree.
