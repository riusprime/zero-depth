extends SceneTree
## v0.9.0 HB (owner Q27; HUB_MOCKUPS option A, the Rune Ring; OWNER_GATES G2 in-engine shots): the real main.tscn on a
## memory-only profile, en then es: the small menu at boot, Play (an Enter press), the hub from the spawn, then the hero
## walked to the Portal Machine (a tool, not a test: it places the hero in the hub's World directly) with its prompt.
## Needs a renderer (the GPU on the owner's PC):
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/hub_shots.gd
## Writes build/shots/v0.9.0/hb/<lang>_<shot>.png (copy the ones the owner looks at into the evidence by hand).

const OUT := "res://build/shots/v0.9.0/hb/"
const LANGS: Array[String] = ["en", "es"]
## Frames to let the menu's fade and the hub's cover settle before a shot.
const SETTLE := 70

var main: Main
var _lang := 0
var _step := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_boot()


func _boot() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = LANGS[_lang]
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var path := OUT + "%s_%s.png" % [LANGS[_lang], shot_name]
	root.get_texture().get_image().save_png(path)
	print("hub_shots: ", path)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == SETTLE:
				_shot("1_menu")
				_key(KEY_ENTER)  # Play
				_next()
		1:
			if _frames == SETTLE:
				_shot("2_hub_spawn")
				var w := main.hub.driver.world
				w.actors.set_pos(0, HubLayout.to_sim(Vector2(0.0, -3.2)))
				w.vel = Vector2.ZERO
				_next()
		2:
			if _frames == SETTLE:
				_shot("3_hub_portal_machine")
				_next()
		3:
			main.queue_free()
			_lang += 1
			if _lang >= LANGS.size():
				return true
			TranslationServer.set_locale(LANGS[_lang])
			_step = 4
			_frames = 0
		4:
			if _frames == 2:
				_boot()
				_step = 0
				_frames = 0
	return false


func _next() -> void:
	_step += 1
	_frames = 0
