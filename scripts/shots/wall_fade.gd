extends SceneTree
## v0.10.5 W3-S5 shot (owner: "close to a wall the see-through effect has a ton of grain"): main.tscn on run seed SEED,
## the hero put behind the WALL-th wall nearest the start (the wall between camera and hero), then one shot from the
## game camera. A tool, not a test. Needs a renderer (not --headless):
##   godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/wall_fade.gd -- seed=40 wall=0 name=after_wall_fade
## Writes build/shots/v0.10.5/w3s5/<name>.png.

const OUT := "res://build/shots/v0.10.5/w3s5/"

var main: Main
var seed_value := 40
var wall_index := 0
var shot_name := "wall_fade"
var _step := 0
var _frames := 0
var _wait := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"seed":
				seed_value = int(kv[1])
			"wall":
				wall_index = int(kv[1])
			"name":
				shot_name = kv[1]
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
				var p := main.driver.reader.arrival_progress()
				if p >= 0.9 or p < 0.0:
					var w: World = main.driver.world
					var tc: Vector2 = main.view.rig.toward_camera_on_plane()
					var cands: Array[Obb] = []
					for o: Obb in w.floor_layout.walls:
						if maxf(o.half.x, o.half.y) > 2.0 and minf(o.half.x, o.half.y) < 1.0:
							cands.append(o)
					cands.sort_custom(
						func(a: Obb, b: Obb) -> bool:
							return (
								a.center.distance_to(w.floor_layout.start_pos)
								< b.center.distance_to(w.floor_layout.start_pos)
							)
					)
					var o: Obb = cands[wall_index]
					# Beyond the wall from the camera: the wall stands between the camera and the hero.
					var pos := o.center - tc * (minf(o.half.x, o.half.y) + 0.8)
					w.actors.set_pos(0, pos)
					w.vel = Vector2.ZERO
					print("wall_fade: wall ", wall_index, " at ", o.center, " hero ", pos)
					_step = 2
		2:
			_wait += 1
			if _wait == 120:
				var path := OUT + shot_name + ".png"
				root.get_texture().get_image().save_png(path)
				print("wall_fade: ", ProjectSettings.globalize_path(path))
				quit(0)
	return false
