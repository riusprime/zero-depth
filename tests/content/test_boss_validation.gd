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
	d.attack(&"fist_slam").shape_params.erase("radius_m")
	d.attack(&"fist_slam").shape_params["mystery"] = 1
	d.attack(&"rock_rings").move = &"dragon_breath"
	d.attack(&"shock_lanes").shape = AttackDefinition.Shape.PROJECTILE
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
	d.front_mult_permille = -1  # v0.8.0 BS1: 0 is a valid shield (the Warlord's); below it is not
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


## v0.8.0 BS1 (owner O5; BOSS_SIGNATURES.md S1-S3): the signature params are checked: pillars need a size and a step
## wider than it, a recall and an egg at least the telegraph minimum, an egg its enemy and HP, a late part its line.
func test_the_signature_params_are_checked() -> void:
	for id in ["gatekeeper", "warlord", "brood_mother"]:
		assert_eq(_codes(_def(id)), [], "%s ships valid" % id)
	var g := _def("gatekeeper")
	g.attack(&"shock_lanes").shape_params["pillar_step_m"] = 0.5
	assert_has(_codes(g), &"no_gap", "pillars need a gap between them")
	g = _def("gatekeeper")
	g.attack(&"shock_lanes").shape_params["pillar_m"] = 0.0
	assert_has(_codes(g), &"not_positive")
	var w := _def("warlord")
	w.attack(&"javelin_fan").shape_params["recall_seconds"] = 0.1
	assert_has(_codes(w), &"telegraph_short", "the way back is warned")
	w = _def("warlord")
	w.attack(&"javelin_fan").late_cause_key = &""
	assert_has(_codes(w), &"missing", "the javelins coming back name their death line")
	var b := _def("brood_mother")
	b.attack(&"egg_storm").shape_params.erase("enemy_id")
	assert_has(_codes(b), &"missing", "an egg names what hatches")
	b = _def("brood_mother")
	b.attack(&"egg_storm").shape_params["burst_phase"] = 0
	assert_has(_codes(b), &"range", "burst_phase is 1-based")
	b = _def("brood_mother")
	b.attack(&"egg_storm").shape_params["egg_seconds"] = 0.2
	assert_has(_codes(b), &"telegraph_short", "an egg sits long enough to be seen")
	b = _def("brood_mother")
	b.attack(&"egg_storm").shape_params["mystery"] = 1
	assert_has(_codes(b), &"param_unknown", "other keys still fail")


## v0.8.0 BS2 (owner O5; BOSS_SIGNATURES.md S4-S6): the Gaze's turn, the ricochets and the lava and melt are checked.
func test_the_signature_params_of_part_2_are_checked() -> void:
	for id in ["hive_lens", "siege_engine", "foundry"]:
		assert_eq(_codes(_def(id)), [], "%s ships valid" % id)
	var h := _def("hive_lens")
	h.attack(&"gaze").shape_params["quarter_seconds"] = 0.0
	assert_has(_codes(h), &"not_positive", "the beam turns")
	h = _def("hive_lens")
	h.attack(&"gaze").late_cause_key = &""
	assert_has(_codes(h), &"missing", "its orbs name their death line")
	var s := _def("siege_engine")
	s.attack(&"turret_cross").shape_params["bounces"] = 2
	assert_has(_codes(s), &"range", "a shell bounces once")
	s = _def("siege_engine")
	s.attack(&"deploy").shape_params["bounce_phase"] = 0
	assert_has(_codes(s), &"range", "bounce_phase is 1-based")
	var f := _def("foundry")
	f.attack(&"molten_flood").shape_params["lava_seconds"] = 0.1
	assert_has(_codes(f), &"telegraph_short", "lava stays long enough to be seen")
	f = _def("foundry")
	f.attack(&"molten_flood").shape_params["ford_m"] = 0.5
	assert_has(_codes(f), &"range", "a ford the hero fits through")
	f = _def("foundry")
	f.attack(&"meltdown").shape_params["warn_seconds"] = 9.0
	assert_has(_codes(f), &"telegraph_short", "each step warned, within its step")
	f = _def("foundry")
	f.attack(&"meltdown").shape_params["min_radius_m"] = 0.0
	assert_has(_codes(f), &"not_positive", "a minimum radius")


## v0.8.0 FB2 (FINAL_BOSS.md F5, F7): the Prism's Cross and her DPS-based HP are checked.
func test_the_prism_cross_and_dps_hp_are_checked() -> void:
	var fresh := func() -> FinalBossDefinition:
		return (load("res://data/final_boss/prism.tres") as FinalBossDefinition).duplicate(true)
	assert_eq(_codes(fresh.call()), [], "the Prism ships valid")
	var p: FinalBossDefinition = fresh.call()
	p.attack(&"cross_ring").shape_params["fast_quarter_seconds"] = 3.0
	assert_has(_codes(p), &"range", "it speeds up, never slows")
	p = fresh.call()
	p.attack(&"cross_ring").shape_params["window_seconds"] = 0.1
	assert_has(_codes(p), &"telegraph_short", "a window you can see")
	p = fresh.call()
	p.attack(&"cross_ring").active_seconds = 3.0
	assert_has(_codes(p), &"duration", "the spin and the window fit its active time")
	p = fresh.call()
	p.attack(&"cross_ring").shielded = false
	assert_has(_codes(p), &"missing", "shielded but for its window")
	p = fresh.call()
	p.attack(&"cross_ring").shape_params["bolt_attack"] = "cross_spiral"
	assert_has(_codes(p), &"unknown_attack", "its bolts are a bolt_fan with a lock")
	p = fresh.call()
	p.attack(&"cross_ring").shape_params["bolt_every_seconds"] = 0.3
	assert_has(_codes(p), &"duration", "a bolt aims before the next one")
	p = fresh.call()
	p.dps_hp_max = 10
	assert_has(_codes(p), &"range", "her clamps hold min <= max")
	p = fresh.call()
	p.dps_measure_seconds = 90
	assert_has(_codes(p), &"range", "the meter holds 60 s")
	p = fresh.call()
	p.shard_orbit_m = 1.0
	assert_has(_codes(p), &"range", "the shards orbit outside her body")
