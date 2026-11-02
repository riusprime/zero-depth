extends GutTest
## v0.3.0 G content: item tags (a closed set), the engines' members, the eight combos (valid, both items exist,
## no pair twice) and their strings.


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


## A definition by path (one place that loads, so a test may duplicate the same one twice).
func _def(path: String) -> Resource:
	return load(path)


func _codes(issues: Array[ValidationIssue]) -> Array:
	return issues.map(func(v: ValidationIssue) -> StringName: return v.code)


func test_every_item_has_tags_from_the_closed_set() -> void:
	for def: ItemDefinition in _repo().all_of(&"items"):
		assert_gt(def.tags.size(), 0, String(def.id))
		for t in def.tags:
			assert_has(ItemDefinition.TAGS, StringName(t), "%s: %s" % [def.id, t])


func test_each_engine_has_a_member() -> void:
	var count := {}
	for def: ItemDefinition in _repo().all_of(&"items"):
		if def.kind in [ItemDefinition.Kind.MODIFIER, ItemDefinition.Kind.WAND]:
			continue  # v0.6.0 MX4: the M-list's cards feed the engines too; the rule is the v0.3.0 items'
			# (v0.6.5 WN5a: and the wand's pool cards: S5 Bleed, S7 Explosive)
		for t in def.tags:
			count[t] = count.get(t, 0) + 1
	# v0.10.5 O1: the v0.3.0 items (3-4 per engine) are gone; each live engine keeps at least one
	for engine in ["fire", "frost", "bleed", "guard"]:
		assert_gt(count.get(engine, 0), 0, engine)


func test_bad_tags_are_rejected() -> void:
	var d := (_def("res://data/items/bulwark.tres") as ItemDefinition).duplicate(true)
	d.tags = PackedStringArray()
	assert_has(_codes(d.validate()), &"tags", "no tags")
	d.tags = PackedStringArray(["blade", "poison"])
	assert_has(_codes(d.validate()), &"tags", "unknown tag")
	d.tags = PackedStringArray(["blade", "blade"])
	assert_has(_codes(d.validate()), &"tags", "a tag twice")
	d.tags = PackedStringArray(["blade"])
	assert_eq(d.validate(), [])


func test_bad_engine_items_are_rejected() -> void:
	var b := (load("res://data/items/shared_bleed.tres") as ItemDefinition).duplicate(true)
	b.bleed_max_stacks = 0  # v0.6.0 MX1: its every-N bolt feed moved into its modifier
	assert_has(_codes(b.validate()), &"range")
	var g := (load("res://data/items/cold_snap.tres") as ItemDefinition).duplicate(true)
	g.freeze_seconds = 0.001
	assert_has(_codes(g.validate()), &"duration_zero_ticks")
	var w := (_def("res://data/items/bulwark.tres") as ItemDefinition).duplicate(true)
	w.charge_max = 0
	assert_has(_codes(w.validate()), &"not_positive")


## v0.10.5 O1: the four combos left are valid and name real items; the twelve retired effects are refused.
func test_the_four_combos_are_valid_and_name_real_items() -> void:
	var repo := _repo()
	assert_eq(repo.count(&"combos"), 4)
	for i in repo.errors():
		fail_test("%s: %s (%s)" % [i.path, i.message, i.code])
	for def: ComboDefinition in repo.all_of(&"combos"):
		assert_eq(def.validate(), [], String(def.id))
		assert_not_null(repo.get_def(&"items", def.item_a), "%s: %s" % [def.id, def.item_a])
		assert_not_null(repo.get_def(&"items", def.item_b), "%s: %s" % [def.id, def.item_b])
	assert_eq(ContentCompiler.compile_combos(repo).size(), 16, "tombstones keep the saved indices")


func test_a_retired_combo_effect_is_refused() -> void:
	var live := (load("res://data/combos/blood_harvest.tres") as ComboDefinition).duplicate(true)
	assert_eq(live.validate(), [])
	for effect: int in ComboDefinition.RETIRED_EFFECTS:
		var c := live.duplicate(true) as ComboDefinition
		c.effect = effect as ComboDefinition.Effect
		assert_has(_codes(c.validate()), &"unknown", "effect %d is retired" % effect)


func test_a_combo_needs_two_existing_items_and_a_new_pair() -> void:
	var items: Array[ContentDef] = []
	for id in ["vampiric_core", "executioner"]:
		items.append(load("res://data/items/%s.tres" % id))
	var plasma := (_def("res://data/combos/blood_harvest.tres") as ComboDefinition).duplicate(true)
	var swapped := plasma.duplicate(true) as ComboDefinition
	swapped.id = &"blood_again"
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
	var g: ItemTable = by_id[&"frost_core"]
	assert_eq([g.frost_threshold, g.freeze_ticks], [3, 60])
	var b: ItemTable = by_id[&"bulwark"]
	assert_eq([b.charge_max, b.charge_bonus_permille], [3, 400])
	assert_eq(b.tags, PackedStringArray(["guard"]))
	var combos := {}
	for t in ContentCompiler.compile_combos(_repo()):
		combos[t.id] = t
	assert_eq(combos[&"shatter_dash"].damage, 30)
	assert_eq(combos[&"slipstream"].window_ticks, 90)


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
