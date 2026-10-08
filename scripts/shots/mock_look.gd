extends SceneTree
## G2 "Look" mockup (v0.5.9 PLAN Step 2): the same floor (fixed run seed) in each biome. A = the pre-v0.5.9
## look (no mood), B = the biome's lighting mood and the owner's kit, C = B pixelated. C is made in post: the B
## frame is downsampled PIXEL_FACTOR times and scaled back up nearest-neighbour, so the HUD is pixelated too
## (the real filter would render only the 3D world at low resolution and keep the HUD sharp).
## Boots main.tscn, starts a run with keys, then rebuilds the first floor
## per biome and variant. Saves PNGs to build/shots/<version>/look/. Needs a renderer (not --headless):
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mock_look.gd
## Optional: lighting=low (B without SSAO/SSIL), biomes=ruins,red_canyon, zoom=30 (the ortho camera size),
## focus=light (look at the fire nearest the start instead of the hero), focus=chest or focus=chest_open.

## Frames to let a rebuilt floor settle (shaders compile, SSAO/SSIL history fills) before the shot.
const SETTLE := 40
const PIXEL_FACTOR := 3

var _biomes: Array[StringName] = [&"ruins", &"night_rocks", &"red_canyon"]

var _main: Main
var _frame := 0
var _dir := ""
var _lighting := "high"
var _zoom := 0.0
var _focus_light := false
## focus=chest: look at a chest; focus=chest_open: and open its lid (the cosmetic opening, no sim change).
var _focus_chest := ""
var _chest: Node3D
var _tag := ""
var _jobs: Array = []
var _wait := 0
var _phase := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("lighting="):
			_lighting = arg.trim_prefix("lighting=")
		elif arg == "focus=light":
			_focus_light = true
			_tag = "_fire"
		elif arg in ["focus=chest", "focus=chest_open"]:
			_focus_chest = arg.trim_prefix("focus=")
			_tag = "_" + _focus_chest
		elif arg.begins_with("zoom="):
			_zoom = float(arg.trim_prefix("zoom="))
		elif arg.begins_with("biomes="):
			_biomes.assign(
				Array(arg.trim_prefix("biomes=").split(",")).map(
					func(b: String) -> StringName: return StringName(b)
				)
			)
	_dir = "res://build/shots/%s/look/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var profile := ProfileStore.new("")
	profile.section("settings")["lighting"] = _lighting
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for b in _biomes:
		for variant in ["A", "B", "C"]:
			_jobs.append([b, variant])


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		0:  # the main menu, then the build picker: Enter twice starts the run.
			if _frame in [10, 20]:
				_key(KEY_ENTER, true)
			elif _frame in [11, 21]:
				_key(KEY_ENTER, false)
			elif _frame == 40:
				_phase = 1
		1:
			if _jobs.is_empty():
				quit(0)
				return false
			var job: Array = _jobs.pop_front()
			_build(job[0], job[1])
			_wait = SETTLE
			_phase = 2
			_jobs.push_front(job)
		2:
			_wait -= 1
			if _wait == 12 and _focus_chest != "":
				_look_at_chest()
			# Lavapipe frames are slow: open the lid just before the shot so it is caught mid-swing.
			if (
				_wait == 1
				and _focus_chest == "chest_open"
				and _chest != null
				and _chest.has_meta(&"lid")
			):
				_main.view.rewards._opening[_chest] = 0.0
			if _wait <= 0:
				var job: Array = _jobs.pop_front()
				_shot("%s_%s_%s%s" % [job[1], job[0], _lighting, _tag], job[1] == "C")
				_phase = 1
	return false


## Rebuilds the run's first floor in `biome`, with its mood (B) or without (A).
func _build(biome: StringName, variant: String) -> void:
	var def: BiomeDefinition = load("res://data/biomes/%s.tres" % biome)
	var mood := def.mood
	if variant == "A":
		def.mood = null  # C keeps the mood: it is B, pixelated at the shot
	_main._end_floor()
	_main._run_biomes = [biome, biome, biome, biome] as Array[StringName]
	_main._start_floor()
	def.mood = mood
	if _zoom > 0.0:
		_main.view.rig.view_size = _zoom
	# focus=light: the camera stops following the hero and looks at the fire nearest the start.
	var kit := _main.view.stage.kit
	if _focus_light and kit != null and not kit.lights.is_empty():
		var rig := _main.view.rig
		var best := kit.lights[0].global_position
		for l in kit.lights:
			if l.global_position.length() < best.length():
				best = l.global_position
		rig.dead_zone_m = 1.0e6
		rig.snap_to(Vector3(best.x, 0, best.z))


func _look_at_chest() -> void:
	var rewards := _main.view.rewards
	for n: Node in rewards.get_children():
		if n is Node3D and (n as Node3D).has_meta(&"price"):
			var rig := _main.view.rig
			rig.dead_zone_m = 1.0e6
			rig.snap_to(Vector3((n as Node3D).position.x, 0, (n as Node3D).position.z))
			_chest = n as Node3D
			return


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _shot(name: String, pixelate := false) -> void:
	var path := _dir + name + ".png"
	var img := root.get_texture().get_image()
	if pixelate:
		var w := img.get_width()
		var h := img.get_height()
		img.resize(w / PIXEL_FACTOR, h / PIXEL_FACTOR, Image.INTERPOLATE_BILINEAR)
		img.resize(w, h, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("mock_look: ", path)
