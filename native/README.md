# The native library (GDExtension)

C++ for the sim's hottest numeric loops, loaded by `native/zd_native.gdextension`, which the build writes from the
tracked `zd_native.gdextension.in` (a tracked `.gdextension` without its library makes Godot print an import
`ERROR` on every machine, and CI fails on those). Today it holds one class,
`ZdMover`: the move phase's collision passes (walls, solids, body pairs). It is optional at runtime: without the
built library the class is missing and every world runs the GDScript passes (`World._resolve_bodies`). With the
library, the passes run native only when switched on (`NativeSwitch`): `-- --native-move` on the game's command
line, `ZD_NATIVE_MOVE=1` in the environment, `--native=1` for `scripts/checks/horde_phases.gd`, or the GUT pre-run
hook `tests/support/native_move_hook.gd`.

## Build

```bash
bash scripts/native/build.sh            # debug: what the editor binary and headless runs load
bash scripts/native/build.sh release    # template_release, for a release export
bash scripts/native/build.sh all        # both
godot --headless --path . --editor --import --quit   # once after the first build, so Godot lists the extension
```

Needs Python 3 with `pip install -r native/requirements.txt` (SCons, pinned), git, and a C++ compiler:
- **Windows:** Visual Studio (2022 or 2026, a prerelease channel too) with the C++ x64 tools. The script finds it with
  `vswhere -prerelease -latest` and hands `vcvars64.bat` to the SConstruct, which reads its PATH, INCLUDE, LIB and
  LIBPATH (SCons alone asks `vswhere` without `-prerelease` and finds no compiler in a preview Visual Studio). Run it
  from Git Bash.
- **Linux:** gcc (godot-cpp's default; `CC`/`CXX` are not changed).

The first build on a machine compiles godot-cpp's ~1,000 generated files (about 3.5 minutes on the owner's PC);
SCons keeps the objects in `SCONS_CACHE` (default `~/.cache/zero-depth/scons`, shared by every worktree on the
machine, one set per bindings commit, target and compiler), so a fresh checkout or worktree after that only compiles
`native/src/`. To go back to no library: delete `native/bin/` and `native/zd_native.gdextension`, then import twice
(the first import still reports the old entry in `.godot/extension_list.cfg`).

## Where things are

| What | Where |
|---|---|
| The library's code | `native/src/` (a `.gdignore` keeps Godot out) |
| The build | `native/SConstruct` (flags, the library), `scripts/native/build.sh` (bindings, compiler, cache) |
| The bindings (godot-cpp) | fetched by `scripts/native/fetch_bindings.sh` into `native/godot-cpp/` (git-ignored) at the commit in `native/GODOT_CPP_COMMIT`. Not a submodule: every git worktree would need it initialised by hand |
| The engine's API description | `native/api/extension_api.json`, from Godot `4.7.2.stable.official.ed1daf0bf` (Windows x86-64): `godot --headless --dump-extension-api` in an empty folder (6,965,057 bytes; dump and commit it again when the engine pin changes). The interface itself comes with the pinned bindings (`gdextension/gdextension_interface.json`) |
| The built library | `native/bin/zd_native.<platform>.<target>.x86_64.{dll,so}` (git-ignored) |
| CI | `.github/workflows/verify.yml` (prepare builds the Linux library, the gut shards restore it; `scripts/ci/native_lib.sh`), `.github/workflows/windows.yml` (debug and release, the release one goes into the export) |

## Rules for code here

The sim's results are recorded on Windows (MSVC) and checked on Linux (gcc), so the library must give the same float
bits on both:
- **Float flags** (`native/SConstruct`, which fails the build on a banned flag): MSVC `/fp:precise`, never `/fp:fast`,
  `/fp:contract` or `/arch:AVX*`; gcc/clang `-ffp-contract=off -fno-fast-math`, never `-ffast-math`, `-Ofast`,
  `-march=native`, `-mfma` or `-mavx*`. The target is the x86-64 baseline (SSE2): one IEEE single-precision rounding
  per operation, no fused multiply-add.
- **No `sin`, `cos`, `atan2`, `pow`, `exp` or `log`** from the C library in sim code: each C library rounds them its
  own way. The GDScript sim bans them too and uses the lookup tables in `src/sim/core/kin.gd`; native code that needs
  them uses the same tables. `sqrt`, `fabs`, `floor`, `min`, `max` are allowed (exact or correctly rounded by IEEE).
- **No threads, no clock in results, a fixed iteration order** (the clock only in the benchmark entries).
- **The self-test:** `ZdMover.determinism_probe()` runs a fixed scene through the mover and hashes the float bits;
  `tests/unit/app/test_native_move.gd` pins the value MSVC gives. A compiler or a flag that rounds one operation
  differently fails that test. Change the pinned value only on purpose, when the mover's code changes.
