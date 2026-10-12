extends GutTest
## v0.7.5 CX: every Codex entry's text is a key in locale/strings.csv with en and es (EI-10): the cards' own name and
## sentence keys, and the enemies', bosses' and biomes' Codex lines (`desc_key`, CONTENT_SCHEMA). A definition may
## leave `desc_key` empty (the page then shows no line); one it names must exist.

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


func test_every_codex_entry_names_existing_keys() -> void:
	var keys := _keys()
	var c := CodexCatalog.build(ContentRepository.load_all())
	var n := 0
	for page: StringName in CodexStore.PAGES:
		for e: Dictionary in c.entries(page):
			for field in ["name_key", "alt_name_key", "desc_key"]:
				var k := String(e.get(field, &""))
				if k.is_empty():
					continue
				n += 1
				assert_true(keys.has(k), "%s/%s %s %s" % [page, e["id"], field, k])
	assert_gt(n, 100, "the scan read the catalog")


func test_the_shipped_enemies_bosses_and_biomes_have_their_codex_line() -> void:
	var repo := ContentRepository.load_all()
	for cat: StringName in [&"enemies", &"bosses", &"biomes"]:
		for def: ContentDef in repo.all_of(cat):
			assert_ne(String(def.get("desc_key")), "", "%s/%s has a Codex line" % [cat, def.id])
