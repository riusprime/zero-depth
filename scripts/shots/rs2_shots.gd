extends SceneTree
## v0.9.5 RS2 (RUNIC_STONE.md S6): the full Runic Stone, ringed by its 24 runes, with its newest line, in English:
## the real main.tscn on a memory-only profile holding all ten lines, Play, the hero placed before the stone, E,
## the glyphs fade in. Needs a renderer (the GPU on the owner's PC):
##   godot --path . --language en --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/rs2_shots.gd
## Writes build/shots/v0.9.5/rs2/en.png.

const OUT := "res://build/shots/v0.9.5/rs2/"
const SETTLE := 70

var main: Main
var _step := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "en"
	var stone := RunicStone.new(
		profile, ContentRepository.load_all().get_def(&"runic_lines", &"main")
	)
	for i in 10:
		stone.learn(StringName("r%d" % (i + 1)))
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var path := OUT + "%s.png" % shot_name
	root.get_texture().get_image().save_png(path)
	print("rs2_shots: ", path)


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
				_key(KEY_ENTER)  # Play
				_next()
		1:
			if _frames == SETTLE:
				var hub := main.hub
				var front := hub.layout.front_of(&"runic", 0.2)
				hub.driver.world.actors.set_pos(0, HubLayout.to_sim(front))
				hub.driver.world.vel = Vector2.ZERO
				_next()
		2:
			if _frames == 40:
				_key(KEY_E)
				_next()
		3:
			if _frames == 400:
				_shot("en")
				return true
	return false


func _next() -> void:
	_step += 1
	_frames = 0
