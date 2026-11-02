extends GutTest
## v0.6.0 MX1 (CONTENT_SCHEMA "Modifiers"): the modifiers in data/modifiers/ are discovered by ContentScanner, valid,
## named by the items whose attack effects moved into them, and compiled to sim units; a bad modifier, or an item
## naming a missing one, is rejected.


func _repo() -> ContentRepository:
	return AttackScenario.repo()


## A definition by path (one place that loads, so a test may use the same one twice).
func _def(path: String) -> Resource:
	return load(path)


func _codes(d: ModifierDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_every_modifier_is_discovered_and_valid() -> void:
	var repo := _repo()
	assert_eq(
		repo.count(&"modifiers"),
		50,
		(
			"v0.10.5 O1: the retired cards are gone (it was 105, saved indices stay as tombstones)."
			+ " MX1's 14, MX2's frost_nova and razor_orbit; MX4: the M-list's 29 new (Frost Core was one),"
			+ " 3 legendary, and Cluster Payload, Overclocked Drone and Afterimage; v0.6.5 WN1: 4 triggers;"
			+ " v0.6.5 WN3: the Gun pool's 12 new; WN4: the Blade pool's 12 new cards (B3–B11, B13, B14,"
			+ " B16); WN5a: the shared pool's 2 new (S5 Bleed, S7 Explosive); v0.6.5 WN5b: the 3 legendary"
			+ " triggers (On Hit, On Kill, On End ×2); v0.8.0 BL: Blade Storm and Riposte Chain; v0.8.0 RR: Chain Blast"
			+ " + v0.8.0 RM: Threadline, Faultline, Gravity Stitch, Stress Mark and the two mutations"
			+ " + v0.9.0 LZ, BM, VP, AF1: the Laser, the Bomb, the Void, the Lance, the Scatter"
			+ " + v0.9.0 AF2: the Glaive, the Seekers"
			+ " + v0.9.0 AF3: the Wave, the Wisps"
			+ " + v0.9.5 FC0: the Rune Explosion"
		)
	)
	assert_true(
		repo.paths.has("res://data/modifiers/ember_core.tres"), "the scanner finds the folder"
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
			assert_true(def.modifiers.is_empty(), "%s: no attack rewrite" % def.id)


func test_values_convert_with_the_item_compilers_functions() -> void:
	var by_id := {}
	for t in ModifierCompiler.compile_modifiers(_repo()):
		by_id[t.id] = t
	var twin: ModifierTable = by_id[&"double_slash"]
	assert_eq([twin.ops[0].field, twin.ops[0].value], [&"repeat_delay_ticks", 9.0], "0.15 s")
	var split: ModifierTable = by_id[&"gun_twin"]
	assert_eq([split.ops[0].field, split.ops[0].value], [&"twin", 1.0])


func test_an_unknown_modifier_on_an_item_is_an_error() -> void:
	var item := (load("res://data/items/wide_arc.tres") as ItemDefinition).duplicate(true)
	var ids: Array[StringName] = [&"no_such_modifier"]
	item.modifiers = ids
	var defs: Array[ContentDef] = [item]
	var issues := ContentValidator.validate(defs)
	assert_true(issues.any(func(i: ValidationIssue) -> bool: return i.code == &"unknown_modifier"))


func test_bad_modifiers_are_rejected() -> void:
	var base := load("res://data/modifiers/wide_arc.tres") as ModifierDefinition
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
	var s := (load("res://data/modifiers/ember_core.tres") as ModifierDefinition).duplicate(true)
	s.ops[0].status = &"glitter"
	assert_has(_codes(s), &"range", "unknown status")
	var oc := _def("res://data/modifiers/ember_core.tres") as ModifierDefinition
	var h := oc.duplicate(true)
	h.ops[2].hook_radius_m = 0.0
	assert_has(_codes(h), &"not_positive", "a burst hook needs a radius")
	h = oc.duplicate(true)
	h.ops[2].form = ModifierOpDefinition.Form.ORBITER
	assert_has(_codes(h), &"not_positive", "v0.6.5 WN4: an orbiter hook needs its orbit's reach")
	h = oc.duplicate(true)
	h.ops[2].form = 99 as ModifierOpDefinition.Form
	assert_has(_codes(h), &"range", "a hook spawns one of the forms")


## v0.6.0 MX4: the new hook parts (EVERY_NTH's count, a delay, the condition, the child's ops) are checked too.
func test_bad_mx4_hooks_are_rejected() -> void:
	var br := _def("res://data/modifiers/ember_core.tres") as ModifierDefinition
	assert_eq(br.validate(), [])
	var d := br.duplicate(true)
	d.ops[2].hook_trigger = ModifierOpDefinition.Trigger.EVERY_NTH
	d.ops[2].hook_every = 1
	assert_has(_codes(d), &"range", "every_nth needs every >= 2")
	d = br.duplicate(true)
	d.ops[2].hook_delay_seconds = -1.0
	assert_has(_codes(d), &"range", "a negative delay")
	d = br.duplicate(true)
	for child: ModifierOpDefinition in d.ops[2].hook_ops:
		child.field = &"mana"
	assert_has(_codes(d), &"range", "a child op's unknown field")
	d = br.duplicate(true)
	var nested := ModifierOpDefinition.new()
	nested.op = ModifierOpDefinition.Op.HOOK
	d.ops[2].hook_ops.append(nested)
	assert_has(_codes(d), &"range", "a child op is never a hook")
	var ls := (load("res://data/modifiers/long_shadow.tres") as ModifierDefinition).duplicate(true)
	assert_eq(ls.validate(), [], "Dodge Imprint's numbers validate (v0.8.0 RM)")
	ls.target = PackedStringArray(["dash", "sparkle"])
	assert_has(_codes(ls), &"tags", "an unknown target tag")


func test_mx4_values_convert() -> void:
	var by_id := {}
	for t in ModifierCompiler.compile_modifiers(_repo()):
		by_id[t.id] = t
	var seeker: ModifierTable = by_id[&"gun_homing"]
	assert_eq(
		[seeker.ops[0].field, seeker.ops[0].value],
		[&"homing", float(ContentCompiler.degrees_to_units(540.0) / 60)],
		"360°/s in 1/4096 turns per tick"
	)
	var ls: ModifierTable = by_id[&"long_shadow"]
	assert_eq([ls.ops[0].field, ls.ops[0].value], [&"imprint_ticks", 90.0], "1.5 s (v0.8.0 RM)")
	var split: ModifierTable = by_id[&"split_shot"]
	assert_eq(split.ops[0].child_ops.size(), 2, "the child's count and spread")


## v0.6.5 WN3: the Gun pool's new fields convert like the rest, a level's step converts in the same units, and a
## level only grows a number or a hook's damage share.
func test_wn3_values_and_levels_convert() -> void:
	var by_id := {}
	for t in ModifierCompiler.compile_modifiers(_repo()):
		by_id[t.id] = t
	var mine: ModifierTable = by_id[&"gun_mine"]
	assert_eq(
		[mine.ops[0].field, mine.ops[0].value, mine.ops[0].per_level], [&"mine_ticks", 240.0, 0.0]
	)
	assert_eq(mine.ops[1].per_level, 0.0, "v0.9.5 CLV: the blast's share is fixed")
	var spiral: ModifierTable = by_id[&"gun_spiral"]
	assert_eq([spiral.ops[0].field, spiral.ops[0].value], [&"spiral", 398.0], "35° in 1/4096 turns")
	var charge: ModifierTable = by_id[&"gun_lance"]
	assert_eq([charge.ops[1].field, charge.ops[1].value], [&"hold_ticks", 72.0], "1.2 s")
	var at3 := mine.at(3)
	assert_eq([at3.ops[0].value, at3.ops[1].damage_permille], [240.0, 1200], "level 3")
	assert_eq(mine.at(1), mine, "level 1 is the card itself")
	var bad := (load("res://data/modifiers/gun_spiral.tres") as ModifierDefinition).duplicate(true)
	bad.ops[0].op = ModifierOpDefinition.Op.ELEMENT
	bad.ops[0].stage = 3
	bad.ops[0].element = &"storm"
	assert_does_not_have(_codes(bad), &"range", "a plain element op is fine")
	bad.ops[0].per_level = 1.0
	assert_has(_codes(bad), &"range", "an element doesn't level")
