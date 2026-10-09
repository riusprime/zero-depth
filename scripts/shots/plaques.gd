extends SceneTree
## v0.6.1 PQ screenshots (needs a renderer, not --headless): the owner's crystal plaques and the build picker art.
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/plaques.gd
## (repeat with --resolution 1280x720; the files carry the window size). Writes to build/shots/v0.6.1/plaques/:
##   01_build_<lang>_<w>x<h>.png   - the real build picker opened with Enter from the main menu, English then Spanish;
##   02_hud_<lang>_<w>x<h>.png     - over the main menu: the item plaque (a long ability sentence), the combo
##                                    plaque, the shrine plaque and the phase banner, filled directly;
##   03_event_<lang>_<w>x<h>.png   - an event panel (Blood Price, a cursed choice) from the test lab's world;
##   04_shop_<lang>_<w>x<h>.png    - the shop's service and salvage plaques, filled directly.
## A tool, not a test: the real input paths are tests/e2e. Evidence copies are made by hand. It quits on every path
## (a frame cap ends it if a step never happens).

const OUT := "res://build/shots/v0.6.1/plaques/"
const MAX_FRAMES := 900

var _main: Main
var _frame := 0
var _size := ""
var _built: Array[Node] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("plaques: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _size.is_empty():
		var s := root.get_window().size
		_size = "%dx%d" % [s.x, s.y]
	match _frame:
		10:
			_tap(KEY_ENTER)  # Play
		80:
			_shot("01_build_en_" + _size)
			TranslationServer.set_locale("es")
		110:
			_shot("01_build_es_" + _size)
			TranslationServer.set_locale("en")
		120:
			_tap(KEY_ESCAPE)  # back to the main menu: the overlays below need no run (a light renderer load)
		170:
			_build_hud("en")
		200:
			_shot("02_hud_en_" + _size)
			_clear()
			TranslationServer.set_locale("es")
			_build_hud("es")
		230:
			_shot("02_hud_es_" + _size)
			_clear()
			TranslationServer.set_locale("en")
			_build_event()
		260:
			_shot("03_event_en_" + _size)
			_clear()
			TranslationServer.set_locale("es")
			_build_event()
		290:
			_shot("03_event_es_" + _size)
			_clear()
			TranslationServer.set_locale("en")
			_build_shop()
		320:
			_shot("04_shop_en_" + _size)
			_clear()
			TranslationServer.set_locale("es")
			_build_shop()
		350:
			_shot("04_shop_es_" + _size)
			_clear()
			TranslationServer.set_locale("en")
			quit(0)
	if _frame > MAX_FRAMES:
		print("plaques: frame cap reached")
		quit(1)
	return false


func _ui() -> Node:
	return _main.get_node("UI")


func _add(n: Node) -> void:
	_ui().add_child(n)
	_built.append(n)


func _build_hud(_lang: String) -> void:
	var w := EventLab.world(4242)
	var r := WorldReader.new(w)
	var item := ItemCard.new()
	_add(item)
	var blink := Offers.ability_code(Abilities.index_of_kind(w, AbilityTable.Kind.BLINK))
	var face := PickPanel.card_face(item, r, blink)
	item.show_item(
		face["id"],
		face["title"],
		face["sentence"],
		face["color"],
		tr("HUD_PICKED_UP"),
		Plaques.of_card(face["id"], int(face["type"]), int(face["tier"]))
	)
	item.place_bottom_centre(-196)
	var combo := ComboCard.new()
	_add(combo)
	var defs := ContentRepository.load_all().all_of(&"combos")
	var c: Resource = defs[0]
	var a: StringName = c.item_a if c.item_a != &"" else c.ability_a
	var b: StringName = c.item_b if c.item_b != &"" else c.ability_b
	combo.show_combo(c.id, a, b, tr(c.name_key), tr(c.desc_key), tr("UI_COMBO_UNLOCKED"))
	combo.place_bottom_centre(-196 - item.plaque_height() - 10)
	var gamble := GambleCard.new()
	_add(gamble)
	gamble.set_anchors_preset(Control.PRESET_CENTER_TOP)
	gamble.position = Vector2(root.get_visible_rect().size.x * 0.5 + 300, 260)
	gamble.play(
		[&"heat_capacity"] as Array[StringName],
		&"heat_capacity",
		GambleIcons.line(gamble, &"heat_capacity", 60)
	)
	gamble.finish_spin()
	var phase := PhaseHud.new()
	_add(phase)
	phase.visible = true
	phase.phase_label.text = tr("PHASE_STIR")
	phase.announce.text = tr("HUD_NEW_ENEMY") % tr("ENEMY_SNIPER")
	phase.announce.visible = true
	phase.banner.visible = true
	phase.set_process(false)


func _build_event() -> void:
	var w := EventLab.world(4242, 1, &"blade", [&"withering"])
	EventLab.set_event(w, &"blood_price")
	EventLab.open(w)
	var panel := EventPanel.new()
	panel.input_enabled = false
	_add(panel)
	panel.sync(WorldReader.new(w))
	print("plaques: event cards %d" % panel.card_count())


func _build_shop() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_add(dim)
	_add(holder)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	holder.add_child(col)
	var services := HBoxContainer.new()
	services.add_theme_constant_override("separation", 16)
	col.add_child(services)
	var heal := ShopTile.new("Heal", 360.0)
	var reroll := ShopTile.new("Reroll", 360.0)
	var cleanse := ShopTile.new("Cleanse", 360.0)
	for t: ShopTile in [heal, reroll, cleanse]:
		services.add_child(t)
	heal.show_tile(
		tr("SHOP_HEAL") % 30,
		tr("SHOP_HEAL_FULL"),
		25,
		false,
		false,
		false,
		Color("#9CF29C"),
		Plaques.of_use(&"shop_heal")
	)
	reroll.show_tile(
		tr("SHOP_REROLL"), "", 20, true, false, false, ShardIcon.MID, Plaques.of_use(&"shop_reroll")
	)
	cleanse.show_tile(
		tr("SHOP_CLEANSE"),
		tr("CURSE_WITHERING"),
		60,
		true,
		true,
		false,
		CurseLook.COLOR,
		Plaques.of_use(&"shop_cleanse")
	)
	reroll.set_focused(true)
	var grid := GridContainer.new()
	grid.columns = ShopPanel.SALVAGE_COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	var ids := [
		&"wildfire",
		&"frost_core",
		&"vampiric_core",
		&"momentum",
		&"crit_chance",
		&"area",
		&"blink",
		&"cooldowns"
	]
	var repo := ContentRepository.load_all()
	for id: StringName in ids:
		var name_key := ""
		for kind in [&"items", &"stat_card", &"ability"]:
			for d: Resource in repo.all_of(kind):
				if d.id == id:
					name_key = d.name_key
		var t := ShopTile.new("Sell", ShopPanel.SELL_W)
		grid.add_child(t)
		t.show_tile(
			tr(name_key), tr("UI_CARD_MOD"), 12, true, false, true, Color.WHITE, Plaques.of_card(id)
		)


func _clear() -> void:
	for n in _built:
		n.queue_free()
	_built.clear()


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + shot_name + ".png")
	print("plaques: ", OUT + shot_name + ".png")


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
