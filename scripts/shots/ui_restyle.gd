extends SceneTree
## v0.5.5 Step UI screenshots (needs a renderer, not --headless): the A5 restyle in the real game. The HUD in B
## "Ember stone" (minimap with no black background) and the pause menu and main menu in C "Cold glass".
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/ui_restyle.gd
## (repeat with --resolution 1280x720; the files carry the window size). Writes to build/shots/v0.5.5/ui/:
##   ui_hud_<lang>_<w>x<h>.png   - a run from the menu (Enter, Enter), posed by the script (a tool, not a test: HP
##                                 set to 72 %, Overclock heat at Hot, Blink granted, the hero can't be hurt);
##   ui_pause_<lang>_<w>x<h>.png - the pause menu opened with Esc over that run;
##   ui_options_en_<w>x<h>.png   - Options opened from that pause menu (Down, Down, Enter);
##   ui_menu_<lang>_<w>x<h>.png  - the main menu.
## Evidence copies are made by hand.

const OUT := "res://build/shots/v0.5.5/ui/"
const HEAT := 58

var _main: Main
var _frame := 0
var _size := ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("ui: renderer=%s" % RenderingServer.get_current_rendering_method())
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
		var w := _main.driver.world
		if _frame > 40 and w.heat != null:
			w.heat.milli = HEAT * HeatTable.MILLI  # shot setup: hold the heat at Hot
			w.heat.idle = 0
	match _frame:
		10, 20:
			_tap(KEY_ENTER)  # Play, then Blade
		40:
			_pose()
		100:
			_shot("ui_hud_en_" + _size)
			TranslationServer.set_locale("es")
		130:
			_shot("ui_hud_es_" + _size)
			_tap(KEY_ESCAPE)
		170:
			_shot("ui_pause_es_" + _size)
			_tap(KEY_ESCAPE)
			TranslationServer.set_locale("en")
		180:
			_tap(KEY_ESCAPE)
		220:
			_shot("ui_pause_en_" + _size)
		222, 224:
			_tap(KEY_DOWN)  # to Options
		226:
			_tap(KEY_ENTER)
		270:
			_shot("ui_options_en_" + _size)
			_main.show_main_menu()
		310:
			_shot("ui_menu_en_" + _size)
			TranslationServer.set_locale("es")
		340:
			_shot("ui_menu_es_" + _size)
			TranslationServer.set_locale("en")
			quit(0)
	return false


func _pose() -> void:
	var w := _main.driver.world
	w.actors.hp[0] = w.actors.max_hp[0] * 72 / 100
	if w.heat == null:
		var repo := ContentRepository.load_all()
		Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	w.heat.milli = HEAT * HeatTable.MILLI
	w.heat.idle = 0
	for i in w.ability_tables.size():
		if w.ability_tables[i].kind == AbilityTable.Kind.BLINK:
			Abilities.grant(w, i)
	print(
		(
			"ui: posed hp %d / %d, abilities %d"
			% [w.actors.hp[0], w.actors.max_hp[0], w.ability_owned.size()]
		)
	)


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + shot_name + ".png")
	print("ui: ", OUT + shot_name + ".png")


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
