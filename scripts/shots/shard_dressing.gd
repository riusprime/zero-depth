extends SceneTree
## v0.6.1 Step SD shots: the crystal-shard dressing on a real generated floor, drawn by the game's own WorldViewRoot
## (the biome's v0.5.9 mood, the kit, the dresser, then the shards): the start room's hero cluster, a close-up of
## it, and two ordinary rooms with small clusters. The world is never stepped (a still floor, no enemies yet).
## Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/shard_dressing.gd
## Options after `--`: seed=<run seed> (default 7), floor=<index> (default 1), biome=<id> (default ruins).
## Writes build/shots/<version>/shards/. Quits on every path (a missing floor or shard node quits with 1).

const SETTLE := 8

var _seed := 7
var _floor := 1
var _biome := &"ruins"
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
		elif a.begins_with("biome="):
			_biome = StringName(a.trim_prefix("biome="))
	_dir = "res://build/shots/%s/shards/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", _biome)
	if biome == null:
		push_error("shard_dressing: no biome %s" % _biome)
		quit(1)
		return
	var w := SaveLab.floor_world(_seed, _floor)
	_reader = WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(_reader, biome.palette, 60.0)
	var shards := _view.stage.shards
	if shards == null:
		push_error("shard_dressing: the stage built no shards")
		quit(1)
		return
	var start := _reader.floor_start_room()
	var ordinary: Array = []
	for c: Dictionary in shards.clusters:
		if c["hero"]:
			var at: Vector2 = c["foot"]
			_shots.append(["1_start_room", at + Vector2(3.0, -3.0), 15.0])
			_shots.append(["2_hero_cluster", at + Vector2(0.6, -0.4), 7.0])
		elif ordinary.size() < 2 and not ordinary.has(c["room"]):
			ordinary.append(c["room"])
			var at: Vector2 = c["foot"]
			_shots.append(
				["%d_room_%d" % [3 + ordinary.size() - 1, c["room"]], at + Vector2(2.0, -2.0), 12.0]
			)
	print(
		(
			"shard_dressing: seed=%d floor=%d biome=%s clusters=%d (hero %s) start_room=%d"
			% [
				_seed,
				_floor,
				_biome,
				shards.clusters.size(),
				shards.hero_light != null,
				start,
			]
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
				push_error("shard_dressing: could not save %s" % path)
				quit(1)
				return false
			print("shard_dressing: ", path)
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
