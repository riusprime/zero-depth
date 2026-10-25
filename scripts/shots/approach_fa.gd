extends SceneTree
## v0.9.0 FA (owner C §3, Q18): the final approach in the real game view (WorldViewRoot: the plateau and the stair
## causeway, the purple altar, the pylons, the iso camera) of a real World built as the game builds it after the
## Ascension portal (FinalLab.approach). A tool, not a test (it moves the hero and presses for it). Needs a renderer:
##   godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/approach_fa.gd
## Writes build/shots/v0.9.0/safa/<n>_<label>.png.

## [label, camera size, the camera's centre (a share of the way from the causeway's foot to the altar), the pylons on
## before the shot, ticks into the buildup (-1: none)].
const PLAN := [
	["approach_from_the_causeway", 30.0, 0.45, 0, -1],
	["plateau_one_pylon", 24.0, 0.85, 1, -1],
	["plateau_buildup", 24.0, 1.0, 2, 120],
]
const SIZE := Vector2i(1600, 900)

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _reader: WorldReader
var _view: WorldViewRoot
var _k := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/shots/v0.9.0/safa/")
	)
	print(
		(
			"approach_fa: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(_k)


func _press() -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	_world = FinalLab.approach(FinalLab.run_state(4242))
	_world.actors.invuln[0] = 1 << 20
	var f := _world.floor_layout
	for p in int(spec[3]):
		_world.actors.set_pos(0, f.pylons[p])
		_world.step(_press())
	for t in maxi(0, int(spec[4])):
		_world.step(InputFrame.new())
	var at: Vector2 = f.causeway_foot.lerp(f.altar_pos, float(spec[2]))
	if int(spec[3]) == 0:
		_world.actors.set_pos(0, at)
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var def: FinalArenaDefinition = _repo.get_def(&"final_arena", &"hollow_arena")
	_view.stage.mood = def.mood
	_view.setup(_reader, def.palette, _reader.final_arena_radius() + 4.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_view.rig.view_size = float(spec[1])
	_view.rig.camera.size = float(spec[1])
	_view.rig.snap_to(SimPlane.to_3d(at))
	_frames = 0


func _process(_delta: float) -> bool:
	_frames += 1
	_view.sync()
	if _frames < 40:
		return false
	var spec: Array = PLAN[_k]
	var img := _vp.get_texture().get_image()
	var path := "res://build/shots/v0.9.0/safa/%d_%s.png" % [_k + 1, spec[0]]
	img.save_png(path)
	print("approach_fa: ", path, " (tick ", _world.tick, ")")
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
