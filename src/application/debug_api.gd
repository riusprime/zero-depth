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
## v0.3.5 AI: the normal enemy kind the panel spawns next (an index into enemy_kinds()), and a spawn waiting.
var enemy_choice := 0
## v0.4.0 BS forced loadouts: the ability the panel grants next (an index into World.ability_tables), and grants
## waiting for the tick boundary (each one a new slot or a level, as a card would).
var ability_choice := 0
var _kill_boss := false
var _grants := PackedInt32Array()
## v0.6.0 MX2: attack-item modifiers queued by grant_mod (each the first one not held that the build may take).
var _mod_grants := 0
## v0.4.0 AB: a dev route to the Overrun door waiting for the tick boundary.
var _to_overrun := false
## v0.5.5 AR: dev routes to an arena door and to clear the sealed arena's wave, waiting for the tick boundary.
var _to_arena := false
var _clear_wave := false
var _next_phase := false
var _steps := 0
var _boss_pending := -1
var _enemy_pending := -1
var _curse_chest := false


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


## The normal enemy kinds the world has tables for, in kind order (v0.3.5 AI: the panel's enemy spawn).
func enemy_kinds() -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in range(ActorStore.Kind.CHARGER, ActorStore.Kind.size()):
		if world.enemy_table(k) != null and not BossAi.is_boss_kind(k):
			out.append(k)
	return out


## Picks the next enemy kind for request_enemy.
func next_enemy() -> void:
	var kinds := enemy_kinds()
	if not kinds.is_empty():
		enemy_choice = (enemy_choice + 1) % kinds.size()


## Queues the chosen enemy to spawn about 6 m from the player at the next tick boundary.
func request_enemy() -> void:
	if not enemy_kinds().is_empty():
		_enemy_pending = enemy_choice % enemy_kinds().size()


## Applies queued commands between ticks. Returns the spawned boss's actor id, or -1.
func apply_pending() -> int:
	if _enemy_pending >= 0:
		var kind := enemy_kinds()[_enemy_pending]
		_enemy_pending = -1
		world.add_enemy(kind, boss_spot(world, world.enemy_table(kind).radius_m))
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


## v0.4.0 BS: picks the next compiled ability for grant_ability.
func next_ability() -> void:
	if not world.ability_tables.is_empty():
		ability_choice = (ability_choice + 1) % world.ability_tables.size()


## Queues the chosen ability (a new slot, or one level up) for the next tick boundary.
func grant_ability() -> void:
	if not world.ability_tables.is_empty():
		_grants.append(ability_choice)


## v0.6.0 MX2: queues the next attack-item modifier (the first slot item not held that the build may use) for the next
## tick boundary; with the six slots full it opens the Swap, as a found card would (Offers.apply).
func grant_mod() -> void:
	_mod_grants += 1


## v0.4.0 AB (dev route): puts the player just outside the Overrun room's first doorway at the next tick boundary,
## so walking on goes through the red frame.
func go_overrun() -> void:
	_to_overrun = true


## v0.5.5 AR (dev route): puts the player just outside the first doorway of the nearest arena that isn't cleared (a
## regular one), at the next tick boundary, so walking on seals it.
func go_arena() -> void:
	_to_arena = true


## v0.5.5 AR (dev runs only): kills every enemy inside the sealed arena at the next tick boundary (one wave).
func clear_wave() -> void:
	_clear_wave = true


## The spot `m` metres outside the first doorway of the nearest regular arena not cleared, or Vector2.INF.
static func arena_door_outside(w: World, m: float) -> Vector2:
	var f := w.floor_layout
	if f == null:
		return Vector2.INF
	var best := Vector2.INF
	for room in f.arena_rooms:
		if Arenas.is_cleared(w, room):
			continue
		var doors := ArenaRooms.doors_of(f, room)
		if doors.is_empty():
			continue
		var d := doors[0]
		var into := Kin.dir(f.door_angles[d])
		if f.door_rooms[d].x == room:
			into = -into
		var at := f.door_centers[d] - into * (f.door_depths[d] * 0.5 + m)
		if best == Vector2.INF or at.distance_to(w.player_pos()) < best.distance_to(w.player_pos()):
			best = at
	return best


## v0.4.0 TU (dev route): moves the floor's clock to the start of the next difficulty phase at the next tick
## boundary, so a phase can be seen without waiting for it.
func next_phase() -> void:
	_next_phase = true


## The spot `m` metres outside the Overrun room's first doorway (in the room next to it), or Vector2.INF.
static func overrun_door_outside(w: World, m: float) -> Vector2:
	var f := w.floor_layout
	if f == null or f.overrun_room < 0 or f.overrun_doors.is_empty():
		return Vector2.INF
	var d := f.overrun_doors[0]
	var into := Kin.dir(f.door_angles[d])  # from door_rooms.x toward .y
	if f.door_rooms[d].x == f.overrun_room:
		into = -into
	return f.door_centers[d] - into * (f.door_depths[d] * 0.5 + m)


## v0.5.0 EV (dev runs only): the next chest offer rolled is cursed.
func curse_next_chest() -> void:
	_curse_chest = true


func _apply_commands() -> void:
	if _next_phase:
		_next_phase = false
		var c := world.spawner.curve if world.spawner != null else null
		if c != null:
			world.run_ticks += c.ticks_to_next(world.run_ticks)
	if _curse_chest:
		_curse_chest = false
		world.ev.force_curse = true
	if _to_arena:
		_to_arena = false
		var spot := arena_door_outside(world, 1.5)
		if spot != Vector2.INF:
			world.actors.set_pos(0, spot)
	if _clear_wave:
		_clear_wave = false
		if world.arenas.sealed():
			var rect := world.floor_layout.rooms[world.arenas.room].grow(Arenas.ROOM_MARGIN_M)
			for i in range(1, world.actors.size()):
				var p := world.actors.pos(i)
				if (
					world.actors.dead[i] == 0
					and EnemyAi.is_enemy_kind(world.actors.kinds[i])
					and rect.has_point(p)
				):
					world.actors.invuln[i] = 0
					Damage.hit(world, i, world.actors.hp[i] * 10, 0, 0, world.take_root(), 0, p, p)
	if _to_overrun:
		_to_overrun = false
		var at := overrun_door_outside(world, 1.5)
		if at != Vector2.INF:
			world.actors.set_pos(0, at)
	for idx in _grants:
		Offers.apply(world, Offers.ability_code(idx))  # v0.6.0 MX2: a seventh modifier opens the Swap
	_grants.clear()
	while _mod_grants > 0 and not BuildSlots.swapping(world):
		_mod_grants -= 1
		for k in world.item_tables.size():
			if (
				BuildSlots.is_slot_item(world.item_tables[k])
				and not world.items_owned.has(k)
				and ItemPool.usable(world, k)
			):
				Offers.apply(world, k)
				break
	_mod_grants = 0
	if god and world.actors.invuln[0] < 2:
		world.actors.invuln[0] = 2
	if _kill_boss:
		_kill_boss = false
		var i := world.actors.index_of(world.boss_id) if world.boss_id >= 0 else -1
		if i >= 0:
			world.actors.invuln[i] = 0
			var at := world.actors.pos(i)
			Damage.hit(world, i, world.actors.hp[i] * 10, 0, 0, world.take_root(), 0, at, at)
