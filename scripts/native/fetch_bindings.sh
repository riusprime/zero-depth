#!/usr/bin/env bash
# Fetches godot-cpp (the C++ bindings) at the one commit native/GODOT_CPP_COMMIT names, into native/godot-cpp/
# (git-ignored). Not a submodule: the project works in many git worktrees, and a submodule must be initialised in
# each one by hand; a plain folder that the build fetches by itself has no such step to forget.
# Usage: bash scripts/native/fetch_bindings.sh       (a no-op when the folder is already at the pinned commit)
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHA="$(tr -d '[:space:]' < "$REPO_ROOT/native/GODOT_CPP_COMMIT")"
DEST="$REPO_ROOT/native/godot-cpp"
URL="https://github.com/godotengine/godot-cpp.git"

if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
	echo "fetch_bindings: native/GODOT_CPP_COMMIT is not a full commit SHA: '$SHA'" >&2
	exit 1
fi
if [[ -d "$DEST/.git" ]] && [[ "$(git -C "$DEST" rev-parse HEAD 2>/dev/null)" == "$SHA" ]]; then
	exit 0
fi

echo "fetch_bindings: godot-cpp $SHA -> native/godot-cpp"
mkdir -p "$DEST"
if [[ ! -d "$DEST/.git" ]]; then
	git -C "$DEST" init -q
	git -C "$DEST" remote add origin "$URL"
fi
git -C "$DEST" fetch -q --depth 1 origin "$SHA"
git -C "$DEST" checkout -q --force FETCH_HEAD
# Godot must not scan the bindings: their test project holds a .gdextension of its own
touch "$DEST/.gdignore"
[[ "$(git -C "$DEST" rev-parse HEAD)" == "$SHA" ]] || { echo "fetch_bindings: checkout is not $SHA" >&2; exit 1; }
