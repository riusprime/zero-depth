extends SceneTree
## v0.7.5 NB2 shots: Biome 5, Starfall, on a real generated floor drawn by the game's own WorldViewRoot (its mood,
## look, the kit and the dresser, the shards, the starglow pools the sim laid, the starry void past the edge): the
## start room, the room with the floor's biggest starglow pool, a stretch of the floor's edge over the void, and a
## wide view. The world is never stepped (a still floor, no enemies yet).
## Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/starfall.gd
## Options after `--`: seed=<run seed> (default 20261008), floor=<index> (default 1), biome=<id> (default starfall;
## v0.8.0 MI: night_rocks shows its moss islands; writes build/shots/<version>/<biome>/). Whatever biome the run drew
## there, the floor is drawn and laid as Starfall.
## Writes build/shots/<version>/starfall/. Quits on every path.

const SETTLE := 10

var _seed := 20261008
var _floor := 1
var _biome := &"starfall"
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
		elif a.begins_with("biome="):  # v0.8.0 MI: another biome's edge (Night Rocks' islands)
			_biome = StringName(a.trim_prefix("biome="))
	_dir = "res://build/shots/%s/%s/" % [GameVersion.label(), _biome]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", _biome)
	var w := SaveLab.floor_world(_seed, _floor)
	if biome.surface != null:
		IcePatches.place(w, BiomeCompiler.compile_surface(biome))  # as Main (whatever biome the run drew here)
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
		_shots.append(["2_starglow_pool", best.get_center(), 14.0])
	var b := _reader.floor_bounds()
	var west := Rect2(Vector2(INF, 0), Vector2.ZERO)  # the ground rect reaching farthest west: its open edge
	for r: Rect2 in _reader.floor_ground():
		if r.position.x < west.position.x:
			west = r
	_shots.append(["3_void_edge", Vector2(west.position.x, west.get_center().y), 18.0])
	_shots.append(["4_wide", b.get_center(), maxf(b.size.x, b.size.y) * 0.75])
	var e := _view.stage.edge
	if e == null:
		return
	print(
		(
			"starfall: seed=%d floor=%d pools=%d stars=%d islands=%d crystals=%d spikes=%d nebula=%d"
			% [
				_seed,
				_floor,
				_reader.ice_patch_count(),
				e.star_count,
				e.island_count,
				e.crystal_count,
				e.spike_count,
				e.nebula_count
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
				push_error("starfall: could not save %s" % path)
				quit(1)
				return false
			print("starfall: ", path)
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
