class_name EliteCompiler
extends RefCounted
## v0.9.0 EL (ELITES.md): the elites' content into sim tables, beside ContentCompiler (its file-length limit). An
## archetype (EliteDefinition) becomes an EnemyTable of its kind (HP, body, walk, shards: every enemy's numbers, so
## spawning, scaling, rewards and the flow field treat it as an enemy) carrying an EliteTable (its ability and plain
## attack). The rules (EliteRulesDefinition) become EliteRules.

const KINDS := {
	&"breaker": ActorStore.Kind.BREAKER,
	&"rift_hunter": ActorStore.Kind.RIFT_HUNTER,
	&"conduit": ActorStore.Kind.CONDUIT,
}


## Every elite archetype in a repository, compiled (by id).
static func compile_elites(repo: ContentRepository) -> Array[EnemyTable]:
	var out: Array[EnemyTable] = []
	for def: EliteDefinition in repo.all_of(&"elites"):
		out.append(compile_elite(def, repo))
	return out


static func compile_elite(def: EliteDefinition, repo: ContentRepository = null) -> EnemyTable:
	var t := EnemyTable.new()
	t.kind = KINDS[def.archetype]
	t.name_key = def.name_key
	t.hp = def.hp
	t.radius_m = def.radius_m
	t.speed = def.move_speed_mps / SimTick.TICKS_PER_SECOND
	t.shards = def.shards
	t.damage = def.contact_damage
	t.keep_min_m = def.keep_min_m
	t.keep_distance_m = def.keep_max_m
	var e := EliteTable.new()
	e.contact_damage = def.contact_damage
	e.contact_cd_ticks = maxi(1, SimTick.seconds_to_ticks(def.contact_cooldown_seconds))
	e.every_ticks = maxi(1, SimTick.seconds_to_ticks(def.ability_every_seconds))
	e.windup_ticks = maxi(1, SimTick.seconds_to_ticks(def.ability_windup_seconds))
	e.track_ticks = SimTick.seconds_to_ticks(def.ability_track_seconds)
	e.vanish_ticks = SimTick.seconds_to_ticks(def.ability_vanish_seconds)
	e.damage = def.ability_damage
	e.radius_m = def.ability_radius_m
	e.half_width_m = def.ability_half_width_m
	e.range_m = def.ability_range_m
	e.recover_ticks = SimTick.seconds_to_ticks(def.ability_recover_seconds)
	e.vulnerable_permille = def.ability_vulnerable_permille
	e.basic_damage = def.basic_damage
	e.basic_every_ticks = maxi(1, SimTick.seconds_to_ticks(def.basic_every_seconds))
	e.basic_windup_ticks = maxi(1, SimTick.seconds_to_ticks(def.basic_windup_seconds))
	e.basic_recover_ticks = SimTick.seconds_to_ticks(def.basic_recover_seconds)
	e.basic_range_m = def.basic_range_m
	if repo != null and def.basic_pattern_id != &"":
		var pd: BulletPatternDefinition = repo.get_def(&"bullet_patterns", def.basic_pattern_id)
		if pd != null:
			e.basic_pattern = PatternCompiler.compile_pattern(pd)
	t.elite = e
	return t


## The elite rules (the defaults without a definition).
static func compile_rules(def: EliteRulesDefinition) -> EliteRules:
	var t := EliteRules.new()
	if def == null:
		return t
	t.room_permille = def.room_permille.duplicate()
	t.min_gap_rooms = def.min_gap_rooms
	t.max_alive = def.max_alive
	t.core_drop_permille = def.core_drop_permille
	t.kind_weights = def.kind_weights.duplicate()
	t.lockdown_escort = def.lockdown_escort
	t.elite_weight = def.elite_weight  # v0.9.0 CF
	return t
