class_name DebugApi
extends RefCounted
## Debug commands for the dev panel, applied at tick boundaries by SimDriver, never by touching World from a
## view (PLAN v0.0.1 Step 12). Runs touched here are dev runs.

signal reseed_requested(seed_value: int)

var world: World
var paused := false
var ticks_last_frame := 0
## Run flow helpers (v0.3.0 B; dev runs only): the player can't be hurt, and a queued boss kill.
var god := false
var _kill_boss := false
var _steps := 0


func _init(p_world: World) -> void:
	world = p_world


func toggle_pause() -> void:
	paused = not paused


## Queue exactly one tick while paused.
func request_step() -> void:
	paused = true
	_steps += 1


## Toggles god mode: the player stays invulnerable from the next tick on.
func toggle_god() -> void:
	god = not god


## Kills the floor's boss at the next tick boundary (through Damage, so the kill and its events are the sim's).
func kill_boss() -> void:
	_kill_boss = true


## SimDriver asks this before each tick. Returns whether to step now. Queued commands apply here, between ticks.
func should_step() -> bool:
	_apply_commands()
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


func _apply_commands() -> void:
	if god and world.actors.invuln[0] < 2:
		world.actors.invuln[0] = 2
	if _kill_boss:
		_kill_boss = false
		var i := world.actors.index_of(world.boss_id) if world.boss_id != 0 else -1
		if i >= 0:
			world.actors.invuln[i] = 0
			var at := world.actors.pos(i)
			Damage.hit(world, i, world.actors.hp[i] * 10, 0, 0, world.take_root(), 0, at, at)
