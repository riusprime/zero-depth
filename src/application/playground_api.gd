class_name PlaygroundApi
extends RefCounted
## v0.7.5 PG (owner N19, docs/tools/PLAYGROUND.md): the Playground's commands. The panel queues them and SimDriver
## applies them between ticks (apply_pending), also while the panel holds the sim paused, so a placed dummy shows at
## once. They touch only the Playground's World, never a run's.
## - Dummies are the sim's DUMMY actor (the enemy team: hits, procs, statuses and on-kill triggers land on it), still
##   and silent. An endless one ("∞") gets its HP back here before every tick; one with a set HP dies.
## - Enemies and bosses are spawned as the entities they are (their AI, attacks and phases), at a point.
## - Cards go in through the sim's own take (BuildSlots / Offers), at a chosen level.

## An endless dummy's pool: no tick of any build empties it, and it is refilled before the next.
const ENDLESS_HP := 100_000_000
const DUMMY_RADIUS_M := 0.5
## How far past a body's edge a delete click still picks it, in metres.
const PICK_SLACK_M := 0.6

var world: World
## The player can't be hurt (as DebugApi.god).
var god := false
## Ids of the endless dummies.
var endless := {}
var _queue: Array[Callable] = []


func _init(p_world: World) -> void:
	world = p_world


func has_pending() -> bool:
	return not _queue.is_empty()


## Runs the queued commands, then refills the endless dummies and keeps god mode. Returns whether a command ran.
func apply_pending() -> bool:
	var ran := not _queue.is_empty()
	var q := _queue
	_queue = []
	for c in q:
		c.call()
	_upkeep()
	return ran


# --- Queued commands (the panel's) -------------------------------------------------------------------------------


## A dummy at `at`; `hp` <= 0 makes it endless.
func place_dummy(at: Vector2, hp: int = 0) -> void:
	_queue.append(func() -> void: place_dummy_now(at, hp))


func place_enemy(kind: int, at: Vector2) -> void:
	_queue.append(func() -> void: place_enemy_now(kind, at))


## Boss `table_index` (an index into World.boss_tables) at `at`.
func place_boss(table_index: int, at: Vector2) -> void:
	_queue.append(func() -> void: place_boss_now(table_index, at))


## Removes what stands under `at` (the nearest body whose edge is within PICK_SLACK_M), never the player.
func remove_at(at: Vector2) -> void:
	_queue.append(func() -> void: remove_at_now(at))


## Removes every enemy and boss; with `dummies` the dummies too.
func clear(dummies: bool) -> void:
	_queue.append(func() -> void: clear_now(dummies))


## Card `code` (Offers' codes) at `level` (wand cards and abilities 1..5; others ignore it).
func grant(code: int, level: int = 1) -> void:
	_queue.append(func() -> void: grant_now(code, level))


func remove_card(code: int) -> void:
	_queue.append(func() -> void: remove_card_now(code))


func heal() -> void:
	_queue.append(func() -> void: world.actors.hp[0] = world.actors.max_hp[0])


# --- Applied now (between ticks; the tests call these directly) ------------------------------------------------


## False (nothing placed) when a body of the dummy's size at `at` would overlap a wall.
func place_dummy_now(at: Vector2, hp: int = 0) -> bool:
	if not clear_spot(at, DUMMY_RADIUS_M):
		return false
	var id := world.add_dummy(at, DUMMY_RADIUS_M, hp if hp > 0 else ENDLESS_HP)
	if hp <= 0:
		endless[id] = true
	return true


func place_enemy_now(kind: int, at: Vector2) -> bool:
	var t := world.enemy_table(kind)
	if t == null or BossAi.is_boss_kind(kind) or not clear_spot(at, t.radius_m):
		return false
	world.add_enemy(kind, at)
	return true


func place_boss_now(table_index: int, at: Vector2) -> bool:
	if table_index < 0 or table_index >= world.boss_tables.size():
		return false
	if not clear_spot(at, world.boss_tables[table_index].radius_m):
		return false
	world.spawn_boss(table_index, at)
	return true


## The actor index under `at` (not the player), or -1.
func actor_at(at: Vector2) -> int:
	var a := world.actors
	var best := -1
	var best_d := INF
	for i in range(1, a.size()):
		if a.dead[i] == 1:
			continue
		var d := (a.pos(i) - at).length() - a.radius[i]
		if d <= PICK_SLACK_M and d < best_d:
			best = i
			best_d = d
	return best


func remove_at_now(at: Vector2) -> bool:
	var i := actor_at(at)
	if i < 0:
		return false
	_remove(PackedInt32Array([i]))
	return true


func clear_now(dummies: bool) -> int:
	var gone := PackedInt32Array()
	for i in range(1, world.actors.size()):
		if dummies or world.actors.kinds[i] != ActorStore.Kind.DUMMY:
			gone.append(i)
	_remove(gone)
	return gone.size()


## Takes `code` as a found card would, then sets its level. False when it can't go in: the wand is full (the
## Playground opens no Swap: remove a card first), the build already has a utility, or the code is unknown.
func grant_now(code: int, level: int = 1) -> bool:
	level = clampi(level, 1, CardLevels.MAX_LEVEL)
	match Offers.type_of(code):
		Offers.MOD:
			return _grant_item(code, level)
		Offers.ABILITY:
			return _grant_ability(Offers.ability_of(code), level)
		Offers.STAT:
			Offers.apply(world, code)
			return true
	return false


## Takes `code` out of the build (a stat card: its last copy). The build's weapon stays.
func remove_card_now(code: int) -> bool:
	match Offers.type_of(code):
		Offers.MOD:
			return _remove_item(code)
		Offers.ABILITY:
			return _remove_ability(Offers.ability_of(code))
		Offers.STAT:
			if not world.stat_cards.has(code):
				return false
			Shop.remove_stat_card(world, code)
			return true
	return false


func _grant_item(idx: int, level: int) -> bool:
	if idx < 0 or idx >= world.item_tables.size():
		return false
	if not world.items_owned.has(idx):
		if BuildSlots.needs_swap(world, idx):
			return false
		Offers.apply(world, idx)
	if CardLevels.is_card(world, idx):
		CardLevels.set_level(world, idx, level)
	return world.items_owned.has(idx)


func _grant_ability(idx: int, level: int) -> bool:
	if idx < 0 or idx >= world.ability_tables.size():
		return false
	if Abilities.level_of(world, idx) > level:
		_remove_ability(idx)  # down a level: it goes in again from level 1
	if not Abilities.owned(world, idx) and not Abilities.grant(world, idx):
		return false
	while Abilities.level_of(world, idx) < level and Abilities.grant(world, idx):
		pass
	return true


func _remove_item(idx: int) -> bool:
	if not world.items_owned.has(idx):
		return false
	var s := world.mod_slots.find(idx)
	if s >= 0:
		BuildSlots.drop(world, s)
	else:
		Shop.remove_item(world, idx)
		CardLevels.reset(world, idx)
	return true


func _remove_ability(idx: int) -> bool:
	var slot := world.ability_owned.find(idx)
	if slot < 0 or world.ability_tables[idx].start_weapon != 0:
		return false
	var s := world.mod_slots.find(Offers.ability_code(idx))
	if s >= 0:
		BuildSlots.drop(world, s)
	else:
		Abilities.remove_slot(world, slot)
		BuildSlots.sync(world)
		world.refresh_build(true)
	return true


## No wall overlaps a body of radius `r` at `at`, and `at` is on the floor.
func clear_spot(at: Vector2, r: float) -> bool:
	var layout := world.floor_layout
	if layout != null and not layout.rooms[0].grow(-r).has_point(at):
		return false
	for wall in world.walls:
		if Collide.circle_vs_obb(at, r, wall) != Vector2.ZERO:
			return false
	return true


# --- Inside -----------------------------------------------------------------------------------------------------


## Removes actors `gone` (indices, any order) with no kill, shards or reward: one ENEMY_DISSOLVED each (as a
## summoned boss dissolves a run's floor, BossChallenge.dissolve_floor); a boss leaves the boss store too.
func _remove(gone: PackedInt32Array) -> void:
	var a := world.actors
	gone.sort()
	for i in gone:
		var id := a.ids[i]
		var e := world.emit_event(SimEvent.Kind.ENEMY_DISSOLVED, id, id, id, a.pos(i))
		e.amount = a.kinds[i]
		var b := world.bosses.index_of(id)
		if b >= 0:
			world.bosses.remove(b)
			if world.boss_id == id:
				world.boss_id = -1
		endless.erase(id)
	a.remove_sorted(gone)
	if world.boss_id < 0 and world.bosses.size() > 0:
		world.boss_id = world.bosses.ids[world.bosses.size() - 1]


func _upkeep() -> void:
	var a := world.actors
	for i in range(1, a.size()):
		if endless.has(a.ids[i]) and a.dead[i] == 0:
			a.hp[i] = a.max_hp[i]
	if god and a.invuln[0] < 2:
		a.invuln[0] = 2
