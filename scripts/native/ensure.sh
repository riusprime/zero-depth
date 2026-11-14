#!/usr/bin/env bash
# Makes the native library current for this checkout and registered with Godot, so a test run or a tool can start
# (the sim runs only in the library: native/README.md). Builds it (scripts/native/build.sh: about 10 s when nothing
# changed, 35 s with a warm SCONS_CACHE), then imports; when Godot did not list the extension yet (a fresh checkout,
# a first build) it imports a second time, since the first import only registers it.
# ZD_NATIVE_PREBUILT=1 skips the build and only checks that the library is there (CI jobs that restore it).
# A failure stops here with the reason, never as failing tests later.
# Usage: bash scripts/native/ensure.sh [debug|release|all]        (writes build/native_build.log, build/import.log)
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
mkdir -p build

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) LIB="native/bin/zd_native.windows.template_debug.x86_64.dll" ;;
*) LIB="native/bin/zd_native.linux.template_debug.x86_64.so" ;;
esac

if [[ "${ZD_NATIVE_PREBUILT:-}" == 1 ]]; then
	[[ -f "$LIB" && -f native/zd_native.gdextension ]] || {
		echo "native: ZD_NATIVE_PREBUILT=1 but $LIB or native/zd_native.gdextension is missing" >&2
		exit 1
	}
else
	bash scripts/native/build.sh "${1:-debug}" > build/native_build.log 2>&1 || {
		tail -20 build/native_build.log >&2
		echo "native: the library did not build (build/native_build.log; native/README.md lists what it needs)" >&2
		exit 1
	}
fi

import() {
	"${GODOT:-godot}" --headless --path . --editor --import --quit > build/import.log 2>&1 || true
}
registered() {
	grep -q "zd_native.gdextension" .godot/extension_list.cfg 2>/dev/null
}
registered_before=0
registered && registered_before=1
import
if [[ $registered_before == 0 ]]; then
	import
fi
registered || {
	echo "native: Godot did not register native/zd_native.gdextension (see build/import.log)" >&2
	exit 1
}
