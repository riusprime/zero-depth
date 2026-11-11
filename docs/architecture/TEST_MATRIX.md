# Test matrix

What proof each kind of change needs. A version's PLAN may add stricter checks but never remove one listed here.
Evidence files are part of the deliverable, not a substitute for tests
([`../process/TEMPLATES.md`](../process/TEMPLATES.md) §3).

## 1. Toolchain and commands

- **Engine:** Godot `4.7.x`, pinned (EI-01). **Tests:** GUT `9.7.1`, vendored in `addons/gut/`.
- **Import** (run once after a clone and after adding `class_name`s):
  `godot --headless --path . --editor --import --quit`
- **Full suite** (always with `--fixed-fps 60`, so physics frames are deterministic in every test):
  `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gjunit_xml_file=build/gut.xml -gexit`
- **Hitch probe** (real time, so it runs **without** `--fixed-fps`, as its own CI step):
  `godot --headless --path . -s scripts/checks/hitch_probe.gd`
- **Local wrappers:** `bash scripts/verify.sh` and `pwsh scripts/verify.ps1`. Both import first, then run the
  suite with the same summary guards as CI (§3).
- **Lint:** `gdformat --check src scripts tests` and `gdlint src scripts tests`, with gdtoolkit pinned in
  `requirements-dev.txt`.
- **Sims and bench** are `SceneTree` scripts run with `godot --headless --path . -s <script> -- key=value …`.

## 2. Test layers

| ID | Layer | Folder | What it proves | Runs in |
|---|---|---|---|---|
| T-UNIT | Unit | `tests/unit/` | Sim and application rules in isolation: kinematics, collision, damage pipeline, effect queue, statuses, caps, RNG | CI `verify` |
| T-ARCH | Architecture lint | `tests/arch/` | Layering and sim purity ([`ARCHITECTURE.md`](ARCHITECTURE.md) §3) | CI `verify` |
| T-GOLDEN | Replay goldens | `tests/golden/` | A recorded `InputFrame` log reproduces its checkpoint hashes. Few goldens, at milestones only | CI `verify` **and** `windows` (EI-11) |
| T-HITCH | Hitch rules | `tests/unit/sim/test_hitch_rules.gd` + `scripts/checks/hitch_probe.gd` | The unit test: `project.godot` holds 60 ticks and 4 max steps; a press latched before several back-to-back ticks is consumed exactly once. The probe (real time): a 250 ms `_process` stall is followed by at most 4 sim ticks in the next frame | CI `verify` |
| T-E2E | Real-input e2e | `tests/e2e/` | Boots `main.tscn` and drives it **only** through `Input.parse_input_event` + `Input.flush_buffered_events()` + `await physics_frame`, under `--fixed-fps 60`. No direct calls into game objects, no writes to private state | CI `verify` |
| T-CONTENT | Content | `tests/content/` | Every definition validates. References resolve. Pool limits hold. Rooms re-bake identically | CI `verify` |
| T-LOCALE | Locale coverage | `tests/content/test_locale_coverage.gd` | Every key has `en` and `es`; every `tr()` literal exists | CI `verify` |
| T-GEN | Generation properties | `tests/gen/` | N seeds per biome produce valid, deterministic floors with no fallback storms | CI (200 per biome); `nightly.yml` (10,000 per biome), both from v0.3.0 |
| T-PARITY | Forecast parity | `tests/unit/presentation/` | Telegraph areas and preview numbers equal the resolved outcome (EI-07) | CI `verify` |
| T-FUZZ | Chain fuzz | `tests/unit/effects/test_chain_fuzz.gd` | 200 random loadouts of 10–30 stacks: zero `LIMIT` events, ≤ 256 events per tick | CI `verify` (from v0.2.0) |
| T-SAVE | Save round-trip | `tests/unit/sim/test_world_snapshot.gd`, `tests/unit/application/test_run_saves.gd`, `tests/e2e/test_e2e_saves.gd` | Save → load → continue gives the same hashes (and 600 more ticks stay equal). A bad save is kept and reported. Hashed state is always snapshotted (the guard) | CI `verify` (from v0.4.0) |
| T-EXPORT | Export smoke | `tests/export/export_smoke.gd` | The exported pack holds the project's content (same manifest hash), loads Spanish, runs a 600-tick `World` (an encounter from v0.1.0), and doesn't ship GUT | CI `verify` |
| T-BENCH | Bench | `scripts/bench/` | Sim tick cost against the budget in [`ARCHITECTURE.md`](ARCHITECTURE.md) §13 | Each version; result in `evidence/` |
| T-SIM | Balance sims (**retired**) | — (v0.5.5 EC removed `scripts/sims/scorecard.gd`, `scripts/sim/tuning_sim.gd`, the bots `tests/support/score_*.gd`, `run_bot.gd`, `tuning_run.gd` and `tests/unit/scorecard/`) | None. Owner, 2026-10-08: "From now on not run bot tests, because they do not represent reality". Tests that assert a balance band measured by bots (death rates, TTK, fight lengths) left the suite; scripted drivers (`FightBot`, the boss-fight drivers) stay only to prove a mechanic works (a boss takes hits and dies, a hit has a readable cause, replays match). Balance is judged by the owner's play (LOCKED_DECISIONS 2026-10-08) | Retired v0.5.5 |
| T-SHOTS | Screenshot tour | `scripts/shots/` | Every screen renders in en and es at the tested resolutions. It needs a real renderer, never `--headless` | CI `shots` (xvfb) and each release; evidence |
| T-CI | CI self-checks | `.github/workflows/` | Versions match the pins. The minimum test count holds. No `SCRIPT ERROR` or `Parse Error` in the log | CI |

## 3. CI guards against a green run that tested nothing

Deathventory's GUT exits 0 when it can't start (for example when `class_name`s weren't imported). Its CI added a
`grep "Passing Tests"` guard ([`../LESSONS.md`](../LESSONS.md) L5). Here CI fails when any of these holds:
- the GUT summary line is missing;
- the number of passing tests is below `tests/MIN_TEST_COUNT`. This is a committed integer, seeded in v0.0.1
  Step 2. The lead raises it at the end of every step and at every release, and never lowers it without an
  owner-approved reason in PROGRESS;
- the log contains `SCRIPT ERROR`, `Parse Error` or `Failed to load script`;
- the import step logs an error (no `|| true`).

## 4. Proof each kind of change needs

| Change | Needs |
|---|---|
| A sim rule (combat, effects, AI, generation, run rules) | T-UNIT tests written first. T-E2E if the player can trigger it. A sim or bench run in `evidence/` if it moves a scorecard number |
| A new player-facing feature | At least one T-E2E test that reaches it from the main menu or a dev-panel seed **through real input**. The PLAN step answers "reachable from the real game?" with the test's name |
| A new item, enemy or boss | T-CONTENT (validates), T-UNIT for its effect or behaviour, an entry in the stress matrix, and a sim row once sims exist |
| A presentation-only change | T-PARITY if it draws an area or number. T-SHOTS output for the owner. No change under `src/sim/` |
| A new screen | Gate G2 first ([`../process/OWNER_GATES.md`](../process/OWNER_GATES.md) §3), then T-SHOTS in en and es. v0.0.1's functional stubs are exempt until they're designed ([`PRESENTATION_CONTRACTS.md`](PRESENTATION_CONTRACTS.md) §9) |
| Content data only (tuning values) | T-CONTENT, plus a sim result if a scorecard metric moves |
| A save format change | Bump `save_version`, add a migration or a "can't load" path, and T-SAVE |
| A golden regeneration | Only on purpose. Named in PROGRESS "Goldens changed on purpose" with the reason, the old and new hash, and the commit |
| CI or export changes | A passing CI run on the PR, plus an export smoke log in `evidence/` |

## 5. Testing before a push

The same rule that worked in Deathventory (its ROADMAP §0.6):

| The change touches | Before pushing |
|---|---|
| Only docs, or scripts that write only under `docs/` | Nothing local; CI covers it |
| Installed assets or manifests (`assets/`) | The asset tests (`tests/content/test_assets*.gd`) |
| Code (`src/`), data (`data/`), tests, goldens, sims, the version or project files | An agent: lint + its folders and their e2e. The lead, after a merge: `scripts/ci/seams.sh`. The full suite: once per version, on the PR into `main` (GitHub, sharded) |

Since 2026-10-13 (owner; CLAUDE.md "Testing before a push" and LOCKED_DECISIONS) there is no local full suite. GitHub's `verify` runs the full suite as parallel shards (`scripts/ci/gut_shard.sh`: every test file in exactly one shard, checked) and sums their passing tests against `tests/MIN_TEST_COUNT` (`scripts/ci/check_gut_total.sh`). A release always runs the full suite, the export smoke and the screenshot tour.

## 6. A review rejects a step when

- a test calls private methods or writes private state to make a player path pass;
- evidence lacks the exact command, the raw output or the build SHA, or contains placeholder values;
- a result is described that no command produced (see [`../../CLAUDE.md`](../../CLAUDE.md), "Evidence
  honesty");
- a golden changed without a PROGRESS entry;
- `src/sim/` gained a banned token, or presentation writes sim state;
- a visible string skips `tr()`.

## 7. The native core and the batched display

What each test proves about the C++ library ([`NATIVE_CORE.md`](NATIVE_CORE.md)) and the batched views
([`PRESENTATION_CONTRACTS.md`](PRESENTATION_CONTRACTS.md) §11). A test that needs the library is **pending** when it
is not built (each file's `_built()`); with `ZD_NATIVE_REQUIRED=1` (set by CI when it restored the library) a missing
library is a failure instead.

| File | What it proves |
|---|---|
| `tests/unit/app/test_native_move.gd` | The switch takes each kernel by name; a world with no kernels has no native side; the collision passes part bodies and clear walls as the GDScript ones do; a kernel's columns come back as new arrays (an array read before the call is untouched); the same start gives the same hashes; **`determinism_probe` equals the value MSVC gives** (the cross-compiler fixture); the per-kind table agrees with `EnemyAi` for every kind, every kind runs in its mode, hooks and shapes follow `EnemyAi`, the table's numbers are the `EnemyTable`s', the native side holds what was sent and lists the script rows |
| `tests/unit/app/test_native_core.gd` | The game's start turns every kernel on unless told otherwise and gives the switch back when `Main` leaves; the dev panel's switch changes the next world only; **a save made under one sim resumes under the other** with an equal state hash, both ways |
| `tests/unit/native/test_native_geom.gd` | `dir` equals `Kin` for every angle (and the wrap), `angle_of` for seeded vectors, `turn_toward` exactly; the tables must be whole; the nav grid slot takes a world's field |
| `tests/unit/native/test_native_ai.gd` | The native side reads the table at `NativeKindTable`'s offsets; **every table kind goes through the same states at the same ticks as with GDScript**; each intent reaches its rule (the Mender heals, the Rubble Warden sheds its crust, the Ember Charger leaves its trail, the Sniper relocates, a wall sends the walk along the flow field); a horde run is the same twice and a snapshot restored mid-run continues exactly |
| `tests/unit/native/test_native_strike.gd` | The codes and shapes are the GDScript ones; **every table kind lands the same hits on the same ticks for the same damage, and fires the same shots**; a wall raised during a windup stops the hit on both sides; same twice, resumes exactly |
| `tests/unit/native/test_native_shots.gd` | A tie goes to the wall, then the lower body; a Void shot meets walls only; a shot that meets nothing advances and ends with its life; the phase gives what GDScript gives; a body killed earlier in the phase is not hit; same twice; a snapshot restored mid-run goes on as the run did |
| `tests/unit/native/test_native_nav.gd` | **The native flood equals the GDScript flood exactly** on generated floors (every cell's distance, the key, the work; `ZD_NAV_FLOORS=<n>` for more floors) and equals the reference flood; a world floods whole on its period tick; deterministic, and resumes exactly |
| `tests/unit/native/test_native_crowd.gd` | **The native crowd writer's buffers equal the GDScript writer's, bit for bit,** over 300 seeded frames; events reach the buffers on their frame; the GDScript pass is taken without the library or with the switch off; the native avatars draw the script avatars' bodies; an avatar read during native play has the latest numbers |

**Check after step 54b:** the per-kind and per-phase tests above compare the native path against the GDScript path;
the flip deletes the GDScript versions of the ported loops. Record here what each test compares against afterwards,
and whether the pending-without-library rule and `ZD_NATIVE_REQUIRED` remain.

**Not tests:** the twin probe (`frame_probe.gd -- --twin`) compares the batched enemies with a node view every frame
of a real scene; `scripts/checks/native_compare.gd` compares fight outcomes over seeds; `view_dump.gd` and
`hud_still_diff.gd` give before/after dumps and pixel diffs. Their results go into evidence, never into CI
([`../process/PERF_TOOLS.md`](../process/PERF_TOOLS.md)).

### 7.1 How to run them

```bash
bash scripts/native/build.sh                                            # the library first (native/README.md)
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/native,res://tests/unit/app -ginclude_subdirs -gexit; echo "exit $?"
```
- `tests/unit/app` is in `scripts/ci/seams.sh`; `tests/unit/native` is not, so a change to `native/` or a bridge runs
  that folder itself.
- **The rule tests with the kernels on:** the GUT pre-run hook `tests/support/native_move_hook.gd` installs the
  kernels the environment names (`ZD_NATIVE_MOVE=1`, `_AI`, `_STRIKE`, `_SHOTS`, `_NAV`, or `ZD_NATIVE_ALL=1`; `move`
  when none) and aborts the run if the library is not loaded:
  `ZD_NATIVE_ALL=1 godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd
  -gpre_run_script=res://tests/support/native_move_hook.gd -gdir=res://tests/unit/sim -ginclude_subdirs -gexit`.
  **Check after step 54b:** whether the hook and the `ZD_NATIVE_*` variables survive.
- **Run the parts together.** Each kernel passed alone before the lead first ran them all on together; an exit crash
  appeared only with two test files in one process ([`../LESSONS.md`](../LESSONS.md) L25). After a merge, run the
  native, presentation, arch and golden folders in one process.

### 7.2 A run is judged by its exit code and its totals

- **The totals:** GUT exits 0 when it cannot start a test file (a parse error, an unimported `class_name`), so a run
  passes only when its summary shows every test passing and the count is right (§3, `scripts/ci/check_gut_log.sh`).
- **The exit code:** an engine crash while quitting (a segfault, exit 139) comes after the summary, which still reads
  all passed. Only the exit code shows it. `seams.sh` fails on GUT's exit code; a hand-run command must print it
  (`echo "exit $?"`).

### 7.3 What runs only on GitHub

| Check | Where | First run |
|---|---|---|
| The Linux (gcc) build of the library, and that the engine loads it | `verify.yml` `prepare` (`scripts/ci/native_lib.sh`); the shards restore it with `ZD_NATIVE_REQUIRED=1` | the PR into `main` |
| `determinism_probe` on gcc: the cross-compiler identity | `test_native_move.gd` in a shard | the PR into `main` |
| The Windows debug and release builds, the goldens, the export with the release library | `windows.yml` | the PR into `main` |

Until that run is green, "identical across compilers" is a rule of the build, not a result. If `native_lib.sh` fails,
it removes the library so the shards run without it, and the `verify` job then fails on the `native` output.
