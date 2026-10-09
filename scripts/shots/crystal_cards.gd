extends SceneTree
## v0.5.5 CD screenshots (needs a renderer, not --headless): the crystal pick cards (owner's frames, A4).
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/crystal_cards.gd
## (repeat with --resolution 1280x720; the files carry the window size). Writes to build/shots/v0.5.5/cards/:
##   01_altar_<lang>_<w>x<h>.png  - a real altar opened with the interact key (shot setup: the hero is placed at
##                                   the nearest altar), in English then Spanish;
##   02_kinds_<lang>_<w>x<h>.png  - a pick filled directly with an ability card, an epic stat card and a cursed mod
##                                   (the three looks the altar above may not roll), English then Spanish;
##   03_frames_<w>x<h>.png        - the twelve frames, one card per family, over the game;
##   00_game_no_hud_<w>x<h>.png   - the same frame with the HUD hidden (the A5 mockups' background).
## A tool, not a test: the real input path is tests/e2e (test_e2e_floor, test_e2e_rewards). Evidence copies are made
## by hand.

const OUT := "res://build/shots/v0.5.5/cards/"
const LANGS := ["en", "es"]

var _main: Main
var _frame := 0
var _size := ""
var _built: Array[Node] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("cards: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _size.is_empty():
		var s := root.get_window().size
		_size = "%dx%d" % [s.x, s.y]
	if _main.driver != null:
		_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
	match _frame:
		10, 20:
			_tap(KEY_ENTER)  # Play, then Blade
		40:
			_to_altar()
		70:
			_tap(KEY_E)
		110:
			print("cards: altar open %s, title '%s'" % [_pick().is_open(), _pick().title_text()])
			_shot("01_altar_en_" + _size)
			TranslationServer.set_locale("es")
			_pick()._reward = -1  # re-render the open pick in Spanish on the next sync
		150:
			_shot("01_altar_es_" + _size)
			_tap(KEY_ESCAPE)
			TranslationServer.set_locale("en")
		170:
			_pick().visible = false
			_build_kinds()
		210:
			_shot("02_kinds_en_" + _size)
			_clear()
			TranslationServer.set_locale("es")
			_build_kinds()
		250:
			_shot("02_kinds_es_" + _size)
			_clear()
			TranslationServer.set_locale("en")
			_build_frames()
		290:
			_shot("03_frames_" + _size)
			_clear()
			(_main.get_node("UI/Hud") as Hud).visible = false
		300:
			_shot("00_game_no_hud_" + _size)  # the background for the A5 mockups (scripts/art/ui_mockups.py)
			(_main.get_node("UI/Hud") as Hud).visible = true
			quit(0)
	return false


func _pick() -> PickPanel:
	return (_main.get_node("UI/Hud") as Hud).pick_panel()


func _to_altar() -> void:
	var w := _main.driver.world
	var best := -1
	for k in w.rewards.size():
		if w.rewards.kind[k] != RewardStore.Kind.ALTAR:
			continue
		if (
			best < 0
			or (
				w.rewards.pos(k).distance_to(w.player_pos())
				< w.rewards.pos(best).distance_to(w.player_pos())
			)
		):
			best = k
	w.actors.set_pos(0, w.rewards.pos(best) + Vector2(0.5, 0.5))
	print("cards: altar %d at %s" % [best, w.rewards.pos(best)])


## A pick with an ability card, an epic stat card and a cursed mod, from the game's own tables.
func _build_kinds() -> void:
	var r: WorldReader = _main.driver.reader
	var w := _main.driver.world
	var panel := PickPanel.new()
	panel.input_enabled = false
	_main.get_node("UI").add_child(panel)
	_built.append(panel)
	panel._title.text = tr("PICK_TITLE_EPIC_ALTAR")
	panel._hint.text = tr("PICK_HINT")
	panel._count = 3
	panel.visible = true
	var codes := [
		Offers.ability_code(Abilities.index_of_kind(w, AbilityTable.Kind.BLINK)),
		Offers.stat_code(_stat_index(w, &"crit_chance"), Offers.EPIC),
		_item_index(r, &"wildfire"),
	]
	for k in 3:
		panel.slot(k).show_card(PickPanel.card_face(panel, r, codes[k]))
	if w.ev.curses.size() > 0:
		panel.slot(2).show_curse(CurseLook.line(panel, r, 0))
	panel._set_focus(1)


## One card per frame (family), twelve over the game in two rows.
func _build_frames() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.get_node("UI").add_child(dim)
	_main.get_node("UI").add_child(holder)
	_built.append(dim)
	_built.append(holder)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	holder.add_child(grid)
	var k := 0
	for fam: StringName in CardFrames.FRAME:
		var c := CrystalCard.new(0.82)
		grid.add_child(c)
		var tier := 2 if fam == &"epic" else (1 if k % 3 == 1 else 0)
		c.show_face(
			&"",
			"%s" % CardFrames.FRAME[fam],
			"%s" % fam,
			fam,
			tier,
			PickSlot.TIERS[tier],
			tr(["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC"][tier])
		)
		c.set_focused(k == 0)
		k += 1


func _stat_index(w: World, id: StringName) -> int:
	for i in w.stat_tables.size():
		if w.stat_tables[i].id == id:
			return i
	return 0


func _item_index(r: WorldReader, id: StringName) -> int:
	for i in r.item_table_count():
		if r.item_id(i) == id:
			return i
	return 0


func _clear() -> void:
	for n in _built:
		n.queue_free()
	_built.clear()


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + shot_name + ".png")
	print("cards: ", OUT + shot_name + ".png")


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
