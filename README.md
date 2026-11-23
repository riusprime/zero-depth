# Zero Depth

A real-time action roguelike in low-poly isometric 3D. Move and aim freely; fight with a wand of cards read left to
right (the Gun or the Blade), elemental spells, abilities and a dash. Push through procedural floors across five
biomes to bosses you beat by learning them, and loop on through the Ascension portal.

**Status:** v0.12.0 "Bosses You Learn" is built ([plan](docs/roadmap/v0.12.0/PLAN.md),
[patch notes](docs/patch-notes/v0.12.0.md)) and waits on the owner's playtest
([playtest](docs/roadmap/v0.12.0/PLAYTEST.md)). `main` holds v0.11.0 and v0.11.1 and gets v0.12.0 through its PR.
Windows; mouse+keyboard and gamepad; English and Spanish.

## Run

Godot 4.7.2 (the version `scripts/setup_toolchain.sh` pins). The sim's hot loops are C++, so **the native library is
required**: without it the game and every test run stop with a message that says how to build it. Build it once per
checkout. It needs Python 3 with SCons (`pip install -r native/requirements.txt`), git, and Visual Studio's C++ x64
tools on Windows or gcc on Linux ([`native/README.md`](native/README.md)).

```bash
bash scripts/native/ensure.sh                          # build the library (debug), then import
godot --path .                                         # play
```

On Windows, run the bash scripts from Git Bash and Godot natively. [`CLAUDE.md`](CLAUDE.md) has the full list of
commands.

## Test

- **A change:** lint (`gdformat --check src scripts tests && gdlint src scripts tests`), the test folders it touched
  and the e2e tests that reach it.
- **After merging branches:** `bash scripts/ci/seams.sh`, the tests where separate changes meet.
- **The full suite** runs once per version, on GitHub, in the PR into `main`, as six parallel shards
  (`bash scripts/ci/gut_shard.sh <shard>` runs one locally).

## Windows export

```bash
bash scripts/native/build.sh all                       # the debug and the release library
bash scripts/native/check_release.sh                   # the release library gives the recorded native results
pwsh -File scripts/export_windows.ps1                  # export (PowerShell; Godot 4.7.2 export templates)
```

`export_windows.ps1` writes `build/windows/game_windows_x86_64.zip` (`game.exe`, `game.pck` and the release native
library beside them) and `SHA256SUMS.txt`. A player needs nothing else: unzip and run `game.exe`.

## CI

In `.github/workflows/`:
- **Verify** (each PR into `main`, or by hand; ubuntu): lint and format, the Godot and GUT pins, every test file in
  exactly one shard; the native library built with gcc (debug and release) and checked against the recorded MSVC
  results; the hitch probe, a kernel smoke (20 seeds, run twice, identical), the bench (informational) and an export
  smoke; the full suite in six parallel shards, whose total must reach `tests/MIN_TEST_COUNT`.
- **Windows** (each push to `main`, or by hand): the native library built with MSVC, the golden replays and native
  results (cross-OS determinism), the release library checked, the release export, a zip audit (no tests, docs or
  scripts inside; the release library present), and the zip uploaded as an artifact for playtests.
- **Shots** (each push to `main`, or by hand; ubuntu, software renderer): the galleries and the screenshot tour in
  English and Spanish, uploaded as an artifact.

## Docs

| Start with | |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | How work is done here (read first, every session) |
| [`docs/roadmap/ROADMAP.md`](docs/roadmap/ROADMAP.md) | Versions, exit gates, release checklist |
| [`docs/design/GAME_BLUEPRINT.md`](docs/design/GAME_BLUEPRINT.md) | The game design |
| [`docs/LESSONS.md`](docs/LESSONS.md) | Lessons from the owner's previous game and the rules they became |
| [`docs/architecture/`](docs/architecture/) | Locked decisions, architecture, sim, content, presentation, tests |
| [`docs/architecture/NATIVE_CORE.md`](docs/architecture/NATIVE_CORE.md) | The native (C++) core |
| [`docs/OWNER_TODO.md`](docs/OWNER_TODO.md) | Everything waiting on the owner |
| [`docs/patch-notes/`](docs/patch-notes/README.md) | What changed in each version |
