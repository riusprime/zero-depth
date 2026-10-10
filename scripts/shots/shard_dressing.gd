extends SceneTree
## v0.6.1 Step SD / SD2 / SD3 / SD4 shots: the crystal-shard dressing on a real generated floor, drawn by the game's own
## WorldViewRoot (the biome's v0.5.9 mood, the kit, the dresser, then the shards): the whole start room, its hero
## cluster's corner or wall, an ordinary room (SD4: the one with the most clusters, up to 400 m²) and a crystal
## room. The world is never stepped (a still floor, no enemies yet).
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
	var per_room := {}
	for c: Dictionary in shards.clusters:
		per_room[c["room"]] = per_room.get(c["room"], 0) + 1
		if c["hero"]:
			var at: Vector2 = c["foot"]
			_shots.append(["2_hero_corner", at + Vector2(3.5, -3.5), 14.0])
	var start_rect := _reader.floor_room(start)
	_shots.push_front(["1_start_room", start_rect.get_center(), 30.0])
	# SD4: an ordinary room (the one with the most clusters, not too big to frame) and a crystal room.
	var ordinary := -1
	var ordinary_best := -1
	var crystal := -1
	for c: Dictionary in shards.clusters:
		if c["crystal_room"] and crystal < 0:
			crystal = c["room"]
	for r: int in per_room:
		var rect := _reader.floor_room(r)
		if r == start or r == crystal or rect.get_area() > 400.0:
			continue
		if per_room[r] > ordinary_best:
			ordinary_best = per_room[r]
			ordinary = r
	for pick in [[ordinary, "3_ordinary_room"], [crystal, "4_crystal_room"]]:
		if pick[0] < 0:
			continue
		var rect := _reader.floor_room(pick[0])
		var fit := maxf(rect.size.x, rect.size.y) * 0.85
		_shots.append(["%s_%d" % [pick[1], pick[0]], rect.get_center(), clampf(fit, 11.0, 22.0)])
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
