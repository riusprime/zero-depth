class_name RoomInterior
extends RefCounted
## Interior templates for a floor's rooms (v0.2.0 PLAN L14; v0.3.0 L2), scaled to the room. Each template proposes
## pieces in groups (a group is one obstacle: a pillar, a slab, an L of two slabs); FloorGenerator keeps a group
## only if it keeps its distance, leaves doorways, the start and the gate clear, and leaves the room one region. So
## a template never blocks a door or splits a room; at worst it loses a piece. Each template draws its own
## parameters (counts, spacing, sizes, which way it turns or mirrors). Pieces are axis-aligned except the
## diagonals' (angles that are multiples of 512). Pure sim code: draws from the `map` stream, floats from whole
## centimetres, no trig. SCATTER (random slabs) is placed by FloorGenerator itself, slab by slab.

## Free space from a wall face to a piece's edge: the generator's gap plus a margin.
const EDGE := 2.6
const T := FloorLayout.Template

## Template weights, in Template order: OPEN, SCATTER, PILLARS, CENTRE, CROSS, LINES, BUNKERS, COLONNADE,
## DIAGONALS.
const _W_HALL := [0, 3, 3, 2, 2, 1, 3, 2, 2]
const _W_SMALL := [2, 4, 2, 3, 1, 1, 2, 1, 2]
const _W_LONG := [1, 2, 1, 1, 1, 6, 1, 4, 1]
const _W_BIG := [1, 3, 3, 3, 2, 2, 3, 2, 3]


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


## A draw in [lo, hi] metres, in whole centimetres.
static func _draw(rng: RngStream, lo: float, hi: float) -> float:
	return rng.range_int(roundi(lo * 100.0), roundi(hi * 100.0)) / 100.0


## An axis-aligned piece from lo to hi (corners).
static func _box(lo: Vector2, hi: Vector2) -> Obb:
	var a := Vector2(_cm(lo.x), _cm(lo.y))
	var b := Vector2(_cm(hi.x), _cm(hi.y))
	return Obb.make((a + b) * 0.5, (b - a) * 0.5, 0)


## The candidate groups of a template for room interior r, in the order they should be tried.
static func groups(template: int, r: Rect2, rng: RngStream, p: FloorParams, hall: bool) -> Array:
	match template:
		T.PILLARS:
			return _pillars(r, rng, p)
		T.CENTRE:
			return _centre(r, rng, p, hall)
		T.CROSS:
			return _cross(r, rng, p, hall)
		T.LINES:
			return _lines(r, rng, p)
		T.BUNKERS:
			return _bunkers(r, rng, p)
		T.COLONNADE:
			return _colonnade(r, rng, p)
		T.DIAGONALS:
			return _diagonals(r, rng, p)
	return []


## A grid of pillars; in a big room every other one (a checkerboard). Drawn: the spacing, the pillar size, and
## whether the pillars are square or stretched (along x or y).
static func _pillars(r: Rect2, rng: RngStream, p: FloorParams) -> Array:
	var pitch := _draw(rng, 5.0, 6.5)
	var half := _draw(rng, 0.45, 0.65)
	var size := Vector2(half, half)
	if rng.chance_permille(350):
		var stretch := _draw(rng, 1.4, 2.0)
		size = (
			Vector2(half * stretch, half)
			if rng.chance_permille(500)
			else Vector2(half, half * stretch)
		)
		size = Vector2(_cm(size.x), _cm(size.y))
	var span := r.size - (Vector2(EDGE, EDGE) + size) * 2.0
	var n := Vector2i(maxi(1, int(span.x / pitch) + 1), maxi(1, int(span.y / pitch) + 1))
	var checker := n.x * n.y > 12 or rng.chance_permille(p.template_flip_permille / 2)
	var phase := rng.range_int(0, 1)
	var c := r.get_center()
	var out := []
	for j in n.y:
		for i in n.x:
			if checker and (i + j + phase) % 2 == 1:
				continue
			var q := c + Vector2((i - (n.x - 1) * 0.5) * pitch, (j - (n.y - 1) * 0.5) * pitch)
			out.append([_box(q - size, q + size)])
	return out


## A solid block in the middle with a walkway around it, or (in a room at least two cells each way, and always in
## the hall, where the start is the middle) a ring of four L corners with an opening in the middle of each side.
## Drawn: the block's or the ring's size, and the openings.
static func _centre(r: Rect2, rng: RngStream, p: FloorParams, hall: bool) -> Array:
	var c := r.get_center()
	var ring := hall or (minf(r.size.x, r.size.y) >= 20.0 and rng.chance_permille(500))
	if not ring:
		var fx := rng.range_int(12, 20) / 100.0
		var fy := rng.range_int(12, 20) / 100.0
		var h := Vector2(maxf(1.0, r.size.x * fx), maxf(0.8, r.size.y * fy))
		return [[_box(c - h, c + h)]]
	var t := p.slab_half_thickness
	var hx := r.size.x * rng.range_int(17, 23) / 100.0
	var hy := r.size.y * rng.range_int(17, 23) / 100.0
	var o := _draw(rng, 1.5, 1.9)  # half the opening in the middle of each side
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
## broken in the middle too. In the hall the centre gap is wider, around the start. Drawn: the centre gap, and
## (outside the hall, by template_flip_permille) one arm left out, so the cross becomes a T turned any way.
static func _cross(r: Rect2, rng: RngStream, p: FloorParams, hall: bool) -> Array:
	var c := r.get_center()
	var t := p.slab_half_thickness
	var g := _draw(rng, 2.4, 3.0)
	if hall:
		g += p.start_clear_radius - 2.0
	var skip := -1
	if not hall and rng.chance_permille(p.template_flip_permille):
		skip = rng.range_int(0, 3)
	var out := []
	for axis in 2:
		var reach := (r.size.x if axis == 0 else r.size.y) * 0.5 - EDGE
		for k in 2:
			if axis * 2 + k == skip:
				continue
			var s := -1.0 if k == 0 else 1.0
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


## Long broken lines of cover, staggered. Drawn: the number of lines (two, or two to three in a wide room), which
## lines start late (mirrored), the segment and gap lengths, and in a near-square room which way they run.
static func _lines(r: Rect2, rng: RngStream, p: FloorParams) -> Array:
	var along_x := r.size.x >= r.size.y
	if maxf(r.size.x, r.size.y) < minf(r.size.x, r.size.y) * 1.3:
		along_x = rng.chance_permille(500)
	var long := r.size.x if along_x else r.size.y
	var short := r.size.y if along_x else r.size.x
	var k := 2 if short < 20.0 else rng.range_int(2, 3)
	var late := 1 if rng.chance_permille(p.template_flip_permille) else 0
	var t := p.slab_half_thickness
	var out := []
	for i in k:
		var across := short * (i + 1) / (k + 1)
		var pos := EDGE + (_draw(rng, 1.5, 3.0) if i % 2 == late else 0.0)
		var stop := long - EDGE
		while stop - pos >= 1.5:
			var seg := minf(_draw(rng, 3.0, 6.0), stop - pos)
			if seg >= 1.5:
				var lo := Vector2(pos, across - t)
				var hi := Vector2(pos + seg, across + t)
				if not along_x:
					lo = Vector2(lo.y, lo.x)
					hi = Vector2(hi.y, hi.x)
				out.append([_box(r.position + lo, r.position + hi)])
			pos += seg + _draw(rng, 2.8, 3.8)
	return out


## An L in each corner (some corners skipped), its arms running back toward the two walls with a gap at each,
## so the corner behind it is a bunker you can walk into. Drawn: how deep the bunkers are, how likely each corner
## is to get one, and which corners do.
static func _bunkers(r: Rect2, rng: RngStream, p: FloorParams) -> Array:
	var t := p.slab_half_thickness
	var depth := rng.range_int(25, 35) / 100.0
	var d := _cm(clampf(minf(r.size.x, r.size.y) * depth, 4.0, 7.0))
	var keep := rng.range_int(650, 900)
	var out := []
	for corner in 4:
		if not rng.chance_permille(keep):
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


## COLONNADE (v0.3.0): two rows of pillars along the room's long axis, an aisle between them and a walkway
## behind each. Drawn: the pillar size and spacing, how far the rows stand from the long walls, and whether the
## second row is staggered by half a spacing.
static func _colonnade(r: Rect2, rng: RngStream, p: FloorParams) -> Array:
	var along_x := r.size.x >= r.size.y
	var long := r.size.x if along_x else r.size.y
	var short := r.size.y if along_x else r.size.x
	var half := _draw(rng, 0.4, 0.6)
	var pitch := _draw(rng, 4.0, 5.5)
	var inset := EDGE + half + _draw(rng, 0.0, 1.5)
	inset = minf(inset, short * 0.5 - half - p.slab_gap * 0.5 - 0.5)
	var stagger := rng.chance_permille(p.template_flip_permille)
	var n := maxi(1, int((long - (EDGE + half) * 2.0) / pitch) + 1)
	var out := []
	for row in 2:
		var across := inset if row == 0 else short - inset
		var shift := pitch * 0.5 if stagger and row == 1 else 0.0
		for i in n:
			var along := long * 0.5 + (i - (n - 1) * 0.5) * pitch + shift
			if along - half < EDGE or along + half > long - EDGE:
				continue
			var q := Vector2(along, across) if along_x else Vector2(across, along)
			q += r.position
			out.append([_box(q - Vector2(half, half), q + Vector2(half, half))])
	return out


## DIAGONALS (v0.3.0): slabs turned an eighth of a turn, on a staggered grid. Drawn: the slab length, the
## spacing, which way they lean (mirrored), and whether every other row leans the other way (a herringbone).
static func _diagonals(r: Rect2, rng: RngStream, p: FloorParams) -> Array:
	var half_len := _draw(rng, 1.2, 1.8)
	var pitch := _draw(rng, 5.5, 7.0)
	var lean := 512 if rng.chance_permille(p.template_flip_permille) else 1536
	var herring := rng.chance_permille(p.template_flip_permille)
	var reach := (half_len + p.slab_half_thickness) * 0.75  # an eighth turn's half-extent, rounded up
	var span := r.size - Vector2(EDGE + reach, EDGE + reach) * 2.0
	var n := Vector2i(maxi(1, int(span.x / pitch) + 1), maxi(1, int(span.y / pitch) + 1))
	var c := r.get_center()
	var out := []
	for j in n.y:
		var angle := lean
		if herring and j % 2 == 1:
			angle = 2048 - lean
		var shift := pitch * 0.5 if j % 2 == 1 and n.x > 1 else 0.0
		for i in n.x:
			var q := (
				c + Vector2((i - (n.x - 1) * 0.5) * pitch + shift, (j - (n.y - 1) * 0.5) * pitch)
			)
			if q.x + reach > r.end.x - EDGE:
				continue
			q = Vector2(_cm(q.x), _cm(q.y))
			out.append([Obb.make(q, Vector2(half_len, p.slab_half_thickness), angle)])
	return out
