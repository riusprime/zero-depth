extends SceneTree
## v0.9.0 SH, HF: the three shrines and the healing fountain in the real game view (WorldViewRoot on the Ruins stage,
## the iso camera) of real floors (ShrineLab, the tests' floor 2: the first run seed whose shrine is each kind, and the
## first with a fountain), the hero standing in front so the HUD's prompt shows the price. Four shots. A tool, not a
## test. Needs a renderer:
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/shrines_shhf.gd
## Writes build/shots/v0.9.0/shhf/{shrine_fortune,shrine_blood,shrine_chaos,healing_fountain}.png.

const SIZE := Vector2i(1280, 720)
const CAMERA_M := 11.0
const OUT := "res://build/shots/v0.9.0/shhf/"
const SHOTS := ["shrine_fortune", "shrine_blood", "shrine_chaos", "healing_fountain"]

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _hud: Hud
var _frames := 0
var _k := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("shrines_shhf: renderer=%s" % RenderingServer.get_current_rendering_method())
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_next()


func _next() -> void:
	if _view != null:
		_view.queue_free()
		_hud.queue_free()
		_view = null
	_k += 1
	if _k >= SHOTS.size():
		return
	var at := Vector2.ZERO
	if SHOTS[_k] == "healing_fountain":
		_world = ShrineLab.with_fountain()
		if _world != null:
			at = _world.shrine.fountain_pos
	else:
		_world = ShrineLab.with_kind(_k)  # ShrineTable.Kind: Fortune 0, Blood 1, Chaos 2
		if _world != null:
			at = _world.gamble_pos
	if _world == null:
		push_error("shrines_shhf: no floor for %s" % SHOTS[_k])
		_next()
		return
	ShrineLab.stand_by(_world, at)
	_world.shards = 200
	if SHOTS[_k] == "healing_fountain":
		_world.actors.hp[0] = _world.actors.max_hp[0] / 3
	_world.step(InputFrame.new())
	var reader := WorldReader.new(_world)
	var repo := ShrineLab.repo()
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_vp.add_child(_view)
	_view.setup(reader, biome.palette, 60.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_view.rig.view_size = CAMERA_M
	_view.rig.camera.size = CAMERA_M
	_view.rig.snap_to(SimPlane.to_3d(at))
	_hud = Hud.new()
	_vp.add_child(_hud)
	_hud.sync(reader)
	_frames = 0
	print(
		(
			"shrines_shhf: %s seed=%d at=%s prompt=%s args=%s"
			% [
				SHOTS[_k],
				_world.seed_value,
				at,
				reader.interact_prompt_key(),
				reader.interact_prompt_args()
			]
		)
	)


func _process(_delta: float) -> bool:
	if _k >= SHOTS.size():
		return true
	if _view == null:
		return false
	_frames += 1
	_view.sync()
	_hud.sync(WorldReader.new(_world))
	if _frames < 40:
		return false
	var path: String = OUT + String(SHOTS[_k]) + ".png"
	_vp.get_texture().get_image().save_png(path)
	print("shrines_shhf: ", path)
	_next()
	return _k >= SHOTS.size()
