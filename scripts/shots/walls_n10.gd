extends SceneTree
## v0.8.0 N10 (owners O66, O67; G2): the wall styles side by side. One real generated floor (SaveLab.floor_world, the
## biome_probe's floor) drawn by the game's own WorldViewRoot in one biome with one wall style (ViewPrefs.wall_style),
## the camera at the game's view size stopped at the same spots every run: the start hall, the smallest room, the
## biggest room, a corner of the biggest room and the start hall's first doorway. Each spot's frame is saved to
## build/shots/n10/<walls>/<biome>_<spot>.png (scripts/shots/n10_sheet.py puts the styles side by side). Needs a
## renderer (xvfb-run with a software Vulkan device in a container):
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/walls_n10.gd \
##     -- walls=old|a|b [biome=ruins] [seed=20261008] [floor=1] [settle=12] [spots=start,small,big,corner,door]
##     [grain=old] [pan=1] [tag=name]
## grain=old draws option A as it was before O68's fix (ProceduralWall.legacy_look); pan=1 also saves, per spot, the
## frame after the camera moves PAN_M along the ground (<spot>_pan.png: a two-frame difference shows shimmer); tag=
## names the output folder (default: the walls value).
## Writes only under build/. Quits on every path.

const OUT_DIR := "res://build/shots/n10"
const PAN_M := 0.13

var _biome_id := &"ruins"
var _seed := 20261008
var _floor := 1
var _settle := 12
var _walls := "old"
var _names: PackedStringArray = ["start", "small", "big", "corner", "door"]
var _pan := false
var _tag := ""
var _panned := false
var _view: WorldViewRoot
var _reader: WorldReader
var _spots: Array = []
var _spot := -1
var _wait := 0
var _guard := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("biome="):
			_biome_id = StringName(a.trim_prefix("biome="))
		elif a.begins_with("seed="):
			_seed = int(a.trim_prefix("seed="))
		elif a.begins_with("floor="):
			_floor = int(a.trim_prefix("floor="))
		elif a.begins_with("settle="):
			_settle = int(a.trim_prefix("settle="))
		elif a.begins_with("walls="):
			_walls = a.trim_prefix("walls=")
		elif a.begins_with("spots="):
			_names = a.trim_prefix("spots=").split(",", false)
		elif a == "grain=old":
			ProceduralWall.legacy_look = true
		elif a == "pan=1":
			_pan = true
		elif a.begins_with("tag="):
			_tag = a.trim_prefix("tag=")
	ViewPrefs.wall_style = StringName(_walls)
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", _biome_id)
	if biome == null:
		push_error("walls_n10: no biome %s" % _biome_id)
		quit(1)
		return
	var w := SaveLab.floor_world(_seed, _floor)
	IcePatches.place(w, BiomeCompiler.compile_surface(biome))
	_reader = WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	var b := _reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	_view.setup(_reader, biome.palette, half + 4.0)
	_view.sync()
	var ws := _view.stage.structural_wall_stats()
	print(
		(
			"walls_n10: biome=%s walls=%s style=%s wall_meshes=%d wall_tris=%d proc_build_ms=%.1f"
			% [
				_biome_id,
				_walls,
				_view.stage.wall_style,
				ws["nodes"],
				ws["tris"],
				_view.stage.wall_build_ms
			]
		)
	)
	var start := _reader.floor_start_room()
	var small := start
	var big := start
	for i in _reader.floor_room_count():
		var r := _reader.floor_room(i)
		if i == _reader.boss_room():
			continue
		if i != start and (small == start or r.get_area() < _reader.floor_room(small).get_area()):
			small = i
		if r.get_area() > _reader.floor_room(big).get_area():
			big = i
	var at := {
		"start": _reader.floor_room(start).get_center(),
		"small": _reader.floor_room(small).get_center(),
		"big": _reader.floor_room(big).get_center(),
		"corner": _reader.floor_room(big).position + Vector2(3.0, 3.0),
		"door": _door_of(start),
	}
	for n in _names:
		if at.has(n):
			_spots.append([n, at[n]])


func _door_of(room: int) -> Vector2:
	var r := _reader.floor_room(room).grow(3.0)
	for i in _reader.floor_door_count():
		var d := _reader.floor_door_rect(i)
		if r.intersects(d):
			return d.get_center()
	return _reader.floor_room(room).get_center()


func _process(_delta: float) -> bool:
	_guard += 1
	if _view == null or _guard > 5000:
		quit(1)
		return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			if _panned:
				_save(_spots[_spot][0] + "_pan")
				_panned = false
				return false
			_save(_spots[_spot][0])
			if _pan:  # the same spot, the camera a little along the ground: the next saved frame
				_view.rig.snap_to(SimPlane.to_3d(_spots[_spot][1] + Vector2(PAN_M, PAN_M * 0.5)))
				_panned = true
				_wait = 4
		return false
	_spot += 1
	if _spot >= _spots.size():
		quit(0)
		return false
	_view.rig.view_size = 17.0  # IsoRig's default: the game's own view
	_view.rig.snap_to(SimPlane.to_3d(_spots[_spot][1]))
	_wait = _settle
	return false


func _save(spot: String) -> void:
	var dir := OUT_DIR + "/" + (_tag if _tag != "" else _walls)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var img := root.get_texture().get_image()
	var path := dir + "/%s_%s.png" % [_biome_id, spot]
	if img == null or img.save_png(path) != OK:
		push_error("walls_n10: could not save " + path)
	else:
		print("shot: " + path)
