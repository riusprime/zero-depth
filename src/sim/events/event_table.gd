class_name EventTable
extends RefCounted
## One event's compiled numbers (v0.5.0 EV; EventCompiler from EventDefinition). The choices are parallel arrays in
## the data's order: their label key, cost (Events.Cost) and its amount (per mille of max HP for hp and max_hp,
## shards per floor, enemies for a fight, ticks for a defence), reward (Events.Reward) and its amount (per mille of
## Overclock damage, shards per floor), and curse (-1 none, Events.CURSE_RANDOM, or a curse index).

var id := &""
var name_key := &""
var desc_key := &""
var weight := 0
var min_floor := 1
## Events.Need.
var requires := 0
var labels: Array[StringName] = []
var cost := PackedInt32Array()
var cost_amount := PackedInt32Array()
var reward := PackedInt32Array()
var reward_amount := PackedInt32Array()
var curse := PackedInt32Array()


func choice_count() -> int:
	return cost.size()
