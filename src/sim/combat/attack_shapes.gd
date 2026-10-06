class_name AttackShapes
extends RefCounted
## Every attack's area, as one function used both to resolve the hit and to draw it (EI-07, PRESENTATION §4).


## True if a circle (p, r) touches the arc fan at `center` facing `angle`: within `reach` of the attacker's edge
## (`own_r`) and within `half_arc` of the facing, or overlapping the attacker.
static func arc_touches(
	center: Vector2, own_r: float, angle: int, half_arc: int, reach: float, p: Vector2, r: float
) -> bool:
	var d := p - center
	var dist := Kin.length(d)
	if dist <= own_r + r:
		return true
	if dist - r > own_r + reach:
		return false
	return Kin.angle_diff(Kin.angle_of(d), angle) <= half_arc


## True if a circle touches a disc (a slam).
static func disc_touches(center: Vector2, radius: float, p: Vector2, r: float) -> bool:
	return Kin.length(p - center) <= radius + r


## The lane a charge sweeps: from `start`, `length` metres along `angle`, `half_width` to each side.
static func lane(start: Vector2, angle: int, length: float, half_width: float) -> Obb:
	return Obb.make(
		start + Kin.dir(angle) * (length * 0.5), Vector2(length * 0.5, half_width), angle
	)
