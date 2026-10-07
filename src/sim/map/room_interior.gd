class_name RoomInterior
extends RefCounted
## Interior templates for a floor's rooms (v0.2.0 PLAN L14), scaled to the room. Each template proposes pieces
## in groups (a group is one obstacle: a pillar, a slab, an L of two slabs); FloorGenerator keeps a group only if
## it keeps its distance, leaves doorways, the start and the gate clear, and leaves the room one region. So a
## template never blocks a door or splits a room; at worst it loses a piece. All pieces are axis-aligned
## (angle 0). Pure sim code: draws from the `map` stream, floats from whole centimetres, no trig.
## SCATTER (random slabs) is placed by FloorGenerator itself, slab by slab.

## Free space from a wall face to a piece's edge: the generator's gap plus a margin.
const EDGE := 2.6
const T := FloorLayout.Template

## Template weights, in Template order: OPEN, SCATTER, PILLARS, CENTRE, CROSS, LINES, BUNKERS.
const _W_HALL := [0, 3, 3, 2, 2, 1, 3]
const _W_SMALL := [2, 4, 2, 3, 1, 1, 2]
const _W_LONG := [1, 2, 1, 1, 1, 6, 1]
const _W_BIG := [1, 3, 3, 3, 2, 2, 3]


## The template weights for a room of `cells` (the start hall has its own: never open, never a solid block).
static func weights(cells: Vector2i, hall: bool) -> PackedInt32Array:
	if hall:
		return PackedInt32Array(_W_HALL)
	if cells == Vector2i(1, 1):
		return PackedInt32Array(_W_SMALL)
	if mini(cells.x, cells.y) == 1 and maxi(cells.x, cells.y) >= 3:
		return PackedInt32Array(_W_LONG)
	return PackedInt32Array(_W_BIG)


## A template for a room, drawn from the map stream by weights (templates weighted 0 can't be drawn).
static func pick(rng: RngStream, cells: Vector2i, hall: bool) -> int:
	var w := weights(cells, hall)
	var ids := PackedInt32Array()
	var positive := PackedInt32Array()
	for t in w.size():
		if w[t] > 0:
			ids.append(t)
			positive.append(w[t])
	return ids[rng.pick_weighted(positive)]


static func _cm(metres: float) -> float:
	return roundi(metres * 100.0) / 100.0


## An axis-aligned piece from lo to hi (corners).
static func _box(lo: Vector2, hi: Vector2) -> Obb:
	var a := Vector2(_cm(lo.x), _cm(lo.y))
	var b := Vector2(_cm(hi.x), _cm(hi.y))
	return Obb.make((a + b) * 0.5, (b - a) * 0.5, 0)


## The candidate groups of a template for room interior r, in the order they should be tried.
static func groups(template: int, r: Rect2, rng: RngStream, p: FloorParams, hall: bool) -> Array:
	match template:
		T.PILLARS:
			return _pillars(r, rng)
		T.CENTRE:
			return _centre(r, rng, p, hall)
		T.CROSS:
			return _cross(r, rng, p, hall)
		T.LINES:
			return _lines(r, rng, p)
		T.BUNKERS:
			return _bunkers(r, rng, p)
	return []


## A grid of square pillars; in a big room every other one (a checkerboard).
static func _pillars(r: Rect2, rng: RngStream) -> Array:
	var pitch := rng.range_int(500, 650) / 100.0
	var half := rng.range_int(45, 65) / 100.0
	var span := r.size - Vector2(EDGE + half, EDGE + half) * 2.0
	var n := Vector2i(maxi(1, int(span.x / pitch) + 1), maxi(1, int(span.y / pitch) + 1))
	var checker := n.x * n.y > 12
	var phase := rng.range_int(0, 1)
	var c := r.get_center()
	var out := []
	for j in n.y:
		for i in n.x:
			if checker and (i + j + phase) % 2 == 1:
				continue
			var q := c + Vector2((i - (n.x - 1) * 0.5) * pitch, (j - (n.y - 1) * 0.5) * pitch)
			out.append([_box(q - Vector2(half, half), q + Vector2(half, half))])
	return out


## A solid block in the middle with a walkway around it, or (in a room at least two cells each way, and always in
## the hall, where the start is the middle) a ring of four L corners with an opening in the middle of each side.
static func _centre(r: Rect2, rng: RngStream, p: FloorParams, hall: bool) -> Array:
	var c := r.get_center()
	var ring := hall or (minf(r.size.x, r.size.y) >= 20.0 and rng.chance_permille(500))
	if not ring:
		var h := Vector2(maxf(1.0, r.size.x * 0.15), maxf(0.8, r.size.y * 0.15))
		return [[_box(c - h, c + h)]]
	var t := p.slab_half_thickness
	var hx := r.size.x * 0.2
	var hy := r.size.y * 0.2
	var o := rng.range_int(150, 190) / 100.0  # half the opening in the middle of each side
	var out := []
	for sy: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			var arm_x := _box(
				c + Vector2(sx * o, sy * (hy - t)), c + Vector2(sx * (hx + t), sy * (hy + t))
			)
			var arm_y := _box(
				c + Vector2(sx * (hx - t), sy * o), c + Vector2(sx * (hx + t), sy * (hy - t))
			)
			out.append([_fix(arm_x), _fix(arm_y)])
	return out


## A box made from two opposite corners in any order.
static func _fix(o: Obb) -> Obb:
	return Obb.make(o.center, Vector2(absf(o.half.x), absf(o.half.y)), 0)


## Low walls along the room's two middle lines, with a gap at the centre and at both walls; long arms are
## broken in the middle too. In the hall the centre gap is wider, around the start.
static func _cross(r: Rect2, rng: RngStream, p: FloorParams, hall: bool) -> Array:
	var c := r.get_center()
	var t := p.slab_half_thickness
	var g := rng.range_int(240, 300) / 100.0
	if hall:
		g += p.start_clear_radius - 2.0
	var out := []
	for axis in 2:
		var reach := (r.size.x if axis == 0 else r.size.y) * 0.5 - EDGE
		for s: float in [-1.0, 1.0]:
			for span: Vector2 in _split(g, reach):
				var a := span.x * s
				var b := span.y * s
				if axis == 0:
					out.append([_fix(_box(c + Vector2(a, -t), c + Vector2(b, t)))])
				else:
					out.append([_fix(_box(c + Vector2(-t, a), c + Vector2(t, b)))])
	return out


## The pieces of an arm from `from` to `to` (distances from the centre): one piece, or two around a 3 m gap when
## it is long. Pieces shorter than 1 m are dropped.
static func _split(from: float, to: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if to - from < 1.0:
		return out
	if to - from <= 9.0:
		out.append(Vector2(from, to))
		return out
	var mid := (from + to) * 0.5
	out.append(Vector2(from, mid - 1.5))
	out.append(Vector2(mid + 1.5, to))
	return out


## Long broken lines of cover along the room's long axis (two, or three in a wide room), staggered.
static func _lines(r: Rect2, rng: RngStream, p: FloorParams) -> Array:
	var along_x := r.size.x >= r.size.y
	var long := r.size.x if along_x else r.size.y
	var short := r.size.y if along_x else r.size.x
	var k := 2 if short < 20.0 else 3
	var t := p.slab_half_thickness
	var out := []
	for i in k:
		var across := short * (i + 1) / (k + 1)
		var pos := EDGE + (rng.range_int(150, 300) / 100.0 if i % 2 == 1 else 0.0)
		var stop := long - EDGE
		while stop - pos >= 1.5:
			var seg := minf(rng.range_int(300, 600) / 100.0, stop - pos)
			if seg >= 1.5:
				var lo := Vector2(pos, across - t)
				var hi := Vector2(pos + seg, across + t)
				if not along_x:
					lo = Vector2(lo.y, lo.x)
					hi = Vector2(hi.y, hi.x)
				out.append([_box(r.position + lo, r.position + hi)])
			pos += seg + rng.range_int(280, 380) / 100.0
	return out


## An L in each corner (some corners skipped), its arms running back toward the two walls with a gap at each,
## so the corner behind it is a bunker you can walk into.
static func _bunkers(r: Rect2, rng: RngStream, p: FloorParams) -> Array:
	var t := p.slab_half_thickness
	var d := _cm(clampf(minf(r.size.x, r.size.y) * 0.3, 4.0, 7.0))
	var out := []
	for corner in 4:
		if not rng.chance_permille(800):
			continue
		var sx := -1.0 if corner % 2 == 0 else 1.0
		var sy := -1.0 if corner < 2 else 1.0
		var wall := Vector2(
			r.position.x if sx < 0.0 else r.end.x, r.position.y if sy < 0.0 else r.end.y
		)
		var k := wall - Vector2(sx * d, sy * d)
		var arm_x := _box(Vector2(wall.x - sx * EDGE, k.y - t), Vector2(k.x - sx * t, k.y + t))
		var arm_y := _box(Vector2(k.x - t, wall.y - sy * EDGE), Vector2(k.x + t, k.y + sy * t))
		out.append([_fix(arm_x), _fix(arm_y)])
	return out
