extends SceneTree
## v0.9.0 SA shots (owner C §2, Q16): the real main.tscn on a new run, from the game camera: floor 1's arrival altar
## idle, mid-sequence (the runes orbiting through the buildup) and at the pop, chosen by the sim's own arrival progress
## (WorldReader). A tool, not a test. Needs a renderer (not --headless):
##   godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/altar_safa.gd
## Writes each shot to build/shots/v0.9.0/safa/.

const OUT := "res://build/shots/v0.9.0/safa/"
## Arrival progress marks: idle, the runes lit, the buildup mid-orbit, just after the pop.
const AT := [0.02, 0.3, 0.62, 0.75]
const NAMES := ["altar_1_idle", "altar_2_lit", "altar_3_buildup", "altar_4_pop"]

var main: Main
var _step := 0
var _frames := 0
var _mark := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"altar_safa: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + shot_name + ".png")
	print(
		"altar_safa: ",
		OUT + shot_name + ".png tick=",
		main.driver.world.tick,
		" progress=",
		main.driver.reader.arrival_progress()
	)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_step = 1
		1:
			if main.driver != null and not main.loads.cover.showing():
				var q := main.driver.reader.arrival_progress()
				if _mark < AT.size() and q >= AT[_mark]:
					_shot(NAMES[_mark])
					_mark += 1
				if _mark >= AT.size() or q < 0.0:
					quit(0)
	return false
