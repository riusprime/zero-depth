class_name RunTable
extends RefCounted
## A run's compiled numbers (RunDefinition, v0.3.0 B): floors, the biome count (the ids stay in the app) and the
## per-mille scaling. Starting values: 3 floors, enemy HP +400 and damage +200 per mille per floor after the first,
## heal 400 per mille of max HP between floors.

var floors := 3
var biome_count := 1
var hp_per_floor_permille := 400
var damage_per_floor_permille := 200
var heal_permille := 400


static func starting_values() -> RunTable:
	return RunTable.new()
