extends SceneTree
## G2 "Look" mockup (v0.5.9 PLAN Step 2): the same floor (fixed run seed) in each biome, A = the pre-v0.5.9 look
## (no mood), B = the biome's lighting mood. Boots main.tscn, starts a run with keys, then rebuilds the first floor
## per biome and variant. Saves PNGs to build/shots/<version>/look/. Needs a renderer (not --headless):
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mock_look.gd
## Optional: lighting=low (B without SSAO/SSIL), biomes=ruins,red_canyon.

## Frames to let a rebuilt floor settle (shaders compile, SSAO/SSIL history fills) before the shot.
const SETTLE := 40

var _biomes: Array[StringName] = [&"ruins", &"night_rocks", &"red_canyon"]

var _main: Main
var _frame := 0
var _dir := ""
var _lighting := "high"
var _jobs: Array = []
var _wait := 0
var _phase := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("lighting="):
			_lighting = arg.trim_prefix("lighting=")
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
		for variant in ["A", "B"]:
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
			if _wait <= 0:
				var job: Array = _jobs.pop_front()
				_shot("%s_%s_%s" % [job[1], job[0], _lighting])
				_phase = 1
	return false


## Rebuilds the run's first floor in `biome`, with its mood (B) or without (A).
func _build(biome: StringName, variant: String) -> void:
	var def: BiomeDefinition = load("res://data/biomes/%s.tres" % biome)
	var mood := def.mood
	if variant == "A":
		def.mood = null
	_main._end_floor()
	_main._run_biomes = [biome, biome, biome, biome] as Array[StringName]
	_main._start_floor()
	def.mood = mood


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _shot(name: String) -> void:
	var path := _dir + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("mock_look: ", path)
