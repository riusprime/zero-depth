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
| T-SIM | Balance sims | `scripts/sim/`, `scripts/sims/scorecard.gd` (v0.5.0 SCD: every scorecard cell from one command; bots in `tests/support/score_*.gd`) | Scorecard metrics ([`../balance/SCORECARD.md`](../balance/SCORECARD.md)). `tests/unit/scorecard/` runs the scorecard in quick mode (every cell produced and well-formed, records byte-reproducible) and checks each bot policy is deterministic | From v0.2.0; evidence. Quick mode in CI `verify` (v0.5.0) |
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
| Code (`src/`), data (`data/`), tests, goldens, sims, the version or project files | The full suite, from a clean worktree of the commit |

A release always runs the full suite, the export smoke and the screenshot tour.

## 6. A review rejects a step when

- a test calls private methods or writes private state to make a player path pass;
- evidence lacks the exact command, the raw output or the build SHA, or contains placeholder values;
- a result is described that no command produced (see [`../../CLAUDE.md`](../../CLAUDE.md), "Evidence
  honesty");
- a golden changed without a PROGRESS entry;
- `src/sim/` gained a banned token, or presentation writes sim state;
- a visible string skips `tr()`.
