extends GutTest
## v0.6.0 MX1 (CONTENT_SCHEMA "Modifiers"): the modifiers in data/modifiers/ are discovered by ContentScanner, valid,
## named by the items whose attack effects moved into them, and compiled to sim units; a bad modifier, or an item
## naming a missing one, is rejected.


func _repo() -> ContentRepository:
	return AttackScenario.repo()


func _codes(d: ModifierDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_every_modifier_is_discovered_and_valid() -> void:
	var repo := _repo()
	assert_eq(repo.count(&"modifiers"), 14)
	assert_true(
		repo.paths.has("res://data/modifiers/static_chain.tres"), "the scanner finds the folder"
	)
	for def: ModifierDefinition in repo.all_of(&"modifiers"):
		assert_eq(def.validate(), [], String(def.id))
	assert_eq(repo.errors(), [], "no content errors")


func test_each_attack_item_names_its_own_modifier() -> void:
	var repo := _repo()
	for def: ItemDefinition in repo.all_of(&"items"):
		if def.kind in ItemDefinition.MODIFIER_KINDS:
			assert_eq(def.modifiers, [def.id] as Array[StringName], String(def.id))
			assert_not_null(repo.get_def(&"modifiers", def.id), String(def.id))
		else:
			assert_true(def.modifiers.is_empty(), "%s: no attack rewrite in MX1" % def.id)


func test_values_convert_with_the_item_compilers_functions() -> void:
	var by_id := {}
	for t in ModifierCompiler.compile_modifiers(_repo()):
		by_id[t.id] = t
	var twin: ModifierTable = by_id[&"twin_arc"]
	assert_eq([twin.ops[0].field, twin.ops[0].value], [&"repeat_delay_ticks", 6.0], "0.1 s")
	var split: ModifierTable = by_id[&"splinter_shot"]
	assert_eq([split.ops[1].field, split.ops[1].value], [&"spread", 137.0], "12 degrees")
	assert_eq(
		[split.ops[2].stage, split.stage],
		[ModifierTable.Stage.PAYLOAD, ModifierTable.Stage.PATTERN]
	)
	var chain: ModifierTable = by_id[&"static_chain"]
	var hook: ModifierOp = chain.ops[2]
	assert_eq(
		[hook.form, hook.trigger, hook.hook_every, hook.damage], [AttackSpec.Form.BEAM, 0, 3, 5]
	)


func test_an_unknown_modifier_on_an_item_is_an_error() -> void:
	var item := (load("res://data/items/long_edge.tres") as ItemDefinition).duplicate(true)
	var ids: Array[StringName] = [&"no_such_modifier"]
	item.modifiers = ids
	var defs: Array[ContentDef] = [item]
	var issues := ContentValidator.validate(defs)
	assert_true(issues.any(func(i: ValidationIssue) -> bool: return i.code == &"unknown_modifier"))


func test_bad_modifiers_are_rejected() -> void:
	var base := load("res://data/modifiers/long_edge.tres") as ModifierDefinition
	var d := base.duplicate(true)
	d.family = &"sparkles"
	assert_has(_codes(d), &"range", "unknown family")
	d = base.duplicate(true)
	d.target = PackedStringArray(["melee", "melee"])
	assert_has(_codes(d), &"tags", "a tag twice")
	d = base.duplicate(true)
	d.ops.clear()
	assert_has(_codes(d), &"missing", "no ops")
	d = base.duplicate(true)
	d.ops[0].field = &"mana"
	assert_has(_codes(d), &"range", "unknown field")
	d = base.duplicate(true)
	d.stage = ModifierDefinition.Stage.PATTERN
	assert_has(_codes(d), &"stage", "a reach op runs in SCALE")
	var s := (load("res://data/modifiers/ember_edge.tres") as ModifierDefinition).duplicate(true)
	s.ops[0].status = &"glitter"
	assert_has(_codes(s), &"range", "unknown status")
	var oc := load("res://data/modifiers/overcharge.tres") as ModifierDefinition
	var h := oc.duplicate(true)
	h.ops[2].hook_radius_m = 0.0
	assert_has(_codes(h), &"not_positive", "a burst hook needs a radius")
	h = oc.duplicate(true)
	h.ops[2].form = ModifierOpDefinition.Form.ORBITER
	assert_has(_codes(h), &"range", "MX1 hooks spawn bursts and beams")
