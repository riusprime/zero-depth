class_name ContentCompiler
extends RefCounted
## Turns definitions into the sim's plain tables, converting seconds to ticks once (CONTENT_SCHEMA §9).
## In v0.0.1 it compiles only the player.


static func compile_player(def: PlayerDefinition) -> PlayerTable:
	var t := PlayerTable.new()
	t.hp = def.hp
	t.radius_m = def.radius_m
	t.move_speed = def.move_speed_mps / SimTick.TICKS_PER_SECOND
	t.accel_permille = ease_permille(def.accel_seconds)
	t.decel_permille = ease_permille(def.stop_seconds)
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
	t.shot_period_ticks = maxi(1, SimTick.seconds_to_ticks(p.shot_period_seconds))
	t.bolt_damage = p.bolt_damage
	t.bolt_speed = p.bolt_speed_mps / SimTick.TICKS_PER_SECOND
	t.bolt_radius_m = p.bolt_radius_m
	t.bolt_life_ticks = SimTick.seconds_to_ticks(p.bolt_life_seconds)
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
			t.front_half_arc = degrees_to_units(float(bp["front_arc_degrees"]) * 0.5)
			t.front_mult_permille = int(bp["front_mult_permille"])
			t.rear_half_arc = degrees_to_units(float(bp["rear_arc_degrees"]) * 0.5)
			t.rear_mult_permille = int(bp["rear_mult_permille"])
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


## An encounter, its enemy ids resolved to actor kinds through their behaviours.
static func compile_encounter(def: EncounterDefinition, repo: ContentRepository) -> EncounterTable:
	var t := EncounterTable.new()
	t.min_spawn_distance_m = def.min_spawn_distance_m
	for wv in def.waves:
		var kinds: Array[int] = []
		for s in wv.spawns:
			var e: EnemyDefinition = repo.get_def(&"enemies", s.enemy_id)
			var kind := compile_enemy(e).kind
			for n in s.count:
				kinds.append(kind)
		t.waves.append(kinds)
		t.delays.append(SimTick.seconds_to_ticks(wv.delay_seconds))
	return t


## A spawn director in ticks and per mille, its enemy ids resolved to actor kinds through their behaviours.
static func compile_spawning(def: SpawnDirectorDefinition, repo: ContentRepository) -> SpawnTable:
	var t := SpawnTable.new()
	t.tier_ticks = maxi(1, SimTick.seconds_to_ticks(def.tier_seconds))
	t.cap_base = def.cap_base
	t.cap_per_tier = def.cap_per_tier
	t.cap_max = def.cap_max
	t.interval_start_ticks = maxi(1, SimTick.seconds_to_ticks(def.interval_start_seconds))
	t.interval_step_ticks = SimTick.seconds_to_ticks(def.interval_step_seconds)
	t.interval_min_ticks = maxi(1, SimTick.seconds_to_ticks(def.interval_min_seconds))
	t.hp_per_tier_permille = int(round(def.hp_scale_per_tier * 1000.0))
	t.min_distance_m = def.min_distance_m
	for e in def.mix:
		var enemy: EnemyDefinition = repo.get_def(&"enemies", e.enemy_id)
		t.kinds.append(compile_enemy(enemy).kind)
		t.weights.append(e.weight)
		t.unlock_tiers.append(e.unlock_tier)
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


## The per-tick share of the gap that closes 90% of it in `seconds` (exponential easing), in per mille.
static func ease_permille(seconds: float) -> int:
	var ticks := maxi(1, SimTick.seconds_to_ticks(seconds))
	return int(round((1.0 - pow(0.1, 1.0 / ticks)) * 1000.0))


## Degrees to 1/4096 turns, rounded.
static func degrees_to_units(deg: float) -> int:
	return int(round(deg * SimTick.ANGLE_UNITS / 360.0))


## One item's numbers in sim units (v0.2.0 E). The definition's kind maps to the sim kind by name.
static func compile_item(def: ItemDefinition) -> ItemTable:
	var t := ItemTable.new()
	t.id = def.id
	t.kind = {
		ItemDefinition.Kind.LONG_EDGE: ItemTable.Kind.LONG_EDGE,
		ItemDefinition.Kind.TWIN_ARC: ItemTable.Kind.TWIN_ARC,
		ItemDefinition.Kind.EMBER_EDGE: ItemTable.Kind.EMBER_EDGE,
		ItemDefinition.Kind.SPLINTER_SHOT: ItemTable.Kind.SPLINTER_SHOT,
		ItemDefinition.Kind.RAPID_COIL: ItemTable.Kind.RAPID_COIL,
		ItemDefinition.Kind.RICOCHET_CORE: ItemTable.Kind.RICOCHET_CORE,
		ItemDefinition.Kind.KINETIC_DASH: ItemTable.Kind.KINETIC_DASH,
		ItemDefinition.Kind.OVERCHARGE: ItemTable.Kind.OVERCHARGE,
		ItemDefinition.Kind.VAMPIRIC_CORE: ItemTable.Kind.VAMPIRIC_CORE,
		ItemDefinition.Kind.STATIC_CHAIN: ItemTable.Kind.STATIC_CHAIN,
		ItemDefinition.Kind.MOMENTUM: ItemTable.Kind.MOMENTUM,
		ItemDefinition.Kind.FROST_CORE: ItemTable.Kind.FROST_CORE,
		ItemDefinition.Kind.THORN_MANTLE: ItemTable.Kind.THORN_MANTLE,
		ItemDefinition.Kind.EXECUTIONER: ItemTable.Kind.EXECUTIONER,
		ItemDefinition.Kind.SWIFT_FEET: ItemTable.Kind.SWIFT_FEET,
		ItemDefinition.Kind.PHASE_STRIKE: ItemTable.Kind.PHASE_STRIKE,
	}[def.kind]
	t.name_key = def.name_key
	t.desc_key = def.desc_key
	t.reach_bonus_permille = def.reach_bonus_permille
	t.echo_delay_ticks = SimTick.seconds_to_ticks(def.echo_delay_seconds)
	t.echo_damage_permille = def.echo_damage_permille
	t.burn_damage = def.burn_damage
	t.burn_period_ticks = maxi(1, SimTick.seconds_to_ticks(def.burn_period_seconds))
	t.burn_duration_ticks = SimTick.seconds_to_ticks(def.burn_duration_seconds)
	t.burn_max_stacks = def.burn_max_stacks
	t.split_count = def.split_count
	t.split_spread = degrees_to_units(def.split_spread_degrees)
	t.split_damage_permille = def.split_damage_permille
	t.fire_rate_bonus_permille = def.fire_rate_bonus_permille
	t.bounces = def.bounces
	t.dash_hit_damage = def.dash_hit_damage
	t.overcharge_every = def.overcharge_every
	t.overcharge_mult_permille = def.overcharge_mult_permille
	t.shockwave_radius_m = def.shockwave_radius_m
	t.shockwave_damage_permille = def.shockwave_damage_permille
	_compile_item_v2(def, t)
	return t


## The second eight items (v0.2.0 J).
static func _compile_item_v2(def: ItemDefinition, t: ItemTable) -> void:
	t.heal_per_kill = def.heal_per_kill
	t.heal_cap = def.heal_cap
	t.heal_window_ticks = SimTick.seconds_to_ticks(def.heal_window_seconds)
	t.chain_every = def.chain_every
	t.chain_range_m = def.chain_range_m
	t.chain_damage = def.chain_damage
	t.momentum_window_ticks = SimTick.seconds_to_ticks(def.momentum_window_seconds)
	t.momentum_bonus_permille = def.momentum_bonus_permille
	t.slow_permille = def.slow_permille if def.slow_permille > 0 else 1000
	t.slow_ticks = SimTick.seconds_to_ticks(def.slow_seconds)
	t.thorn_bolts = def.thorn_bolts
	t.thorn_damage = def.thorn_damage
	t.execute_threshold_permille = def.execute_threshold_permille
	t.execute_bonus_permille = def.execute_bonus_permille
	t.move_speed_bonus_permille = def.move_speed_bonus_permille
	t.dash_cooldown_cut_permille = def.dash_cooldown_cut_permille
	t.phase_damage = def.phase_damage
	t.phase_radius_m = def.phase_radius_m
	t.phase_guard_window_ticks = SimTick.seconds_to_ticks(def.phase_guard_window_seconds)


## Every item in a repository, compiled, in id order (the order of item indices). Give it to the world with
## World.set_item_tables.
static func compile_items(repo: ContentRepository) -> Array[ItemTable]:
	var out: Array[ItemTable] = []
	for def: ItemDefinition in repo.all_of(&"items"):
		out.append(compile_item(def))
	return out


## A run's floors, biome count and scaling in per mille (v0.3.0 B).
static func compile_run(def: RunDefinition) -> RunTable:
	var t := RunTable.new()
	t.floors = def.floors
	t.biome_count = def.biomes.size()
	t.hp_per_floor_permille = int(round(def.enemy_hp_per_floor * 1000.0))
	t.damage_per_floor_permille = int(round(def.enemy_damage_per_floor * 1000.0))
	t.heal_permille = int(round(def.heal_between_floors * 1000.0))
	return t
