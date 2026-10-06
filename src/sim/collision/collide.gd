class_name Collide
extends RefCounted
## Narrow-phase tests. Pure functions over floats; only + - * / and sqrt.

const NO_HIT := -1.0


## The push (vector) that moves a circle out of a box, or ZERO if they don't overlap.
static func circle_vs_obb(p: Vector2, r: float, box: Obb) -> Vector2:
	var d := p - box.center
	var lx := d.dot(box.axis_u)
	var ly := d.dot(box.axis_v)
	var cx := clampf(lx, -box.half.x, box.half.x)
	var cy := clampf(ly, -box.half.y, box.half.y)
	if cx == lx and cy == ly:
		# Centre inside the box: leave through the nearest face.
		var px := box.half.x - absf(lx) + r
		var py := box.half.y - absf(ly) + r
		if px < py:
			return box.axis_u * (px if lx >= 0.0 else -px)
		return box.axis_v * (py if ly >= 0.0 else -py)
	var ox := lx - cx
	var oy := ly - cy
	var dist2 := ox * ox + oy * oy
	if dist2 >= r * r:
		return Vector2.ZERO
	var dist := sqrt(dist2)
	var k := (r - dist) / dist
	return box.axis_u * (ox * k) + box.axis_v * (oy * k)


## The push that separates circle a from circle b, applied half to each (returned for a; b gets the negation).
static func circle_vs_circle(pa: Vector2, ra: float, pb: Vector2, rb: float) -> Vector2:
	var d := pa - pb
	var rr := ra + rb
	var dist2 := float(d.x) * d.x + float(d.y) * d.y
	if dist2 >= rr * rr:
		return Vector2.ZERO
	if dist2 == 0.0:
		return Vector2(rr * 0.5, 0.0)
	var dist := sqrt(dist2)
	return d * ((rr - dist) * 0.5 / dist)


## The first t in [0, 1] where a segment from a to b, thickened by r, touches a circle; NO_HIT otherwise.
static func sweep_vs_circle(a: Vector2, b: Vector2, r: float, c: Vector2, cr: float) -> float:
	var d := b - a
	var f := a - c
	var rr := r + cr
	var qa := float(d.x) * d.x + float(d.y) * d.y
	var qc := float(f.x) * f.x + float(f.y) * f.y - rr * rr
	if qc <= 0.0:
		return 0.0
	if qa == 0.0:
		return NO_HIT
	var qb := 2.0 * (float(f.x) * d.x + float(f.y) * d.y)
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return NO_HIT
	var t := (-qb - sqrt(disc)) / (2.0 * qa)
	return t if t >= 0.0 and t <= 1.0 else NO_HIT


## The first t in [0, 1] where a segment from a to b, thickened by r, touches a box; NO_HIT otherwise.
## The box is grown by r (a Minkowski approximation that is exact on faces, slightly generous on corners).
static func sweep_vs_obb(a: Vector2, b: Vector2, r: float, box: Obb) -> float:
	var da := a - box.center
	var la := Vector2(da.dot(box.axis_u), da.dot(box.axis_v))
	var db := b - box.center
	var lb := Vector2(db.dot(box.axis_u), db.dot(box.axis_v))
	var hx := box.half.x + r
	var hy := box.half.y + r
	var t0 := 0.0
	var t1 := 1.0
	var dir := lb - la
	for axis in 2:
		var p := la.x if axis == 0 else la.y
		var dd := dir.x if axis == 0 else dir.y
		var h := hx if axis == 0 else hy
		if dd == 0.0:
			if p < -h or p > h:
				return NO_HIT
			continue
		var ta := (-h - p) / dd
		var tb := (h - p) / dd
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return NO_HIT
	return t0
