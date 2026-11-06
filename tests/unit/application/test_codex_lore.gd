extends GutTest
## v0.10.5 O18: the Codex's Lore page lists its nine entries in order (O5b: and one per loop rule); four are
## open on a fresh profile, the rest
## unlock when their system is first met (CodexRecorder); each has a title and a line in both languages.

const ORDER: Array[StringName] = [
	&"depths",
	&"heat",
	&"wand",
	&"shards",
	&"curses",
	&"deep",
	&"runes",
	&"crown",
	&"ascension",
	&"rule_swift",
	&"rule_lean_mending",
	&"rule_elite_hunt",
	&"rule_shielded",
	&"rule_point_blank",
]
const OPEN: Array[StringName] = [&"depths", &"heat", &"wand", &"shards"]


func _catalog() -> CodexCatalog:
	return CodexCatalog.build(ContentRepository.load_all())


func test_the_lore_page_lists_nine_entries_in_order() -> void:
	var c := _catalog()
	var ids: Array[StringName] = []
	for e: Dictionary in c.entries(&"lore"):
		ids.append(e["id"])
	assert_eq(ids, ORDER)
	assert_eq(c.sections(&"lore"), [&"lore"] as Array[StringName])
	assert_eq(c.entry(&"lore", &"heat")["name_key"], &"LORE_HEAT_TITLE")
	assert_eq(c.entry(&"lore", &"heat")["desc_key"], &"LORE_HEAT")


func test_four_are_open_on_a_fresh_profile_and_the_rest_unlock_once() -> void:
	var c := _catalog()
	var store := CodexStore.new(ProfileStore.new(""))
	for id in ORDER:
		assert_eq(store.is_unlocked(&"lore", id), OPEN.has(id), "%s on a fresh profile" % id)
		assert_eq(bool(c.entry(&"lore", id)["always"]), OPEN.has(id), "%s: always" % id)
	assert_true(store.unlock(&"lore", &"curses"), "a curse taken unlocks its line")
	assert_true(store.is_unlocked(&"lore", &"curses"))
	assert_false(store.is_unlocked(&"lore", &"deep"))


func test_every_lore_line_is_translated_in_english_and_spanish() -> void:
	var c := _catalog()
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for e: Dictionary in c.entries(&"lore"):
			for k in ["name_key", "desc_key"]:
				assert_ne(tr(e[k]), String(e[k]), "%s %s in %s" % [e["id"], k, lang])
	TranslationServer.set_locale("en")
