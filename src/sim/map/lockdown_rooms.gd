class_name LockdownRooms
extends RefCounted
## v0.9.0 LK (owner Q21: "a new room type"; "1-2 a floor, short"): the floor's Lockdown rooms and their kinds, chosen
## after every other room kind and secret is set (Lockdowns.setup, last), from the rooms already generated, so the
## floor's walls and every other draw stay as they were:
## - a candidate is never the start hall, the boss room or its host, the portal room, the Overrun room, the shop's
##   room (ShopPlacement's pick, on any floor), the curse room, an arena, a secret room (the timed door's, the rune
##   puzzle's, the cracked wall's) or a secret's host, the purple-rune room, or a room in `taken` (an event's, the
##   gamble shrine's); it needs at least MIN_SPOTS spawn points (its formations stand inside) and (v0.9.0 CF, owner:
##   "lets never make it a 1x1") at least the table's min_cells grid cells (0, a floor saved before CF: any room);
## - the count is drawn in rooms_min..rooms_max from the `map:lockdowns` sub-stream of the floor seed, the candidates
##   are shuffled from it and taken in that order, rooms off the main path (start hall to boss room) first;
## - each is taken only if, with every Lockdown taken so far, the arenas and the Overrun room shut, every room reached
##   from the start hall with the arenas and the Overrun room shut is still reached (reached(): a Lockdown is
##   skippable, as an arena, and so never stands on the only way to the boss), and never next to another Lockdown
##   (never two in a row);
## - each one's kind is drawn from the same stream by the kinds' weights among those allowed on the floor (the Elite
##   kind is step EL's hook, weight 0 in the data).
## v0.9.0 CF2 (owner: "Lockdowns get rooms first"): from floor rules 17 mark runs right after the arenas and the
## Overrun room (FloorScenario.build, `taken` empty, no event, shrine, curse room or secret placed yet), and those
## kinds keep out of lockdown_rooms (and a secret's host is never one); the rules above are unchanged.
## Pure sim code: integers, BFS over the doorway graph.

const STREAM := "map:lockdowns"
const MIN_SPOTS := 3


## Marks `f`'s Lockdowns (FloorLayout.lockdown_rooms and lockdown_kinds, in the order taken) for floor `floor_index`
## (1-based, within the loop). Returns the rooms.
static func mark(
	f: FloorLayout, t: LockdownTable, floor_index: int, taken: PackedInt32Array
) -> PackedInt32Array:
	f.lockdown_rooms = PackedInt32Array()
	f.lockdown_kinds = PackedInt32Array()
	if t == null or t.rooms_max <= 0 or f.room_count() == 0:
		return f.lockdown_rooms
	var rng := RngStream.derive(f.seed_value, STREAM)
	var want := rng.range_int(mini(t.rooms_min, t.rooms_max), maxi(t.rooms_min, t.rooms_max))
	var cands := candidates(f, taken, t.min_cells)
	for k in range(cands.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := cands[k]
		cands[k] = cands[j]
		cands[j] = swap
	var path := main_path(f)
	var ordered := PackedInt32Array()
	for on in [false, true]:
		for r in cands:
			if path.has(r) == on:
				ordered.append(r)
	var shut := f.arena_rooms.duplicate()
	if f.overrun_room >= 0:
		shut.append(f.overrun_room)
	var before := reached(f, shut)
	for r in ordered:
		if f.lockdown_rooms.size() >= want:
			break
		if _next_to_one(f, r) or before[r] == 0:
			continue
		var trial := shut.duplicate()
		trial.append_array(f.lockdown_rooms)
		trial.append(r)
		if _keeps(f, before, reached(f, trial), trial):
			f.lockdown_rooms.append(r)
	var weights := kind_weights(t, floor_index)
	for r in f.lockdown_rooms:
		f.lockdown_kinds.append(maxi(0, Offers.pick(rng, weights)))
	return f.lockdown_rooms


## The kinds' weights on floor `floor_index`: each kind's data weight from its first floor, else 0.
static func kind_weights(t: LockdownTable, floor_index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in LockdownTable.Kind.size():
		var w := t.kind_weights[k] if k < t.kind_weights.size() else 0
		var lo := t.kind_floor_min[k] if k < t.kind_floor_min.size() else 1
		out.append(w if floor_index >= lo else 0)
	return out


## Rooms that may be Lockdowns, ascending.
static func candidates(
	f: FloorLayout, taken: PackedInt32Array, min_cells: int = 0
) -> PackedInt32Array:
	var out := PackedInt32Array()
	var never := [f.start_room, f.boss_room, f.boss_host_room, f.portal_room, f.overrun_room]
	never.append_array([f.shop_room, Routes.shop_room_of(f), f.curse_room, f.purple_room])
	never.append_array(
		[f.timed_room, f.timed_host, f.rune_room, f.rune_host, f.crack_room, f.crack_host]
	)
	never.append_array(f.timed_switch_rooms)  # v0.9.5 TS
	for r in f.room_count():
		if r in never or f.arena_rooms.has(r) or taken.has(r):
			continue
		if r >= f.spawn_points.size() or f.spawn_points[r].size() < MIN_SPOTS:
			continue
		if not ClosedFights.fits(f, r, min_cells):
			continue
		out.append(r)
	return out


## The rooms on the shortest doorway path from the start hall to the boss room (both ends included; empty without a
## boss room).
static func main_path(f: FloorLayout) -> PackedInt32Array:
	var out := PackedInt32Array()
	if f.boss_room < 0:
		return out
	var n := f.room_count()
	var from := PackedInt32Array()
	from.resize(n)
	from.fill(-1)
	from[f.start_room] = f.start_room
	var queue := PackedInt32Array([f.start_room])
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		for nb in f.neighbours(r):
			if from[nb] < 0:
				from[nb] = r
				queue.append(nb)
	if from[f.boss_room] < 0:
		return out
	var r := f.boss_room
	while r != f.start_room:
		out.append(r)
		r = from[r]
	out.append(f.start_room)
	return out


## The rooms reached from the start hall without entering a room in `shut` (1 = reached), as ArenaRooms.all_reachable
## walks them.
static func reached(f: FloorLayout, shut: PackedInt32Array) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(f.room_count())
	seen[f.start_room] = 1
	var queue := PackedInt32Array([f.start_room])
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		for nb in f.neighbours(r):
			if seen[nb] == 0 and not shut.has(nb):
				seen[nb] = 1
				queue.append(nb)
	return seen


## Whether every room reached `before` (and not shut now) is still reached `now`: a Lockdown never cuts a room off
## (on a floor whose Overrun room already closes a dead end, the rooms behind it don't count).
static func _keeps(
	f: FloorLayout, before: PackedByteArray, now: PackedByteArray, shut: PackedInt32Array
) -> bool:
	for r in f.room_count():
		if before[r] == 1 and now[r] == 0 and not shut.has(r):
			return false
	return true


static func _next_to_one(f: FloorLayout, r: int) -> bool:
	for nb in f.neighbours(r):
		if f.lockdown_rooms.has(nb):
			return true
	return false


## The kind of Lockdown room `room` (LockdownTable.Kind), or -1 when it is none.
static func kind_of(f: FloorLayout, room: int) -> int:
	var k := f.lockdown_rooms.find(room)
	return f.lockdown_kinds[k] if k >= 0 and k < f.lockdown_kinds.size() else -1
