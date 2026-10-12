extends SceneTree
## v0.7.5 NB1 shots: Biome 4, Frozen Shore, on a real generated floor drawn by the game's own WorldViewRoot (its
## mood, look, the kit and the dresser, the shards, the ice patches the sim laid, the frozen sea past the edge): the
## start room, the room with the floor's biggest ice patch, a stretch of the floor's edge over the sea, and a wide view.
## The world is never stepped (a still floor, no enemies yet).
## Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/frozen_shore.gd
## Options after `--`: seed=<run seed> (default 20261008, whose floor 1 is Frozen Shore), floor=<index> (default 1).
## Writes build/shots/<version>/frozen_shore/. Quits on every path.

const SETTLE := 10

var _seed := 20261008
var _floor := 1
var _dir := ""
var _view: WorldViewRoot
var _reader: WorldReader
var _shots: Array = []
var _frame := 0
var _wait := 0
var _step := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.trim_prefix("seed="))
		elif a.begins_with("floor="):
			_floor = int(a.trim_prefix("floor="))
	_dir = "res://build/shots/%s/frozen_shore/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"frozen_shore")
	var w := SaveLab.floor_world(_seed, _floor)
	IcePatches.place(w, BiomeCompiler.compile_ice(biome))  # as Main (whatever biome the run drew here)
	_reader = WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	_view.actors.enemy_tint = biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(_reader, biome.palette, 60.0)
	var start := _reader.floor_room(_reader.floor_start_room())
	_shots.append(["1_start_room", start.get_center(), 26.0])
	var best := Rect2()
	for i in _reader.ice_patch_count():
		if _reader.ice_patch(i).get_area() > best.get_area():
			best = _reader.ice_patch(i)
	if best.get_area() > 0.0:
		_shots.append(["2_ice_patch", best.get_center(), 14.0])
	var b := _reader.floor_bounds()
	_shots.append(["3_shore_edge", Vector2(start.position.x - 1.0, start.get_center().y), 16.0])
	_shots.append(["4_wide", b.get_center(), maxf(b.size.x, b.size.y) * 0.75])
	print(
		(
			"frozen_shore: seed=%d floor=%d ice_patches=%d floes=%d"
			% [_seed, _floor, _reader.ice_patch_count(), _view.stage.edge.floe_count]
		)
	)


func _process(_delta: float) -> bool:
	_frame += 1
	if _view == null or _frame > 2000:
		quit(1)
		return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var shot: Array = _shots[_step]
			var path := _dir + "%s.png" % shot[0]
			var img := root.get_texture().get_image()
			if img == null or img.save_png(path) != OK:
				push_error("frozen_shore: could not save %s" % path)
				quit(1)
				return false
			print("frozen_shore: ", path)
		return false
	_step += 1
	if _step >= _shots.size():
		quit(0)
		return false
	var shot: Array = _shots[_step]
	_view.rig.view_size = shot[2]
	_view.rig.snap_to(SimPlane.to_3d(shot[1]))
	_wait = SETTLE
	return false
