class_name RunTable
extends RefCounted
## A run's compiled numbers (RunDefinition, v0.3.0 B): floors, the biome count (the ids stay in the app) and the
## per-mille scaling. Starting values: 3 floors; normal enemies' HP and damage per floor from per-mille tables
## (v0.4.0 SC: 1.9^(f − 1), 1.4^(f − 1)); bosses' HP +400 and damage +200 per mille per floor after the first; heal
## 400 per mille of max HP between floors.

var floors := 3
var biome_count := 1
var enemy_hp_floor_permille := PackedInt32Array([1000, 1900, 3610])
var enemy_damage_floor_permille := PackedInt32Array([1000, 1400, 1960])
var boss_hp_per_floor_permille := 400
var boss_damage_per_floor_permille := 200
var heal_permille := 400


static func starting_values() -> RunTable:
	return RunTable.new()
