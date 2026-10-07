class_name BossRoomBuilder
extends RefCounted
## The boss room (v0.3.0 PLAN L4, "Boss room and portal"): after FloorGenerator.generate, a room of the boss's size
## (BossArenaSpec.cells, in grid cells) is attached to the farthest room through one doorway, the boss door, and the
## stone gate moves into it, against the wall opposite the door. The room sits on free grid cells (it never overlaps
## another room), so it is walled like any room: new walls where it borders nothing, the existing wall where it
## borders a room, cut for the door. Its interior comes from the spec's template (FloorLayout.Template; OPEN by
## default), kept only where it leaves the door, the gate and the room whole. If no side of the farthest room has
## free cells for it, the next farthest room hosts it (a room on the floor's edge always has a free side).
## Draws come from the `boss_room` stream, never `map`, so the rest of the floor is unchanged. Pure sim code.

## The boss door's gap (m), wider than a normal doorway so it reads as the way on.
const DOOR_WIDTH := 3.0
const _STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## The gate's facing on the boss room's +X, +Y, -X, -Y wall (it faces into the room).
const _SIDE_ANGLES := [2048, 3072, 0, 1024]
## The boss needs this much clear floor around where it appears.
const _SPAWN_CLEAR := 1.5
## Host spawn points closer than this to the boss door are dropped (no enemy appears in the doorway).
const _HOST_SPAWN_CLEAR := 3.0
const _DOOR_APPROACH := 1.4
const _NONE := -1


## Adds the boss room to `f` and moves the gate into it. Returns the boss room's index.
static func attach(f: FloorLayout, spec: BossArenaSpec = null, params: FloorParams = null) -> int:
	var p := params if params != null else FloorParams.defaults()
	var s := spec if spec != null else BossArenaSpec.new()
	var rng := RngStream.derive(f.seed_value, "boss_room")
	var place := _choose(f, p, s, rng)
	assert(not place.is_empty(), "no room can host the boss room")
	var host: int = place[0]
	var rect: Rect2i = place[1]
	var side: int = place[2]
	var door := _door_center(f, f.room_cells[host], rect, side)
	var hw := p.wall_half
	var interior := Rect2(
		f.grid_origin + Vector2(rect.position) * f.cell_pitch + Vector2(hw, hw),
		Vector2(rect.size) * f.cell_pitch - Vector2(hw, hw) * 2.0
	)
	# Walls: the structural ones (cut for the door, plus the boss room's own), then every interior piece.
	var structural: Array[Obb] = []
	var pieces: Array[Obb] = []
	for i in f.walls.size():
		if i < f.slab_first:
			structural.append(f.walls[i])
		elif Collide.circle_vs_obb(door, p.door_clear_radius, f.walls[i]) == Vector2.ZERO:
			pieces.append(f.walls[i])  # a host piece in the door's way is dropped
	f.boss_door_wall = _cut_door(structural, door, side)
	structural.append_array(_new_walls(f, p, rect))
	var boss := f.room_count()
	f.rooms.append(interior)
	f.room_cells.append(rect)
	f.room_template.append(s.template)
	f.spawn_points.append(PackedVector2Array())
	f.hops.append(f.hops[host] + 1)
	f.door_rooms.append(Vector2i(host, boss))
	f.door_centers.append(door)
	f.door_angles.append(side * 1024)
	f.boss_room = boss
	f.boss_host_room = host
	f.boss_door_center = door
	f.boss_door_angle = side * 1024
	f.boss_door_width = DOOR_WIDTH
	_place_gate(f, interior, side)
	f.walls = structural
	f.slab_first = structural.size()
	f.walls.append_array(pieces)
	f.walls.append_array(_furnish(f, p, rng, s.template))
	f.boss_spawn = _spawn_spot(f, p)
	var kept := PackedVector2Array()
	for q in f.spawn_points[host]:
		if Kin.length(q - door) >= _HOST_SPAWN_CLEAR:
			kept.append(q)
	f.spawn_points[host] = kept
	_grow_bounds(f, interior.grow(hw))
	return boss


## [host room, the boss room's cells, the side of the host it sits on], or [] if nothing fits. The farthest room
## is tried first; a placement whose door no host piece blocks wins over one that has to drop a piece.
static func _choose(f: FloorLayout, p: FloorParams, s: BossArenaSpec, rng: RngStream) -> Array:
	for host in _hosts(f):
		var sides := PackedInt32Array([0, 1, 2, 3])
		for i in range(3, 0, -1):
			var j := rng.range_int(0, i)
			var t := sides[i]
			sides[i] = sides[j]
			sides[j] = t
		var sizes: Array[Vector2i] = [s.cells]
		if s.cells.x != s.cells.y:
			sizes.append(Vector2i(s.cells.y, s.cells.x))
		var fallback := []
		for side in sides:
			for size in sizes:
				for rect in _candidates(f.room_cells[host], size, side, rng):
					if _overlaps(f, rect):
						continue
					var door := _door_center(f, f.room_cells[host], rect, side)
					if _door_clean(f, p, door):
						return [host, rect, side]
					if fallback.is_empty():
						fallback = [host, rect, side]
		if not fallback.is_empty():
			return fallback
	return []


## Rooms in the order they may host the boss room: the farthest (the old portal room), then the rest by hops,
## farthest first (lowest index on a tie), the start hall last.
static func _hosts(f: FloorLayout) -> PackedInt32Array:
	var out := PackedInt32Array([f.portal_room])
	var rest := []
	for room in f.room_count():
		if room != f.portal_room and room != f.start_room:
			rest.append(room)
	rest.sort_custom(
		func(a: int, b: int) -> bool:
			return f.hops[a] > f.hops[b] or (f.hops[a] == f.hops[b] and a < b)
	)
	for room: int in rest:
		out.append(room)
	if f.start_room != f.portal_room:
		out.append(f.start_room)
	return out


## Every placement of a `size` room against side `side` of `host` that shares at least one cell edge with it,
## starting from a random one.
static func _candidates(host: Rect2i, size: Vector2i, side: int, rng: RngStream) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var lo := 0
	var hi := 0
	if side % 2 == 0:
		lo = host.position.y - size.y + 1
		hi = host.end.y - 1
	else:
		lo = host.position.x - size.x + 1
		hi = host.end.x - 1
	var n := hi - lo + 1
	var k0 := rng.range_int(0, n - 1)
	for k in n:
		var along := lo + (k0 + k) % n
		var pos := Vector2i.ZERO
		match side:
			0:
				pos = Vector2i(host.end.x, along)
			1:
				pos = Vector2i(along, host.end.y)
			2:
				pos = Vector2i(host.position.x - size.x, along)
			_:
				pos = Vector2i(along, host.position.y - size.y)
		out.append(Rect2i(pos, size))
	return out


static func _overlaps(f: FloorLayout, rect: Rect2i) -> bool:
	for r in f.room_cells:
		if r.intersects(rect):
			return true
	return false


## The door's centre on the shared wall line: the middle of the cell edges the two rooms share.
static func _door_center(f: FloorLayout, host: Rect2i, rect: Rect2i, side: int) -> Vector2:
	var o := f.grid_origin
	var pitch := f.cell_pitch
	if side % 2 == 0:
		var x := host.end.x if side == 0 else host.position.x
		var y0 := maxi(host.position.y, rect.position.y)
		var y1 := mini(host.end.y, rect.end.y)
		return Vector2(o.x + x * pitch.x, o.y + (y0 + y1) * 0.5 * pitch.y)
	var y := host.end.y if side == 1 else host.position.y
	var x0 := maxi(host.position.x, rect.position.x)
	var x1 := mini(host.end.x, rect.end.x)
	return Vector2(o.x + (x0 + x1) * 0.5 * pitch.x, o.y + y * pitch.y)


## No interior piece of the host stands within a doorway's clear radius of the door.
static func _door_clean(f: FloorLayout, p: FloorParams, door: Vector2) -> bool:
	for i in range(f.slab_first, f.walls.size()):
		if Collide.circle_vs_obb(door, p.door_clear_radius, f.walls[i]) != Vector2.ZERO:
			return false
	return true


## Cuts the door's gap out of the structural wall it lies on and returns the collider that seals it (as thick as
## that wall, a little longer than the gap so it overlaps the cut ends).
static func _cut_door(structural: Array[Obb], door: Vector2, side: int) -> Obb:
	var horizontal := side % 2 == 1
	var half_gap := DOOR_WIDTH * 0.5
	for i in structural.size():
		var w := structural[i]
		if w.angle != 0 or not w.bounds().grow(0.01).has_point(door):
			continue
		var b := w.bounds()
		var lo := b.position.x if horizontal else b.position.y
		var hi := b.end.x if horizontal else b.end.y
		var cut := door.x if horizontal else door.y
		var thick := w.half.y if horizontal else w.half.x
		var fixed := w.center.y if horizontal else w.center.x
		structural.remove_at(i)
		for span: Vector2 in [Vector2(lo, cut - half_gap), Vector2(cut + half_gap, hi)]:
			if span.y - span.x > 0.001:
				structural.append(_piece(horizontal, fixed, span.x, span.y, thick))
		return _piece(horizontal, fixed, cut - half_gap - 0.05, cut + half_gap + 0.05, thick)
	assert(false, "no wall under the boss door")
	return null


static func _piece(horizontal: bool, fixed: float, lo: float, hi: float, thick: float) -> Obb:
	var mid := (lo + hi) * 0.5
	var half := (hi - lo) * 0.5
	if horizontal:
		return Obb.make(Vector2(mid, fixed), Vector2(half, thick), 0)
	return Obb.make(Vector2(fixed, mid), Vector2(thick, half), 0)


## Walls on every cell edge of the boss room that borders no room, merged into runs. Each run reaches one wall
## half past its ends, so the corners are closed.
static func _new_walls(f: FloorLayout, p: FloorParams, rect: Rect2i) -> Array[Obb]:
	var out: Array[Obb] = []
	var hw := p.wall_half
	var o := f.grid_origin
	var pitch := f.cell_pitch
	for side in 4:
		var horizontal := side % 2 == 1
		var n := rect.size.x if horizontal else rect.size.y
		var line := 0.0
		match side:
			0:
				line = o.x + rect.end.x * pitch.x
			1:
				line = o.y + rect.end.y * pitch.y
			2:
				line = o.x + rect.position.x * pitch.x
			_:
				line = o.y + rect.position.y * pitch.y
		var start := _NONE
		for k in n + 1:
			var open := false
			if k < n:
				var cell := (
					Vector2i(rect.position.x + k, rect.position.y)
					if horizontal
					else Vector2i(rect.position.x, rect.position.y + k)
				)
				if side == 0:
					cell.x = rect.end.x - 1
				elif side == 1:
					cell.y = rect.end.y - 1
				open = _room_at(f, cell + _STEPS[side]) == _NONE
			if open and start == _NONE:
				start = k
			elif not open and start != _NONE:
				var base := rect.position.x if horizontal else rect.position.y
				var step := pitch.x if horizontal else pitch.y
				var origin := o.x if horizontal else o.y
				var a := origin + (base + start) * step - hw
				var b := origin + (base + k) * step + hw
				out.append(_piece(horizontal, line, a, b, hw))
				start = _NONE
	return out


static func _room_at(f: FloorLayout, cell: Vector2i) -> int:
	for i in f.room_cells.size():
		if f.room_cells[i].has_point(cell):
			return i
	return _NONE


## The gate against the middle of the wall opposite the door, facing into the room.
static func _place_gate(f: FloorLayout, r: Rect2, side: int) -> void:
	var c := r.get_center()
	var face := c
	match side:
		0:
			face = Vector2(r.end.x, c.y)
		1:
			face = Vector2(c.x, r.end.y)
		2:
			face = Vector2(r.position.x, c.y)
		_:
			face = Vector2(c.x, r.position.y)
	f.portal_room = f.boss_room
	f.portal_angle = _SIDE_ANGLES[side]
	f.portal_pos = face + f.portal_facing() * FloorLayout.GATE_HALF_DEPTH


## The gate's footprint, its clear front square and a margin: kept free of interior pieces.
static func _gate_zone(f: FloorLayout) -> Rect2:
	var n := f.portal_facing()
	var t := Vector2(-n.y, n.x)
	var face := f.portal_pos - n * FloorLayout.GATE_HALF_DEPTH
	var half_w := FloorLayout.GATE_WIDTH * 0.5 + 1.0
	var depth := FloorLayout.GATE_HALF_DEPTH * 2.0 + FloorLayout.GATE_FRONT + 1.0
	return Rect2(face + t * half_w, Vector2.ZERO).expand(face - t * half_w + n * depth)


## The template's pieces that keep the door, the gate and the middle clear and leave the room one region.
static func _furnish(f: FloorLayout, p: FloorParams, rng: RngStream, template: int) -> Array[Obb]:
	var r := f.rooms[f.boss_room]
	var walls: Array[Obb] = []
	for w in f.walls:
		if w.bounds().intersects(r.grow(1.0)):
			walls.append(w)
	var kept: Array[Obb] = []
	for group: Array in RoomInterior.groups(template, r, rng, p, false):
		var ok := true
		for piece: Obb in group:
			ok = ok and _piece_allowed(f, p, r, piece, walls)
		if not ok:
			continue
		var trial: Array[Obb] = walls.duplicate()
		for piece: Obb in group:
			trial.append(piece)
		if _whole(f, p, r, trial):
			for piece: Obb in group:
				walls.append(piece)
				kept.append(piece)
	return kept


static func _piece_allowed(
	f: FloorLayout, p: FloorParams, r: Rect2, piece: Obb, walls: Array[Obb]
) -> bool:
	var b := piece.bounds()
	if not r.encloses(b) or b.intersects(_gate_zone(f)):
		return false
	if Collide.circle_vs_obb(f.boss_door_center, p.door_clear_radius + 1.0, piece) != Vector2.ZERO:
		return false
	for w in walls:
		if w.bounds().grow(p.slab_gap).intersects(b):
			return false
	return true


## The boss room's floor is one region holding the door's approach and the gate's front.
static func _whole(f: FloorLayout, p: FloorParams, r: Rect2, walls: Array[Obb]) -> bool:
	var reach := FloorReach.new()
	reach.build(r, walls, p.nav_clearance)
	if reach.region_count != 1:
		return false
	var inward := Kin.dir(f.boss_door_angle)
	var approach := f.boss_door_center + inward * (p.wall_half + _DOOR_APPROACH)
	return reach.region_at(approach) == 0 and reach.region_at(f.portal_front_point()) == 0


## Where the boss appears: the room's middle, or the open cell nearest it.
static func _spawn_spot(f: FloorLayout, p: FloorParams) -> Vector2:
	var r := f.rooms[f.boss_room]
	var walls: Array[Obb] = []
	for w in f.walls:
		if w.bounds().intersects(r.grow(1.0)):
			walls.append(w)
	walls.append(_gate_box(f))
	if _clear(r.get_center(), walls):
		return r.get_center()
	var reach := FloorReach.new()
	reach.build(r, walls, p.nav_clearance)
	var best := r.get_center()
	var best_d := INF
	for k in reach.size.x * reach.size.y:
		var q := reach.center(Vector2i(k % reach.size.x, k / reach.size.x))
		var d := Kin.length(q - r.get_center())
		if d < best_d and reach.region_at(q) == 0 and _clear(q, walls):
			best = q
			best_d = d
	return best


## The gate's stone footprint (the same shape as FloorScenario.gate_collider).
static func _gate_box(f: FloorLayout) -> Obb:
	var half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	return Obb.make(f.portal_pos, half, f.portal_angle)


static func _clear(q: Vector2, walls: Array[Obb]) -> bool:
	for w in walls:
		if Collide.circle_vs_obb(q, _SPAWN_CLEAR, w) != Vector2.ZERO:
			return false
	return true


static func _grow_bounds(f: FloorLayout, r: Rect2) -> void:
	f.bounds = f.bounds.merge(r)
	var lo := f.room_cells[0].position
	var hi := f.room_cells[0].end
	for c in f.room_cells:
		lo = Vector2i(mini(lo.x, c.position.x), mini(lo.y, c.position.y))
		hi = Vector2i(maxi(hi.x, c.end.x), maxi(hi.y, c.end.y))
	f.cols = hi.x - lo.x
	f.rows = hi.y - lo.y
