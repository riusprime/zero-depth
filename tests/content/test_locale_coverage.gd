extends GutTest
## EI-10: every visible string is a key in locale/strings.csv with both en and es (CONTENT_SCHEMA §10).

const CSV := "res://locale/strings.csv"
const KEY_RE := "^(UI|ITEM|ENEMY|BIOME|HINT|CREDITS)_[A-Z0-9_]+$"


func _table() -> Dictionary:
	var out := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	var header := f.get_csv_line()
	assert_eq(Array(header), ["keys", "en", "es"], "CSV columns")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			out[row[0]] = row
	return out


func test_every_row_has_en_and_es() -> void:
	for key: String in _table():
		var row: PackedStringArray = _table()[key]
		assert_false(row[1].strip_edges().is_empty(), "%s has en" % key)
		assert_false(row[2].strip_edges().is_empty(), "%s has es" % key)


func test_every_key_literal_in_src_exists() -> void:
	var table := _table()
	var key := RegEx.create_from_string(KEY_RE)
	var literal := RegEx.create_from_string('"([A-Z][A-Z0-9_]+)"')
	var found := 0
	for path in GdSource.files_under("res://src"):
		for m in literal.search_all(GdSource.read(path)):
			var k := m.get_string(1)
			if key.search(k) != null and not k.ends_with("_"):  # "UI_OPT_" is a prefix, checked below
				found += 1
				assert_true(table.has(k), "%s uses %s" % [path, k])
	assert_gt(found, 10, "the scan found the UI keys")


func test_generated_option_keys_exist() -> void:
	var table := _table()
	for opt in GameSettings.LANGUAGES + GameSettings.FRAME_CAPS + ["on", "off"]:
		assert_true(table.has("UI_OPT_" + String(opt).to_upper()), "option %s" % opt)
	for setting in ["volume_master", "volume_music", "volume_effects"]:
		assert_true(table.has("UI_" + setting.to_upper()), setting)


func test_content_name_keys_exist() -> void:
	var table := _table()
	var repo := ContentRepository.load_all()
	for cat: String in repo.by_category:
		for id: String in repo.by_category[cat]:
			var def: Resource = repo.by_category[cat][id]
			if "name_key" in def:
				assert_true(table.has(String(def.get("name_key"))), "%s/%s name_key" % [cat, id])


func test_tscn_text_properties_are_keys() -> void:
	var table := _table()
	var re := RegEx.create_from_string('(?m)^(text|tooltip_text) = "([^"]*)"')
	for path in _tscn_under("res://src"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			assert_true(table.has(m.get_string(2)), "%s: %s" % [path, m.get_string(2)])


func _tscn_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_tscn_under(dir.path_join(d)))
	return out
