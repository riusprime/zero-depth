extends SceneTree
## v0.10.5 S15 shot (owner: "i've never seen in game a cracked wall"): main.tscn on run seed SEED (floor 1 holds a
## cracked wall: tests/e2e/test_e2e_cracked_wall.gd), the hero put 3 m out from the wall on the host side, then one shot
## from the game camera. A tool, not a test. Needs a renderer (not --headless):
##   godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/cracked_wall.gd -- seed=40
## Writes build/shots/v0.10.5/cracked_wall/cracked_wall_seed<N>.png.

const OUT := "res://build/shots/v0.10.5/cracked_wall/"

var main: Main
var seed_value := 40
var _step := 0
var _frames := 0
var _wait := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2 and kv[0] == "seed":
			seed_value = int(kv[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	Main.fixed_seed = seed_value
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_step = 1
		1:
			if main.driver != null and not main.loads.cover.showing():
				var w: World = main.driver.world
				if w.breakables == null or not w.breakables.has_crack():
					print("cracked_wall: no cracked wall on seed ", seed_value)
					quit(1)
					return true
				if (
					main.driver.reader.arrival_progress() >= 0.9
					or main.driver.reader.arrival_progress() < 0.0
				):
					CrackLab.face_wall(w, 3.0)
					_step = 2
		2:
			_wait += 1
			if _wait == 90:
				var img := root.get_texture().get_image()
				var path := OUT + "cracked_wall_seed%d.png" % seed_value
				img.save_png(path)
				print("cracked_wall: ", ProjectSettings.globalize_path(path))
				quit(0)
	return false
