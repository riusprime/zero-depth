extends GutTest
## v0.3.0 G content: item tags (a closed set), the engines' members, the eight combos (valid, both items exist,
## no pair twice) and their strings.


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


func _codes(issues: Array[ValidationIssue]) -> Array:
	return issues.map(func(v: ValidationIssue) -> StringName: return v.code)


func test_every_item_has_tags_from_the_closed_set() -> void:
	for def: ItemDefinition in _repo().all_of(&"items"):
		assert_gt(def.tags.size(), 0, String(def.id))
		for t in def.tags:
			assert_has(ItemDefinition.TAGS, StringName(t), "%s: %s" % [def.id, t])


func test_each_engine_has_three_or_four_members() -> void:
	var count := {}
	for def: ItemDefinition in _repo().all_of(&"items"):
		for t in def.tags:
			count[t] = count.get(t, 0) + 1
	for engine in ["fire", "shock", "frost", "bleed", "guard"]:
		assert_between(count.get(engine, 0), 3, 4, engine)


func test_bad_tags_are_rejected() -> void:
	var d := (load("res://data/items/long_edge.tres") as ItemDefinition).duplicate(true)
	d.tags = PackedStringArray()
	assert_has(_codes(d.validate()), &"tags", "no tags")
	d.tags = PackedStringArray(["blade", "poison"])
	assert_has(_codes(d.validate()), &"tags", "unknown tag")
	d.tags = PackedStringArray(["blade", "blade"])
	assert_has(_codes(d.validate()), &"tags", "a tag twice")
	d.tags = PackedStringArray(["blade"])
	assert_eq(d.validate(), [])


func test_bad_engine_items_are_rejected() -> void:
	var c := (load("res://data/items/conductor.tres") as ItemDefinition).duplicate(true)
	c.shock_threshold = 1
	assert_has(_codes(c.validate()), &"range")
	var b := (load("res://data/items/barbed_bolts.tres") as ItemDefinition).duplicate(true)
	b.stack_every = 0
	assert_has(_codes(b.validate()), &"not_positive")
	var g := (load("res://data/items/glacial_edge.tres") as ItemDefinition).duplicate(true)
	g.freeze_seconds = 0.001
	assert_has(_codes(g.validate()), &"duration_zero_ticks")
	var w := (load("res://data/items/bulwark.tres") as ItemDefinition).duplicate(true)
	w.charge_max = 0
	assert_has(_codes(w.validate()), &"not_positive")


## v0.4.0 AB: eight item combos and eight ability combos (each names two real abilities).
func test_the_eight_combos_are_valid_and_name_real_items() -> void:
	var repo := _repo()
	assert_eq(repo.count(&"combos"), 16)
	for i in repo.errors():
		fail_test("%s: %s (%s)" % [i.path, i.message, i.code])
	var abilities := 0
	for def: ComboDefinition in repo.all_of(&"combos"):
		assert_eq(def.validate(), [], String(def.id))
		if def.is_ability_combo():
			abilities += 1
			assert_not_null(repo.get_def(&"ability", def.ability_a), String(def.ability_a))
			assert_not_null(repo.get_def(&"ability", def.ability_b), String(def.ability_b))
			continue
		assert_not_null(repo.get_def(&"items", def.item_a), "%s: %s" % [def.id, def.item_a])
		assert_not_null(repo.get_def(&"items", def.item_b), "%s: %s" % [def.id, def.item_b])
	assert_eq(abilities, 8, "eight ability combos")
	assert_eq(ContentCompiler.compile_combos(repo).size(), 16, "every combo compiles")


func test_an_ability_combo_needs_two_real_abilities_and_an_ability_effect() -> void:
	var storm := (load("res://data/combos/storm_bombs.tres") as ComboDefinition).duplicate(true)
	assert_eq(storm.validate(), [])
	var both := storm.duplicate(true) as ComboDefinition
	both.item_a = &"ember_edge"
	assert_has(_codes(both.validate()), &"combo_pair", "items and abilities, not both")
	var solo := storm.duplicate(true) as ComboDefinition
	solo.ability_b = solo.ability_a
	assert_has(_codes(solo.validate()), &"combo_pair")
	var wrong := storm.duplicate(true) as ComboDefinition
	wrong.effect = ComboDefinition.Effect.PLASMA_ARC
	assert_has(_codes(wrong.validate()), &"mismatch")
	var lvl := storm.duplicate(true) as ComboDefinition
	lvl.min_level = 6
	assert_has(_codes(lvl.validate()), &"range")
	var ghost := storm.duplicate(true) as ComboDefinition
	ghost.ability_b = &"no_such_ability"
	var defs: Array[ContentDef] = [load("res://data/abilities/bomb_lobber.tres"), ghost]
	assert_has(_codes(ContentValidator.validate(defs)), &"unknown_ability")
	var nova := (load("res://data/abilities/frost_nova.tres") as AbilityDefinition).duplicate(true)
	nova.engine_item = &"no_such_item"
	var adefs: Array[ContentDef] = [nova]
	assert_has(_codes(ContentValidator.validate(adefs)), &"unknown_item", "an engine item exists")


func test_a_combo_needs_two_existing_items_and_a_new_pair() -> void:
	var items: Array[ContentDef] = []
	for id in ["ember_edge", "static_chain"]:
		items.append(load("res://data/items/%s.tres" % id))
	var plasma := (load("res://data/combos/plasma_arc.tres") as ComboDefinition).duplicate(true)
	var swapped := plasma.duplicate(true) as ComboDefinition
	swapped.id = &"plasma_again"
	swapped.item_a = plasma.item_b
	swapped.item_b = plasma.item_a
	var ghost := plasma.duplicate(true) as ComboDefinition
	ghost.id = &"ghost"
	ghost.item_b = &"no_such_item"
	var defs: Array[ContentDef] = []
	defs.append_array(items)
	for d: ContentDef in [plasma, swapped, ghost]:
		defs.append(d)
	var codes := _codes(ContentValidator.validate(defs))
	assert_has(codes, &"duplicate_pair", "the same pair in either order")
	assert_has(codes, &"unknown_item")
	var solo := plasma.duplicate(true) as ComboDefinition
	solo.item_b = solo.item_a
	assert_has(_codes(solo.validate()), &"combo_pair", "an item can't combo with itself")
	var weak := plasma.duplicate(true) as ComboDefinition
	weak.damage = 0
	assert_has(_codes(weak.validate()), &"not_positive")
	var slip := (load("res://data/combos/slipstream.tres") as ComboDefinition).duplicate(true)
	slip.window_seconds = 0.001
	assert_has(_codes(slip.validate()), &"duration_zero_ticks")


func test_new_items_and_combos_compile_to_their_starting_values() -> void:
	var by_id := {}
	for t in ContentCompiler.compile_items(_repo()):
		by_id[t.id] = t
	var c: ItemTable = by_id[&"conductor"]
	assert_eq([c.shock_threshold, c.shock_ticks, c.shock_damage, c.shock_jumps], [5, 180, 12, 4])
	var s: ItemTable = by_id[&"serrated_edge"]
	assert_eq(
		[s.bleed_damage, s.bleed_period_ticks, s.bleed_ticks, s.bleed_max_stacks], [1, 30, 240, 8]
	)
	assert_eq(s.bleed_burst_per_stack, 5)
	var g: ItemTable = by_id[&"glacial_edge"]
	assert_eq([g.frost_threshold, g.frost_ticks, g.freeze_ticks], [4, 180, 60])
	var b: ItemTable = by_id[&"bulwark"]
	assert_eq([b.charge_max, b.charge_bonus_permille], [3, 400])
	assert_eq(b.tags, PackedStringArray(["guard"]))
	var combos := {}
	for t in ContentCompiler.compile_combos(_repo()):
		combos[t.id] = t
	assert_eq(combos[&"shatter_dash"].damage, 30)
	assert_eq(combos[&"slipstream"].window_ticks, 90)
	assert_eq(combos[&"shrapnel_storm"].spread, 455, "40 degrees in 1/4096 turns")


func test_every_combo_has_name_and_short_description_strings() -> void:
	var keys := {}
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3:
			keys[row[0]] = row
	for def: ComboDefinition in _repo().all_of(&"combos"):
		for k in [def.name_key, def.desc_key]:
			assert_true(keys.has(String(k)), "%s: %s" % [def.id, k])
		var desc: PackedStringArray = keys.get(String(def.desc_key), ["", "", ""])
		assert_between(desc[1].length(), 1, 60, "%s en" % def.id)
		assert_between(desc[2].length(), 1, 60, "%s es" % def.id)
