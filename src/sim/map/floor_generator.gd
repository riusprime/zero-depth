class_name FloorGenerator
extends RefCounted
## Seeded floor generation, v2 (v0.2.0 PLAN L14-L15). A floor is 10-12 rooms on a grid of cells: a 3 x 3-cell start
## hall (one big room, no partitions), whose single exit is on a randomly chosen outer side, then rooms of 1 x 1 up
## to 3 x 3 cells grown outward, each joined by a doorway to a room already placed (a tree), plus one or two extra
## doorways between rooms that touch (loops; never into the hall). Each room gets an interior template (RoomInterior)
## that never blocks a doorway or splits the room; item spots (1 in a 1 x 1 room, 1-2 in bigger rooms, none in the
## hall) and spawn points scaled with its size. The portal room is the room farthest from the hall by doorways.
## Every draw comes from the `map` stream in a fixed order, so a seed always gives the same floor. Pure sim code:
## integer draws, floats from whole centimetres, no trig.

const _SIDE_ANGLES := [2048, 3072, 0, 1024]  # the gate's facing on the room's +X, +Y, -X, -Y wall
const _STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const _GATE_SLIDES := [0.0, 2.5, -2.5]
const _ITEM_ATTEMPTS := 64
const _SPAWN_ATTEMPTS_PER_POINT := 20
const _DOOR_APPROACH := 1.0  # metres in from the wall face, where a doorway's approach must be walkable
const _NONE := -1


## The floor plan on the cell grid, before it has metres.
class Plan:
	extends RefCounted
	var cells: Array[Rect2i] = []
	var occupied := {}  # Vector2i cell -> room
	## Doorway k: from room door_rooms[k].x (the lower index) through the side door_side[k] of its cell
	## door_cell[k], slid door_slide[k] metres along the wall from the cell edge's middle.
	var door_rooms: Array[Vector2i] = []
	var door_cell: Array[Vector2i] = []
	var door_side := PackedInt32Array()
	var door_slide := PackedFloat64Array()

	func add_room(r: Rect2i) -> void:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				occupied[Vector2i(x, y)] = cells.size()
		cells.append(r)

	func room_at(c: Vector2i) -> int:
		return occupied.get(c, _NONE)

	func linked(a: int, b: int) -> bool:
		return door_rooms.has(Vector2i(mini(a, b), maxi(a, b)))

	func min_cell() -> Vector2i:
		var m := cells[0].position
		for r in cells:
			m = Vector2i(mini(m.x, r.position.x), mini(m.y, r.position.y))
		return m

	func max_cell() -> Vector2i:
		var m := cells[0].end
		for r in cells:
			m = Vector2i(maxi(m.x, r.end.x), maxi(m.y, r.end.y))
		return m


static func generate(seed_value: int, params: FloorParams = null) -> FloorLayout:
	var p := params if params != null else FloorParams.defaults()
	var rng := RngStream.derive(seed_value, "map")
	var f := FloorLayout.new()
	f.seed_value = seed_value
	var plan := Plan.new()
	_place_rooms(plan, p, rng)
	_link_extra(plan, p, rng)
	_lay_out(f, p, plan)
	f.start_room = 0
	f.start_pos = f.rooms[0].get_center()
	f.hops = _hops_from(f, f.start_room)
	f.portal_room = _farthest(f.hops)
	_place_portal(f, p, rng)
	_make_walls(f, p, plan)
	f.slab_first = f.walls.size()
	for room in f.room_count():
		var cells := f.room_cells[room].size
		f.room_template.append(RoomInterior.pick(rng, cells, room == f.start_room))
	for room in f.room_count():
		_furnish(f, p, rng, room)
	f.spawn_points.resize(f.room_count())
	for room in f.room_count():
		_place_spots(f, p, rng, room)
	return f


static func _cm(metres: float) -> int:
	return roundi(metres * 100.0)


# --- the plan on the cell grid ---


## The hall, its one exit on a random side, then rooms grown from any room but the hall until the drawn count.
static func _place_rooms(plan: Plan, p: FloorParams, rng: RngStream) -> void:
	plan.add_room(Rect2i(Vector2i.ZERO, p.hall_cells))
	var target := rng.range_int(p.rooms_min, p.rooms_max)
	var side := rng.range_int(0, 3)
	var attempts := 0
	while plan.cells.size() < 2:
		attempts += 1
		assert(attempts <= p.place_attempts, "the hall's exit never fit")
		_try_attach(plan, p, rng, 0, side)
	attempts = 0
	while plan.cells.size() < target and attempts < p.place_attempts:
		attempts += 1
		var parent := rng.range_int(1, plan.cells.size() - 1)
		_try_attach(plan, p, rng, parent, rng.range_int(0, 3))
	assert(plan.cells.size() >= p.rooms_min, "the floor ran out of room")


## A room of a drawn footprint against side `side` of room `parent`, sharing at least one cell edge with it, and
## a doorway on a shared cell edge. False (nothing placed) if it overlaps a room or makes the floor too wide.
static func _try_attach(plan: Plan, p: FloorParams, rng: RngStream, parent: int, side: int) -> bool:
	var fp := p.footprints[rng.pick_weighted(p.footprint_weights)]
	var pr := plan.cells[parent]
	var pos := Vector2i.ZERO
	if side % 2 == 0:
		pos.y = rng.range_int(pr.position.y - fp.y + 1, pr.end.y - 1)
		pos.x = pr.end.x if side == 0 else pr.position.x - fp.x
	else:
		pos.x = rng.range_int(pr.position.x - fp.x + 1, pr.end.x - 1)
		pos.y = pr.end.y if side == 1 else pr.position.y - fp.y
	var rect := Rect2i(pos, fp)
	if not _fits(plan, p, rect):
		return false
	plan.add_room(rect)
	_add_door(plan, p, rng, parent, plan.cells.size() - 1, side)
	return true


static func _fits(plan: Plan, p: FloorParams, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if plan.room_at(Vector2i(x, y)) != _NONE:
				return false
	var lo := plan.min_cell()
	var hi := plan.max_cell()
	lo = Vector2i(mini(lo.x, rect.position.x), mini(lo.y, rect.position.y))
	hi = Vector2i(maxi(hi.x, rect.end.x), maxi(hi.y, rect.end.y))
	return hi.x - lo.x <= p.max_span and hi.y - lo.y <= p.max_span


## The side of room a that room b touches along a shared cell edge (0 +X, 1 +Y, 2 -X, 3 -Y), or -1.
static func _touching_side(a: Rect2i, b: Rect2i) -> int:
	var over_y := mini(a.end.y, b.end.y) - maxi(a.position.y, b.position.y)
	var over_x := mini(a.end.x, b.end.x) - maxi(a.position.x, b.position.x)
	if over_y > 0 and a.end.x == b.position.x:
		return 0
	if over_x > 0 and a.end.y == b.position.y:
		return 1
	if over_y > 0 and b.end.x == a.position.x:
		return 2
	if over_x > 0 and b.end.y == a.position.y:
		return 3
	return -1


## A doorway from room a (lower index) to room b, which touches a's side `side`: on a random shared cell edge.
static func _add_door(
	plan: Plan, p: FloorParams, rng: RngStream, a: int, b: int, side: int
) -> void:
	var ra := plan.cells[a]
	var rb := plan.cells[b]
	var cell := Vector2i.ZERO
	if side % 2 == 0:
		cell.y = rng.range_int(maxi(ra.position.y, rb.position.y), mini(ra.end.y, rb.end.y) - 1)
		cell.x = ra.end.x - 1 if side == 0 else ra.position.x
	else:
		cell.x = rng.range_int(maxi(ra.position.x, rb.position.x), mini(ra.end.x, rb.end.x) - 1)
		cell.y = ra.end.y - 1 if side == 1 else ra.position.y
	var jitter := _cm(p.door_jitter)
	plan.door_rooms.append(Vector2i(a, b))
	plan.door_cell.append(cell)
	plan.door_side.append(side)
	plan.door_slide.append(rng.range_int(-jitter, jitter) / 100.0)


## Extra doorways between touching rooms not yet joined (never the hall, whose one exit stays its only one).
static func _link_extra(plan: Plan, p: FloorParams, rng: RngStream) -> void:
	var pairs: Array[Vector3i] = []
	for a in range(1, plan.cells.size()):
		for b in range(a + 1, plan.cells.size()):
			var side := _touching_side(plan.cells[a], plan.cells[b])
			if side >= 0 and not plan.linked(a, b):
				pairs.append(Vector3i(a, b, side))
	var extra := mini(rng.range_int(p.extra_links_min, p.extra_links_max), pairs.size())
	for k in extra:
		var at := rng.range_int(0, pairs.size() - 1)
		var e := pairs[at]
		pairs.remove_at(at)
		_add_door(plan, p, rng, e.x, e.y, e.z)


# --- metres ---


## Grid line g lies at grid_origin + g * cell_pitch; the floor's bounding box is centred on the origin.
static func _lay_out(f: FloorLayout, p: FloorParams, plan: Plan) -> void:
	var hw := p.wall_half
	var lo := plan.min_cell()
	var hi := plan.max_cell()
	f.cols = hi.x - lo.x
	f.rows = hi.y - lo.y
	f.cell_pitch = p.cell_size + Vector2(hw, hw) * 2.0
	f.grid_origin = -Vector2(lo + hi) * 0.5 * f.cell_pitch
	var edge := f.grid_origin + Vector2(lo) * f.cell_pitch
	f.bounds = Rect2(
		edge - Vector2(hw, hw), Vector2(hi - lo) * f.cell_pitch + Vector2(hw, hw) * 2.0
	)
	for r in plan.cells:
		var corner := f.grid_origin + Vector2(r.position) * f.cell_pitch + Vector2(hw, hw)
		f.rooms.append(Rect2(corner, Vector2(r.size) * f.cell_pitch - Vector2(hw, hw) * 2.0))
		f.room_cells.append(r)
	for k in plan.door_rooms.size():
		var side := plan.door_side[k]
		var step := Vector2(_STEPS[side])
		var mid := f.grid_origin + (Vector2(plan.door_cell[k]) + Vector2(0.5, 0.5)) * f.cell_pitch
		var at := mid + step * f.cell_pitch * 0.5
		var slide := plan.door_slide[k]
		at += Vector2(0.0, slide) if side % 2 == 0 else Vector2(slide, 0.0)
		f.door_rooms.append(plan.door_rooms[k])
		f.door_centers.append(at)
		f.door_angles.append(side * 1024)


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
	if d.x == room:
		return f.door_angles[door] / 1024
	if d.y == room:
		return (f.door_angles[door] / 1024 + 2) % 4
	return -1


## A point on the room's wall face at side (0 +X, 1 +Y, 2 -X, 3 -Y), at the middle of its k-th cell along that
## side, slid along the wall.
static func _face_point(
	f: FloorLayout, p: FloorParams, room: int, side: int, k: int, slide: float
) -> Vector2:
	var r := f.rooms[room]
	var along := (
		Vector2(p.cell_size.x * 0.5 + k * f.cell_pitch.x, p.cell_size.y * 0.5 + k * f.cell_pitch.y)
		+ Vector2(slide, slide)
	)
	match side:
		0:
			return Vector2(r.end.x, r.position.y + along.y)
		1:
			return Vector2(r.position.x + along.x, r.end.y)
		2:
			return Vector2(r.position.x, r.position.y + along.y)
		_:
			return Vector2(r.position.x + along.x, r.position.y)


## The gate stands against a wall of the portal room, clear of its doorways, facing into the room.
## Sides without a doorway are tried first, in a random order, from a random cell along the side.
static func _place_portal(f: FloorLayout, p: FloorParams, rng: RngStream) -> void:
	var sides := PackedInt32Array([0, 1, 2, 3])
	for i in range(3, 0, -1):
		var j := rng.range_int(0, i)
		var t := sides[i]
		sides[i] = sides[j]
		sides[j] = t
	var cells := f.room_cells[f.portal_room].size
	var keep := p.door_width * 0.5 + FloorLayout.GATE_WIDTH * 0.5 + 1.5
	for allow_doors in [false, true]:
		for side in sides:
			var along := PackedFloat32Array()
			for d in f.door_rooms.size():
				if _door_side(f, d, f.portal_room) == side:
					along.append(f.door_centers[d].y if side % 2 == 0 else f.door_centers[d].x)
			if not along.is_empty() and not allow_doors:
				continue
			var n := cells.y if side % 2 == 0 else cells.x
			var k0 := rng.range_int(0, n - 1)
			for i in n:
				for slide: float in _GATE_SLIDES:
					var at := _face_point(f, p, f.portal_room, side, (k0 + i) % n, slide)
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


# --- walls ---


## True where the horizontal cell edge on grid line gy above cell (gx, gy) separates two rooms (or a room from
## nothing).
static func _h_edge(plan: Plan, gx: int, gy: int) -> bool:
	return plan.room_at(Vector2i(gx, gy - 1)) != plan.room_at(Vector2i(gx, gy))


static func _v_edge(plan: Plan, gx: int, gy: int) -> bool:
	return plan.room_at(Vector2i(gx - 1, gy)) != plan.room_at(Vector2i(gx, gy))


## A grid corner where a horizontal wall passes (its wall square is covered by that wall).
static func _covered(plan: Plan, gx: int, gy: int) -> bool:
	return _h_edge(plan, gx - 1, gy) or _h_edge(plan, gx, gy)


## Outer walls and partitions: every cell edge between two different rooms (or a room and nothing) is wall,
## merged into runs and broken at doorways. Horizontal runs cover the corner squares at their ends; vertical
## runs stop at a corner a horizontal wall covers, so walls never overlap.
static func _make_walls(f: FloorLayout, p: FloorParams, plan: Plan) -> void:
	var lo := plan.min_cell()
	var hi := plan.max_cell()
	var hw := p.wall_half
	for gy in range(lo.y, hi.y + 1):
		var running := false
		var start := 0
		for gx in range(lo.x, hi.x + 1):
			var wall := gx < hi.x and _h_edge(plan, gx, gy)
			if wall and not running:
				running = true
				start = gx
			elif not wall and running:
				var y := f.grid_origin.y + gy * f.cell_pitch.y
				var x0 := f.grid_origin.x + start * f.cell_pitch.x - hw
				var x1 := f.grid_origin.x + gx * f.cell_pitch.x + hw
				_emit_line(f, p, true, y, x0, x1, _gaps(f, true, y, x0, x1))
				running = false
	for gx in range(lo.x, hi.x + 1):
		var running := false
		var start := 0
		for gy in range(lo.y, hi.y + 1):
			var wall := gy < hi.y and _v_edge(plan, gx, gy)
			if running and (not wall or _covered(plan, gx, gy)):
				var x := f.grid_origin.x + gx * f.cell_pitch.x
				var y0 := f.grid_origin.y + start * f.cell_pitch.y
				y0 += hw if _covered(plan, gx, start) else -hw
				var y1 := f.grid_origin.y + gy * f.cell_pitch.y
				y1 -= hw if _covered(plan, gx, gy) else -hw
				_emit_line(f, p, false, x, y0, y1, _gaps(f, false, x, y0, y1))
				running = false
			if wall and not running:
				running = true
				start = gy


## The doorway centres (along the line) on the wall line at `fixed` between lo and hi.
static func _gaps(
	f: FloorLayout, horizontal: bool, fixed: float, lo: float, hi: float
) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for d in f.door_centers.size():
		var c := f.door_centers[d]
		var on_horizontal := f.door_angles[d] % 2048 == 1024
		if on_horizontal != horizontal:
			continue
		var line := c.y if horizontal else c.x
		var along := c.x if horizontal else c.y
		if absf(line - fixed) < 0.01 and along > lo and along < hi:
			out.append(along)
	return out


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
	var cuts := PackedFloat64Array([lo])
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


# --- interiors ---


## The walls that can touch a room: its partitions and outer walls, and the pieces inside it.
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


## The piece keeps `gap` from every wall: sampled along its long centre line, every 0.25 m, with circles of its
## short half-extent plus the gap. Free-standing pieces leave no pocket at any grid alignment.
static func _slab_spaced(slab: Obb, walls: Array[Obb], gap: float) -> bool:
	var along_u := slab.half.x >= slab.half.y
	var axis := slab.axis_u if along_u else slab.axis_v
	var half_long := slab.half.x if along_u else slab.half.y
	var half_short := slab.half.y if along_u else slab.half.x
	var steps := int(ceil(half_long / 0.25))
	for k in range(-steps, steps + 1):
		var q := slab.center + axis * (half_long * k / steps)
		if not _clear_of(q, half_short + gap, walls):
			return false
	return true


## A group of pieces fits when each piece is allowed and spaced from everything but its own group, and the room
## stays whole with it.
static func _group_fits(
	f: FloorLayout, p: FloorParams, room: int, walls: Array[Obb], group: Array
) -> bool:
	for piece: Obb in group:
		if not _slab_allowed(f, p, room, piece) or not _slab_spaced(piece, walls, p.slab_gap):
			return false
	var trial: Array[Obb] = walls.duplicate()
	for piece: Obb in group:
		trial.append(piece)
	return _room_is_whole(f, p, room, trial)


static func _furnish(f: FloorLayout, p: FloorParams, rng: RngStream, room: int) -> void:
	var walls := _room_walls(f, room)
	var pieces: Array[Obb] = []
	var template := f.room_template[room]
	if template == FloorLayout.Template.SCATTER:
		var cells := f.room_cell_count(room)
		var count := mini(
			p.scatter_cap,
			rng.range_int(cells * p.scatter_per_cell_min, cells * p.scatter_per_cell_max)
		)
		for s in count:
			for attempt in p.slab_attempts:
				var slab := _random_slab(f.rooms[room], p, rng)
				if _group_fits(f, p, room, walls, [slab]):
					walls.append(slab)
					pieces.append(slab)
					break
	else:
		var hall := room == f.start_room
		for group: Array in RoomInterior.groups(template, f.rooms[room], rng, p, hall):
			if _group_fits(f, p, room, walls, group):
				for piece: Obb in group:
					walls.append(piece)
					pieces.append(piece)
	f.walls.append_array(pieces)


static func _random_slab(r: Rect2, p: FloorParams, rng: RngStream) -> Obb:
	var half_len := rng.range_int(_cm(p.slab_half_len_min), _cm(p.slab_half_len_max)) / 100.0
	var angle := rng.range_int(0, 7) * 512
	var cx := rng.range_int(_cm(r.position.x + 1.0), _cm(r.end.x - 1.0)) / 100.0
	var cy := rng.range_int(_cm(r.position.y + 1.0), _cm(r.end.y - 1.0)) / 100.0
	return Obb.make(Vector2(cx, cy), Vector2(half_len, p.slab_half_thickness), angle)


# --- spots ---


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


## Item spots for a room: none in the hall, 1 in a 1 x 1 room, else 1 or 2 (2 more likely in a bigger room).
static func _item_count(f: FloorLayout, p: FloorParams, rng: RngStream, room: int) -> int:
	if room == f.start_room:
		return 0
	var cells := f.room_cell_count(room)
	if cells == 1:
		return 1
	var permille := mini(p.item_two_cap, p.item_two_base + p.item_two_per_cell * cells)
	return 2 if rng.chance_permille(permille) else 1


static func _place_spots(f: FloorLayout, p: FloorParams, rng: RngStream, room: int) -> void:
	var walls := _room_walls(f, room)
	var reach := FloorReach.new()
	reach.build(f.rooms[room], walls, p.nav_clearance)
	var items := PackedVector2Array()
	for n in _item_count(f, p, rng, room):
		var item := Vector2.INF
		for attempt in _ITEM_ATTEMPTS:
			var q := _random_cell(rng, reach)
			if (
				_spot_ok(f, reach, walls, q, p.item_clearance)
				and _far_from_all(q, items, p.item_spacing)
			):
				item = q
				break
		if item == Vector2.INF:
			item = _nearest_ok_cell(
				f, reach, walls, p.item_clearance, f.rooms[room].get_center(), items, p.item_spacing
			)
		if item == Vector2.INF:
			assert(not items.is_empty(), "a room has no open cell for an item")
			break
		items.append(item)
		f.item_spots.append(item)
		f.item_rooms.append(room)
	var cells := f.room_cell_count(room)
	var target := mini(
		p.spawn_cap,
		rng.range_int(
			p.spawn_min + p.spawn_min_per_extra_cell * (cells - 1),
			p.spawn_max + p.spawn_max_per_extra_cell * (cells - 1)
		)
	)
	var spots := PackedVector2Array()
	for attempt in target * _SPAWN_ATTEMPTS_PER_POINT:
		if spots.size() >= target:
			break
		var q := _random_cell(rng, reach)
		if _spawn_ok(f, reach, walls, q, p, spots, items):
			spots.append(q)
	if spots.size() < target:
		for k in reach.size.x * reach.size.y:
			var q := reach.center(Vector2i(k % reach.size.x, k / reach.size.x))
			if spots.size() < target and _spawn_ok(f, reach, walls, q, p, spots, items):
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


## The valid cell nearest a point (first in cell order on a tie), at least `gap` from every point of `away`; a
## fallback when random draws all miss. Vector2.INF if there is none.
static func _nearest_ok_cell(
	f: FloorLayout,
	reach: FloorReach,
	walls: Array[Obb],
	clear: float,
	near: Vector2,
	away: PackedVector2Array,
	gap: float
) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for k in reach.size.x * reach.size.y:
		var q := reach.center(Vector2i(k % reach.size.x, k / reach.size.x))
		var d := Kin.length(q - near)
		if d < best_d and _spot_ok(f, reach, walls, q, clear) and _far_from_all(q, away, gap):
			best = q
			best_d = d
	return best
