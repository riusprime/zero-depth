extends GutTest
## The crystal pick cards (v0.5.5 A4): every card in the game has a family in CardFrames' one table (so its frame
## colour is chosen, not a fallback), the epic and curse rules, and every card's title and sentence fit inside the
## frame's panel in English and Spanish, at the pick's size and the shop's, at a legible size.

const CARD_DIRS := ["res://data/items", "res://data/stat_cards", "res://data/abilities"]
## Font sizes below these (px at 1080p) count as too small to read at 1280 x 720.
const MIN_TITLE := 13
const MIN_DESC := 12

var _locale := ""


func before_all() -> void:
	_locale = TranslationServer.get_locale()


func after_all() -> void:
	TranslationServer.set_locale(_locale)


func _cards() -> Array[Resource]:
	var out: Array[Resource] = []
	for dir: String in CARD_DIRS:
		for path in ContentScanner.scan(dir):
			out.append(load(path))
	return out


func test_every_card_has_a_family_in_the_table() -> void:
	var cards := _cards()
	assert_gt(cards.size(), 40, "items, stat cards and abilities found")
	for r in cards:
		assert_true(
			CardFrames.FAMILY_OF.has(r.id), "%s has a family in CardFrames.FAMILY_OF" % r.id
		)
		assert_true(
			CardFrames.FRAME.has(CardFrames.FAMILY_OF.get(r.id, &"")), "%s: a known family" % r.id
		)


func test_the_mapping_uses_each_frame_once() -> void:
	var seen := {}
	for fam: StringName in CardFrames.FRAME:
		var f: StringName = CardFrames.FRAME[fam]
		assert_false(seen.has(f), "%s worn by one family only" % f)
		seen[f] = true
	assert_eq(CardFrames.frame_of(&"damage"), &"red")
	assert_eq(CardFrames.frame_of(&"projectile"), &"blue")
	assert_eq(CardFrames.frame_of(&"economy"), &"amber")
	assert_eq(CardFrames.frame_of(&"dash"), &"purple")
	assert_eq(CardFrames.frame_of(&"healing"), &"green")
	assert_eq(CardFrames.frame_of(&"time"), &"silver")
	assert_eq(CardFrames.frame_of(&"crit"), &"pink")
	assert_eq(CardFrames.frame_of(&"area"), &"cyan")
	assert_eq(CardFrames.frame_of(&"fire"), &"orange")
	assert_eq(CardFrames.frame_of(&"curse"), &"violet")
	assert_eq(CardFrames.frame_of(&"epic"), &"gold")
	assert_eq(CardFrames.frame_of(&"trinket"), &"indigo")


func test_epic_and_curse_rules() -> void:
	assert_eq(CardFrames.family(&"wildfire", Offers.MOD), &"fire")
	assert_eq(CardFrames.family(&"crit_chance", Offers.STAT, 2), &"epic", "an epic card wears gold")
	assert_eq(
		CardFrames.family(&"wildfire", Offers.MOD, 0, true), &"curse", "a cursed offer wears violet"
	)
	assert_eq(
		CardFrames.family(&"no_such_card", Offers.STAT), &"economy", "unknown: its type's family"
	)


func test_slot_wears_its_family_frame_and_reads_its_rarity() -> void:
	var s := PickSlot.new(0)
	add_child_autofree(s)
	s.show_card(_face(&"wildfire", "Wildfire", "Kills spread burn.", 1, Offers.MOD))
	assert_eq(s.frame_id(), &"orange")
	assert_eq(s.card.frame_texture().resource_path, CardFrames.path(&"orange"))
	assert_eq(s.rarity_color(), PickSlot.RARE)
	assert_eq(s.card.gem.color, PickSlot.RARE, "the gem icon carries the rarity")
	assert_eq(s.card.tier_text(), "Rare")
	assert_gt(s.card.glow_alpha(), 0.0, "a rare card glows")
	s.show_curse("Cursed: +1 enemy")
	assert_eq(s.frame_id(), &"violet", "cursed: the curse frame")
	s.show_curse("")
	assert_eq(s.frame_id(), &"orange")
	var c := PickSlot.new(1)
	add_child_autofree(c)
	c.show_card(_face(&"armour", "Armour", "-5% damage taken", 0, Offers.STAT))
	assert_eq(c.card.glow_alpha(), 0.0, "an unfocused common card has no glow")
	c.set_focused(true)
	assert_gt(c.card.glow_alpha(), 0.0, "the focused card glows")
	assert_true(
		CardStyle.is_plain(c.panel_box()), "the text panel keeps the cards' plain FACET box"
	)


func test_every_card_fits_in_english_and_spanish() -> void:
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for scale: float in [PickSlot.PICK_SCALE, ShopPanel.CARD_SCALE]:
			var card := CrystalCard.new(scale)
			add_child_autofree(card)
			for r in _cards():
				var sentence := tr(r.desc_key)
				if r is StatCardDefinition:
					sentence = sentence % _args(sentence)
				card.show_face(
					r.id,
					tr(r.name_key),
					sentence,
					CardFrames.family(r.id),
					1,
					PickSlot.RARE,
					tr("RARITY_RARE")
				)
				var where := "%s %s x%.2f" % [lang, r.id, scale]
				assert_true(card.text_fits(), "%s: the text fits the panel" % where)
				assert_gte(
					card.title_size,
					roundi(MIN_TITLE * scale),
					"%s: title %d px" % [where, card.title_size]
				)
				assert_gte(
					card.desc_size,
					roundi(MIN_DESC * scale),
					"%s: sentence %d px" % [where, card.desc_size]
				)
	TranslationServer.set_locale(_locale)


## Sample numbers for a stat card's "%s" slots (the widest the game shows).
func _args(fmt: String) -> Array:
	var n := fmt.count("%s")
	var out := []
	for i in n:
		out.append("40")
	return out


func _face(id: StringName, title: String, sentence: String, tier: int, type: int) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"sentence": sentence,
		"color": Color.WHITE,
		"tier": tier,
		"tier_text": ["Common", "Rare", "Epic", "New ability"][tier],
		"type": type,
	}
