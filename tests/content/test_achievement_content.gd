extends GutTest
## v0.7.5 AC: the achievement definitions (`data/achievements/*.tres`, AchievementDefinition) are found by the
## ContentScanner, validate, name keys that exist in en and es (EI-10), and agree with the Codex they read.

const CSV := "res://locale/strings.csv"


func _keys() -> Dictionary:
	var out := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			out[row[0]] = row
	return out


func test_the_definitions_are_scanned_and_valid() -> void:
	var paths := ContentScanner.scan("res://data/achievements")
	assert_between(paths.size(), 20, 40, "about 20-30 definitions")
	var repo := ContentRepository.load_all()
	assert_eq(repo.count(&"achievements"), paths.size(), "every file is a definition")
	for def: AchievementDefinition in repo.all_of(&"achievements"):
		assert_eq(def.problems(), PackedStringArray(), "%s is valid" % def.id)
	for i in repo.errors():
		assert_false(i.path.contains("achievements"), "no error: %s %s" % [i.path, i.message])


func test_keys_exist_in_both_languages_with_the_entry_slot_where_needed() -> void:
	var keys := _keys()
	for def: AchievementDefinition in ContentRepository.load_all().all_of(&"achievements"):
		for k: StringName in [def.name_key, def.desc_key]:
			assert_true(keys.has(String(k)), "%s: %s exists" % [def.id, k])
			if not keys.has(String(k)):
				continue
			var row: PackedStringArray = keys[String(k)]
			for col in [1, 2]:
				var each := def.kind == AchievementDefinition.Kind.CODEX_EACH
				assert_eq(
					row[col].contains("%s"),
					each,
					"%s %s: a %%s for the entry's name only on a per-entry one" % [k, col]
				)


func test_the_codex_pages_counters_and_sections_match_the_codex() -> void:
	assert_eq(AchievementDefinition.CODEX_COUNTERS.keys(), CodexStore.PAGES as Array)
	for p: StringName in CodexStore.PAGES:
		assert_eq(AchievementDefinition.CODEX_COUNTERS[p], CodexStore.COUNTERS[p], String(p))
	for def: AchievementDefinition in ContentRepository.load_all().all_of(&"achievements"):
		if def.section != &"":
			assert_true(
				def.section in CodexCatalog.SECTIONS[def.page],
				"%s: section %s" % [def.id, def.section]
			)


func test_bad_definitions_are_errors() -> void:
	var d := AchievementDefinition.new()
	d.id = &"x"
	d.name_key = &"K"
	d.desc_key = &"K"
	assert_eq(d.problems().size(), 1, "a STAT with no stat")
	d.stat = &"runs:won"
	assert_eq(d.problems(), PackedStringArray())
	d.glyph = &"nope"
	d.target = 0
	assert_eq(d.problems().size(), 2, "an unknown glyph, a target of 0")
	d.glyph = &"star"
	d.target = 1
	d.kind = AchievementDefinition.Kind.CODEX_TOTAL
	d.page = &"enemies"
	d.counter = &"visits"
	assert_eq(d.problems().size(), 1, "visits is not an enemy counter")
	d.counter = &"kills"
	d.section = &"gun"
	assert_eq(d.problems().size(), 1, "a total reads no section")
	d.kind = AchievementDefinition.Kind.CODEX_EVERY
	d.counter = &""
	assert_eq(d.problems(), PackedStringArray(), "every entry met")
	d.page = &"spells"
	assert_eq(d.problems().size(), 1, "an unknown page")
	assert_false(d.validate().is_empty())
