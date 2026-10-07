class_name ContentCompiler
extends RefCounted
## Turns definitions into the sim's plain tables, converting seconds to ticks once (CONTENT_SCHEMA §9).
## In v0.0.1 it compiles only the player.

## Bosses (v0.3.0 C): boss ids to actor kinds, move names to BossAttackTable moves.
const BOSS_KINDS := {
	&"gatekeeper": ActorStore.Kind.GATEKEEPER,
	&"brood_mother": ActorStore.Kind.BROOD_MOTHER,
	&"siege_engine": ActorStore.Kind.SIEGE_ENGINE,
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
	t.shards = def.shards
	t.shards_by_floor = def.shards_by_floor
	match def.behaviour_id:
		&"charger", &"hatchling":
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
		ItemDefinition.Kind.CINDER_SHOT: ItemTable.Kind.CINDER_SHOT,
		ItemDefinition.Kind.WILDFIRE: ItemTable.Kind.WILDFIRE,
		ItemDefinition.Kind.CONDUCTOR: ItemTable.Kind.CONDUCTOR,
		ItemDefinition.Kind.SERRATED_EDGE: ItemTable.Kind.SERRATED_EDGE,
		ItemDefinition.Kind.BARBED_BOLTS: ItemTable.Kind.BARBED_BOLTS,
		ItemDefinition.Kind.GLACIAL_EDGE: ItemTable.Kind.GLACIAL_EDGE,
		ItemDefinition.Kind.COLD_SNAP: ItemTable.Kind.COLD_SNAP,
		ItemDefinition.Kind.BULWARK: ItemTable.Kind.BULWARK,
	}[def.kind]
	t.name_key = def.name_key
	t.desc_key = def.desc_key
	t.rarity = def.rarity
	var needs := {&"guard": PlayerTable.Utility.GUARD, &"blink": PlayerTable.Utility.BLINK}
	t.requires_utility = needs.get(def.requires_utility, -1)
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
	return t


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


## A run's floors, biome count and scaling in per mille (v0.3.0 B).
static func compile_run(def: RunDefinition) -> RunTable:
	var t := RunTable.new()
	t.floors = def.floors
	t.biome_count = def.biomes.size()
	t.hp_per_floor_permille = int(round(def.enemy_hp_per_floor * 1000.0))
	t.damage_per_floor_permille = int(round(def.enemy_damage_per_floor * 1000.0))
	t.heal_permille = int(round(def.heal_between_floors * 1000.0))
	return t
