# v0.11.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0110` (shared with v0.11.0), from `c339458a`.

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-10.)

- **Waves 1 and 2 are done, and step 45.** Seams on `060e883b`: **674 of 674, 1,396 s of tests, 1,606 s wall** (it
  was 669, 3,185 s, 3,442 s at `ee42eafa`): [`evidence/SEAMS_TIMING.md`](evidence/SEAMS_TIMING.md).
- **Seams on `2cb95232` (everything merged, step 55c included): 703 of 703,** 1,259 s of tests, 1,498 s wall, with the
  library built; and the native, presentation, arch and golden folders in one process, 1,611 of 1,611, exit 0. The
  owner was playing and an agent was probing during it.
- **Owner playtest, 2026-11-11** (the build before step 55c, native core on): "tried it, game feels really smooth,
  barely falls under 60 fps and I like that, but I think a big cost is coming from light effects in some attack forms
  like ring for example". **Measured and fixed (step 62, merged on `lead-merge`, not pushed):** the Ring cost 4.7 ms
  a frame over the Gun alone at 20 enemies; its lights cost nothing measurable; a travelling ring's pack effects were
  taken again almost every frame. Now 1.3 ms (busy machine). **For the owner to judge:** a travelling void ring's
  tendrils now stay in place along the ring where they jumped every frame (OWNER_QUESTIONS Q9).
- **Left over from Wave 2, small:** the HUD and menu half of the dead-code scan; the menu backdrop's ember mode and
  the option picker's plain look (dead since step 13); the hub station stand-in panel (only a test builds it: the
  owner was asked whether to delete it); the duplicate final-boss texture (needs model prep).
- **Wave 3 is measured** ([`evidence/PERF_AFTER.md`](evidence/PERF_AFTER.md), quiet machine, `930485be`): the
  average frame is 20–31 % shorter (20 enemies 14.8 → 10.2 ms; 60 heavy 36.7 → 27.7 ms; 120 swarmers 29.6 → 23.8 ms),
  the 1 % lows in the horde scenes about doubled (10 → 20 fps), the tick at 120 enemies 4.26 → 3.09 ms. **Every
  target is still missed** (horde tick 4.14 ms against 4; stress 3.31 against 2; no horde frame under 6.94 ms).
- **The native core (Wave 7) is merged and pushed:** the spike (49), the build (50), the design (51), the shared
  core (52a), enemy think and steering (52b), strikes (52c), the projectile sweep (53a), the path flood (53b), and
  54a: every kernel is on at the game's start when the library is built, with a dev-panel switch back (F10, Tools).
  Tick at 120 enemies 3.3 → 0.56 ms ([`evidence/PERF_NATIVE.md`](evidence/PERF_NATIVE.md)). **54b (delete the script
  versions, re-record the goldens) waits for the owner's playtest and the PR's CI** (OWNER_QUESTIONS Q7).
- **Also merged and pushed:** step 35 (the sim carries no old-save code: 3,900 lines and 57 tests gone, hash and
  goldens unchanged), step 56 (a dead enemy's cubes are one draw and last 0.5 s at any frame rate), the
  frame-attribution tooling (`scripts/checks/frame_attribution.sh`, `frame_spans.gd`).
- **Not merged:** step 48 (`v0111-s48`), the sim on its own thread: parked (OWNER_QUESTIONS Q2).
- **Wave 8 (the display layer, owner L19):** merged and pushed: steps 55, 55b, 55c (nine enemy kinds batched; their
  furniture, clocks, pose and bodies written in C++, bit-equal to the GDScript path), 57 (lightning bolts by
  shader), 58 (views read in bulk), 59 (the HUD), 60 (shard drops as instances), and the exit-crash fix. Last quiet
  run, before 55b, 55c, 58 and 60 ([`evidence/PERF_W8.md`](evidence/PERF_W8.md)): 20 enemies 8.2 ms (122 fps), 60
  heavy 24.9 ms, 120 swarmers 18.5 ms. **The quiet run after them is NOT YET RUN** (the owner is using the PC).
- **The owner's folder** is at `932d47a1` (without step 55c) with its library built; the owner is using it, so the
  lead does not touch it: `git merge --ff-only` to the pushed head and `bash scripts/native/build.sh all` there once
  the owner says the editor is closed.
- **Next:** step 54b (the native core the only one; an agent is on it) reports; the lead merges, runs seams and the
  final docs pass; the quiet run on the final code; push, the owner's folder, the PR into `main`.
- **Questions for the owner:** [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md).
- **Pushed:** `claude/v0110` up to the docs commit after `2cb95232` (pushed from the lead's worktree), and the tag
  `archive/scripts-2026-11`.
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
| 62 | A travelling ring keeps its effects: its held pack effects (the storm rim and its edge sparks, the fire, frost, venom and bleed rims) are keyed by the ring's own seed and move with it, where they were keyed by its position and so released and spawned again as it flew. Gun + Ring at 20 enemies 12.80 → 9.41 ms a frame (Gun alone 8.1); at 60 enemies 24.5 → 22.7 ms; pack spawns in an 18 s fight about 20,000 → 1,100 (busy machine: an agent's tests ran beside it). The ring's own light off, and every light off: no change beyond the spread. The other forms (Seekers, Wisps, Void, Laser, Rune Explosion, Glaive) showed no such churn. The look: rims and glow match in the before/after shot; a travelling void ring's tendrils now stay in place along the ring (they jumped each frame): the owner judges. The frame probe plays a chosen build (`--cards=`, `scripts/checks/probe_build.gd`), counts lights (`light_census.gd`) and has `--ab=no_ring`, `no_ring_light`, `no_ring_sparks`. The ring drawing moved to `form_ring.gd` (the canvas was at its cap) | `80ca8a7e`, merge `1093afd4` |
| 61 | The hub station stand-in panel is gone (owner Q6: "Sure"): the panel, its two strings and its test lines deleted; `hub_session.gd` no longer builds it | `ca73cc6a`, merge `fbafb862` |
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
| 55c | A batched enemy's clock, pose and body instance are computed and written in C++ (`zd_avatar.*`, `zd_crowd_avatars.cpp`; each avatar's state a row of packed doubles in `BatchAvatars`): the nine kinds' animation clocks, strike, tell, flinch and hold, the pose drives and the body buffers. A native view and a GDScript view of one world, 300 frames with hits, flinches, holds, a dazed Charger, kills and spawns: every buffer equal bit for bit, no tolerance. Busy machine, 120 swarmers: `vat_crowd.gd` 935 → 118 µs, `enemy_batch.gd` 810 → 117, the frame's scripts-and-views span 11.4 → 8.2 ms. Also: a batched enemy's root is freed when its view lets it go (the two tests that left orphans end with none). Not done: the per-sync loop (`actors.update` about 1.5 ms at 120) | `1af155eb`, `b2b8c3a1` |
| 60 | A shard drop is an instance of a shape built before the fight: the 48 drop shapes are static meshes built once a session at load (about 136 ms behind the cover the first time, 2.5 ms after), each drop an instance in its shape's batches. `shards.drops` 381 / 4,360 → 93 / 401 µs (mean / p99) at 120 swarmers, 292 / 5,011 → 104 / 475 at 60 heavy (busy machine); a new per-frame write of 0.13–0.18 ms while a drop lies. 0 of 518,400 pixels differ on 8 frames. 1,576 presentation tests | `3101a7b9` |
| 58 | A view is visited when something of its kind changed, and reads the sim in bulk: telegraphs, statuses, cores, burn tints and the kind-specific views walk only the actors concerned (new read-only bulk getters in `WorldReader`); the flying shard gems are two pooled batches; the per-tick reader copies columns whole. A 900-frame state dump is byte-identical; the shard burst shots differ by 0 pixels. About 0.7 ms at 120 swarmers and 0.9 ms at 60 heavy on a busy machine | `e4bf34f9` |
| 55b | A batched enemy's furniture (disc, ring, dazed ring, bar, blob) is written in C++ (`ZdCrowd`), bit-equal to the GDScript pass over 300 frames, with the GDScript pass as the fallback and the dev panel's switch turning it off; 0.25 ms at 120 swarmers. The first stage only: the avatars' clocks, the body write and the per-sync loop remain (step 55c) | `b2e4c304` |
| 59 | The HUD costs about 1 ms a frame where it cost about 2 (quiet run, PERF_W8): bars, meters and squares redraw only on a visible change, the DPS lines are written once a frame, the minimap image is moved instead of redrawn, and each still part is drawn from a texture rendered once (`HudStill`; any change switches it back the same frame). 2D draw calls 346–388 → 70–81, redraws 7–13 → 3–6 a frame. The look differs by at most 2/255 a channel at three sizes. 1,549 presentation tests + 32 HUD e2e | `6b23f3f4` |
| 57 | Lightning bolts are drawn by a shader from a few numbers each (one shared strip; a bolt used to rebuild a two-surface mesh whenever its ends moved and on every flicker): `bolt.rebuild` 0.77 → 0.06 ms and its `_process` 0.34 → 0.04 ms at 120 swarmers. The step's premise was otherwise wrong: the effects layer's sprite pools were already instanced (a one-pass buffer write measured slower), and the rest of its time feeds pack effects, which PD-13 keeps. A bolt's core now always draws over its shell (OWNER_QUESTIONS Q8) | `efc8547d` |
| 55 | Nine horde kinds have no node in the tree: their disc, ring, dazed ring, bar and blob are batches written in one pass (`EnemyBatch`); a twin of nodes run beside the batch matches it over 47,000 instances (position within 0.000002, bar fill 0). Worth 0.15 ms by itself at 120 swarmers (PERF_W8): the per-enemy script loop remains (step 55b) | `5f431804` |
| 54a | The native core is on by default in the game when the library is built (`-- --native=0` turns it off); a dev-panel switch (F10, Tools, "Native core on/off (next floor)") goes back to the script sim from the next floor or run and is not saved; tests and tools stay on the script sim unless they ask. A run saved under one sim resumes under the other, both ways, with an equal state hash. The seams' 25 e2e files pass with the library (native) and without it (script) | `a88a976d`, merge `36c644f7` |
| 53b | The path flood runs whole in C++ (behind the switch): exact (207,533,900 cells over 40 floors and 2,000 floods, 0 differ); one bounded flood 0.2 ms against 4–8 ms in GDScript, so it runs in one tick instead of sliced; `nav_flood` 0.36 → 0.045 ms a tick at 120 enemies, its worst tick about halved. A save with it on restores with it on. Two tests pin the script flood's slicing; they now turn the kernel off for themselves | `4d4d749c` |
| 53a | The projectile sweep runs in C++ (behind the switch): the sweep 0.55 → 0.035 ms a tick at 120 enemies; a 300-projectile stress scene's tick 5.7 → 2.0 ms. The hit rules (damage, pierce, bounce, split, procs, homing) stay GDScript, moved unchanged into `projectile_contacts.gd` so both paths run them. 1,072 projectile and weapon tests pass with it on; same outcome hash as GDScript in the horde scenes | `56e598d4` |
| 52c | Enemy strikes run in C++ (behind the switch): hit shapes, sight and fire timers native, returning hit, shot and hook lists that GDScript applies; `resolve` 0.19 → 0.05 ms at 120. Each of the 29 table kinds lands the same hits on the same ticks for the same damage and fires the same shots over 600 ticks; 293 rule tests pass with it on | `3f29a9dc` |
| 52b | Enemy thinking and steering run in C++ (behind the switch): the plan, the state machine, aim, table-kind steering native, returning intents that GDScript applies in row order (every random draw stays in GDScript); 20 kinds native, 9 hooked, bosses and elites script. `ai` 1.5 → 0.19 ms and `move` 1.7 → 0.19 ms at 120 (busy machine). Each table kind gives the same state sequence as GDScript over 600 ticks; a snapshot restored mid-run continues identically; 308 rule tests pass with it on. A 20-seed fight comparison (`scripts/checks/native_compare.gd`): hero damage 777 against 769, half-dead tick 2,121 against 2,212; native left stragglers in 4 seeds against 2 (kiting kinds the test bot does not finish in either version) | `5dffcf1b` |
| 56 | A dead enemy's cubes are one draw a look and last 0.5 s at any frame rate (owner L18): a pooled multimesh (cap 1,024 a look) in place of 7 nodes and 7 draws a kill; the same random flight; the life was 30 rendered frames. 1,543 presentation tests + 5 new | `dc7c5fa2` |
| 52a | The native side is one world object (`ZdWorld`) that kernels plug into: shared geometry, columns read and written by name (a read about 0.1 µs, a write about 0.3 µs), the trig tables sent from `Kin` (exact), the per-kind table built and tested against `EnemyAi` for every kind (20 native, 9 hooked, the rest script), the switch a set of kernel bits. Hashes unchanged off and with `move` on | `e7f8e26f` |
| 51 | The design of the full port | [`NATIVE_CORE.md`](NATIVE_CORE.md) |
| 50 | The native library builds from a clean checkout with one command (`bash scripts/native/build.sh`: 3.5 min cold, 35 s cached, 10 s no-op): bindings pinned by commit, the engine's API description committed, float flags fixed and guarded, a pinned determinism self-test, CI written (not run: its first run is on the PR). Fixed: the engine crashed on exit with the switch on (a lambda held in a static) | `f2f80491` |
| 49 | The native spike: enemy separation and walls in C++ through GDExtension, a switch off by default; about 20× on the ported work in the game | `3b3587b7` |
| 35 | The sim carries no compatibility code for older saves: `ADDED_SINCE_V05` and the padding (a missing field is now refused by name), the column-size guards, the wand migration, the versioned floor rules and every branch keyed on them, 57 old-save tests; `world_snapshot.gd` 1,200 → 571 lines (its line-cap exemption removed); the "old saves" seam left `seams.sh`. Hash and goldens unchanged; the 17 slow test files its agent did not reach were run by the lead on the merge (188 of 188). Open: wave arenas now run only in worlds without Lockdowns (labs and tests): maybe dead | `ad31693c`, merge `00fdf002` |
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
- 2026-11-10 (lead): tried Godot's separate render thread (`--render-thread separate`, no project change) on
  `930485be`: not usable as the game is. 20 enemies: avg 17.96 ms and 1 % low 8.8 fps against 9.92 ms and 42.0 fps on
  the default; the 60-enemy heavy scene hung (the owner saw the frozen window; the lead killed it). The log shows why
  it is slower: per-frame questions to the renderer each force a wait (`particles_is_inactive` 1,085 times in 20 s,
  `mesh_get_surface` 175, shader parameter lists 249; the probe's own GPU timer 1,108). The owner's Visual Studio
  install ran at the same time. Parked.
- 2026-11-10 (owner): installed the C++ build tools (Visual Studio Community 2026) and restarted the PC; nothing of
  the lead's was running. Steps 49 (the native spike) and 35 started.
- 2026-11-10 (lead): step 49 reported and re-run by the lead. Build: SCons 4.11.1 does not find a prerelease Visual
  Studio, so `native/SConstruct` takes the compiler's environment from `vcvars64.bat`; the bindings are built against
  the API dumped from the engine binary; a clean build takes 3.5 min. A tracked `.gdextension` without its library
  prints an ERROR on every start (CI fails the import on that), so it is written by the build from a tracked `.in`.
- 2026-11-10 (owner): "Yes, port the rest" (L17). Wave 7 written into the PLAN; steps 50 (the permanent build) and 51
  (the design) started. Steps 37 and 38 are paused until the flip; step 36 rides with it.
- 2026-11-10 (lead): step 51 done: [`NATIVE_CORE.md`](NATIVE_CORE.md) (the agent's commit `00c03cdc` on
  `v0111-s51`; the document copied here, the branch not merged because it sits on the spike). It changes one thing
  the lead had told the owner: enemies are NOT made to decide less often. Planning already runs 7.5 times a second,
  staggered by id; in C++ the per-tick part costs about 0.02 ms, so a lower rate would save nothing measurable and
  would delay attack starts. The one rate change is the path flood, run whole in one tick.
- 2026-11-10 (owner, before going to sleep): approved the display-layer changes (L19: "go ahead until you completed
  those three, then I'll play test it"); questions go to [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md). Wave 8 written.
- 2026-11-10 (lead): step 51's table of a horde frame had an "unnamed 9 ms" that does not exist. The frame-attribution
  tooling (`v0111-prof`, `7149108f`) showed the probe's three frame spans cover the whole frame; the `--process` run
  adds 5–7 ms of its own, and `engine.process` / `engine.physics_process` are per-second maxima, not per-frame means
  (PERF_AFTER's breakdown rows carry that error: read them for proportions among script buckets only). Orphan nodes
  are the pack effects' idle pools; the live-object growth is the event log filling to its cap. Steps 52a (the native
  shared core, `e7f8e26f`) and 56 (the death cubes, `dc7c5fa2`) reported; merging after the seams run, which found one
  failure: the locale key scan read the native switch's environment variable name as a text key (52a already rewrote
  that line).
- 2026-11-11 (lead): seams on `5736f08e`: 697/697. Pushed. The run before it (`00fdf002`) had one failure: the locale
  key scan read `"ZD_NATIVE_MOVE"` in `native_switch.gd` as a text key; step 52a had already rewritten that line.
  Step 52b reported (`5dffcf1b`): think and steering native; 308 rule tests pass with the switch on; each of the 29
  table kinds gives the same state sequence as GDScript over 600 ticks; a 20-seed fight comparison is close on means
  (hero damage 777 against 769) with more stragglers on the native side (4 seeds against 2), which its agent traced
  to the test bot not finishing kiting kinds in either version. Step 52c started on top of it.
- 2026-11-11 (lead): steps 53a, 53b and 52c reported and merged with 52b in the lead's worktree (`68b92b18`). The
  lead re-ran 52b's hashes (equal) and then ran every kernel together, which no agent had: the combination replays
  itself (two runs, equal hashes at 20, 60 and 120); tests off 162/162; all on 151/153, the two being the sliced-flood
  tests, fixed to turn the nav kernel off for themselves. First combined tick (move, ai, shots, nav; machine nearly
  quiet): 0.95 → 0.35 ms at 20 enemies, 1.91 → 0.50 at 60, 3.46 → 0.68 at 120.
- 2026-11-11 (lead): **the flip is split in two** (the lead's decision while the owner sleeps; OWNER_QUESTIONS Q7).
  Step 54a: the native kernels are ON by default in the game when the library is built, with a dev-panel switch to
  compare; the GDScript paths stay and the goldens stay theirs. Step 54b (delete the GDScript versions, re-record
  the goldens) waits for the owner's playtest and for CI's first run on the PR, because both are the only checks
  the lead cannot do alone: how fights feel, and whether Linux gives the same results.
- 2026-11-11 (lead): the quiet run on `68b92b18` ([`evidence/PERF_NATIVE.md`](evidence/PERF_NATIVE.md)). Tick at 120
  enemies 3.3 → 0.56 ms with every kernel on; the horde frame gains 2–3 ms. The attribution (kernels on): the
  enemies' nodes cost 6.0 ms at 120 swarmers and 8.9 ms at 60 heavy; the HUD 2.0–2.4 ms in every scene (step 59
  added: step 29 had been dropped wrongly, on script cost alone). Started: 54a, 55, 57, 59.
- 2026-11-11 (lead): seams on `36c644f7`: 703/703 with the library built. Pushed. Step 57 reported: its premise was
  mostly wrong (the effects layer's sprite pools are already instanced; a one-pass buffer write measured slower); it
  converted the one effect still rebuilt in script, the lightning bolt (`bolt.rebuild` 0.77 → 0.06 ms at 120). One
  visible change: a bolt's core now always draws over its shell (the order used to vary by bolt). Step 59 reported:
  counts firm, timing unproven on a busy machine. The Nemesis true-ending e2e (outside the seams) was failing since
  v0.11.0 F16 (God mode carried across floors: the test's second God click now turned it off); the game was fine,
  the test is fixed (`v0111-nem` `f64e5cb5`). The lead's miss when F16 was made.
- 2026-11-11 (lead): the quiet run on `9bea0088` ([`evidence/PERF_W8.md`](evidence/PERF_W8.md)): 20 enemies 8.2 ms
  (122 fps), 60 heavy 24.9 ms, 120 swarmers 18.5 ms: 2.7–3.7 ms shorter than before steps 55, 57 and 59. The HUD's
  still textures stay on. Step 55 alone is worth 0.15 ms: started step 55b (the per-enemy loop in C++) and step 58
  (the views' sync). The Nemesis test fix merged (`f64e5cb5`).
- 2026-11-11 (lead): seams on `9bea0088`: 703/703; presentation 1,560/1,560. Pushed. The library built in the owner's
  folder.
- 2026-11-11 (lead): step 55b reported (`b2e4c304`): only its first stage, the furniture written in C++ (bit-equal to
  the GDScript pass over 300 frames; 0.25 ms); about 3 ms of per-enemy script remains (step 55c started). Step 58
  reported (`e4bf34f9`): bulk reads for telegraphs, statuses, cores and kind-specific views, the flying shard gems
  batched, the per-tick reader copy; a 900-frame state dump is byte-identical and the shard shots differ by 0
  pixels; about 0.7 ms at 120 swarmers on a busy machine, the 1 % low 23 → 26 fps. It found the shards view's spike
  is the floor drops, not the bursts (step 60 started). Both merged in the lead's worktree (`b9db14da`).
- 2026-11-11 (lead): **an engine crash on exit, found by the lead's merge check, not yet explained:** with the
  library built, `test_native_geom.gd` followed by `test_enemy_vat.gd` in one process passes every test and then
  the engine segfaults while quitting (exit 139). Not step 55b (it crashes with the C++ crowd writer off); the other
  order, each file alone, the seams run and a boot of the game all exit 0. An agent is on the cause (`v0111-crash`).
- 2026-11-11 (lead): the PC restarted mid-work; nothing merged was lost, the three running agents were resumed.
  **The exit crash is explained and fixed** (`f029861c`): not native code. `ViewPrefs.apply_settings` kept a lambda in
  the static table `DebugApi.view_switches` (the dev panel's enemy-VAT switch); when `DebugApi`'s script loads before
  `ViewPrefs`'s (the native tests load it first, through `NativeSwitch`), the engine frees the lambda at quit after
  its owner and segfaults. Now a named static function; the rule is in CLAUDE.md. The game's own load order did not
  trigger it (fights on the native core and a 600-frame boot exit 0), but a later change could have. Step 60
  reported and merged with the fix (`a213977c`). The lead's re-run check of 55b and 58: presentation 1,566/1,566,
  native + arch + golden 40/40, ten e2e files 29/29, all exit 0.
- Open, small: batched enemies' roots leak when the enemy-VAT switch is flipped or a view is freed while bodies fall
  (GUT counts them as orphans; given to step 55c); `scripts/checks/hit_soak.gd` never reaches a fight (tests nothing).
- 2026-11-11 (lead): seams on `a213977c`: 703/703; native + presentation + arch in one process 1,607/1,607, exit 0.
  Pushed; the library rebuilt in the owner's folder.
- 2026-11-11 (lead): step 55c reported and merged (`2cb95232`); seams 703/703; 1,611/1,611 in one process. Pushed from
  the lead's worktree, because the owner had the editor and the game open on the main checkout (the lead had merged
  into it and tried to rebuild its library while they were open, before noticing: the build failed on the locked
  library; the owner was told to restart the game; the library was rebuilt there once the editor was closed).
- 2026-11-11 (owner, after playing): "feels really smooth, barely falls under 60 fps and I like that"; suspects the
  light effects of some attack forms, Ring for example. The lead first measured a scene without Ring (the probe's
  heavy build is Rune Explosion): omni lights off changed nothing there, which says nothing about Ring.
- 2026-11-11 (owner): answered the eight questions (OWNER_QUESTIONS "Answers"; PLAN L20). The frame target is now
  "never below 60 fps" with 144 as the ceiling. Step 54b (the native core the only one) and step 61 (the station
  stand-in panel) go ahead; the thread trial is dropped; the PR into `main` opens when the flip and seams are in.
- 2026-11-11 (lead): the Ring agent reported (`80ca8a7e`): the Ring was costly, as the owner said; the cause was
  not its lights; see the Done row for step 62. The lead had told the owner the heavy probe scene has no Ring; the
  probe's build list did include it, and the lead said so. Merged with step 61 on `lead-merge` (`1093afd4`); not yet
  under a seams run (it goes with step 54b's merge).
