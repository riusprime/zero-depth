# The native library (GDExtension)

C++ for the sim's hottest numeric loops, loaded by `native/zd_native.gdextension`, which the build writes from the
tracked `zd_native.gdextension.in` (a tracked `.gdextension` without its library makes Godot print an import
`ERROR` on every machine, and CI fails on those). Today it holds one class,
`ZdMover`: the move phase's collision passes (walls, solids, body pairs). It is optional at runtime: without the
built library the class is missing and every world runs the GDScript passes (`World._resolve_bodies`). With the
library, the passes run native only when switched on (`NativeSwitch`): `-- --native-move` on the game's command
line, `ZD_NATIVE_MOVE=1` in the environment, `--native=1` for `scripts/checks/horde_phases.gd`, or the GUT pre-run
hook `tests/support/native_move_hook.gd`.

The built library goes to `native/bin/` (git-ignored), the `.gdextension` beside this file (git-ignored). godot-cpp is
not in the repository. To go back to no library: delete both, then import twice (the first import still reports the
old entry in `.godot/extension_list.cfg`).

## Build on Windows (the owner's PC)

Needs Visual Studio with the C++ workload, Python 3 with `pip install scons`, and a clone of
[godot-cpp](https://github.com/godotengine/godot-cpp) (master; there is no 4.7 branch).

1. The engine's API, from the engine the game runs on (once per engine version), in any folder outside the project:

   ```bash
   godot --headless --dump-extension-api        # writes extension_api.json in the current folder
   ```

2. The bindings and the library, from `native/` (the first build compiles godot-cpp's ~1,000 generated files: 3 min 33 s
   on the owner's PC at -j8; a rebuild that only relinks the library: 12 s):

   ```bash
   scons godot_cpp=C:/Users/extri/Desktop/zerodepth/godot-cpp \
         custom_api_file=C:/Users/extri/Desktop/zerodepth/godot-api/extension_api.json \
         "vcvars=C:/Program Files/Microsoft Visual Studio/18/Insiders/VC/Auxiliary/Build/vcvars64.bat" \
         target=template_debug -j8
   ```

   `target=template_debug` is what the editor binary and debug exports load; `template_release` for release exports.
   `vcvars=` is needed for Visual Studio 2026 Insiders: SCons asks `vswhere` without `-prerelease`, so it finds no
   compiler on its own ("cl is not recognized"), and godot-cpp clears any `MSVC_VERSION` given. The SConstruct runs
   the script once and hands its PATH, INCLUDE, LIB and LIBPATH to the compiler. A release Visual Studio (2022 or a
   2026 release channel) should be found without it.

3. Reimport once so Godot lists the extension: `godot --headless --path . --editor --import --quit`.

## A permanent setup

- godot-cpp as a git submodule pinned to a commit (or a pinned download in `scripts/setup_toolchain.sh`), and the
  dumped `extension_api.json` for the pinned engine committed beside it, so every machine builds the same bindings.
- CI (Linux runners) builds `linux.*.x86_64` with gcc, before the test shards, and caches godot-cpp's objects
  (`SCONS_CACHE`); the Windows export job builds `windows.template_release.x86_64` with MSVC. The `.gdextension`
  gains the `linux.*` lines.
