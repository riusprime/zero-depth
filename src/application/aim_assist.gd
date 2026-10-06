class_name AimAssist
extends RefCounted
## Gamepad-only aim assist (about a 12° cone, owner decision): the aim snaps to the nearest target inside the
## cone, before quantization, so replays store the final aim. v0.0.1 has no targets, so it returns the aim as is.

const CONE_DEG := 12.0


## aim: the stick's direction on the sim plane; targets: target positions relative to the player.
static func apply(aim: Vector2, targets: Array[Vector2], cone_deg: float = CONE_DEG) -> Vector2:
	if aim == Vector2.ZERO:
		return aim
	var best := aim
	var best_angle := deg_to_rad(cone_deg)
	for t in targets:
		if t == Vector2.ZERO:
			continue
		var a := absf(aim.angle_to(t))
		if a <= best_angle:
			best_angle = a
			best = t.normalized() * aim.length()
	return best
