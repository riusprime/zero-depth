#!/usr/bin/env bash
# CI: builds the native library (scripts/native/build.sh) and checks that Godot loads it (two imports: the first only
# registers the extension). The library is required (the sim runs only there), so a failed build or load fails this
# step, with the build or import log's last lines, before any test runs.
# Usage: bash scripts/ci/native_lib.sh [debug|release|all]
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
mkdir -p build

bash scripts/native/build.sh "${1:-debug}" 2>&1 | tee build/native_build.log
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
	echo "native_lib: the native library did not build (build/native_build.log, native/README.md)" >&2
	exit 1
fi
for pass in 1 2; do
	godot --headless --path . --editor --import --quit > build/native_import.log 2>&1
done
if sed -E 's/\x1B\[[0-9;]*[mK]//g' build/native_import.log | grep -E "^(ERROR|SCRIPT ERROR)" | head -10 | grep -q .; then
	sed -E 's/\x1B\[[0-9;]*[mK]//g' build/native_import.log | grep -E "^(ERROR|SCRIPT ERROR)" | head -10 >&2
	echo "native_lib: the import reported errors with the library" >&2
	exit 1
fi
grep -q "zd_native.gdextension" .godot/extension_list.cfg 2>/dev/null || {
	echo "native_lib: Godot did not register native/zd_native.gdextension" >&2
	exit 1
}
echo "native_lib: built, and Godot loads it without errors"
