extends GutTest
## Spawn director content (PLAN v0.2.0 C; hordes v0.4.0 SC): the shipped director validates and compiles; bad
## values and bad per-mille tables are rejected.


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
	assert_eq(t.interval_start_ticks, 150)
	assert_eq(t.interval_min_ticks, 24)
	assert_eq(t.cap_by_floor, PackedInt32Array([14, 30, 50]))
	assert_eq([t.cap_per_tier, t.cap_max], [6, 120])
	assert_eq(t.pack_min_by_floor, PackedInt32Array([2, 3, 3]))
	assert_eq(t.pack_max_by_floor, PackedInt32Array([3, 4, 5]))
	assert_eq(t.hp_tier_permille[1], 1100)
	assert_eq(t.damage_tier_permille[1], 1050)
	assert_eq(t.interval_tier_permille[1], 900)
	assert_eq(t.kinds.size(), 11)
	assert_eq(t.packs.size(), t.kinds.size(), "a pack per mix row (0 = the floor's draw)")
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
	# One pack rule (v0.4.0 SC + EN): the older kinds take the floor's draw (0); the horde kinds name theirs.
	assert_eq(t.packs[t.kinds.find(ActorStore.Kind.CHARGER)], 0)
	for kind: int in horde:
		var k := t.kinds.find(kind)
		assert_gte(k, 0, "kind %d is in the mix" % kind)
		assert_eq([t.unlock_tiers[k], t.packs[k]], horde[kind], "kind %d: tier, pack" % kind)


func test_non_positive_values_are_rejected() -> void:
	var d := _def()
	d.tier_seconds = 0.0
	d.cap_by_floor = PackedInt32Array([0, 30])
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
	d.mix[0].pack = -1
	assert_has(_codes(d), &"mix_entry")


func test_something_must_be_unlocked_at_tier_0() -> void:
	var d := _def()
	for e in d.mix:
		e.unlock_tier = 1
	assert_has(_codes(d), &"mix_tier0")
	d.mix.clear()
	assert_has(_codes(d), &"missing")


func test_bad_tier_tables_are_rejected() -> void:
	var d := _def()
	d.hp_tier_permille = PackedInt32Array([1000, 1100, 1050])
	assert_has(_codes(d), &"table_order", "an HP table never falls")
	d = _def()
	d.interval_tier_permille = PackedInt32Array([1000, 900, 950])
	assert_has(_codes(d), &"table_order", "the interval table never rises")
	d = _def()
	d.damage_tier_permille = PackedInt32Array([1050, 1100])
	assert_has(_codes(d), &"table_start", "a table starts at ×1")
	d = _def()
	d.hp_tier_permille = PackedInt32Array()
	assert_has(_codes(d), &"table_size")
	d = _def()
	d.hp_tier_permille = PackedInt32Array([1000, 200000])
	assert_has(_codes(d), &"table_range", "at most ×100, so the integer products stay safe")


func test_bad_caps_and_packs_are_rejected() -> void:
	var d := _def()
	d.cap_max = 20
	assert_has(_codes(d), &"cap_range", "a floor's base cap above the hard cap")
	d = _def()
	d.pack_max_by_floor = PackedInt32Array([1, 4, 5])
	assert_has(_codes(d), &"pack_range")
	d = _def()
	d.pack_max_by_floor = PackedInt32Array([3, 4])
	assert_has(_codes(d), &"pack_range")
	d = _def()
	d.mix[0].pack = -1
	assert_has(_codes(d), &"mix_entry")
	d = _def()
	d.edge_band_m = -1.0
	assert_has(_codes(d), &"negative")
