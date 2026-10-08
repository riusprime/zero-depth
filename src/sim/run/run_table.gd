class_name RunTable
extends RefCounted
## A run's compiled numbers (RunDefinition, v0.3.0 B): floors, the biome count (the ids stay in the app) and the
## per-mille scaling. Starting values: 3 floors; normal enemies' HP and damage per floor from per-mille tables
## (v0.4.0 SC: 1.9^(f − 1), 1.4^(f − 1)); bosses' HP +400 and damage +200 per mille per floor after the first; heal
## 400 per mille of max HP between floors; Deep floors ×1.25 and one extra chest (v0.5.0 RT).

var floors := 3
var biome_count := 1
var enemy_hp_floor_permille := PackedInt32Array([1000, 1900, 3610])
var enemy_damage_floor_permille := PackedInt32Array([1000, 1400, 1960])
var boss_hp_per_floor_permille := 400
var boss_damage_per_floor_permille := 200
var heal_permille := 400
## v0.5.0 RT: a Deep floor's extra scaling (per mille, on top of the floor's) and extra chests.
var deep_scale_permille := 1250
var deep_extra_chests := 1
## v0.4.0 TU (owner D9): per floor, the boss's HP and damage per mille and the HP restored when its room seals.
var boss_ease_floor_permille := PackedInt32Array([1000])
var boss_room_heal_floor_permille := PackedInt32Array([0])


static func starting_values() -> RunTable:
	return RunTable.new()
