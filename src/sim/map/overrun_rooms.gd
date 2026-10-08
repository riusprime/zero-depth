class_name OverrunRooms
extends RefCounted
## The Overrun threat branch's room (v0.4.0 AB; ROADMAP "Threat T branches"): one optional side room per floor,
## behind red-framed doorways, never on the way to the boss. Chosen after the boss room is attached
## (BossRoomBuilder.attach), from the rooms already generated, so the floor's walls and draws stay as they were:
## - a candidate is any room but the start hall, the boss room, the boss room's host and the portal room, that is
##   off the shortest doorway path from the hall to the boss room's host, and whose removal still leaves the hall and
##   the host joined (you never have to go through it);
## - among the candidates, those with the fewest doorways (a dead end when there is one) win; the pick among them is a
##   draw from the `map:overrun` sub-stream of the floor seed (never the `map` stream itself, so layouts don't move);
## - no candidate (a tiny floor): no Overrun on that floor (overrun_room stays -1).
## Pure sim code: integers, BFS over the doorway graph.


## Marks `f`'s Overrun room and its doorways. Returns the room, or -1.
static func mark(f: FloorLayout) -> int:
	f.overrun_room = -1
	f.overrun_doors = PackedInt32Array()
	var cands := candidates(f)
	if cands.is_empty():
		return -1
	var best := 1 << 30
	var fewest := PackedInt32Array()
	for room in cands:
		var d := f.neighbours(room).size()
		if d < best:
			best = d
			fewest = PackedInt32Array()
		if d == best:
			fewest.append(room)
	var rng := RngStream.derive(f.seed_value, "map:overrun")
	f.overrun_room = fewest[rng.range_int(0, fewest.size() - 1)]
	for i in f.door_rooms.size():
		if f.door_rooms[i].x == f.overrun_room or f.door_rooms[i].y == f.overrun_room:
			f.overrun_doors.append(i)
	return f.overrun_room


## Rooms that may hold the Overrun, ascending.
static func candidates(f: FloorLayout) -> PackedInt32Array:
	var out := PackedInt32Array()
	var target := f.boss_host_room if f.boss_room >= 0 else f.portal_room
	var path := shortest_path(f, f.start_room, target, -1)
	for room in f.room_count():
		if room in [f.start_room, f.boss_room, f.boss_host_room, f.portal_room]:
			continue
		if path.has(room):
			continue
		if shortest_path(f, f.start_room, target, room).is_empty():
			continue
		out.append(room)
	return out


## The rooms of a shortest doorway path from `a` to `b` (both included; BFS, lower room first on a tie) that never
## enters room `banned` (-1 = none). Empty when there is none.
static func shortest_path(f: FloorLayout, a: int, b: int, banned: int) -> PackedInt32Array:
	var n := f.room_count()
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-2)
	parent[a] = -1
	var queue := PackedInt32Array([a])
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		if r == b:
			break
		for nb in f.neighbours(r):
			if nb == banned or parent[nb] != -2:
				continue
			parent[nb] = r
			queue.append(nb)
	if parent[b] == -2:
		return PackedInt32Array()
	var out := PackedInt32Array()
	var r := b
	while r != -1:
		out.append(r)
		r = parent[r]
	out.reverse()
	return out
