class_name VfxLayer
extends VfxCore
## Real 3D effects for the elements (owner, 2026-10-09: "fire should be fire, even if minimalistic, that matches the
## style of the game … not a circle with bad made particles on top"; G2 Effects: "the after"; docs/art/VFX_REQUESTS.md).
## One look per element, drawn on every form: a lingering patch (field), an expanding ring, a line (beams, chains),
## a burst (bomb landings, blasts), and the statuses on an enemy. AttackFormCanvas calls it per frame instead of
## drawing its flat ground shapes when the new look is on (WorldViewRoot sets canvas.vfx); StatusVisuals draws the
## enemy statuses into it. Pools, lights and floor marks: VfxCore.
## Kinds: &"fire", &"storm", &"frost", &"venom", &"void", &"bleed".

const WARM := Color(1.0, 0.6, 0.28)
const COLD := Color(0.55, 0.75, 1.0)
const ICE := Color(0.72, 0.9, 1.0)
const VENOM := Color(0.45, 0.92, 0.3)
const VOID_GLOW := Color(0.62, 0.32, 1.0)
const VOID_DARK := Color(0.24, 0.1, 0.42)
const BLOOD := Color(0.58, 0.05, 0.09)
const SCORCH := Color(0.05, 0.04, 0.035, 0.85)
const FROST_MARK := Color(0.78, 0.93, 1.0, 0.8)
const VENOM_MARK := Color(0.2, 0.55, 0.12, 0.85)
const BLOOD_MARK := Color(0.32, 0.02, 0.04, 0.9)
const VOID_MARK := Color(0.12, 0.04, 0.2, 0.85)
## Mark keys: an effect's seed times MARK_KINDS plus its kind, so two marks of one effect never collide.
const MARK_KINDS := 8


# --- Public: one call per form ----------------------------------------------------------------------------------
## A lingering patch of radius `r` at `c` (ground). `fade` 0..1, `age` in ticks, `sd` the effect's seed.
func field(kind: StringName, c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	if fade <= 0.0:
		return
	match kind:
		&"fire":
			_fire(c, r, fade, age, sd)
		&"storm":
			_storm_field(c, r, fade, age, sd)
		&"frost":
			_frost_field(c, r, fade, age, sd)
		&"venom":
			_liquid_field(c, r, fade, age, sd, VENOM, true)
		&"bleed":
			_liquid_field(c, r, fade, age, sd, BLOOD, false)
		&"void":
			_void_field(c, r, fade, age, sd)


## A ring of radius `r` at `c` now (its front), no fill.
func ring(kind: StringName, c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	if r < 0.1 or fade <= 0.0:
		return
	match kind:
		&"fire":
			_fire_ring(c, r, fade, age, sd)
		&"storm":
			_storm_ring(c, r, fade, age, sd)
		&"frost":
			_frost_ring(c, r, fade, age, sd)
		&"venom":
			_liquid_ring(c, r, fade, age, sd, VENOM)
		&"bleed":
			_liquid_ring(c, r, fade, age, sd, BLOOD)
		&"void":
			_void_ring(c, r, fade, age, sd)


## A line from `a` to `b` (a beam or a chain at body height).
func line(kind: StringName, a: Vector3, b: Vector3, fade: float, age: float, sd: int) -> void:
	if fade <= 0.0:
		return
	match kind:
		&"fire":
			_fire_line(a, b, fade, age, sd)
		&"storm":
			_lightning(a, b, fade, age, sd, COLD)
		&"frost":
			_frost_line(a, b, fade, age, sd)
		&"venom":
			_liquid_line(a, b, fade, age, sd, VENOM, VENOM_MARK)
		&"bleed":
			_liquid_line(a, b, fade, age, sd, BLOOD, BLOOD_MARK)
		&"void":
			_void_line(a, b, fade, age, sd)


## A burst of radius `r` at `c` (ground), `u` (0..1) through its life: a bomb landing or a blast.
func burst(kind: StringName, c: Vector3, r: float, u: float, sd: int) -> void:
	match kind:
		&"storm":
			_storm_burst(c, r, u, sd)
		&"frost":
			_frost_burst(c, r, u, sd)
		&"venom":
			_liquid_burst(c, r, u, sd, VENOM, VENOM_MARK, true)
		&"bleed":
			_liquid_burst(c, r, u, sd, BLOOD, BLOOD_MARK, false)
		&"void":
			_void_burst(c, r, u, sd)
		_:
			_explosion(c, r, u, sd)


## An enemy's statuses at `p` (its feet), body radius `r`: {burn, shock, bleed, frost, frozen, poison: stacks}.
## Burning: flames on the body; shocked: arcs over it; bleeding: red drips; poisoned: bubbles and green drips;
## frost: ice crystals at its feet, frozen: a crystal cage and frost under it.
func status(p: Vector3, r: float, on: Dictionary, sd: int) -> void:
	var age := _now
	var burn: int = on.get(&"burn", 0)
	if burn > 0:
		var n := clampi(1 + burn / 2, 1, 4)
		for k in n:
			var a := TAU * (k / float(n) + h(sd, k))
			var q := p + Vector3(cos(a) * r * 0.45, 0.25 + 0.2 * h(sd + 1, k), sin(a) * r * 0.45)
			var beat := 0.85 + 0.15 * sin(age * 0.4 + TAU * h(sd + 2, k))
			var hgt := (0.45 + 0.25 * h(sd + 3, k) + 0.04 * burn) * beat
			var cell := (k + int(age / 11.0)) % 4
			_put(
				&"flame",
				_facing(q, hgt * 0.72, hgt, false),
				Color(1.6, 1.4, 1.2, 1.0),
				cell,
				0.0,
				h(sd, k) * 10.0
			)
		_embers(p + Vector3(0, 0.4, 0), age, sd, 2, 1.0)
		_light(p + Vector3(0, 0.8, 0), WARM, 0.7 + 0.1 * burn, 3.0)
	var shock: int = on.get(&"shock", 0)
	if shock > 0 and (int(age / 3.0) + sd) % 3 != 0:
		var strike := int(age / 3.0)
		var a := TAU * h(sd + strike, 1)
		var b := a + PI * (0.6 + 0.6 * h(sd + strike, 2))
		_lightning(
			p + Vector3(cos(a) * r, 0.35 + 0.5 * h(sd + strike, 3), sin(a) * r),
			p + Vector3(cos(b) * r, 0.35 + 0.5 * h(sd + strike, 4), sin(b) * r),
			0.9,
			age,
			sd + 5,
			COLD,
			0.28,
			false
		)
	var bleed: int = on.get(&"bleed", 0)
	if bleed > 0:
		_drips(p, r, age, sd, mini(3, 1 + bleed / 3), BLOOD)
		mark(
			_status_key(sd, 1, int(age / 120.0)),
			_splat(sd + int(age / 120.0)),
			p,
			0.35 + r * 0.6,
			BLOOD_MARK
		)
	var poison: int = on.get(&"poison", 0)
	if poison > 0:
		_drips(p, r, age, sd + 3, mini(2, 1 + poison / 4), VENOM)
		for k in mini(4, 1 + poison / 2):
			_bubble(p + Vector3(0, 0.3, 0), r * 0.8, age, sd + 9 * k, 0.16, 1.0, 40.0, VENOM)
	var frozen := on.has(&"frozen")
	var frost: int = 6 if frozen else mini(on.get(&"frost", 0), 4)
	for k in frost:
		var a := TAU * k / maxf(frost, 1) + h(sd, k + 20)
		var out := Vector3(cos(a), 0, sin(a))
		var lean := (-0.35 if frozen else 0.45) + 0.15 * h(sd, k + 21)
		var hgt := (1.05 if frozen else 0.35) * (0.8 + 0.4 * h(sd, k + 22))
		_crystal(p + out * (r * (1.0 if frozen else 0.95)), Vector3.UP + out * lean, hgt, 0.22, ICE)
	if frozen:
		mark(_status_key(sd, 2, 0), &"frost", p, r * 2.4, FROST_MARK)


static func _status_key(sd: int, kind: int, slot: int) -> int:
	return -((sd * 4096 + slot) * MARK_KINDS + kind) - 1


static func _splat(k: int) -> StringName:
	return [&"splat0", &"splat1", &"splat2", &"splat3"][posmod(k, 4)]


# --- Fire -------------------------------------------------------------------------------------------------------
## Fire over a patch: upright flames with a taller core, rising embers, a little smoke, warm light, a scorch.
func _fire(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var n := clampi(int(round((4.0 + r * r * 2.5) * density)), 3, 20)
	for k in n:
		var a := TAU * h(sd, k)
		# The first three flames make a taller core near the centre, so the patch reads as one blaze.
		var d := sqrt(h(sd + 3, k)) * r * (0.3 if k < 3 else 0.85)
		var p := c + Vector3(cos(a) * d, 0.0, sin(a) * d)
		# Each flame breathes on its own beat and swaps its shape now and then.
		var beat := 0.85 + 0.15 * sin(age * (0.35 + 0.2 * h(sd + 5, k)) + TAU * h(sd + 7, k))
		var hgt := (
			(0.9 + 0.9 * h(sd + 9, k))
			* (0.6 + 0.4 * (1.0 - d / maxf(r, 0.01)))
			* beat
			* fade
			* (1.35 if k < 3 else 1.0)
		)
		_flame(p, hgt, k, age, sd, fade)
		_embers(p, age, sd + k * 13, 2, fade)
	for k in maxi(1, int(n / 4)):
		_smoke(c + Vector3(0, 0.5, 0), age, sd + 77 + k, 0.35 + r * 0.25, fade * 0.5, 70.0)
	_light(
		c + Vector3(0, 0.9, 0),
		WARM,
		(3.0 + r) * fade * (0.85 + 0.15 * sin(age * 0.9 + sd)),
		r + 3.5
	)
	mark(sd * MARK_KINDS, &"scorch", c, r * 1.1, SCORCH)


func _flame(p: Vector3, hgt: float, k: int, age: float, sd: int, fade: float) -> void:
	var cell := (k + int(age / (9.0 + 5.0 * h(sd, k + 40)))) % 4
	_put(
		&"flame",
		_facing(p, hgt * 0.72, hgt, false),
		Color(1.6, 1.4, 1.2, fade),
		cell,
		0.0,
		h(sd, k) * 10.0
	)


## Flames along a ring's edge.
func _fire_ring(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var n := clampi(int(r * 4.0 * density), 8, 24)
	for k in n:
		var a := TAU * (k + 0.3 * h(sd, k)) / n
		var hgt := (0.5 + 0.35 * h(sd + 1, k)) * fade
		_flame(c + Vector3(cos(a), 0, sin(a)) * r, hgt, k, age, sd, fade)
	_light(c + Vector3(0, 0.8, 0), WARM, 2.0 * fade, r + 2.5)


## Flames along the ground under a beam.
func _fire_line(a: Vector3, b: Vector3, fade: float, age: float, sd: int) -> void:
	var g0 := Vector3(a.x, 0.05, a.z)
	var g1 := Vector3(b.x, 0.05, b.z)
	var n := clampi(int(g0.distance_to(g1) / 0.55), 2, 24)
	for k in n:
		var t := (k + 0.5) / n
		var side := Vector3(h(sd, k) - 0.5, 0, h(sd + 1, k) - 0.5) * 0.4
		_flame(g0.lerp(g1, t) + side, (0.45 + 0.35 * h(sd + 2, k)) * fade, k, age, sd, fade)
	_light(g0.lerp(g1, 0.5) + Vector3(0, 0.8, 0), WARM, 2.2 * fade, g0.distance_to(g1) * 0.5 + 2.5)


## Rising embers from `p`: `n` sparks on short cycles.
func _embers(p: Vector3, age: float, sd: int, n: int, fade: float) -> void:
	for j in n:
		var period := 34.0 + 20.0 * h(sd, j)
		var u := fposmod(age + h(sd + 1, j) * period, period) / period
		var a := TAU * h(sd + 2, j)
		var q := p + Vector3(cos(a) * 0.25 * u, 0.2 + 1.4 * u, sin(a) * 0.25 * u)
		var s := 0.07 * (1.0 - u * 0.6)
		_put(&"spark", _facing(q, s, s, true), Color(2.2, 1.1, 0.35, (1.0 - u) * fade), 3, 0.0, 0.0)


## A smoke puff rising from `p` on a `period`-tick cycle, `size` across at the start, tinted `tint`.
func _smoke(
	p: Vector3,
	age: float,
	sd: int,
	size: float,
	alpha: float,
	period: float,
	tint: Color = Color(0.46, 0.43, 0.41)
) -> void:
	var u := fposmod(age + h(sd, 1) * period, period) / period
	var q := p + Vector3((h(sd, 2) - 0.5) * 0.6 * u, 1.4 * u, (h(sd, 3) - 0.5) * 0.6 * u)
	var s := size * (0.6 + 1.1 * u)
	var a := alpha * sin(PI * u)
	_put(
		&"smoke",
		_facing(q, s, s, true, h(sd, 4) * TAU),
		Color(tint, a),
		int(h(sd, 5) * 4.0),
		u * 0.5,
		h(sd, 6)
	)


## A bomb landing: a fireball that blooms and burns out (fading, darkening, no streaks), debris thrown out, a smoke
## cloud that rises after it, a light flash, a ragged scorch.
func _explosion(c: Vector3, r: float, u: float, sd: int) -> void:
	var bloom := clampf(u / 0.2, 0.0, 1.0)
	var burn := clampf((u - 0.1) / 0.3, 0.0, 1.0)
	if burn < 1.0:
		for k in 3:
			var a := TAU * h(sd, k)
			var off := Vector3(cos(a), 0, sin(a)) * r * 0.35 * h(sd + 1, k)
			var s := r * (0.9 + 0.5 * h(sd + 2, k)) * (0.5 + 0.7 * bloom + 0.2 * burn)
			var hot := 1.0 - burn
			_put(
				&"blast",
				_facing(c + off + Vector3(0, 0.05 + 0.4 * burn, 0), s, s, false),
				Color(1.8, 1.0 + 0.6 * hot, 0.5 + 0.9 * hot, hot * hot),
				(sd + k) % 4,
				0.0,
				h(sd, k)
			)
	var nd := int(round(4 * density))
	for k in nd:
		var a := TAU * (k + h(sd + 4, k)) / maxf(nd, 1)
		var sp := r * (0.9 + 0.8 * h(sd + 5, k))
		var t := clampf(u * 1.6, 0.0, 1.0)
		var q := (
			c
			+ Vector3(
				cos(a) * sp * t,
				(2.4 * t - 2.6 * t * t) * (0.8 + h(sd + 6, k)) + 0.15,
				sin(a) * sp * t
			)
		)
		var s := 0.9 + 0.4 * h(sd + 7, k)
		_put(
			&"debris",
			_facing(q, s, s, true, u * 6.0 * (h(sd, k) - 0.5)),
			Color(0.95, 0.9, 0.85, 1.0 - clampf((u - 0.35) / 0.2, 0.0, 1.0)),
			(sd + k) % 4,
			0.0,
			0.0
		)
	# The smoke takes over as the fireball goes: a cloud that rises and spreads, light grey so it reads on dark floors.
	for k in int(round(5 * density)):
		var a := TAU * h(sd + 8, k)
		var q := c + Vector3(cos(a) * r * 0.45, 0.5 + 1.6 * u, sin(a) * r * 0.45)
		var s := r * (0.8 + 1.0 * u) * (0.8 + 0.4 * h(sd + 11, k))
		var al := 0.85 * clampf((u - 0.08) / 0.2, 0.0, 1.0) * (1.0 - u) * (1.0 - u * 0.3)
		_put(
			&"smoke",
			_facing(q, s, s, true, TAU * h(sd + 9, k)),
			Color(0.52, 0.48, 0.45, al),
			(sd + k) % 4,
			u * 0.4,
			h(sd, k + 9)
		)
	for k in int(round(10 * density)):
		var a := TAU * h(sd + 10, k)
		var t := clampf(u * 2.2, 0.0, 1.0)
		var q := (
			c + Vector3(cos(a) * r * 1.3 * t, 0.3 + 1.6 * t - 1.8 * t * t, sin(a) * r * 1.3 * t)
		)
		_put(&"spark", _facing(q, 0.12, 0.12, true), Color(2.4, 1.3, 0.4, 1.0 - t), k % 4, 0.0, 0.0)
	_light(c + Vector3(0, 1.0, 0), WARM, 7.0 * pow(1.0 - u, 2.0), r * 3.0 + 2.0)
	mark(sd * MARK_KINDS, &"scorch", c, r * 1.25, SCORCH)


# --- Storm ------------------------------------------------------------------------------------------------------
## Lightning from `a` to `b`: a jagged bolt that re-strikes every few ticks, sparks at its end, a cold flicker.
func _lightning(
	a: Vector3,
	b: Vector3,
	fade: float,
	age: float,
	sd: int,
	cold: Color,
	width: float = 0.5,
	lit: bool = true
) -> void:
	var strike := int(age / 3.0)
	var span := a.distance_to(b)
	var on := 0.75 + 0.25 * float((strike + sd) % 2)
	var segs := clampi(int(span / 2.5) + 1, 1, 6)
	var prev := a
	for s in segs:
		var t := float(s + 1) / segs
		var nxt := a.lerp(b, t)
		if s < segs - 1:
			nxt += (
				Vector3(
					h(sd + strike, s) - 0.5,
					(h(sd + strike, s + 9) - 0.5) * 0.6,
					h(sd + strike, s + 17) - 0.5
				)
				* minf(span * 0.25, 0.9)
			)
		_put(
			&"bolt",
			_ribbon(prev, nxt, width * (0.8 + 0.4 * h(sd, s))),
			Color(cold.r * 2.2, cold.g * 2.2, cold.b * 2.4, fade * on),
			(strike + s + sd) % 4,
			0.0,
			0.0
		)
		prev = nxt
	for j in 3:
		var q := (
			b
			+ (
				Vector3(
					h(sd + strike, j + 30) - 0.5,
					h(sd + strike, j + 40) * 0.5,
					h(sd + strike, j + 50) - 0.5
				)
				* 0.5
			)
		)
		_put(
			&"spark",
			_facing(q, 0.16, 0.16, true, h(sd, j) * TAU),
			Color(cold.r * 2.0, cold.g * 2.0, cold.b * 2.2, fade),
			j % 4,
			0.0,
			0.0
		)
	if lit:
		_light(b + Vector3(0, 0.6, 0), cold, 1.8 * fade * on, 4.0)


## A crackling field: bolts arcing from near its middle out to its edge, re-striking, a cold light.
func _storm_field(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var strike := int(age / 4.0)
	var n := clampi(int(round((3.0 + r * 2.0) * density)), 2, 10)
	for k in n:
		var a := TAU * (k + h(sd + strike, k)) / n
		var p := (
			c
			+ Vector3(
				(h(sd + strike, k + 3) - 0.5) * r * 0.5,
				0.3 + 0.5 * h(sd + strike, k + 7),
				(h(sd + strike, k + 5) - 0.5) * r * 0.5
			)
		)
		var q := c + Vector3(cos(a) * r * 0.9, 0.08, sin(a) * r * 0.9)
		_lightning(p, q, fade * 0.9, age, sd + k * 7, COLD, 0.45, false)
	_light(c + Vector3(0, 0.8, 0), COLD, (1.4 + r * 0.5) * fade, r + 3.0)


## A shock ring: lightning running round its edge at waist height, no ground fill.
func _storm_ring(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var n := clampi(int(r * 3.0), 6, 18)
	var y := Vector3(0, 0.35, 0)
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p := c + y + Vector3(cos(a0), 0, sin(a0)) * r
		var q := c + y + Vector3(cos(a1), 0, sin(a1)) * r
		_put(
			&"bolt",
			_ribbon(p, q, 0.45),
			Color(
				COLD.r * 2.2,
				COLD.g * 2.2,
				COLD.b * 2.4,
				fade * (0.7 + 0.3 * h(sd + int(age / 3.0), k))
			),
			(k + int(age / 3.0)) % 4,
			0.0,
			0.0
		)
	_light(c + Vector3(0, 0.6, 0), COLD, 1.6 * fade, r + 2.5)


## A storm blast: bolts striking out from its middle to its edge, sparks, a cold flash.
func _storm_burst(c: Vector3, r: float, u: float, sd: int) -> void:
	var fade := 1.0 - u
	var top := c + Vector3(0, 0.9, 0)
	for k in 6:
		var a := TAU * (k + h(sd, k)) / 6.0
		_lightning(
			top,
			c + Vector3(cos(a), 0.05, sin(a)) * r * (0.6 + 0.4 * u),
			fade,
			u * 70.0,
			sd + k,
			COLD,
			0.5,
			false
		)
	_light(top, COLD, 5.0 * fade * fade, r * 2.5 + 2.0)


# --- Frost ------------------------------------------------------------------------------------------------------
## Frost over a patch: ice crystals grown out of the floor, a low cold mist, glints, frost on the floor.
func _frost_field(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var grow := clampf(age / 10.0, 0.0, 1.0)
	var n := clampi(int(round((3.0 + r * r * 2.0) * density)), 3, 16)
	for k in n:
		var a := TAU * h(sd, k)
		var d := sqrt(h(sd + 1, k)) * r * 0.85
		var out := Vector3(cos(a), 0, sin(a))
		var hgt := (0.35 + 0.55 * h(sd + 2, k)) * (1.0 - 0.5 * d / maxf(r, 0.01)) * grow * fade
		_crystal(
			c + out * d,
			Vector3.UP + out * (0.25 + 0.4 * h(sd + 3, k)),
			hgt,
			0.2 + 0.12 * h(sd + 4, k),
			ICE
		)
		if k < 4:
			_glint(c + out * d + Vector3(0, hgt, 0), age, sd + k, fade)
	for k in 2:
		_smoke(
			c + Vector3(0, 0.1, 0),
			age,
			sd + 40 + k,
			0.5 + r * 0.4,
			0.35 * fade,
			110.0,
			Color(0.75, 0.88, 1.0)
		)
	_light(c + Vector3(0, 0.6, 0), ICE, 0.9 * fade, r + 2.0)
	mark(sd * MARK_KINDS + 1, &"frost", c, r * 1.2, FROST_MARK)


## A ring of ice spikes erupting along the ring's front.
func _frost_ring(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var n := clampi(int(r * 4.0 * density), 8, 24)
	for k in n:
		var a := TAU * (k + 0.4 * h(sd, k)) / n
		var out := Vector3(cos(a), 0, sin(a))
		var hgt := (0.4 + 0.4 * h(sd + 1, k)) * fade
		_crystal(c + out * r, Vector3.UP + out * 0.5, hgt, 0.22, ICE)
		if k % 4 == 0:
			_glint(c + out * r + Vector3(0, hgt, 0), age, sd + k, fade)
	_light(c + Vector3(0, 0.5, 0), ICE, 1.2 * fade, r + 2.0)


## Ice spikes along the ground under a beam, glints along it.
func _frost_line(a: Vector3, b: Vector3, fade: float, age: float, sd: int) -> void:
	var g0 := Vector3(a.x, 0.0, a.z)
	var g1 := Vector3(b.x, 0.0, b.z)
	var dir := (g1 - g0).normalized()
	var side := dir.cross(Vector3.UP)
	var n := clampi(int(g0.distance_to(g1) / 0.5), 2, 28)
	for k in n:
		var t := (k + 0.5) / n
		var s := 1.0 if k % 2 == 0 else -1.0
		var hgt := (0.35 + 0.3 * h(sd, k)) * fade
		_crystal(
			g0.lerp(g1, t) + side * s * 0.15, Vector3.UP + side * s * 0.4 + dir * 0.2, hgt, 0.2, ICE
		)
	for k in 3:
		_glint(a.lerp(b, h(sd + int(age / 6.0), k)), age, sd + k, fade)
	_light(g0.lerp(g1, 0.5) + Vector3(0, 0.6, 0), ICE, 1.3 * fade, g0.distance_to(g1) * 0.5 + 2.0)


## Ice bursting out of the floor: crystals erupt outward, shards fly, a cold flash, frost left behind.
func _frost_burst(c: Vector3, r: float, u: float, sd: int) -> void:
	var rise := clampf(u / 0.12, 0.0, 1.0)
	var sink := clampf((u - 0.6) / 0.4, 0.0, 1.0)
	var n := clampi(int(round((6.0 + r * 4.0) * density)), 6, 20)
	for k in n:
		var a := TAU * (k + h(sd, k)) / n
		var d := r * (0.25 + 0.65 * h(sd + 1, k))
		var out := Vector3(cos(a), 0, sin(a))
		var hgt := (0.5 + 0.7 * h(sd + 2, k)) * (1.0 - 0.4 * d / r) * rise * (1.0 - sink)
		_crystal(c + out * d, Vector3.UP + out * (0.3 + 0.5 * h(sd + 3, k)), hgt, 0.26, ICE)
	for k in int(round(10 * density)):
		var a := TAU * h(sd + 5, k)
		var t := clampf(u * 2.5, 0.0, 1.0)
		var q := (
			c + Vector3(cos(a) * r * 1.1 * t, 0.2 + 1.4 * t - 1.6 * t * t, sin(a) * r * 1.1 * t)
		)
		_put(&"spark", _facing(q, 0.14, 0.14, true, a), Color(1.4, 1.8, 2.2, 1.0 - t), 2, 0.0, 0.0)
	_smoke(
		c + Vector3(0, 0.1, 0),
		u * 60.0,
		sd + 7,
		r * 0.9,
		0.4 * (1.0 - u),
		60.0,
		Color(0.8, 0.9, 1.0)
	)
	_light(c + Vector3(0, 0.8, 0), ICE, 4.0 * (1.0 - u) * (1.0 - u), r * 2.5 + 1.5)
	mark(sd * MARK_KINDS + 1, &"frost_burst", c, r * 1.35, FROST_MARK)


func _glint(p: Vector3, age: float, sd: int, fade: float) -> void:
	var u := fposmod(age + 40.0 * h(sd, 1), 40.0) / 40.0
	if u > 0.25:
		return
	var s := 0.22 * sin(PI * u / 0.25)
	_put(&"spark", _facing(p, s, s, true), Color(1.6, 1.9, 2.2, fade), 0, 0.0, 0.0)


# --- Venom and bleed (liquids) -----------------------------------------------------------------------------------
## A liquid patch: splatters on the floor, splashes and drips cycling, and for venom bubbles and green gas.
func _liquid_field(
	c: Vector3, r: float, fade: float, age: float, sd: int, col: Color, toxic: bool
) -> void:
	var mark_c := VENOM_MARK if toxic else BLOOD_MARK
	mark(sd * MARK_KINDS + 2, _splat(sd), c, r * 1.15, mark_c)
	if r > 1.4:
		var a := TAU * h(sd, 70)
		mark(
			sd * MARK_KINDS + 3,
			_splat(sd + 1),
			c + Vector3(cos(a), 0, sin(a)) * r * 0.5,
			r * 0.7,
			mark_c
		)
	var n := clampi(int(round((2.0 + r * r * 1.5) * density)), 2, 12)
	for k in n:
		var a := TAU * h(sd, k)
		var d := sqrt(h(sd + 1, k)) * r * 0.8
		var p := c + Vector3(cos(a) * d, 0.02, sin(a) * d)
		if toxic:
			_bubble(p, 0.15, age, sd + k * 5, 0.14 + 0.1 * h(sd + 2, k), fade, 50.0, col)
		else:
			_splash_cycle(p, age, sd + k * 5, 0.35, fade, col)
	if toxic:
		for k in 2:
			_smoke(c, age, sd + 60 + k, 0.5 + r * 0.35, 0.3 * fade, 90.0, Color(0.42, 0.75, 0.3))
		_light(c + Vector3(0, 0.5, 0), col, 0.8 * fade, r + 2.0)


## Splashes cycling along a ring's front.
func _liquid_ring(c: Vector3, r: float, fade: float, age: float, sd: int, col: Color) -> void:
	var n := clampi(int(r * 3.0 * density), 6, 18)
	for k in n:
		var a := TAU * (k + 0.4 * h(sd, k)) / n
		_splash_cycle(c + Vector3(cos(a), 0, sin(a)) * r, age, sd + k, 0.45, fade, col)


## A spray along a beam: sideways jets along it, a splash and a splatter where it ends.
func _liquid_line(
	a: Vector3, b: Vector3, fade: float, age: float, sd: int, col: Color, mark_c: Color
) -> void:
	var n := clampi(int(a.distance_to(b) / 0.8), 1, 12)
	var dir := b - a
	var screen := Vector2(dir.dot(_cam_basis.x), dir.dot(_cam_basis.y))
	var roll := screen.angle()
	for k in n:
		var t := (k + 0.5) / n
		var s := 0.8 + 0.3 * h(sd + int(age / 5.0), k)
		_put(
			&"splash",
			_facing(a.lerp(b, t), s, s * 0.6, true, roll),
			Color(col, 0.9 * fade),
			1,
			0.0,
			0.0
		)
	_splash_cycle(Vector3(b.x, 0.02, b.z), age, sd, 0.6, fade, col)
	mark(sd * MARK_KINDS + 2, _splat(sd), Vector3(b.x, 0.0, b.z), 0.7, mark_c)


## A liquid blast: a crown splash, drops thrown out, a splatter left on the floor; venom bubbles after it.
func _liquid_burst(
	c: Vector3, r: float, u: float, sd: int, col: Color, mark_c: Color, toxic: bool
) -> void:
	var grow := clampf(u / 0.25, 0.0, 1.0)
	var gone := clampf((u - 0.3) / 0.3, 0.0, 1.0)
	if gone < 1.0:
		var s := r * (0.9 + 0.6 * grow)
		_put(
			&"splash",
			_facing(c, s * 1.3, s * 0.8, false),
			Color(col, 1.0 - gone),
			0,
			gone * 0.6,
			h(sd, 1)
		)
		_put(
			&"splash",
			_facing(c, s * 0.7, s, false),
			Color(col, 1.0 - gone),
			2,
			gone * 0.6,
			h(sd, 2)
		)
	for k in int(round(10 * density)):
		var a := TAU * h(sd + 3, k)
		var t := clampf(u * 1.8, 0.0, 1.0)
		var q := (
			c + Vector3(cos(a) * r * 1.2 * t, 0.3 + 1.8 * t - 2.0 * t * t, sin(a) * r * 1.2 * t)
		)
		var sz := 0.2 + 0.12 * h(sd + 4, k)
		_put(&"bubble", _facing(q, sz, sz, true), Color(col, 1.0 - t), 0, 0.0, 0.0)
	if toxic:
		for k in 4:
			_bubble(c, r * 0.8, u * 70.0, sd + 9 * k, 0.18, 1.0 - u, 40.0, col)
		_smoke(c, u * 60.0, sd + 5, r, 0.4 * (1.0 - u), 60.0, Color(0.42, 0.75, 0.3))
	_light(c + Vector3(0, 0.6, 0), col, 2.0 * (1.0 - u), r * 2.0 + 1.0)
	mark(sd * MARK_KINDS + 2, _splat(sd), c, r * 1.3, mark_c)


## A splash at `p` on a cycle: it rises and falls back.
func _splash_cycle(p: Vector3, age: float, sd: int, size: float, fade: float, col: Color) -> void:
	var period := 30.0 + 20.0 * h(sd, 1)
	var u := fposmod(age + h(sd, 2) * period, period) / period
	if u > 0.5:
		return
	var s := size * (0.6 + 0.8 * u)
	var cell := 0 if h(sd, 3) < 0.5 else 2
	_put(
		&"splash",
		_facing(p, s, s * 0.8, false),
		Color(col, fade * (1.0 - 2.0 * u)),
		cell,
		u,
		h(sd, 4)
	)


## A bubble rising from somewhere within `spread` of `p` and popping at the top of its cycle.
func _bubble(
	p: Vector3,
	spread: float,
	age: float,
	sd: int,
	size: float,
	fade: float,
	period: float,
	col: Color
) -> void:
	var u := fposmod(age + h(sd, 1) * period, period) / period
	var a := TAU * h(sd, 2)
	var q := p + Vector3(cos(a) * spread * h(sd, 3), 0.1 + 0.8 * u, sin(a) * spread * h(sd, 3))
	var pop := u > 0.85
	var s := size * (1.6 if pop else 0.7 + 0.5 * u)
	var cell := 2 if pop else (0 if h(sd, 4) < 0.6 else 1)
	_put(&"bubble", _facing(q, s, s, true), Color(col.lightened(0.25), fade * 0.9), cell, 0.0, 0.0)


## Drips falling from a body of radius `r` at `p`.
func _drips(p: Vector3, r: float, age: float, sd: int, n: int, col: Color) -> void:
	for k in n:
		var u := fposmod(age / 40.0 + k / float(n) + h(sd, k), 1.0)
		var a := TAU * h(sd + 1, k)
		var q := p + Vector3(cos(a) * r * 0.7, 0.85 * (1.0 - u * u), sin(a) * r * 0.7)
		_put(&"splash", _facing(q, 0.22, 0.3, true), Color(col, 1.0 - u * 0.5), 3, 0.0, 0.0)


# --- Void -------------------------------------------------------------------------------------------------------
## A void patch: dark tendrils curling up out of it, a rift flickering open in its middle, a violet glow.
func _void_field(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var n := clampi(int(round((2.0 + r * r * 1.5) * density)), 2, 12)
	for k in n:
		var a := TAU * h(sd, k)
		var d := sqrt(h(sd + 1, k)) * r * 0.8
		_tendril(
			c + Vector3(cos(a) * d, 0, sin(a) * d),
			age,
			sd + k * 3,
			0.9 + 0.6 * h(sd + 2, k),
			fade,
			60.0
		)
	var open := 0.75 + 0.25 * sin(age * 0.2 + sd)
	_put(
		&"rift",
		_facing(c + Vector3(0, 0.1, 0), r * 0.35 * open, r * 0.9, false),
		Color(VOID_GLOW * 1.6, fade),
		int(age / 20.0 + sd) % 4,
		0.0,
		h(sd, 9)
	)
	_light(c + Vector3(0, 0.7, 0), VOID_GLOW, 1.4 * fade, r + 2.5)
	mark(sd * MARK_KINDS + 4, &"scorch", c, r * 1.1, VOID_MARK)


## Tendrils curling up along a ring's front.
func _void_ring(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var n := clampi(int(r * 3.0 * density), 6, 18)
	for k in n:
		var a := TAU * (k + 0.4 * h(sd, k)) / n
		_tendril(c + Vector3(cos(a), 0, sin(a)) * r, age, sd + k, 0.7, fade, 30.0)
	_light(c + Vector3(0, 0.5, 0), VOID_GLOW, 1.2 * fade, r + 2.0)


## A rift torn along a beam, tendrils where it ends.
func _void_line(a: Vector3, b: Vector3, fade: float, age: float, sd: int) -> void:
	var w := 0.5 * (0.85 + 0.15 * sin(age * 0.5 + sd))
	_put(
		&"rift",
		_ribbon_tall(a, b, w),
		Color(VOID_GLOW * 1.6, fade),
		int(age / 8.0 + sd) % 4,
		0.0,
		h(sd, 1)
	)
	for k in 2:
		_tendril(Vector3(b.x, 0, b.z), age, sd + k, 0.8, fade, 40.0)
	_light(a.lerp(b, 0.5), VOID_GLOW, 1.5 * fade, a.distance_to(b) * 0.5 + 2.0)


## A void blast: a rift tears open and closes, tendrils lash out, a violet flash, a dark mark.
func _void_burst(c: Vector3, r: float, u: float, sd: int) -> void:
	var open := clampf(u / 0.15, 0.0, 1.0) * (1.0 - clampf((u - 0.45) / 0.35, 0.0, 1.0))
	if open > 0.0:
		_put(
			&"rift",
			_facing(c, r * 0.6 * open, r * 1.6, false),
			Color(VOID_GLOW * 2.0, 1.0),
			sd % 4,
			0.0,
			h(sd, 1)
		)
	var n := int(round(6 * density))
	for k in n:
		var a := TAU * (k + h(sd + 2, k)) / maxf(n, 1)
		var t := clampf(u * 1.5, 0.0, 1.0)
		var p := c + Vector3(cos(a), 0, sin(a)) * r * 0.9 * t
		_tendril(p, u * 70.0, sd + k, 1.1 * (1.0 - u * 0.5), 1.0 - u, 70.0)
	_light(c + Vector3(0, 0.9, 0), VOID_GLOW, 5.0 * (1.0 - u) * (1.0 - u), r * 2.5 + 1.5)
	mark(sd * MARK_KINDS + 4, &"scorch", c, r * 1.25, VOID_MARK)


## A dark tendril curling up from `p` on a `period`-tick cycle, `size` tall.
func _tendril(p: Vector3, age: float, sd: int, size: float, fade: float, period: float) -> void:
	var u := fposmod(age + h(sd, 1) * period, period) / period
	var s := size * (0.7 + 0.5 * u)
	var flip := 1.0 if h(sd, 5) < 0.5 else -1.0
	var xf := _facing(p, s * 0.6 * flip, s, false, (h(sd, 4) - 0.5) * 0.4)
	_put(
		&"tendril", xf, Color(VOID_DARK, fade * sin(PI * u)), int(h(sd, 3) * 4.0), u * 0.6, h(sd, 6)
	)
