extends SceneTree
## v0.10.5 W3-O18: the menus in the Astral style, in the real game, one language per run (`-- --lang=en|es`). It boots
## main.tscn with an empty profile and no save and walks it with key presses (Input.parse_input_event):
##   main          - the main menu, Play focused;
##   options_menu  - Down, Enter: Options over Astral's own night (nothing behind), Audio's tab focused;
##   credits       - Esc, Down twice, Enter: the credits, Back focused;
##   loading       - Esc, then (shot setup: Main.show_build_picker, the hub skipped) Enter on the Blade: the load's
##                   cover with its mark;
##   pause         - the run's first floor, the hero kept unhurt (shot setup), Esc: the pause menu, Resume focused;
##   options_audio / _display / _controls / _access - Down to Options, Enter; each category in turn (Down) and Right
##                   into it: its first control focused (the master volume's slider, the window mode's field, the
##                   first binding cell, screen shake's switch);
##   recap         - Esc out of Options and the pause; shot setup: a run recap (EndPanel, killed by a Charger, with
##                   Main's recap of the run so far) over the game, Restart focused;
##   hub_pause     - en only: the hub's pause (shot setup: HubPauseMenu over the game), Resume focused.
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3o18_menus.gd -- --lang=en
## Writes build/shots/v0.10.5/w3o18/<screen>_<lang>.png.

const OUT := "res://build/shots/v0.10.5/w3o18/"
const LAST_MS := 600_000

var _main: Main
var _lang := "en"
var _frame := 0
var _step := 0
var _at := 0
var _landed := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("w3o18: renderer=%s lang=%s" % [RenderingServer.get_current_rendering_method(), _lang])
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if Time.get_ticks_msec() > LAST_MS:
		print("w3o18: gave up at step %d frame %d" % [_step, _frame])
		quit(1)
		return true
	var since := _frame - _at
	match _step:
		0:
			if since == 6:
				TranslationServer.set_locale(_lang)
			if since == 20:
				_shot("main")
				_tap(KEY_DOWN)
				_tap(KEY_ENTER)
				_next()
		1:
			if since == 12:
				_shot("options_menu")
				_tap(KEY_ESCAPE)
			if since == 20:
				_tap(KEY_DOWN)
				_tap(KEY_DOWN)
				_tap(KEY_ENTER)
			if since == 32:
				_shot("credits")
				_tap(KEY_ESCAPE)
			if since == 40:
				_main.show_build_picker()  # shot setup: the hub's walk to the portal skipped
			if since == 50:
				_tap(KEY_ENTER)
				_next()
		2:
			if since == 2:
				_shot("loading")
			if _main.driver == null or _main.driver.reader.arriving():
				return false
			_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
			_landed += 1
			if _landed == 40:
				_tap(KEY_ESCAPE)
				_next()
		3:
			_hold()
			if since == 16:
				_shot("pause")
				for k in 3:
					_tap(KEY_DOWN)
				_tap(KEY_ENTER)
			if since == 26:
				_tap(KEY_RIGHT)
			if since == 34:
				_shot("options_audio")
				_tap(KEY_ESCAPE)
				_tap(KEY_DOWN)
			if since == 40:
				_tap(KEY_RIGHT)
			if since == 48:
				_shot("options_display")
				_tap(KEY_ESCAPE)
				_tap(KEY_DOWN)
			if since == 54:
				_tap(KEY_RIGHT)
			if since == 62:
				_shot("options_controls")
				_tap(KEY_ESCAPE)
				_tap(KEY_DOWN)
			if since == 68:
				_tap(KEY_RIGHT)
			if since == 76:
				_shot("options_access")
				_tap(KEY_ESCAPE)
			if since == 82:
				_tap(KEY_ESCAPE)
			if since == 90:
				_tap(KEY_ESCAPE)  # resume
				_next()
		4:
			_hold()
			if since == 8:
				_recap()
			if since == 24:
				_shot("recap")
				if _lang != "en":
					print("w3o18: done")
					quit(0)
					return true
				_main.ui.get_node("EndPanel").queue_free()
				var hp := HubPauseMenu.new()  # shot setup: the hub's pause over the game
				_main.ui.add_child(hp)
				hp.focus_first()
			if since == 40:
				_shot("hub_pause")
				print("w3o18: done")
				quit(0)
				return true
	return false


func _next() -> void:
	_step += 1
	_at = _frame


## The hero stays unhurt while the shots are taken (shot setup).
func _hold() -> void:
	if _main.driver != null:
		_main.driver.world.actors.invuln[0] = 2


func _recap() -> void:
	var recap := _main.run_recap()
	recap["items"] = []
	var p := EndPanel.new(false, WorldReader.KIND_CHARGER, &"", recap)
	_main.ui.add_child(p)
	p.focus_first()


func _shot(screen: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s.png" % [screen, _lang]
	img.save_png(path)
	var f := root.gui_get_focus_owner()
	print("w3o18: ", path, " ", img.get_size(), " focus=", f.name if f != null else "-")


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
