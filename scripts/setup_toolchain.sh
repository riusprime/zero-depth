#!/usr/bin/env bash
# Installs the pinned toolchain in a fresh (cloud) session: Godot, optionally its export templates, gdtoolkit.
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
