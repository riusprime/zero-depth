extends GutTest
## Item content (v0.2.0 E): all eight items validate, compile to the PLAN's starting values, and have strings.


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


func _codes(d: ItemDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_the_eight_items_are_valid() -> void:
	var repo := _repo()
	assert_eq(repo.count(&"items"), 8)
	for def: ItemDefinition in repo.all_of(&"items"):
		assert_eq(def.validate(), [], String(def.id))


func test_items_compile_to_the_plan_numbers() -> void:
	var by_id := {}
	for t in ContentCompiler.compile_items(_repo()):
		by_id[t.id] = t
	assert_eq(by_id[&"long_edge"].reach_bonus_permille, 350)
	assert_eq(by_id[&"twin_arc"].echo_delay_ticks, 6)
	assert_eq(by_id[&"twin_arc"].echo_damage_permille, 500)
	var ember: ItemTable = by_id[&"ember_edge"]
	assert_eq(
		[
			ember.burn_damage,
			ember.burn_period_ticks,
			ember.burn_duration_ticks,
			ember.burn_max_stacks
		],
		[2, 30, 180, 5]
	)
	var split: ItemTable = by_id[&"splinter_shot"]
	assert_eq([split.split_count, split.split_spread, split.split_damage_permille], [3, 137, 600])
	assert_eq(by_id[&"rapid_coil"].fire_rate_bonus_permille, 400)
	assert_eq(by_id[&"ricochet_core"].bounces, 1)
	assert_eq(by_id[&"kinetic_dash"].dash_hit_damage, 12)
	var oc: ItemTable = by_id[&"overcharge"]
	assert_eq(
		[oc.overcharge_every, oc.overcharge_mult_permille, oc.shockwave_damage_permille],
		[4, 2000, 500]
	)
	assert_almost_eq(oc.shockwave_radius_m, 2.0, 1e-6)


func test_every_item_has_name_and_description_strings() -> void:
	var keys := {}
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3:
			keys[row[0]] = row
	for def: ItemDefinition in _repo().all_of(&"items"):
		for k in [def.name_key, def.desc_key]:
			assert_true(keys.has(String(k)), "%s: %s" % [def.id, k])
			if keys.has(String(k)):
				assert_false(keys[String(k)][2].is_empty(), "%s has es" % k)


func test_bad_items_are_rejected() -> void:
	var d := (load("res://data/items/splinter_shot.tres") as ItemDefinition).duplicate(true)
	d.split_count = 1
	assert_has(_codes(d), &"range")
	var e := (load("res://data/items/ember_edge.tres") as ItemDefinition).duplicate(true)
	e.burn_period_seconds = 0.001
	assert_has(_codes(e), &"duration_zero_ticks")
	e.burn_max_stacks = 0
	assert_has(_codes(e), &"not_positive")
	var o := (load("res://data/items/overcharge.tres") as ItemDefinition).duplicate(true)
	o.desc_key = &""
	assert_has(_codes(o), &"missing")
