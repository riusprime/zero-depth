extends GutTest
## v0.9.5 EE3: an element pair turning on shows its name on the combo card (the HUD banner), the ten names and lines fit
## the plaque in English and Spanish, and a Toxic Fumes cloud is one flat quad. (The Codex lists no combos, so it lists
## no pairs either.)

var _locale := ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _world() -> World:
	var repo := ContentRepository.load_all()
	var w := FloorScenario.build(
		4,
		PlayerTable.starting_values(),
		ContentCompiler.compile_enemies(repo),
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo)
	)
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	w.pair_table = WandCompiler.pairs(repo)
	return w


func _grant(w: World, id: StringName, lv: int) -> void:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			w.add_item(k)
			CardLevels.set_level(w, k, lv)


func test_hud_shows_the_pairs_name_when_it_turns_on() -> void:
	TranslationServer.set_locale("en")
	var w := _world()
	var reader := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(reader)
	assert_true(hud.notices.is_empty())
	_grant(w, &"ember_core", 3)
	Modifiers.book(w)
	hud.sync(reader)
	assert_true(hud.notices.is_empty(), "one element: no pair")
	_grant(w, &"frost_core", 3)
	Modifiers.book(w)
	hud.sync(reader)
	await wait_process_frames(1)
	assert_eq(
		hud.notices.texts(), PackedStringArray(["Thermal Shock"]), "its name is a ticker line"
	)
	assert_eq(hud.notices.find_child("Pips", true, false).level, 3, "with its level as pips")
	assert_eq(hud.combo_badge_count(), 0, "it is a ticker line, not a combo badge")
	hud.notices.advance(NoticeTicker.PAIR_HOLD + NoticeTicker.FADE_OUT + 0.1)
	assert_true(hud.notices.is_empty(), "it goes after its time")


func test_the_ten_banners_fit_in_english_and_spanish() -> void:
	var card := ComboCard.new()
	add_child_autofree(card)
	var names := {"en": [], "es": []}
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for x in ElementPairs.COUNT:
			var cards := ElementPairs.card_ids(x)
			card.show_combo(
				ElementPairs.IDS[x],
				cards[0],
				cards[1],
				tr(ElementPairs.name_key(x)),
				tr(ElementPairs.desc_key(x)),
				tr("UI_PAIR_ON")
			)
			assert_true(card.text_fits(), "%s %s fits its plaque" % [lang, ElementPairs.IDS[x]])
			names[lang].append(tr(ElementPairs.name_key(x)))
			assert_ne(tr(ElementPairs.name_key(x)), String(ElementPairs.name_key(x)), "translated")
	assert_eq(
		names["en"],
		[
			"Thermal Shock",
			"Toxic Fumes",
			"Ignition Arc",
			"Boiling Blood",
			"Cold Circuit",
			"Black Ice",
			"Brittle",
			"Neurotoxin",
			"Arterial Arc",
			"Sepsis"
		]
	)
	assert_eq(names["es"][0], "Choque Térmico")
	assert_eq(names["es"][9], "Sepsis")


func test_a_gas_cloud_is_one_flat_quad_each() -> void:
	var w := _world()
	var view := ElementVisuals.new()
	add_child_autofree(view)
	var reader := WorldReader.new(w)
	view.sync(reader)
	assert_eq(view.cloud_count(), 0)
	w.pair_clouds = PackedInt32Array([1000, 2000, 180, 4000, 2000, 30])
	view.sync(reader)
	assert_eq(view.cloud_count(), 2, "one quad per cloud")
	w.pair_clouds = PackedInt32Array()
	view.sync(reader)
	assert_eq(view.cloud_count(), 0, "gone with the cloud")


func _item(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


## v0.9.5 EP4: the offer card of an element that would turn a pair on says so, in the pair's words.
func test_the_offer_card_names_the_pair_it_would_turn_on() -> void:
	TranslationServer.set_locale("en")
	var w := _world()
	var reader := WorldReader.new(w)
	_grant(w, &"ember_core", 1)
	Modifiers.book(w)
	var face := PickPanel.card_face(self, reader, _item(w, &"frost_core"))
	assert_eq(face.get("form_line", ""), "Pair: Thermal Shock")
	var plain := PickPanel.card_face(self, reader, _item(w, &"ember_core"))
	assert_false(plain.has("form_line"), "Fire again pairs with nothing new")


## v0.9.5 EP4: a pair that turns on at Lv 2 says so on the card and shows the big title; its badge shows its level.
func test_banner_title_and_badge_show_the_pairs_level() -> void:
	TranslationServer.set_locale("en")
	var w := _world()
	var reader := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(reader)
	_grant(w, &"ember_core", 2)
	_grant(w, &"frost_core", 2)
	Modifiers.book(w)
	hud.sync(reader)
	await wait_process_frames(2)
	assert_eq(hud.notices.texts(), PackedStringArray(["Thermal Shock"]))
	assert_eq(hud.notices.find_child("Pips", true, false).level, 2, "the level shows as pips")
	assert_null(hud.find_child("PairTitle", true, false), "no big centred title")
	var badge := hud.find_child("PairBadge0", true, false)
	assert_not_null(badge, "X1 has a badge")
	assert_eq((badge.find_child("Level", true, false) as Label).text, "Lv 2")
	assert_eq(hud.combo_badge_count(), 0, "it is not a combo badge")
