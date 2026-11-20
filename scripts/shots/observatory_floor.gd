extends SceneTree
## The Starfall observatory (KitModels' ruined_observatory, half again its first height) where a real generated
## Starfall floor draws it (its pools' landmark and block cover, at most one a floor), from the game's iso camera at
## its own size, with the hero beside it for scale. The world is built as Main builds it (SaveLab.build_floor) and
## never stepped. Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/observatory_floor.gd
## Option after `--`: out=<res:// folder> (default OUT).
## SHOT CHOICE (labelled): the first run seed from SEED whose floor 1 draws the observatory. SHOT STAGING (labelled):
## the camera on it, the hero 2.5 m to its side. Writes <out>/observatory_starfall.png. Quits on every path.

const OUT := "res://build/shots/models_v0120b/focal/"
const SEED := 20261014
const SEARCH := 40
const PIECE := &"ruined_observatory"
const SETTLE := 24

var _repo: ContentRepository
var _out := OUT
var _seed := 0
var _world: World
var _view: WorldViewRoot
var _wait := -1
var _frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4).trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_repo = ContentRepository.load_all()
	_next_floor()


func _next_floor() -> void:
	if _view != null:
		_view.queue_free()
	if _seed >= SEARCH:
		print("observatory_floor: no Starfall floor drew it within %d seeds" % SEARCH)
		quit(1)
		return
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"starfall")
	_world = SaveLab.build_floor(
		SaveLab.run_state(SEED + _seed, 1, &"blade", 0, _repo), biome.id, _repo
	)
	IcePatches.place(_world, BiomeCompiler.compile_surface(biome))  # as Main
	_seed += 1
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	_view.actors.enemy_tint = biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 60.0)
	_wait = -1


## The observatory's placement on the dressed floor, or {} (SHOT STAGING, labelled: the stage's own placements are
## read to find where the dresser drew it).
func _drawn() -> Dictionary:
	for p: Dictionary in _view.stage._placements:
		if p["piece"] == PIECE:
			return p
	return {}


## The camera on the observatory, the hero beside it.
func _frame_on(xf: Transform3D) -> void:
	var at := SimPlane.to_sim(xf.origin)
	var yaw := deg_to_rad(IsoRig.YAW_DEG)  # as IsoRig.toward_camera_on_plane
	var to_cam := SimPlane.to_sim(Vector3(sin(yaw), 0, cos(yaw))).normalized()
	var side := Vector2(-to_cam.y, to_cam.x)
	_world.actors.pos_x[0] = at.x + side.x * 2.5
	_world.actors.pos_y[0] = at.y + side.y * 2.5
	_view.rig.snap_to(SimPlane.to_3d(at))
	var size := Vector3(xf.basis.x.length(), xf.basis.z.length(), xf.basis.y.length())
	print("observatory_floor: run_seed=%d floor=1 drawn %s m" % [SEED + _seed - 1, size])
	_wait = SETTLE


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 20000:
		print("observatory_floor: gave up")
		quit(1)
	elif _wait < 0:
		if _view.stage.kit != null:  # dressed
			var p := _drawn()
			if p.is_empty():
				_next_floor()
			else:
				_frame_on(p["xform"])
	else:
		_view.sync()
		_wait -= 1
		if _wait == 0:
			_save()
	return false


func _save() -> void:
	var path := _out + "observatory_starfall.png"
	var img := root.get_texture().get_image()
	if img == null or img.save_png(path) != OK:
		push_error("observatory_floor: could not save %s" % path)
		quit(1)
		return
	print("observatory_floor: ", path)
	quit(0)
