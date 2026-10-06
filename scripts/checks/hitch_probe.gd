extends SceneTree
## The real-time half of T-HITCH. Without --fixed-fps, a 250 ms stall must be followed by at most
## max_physics_steps_per_frame (4) sim ticks, so the game slows down instead of skipping time, and a press
## latched before the stall is consumed exactly once.
##   godot --headless --path . -s scripts/checks/hitch_probe.gd

const STALL_MS := 250
const STALL_FRAME := 30
const END_FRAME := 60

var _driver: SimDriver
var _frame := 0
var _max_ticks := 0
var _after_stall := -1
var _dash_starts := 0
var _was_dashing := false


func _initialize() -> void:
	_driver = SimDriver.new()
	_driver.setup(World.new(1, PlayerTable.starting_values()))
	_driver.input_source = func() -> Array: return [Vector2.ZERO, Vector2.RIGHT, 1.0]
	_driver.ticked.connect(_on_tick)
	root.add_child(_driver)


func _on_tick() -> void:
	var dashing := _driver.world.is_dashing()
	if dashing and not _was_dashing:
		_dash_starts += 1
	_was_dashing = dashing


func _process(_delta: float) -> bool:
	# SceneTree._process runs after the frame's physics steps; read the count, then let SimDriver reset it.
	_frame += 1
	_max_ticks = maxi(_max_ticks, _driver.ticks_this_frame)
	if _frame == STALL_FRAME + 1:
		_after_stall = _driver.ticks_this_frame
	if _frame == STALL_FRAME:
		_driver.latch.note_pressed(InputFrame.DASH)
		OS.delay_msec(STALL_MS)
	if _frame >= END_FRAME:
		var limit: int = ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame")
		var ok := _after_stall >= 2 and _max_ticks <= limit and _dash_starts == 1
		print(
			(
				"hitch_probe: ticks after a %d ms stall = %d (limit %d, max seen %d), dash starts = %d -> %s"
				% [STALL_MS, _after_stall, limit, _max_ticks, _dash_starts, "ok" if ok else "FAIL"]
			)
		)
		quit(0 if ok else 1)
	return false
