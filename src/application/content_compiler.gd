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


## An enemy's numbers in sim units. The behaviour id picks the actor kind.
static func compile_enemy(def: EnemyDefinition) -> EnemyTable:
	var t := EnemyTable.new()
	t.kind = {
		&"charger": ActorStore.Kind.CHARGER,
		&"warden": ActorStore.Kind.WARDEN,
		&"needle": ActorStore.Kind.NEEDLE,
	}[def.behaviour_id]
	t.hp = def.hp
	t.radius_m = def.radius_m
	t.speed = def.move_speed_mps / SimTick.TICKS_PER_SECOND
	var bp := def.behaviour_params
	t.attack_range_m = bp["attack_range_m"]
	t.cooldown_ticks = SimTick.seconds_to_ticks(bp["cooldown_seconds"])
	var atk := def.attacks[0]
	var sp := atk.shape_params
	t.windup_ticks = SimTick.seconds_to_ticks(atk.telegraph_seconds)
	t.active_ticks = maxi(1, SimTick.seconds_to_ticks(atk.active_seconds))
	t.recover_ticks = SimTick.seconds_to_ticks(atk.recovery_seconds)
	t.damage = atk.damage
	match def.behaviour_id:
		&"charger":
			t.charge_speed = float(sp["speed_mps"]) / SimTick.TICKS_PER_SECOND
			t.charge_distance_m = sp["length_m"]
		&"warden":
			t.shield_half_arc = degrees_to_units(float(bp["shield_arc_degrees"]) * 0.5)
			t.turn_rate = maxi(
				1, degrees_to_units(float(bp["turn_rate_dps"]) / SimTick.TICKS_PER_SECOND)
			)
			t.slam_radius_m = sp["radius_m"]
		&"needle":
			t.keep_distance_m = bp["keep_distance_m"]
			t.flee_distance_m = bp["flee_distance_m"]
			t.burst_count = int(sp["count"])
			t.burst_gap_ticks = maxi(1, SimTick.seconds_to_ticks(sp["gap_seconds"]))
			t.bolt_speed = float(sp["speed_mps"]) / SimTick.TICKS_PER_SECOND
			t.bolt_radius_m = sp["radius_m"]
			t.bolt_life_ticks = SimTick.seconds_to_ticks(
				float(sp["range_m"]) / float(sp["speed_mps"])
			)
	return t


## Every enemy in a repository, compiled.
static func compile_enemies(repo: ContentRepository) -> Array[EnemyTable]:
	var out: Array[EnemyTable] = []
	for def: EnemyDefinition in repo.all_of(&"enemies"):
		out.append(compile_enemy(def))
	return out


## The chosen utility, applied to a compiled player table (PD-01: one, chosen before the run).
static func apply_utility(t: PlayerTable, def: UtilityDefinition) -> PlayerTable:
	if def == null:
		t.utility = PlayerTable.Utility.NONE
		return t
	match def.kind:
		UtilityDefinition.Kind.GUARD:
			t.utility = PlayerTable.Utility.GUARD
			t.guard_half_arc = degrees_to_units(def.guard_arc_degrees * 0.5)
			t.guard_mult_permille = int(round(def.guard_multiplier * 1000.0))
			t.guard_move_permille = int(round(def.guard_move_multiplier * 1000.0))
		UtilityDefinition.Kind.BLINK:
			t.utility = PlayerTable.Utility.BLINK
			t.blink_range_m = def.blink_range_m
			t.blink_cooldown_ticks = SimTick.seconds_to_ticks(def.blink_cooldown_seconds)
			t.blink_iframe_ticks = SimTick.seconds_to_ticks(def.blink_iframes_seconds)
	return t


## Degrees to 1/4096 turns, rounded.
static func degrees_to_units(deg: float) -> int:
	return int(round(deg * SimTick.ANGLE_UNITS / 360.0))
