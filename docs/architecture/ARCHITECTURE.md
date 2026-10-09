# Architecture

How the code is laid out and how the pieces talk. The rules inside the simulation are in
[`SIM_CONTRACTS.md`](SIM_CONTRACTS.md), the data formats in [`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md), and the
screen rules in [`PRESENTATION_CONTRACTS.md`](PRESENTATION_CONTRACTS.md). The invariants behind all of it are
EI-01..EI-11 in [`LOCKED_DECISIONS.md`](LOCKED_DECISIONS.md).

## 1. The core change from Deathventory

Deathventory was turn-based. Its domain was a pure reducer: every command cloned the state
(`RunController` alone calls `duplicate_state()` about 50 times). A real-time game can't clone the world 60 times a
second, so:

- The sim holds **one `World`, mutated in place by `World.step(InputFrame)` at a fixed 60 Hz**.
- Determinism is enforced at the boundary: the same (sim version, content hash, seed, loadout, `InputFrame` log)
  always gives the same state hash. A replay golden proves it on Linux and Windows.
- A **3D view** draws the sim's flat 2D plane through a fixed orthographic isometric camera. The view reads the
  sim and never changes it.

## 2. Layers

```
app ──► presentation ──► application ──► sim ──► content/defs
 │                            ▲
 └──► debug ──(DebugApi)──────┘
```

| Layer | Folder | May import | Owns |
|---|---|---|---|
| `app` | `src/app/` | everything below | `main.tscn`, composition root, `SimDriver`, boot, window-close handling |
| `presentation` | `src/presentation/` | `application`, `WorldReader` and plain sim value types (`SimEvent`, `InputFrame`), `content/defs` | 3D views, camera, HUD, menus, theme, audio, VFX, device input capture |
| `application` | `src/application/` | `sim`, `content` | run and encounter sessions, `InputLatch`, aim assist, replay record/play, save and profile stores, settings, input remap, `CueBuffer` |
| `sim` | `src/sim/` | `content/defs` (compiled tables only) | `World`, kernel, collision, combat, effects, AI, generation, run rules |
| `content` | `src/content/` | nothing above it | definitions, scanner, repository, validator, compilers |
| `debug` | `src/debug/` | `application` through `DebugApi` | dev panel, event-chain inspector, time controls; debug builds only |

- **Nothing imports `app/` or `debug/`.**
- `presentation` never writes sim state (EI-07). It calls `application` methods, which turn requests into
  `InputFrame` bits or debug commands applied at a tick boundary.
- `scripts/` (bench, checks, content tools; the bot balance sims were retired in v0.5.5, owner P1) may use `application`, `sim` and `content`. Only `scripts/shots/` and
  `scripts/checks/` boot the app (`main.tscn`), because they test the running game.

## 3. Architecture lint

`tests/arch/test_layering.gd` and `tests/arch/test_sim_purity.gd` read every `.gd` file and fail on violations.

- **Layering:** a `preload`/`load` path or `class_name` reference that crosses a layer the wrong way fails.
- **Read-only view (EI-07):** `src/presentation/` may name `WorldReader` (a facade with getters, `events_since()`
  and `snapshot()`), but never `World` itself. A reference to `World`, `ActorStore` or `ProjectileStore` there
  fails.
- **Sim purity:** inside `src/sim/`, these whole-word tokens fail (outside comments and strings):
  - **Scene and engine access:** `Node`, `SceneTree`, `get_tree`, `get_node`, `emit_signal`, `await`, `Tween`,
    `Timer`, `Input`, `Time.`, `OS.`, `Engine.`, `load(`, `preload(` (except the allow-listed kernel tables).
  - **Randomness:** `randi`, `randf`, `randomize`, `RandomNumberGenerator`, `cosmetic`.
  - **Banned maths:** `sin(`, `cos(`, `tan(`, `atan2(`, `atan(`, `pow(`, `exp(`, `log(`, plus the method forms
    `.angle(`, `.rotated(`, `from_angle(`, `angle_to(`, `angle_to_point(` and `.slerp(`.
- This widens Deathventory's purity scan (`tests/unit/dv_330/test_statuses_hazards.gd`). That scan read only one
  folder, matched raw substrings (so `Input` would also flag `InputFrame`), and didn't ban
  `RandomNumberGenerator`. Here the match is word-bounded and recursive.

## 4. The loop

- `SimDriver` (`src/app/sim_driver.gd`) steps the sim in `_physics_process`.
- **Project settings** (set in v0.0.1):

  | Setting | Value |
  |---|---|
  | `physics/common/physics_ticks_per_second` | `60` |
  | `physics/common/max_physics_steps_per_frame` | `4` |
  | `physics/common/physics_interpolation` | `true` |
  | `physics/common/physics_jitter_fix` | `0.0` |

- **Catch-up.** After a long frame, Godot runs at most 4 physics steps and drops the rest of the backlog, so the
  game slows down instead of skipping time. Deathventory's `AUDIT_COMBAT` found presentation-owned clocks and
  hitches that ate game time ([`../LESSONS.md`](../LESSONS.md) L3). This design is meant to rule that out, and
  T-HITCH must prove it ([`TEST_MATRIX.md`](TEST_MATRIX.md)) before anything builds on it.
- **One tick, in order:**
  1. The `InputLatch` closes the frame for this tick ([`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §3).
  2. `World.step(frame)` runs.
  3. Views write `Node3D` transforms.
  4. Godot interpolates them until the next tick.
- **Headless runs** (tests, sims, replays) never touch `SimDriver`. They loop `World.step` directly with no scene
  tree.

## 5. Folders

```
src/
  sim/
    core/        tick constants, RngStream (+ ported rng math), CanonicalValue, Kin (+ generated trig_lut.gd),
                 StateHasher, InputFrame
    world/       World, WorldReader (read-only facade), actor and projectile stores, snapshots
    collision/   circles, OBBs, swept segments, dense broadphase grids (DenseGrid, v0.4.0 SC)
    combat/      action states, hitboxes, damage pipeline, statuses, CapLedger
    effects/     SimEvent, EffectQueue, RootLedger, LoadoutCompiler, EffectRuntime, watchdog
    ai/          behaviours, behaviour param schemas, steering
    gen/         FloorGenerator, room placement, validator
    run/         RunState, reward schedule, threat T, floor progression
  content/
    defs/        Resource classes (ContentDef base, PlayerDefinition, BiomeDefinition, …)
    content_scanner.gd, content_validator.gd, validation_issue.gd
    (content_repository.gd and content_compiler.gd live in application/: the manifest hash uses the sim's
    CanonicalValue and the compiler emits sim tables, and content may not import upward)
  application/   game_version, run_session, encounter_session, input_latch, aim_assist, replay, run_save_store, run_saver,
                 profile_store, game_settings, input_remap, cue_buffer, debug_api
  presentation/
    world_view/  actor, projectile, wall, prop and telegraph views
    camera/      iso rig, follow, shake, occlusion
    input/       device tracker, mouse ground-plane aim, prompt glyphs
    hud/  menus/  theme/  audio/  vfx/
  app/           main.tscn, main.gd (the composition root), sim_driver.gd, stage_scenario.gd, galleries/
  debug/         dev_panel, event_chain_inspector, debug_event_log, debug_time_controller, galleries/
scripts/
  sim/           gen_trig_lut.gd, kernel_smoke.gd, encounter_sim.gd, run_sim.gd, policies/
  bench/         sim_bench.gd, view_bench.gd
  checks/        hitch_probe.gd
  content/       print_manifest.gd, build_patch_notes.gd, bake_rooms.gd (from v0.3.0)
  shots/         galleries.gd, tour.gd, mock_<screen>.gd
  setup_toolchain.sh, verify.sh, verify.ps1, export_windows.ps1
data/
  items/ enemies/ encounters/ bosses/ biomes/ threat/ rooms/ rooms_src/ player/ loot_pools/ patch_notes/ credits/
  audio/cues/
locale/strings.csv
tests/
  unit/ arch/ golden/ gen/ content/ e2e/ export/ support/
docs/ (this kit)
```

## 6. Coordinates

- The sim plane uses metres, with `(x, y)` → 3D `(x, 0, -y)`. Up in the sim is "away" on the 3D ground.
- The camera rig's yaw is fixed at `rotation.y = +45°`. Screen-relative input (WASD, both sticks) is rotated +45°
  into the sim plane by the `InputLatch` before quantizing. W maps to sim angle 135°. The convention and a worked
  table are in [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §3. Mouse aim needs no rotation, because its ray hits the
  plane in world coordinates.
- **Core height** is a constant (**starting value** 0.5 m). It is where mouse rays meet the ground plane and where
  projectiles are drawn, so the reticle lines up with the shot.

## 7. Input

- **Actions.** Every input is an `InputMap` action: `move_up/down/left/right`, `aim_*` (right stick),
  `primary`, `utility`, `dash`, `interact`, `pause`, plus UI actions.
  - Keyboard bindings use **physical keycodes**, so WASD stays WASD on AZERTY.
  - Gamepad defaults are a twin-stick layout.
- **Remapping.** `InputRemap` (application) stores bindings in the profile and applies them to `InputMap` at
  boot. Deathventory's `Keybinds` mapped rebound keys back to hard-coded keycodes and had no gamepad support; it
  is not reused.
- **Device tracker.** It records the last device used. That switches the button prompts and the aim mode (mouse
  ray vs. right stick).
- **Mouse aim.** The cached mouse position becomes a camera ray (`project_ray_origin`/`project_ray_normal`),
  intersected with the plane at core height.
- **Aim assist.** Gamepad only, a cone of about 12° (GA: input), applied in `application` before quantization.
- **e2e tests** drive the real `main.tscn` the way a player does ([`TEST_MATRIX.md`](TEST_MATRIX.md) T-E2E):
  1. `Input.parse_input_event(ev)`, then `Input.flush_buffered_events()`;
  2. `await get_tree().physics_frame`, under `--fixed-fps 60`.

  Deathventory's e2e driver called game methods directly (`comp._unhandled_key_input(...)`, panel APIs) and
  never sent input this way. So a feature could pass its tests without being reachable in the game
  ([`../LESSONS.md`](../LESSONS.md) L2).

## 8. Content

[`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md) is the full contract. In short:
- typed `.tres` definitions with `validate()`;
- one remap-safe `ContentScanner` on `ResourceLoader.list_directory`;
- a manifest hash checked inside the exported pack;
- definitions compiled into plain tables at encounter start.

## 9. Floor generation

- `FloorGenerator.generate(seed: int, floor: int, biome: BiomeDefinition) -> FloorPlan` is pure and lives in
  `src/sim/gen/`.
- **Graph.** A DAG holding a main path of 7–9 encounters, 1–3 optional branches and a boss room (PD-03). Fork
  doors carry their threat cost and reward preview, which the HUD shows before the choice.
- **Rooms.**
  - Each room gets a sub-seed derived from the `map` stream, so changing one room never shifts another
    ([`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §5).
  - Templates are picked by tag (size class, shape, biome affinity).
  - Cover fills a seeded subset of the template's authored cover slots.
  - Props such as rocks and grass are placed by Poisson-disk sampling outside lanes and slots.
- **Validator.** Every room must pass all of these:
  - every exit is reachable from the entry at the player's radius;
  - every spawn is at least 6 m from the entry;
  - doors have clearance;
  - the open area is at least a minimum;
  - cover count is within the template's range.

  On failure, the generator retries up to 8 sub-seeds, then falls back to the template's authored default layout.
  A fallback is logged and counted.
- **Tests.**
  - CI runs 200 seeds per biome on every PR, checking validity, determinism and no fallback storms.
  - A nightly job (`.github/workflows/nightly.yml`, from v0.3.0) runs 10,000 seeds per biome.
  - v0.4.0 adds 1,000-seed property tests across all floors.
- **Plan check.** A save's snapshot carries the floor's walls; restoring it into a floor generated from the save's
  inputs checks they match ([`§10`](#10-save)).

## 10. Save

v0.4.0 SV ([`../roadmap/v0.4.0/PLAN.md`](../roadmap/v0.4.0/PLAN.md) "Saves (SV)", ROADMAP R3). The PLAN's owner-directed
design replaces this section's earlier rule ("never `World` in a save"): the save now holds the room-entry snapshot of
the whole `World`.
- **When.** At each **first entry into a room** of the floor (the start hall at the floor's first tick, then every room
  the player walks into for the first time), right after the tick of the entry; and **on close** (pause → Main menu,
  the window's close request), which makes sure the last room-entry save is on disk. Quitting mid-room resumes at that
  room's entry. A death or a win deletes the save; a new run overwrites it. `RunSaver` (`src/application/`) decides.
- **What** (a payload, `RunSaver.PAYLOAD_VERSION`):
  - the run: `RunState`'s seed, floor, biome order, carry, totals and build, plus the stage seed (the `RunTable` is
    compiled again from content);
  - the rooms entered on this floor (the minimap's discovery comes back with them);
  - the tick, and the world's canonical snapshot (`WorldSnapshot`, [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10a).
- **Load (Continue).** The main menu shows **Continue** (first, focused) while a save reads. Continue rebuilds the run
  and its floor the way a new floor is built (seed, floor, build, content), then writes the snapshot into it
  (`WorldSnapshot.apply`): the resumed world has the saved state hash. A snapshot whose floor differs from the one
  generated from its inputs (other content, another game build) doesn't fit and is a reported load failure.
- **Cost.** The snapshot is taken on the frame (≈ 0.6–0.8 ms, packed arrays copied, no hashing); the encode, the
  checksum and the file write run on a `WorkerThreadPool` task (`RunSaveStore.write_async`). Numbers:
  [`../roadmap/v0.4.0/evidence/SAVES.md`](../roadmap/v0.4.0/evidence/SAVES.md).
- **Store.** `RunSaveStore`, `user://saves/run.save`:
  - atomic write: write a `.tmp`, then rename;
  - an envelope `{save_version, game_version, payload}`, stored as the magic `ZDSV`, `save_version`, the size, a
    SHA-256 of the body and the body (zstd of `var_to_bytes`, plain data only);
  - compatibility checks `save_version` only (EI-09);
  - headless runs (tests, sims, CI) keep the bytes in memory (`RunSaveStore.new("")`).
- **Failed load.** A save that is corrupt, fails its checksum, has another `save_version` or doesn't fit is ignored
  with a warning and moved to `run.bad.<time>.save` (kept on disk, never deleted, EI-09); the menu shows no Continue.
  A "Can't load this save" message in the menu is not built (v0.4.0 SV open item).
- **Profile.** Port `ProfileStore`: atomic writes, per-section merge on load, and a corrupt file renamed to
  `profile.bad.json`. It holds settings, bindings, unlocks and seen hints.

## 11. Localization, renderer, CI

- **Localization:** `tr()` keys from `locale/strings.csv` ([`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md) §10), a
  dynamic TTF font, and a key-coverage test. It replaces Deathventory's regex-based `Loc` (which looked up
  translations from English display text) and its bitmap Spanish fonts.
- **Renderer:** Forward+ is the default until the v0.0.1 gate decides.
  - It is expected to give stable orthographic shadows, glow for the cyan core and the yellow streaks, and MSAA.
    The renderer gallery checks that against Compatibility on the lowest-spec Windows PC the owner wants to
    support, and the owner picks.
  - Materials are `StandardMaterial3D` only, with no custom shaders unless a gallery scene proves the need.
- **CI.** This is a summary. The exact steps, and the step in which each guard goes live, are in
  [`../roadmap/v0.0.1/PLAN.md`](../roadmap/v0.0.1/PLAN.md) Step 3.
  - **`verify` (ubuntu)** runs on PRs into `main` and by hand (owner, 2026-10-08: session branches run the full suite locally before each push):
    1. check the Godot and GUT versions;
    2. import;
    3. run GUT, grepping its summary, writing JUnit XML, asserting a committed minimum test count, and failing on
       `SCRIPT ERROR` or `Parse Error`;
    4. run the real-time hitch probe (`scripts/checks/hitch_probe.gd`), then `gdformat --check` and `gdlint`;
    5. re-bake rooms and fail on any diff (`git diff --exit-code -- data/rooms`; from v0.3.0, when rooms exist);
    6. export the pack and smoke it: content counts, the manifest hash, Spanish loaded, a 600-tick headless
       `World` run inside the pack (dummy movers in v0.0.1, a real encounter from v0.1.0), and no GUT shipped;
    7. sim smoke: 20 seeded runs, run twice and diffed;
    8. the bench, as an informational (non-failing) step whose output feeds evidence.
  - **`shots`** and **`windows`** run only on pushes to `main` and on demand (the Actions tab's "Run workflow"
    button), so a playable build exists per merge, not per branch push. Uploaded artifacts are kept 14 days.
  - **`shots`** (ubuntu, under `xvfb-run`): gallery and tour screenshots as an artifact
    ([`PRESENTATION_CONTRACTS.md`](PRESENTATION_CONTRACTS.md) §10).
  - **`windows`:**
    1. check the pins and import, with the same guards;
    2. run the golden replays (cross-OS determinism, EI-11);
    3. export the release `.exe` and a debug gallery build;
    4. audit the zip;
    5. upload both artifacts.

## 12. Reusing Deathventory

The new repo can read `riusprime/deathventory` only if the owner adds it to the session.
[`../../KICKOFF.md`](../../KICKOFF.md) asks for it to be added **read-only**, and v0.0.1 Step 0 copies the PORT
files. Each copied file gets a header comment:
`# Ported from riusprime/deathventory@<sha>:<path>. Changes: <list>.`

All paths and line numbers below were verified against Deathventory `main` at `1d697803` (v0.9.7). v0.0.1 Step 0
records the SHA it ports from in `evidence/PORTS.md`. Every later port uses that same SHA, even if Deathventory's
`main` moves on.

### PORT (copy, then trim)

| Deathventory path | What to keep | What to change |
|---|---|---|
| `src/domain/core/deterministic_rng.gd` + `rng_step.gd` | xorshift32 (13/17/5), FNV-1a `derive_stream_seed`, the zero-state remap | Wrap in a mutable `RngStream`. Replace the modulo pick with rejection sampling. Add `range_int`/`chance_permille` |
| `src/domain/core/canonical_value.gd` | Type-tagged little-endian encoding, sorted dictionary keys, `sha256_hex` | Add `Vector2` and packed float arrays. Write floats as **float32** bits, with −0.0 normalized. Replace `assert(false)` (stripped in release) with a hard error. Add a streaming mode for `StateHasher` |
| `src/domain/model/validation_issue.gd` | All of it | — |
| `src/app/game_version.gd` + its test `tests/v2/v2_01/test_game_version.gd` (lines 14–22) | The version comes from `application/config/version`. The test checks every export preset's `file_version`/`product_version` | Drop the patch-note entry checks from the test (lines 34–49) until patch notes exist |
| `src/application/run_save_store.gd` | Atomic tmp+rename, the envelope, `save_version`-only compatibility, the headless in-memory mode | Built in v0.4.0 SV (§10): the run payload with the world snapshot, a checksum, worker-thread writes, the `.bad` copy on a failed load |
| `src/application/profile_store.gd` | Atomic writes, a corrupt file renamed to `.bad.json`, per-section merge, the headless in-memory mode | Replace Deathventory's sections. Cut `JournalStore` and its migration |
| `src/presentation/audio/sfx_mixer.gd` | Pure voice policy: per-cue cooldown, lane caps, max voices, the repeat roll-off, ducking | Read typed cue resources instead of `SfxLibrary.spec()`. Pitch jitter uses the `cosmetic` stream |
| `tests/export/export_smoke.gd` | Runs as a `SceneTree` script inside the pack. Pack detection, the "GUT not shipped" check, the `ok`/`MISS` lines and exit code | Replace every check with this game's (§11) |
| `.github/workflows/verify.yml` | `setup-godot@v2`, import, GUT with the `grep "Passing Tests"` guard, export-pack + smoke, log upload on failure | Add JUnit, the minimum count, error greps, lint, re-bake, sim smoke. Don't swallow import errors with `\|\| true`; fail on them |
| `scripts/verify.sh` (and `verify.ps1`) | The GUT command | Add the import step and the summary guard that CI has |
| `tests/support/test_harness_self_test.gd` | Asserts the vendored GUT version | — |

### ADAPT (copy the idea and the useful parts, rewrite the rest)

| Deathventory path | Keep | Rework |
|---|---|---|
| `src/content/content_repository.gd`, `src/content/resource_index.gd`, `src/content/content_validator.gd` | Sorted discovery, the id index with issue codes (`id_empty`, `duplicate_id`), validate-all with no early exit, the manifest hash only when valid | Discovery through `ResourceLoader.list_directory`. Replace the hard-coded category lists and per-class serializer chains with a base definition class that declares its category |
| `src/domain/events/event_queue.gd` | Ordered drain with binary insertion. Its key is depth → priority → root → target → source → rule → insertion | Key becomes `(depth, priority, root_id, seq)`. Dedupe per `(root, effect)`, not per exchange. Counters reset per tick. Emit `LIMIT` events |
| `src/domain/progression/build_query.gd` → `LoadoutCompiler` | Querying effects by key, sums and maxima | Compile once when stacks change, not on every query |
| `src/domain/progression/stack_curve.gd` → integer tables | The idea of diminishing stacks | It computes `a * ln(1 + n / k)`. Here curves are authored integer tables (no `log` in the sim) |
| `src/application/game_settings.gd` | Defaults, option lists, audio bus setup, frame cap, the headless display skip | Language through `TranslationServer`. Bindings through `InputMap`. Drop Deathventory's keys |
| `src/presentation/theme/theme_palette.gd` | The closed role table, the magenta sentinel for unknown roles, colour-blind mode maps, WCAG contrast | New tokens ([`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md)) |
| `src/presentation/menu/dev_panel.gd` | The release-build gate, and `track_profile=false` on touched runs | Debug edits become `DebugApi` commands applied at a tick boundary. Text through `tr()` |
| `src/debug/debug_event_log.gd`, `src/debug/debug_time_controller.gd` | A bounded log; a pause/step API | Use a ring buffer (not `pop_front`), with tick stamps. Time control drives ticks per frame and single-step, never `Engine.time_scale` |
| `scripts/balance/campaign_sim.gd`, `scripts/balance/sim/run_recorder.gd`, `scripts/balance/sim/policies/sim_policy.gd`, `scripts/balance/sim/policy_registry.gd` | `-- key=value` arguments, seed ranges, shards and workers, sorted-key JSONL, `timings.tsv` kept out of the JSON, `SUMMARY.md` with Wilson intervals, the policy registry | A policy returns an `InputFrame` per tick instead of answering turn questions. Records hook into events, not turns |
| `tests/e2e/dv_840/run_driver.gd` | Booting the real `main.tscn`, recording ops and markers | Send input with `Input.parse_input_event`; no direct method calls and no writes to private state |
| `tests/golden/dv_350/fixtures/golden_scenario_runner.gd` | Fixture → run → hash → compare | Hash with `StateHasher`, not `JSON.stringify` (which loses float precision) |
| The purity test in `tests/unit/dv_330/test_statuses_hazards.gd` | Its banned-token list | Recursive, word-bounded, wider list (§3) |
| `tests/v9/v096/test_export_paths.gd`, `export_presets.cfg`, `.github/workflows/windows-export.yml`, `scripts/export_windows.ps1` | One "Windows Desktop" preset (x86_64, `embed_pck=false`), excluding `tests/*`, `docs/*`, `scripts/*`, `addons/gut/*`, `*.uid`, `*.md`. The Windows job with templates, the zip and `SHA256SUMS.txt` | The include filter is not needed for CSV locale (it imports to `.translation`). Names come from `{{TITLE}}`. The path test checks the scanner, not `.remap` stripping |

### Not reused

| Deathventory path | Why not |
|---|---|
| `src/domain/reactions/reaction_engine.gd` | Clones the state for every chain (`context.state.duplicate_state()`); built for one grid backpack |
| `src/application/run_controller.gd` | Clones the state per command, and runs its own private clock (`advance_time_us`, telegraph timers) |
| `src/application/presentation_gate.gd` | Lets presentation hold game actions (`can_save()` waits on pending animations) and silently evicts the oldest batches. Replaced by the non-blocking `CueBuffer` |
| `src/application/keybinds.gd` | Raw keycode map with no `InputMap` and no gamepad |
| `src/presentation/i18n/loc.gd` | Translates English display text with regex templates; bitmap Spanish fonts |
| `src/bootstrap/bootstrap.gd` | A 640×360 pixel-art letterbox; not the main scene |
| `src/content/content_paths.gd` | Hard-coded content paths that bypass the index |

## 13. Top risks and their early proofs

| # | Risk | Early proof | When |
|---|---|---|---|
| 1 | GDScript is too slow for the sim | `scripts/bench/sim_bench.gd`. **Stress scene:** 60 enemies, 300 projectiles, 40 walls, for 3,600 ticks, at mean ≤ 2 ms per tick and p99 ≤ 4 ms. **Reference encounter** (what sims run): headless ≥ 15× real time, which means a mean ≤ 1.1 ms. The stress scene can't meet both: 2 ms per tick is only 8.3× real time. So the 15× target applies to the reference encounter; the owner confirms this reading in v0.0.1 | v0.0.1 (dummy movers), v0.1.0 (real enemy AI) |
| 2 | Floats differ between operating systems | Replay golden with the same hash on the ubuntu and windows jobs | v0.0.1 |
| 3 | The renderer misbehaves | Shadow and streak scene in Forward+ vs. Compatibility on the owner's GPU | v0.0.1 |
| 4 | Iso occlusion hides the action | Occlusion gallery scene, plus a unit test of the pure occluder-selection function | v0.0.1 |
| 5 | Proc chains explode | Fuzz 200 random loadouts of 10–30 stacks: zero `LIMIT` events and ≤ 256 events per tick | v0.2.0 |
| 6 | Input feels wrong | e2e tests: a tap shorter than one frame still dashes; pad and mouse aim parity | v0.0.1 |
| 7 | Exports ship without content | The in-pack 600-tick encounter and the manifest-hash check | v0.0.1 |
| 8 | The generator softlocks | Seeded property tests | v0.3.0 (200/biome in CI), v0.4.0 (1,000) |

If a proof fails, the version stops and the owner decides the response. The fallbacks are:
- risk 1: a GDExtension sim core, or fewer entities;
- risk 2: fixed-point kinematics;
- risk 3: Compatibility.

Each fallback is an EI change.
