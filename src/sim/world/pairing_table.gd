class_name PairingTable
extends RefCounted
## The compiled enemy pairings (v0.10.5 O15; PairingSetDefinition by ContentCompiler): parallel arrays, one row per
## duo, kinds as actor kinds. Loadout: hangs on the floor's SpawnTable (SpawnTable.pairings; null = off).

enum Place { BEHIND, FAR_SIDE, FLANKING, IN_FRONT, ABOVE_BEHIND }

var lead := PackedInt32Array()
var partner := PackedInt32Array()
var from_floor := PackedInt32Array()
var chance := PackedInt32Array()
var count := PackedInt32Array()
var placement := PackedInt32Array()
var name_keys: Array[StringName] = []


func size() -> int:
	return lead.size()
