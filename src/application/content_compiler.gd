class_name ContentCompiler
extends RefCounted
## Turns definitions into the sim's plain tables, converting seconds to ticks once (CONTENT_SCHEMA §9).
## In v0.0.1 it compiles only the player.


static func compile_player(def: PlayerDefinition) -> PlayerTable:
	var t := PlayerTable.new()
	t.hp = def.hp
	t.radius_m = def.radius_m
	t.move_speed = def.move_speed_mps / SimTick.TICKS_PER_SECOND
	t.dash_distance_m = def.dash.distance_m
	t.dash_ticks = maxi(1, SimTick.seconds_to_ticks(def.dash.duration_seconds))
	t.dash_cooldown_ticks = SimTick.seconds_to_ticks(def.dash.cooldown_seconds)
	t.dash_iframe_ticks = SimTick.seconds_to_ticks(def.dash.iframes_seconds)
	return t
