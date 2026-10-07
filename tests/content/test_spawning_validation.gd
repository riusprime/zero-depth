extends GutTest
## Spawn director content (PLAN v0.2.0 C): the shipped floor validates and compiles; bad values are rejected.


func _def() -> SpawnDirectorDefinition:
	return (load("res://data/spawning/floor_1.tres") as SpawnDirectorDefinition).duplicate(true)


func _codes(d: SpawnDirectorDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_the_shipped_floor_is_valid_and_compiles() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(repo.count(&"spawning"), 1)
	var def: SpawnDirectorDefinition = repo.get_def(&"spawning", &"floor_1")
	assert_eq(def.validate(), [])
	for id in def.enemy_ids():
		assert_not_null(repo.get_def(&"enemies", id), "enemy %s exists" % id)
	var t := ContentCompiler.compile_spawning(def, repo)
	assert_eq(t.tier_ticks, 1800)
	assert_eq(t.interval_start_ticks, 180)
	assert_eq(t.interval_step_ticks, 15)
	assert_eq(t.interval_min_ticks, 48)
	assert_eq(t.hp_per_tier_permille, 80)
	assert_eq(t.kinds.size(), 11)
	var warden := t.kinds.find(ActorStore.Kind.WARDEN)
	assert_gte(warden, 0)
	assert_eq(t.unlock_tiers[warden], 1, "Wardens from tier 1")
	# v0.3.5 AI (owner F5, F6): the Arc Caster from tier 1, the Bomb Drone from tier 2.
	assert_eq(t.unlock_tiers[t.kinds.find(ActorStore.Kind.ARC_CASTER)], 1)
	assert_eq(t.unlock_tiers[t.kinds.find(ActorStore.Kind.BOMB_DRONE)], 2)
	# v0.4.0 EN: the horde kinds, Swarmers in packs of 8.
	var horde := {
		ActorStore.Kind.SWARMER: [1, 8],
		ActorStore.Kind.SPLITTER: [1, 1],
		ActorStore.Kind.SHIELD_BEARER: [2, 1],
		ActorStore.Kind.MINE_LAYER: [2, 1],
		ActorStore.Kind.SNIPER: [2, 1],
		ActorStore.Kind.MENDER: [3, 1],
	}
	for kind: int in horde:
		var k := t.kinds.find(kind)
		assert_gte(k, 0, "kind %d is in the mix" % kind)
		assert_eq([t.unlock_tiers[k], t.packs[k]], horde[kind], "kind %d: tier, pack" % kind)


func test_non_positive_values_are_rejected() -> void:
	var d := _def()
	d.tier_seconds = 0.0
	d.cap_base = 0
	d.interval_min_seconds = -1.0
	d.min_distance_m = 0.0
	var codes := _codes(d)
	assert_has(codes, &"not_positive")
	assert_gte(codes.count(&"not_positive"), 4)


func test_a_bad_mix_entry_is_rejected() -> void:
	var d := _def()
	d.mix[0].enemy_id = &""
	assert_has(_codes(d), &"mix_entry")
	d = _def()
	d.mix[1].weight = 0
	assert_has(_codes(d), &"mix_entry")
	d = _def()
	d.mix[0].pack = 0
	assert_has(_codes(d), &"mix_entry")


func test_something_must_be_unlocked_at_tier_0() -> void:
	var d := _def()
	for e in d.mix:
		e.unlock_tier = 1
	assert_has(_codes(d), &"mix_tier0")
	d.mix.clear()
	assert_has(_codes(d), &"missing")
