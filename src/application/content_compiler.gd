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
	t.hurt_iframe_ticks = SimTick.seconds_to_ticks(def.hurt_iframes_seconds)
	t.hurt_freeze_ticks = SimTick.seconds_to_ticks(def.hurt_hitstop_seconds)
	var p := def.primary
	t.swing_ticks = maxi(1, SimTick.seconds_to_ticks(p.swing_duration_seconds))
	t.swing_active_tick = maxi(1, SimTick.seconds_to_ticks(p.swing_active_seconds))
	t.swing_reach_m = p.swing_reach_m
	t.swing_half_arc = degrees_to_units(p.swing_arc_degrees * 0.5)
	t.swing_damage = p.swing_damage.duplicate()
	t.combo_window_ticks = SimTick.seconds_to_ticks(p.combo_window_seconds)
	t.swing_hitstop_ticks = SimTick.seconds_to_ticks(p.swing_hitstop_seconds)
	t.charge_start_ticks = SimTick.seconds_to_ticks(p.charge_start_seconds)
	t.charge_full_ticks = SimTick.seconds_to_ticks(p.charge_full_seconds)
	t.charge_move_permille = int(round(p.charge_move_multiplier * 1000.0))
	t.bolt_min_damage = p.bolt_min_damage
	t.bolt_max_damage = p.bolt_max_damage
	t.bolt_speed = p.bolt_speed_mps / SimTick.TICKS_PER_SECOND
	t.bolt_radius_m = p.bolt_radius_m
	t.bolt_life_ticks = SimTick.seconds_to_ticks(p.bolt_life_seconds)
	t.bolt_full_hitstop_ticks = SimTick.seconds_to_ticks(p.bolt_full_hitstop_seconds)
	return t


## Degrees to 1/4096 turns, rounded.
static func degrees_to_units(deg: float) -> int:
	return int(round(deg * SimTick.ANGLE_UNITS / 360.0))
