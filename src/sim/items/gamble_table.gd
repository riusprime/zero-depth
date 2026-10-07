class_name GambleTable
extends RefCounted
## The gamble shrine's compiled rules (v0.3.0 L19), built from GambleDefinition by ContentCompiler.compile_gamble.
## The defaults equal the data's starting values, so a world built without content still has a sane shrine.
## Per stat (index = Stat): what one win adds (`amount`: HP for MAX_HP, per mille for every other stat; REGEN is per
## mille of max HP per second), its draw weight and its cap in wins.

enum Stat { MAX_HP, MELEE, SHOT, MOVE, DASH_CD, REGEN, HEAT, SHARDS }

const STAT_COUNT := 8
## The data's stat names, in Stat order.
const STAT_IDS: Array[StringName] = [
	&"max_hp",
	&"melee_damage",
	&"shot_damage",
	&"move_speed",
	&"dash_cooldown",
	&"regen",
	&"heat_capacity",
	&"shard_gain",
]

var base_price := 25
var price_step_permille := 500
var floor_price_step_permille := 500
var interact_radius_m := 1.8
var spot_distance_m := 2.6
var clear_radius_m := 0.9
## Per Stat; a stat missing from the data has weight 0 (never drawn).
var amount := PackedInt32Array([8, 60, 60, 40, 60, 5, 80, 50])
var weight := PackedInt32Array([3, 3, 3, 2, 2, 2, 2, 2])
var cap := PackedInt32Array([6, 5, 5, 4, 4, 4, 4, 4])


## The price of the next use after `uses` uses on floor `floor_index` (1-based), integer math: the floor's base
## (raised like the chests), then × (1 + step) per use, rounded half up each time.
func price(uses: int, floor_index: int) -> int:
	var p := base_price * (1000 + floor_price_step_permille * maxi(0, floor_index - 1)) / 1000
	for k in uses:
		p = (p * (1000 + price_step_permille) + 500) / 1000
	return maxi(1, p)
