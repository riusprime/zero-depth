#!/usr/bin/env bash
# Installs the pinned toolchain in a fresh (cloud) session: Godot, optionally its export templates, gdtoolkit, and
# the C++ toolchain (gcc/g++, SCons), then builds and registers the native library the sim needs.
# Usage: bash scripts/setup_toolchain.sh [--templates]
# If a download is blocked by the network policy, this fails loudly; report checks as "not run locally".
set -euo pipefail
GODOT_VERSION="4.7.2"
DEST="${GODOT_HOME:-/opt/godot}"
BIN="$DEST/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"

if ! command -v godot >/dev/null || [[ "$(godot --version)" != ${GODOT_VERSION}.stable* ]]; then
	mkdir -p "$DEST"
	curl -fsSL -o "$DEST/godot.zip" "$BASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
	unzip -q -o "$DEST/godot.zip" -d "$DEST" && rm "$DEST/godot.zip"
	ln -sf "$BIN" /usr/local/bin/godot 2>/dev/null || { mkdir -p "$HOME/.local/bin"; ln -sf "$BIN" "$HOME/.local/bin/godot"; }
fi
godot --version

if [[ "${1:-}" == "--templates" ]]; then
	TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
	if [[ ! -d "$TPL_DIR" ]]; then
		curl -fsSL -o /tmp/templates.tpz "$BASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
		mkdir -p "$TPL_DIR" && unzip -q -o /tmp/templates.tpz -d /tmp/tpl && mv /tmp/tpl/templates/* "$TPL_DIR/" && rm -rf /tmp/tpl /tmp/templates.tpz
	fi
fi

python3 -m pip install -q -r "$(dirname "$0")/../requirements-dev.txt" 2>/dev/null \
	|| python3 -m pip install -q --break-system-packages -r "$(dirname "$0")/../requirements-dev.txt"
gdformat --version

# The native library (native/README.md) is required: the sim runs only there. Linux needs gcc/g++ (godot-cpp's
# default), git and SCons (pinned in native/requirements.txt); then it is built once (about 3.5 minutes cold, the
# compiled bindings kept in SCONS_CACHE) and registered with two imports (scripts/native/ensure.sh).
if ! command -v g++ >/dev/null; then
	if command -v apt-get >/dev/null; then
		SUDO=""
		[[ $(id -u) -eq 0 ]] || SUDO="sudo"
		$SUDO apt-get update -q && $SUDO apt-get install -y -q build-essential git
	else
		echo "setup_toolchain: no g++ and no apt-get: install gcc/g++ by hand (native/README.md)" >&2
		exit 1
	fi
fi
g++ --version | head -1
python3 -m pip install -q -r "$(dirname "$0")/../native/requirements.txt" 2>/dev/null \
	|| python3 -m pip install -q --break-system-packages -r "$(dirname "$0")/../native/requirements.txt"
scons --version | head -1
bash "$(dirname "$0")/native/ensure.sh" debug
