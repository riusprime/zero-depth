extends GutTest
## Boss content rules (PLAN v0.3.0 C; CONTENT_SCHEMA §4): the shipped bosses and pools are valid and compile; the
## telegraph minimum, the move schemas, phases, armour and arenas are checked.


func _def(id: String = "gatekeeper") -> BossDefinition:
	return (load("res://data/bosses/%s.tres" % id) as BossDefinition).duplicate(true)


func _codes(d: BossDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_the_shipped_bosses_are_valid_and_compile() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(repo.count(&"bosses"), 6, "two per pool (v0.4.0 BO)")
	assert_eq(repo.count(&"boss_pools"), 3)
	for def: BossDefinition in repo.all_of(&"bosses"):
		assert_eq(def.validate(), [], String(def.id))
		var t := ContentCompiler.compile_boss(def, repo)
		assert_eq(t.phase_threshold[0], 1000)
		for atk in t.attacks:
			assert_gte(atk.windup_ticks, SimTick.MIN_TELEGRAPH_TICKS, "%s %s" % [def.id, atk.id])
			if atk.move == BossAttackTable.Move.BURROW:
				assert_gte(atk.erupt_ticks, SimTick.MIN_TELEGRAPH_TICKS, "the eruption's own mark")
		for ks in t.phase_attacks:
			assert_false(ks.has(-1), "every phase attack resolves")
		assert_eq(t.stagger_ticks, 150, "staggered for 2.5 s (PLAN)")


func test_pools_and_spawned_enemies_resolve() -> void:
	var repo := ContentRepository.load_all()
	for pool: BossPoolDefinition in repo.all_of(&"boss_pools"):
		for bid in pool.boss_ids:
			assert_not_null(repo.get_def(&"bosses", StringName(bid)), "%s: %s" % [pool.id, bid])
	for def: BossDefinition in repo.all_of(&"bosses"):
		for atk in def.attacks:
			if atk.shape_params.has("enemy_id"):
				var e := StringName(atk.shape_params["enemy_id"])
				assert_not_null(repo.get_def(&"enemies", e), "%s %s: %s" % [def.id, atk.id, e])


func test_arena_templates_match_the_generator() -> void:
	for k in BossSchemas.ARENA_TEMPLATES.size():
		assert_eq(BossSchemas.ARENA_TEMPLATES[k], FloorLayout.TEMPLATE_NAMES[k])
	var d := _def()
	d.arena_template = 99
	d.arena_cells = Vector2i(0, 9)
	assert_eq(_codes(d).count(&"arena"), 2)


func test_a_short_telegraph_is_rejected() -> void:
	var d := _def()
	d.attacks[0].telegraph_seconds = 0.2
	assert_has(_codes(d), &"telegraph_short")
	var b := _def("brood_mother")
	b.attack(&"burrow").shape_params["erupt_seconds"] = 0.2
	assert_has(_codes(b), &"telegraph_short", "a burrow's eruption mark is a telegraph too")


func test_moves_and_params_are_checked() -> void:
	var d := _def()
	d.attacks[0].shape_params.erase("radius_m")
	d.attacks[0].shape_params["mystery"] = 1
	d.attacks[1].move = &"dragon_breath"
	d.attacks[2].shape = AttackDefinition.Shape.PROJECTILE
	var codes := _codes(d)
	assert_has(codes, &"param_missing")
	assert_has(codes, &"param_unknown")
	assert_has(codes, &"unknown_move")
	assert_has(codes, &"shape")


func test_phases_are_checked() -> void:
	var d := _def()
	d.phases[1].hp_threshold_permille = 1000
	d.phases[1].attack_ids.append("nope")
	d.phases[1].entry_attack = &"nope_either"
	var codes := _codes(d)
	assert_has(codes, &"phases", "thresholds must fall")
	assert_eq(codes.count(&"unknown_attack"), 2)
	var e := _def()
	e.phases[0].hp_threshold_permille = 900
	assert_has(_codes(e), &"phases", "the first phase starts at 1000")


func test_armour_stagger_and_basics_are_checked() -> void:
	var d := _def()
	d.front_mult_permille = 0
	d.rear_mult_permille = 900
	d.stagger_size = 0
	d.hp = 0
	d.id = &"dragon"
	var codes := _codes(d)
	assert_eq(codes.count(&"armour"), 2)
	assert_has(codes, &"not_positive")
	assert_has(codes, &"unknown_boss")
	d.attacks[0].cause_key = &""
	assert_has(_codes(d), &"missing")


func test_the_boss_challenge_numbers_are_checked() -> void:
	var d := _def()
	assert_eq(_codes(d), [])
	d.punish_attack = &"nope"
	assert_has(_codes(d), &"unknown_attack", "the punish attack must exist")
	d = _def()
	d.arena_close_warn_seconds = 0.2
	assert_has(_codes(d), &"telegraph_short", "each closing step is marked long enough")
	d = _def()
	d.attacks[0].follow_up = d.attacks[0].id
	assert_has(_codes(d), &"unknown_attack", "an attack can't follow itself")
	d = _def()
	d.ranged_far_permille = 0
	d.weak_point_mult_permille = 900
	d.recovery_permille = 0
	d.arena_close_phase = 5
	assert_eq(_codes(d).count(&"challenge"), 4)
	d = _def()
	d.attacks[0].follow_up_permille = 1001
	assert_has(_codes(d), &"range")
