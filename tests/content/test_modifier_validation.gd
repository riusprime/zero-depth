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
	assert_eq(
		repo.count(&"modifiers"),
		51,
		(
			"MX1's 14, MX2's frost_nova and razor_orbit; MX4: the M-list's 29 new (Frost Core was one),"
			+ " 3 legendary, and Cluster Payload, Overclocked Drone and Afterimage"
		)
	)
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
		elif def.id == &"razor_orbit":  # v0.6.0 MX2: the orbit spec's bleed
			assert_eq(def.modifiers, [&"razor_orbit"] as Array[StringName])
		else:
			assert_true(def.modifiers.is_empty(), "%s: no attack rewrite" % def.id)


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


## v0.6.0 MX4: the new hook parts (EVERY_NTH's count, a delay, the condition, the child's ops) are checked too.
func test_bad_mx4_hooks_are_rejected() -> void:
	var br := load("res://data/modifiers/bomb_rounds.tres") as ModifierDefinition
	assert_eq(br.validate(), [])
	var d := br.duplicate(true)
	d.ops[0].hook_every = 1
	assert_has(_codes(d), &"range", "every_nth needs every >= 2")
	d = br.duplicate(true)
	d.ops[0].hook_delay_seconds = -1.0
	assert_has(_codes(d), &"range", "a negative delay")
	d = br.duplicate(true)
	d.ops[0].hook_ops[0].field = &"mana"
	assert_has(_codes(d), &"range", "a child op's unknown field")
	d = br.duplicate(true)
	var nested := ModifierOpDefinition.new()
	nested.op = ModifierOpDefinition.Op.HOOK
	d.ops[0].hook_ops.append(nested)
	assert_has(_codes(d), &"range", "a child op is never a hook")
	var ls := (load("res://data/modifiers/long_shadow.tres") as ModifierDefinition).duplicate(true)
	assert_eq(ls.validate(), [], "a weapon copy needs no size")
	ls.target = PackedStringArray(["dash", "sparkle"])
	assert_has(_codes(ls), &"tags", "an unknown target tag")


func test_mx4_values_convert() -> void:
	var by_id := {}
	for t in ModifierCompiler.compile_modifiers(_repo()):
		by_id[t.id] = t
	var seeker: ModifierTable = by_id[&"seeker"]
	assert_eq(
		[seeker.ops[0].field, seeker.ops[0].value],
		[&"homing", float(ContentCompiler.degrees_to_units(360.0) / 60)],
		"360°/s in 1/4096 turns per tick"
	)
	var ls: ModifierTable = by_id[&"long_shadow"]
	assert_eq([ls.ops[0].delay_ticks, ls.ops[0].form], [9, AttackSpec.Form.WEAPON], "0.15 s")
	var split: ModifierTable = by_id[&"split_shot"]
	assert_eq(split.ops[0].child_ops.size(), 2, "the child's count and spread")
	var fuse: ModifierTable = by_id[&"short_fuse"]
	assert_eq([fuse.ops[0].field, fuse.ops[0].value], [&"range", 600.0])
