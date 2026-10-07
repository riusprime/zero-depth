class_name ContentCompiler
extends RefCounted
## Turns definitions into the sim's plain tables, converting seconds to ticks once (CONTENT_SCHEMA §9).
## In v0.0.1 it compiles only the player.

## Bosses (v0.3.0 C): boss ids to actor kinds, move names to BossAttackTable moves.
const BOSS_KINDS := {
	&"gatekeeper": ActorStore.Kind.GATEKEEPER,
	&"brood_mother": ActorStore.Kind.BROOD_MOTHER,
	&"siege_engine": ActorStore.Kind.SIEGE_ENGINE,
	&"warlord": ActorStore.Kind.WARLORD,
	&"hive_lens": ActorStore.Kind.HIVE_LENS,
	&"foundry": ActorStore.Kind.FOUNDRY,
}
const BOSS_MOVES := {
	&"slam_ring": BossAttackTable.Move.SLAM_RING,
	&"lanes": BossAttackTable.Move.LANES,
	&"sweep": BossAttackTable.Move.SWEEP,
	&"charge": BossAttackTable.Move.CHARGE,
	&"leap": BossAttackTable.Move.LEAP,
	&"burrow": BossAttackTable.Move.BURROW,
	&"brood": BossAttackTable.Move.BROOD,
	&"barrage": BossAttackTable.Move.BARRAGE,
	&"rail": BossAttackTable.Move.RAIL,
	&"bolt_fan": BossAttackTable.Move.BOLT_FAN,
	&"deploy": BossAttackTable.Move.DEPLOY,
	&"pull": BossAttackTable.Move.PULL,
	&"flood": BossAttackTable.Move.FLOOD,
}


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
	t.regen_delay_ticks = SimTick.seconds_to_ticks(def.regen_delay_seconds)
	t.regen_permille = def.regen_permille_per_second
	t.crit_chance_permille = int(round(def.crit_chance * 1000.0))  # v0.4.0 BS
	t.crit_mult_permille = int(round(def.crit_damage * 1000.0))
	var p := def.primary
	var combo: Array[SwingStep] = []
	for sd in p.combo:
		combo.append(compile_swing_step(sd))
	t.combo = combo
	t.combo_window_ticks = SimTick.seconds_to_ticks(p.combo_window_seconds)
	t.shot_period_ticks = maxi(1, SimTick.seconds_to_ticks(p.shot_period_seconds))
	t.bolt_damage = p.bolt_damage
	t.bolt_speed = p.bolt_speed_mps / SimTick.TICKS_PER_SECOND
	t.bolt_radius_m = p.bolt_radius_m
	t.bolt_life_ticks = SimTick.seconds_to_ticks(p.bolt_life_seconds)
	return t


## One melee combo step in sim units (v0.3.0 L11). The hit comes at least one tick after the swing starts.
static func compile_swing_step(sd: SwingStepDefinition) -> SwingStep:
	return SwingStep.make(
		sd.motion as SwingStep.Motion,
		maxi(1, SimTick.seconds_to_ticks(sd.active_seconds)),
		SimTick.seconds_to_ticks(sd.recovery_seconds),
		mini(degrees_to_units(sd.arc_degrees * 0.5), SimTick.ANGLE_UNITS / 2),
		sd.reach_m,
		sd.damage,
		SimTick.seconds_to_ticks(sd.hitstop_seconds),
		sd.lunge_m,
		maxi(1, SimTick.seconds_to_ticks(sd.sweep_seconds))
	)


## An enemy's numbers in sim units. The behaviour id picks the actor kind.
static func compile_enemy(def: EnemyDefinition) -> EnemyTable:
	var t := EnemyTable.new()
	t.kind = {
		&"charger": ActorStore.Kind.CHARGER,
		&"warden": ActorStore.Kind.WARDEN,
		&"needle": ActorStore.Kind.NEEDLE,
		&"hatchling": ActorStore.Kind.HATCHLING,
		&"arc_caster": ActorStore.Kind.ARC_CASTER,
		&"bomb_drone": ActorStore.Kind.BOMB_DRONE,
		&"swarmer": ActorStore.Kind.SWARMER,
		&"splitter": ActorStore.Kind.SPLITTER,
		&"splitling": ActorStore.Kind.SPLITLING,
		&"shield_bearer": ActorStore.Kind.SHIELD_BEARER,
		&"mender": ActorStore.Kind.MENDER,
		&"mine_layer": ActorStore.Kind.MINE_LAYER,
		&"sniper": ActorStore.Kind.SNIPER,
		&"lens_drone": ActorStore.Kind.LENS_DRONE,
	}[def.behaviour_id]
	t.name_key = def.name_key
	t.hp = def.hp
	t.radius_m = def.radius_m
	t.speed = def.move_speed_mps / SimTick.TICKS_PER_SECOND
	var bp := def.behaviour_params
	t.shards = def.shards
	t.shards_by_floor = def.shards_by_floor
	if def.attacks.is_empty():  # v0.4.0 EN: the Mender has no attack.
		_compile_horde(def, t, {})
		return t
	t.attack_range_m = bp["attack_range_m"]
	t.cooldown_ticks = SimTick.seconds_to_ticks(bp["cooldown_seconds"])
	var atk := def.attacks[0]
	var sp := atk.shape_params
	t.windup_ticks = SimTick.seconds_to_ticks(atk.telegraph_seconds)
	t.windup_max_ticks = maxi(t.windup_ticks, SimTick.seconds_to_ticks(atk.telegraph_max_seconds))
	t.active_ticks = maxi(1, SimTick.seconds_to_ticks(atk.active_seconds))
	t.recover_ticks = SimTick.seconds_to_ticks(atk.recovery_seconds)
	t.damage = atk.damage
	match def.behaviour_id:
		&"charger", &"hatchling", &"swarmer":
			t.charge_speed = float(sp["speed_mps"]) / SimTick.TICKS_PER_SECOND
			t.charge_distance_m = sp["length_m"]
			t.charge_turn = degrees_to_units(
				float(bp["charge_turn_dps"]) / SimTick.TICKS_PER_SECOND
			)
		&"warden":
			t.front_half_arc = degrees_to_units(float(bp["front_arc_degrees"]) * 0.5)
			t.front_mult_permille = int(bp["front_mult_permille"])
			t.rear_half_arc = degrees_to_units(float(bp["rear_arc_degrees"]) * 0.5)
			t.rear_mult_permille = int(bp["rear_mult_permille"])
			t.turn_rate = maxi(
				1, degrees_to_units(float(bp["turn_rate_dps"]) / SimTick.TICKS_PER_SECOND)
			)
			t.slam_radius_m = sp["radius_m"]
		&"needle", &"lens_drone":
			t.keep_distance_m = bp["keep_distance_m"]
			t.flee_distance_m = bp["flee_distance_m"]
			t.burst_count = int(sp["count"])
			t.burst_gap_ticks = maxi(1, SimTick.seconds_to_ticks(sp["gap_seconds"]))
			t.bolt_speed = float(sp["speed_mps"]) / SimTick.TICKS_PER_SECOND
			t.bolt_radius_m = sp["radius_m"]
			t.bolt_life_ticks = SimTick.seconds_to_ticks(
				float(sp["range_m"]) / float(sp["speed_mps"])
			)
			t.burst_spread = degrees_to_units(float(sp["spread_degrees"]))
		&"arc_caster":
			_compile_arc_caster(def, t)
		&"bomb_drone":
			t.keep_min_m = bp["keep_min_m"]
			t.keep_distance_m = bp["keep_max_m"]
			t.slam_radius_m = sp["radius_m"]
		_:
			_compile_horde(def, t, sp)
	return t


## The horde kinds (v0.4.0 EN): the numbers each one adds, from its params and its attack's shape params.
static func _compile_horde(def: EnemyDefinition, t: EnemyTable, sp: Dictionary) -> void:
	var bp := def.behaviour_params
	if bp.has("keep_min_m"):
		t.keep_min_m = bp["keep_min_m"]
		t.keep_distance_m = bp["keep_max_m"]
	match def.behaviour_id:
		&"splitter", &"splitling":
			t.slam_radius_m = sp["radius_m"]
			t.reach_m = sp["reach_m"]
			t.split_count = int(bp.get("split_count", 0))
		&"shield_bearer":
			t.front_half_arc = degrees_to_units(float(bp["shield_arc_degrees"]) * 0.5)
			t.front_mult_permille = 0
			t.turn_rate = maxi(
				1, degrees_to_units(float(bp["turn_rate_dps"]) / SimTick.TICKS_PER_SECOND)
			)
			t.reach_m = sp["length_m"]
			t.lane_half_m = sp["half_width_m"]
		&"mender":
			t.heal_amount = int(bp["heal_amount"])
			t.heal_period_ticks = maxi(1, SimTick.seconds_to_ticks(bp["heal_period_seconds"]))
			t.heal_range_m = bp["heal_range_m"]
		&"mine_layer":
			t.slam_radius_m = sp["radius_m"]
			t.fuse_ticks = t.windup_ticks
			t.windup_ticks = maxi(1, SimTick.seconds_to_ticks(bp["drop_seconds"]))
			t.windup_max_ticks = t.windup_ticks
			t.max_mines = int(bp["max_mines"])
			t.mine_life_ticks = SimTick.seconds_to_ticks(bp["mine_life_seconds"])
		&"sniper":
			t.reach_m = sp["range_m"]
			t.lane_half_m = sp["half_width_m"]


## The Arc Caster (v0.3.5 AI): its three spells, in the schema's order (bolt, spread, rune).
static func _compile_arc_caster(def: EnemyDefinition, t: EnemyTable) -> void:
	var bp := def.behaviour_params
	t.keep_min_m = bp["keep_min_m"]
	t.keep_distance_m = bp["keep_max_m"]
	t.spell_weights = PackedInt32Array(
		[int(bp["bolt_weight"]), int(bp["spread_weight"]), int(bp["rune_weight"])]
	)
	var bolt := def.attacks[0].shape_params
	t.burst_count = 1
	t.bolt_speed = float(bolt["speed_mps"]) / SimTick.TICKS_PER_SECOND
	t.bolt_radius_m = bolt["radius_m"]
	t.bolt_life_ticks = SimTick.seconds_to_ticks(float(bolt["range_m"]) / float(bolt["speed_mps"]))
	var spread := def.attacks[1].shape_params
	t.spread_count = int(spread["count"])
	t.spread_angle = degrees_to_units(float(spread["spread_degrees"]))
	t.spread_speed = float(spread["speed_mps"]) / SimTick.TICKS_PER_SECOND
	t.spread_radius_m = spread["radius_m"]
	t.spread_life_ticks = SimTick.seconds_to_ticks(
		float(spread["range_m"]) / float(spread["speed_mps"])
	)
	t.rune_radius_m = def.attacks[2].shape_params["radius_m"]
	t.rune_windup_ticks = SimTick.seconds_to_ticks(def.attacks[2].telegraph_seconds)


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
	t.cap_by_floor = def.cap_by_floor.duplicate()
	t.cap_per_tier = def.cap_per_tier
	t.cap_max = def.cap_max
	t.interval_start_ticks = maxi(1, SimTick.seconds_to_ticks(def.interval_start_seconds))
	t.interval_min_ticks = maxi(1, SimTick.seconds_to_ticks(def.interval_min_seconds))
	t.interval_tier_permille = def.interval_tier_permille.duplicate()
	t.hp_tier_permille = def.hp_tier_permille.duplicate()
	t.damage_tier_permille = def.damage_tier_permille.duplicate()
	t.pack_min_by_floor = def.pack_min_by_floor.duplicate()
	t.pack_max_by_floor = def.pack_max_by_floor.duplicate()
	t.min_distance_m = def.min_distance_m
	t.edge_band_m = def.edge_band_m
	for e in def.mix:
		var enemy: EnemyDefinition = repo.get_def(&"enemies", e.enemy_id)
		t.kinds.append(compile_enemy(enemy).kind)
		t.weights.append(e.weight)
		t.unlock_tiers.append(e.unlock_tier)
		t.packs.append(e.pack)
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


## The chosen build, applied to a compiled player table (v0.3.0 L15, L16): only its weapon is enabled, and that
## weapon's damage takes the build's per mille. null keeps both weapons at full damage (the pre-build default).
static func apply_build(t: PlayerTable, def: BuildDefinition) -> PlayerTable:
	if def == null:
		return t
	match def.weapon:
		BuildDefinition.Weapon.BLADE:
			t.weapons = PlayerTable.WEAPON_BLADE
			t.melee_damage_permille = def.damage_permille
		BuildDefinition.Weapon.GUN:
			t.weapons = PlayerTable.WEAPON_GUN
			t.bolt_damage_permille = def.damage_permille
	t.skill = compile_skill(def.skill)  # v0.3.5 K: the build's second ability.
	return t


## A build's skill in sim units (v0.3.5 K); null stays null (no Skill button).
static func compile_skill(def: SkillDefinition) -> SkillTable:
	if def == null:
		return null
	var t := SkillTable.new()
	t.kind = def.kind as SkillTable.Kind
	t.cooldown_ticks = SimTick.seconds_to_ticks(def.cooldown_seconds)
	t.damage = def.damage
	t.heat_gain = int(round(def.heat * HeatTable.MILLI))
	t.lunge_m = def.lunge_m
	t.lunge_ticks = maxi(1, SimTick.seconds_to_ticks(def.lunge_seconds))
	t.half_arc = degrees_to_units(def.arc_degrees * 0.5)
	t.reach_m = def.reach_m
	t.hitstop_ticks = SimTick.seconds_to_ticks(def.hitstop_seconds)
	t.pellets = def.pellets
	t.half_cone = degrees_to_units(def.cone_degrees * 0.5)
	t.range_m = def.range_m
	t.pellet_radius_m = def.pellet_radius_m
	t.knockback_m = def.knockback_m
	t.knockback_ticks = SimTick.seconds_to_ticks(def.knockback_seconds)
	t.recoil_m = def.recoil_m
	t.recoil_ticks = maxi(1, SimTick.seconds_to_ticks(def.recoil_seconds))
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
		ItemDefinition.Kind.CINDER_SHOT: ItemTable.Kind.CINDER_SHOT,
		ItemDefinition.Kind.WILDFIRE: ItemTable.Kind.WILDFIRE,
		ItemDefinition.Kind.CONDUCTOR: ItemTable.Kind.CONDUCTOR,
		ItemDefinition.Kind.SERRATED_EDGE: ItemTable.Kind.SERRATED_EDGE,
		ItemDefinition.Kind.BARBED_BOLTS: ItemTable.Kind.BARBED_BOLTS,
		ItemDefinition.Kind.GLACIAL_EDGE: ItemTable.Kind.GLACIAL_EDGE,
		ItemDefinition.Kind.COLD_SNAP: ItemTable.Kind.COLD_SNAP,
		ItemDefinition.Kind.BULWARK: ItemTable.Kind.BULWARK,
		ItemDefinition.Kind.HEAT_SINK: ItemTable.Kind.HEAT_SINK,
		ItemDefinition.Kind.THERMAL_EDGE: ItemTable.Kind.THERMAL_EDGE,
		ItemDefinition.Kind.MELTDOWN: ItemTable.Kind.MELTDOWN,
		ItemDefinition.Kind.CLUSTER_PAYLOAD: ItemTable.Kind.CLUSTER_PAYLOAD,
		ItemDefinition.Kind.OVERCLOCKED_DRONE: ItemTable.Kind.OVERCLOCKED_DRONE,
		ItemDefinition.Kind.RAZOR_ORBIT: ItemTable.Kind.RAZOR_ORBIT,
		ItemDefinition.Kind.AFTERIMAGE: ItemTable.Kind.AFTERIMAGE,
	}[def.kind]
	t.name_key = def.name_key
	t.desc_key = def.desc_key
	t.rarity = def.rarity
	var needs := {&"guard": PlayerTable.Utility.GUARD, &"blink": PlayerTable.Utility.BLINK}
	t.requires_utility = needs.get(def.requires_utility, -1)
	var weapons := {&"blade": PlayerTable.WEAPON_BLADE, &"gun": PlayerTable.WEAPON_GUN}
	t.requires_weapon = weapons.get(def.requires_weapon, 0)
	t.requires_ability = ItemDefinition.ability_kind(def.requires_ability)  # v0.5.0 CP
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
	_compile_item_engines(def, t)


## Engines (v0.3.0 G).
static func _compile_item_engines(def: ItemDefinition, t: ItemTable) -> void:
	t.tags = def.tags.duplicate()
	t.stacks_per_hit = def.stacks_per_hit
	t.stack_every = def.stack_every
	t.shock_threshold = def.shock_threshold
	t.shock_ticks = SimTick.seconds_to_ticks(def.shock_seconds)
	t.shock_damage = def.shock_damage
	t.shock_jumps = def.shock_jumps
	t.shock_range_m = def.shock_range_m
	t.bleed_damage = def.bleed_damage
	t.bleed_period_ticks = maxi(1, SimTick.seconds_to_ticks(def.bleed_period_seconds))
	t.bleed_ticks = SimTick.seconds_to_ticks(def.bleed_seconds)
	t.bleed_max_stacks = def.bleed_max_stacks
	t.bleed_burst_per_stack = def.bleed_burst_per_stack
	t.frost_threshold = def.frost_threshold
	t.frost_ticks = SimTick.seconds_to_ticks(def.frost_seconds)
	t.freeze_ticks = SimTick.seconds_to_ticks(def.freeze_seconds)
	t.spread_radius_m = def.spread_radius_m
	t.chill_bonus_permille = def.chill_bonus_permille
	t.frozen_bonus_permille = def.frozen_bonus_permille
	t.charge_max = def.charge_max
	t.charge_bonus_permille = def.charge_bonus_permille
	# Overclock heat (v0.3.0 L18).
	t.requires_heat = (
		def.kind
		in [
			ItemDefinition.Kind.HEAT_SINK,
			ItemDefinition.Kind.THERMAL_EDGE,
			ItemDefinition.Kind.MELTDOWN,
			ItemDefinition.Kind.OVERCLOCKED_DRONE,
		]
	)
	t.vent_damage_bonus_permille = def.vent_damage_bonus_permille
	t.vent_radius_bonus_permille = def.vent_radius_bonus_permille
	t.heat_hot_threshold = def.heat_hot_threshold
	t.meltdown_damage_permille = def.meltdown_damage_permille
	# Ability mods (v0.5.0 CP).
	t.bomblets = def.bomblets
	t.bomblet_damage_permille = def.bomblet_damage_permille
	t.bomblet_radius_permille = def.bomblet_radius_permille
	t.bomblet_delay_ticks = SimTick.seconds_to_ticks(def.bomblet_delay_seconds)
	t.drone_rate_per_heat_permille = def.drone_rate_per_heat_permille
	t.afterimage_damage = def.afterimage_damage
	t.afterimage_radius_m = def.afterimage_radius_m
	t.afterimage_delay_ticks = SimTick.seconds_to_ticks(def.afterimage_delay_seconds)


## Every item in a repository, compiled, in id order (the order of item indices). Give it to the world with
## World.set_item_tables.
static func compile_items(repo: ContentRepository) -> Array[ItemTable]:
	var out: Array[ItemTable] = []
	for def: ItemDefinition in repo.all_of(&"items"):
		out.append(compile_item(def))
	return out


# --- Bosses (v0.3.0 C) --------------------------------------------------------------------------------------
## Every boss in a repository, compiled, in id order (the order of boss indices: World.spawn_boss). Give it to the
## world with World.set_boss_tables.
static func compile_bosses(repo: ContentRepository) -> Array[BossTable]:
	var out: Array[BossTable] = []
	for def: BossDefinition in repo.all_of(&"bosses"):
		out.append(compile_boss(def, repo))
	return out


## A floor's boss pool as indices into compile_bosses (empty if the floor has no pool).
static func compile_boss_pool(repo: ContentRepository, floor_index: int) -> PackedInt32Array:
	var ids: Array = repo.all_of(&"bosses").map(func(d: BossDefinition) -> StringName: return d.id)
	var out := PackedInt32Array()
	for pool: BossPoolDefinition in repo.all_of(&"boss_pools"):
		if pool.floor_index != floor_index:
			continue
		for bid in pool.boss_ids:
			var k := ids.find(StringName(bid))
			if k >= 0:
				out.append(k)
	return out


static func compile_boss(def: BossDefinition, repo: ContentRepository) -> BossTable:
	var t := BossTable.new()
	t.id = def.id
	t.name_key = def.name_key
	t.kind = BOSS_KINDS[def.id]
	t.hp = def.hp
	t.radius_m = def.radius_m
	t.speed = def.move_speed_mps / SimTick.TICKS_PER_SECOND
	t.turn_rate = (
		0
		if def.turn_rate_dps <= 0.0
		else maxi(1, degrees_to_units(def.turn_rate_dps / SimTick.TICKS_PER_SECOND))
	)
	t.keep_distance_m = def.keep_distance_m
	t.front_half_arc = degrees_to_units(def.front_arc_degrees * 0.5)
	t.front_mult_permille = def.front_mult_permille
	t.rear_half_arc = degrees_to_units(def.rear_arc_degrees * 0.5)
	t.rear_mult_permille = def.rear_mult_permille
	t.stagger_size_milli = def.stagger_size * 1000
	t.stagger_decay_milli = int(
		round(def.stagger_decay_per_second * 1000.0 / SimTick.TICKS_PER_SECOND)
	)
	t.stagger_ticks = maxi(1, SimTick.seconds_to_ticks(def.stagger_seconds))
	for a in def.attacks:
		t.attacks.append(compile_boss_attack(a, repo))
	for ph in def.phases:
		t.phase_threshold.append(ph.hp_threshold_permille)
		var ks := PackedInt32Array()
		for aid in ph.attack_ids:
			ks.append(t.attack_index(StringName(aid)))
		t.phase_attacks.append(ks)
		t.phase_entry.append(
			t.attack_index(ph.entry_attack) if not String(ph.entry_attack).is_empty() else -1
		)
		t.phase_speed_permille.append(ph.speed_permille)
		t.phase_cd_permille.append(ph.cooldown_permille)
	t.arena_cells = def.arena_cells
	t.arena_template = def.arena_template
	_compile_boss_challenge(def, t)
	return t


## Boss challenge (v0.3.0 BX): ranged armour, punish, weak point, closing arena, harder AI.
static func _compile_boss_challenge(def: BossDefinition, t: BossTable) -> void:
	t.ranged_full_m = def.ranged_full_m
	t.ranged_far_m = def.ranged_far_m
	t.ranged_far_permille = def.ranged_far_permille
	t.punish_distance_m = def.punish_distance_m
	t.punish_ticks = SimTick.seconds_to_ticks(def.punish_seconds)
	t.punish_attack = (
		t.attack_index(def.punish_attack) if not String(def.punish_attack).is_empty() else -1
	)
	t.weak_ticks = SimTick.seconds_to_ticks(def.weak_point_seconds)
	t.weak_range_m = def.weak_point_range_m
	t.weak_mult_permille = def.weak_point_mult_permille
	t.weak_stagger_permille = def.weak_point_stagger_permille
	t.weak_drops_armour = def.weak_point_drops_armour
	t.close_phase = def.arena_close_phase
	t.close_after_ticks = SimTick.seconds_to_ticks(def.arena_close_after_seconds)
	t.close_step_ticks = maxi(1, SimTick.seconds_to_ticks(def.arena_close_step_seconds))
	t.close_step_m = def.arena_close_step_m
	t.close_warn_ticks = SimTick.seconds_to_ticks(def.arena_close_warn_seconds)
	t.safe_half_m = def.arena_safe_half_m
	t.hazard_damage = def.arena_hazard_damage
	t.hazard_ticks = maxi(1, SimTick.seconds_to_ticks(def.arena_hazard_seconds))
	t.lead_ticks = SimTick.seconds_to_ticks(def.lead_seconds)
	t.commit_ticks = SimTick.seconds_to_ticks(def.track_commit_seconds)
	t.dash_read_ticks = SimTick.seconds_to_ticks(def.dash_read_seconds)
	t.gap_distance_m = def.gap_close_distance_m
	t.gap_ticks = SimTick.seconds_to_ticks(def.gap_close_seconds)
	t.gap_attack = (
		t.attack_index(def.gap_close_attack) if not String(def.gap_close_attack).is_empty() else -1
	)
	for k in def.attacks.size():
		var a := def.attacks[k]
		var at := t.attacks[k]
		at.recover_ticks = at.recover_ticks * def.recovery_permille / 1000
		at.opens_weak = a.opens_weak_point
		at.follow_up = t.attack_index(a.follow_up) if not String(a.follow_up).is_empty() else -1
		at.follow_up_permille = a.follow_up_permille


static func compile_boss_attack(
	def: BossAttackDefinition, repo: ContentRepository
) -> BossAttackTable:
	var t := BossAttackTable.new()
	var sp := def.shape_params
	t.id = def.id
	t.move = BOSS_MOVES[def.move]
	t.cause_key = def.cause_key
	t.windup_ticks = SimTick.seconds_to_ticks(def.telegraph_seconds)
	t.active_ticks = maxi(1, SimTick.seconds_to_ticks(def.active_seconds))
	t.recover_ticks = SimTick.seconds_to_ticks(def.recovery_seconds)
	t.cooldown_ticks = SimTick.seconds_to_ticks(def.cooldown_seconds)
	t.damage = def.damage
	t.min_range_m = def.min_range_m
	t.max_range_m = def.max_range_m
	t.weight = def.weight
	t.count = int(sp.get("count", 1))
	t.chain = int(sp.get("chain", 1))
	t.volleys = int(sp.get("volleys", 1))
	t.gap_ticks = maxi(1, SimTick.seconds_to_ticks(float(sp.get("gap_seconds", 0.0))))
	t.radius_m = float(sp.get("radius_m", 0.0))
	t.inner_radius_m = float(sp.get("inner_radius_m", 0.0))
	t.distance_m = float(sp.get("distance_m", 0.0))
	t.spread_m = float(sp.get("spread_m", 0.0))
	t.spread = degrees_to_units(float(sp.get("spread_degrees", 0.0)))
	t.half_arc = degrees_to_units(float(sp.get("arc_degrees", 0.0)) * 0.5)
	t.length_m = float(sp.get("length_m", sp.get("range_m", 0.0)))
	t.reach_m = float(sp.get("reach_m", 0.0))
	t.half_width_m = float(sp.get("width_m", 0.0)) * 0.5
	t.speed = float(sp.get("speed_mps", 0.0)) / SimTick.TICKS_PER_SECOND
	if t.move == BossAttackTable.Move.BOLT_FAN and t.speed > 0.0:
		t.bolt_life_ticks = maxi(
			1, SimTick.seconds_to_ticks(float(sp["range_m"]) / float(sp["speed_mps"]))
		)
	t.track_ticks = SimTick.seconds_to_ticks(float(sp.get("track_seconds", 0.0)))
	t.erupt_ticks = SimTick.seconds_to_ticks(float(sp.get("erupt_seconds", 0.0)))
	if sp.has("enemy_id"):
		var e: EnemyDefinition = repo.get_def(&"enemies", StringName(sp["enemy_id"]))
		if e != null:
			t.enemy_kind = compile_enemy(e).kind
	t.max_alive = int(sp.get("max_alive", 99))
	t.pull = float(sp.get("pull_mps", 0.0)) / SimTick.TICKS_PER_SECOND
	t.pull_range_m = float(sp.get("pull_range_m", 0.0))
	t.gap_m = float(sp.get("gap_m", 0.0))  # v0.4.0 BO: a flood's lanes
	t.burn_ticks = maxi(1, SimTick.seconds_to_ticks(float(sp.get("burn_seconds", 0.0))))
	return t


## The floor's reward rules (v0.3.0 E): counts, chest prices, rarity weight, the shard tier bonus, in per mille.
static func compile_rewards(def: RewardsDefinition) -> RewardTable:
	var t := RewardTable.new()
	if def == null:
		return t
	t.altars_min = def.altars_min
	t.altars_max = def.altars_max
	t.chests_min = def.chests_min
	t.chests_max = def.chests_max
	t.chest_prices = def.chest_prices.duplicate()
	t.floor_price_step_permille = int(round(def.floor_price_step * 1000.0))
	t.rare_weight_chest = def.rare_weight_chest
	t.rare_weight_altar = def.rare_weight_altar
	t.offer_size = def.offer_size
	t.interact_radius_m = def.interact_radius_m
	t.shard_tier_bonus_permille = int(round(def.shard_tier_bonus * 1000.0))
	t.boss_shards = def.boss_shards
	t.altar_card_weights = def.altar_card_weights.duplicate()  # v0.4.0 BS
	t.chest_card_weights = def.chest_card_weights.duplicate()
	t.altar_rarity_weights = def.altar_rarity_weights.duplicate()
	t.chest_rarity_weights = def.chest_rarity_weights.duplicate()
	return t


## The gamble shrine (v0.3.0 L19): prices in per mille, each stat's amount (HP for max_hp, per mille of the data's
## percent otherwise), weight and cap in GambleTable.Stat order. A stat the data leaves out gets weight 0.
static func compile_gamble(def: GambleDefinition) -> GambleTable:
	var t := GambleTable.new()
	if def == null:
		return t
	t.base_price = def.base_price
	t.price_step_permille = int(round(def.price_step * 1000.0))
	t.floor_price_step_permille = int(round(def.floor_price_step * 1000.0))
	t.interact_radius_m = def.interact_radius_m
	t.spot_distance_m = def.spot_distance_m
	t.clear_radius_m = def.clear_radius_m
	t.amount = PackedInt32Array()
	t.weight = PackedInt32Array()
	t.cap = PackedInt32Array()
	t.requires_weapon = PackedInt32Array()
	for s in GambleTable.STAT_COUNT:
		t.amount.append(0)
		t.weight.append(0)
		t.cap.append(0)
		t.requires_weapon.append(0)
	for e in def.stats:
		var s := GambleTable.STAT_IDS.find(e.stat) if e != null else -1
		if s < 0:
			continue
		var scale := 1.0 if s == GambleTable.Stat.MAX_HP else 10.0
		t.amount[s] = int(round(e.amount * scale))
		t.weight[s] = e.weight
		t.cap[s] = e.max_stacks
		t.requires_weapon[s] = (
			{&"blade": PlayerTable.WEAPON_BLADE, &"gun": PlayerTable.WEAPON_GUN}
			. get(e.requires_weapon, 0)
		)
	return t


## The named combos (v0.3.0 G), their item ids resolved to item indices (the order compile_items gives: by id).
## Combos naming an unknown item are left out (the validator reports them).
static func compile_combos(repo: ContentRepository) -> Array[ComboTable]:
	var index := {}
	var items := repo.all_of(&"items")
	for k in items.size():
		index[(items[k] as ItemDefinition).id] = k
	var out: Array[ComboTable] = []
	for def: ComboDefinition in repo.all_of(&"combos"):
		if not index.has(def.item_a) or not index.has(def.item_b):
			continue
		var t := ComboTable.new()
		t.id = def.id
		t.effect = int(def.effect)
		t.item_a = index[def.item_a]
		t.item_b = index[def.item_b]
		t.name_key = def.name_key
		t.desc_key = def.desc_key
		t.damage = def.damage
		t.radius_m = def.radius_m
		t.stacks = def.stacks
		t.count = def.count
		t.spread = degrees_to_units(def.spread_degrees)
		t.share_permille = def.share_permille
		t.heal = def.heal
		t.window_ticks = SimTick.seconds_to_ticks(def.window_seconds)
		out.append(t)
	return out


## The abilities (v0.4.0 BS) in id order (the order World.ability_owned refers to): seconds to ticks, multipliers
## to per mille, the start weapon to its PlayerTable.WEAPON_* bit.
static func compile_abilities(repo: ContentRepository) -> Array[AbilityTable]:
	var out: Array[AbilityTable] = []
	for def: AbilityDefinition in repo.all_of(&"ability"):
		out.append(compile_ability(def))
	return out


static func compile_ability(def: AbilityDefinition) -> AbilityTable:
	var t := AbilityTable.new()
	t.id = def.id
	t.kind = def.kind as AbilityTable.Kind
	t.auto = def.activation == AbilityDefinition.Activation.AUTO
	t.button = def.button as AbilityTable.Binding
	t.rare = def.rarity == AbilityDefinition.Rarity.RARE
	t.name_key = def.name_key
	t.desc_key = def.desc_key
	var weapons := {&"blade": PlayerTable.WEAPON_BLADE, &"gun": PlayerTable.WEAPON_GUN}
	t.start_weapon = weapons.get(def.start_weapon, 0)
	t.tags = PackedStringArray()
	for tag in def.tags:
		t.tags.append(String(tag))
	t.cooldown_ticks = SimTick.seconds_to_ticks(def.cooldown_seconds)
	t.damage = def.damage
	t.range_m = def.range_m
	t.radius_m = def.radius_m
	t.speed = def.speed_mps / SimTick.TICKS_PER_SECOND
	t.period_ticks = maxi(1, SimTick.seconds_to_ticks(def.period_seconds))
	t.duration_ticks = SimTick.seconds_to_ticks(def.duration_seconds)
	t.hit_ticks = SimTick.seconds_to_ticks(def.hit_seconds)
	t.level_damage = PackedInt32Array()
	t.level_radius = PackedInt32Array()
	t.level_rate = PackedInt32Array()
	t.level_cooldown = PackedInt32Array()
	for k in AbilityTable.MAX_LEVEL:
		t.level_damage.append(int(round(def.level_damage[k] * 1000.0)))
		t.level_radius.append(int(round(def.level_radius[k] * 1000.0)))
		t.level_rate.append(int(round(def.level_rate[k] * 1000.0)))
		t.level_cooldown.append(SimTick.seconds_to_ticks(def.level_cooldown[k]))
	t.level_count = def.level_count.duplicate()
	t.level_extra = def.level_extra.duplicate()
	return t


## The stat cards (v0.4.0 BS), indexed by Stats.Stat (null for a stat without data). Amounts: percent (points for
## crit) to per mille (x 10). Caps: the ADD stats (crit chance, crit damage, regen, onrush, overkill, hoarder) in
## percent points (x 10), the others as a multiplier (x 1000). v0.5.0 CP: side x 10, limit x 1000.
static func compile_stat_cards(repo: ContentRepository) -> Array[StatTable]:
	var out: Array[StatTable] = []
	out.resize(Stats.COUNT)
	for def: StatCardDefinition in repo.all_of(&"stat_card"):
		var s := StatCardDefinition.STATS.find(def.stat)
		if s < 0:
			continue
		var t := StatTable.new()
		t.id = def.id
		t.stat = s
		t.name_key = def.name_key
		t.desc_key = def.desc_key
		t.amounts = PackedInt32Array()
		for k in StatCardDefinition.RARITIES:
			t.amounts.append(int(round(def.amounts[k] * 10.0)))
		var points := Stats.MODE[s] == Stats.ADD  # crit, regen and the v0.5.0 CP added cards
		t.cap = int(round(def.cap * (10.0 if points else 1000.0)))
		t.weight = def.weight
		if def.side.size() == StatCardDefinition.RARITIES:  # v0.5.0 CP: the rule cards
			for k in StatCardDefinition.RARITIES:
				t.side[k] = int(round(def.side[k] * 10.0))
		t.limit_permille = int(round(def.limit * 1000.0))
		out[s] = t
	return out


## A run's floors, biome count and scaling in per mille (v0.3.0 B).
static func compile_run(def: RunDefinition) -> RunTable:
	var t := RunTable.new()
	t.floors = def.floors
	t.biome_count = def.biomes.size()
	t.enemy_hp_floor_permille = def.enemy_hp_floor_permille.duplicate()
	t.enemy_damage_floor_permille = def.enemy_damage_floor_permille.duplicate()
	t.boss_hp_per_floor_permille = int(round(def.boss_hp_per_floor * 1000.0))
	t.boss_damage_per_floor_permille = int(round(def.boss_damage_per_floor * 1000.0))
	t.heal_permille = int(round(def.heal_between_floors * 1000.0))
	return t


## Overclock heat (v0.3.0 L18) in sim units: heat in milli-points, seconds in ticks. Null without a definition
## (Heat.enable then leaves heat off).
static func compile_heat(def: HeatDefinition) -> HeatTable:
	if def == null:
		return null
	var t := HeatTable.new()
	var m := HeatTable.MILLI
	t.max_heat = def.max_heat
	t.gain_swing = int(round(def.gain_swing * m))
	t.gain_finisher = int(round(def.gain_finisher * m))
	t.gain_bolt = int(round(def.gain_bolt * m))
	t.decay_delay_ticks = SimTick.seconds_to_ticks(def.decay_delay_seconds)
	t.decay_per_tick = int(round(def.decay_per_second * m / SimTick.TICKS_PER_SECOND))
	t.hot_threshold = def.hot_threshold
	t.hot_reach_permille = int(round(def.hot_reach_bonus * 1000.0))
	t.overclock_threshold = def.overclock_threshold
	t.overclock_damage_permille = int(round(def.overclock_damage_bonus * 1000.0))
	t.overclock_burn_stacks = def.overclock_burn_stacks
	t.stall_ticks = maxi(1, SimTick.seconds_to_ticks(def.overheat_seconds))
	t.stall_move_permille = int(round(def.overheat_move_multiplier * 1000.0))
	t.vent_radius_m = def.vent_radius_m
	t.vent_damage_permille = int(round(def.vent_damage_per_heat * 1000.0))
	return t
