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
	avoid: PackedVector2Array,
	steps_max := 0
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
		var spots := PackedVector2Array()
		var rooms := PackedInt32Array()
		if steps_max > 0:  # v0.9.5 TS (owner Q7): two other rooms 1..steps_max steps away
			var got := spread_spots(f, host, room, door, avoid, budget, steps_max, rng)
			spots = got.get("spots", PackedVector2Array())
			rooms = got.get("rooms", PackedInt32Array())
		else:
			spots = switch_spots(f, host, door, avoid, budget, rng)
		if spots.size() == 2:
			f.timed_room = room
			f.timed_host = host
			f.timed_door = door
			f.timed_switches = spots
			f.timed_door_wall = door_wall(f, door)
			f.timed_switch_rooms = rooms
			if steps_max > 0:
				f.timed_lever = lever_spot(f, room, door)
			return room
	return -1


## No secret room (the fields' defaults).
static func clear(f: FloorLayout) -> void:
	f.timed_room = -1
	f.timed_host = -1
	f.timed_door = -1
	f.timed_switches = PackedVector2Array()
	f.timed_door_wall = null
	f.timed_switch_rooms = PackedInt32Array()
	f.timed_lever = Vector2.ZERO


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


## v0.9.5 TS (owner Q7: "spread them a bit over the map"): the two switches in two DIFFERENT rooms, each 1..steps_max
## doorway steps from `host` (never the secret room `dead`, nor a sealed, boss, start or shop room, nor one walked
## through a sealed room), on spots passing the rules. Rooms behind different first doorways out of the host are
## preferred. Each switch's walk to the door (through the rooms between) is at most `budget` m, so either order is
## completable. Returns {"spots": 2 points, "rooms": their 2 rooms}, or {} when none fit.
static func spread_spots(
	f: FloorLayout,
	host: int,
	dead: int,
	door: int,
	avoid: PackedVector2Array,
	budget: float,
	steps_max: int,
	rng: RngStream
) -> Dictionary:
	var found := _rooms_within(f, host, dead, steps_max)
	var order: Array = found.keys()
	for k in range(order.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap: Variant = order[k]
		order[k] = order[j]
		order[j] = swap
	var reaches := {}
	var goal := door_goal(f, host, door)
	var options := {}  # room -> its spots within the budget (shuffled)
	for room: int in order:
		var ok := PackedVector2Array()
		for q in room_spots(f, room, avoid):
			var m := path_m(f, found[room], q, goal, reaches)
			if m >= 0.0 and m <= budget:
				ok.append(q)
		for k in range(ok.size() - 1, 0, -1):
			var j := rng.range_int(0, k)
			var swap := ok[k]
			ok[k] = ok[j]
			ok[j] = swap
		if not ok.is_empty():
			options[room] = ok
	var rooms: Array = options.keys()
	for different in [true, false]:
		for a in rooms.size():
			for b in range(a + 1, rooms.size()):
				var ra: int = rooms[a]
				var rb: int = rooms[b]
				if different and found[ra]["first"] == found[rb]["first"]:
					continue
				return {
					"spots": PackedVector2Array([options[ra][0], options[rb][0]]),
					"rooms": PackedInt32Array([ra, rb])
				}
	return {}


## The rooms 1..steps_max doorway steps from `host` that may hold a switch, each as {"first": the host's doorway the
## way out starts with, "rooms": the rooms from it to host, "doors": the doorways between them}.
static func _rooms_within(f: FloorLayout, host: int, dead: int, steps_max: int) -> Dictionary:
	var info := {host: {"first": -1, "rooms": [host], "doors": []}}
	var frontier := [host]
	var out := {}
	for step in range(1, steps_max + 1):
		var next := []
		for room: int in frontier:
			for d in f.door_rooms.size():
				var pair := f.door_rooms[d]
				if pair.x != room and pair.y != room:
					continue
				var to := pair.y if pair.x == room else pair.x
				if info.has(to) or to == dead or _sealed(f, to):
					continue
				var first: int = d if room == host else info[room]["first"]
				var rooms: Array = [to]
				rooms.append_array(info[room]["rooms"])
				var doors: Array = [d]
				doors.append_array(info[room]["doors"])
				info[to] = {"first": first, "rooms": rooms, "doors": doors}
				next.append(to)
				if (
					to != f.start_room
					and to != f.shop_room
					and to < f.spawn_points.size()
					and not f.spawn_points[to].is_empty()
				):
					out[to] = info[to]
		frontier = next
	return out


## A room the walk may not use and no switch may stand in: the boss room, a sealed fight (an arena, the Overrun room,
## a locked room, the curse room).
static func _sealed(f: FloorLayout, room: int) -> bool:
	return (
		room == f.boss_room
		or room == f.overrun_room
		or room == f.curse_room
		or f.arena_rooms.has(room)
		or f.lockdown_rooms.has(room)
	)


## The spawn spots of `room` that pass the rules (away from its doorways, the rewards and the item spots).
static func room_spots(f: FloorLayout, room: int, avoid: PackedVector2Array) -> PackedVector2Array:
	var ok := PackedVector2Array()
	if room >= f.spawn_points.size():
		return ok
	var approaches := f.door_approaches(room, 1.0)
	for q in f.spawn_points[room]:
		if (
			_far(q, approaches, DOOR_GAP_M)
			and _far(q, avoid, AVOID_M)
			and _far(q, f.item_spots, AVOID_M)
		):
			ok.append(q)
	return ok


## The walk (m) from `at` (a spot in way["rooms"][0]) through the rooms of `way` to `goal` in its last room; -1 when
## a leg has no path. `goal` is the door's (door_goal). `reaches` caches each room's grid.
static func path_m(
	f: FloorLayout, way: Dictionary, at: Vector2, goal: Vector2, reaches: Dictionary
) -> float:
	var rooms: Array = way["rooms"]
	var doors: Array = way["doors"]
	var total := 0.0
	var pos := at
	for i in rooms.size() - 1:
		var d: int = doors[i]
		var leg := walk_m(_reach_of(f, rooms[i], reaches), pos, side_point(f, d, rooms[i]))
		if leg < 0.0:
			return -1.0
		total += leg + f.door_depths[d] + 1.0
		pos = side_point(f, d, rooms[i + 1])
	var last := walk_m(_reach_of(f, rooms[rooms.size() - 1], reaches), pos, goal)
	return -1.0 if last < 0.0 else total + last


## `room`'s walkable grid over its rectangle and its doorways (cached in `reaches`).
static func _reach_of(f: FloorLayout, room: int, reaches: Dictionary) -> FloorReach:
	if reaches.has(room):
		return reaches[room]
	var area := f.rooms[room]
	for d in f.door_rooms.size():
		if f.door_rooms[d].x == room or f.door_rooms[d].y == room:
			area = area.merge(f.door_rect(d))
	var reach := FloorReach.new()
	reach.build(area, f.room_walls(room), PATH_CLEARANCE_M)
	reaches[room] = reach
	return reach


## The point 0.5 m inside `room` from doorway `door`'s wall face.
static func side_point(f: FloorLayout, door: int, room: int) -> Vector2:
	var into := -1.0 if f.door_rooms[door].x == room else 1.0  # the doorway points from x to y
	return (
		f.door_centers[door]
		+ Kin.dir(f.door_angles[door]) * into * (f.door_depths[door] * 0.5 + 0.5)
	)


## v0.9.5 TS: the lever inside the secret room, on the wall the door is in, a metre or so beside the doorway.
static func lever_spot(f: FloorLayout, room: int, door: int) -> Vector2:
	var along := Kin.dir(f.door_angles[door])
	var perp := Vector2(-along.y, along.x)
	var base := side_point(f, door, room)
	var rect := f.rooms[room].grow(-0.5)
	for side in [1.0, -1.0]:
		var q: Vector2 = base + perp * side * (f.door_widths[door] * 0.5 + 1.0)
		if rect.has_point(q):
			return q
	return base


## The point on the host's side of the door the walk counts to (0.5 m in from the host's wall face).
static func door_goal(f: FloorLayout, host: int, door: int) -> Vector2:
	return side_point(f, door, host)


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
