#!/usr/bin/env bash
# Every look of the given biomes (default: red_canyon frozen_shore starfall), one Godot process per cell, then the
# contact sheet per biome. Needs a renderer; runs off screen. GODOT: the Godot binary (default `godot`).
set -e
GODOT="${GODOT:-godot}"
biomes=("$@")
[ ${#biomes[@]} -eq 0 ] && biomes=(red_canyon frozen_shore starfall)
for b in "${biomes[@]}"; do
	for l in now a b c; do
		"$GODOT" --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000 \
			-s scripts/shots/enemy_looks.gd -- biome="$b" look="$l"
	done
	"$GODOT" --headless --path . -s scripts/shots/enemy_looks_sheet.gd -- biome="$b"
done
