extends GutTest
## v0.6.0 Step UP (UI polish on the A5 restyle): every ability slot's key name fits its 52 px slot in English and
## Spanish (short names for mouse and pad bindings: "LMB" / "Clic izq."; long key names shrink); the shrine stats and
## threat panels wear the HUD's Ember stone on the HUD and the menus' Cold glass on the pause screen; the floor card
## and the boss name follow a language switch; the Options "Back" row is left-aligned like the categories.

const LANGS := ["en", "es"]
## Keyboard keys beyond the letters, digits and F keys (the engine names them; the long ones have short names).
const KEYS := [
	KEY_ESCAPE,
	KEY_TAB,
	KEY_BACKSPACE,
	KEY_ENTER,
	KEY_INSERT,
	KEY_DELETE,
	KEY_PAUSE,
	KEY_PRINT,
	KEY_HOME,
	KEY_END,
	KEY_LEFT,
	KEY_UP,
	KEY_RIGHT,
	KEY_DOWN,
	KEY_PAGEUP,
	KEY_PAGEDOWN,
	KEY_SHIFT,
	KEY_CTRL,
	KEY_META,
	KEY_ALT,
	KEY_CAPSLOCK,
	KEY_NUMLOCK,
	KEY_SCROLLLOCK,
	KEY_SPACE,
	KEY_KP_MULTIPLY,
	KEY_KP_DIVIDE,
	KEY_KP_SUBTRACT,
	KEY_KP_ADD,
	KEY_KP_PERIOD,
	KEY_KP_ENTER,
	KEY_QUOTELEFT,
	KEY_MINUS,
	KEY_EQUAL,
	KEY_BRACKETLEFT,
	KEY_BRACKETRIGHT,
	KEY_SEMICOLON,
	KEY_APOSTROPHE,
	KEY_COMMA,
	KEY_PERIOD,
	KEY_SLASH,
	KEY_BACKSLASH
]


func after_each() -> void:
	TranslationServer.set_locale("en")
	HudStyle.current = HudStyle.DEFAULT


## Every binding a slot can name: each mouse button, pad button and stick direction, and long keyboard keys.
func _specs() -> Array:
	var out := []
	for code: int in InputLabels.MOUSE:
		out.append([&"mouse", code])
	out.append([&"mouse", 99])  # an unnamed button
	for code: int in InputLabels.BUTTONS:
		out.append([&"button", code])
	for code: int in InputLabels.AXES:
		out.append([&"axis", code, -1.0])
		out.append([&"axis", code, 1.0])
	var codes: Array = KEYS.duplicate()
	for k in 26:
		codes.append(KEY_A + k)
	for k in 10:
		codes.append(KEY_0 + k)
		codes.append(KEY_KP_0 + k)
	for k in 12:
		codes.append(KEY_F1 + k)
	for code: int in codes:
		out.append([&"key", code])
	return out


func test_every_slot_key_name_fits_its_slot_in_both_languages() -> void:
	# The HUD is laid out on the 1920 x 1080 base canvas and scaled to the window (canvas_items, expand), so a
	# name that fits the slot at the base size fits it at 1280 x 720 and at 1920 x 1080 alike.
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080)
	for lang: String in LANGS:
		TranslationServer.set_locale(lang)
		for spec: Array in _specs():
			var t := InputLabels.short_text(spec)
			assert_false(t.is_empty(), "%s %s has a short name" % [lang, spec])
			assert_true(AbilitySlot.key_fits(t), "%s: '%s' fits the slot" % [lang, t])
	TranslationServer.set_locale("en")
	assert_eq(InputLabels.short_text([&"mouse", MOUSE_BUTTON_LEFT]), "LMB")
	assert_eq(AbilitySlot.fit_key("LMB"), AbilityHud.KEY_FONT, "a short name keeps the full size")
	TranslationServer.set_locale("es")
	assert_eq(InputLabels.short_text([&"mouse", MOUSE_BUTTON_LEFT]), "Clic izq.")
	assert_eq(AbilitySlot.fit_key("Clic izq."), AbilityHud.KEY_FONT)
	assert_lt(AbilitySlot.fit_key("Escape Escape"), AbilityHud.KEY_FONT, "a long name shrinks")
	assert_eq(InputLabels.short_text([&"key", KEY_KP_MULTIPLY]), "Kp *", "the keypad's symbols")
	# The Options list keeps the full names.
	assert_eq(InputLabels.text([&"mouse", MOUSE_BUTTON_LEFT]), "Clic izquierdo")


func test_every_short_name_is_in_both_languages() -> void:
	var rows := ReadableCause.locale_rows()
	for full: String in InputLabels.SHORT:
		var k: String = InputLabels.SHORT[full]
		assert_true(rows.has(k), "%s is in strings.csv" % k)
		if rows.has(k):
			assert_false(String(rows[k][0]).is_empty() or String(rows[k][1]).is_empty(), k)
	for key: String in InputLabels.MOUSE.values() + InputLabels.BUTTONS.values():
		assert_true(InputLabels.SHORT.has(key), "%s has a short name" % key)
	for pair: Array in InputLabels.AXES.values():
		for key: String in pair:
			assert_true(InputLabels.SHORT.has(key), "%s has a short name" % key)


func test_the_weapon_slot_names_its_key_in_full_in_both_languages() -> void:
	InputDefaults.apply()
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"blade"))
	var w := World.new(3, t)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.BLINK))
	var hud := AbilityHud.new()
	add_child_autofree(hud)
	var reader := WorldReader.new(w)
	for lang: String in LANGS:
		TranslationServer.set_locale(lang)
		hud.sync(reader)
		for k in hud.filled_count():
			var s := hud.slot(k)
			if s.key_text.is_empty():
				continue
			var f := HudStyle.font(true)
			var width := (
				f.get_string_size(s.key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, s.key_font_size()).x
			)
			assert_lte(width, AbilitySlot.KEY_W, "%s slot %d: '%s' fits" % [lang, k, s.key_text])
			assert_lte(width, s.size.x, "inside the slot")
		var expect := "Clic izq." if lang == "es" else "LMB"
		assert_eq(hud.slot(0).key_text, expect, "%s: the weapon's key (left click)" % lang)


func test_the_shrine_stats_panel_wears_the_menu_style_in_the_pause_menu() -> void:
	var hud_panel := GambleStatsPanel.new()
	add_child_autofree(hud_panel)
	assert_false(hud_panel.in_menu)
	assert_true(
		hud_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "on the HUD: an Ember stone slab"
	)
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	var stats := GambleStatsPanel.new()
	pause.add_child(stats)
	stats.place_top_right(84)
	assert_true(stats.in_menu, "in the pause menu")
	_assert_glass(stats.get_theme_stylebox("panel"), "shrine stats")
	var threat := ThreatPanel.new()
	pause.add_child(threat)
	assert_true(threat.in_menu)
	_assert_glass(threat.get_theme_stylebox("panel"), "threat")
	var hud_threat := ThreatPanel.new()
	add_child_autofree(hud_threat)
	assert_false(hud_threat.in_menu)
	assert_true(hud_threat.get_theme_stylebox("panel") is StyleBoxEmpty)


func _assert_glass(box: StyleBox, what: String) -> void:
	assert_true(box is StyleBoxFlat, "%s: a glass panel" % what)
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		var glass := MenuStyle.theme().get_stylebox("panel", "PanelContainer") as StyleBoxFlat
		assert_eq(flat.bg_color, glass.bg_color, "%s: the menus' glass fill" % what)
		assert_eq(flat.border_color, glass.border_color, "%s: the cold top edge" % what)
		assert_eq(flat.border_width_top, glass.border_width_top)


func test_the_floor_card_follows_a_language_switch() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.show_floor(2, "BIOME_RUINS")
	assert_eq(hud.floor_card_text(), "Floor 2 Ruins")
	TranslationServer.set_locale("es")
	assert_eq(hud.floor_card_text(), "Piso 2 Ruinas", "worded again")


func test_the_phase_banner_line_is_worded_in_the_language_now() -> void:
	var p := PhaseHud.new()
	add_child_autofree(p)
	var entry := PackedStringArray(["HUD_NEW_ENEMY", "ENEMY_CHARGER"])
	assert_eq(p.line(entry), "New: Charger")
	TranslationServer.set_locale("es")
	assert_eq(p.line(entry), "Nuevo: Embestidor")
	assert_eq(p.line(PackedStringArray(["PHASE_STIR", ""])), "Se agitan")


func test_the_options_back_row_is_left_aligned_like_the_categories() -> void:
	var o := OptionsMenu.new(ProfileStore.new(""))
	add_child_autofree(o)
	var back := o.find_child("Back", true, false) as Button
	assert_not_null(back)
	assert_eq(back.alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq((o.tabs[&"audio"] as Button).alignment, back.alignment)


func test_the_threat_and_shrine_rows_follow_a_language_switch() -> void:
	var w := EventLab.world(5, 1, &"blade", [&"swift_foes"])
	w.gamble_id = w.take_root()
	w.gamble_pos = Vector2(0.8, 0)
	Gamble.grant(w, GambleTable.Stat.MELEE)
	var reader := WorldReader.new(w)
	var threat := ThreatPanel.new()
	var stats := GambleStatsPanel.new()
	add_child_autofree(threat)
	add_child_autofree(stats)
	threat.sync(reader)
	stats.sync(reader)
	var curse := w.curses_owned[0]
	assert_eq(threat.row_text(0), CurseLook.line(threat, reader, curse))
	var en_curse := threat.row_text(0)
	var en_stat := stats.row_text(0)
	TranslationServer.set_locale("es")
	threat.sync(reader)
	stats.sync(reader)
	await get_tree().process_frame  # the old rows are freed
	assert_ne(threat.row_text(0), en_curse, "the curse's line is worded again")
	assert_eq(threat.row_text(0), CurseLook.line(threat, reader, curse))
	assert_ne(stats.row_text(0), en_stat, "the stat's line is worded again")
	assert_eq(stats.row_text(0), GambleIcons.line(stats, &"melee_damage", 60))


## Every name a modifier slot can hold (abilities and items), as name keys.
func _slot_name_keys() -> Array[String]:
	var out: Array[String] = []
	var repo := ContentRepository.load_all()
	for cat in [&"ability", &"items"]:
		for d: ContentDef in repo.all_of(cat):
			if "name_key" in d:
				out.append(String(d.get("name_key")))
	return out


func test_the_build_row_sits_on_an_ember_slab_and_fits_in_both_languages() -> void:
	var hud := BuildHud.new()
	add_child_autofree(hud)
	var plate := hud.find_child("BuildPlate", true, false) as HudFrame
	assert_not_null(plate, "the build row sits on a slab")
	assert_eq(plate.style, HudStyle.Style.EMBER, "Ember stone")
	# The longest weapon name next to the longest utility name stays a small row on the left of the HUD.
	var f := HudStyle.font(true)
	var r := HudStyle.font(false)
	for lang: String in LANGS:
		TranslationServer.set_locale(lang)
		var widest := 0.0
		for k: String in _slot_name_keys():
			widest = maxf(widest, f.get_string_size(tr(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
		var util := 0.0
		for k: String in ["ABILITY_BLINK", "ABILITY_AEGIS"]:
			var line := "· %s" % tr(k)
			util = maxf(util, r.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
		var row := widest + util + WorldReader.MOD_SLOTS * (BuildHud.PIP + BuildHud.GAP) + 40.0
		assert_lt(row, 700.0, "%s: the build row stays on the left (%d px)" % [lang, int(row)])


func test_the_swap_panel_wears_cold_glass_and_its_names_fit_the_tiles() -> void:
	var swap := SwapPanel.new()
	add_child_autofree(swap)
	assert_true(swap.get_child(0) is MenuBackdrop, "the game blurred and dimmed behind")
	assert_eq((swap.get_child(0) as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
	swap.call("_set_focus", SwapPanel.SKIP)
	var off := swap.tile(0).get_theme_stylebox("panel") as StyleBoxFlat
	var on := swap.tile(SwapPanel.SKIP).get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(off)
	assert_not_null(on)
	if off != null and on != null:
		assert_eq(off.bg_color, MenuStyle.PANEL, "a glass tile")
		assert_eq(on.border_color, MenuStyle.GLASS, "the focused tile's cold rim")
	# Tile names wrap by word; every word of every slot name fits a tile, in both languages.
	var f := HudStyle.font(true)
	var inner := SwapPanel.TILE.x - 16.0
	assert_gt(_slot_name_keys().size(), 20, "the abilities' and items' names")
	for lang: String in LANGS:
		TranslationServer.set_locale(lang)
		for k: String in _slot_name_keys():
			for word in tr(k).split(" ", false):
				var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				assert_lte(w, inner, "%s: '%s' (%s) fits a swap tile" % [lang, word, k])


func test_the_options_binding_cells_follow_a_language_switch() -> void:
	InputDefaults.apply()
	var o := OptionsMenu.new(ProfileStore.new(""))
	add_child_autofree(o)
	var cell := o.bind_buttons["primary/%s" % InputRebind.KBM] as Button
	assert_eq(cell.text, "Left click")
	TranslationServer.set_locale("es")
	assert_eq(cell.text, "Clic izquierdo", "worded again in Spanish")


func test_the_pause_screen_follows_a_language_switch_from_its_options() -> void:
	var w := EventLab.world(5, 1, &"blade", [&"swift_foes"])
	w.gamble_id = w.take_root()
	w.gamble_pos = Vector2(0.8, 0)
	Gamble.grant(w, GambleTable.Stat.MAX_HP)
	var reader := WorldReader.new(w)
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	pause.show_run(1, 8.0, 0, 0)
	var stats := GambleStatsPanel.new()
	var threat := ThreatPanel.new()
	pause.add_child(stats)
	pause.add_child(threat)
	stats.sync(reader)  # Main syncs them once, when the pause menu opens
	threat.sync(reader)
	assert_eq(pause.run_line.text, "Floor 1 · 00:08 · 0 kills · 0 shards")
	var en_curse := threat.row_text(0)
	TranslationServer.set_locale("es")
	await get_tree().process_frame
	assert_eq(pause.run_line.text, "Piso 1 · 00:08 · 0 bajas · 0 fragmentos", "the run line")
	assert_eq(threat.title_text(), "Amenaza 1")
	assert_ne(threat.row_text(0), en_curse, "the curse's line")
	assert_eq(stats.row_text(0), GambleIcons.line(stats, &"max_hp", 8), "the stat's line")


func test_the_threat_panel_wraps_long_lines_clear_of_the_top_plate() -> void:
	var w := EventLab.world(5, 1, &"blade", [&"swift_foes"])
	var reader := WorldReader.new(w)
	for id: StringName in [&"blood_price", &"brittle", &"glass_heart", &"tunnel_vision"]:
		Curses.add(w, EventLab.curse_index(w, id))
	var threat := ThreatPanel.new()
	add_child_autofree(threat)
	threat.place_top_left(84)
	threat.sync(reader)
	assert_eq(threat.row_count(), 5, "five curses held")
	for lang: String in LANGS:
		TranslationServer.set_locale(lang)
		threat.sync(reader)
		await get_tree().process_frame
		# The top plate is centred, 540 px wide on the 1920 px canvas: it starts at x = 690.
		assert_lt(28.0 + threat.panel_width(), 690.0, "%s: clear of the top plate" % lang)


func test_the_swap_panel_words_its_skip_again_on_a_language_switch() -> void:
	var swap := SwapPanel.new()
	add_child_autofree(swap)
	assert_eq(swap.skip_text(), "Skip")
	TranslationServer.set_locale("es")
	assert_eq(swap.skip_text(), "Saltar")
