class_name DebugApi
extends RefCounted
## Debug commands for the dev panel, applied at tick boundaries by SimDriver, never by touching World from a
## view (PLAN v0.0.1 Step 12). Runs touched here are dev runs.

signal reseed_requested(seed_value: int)

var world: World
var paused := false
var ticks_last_frame := 0
var _steps := 0


func _init(p_world: World) -> void:
	world = p_world


func toggle_pause() -> void:
	paused = not paused


## Queue exactly one tick while paused.
func request_step() -> void:
	paused = true
	_steps += 1


## SimDriver asks this before each tick. Returns whether to step now.
func should_step() -> bool:
	if not paused:
		return true
	if _steps > 0:
		_steps -= 1
		return true
	return false


func hash_now() -> String:
	return world.state_hash()


func reseed(seed_value: int) -> void:
	reseed_requested.emit(seed_value)
