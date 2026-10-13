extends GutTest
## v0.7.5 SM (owner N8): the first-run hints' view. Every hint has its line in English and Spanish and fits its slab
## in two lines; the keys it names are the live bindings (a remap shows) of the device used last; a hint about a
## moment (the first pick) comes before a waiting first-run step, which shows again after it; the Codex hint waits for
## the second floor; Options carries "Interface size", "Show hints" and "Reset hints"; the interface size scales the
## window's content.

var _locale := ""


func before_all() -> void:
	_locale = TranslationServer.get_locale()
	InputDefaults.apply()


func after_all() -> void:
	TranslationServer.set_locale(_locale)
	InputDefaults.apply()


func _reader() -> WorldReader:
	return WorldReader.new(WandLab.world(&"blade"))


func test_every_hint_has_its_line_in_both_languages_and_fits() -> void:
	var h := OnboardingHints.new()
	add_child_autofree(h)
	h.setup(HintStore.new(ProfileStore.new("")))
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for id in HintStore.IDS:
			var key := "HINT_" + String(id).to_upper()
			assert_ne(tr(key), key, "%s: %s has a line" % [lang, key])
			for dev in [InputRebind.KBM, InputRebind.PAD]:
				h.device = dev
				var t := h.hint_text(id)
				assert_false(t.contains("%"), "%s %s: every key filled (%s)" % [lang, id, t])
				var font := h.line.get_theme_font("font")
				var size := h.line.get_theme_font_size("font_size")
				var width := OnboardingHints.W - OnboardingHints.PAD.x * 2.0
				var lines := ceili(
					CrystalCard.text_height(font, t, width, size) / font.get_height(size) - 0.01
				)
				assert_lte(lines, 2, "%s %s (%s): %d lines" % [lang, id, dev, lines])
	TranslationServer.set_locale("en")


func test_the_keys_named_are_the_live_bindings_of_the_last_device() -> void:
	var h := OnboardingHints.new()
	add_child_autofree(h)
	h.setup(HintStore.new(ProfileStore.new("")))
	TranslationServer.set_locale("en")
	assert_eq(h.hint_text(&"dash"), tr("HINT_DASH") % "[Space]")
	var p := ProfileStore.new("")
	InputRebind.rebind(p, &"dash", [&"key", KEY_J])
	assert_eq(h.hint_text(&"dash"), tr("HINT_DASH") % "[J]", "a remap shows at once")
	h.device = InputRebind.PAD
	assert_eq(h.hint_text(&"dash"), tr("HINT_DASH") % "[RB]", "the pad's button once a pad is used")
	assert_string_contains(h.hint_text(&"move"), tr("HINT_PAD_LEFT_STICK"))
	InputDefaults.apply()


func test_a_moment_comes_first_and_the_waiting_step_shows_after() -> void:
	var store := HintStore.new(ProfileStore.new(""))
	var h := OnboardingHints.new()
	add_child_autofree(h)
	h.setup(store)
	h.begin_floor(1, _reader())
	assert_eq(h.current_id(), &"move", "a first run opens with move")
	assert_eq(h.queued_ids(), [&"attack", &"dash"] as Array[StringName])
	h._moment = {&"pick": true}
	h._enqueue(&"pick")
	assert_eq(h.current_id(), &"pick", "the first pick comes first")
	assert_eq(h.queued_ids()[0], &"move", "move waits its turn again")
	assert_true(store.seen(&"pick") and store.seen(&"move"))
	h.end_floor()
	assert_false(h.visible, "no floor, no hint")
	assert_false(&"pick" in h.queued_ids())


func test_the_codex_hint_waits_for_the_second_floor() -> void:
	var store := HintStore.new(ProfileStore.new(""))
	for id in [&"move", &"attack", &"dash"]:
		store.mark(id)
	var h := OnboardingHints.new()
	add_child_autofree(h)
	h.setup(store)
	h.begin_floor(1, _reader())
	assert_eq(h.current_id(), &"", "floor 1: the first-run steps were seen; no Codex yet")
	h.end_floor()
	h.begin_floor(2, _reader())
	assert_eq(h.current_id(), &"codex", "the second floor: the Codex")
	h.set_covered(true)
	assert_eq(h.current_id(), &"", "opening the pause menu (where the Codex is) closes it")


func test_options_carry_interface_size_show_hints_and_reset_hints() -> void:
	var p := ProfileStore.new("")
	var o := OptionsMenu.new(p)
	add_child_autofree(o)
	var acc := o.sections[&"accessibility"] as Control
	for n in ["ui_scale", "hints", "ResetHints"]:
		assert_not_null(acc.find_child(n, true, false), "%s in Accessibility" % n)
	HintStore.new(p).mark(&"move")
	(acc.find_child("ResetHints", true, false) as Button).pressed.emit()
	assert_true(HintStore.new(p).due(&"move"), "Reset hints")


func test_the_interface_size_scales_the_window_content() -> void:
	var p := ProfileStore.new("")
	var root := get_tree().root
	var before := root.content_scale_factor
	assert_eq(GameSettings.get_value(p, "ui_scale"), "100", "100 % by default")
	GameSettings.set_value(p, "ui_scale", "125")
	assert_almost_eq(root.content_scale_factor, 1.25, 0.001)
	GameSettings.set_value(p, "ui_scale", "90")
	assert_almost_eq(root.content_scale_factor, 0.9, 0.001)
	GameSettings.set_value(p, "ui_scale", "100")
	assert_almost_eq(root.content_scale_factor, 1.0, 0.001)
	root.content_scale_factor = before
