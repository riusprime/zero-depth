extends SceneTree
## v0.9.0 MI2: the timed door with the owner's models (his iron gate as the slab, his two rune switches) in the real
## game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World with a timed door (TimedLab, the
## tests' floor). Two shots: shut, and one switch pressed (its rune lit). A tool, not a test. Needs a renderer:
##   godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/timed_door_mi2.gd
## Writes build/shots/v0.9.0/mi2/timed_door_<n>.png.

const SIZE := Vector2i(1600, 900)
const CAMERA_M := 13.0

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _k := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/shots/v0.9.0/mi2/")
	)
	print("timed_door_mi2: renderer=%s" % RenderingServer.get_current_rendering_method())
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build()


func _build() -> void:
	if _view != null:
		_view.queue_free()
	_world = TimedLab.world()
	if _world == null:
		push_error("timed_door_mi2: no timed door floor")
		quit(1)
		return
	_world.step(InputFrame.new())
	if _k == 1:
		TimedLab.switch(_world, 0)
	var reader := WorldReader.new(_world)
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_vp.add_child(_view)
	_view.setup(reader, biome.palette, 60.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_view.rig.view_size = CAMERA_M
	_view.rig.camera.size = CAMERA_M
	_view.rig.snap_to(SimPlane.to_3d(reader.timed_door_center()))
	_frames = 0


func _process(_delta: float) -> bool:
	if _view == null:
		return true
	_frames += 1
	_view.sync()
	if _frames < 40:
		return false
	var path := "res://build/shots/v0.9.0/mi2/timed_door_%d.png" % (_k + 1)
	_vp.get_texture().get_image().save_png(path)
	print("timed_door_mi2: ", path)
	_k += 1
	if _k >= 2:
		return true
	_build()
	return false
