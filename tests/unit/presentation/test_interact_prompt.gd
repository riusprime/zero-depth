extends GutTest
## v0.9.5 PR (owner L15, Q10 a): the interaction prompt. The glyph follows the device and the pad's name, the text is
## the verb (and the cost when there is one), and the prompt sits 40 px (at 1080p) under the hero.


func before_all() -> void:
	InputDefaults.apply()


func test_pad_names_choose_the_style() -> void:
	for n in [
		"DualSense Wireless Controller",
		"PS4 Controller",
		"Sony DualShock 4",
		"Wireless Controller",
		"PS5 pad"
	]:
		assert_true(InteractPrompt.is_playstation(n), n)
	for n in [
		"Xbox 360 Controller", "Xbox One Controller", "Steam Deck", "Logitech Gamepad F310", ""
	]:
		assert_false(InteractPrompt.is_playstation(n), n)


func test_xbox_pad_draws_a_coloured_letter() -> void:
	var g := InteractPrompt.glyph_spec(&"interact", true, "Xbox One Controller")
	assert_eq(g["style"], &"xbox")
	assert_eq(g["label"], "X")
	assert_eq(g["color"], InteractPrompt.XBOX[JOY_BUTTON_X][1], "blue")
	assert_eq(g["shape"], &"")


func test_playstation_pad_draws_a_shape() -> void:
	var g := InteractPrompt.glyph_spec(&"interact", true, "DualSense Wireless Controller")
	assert_eq(g["style"], &"ps")
	assert_eq(g["shape"], &"square", "pad X is the square")
	assert_eq(g["color"], InteractPrompt.PLAYSTATION[JOY_BUTTON_X][1], "pink")


func test_keyboard_draws_the_bound_key_never_a_hardcoded_one() -> void:
	var g := InteractPrompt.glyph_spec(&"interact", false, "Xbox One Controller")
	assert_eq(g["style"], &"key")
	assert_eq(g["label"], InputLabels.short_text(KitHud.key_spec_for(&"interact", false)))
	assert_eq(g["label"], "E")


func test_text_is_the_verb_then_a_cost_only_when_there_is_one() -> void:
	TranslationServer.set_locale("en")
	var reader := WorldReader.new(World.new(9, PlayerTable.starting_values()))
	var p := InteractPrompt.new()
	add_child_autofree(p)
	p.show_prompt(reader, tr("REWARD_OPEN_ALTAR"))
	assert_eq(p.text(), "Open")
	assert_false(p._cost.visible, "no cost, no tail")
	p.show_prompt(reader, tr("REWARD_OPEN_CHEST") % 40, true)
	assert_eq(p.text(), "Open · 40 ◆")
	assert_eq(p._verb.text, "Open")
	assert_eq(p._cost.text, "40 ◆")
	assert_true(p.is_poor(), "red when you cannot pay")
	p.hide_prompt()
	assert_eq(p.text(), "")


func test_it_sits_under_the_feet_scaled_with_the_screen_height() -> void:
	var at := InteractPrompt.top_left_for(Vector2(960, 500), Vector2(100, 30), 1080.0)
	assert_eq(at, Vector2(910, 540), "40 px below the feet at 1080p, centred")
	var half := InteractPrompt.top_left_for(Vector2(960, 500), Vector2(100, 30), 540.0)
	assert_eq(half.y, 520.0, "20 px at 540p")


func test_every_prompt_line_is_short_and_translated() -> void:
	for key in [
		"SHOP_PROMPT",
		"BOSS_DOOR_PROMPT",
		"APPROACH_PYLON_PROMPT",
		"TIMED_SWITCH_PROMPT",
		"TIMED_LEVER_PROMPT",
		"RUNE_PILLAR_PROMPT",
		"REWARD_OPEN_ALTAR",
		"REWARD_OPEN_CHEST",
		"REWARD_OPEN_DROP",
		"UI_GAMBLE_USE",
		"HUB_PROMPT_PORTAL",
		"UI_CURSE_ALTAR_OPEN",
	]:
		for lang in ["en", "es"]:
			TranslationServer.set_locale(lang)
			var t := TranslationServer.translate(key)
			assert_ne(t, key, "%s %s: translated" % [key, lang])
			assert_false(t.contains("[E"), "%s %s: no hardcoded key" % [key, lang])
			assert_lt(t.length(), 28, "%s %s: short" % [key, lang])
	TranslationServer.set_locale("en")
