class_name PackFxSessionWarm
extends Node
## v0.10.0 VX-W: the VFX pack's warm-up, once a session, while the main menu shows (instead of one spawn per effect
## behind every floor's loading cover, which froze the cover for 0.5 s a frame and made a load 3-4 times longer).
## - The effect scenes are requested on a loader thread at once (PackFx.request_scenes) and kept for the session
##   (PackFx keeps them: a scene that is let go takes its compiled shaders with it).
## - A tiny off-screen SubViewport with its own World3D and a camera holds a PackFx. Every STEP_FRAMES frames the
##   next id that no floor has warmed yet is spawned in front of the camera (PackFx.warm) and goes back to its pool
##   two frames later; the frame that draws it compiles its shaders and pipelines, so it is one frame in STEP_FRAMES
##   that is long, on a menu, not on a cover (N12: the cover's mark keeps moving).
## - A floor that loads before this is done warms only what is left (PackFx.pending_warm_ids).
## Cosmetic only: nothing here reads or writes the sim.

const STEP_FRAMES := 4
const VIEW_SIZE := Vector2i(96, 96)

var fx: PackFx = null
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _todo: Array[StringName] = []
var _frame := 0


## Adds the warm-up to `parent` (Main, at boot) in PackFx.warm_mode "menu", when it is wanted().
static func start(parent: Node) -> void:
	if PackFx.warm_mode == &"menu" and wanted():
		parent.add_child(PackFxSessionWarm.new())


## False without a renderer (the headless tests) or without the pack's table.
static func wanted() -> bool:
	return DisplayServer.get_name() != "headless" and PackFx.available()


func _ready() -> void:
	PackFx.request_scenes()
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = get_tree().root.msaa_3d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 8.0
	_viewport.add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 10.0, 10.0), Vector3.ZERO)
	fx = PackFx.new()
	fx.camera = _camera
	_viewport.add_child(fx)
	_todo = fx.pending_warm_ids()


func done() -> bool:
	return _todo.is_empty()


func _process(_delta: float) -> void:
	if _todo.is_empty():
		# v0.10.5 (DRAW_CALLS.md): the last effect drawn and back in its pool, the viewport stops rendering (it
		# rendered its empty world every frame of the session, a whole extra 3D pass).
		_frame += 1
		if _frame % STEP_FRAMES == 0:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			set_process(false)
		return
	_frame += 1
	if _frame % STEP_FRAMES != 0 or not PackFx.scenes_ready(_todo[0]):
		return
	var id: StringName = _todo.pop_front()
	if not PackFx.is_warmed(id):
		fx.warm(id)
