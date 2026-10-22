class_name PurpleRooms
extends RefCounted
## v0.9.0 DP (owner Q26b: "one of the event rooms, in a big room, has activation purple runes"; "never in floor 1, 50%
## of appearing in floor 2 if does not appear, then warrantee on the next floor"): the floor's purple-rune room, chosen
## after every other room kind and secret is set (PurpleRunes.setup), from the rooms already generated, so the floor's
## walls and draws stay as they were:
## - on chance_permille of the floors (PurpleRunes.chance: the data's per-floor chance while the loop has had none;
##   a draw from the `map:purple_runes` sub-stream of the floor seed), one big room (at least MIN_CELLS grid cells;
##   when none is that big, the biggest that fit) becomes the purple-rune room: never the start hall, the boss room,
##   the portal room, the Overrun room, the shop's room, the curse room, an arena, a secret room (the timed door's,
##   the rune puzzle's, the cracked wall's), a secret's host or a room in `taken` (a room holding an event may hold
##   it: the dais keeps clear of the pedestal), and never a room the floor's main path needs to cross (the boss room
##   stays reachable from the start hall without it; the dais is not solid, so the room never blocks a way either);
## - its dais stands in the room's middle: the centre, else the spawn spot nearest it, that keeps DAIS_CLEAR_M from
##   every wall, AVOID_M from `avoid` (rewards, events, the shrine, the puzzles' pieces, the containers) and
##   DOOR_GAP_M from the room's doorway approaches, on the open floor reached from its doorways.
## Pure sim code: integers, the doorway graph and the reach grid.

const STREAM := "map:purple_runes"
## "In a big room": at least 2 x 2 grid cells.
const MIN_CELLS := 4
const DAIS_CLEAR_M := 1.2
const AVOID_M := 3.0
const DOOR_GAP_M := 2.0
const REACH_CLEARANCE_M := 0.5


## Marks `f`'s purple-rune room and its dais (FloorLayout.purple_*). Returns the room, or -1.
static func mark(
	f: FloorLayout, chance_permille: int, taken: PackedInt32Array, avoid: PackedVector2Array
) -> int:
	clear(f)
	var rng := RngStream.derive(f.seed_value, STREAM)
	if not rng.chance_permille(chance_permille):
		return -1
	var cands := candidates(f, taken)
	for k in range(cands.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := cands[k]
		cands[k] = cands[j]
		cands[j] = swap
	for room in _big_first(f, cands):
		var at := dais_spot(f, room, avoid)
		if at.size() == 1:
			f.purple_room = room
			f.purple_pos = at[0]
			return room
	return -1


## No purple-rune room (the fields' defaults).
static func clear(f: FloorLayout) -> void:
	f.purple_room = -1
	f.purple_pos = Vector2.ZERO


## Rooms that may hold the runes, ascending (any size; mark() prefers the big ones).
static func candidates(f: FloorLayout, taken: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var never := [
		f.start_room, f.boss_room, f.portal_room, f.overrun_room, f.shop_room, f.curse_room
	]
	never.append_array(
		[f.timed_room, f.timed_host, f.rune_room, f.rune_host, f.crack_room, f.crack_host]
	)
	for room in f.room_count():
		if room in never or f.arena_rooms.has(room) or taken.has(room):
			continue
		if room >= f.spawn_points.size() or room >= f.room_cells.size():
			continue
		if not main_path_open(f, room):
			continue  # the way from the start hall to the boss needs to cross it
		out.append(room)
	return out


## Whether the boss room is reached from the start hall without crossing `room` (BFS over the doorway graph).
static func main_path_open(f: FloorLayout, room: int) -> bool:
	if f.boss_room < 0:
		return true
	var seen := PackedByteArray()
	seen.resize(f.room_count())
	seen[f.start_room] = 1
	var queue := PackedInt32Array([f.start_room])
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		if r == f.boss_room:
			return true
		for nb in f.neighbours(r):
			if seen[nb] == 0 and nb != room:
				seen[nb] = 1
				queue.append(nb)
	return false


## `cands` (in their drawn order) keeping the rooms of MIN_CELLS or more; when none is, the biggest ones.
static func _big_first(f: FloorLayout, cands: PackedInt32Array) -> PackedInt32Array:
	var big := PackedInt32Array()
	var most := 0
	for room in cands:
		most = maxi(most, f.room_cell_count(room))
		if f.room_cell_count(room) >= MIN_CELLS:
			big.append(room)
	if not big.is_empty():
		return big
	for room in cands:
		if f.room_cell_count(room) == most:
			big.append(room)
	return big


## The dais's spot in `room` ([] when none fits): the room's centre, else its spawn spot nearest the centre.
static func dais_spot(f: FloorLayout, room: int, avoid: PackedVector2Array) -> PackedVector2Array:
	var mid := f.rooms[room].get_center()
	var spots := PackedVector2Array([mid])
	var rest := f.spawn_points[room].duplicate()
	while not rest.is_empty():
		var best := 0
		for k in rest.size():
			if Kin.length(rest[k] - mid) < Kin.length(rest[best] - mid):
				best = k
		spots.append(rest[best])
		rest.remove_at(best)
	var walls := f.room_walls(room)
	var approaches := f.door_approaches(room, 1.0)
	var reach := FloorReach.new()
	reach.build(f.rooms[room], walls, REACH_CLEARANCE_M)
	var region := -1
	for a in approaches:
		if region < 0:
			region = reach.region_at(a)
	if region < 0:
		return PackedVector2Array()
	for q in spots:
		if _fits(q, walls, approaches, avoid) and reach.region_at(q) == region:
			return PackedVector2Array([q])
	return PackedVector2Array()


static func _fits(
	q: Vector2, walls: Array[Obb], approaches: PackedVector2Array, avoid: PackedVector2Array
) -> bool:
	for w in walls:
		if Collide.circle_vs_obb(q, DAIS_CLEAR_M, w) != Vector2.ZERO:
			return false
	for p in approaches:
		if Kin.length(p - q) < DOOR_GAP_M:
			return false
	for p in avoid:
		if Kin.length(p - q) < AVOID_M:
			return false
	return true
