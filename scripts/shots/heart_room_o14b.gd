extends SceneTree
## v0.11.0 O14b (owner Q-O14b "Both"; OWNER_QUESTIONS §J N1, N2): the hidden room under the Hollow Crown's throne in
## the real game view (WorldViewRoot), of a real World built as the game builds it (FloorPlan's final approach of a run
## whose profile learned all ten Runic Stone lines), its cracked wall broken, the hero by the sealed door (its rune
## line shows): the rune slab, the pedestal with the City's Heart, the sealed door. A tool, not a test. Needs a
## renderer:
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000
##     -s scripts/shots/heart_room_o14b.gd
## Writes build/shots/v0.11.0/o14b/1_heart_room.png.

const SIZE := Vector2i(1600, 900)
const DIR := "res://build/shots/v0.11.0/o14b/"

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var repo := ContentRepository.load_all()
	var run := FinalLab.run_state(4242)
	run.heart_room = true
	var def: RunDefinition = repo.get_def(&"run", RunSaver.RUN_ID)
	var plan := FloorPlan.next_floor(run, def.biomes.duplicate(), {}, true)
	plan.repo = repo
	plan.build()
	_world = plan.world
	_world.actors.invuln[0] = 1 << 20
	for k in 400:
		_world.step(InputFrame.new())
	var f := _world.floor_layout
	_world.breakables.crack_hp = 0
	_world.breakables.crack_broken = 1
	var slab: Array[Obb] = [f.crack_wall]
	_world.remove_barriers(slab)
	_world.actors.set_pos(0, f.heart_door + Vector2(0.0, -1.4))
	_world.step(InputFrame.new())
	var reader := WorldReader.new(_world)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_view = WorldViewRoot.new()
	_view.heart_lines = repo.get_def(&"runic_lines", &"main") as RunicLinesDefinition
	_vp.add_child(_view)
	var arena: FinalArenaDefinition = repo.get_def(&"final_arena", run.table.final_arena)
	_view.stage.mood = arena.mood
	_view.setup(reader, arena.palette, reader.final_arena_radius() + 4.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_view.rig.view_size = 20.0
	_view.rig.camera.size = 20.0
	_view.rig.snap_to(SimPlane.to_3d(f.rooms[f.heart_room].get_center() + Vector2(-1.5, 0.0)))


func _process(_delta: float) -> bool:
	_frames += 1
	_view.sync()
	if _frames < 150:
		return false
	var path := DIR + "1_heart_room.png"
	_vp.get_texture().get_image().save_png(path)
	print("heart_room_o14b: ", path, " bubble=", _view.heart_room.bubble.is_open())
	return true
