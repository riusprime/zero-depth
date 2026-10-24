class_name TimedDoorRooms
extends RefCounted
## v0.9.0 TD (owner W §2: "optional rooms containing a closed door controlled by two separate interactive mechanisms";
## W17 "Ensure completion is possible at normal movement speed"; W18 "Reset safely without trapping the player"; W19
## "Allow variations in switch placement and layout. Make rewards or secret areas optional"): the floor's secret room
## behind a timed door, chosen after the floor and its rooms' kinds are set (TimedDoor.setup), from the rooms already
## generated, so the floor's walls and draws stay as they were:
## - on chance_permille of the floors (a draw from the `map:timed_door` sub-stream of the floor seed, never the `map`
##   stream itself), one dead-end room (one doorway, to one room) becomes the secret room: never the start hall, the
##   boss room, its host, the portal room, the Overrun room, the shop's room, the curse room or an arena, and never a
##   room in `taken` (a room holding a reward, an event or the shrine); its one doorway is the timed door;
## - the room before it (the host: the dead end's one neighbour; not the start hall, the boss room, the Overrun room,
##   the shop's room, the curse room or an arena) holds the two switches, on two of its spawn spots SWITCH_GAP_M apart,
##   DOOR_GAP_M from its doorways' approaches and AVOID_M from `avoid` (rewards, pedestals, the shrine) and its item
##   spots; the spots are drawn from the same sub-stream;
## - the check (W17): the walk from either switch (either may be the second) to the door, on the host's open floor at
##   PATH_CLEARANCE_M (4-connected FloorReach cells: never shorter than the real path), is at most
##   PATH_SHARE_PERMILLE of the timer at base move speed; else other spots, then another room, else no timed door on
##   that floor;
## - a dead end is never on the way anywhere (the property test: every other room stays reachable without it).
## Pure sim code: integers, BFS over the doorway graph and the reach grid.

const STREAM := "map:timed_door"
const SWITCH_GAP_M := 4.0
const DOOR_GAP_M := 2.5
const AVOID_M := 3.0
const PATH_CLEARANCE_M := 0.5
## W17: the walk from the second switch to the door is at most this share of the timer at base speed.
const PATH_SHARE_PERMILLE := 600


## Marks `f`'s secret room, its door, host and switches (FloorLayout.timed_*). Returns the room, or -1.
## `speed` is the hero's base move speed (m per tick).
static func mark(
	f: FloorLayout,
	chance_permille: int,
	timer_ticks: int,
	speed: float,
	taken: PackedInt32Array,
	avoid: PackedVector2Array
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
	var budget := float(timer_ticks) * speed * PATH_SHARE_PERMILLE / 1000.0
	for room in cands:
		var door := only_door(f, room)
		var host := f.door_rooms[door].x if f.door_rooms[door].y == room else f.door_rooms[door].y
		var spots := switch_spots(f, host, door, avoid, budget, rng)
		if spots.size() == 2:
			f.timed_room = room
			f.timed_host = host
			f.timed_door = door
			f.timed_switches = spots
			f.timed_door_wall = door_wall(f, door)
			return room
	return -1


## No secret room (the fields' defaults).
static func clear(f: FloorLayout) -> void:
	f.timed_room = -1
	f.timed_host = -1
	f.timed_door = -1
	f.timed_switches = PackedVector2Array()
	f.timed_door_wall = null


## Dead ends that may become the secret room, ascending (their host allowed too).
static func candidates(f: FloorLayout, taken: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var never := [f.start_room, f.boss_room, f.boss_host_room, f.portal_room, f.overrun_room]
	never.append_array([f.shop_room, f.curse_room])
	for room in f.room_count():
		if room in never or f.arena_rooms.has(room) or taken.has(room):
			continue
		if f.lockdown_rooms.has(room):  # v0.9.0 CF2: marked first from floor rules 17
			continue
		var door := only_door(f, room)
		if door < 0:
			continue
		var host := f.door_rooms[door].x if f.door_rooms[door].y == room else f.door_rooms[door].y
		if host in [f.start_room, f.boss_room, f.overrun_room, f.shop_room, f.curse_room]:
			continue
		if f.arena_rooms.has(host) or f.lockdown_rooms.has(host) or host >= f.spawn_points.size():
			continue
		out.append(room)
	return out


## Room `room`'s doorway when it has exactly one, else -1.
static func only_door(f: FloorLayout, room: int) -> int:
	var found := -1
	for d in f.door_rooms.size():
		if f.door_rooms[d].x == room or f.door_rooms[d].y == room:
			if found >= 0:
				return -1
			found = d
	return found


## The slab that shuts doorway `door`: its passage through the wall, a little wider along the wall.
static func door_wall(f: FloorLayout, door: int) -> Obb:
	var r := f.door_rect(door)
	var grow := Vector2(0.0, 0.05) if f.door_angles[door] % 2048 == 0 else Vector2(0.05, 0.0)
	return Obb.make(r.get_center(), r.size * 0.5 + grow, 0)


## Two switch spots in `host` (drawn from rng) passing the rules, or fewer when none do.
static func switch_spots(
	f: FloorLayout, host: int, door: int, avoid: PackedVector2Array, budget: float, rng: RngStream
) -> PackedVector2Array:
	var ok := PackedVector2Array()
	var approaches := f.door_approaches(host, 1.0)
	for q in f.spawn_points[host]:
		if (
			_far(q, approaches, DOOR_GAP_M)
			and _far(q, avoid, AVOID_M)
			and _far(q, f.item_spots, AVOID_M)
		):
			ok.append(q)
	for k in range(ok.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := ok[k]
		ok[k] = ok[j]
		ok[j] = swap
	if ok.size() < 2:
		return PackedVector2Array()
	var reach := FloorReach.new()
	var area := f.rooms[host].merge(f.door_rect(door))
	reach.build(area, f.room_walls(host), PATH_CLEARANCE_M)
	var goal := door_goal(f, host, door)
	var dist := PackedFloat64Array()
	for q in ok:
		dist.append(walk_m(reach, q, goal))
	for a in ok.size():
		if dist[a] < 0.0 or dist[a] > budget:
			continue
		for b in range(a + 1, ok.size()):
			if dist[b] < 0.0 or dist[b] > budget:
				continue
			if Kin.length(ok[a] - ok[b]) >= SWITCH_GAP_M:
				return PackedVector2Array([ok[a], ok[b]])
	return PackedVector2Array()


## The point on the host's side of the door the walk counts to (0.5 m in from the host's wall face).
static func door_goal(f: FloorLayout, host: int, door: int) -> Vector2:
	var into := 1.0 if f.door_rooms[door].x == host else -1.0  # the doorway points from x to y
	var back := Kin.dir(f.door_angles[door]) * -into
	return f.door_centers[door] + back * (f.door_depths[door] * 0.5 + 0.5)


## The walk (m) from `a` to `b` over reach's open cells (4-connected, so never shorter than the real path), plus one
## cell; -1 when there is none.
static func walk_m(reach: FloorReach, a: Vector2, b: Vector2) -> float:
	var from := reach.cell_of(a)
	var to := reach.cell_of(b)
	if not reach.inside(from) or not reach.inside(to):
		return -1.0
	var n := reach.size.x * reach.size.y
	var seen := PackedInt32Array()
	seen.resize(n)
	seen.fill(-1)
	var start := from.y * reach.size.x + from.x
	var goal := to.y * reach.size.x + to.x
	if reach.blocked[start] == 1 or reach.blocked[goal] == 1:
		return -1.0
	seen[start] = 0
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == goal:
			return seen[c] * FloorReach.CELL + FloorReach.CELL
		var cx := c % reach.size.x
		var cy := c / reach.size.x
		for s: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := cx + s.x
			var ny := cy + s.y
			if nx < 0 or ny < 0 or nx >= reach.size.x or ny >= reach.size.y:
				continue
			var k := ny * reach.size.x + nx
			if seen[k] >= 0 or reach.blocked[k] == 1:
				continue
			seen[k] = seen[c] + 1
			queue.append(k)
	return -1.0


static func _far(q: Vector2, points: PackedVector2Array, gap: float) -> bool:
	for p in points:
		if Kin.length(p - q) < gap:
			return false
	return true
