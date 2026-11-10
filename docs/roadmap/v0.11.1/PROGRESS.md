# v0.11.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0110` (shared with v0.11.0), from `c339458a`.

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-10.)

- **Waves 1 and 2 are done, and step 45.** Seams on `060e883b`: **674 of 674, 1,396 s of tests, 1,606 s wall** (it
  was 669, 3,185 s, 3,442 s at `ee42eafa`): [`evidence/SEAMS_TIMING.md`](evidence/SEAMS_TIMING.md).
- **Seams on `930485be` (everything merged so far): 697 of 697,** 1,117 s of tests, 1,326 s wall (22 min). The lead
  ran nothing else on the PC during it; whether the owner used the PC is not known, so the seconds are a good
  indication, not evidence.
- **Left over from Wave 2, small:** the HUD and menu half of the dead-code scan; the menu backdrop's ember mode and
  the option picker's plain look (dead since step 13); the hub station stand-in panel (only a test builds it: the
  owner was asked whether to delete it); the duplicate final-boss texture (needs model prep).
- **Wave 3 is measured** ([`evidence/PERF_AFTER.md`](evidence/PERF_AFTER.md), quiet machine, `930485be`): the
  average frame is 20–31 % shorter (20 enemies 14.8 → 10.2 ms; 60 heavy 36.7 → 27.7 ms; 120 swarmers 29.6 → 23.8 ms),
  the 1 % lows in the horde scenes about doubled (10 → 20 fps), the tick at 120 enemies 4.26 → 3.09 ms. **Every
  target is still missed** (horde tick 4.14 ms against 4; stress 3.31 against 2; no horde frame under 6.94 ms).
- **Not merged:** step 48 (`v0111-s48`, `14c6c93f`), the sim on its own thread, a switch off by default. Clean
  numbers: 4 %, 9 % and 15 % off the average frame in the three scenes, the 1 % lows unchanged, one rendered frame
  of delay, one e2e fails with it on. **The owner decides** (OWNER_TODO).
- **Next:** step 35 (the sim's old-save code; it does not depend on the native question). **Steps 36 to 38 wait**
  for the native spike (step 49, owner L16): a native core changes where the world's state lives, and the goldens are
  re-recorded from it anyway. The spike waits on the owner installing the C++ build tools (OWNER_TODO).
- **Pushed:** `claude/v0110` up to the docs commit after `930485be` (steps 47, 32 and the shard fix included), and the
  tag `archive/scripts-2026-11`.
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
| 32 | The gain is measured on a quiet machine: frames 20–31 % shorter, 1 % lows in hordes 10 → 20 fps, tick at 120 enemies −27 %; every target still missed. It caught step 31's shard bake as a script regression (fixed, `930485be`) and gave the thread trial its clean numbers | evidence `PERF_AFTER.md` |
| 47 | The heaviest pack effects draw far fewer triangles (owner L14): 129 default-detail primitives in 66 pack scenes lowered (particle spheres 64x32 → 16–40 segments, flat particle quads unsubdivided); amounts, colours, sizes, timings and shaders untouched; meshes under vertex-moving shaders left alone; one steam pulse and every cylinder cut reverted because they showed. Beams 558,848 → about 70,000 triangles with every particle alive; the catalogue's sum 9.7 M → 1.8 M. A budget test (200,000 an effect). **Look approved by the owner** from eight before/after pairs. Measured: about 1 ms off the GPU in the heavy scene, nothing off the average frame. Open: 200–300 k triangles in the PackFx row are not explained by the per-effect rows. 262 tests on the merge | `b61433f9`, merge `df3b9039` |
| 34 | A run saved by an older version is refused, kept on disk and reported once (owner: old saves do not matter until release). The run payload has one version (5); any other, or an unreadable one, is moved aside as `run.bad.<datetime>.save` with its bytes unchanged (EI-09), Continue is greyed and one line under the main menu says why (en, es), once; the profile still loads. Deleted: the three older payload versions and their defaults in `RunSaver`, the resume-time wand migration in `FloorPlan`, six tests of older payloads and a fixture. Left for step 35: everything keyed on the versioned floor rules, the sim's own migration, `three_floors.tres`. `UserDirMigration` (the one-time folder copy) and `data/wand/migration.tres` stay. **The owner's own saved run, if any, is refused once after this.** 8 new tests + the rewritten e2e | `17b0df84`, merge `83478dd3` |
| 33 | Aim bends slightly toward the nearest enemy (owner: "a bit of aim assist 10% or so"): the aim turns 10 % of its angle toward the enemy nearest the aim inside a 12° cone and 12 m; direction only, the aim distance is untouched. Applied in `PlayerInput.sample()` before the frame is quantized, so replays hold the final aim and the sim knows nothing of it; mouse and gamepad; Options → Controls switch (en, es), on by default; the three values are data (`data/tuning/aim_assist.tres`) and editable in the dev panel. The old `AimAssist` (a gamepad-only snap, never called) is rewritten. No wall check. 16 new tests; the record-and-replay e2e passes with it on; goldens identical. **Feel: OWNER ONLY** | `1405dc75`, merge `abdebe79` |
| 46 | Options → Display has a "Show FPS" switch (off by default, saved); while it is on a small counter sits top-right above the shard count, in the menus and in a run, refreshed four times a second (owner L13). An e2e test turns it on through the Options menu, reads the counter and restarts; 20 tests on its branch, 42 on the merge | `a776bc17`, merge `fa7f0223` |
| 31 | The draw is counted, and one cut taken. The count: the renderer draws 1,700–3,100 objects a frame, not 20,000 (the probe column was live objects in memory; it is now two columns, `live_objects` and `drawn_objects`). In the 60-enemy heavy fight: 1,842 draws and 2.13 M triangles, of which pack effects 589 draws and 1.39 M triangles, enemies 542 draws (8–9 each) and 0.45 M, the sun shadow pass 127 draws, the HUD a flat 389 2D draws. The cut: a shard drop cluster is one mesh per material (ShardViews 213 → 96 draws at 60 enemies); a shot diff is inside the frame-to-frame noise. Left for the owner: the pack effects' triangles (step 47), the HUD's draws, the per-enemy draws. `draw_census.gd` lists each pack effect. 1,527 + 6 tests | `e86c7be8`, merge `2b6c1141` |
| 30 | Content is checked only in debug builds (the check measured 90–110 ms of a warm load; a release build skips it), and seven sites read an enemy's kind from the compiler's table instead of compiling the enemy. 418 + 6 tests | `b8e65c49`, merge `5368d2bc` |
| 28 | A view with nothing to show does no work: twelve views (the Prism's, Seekers, Wisps, Void, blade forms, five boss views, tide waves, interphase) go quiet once everything is hidden and wake on content; their buckets fell from 15–85 µs to 2–24 µs each, about 0.5 ms a frame (busy machine). 30 state-dump hashes identical with and without the change; 1,531 + 12 tests. The split also showed `attack_form_view.gd`'s bucket is three quarters the shared effects layer's drawers, with real content, and that status visuals already skip when idle | `01cd71dc`, merge `771f603a` |
| 24 | The hero's attacks cost less a tick: `dash_abilities` 0.52–0.54 → 0.43–0.45 ms in the heavy scene (busy machine). The cost was landed hits, not projectiles: the element card lookups are remembered on the build's book, `enemies_near` reads columns, no-overlevel returns at once. New tool `scripts/checks/attack_phases.gd`; its outcome hash and `horde_phases`' are identical before and after (the lead re-ran both on the merge). Audit S1, S8, S9 had nothing to act on in this scene (a Rune Explosion build fires no projectiles); 179 tests | `227c9592`, merge `b29c79b4` |
| 26 | An enemy spawn builds almost nothing: the contact disc, team ring, dazed ring and health bar share one mesh per size and one material per colour (`ActorParts`), a VAT kind's proxy shadow is built once behind the loading cover, code-built enemy shapes are cached. In the 60-enemy heavy scene `view.actors` p99 32.9 → 5.3 ms and the 1 % lows 9–12 → 14–17 fps (busy machine). A dump of every kind's nodes, meshes and materials is identical before and after; `actor_views.gd` is under the line cap again (969 lines; its exemption removed). 1,531 + 7 tests on the merge | `8f4d19dd`, merge `c4657bad` |
| 22 | An enemy costs less a tick: at 120 enemies the tick 4.2–4.3 → 3.3–3.4 ms, `ai` 1.46 → 1.03, `move` 1.47 → 1.14, `resolve` 0.30 → 0.15 (busy machine). Kind tests are table lookups; the wall passes read local columns. `sim_bench`: horde 5.37 → 4.56 ms (target 4: still missed), stress 3.86 → 3.58 (target 2: missed). The outcome hashes at 20, 60 and 120 enemies are identical (the lead re-ran 120 on the merge) | `dfd691bf`, merge `a0618f6a` |
| 21 | The performance baseline on the owner's PC (quiet machine): the sim bench, the tick by phase at 20, 60 and 120 enemies, and three frame-probe scenes with their breakdown | evidence `PERF_BASELINE.md` |
| 18 | Code comments say what and why, not which step: the version, step and owner-line tags stripped from 7,659 comment lines in 749 files of `src/` by script; each file's code without comments is byte-identical; 1,926 version mentions remain inside sentences. The rule is in CLAUDE.md | `4c665dae` |
| 11 | The gain is measured: seams 3,442 s → 1,606 s wall, 3,185 s → 1,396 s of tests, 669 → 674 tests, all passing | evidence `SEAMS_TIMING.md` |
| 45 | A floor builds its flow fields once. A floor build set its walls up to five times (floor, shop, purposes, curse room, fountain) and rebuilt both flow fields each time; no build step reads them, so they are deferred and built once at the end (the wall grid stays current). Floor build, six seeds, before → after (ms, busy machine): 1960 → 876, 901 → 612, 4194 → 1867, 1464 → 642, 1825 → 1285, 1675 → 1200. **Identical on 168 worlds** (30 seeds × floors 1–5, 10 stepped 600 ticks, 5 resumed, 3 final arenas: state hash, snapshot, walls, both fields, grid, spawn points); the lead re-ran the baseline on the tree without the step: 168 of 168 lines equal. 34 + 96 tests. The test floor builder (`SaveLab`) opted in afterwards: `test_world_snapshot` 147.3 s → 103.2 s, `test_old_saves` 54.6 s → 32.7 s | `7f6b6847`, merge `724e8159`; `26bdbb20` |
| 13 | Every menu is in the Astral look: the Wardrobe, Progression, Training Terminal and hub station panels; `MenuStyle` and the ember rows are deleted. Hover lights a row like focus (the Astral rule); the codex and build page columns sit 20 px further right. 1,515 + 202 + 57 tests. Shots before and after sent to the owner | `72aa2039`, merge `b1b349c3` |
| 15 (b) | Unreferenced 3D-view code is gone: 25 functions, 12 constants, `final_stub_clips.gd`, the walls' `legacy_look` and its shot tool (829 lines) | `98628cae`, merge `060e883b` |
| 16 (b) | The VAT bake verifier lives in `tests/support/vat_verify.gd`; `vat_bake.gd` 831 → 574 lines; `vat_sample`/`vat_set` out of 10 avatars. 1,519 presentation tests | `64c21cb1`, merge `060e883b` |
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
- 2026-11-10 (lead): steps 13, 15b, 16b and 45 merged (`060e883b`); the merged tree imports and lints clean. Seams
  started on it on a quiet machine (the post-merge check and step 11's re-measure).
- 2026-11-10 (lead): seams on `060e883b`: 674/674 (1,396 s of tests, 1,606 s wall). Steps 18 and 11 done; the test
  floor builder opted into step 45 (`26bdbb20`). Waves 1 and 2 are complete. Next: Wave 3's baseline (step 21).
- 2026-11-10 (lead): step 21 done. The baseline overturned the audit's ranking for Wave 3 (V1 first): the enemies'
  own per-frame cost is small; the tick's per-enemy work, the spawn hitch, one always-on view script and the draw's
  object count are where the frame goes. Wave 3 rewritten in the PLAN.
- 2026-11-10 (lead): seams on `386a502d`: 674/674 (1,303 s of tests, 1,537 s wall, with two agents running Godot
  alongside). Pushed `claude/v0110` and the tag `archive/scripts-2026-11` on the owner's "Yes, push".
- 2026-11-10 (lead): steps 22, 26, 30, 28 and 24 merged; seams on `b29c79b4`: 676/676 (1,223 s of tests, 1,461 s
  wall, agents running alongside). v0.11.0 F17: two sim tests outside the seams were stale since v0.11.0 (the
  Gatekeeper's longer cross, the biome kinds in every floor's table); fixed, no game change. Step 31 corrected the
  baseline's object count. The owner asked for a Show FPS switch (L13, step 46: built on its branch) and for lighter
  effect meshes (L14, step 47: with an agent).
- 2026-11-10 (lead): steps 31 and 46 merged (42/42 on the merge; under the next seams run before a push). The owner
  asked which CPU lever actually moves the frame; the lead picked the sim on its own thread (L15) and started it as a
  trial (step 48). Open side finding from step 31: live objects grow by about 120 a second during the frame probe
  (18,530 → 20,919 in 20 s) while orphan nodes hold at about 3,000; not a draw cost, not yet explained.
- 2026-11-10 (lead): step 33 (aim assist) merged; Wave 4 is built, its feel is with the owner (OWNER_TODO).
- 2026-11-10 (lead): step 34 merged (two translation files conflicted with step 33's and were regenerated from the
  merged strings). Seams on `83478dd3`: 694/694. The owner asked how aim assist behaves on charged attacks ("I dont
  want the character snapping into the enemy"): the pull now fades in over the outer third of the cone (it came on
  whole at the edge). Steps 47 and 48 are built on their branches and wait on the owner and on clean numbers.
- 2026-11-10 (owner): step 47's look approved from eight before/after pairs (beam, rail, dust, frost status, fumes,
  fire explosion, impact, poison bubbles): "Great job on the VFX go for those I can't see any difference, so the gain is
  real". Merged once the quiet-machine measurement frees the lead's worktree.
- 2026-11-10 (lead): step 32 run on a quiet machine. It caught a regression of step 31 (the shard bake, fixed in
  `930485be`), measured step 47 (merged: about 1 ms of GPU, no frame time) and the thread trial (4–15 % of the average
  frame; the lead had expected more: under 60 fps the catch-up ticks stay on the main thread and the draw is no longer
  than the tick). Not explained: the GPU time in the 120-swarmer scene rose from 4.7 to 6.2–7.1 ms.
- 2026-11-10 (owner): a native core is on the table (L16). The compiled code need not match the GDScript sim bit
  for bit ("can we change both? … we do not have to meet all the seems and rules, if the best choice is to modify them
  we can"); the owner will install the toolchain. The lead recommended C++ through GDExtension and starts with a
  spike (step 49). Kept on purpose: the sim stays deterministic against itself, and tests run before a push.
- 2026-11-10 (lead): seams on `930485be`: 697/697 (1,117 s of tests, 1,326 s wall). Pushed.
