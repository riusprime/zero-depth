extends SceneTree
## v0.8.0 SR shots (owner O13): the shop room of a biome on a real run floor, drawn by the game's own WorldViewRoot
## (the biome's mood and look, the kit and the dresser, the stall and its vendor), seen whole from the game's iso
## camera, then closer on the stall. The world is never stepped (a still floor, no enemies).
## Needs a renderer:
##   XDG_DATA_HOME=<empty folder> xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/shop_rooms.gd -- biome=ruins
## Options after `--`: biome=<id> (default ruins), seed=<first run seed to search from> (default 20261014),
## standins (draw the code stand-ins: ShopModels reads no manifest, so the owner's stall is not used; shots named
## shop_<biome>_standin_*).
## SHOT CHOICE (labelled): the first run seed from `seed` on whose floor-1 shop room is at least 2 cells (so the
## dressing round the stall shows), the same seed for every biome; the floor's shop room is furnished as the asked
## biome's (SaveLab.build_floor's biome, shots only). SHOT STAGING (labelled): the player is put at the counter's
## front, so the vendor turns to it (the reach and the turn are tested in tests/unit/presentation/
## test_shop_stall_view.gd and walked to by input in tests/e2e/test_e2e_shop.gd). Writes
## build/shots/v0.8.0/sr/shop_<biome>_{room,close}.png. Quits on every path. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.8.0/sr/"
const SETTLE := 20
const SEARCH := 40

var _biome_id := &"ruins"
var _seed := 20261014
var _standins := false
var _biome: BiomeDefinition
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
		elif a == "standins":
			_standins = true
			ShopModels.manifest = "res://build/no_such_manifest.json"
			ShopModels.clear_cache()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var repo := ContentRepository.load_all()
	_biome = repo.get_def(&"biomes", _biome_id)
	if _biome == null:
		print("shop_rooms: no biome ", _biome_id)
		quit(1)
		return
	var chosen := -1
	for s in SEARCH:
		var run := SaveLab.run_state(_seed + s, 1)
		var w := SaveLab.build_floor(run, _biome_id)
		var f := w.floor_layout
		if f.shop_room >= 0 and f.shop_layout != &"":
			var cells := f.room_cells[f.shop_room].size
			if cells.x * cells.y >= 2:
				chosen = _seed + s
				_build(w)
				break
	print(
		(
			"shop_rooms: renderer=%s device=%s window=%s biome=%s seed=%d"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				DisplayServer.window_get_size(),
				_biome_id,
				chosen
			]
		)
	)
	if chosen < 0:
		quit(1)


func _build(w: World) -> void:
	IcePatches.place(w, BiomeCompiler.compile_surface(_biome))  # as Main
	var f := w.floor_layout
	var front := ShopPlacement.front(f)
	w.actors.pos_x[0] = front.x  # SHOT STAGING (labelled): the player at the counter's front
	w.actors.pos_y[0] = front.y
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
	var room := f.shop_room
	var r := _reader.floor_room(room)
	var stem := "shop_%s%s" % [_biome_id, "_standin" if _standins else ""]
	print(
		(
			"shop_rooms: %s floor=1 room=%d cells=%s size=%.1fx%.1f m layout=%s counter=%s facing=%d shop_pieces=%d tent=%s"
			% [
				stem,
				room,
				f.room_cells[room].size,
				r.size.x,
				r.size.y,
				f.shop_layout,
				f.shop_pos,
				f.shop_angle,
				f.shop_props.size(),
				"stand-in" if ShopModels.get_model(&"shop_tent").is_empty() else "owner model"
			]
		)
	)
	_shots = [
		[stem + "_room", r.get_center(), maxf(r.size.x, r.size.y) * 0.72],
		[stem + "_close", f.shop_pos, 9.0],
	]


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 3000:
		print("shop_rooms: gave up")
		quit(1)
		return false
	if _view == null:
		return false
	_view.sync()
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var shot: Array = _shots[_step]
			var path: String = OUT + "%s.png" % shot[0]
			var img := root.get_texture().get_image()
			if img == null or img.save_png(path) != OK:
				push_error("shop_rooms: could not save %s" % path)
				quit(1)
				return false
			print("shop_rooms: ", path)
		return false
	_step += 1
	if _step >= _shots.size():
		quit(0)
		return false
	var s: Array = _shots[_step]
	_view.rig.view_size = s[2]
	_view.rig.snap_to(SimPlane.to_3d(s[1]))
	_wait = SETTLE
	return false
