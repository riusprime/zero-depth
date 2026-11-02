extends GutTest
## Item content (v0.2.0 E, J; v0.3.0 G, L18; v0.5.0 CP): all 31 items validate, compile to the PLAN's starting values,
## and have strings. v0.6.0 MX1: the numbers an item applies to the weapon attacks live in its modifier; they are
## checked here on the compiled specs of a build holding the item (Modifiers).


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


func _codes(d: ItemDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_every_item_is_valid() -> void:
	var repo := _repo()
	assert_eq(
		repo.count(&"items"),
		63,
		(
			"v0.10.5 O1: the 54 retired cards are gone (their saved indices stay as tombstones)."
			+ " It was 117: 24 + the three heat items (L18) + four ability mods (v0.5.0 CP) + the M-list's 29 new cards"
			+ " (Frost Core was one) + 3 legendary (v0.6.0 MX4) + the wand's 4 triggers (v0.6.5 WN1)"
			+ " + the Gun pool's 12 new cards (v0.6.5 WN3; G5, G9, G10, G16 are M-list cards)"
			+ " + the Blade pool's 12 new cards (v0.6.5 WN4) + the shared pool's 2 new (v0.6.5 WN5a:"
			+ " S5 Bleed, S7 Explosive; S1-S4 and S6 are M-list cards) + the 3 legendary triggers (v0.6.5 WN5b)"
			+ " + the Blade's 2 multiplier cards (v0.8.0 BL: Blade Storm, Riposte Chain) + v0.8.0 RR: Chain Blast"
			+ " + v0.8.0 RM: Threadline, Faultline, Gravity Stitch, Stress Mark and the two mutations"
			+ " + v0.9.0 LZ, BM, VP, AF1: the Laser, the Bomb, the Void, the Lance, the Scatter"
			+ " + v0.9.0 AF2: the Glaive, the Seekers"
			+ " + v0.9.0 AF3: the Wave, the Wisps"
			+ " + v0.9.5 FC0: the Rune Explosion (the Scatter stays in the data, retired)"
		)
	)
	for def: ItemDefinition in repo.all_of(&"items"):
		assert_eq(def.validate(), [], String(def.id))
	# ContentCompiler.compile_item casts the content kind to the sim kind: the enums must match name for name.
	assert_eq(
		ItemDefinition.Kind.keys(), ItemTable.Kind.keys(), "item kinds: content and sim enums match"
	)
	assert_eq(ItemDefinition.Kind.values(), ItemTable.Kind.values(), "item kinds: same numbers")


## The compiled specs of the runner holding item `id` alone.
func _book(id: StringName) -> AttackBook:
	var tables := ContentCompiler.compile_items(_repo())
	var w := World.new(1, PlayerTable.starting_values())
	w.set_item_tables(tables)
	assert_true(w.add_item(AttackScenario.item_index(tables, id)), "holds %s" % id)
	return Modifiers.book(w)


func test_items_compile_to_the_plan_numbers() -> void:
	var by_id := {}
	for t in ContentCompiler.compile_items(_repo()):
		by_id[t.id] = t
	assert_eq(_book(&"wide_arc").spec(&"blade_step_0").reach_bonus_permille, 300)
	var twin := _book(&"double_slash").spec(&"blade_step_2")
	assert_eq([twin.repeat_delay_ticks, twin.repeat_damage_permille], [9, 600])
	var ember: ItemTable = by_id[&"ember_core"]
	assert_eq(
		[
			ember.burn_damage,
			ember.burn_period_ticks,
			ember.burn_duration_ticks,
			ember.burn_max_stacks
		],
		[2, 30, 180, 5]
	)
	var split := _book(&"gun_twin").spec(&"gun_bolt")
	assert_eq(split.twin, 1)
	assert_eq(_book(&"gun_rapid_fire").spec(&"gun_bolt").rate_bonus_permille, 300)
	assert_eq(_book(&"gun_ricochet").spec(&"gun_bolt").bounces, 3)
	assert_eq(by_id[&"kinetic_dash"].dash_hit_damage, 12)


func test_the_second_eight_compile_to_their_starting_values() -> void:
	var by_id := {}
	for t in ContentCompiler.compile_items(_repo()):
		by_id[t.id] = t
	var v: ItemTable = by_id[&"vampiric_core"]
	assert_eq([v.heal_per_kill, v.heal_cap, v.heal_window_ticks], [3, 15, 300])
	var mo: ItemTable = by_id[&"momentum"]
	assert_eq([mo.momentum_window_ticks, mo.momentum_bonus_permille], [60, 600])
	var f: ItemTable = by_id[&"frost_core"]
	assert_eq([f.slow_permille, f.slow_ticks], [700, 90])
	var th: ItemTable = by_id[&"thorn_mantle"]
	assert_eq([th.thorn_bolts, th.thorn_damage], [6, 4])
	var ex: ItemTable = by_id[&"executioner"]
	assert_eq([ex.execute_threshold_permille, ex.execute_bonus_permille], [300, 500])
	var sf: ItemTable = by_id[&"swift_feet"]
	assert_eq([sf.move_speed_bonus_permille, sf.dash_cooldown_cut_permille], [150, 200])
	var ph: ItemTable = by_id[&"phase_strike"]
	assert_eq([ph.phase_damage, ph.phase_guard_window_ticks], [12, 120])
	assert_almost_eq(ph.phase_radius_m, 1.5, 1e-6)


func test_item_descriptions_are_short() -> void:
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and row[0].begins_with("ITEM_") and row[0].ends_with("_DESC"):
			assert_lte(row[1].length(), 60, row[0] + " en")
			assert_lte(row[2].length(), 60, row[0] + " es")


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
	var d := (load("res://data/items/gun_twin.tres") as ItemDefinition).duplicate(true)
	d.modifiers.clear()
	assert_has(_codes(d), &"missing", "an attack item names its modifier (v0.6.0 MX1)")
	var e := (load("res://data/items/ember_core.tres") as ItemDefinition).duplicate(true)
	e.burn_period_seconds = 0.001
	assert_has(_codes(e), &"duration_zero_ticks")
	e.burn_max_stacks = 0
	assert_has(_codes(e), &"range")
	var o := (load("res://data/items/finisher_plus.tres") as ItemDefinition).duplicate(true)
	o.desc_key = &""
	assert_has(_codes(o), &"missing")


func test_bad_second_eight_items_are_rejected() -> void:
	var f := (load("res://data/items/frost_core.tres") as ItemDefinition).duplicate(true)
	f.slow_permille = 1000
	assert_has(_codes(f), &"range", "a slow to 100% isn't a slow")
	var x := (load("res://data/items/executioner.tres") as ItemDefinition).duplicate(true)
	x.execute_threshold_permille = 0
	assert_has(_codes(x), &"range")
	var v := (load("res://data/items/vampiric_core.tres") as ItemDefinition).duplicate(true)
	v.heal_window_seconds = 0.001
	assert_has(_codes(v), &"duration_zero_ticks")
	var s := (load("res://data/items/swift_feet.tres") as ItemDefinition).duplicate(true)
	s.dash_cooldown_cut_permille = 1000
	assert_has(_codes(s), &"range")
