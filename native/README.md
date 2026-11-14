# The native library (GDExtension)

The sim's hot loops are C++, and only C++: since v0.11.1 step 54b there is no GDScript version of them. The library is
loaded by `native/zd_native.gdextension`, which the build writes from the tracked `zd_native.gdextension.in` (a
tracked `.gdextension` without its library would make Godot print an import `ERROR` on every machine). It holds two
classes:
- **`ZdWorld`**, the sim's native side: one per `World` (`World.native`). It keeps only caches derived from the world
  (the walls and solids with their grid, the direction tables, the per-kind table and the tuning, the nav grid) and
  runs the five kernels below, each one batched call a tick phase. Every hashed column stays in GDScript
  (`ActorStore`, `ProjectileStore`, `NavField.dist`); a kernel reads them by name and writes the ones it changed back
  as new arrays. So the snapshot never holds the native side, and a restore only sends the caches again.
- **`ZdCrowd`**, a presentation helper (the batched enemies' furniture and avatars). It is not part of the sim and
  keeps its GDScript writer beside it as the reference (`EnemyBatch.native`, its own switch; the frame probe's
  `--ab=no_native_crowd`).

**The library is required.** The game, every test run and every tool that builds a `World` need it. Build it once per
checkout (below); after that the scripts that run tests keep it current themselves.

## How a `World` gets its native side, and what happens without the library

- `World._init` calls `NativeWorld.make()` (`src/sim/world/native_world.gd`), which instantiates `ZdWorld` and sends
  it the direction tables. That file is the one place in `src/sim` allowed to name `ClassDB`, with exactly the calls
  `ClassDB.class_exists(CLASS)` and `ClassDB.instantiate(CLASS)` (`tests/arch/test_sim_purity.gd`; LOCKED_DECISIONS
  2026-11-11: instantiating the sim's own kernel is not a node, a clock, content loading, randomness or library
  trigonometry). No factory has to be installed first: a `World` made anywhere (the game, a GUT test, a tool script)
  gets its native side.
- A `NavField` used on its own (the test bots' path fields) floods on a native side of its own, made the same way the
  first time it floods.
- **Without the library** the class is missing: `NativeWorld.make()` returns null and prints one error,
  `NativeWorld.MISSING` (how to build it), once a process. Then:
  - **the game** (`Main._ready` through `NativeCheck.passes`) stops its start, shows the message in a dialog when there
    is a display, and quits with exit code 1;
  - **a GUT run** stops before its first test with that error and exit code 1 (the pre-run hook
    `tests/support/native_required_hook.gd`, set in `res://.gutconfig.json`);
  - **a tool script** that checks (`scripts/checks/horde_phases.gd`, `shot_phases.gd`, `native_fixtures.gd`, the
    benches, the fixture generator) prints the error and exits 1; any other `World` prints it once and its `step()`
    only counts ticks. Nothing silently runs a different sim.

## Build

```bash
bash scripts/native/build.sh            # debug: what the editor binary and every headless run load
bash scripts/native/build.sh release    # template_release, what an export ships
bash scripts/native/build.sh all        # both
bash scripts/native/ensure.sh           # build (debug) if needed, then import, twice when Godot doesn't list it yet
```

The first import after a new library only registers the extension (`.godot/extension_list.cfg`), so import twice
(`godot --headless --path . --editor --import --quit`), or use `ensure.sh`. `scripts/verify.sh`, `scripts/verify.ps1`,
`scripts/ci/seams.sh`, `scripts/ci/gut_shard.sh` and `scripts/setup_toolchain.sh` call it first; with
`ZD_NATIVE_PREBUILT=1` (CI jobs that restore a library built earlier) it only checks the library is there.

Needs Python 3 with `pip install -r native/requirements.txt` (SCons, pinned), git, and a C++ compiler:
- **Windows:** Visual Studio (2022 or 2026, a prerelease channel too) with the C++ x64 tools. The script finds it with
  `vswhere -prerelease -latest` and hands `vcvars64.bat` to the SConstruct, which reads its PATH, INCLUDE, LIB and
  LIBPATH (SCons alone asks `vswhere` without `-prerelease` and finds no compiler in a preview Visual Studio). Run it
  from Git Bash.
- **Linux:** gcc/g++ (godot-cpp's default; `CC`/`CXX` are not changed). A cloud session gets it from
  `bash scripts/setup_toolchain.sh` (`build-essential`, SCons), which then builds the library.

The first build on a machine compiles godot-cpp's ~1,000 generated files (about 3.5 minutes on the owner's PC);
SCons keeps the objects in `SCONS_CACHE` (default `~/.cache/zero-depth/scons`, shared by every worktree on the
machine, one set per bindings commit, target and compiler), so a fresh checkout or worktree after that only compiles
`native/src/` (about 35 s), and a build with nothing changed takes about 10 s.

## The kernels (one batched call a tick phase)

| Phase | Kernel (`ZdWorld` method, file) | GDScript bridge | What GDScript still does with it |
|---|---|---|---|
| 3 nav | `nav_flood`, `nav_dist`, `nav_directions` (`zd_nav.*`) | `NativeNav` (`NavField.flood`) | the grid, its steps and the seeds (`NavField.build`, `_seeds`), the skip rule, `direction()` for the script rows; `flood_reference` is the oracle the tests compare with |
| 3 ai | `think`, `ai_intents_i/_f` (`zd_ai.*`) | `NativeAi.think` | applies the intents in row order: every random draw (`rng_enemy`: windup lengths, spells, a Sniper's next spot), the Mender's heal, the Rubble Warden's crust, the Star Warper's star and cancel; then thinks the script rows (bosses, elites, signatures, the Cinder Priest, eggs, dummies) |
| 5 move | `move` (`zd_ai.*`), then `resolve_actors` (`zd_collide.*`) | `NativeAi.move`, `NativeMove.resolve` | steers the script rows first; applies the charge trails; builds the body grid the GDScript rules read (`World.actors_near`, `enemies_near`) |
| 6 resolve | `strike`, `strike_out_i/_f` (`zd_strike.*`) | `NativeStrike.resolve` | applies the hits (`Damage.hit`), bolts, pattern waves and the hooked kinds' rules in row order; resolves the script rows |
| 6 proj | `sweep_shots`, `shot_events`, `shot_t`, `sweep_one` (`zd_shots.*`) | `NativeShots.sweep` | steers the projectiles that have a behaviour first; runs every contact through `ProjectileContacts` (damage, procs, pierce, bounce, the end hooks) |

Which kinds the native side runs is the per-kind table (`src/sim/ai/native_kind_table.gd`, read by `zd_kinds.h`):
NATIVE (from the table alone), HOOKED (the table plus a GDScript hook on an intent) or SCRIPT (GDScript runs the
row; the bodies still go through the native collision passes). How to add a kernel: the top of `zd_world.h`.

## Where things are

| What | Where |
|---|---|
| The library's code | `native/src/` (a `.gdignore` keeps Godot out): `zd_world.*` (the class, its caches and setup, the kernel slots), `zd_geom.*` (boxes, sweeps, the wall and body grids, the direction tables), `zd_columns.*` (store columns by name), `zd_kinds.h` (the per-kind table's layout), one pair per kernel: `zd_ai.*`, `zd_collide.*`, `zd_strike.*`, `zd_shots.*`, `zd_nav.*`; the presentation's `zd_crowd.*`, `zd_crowd_avatars.cpp`, `zd_avatar.*`; `register_types.cpp` |
| The GDScript side | `src/sim/world/native_world.gd` (the seam: `make`, the caches' sync), `native_ai.gd`, `native_move.gd`, `native_strike.gd`, `native_shots.gd`, `native_nav.gd` (the bridges), `src/sim/ai/native_kind_table.gd`, `src/app/native_check.gd` (the game's start) |
| The build | `native/SConstruct` (flags, the library), `scripts/native/build.sh` (bindings, compiler, cache), `scripts/native/ensure.sh` (build and register) |
| The bindings (godot-cpp) | fetched by `scripts/native/fetch_bindings.sh` into `native/godot-cpp/` (git-ignored) at the commit in `native/GODOT_CPP_COMMIT`. Not a submodule: every git worktree would need it initialised by hand |
| The engine's API description | `native/api/extension_api.json`, from Godot `4.7.2.stable.official.ed1daf0bf` (Windows x86-64): `godot --headless --dump-extension-api` in an empty folder (6,965,057 bytes; dump and commit it again when the engine pin changes). The interface itself comes with the pinned bindings (`gdextension/gdextension_interface.json`) |
| The built library | `native/bin/zd_native.<platform>.<target>.x86_64.{dll,so}` (git-ignored) |
| The tests | `tests/unit/native/` (each kernel's rules, the crowd writer), `tests/unit/app/test_native_move.gd` (the collision passes, the per-kind table, `determinism_probe`), `tests/unit/app/test_native_core.gd` (every `World` has its side; save and resume), `tests/golden/test_native_fixtures.gd` (the cross-compiler fixtures) |
| CI | `.github/workflows/verify.yml`: the prepare job builds the Linux library, debug and release (`scripts/ci/native_lib.sh`), and fails there if it doesn't build or load; the checks job and the gut shards restore it (a missing one fails the restore step) and the checks job runs the fixtures with both builds. `.github/workflows/windows.yml`: debug and release with MSVC, the fixtures with both, the release library into the export (the zip audit checks it is there) |

## Rules for code here

The sim's results are recorded on Windows (MSVC) and checked on Linux (gcc), so the library must give the same float
bits on both, in both build types:
- **Float flags** (`native/SConstruct`, which fails the build on a banned flag): MSVC `/fp:precise`, never `/fp:fast`,
  `/fp:contract` or `/arch:AVX*`; gcc/clang `-ffp-contract=off -fno-fast-math`, never `-ffast-math`, `-Ofast`,
  `-march=native`, `-mfma` or `-mavx*`. The target is the x86-64 baseline (SSE2): one IEEE single-precision rounding
  per operation, no fused multiply-add.
- **No `sin`, `cos`, `atan2`, `pow`, `exp` or `log`** from the C library in sim code: each C library rounds them its
  own way. The GDScript sim bans them too and uses the lookup tables in `src/sim/core/kin.gd`; the native side gets
  the same tables at its creation (`set_trig`). `sqrt`, `fabs`, `floor`, `min`, `max` are allowed (exact or correctly
  rounded by IEEE).
- **No threads, no clock in results, a fixed iteration order** (the clock only in the `bench_*` probes, which
  `src/sim` never calls). **No random draws:** every draw stays in GDScript on the sim's named streams, at the
  intents, in ascending row order.
- **Columns:** a kernel reads a store's columns by name (`Object::get`, sharing the buffer) and sends a changed
  column back as a new array (`Object::set`), never writing into the array it was given (`zd_columns.h`). GDScript
  must not hold a column in a local across a native call: the local keeps the old array.
- **Results are deterministic per build and identical across the Windows and Linux builds, debug and release.** What
  checks it:
  - `ZdWorld.determinism_probe()`: a fixed scene through the collision kernel; `tests/unit/app/test_native_move.gd`
    pins the value MSVC gives.
  - **The fixtures** (`tests/support/native_fixtures.gd`): every kernel called once, directly, on a seeded horde
    world (`nav`, `think`, `move`, `collide`, `strike`, `shots`, plus the probe), each hashed over its outputs and
    the columns it writes, in `tests/golden/fixtures/native_kernels_hash.txt`; and the same world played 600 ticks,
    its state hash in `native_horde_hash.txt`. `tests/golden/test_native_fixtures.gd` checks them in every GUT run
    (the debug library); `scripts/native/check_release.sh` checks them with the release library (it points the
    generated `.gdextension`'s debug entries at the release build for one run of `scripts/checks/native_fixtures.gd`,
    then puts the file back). A failure says "the native core gives different results on this compiler/platform" and
    names the kernel that differs: fix the build (its flags), never re-record to make it pass.
  - Re-record the fixtures only on purpose, from the owner's Windows build, when a kernel's code changes:
    `godot --headless --path . -s tests/golden/generate_native_fixtures.gd` (and name the change in PROGRESS).
