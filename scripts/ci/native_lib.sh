#!/usr/bin/env bash
# CI: builds the native library (scripts/native/build.sh) and checks that Godot loads it. When either fails, the
# library and its .gdextension are removed, so the later jobs run every test without it (the native tests report
# pending) instead of failing on a bad library; the workflow's `verify` job reports the failure.
# Usage: bash scripts/ci/native_lib.sh [debug|release|all]
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
mkdir -p build

drop() {
	echo "native_lib: $1; removing the library, the tests run without it" >&2
	rm -rf native/bin native/zd_native.gdextension native/zd_native.gdextension.uid .godot/extension_list.cfg
	exit 1
}

bash scripts/native/build.sh "${1:-debug}" 2>&1 | tee build/native_build.log
[[ ${PIPESTATUS[0]} -eq 0 ]] || drop "the build failed"
godot --headless --path . --editor --import --quit > build/native_import.log 2>&1
if sed -E 's/\x1B\[[0-9;]*[mK]//g' build/native_import.log | grep -E "^(ERROR|SCRIPT ERROR)" | head -10 | grep -q .; then
	sed -E 's/\x1B\[[0-9;]*[mK]//g' build/native_import.log | grep -E "^(ERROR|SCRIPT ERROR)" | head -10 >&2
	drop "the import reported errors with the library"
fi
echo "native_lib: built, and the import loaded it without errors"
