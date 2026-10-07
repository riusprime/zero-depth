class_name GambleStatEntry
extends Resource
## One line of the gamble shrine's pool (v0.3.0 L19): a stat, how much one win adds, its draw weight, and how many
## wins it can take (its cap). Units: max_hp in HP; regen in % of max HP per second; every other stat in %.

## The stats the sim knows (GambleTable.Stat, same order).
const STATS: Array[StringName] = [
	&"max_hp",
	&"melee_damage",
	&"shot_damage",
	&"move_speed",
	&"dash_cooldown",
	&"regen",
	&"heat_capacity",
	&"shard_gain",
]

@export var stat: StringName
@export var amount := 1.0
@export var weight := 1
@export var max_stacks := 1
