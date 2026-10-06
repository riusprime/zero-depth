# v0.0.1 — Ground Plane: a deterministic kernel, a cube that moves on both devices, and every CI guard (plan; outline approved by the owner 2026-10-06, step details from the starter kit)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **The repo holds only the starter doc kit.** It was committed on branch `claude/lucid-fermat-9wv2tf` as the
  first commit, and there is no game code yet.
- **The owner decided on 2026-10-06:**
  - Godot 4 3D with a fixed orthographic iso camera over a flat 2D sim;
  - procedural floors, with 3 biomes first;
  - Windows with mouse+keyboard and gamepad parity from day one;
  - this doc kit as the kickoff deliverable.
- **This version is milestone M0.** It builds the ground everything else stands on:
  - the project and its layers;
  - every CI guard Deathventory added late;
  - the deterministic sim kernel;
  - a cube that moves, aims and dashes on an iso stage with both input devices;
  - the proof scenes for the renderer, camera and occlusion;
  - localization, version, credits and dev-panel foundations.
- **Owner rule:** anything that isn't a direct fix is decided before it's built.
- **Gates in this version:**
  - the renderer pick (after Step 8);
  - the camera-pitch pick (after Step 8);
  - the owner's Windows check (after Step 13).
- **Workflow:** one lead, one commit per step (`v0.0.1 Step N: <outcome>`), PROGRESS updated each step, and the
  full suite before every code push once Step 2 exists.

## Every owner line → where it lands
| # | Owner line (2026-10-06) | Decision | Step |
|---|---|---|---|
| L1 | "Godot 4 3D, fixed orthographic iso camera, the simulation is a flat 2D plane" | PD-02, EI-02/03. Camera gallery offers 3 pitches; the owner picks | 4, 8 |
| L2 | "Floors are procedural; 3 biomes first, more during balancing" | PD-04. Only the Ruins `BiomeDefinition` and palette are needed now; the generator is v0.3.0 | 6 |
| L3 | "Windows, mouse+keyboard and twin-stick gamepad parity from day one" | PD-09. `InputMap` for both devices, the remap store, the device tracker, parity e2e tests | 7 |
| L4 | "Copy the Deathventory process that worked" | PLAN/PROGRESS, gates, evidence, patch notes, CI export smoke from day one | 0, 3, 13 |
| L5 | "Turn every Deathventory lesson into a rule" | [`../../LESSONS.md`](../../LESSONS.md); this version enforces L2–L5, L12–L14, L19, L21 | 2–13 |
| L6 | "Deterministic real-time simulation behind a 3D view" | Kernel, replay golden on two operating systems, hitch rules, bench | 4, 5 |

## Steps

### 0. Setup (docs and repo hygiene)
- **Owner actions** (they don't block Steps 1–13, but they are needed before v0.1.0):
  - **O1.** Paste the full *Roguelike Gap Analysis & Initial Development Roadmap v0.1* into
    [`../../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md`](../../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md), replacing the
    placeholder body. The lead then fills that file's citation map.
  - **O2.** Add the reference image as `docs/art/reference/biomes_reference.png`.
  - **O3.** Make `main` exist: either merge the kit branch's PR, or tell the lead to push `main` from the kit
    commit. Then make `main` the default branch on GitHub.
- **Branch:** cut the session branch from `origin/main`. If `main` doesn't exist yet, cut it from the kit branch
  and note that in PROGRESS History.
- **Files:**
  - `.gitignore`: `.godot/`, `build/`, `dist/`, `*.log`, `.DS_Store`, `Thumbs.db`, `.vscode/`, `.idea/`,
    `__pycache__/`, `.env*`, `*.pfx`, `*.pem`.
  - `.gitattributes`: `* text=auto eol=lf`; `*.ps1 text eol=crlf`; `binary` for `*.png *.jpg *.webp *.ogg *.wav
    *.ttf *.otf *.glb`.
- **Deathventory ports.**
  1. Add `riusprime/deathventory` to the session, **read-only**.
  2. Note its `main` SHA.
  3. Copy the PORT files from [`../../architecture/ARCHITECTURE.md`](../../architecture/ARCHITECTURE.md) §12 to
     their new homes:

     | Deathventory | New path |
     |---|---|
     | `src/domain/core/deterministic_rng.gd`, `rng_step.gd` | `src/sim/core/` |
     | `src/domain/core/canonical_value.gd` | `src/sim/core/` |
     | `src/domain/model/validation_issue.gd` | `src/content/` |
     | `src/app/game_version.gd` + `tests/v2/v2_01/test_game_version.gd` | `src/app/`, `tests/unit/app/` |
     | `src/application/run_save_store.gd`, `profile_store.gd` | `src/application/` |
     | `src/presentation/audio/sfx_mixer.gd` | `src/presentation/audio/` |
     | `tests/export/export_smoke.gd` | `tests/export/` |
     | `.github/workflows/verify.yml` | `.github/workflows/` |
     | `scripts/verify.sh`, `scripts/verify.ps1` | `scripts/` |
     | `tests/support/test_harness_self_test.gd` | `tests/support/` |

  4. Give each copied file the provenance header (`# Ported from riusprime/deathventory@<sha>:<path>. Changes:
     …`).
  5. Copy only those files. Read the ADAPT files when their step comes; don't copy them now.
- **Evidence:** `evidence/PORTS.md` lists each file: the source path, the SHA, the new path, and what was cut.
- **Done when:** the files above are committed, and the ported files are in place (unwired, so nothing runs yet).

### 1. Project (no gameplay)
- **Files:**
  - `project.godot`;
  - `export_presets.cfg`;
  - `src/app/main.tscn` + `main.gd` (an empty shell);
  - `src/app/game_version.gd` (ported);
  - `icon.svg` (a stub; the real app icon is v0.3.0).
- **`project.godot` settings:**

  | Section | Settings |
  |---|---|
  | `[application]` | `config/name="{{TITLE}}"`, `config/version="0.0.1"`, `run/main_scene="res://src/app/main.tscn"`, `config/features=PackedStringArray("4.7", "Forward Plus")` |
  | `[physics]` | `common/physics_ticks_per_second=60`, `common/max_physics_steps_per_frame=4`, `common/physics_interpolation=true`, `common/physics_jitter_fix=0.0` |
  | `[rendering]` | `renderer/rendering_method="forward_plus"`, `anti_aliasing/quality/msaa_3d=2` (**starting value**) |
  | `[display]` | `window/size/viewport_width=1920`, `viewport_height=1080`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"` |
  | `[internationalization]` | filled in Step 10 |

- **`export_presets.cfg`:**
  - one `Windows Desktop` preset: x86_64, `embed_pck=false`;
  - `exclude_filter="tests/*,docs/*,scripts/*,addons/gut/*,*.uid,*.md,requirements-dev.txt"`;
  - `file_version`/`product_version` `0.0.1.0`;
  - `product_name="{{TITLE}}"`;
  - export path `build/windows/game.exe`.
- **Tests:** `tests/unit/app/test_game_version.gd` (ported). Every preset's `file_version` and `product_version`
  equal `GameVersion.numeric() + ".0"`.
- **Done when:** the project opens headless and imports with no errors, and the version test passes (after
  Step 2).

### 2. Testing harness
- **Files:**
  - `addons/gut/`: GUT **9.7.1**, vendored. Copy it from Deathventory's `addons/gut/` or from the GUT 9.7.1 release
    (MIT licence kept).
  - `tests/support/test_harness_self_test.gd` (ported).
  - `scripts/verify.sh` and `scripts/verify.ps1`. Each one:
    1. imports, failing on import errors;
    2. runs the full suite with `--fixed-fps 60`;
    3. applies the same guards as CI ([`../../architecture/TEST_MATRIX.md`](../../architecture/TEST_MATRIX.md)
       §3).
  - `tests/MIN_TEST_COUNT`, containing the current passing count (set at Step 13).
  - `requirements-dev.txt` pinning `gdtoolkit` (the release that supports Godot 4 syntax; record the version in
    PROGRESS).
  - `gdlintrc` (default rules plus the project's naming rules).
- **Tests:** the harness self-test asserts that GUT `9.7.1` is vendored.
- **Done when:** `bash scripts/verify.sh` passes locally, and it fails when a test is broken on purpose. Try it,
  then revert the break.

### 3. CI
Adapted from Deathventory's `verify.yml`, `windows-export.yml`, `scripts/export_windows.ps1` and
`tests/export/export_smoke.gd`.

- **`.github/workflows/verify.yml`** (ubuntu-latest, on push and PR to `main`), in order:
  1. Checkout. `grep -q 'version="9.7.1"' addons/gut/plugin.cfg`.
  2. `chickensoft-games/setup-godot@v2` with the pinned `4.7.x` (Deathventory pinned `4.7.2`). Fail if
     `godot --version` doesn't start with the pin.
  3. Import: `godot --headless --path . --editor --import --quit 2>&1 | tee import.log`. Fail on `ERROR` lines;
     don't `|| true`.
  4. GUT, with `set -o pipefail`:
     `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs
     -gjunit_xml_file=build/gut.xml -gexit 2>&1 | tee gut.log`. Then:
     - `grep -q "Passing Tests" gut.log`;
     - parse the passing count and fail if it is below `tests/MIN_TEST_COUNT`;
     - fail if `gut.log` contains `SCRIPT ERROR`, `Parse Error` or `Failed to load script`.
  5. Hitch probe: `godot --headless --path . -s scripts/checks/hitch_probe.gd` (real time, no `--fixed-fps`).
  6. Lint: `pip install -r requirements-dev.txt`, then `gdformat --check src scripts tests` and
     `gdlint src scripts tests`.
  7. Re-bake: `godot --headless --path . -s scripts/content/bake_rooms.gd`, then `git diff --exit-code data/rooms`.
     It's a no-op until rooms exist, but it's wired now.
  8. Export pack + smoke:
     1. Record the project's manifest hash:
        `godot --headless --path . -s scripts/content/print_manifest.gd -- out=build/check/manifest.txt`.
     2. Export the pack: `godot --headless --path . --export-pack "Windows Desktop" build/check/game.pck`.
     3. Run the smoke inside it:
        `godot --headless --main-pack build/check/game.pck -s "$PWD/tests/export/export_smoke.gd" --
        manifest="$PWD/build/check/manifest.txt"`.
  9. Sim smoke: `godot --headless --path . -s scripts/sim/kernel_smoke.gd -- seeds=1..20 out=build/smoke_a.jsonl`
     and the same with `out=build/smoke_b.jsonl`, then `diff` the two files.
  10. On failure, upload `*.log`, `build/gut.xml` and `build/*.jsonl`.
- **`.github/workflows/windows.yml`** (windows-latest, same triggers):
  1. Setup with templates (`include-templates: true`), plus Deathventory's console-exe step.
  2. Golden replays: GUT with `-gdir=res://tests/golden`, the same guards and `--fixed-fps 60`. The hashes must
     equal the committed fixtures, which the ubuntu job also checks. That is the cross-OS proof (EI-11).
  3. `pwsh scripts/export_windows.ps1`. This exports the release `.exe` + `.pck`, zips them, and writes
     `SHA256SUMS.txt`.
  4. Zip audit: no `tests|docs|scripts|addons/gut` entries.
  5. Upload the artifact the owner downloads for playtests.
- **`tests/export/export_smoke.gd`** (a `SceneTree` script run inside the pack) checks:
  - the content counts are greater than 0 for `player` and `biomes`;
  - the pack's manifest hash equals the project's (the file passed as `manifest=`);
  - `TranslationServer` has `es`, and `tr("UI_PLAY")` differs between `en` and `es`;
  - a 600-tick headless `World` run (player + dummy movers, a scripted input) gives the hash committed in
    `tests/golden/fixtures/export_smoke_hash.txt`;
  - `res://addons/gut/plugin.cfg` does **not** exist in the pack.
- **Done when:** a PR shows both workflows green, and a deliberately broken test makes `verify` red (try it on a
  throwaway commit, then revert).

### 4. Sim kernel (sim + tests)
- **Files** (contracts in [`../../architecture/SIM_CONTRACTS.md`](../../architecture/SIM_CONTRACTS.md)):
  - **`src/sim/core/`:**
    - `tick.gd` (`TICKS_PER_SECOND = 60`, `INPUT_BUFFER_TICKS = 6`, `FREEZE_CAP_TICKS`);
    - `rng_stream.gd` (wrapping the ported math);
    - `canonical_value.gd` (float32 policy);
    - `state_hasher.gd`;
    - `kin.gd`;
    - `trig_lut.gd`, generated by `scripts/sim/gen_trig_lut.gd`;
    - `input_frame.gd`.
  - **`src/sim/world/`:** `world.gd` (`step()`, id rules, the event log, `snapshot()`), `actor_store.gd`,
    `projectile_store.gd` (SoA).
  - **`src/sim/collision/`:** `shapes.gd` (circle, OBB, sweep), `uniform_grid.gd`, `wall_grid.gd`, `collide.gd`.
  - **`src/sim/effects/sim_event.gd`:** only the fields and kinds this version uses (`SPAWN`, `HIT`, `LIMIT`).
  - **`src/application/input_latch.gd`:** edge latching between ticks, quantization.
  - **`src/app/sim_driver.gd`:** steps in `_physics_process`.
  - **Player movement and dash:** the kinematic dash moves the player only; no i-frames or damage yet. Values
    come from GA §5 or are marked `STARTING VALUE`.
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
    - `tests/unit/application/test_input_latch.gd`: a press and release between two ticks gives `pressed` once;
      the 6-tick buffer.
  - **Hitch:** `tests/unit/sim/test_hitch_rules.gd` plus `scripts/checks/hitch_probe.gd`
    ([`../../architecture/TEST_MATRIX.md`](../../architecture/TEST_MATRIX.md) T-HITCH).
  - **Replay golden:** `tests/golden/test_replay_ground_plane.gd`.
    - A seeded input script runs for 10,000 ticks with the player, 20 dummy movers, 50 projectiles and 12 walls.
    - The hash is checkpointed every 60 ticks, against `tests/golden/fixtures/replay_ground_plane.json`.
    - Regenerate it with `godot --headless --path . -s tests/golden/generate_replay_ground_plane.gd`, on purpose
      only.
  - **Kernel smoke:** `scripts/sim/kernel_smoke.gd` (used by CI Step 3.9).
- **Evidence:** `evidence/REPLAY_CROSS_OS.md`. It holds the ubuntu and windows CI job links and the final hash
  printed by each, and they must be identical.
- **Done when:** all of the above pass on both CI jobs, and the arch lint fails on a planted `randf()` in
  `src/sim/` (try it, then revert).

### 5. Bench (sim + evidence)
- **Files:** `scripts/bench/sim_bench.gd`. It sets up 60 dummy enemies steering toward the player, 300
  projectiles and 40 walls, runs 3,600 ticks, and reports the mean, p50 and p99 tick cost and the headless
  real-time multiple. Timing uses `Time.get_ticks_usec()` in the script, never in the sim.
- **Evidence:** `evidence/BENCH.md`, in the template's form, with targets from
  [`../../architecture/ARCHITECTURE.md`](../../architecture/ARCHITECTURE.md) §13 (mean ≤ 2 ms, p99 ≤ 4 ms,
  ≥ 15× real time). Run it on the CI runner and, if the owner agrees, on the owner's PC (`OWNER ONLY` rows).
- **Done when:** the evidence is committed. **If a target is missed, stop and report to the owner with the
  numbers.** Don't optimize blind, and don't change the targets.

### 6. Content foundations (sim + tests)
- **Files:**
  - **Scanner, repository, validator** (adapting Deathventory's `content_repository.gd`, `resource_index.gd`,
    `content_validator.gd`): `src/content/content_scanner.gd` (`ResourceLoader.list_directory`, sorted),
    `content_repository.gd`, `content_validator.gd`.
  - **Definitions:** `src/content/defs/player_definition.gd`, `biome_definition.gd`, `dash_definition.gd`.
  - **Data:** `data/player/player.tres` (values from GA §5, or marked `## STARTING VALUE`) and
    `data/biomes/ruins.tres` (palette tokens from [`../../art/ART_DIRECTION.md`](../../art/ART_DIRECTION.md) §2).
- **Tests:**
  - `tests/content/test_content_valid.gd`: all data validates.
  - `tests/content/test_validation_errors.gd`: fixtures in `tests/content/fixtures/` with a missing id, a missing
    palette token, and a duration that rounds to 0 ticks each produce the right `ERROR`.
  - `tests/content/test_scanner.gd`: results are sorted and deterministic, and match the files on disk.
  - The manifest hash is stable across two loads.
- **Done when:** the tests pass, and the export smoke counts this content inside the pack.

### 7. Input on both devices (application + presentation + e2e)
- **`project.godot` `[input]`:** `move_up/down/left/right` (WASD by **physical** keycode, plus the left stick),
  `aim_up/down/left/right` (the right stick), `primary` (left mouse button, right trigger), `dash` (Space,
  right shoulder or A), `utility` (right mouse button, left trigger), `interact` (E, X), `pause` (Esc, Start).
  All pad bindings are **starting values**; the owner tunes them in the Windows check.
- **Files:**
  - `src/presentation/input/device_tracker.gd` (last device used; switches prompts and the aim mode);
  - `src/presentation/input/mouse_aim.gd` (camera ray to the plane at core height);
  - `src/application/input_remap.gd` (bindings stored in the `ProfileStore` `bindings` section and applied to
    `InputMap` at boot; the UI comes in v0.1.0);
  - `src/application/aim_assist.gd` (pad only; with no targets this version, it's a no-op with tests for the
    cone math).
- **Reachable from the real game?** Yes: main menu → Play → move, aim and dash on the stage, proved by the e2e
  tests below.
- **Tests** (`tests/e2e/`, real input only: `Input.parse_input_event` → `Input.flush_buffered_events()` →
  `await get_tree().physics_frame`):
  - `test_e2e_move_kbm.gd`: holding W for 30 ticks moves the player screen-up. The world direction is checked
    against the −45° rotation.
  - `test_e2e_move_pad.gd`: the same with a left-stick `InputEventJoypadMotion`.
  - `test_e2e_tap_dash.gd`: a dash press **and** release inside one frame still dashes on the next tick.
  - `test_e2e_aim_parity.gd`: aiming at the same world point with the mouse and with the right stick gives
    `aim_angle` within ±1.
  - `test_e2e_remap.gd`: a binding stored in the profile changes `InputMap` at boot, and the new key moves the
    player.
- **Done when:** these pass in CI, and the owner's Windows check confirms both devices feel right.

### 8. View and proof scenes (presentation only)
- **Files:**
  - `src/presentation/camera/iso_rig.gd`: `PROJECTION_ORTHOGONAL`, yaw 45°, and an exported pitch.
  - `src/presentation/camera/occlusion.gd`: the pure `select()`, plus fade application.
  - `src/presentation/world_view/stage_view.gd`: the ground from the biome palette, with a large subtle tile
    pattern as in the reference.
  - `actor_view.gd`: a white cube, a cyan emissive core, a contact-shadow ring, a team ring decal and a floating
    white bar.
  - `wall_view.gd`.
  - One `DirectionalLight3D` with hard shadows, falling lower-left as in the reference.
  - `WorldEnvironment`: the biome's ambient tint, and glow on.
- **Proof scenes** (`src/debug/galleries/`, debug builds only):
  - `renderer_gallery.tscn`: the cube, slabs, rocks, yellow streaks and cyan core under shadows and glow. Capture
    it twice: as is, and launched with `--rendering-method gl_compatibility`.
  - `camera_gallery.tscn`: the same room at pitch 30°, 35.26° and 45°.
  - `occlusion_gallery.tscn`: walls of three heights between the camera and actors, comparing dithered fade
    against the X-ray silhouette (the `BaseMaterial3D` stencil mode), and an outline vs. no outline on snow and
    red-canyon grounds.
- **Screenshots:** `scripts/shots/galleries.gd` writes the PNGs to `build/shots/v0.0.1/`. The lead shares them
  with the owner and links them from `evidence/GALLERIES.md`.
- **Tests:** `tests/unit/presentation/test_occlusion_select.gd`, covering a wall in front, a wall behind, a wall
  off-axis and two actors.
- **Gates (owner):**
  - **Renderer pick:** Forward+ or Compatibility, judged on the owner's lowest-spec GPU from the Windows build.
  - **Camera pitch pick.**
  - **Occlusion technique pick.**

  Each pick becomes a PD row in `LOCKED_DECISIONS.md`.
- **Done when:** the galleries are in evidence and the picks are recorded. If the owner is unavailable, build on
  with Forward+ and 35.26°, and log the pending picks under PROGRESS "Gates".

### 9. App shell (presentation + application + e2e)
- **Files:**
  - `src/presentation/menus/main_menu.tscn`: Play, Options, Credits, Quit.
  - `pause_menu.tscn`: Resume, Main menu.
  - `options_menu.tscn` (a stub): the language, the Master/Music/Effects volumes, VSync and the frame cap.
  - `src/application/game_settings.gd`: adapted from Deathventory, stored in `ProfileStore`.
  - `default_bus_layout.tres`: the Master, Music and Effects buses.
  - Window close: `set_auto_accept_quit(false)`, then on `NOTIFICATION_WM_CLOSE_REQUEST` save the profile and
    quit.
- **Reachable from the real game?** Yes: proved by `test_e2e_shell.gd` (boot → menu → Play → Esc pauses → Main
  menu), driven by input events only.
- **Tests:** settings round-trip through `ProfileStore` in memory mode (`ProfileStore.new("")`); the volume
  sliders move the right buses.
- **Done when:** the e2e and unit tests pass.

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
  - an e2e test that switches to `es` and checks the main menu's Play label reads `JUGAR` (or the agreed
    translation).
- **Done when:** both languages render with ñ and accents, and no visible string skips `tr()`. Grep `text = "`
  and `.text = "` in `src/` returns nothing but keys.

### 11. Credits and licenses (presentation)
- **Files:** `src/presentation/menus/credits.tscn` and `data/credits/credits.tres`. The credits hold:
  - the owner's credit line (**Open O4**);
  - "Made with Godot Engine";
  - the Godot license from `Engine.get_license_text()`;
  - third-party notices from `Engine.get_copyright_info()`;
  - the font's licence.
- **Tests:**
  - The credits screen opens from the main menu (e2e).
  - The export smoke confirms GUT isn't in the pack, and the zip audit confirms no `addons/gut`.
- **Done when:** the tests pass.

### 12. Dev panel stub (debug)
- **Files:**
  - `src/debug/dev_panel.tscn` + `dev_panel.gd`. It is adapted from Deathventory's release gate: it opens only
    when `OS.is_debug_build()`, toggled by backtick through its physical keycode.
  - `src/application/debug_api.gd`.
- **What the panel shows:** seed, tick, the last checkpoint hash, FPS, and the sim ticks run this frame.
- **What it can do:** pause the sim, step one tick, reseed and restart. It does this through `DebugApi` commands
  applied at a tick boundary, never by touching `World` directly.
- **Tests:**
  - `DevPanel.unlocked(false)` is closed (the release gate);
  - stepping one tick advances `World.tick` by exactly 1;
  - the panel strings use `tr()`.
- **Done when:** the tests pass.

### 13. Release
- `scripts/shots/tour.gd` runs the shell, stage and galleries in en and es; the output is linked in
  `evidence/TOUR.md`.
- **Release items:**
  - patch notes `docs/patch-notes/v0.0.1.md` + `v0.0.1.es.md`, and the README index row;
  - `data/patch_notes/v0.0.1.tres`, built by `scripts/content/build_patch_notes.gd`;
  - the ROADMAP §4 status and History;
  - the README status line;
  - CLAUDE.md, re-checked;
  - `tests/MIN_TEST_COUNT` set to the passing count;
  - PROGRESS final.
- **`PLAYTEST.md`** for the owner's Windows check
  ([`../../process/OWNER_GATES.md`](../../process/OWNER_GATES.md) §5). It asks the owner to:
  - download the CI artifact;
  - move, aim and dash with mouse+keyboard, then with a gamepad;
  - say which felt off;
  - pick the renderer and camera pitch if not done yet;
  - judge the readability of the cube on the stage;
  - note the frame rate.

  Its answers are **OWNER ONLY**.
- **PR to `main`**, then CI green. The owner merges, or tells the lead to.
- **Done when:** the PR is merged and the owner's Windows check is recorded in `PLAYTEST.md` by the owner.

## Open items (what they block)
- **O1** GA text pasted: blocks v0.1.0 Phase 0, not this version. Until it exists, Steps 4 and 6 use `STARTING
  VALUE`s for the player kit.
- **O2** Reference image added: blocks nothing; it's needed for the v0.1.0 palette G2.
- **O3** `main` exists: blocks Step 13's PR.
- **O4** Credit line: blocks Step 11's final text (a placeholder key `CREDITS_OWNER` shows "…" until it arrives).
- **Gates** (renderer, pitch, occlusion technique): Step 8. **Owner Windows check:** Step 13.
- **Godot patch version:** pin the newest `4.7.x` that `setup-godot` supports. Deathventory proved `4.7.2`; prefer
  it unless a newer 4.7 patch fixes something we need. Record the pin in PROGRESS.

## Verification
- **Tests:** every step's tests in `tests/`, on both CI jobs, with real-input e2e for every player-facing path.
- **Evidence:** `PORTS.md`, `REPLAY_CROSS_OS.md`, `BENCH.md`, `GALLERIES.md`, `TOUR.md`, `EXPORT_SMOKE.md` (the
  CI log excerpt), and `PLAYTEST.md` (owner only).
- **Goldens:** the replay golden and the export-smoke hash are created here. After this, they change only on
  purpose and are named in PROGRESS.
- **Before every code push:** the full suite. CI must be green before merge.
