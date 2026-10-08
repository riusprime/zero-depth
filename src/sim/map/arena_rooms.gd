class_name ArenaRooms
extends RefCounted
## The floor's sealed arenas (v0.5.5 AR; PLAN D2, X1 "open floor, sealed arenas"): about a third of the combat rooms
## seal on entry and fight in waves (Arenas). Chosen after the boss room and the Overrun room are marked, from the
## rooms already generated, so the floor's walls and draws stay as they were:
## - a candidate is a combat room: not the start hall (the shrine stands there), the boss room, the boss room's host,
##   the portal room, the Overrun room (the hardest arena, marked on its own) or the room the shop takes
##   (ShopPlacement is a pure function of the layout); event rooms are picked later among the rooms left
##   (Events.pick_rooms keeps arenas out);
## - a candidate needs at least MIN_SPOTS spawn points (its waves spawn inside);
## - the target is round(combat rooms x share_permille / 1000), at least 1 when there is a candidate;
## - the candidates are taken in a fixed order (fewest doorways first, then the most doorway hops from the start hall,
##   then the lower room) while the target lasts, each only if, with every arena taken so far and the Overrun room
##   shut, every other room is still reachable from the start hall: an arena is always skippable (owner X1 Q3: "you
##   may skip fights"). No draw: the choice is a pure function of the layout (the floor seed already varies it), so
##   no stream is added to EI-05's list and no other draw moves.
## Pure sim code: integers, BFS over the doorway graph.

const MIN_SPOTS := 3


## Marks `f`'s arenas (FloorLayout.arena_rooms, ascending). Returns them.
static func mark(f: FloorLayout, share_permille: int) -> PackedInt32Array:
	f.arena_rooms = PackedInt32Array()
	if share_permille <= 0 or f.room_count() == 0:
		return f.arena_rooms
	var cands := candidates(f)
	var combat := cands.size()
	var target := (combat * share_permille + 500) / 1000
	if combat > 0:
		target = maxi(1, target)
	_order(f, cands)
	var shut := PackedInt32Array()
	if f.overrun_room >= 0:
		shut.append(f.overrun_room)
	var out := PackedInt32Array()
	for r in cands:
		if out.size() >= target:
			break
		if r >= f.spawn_points.size() or f.spawn_points[r].size() < MIN_SPOTS:
			continue
		var trial := shut.duplicate()
		trial.append_array(out)
		trial.append(r)
		if all_reachable(f, trial):
			out.append(r)
	out.sort()
	f.arena_rooms = out
	return out


## Sorts `rooms` in place: fewest doorways, then most hops from the start hall, then the lower index (insertion sort;
## a floor has about a dozen rooms).
static func _order(f: FloorLayout, rooms: PackedInt32Array) -> void:
	for k in range(1, rooms.size()):
		var r := rooms[k]
		var j := k - 1
		while j >= 0 and _before(f, r, rooms[j]):
			rooms[j + 1] = rooms[j]
			j -= 1
		rooms[j + 1] = r


static func _before(f: FloorLayout, a: int, b: int) -> bool:
	var da := f.neighbours(a).size()
	var db := f.neighbours(b).size()
	if da != db:
		return da < db
	var ha := f.hops[a] if a < f.hops.size() else 0
	var hb := f.hops[b] if b < f.hops.size() else 0
	if ha != hb:
		return ha > hb
	return a < b


## Combat rooms that may become arenas, ascending.
static func candidates(f: FloorLayout) -> PackedInt32Array:
	var out := PackedInt32Array()
	var shop := Routes.shop_room_of(f)
	for r in f.room_count():
		if r in [f.start_room, f.boss_room, f.boss_host_room, f.portal_room, f.overrun_room, shop]:
			continue
		out.append(r)
	return out


## Whether every room not in `shut` is reachable from the start hall without entering a room in `shut`.
static func all_reachable(f: FloorLayout, shut: PackedInt32Array) -> bool:
	var n := f.room_count()
	var seen := PackedByteArray()
	seen.resize(n)
	seen[f.start_room] = 1
	var queue := PackedInt32Array([f.start_room])
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		for nb in f.neighbours(r):
			if seen[nb] == 1 or shut.has(nb):
				continue
			seen[nb] = 1
			queue.append(nb)
	for r in n:
		if seen[r] == 0 and not shut.has(r):
			return false
	return true


## The doorways into room `room` (indices into the doorway arrays), ascending.
static func doors_of(f: FloorLayout, room: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in f.door_rooms.size():
		if f.door_rooms[i].x == room or f.door_rooms[i].y == room:
			out.append(i)
	return out


## The barrier that seals doorway `i` (its whole passage, a hair deeper so it meets both wall faces), as the boss
## door's seal is built (BossRoomBuilder).
static func barrier(f: FloorLayout, i: int) -> Obb:
	var rect := f.door_rect(i)
	var along_x := f.door_angles[i] % 2048 == 0
	var seal := rect.grow_individual(
		0.05 if along_x else 0.0,
		0.0 if along_x else 0.05,
		0.05 if along_x else 0.0,
		0.0 if along_x else 0.05
	)
	return Obb.make(seal.get_center(), seal.size * 0.5, 0)
