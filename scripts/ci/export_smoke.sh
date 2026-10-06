#!/usr/bin/env bash
# Exports the Windows pack and runs tests/export/export_smoke.gd INSIDE it (TEST_MATRIX T-EXPORT).
# The smoke must run from outside the project folder, or Godot loads the folder instead of the pack.
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
cd build/check
godot --headless --main-pack game.pck -s "$REPO_ROOT/tests/export/export_smoke.gd" -- "${ARGS[@]}" 2>&1 | tee smoke.log
exit "${PIPESTATUS[0]}"
