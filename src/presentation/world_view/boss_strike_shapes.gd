class_name BossStrikeShapes
extends RefCounted
## v0.8.0 AV part 2: BossStrikeViews' 3D shapes, laid out each draw into its pools: each strike kind's rocks, blades,
## bands, beams and ground quads, the arc swooshes' triangles, and the falling eggs' and shells' shadows. Presentation
## only; ticks are the sim's (the strike's age), so it pauses with the game.

const Y_GROUND := 0.045
const STONE := Color(0.46, 0.43, 0.4)
const STEEL := Color(0.72, 0.7, 0.68)
const METAL := Color(0.26, 0.26, 0.28)
const SHELL := Color(0.86, 0.83, 0.72)
const DUST := Color(0.64, 0.58, 0.52)
const STEAM := Color(0.86, 0.87, 0.9)

## The views' pools (id -> {mm, used, cap, drawn}) and the swooshes' triangles ([position, colour]) this draw.
var pools := {}
var arc_add := []
var arc_mix := []


func put(pool: StringName, xf: Transform3D, c: Color, cd: Color) -> void:
	var p: Dictionary = pools[pool]
	var n: int = p["used"]
	if n >= int(p["cap"]):
		return
	var mm: MultiMesh = p["mm"]
	mm.set_instance_transform(n, xf)
	mm.set_instance_color(n, c)
	mm.set_instance_custom_data(n, cd)
	p["used"] = n + 1


func strike(s: Dictionary, age: float, after: float, dens: float, still: bool) -> void:
	var life: float = BossStrikeViews.LIFE[s["kind"]]
	var sd: int = s["seed"]
	var glow: Color = s["glow"]
	match s["kind"]:
		&"crater", &"crack_impact":
			for d: Array in s["discs"]:
				_crater(d[0], d[1], age, life, sd, glow, float(s["glow_i"]), dens, still)
		&"eruption":
			for d: Array in s["discs"]:
				_eruption(d[0], d[1], age, life, sd, glow, float(s["glow_i"]), dens, still)
		&"shell":
			for k in (s["discs"] as Array).size():
				var d: Array = s["discs"][k]
				_shell(d[0], d[1], age, life, sd + k * 17, dens, still)
		&"acid_splat":
			for k in (s["discs"] as Array).size():
				var d: Array = s["discs"][k]
				_splat(d[0], d[1], age, life, sd + k * 17, glow, dens, still)
		&"javelins":
			for k in (s["discs"] as Array).size():
				var d: Array = s["discs"][k]
				_javelins(d[0], d[1], age, life, sd + k * 17)
		&"light_burst":
			for d: Array in s["discs"]:
				_light_burst(d[0], d[1], age, life, sd, glow)
		&"light_ring", &"shock_ring", &"steam_ring":
			_ring(s, age, life)
		&"dust_arc", &"steel_arc":
			_arc(s, age, life, dens, still)
		&"spears":
			for k in (s["lanes"] as Array).size():
				_spears(s["lanes"][k], age, after, life, sd + k * 97, still)
		&"beam", &"rail":
			for k in (s["lanes"] as Array).size():
				_beam(s, s["lanes"][k], age, after, life, sd + k * 97)
		&"molten", &"fire_lanes":
			for k in (s["lanes"] as Array).size():
				_molten(s, s["lanes"][k], age, after, life, sd + k * 97, dens, still)
		&"skid":
			_skid(s, after, life, sd)


static func _h(a: int, b: int) -> float:
	return VfxCore.h(a, b)


static func _dir3(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, -v.y)


## A tumbling rock `s` across at `p` (custom: heat, seed, glow index).
func _rock(
	p: Vector3, s: float, c: Color, heat: float, sd: int, k: int, spin: float, gi: float
) -> void:
	var axis := Vector3(_h(sd, k) - 0.5, 0.6, _h(sd + 1, k) - 0.5).normalized()
	var b := Basis(axis, spin + TAU * _h(sd + 2, k)).scaled(Vector3.ONE * s)
	put(&"rock", Transform3D(b, p), c, Color(heat, _h(sd + 3, k), gi, BossStrikeMeshes.pack(c)))


## A ground quad at `c` (3D), `along` its long axis (length `l`) and `w` across, pattern `pat` (BossStrikeMeshes.G_*).
func _ground(
	c: Vector3,
	along: Vector3,
	l: float,
	w: float,
	pat: float,
	heat: float,
	alpha: float,
	glow: Color,
	_sd: int  # kept for the callers; the noise offset now comes from the glow
) -> void:
	if alpha <= 0.005 or l <= 0.01:
		return
	var x := along.normalized()
	var z := x.cross(Vector3.UP)
	var b := Basis(x * l, Vector3.UP, z * w)
	put(
		&"ground",
		Transform3D(b, Vector3(c.x, Y_GROUND, c.z)),
		glow,
		Color(pat, clampf(heat, 0.0, 1.0), BossStrikeMeshes.pack(glow), alpha)
	)


## A band (ring) of radius `r`, `hgt` tall at `c`.
func _band(
	pool: StringName, c: Vector3, r: float, hgt: float, col: Color, bright: float, sd: int
) -> void:
	if col.a <= 0.005 or r <= 0.01:
		return
	var b := Basis(Vector3.RIGHT * r, Vector3.UP * hgt, Vector3.BACK * r)
	var cd := Color(
		clampf(col.a, 0.0, 1.0), float(sd % 89) / 89.0, bright, BossStrikeMeshes.pack(col)
	)
	put(pool, Transform3D(b, c), col, cd)


## A beam from `a` to `b`, `rad` thick.
func _tube(a: Vector3, b: Vector3, rad: float, col: Color, bright: float, sd: int) -> void:
	var d := b - a
	if d.length() < 0.01 or col.a <= 0.005:
		return
	var side := d.cross(Vector3.UP).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	var up := side.cross(d).normalized()
	var basis := Basis(d, up * rad, side * rad)
	var cd := Color(
		2.0 + clampf(col.a, 0.0, 1.0), float(sd % 89) / 89.0, bright, BossStrikeMeshes.pack(col)
	)
	put(&"beam", Transform3D(basis, a), col, cd)


static func _fade(age: float, life: float, tail: float) -> float:
	return clampf((life - age) / tail, 0.0, 1.0)


func _crater(
	c2: Vector2,
	r: float,
	age: float,
	life: float,
	sd: int,
	glow: Color,
	gi: float,
	dens: float,
	still: bool
) -> void:
	var c := SimPlane.to_3d(c2)
	var heat := clampf(1.0 - age / life, 0.0, 1.0)
	var fade := _fade(age, life, 14.0)
	_ground(
		c,
		Vector3(cos(sd), 0, sin(sd)),
		r * 2.3,
		r * 2.3,
		BossStrikeMeshes.G_CRATER,
		heat,
		fade,
		glow,
		sd
	)
	var n := int(round(12.0 * dens))
	for k in n:
		var a := TAU * (k + _h(sd + 4, k)) / maxf(n, 1)
		var t := clampf(age / 22.0, 0.0, 1.0)
		var out := r * (0.25 + 0.95 * _h(sd + 5, k)) * t
		var y := 0.15 + (3.0 * t - 3.0 * t * t) * (0.6 + _h(sd + 6, k))
		var p := c + Vector3(cos(a) * out, maxf(y, 0.08), sin(a) * out)
		var s := (0.28 + 0.3 * _h(sd + 7, k)) * fade
		_rock(p, s, STONE, heat, sd, k, 0.0 if still else age * 0.35 * (_h(sd + 8, k) - 0.5), gi)
	var u := clampf(age / 16.0, 0.0, 1.0)
	var front := r * (0.6 + 1.1 * (1.0 - (1.0 - u) * (1.0 - u)))
	_band(&"band_mix", c, front, 0.4 * (1.0 - 0.5 * u), Color(DUST, 0.7 * (1.0 - u)), 1.0, sd)


func _eruption(
	c2: Vector2,
	r: float,
	age: float,
	life: float,
	sd: int,
	glow: Color,
	gi: float,
	dens: float,
	still: bool
) -> void:
	var c := SimPlane.to_3d(c2)
	var heat := clampf(1.0 - age / life, 0.0, 1.0)
	var fade := _fade(age, life, 14.0)
	_ground(
		c, Vector3.RIGHT, r * 2.2, r * 2.2, BossStrikeMeshes.G_CRATER, heat * 0.6, fade, glow, sd
	)
	var n := int(round(14.0 * dens))
	for k in n:
		var a := TAU * (k + _h(sd + 4, k)) / maxf(n, 1)
		var t := clampf(age / 30.0, 0.0, 1.0)
		var out := r * (0.5 + 0.7 * t) * (0.7 + 0.5 * _h(sd + 5, k))
		var y := 0.1 + (4.6 * t - 4.6 * t * t) * (0.7 + 0.7 * _h(sd + 6, k))
		var p := c + Vector3(cos(a) * out, maxf(y, 0.1), sin(a) * out)
		_rock(
			p,
			(0.25 + 0.3 * _h(sd + 7, k)) * fade,
			Color(0.4, 0.33, 0.26),
			heat,
			sd,
			k,
			0.0 if still else age * 0.3,
			gi
		)
	var u := clampf(age / 20.0, 0.0, 1.0)
	_band(
		&"band_mix",
		c,
		r * (0.5 + 0.8 * u),
		1.3 * (1.0 - 0.6 * u),
		Color(0.5, 0.42, 0.33, 0.9 * (1.0 - u)),
		1.0,
		sd
	)


func _shell(
	c2: Vector2, r: float, age: float, life: float, sd: int, dens: float, still: bool
) -> void:
	var c := SimPlane.to_3d(c2)
	var heat := clampf(1.0 - age / 24.0, 0.0, 1.0)
	var fade := _fade(age, life, 14.0)
	_ground(
		c,
		Vector3(cos(sd), 0, sin(sd)),
		r * 2.0,
		r * 2.0,
		BossStrikeMeshes.G_CRATER,
		heat,
		fade,
		Color(1.0, 0.5, 0.15),
		sd
	)
	var n := int(round(8.0 * dens))
	for k in n:
		var a := TAU * _h(sd + 4, k)
		var t := clampf(age / 18.0, 0.0, 1.0)
		var out := r * (0.4 + 1.2 * _h(sd + 5, k)) * t
		var y := 0.12 + (2.6 * t - 2.6 * t * t) * (0.5 + _h(sd + 6, k))
		var p := c + Vector3(cos(a) * out, maxf(y, 0.08), sin(a) * out)
		_rock(
			p,
			(0.14 + 0.16 * _h(sd + 7, k)) * fade,
			METAL,
			heat,
			sd,
			k,
			0.0 if still else age * 0.5,
			0.0
		)
	var u := clampf(age / 8.0, 0.0, 1.0)
	_band(&"band_add", c, r * (0.3 + 1.2 * u), 0.6, Color(1.0, 0.6, 0.25, 0.9 * (1.0 - u)), 2.2, sd)


func _splat(
	c2: Vector2, r: float, age: float, life: float, sd: int, glow: Color, dens: float, still: bool
) -> void:
	var c := SimPlane.to_3d(c2)
	var heat := clampf(1.0 - age / 30.0, 0.0, 1.0)
	var grow := clampf(0.35 + age / 5.0, 0.0, 1.0)
	var fade := _fade(age, life, 24.0)
	_ground(
		c,
		Vector3(cos(sd), 0, sin(sd)),
		r * 2.5 * grow,
		r * 2.5 * grow,
		BossStrikeMeshes.G_SPLAT,
		heat,
		fade,
		glow,
		sd
	)
	var n := int(round(7.0 * dens))
	for k in n:  # the egg's shell, broken
		var a := TAU * _h(sd + 4, k)
		var t := clampf(age / 14.0, 0.0, 1.0)
		var out := r * (0.2 + 0.7 * _h(sd + 5, k)) * t
		var y := 0.08 + (1.6 * t - 1.6 * t * t) * (0.4 + _h(sd + 6, k))
		var p := c + Vector3(cos(a) * out, maxf(y, 0.06), sin(a) * out)
		_rock(p, 0.16 * fade, SHELL, heat * 0.6, sd, k, 0.0 if still else age * 0.4, 1.0)
	var u := clampf(age / 10.0, 0.0, 1.0)
	_band(&"band_add", c, r * (0.4 + 0.8 * u), 0.5, Color(glow, 0.6 * (1.0 - u)), 1.4, sd)


func _javelins(c2: Vector2, r: float, age: float, life: float, sd: int) -> void:
	var c := SimPlane.to_3d(c2)
	var heat := clampf(1.0 - age / 30.0, 0.0, 1.0)
	_ground(
		c,
		Vector3.RIGHT,
		r * 1.6,
		r * 1.6,
		BossStrikeMeshes.G_CRATER,
		heat * 0.5,
		_fade(age, life, 16.0),
		Color(1.0, 0.66, 0.3),
		sd
	)
	for k in 4:
		var a := TAU * (k + _h(sd + 4, k)) / 4.0
		var off := 0.0 if k == 0 else r * (0.35 + 0.35 * _h(sd + 5, k))
		var base := c + Vector3(cos(a) * off, 0.0, sin(a) * off)
		var lean := 0.25 + 0.2 * _h(sd + 6, k)
		var axis := Vector3(-sin(a), 0, cos(a))
		var hgt := 1.5 + 0.4 * _h(sd + 7, k)
		var drop := clampf(age / 4.0, 0.0, 1.0)  # thrown down from the sky in four ticks
		var sink := clampf((age - (life - 16.0)) / 16.0, 0.0, 1.0)
		var lift := (1.0 - drop) * 3.5
		var b := Basis(axis, lean) * Basis.from_scale(Vector3(1.2, hgt * (1.0 - sink * 0.9), 1.2))
		var p := base + b.y.normalized() * lift - Vector3.UP * hgt * 0.15 * drop
		put(&"blade", Transform3D(b, p), STEEL, Color(heat, _h(sd, k), 0.0, 0.0))


func _light_burst(c2: Vector2, r: float, age: float, life: float, sd: int, glow: Color) -> void:
	var c := SimPlane.to_3d(c2)
	var u := clampf(age / 12.0, 0.0, 1.0)
	var fade := _fade(age, life, 18.0)
	_band(&"band_add", c, r * (0.4 + 1.1 * u), 0.8, Color(glow, fade), 2.0, sd)
	_band(&"band_add", c, r * (0.2 + 0.7 * u), 1.4, Color(0.85, 0.6, 1.0, fade * 0.8), 1.6, sd + 1)
	_tube(
		c, c + Vector3.UP * 4.5 * (1.0 - u * 0.5), r * 0.3 * (1.0 - u), Color(glow, fade), 2.0, sd
	)
	_ground(
		c, Vector3.RIGHT, r * 2.0, r * 2.0, BossStrikeMeshes.G_CRATER, 1.0 - u, fade * 0.6, glow, sd
	)


func _ring(s: Dictionary, age: float, life: float) -> void:
	var g: Array = s["ring"]
	var c := SimPlane.to_3d(g[0])
	var r0: float = maxf(float(g[1]), 0.3)
	var r1: float = minf(float(g[2]), r0 + 16.0)  # a room-wide shockwave rolls out, not to the room's edge
	var sd: int = s["seed"]
	var glow: Color = s["glow"]
	var fade := _fade(age, life, 14.0)
	match s["kind"]:
		&"light_ring":
			var u := clampf(age / 8.0, 0.0, 1.0)
			var r := lerpf(r0, r1, 1.0 - (1.0 - u) * (1.0 - u))
			_band(&"band_add", c, r, 0.9, Color(glow, fade), 2.2, sd)
			_band(&"band_add", c, r * 0.85, 0.5, Color(0.85, 0.6, 1.0, fade * 0.7), 1.6, sd + 1)
		&"shock_ring":
			var u := clampf(age / 24.0, 0.0, 1.0)
			var r := lerpf(r0, r1, u)
			_band(&"band_mix", c, r, 0.7 * (1.0 - 0.4 * u), Color(DUST, 0.85 * fade), 1.0, sd)
			_band(&"band_add", c, r + 0.15, 0.25, Color(glow, 0.8 * (1.0 - u)), 1.8, sd + 1)
		_:  # steam_ring: a blast of steam and heat
			var u := clampf(age / 10.0, 0.0, 1.0)
			var r := lerpf(maxf(r0, 0.6), r1, 1.0 - (1.0 - u) * (1.0 - u))
			var rise := clampf(age / life, 0.0, 1.0)
			_band(&"band_mix", c, r, 1.6 + 1.2 * rise, Color(STEAM, 0.8 * fade), 1.0, sd)
			_band(&"band_add", c, r * 0.9, 0.4, Color(glow, 0.9 * (1.0 - u)), 2.0, sd + 1)
			_ground(
				c,
				Vector3.RIGHT,
				r1 * 2.0,
				r1 * 2.0,
				BossStrikeMeshes.G_CRATER,
				0.6 * (1.0 - rise),
				fade * 0.5,
				glow,
				sd
			)


func _arc(s: Dictionary, age: float, life: float, dens: float, still: bool) -> void:
	var g: Array = s["arc"]
	var c: Vector2 = g[0]
	var r0: float = g[1]
	var r1: float = g[2]
	var a0: float = g[3]
	var a1: float = g[4]
	var sd: int = s["seed"]
	var steel: bool = s["kind"] == &"steel_arc"
	var sweep := clampf(age / 7.0, 0.0, 1.0)
	var fade := _fade(age, life, 12.0)
	var head := lerpf(a0, a1, sweep)
	var steps := 18
	var out: Array = arc_add if steel else arc_mix
	for k in steps:
		var t0 := float(k) / steps
		var t1 := float(k + 1) / steps
		var b0 := lerpf(a0, a1, t0)
		var b1 := lerpf(a0, a1, t1)
		if b0 > head:
			break
		b1 = minf(b1, head)
		var trail0 := clampf(1.0 - (head - b0) / maxf(absf(a1 - a0), 0.01) * 0.8, 0.15, 1.0)
		var trail1 := clampf(1.0 - (head - b1) / maxf(absf(a1 - a0), 0.01) * 0.8, 0.15, 1.0)
		var rr := lerpf(r0, r1, 0.92)
		var hgt := 0.9 if steel else 0.7
		var col := Color(1.0, 0.85, 0.6) if steel else Color(0.55, 0.5, 0.45)
		var p0 := SimPlane.to_3d(c + Vector2(cos(b0), sin(b0)) * rr)
		var p1 := SimPlane.to_3d(c + Vector2(cos(b1), sin(b1)) * rr)
		var q0 := SimPlane.to_3d(c + Vector2(cos(b0), sin(b0)) * lerpf(r0, r1, 0.55))
		var q1 := SimPlane.to_3d(c + Vector2(cos(b1), sin(b1)) * lerpf(r0, r1, 0.55))
		var a_0 := (0.85 if steel else 0.5) * fade * trail0
		var a_1 := (0.85 if steel else 0.5) * fade * trail1
		# A curved wall at the reach and a skirt toward the boss: the swing's sweep of dust (or steel).
		(
			out
			. append_array(
				[
					[p0 + Vector3.UP * 0.05, Color(col, a_0)],
					[p1 + Vector3.UP * 0.05, Color(col, a_1)],
					[p1 + Vector3.UP * hgt, Color(col, 0.0)],
					[p0 + Vector3.UP * 0.05, Color(col, a_0)],
					[p1 + Vector3.UP * hgt, Color(col, 0.0)],
					[p0 + Vector3.UP * hgt, Color(col, 0.0)],
					[q0 + Vector3.UP * 0.06, Color(col, 0.0)],
					[q1 + Vector3.UP * 0.06, Color(col, 0.0)],
					[p1 + Vector3.UP * 0.05, Color(col, a_1 * 0.6)],
					[q0 + Vector3.UP * 0.06, Color(col, 0.0)],
					[p1 + Vector3.UP * 0.05, Color(col, a_1 * 0.6)],
					[p0 + Vector3.UP * 0.05, Color(col, a_0 * 0.6)],
				]
			)
		)
	if steel:
		return
	var n := int(round(6.0 * dens))
	for k in n:  # rocks kicked up along the swing
		var t := float(k + _h(sd, k)) / maxf(n, 1)
		var b := lerpf(a0, a1, t)
		var since := age - t * 7.0
		if since < 0.0:
			continue
		var u := clampf(since / 16.0, 0.0, 1.0)
		var rr := r1 * (0.9 + 0.25 * u)
		var p := SimPlane.to_3d(c + Vector2(cos(b), sin(b)) * rr, 0.1 + (2.0 * u - 2.0 * u * u))
		_rock(p, 0.2 * fade, STONE, 0.3 * (1.0 - u), sd, k, 0.0 if still else since * 0.3, 0.0)


func _spears(o: Obb, age: float, after: float, life: float, sd: int, still: bool) -> void:
	var n := maxi(1, int(o.half.x * 2.0 / 0.55))
	var heat := clampf(1.0 - age / 40.0, 0.0, 1.0)
	var down := 0.0 if after < 0.0 else clampf(after / life, 0.0, 1.0)
	for j in n:
		var s := -o.half.x + 0.55 * (j + 0.5)
		var side := (1.0 if j % 2 == 0 else -1.0) * o.half.y * (0.2 + 0.35 * _h(sd, j))
		var at := o.center + o.axis_u * s + o.axis_v * side
		var delay := 6.0 * float(j) / n  # the thrust runs out from the boss
		var k := clampf((age - delay) / 4.0, 0.0, 1.0)
		if k <= 0.0:
			continue
		var e := sin(k * PI * 0.5)
		if not still:
			e *= 1.0 + 0.18 * sin(k * PI)
		e *= 1.0 - down * down
		if e <= 0.01:
			continue
		var hgt := (1.1 + 0.6 * _h(sd + 1, j)) * maxf(o.half.y / 0.5, 0.6)
		var lean := (0.12 + 0.18 * _h(sd + 2, j)) * signf(side)
		var axis := _dir3(o.axis_u)
		var b := Basis(axis, lean) * Basis(Vector3.UP, TAU * _h(sd + 3, j))
		b = b * Basis.from_scale(Vector3(1.3, hgt, 1.3))
		var base := SimPlane.to_3d(at) - Vector3.UP * hgt * (1.0 - e)
		put(&"blade", Transform3D(b, base), STEEL, Color(heat, _h(sd + 4, j), 0.0, 0.0))


func _beam(s: Dictionary, o: Obb, age: float, after: float, life: float, sd: int) -> void:
	var rail: bool = s["kind"] == &"rail"
	var glow: Color = s["glow"]
	var a := SimPlane.to_3d(o.center - o.axis_u * o.half.x, 0.7)
	var b := SimPlane.to_3d(o.center + o.axis_u * o.half.x, 0.7)
	var fade := 1.0
	if rail:
		fade = clampf(1.0 - age / 10.0, 0.0, 1.0)
	elif after >= 0.0:
		fade = clampf(1.0 - after / life, 0.0, 1.0)
	var reach := clampf(age / 3.0, 0.0, 1.0)  # the beam ignites down the line
	var tip := a.lerp(b, reach)
	var flick := 0.85 + 0.15 * _h(sd, int(age))
	if fade > 0.0:
		var core := 0.12 if rail else o.half.y * 0.45
		_tube(a, tip, core, Color(1.0, 0.97, 0.9, fade), 2.6 * flick, sd)
		_tube(a, tip, core * 2.6, Color(glow, 0.55 * fade), 1.8 * flick, sd + 1)
	if rail:  # its haze lingers longer than the streak
		var haze := clampf(1.0 - age / life, 0.0, 1.0)
		_tube(a, b, 0.45, Color(glow, 0.3 * haze), 1.2, sd + 2)
	var heat := clampf(1.0 - age / (life + 20.0), 0.0, 1.0) if rail else fade
	var mid := SimPlane.to_3d(o.center)
	_ground(
		mid,
		_dir3(o.axis_u),
		o.half.x * 2.0 * reach,
		o.half.y * 1.6,
		BossStrikeMeshes.G_SCORCH,
		heat,
		clampf(heat * 1.5, 0.0, 1.0),
		glow,
		sd
	)


func _molten(
	s: Dictionary, o: Obb, age: float, after: float, life: float, sd: int, dens: float, still: bool
) -> void:
	var fire: bool = s["kind"] == &"fire_lanes"
	var glow: Color = s["glow"]
	var pour := clampf(age / 12.0, 0.0, 1.0)  # it pours down the lane from the boss's end
	var len := o.half.x * 2.0 * pour
	var heat := 1.0
	var alpha := 1.0
	if after >= 0.0:
		heat = clampf(1.0 - after / (life * 0.7), 0.0, 1.0)
		alpha = clampf((life - after) / 30.0, 0.0, 1.0)
	var back := o.center - o.axis_u * o.half.x
	var mid := SimPlane.to_3d(back + o.axis_u * (len * 0.5))
	_ground(
		mid,
		_dir3(o.axis_u),
		len,
		o.half.y * 2.0,
		BossStrikeMeshes.G_MOLTEN,
		heat if not fire else minf(1.0, heat * 1.2),
		alpha,
		glow,
		sd
	)
	if pour < 1.0:  # molten blobs splash at the pouring front
		var front := back + o.axis_u * len
		for k in int(round(3.0 * dens)):
			var t := fposmod(age + _h(sd, k) * 6.0, 6.0) / 6.0
			var off := o.axis_v * o.half.y * (_h(sd + 1, k) - 0.5) * 1.4
			var p := SimPlane.to_3d(front + off, 0.1 + 0.6 * (t - t * t) * 4.0 * 0.4)
			_rock(p, 0.18, Color(0.2, 0.1, 0.06), 1.0, sd, k, 0.0 if still else age * 0.4, 3.0)


func _skid(s: Dictionary, after: float, life: float, sd: int) -> void:
	var from: Vector2 = s["from"]
	var to: Vector2 = s["to"]
	var d := to - from
	if d.length() < 0.05:
		return
	var heat := 1.0 if after < 0.0 else clampf(1.0 - after / (life * 0.6), 0.0, 1.0)
	var alpha := 1.0 if after < 0.0 else clampf((life - after) / 30.0, 0.0, 1.0)
	var o: Obb = s["lane"]
	_ground(
		SimPlane.to_3d((from + to) * 0.5),
		_dir3(d),
		d.length(),
		o.half.y * 1.5,
		BossStrikeMeshes.G_SCORCH,
		heat,
		alpha,
		s["glow"],
		sd
	)


## An egg's or a shell's shadow growing on its locked circle as it falls; a shell (not lobbed by FireballViews)
## falls into it from the sky.
func falling(f: Array) -> void:
	var c := SimPlane.to_3d(f[1])
	var r: float = f[2]
	var t: float = f[3]
	var s := r * 2.0 * (0.25 + 0.75 * t)
	var shadow := BossStrikeMeshes.G_SHADOW
	_ground(c + Vector3.UP * 0.005, Vector3.RIGHT, s, s, shadow, 0.0, 0.4 + 0.6 * t, Color.BLACK, 0)
	if bool(f[4]) or BossStrikeLooks.strike_of(f[0]) != &"shell" or t < 0.4:
		return
	var y := 9.0 * pow((1.0 - t) / 0.6, 1.5)
	_rock(c + Vector3.UP * (y + 0.3), 0.42, METAL, 0.8, 7, int(c.x * 10.0), 0.0, 0.0)
