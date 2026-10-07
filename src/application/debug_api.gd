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
## The boss the panel spawns next (an index into World.boss_tables), and a spawn waiting for the tick boundary.
var boss_choice := 0
var _kill_boss := false
var _steps := 0
var _boss_pending := -1


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


## Bosses (v0.3.0 C): picks the next compiled boss for request_boss.
func next_boss() -> void:
	if not world.boss_tables.is_empty():
		boss_choice = (boss_choice + 1) % world.boss_tables.size()


## Queues the chosen boss to spawn near the player at the next tick boundary (SimDriver calls apply_pending).
func request_boss() -> void:
	if not world.boss_tables.is_empty():
		_boss_pending = boss_choice


## Applies queued commands between ticks. Returns the spawned boss's actor id, or -1.
func apply_pending() -> int:
	if _boss_pending < 0:
		return -1
	var k := _boss_pending
	_boss_pending = -1
	BossChallenge.dissolve_floor(world)  # BX (L20): a summoned boss clears the floor.
	return world.spawn_boss(k, boss_spot(world, world.boss_tables[k].radius_m))


## A clear spot about 6 m from the player for a body of radius r (the first of 16 directions clear of walls), or
## 6 m along +x.
static func boss_spot(w: World, r: float) -> Vector2:
	var p := w.player_pos()
	for d in [6.0, 4.5]:
		for k in 16:
			var at: Vector2 = p + Kin.dir(k * 256) * d
			var clear := true
			for wall in w.walls:
				if Collide.circle_vs_obb(at, r + 0.2, wall) != Vector2.ZERO:
					clear = false
					break
			if clear:
				return at
	return p + Vector2(6, 0)


func _apply_commands() -> void:
	if god and world.actors.invuln[0] < 2:
		world.actors.invuln[0] = 2
	if _kill_boss:
		_kill_boss = false
		var i := world.actors.index_of(world.boss_id) if world.boss_id >= 0 else -1
		if i >= 0:
			world.actors.invuln[i] = 0
			var at := world.actors.pos(i)
			Damage.hit(world, i, world.actors.hp[i] * 10, 0, 0, world.take_root(), 0, at, at)
