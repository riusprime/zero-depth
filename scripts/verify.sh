#!/usr/bin/env bash
# Ported from riusprime/deathventory@1d697803:scripts/verify.sh.
# Changes: import first and fail on import errors; --fixed-fps 60; JUnit output; the same GUT log guards as CI.
# Usage: bash scripts/verify.sh [res://tests/<folder>]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:-res://tests}"
cd "$REPO_ROOT"
mkdir -p build

godot --headless --path . --editor --import --quit > build/import.log 2>&1 || true
if sed -E 's/\x1B\[[0-9;]*[mK]//g' build/import.log | grep -E -q "^(ERROR|SCRIPT ERROR)"; then
	sed -E 's/\x1B\[[0-9;]*[mK]//g' build/import.log | grep -E "^(ERROR|SCRIPT ERROR)" | head -10 >&2
	echo "verify: import reported errors" >&2
	exit 1
fi

set +e
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir="$TARGET_DIR" -ginclude_subdirs \
	-gjunit_xml_file=build/gut.xml -gexit 2>&1 | tee build/gut.log
GUT_EXIT=${PIPESTATUS[0]}
set -e
[[ $GUT_EXIT -eq 0 ]] || { echo "verify: GUT exited $GUT_EXIT" >&2; exit "$GUT_EXIT"; }

if [[ "$TARGET_DIR" == "res://tests" ]]; then
	bash scripts/ci/check_gut_log.sh build/gut.log
else
	bash scripts/ci/check_gut_log.sh build/gut.log <(echo 1)
fi
