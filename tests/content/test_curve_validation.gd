extends GutTest
## Difficulty curve content (v0.4.0 TU): the three shipped curves (floors 1-3) validate, name only kinds in SC's
## spawn mix, bring in every kind before the peak and every mix kind by floor 3, and bad curves are rejected by code.


func _def() -> DifficultyCurveDefinition:
	return (load("res://data/curves/floor_1.tres") as DifficultyCurveDefinition).duplicate(true)


func _codes(d: DifficultyCurveDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_the_shipped_curves_are_valid() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(repo.count(&"curve"), 3)
	var sc: SpawnDirectorDefinition = repo.get_def(&"spawning", &"floor_1")
	var mix := sc.enemy_ids()
	var floors := []
	for d: DifficultyCurveDefinition in repo.all_of(&"curve"):
		assert_eq(d.validate(), [], "%s validates" % d.id)
		floors.append(d.floor_index)
		for id in d.enemy_ids():
			assert_has(mix, id, "%s: %s is in the spawn mix (it has a weight)" % [d.id, id])
			assert_not_null(repo.get_def(&"enemies", id))
		var peak := d.phases[d.phases.size() - 1]
		assert_between(
			peak.tier_permille, 1000, (sc.hp_tier_permille.size() - 1) * 1000, "within SC's tables"
		)
		assert_eq(peak.kinds.size(), 0, "%s: every kind is in before the peak" % d.id)
	floors.sort()
	assert_eq(floors, [1, 2, 3])


func test_every_mix_kind_appears_by_floor_3() -> void:
	var repo := ContentRepository.load_all()
	var sc: SpawnDirectorDefinition = repo.get_def(&"spawning", &"floor_1")
	var named := {}
	for d: DifficultyCurveDefinition in repo.all_of(&"curve"):
		for id in d.enemy_ids():
			named[id] = true
	for id in sc.enemy_ids():
		assert_true(named.has(id), "%s is introduced on some floor" % id)


func test_bad_curves_are_rejected() -> void:
	var d := _def()
	d.phases[0].tier_permille = 500
	assert_has(_codes(d), &"calm")
	d = _def()
	d.phases[0].hold = false
	assert_has(_codes(d), &"calm")
	d = _def()
	d.phases[0].start_seconds = 5.0
	assert_has(_codes(d), &"calm")
	d = _def()
	d.phases[2].start_seconds = d.phases[1].start_seconds
	assert_has(_codes(d), &"phase_order")
	d = _def()
	d.phases[2].cap_permille = d.phases[1].cap_permille - 1
	assert_has(_codes(d), &"phase_ramp")
	d = _def()
	d.phases[2].interval_permille = d.phases[1].interval_permille + 1
	assert_has(_codes(d), &"phase_ramp")
	d = _def()
	d.phases[1].damage_permille = 1001
	assert_has(_codes(d), &"phase_range")
	d = _def()
	d.phases[1].kinds.append(&"charger")
	assert_has(_codes(d), &"phase_kind", "a kind opens once")
	d = _def()
	d.phases[1].name_key = &""
	assert_has(_codes(d), &"phase_name")
	d = _def()
	d.phases = []
	assert_has(_codes(d), &"missing")
	d = _def()
	d.floor_index = 0
	assert_has(_codes(d), &"floor_index")
