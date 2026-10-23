class_name FormParticles
extends RefCounted
## v0.6.0 MX3: where an element particle of the canvas's flat look sits and its colour, `u` (0..1) through its cycle
## (AttackFormCanvas._emit_parts). Moved out of AttackFormCanvas unchanged in v0.9.0 VX (its file length).
## Presentation only (EI-07): pure functions.


static func xf(
	kind: StringName, p: Vector3, u: float, r1: float, r2: float, r3: float, age: float, j: int
) -> Transform3D:
	var a := TAU * r1
	var out := Vector3(cos(a), 0, sin(a))
	match kind:
		&"sparks":
			var pos := (
				p
				+ out * u * 0.5 * (0.5 + r2)
				+ Vector3.UP * (u * 0.9 - u * u * 1.1) * (0.6 + r3 * 0.6)
			)
			return Transform3D(Basis.from_scale(Vector3.ONE * 0.05), pos)
		&"crackle":
			var step := floori(age / 3.0)
			var h := AttackFormCanvas._hash(j * 31 + step, int(r1 * 1000.0))
			var pos := p + Vector3(cos(TAU * h), (h - 0.5) * 0.3, sin(TAU * h)) * 0.22
			var b := Basis.from_euler(Vector3(PI * h, TAU * r2, PI * 0.5 * (0.5 + r3)))
			return Transform3D(b * Basis.from_scale(Vector3(0.025, 0.32, 0.025)), pos)
		&"shards":
			var pos := p + out * u * 0.35 + Vector3.UP * (0.15 - u * 0.3)
			var b := Basis.from_euler(Vector3(r1 * TAU + u * 3.0, r2 * TAU, 0.6))
			return Transform3D(b * Basis.from_scale(Vector3(0.06, 0.17, 0.06)), pos)
		&"drip":
			var pos := p + out * 0.08 * r2 + Vector3.DOWN * u * 0.4
			return Transform3D(Basis.from_scale(Vector3(0.045, 0.09 * (1.0 + u), 0.045)), pos)
	# smear: a flat streak stretching as it fades
	return AttackFormCanvas.flat(p + out * 0.1 * u, a, 0.45 * (0.4 + u), 0.15)


static func color(kind: StringName, c: Color, u: float, fade: float, age: float, j: int) -> Color:
	match kind:
		&"sparks":
			return AttackFormCanvas.lit_color(c, (1.0 - u) * fade, 1.6)
		&"crackle":
			var on := 1.0 if (floori(age / 3.0) + j) % 2 == 0 else 0.35
			return AttackFormCanvas.lit_color(c, on * fade, 1.8)
		&"shards":
			return AttackFormCanvas.lit_color(c, (1.0 - u) * fade, 1.3)
		&"drip":
			return AttackFormCanvas.lit_color(c, (1.0 - u * u) * fade, 1.4)
	return AttackFormCanvas.lit_color(c, 0.45 * (1.0 - u) * fade, 1.3)
