extends GutTest
## v0.9.0 AS (PLAN C45, C60, C62): data/wand/attack_slots.tres validates through ContentScanner like all content:
## the limits per category, the caps, one default form, and AttackSlotsDefinition.cross_check: every live wand card
## names its slot category and every table id is a real live card of the right category.


func _codes(issues: Array[ValidationIssue]) -> Array:
	var out := []
	for i in issues:
		out.append("%s %s" % [i.code, i.message])
	return out


func _item(id: StringName, cat: StringName, mods: Array[StringName] = [&"x"]) -> ItemDefinition:
	var d := ItemDefinition.new()
	d.id = id
	d.kind = ItemDefinition.Kind.MODIFIER
	d.name_key = &"K"
	d.desc_key = &"K"
	d.tags = PackedStringArray(["bolt"])
	d.modifiers = mods
	d.slot_category = cat
	return d


func _table(rows: Array[AttackFormRow]) -> AttackSlotsDefinition:
	var t := AttackSlotsDefinition.new()
	t.id = &"attack_slots"
	t.forms = rows
	return t


func _row(id: StringName, card: StringName, allowed: Array[StringName]) -> AttackFormRow:
	var r := AttackFormRow.new()
	r.id = id
	r.card = card
	r.allowed = allowed
	return r


func test_the_shipped_table_and_cards_validate() -> void:
	var repo := ContentRepository.load_all()
	var t := repo.get_def(&"wand", &"attack_slots") as AttackSlotsDefinition
	assert_not_null(t, "the scanner finds data/wand/attack_slots.tres")
	assert_eq(t.validate().size(), 0)
	var defs: Array[ContentDef] = []
	for cat: String in repo.by_category:
		for d: ContentDef in (repo.by_category[cat] as Dictionary).values():
			defs.append(d)
	assert_eq(
		_codes(AttackSlotsDefinition.cross_check(defs)),
		[],
		"every live card classified, every id real"
	)


func test_bad_limits_caps_and_rows_are_errors() -> void:
	var t := _table([_row(&"a", &"", []), _row(&"b", &"", [])])
	t.gun_limits = PackedInt32Array([1, 1, 2])
	t.blade_limits = PackedInt32Array([-2, 1, 1, 9])
	t.shots_per_attack_max = 0
	t.shots_per_second_max = 0
	var got := " | ".join(PackedStringArray(_codes(t.validate())))
	for want in [
		"gun_limits has one entry",
		"blade_limits entries",
		"shots_per_attack_max",
		"shots_per_second_max",
		"exactly one form row"
	]:
		assert_string_contains(got, want)


func test_an_unclassified_live_card_and_a_wrong_cell_are_errors() -> void:
	var defs: Array[ContentDef] = [
		_item(&"a_pattern", &"pattern"),
		_item(&"a_free", &"free"),
		_item(&"no_slot", &""),
		_item(&"no_mods", &"", [] as Array[StringName]),
		_table(
			[
				_row(&"orbs", &"", [&"a_pattern", &"a_free", &"ghost"]),
				_row(&"lab", &"a_pattern", [])
			]
		),
	]
	var got := " | ".join(PackedStringArray(_codes(AttackSlotsDefinition.cross_check(defs))))
	assert_string_contains(got, "a live wand card names its slot_category")
	assert_string_contains(got, "card a_free")
	assert_string_contains(got, "card ghost")
	assert_string_contains(got, "no live form card a_pattern")
	assert_false(got.contains("element card a_pattern"), "a Pattern cell is fine")
	var item := _item(&"bad", &"weird")
	assert_string_contains(
		" | ".join(PackedStringArray(_codes(item.validate()))), "unknown slot_category"
	)
	var trig := _item(&"trig", &"pattern")
	trig.kind = ItemDefinition.Kind.TRIGGER
	assert_string_contains(
		" | ".join(PackedStringArray(_codes(trig.validate()))), "a trigger or mutation card is free"
	)
