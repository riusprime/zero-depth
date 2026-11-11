# v0.11.1 — Clean and fast: quicker tests, no dead code, cheaper frames (plan, owner-approved 2026-11-10)

Recorded so these decisions never depend on chat context. The audit this plan comes from:
[`../../audits/CODE_AUDIT_2026-11-10.md`](../../audits/CODE_AUDIT_2026-11-10.md) (its finding ids, such as T2 or V1,
are cited in the "Audit" column below). Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **Base:** branch `claude/v0110` at `c339458a` (v0.11.0, built, not yet merged; `main` holds v0.10.5). This version
  continues on the same branch: v0.11.0's code is what it cleans, and a second branch would conflict with every
  playtest fix. It ships in the same PR as v0.11.0 or the next one.
- **Why a patch version:** ROADMAP §0.3 and §2 allow tooling, tests, fixes and presentation work while a playtest is
  pending. **v0.11.0 playtest feedback always goes first;** these steps run between rounds.
- **Phase 0:** the audit above (2026-11-10): four read-only audits by layer plus repo-wide scans, with the main
  claims re-checked by the lead. Nothing was profiled, so Wave 3 measures before it changes anything.
- **The owner's rule for this version (2026-11-10):** "plan around [my comments] and take into account what you
  consider best for the game codebase and performance".
- **What a player can notice:** only steps 13 (the last menus in the Astral look), 33 (aim assist) and 34 (a run
  saved by an older build is not offered), plus shorter floor loads from step 45. Every other step must leave the
  game exactly as it plays today.
- **Measure before building (learned in Wave 1, 2026-11-10):** three audit findings (T1, T5, U3) were wrong about
  cost because they were read from the code. A step whose value is a time saving starts with the measurement that
  shows the time is there.
- **Agents:** as in v0.11.0 (3 Sonnet + 2 Opus, or 4 Opus with no Sonnet). **S** = Sonnet, an exact brief;
  **O** = Opus; **lead** = the lead.

## Every owner line → where it lands

| # | Owner line (2026-11-10) | Decision | Step |
|---|---|---|---|
| L1 | "Speeding the tests is something I would highly appreciate, I think they are slow and long, some times unnecessary" | Wave 1, first | 1–11 |
| L2 | "Fixing these would change how the game works or you interact with enemies or fights at all?" | No. Sim steps must give identical results (the goldens prove it); view steps must draw the same picture. Step 39 (enemies on the crowd) is the one with a feel risk, so it gets the owner's check per enemy kind | Rules below |
| L3 | "Code that no longer runs definetly needs a clean up, the four HUD styles were from a brainstorming and they stayed there, but the current new look should stay, we should not lose these last HUD rework we just did" | Delete LINE, BARE, SLATE and EMBER; Astral is untouched | 12 |
| L4 | "I don't really know if 1000 lines for a code file is better than 1200 if needed, i'll let you decide"; "enforce 1,000 with no exceptions, or raise it? what's better?" | **Keep 1,000** (lead's decision). Raising it only moves the wall: the files at the cap would grow to the new one. What changes: a file is never split just to fit; an exemption needs a written reason and is on a list a test checks. Steps 12–18 shrink most of the files that are at the cap today | 19 |
| L5 | "Clean up those then" (history comments) | Strip the version, step and owner tags; keep the sentences that explain why | 18 |
| L6 | Old saves: "sure, since im the only one developing this and only player for now, old saves don't really matter until the release" | Run saves from before this version are refused (kept on disk, EI-09). The compatibility code and its tests go. The profile (unlocks, settings) keeps loading | 34–36 |
| L7 | e2e hub walk: "yes skip them" | A test-only switch on `Main` starts a run without the hub walk and the arrival. The hub, arrival and run-flow e2e tests keep the full path | 5 |
| L8 | Seeds: "if 200 is enough go for it" | 200 seeds locally and in `seams.sh`; 1,000 in the GitHub full suite, which runs once per version. So each version still gets its 1,000 (see "Why 200 is enough") | 4 |
| L9 | AimAssist: "wire it in, i feel like aiming is just a bit hard so a bit of aim assist 10% or so would make the feeling a bit better" | Wired in. Starting values: the aim bends 10 % of the way toward the nearest enemy inside the existing 12° cone. Open: which devices (Open items) | 33 |
| L10 | Menus: "Astral current one live should be the only HUD style for all elements throughout the game" | The five panels still in the old look move to Astral; the old menu style is deleted | 13 |
| L11 | Repo size: "What are the implications of moving the raw art?" | **No change now** (lead's recommendation; see "Repo size" below). No history rewrite | — |
| L12 | Golden reset: "what's the best, and what are the implications to do this" | **Yes, once, last** (the lead's recommendation, "The golden reset" below; owner, same day: "Yes, reset once") | 36–38 |
| L13 | FPS counter (2026-11-10): "now that you are working on performance, can we add an options in settings with a toggle on/off that shows fps?" | An Options switch, off by default; a small counter in a corner of the screen while it is on, in the game and in the menus | 46 |
| L14 | Effect triangles (2026-11-10, after step 31 showed pack effects are 1.39 M of the 2.13 M triangles a frame in the heavy scene): "Could you in anyway, reduce those VFX triangles without modifying the visuals too much?" | The heaviest pack effects get lighter meshes or fewer mesh particles; the owner sees before/after shots and approves the look | 47 |
| L15 | The CPU lever (2026-11-10), after the lead listed four (enemies think less often, the sim on a thread, enemies off the node layer, native code): "I want you to pick the one that would actually move the lever, multithreading and the C# or C++ sound interesting, enemies thinking less often and Skipping the engine's node layer for crowds too" | The lead picked **the sim on its own thread** (it takes the whole tick, 3.4 ms at 120 enemies and paid twice a frame under 60 fps, off the frame without changing a result, and stays in GDScript). Built as a trial behind a switch, off by default; the owner sees the numbers and judges the feel (the picture is one rendered frame later) before it becomes the default. Second, if the trial holds: enemies off the node layer (step 39). Thinking less often saves at most about 0.7 ms a tick and nothing once the sim is on a thread; native code stays in reserve | 48 |
| L16 | A native core (2026-11-10), after the clean numbers showed the thread is a modest gain and the lead named compiled code as the largest lever: "What toolchain is the best I will install it, if we are gonna change the AI to other language does the actual code in C++ need to match those sims or can we change both? This is my game and solo proyect not released yet so we do not have to meet all the seems and rules, if the best choice is to modify them we can" | **The native code does not have to reproduce the GDScript sim bit for bit.** It must be deterministic against itself (replays, save and resume, tests); the goldens are re-recorded from it on purpose; behaviour is held by the existing rule tests and a side-by-side balance comparison. Toolchain: C++ through GDExtension (the lead's recommendation: the standard Godot build stays, direct access to the renderer for the crowd bridge, every export platform). Starts with a spike; Wave 5's steps 36 to 38 wait for its result, because a native core changes where the world's state lives | 49 |
| L17 | Port the rest (2026-11-10), after the spike measured about 20× on the ported work: "Yes, port the rest" | Wave 7 below: the hot loops move to C++ in stages, each behind the switch and measured; then one flip that makes the native core the only one, re-records the goldens and deletes the GDScript versions. The owner playtests the flip | 50–55 |
| L18 | Death cubes (2026-11-10): "what about the cube particles that pop out of an enemy when it dies? do those take a lot of effort?"; told they are cheap (the hit-feedback view is about 0.5 ms a frame) but built one node a cube and timed in rendered frames, and offered the fix: "yeah let's do it" | One draw a look instead of a node a cube; the pieces last 0.5 s at any frame rate (they lasted 30 rendered frames: 0.5 s at 60 fps, 0.2 s at 144). A visible change above 60 fps, which the owner was told | 56 |
| L19 | The display layer (2026-11-10), after the lead said the largest part of a horde frame is the views (GDScript visiting every object every frame) and named three changes: enemies as instances fed in one batch, effects computed on the GPU, views that react to events instead of polling: "Okay this plan sounds good, let's go for it, go ahead until you completed those three, then I'll play test it and see the feeling, i'll go to sleep now so if there is any open questions just wrtie them and ask them in the morning" | Wave 8 below, built after the native core, each change measured on a quiet machine before and after. Questions go to [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md). **The owner playtests at the end** | 55, 57, 58 |

## Rules for every step

- **No behaviour change** unless the step says so. A step that finds it must change behaviour stops and asks.
- **Goldens stay identical through step 35.** Steps 36–38 change them on purpose and name each one in PROGRESS.
- **Performance steps are measured, not assumed.** Step 21 records the baseline on the owner's PC; each Wave 3 step
  reports before and after from the same command. No target is invented here. A step that shows no gain is reverted
  unless it also removes code.
- **Deletions are proved by search:** before a name is deleted, a whole-word search over `src/`, `tests/`,
  `scripts/`, `data/` and every `.tscn`/`.tres`; after, lint plus the folder's tests.
- **Tests per step** follow CLAUDE.md: lint, the touched folders, the e2e that reach the change. The lead runs
  `seams.sh` after each wave, not after each step.

## Steps

### 0. Setup
- This PLAN, PROGRESS, the ROADMAP row and the decision-log row, committed first.

### Wave 1: faster tests (tests, scripts and CI only; step 5 adds one test switch to `Main`)

| Step | Outcome | Audit | Where | Done when | Agent |
|---|---|---|---|---|---|
| 1 | Seams time known per file | T2 | `scripts/ci/seams.sh` writes GUT's JUnit file to `build/`; one seams run | `evidence/SEAMS_TIMING.md` lists every file's seconds (the 2026-11-08 total was 3,131 s) | lead |
| 2 | Seams runs seam tests, not whole heavy files | T2 | `seams.sh`; the heavy cases of `test_modifier_smoke.gd`, `test_five_floors.gd`, `test_final_pace.gd` move to soak files that stay in the GitHub shards (`gut_shard.sh --check` still passes) | The three files' seam tests run in seams; nothing is dropped from GitHub | S |
| 3 | Content compiles once per test file | T4 | `tests/support` (a memoized repository and compiled tables, duplicated before a test changes them); `SaveLab`, `EventLab`; `compile_map` out of the seed loops | The touched tests pass with the same asserts | O |
| 4 | 200 seeds here, 1,000 on GitHub; floors generated once | T3, T7 | `tests/support/seeds.gd` (reads `ZD_FULL_SEEDS`), a shared floor corpus, the 13 `SEEDS := 1000` files; `.github/workflows/verify.yml` sets the variable; the ice and starglow twins become one parameterized test | Locally 200, on GitHub 1,000, same asserts | O |
| 5 | e2e tests start a run directly | T1 | `src/app/main.gd` (a static test switch beside `fixed_seed`), `tests/support/e2e.gd`, `hub_walk.gd` | Every e2e passes; the hub, arrival and run-flow tests still walk the real path | O |
| 6 | ~~One boot per e2e file~~ **Dropped, measured:** a boot is 0.2 s ([`evidence/E2E_FIXED_COST.md`](evidence/E2E_FIXED_COST.md)). The per-step sibling files are merged only when next touched | T1, T7 | — | — | — |
| 7 | Walking out of a locked Leap or Barrage circle is checked in the sim. **The rest was measured and not merged:** the boss e2e files were already at about 10 s a test; the 9,000–18,000-frame numbers in them are limits the fixed seeds never reach | T5 | A new sim test | Done | O |
| 8 | No duplicate smoke test; e2e helpers shared | T6, T9 | `test_modifier_smoke.gd`; `_click`, `_walk`, `_focused`, `_take_at_altar` into `tests/support/e2e.gd` | The 135 copies are gone | S |
| 9 | CI doesn't repeat itself | T14, T11 | `verify.yml`: cache `.godot/imported`, shards wait for lint; `tests/MIN_TEST_COUNT` from the green total | A green `verify` | S |
| 10 | Only live tools in `scripts/` | T12, T13, H4 | Tag `archive/scripts-2026-11`, then delete the 131 shot scripts and 3 checks no code references; a `scripts/shots/README.md` of the live ones; the stray `.uid` files and `PLAN.md.tmp` | Lint and the shot workflow pass | S |
| 11 | The gain is measured | — | One seams run | `SEAMS_TIMING.md` has before and after; CLAUDE.md's numbers updated | lead |

**Found by measuring Wave 1** (not in the audit):

| Step | Outcome | Audit | Where | Done when | Agent |
|---|---|---|---|---|---|
| 45 | A floor builds its walls and paths once | — | A floor build takes 1.0–4.2 s, and 55–65 % of it is `set_walls` + `prepare_wall` run two or three times (`floor_scenario.gd` `build`, `add_shop`, `add_purposes`; E2E_FIXED_COST run 5). This is the fixed cost of every e2e run start, of every unit test that builds a floor, and of every floor the player loads | The built world is bit-identical for 30 seeds × 5 floors (state hash, walls, paths) and after 600 ticks; goldens identical; the stage timings before and after | O |

### Wave 2: one look, no dead code (goldens unchanged)

| Step | Outcome | Audit | Where | Done when | Agent |
|---|---|---|---|---|---|
| 12 | The HUD has one style | D2 | `hud_style.gd` and the 32 branch sites in 13 files; their tests and `scripts/shots/hud_style.gd` | The HUD tests pass; one HUD shot for the owner | O |
| 13 | Every menu is Astral **(visible)** | D2 | `hub_station_panel.gd`, `progression_panel.gd`, `training_panel.gd`, `wardrobe_panel.gd`, `constellation_panel.gd`; then the old `MenuStyle` path in `menu_panel.gd` | One shot per panel for the owner (en) | O |
| 14 | No outline or X-ray plumbing | D3 | `actor_looks.gd`, `avatar_base.gd`, every avatar's `setup()`, the VAT look key | View tests pass; one enemy line-up shot | O |
| 15 | Unreferenced code deleted | D5, D6, D9, D10, D12 | The 48 functions, the 36 constants nothing reads, 25 translation keys, 6 unread content fields and their `.tres` values, `final_stub_clips.gd`, `legacy_look` | Lint, content tests, locale tests | S (one per layer) |
| 16 | Test code lives in `tests/` | D7, D11 | `FightBot`, `KernelScenario`, `ScriptedInput`, `StageScenario`, `ComboCard`, the Combat Lab encounter, the VAT bake verifier; `data/patch_notes` out of `load_all` | The arch lint and the tests that use them pass | O |
| 17 | A local export no longer packs the raw-art folders. **The duplicate final-boss texture is not done here:** it is not three files pointing at one picture; each `.glb` embeds the same 9.2 MB image and the importer extracts a copy per model, so sharing it means preparing the three models again (model prep, with the owner's next model delivery) | H2, H3 | `export_presets.cfg` exclude filter (`art_raw/*`, `unprocessed_images/*`, `newVFX/*`); `.gitignore` (`newVFX/`) | The export smoke: 0 misses | lead |
| 18 | Comments say why, not when | A5 | A script strips the tag prefixes (`v0.9.0 P3 (owner O32):`) per layer; a comment rule in CLAUDE.md. **After the VFX-lab branch merges** (it would conflict with every file) | Lint and import pass; a sample of 50 comments read by the lead | S + lead |
| 19 | The line cap can't be dodged | A1 | `tests/arch`: the files that disable `max-file-lines` must equal a listed set, each with a reason; stale disables removed; wrapper-only overflow files folded back where the file now fits; the rule in CLAUDE.md | The arch test | S |
| 20 | Walls fade when the wall list changes | Audit §10 | `world_view_root.gd:856` (the check compares an array with itself) | A unit test that adds a wall after the first sync | S |

### Wave 3: performance, from the baseline (same results, measured)

Re-planned 2026-11-10 from [`evidence/PERF_BASELINE.md`](evidence/PERF_BASELINE.md). The frame is bound by script,
not by the GPU: with 120 enemies the GPU takes 4.7 ms of a 29.6 ms frame. Each step starts by splitting its own
bucket, and reports the same probe before and after.

| Step | Outcome | Audit | What the baseline shows | Done when | Agent |
|---|---|---|---|---|---|
| 21 | A baseline on the owner's PC | — | Tick: 5.3 ms in the horde bench, 2.9–4.0 ms in the stress benches (targets 4 and 2). Frame: 14.8 ms at 20 enemies, 36.7 ms at 60 with a heavy build, 29.6 ms at 120 swarmers; 1 % lows 10–28 fps | **Done:** `evidence/PERF_BASELINE.md` | lead |
| 22 | An enemy costs less a tick | S6 (and S2, S4 only if the split shows them) | The tick is linear in enemies, about 35 µs each: `ai` 1.47 ms and `move` 1.48 ms at 120 (steer 0.55, pairs 0.44, walls 0.35, `ai.plan` 0.45) | `horde_phases.gd` before and after, its outcome hash chain identical; goldens identical | O |
| 24 | The hero's attacks cost less a tick | S1, S7, S8, S9 | `phase.dash_abilities` is 1.0–1.7 ms a frame with a p99 of 4–9 ms; `proj` 0.3–0.4 ms | Goldens identical; the heavy scene's phases before and after | O |
| 26 | An enemy spawn no longer hitches the frame | V2, V3, V4 | `view.actors` averages 2.8 ms but its p99 is 25–40 ms: the frames in which an enemy's view is built. These are the 10 fps 1 % lows | The frame probe's p99 and 1 % low before and after; view tests | O |
| 28 | A view with nothing to show does no work | V5, V7 | `attack_form_view.gd` runs 1.2–2.5 ms every frame; about forty idle views sync at 60–130 µs each; `status_visuals` 0.3–0.7 ms | The breakdown before and after; view tests | O |
| 31 | The draw is understood, then cut | V5, V9 | ~~20,000 objects are drawn a frame~~ (wrong: that column counted live objects in memory; the renderer draws 1,700–3,100, see the baseline's "Correction"); the draw takes 3.9–7.1 ms of the main thread | First a count of what the objects are (per pass); then the cut that count supports | O |
| 30 | Content is checked only in debug builds; an enemy's kind is read without compiling it | U4, U5 | Not on the frame; a load-time and tidiness item | Content tests; run and save e2e | S |
| 47 | The heaviest pack effects draw far fewer triangles and look the same at the game camera | L14 | Step 31: one `bx_beam_04` is 577,024 triangles (more than 60 enemies), `bx_smoke_dust` about 34,600 each; the GPU takes 10.7 ms in that scene against 4.7 ms elsewhere | A per-effect triangle table before and after; before/after shots of each changed effect at the game camera; **owner approves the look** (OWNER ONLY) | O |
| 32 | The gain is measured | — | The step 21 commands again | **Done:** `evidence/PERF_AFTER.md`. Frames 20–31 % shorter; the 144 fps target and both tick targets missed | lead |
| 48 | The sim steps on its own thread while the main thread draws (a trial behind a switch, off by default; owner L15) | — | The frame is bound by script on one core; the sim is pure (EI-02), so `World.step` can run on a worker between the views' read and the next one. A trial on a branch, after step 32 | Same outcome hashes and goldens; frame probe before and after on a quiet machine; **nothing merged until the owner has seen the numbers** | O |
| 49 | A spike: enemy movement and separation in C++ (GDExtension), measured | L16 | The tick at 120 enemies is 3.09 ms, `move` 1.10 ms of it; GDScript is interpreted. Needs the owner to install the C++ build tools (OWNER_TODO) | The extension builds on this PC and loads headless; `move` before and after in `horde_phases`; the sim still replays itself exactly; what a full port would take, from the measured factor. **Nothing merged until the owner has seen the numbers** | O |
| 56 | A dead enemy's cubes are one draw, and last as long at any frame rate | L18 | `HitFeel._burst`: 7 nodes and 7 draws a kill, a new box mesh a kill, life counted in rendered frames | Tests for the batch, the pool cap and the 0.5 s life at 60 and 144 fps; a before/after shot | S |

**Dropped from this wave by the baseline:** the HUD's redraw-on-change (step 29: the HUD is under 0.3 ms a frame),
the sound players' pool (old step 31: audio does not show in any bucket), and hits without allocations as a step
of its own (old step 23: `resolve` is 0.3–0.6 ms; it rides with step 22 only if the split shows it). Old steps 25
and 27 are inside steps 24 and 26.

### Wave 4: aim assist (sim input + tests; visible)

| Step | Outcome | Audit | Where | Done when | Agent |
|---|---|---|---|---|---|
| 33 | Aim bends slightly toward the nearest enemy | D8 | `aim_assist.gd` (a pull instead of a snap; starting values 10 % inside 12°), applied where the `InputFrame` aim is built, before quantization, so replays store the final aim (EI-04); an Options switch with en and es strings; the strength in the dev panel | Unit tests for the pull; an e2e through real input that shows the aim moved; goldens identical (they replay stored frames). **Feel: OWNER ONLY** | O |
| 46 | Options has a "Show FPS" switch; while it is on a small counter sits in a corner of the screen | L13 | Asked for by the owner during Wave 3. A `GameSettings` key (off by default), a cycler in the Options menu (en + es), a label on its own layer above the HUD and the menus, updated a few times a second | An e2e test turns it on through the Options menu and reads the counter; the setting survives a restart | S |

### Wave 5: old saves and the golden reset

| Step | Outcome | Audit | Where | Done when | Agent |
|---|---|---|---|---|---|
| 34 | Older run saves are refused **(visible once)** | D1 | `run_saver.gd` (one payload version), `floor_scenario.gd`, `floor_plan.gd`, `event_compiler.gd`, `user_dir_migration.gd`, `data/wand/migration.tres`. The file stays on disk and is reported (EI-09); the profile still loads | Save and resume e2e; a test that an older payload is refused and kept | O |
| 35 | The sim carries no compatibility code | D1 | `world_snapshot.gd` (`ADDED_SINCE_V05`, the pads), `wand_migration.gd`, the 12 column-size guards, the versioned floor-rule constants; the 84 old-save tests; the "old saves" seam leaves `seams.sh` and CLAUDE.md | Goldens identical; snapshot round-trip tests | O |
| 36 | Golden change A: dead state removed | D4, D1 | The six never-written `World` fields; `CardOrder`'s retired-card stubs | Every changed golden named in PROGRESS; the event logs of the golden replays identical before and after | O |
| 37 | Golden change B: `World`'s loose fields grouped | A3 | The 36 `spell_*`, 11 `starbound_*`, 10 `gamble_*` fields and similar into state objects (owner's OK, L12) | As step 36 | O |
| 38 | Golden change C: one hasher for every state class | R7 | A reflective hasher over the snapshot's field walk, with an explicit skip list for view-only fields; the 66 hand-written `hash_into` bodies go (owner's OK, L12) | As step 36; the replay tests' time before and after | O |

### Wave 7: the native core (owner L16, L17)

The spike (step 49) showed the shape: the sim keeps its rules in GDScript and calls one batched native entry a phase;
data crosses as packed arrays (about 5 µs a tick). Rules for every step here: the native code is deterministic against
itself and across compilers (no fast-math, no fused multiply-add, no library trigonometry: the sim's lookup tables);
it need not match the GDScript results; the switch stays off by default until the flip, so each step merges without
changing the game; each step reports `horde_phases` off against on.

| Step | Outcome | What | Done when | Agent |
|---|---|---|---|---|
| 50 | The native build is permanent | The spike merged; the bindings pinned; the engine's API description committed; one build script for Windows and Linux; the compile flags that keep results identical across compilers; CI builds and caches the library (Linux for the tests, Windows for the export) | The library builds from a clean checkout with one command; the tests run with and without it; the CI change is written (its first run is on the PR) | O |
| 51 | The design of the full port | Which data lives on the native side, the entry points, what returns to GDScript, what stays; enemies decide less often, staggered (the owner asked about lower rates; the main tick stays 60 Hz); the order of work | **Done:** [`NATIVE_CORE.md`](NATIVE_CORE.md). GDScript keeps the hashed columns; one native `ZdWorld` a world holds only caches; one batched call a phase returns intents and contacts that GDScript finishes. Build order: 52a (shared core), then 52b (think and move), 53a (projectile sweep) and 53b (the flood) in parallel, then 52c (strike). **No further rate cuts recommended:** planning already runs at 7.5 Hz, staggered; native makes the rest too cheap to be worth a visible delay. Estimate: the tick 3.08 → about 0.7 ms | O |
| 52 | Enemy AI and steering run native | `ai` 1.1 ms and `move.steer` 0.36 ms of the 3 ms tick | Behind the switch; the enemy AI rule tests pass with it on; `horde_phases` off against on | O |
| 53 | Projectiles, hits and the path flood run native | `proj` 0.5 ms, `resolve` 0.17 ms, `nav_flood` 0.28 ms | As 52 | O |
| 54a | The native core is on by default in the game | When the library is built, every kernel is on at the game's start; a dev-panel switch (and `-- --native=0`) goes back to the script sim from the next floor; tests stay on the script sim unless they ask, so the goldens stay as they are. The lead split the flip while the owner slept: the feel and the Linux results are the two checks the lead cannot make alone | The e2e seams pass with the library built (they then run native); the frame probe and `PERF_NATIVE.md` on a quiet machine | O |
| 54b | **The flip proper:** the native core is the only one (waits for the owner's playtest and the PR's first CI run; OWNER_QUESTIONS Q7) | The switch goes; the GDScript versions of the ported loops are deleted; **the goldens are re-recorded on purpose** (each named in PROGRESS); step 36's dead state goes with it; a side-by-side balance comparison of the last GDScript build and the native one over many seeds | Seams green; the comparison in evidence; `evidence/PERF_NATIVE.md` on a quiet machine. **Owner playtest: do fights feel the same? (OWNER ONLY)** | lead |
| 55 | Enemies reach the renderer in one batch | The renderer bridge (old step 39 by another road): positions and animation state written to instance buffers from the native side | Decided from step 54's numbers | O |

**Paused by this wave:** steps 37 and 38 (grouping the world's fields, the reflective hasher) are re-decided after
the flip, because the native core changes where the state lives. Step 36 rides with the flip.

### Wave 8: the display layer (owner L19)

Sized from the frame attribution run ([`evidence/PERF_NATIVE.md`](evidence/PERF_NATIVE.md), quiet machine): the enemies' nodes
cost 6.0–8.9 ms of a horde frame and the HUD 2.0–2.4 ms of every frame. Each step repeats that run.
The look must not change: each step proves it with a dump or a shot, and the owner judges the feel at the end.

| Step | Outcome | What | Done when | Agent |
|---|---|---|---|---|
| 55 | Every enemy is an instance fed in one batch | The renderer bridge (step 39 by another road, NATIVE_CORE §8): one instanced batch an enemy kind with baked animation, its rows written from the native side once a frame; the per-enemy nodes go | The enemy dump or shots match; the attribution run before and after | O |
| 55b | A batched enemy is posed and written in C++ from the sim's columns | Step 55 took nine kinds' nodes out of the tree and gained 0.15 ms (PERF_W8): the cost is the per-enemy script loop that still poses and writes each enemy, about 4 ms at 120 swarmers | The twin probe (the node path beside the batch, compared every frame) comes out as for step 55; a GDScript fallback without the library; the quiet run | O |
| 55c | A batched enemy's pose and body are computed and written in C++ | Step 55b moved the furniture write (0.25 ms); about 3 ms a frame of per-enemy GDScript remains at 120 swarmers: the per-sync loop, the avatars' animation clocks and pose, the body instance write | The buffers equal the GDScript path's bit for bit; the twin probe no worse than the GDScript batch's; the quiet run | O |
| 60 | A shard drop is an instance of a shape built before the fight | Step 58: the shards view's spike (p99 3.6–5.1 ms) is a node tree duplicated a drop and a shape baked on first use | No node a drop; no bake in a fight; a pixel diff of the drops | O |
| 57 | Effects are drawn by the GPU, not rebuilt in script | The effects layer's drawers and the attack forms (`attack_form_view.gd` is the largest script in a horde frame): instanced batches and shaders fed a few numbers an effect, in place of geometry rebuilt every frame | Shots of each changed effect match; the attribution run before and after | O |
| 58 | Views react to events instead of polling | The views' sync: a view is visited when the sim says something of its kind changed, not every frame | The idle and wake tests; the attribution run before and after | O |
| 59 | The HUD costs the frame nothing while it does not change | PERF_NATIVE: hiding the HUD saves 2.0–2.4 ms in every scene (a fifth of the 20-enemy frame): 389 2D draw calls and about 14 controls redrawn a frame (the DPS meter's label 4.6 times). Step 29 had been dropped on the scripts' cost alone; the cost is the engine's 2D drawing | The HUD looks the same (shots); 2D draw calls and redraws counted before and after; the attribution run | O |

### Wave 6: structural (each one decided from Wave 3's numbers)

| Step | Outcome | Audit | Where | Done when | Agent |
|---|---|---|---|---|---|
| 39 | ~~Every enemy is drawn by the crowd~~ **Not supported by the baseline:** the enemies' own `_process` is 0.37 ms for 120 of them (3 µs each, not the 40 µs the audit quoted); the cost in `view.actors` is the per-frame update and the spawn, which step 26 takes on. Re-decided after step 32 | V1 | — | — | — |
| 40 | A room builds only the views it needs | V7 | `world_view_root.gd` | View and e2e tests; perf log | O |
| 41 | One row table for the card states | R1 | `modifier_state.gd` (hash order kept) | Goldens identical | O |
| 42 | Enemy avatars share one base; pools share one helper | R3, R4 | `OwnerModelAvatar`, a MultiMesh pool helper | View tests; one shot per enemy kind touched | O |
| 43 | Compilers copy by rule; icons share shapes and one palette | R5, R6 | `src/application/*compiler*.gd`, the five icon files, the Astral colours | Content hash identical; HUD shots | O |
| 44 | `Main` only boots and routes | A2 | A run controller, a pause controller and the dev hooks out of `main.gd` | The run, save, menu and dev-panel e2e | O |

### R. Release
- Version bump (with or after v0.11.0's, which still waits on the owner: v0.11.0 OWNER_QUESTIONS §J N11), patch
  notes en + es, ROADMAP row + History, README status line, CLAUDE.md re-checked (testing numbers, the seams list,
  the comment and line-cap rules), PROGRESS final.

## Why 200 is enough (L8)

The seed tests check "this never happens" over many generated floors. If a change breaks 1 floor in 100, a
200-seed run catches it 87 % of the time and a 1,000-seed run nearly always. If it breaks 1 in 1,000, 200 seeds
catch it 18 % of the time and 1,000 seeds 63 %. So 200 catches anything common on every step, and the rare cases
are still caught before a version ships, because the GitHub full suite keeps 1,000. Nothing is checked less per
version; the long run moves to the machine nobody is waiting on.

## Repo size (L11): what moving the raw art would mean

- **Today:** `unprocessed_images/` (616 MB of raw models and images) and `docs/` evidence images (335 MB) are in
  plain git. The game never loads them. The cost is a slow first clone (1.1 GiB); nothing in play or in tests.
- **Moving them to LFS without rewriting history** makes new files cheap, but every old copy stays in the history,
  so the clone barely shrinks. GitHub also meters LFS storage and downloads, and every CI checkout would count.
- **Rewriting history** is what shrinks the clone, and it changes every commit id. Every SHA written in a
  PROGRESS table or an evidence file (the proof of what was run on which build) would point at nothing, and every
  clone, branch and worktree would have to be made again.
- **Recommendation:** leave it. The raw folder is also how art reaches a cloud session. Revisit before a public
  release, when the repo can be started clean. Step 10's tag and the "few shots" rule already slow the growth.

## The golden reset (L12): what it means

- **A golden** is a recorded fingerprint of the whole sim state after a fixed replay. If the fingerprint matches,
  the sim behaved exactly as before. It is the proof behind "this change didn't alter the game".
- **Steps 37 and 38 change how the fingerprint is computed** (the order of the fields, then the hashing code
  itself), so every golden gets a new value even though the game behaves the same. For that one commit the goldens
  can't be the proof.
- **The proof used instead:** the same replays are run before and after, and their event logs (every hit, spawn
  and death, in order) and a field-by-field dump of the final state must match exactly. Neither depends on the
  hash. Each of steps 36, 37 and 38 is its own commit, so a difference can be traced to one change.
- **What it buys:** about 970 hand-written hashing lines go; a new field can no longer be forgotten from the hash
  (today that is a silent determinism hole); `World` stops being a 334-field list.
- **What it costs:** three large steps, a new save format (already changing in step 34), and the cross-OS golden
  regenerated on GitHub. The replay tests may get slower, which step 38 measures.
- **Decided (owner, 2026-11-10: "Yes, reset once"):** once, as the last thing in Wave 5, when the goldens and the
  save format are changing anyway. Never piecemeal.

## Open items (what they block)

- **Aim assist, which devices (step 33):** the old decision was gamepad only. Default being built: mouse and
  gamepad, one Options switch, on by default. The owner's answer changes only the default.
- **The VFX-lab branch** (`claude/v0110-vfxlab-317952`, unmerged) touches only `src/app/galleries/` (three effects
  files), the locale and its own assets (checked 2026-11-10), so it blocks no step; step 18 skips those three files.
- **Not planned here, done when the file is next touched:** asserts that pin tuning numbers (T8), e2e tests that
  write into the sim (T10), the 322 test-only accessors, per-instance material copies (V9), inline shaders (V10),
  the sprite buffer (V8), the unused pack scenes (H5), `WorldReader`'s re-exported constants (A4, an ARCHITECTURE
  decision).

## Verification

- Per step: lint, the touched test folders and the e2e that reach the change. After each wave: `seams.sh`.
- Goldens identical through step 35; steps 36–38 named in PROGRESS with the event-log proof.
- Performance: `evidence/PERF_BASELINE.md` and `PERF_AFTER.md`, owner's PC, raw output; test time:
  `evidence/SEAMS_TIMING.md`.
- The PR's full suite on GitHub with 1,000 seeds, then the owner plays: nothing should feel different except aim
  assist and the menus.
