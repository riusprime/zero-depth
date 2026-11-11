#!/usr/bin/env bash
# Checks that the release build of the native library (template_release, what an export ships) gives the recorded
# fixtures, as the debug build the tests load does (NATIVE_CORE.md §6: the optimisation level must not change a bit).
# The editor binary always loads the debug entry of native/zd_native.gdextension, so for this run the file's debug
# entries point at the release library; the generated file is put back when the run ends (it is not tracked:
# scripts/native/build.sh writes it from zd_native.gdextension.in).
# Usage: bash scripts/native/check_release.sh      (needs both builds: bash scripts/native/build.sh all)
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
EXT=native/zd_native.gdextension
[[ -f "$EXT" ]] || { echo "check_release: $EXT is missing (bash scripts/native/build.sh all)" >&2; exit 1; }
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) REL="native/bin/zd_native.windows.template_release.x86_64.dll" ;;
*) REL="native/bin/zd_native.linux.template_release.x86_64.so" ;;
esac
[[ -f "$REL" ]] || { echo "check_release: $REL is missing (bash scripts/native/build.sh release)" >&2; exit 1; }
mkdir -p build
cp "$EXT" build/zd_native.gdextension.kept
trap 'cp build/zd_native.gdextension.kept "$EXT"' EXIT
sed -E 's/^(windows|linux)\.debug\.x86_64 = "(.*)template_debug(.*)"$/\1.debug.x86_64 = "\2template_release\3"/' \
	build/zd_native.gdextension.kept > "$EXT"
grep -q "template_release" "$EXT" || { echo "check_release: could not point $EXT at the release library" >&2; exit 1; }
ZD_NATIVE_TARGET=template_release "${GODOT:-godot}" --headless --path . -s scripts/checks/native_fixtures.gd
