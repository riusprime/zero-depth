#!/usr/bin/env bash
# Builds the game's native library (native/README.md) for this machine's platform: fetches the pinned bindings if
# missing, compiles with SCons into native/bin/, and writes native/zd_native.gdextension from its tracked .in.
# Usage: bash scripts/native/build.sh [debug|release|all]     (default debug: what the editor and headless runs load)
# Windows: finds Visual Studio's C++ tools through vswhere (prerelease channels too). Linux: gcc (CC/CXX untouched).
# SCONS_CACHE (default ~/.cache/zero-depth/scons, shared by every worktree) keeps the compiled bindings, so their
# ~3.5-minute build is paid once per bindings commit and compiler.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

case "${1:-debug}" in
debug) TARGETS=(template_debug) ;;
release) TARGETS=(template_release) ;;
all) TARGETS=(template_debug template_release) ;;
*)
	echo "usage: bash scripts/native/build.sh [debug|release|all]" >&2
	exit 2
	;;
esac

if ! command -v scons >/dev/null; then
	echo "build: scons is missing (pip install -r native/requirements.txt)" >&2
	exit 1
fi
bash scripts/native/fetch_bindings.sh

# Paths as the (native) Python under SCons reads them
winpath() { if command -v cygpath >/dev/null; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

export SCONS_CACHE="${SCONS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/zero-depth/scons}"
mkdir -p "$SCONS_CACHE"
export SCONS_CACHE="$(winpath "$SCONS_CACHE")"

ARGS=("godot_cpp=godot-cpp" "custom_api_file=api/extension_api.json")
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
	VSWHERE="$(printenv 'ProgramFiles(x86)' || echo 'C:\Program Files (x86)')/Microsoft Visual Studio/Installer/vswhere.exe"
	[[ -f "$VSWHERE" ]] || { echo "build: vswhere not found at $VSWHERE (install Visual Studio)" >&2; exit 1; }
	VS="$("$VSWHERE" -prerelease -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
		-property installationPath | tr -d '\r' | head -1)"
	[[ -n "$VS" ]] || { echo "build: no Visual Studio with the C++ x64 tools (vswhere found none)" >&2; exit 1; }
	VCVARS="$VS/VC/Auxiliary/Build/vcvars64.bat"
	[[ -f "$VCVARS" ]] || { echo "build: $VCVARS is missing" >&2; exit 1; }
	ARGS+=("platform=windows" "vcvars=$(winpath "$VCVARS")")
	JOBS="${NUMBER_OF_PROCESSORS:-4}"
	;;
Linux)
	ARGS+=("platform=linux")
	JOBS="$(nproc)"
	;;
*)
	echo "build: no native build for $(uname -s) yet" >&2
	exit 1
	;;
esac

for target in "${TARGETS[@]}"; do
	echo "build: $target ($(uname -s), -j$JOBS, cache $SCONS_CACHE)"
	scons -C native -j"$JOBS" "${ARGS[@]}" "target=$target" arch=x86_64
done
ls native/bin/
