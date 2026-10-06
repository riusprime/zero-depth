# v0.0.1 — Ground Plane: a deterministic kernel, a cube that moves on both devices, and every CI guard (plan; outline approved by the owner 2026-10-06, step details from the starter kit)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **What's in the repo:** only the starter doc kit and the owner's reference image, on branch
  `claude/lucid-fermat-9wv2tf`. There is no game code and no `main` branch yet.
- **The owner decided on 2026-10-06:**
  - Godot 4 3D with a fixed orthographic iso camera over a flat 2D sim;
  - procedural floors, with 3 biomes first;
  - Windows with mouse+keyboard and gamepad parity from day one;
  - this doc kit as the kickoff deliverable.

  These are recorded in [`../ROADMAP.md`](../ROADMAP.md) §1.
- **This version is milestone M0.** It builds the ground everything else stands on:
  - the project and its layers;
  - every CI guard Deathventory added late;
  - the deterministic sim kernel;
  - a cube that moves, aims and dashes on an iso stage with both input devices;
  - the proof scenes for the renderer, camera and occlusion;
  - localization, version, credits and dev-panel foundations.
- **Owner rule:** anything that isn't a direct fix is decided before it's built.
- **Gates in this version:**
  - after Step 7: the renderer pick, the camera-pitch pick and the occlusion-technique pick;
  - after Step 13: the owner's Windows check.
- **Workflow:**
  - one lead, one commit per step (`v0.0.1 Step N: <outcome>`), PROGRESS updated each step;
  - from Step 2 on, the full suite before every code push.

## Every owner line → where it lands
| # | Owner line (2026-10-06 brief and the approved kit plan) | Decision | Step |
|---|---|---|---|
| L1 | Godot 4 3D, fixed orthographic iso camera, the simulation is a flat 2D plane | PD-02, EI-02/03. Camera gallery offers 3 pitches; the owner picks | 4, 7 |
| L2 | Floors are procedural; 3 biomes first, more during balancing | PD-04. Only the Ruins `BiomeDefinition` and palette are needed now; the generator is v0.3.0 | 6 |
| L3 | Windows, mouse+keyboard and twin-stick gamepad parity from day one | PD-09. `InputMap` for both devices, the remap store, the device tracker, parity e2e tests | 1, 9 |
| L4 | Copy the Deathventory process that worked (kit plan) | PLAN/PROGRESS, gates, evidence, patch notes, CI export smoke from day one | 0, 3, 13 |
| L5 | Turn every Deathventory lesson into a rule (kit plan) | [`../../LESSONS.md`](../../LESSONS.md); this version enforces L2–L5, L12–L14, L19, L21 | 2–13 |
| L6 | A deterministic real-time simulation behind a 3D view (kit plan) | Kernel, replay golden on two operating systems, hitch rules, bench | 4, 5 |

## Steps

### 0. Setup (docs, repo hygiene, the port map)
- **Owner actions.** O1 and O2 block no step of v0.0.1; O3 blocks only Step 13's PR.
  - **O1.** Provide the *Roguelike Gap Analysis & Initial Development Roadmap v0.1* report for
    [`../../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md`](../../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md). The audit
    framework is already in [`../../design/ROGUELIKE_AUDIT_FRAMEWORK.md`](../../design/ROGUELIKE_AUDIT_FRAMEWORK.md).
    If the framework is all there is, the owner says so.
  - **O2.** ~~Add the reference image~~ **Done:** [`../../art/biomes_reference.png`](../../art/biomes_reference.png).
  - **O3.** Make `main` exist: either merge the kit branch's PR, or tell the lead to push `main` from the kit
    commit. Then make `main` the default branch on GitHub.
- **Branch:** cut the session branch from `origin/main`. If `main` doesn't exist yet, cut it from
  `claude/lucid-fermat-9wv2tf` and note that in PROGRESS History.
- **Files:**
  - `.gitignore`: `.godot/`, `build/`, `dist/`, `*.log`, `.DS_Store`, `Thumbs.db`, `.vscode/`, `.idea/`,
    `__pycache__/`, `.env*`, `*.pfx`, `*.pem`.
  - `.gitattributes`: `* text=auto eol=lf`; `*.ps1 text eol=crlf`; `*.bat text eol=crlf`; `binary` for `*.png
    *.jpg *.webp *.ogg *.wav *.ttf *.otf *.glb`.
- **Deathventory port map.**
  1. Make `riusprime/deathventory` available **read-only**.
  2. Record its `main` SHA in `evidence/PORTS.md`. Every port in this version and later uses that SHA. Paths and
     line numbers in [`../../architecture/ARCHITECTURE.md`](../../architecture/ARCHITECTURE.md) §12 were checked
     at `1d697803`; if the recorded SHA differs, re-check them.
  3. Write the port map in `PORTS.md`: one row per PORT file with its source path, its new path, **the step that
     copies it**, and what gets trimmed.
- **Nothing is copied in Step 0.** Each file is copied in the step that first needs it, then trimmed in the same
  commit so it parses on its own. A copied file that references Deathventory classes would break the import
  step, and a copied workflow file would start running on GitHub. Each copy gets the provenance header
  `# Ported from riusprime/deathventory@<sha>:<path>. Changes: …`.

  | Deathventory | New path | Copied in |
  |---|---|---|
  | `src/app/game_version.gd` + `tests/v2/v2_01/test_game_version.gd` (lines 14–22) | `src/app/`, `tests/unit/app/` | Step 1 |
  | `tests/support/test_harness_self_test.gd`, `scripts/verify.sh`, `scripts/verify.ps1` | `tests/support/`, `scripts/` | Step 2 |
  | `.github/workflows/verify.yml`, `windows-export.yml`, `scripts/export_windows.ps1`, `tests/export/export_smoke.gd` | `.github/workflows/verify.yml`, `windows.yml`, `scripts/`, `tests/export/` | Step 3 |
  | `src/domain/core/deterministic_rng.gd`, `rng_step.gd`, `canonical_value.gd` | `src/sim/core/` | Step 4 |
  | `src/domain/model/validation_issue.gd` | `src/content/` | Step 6 |
  | `src/application/profile_store.gd` | `src/application/` | Step 8 |
  | `src/application/run_save_store.gd` | `src/application/` | v0.4.0 (saves) |
  | `src/presentation/audio/sfx_mixer.gd` | `src/presentation/audio/` | v0.1.0 (audio cues) |

- **Done when:** `.gitignore`, `.gitattributes` and `evidence/PORTS.md` are committed.

### 1. Project (no gameplay)
- **Files:**
  - `project.godot`;
  - `export_presets.cfg`;
  - `src/app/main.tscn` + `main.gd` (an empty shell);
  - `src/app/game_version.gd`, ported. It reads `application/config/version`; `numeric()` drops a `-dev` suffix;
    `label()` returns `"v" + string()`.
  - `icon.svg` (a stub; the real app icon is v0.3.0).
- **`project.godot` settings:**

  | Section | Settings |
  |---|---|
  | `[application]` | `config/name="{{TITLE}}"`, `config/version="0.0.1"`, `run/main_scene="res://src/app/main.tscn"`, `config/features=PackedStringArray("4.7", "Forward Plus")` |
  | `[physics]` | `common/physics_ticks_per_second=60`, `common/max_physics_steps_per_frame=4`, `common/physics_interpolation=true`, `common/physics_jitter_fix=0.0` |
  | `[rendering]` | `renderer/rendering_method="forward_plus"`, `anti_aliasing/quality/msaa_3d=2` (that enum value means 4× MSAA; **starting value**) |
  | `[display]` | `window/size/viewport_width=1920`, `viewport_height=1080`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"` |
  | `[input]` | The default bindings below |
  | `[internationalization]` | Filled in Step 10 |

- **`[input]` default bindings** (pad bindings are **starting values**; the owner tunes them in the Windows
  check):

  | Action | Keyboard / mouse | Gamepad |
  |---|---|---|
  | `move_up/down/left/right` | W/S/A/D by **physical** keycode | Left stick |
  | `aim_up/down/left/right` | — (mouse ray) | Right stick |
  | `primary` | Left mouse button | Right trigger |
  | `utility` | Right mouse button | Left trigger |
  | `dash` | Space | Right shoulder |
  | `interact` | E | Face-left button (Xbox X / PlayStation □) |
  | `pause` | Esc | Start |
  | UI actions | Godot's `ui_*` defaults | Godot's `ui_*` defaults |

- **`export_presets.cfg`:**
  - one `Windows Desktop` preset: x86_64, `embed_pck=false`;
  - `exclude_filter="tests/*,docs/*,scripts/*,addons/gut/*,*.uid,*.md,requirements-dev.txt"`;
  - `file_version`/`product_version` `0.0.1.0`;
  - `product_name="{{TITLE}}"`;
  - export path `build/windows/game.exe`.
- **Tests:** `tests/unit/app/test_game_version.gd`, ported. Every preset's `file_version` and `product_version`
  equal `GameVersion.numeric() + ".0"`.
- **Done when:** the project imports headless with no errors, and the version test passes (it runs from Step 2).

### 2. Testing harness and toolchain
- **Toolchain:** `scripts/setup_toolchain.sh` makes the toolchain reproducible in a fresh cloud session.
  - It downloads the pinned Godot `4.7.x` Linux editor build and its export templates from the official
    `godotengine` GitHub releases, and puts `godot` on `PATH`.
  - It runs `pip install -r requirements-dev.txt`.
  - If the network policy blocks a download, the session says so, and relies on CI for that check. It never
    claims a local run that didn't happen.
  - Optionally, ask the owner whether to register the script as a Claude Code SessionStart hook.
- **Files:**
  - `addons/gut/`: GUT **9.7.1**, vendored. Copy it from Deathventory's `addons/gut/` or from the GUT 9.7.1 release,
    keeping its MIT licence.
  - `tests/support/test_harness_self_test.gd`, ported.
  - `scripts/verify.sh` and `scripts/verify.ps1`, ported, then extended. Each one:
    1. imports, failing on import errors;
    2. runs the full suite with `--fixed-fps 60`;
    3. applies the same guards as CI ([`../../architecture/TEST_MATRIX.md`](../../architecture/TEST_MATRIX.md)
       §3).
  - `tests/MIN_TEST_COUNT`, **seeded now** with the current passing count, and raised at the end of every step.
  - `requirements-dev.txt` pinning `gdtoolkit` at the 4.x release that parses Godot 4.7 syntax. Record the pin in
    PROGRESS.
  - `gdlintrc` (default rules plus the project's naming rules).
- **Tests:** the harness self-test asserts that GUT `9.7.1` is vendored.
- **Done when:** `bash scripts/verify.sh` passes locally (or "not run locally" is recorded with the reason), and it
  fails when a test is broken on purpose. Try it, then revert the break.

### 3. CI (the guards go live as their pieces exist)
Adapted from Deathventory's `verify.yml`, `windows-export.yml`, `scripts/export_windows.ps1` and
`tests/export/export_smoke.gd`, copied now (see the Step 0 port map).

- **`.github/workflows/verify.yml`** (ubuntu-latest). It runs on **every push to any branch** and on PRs to `main`,
  so CI works on the session branch before `main` exists:

  | # | Step | Live from |
  |---|---|---|
  | 1 | Checkout. `grep -q 'version="9.7.1"' addons/gut/plugin.cfg` | 3 |
  | 2 | `chickensoft-games/setup-godot@v2` with the pinned `4.7.x` (Deathventory pinned `4.7.2`). Fail if `godot --version` doesn't start with the pin | 3 |
  | 3 | Import: `godot --headless --path . --editor --import --quit 2>&1 \| tee import.log`. Fail on `ERROR` lines; no `\|\| true` | 3 |
  | 4 | GUT, with `set -o pipefail`: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gjunit_xml_file=build/gut.xml -gexit 2>&1 \| tee gut.log`. Then: `grep -q "Passing Tests"`; parse the passing count and fail below `tests/MIN_TEST_COUNT`; fail on `SCRIPT ERROR`, `Parse Error` or `Failed to load script` | 3 |
  | 5 | Lint: `pip install -r requirements-dev.txt`, then `gdformat --check src scripts tests` and `gdlint src scripts tests` | 3 |
  | 6 | Hitch probe: `godot --headless --path . -s scripts/checks/hitch_probe.gd` (real time, no `--fixed-fps`) | 4 |
  | 7 | Sim smoke: `godot --headless --path . -s scripts/sim/kernel_smoke.gd -- seeds=1..20 out=build/smoke_a.jsonl`, the same with `out=build/smoke_b.jsonl`, then `diff` the two | 4 |
  | 8 | Export pack + smoke (below) | 3 (GUT-not-shipped check), 4 (`World` run), 6 (content, manifest), 10 (Spanish) |
  | 9 | Bench, informational (never fails the job): `godot --headless --path . -s scripts/bench/sim_bench.gd` | 5 |
  | 10 | On failure, upload `*.log`, `build/gut.xml` and `build/*.jsonl` | 3 |

- **Export pack + smoke** (verify step 8):
  1. Record the project's manifest hash:
     `godot --headless --path . -s scripts/content/print_manifest.gd -- out=build/check/manifest.txt`.
  2. Export the pack: `godot --headless --path . --export-pack "Windows Desktop" build/check/game.pck`.
  3. Run the smoke inside it:
     `godot --headless --main-pack build/check/game.pck -s "$PWD/tests/export/export_smoke.gd" --
     manifest="$PWD/build/check/manifest.txt" world_hash="$PWD/tests/golden/fixtures/export_smoke_hash.txt"`.

     The fixture files are passed as absolute paths because `tests/*` isn't in the pack.
- **`tests/export/export_smoke.gd`** is a `SceneTree` script run inside the pack, not a GUT test. Each check is
  added in the step shown:
  - **Step 3:** `res://addons/gut/plugin.cfg` doesn't exist in the pack.
  - **Step 4:** a 600-tick headless `World` run (player + dummy movers, a scripted input) produces the hash in
    the `world_hash` file. That fixture is written by
    `godot --headless --path . -s tests/golden/generate_export_smoke_hash.gd`, on purpose only.
  - **Step 6:** content counts are greater than 0 for `player` and `biomes`, and the pack's manifest hash equals
    the `manifest` file.
  - **Step 10:** `TranslationServer` has `es`, and `TranslationServer.translate("UI_PLAY")` differs between `en`
    and `es`.
- **`.github/workflows/windows.yml`** (windows-latest, the same triggers):
  1. Setup with templates (`include-templates: true`). Then Deathventory's console-exe step: copy Godot's
     `*console.exe` to `godot.exe` on `PATH`, so the CLI's output is captured.
  2. The same pin check and import guard as `verify`.
  3. Golden replays (from Step 4): GUT with `-gdir=res://tests/golden`, the same guards and `--fixed-fps 60`. The
     hashes must equal the committed fixtures, which the ubuntu job also checks. That is the cross-OS proof
     (EI-11).
  4. `pwsh scripts/export_windows.ps1`. This exports the release `.exe` + `.pck`, zips them, and writes
     `SHA256SUMS.txt`. From Step 7 it also exports a **debug gallery build** (`--export-debug`) with
     `run_compatibility.bat`, which launches it with `--rendering-method gl_compatibility`.
  5. Zip audit: no `tests|docs|scripts|addons/gut` entries in the release zip.
  6. Upload both zips as artifacts. The owner downloads them for gates and playtests.
- **`.github/workflows/shots.yml`** (from Step 7; ubuntu under `xvfb-run`): runs `scripts/shots/galleries.gd`
  (later `tour.gd`) with a real renderer and uploads the PNGs. Step 7 proves whether lavapipe (Forward+) or
  llvmpipe (Compatibility) works there ([`../../architecture/PRESENTATION_CONTRACTS.md`](../../architecture/PRESENTATION_CONTRACTS.md)
  §10).
- **Evidence:** `evidence/EXPORT_SMOKE.md` holds the export-smoke log excerpt from the CI run. It is written in this
  step and updated whenever a check is added.
- **Done when:** both workflows are green on the session branch with the guards that are live so far, and a
  deliberately broken test makes `verify` red. Try that on a throwaway commit, then revert.

### 4. Sim kernel (sim + tests)
- **Files** (contracts in [`../../architecture/SIM_CONTRACTS.md`](../../architecture/SIM_CONTRACTS.md)):
  - **`src/sim/core/`:**
    - `tick.gd` (`TICKS_PER_SECOND = 60`, `INPUT_BUFFER_TICKS = 6`, `FREEZE_CAP_TICKS`, `AIM_DIST_MAX_CM`);
    - `deterministic_rng.gd` + `rng_step.gd` (ported), wrapped by `rng_stream.gd`;
    - `canonical_value.gd` (ported, with the float32 policy);
    - `state_hasher.gd`;
    - `kin.gd`;
    - `trig_lut.gd`, generated by `scripts/sim/gen_trig_lut.gd`;
    - `input_frame.gd`.
  - **`src/sim/world/`:** `world.gd` (`step()`, the id rules, the player input buffer, the event log,
    `snapshot()`), `world_reader.gd` (`WorldReader`, the read-only facade for presentation), `actor_store.gd`,
    `projectile_store.gd` (SoA).
  - **`src/sim/collision/`:** `shapes.gd` (circle, OBB, sweep), `uniform_grid.gd`, `wall_grid.gd`, `collide.gd`.
  - **`src/sim/effects/sim_event.gd`:** all fields, and the **whole** `kind` enum declared now, even though this
    version emits only `SPAWN`, `HIT` and `LIMIT`.
  - **`src/application/input_latch.gd`:** edge latching between ticks, the +45° rotation, quantization.
  - **`src/app/sim_driver.gd`:** steps in `_physics_process`.
  - **Player movement and dash:** the kinematic dash moves the player only; no i-frames or damage yet.
    - This step uses a `PlayerTable` built in code; Step 6 replaces it with the compiled `PlayerDefinition`.
    - Values come from GA §5 when the report exists. Otherwise the lead proposes starting values and lists them
      in [`../../design/GAME_BLUEPRINT.md`](../../design/GAME_BLUEPRINT.md) §C. They are a design question for
      the owner in the same batch as the Step 7 gates.
- **Tests:**
  - **Architecture lint:** `tests/arch/test_layering.gd`, `tests/arch/test_sim_purity.gd`.
  - **Unit:**
    - `tests/unit/sim/test_rng_stream.gd`: same seed → same sequence; streams are independent; the rejection
      sampler is unbiased over 10⁵ draws within tolerance.
    - `tests/unit/sim/test_kin.gd`: `dir(0) == (1,0)`; `|dir| ≈ 1`; the `angle_of(dir(a)) == a` round trip for
      all 4096 angles.
    - `tests/unit/sim/test_collision.gd`: circle vs OBB push-out; actor pairs in id order; the sweep stops at the
      first contact, ordered by distance then id.
    - `tests/unit/sim/test_ids.gd`: ids are monotonic and never reused; spawns and deaths apply at the end of the
      tick.
    - `tests/unit/sim/test_state_hasher.gd`: a fixed field order; −0.0 equals 0.0; any field change changes the
      hash.
    - `tests/unit/sim/test_input_buffer.gd`: a press is kept for 6 ticks; freeze ticks don't age it.
    - `tests/unit/application/test_input_latch.gd`: a press and release between two ticks gives `pressed` once;
      the rotation table in SIM_CONTRACTS §3 (W → 1536, D → 512, S → 3584, A → 2560).
  - **Hitch:** `tests/unit/sim/test_hitch_rules.gd` plus `scripts/checks/hitch_probe.gd`
    ([`../../architecture/TEST_MATRIX.md`](../../architecture/TEST_MATRIX.md) T-HITCH).
  - **Replay golden:** `tests/golden/test_replay_ground_plane.gd`.
    - A seeded input script runs for 10,000 ticks with the player, 20 dummy movers, 50 projectiles and 12 walls.
    - The hash is checkpointed every 60 ticks, against `tests/golden/fixtures/replay_ground_plane.json`.
    - Regenerate it with `godot --headless --path . -s tests/golden/generate_replay_ground_plane.gd`, on purpose
      only.
  - **Kernel smoke:** `scripts/sim/kernel_smoke.gd`. It runs 20 seeds × 600 ticks of the dummy-mover world, one
    JSONL line per seed (`seed`, the final hash, event counts by kind). CI runs it twice and diffs the output.
- **Evidence:** `evidence/REPLAY_CROSS_OS.md`. It holds the ubuntu and windows CI job links and the final hash
  printed by each, and they must be identical.
- **Done when:** all of the above pass on both CI jobs, and the arch lint fails on a planted `randf()` in
  `src/sim/` (try it, then revert).

### 5. Bench (sim + evidence)
- **Files:** `scripts/bench/sim_bench.gd`. It has two scenes, and reports the mean, p50 and p99 tick cost and the
  headless real-time multiple for each:
  - **stress:** 60 dummy enemies steering toward the player, 300 projectiles and 40 walls, for 3,600 ticks;
  - **reference:** 12 dummy movers, 40 projectiles and 12 walls, for 3,600 ticks.

  Timing uses `Time.get_ticks_usec()` in the script, never in the sim.
- **Targets** ([`../../architecture/ARCHITECTURE.md`](../../architecture/ARCHITECTURE.md) §13):
  - stress: mean ≤ 2 ms per tick, p99 ≤ 4 ms;
  - reference: ≥ 15× real time.

  The kit reads the plan's "≥ 15×" as applying to the reference scene, because 2 ms per tick is only 8.3×.
  **The owner confirms this reading** (open item O5).
- **Machine:** the CI ubuntu runner (verify step 9). If the owner agrees, also their PC (`OWNER ONLY` rows).
- **Evidence:** `evidence/BENCH.md`, in the template's form.
- **Done when:** the evidence is committed. **If a target is missed, stop and report to the owner with the
  numbers.** Don't optimize blind, and don't change the targets.

### 6. Content foundations (sim + tests)
- **Files:**
  - **Scanner, repository, validator** (adapting Deathventory's `content_repository.gd`, `resource_index.gd`,
    `content_validator.gd`, plus the ported `validation_issue.gd`):
    - `src/content/content_scanner.gd`: `ResourceLoader.list_directory`, recursive over `…/` entries, sorted;
    - `content_repository.gd`, with the manifest hash over canonical properties
      ([`../../architecture/CONTENT_SCHEMA.md`](../../architecture/CONTENT_SCHEMA.md) §1);
    - `content_validator.gd`.
  - **Compiler:** `src/content/content_compiler.gd`, player only (`PlayerDefinition` → `PlayerTable`, seconds →
    ticks). `main.gd` now builds `World` from the compiled table.
  - **Manifest script:** `scripts/content/print_manifest.gd`.
  - **Definitions:** `src/content/defs/player_definition.gd`, `dash_definition.gd`, `biome_definition.gd`.
  - **Data:**
    - `data/player/player.tres`, with values from GA §5 or the starting values listed in BLUEPRINT §C;
    - `data/biomes/ruins.tres`, with exactly the seven palette tokens from
      [`../../art/ART_DIRECTION.md`](../../art/ART_DIRECTION.md) §2.
- **Tests:**
  - `tests/content/test_content_valid.gd`: all data validates.
  - `tests/content/test_validation_errors.gd`: fixtures in `tests/content/fixtures/` each produce the right
    `ERROR`. The fixtures have a missing id, a missing palette key, an unknown palette key, an `outline` below
    3:1, and a duration that rounds to 0 ticks.
  - `tests/content/test_scanner.gd`: results are sorted and deterministic, nested folders are found, and the
    results match the files on disk.
  - The manifest hash is stable across two loads.
- **Done when:** the tests pass, and the export smoke counts this content and matches the manifest inside the
  pack.

### 7. View and proof scenes (presentation only)
- **Files:**
  - `src/presentation/camera/iso_rig.gd`: `PROJECTION_ORTHOGONAL`, `rotation.y = +45°`, an exported pitch, and
    `physics_interpolation_mode` off on the camera.
  - `src/presentation/camera/occlusion.gd`: the pure `select()`, plus fade application.
  - `src/presentation/world_view/stage_view.gd`: the ground from the biome palette, with the reference's large
    two-tone tiles.
  - `actor_view.gd`: a white cube, a cyan emissive core, a contact ring and rim in the biome `outline`, a team
    ring decal and a floating white bar.
  - `wall_view.gd`.
  - One `DirectionalLight3D` with hard shadows, falling lower-left as in the reference.
  - `WorldEnvironment`: the biome's `ambient` tint, and glow on.
  - The views read `WorldReader`, never `World`.
- **Proof scenes** (`src/debug/galleries/`): reachable from a GALLERIES button that exists only in debug builds,
  and shipped in the Windows debug gallery build (Step 3).
  - `renderer_gallery.tscn`: the cube, slabs, rocks, yellow streaks and cyan core under shadows and glow. Judge
    it as is, and launched with `run_compatibility.bat`.
  - `camera_gallery.tscn`: the same room at pitch 30°, 35.26° and 45°.
  - `occlusion_gallery.tscn`: walls of three heights between the camera and actors, comparing dithered fade
    against the X-ray silhouette (the `BaseMaterial3D` stencil mode, 4.5+, which should also be tried under
    Compatibility), and the outline on all four biome grounds.
- **Screenshots:** `scripts/shots/galleries.gd` runs in the `shots` workflow, or locally with a GPU, and writes to
  `build/shots/v0.0.1/en/`. The PNGs the owner picks from are committed under `evidence/shots/` and linked from
  `evidence/GALLERIES.md`.
- **Tests:** `tests/unit/presentation/test_occlusion_select.gd`, covering a wall in front, a wall behind, a wall
  off-axis and two actors.
- **Gates (owner):**
  - **Renderer:** Forward+ or Compatibility, judged on the lowest-spec Windows PC the owner wants to support (the
    owner names it).
  - **Camera pitch.**
  - **Occlusion technique.**

  Each pick becomes a PD row in `LOCKED_DECISIONS.md`.
- **Done when:** the galleries are in evidence and the picks are recorded. If the owner is unavailable, build on
  with the defaults (Forward+, pitch 35.26°, fade + X-ray silhouette) and log the pending picks under PROGRESS
  "Gates".

### 8. App shell (presentation + application + e2e)
- **Files:**
  - `src/app/composition.gd`: wires the stores, settings, `SimDriver` and the views.
  - `src/presentation/menus/main_menu.tscn`: Play, Options, Credits, Quit, plus the version label
    (`GameVersion.label()`).
  - `pause_menu.tscn`: Resume, Main menu.
  - `options_menu.tscn` (a stub): language, the Master/Music/Effects volumes, VSync and the frame cap.
  - `src/application/profile_store.gd` (ported; Deathventory's sections replaced, `JournalStore` cut). Memory mode
    is `ProfileStore.new("")`, selected automatically when headless.
  - `src/application/game_settings.gd`, adapted from Deathventory and stored in `ProfileStore`.
  - `default_bus_layout.tres`: the Master, Music and Effects buses.
  - Window close: `set_auto_accept_quit(false)`, then on `NOTIFICATION_WM_CLOSE_REQUEST` save the profile and
    quit.
- **Stubs and G2:** these screens are functional stubs in the default theme. They skip G2 until they're designed
  for real ([`../../architecture/PRESENTATION_CONTRACTS.md`](../../architecture/PRESENTATION_CONTRACTS.md) §9).
- **Reachable from the real game?** Yes: proved by `tests/e2e/test_e2e_shell.gd` (boot → menu → Play → Esc pauses →
  Main menu), driven by input events only.
- **Tests:** settings round-trip through `ProfileStore` in memory mode; the volume sliders move the right buses.
- **Done when:** the e2e and unit tests pass.

### 9. Input on both devices (application + presentation + e2e)
- **Files:**
  - `src/presentation/input/device_tracker.gd`: the last device used; it switches prompts and the aim mode.
  - `src/presentation/input/mouse_aim.gd`: a camera ray to the plane at core height.
  - `src/application/input_remap.gd`: bindings stored in the `ProfileStore` `bindings` section and applied to
    `InputMap` at boot. The UI comes in v0.1.0.
  - `src/application/aim_assist.gd`: pad only. With no targets this version, it's a no-op with tests for the cone
    math.
- **Reachable from the real game?** Yes: main menu → Play → move, aim and dash on the stage, proved by the e2e
  tests below.
- **Tests** (`tests/e2e/`, real input only: `Input.parse_input_event` → `Input.flush_buffered_events()` →
  `await get_tree().physics_frame`). Each one starts from the main menu and presses Play:
  - `test_e2e_move_kbm.gd`: holding W for 30 ticks moves the player toward sim angle 1536 (135°).
  - `test_e2e_move_pad.gd`: the same with a left-stick `InputEventJoypadMotion`.
  - `test_e2e_tap_dash.gd`: a dash press **and** release inside one frame still dashes on the next tick.
  - `test_e2e_aim_parity.gd`: aiming at the same world point with the mouse and with the right stick gives
    `aim_angle` within ±1.
  - `test_e2e_remap.gd`: a binding stored in the profile changes `InputMap` at boot, and the new key moves the
    player.
- **Done when:** these pass in CI. The owner judges how both devices feel in the Step 13 Windows check.

### 10. Localization (presentation + content)
- **Files:**
  - `locale/strings.csv` (`keys,en,es`), with every string from Steps 7–12;
  - `project.godot` `[internationalization]` `locale/translations` pointing at the imported
    `strings.en.translation` and `strings.es.translation`;
  - a TTF font with full Latin coverage. It must be OFL-licensed: candidates are Noto Sans, Inter and Atkinson
    Hyperlegible; the owner may supply another. Put it in `assets/fonts/` with its `LICENSE` file;
  - `src/presentation/theme/default_theme.tres` using that font, with an 18 px minimum body size at 1080p;
  - a language setting applied through `TranslationServer.set_locale`.
- **Tests:**
  - `tests/content/test_locale_coverage.gd`
    ([`../../architecture/CONTENT_SCHEMA.md`](../../architecture/CONTENT_SCHEMA.md) §10);
  - `tests/content/test_assets.gd`: every file in `assets/fonts/` has a licence file next to it;
  - an e2e test that switches to `es` and checks that the Play button shows `JUGAR`.
    `Button.text` holds the key `UI_PLAY`, so the test checks `tr(button.text)`.
- **Done when:** both languages render with ñ and accents, and no visible string skips `tr()`. The locale test's
  `.tscn` scan passes.

### 11. Credits and licenses (presentation)
- **Files:** `src/presentation/menus/credits.tscn` and `data/credits/credits.tres`. The credits hold:
  - the owner's credit line (**Open O4**);
  - "Made with Godot Engine";
  - the Godot license from `Engine.get_license_text()`;
  - third-party notices from `Engine.get_copyright_info()` and `Engine.get_license_info()`;
  - the font's licence.
- **Tests:**
  - The credits screen opens from the main menu (e2e).
  - The export smoke confirms GUT isn't in the pack, and the zip audit confirms no `addons/gut`.
- **Done when:** the tests pass.

### 12. Dev panel stub (debug)
- **Files:**
  - `src/debug/dev_panel.tscn` + `dev_panel.gd`. It is adapted from Deathventory's release gate, where
    `unlocked()` returns true only in debug builds and takes an override for tests. It is toggled by backtick
    through its physical keycode.
  - `src/application/debug_api.gd`.
- **What the panel shows:** seed, tick, FPS, the sim ticks run this frame, and a **Hash now** button that runs
  `StateHasher` on demand. Live play never hashes on its own.
- **What it can do:** pause the sim, step one tick, reseed and restart. It does this through `DebugApi` commands
  applied at a tick boundary, never by touching `World` directly.
- **Tests:**
  - `DevPanel.unlocked(false)` is closed (the release gate);
  - stepping one tick advances `World.tick` by exactly 1;
  - the panel strings use `tr()`.
- **Done when:** the tests pass.

### 13. Release
- `scripts/shots/tour.gd` runs the shell, the stage and the galleries in en and es (the `shots` workflow). Link the
  artifact from `evidence/TOUR.md`.
- **Release items:**
  - patch notes `docs/patch-notes/v0.0.1.md` + `v0.0.1.es.md`, and the README index row;
  - `data/patch_notes/v0.0.1.tres`, built by `scripts/content/build_patch_notes.gd`;
  - the ROADMAP §4 status and History;
  - the README status line;
  - CLAUDE.md, re-checked;
  - `tests/MIN_TEST_COUNT` at the final passing count;
  - PROGRESS final.
- **`docs/roadmap/v0.0.1/PLAYTEST.md`** for the owner's Windows check
  ([`../../process/OWNER_GATES.md`](../../process/OWNER_GATES.md) §5). It asks the owner to:
  - download the CI artifact;
  - move, aim and dash with mouse+keyboard, then with a gamepad;
  - say which felt off;
  - tune or accept the starting values;
  - pick the renderer, camera pitch and occlusion technique if not done yet;
  - judge the readability of the cube on the stage;
  - note the frame rate.

  Its answers are **OWNER ONLY**.
- **PR to `main`**, then CI green. The owner merges, or tells the lead to.
- **Done when:** the PR is merged and the owner's Windows check is recorded in `PLAYTEST.md` by the owner.

## Open items (what they block)
- **O1** Gap analysis report: blocks v0.1.0 Phase 0, not this version. Until it exists, Steps 4 and 6 use
  starting values (BLUEPRINT §C).
- **O3** `main` exists: blocks Step 13's PR.
- **O4** Credit line: blocks Step 11's final text. A placeholder key, `CREDITS_OWNER`, shows "…" until it arrives.
- **O5** Bench reading: does "≥ 15× real time" apply to the reference scene (the kit's reading) or to the stress
  scene (which would need a mean ≤ 1.1 ms)? Ask with the Step 7 gates.
- **Gates** (renderer, pitch, occlusion technique): after Step 7. **Owner Windows check:** after Step 13.
- **Godot patch version:** pin the newest `4.7.x` that `setup-godot` supports. Deathventory proved `4.7.2`; prefer
  it unless a newer 4.7 patch fixes something we need. Record the pin in PROGRESS.

## Verification
- **Tests:** every step's tests in `tests/`, on both CI jobs, with real-input e2e for every player-facing path.
- **Evidence** (`docs/roadmap/v0.0.1/evidence/`): `PORTS.md`, `EXPORT_SMOKE.md`, `REPLAY_CROSS_OS.md`,
  `BENCH.md`, `GALLERIES.md` (+ `shots/`), `TOUR.md`.
- **Owner-only:** `docs/roadmap/v0.0.1/PLAYTEST.md`.
- **Goldens:** the replay golden and the export-smoke hash are created in Step 4. After this, they change only on
  purpose and are named in PROGRESS.
- **Before every code push:** the full suite. CI must be green before merge.
