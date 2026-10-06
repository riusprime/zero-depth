class_name Occlusion
extends RefCounted
## Which walls hide a focus point from the iso camera (PRESENTATION_CONTRACTS §5). Pure function, unit-tested
## apart from rendering. A wall hides a point if the sight line from the point (at core height) toward the
## camera passes through the wall's box while the line is still below the wall's top.


## to_camera: horizontal unit direction toward the camera (sim plane). pitch_deg: camera pitch.
## walls: [center: Vector2, half: Vector2, angle_rad: float, height: float]. Returns ascending wall indices.
static func select(
	to_camera: Vector2, pitch_deg: float, focus: Array[Vector2], walls: Array
) -> PackedInt32Array:
	var out := PackedInt32Array()
	var rise := tan(deg_to_rad(pitch_deg))
	for wi in walls.size():
		var w: Array = walls[wi]
		var reach: float = maxf(0.0, (w[3] - SimPlane.CORE_HEIGHT) / maxf(rise, 0.01))
		for p in focus:
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
