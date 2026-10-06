class_name Obb
extends RefCounted
## An oriented box on the sim plane: centre, half-extents (metres) and angle (1/4096 turns).

var center: Vector2
var half: Vector2
var angle: int
var axis_u: Vector2
var axis_v: Vector2


static func make(p_center: Vector2, p_half: Vector2, p_angle: int) -> Obb:
	var o := Obb.new()
	o.center = p_center
	o.half = p_half
	o.angle = p_angle & 4095
	o.axis_u = Kin.dir(o.angle)
	o.axis_v = Vector2(-o.axis_u.y, o.axis_u.x)
	return o


## Axis-aligned bounds, for broadphase cells.
func bounds() -> Rect2:
	var ex := absf(axis_u.x) * half.x + absf(axis_v.x) * half.y
	var ey := absf(axis_u.y) * half.x + absf(axis_v.y) * half.y
	return Rect2(center.x - ex, center.y - ey, ex * 2.0, ey * 2.0)
