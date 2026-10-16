class_name Occlusion
extends RefCounted
## Which walls hide a focus point from the iso camera (PRESENTATION_CONTRACTS §5). Pure function, unit-tested
## apart from rendering. A wall hides a point if the sight line from the point (at core height) toward the
## camera passes through the wall's box while the line is still below the wall's top.

## v0.8.0 P3 (owner O32): build_index's grid cell (m). A floor has hundreds of walls and the focus sits in a room or
## two, so select_in tests only the walls whose cells lie near the focus.
const GRID_M := 8.0


## to_camera: horizontal unit direction toward the camera (sim plane). pitch_deg: camera pitch.
## walls: [center: Vector2, half: Vector2, angle_rad: float, height: float]. Returns ascending wall indices.
static func select(
	to_camera: Vector2, pitch_deg: float, focus: Array[Vector2], walls: Array
) -> PackedInt32Array:
	var out := PackedInt32Array()
	if focus.is_empty():
		return out
	var rise := tan(deg_to_rad(pitch_deg))
	# v0.8.0 P3 (owner O32): the focus points' bounding box, so a wall far from all of them is skipped with one
	# test instead of one per point (a generated floor has hundreds of walls; the focus sits in one or two rooms).
	var lo := focus[0]
	var hi := focus[0]
	for p in focus:
		lo = lo.min(p)
		hi = hi.max(p)
	for wi in walls.size():
		var w: Array = walls[wi]
		var reach: float = maxf(0.0, (w[3] - SimPlane.CORE_HEIGHT) / maxf(rise, 0.01))
		# v0.4.0 SC: only points within the wall's circle grown by the reach can be hidden by it (a cheap test
		# before the exact one: with a crowd, most point-wall pairs are far apart).
		var c: Vector2 = w[0]
		var h: Vector2 = w[1]
		var near := reach + h.length() + 0.01
		if c.x < lo.x - near or c.x > hi.x + near or c.y < lo.y - near or c.y > hi.y + near:
			continue
		for p in focus:
			if absf(p.x - c.x) > near or absf(p.y - c.y) > near:
				continue
			if _segment_hits_box(p, p + to_camera * reach, w[0], w[1], w[2]):
				out.append(wi)
				break
	return out


static func _segment_hits_box(
	a: Vector2, b: Vector2, c: Vector2, half: Vector2, angle: float
) -> bool:
	var la := (a - c).rotated(-angle)
	var lb := (b - c).rotated(-angle)
	var t0 := 0.0
	var t1 := 1.0
	var d := lb - la
	for axis in 2:
		var p := la[axis]
		var dd := d[axis]
		var h := half[axis]
		if absf(dd) < 1e-9:
			if p < -h or p > h:
				return false
			continue
		var ta := (-h - p) / dd
		var tb := (h - p) / dd
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return false
	return t0 > 0.0  # a point already inside the wall's footprint isn't "behind" it


## v0.8.0 P3 (owner O32): the walls' fixed numbers at `pitch_deg` (each one's reach, the sight line's length under its
## top, and its quick-reject radius), and the walls bucketed by GRID_M cell of their centre. Built once per floor
## (the walls never move); `count` is the wall count it was built for.
static func build_index(pitch_deg: float, walls: Array) -> Dictionary:
	var rise := tan(deg_to_rad(pitch_deg))
	var reach := PackedFloat32Array()
	var near := PackedFloat32Array()
	var cells := {}
	var max_near := 0.0
	for wi in walls.size():
		var w: Array = walls[wi]
		var r: float = maxf(0.0, (w[3] - SimPlane.CORE_HEIGHT) / maxf(rise, 0.01))
		var n: float = r + (w[1] as Vector2).length() + 0.01
		reach.append(r)
		near.append(n)
		max_near = maxf(max_near, n)
		var c: Vector2 = w[0]
		var cell := Vector2i(floori(c.x / GRID_M), floori(c.y / GRID_M))
		var list: PackedInt32Array = cells.get(cell, PackedInt32Array())
		list.append(wi)
		cells[cell] = list
	return {
		"pitch": pitch_deg,
		"count": walls.size(),
		"reach": reach,
		"near": near,
		"cells": cells,
		"max_near": max_near
	}


## select() through an index (build_index of the same walls and pitch): the same walls, ascending, testing only the
## walls whose centre cell lies within the largest quick-reject radius of the focus points' bounding box.
static func select_in(
	to_camera: Vector2, index: Dictionary, focus: Array[Vector2], walls: Array
) -> PackedInt32Array:
	var out := PackedInt32Array()
	if focus.is_empty():
		return out
	var lo := focus[0]
	var hi := focus[0]
	for p in focus:
		lo = lo.min(p)
		hi = hi.max(p)
	var m: float = index["max_near"]
	var reach: PackedFloat32Array = index["reach"]
	var near: PackedFloat32Array = index["near"]
	var cells: Dictionary = index["cells"]
	for cx in range(floori((lo.x - m) / GRID_M), floori((hi.x + m) / GRID_M) + 1):
		for cy in range(floori((lo.y - m) / GRID_M), floori((hi.y + m) / GRID_M) + 1):
			var list: Variant = cells.get(Vector2i(cx, cy))
			if list == null:
				continue
			for wi: int in list:
				var w: Array = walls[wi]
				var c: Vector2 = w[0]
				var n := near[wi]
				for p in focus:
					if absf(p.x - c.x) > n or absf(p.y - c.y) > n:
						continue
					if _segment_hits_box(p, p + to_camera * reach[wi], c, w[1], w[2]):
						out.append(wi)
						break
	out.sort()
	return out
