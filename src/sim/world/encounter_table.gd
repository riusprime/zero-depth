class_name EncounterTable
extends RefCounted
## A compiled encounter: per wave, the enemy kinds to spawn (counts expanded) and the delay before it arrives.

var waves: Array = []
var delays := PackedInt32Array()
var min_spawn_distance_m := 6.0
