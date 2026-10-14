extends GutTest
## The pick cards (v0.5.5 A4; v0.8.0 MU: carved stone tablets, StoneCard): every card in the game has a family in
## CardFrames' one table (so its colour is chosen, not a fallback), the epic and curse rules, and every card's title
## and sentence fit the tablet in English and Spanish, at every size the game draws it (the pick, the shop, the
## Codex, the Swap), at a legible size, and the sentence never runs into the rarity gem (MENU_G2's known issue: Frost
## Nova in Spanish).

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


func test_slot_wears_its_family_colour_and_reads_its_rarity() -> void:
	var s := PickSlot.new(0)
	add_child_autofree(s)
	s.show_card(_face(&"wildfire", "Wildfire", "Kills spread burn.", 1, Offers.MOD))
	assert_eq(s.colour_id(), &"orange")
	assert_true(s.card is StoneCard, "a carved stone tablet")
	assert_eq(s.panel_box().inlay, CardFrames.tint(&"orange"), "the groove in the family's colour")
	assert_eq(s.rarity_color(), PickSlot.RARE)
	assert_eq(s.card.gem.color, PickSlot.RARE, "the carved gem carries the rarity")
	assert_eq(s.card.tier_text(), "Rare")
	s.show_curse("Cursed: +1 enemy")
	assert_eq(s.colour_id(), &"violet", "cursed: the curse colour")
	s.show_curse("")
	assert_eq(s.colour_id(), &"orange")
	var c := PickSlot.new(1)
	add_child_autofree(c)
	c.show_card(_face(&"armour", "Armour", "-5% damage taken", 0, Offers.STAT))
	assert_gt(s.card.glow_alpha(), c.card.glow_alpha(), "a rare card glows more than a common one")
	var idle := c.card.glow_alpha()
	c.set_focused(true)
	assert_gt(c.card.glow_alpha(), idle, "the focused card glows more")
	assert_eq(c.panel_box().focus, 1.0, "the focused tablet's lower edge lights up")


func test_epic_and_legendary_cards_get_the_gold_rim() -> void:
	var c := StoneCard.new(1.0)
	add_child_autofree(c)
	for tier in [0, 1, 3]:
		c.show_face(&"wildfire", "W", "s", &"fire", tier, PickSlot.TIERS[tier], "t")
		assert_eq(c.panel_box().rim.a, 0.0, "tier %d: no rim" % tier)
	for tier in [2, CardFrames.LEGENDARY_TIER]:
		c.show_face(&"wildfire", "W", "s", &"epic", tier, PickSlot.TIERS[tier], "t")
		assert_eq(c.panel_box().rim, EmberStone.GOLD, "tier %d: the gold rim" % tier)
	c.show_face(
		&"frost_nova", "F", "s", &"projectile", 3, PickSlot.ABILITY, "t", "Lv 1", Color.CYAN
	)
	assert_eq(c.socket.color, Color.CYAN, "the inlay ring wears the element's colour")
	assert_eq(c.level_text(), "Lv 1", "the level badge is kept")
	assert_true(Rect2(Vector2.ZERO, c.size).encloses(c.level_rect()), "the badge sits on the card")
	assert_false(
		c.level_rect().intersects(Rect2(c.socket.position, c.socket.size)), "clear of the socket"
	)


func test_every_card_fits_in_english_and_spanish() -> void:
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for scale: float in [PickSlot.PICK_SCALE, ShopPanel.CARD_SCALE, 1.0, 0.8]:
			var card := StoneCard.new(scale)
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
					"%s · %s" % [tr("UI_CARD_MODIFIER"), tr("RARITY_LEGENDARY")],
					tr("UI_CARD_LEVEL_UP") % [4, 5]
				)
				var where := "%s %s x%.2f" % [lang, r.id, scale]
				assert_true(card.text_fits(), "%s: the text fits the tablet" % where)
				assert_lte(
					card.desc_rect().end.y,
					card.gem_rect().position.y,
					"%s: the sentence stays above the rarity gem" % where
				)
				assert_lte(
					card.socket.position.y + card.socket.size.y,
					card.desc_rect().position.y,
					"%s: below the socket" % where
				)
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


func test_frost_nova_in_spanish_reflows_clear_of_the_gem() -> void:
	TranslationServer.set_locale("es")
	var card := StoneCard.new(PickSlot.PICK_SCALE)
	add_child_autofree(card)
	var def: Resource = load("res://data/abilities/frost_nova.tres")
	var sentence := tr(def.desc_key)
	assert_gt(sentence.length(), 150, "the long sentence MENU_G2 flagged")
	card.show_face(
		&"frost_nova", tr(def.name_key), sentence, &"projectile", 3, PickSlot.ABILITY, "x"
	)
	assert_true(card.text_fits(), "it fits")
	assert_lte(card.desc_rect().end.y, card.gem_rect().position.y, "above the gem")
	var f := HudStyle.font(false)
	var h := TextFit.text_height(f, sentence, card.desc_rect().size.x, card.desc_size)
	assert_lte(card.desc_rect().position.y + h, card.gem_rect().position.y, "its last line too")
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
