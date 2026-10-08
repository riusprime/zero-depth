class_name DenseGrid
extends RefCounted
## Broadphase for the walls and the actors (v0.4.0 SC; they used UniformGrid's Dictionary of Arrays): a dense grid
## of CELL metres over the bounds of what it holds, each cell's indices in one flat list built by a counting sort.
## - Boxes (the walls; build, add): each box is listed in every cell it covers. Built once, and again when the
##   boss door is added.
## - Circles (the actors; build_circles): each circle is listed in the one cell of its centre and queries grow by
##   the largest radius. Rebuilt in place every collision pass from the actors' packed arrays.
## Queries return ascending indices without duplicates: every index whose box overlaps the query's, and maybe a few
## more (a superset of those that overlap).

const CELL := 2.0
## At most this many cells a side: past it the cells grow, so a stray far-off box can't blow up the grid.
const MAX_SIDE := 256

var cell := CELL
var origin := Vector2.ZERO
var size := Vector2i.ZERO
## The boxes held: min and max corners, by index (box mode).
var _x0 := PackedFloat32Array()
var _y0 := PackedFloat32Array()
var _x1 := PackedFloat32Array()
var _y1 := PackedFloat32Array()
## Circle mode: queries grow by this (the largest radius); -1 in box mode.
var _pad := -1.0
var _count := 0
## Cell k's indices are _items[_start[k] .. _start[k + 1] - 1], ascending.
var _start := PackedInt32Array()
var _items := PackedInt32Array()
var _fill := PackedInt32Array()
var _cell_of := PackedInt32Array()
## Box-mode query de-duplication: the last query that took each index.
var _stamp := PackedInt32Array()
var _query := 0


## Holds these boxes (the walls' bounds).
func build(rects: Array[Rect2]) -> void:
	_resize(rects.size())
	for i in rects.size():
		_x0[i] = rects[i].position.x
		_y0[i] = rects[i].position.y
		_x1[i] = rects[i].end.x
		_y1[i] = rects[i].end.y
	_rebuild_boxes()


## Adds one box and rebuilds (a wall added in play).
func add(rect: Rect2) -> void:
	var n := _x0.size()
	_resize(n + 1)
	_x0[n] = rect.position.x
	_y0[n] = rect.position.y
	_x1[n] = rect.end.x
	_y1[n] = rect.end.y
	_rebuild_boxes()


## Holds one entry per circle: index i is the circle at (xs[i], ys[i]) of radius rs[i] (the actors).
func build_circles(xs: PackedFloat32Array, ys: PackedFloat32Array, rs: PackedFloat32Array) -> void:
	var n := xs.size()
	_count = n
	if n == 0:
		size = Vector2i.ZERO
		_pad = 0.0
		return
	var lox := xs[0]
	var loy := ys[0]
	var hix := lox
	var hiy := loy
	var pad := 0.0
	for i in n:
		var x := xs[i]
		var y := ys[i]
		if x < lox:
			lox = x
		elif x > hix:
			hix = x
		if y < loy:
			loy = y
		elif y > hiy:
			hiy = y
		if rs[i] > pad:
			pad = rs[i]
	_pad = pad
	_frame(lox, loy, hix, hiy)
	var sx := size.x
	var mx := sx - 1
	var my := size.y - 1
	var inv := 1.0 / cell
	var cells := sx * size.y
	_start.resize(cells + 1)
	_start.fill(0)
	_cell_of.resize(n)
	for i in n:
		var k := mini(int((ys[i] - loy) * inv), my) * sx + mini(int((xs[i] - lox) * inv), mx)
		_cell_of[i] = k
		_start[k + 1] += 1
	for k in cells:
		_start[k + 1] += _start[k]
	_items.resize(n)
	_fill.resize(cells)
	for k in cells:
		_fill[k] = _start[k]
	for i in n:
		var k := _cell_of[i]
		_items[_fill[k]] = i
		_fill[k] += 1


func count() -> int:
	return _count


## Indices of the entries that may overlap `rect`, ascending, without duplicates.
func query_rect(rect: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	if _count == 0:
		return out
	var grow := _pad if _pad > 0.0 else 0.0
	var inv := 1.0 / cell
	var mx := size.x - 1
	var my := size.y - 1
	# Truncation, then the clamp: the same cells as floor() for every coordinate past the origin's side.
	var cx0 := clampi(int((rect.position.x - grow - origin.x) * inv), 0, mx)
	var cx1 := clampi(int((rect.end.x + grow - origin.x) * inv), 0, mx)
	var cy0 := clampi(int((rect.position.y - grow - origin.y) * inv), 0, my)
	var cy1 := clampi(int((rect.end.y + grow - origin.y) * inv), 0, my)
	if _pad >= 0.0:
		# Circle mode: each index sits in one cell, so the cells' lists are joined natively, then sorted.
		var parts := 0
		for cy in range(cy0, cy1 + 1):
			var row := cy * size.x
			for k in range(row + cx0, row + cx1 + 1):
				var a := _start[k]
				var b := _start[k + 1]
				if a < b:
					parts += 1
					out.append_array(_items.slice(a, b))
		if parts > 1:
			out.sort()
		return out
	if cx0 == cx1 and cy0 == cy1:  # one cell: its list is already ascending and unique
		var k := cy0 * size.x + cx0
		return _items.slice(_start[k], _start[k + 1])
	_query += 1
	var unsorted := false
	var last := -1
	for cy in range(cy0, cy1 + 1):
		var row := cy * size.x
		for k in range(row + cx0, row + cx1 + 1):
			for j in range(_start[k], _start[k + 1]):
				var idx := _items[j]
				if _stamp[idx] == _query:
					continue
				_stamp[idx] = _query
				if idx < last:
					unsorted = true
				last = idx
				out.append(idx)
	if unsorted:
		out.sort()
	return out


## v0.4.0 TU: whether query_rect(rect) would return anything (box mode or circle mode), without building the list.
func any_in_rect(rect: Rect2) -> bool:
	if _count == 0:
		return false
	var grow := _pad if _pad > 0.0 else 0.0
	var inv := 1.0 / cell
	var mx := size.x - 1
	var my := size.y - 1
	var cx0 := clampi(int((rect.position.x - grow - origin.x) * inv), 0, mx)
	var cx1 := clampi(int((rect.end.x + grow - origin.x) * inv), 0, mx)
	var cy0 := clampi(int((rect.position.y - grow - origin.y) * inv), 0, my)
	var cy1 := clampi(int((rect.end.y + grow - origin.y) * inv), 0, my)
	for cy in range(cy0, cy1 + 1):
		var row := cy * size.x
		if _start[row + cx1 + 1] > _start[row + cx0]:
			return true
	return false


## Box mode: indices of the boxes whose cells the segment from `a` to `b`, thickened by `r`, passes through
## (ascending, no duplicates; a superset of the boxes it touches). Walks the grid a column at a time, so a long
## line of sight visits about twice its length in cells, not its bounding box's area.
func query_segment(a: Vector2, b: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	if _count == 0:
		return out
	if b.x < a.x:
		var t := a
		a = b
		b = t
	var dx := b.x - a.x
	var steep := dx < 0.000001
	var slope := 0.0 if steep else (b.y - a.y) / dx
	var lo_y := minf(a.y, b.y) - r
	var hi_y := maxf(a.y, b.y) + r
	_query += 1
	var unsorted := false
	var last := -1
	for cx in range(_col(a.x - r), _col(b.x + r) + 1):
		var y0 := lo_y
		var y1 := hi_y
		if not steep:
			var left := origin.x + cx * cell
			var x0 := clampf(left - r, a.x, b.x)
			var x1 := clampf(left + cell + r, a.x, b.x)
			var ya := a.y + slope * (x0 - a.x)
			var yb := a.y + slope * (x1 - a.x)
			y0 = minf(ya, yb) - r
			y1 = maxf(ya, yb) + r
		for cy in range(_row(y0), _row(y1) + 1):
			var k := cy * size.x + cx
			for j in range(_start[k], _start[k + 1]):
				var idx := _items[j]
				if _stamp[idx] == _query:
					continue
				_stamp[idx] = _query
				if idx < last:
					unsorted = true
				last = idx
				out.append(idx)
	if unsorted:
		out.sort()
	return out


func _col(x: float) -> int:
	return clampi(int(floor((x - origin.x) / cell)), 0, size.x - 1)


func _row(y: float) -> int:
	return clampi(int(floor((y - origin.y) / cell)), 0, size.y - 1)


## Sets the origin, cell size and size for these bounds.
func _frame(lox: float, loy: float, hix: float, hiy: float) -> void:
	origin = Vector2(lox, loy)
	cell = maxf(CELL, maxf(hix - lox, hiy - loy) / (MAX_SIDE - 1))
	size = Vector2i(int((hix - lox) / cell) + 1, int((hiy - loy) / cell) + 1)


func _resize(n: int) -> void:
	_x0.resize(n)
	_y0.resize(n)
	_x1.resize(n)
	_y1.resize(n)
	_count = n
	if _stamp.size() != n:
		_stamp.resize(n)
		_stamp.fill(0)
		_query = 0


func _rebuild_boxes() -> void:
	_pad = -1.0
	var n := _x0.size()
	if n == 0:
		size = Vector2i.ZERO
		return
	var lo := Vector2(_x0[0], _y0[0])
	var hi := Vector2(_x1[0], _y1[0])
	for i in range(1, n):
		lo.x = minf(lo.x, _x0[i])
		lo.y = minf(lo.y, _y0[i])
		hi.x = maxf(hi.x, _x1[i])
		hi.y = maxf(hi.y, _y1[i])
	_frame(lo.x, lo.y, hi.x, hi.y)
	var cells := size.x * size.y
	_start.resize(cells + 1)
	_start.fill(0)
	var total := 0
	for i in n:
		var cx0 := _col(_x0[i])
		var cx1 := _col(_x1[i])
		for cy in range(_row(_y0[i]), _row(_y1[i]) + 1):
			for cx in range(cx0, cx1 + 1):
				_start[cy * size.x + cx + 1] += 1
				total += 1
	for k in cells:
		_start[k + 1] += _start[k]
	_items.resize(total)
	_fill.resize(cells)
	for k in cells:
		_fill[k] = _start[k]
	for i in n:
		var cx0 := _col(_x0[i])
		var cx1 := _col(_x1[i])
		for cy in range(_row(_y0[i]), _row(_y1[i]) + 1):
			for cx in range(cx0, cx1 + 1):
				var k := cy * size.x + cx
				_items[_fill[k]] = i
				_fill[k] += 1
