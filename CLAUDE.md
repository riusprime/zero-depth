# CLAUDE.md

A real-time, low-poly isometric action roguelike in **Godot 4.7 (3D)**. The simulation is a deterministic 2D plane
stepped at 60 Hz, and a fixed orthographic iso camera draws it. The game is untitled; the token `{{TITLE}}`
stands in for the name in `README.md`, `project.godot` and `export_presets.cfg`.

The owner is **Rius**. They decide what the game is; you build it, prove it and report honestly. The process
copies what worked in the owner's previous game, Deathventory ("DV"). The rules exist because of what didn't:
[`docs/LESSONS.md`](docs/LESSONS.md).

## Start every session here

1. Read this file, then [`docs/roadmap/ROADMAP.md`](docs/roadmap/ROADMAP.md) §0 (the pickup protocol).
2. Open the active version's `docs/roadmap/vX.Y.Z/PLAN.md` and `PROGRESS.md`. Continue from the first step that
   isn't Done.
3. If there's no PLAN for the active version, you're its lead: do Phase 0 (ROADMAP §0.2), write the PLAN, and
   commit it before any code.

## Authority

A higher rank wins over a lower one. Stop and ask the owner when:
- two sources of the same rank disagree;
- a lower-ranked source looks more right than a higher one.

Never resolve a conflict quietly.

1. The owner's explicit instructions, once written into a PLAN, PROGRESS or LOCKED_DECISIONS.
2. [`docs/architecture/LOCKED_DECISIONS.md`](docs/architecture/LOCKED_DECISIONS.md) and
   [`docs/design/GAME_BLUEPRINT.md`](docs/design/GAME_BLUEPRINT.md). The blueprint draws on
   [`docs/design/ROGUELIKE_AUDIT_FRAMEWORK.md`](docs/design/ROGUELIKE_AUDIT_FRAMEWORK.md) (the five design pillars,
   the only design source).
3. [`docs/roadmap/ROADMAP.md`](docs/roadmap/ROADMAP.md), the process docs in `docs/process/`, and the contracts:
   - [`ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md);
   - [`SIM_CONTRACTS.md`](docs/architecture/SIM_CONTRACTS.md);
   - [`CONTENT_SCHEMA.md`](docs/architecture/CONTENT_SCHEMA.md);
   - [`PRESENTATION_CONTRACTS.md`](docs/architecture/PRESENTATION_CONTRACTS.md);
   - [`TEST_MATRIX.md`](docs/architecture/TEST_MATRIX.md);
   - [`SCORECARD.md`](docs/balance/SCORECARD.md);
   - [`ART_DIRECTION.md`](docs/art/ART_DIRECTION.md).
4. The active version's PLAN. It refines the ROADMAP scope for its version. It may add stubs ahead of the
   roadmap, but it drops roadmap scope only with the owner's agreement.
5. Existing code and tests.

Superseded rules are listed in ROADMAP §3.

## Hard rules

- **The sim is pure** (EI-02). `src/sim/` never uses:
  - Nodes, the scene tree or Godot physics;
  - `Input`, `OS`, `Time` or `Engine`;
  - `load()` of content;
  - `randf`/`randi`/`RandomNumberGenerator`;
  - `sin`/`cos`/`atan2`/`pow`/`exp`/`log`.

  The arch lint enforces this.
- **One clock** (EI-03). `World.tick` at 60 Hz is the only gameplay time. No `Timer`, tween or animation decides
  an outcome.
- **Input is an `InputFrame` per tick** (EI-04). Randomness comes only from named streams (EI-05).
- **Presentation reads, never writes** (EI-07). Forecasts call the same sim function as the outcome.
- **Content is typed `.tres`, validated, and discovered through `ContentScanner`** (EI-08).
- **Every visible string uses `tr()`, with `en` and `es` in `locale/strings.csv`** (EI-10).
- **Decide before you build** anything that isn't a direct fix. Use the gates in
  [`docs/process/OWNER_GATES.md`](docs/process/OWNER_GATES.md): an owner-lines table, G1 audits, G2 mockups,
  design questions.
- **No minor version without an owner playtest of the previous one** (ROADMAP §0.3).
- **Every player-facing feature is reachable from the real game,** proved by an e2e test that drives `main.tscn`
  through `Input.parse_input_event` only.
- **Decisions go into docs the same day** (PLAN, PROGRESS, LOCKED_DECISIONS). Never leave them only in chat.

## Evidence honesty

Deathventory once shipped an agent-written "human playtest" and a smoke test with made-up checksums (L1). So:

- **Never write a result you didn't produce.** Evidence pastes the exact command, the raw output and the build SHA
  ([`docs/process/TEMPLATES.md`](docs/process/TEMPLATES.md) §3).
- **`NOT YET RUN` is a legal status.** Use it instead of a guess.
- **Owner-only fields stay empty for the owner:** playtest answers, "fun", feel, results on their hardware.
  Mark them `OWNER ONLY`.
- **No placeholder that looks like data:** no fake hashes, timings or counts. Write `—`, or the real value.
- **Tools never write into tracked evidence.** A script writes to `build/`. Evidence files are edited by hand, from
  the script's output.
- **If a target is missed, report the numbers and stop.** Never quietly widen the target, retune blind, or skip
  the check.
- **Report failures as failures.** Paste the failing output.

## Testing before a push

| The change touches | Before pushing |
|---|---|
| Only docs, or scripts that write only under `docs/` | Nothing local; CI covers it |
| Installed assets or manifests (`assets/`) | The asset tests |
| Code (`src/`), data (`data/`), tests, goldens, sims, the version or project files | The full suite, from a clean worktree of the commit |

A release runs everything (ROADMAP §0.4).

## Commands

```bash
godot --headless --path . --editor --import --quit                     # import (after clone / new class_name)
bash scripts/verify.sh                                                 # import + full suite + CI guards
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/sim -ginclude_subdirs -gexit   # one folder
godot --headless --path . -s scripts/checks/hitch_probe.gd             # real-time hitch rule
godot --headless --path . -s scripts/bench/sim_bench.gd                # bench → paste into evidence
godot --path . -s scripts/shots/tour.gd                                # screenshot tour (needs a renderer, not --headless) → build/shots/<version>/<lang>/
gdformat --check src scripts tests && gdlint src scripts tests         # lint (pip install -r requirements-dev.txt)
```

Also: `godot --headless --path . -s scripts/content/build_patch_notes.gd` (after editing patch notes) and
`bash scripts/ci/export_smoke.sh` (export + smoke, run from outside the project folder).

## Toolchain in a cloud session

- `bash scripts/setup_toolchain.sh` (from v0.0.1 Step 2) installs the pinned Godot `4.7.x`, its export templates
  and `gdtoolkit`.
- If the environment's network policy blocks a download, say so, and rely on CI for that check. A check that
  didn't run locally is reported as "not run locally (reason)", never as passed.
- The owner may register the setup script as a SessionStart hook, so every session starts ready.

## Commits and branches

- Work on a session branch cut from `origin/main`. `main` changes only through a merged PR.
- **One commit per PLAN step:** `vX.Y.Z Step N: <player-facing outcome>`. Docs-only commits start with `Docs:`.
  An unfinished session ends with a `WIP:` commit and a PROGRESS History line.
- Commit each `.uid` file with its script. **Never stage `.uid` or `.import` files you didn't cause.** Review
  `git status` before every commit.
- **Goldens change only on purpose.** Name each one in PROGRESS "Goldens changed on purpose".
- When code is ported from Deathventory, add a provenance header:
  `# Ported from riusprime/deathventory@<sha>:<path>. Changes: …`.

## Where things are

| Need | File |
|---|---|
| What went wrong last time and the rule it became | [`docs/LESSONS.md`](docs/LESSONS.md) |
| The game design | [`docs/design/GAME_BLUEPRINT.md`](docs/design/GAME_BLUEPRINT.md) |
| Versions, exit gates, release checklist | [`docs/roadmap/ROADMAP.md`](docs/roadmap/ROADMAP.md) |
| Layers, folders, loop, input, save, Deathventory reuse | [`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md) |
| Tick, `InputFrame`, events, damage, procs, caps, hashing | [`docs/architecture/SIM_CONTRACTS.md`](docs/architecture/SIM_CONTRACTS.md) |
| Balance metrics, bots, sim rules, gap-analysis reports | [`docs/balance/SCORECARD.md`](docs/balance/SCORECARD.md) |
| The five design pillars (the audit framework) | [`docs/design/ROGUELIKE_AUDIT_FRAMEWORK.md`](docs/design/ROGUELIKE_AUDIT_FRAMEWORK.md) |
| Palettes, shapes, lighting, art requests | [`docs/art/ART_DIRECTION.md`](docs/art/ART_DIRECTION.md) |
| PLAN, PROGRESS, evidence, patch-note templates | [`docs/process/TEMPLATES.md`](docs/process/TEMPLATES.md) |

## Glossary

- **GA:** a retired citation. The owner confirmed there is no gap-analysis report; old `GA` citations resolve
  through `docs/design/ROGUELIKE_GAP_ANALYSIS_v0.1.md` (to an owner decision or an open design question). Don't
  add new ones.
- **EI / PD:** engineering invariant / product default ([`LOCKED_DECISIONS.md`](docs/architecture/LOCKED_DECISIONS.md)).
- **T:** threat, raised only by the player's choices.
- **G1 / G2:** an audit list approved row by row / mockups the owner picks from.
- **Engine:** a renewable, scaling item loop that defines a build (for example bleed or guard).
- **Starting value:** a tuning default, not a measurement.
