extends SceneTree
## v0.9.0 LK: a sealed Lockdown in the real game view (WorldViewRoot on the floor's biome stage, the iso camera) of a
## real World (LockLab, the tests' floor 2): the hero inside, the owner's lockdown_seal bars down in the doorways, the
## first formation standing. One shot. A tool, not a test. Needs a renderer:
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/lockdown_lk.gd
## Writes build/shots/v0.9.0/lk/lockdown_sealed.png.

const SIZE := Vector2i(1280, 720)
const CAMERA_M := 16.0
const OUT := "res://build/shots/v0.9.0/lk/"

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("lockdown_lk: renderer=%s" % RenderingServer.get_current_rendering_method())
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = LockLab.world()
	if _world == null:
		push_error("lockdown_lk: no Lockdown floor")
		quit(1)
		return
	var room := LockLab.room(_world)
	LockLab.enter(_world, room)
	LockLab.to_wave(_world)
	for k in 20:
		_world.step(InputFrame.new())
	var reader := WorldReader.new(_world)
	var repo := ContentRepository.load_all()
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
	_view.rig.snap_to(SimPlane.to_3d(_world.floor_layout.rooms[room].get_center()))
	print(
		(
			"lockdown_lk: room=%d doors=%d formation=%d enemies=%d"
			% [
				room,
				_world.lockdown.barriers.size(),
				_world.lockdown.formation,
				Lockdowns.fighters(_world).size()
			]
		)
	)


func _process(_delta: float) -> bool:
	if _view == null:
		return true
	_frames += 1
	_view.sync()
	if _frames < 40:
		return false
	var path := OUT + "lockdown_sealed.png"
	_vp.get_texture().get_image().save_png(path)
	print("lockdown_lk: ", path, " bars_down=", _view.lockdowns.bars_down(LockLab.room(_world)))
	return true
