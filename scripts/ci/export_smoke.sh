#!/usr/bin/env bash
# Exports the Windows pack and runs tests/export/export_smoke.gd INSIDE it (TEST_MATRIX T-EXPORT).
# The smoke must run from outside the project folder, or Godot loads the folder instead of the pack.
# The sim needs its native library (native/README.md), and a pack never holds it: an exported game finds it beside its
# executable. So the smoke runs from build/check/run/, a folder laid out like an export: a copy of this Godot
# executable (and its console wrapper on Windows), this platform's debug library, and the pack.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
mkdir -p build/check
ARGS=(expect_pack=1)
if [[ -f scripts/content/print_manifest.gd ]]; then
	godot --headless --path . -s scripts/content/print_manifest.gd -- out="$REPO_ROOT/build/check/manifest.txt"
	ARGS+=(manifest="$REPO_ROOT/build/check/manifest.txt")
fi
if [[ -f tests/golden/fixtures/export_smoke_hash.txt ]]; then
	ARGS+=(world_hash="$REPO_ROOT/tests/golden/fixtures/export_smoke_hash.txt")
fi
godot --headless --path . --export-pack "Windows Desktop" build/check/game.pck > build/check/export.log 2>&1
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) LIB="native/bin/zd_native.windows.template_debug.x86_64.dll" ;;
*) LIB="native/bin/zd_native.linux.template_debug.x86_64.so" ;;
esac
[[ -f "$LIB" ]] || { echo "export_smoke: $LIB is missing (bash scripts/native/ensure.sh)" >&2; exit 1; }
EXE="$(godot --headless --path . -s scripts/ci/print_executable.gd | sed -n 's/^EXE|//p' | tr -d '\r' | tail -1)"
[[ -f "$EXE" ]] || { echo "export_smoke: could not find the Godot executable ($EXE)" >&2; exit 1; }
RUN=build/check/run
rm -rf "$RUN" && mkdir -p "$RUN"
cp "$EXE" "$RUN/"
CONSOLE="${EXE%.exe}_console.exe"
RUNNER="$RUN/$(basename "$EXE")"
if [[ "$EXE" == *.exe && -f "$CONSOLE" ]]; then
	cp "$CONSOLE" "$RUN/"
	RUNNER="$RUN/$(basename "$CONSOLE")"  # the console wrapper keeps stdout; it must sit beside the GUI exe
fi
cp "$LIB" build/check/game.pck "$RUN/"
cd "$RUN"
"./$(basename "$RUNNER")" --headless --main-pack game.pck -s "$REPO_ROOT/tests/export/export_smoke.gd" -- "${ARGS[@]}" 2>&1 \
	| tee ../smoke.log
exit "${PIPESTATUS[0]}"
