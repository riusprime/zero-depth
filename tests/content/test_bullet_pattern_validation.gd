extends GutTest
## v0.7.5 BF1 (owner N15; BOSS_FIGHTS.md): bullet patterns (data/bullet_patterns, BulletPatternDefinition) and the
## boss attacks' lock and shield (CONTENT_SCHEMA §4b): the shipped ones are valid, every pattern a boss names exists,
## and the fairness rules (a gap, slow shots) and the lock rules are checked.


func _pattern(id: String) -> BulletPatternDefinition:
	return (load("res://data/bullet_patterns/%s.tres" % id) as BulletPatternDefinition).duplicate(
		true
	)


func _codes(v: Array[ValidationIssue]) -> Array:
	return v.map(func(i: ValidationIssue) -> StringName: return i.code)


func test_the_shipped_patterns_are_valid_and_compile() -> void:
	var repo := ContentRepository.load_all()
	assert_gte(repo.count(&"bullet_patterns"), 8, "the Gatekeeper's and the Warlord's patterns")
	for def: BulletPatternDefinition in repo.all_of(&"bullet_patterns"):
		assert_eq(def.validate(), [], String(def.id))
		var t := PatternCompiler.compile_pattern(def)
		assert_gt(t.speed, 0.0)
		assert_gte(t.life_ticks, 1)
		assert_false(String(t.look).is_empty(), "%s has its look" % def.id)


func test_every_pattern_a_boss_names_exists() -> void:
	var repo := ContentRepository.load_all()
	var named := 0
	for def: BossDefinition in repo.all_of(&"bosses"):
		for atk in def.attacks:
			if atk.move != &"pattern":
				continue
			named += 1
			var pid := StringName(atk.shape_params["pattern_id"])
			assert_not_null(
				repo.get_def(&"bullet_patterns", pid), "%s %s: %s" % [def.id, atk.id, pid]
			)
			var t := ContentCompiler.compile_boss(def, repo)
			var a := t.attacks[t.attack_index(atk.id)]
			assert_not_null(a.pattern, "%s compiles its pattern" % atk.id)
			assert_gte(a.active_ticks, a.pattern.duration_ticks(), "active for the whole pattern")
	assert_gte(named, 8)


func test_a_ring_without_a_gap_is_rejected() -> void:
	var d := _pattern("gatekeeper_rock_rings")
	d.gap_count = 0
	assert_has(_codes(d.validate()), &"no_gap")
	d = _pattern("gatekeeper_rock_rings")
	d.gap_width = 16
	assert_has(_codes(d.validate()), &"no_gap", "the gaps can't take every shot")
	d = _pattern("gatekeeper_rock_rings")
	d.count = 60
	d.gap_width = 1
	assert_has(_codes(d.validate()), &"no_gap", "a one-shot gap in a dense ring is too narrow")


func test_a_wall_needs_a_gap_the_hero_fits() -> void:
	var d := _pattern("warlord_shield_wall")
	d.gap_m = 0.5
	assert_has(_codes(d.validate()), &"no_gap")
	d = _pattern("warlord_shield_wall")
	d.spacing_m = 0.1
	assert_has(_codes(d.validate()), &"too_many")


func test_shots_stay_slow_and_named() -> void:
	var d := _pattern("warlord_javelin_fan")
	d.speed_mps = 14.0
	d.look = &""
	var codes := _codes(d.validate())
	assert_has(codes, &"range", "not bullets going fast but slower attacks")
	assert_has(codes, &"missing", "each source its own look")
	d = _pattern("warlord_javelin_fan")
	d.spread_degrees = 360.0
	assert_has(_codes(d.validate()), &"no_gap", "a fan leaves a side open")


func test_flower_spiral_and_burst_rules() -> void:
	var f := BulletPatternDefinition.new()
	f.id = &"test_flower"
	f.look = &"ember_stone"
	f.kind = BulletPatternDefinition.Kind.FLOWER
	f.count = 40
	assert_eq(f.validate(), [], "the defaults make a fair flower")
	f.petal_cut_permille = 0
	assert_has(_codes(f.validate()), &"no_gap", "the cut opens the gaps between petals")
	var s := BulletPatternDefinition.new()
	s.id = &"test_spiral"
	s.look = &"ember_stone"
	s.kind = BulletPatternDefinition.Kind.SPIRAL
	s.arms = 13  # v0.8.0 PR: 1..12
	assert_has(_codes(s.validate()), &"range")
	var b := BulletPatternDefinition.new()
	b.id = &"test_burst"
	b.look = &"ember_stone"
	b.kind = BulletPatternDefinition.Kind.BURST
	b.count = 8
	assert_eq(b.validate(), [])
	b.lob_seconds = 0.0
	assert_has(_codes(b.validate()), &"duration")


func test_the_lock_rules() -> void:
	var d: BossDefinition = (load("res://data/bosses/gatekeeper.tres") as BossDefinition).duplicate(
		true
	)
	var slam := d.attack(&"fist_slam")
	slam.lock_seconds = 0.0
	assert_has(_codes(d.validate()), &"missing", "a marker must lock")
	slam.lock_seconds = 0.2
	assert_has(_codes(d.validate()), &"telegraph_short", "the dodge window is a telegraph too")
	slam.lock_seconds = 1.6
	assert_has(_codes(d.validate()), &"duration", "it tracks before it locks")
	slam.lock_seconds = 0.8
	assert_eq(d.validate(), [])
	d.attack(&"fist_slam_2").shape_params["stagger_seconds"] = 0.0
	assert_has(_codes(d.validate()), &"duration", "two markers can't share a tick")


func test_the_two_fights_follow_the_design() -> void:
	var repo := ContentRepository.load_all()
	var signature := {&"gatekeeper": [&"rock_rings", &"rock_rings_4"], &"warlord": [&"shield_wall"]}
	signature[&"warlord"].append(&"shield_wall_cross")
	for id: StringName in signature:
		var def: BossDefinition = repo.get_def(&"bosses", id)
		assert_eq(def.hp, 1750, "%s: HP ×1.25 of 1400 (BOSS_FIGHTS.md rule 4)" % id)
		for atk in def.attacks:
			var sig: bool = (signature[id] as Array).has(atk.id)
			assert_eq(atk.shielded, sig, "%s %s: only the signature is shielded" % [id, atk.id])
			if atk.move in [&"marks", &"row_lanes", &"flood", &"charge", &"barrage"]:
				assert_almost_eq(atk.lock_seconds, 0.8, 0.001, "%s %s locks 0.8 s" % [id, atk.id])
		assert_eq(def.phases.size(), 3)
		assert_eq(def.phases[1].hp_threshold_permille, 660, "the 66 % gate stays")
		assert_eq(def.phases[2].hp_threshold_permille, 330, "the 33 % gate stays")
