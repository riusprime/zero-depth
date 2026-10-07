class_name FloorGenerator
extends RefCounted
## Seeded floor generation (v0.2.0 PLAN L5, "Floor"): a grid of rooms joined by doorways (a random spanning tree
## plus extra links), interior slabs that never cut a room apart, a corner start room and a portal room farthest
## from it by doorways. Every draw comes from the `map` stream in a fixed order, so a seed always gives the same
## floor. Pure sim code: integer draws, floats from whole centimetres, no trig.

const _SIDE_ANGLES := [2048, 3072, 0, 1024]  # the gate's facing on the room's +X, +Y, -X, -Y wall
const _GATE_SLIDES := [0.0, 3.5, -3.5]
const _ITEM_ATTEMPTS := 64
const _SPAWN_ATTEMPTS_PER_POINT := 20
const _DOOR_APPROACH := 1.0  # metres in from the wall face, where a doorway's approach must be walkable


static func generate(seed_value: int, params: FloorParams = null) -> FloorLayout:
	var p := params if params != null else FloorParams.defaults()
	var rng := RngStream.derive(seed_value, "map")
	var f := FloorLayout.new()
	f.seed_value = seed_value
	f.cols = p.cols
	f.rows = p.rows
	_make_rooms(f, p)
	_make_doors(f, p, rng)
	f.start_room = _corner_rooms(f)[rng.range_int(0, 3)]
	f.start_pos = f.rooms[f.start_room].get_center()
	f.hops = _hops_from(f, f.start_room)
	f.portal_room = _farthest(f.hops)
	_place_portal(f, p, rng)
	_make_walls(f, p)
	f.slab_first = f.walls.size()
	for room in f.room_count():
		_place_slabs(f, p, rng, room)
	f.spawn_points.resize(f.room_count())
	for room in f.room_count():
		_place_spots(f, p, rng, room)
	return f


static func _cm(metres: float) -> int:
	return roundi(metres * 100.0)


static func _make_rooms(f: FloorLayout, p: FloorParams) -> void:
	var pitch := p.room_size + Vector2(p.wall_half, p.wall_half) * 2.0
	var total := Vector2(pitch.x * p.cols, pitch.y * p.rows)
	var origin := -total * 0.5
	f.bounds = Rect2(
		origin - Vector2(p.wall_half, p.wall_half), total + Vector2(p.wall_half, p.wall_half) * 2.0
	)
	for r in p.rows:
		for c in p.cols:
			var corner := (
				origin + Vector2(pitch.x * c, pitch.y * r) + Vector2(p.wall_half, p.wall_half)
			)
			f.rooms.append(Rect2(corner, p.room_size))


## Grid edges in a fixed order: each room's +X neighbour, then its +Y neighbour.
static func _grid_edges(f: FloorLayout) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	for r in f.rows:
		for c in f.cols:
			var i := r * f.cols + c
			if c + 1 < f.cols:
				edges.append(Vector2i(i, i + 1))
			if r + 1 < f.rows:
				edges.append(Vector2i(i, i + f.cols))
	return edges


## A random spanning tree (Prim's over the grid edges) plus extra links, then a doorway per link.
static func _make_doors(f: FloorLayout, p: FloorParams, rng: RngStream) -> void:
	var edges := _grid_edges(f)
	var n := f.room_count()
	var in_tree := PackedByteArray()
	in_tree.resize(n)
	in_tree[rng.range_int(0, n - 1)] = 1
	var used := PackedByteArray()
	used.resize(edges.size())
	for k in n - 1:
		var frontier := PackedInt32Array()
		for e in edges.size():
			if in_tree[edges[e].x] != in_tree[edges[e].y]:
				frontier.append(e)
		var pick := frontier[rng.range_int(0, frontier.size() - 1)]
		used[pick] = 1
		in_tree[edges[pick].x] = 1
		in_tree[edges[pick].y] = 1
	var spare := PackedInt32Array()
	for e in edges.size():
		if used[e] == 0:
			spare.append(e)
	var extra := mini(rng.range_int(p.extra_links_min, p.extra_links_max), spare.size())
	for k in extra:
		var at := rng.range_int(0, spare.size() - 1)
		used[spare[at]] = 1
		spare.remove_at(at)
	var jitter := _cm(p.door_jitter)
	for e in edges.size():
		if used[e] == 0:
			continue
		var a := edges[e].x
		var b := edges[e].y
		var ra := f.rooms[a]
		var slide := rng.range_int(-jitter, jitter) / 100.0
		f.door_rooms.append(edges[e])
		if b == a + 1:
			f.door_centers.append(Vector2(ra.end.x + p.wall_half, ra.get_center().y + slide))
			f.door_angles.append(0)
		else:
			f.door_centers.append(Vector2(ra.get_center().x + slide, ra.end.y + p.wall_half))
			f.door_angles.append(1024)


static func _corner_rooms(f: FloorLayout) -> PackedInt32Array:
	var last := f.room_count() - 1
	return PackedInt32Array([0, f.cols - 1, last - (f.cols - 1), last])


## Breadth-first doorway hops from a room (-1 for a room it can't reach).
static func _hops_from(f: FloorLayout, from: int) -> PackedInt32Array:
	var hops := PackedInt32Array()
	hops.resize(f.room_count())
	hops.fill(-1)
	hops[from] = 0
	var queue := PackedInt32Array([from])
	var head := 0
	while head < queue.size():
		var room := queue[head]
		head += 1
		for nb in f.neighbours(room):
			if hops[nb] == -1:
				hops[nb] = hops[room] + 1
				queue.append(nb)
	return hops


## The room with the most hops; ties go to the lowest room index.
static func _farthest(hops: PackedInt32Array) -> int:
	var best := 0
	for i in hops.size():
		if hops[i] > hops[best]:
			best = i
	return best


## Which side of a room a doorway is on (0 +X, 1 +Y, 2 -X, 3 -Y), or -1 if it doesn't touch the room.
static func _door_side(f: FloorLayout, door: int, room: int) -> int:
	var d := f.door_rooms[door]
	if d.x != room and d.y != room:
		return -1
	var low := d.x == room
	if f.door_angles[door] == 0:
		return 0 if low else 2
	return 1 if low else 3


## A point on the room's wall face at side (0 +X, 1 +Y, 2 -X, 3 -Y), slid along the wall from its middle.
static func _face_point(r: Rect2, side: int, slide: float) -> Vector2:
	match side:
		0:
			return Vector2(r.end.x, r.get_center().y + slide)
		1:
			return Vector2(r.get_center().x + slide, r.end.y)
		2:
			return Vector2(r.position.x, r.get_center().y + slide)
		_:
			return Vector2(r.get_center().x + slide, r.position.y)


## The gate stands against a wall of the portal room, clear of its doorways, facing into the room.
## Sides without a doorway are tried first, in a random order.
static func _place_portal(f: FloorLayout, p: FloorParams, rng: RngStream) -> void:
	var sides := PackedInt32Array([0, 1, 2, 3])
	for i in range(3, 0, -1):
		var j := rng.range_int(0, i)
		var t := sides[i]
		sides[i] = sides[j]
		sides[j] = t
	var r := f.rooms[f.portal_room]
	var keep := p.door_width * 0.5 + FloorLayout.GATE_WIDTH * 0.5 + 1.5
	for allow_doors in [false, true]:
		for side in sides:
			var along := PackedFloat32Array()
			for d in f.door_rooms.size():
				if _door_side(f, d, f.portal_room) == side:
					along.append(f.door_centers[d].y if side % 2 == 0 else f.door_centers[d].x)
			if not along.is_empty() and not allow_doors:
				continue
			for slide: float in _GATE_SLIDES:
				var at := _face_point(r, side, slide)
				var ok := true
				for a in along:
					if absf(a - (at.y if side % 2 == 0 else at.x)) < keep:
						ok = false
				if ok:
					f.portal_angle = _SIDE_ANGLES[side]
					f.portal_pos = at + f.portal_facing() * FloorLayout.GATE_HALF_DEPTH
					return
	assert(false, "no wall of the portal room fits the gate")


## The area kept free of slabs and spots around the gate: its footprint, the clear front square, and a margin.
static func _portal_zone(f: FloorLayout) -> Rect2:
	var n := f.portal_facing()
	var t := Vector2(-n.y, n.x)
	var face := f.portal_pos - n * FloorLayout.GATE_HALF_DEPTH
	var half_w := FloorLayout.GATE_WIDTH * 0.5 + 1.0
	var depth := FloorLayout.GATE_HALF_DEPTH * 2.0 + FloorLayout.GATE_FRONT + 1.0
	return Rect2(face + t * half_w, Vector2.ZERO).expand(face - t * half_w + n * depth)


## Outer walls and partitions: each grid line is one wall, broken at its doorways. Horizontal lines run the full
## width; vertical pieces fill between them, so walls never overlap.
static func _make_walls(f: FloorLayout, p: FloorParams) -> void:
	var hw := p.wall_half
	var pitch := p.room_size + Vector2(hw, hw) * 2.0
	var origin := f.bounds.position + Vector2(hw, hw)
	for r in f.rows + 1:
		var gaps := PackedFloat32Array()
		for d in f.door_rooms.size():
			if f.door_angles[d] == 1024 and f.door_rooms[d].x / f.cols + 1 == r:
				gaps.append(f.door_centers[d].x)
		var y := origin.y + pitch.y * r
		_emit_line(f, p, true, y, f.bounds.position.x, f.bounds.end.x, gaps)
	for c in f.cols + 1:
		for r in f.rows:
			var gaps := PackedFloat32Array()
			for d in f.door_rooms.size():
				var a := f.door_rooms[d].x
				if f.door_angles[d] == 0 and a % f.cols + 1 == c and a / f.cols == r:
					gaps.append(f.door_centers[d].y)
			var y0 := origin.y + pitch.y * r + hw
			_emit_line(f, p, false, origin.x + pitch.x * c, y0, y0 + p.room_size.y, gaps)


## Solid pieces of the line from lo to hi (along x if horizontal) at `fixed`, skipping a door gap at each centre.
static func _emit_line(
	f: FloorLayout,
	p: FloorParams,
	horizontal: bool,
	fixed: float,
	lo: float,
	hi: float,
	gaps: PackedFloat32Array
) -> void:
	gaps.sort()
	var cuts := PackedFloat32Array([lo])
	for g in gaps:
		cuts.append(g - p.door_width * 0.5)
		cuts.append(g + p.door_width * 0.5)
	cuts.append(hi)
	for k in range(0, cuts.size(), 2):
		var a := cuts[k]
		var b := cuts[k + 1]
		if b - a <= 0.001:
			continue
		var mid := (a + b) * 0.5
		var half := (b - a) * 0.5
		if horizontal:
			f.walls.append(Obb.make(Vector2(mid, fixed), Vector2(half, p.wall_half), 0))
		else:
			f.walls.append(Obb.make(Vector2(fixed, mid), Vector2(p.wall_half, half), 0))


## The walls that can touch a room: its partitions and outer walls, and the slabs inside it.
static func _room_walls(f: FloorLayout, room: int) -> Array[Obb]:
	var near := f.rooms[room].grow(1.0)
	var out: Array[Obb] = []
	for w in f.walls:
		if w.bounds().intersects(near):
			out.append(w)
	return out


## The doorways of a room, as approach points just inside it.
static func _door_approaches(f: FloorLayout, p: FloorParams, room: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for d in f.door_rooms.size():
		var side := _door_side(f, d, room)
		if side < 0:
			continue
		var inward := -Kin.dir(side * 1024)
		out.append(f.door_centers[d] + inward * (p.wall_half + _DOOR_APPROACH))
	return out


## The room's open floor is one region, and every place that must be reached is in it.
static func _room_is_whole(f: FloorLayout, p: FloorParams, room: int, walls: Array[Obb]) -> bool:
	var reach := FloorReach.new()
	reach.build(f.rooms[room], walls, p.nav_clearance)
	if reach.region_count != 1:
		return false
	var must := _door_approaches(f, p, room)
	if room == f.start_room:
		must.append(f.start_pos)
	if room == f.portal_room:
		must.append(f.portal_front_point())
	for q in must:
		if reach.region_at(q) != 0:
			return false
	return true


static func _slab_allowed(f: FloorLayout, p: FloorParams, room: int, slab: Obb) -> bool:
	var b := slab.bounds()
	if not f.rooms[room].encloses(b):
		return false
	if (
		room == f.start_room
		and Collide.circle_vs_obb(f.start_pos, p.start_clear_radius, slab) != Vector2.ZERO
	):
		return false
	if room == f.portal_room and b.intersects(_portal_zone(f)):
		return false
	for d in f.door_centers:
		if Collide.circle_vs_obb(d, p.door_clear_radius, slab) != Vector2.ZERO:
			return false
	return true


## The slab keeps `gap` from every wall: sampled along its centre line, every 0.25 m, with circles of its
## half-thickness plus the gap. Free-standing slabs leave no pocket at any grid alignment.
static func _slab_spaced(slab: Obb, walls: Array[Obb], gap: float) -> bool:
	var steps := int(ceil(slab.half.x / 0.25))
	for k in range(-steps, steps + 1):
		var q := slab.center + slab.axis_u * (slab.half.x * k / steps)
		if not _clear_of(q, slab.half.y + gap, walls):
			return false
	return true


static func _place_slabs(f: FloorLayout, p: FloorParams, rng: RngStream, room: int) -> void:
	var r := f.rooms[room]
	var count := rng.range_int(p.slabs_min, p.slabs_max)
	var walls := _room_walls(f, room)
	var slabs: Array[Obb] = []
	for s in count:
		for attempt in p.slab_attempts:
			var half_len := (
				rng.range_int(_cm(p.slab_half_len_min), _cm(p.slab_half_len_max)) / 100.0
			)
			var angle := rng.range_int(0, 7) * 512
			var cx := rng.range_int(_cm(r.position.x + 1.0), _cm(r.end.x - 1.0)) / 100.0
			var cy := rng.range_int(_cm(r.position.y + 1.0), _cm(r.end.y - 1.0)) / 100.0
			var slab := Obb.make(Vector2(cx, cy), Vector2(half_len, p.slab_half_thickness), angle)
			if not _slab_allowed(f, p, room, slab) or not _slab_spaced(slab, walls, p.slab_gap):
				continue
			var trial: Array[Obb] = walls.duplicate()
			trial.append(slab)
			if _room_is_whole(f, p, room, trial):
				walls = trial
				slabs.append(slab)
				break
	f.walls.append_array(slabs)


static func _clear_of(q: Vector2, radius: float, walls: Array[Obb]) -> bool:
	for w in walls:
		if Collide.circle_vs_obb(q, radius, w) != Vector2.ZERO:
			return false
	return true


static func _far_from_all(q: Vector2, points: PackedVector2Array, gap: float) -> bool:
	for o in points:
		if Kin.length(o - q) < gap:
			return false
	return true


## An open spot: in the room's region, clear of walls, out of the gate zone, away from doorways and the start.
static func _spot_ok(
	f: FloorLayout, reach: FloorReach, walls: Array[Obb], q: Vector2, clear: float
) -> bool:
	if reach.region_at(q) != 0 or not _clear_of(q, clear, walls):
		return false
	if f.room_of(q) == f.portal_room and _portal_zone(f).has_point(q):
		return false
	if not _far_from_all(q, f.door_centers, 2.0 + clear):
		return false
	return Kin.length(q - f.start_pos) >= 3.5


static func _random_cell(rng: RngStream, reach: FloorReach) -> Vector2:
	return reach.center(
		Vector2i(rng.range_int(0, reach.size.x - 1), rng.range_int(0, reach.size.y - 1))
	)


static func _place_spots(f: FloorLayout, p: FloorParams, rng: RngStream, room: int) -> void:
	var walls := _room_walls(f, room)
	var reach := FloorReach.new()
	reach.build(f.rooms[room], walls, p.nav_clearance)
	var item := Vector2.INF
	if room != f.start_room:
		for attempt in _ITEM_ATTEMPTS:
			var q := _random_cell(rng, reach)
			if _spot_ok(f, reach, walls, q, p.item_clearance):
				item = q
				break
		if item == Vector2.INF:
			item = _nearest_ok_cell(f, reach, walls, p.item_clearance, f.rooms[room].get_center())
		f.item_spots.append(item)
		f.item_rooms.append(room)
	var avoid := PackedVector2Array([item]) if item != Vector2.INF else PackedVector2Array()
	var target := rng.range_int(p.spawn_min, p.spawn_max)
	var spots := PackedVector2Array()
	for attempt in target * _SPAWN_ATTEMPTS_PER_POINT:
		if spots.size() >= target:
			break
		var q := _random_cell(rng, reach)
		if _spawn_ok(f, reach, walls, q, p, spots, avoid):
			spots.append(q)
	if spots.size() < target:
		for k in reach.size.x * reach.size.y:
			var q := reach.center(Vector2i(k % reach.size.x, k / reach.size.x))
			if spots.size() < target and _spawn_ok(f, reach, walls, q, p, spots, avoid):
				spots.append(q)
	f.spawn_points[room] = spots


static func _spawn_ok(
	f: FloorLayout,
	reach: FloorReach,
	walls: Array[Obb],
	q: Vector2,
	p: FloorParams,
	spots: PackedVector2Array,
	avoid: PackedVector2Array
) -> bool:
	if not _spot_ok(f, reach, walls, q, p.spawn_clearance):
		return false
	return _far_from_all(q, spots, p.spawn_spacing) and _far_from_all(q, avoid, 1.5)


## The valid cell nearest a point (first in cell order on a tie); a fallback when random draws all miss.
static func _nearest_ok_cell(
	f: FloorLayout, reach: FloorReach, walls: Array[Obb], clear: float, near: Vector2
) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for k in reach.size.x * reach.size.y:
		var q := reach.center(Vector2i(k % reach.size.x, k / reach.size.x))
		var d := Kin.length(q - near)
		if d < best_d and _spot_ok(f, reach, walls, q, clear):
			best = q
			best_d = d
	assert(best != Vector2.INF, "a room has no open cell for an item")
	return best
