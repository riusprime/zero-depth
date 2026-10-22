class_name WallGrid
extends RefCounted
## The walls' union on a grid of their edges: per cell, the wall it belongs to (the first that covers it) or -1.
## v0.8.0 N10: ProceduralWall's grid (presentation only).

var xs := PackedFloat64Array()
var ys := PackedFloat64Array()
var nx := 0
var ny := 0
var cells := PackedInt32Array()
## Each solid cell's top (m).
var cell_h := PackedFloat32Array()
## Each solid cell's top texture offset (its stone's; tiles).
var cell_off := PackedFloat32Array()
## Each grid vertex's top point, once asked.
var tops := PackedVector3Array()
var top_done := PackedByteArray()


func _init(rects: Array, owners: PackedInt32Array, cuts: Array) -> void:
	var ex: Array = []
	var ey: Array = []
	for r: Rect2 in rects:
		ex.append_array([r.position.x, r.end.x])
		ey.append_array([r.position.y, r.end.y])
	var live: Array = []
	for c: Rect2 in cuts:
		if c.size.x > 0.01 and c.size.y > 0.01:
			live.append(c)
			ex.append_array([c.position.x, c.end.x])
			ey.append_array([c.position.y, c.end.y])
	xs = axis(ex)
	ys = axis(ey)
	nx = xs.size() - 1
	ny = ys.size() - 1
	cells.resize(nx * ny)
	cells.fill(-1)
	cell_h.resize(nx * ny)
	cell_off.resize(nx * ny)
	tops.resize((nx + 1) * (ny + 1))
	top_done.resize((nx + 1) * (ny + 1))
	top_done.fill(0)
	for k in rects.size():
		_paint(rects[k], owners[k], false)
	for c: Rect2 in live:
		_paint(c, -1, true)


func _paint(r: Rect2, value: int, over: bool) -> void:
	var i0 := _index(xs, r.position.x)
	var i1 := _index(xs, r.end.x)
	var j0 := _index(ys, r.position.y)
	var j1 := _index(ys, r.end.y)
	for j in range(j0, j1):
		for i in range(i0, i1):
			if over or cells[j * nx + i] < 0:
				cells[j * nx + i] = value


static func _index(arr: PackedFloat64Array, v: float) -> int:
	return clampi(arr.bsearch(v - 0.0001), 0, arr.size() - 1)


func at(i: int, j: int) -> int:
	if i < 0 or j < 0 or i >= nx or j >= ny:
		return -1
	return cells[j * nx + i]


## The wall at a sim-plane point (-1 off the union).
func owner_at(p: Vector2) -> int:
	var i := xs.bsearch(p.x) - 1
	var j := ys.bsearch(p.y) - 1
	return at(i, j)


## v0.8.0 N13 (ProceduralWall's rim and fill): each solid cell's distance (m, from its centre) to the union's edge
## along the grid's rows and columns (the nearest open cell in any of the four directions; off the grid is open).
func edge_dist() -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(nx * ny)
	d.fill(1e6)
	for j in ny:
		var edge := xs[0]
		for i in nx:
			if cells[j * nx + i] < 0:
				edge = xs[i + 1]
				continue
			d[j * nx + i] = minf(d[j * nx + i], (xs[i] + xs[i + 1]) * 0.5 - edge)
		edge = xs[nx]
		for i in range(nx - 1, -1, -1):
			if cells[j * nx + i] < 0:
				edge = xs[i]
				continue
			d[j * nx + i] = minf(d[j * nx + i], edge - (xs[i] + xs[i + 1]) * 0.5)
	for i in nx:
		var edge := ys[0]
		for j in ny:
			if cells[j * nx + i] < 0:
				edge = ys[j + 1]
				continue
			d[j * nx + i] = minf(d[j * nx + i], (ys[j] + ys[j + 1]) * 0.5 - edge)
		edge = ys[ny]
		for j in range(ny - 1, -1, -1):
			if cells[j * nx + i] < 0:
				edge = ys[j]
				continue
			d[j * nx + i] = minf(d[j * nx + i], edge - (ys[j] + ys[j + 1]) * 0.5)
	return d


## Sorted grid lines: the given edges (closer than 0.1 mm merged), each gap split into STEP or less.
static func axis(values: Array) -> PackedFloat64Array:
	values.sort()
	var base := PackedFloat64Array()
	for v: float in values:
		if base.is_empty() or v - base[base.size() - 1] > 0.0001:
			base.append(v)
	var out := PackedFloat64Array()
	for k in base.size():
		if k > 0:
			var gap := base[k] - base[k - 1]
			var n := int(ceil(gap / ProceduralWall.STEP - 0.001))
			for t in range(1, n):
				out.append(base[k - 1] + gap * t / n)
		out.append(base[k])
	return out
