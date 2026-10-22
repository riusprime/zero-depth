extends SceneTree
## v0.8.0 RT shots (owner O12, the G2 on the first designed rooms): each designed layout on a real run floor, drawn by
## the game's own WorldViewRoot (the biome's mood and look, the kit and the dresser, the shards), seen whole from the
## game's iso camera, then a closer look. The world is never stepped (a still floor, no enemies yet).
## Needs a renderer:
##   XDG_DATA_HOME=<empty folder> xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy \
##     --resolution 1920x1080 -s scripts/shots/room_layouts.gd -- biome=ruins
## Options after `--`: biome=<id> (default ruins; the floor is drawn as that biome whatever the run drew there),
## seed=<first run seed to search from> (default 20261014), only=<layout id> (default: every layout), out=<folder under
## build/shots/v0.8.0/> (default rt; RT2's shots: out=rt2), search=<run seeds searched> (default 60).
## SHOT CHOICE (labelled): for each layout, the floor-1 rooms of `search` run seeds from `seed` on are searched and the
## room that kept the largest share of the layout's blockers (its doorways drop the rest) is shown, in whichever turn
## and mirror the generator chose; the log prints that share and the mean over every room searched, and the shot
## names the seed, room, turn and mirror. Writes
## build/shots/v0.8.0/<out>/<layout>_<biome>_{room,close}.png. Quits on every path. Evidence copies are made by hand.

const SETTLE := 12

var _out := "res://build/shots/v0.8.0/rt/"
var _search := 60

var _biome_id := &"ruins"
var _seed := 20261014
var _only := &""
var _biome: BiomeDefinition
var _targets: Array = []  # [layout id, run seed, room]
var _target := -1
var _view: WorldViewRoot
var _reader: WorldReader
var _shots: Array = []
var _step := -1
var _wait := 0
var _frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("biome="):
			_biome_id = StringName(a.trim_prefix("biome="))
		elif a.begins_with("seed="):
			_seed = int(a.trim_prefix("seed="))
		elif a.begins_with("only="):
			_only = StringName(a.trim_prefix("only="))
		elif a.begins_with("out="):
			_out = "res://build/shots/v0.8.0/%s/" % a.trim_prefix("out=")
		elif a.begins_with("search="):
			_search = int(a.trim_prefix("search="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var repo := ContentRepository.load_all()
	_biome = repo.get_def(&"biomes", _biome_id)
	if _biome == null:
		print("room_layouts: no biome ", _biome_id)
		quit(1)
		return
	var want: Array[StringName] = []
	for d: RoomLayoutDefinition in repo.all_of(&"room_layout"):
		if _only == &"" or d.id == _only:
			want.append(d.id)
	var params: FloorParams = RunSaver.floor_tables(null, repo)[&"map"]
	var best := {}  # id -> [share, seed, room]
	var sums := {}  # id -> [share sum, rooms]
	for s in _search:
		var run := SaveLab.run_state(_seed + s, 1)
		var f := FloorGenerator.generate(run.floor_seed(), params)
		for room in f.room_count():
			var id := f.layout_of(room)
			if not id in want:
				continue
			var share := _kept_share(f, params, room)
			var sum: Array = sums.get(id, [0.0, 0])
			sums[id] = [sum[0] + share, sum[1] + 1]
			if not best.has(id) or share > best[id][0]:
				best[id] = [share, _seed + s, room]
	for id: StringName in want.duplicate():
		if best.has(id):
			_targets.append([id, best[id][1], best[id][2]])
			print(
				(
					"room_layouts: %s: best kept share %.0f%% (seed %d room %d); mean %.0f%% over %d rooms"
					% [
						id,
						best[id][0] * 100.0,
						best[id][1],
						best[id][2],
						sums[id][0] * 100.0 / sums[id][1],
						sums[id][1]
					]
				)
			)
			want.erase(id)
	print(
		(
			"room_layouts: renderer=%s device=%s window=%s biome=%s targets=%s missing=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				DisplayServer.window_get_size(),
				_biome_id,
				_targets,
				want
			]
		)
	)
	if _targets.is_empty():
		quit(1)


## The share of a designed room's layout blockers the generator kept.
static func _kept_share(f: FloorLayout, params: FloorParams, room: int) -> float:
	var total := 0
	for t: RoomLayoutTable in params.room_layouts.get(RoomLayouts.key(f.room_cells[room].size), []):
		if t.id == f.layout_of(room):
			for g in t.groups:
				for p in g.pieces:
					total += 1 if p.solid else 0
	var kept := 0
	for i in range(f.slab_first, f.walls.size()):
		if (
			f.room_of(f.walls[i].bounds().get_center()) == room
			and f.piece_height(f.walls[i]) >= 0.0
		):
			kept += 1
	return float(kept) / maxf(total, 1.0)


func _next_target() -> bool:
	if _view != null:
		_view.queue_free()
		_view = null
	_target += 1
	if _target >= _targets.size():
		return false
	var t: Array = _targets[_target]
	var w := SaveLab.floor_world(int(t[1]), 1)
	IcePatches.place(w, BiomeCompiler.compile_surface(_biome))  # as Main
	_reader = WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.stage.mood = _biome.mood
	_view.stage.prop_style = _biome.id
	_view.stage.look = _biome.look
	if _biome.look != null:
		_view.actors.enemy_tint = _biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(_reader, _biome.palette, 60.0)
	var room: int = t[2]
	var r := _reader.floor_room(room)
	var f := w.floor_layout
	var stem := "%s_%s" % [t[0], _biome_id]
	print(
		(
			"room_layouts: %s seed=%d floor=1 room=%d cells=%s size=%.1fx%.1f m turn=%d mirror=%d props=%d"
			% [
				stem,
				t[1],
				room,
				f.room_cells[room].size,
				r.size.x,
				r.size.y,
				f.room_turn[room],
				f.room_mirror[room],
				f.layout_props.size()
			]
		)
	)
	_shots = [
		[stem + "_room", r.get_center(), maxf(r.size.x, r.size.y) * 0.72],
		[stem + "_close", r.get_center() + (r.position - r.get_center()) * 0.45, 14.0],
	]
	_step = -1
	return true


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 6000:
		print("room_layouts: gave up")
		quit(1)
		return false
	if _target < 0 or _step >= _shots.size():
		if not _next_target():
			quit(0)
			return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var shot: Array = _shots[_step]
			var path: String = _out + "%s.png" % shot[0]
			var img := root.get_texture().get_image()
			if img == null or img.save_png(path) != OK:
				push_error("room_layouts: could not save %s" % path)
				quit(1)
				return false
			print("room_layouts: ", path)
		return false
	_step += 1
	if _step >= _shots.size():
		return false
	var s: Array = _shots[_step]
	_view.rig.view_size = s[2]
	_view.rig.snap_to(SimPlane.to_3d(s[1]))
	_wait = SETTLE
	return false
