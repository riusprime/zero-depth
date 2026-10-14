extends SceneTree
## v0.8.0 MU (owner O14, G2 "menu style B" shipped): screenshots of the real screens in the Ember stone look, one
## language per run (`-- --lang=en` or `-- --lang=es`). It boots main.tscn with an empty profile and no save and
## walks the real game with key presses (Input.parse_input_event):
##   main_menu    - the main menu over its own ember backdrop (nothing behind it), Play focused;
##   build_picker - Enter: the build picker (Blade focused), settled;
##   pick         - Enter (Blade), the first floor runs a few seconds with floor 3's wand of eight cards posed (as
##                  scripts/shots/wand_build.gd) and the hero kept unhurt (shot setup), then the room's first reward
##                  is opened on Frost Nova (a new ability), Ember Edge (a common mod in the wand: its level badge) and
##                  Cold Snap (a rare mod) through the sim's own choice state (shot setup), Right focuses the middle;
##   pause        - Esc leaves the pick for later, Esc pauses;
##   build        - the Build row (focus set, Enter): the Build page with the live wand, Right twice;
##   codex        - Esc back, the Codex row (focus set, Enter): the Cards page (shot setup: the profile has met most
##                  of its first two sections), then Right twice;
##   achievements - E four times: the Codex's Achievements page.
## Before the pick it grabs the world once and holds it as a still under the UI (software GL takes seconds a frame),
## so the HUD and every menu draw live over a fixed frame. A tool, not a test; it quits on every path. Needs a
## renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1920x1080 -s scripts/shots/mu2_shots.gd -- --lang=en
## Writes build/shots/v0.8.0/mu2/<screen>_<lang>.png. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.8.0/mu2/"
const EIGHT: Array[StringName] = [
	&"ember_edge",
	&"trigger_on_hit",
	&"long_edge",
	&"twin_arc",
	&"trigger_on_kill",
	&"serrated_edge",
	&"wide_arc",
	&"echo_slash",
]
const ABILITY := &"frost_nova"
const MODS: Array[StringName] = [&"ember_edge", &"cold_snap"]
const LAST_MS := 1_500_000
const RUN_MS := 6000

var _main: Main
var _lang := "en"
## `-- --menu-only`: just the main menu (a quick look at its backdrop).
var _menu_only := false
var _frame := 0
var _step := 0
var _at := 0
var _base_ms := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
		_menu_only = _menu_only or a == "--menu-only"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("mu2: renderer=%s lang=%s" % [RenderingServer.get_current_rendering_method(), _lang])
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if Time.get_ticks_msec() > LAST_MS:
		print("mu2: gave up at step %d frame %d" % [_step, _frame])
		quit(1)
		return true
	var since := _frame - _at
	match _step:
		0:
			if since == 6:
				TranslationServer.set_locale(_lang)
			if since == 14:
				_shot("main_menu")
				if _menu_only:
					quit(0)
					return true
				_tap(KEY_ENTER)  # Play
				_next()
		1:
			if since == 4:
				var picker := _find(BuildPicker) as BuildPicker
				if picker != null:
					picker.settle()
			if since == 8:
				_shot("build_picker")
				_tap(KEY_ENTER)  # Blade
				_next()
		2:
			if _main.driver == null:
				_at = _frame
				return false
			if _base_ms == 0:
				_base_ms = Time.get_ticks_msec()
				_pose()
			_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
			if since > 30 and Time.get_ticks_msec() - _base_ms > RUN_MS:
				_freeze()
				_open_pick()
				_next()
		3:
			if since == 6:
				_tap(KEY_RIGHT)
			if since == 12:
				_shot("pick")
				_tap(KEY_ESCAPE)  # leave it for later
			if since == 18:
				_tap(KEY_ESCAPE)  # pause
			if since == 26:
				_shot("pause")
				_press_row("Build")
				_next()
		4:
			if since == 8:
				_tap(KEY_RIGHT)
				_tap(KEY_RIGHT)
			if since == 14:
				_shot("build")
				_tap(KEY_ESCAPE)
			if since == 20:
				_press_row("Codex")
				_next()
		5:
			if since == 3:
				_meet_cards()
			if since == 8:
				_tap(KEY_RIGHT)
				_tap(KEY_RIGHT)
			if since == 14:
				_shot("codex")
				for k in 4:
					_tap(KEY_E)
			if since == 22:
				_shot("achievements")
				print("mu2: done")
				quit(0)
	return false


func _next() -> void:
	_step += 1
	_at = _frame


func _shot(screen: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s.png" % [screen, _lang]
	img.save_png(path)
	print("mu2: ", path, " ", img.get_size())


## Holds the world's frame as a still under the UI and stops the 3D drawing (the HUD and menus stay live).
func _freeze() -> void:
	for n in _main.find_children("*", "", true, false):
		if n is AchievementToast or n is PhaseHud:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			(n as CanvasItem).visible = false
	_main.ui.visible = false
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var still := CanvasLayer.new()
	still.layer = _main.ui.layer - 1
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(img)
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	still.add_child(tex)
	root.add_child(still)
	_main.ui.visible = true
	root.disable_3d = true


## Shot setup: the room's first reward offers the three cards and the world is choosing it (the sim's own state; the
## real PickPanel opens from it).
func _open_pick() -> void:
	var w := _main.driver.world
	if w.rewards.ids.is_empty():
		print("mu2: no reward on the floor")
		return
	var codes := PackedInt32Array([Offers.ABILITY_BASE + _ability_index(w, ABILITY)])
	for id in MODS:
		codes.append(_item_index(w, id))
	w.rewards.set_offer(0, codes)
	w.choosing = w.rewards.ids[0]


## Shot setup: the profile has met the Cards page's first two sections but every fourth card (so the page shows
## stone tablets with their pictures, and a few locked ones); the page is rebuilt from it.
func _meet_cards() -> void:
	var view := _find(CodexView) as CodexView
	if view == null:
		print("mu2: no codex")
		return
	var n := 0
	for sec: StringName in view.catalog.sections(&"cards").slice(0, 2):
		for e: Dictionary in view.catalog.section_entries(&"cards", sec):
			if n % 4 != 3:
				_main.codex.unlock(&"cards", e["id"])
				_main.codex.add(&"cards", e["id"], &"offered", 3)
				_main.codex.add(&"cards", e["id"], &"taken", 1)
			n += 1
	view.open(&"enemies")
	view.open(&"cards")


func _press_row(row: String) -> void:
	var pause := _find(PauseMenu) as PauseMenu
	if pause == null:
		print("mu2: no pause menu")
		return
	(pause.box.get_node(row) as Button).grab_focus()
	_tap(KEY_ENTER)


func _find(type: Variant) -> Node:
	for n in _main.find_children("*", "", true, false):
		if is_instance_of(n, type) and (n as CanvasItem).is_visible_in_tree():
			return n
	return null


func _pose() -> void:
	var w := _main.driver.world
	w.floor_index = 3  # shot setup: floor 3's eight slots
	w.run_floor = 3
	for id: StringName in EIGHT:
		var k := _item_index(w, id)
		if k >= 0:
			BuildSlots.take(w, k)
	print("mu2: posed %d cards in %d slots" % [w.mod_slots.size(), Wand.slots(w)])


static func _item_index(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


static func _ability_index(w: World, id: StringName) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].id == id:
			return k
	return -1


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
