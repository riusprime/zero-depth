class_name BossRoomBuilder
extends RefCounted
## The boss room (v0.3.0 PLAN L4, "Boss room and portal"): after FloorGenerator.generate, a room of the boss's size
## (BossArenaSpec.cells, in grid cells) is attached to the farthest room through one doorway, the boss door, and the
## stone gate moves into it, against the wall opposite the door. The room sits on free grid cells (it never overlaps
## another room) and follows the generator's wall-thickness model (v0.3.0 L1): each side's half is drawn from
## wall_half_min..wall_half_max, except the side shared with the host, which keeps the host's half (the host's outer
## skin there becomes the boss room's frame, so the shared wall is twice the host side's half); a side is thickened
## where a neighbour's skin reaches further into its cells. Its frame strips (interior out to the grid lines) and its
## outer skins are added where no wall stands yet, and the door is cut through the full thickness. Its cells and new
## skins join FloorLayout.ground. Its interior comes from the spec's template (OPEN by default), kept only where it
## leaves the door, the gate and the room whole. If no side of the farthest room has free cells for it, the next
## farthest room hosts it (a room on the floor's edge always has a free side). Draws come from the `boss_room`
## stream, never `map`, so the rest of the floor is unchanged. Pure sim code.

## The boss door's gap (m), wider than most doorways so it reads as the way on.
const DOOR_WIDTH := 3.0
const _STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## The gate's facing on the boss room's +X, +Y, -X, -Y wall (it faces into the room).
const _SIDE_ANGLES := [2048, 3072, 0, 1024]
## The boss needs this much clear floor around where it appears.
const _SPAWN_CLEAR := 1.5
## Host spawn points closer than this to the boss door's host face are dropped (no enemy appears in the doorway).
const _HOST_SPAWN_CLEAR := 3.0
const _DOOR_APPROACH := 1.4
const _SLIVER := 0.01
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
	var cell := _cell_rect(f, rect)
	var structural: Array[Obb] = []
	for i in f.slab_first:
		structural.append(f.walls[i])
	# Halves: drawn, the host side's from the host, then thickened past any wall already in the cells.
	var halves := PackedFloat64Array()
	for k in 4:
		halves.append(rng.range_int(_cm(p.wall_half_min), _cm(p.wall_half_max)) / 100.0)
	var back := (side + 2) % 4
	halves[back] = f.room_halves[host * 4 + side]
	halves = _thicken(cell, halves, structural)
	var interior := _inset(cell, halves)
	# The door: across the shared stretch's middle, from the host's face to the boss room's.
	var door := _door_rect(f, host, side, interior)
	var width := door.size.x if side % 2 == 1 else door.size.y
	var door_center := door.get_center()
	var host_face := door_center - Kin.dir(side * 1024) * _depth(door, side) * 0.5
	var pieces: Array[Obb] = []
	for i in range(f.slab_first, f.walls.size()):
		if Collide.circle_vs_obb(host_face, p.door_clear_radius, f.walls[i]) == Vector2.ZERO:
			pieces.append(f.walls[i])  # a host piece in the door's way is dropped
	# The frame and skins, where no wall stands yet; then the door cut through everything on its rect.
	var blockers: Array[Rect2] = []
	for w in structural:
		blockers.append(w.bounds())
	var fresh: Array[Rect2] = []
	for strip in _strips(cell, interior):
		fresh.append_array(_subtract_all(strip, blockers))
	var skins := _skins(f, rect, cell, halves)
	for skin in skins:
		fresh.append_array(_subtract_all(skin, blockers))
	for r in fresh:
		if r.size.x > _SLIVER and r.size.y > _SLIVER:
			structural.append(Obb.make(r.get_center(), r.size * 0.5, 0))
	structural = _cut(structural, door)
	# Ground: the room's cells and its skins, less what is already ground.
	var ground_new: Array[Rect2] = [cell]
	ground_new.append_array(skins)
	for g in ground_new:
		for r in _subtract_all(g, f.ground):
			if r.size.x > _SLIVER and r.size.y > _SLIVER:
				f.ground.append(r)
	var boss := f.room_count()
	f.rooms.append(interior)
	f.room_halves.append_array(halves)
	f.room_cells.append(rect)
	f.room_template.append(s.template)
	f.spawn_points.append(PackedVector2Array())
	f.hops.append(f.hops[host] + 1)
	f.door_rooms.append(Vector2i(host, boss))
	f.door_centers.append(door_center)
	f.door_angles.append(side * 1024)
	f.door_widths.append(width)
	f.door_depths.append(_depth(door, side))
	f.boss_room = boss
	f.boss_host_room = host
	f.boss_door_index = f.door_centers.size() - 1
	f.boss_door_center = door_center
	f.boss_door_angle = side * 1024
	f.boss_door_width = width
	f.boss_cells_rect = cell
	var seal := door.grow_individual(
		0.05 if side % 2 == 1 else 0.0,
		0.05 if side % 2 == 0 else 0.0,
		0.05 if side % 2 == 1 else 0.0,
		0.05 if side % 2 == 0 else 0.0
	)
	f.boss_door_wall = Obb.make(seal.get_center(), seal.size * 0.5, 0)
	_place_gate(f, interior, side)
	f.walls = structural
	f.slab_first = structural.size()
	f.walls.append_array(pieces)
	f.walls.append_array(_furnish(f, p, rng, s.template))
	f.boss_spawn = _spawn_spot(f, p)
	var kept := PackedVector2Array()
	for q in f.spawn_points[host]:
		if Kin.length(q - host_face) >= _HOST_SPAWN_CLEAR:
			kept.append(q)
	f.spawn_points[host] = kept
	var m := p.wall_half_max
	f.bounds = f.bounds.merge(cell.grow(m))
	_grid_extent(f)
	return boss


static func _cm(metres: float) -> int:
	return roundi(metres * 100.0)


## A room's cells in metres, grid line to grid line.
static func _cell_rect(f: FloorLayout, cells: Rect2i) -> Rect2:
	var a := f.grid_origin + Vector2(cells.position) * f.cell_pitch
	var b := f.grid_origin + Vector2(cells.end) * f.cell_pitch
	return Rect2(a, b - a)


static func _inset(cell: Rect2, halves: PackedFloat64Array) -> Rect2:
	var a := cell.position + Vector2(halves[2], halves[3])
	var b := cell.end - Vector2(halves[0], halves[1])
	return Rect2(a, b - a)


## The halves, each raised until no existing wall reaches into the interior.
static func _thicken(
	cell: Rect2, drawn: PackedFloat64Array, walls: Array[Obb]
) -> PackedFloat64Array:
	var halves := drawn.duplicate()
	var r := _inset(cell, halves)
	for pass_k in 8:
		var moved := false
		for w in walls:
			var b := w.bounds()
			if not b.intersects(r.grow(-0.001)):
				continue
			# The side whose grid line the wall reaches in from: the least penetration.
			var depth := [
				cell.end.x - b.position.x,
				cell.end.y - b.position.y,
				b.end.x - cell.position.x,
				b.end.y - cell.position.y
			]
			var best := 0
			for k in 4:
				if depth[k] < depth[best]:
					best = k
			halves[best] = maxf(halves[best], depth[best])
			r = _inset(cell, halves)
			moved = true
		if not moved:
			break
	assert(r.size.x > 4.0 and r.size.y > 4.0, "the boss room's walls ate its interior")
	return halves


## The doorway rect: DOOR_WIDTH along the shared wall (less where the stretch both interiors face is short, keeping
## door_corner_margin from the corners) at the stretch's middle, from the host's face to the boss room's.
static func _door_rect(f: FloorLayout, host: int, side: int, interior: Rect2) -> Rect2:
	var hr := f.rooms[host]
	var along_x := side % 2 == 1
	var lo := (
		maxf(hr.position.x, interior.position.x)
		if along_x
		else maxf(hr.position.y, interior.position.y)
	)
	var hi := minf(hr.end.x, interior.end.x) if along_x else minf(hr.end.y, interior.end.y)
	var mid := roundi((lo + hi) * 50.0) / 100.0
	var a := 0.0
	var b := 0.0
	match side:
		0:
			a = hr.end.x
			b = interior.position.x
		1:
			a = hr.end.y
			b = interior.position.y
		2:
			a = interior.end.x
			b = hr.position.x
		_:
			a = interior.end.y
			b = hr.position.y
	var margin := FloorParams.defaults().door_corner_margin
	var width := minf(DOOR_WIDTH, floorf((hi - lo - 2.0 * margin) * 100.0) / 100.0)
	assert(width >= FloorParams.defaults().door_width_min, "the boss door has no room")
	var half := width * 0.5
	if along_x:
		return Rect2(mid - half, a, width, b - a)
	return Rect2(a, mid - half, b - a, width)


## The door's depth through the wall.
static func _depth(door: Rect2, side: int) -> float:
	return door.size.y if side % 2 == 1 else door.size.x


## The four frame strips from the interior out to the grid lines (the -Y and +Y strips run over the corners).
static func _strips(c: Rect2, r: Rect2) -> Array[Rect2]:
	return [
		Rect2(c.position.x, c.position.y, c.size.x, r.position.y - c.position.y),
		Rect2(c.position.x, r.end.y, c.size.x, c.end.y - r.end.y),
		Rect2(c.position.x, r.position.y, r.position.x - c.position.x, r.size.y),
		Rect2(r.end.x, r.position.y, c.end.x - r.end.x, r.size.y),
	]


## Skins outside the grid lines on every run of side cells with no room beyond, as thick as the side's half; the -Y
## and +Y skins run over a free corner (as FloorGenerator does).
static func _skins(
	f: FloorLayout, rect: Rect2i, cell: Rect2, halves: PackedFloat64Array
) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for side in 4:
		var along_x := side % 2 == 1
		var along := Vector2i(1, 0) if along_x else Vector2i(0, 1)
		var first := rect.position
		if side == 0:
			first.x = rect.end.x - 1
		elif side == 1:
			first.y = rect.end.y - 1
		var n := rect.size.x if along_x else rect.size.y
		var h := halves[side]
		var step := _STEPS[side]
		var k := 0
		while k < n:
			if _room_at(f, first + along * k + step) != _NONE:
				k += 1
				continue
			var k1 := k
			while k1 < n and _room_at(f, first + along * k1 + step) == _NONE:
				k1 += 1
			var c0 := _cell_rect(f, Rect2i(first + along * k, Vector2i.ONE))
			var c1 := _cell_rect(f, Rect2i(first + along * (k1 - 1), Vector2i.ONE))
			var lo := c0.position.x if along_x else c0.position.y
			var hi := c1.end.x if along_x else c1.end.y
			if along_x:
				if k == 0 and _free_corner(f, first, step, Vector2i(-1, 0)):
					lo -= halves[2]
				if k1 == n and _free_corner(f, first + along * (n - 1), step, Vector2i(1, 0)):
					hi += halves[0]
			var line := 0.0
			match side:
				0:
					line = cell.end.x
				1:
					line = cell.end.y
				2:
					line = cell.position.x - h
				_:
					line = cell.position.y - h
			out.append(Rect2(lo, line, hi - lo, h) if along_x else Rect2(line, lo, h, hi - lo))
			k = k1
	return out


static func _free_corner(f: FloorLayout, c: Vector2i, out: Vector2i, side_step: Vector2i) -> bool:
	return _room_at(f, c + side_step) == _NONE and _room_at(f, c + side_step + out) == _NONE


## `r` less every blocker (axis-aligned), as up to four pieces per blocker.
static func _subtract_all(r: Rect2, blockers: Array[Rect2]) -> Array[Rect2]:
	var parts: Array[Rect2] = [r]
	for b in blockers:
		var next: Array[Rect2] = []
		for q in parts:
			next.append_array(_subtract(q, b))
		parts = next
	return parts


static func _subtract(q: Rect2, b: Rect2) -> Array[Rect2]:
	var i := q.intersection(b)
	if i.size.x <= _SLIVER or i.size.y <= _SLIVER:
		return [q]
	var out: Array[Rect2] = []
	if i.position.y - q.position.y > _SLIVER:
		out.append(Rect2(q.position.x, q.position.y, q.size.x, i.position.y - q.position.y))
	if q.end.y - i.end.y > _SLIVER:
		out.append(Rect2(q.position.x, i.end.y, q.size.x, q.end.y - i.end.y))
	if i.position.x - q.position.x > _SLIVER:
		out.append(Rect2(q.position.x, i.position.y, i.position.x - q.position.x, i.size.y))
	if q.end.x - i.end.x > _SLIVER:
		out.append(Rect2(i.end.x, i.position.y, q.end.x - i.end.x, i.size.y))
	return out


## Every axis-aligned wall less the door's rect.
static func _cut(walls: Array[Obb], door: Rect2) -> Array[Obb]:
	var out: Array[Obb] = []
	var gap: Array[Rect2] = [door]
	for w in walls:
		var b := w.bounds()
		if w.angle != 0 or not b.intersects(door):
			out.append(w)
			continue
		for r in _subtract_all(b, gap):
			if r.size.x > _SLIVER and r.size.y > _SLIVER:
				out.append(Obb.make(r.get_center(), r.size * 0.5, 0))
	return out


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
					if _overlaps(f, rect) or not _shares_enough(f, p, host, rect, side):
						continue
					if _door_clean(f, p, _host_face(f, host, rect, side)):
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


## The host's interior and the boss room's interior (at its thickest walls, wall_half_max a side) share room for
## the narrowest doorway plus the corner margins.
static func _shares_enough(
	f: FloorLayout, p: FloorParams, host: int, rect: Rect2i, side: int
) -> bool:
	var hr := f.rooms[host]
	var c := _cell_rect(f, rect).grow(-p.wall_half_max)
	var along_x := side % 2 == 1
	var lo := maxf(hr.position.x, c.position.x) if along_x else maxf(hr.position.y, c.position.y)
	var hi := minf(hr.end.x, c.end.x) if along_x else minf(hr.end.y, c.end.y)
	return hi - lo >= p.door_width_min + 2.0 * p.door_corner_margin


## Where the door will meet the host's face (the middle of the shared stretch of the host's interior edge).
static func _host_face(f: FloorLayout, host: int, rect: Rect2i, side: int) -> Vector2:
	var hr := f.rooms[host]
	var c := _cell_rect(f, rect)
	var along_x := side % 2 == 1
	var lo := maxf(hr.position.x, c.position.x) if along_x else maxf(hr.position.y, c.position.y)
	var hi := minf(hr.end.x, c.end.x) if along_x else minf(hr.end.y, c.end.y)
	var mid := (lo + hi) * 0.5
	match side:
		0:
			return Vector2(hr.end.x, mid)
		1:
			return Vector2(mid, hr.end.y)
		2:
			return Vector2(hr.position.x, mid)
	return Vector2(mid, hr.position.y)


## No interior piece of the host stands within a doorway's clear radius of the door's host face.
static func _door_clean(f: FloorLayout, p: FloorParams, face: Vector2) -> bool:
	for i in range(f.slab_first, f.walls.size()):
		if Collide.circle_vs_obb(face, p.door_clear_radius, f.walls[i]) != Vector2.ZERO:
			return false
	return true


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


## The door's approach point just inside the boss room.
static func _inner_approach(f: FloorLayout) -> Vector2:
	var into := Kin.dir(f.boss_door_angle)
	var depth := f.door_depths[f.boss_door_index]
	return f.boss_door_center + into * (depth * 0.5 + _DOOR_APPROACH)


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
	if Collide.circle_vs_obb(_inner_approach(f), p.door_clear_radius, piece) != Vector2.ZERO:
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
	return reach.region_at(_inner_approach(f)) == 0 and reach.region_at(f.portal_front_point()) == 0


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


static func _grid_extent(f: FloorLayout) -> void:
	var lo := f.room_cells[0].position
	var hi := f.room_cells[0].end
	for c in f.room_cells:
		lo = Vector2i(mini(lo.x, c.position.x), mini(lo.y, c.position.y))
		hi = Vector2i(maxi(hi.x, c.end.x), maxi(hi.y, c.end.y))
	f.cols = hi.x - lo.x
	f.rows = hi.y - lo.y
