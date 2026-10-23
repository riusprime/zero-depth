class_name RoomCensus
extends RefCounted
## v0.9.0 RG: which rooms of a built floor hold which special room kind (the ids of data/special_rooms, plus the fixed
## rooms and the hosts), read from the world as Main builds it (SaveLab.floor_world: FloorScenario, the shop, the
## events and FloorPlan.add_secrets). For the pacing report (scripts/balance/room_pacing.gd) and the no-softlock
## property tests (tests/unit/sim/test_special_room_rules.gd). Test-side only: it reads, never writes.
## - `reward`: the floor's own rewards' rooms (altars, chests), without the secret rooms' rewards, which their own setup
##   places inside them.

## The special room kinds, in the report's order (each one's SpecialRoomDefinition id).
const KINDS: Array[StringName] = [
	&"arena",
	&"overrun",
	&"lockdown",
	&"shop",
	&"curse",
	&"event",
	&"shrine",
	&"fountain",
	&"timed_door",
	&"rune_puzzle",
	&"cracked_wall",
	&"purple_runes",
]
## The fixed rooms and the hosts (never special rooms of their own, but named in the schema's avoid lists).
const FIXED: Array[StringName] = [
	&"start",
	&"boss",
	&"boss_host",
	&"portal",
	&"reward",
	&"timed_door_host",
	&"rune_puzzle_host",
	&"cracked_wall_host",
]


## Kind (KINDS and FIXED) -> its rooms on `w`'s floor (ascending, no repeats; empty when the floor has none).
static func of(w: World) -> Dictionary:
	var f := w.floor_layout
	var out := {}
	for k in KINDS + FIXED:
		out[k] = PackedInt32Array()
	_add(out, &"start", f.start_room)
	_add(out, &"boss", f.boss_room)
	_add(out, &"boss_host", f.boss_host_room)
	_add(out, &"portal", f.portal_room)
	_add(out, &"overrun", f.overrun_room)
	for r in f.arena_rooms:
		_add(out, &"arena", r)
	_add(out, &"shop", f.shop_room)
	_add(out, &"curse", f.curse_room)
	for k in w.ev.ids.size():
		if k != w.ev.curse_k:
			_add(out, &"event", w.ev.room[k])
	if w.gamble_id >= 0:
		_add(out, &"shrine", f.room_of(w.gamble_pos))
	if w.shrine != null and w.shrine.has_fountain():
		_add(out, &"fountain", f.room_of(w.shrine.fountain_pos))
	_add(out, &"timed_door", f.timed_room)
	_add(out, &"timed_door_host", f.timed_host)
	_add(out, &"rune_puzzle", f.rune_room)
	_add(out, &"rune_puzzle_host", f.rune_host)
	_add(out, &"cracked_wall", f.crack_room)
	_add(out, &"cracked_wall_host", f.crack_host)
	_add(out, &"purple_runes", f.purple_room)
	for r in f.lockdown_rooms:
		_add(out, &"lockdown", r)
	var own := PackedInt32Array()
	if w.timed != null:
		own.append(w.timed.reward_id)
	if w.runes != null:
		own.append(w.runes.reward_id)
	if w.breakables != null:
		own.append(w.breakables.crack_reward_id)
	for i in w.rewards.size():
		if not own.has(w.rewards.ids[i]):
			_add(out, &"reward", f.room_of(w.rewards.pos(i)))
	for k: StringName in out:
		var rooms: PackedInt32Array = out[k]
		rooms.sort()
		out[k] = rooms
	return out


## The rooms holding any special room kind (KINDS), ascending.
static func special_rooms(census: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in KINDS:
		for r: int in census[k]:
			if not out.has(r):
				out.append(r)
	out.sort()
	return out


## The rooms on the floor's critical path: the shortest doorway path from the start hall to the boss room (start
## first; LockdownRooms.main_path, reversed).
static func critical_path(f: FloorLayout) -> PackedInt32Array:
	var path := LockdownRooms.main_path(f)
	path.reverse()
	return path


## Doorway hops from `from` to every room (-1 unreached), never entering a room in `shut` (`from` itself excepted).
static func hops_from(f: FloorLayout, from: int, shut: PackedInt32Array) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(f.room_count())
	d.fill(-1)
	d[from] = 0
	var queue := PackedInt32Array([from])
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		for nb in f.neighbours(r):
			if d[nb] < 0 and not shut.has(nb):
				d[nb] = d[r] + 1
				queue.append(nb)
	return d


static func _add(out: Dictionary, kind: StringName, room: int) -> void:
	var rooms: PackedInt32Array = out[kind]
	if room >= 0 and not rooms.has(room):
		rooms.append(room)
		out[kind] = rooms
