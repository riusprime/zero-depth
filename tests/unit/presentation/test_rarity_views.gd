extends GutTest
## v0.8.0 RR (owner O33): every card shows its tier: the pick panel's and the shop's faces (PickPanel.card_face), the
## boss altar's (legendary_face keeps the card's own tier; v0.8.0 FL: no level-5 version any more) and its title,
## and the Codex's Cards entries (CodexView.tier_of / tier_text); a word on top of the colour, in en and es.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func after_each() -> void:
	TranslationServer.set_locale("en")


func _world() -> World:
	var w := CardPoolSurvey.world(_repo, 4, &"gun", [])
	w.legendary_table = RunContentCompiler.compile_legendary(
		_repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	return w


func _code(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


func test_each_tier_has_its_colour_and_word() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var want := {
		&"shared_explosive": [0, "RARITY_COMMON"],
		&"wildfire": [1, "RARITY_RARE"],
		&"gun_twin": [2, "RARITY_EPIC"],
		&"chain_blast": [CardFrames.LEGENDARY_TIER, "RARITY_LEGENDARY"],
	}
	var colours := []
	for id: StringName in want:
		var face := PickPanel.card_face(self, r, _code(w, id))
		assert_eq(int(face["tier"]), want[id][0], "%s's tier" % id)
		assert_true(String(face["tier_text"]).ends_with(tr(want[id][1])), "%s says it" % id)
		colours.append(PickSlot.TIERS[int(face["tier"])])
	for a in colours.size():
		for b in range(a + 1, colours.size()):
			assert_ne(colours[a], colours[b], "four different colours")
	TranslationServer.set_locale("es")
	var es := PickPanel.card_face(self, r, _code(w, &"chain_blast"))
	assert_true(String(es["tier_text"]).ends_with("Legendaria"), "in Spanish")


func test_the_boss_altar_keeps_each_cards_tier_and_its_title_says_a_legendary() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var spread := PickPanel.legendary_face(
		self, PickPanel.card_face(self, r, _code(w, &"gun_spread"))
	)
	assert_eq(int(spread["tier"]), 0, "a common card stays common")
	assert_eq(spread["tier_text"], "Mod · Common", "v0.8.0 FL: no level-5 version")
	assert_eq(spread["level_text"], "Lv 1")
	var chain := PickPanel.legendary_face(
		self, PickPanel.card_face(self, r, _code(w, &"chain_blast"))
	)
	assert_eq(int(chain["tier"]), CardFrames.LEGENDARY_TIER, "the Legendary one in gold")
	assert_eq(chain["tier_text"], "Mod · Legendary")
	var plain := PickSlot.new(0)
	var gold := PickSlot.new(1)
	add_child_autofree(plain)
	add_child_autofree(gold)
	plain.show_card(spread)
	gold.show_card(chain)
	assert_eq(PickPanel.boss_title(self, [plain], 0), tr("PICK_TITLE_BOSS"))
	assert_eq(PickPanel.boss_title(self, [plain, gold], 0), tr("PICK_TITLE_BOSS_LEGENDARY"))
	assert_eq(
		PickPanel.boss_title(self, [plain], 2),
		tr("PICK_TITLE_BOSS_MORE") % [tr("PICK_TITLE_BOSS"), 2],
		"a later loop's extra picks"
	)


func test_the_codex_says_a_mod_cards_tier() -> void:
	var catalog := CodexCatalog.build(_repo)
	var seen := {}
	for e: Dictionary in catalog.entries(&"cards"):
		if int(e["type"]) != WorldReader.CARD_MOD:
			assert_eq(CodexView.tier_text(self, e), "", "%s: no tier word" % e["id"])
			continue
		seen[int(e["rarity"])] = true
		var word := tr(CodexView.RARITY_KEYS[int(e["rarity"])])
		assert_eq(CodexView.tier_text(self, e), word, "%s says its tier" % e["id"])
		if int(e["rarity"]) == 3:
			assert_eq(CodexView.tier_of(e), CardFrames.LEGENDARY_TIER)
	assert_eq(seen.keys().size(), 4, "the Codex holds all four tiers")
