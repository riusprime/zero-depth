class_name HeroFx
extends RefCounted
## v0.9.0 VX (VFX_AUDIT.md V3, V4, V6, V8, V14, V15, V19, V22, V25, V26, V29, V30, V31, V33; owner, the quality bar:
## "no cheap 2d flat arts with just plane colours, the idea is that every VFX has a high quality layered effect"): the
## hero's element effects, drawn into the effects layer's pools (VfxCore), each one layered:
## - a bright additive core (a white-hot star or flash), a soft glow halo round it (the `glow` pool), a textured body
##   (the owner's sheets: flames, embers, lightning bolts, frost burst, splashes, bubbles, tendrils, smoke) and pieces
##   with motion and falloff (sparks streaking out and dropping, embers rising, drips falling, mist drifting);
## - per element: Fire embers, a hot halo and a wisp of smoke; Lightning forked, re-striking bolts that flicker; Frost
##   sharp ice shards (low-poly crystals), frosted glints and a cold mist; Venom and Bleed glossy droplets, drips and
##   splashes (Bleed dark red, a splatter left on the floor where it lands); Void its dark tendrils.
## Every piece is a pooled sprite (VfxCore's pools, its frame cap MAX_SPRITES and pressure thinning), laid out again
## each frame from the caller's numbers and the layer's clock (sim ticks plus the fraction): no state, no node, no
## allocation.
## The texture requests (VfxCore.OPTIONAL_POOLS: fx_frost_shards, fx_blood_drops, fx_lightning_fork, fx_muzzle_flash)
## are drawn when installed; without them the same layer uses the sheets above (the code fallback).
## Flashes are additive light; drops, splashes and smoke are lit matter (ART_DIRECTION §4, the A3 rule).
## Presentation only (EI-07).

## Effects density under which the accents and impact extras are left out (Low: 0.25; the core shapes stay, V47).
const LOW := 0.3
const WARM := Color(1.0, 0.6, 0.28)
const COLD := Color(0.55, 0.75, 1.0)
## The splatter sheet's four marks (VfxCore.MARK_TEX).
const SPLATS: Array[StringName] = [&"splat0", &"splat1", &"splat2", &"splat3"]


static func _h(a: int, b: int) -> float:
	return VfxCore.h(a, b)


## An additive colour `c` times `e` (over 1 feeds the glow), alpha `a`.
static func _lit(c: Color, e: float, a: float) -> Color:
	return Color(c.r * e, c.g * e, c.b * e, clampf(a, 0.0, 1.0))


# --- V6, V15, V18, V22, V25, V29, V30, V31: an element accent on a moving shot -------------------------------------
## The element accent of a shot at `p` (3D) flying along `dir` (3D, flat, unit; ZERO: none), its seed `sd`, at the
## layer's time `age`, `s` its size (1: an Orb). 2-4 pieces a frame: a glow halo in the element's colour and the
## element's own pieces trailing behind. None at Low.
static func accent(
	layer: VfxCore,
	kind: StringName,
	element: StringName,
	p: Vector3,
	dir: Vector3,
	sd: int,
	s: float = 1.0
) -> void:
	if layer == null or kind == &"" or layer.density < LOW:
		return
	var age := layer.now()
	var col := ElementLooks.core(element)
	layer.sprite(&"glow", p, 0.75 * s, _lit(col, 1.1, 0.32), 0, 0.0)
	var n := 1 if layer.density < 0.7 else 2
	for j in n:
		var period := 16.0 + 8.0 * _h(sd, j)
		var u := fposmod(age + _h(sd + 1, j) * period, period) / period
		var back := p - dir * (0.25 + 0.55 * u) * s
		match kind:
			&"fire":
				_ember(layer, back + Vector3(0, 0.25 * u, 0), u, sd + j, 0.16 * s)
				if j == 0 and _h(sd + int(age / period), 7) < 0.5:
					_wisp(layer, back, u, sd + j, 0.3 * s)
			&"storm":
				_crackle(layer, p, age, sd + j * 17, 0.38 * s, col)
			&"frost":
				_shard(layer, back + Vector3(0, -0.15 * u, 0), dir, u, sd + j, 0.16 * s)
				if j == 0:
					_glint(layer, p + dir * 0.1, age, sd, 0.26 * s)
			&"venom", &"bleed":
				_drop(layer, back + Vector3(0, -0.45 * u * u, 0), u, sd + j, 0.13 * s, kind)
			&"void":
				layer.sprite(
					&"tendril",
					back,
					0.45 * s,
					Color(col, 0.6 * sin(PI * u)),
					int(_h(sd, j) * 4),
					0.0
				)


## V29: one trail mote as the element's own piece at `q`, `f` its strength (1 the newest): an ember, a crackling
## spark, a frost shard with a glint, a glossy drop, a wisp of void. Drawn even at Low (it replaces a round mote).
static func mote(
	layer: VfxCore, kind: StringName, element: StringName, q: Vector3, f: float, sd: int
) -> void:
	var u := 1.0 - f
	match kind:
		&"fire":
			_ember(layer, q + Vector3(0, 0.1 * u, 0), u, sd, 0.2)
		&"storm":
			var on := 1.0 if (int(layer.now() / 3.0) + sd) % 3 != 0 else 0.35
			var c := _lit(ElementLooks.core(element).lerp(Color.WHITE, 0.3), 2.2, f * on)
			layer.sprite(
				&"spark", q, 0.2 * (0.6 + 0.4 * f), c, 0, _h(sd, int(layer.now() / 3.0)) * TAU
			)
		&"frost":
			_shard(layer, q, Vector3.ZERO, u, sd, 0.15)
		&"venom", &"bleed":
			_drop(layer, q, u, sd, 0.12, kind)
		&"void":
			layer.sprite(&"tendril", q, 0.35, Color(0.5, 0.26, 0.9, f), sd % 4, 0.0)


## A rising ember at `q`, `u` through its life.
static func _ember(layer: VfxCore, q: Vector3, u: float, sd: int, size: float) -> void:
	var sz := size * (1.0 - 0.5 * u)
	var c := Color(1.5, 1.2, 1.0, 1.0 - u)
	if not layer.sprite(&"ember", q, sz * 1.4, c, int(_h(sd, 3) * 4.0), u * 4.0):
		layer.sprite(&"spark", q, sz, Color(2.2, 1.1, 0.35, 1.0 - u), 3, 0.0)


## A wisp of smoke at `q` rising, `u` through its life (lit matter, a warm grey).
static func _wisp(layer: VfxCore, q: Vector3, u: float, sd: int, size: float) -> void:
	var c := Color(0.5, 0.45, 0.42, 0.28 * sin(PI * u))
	layer.sprite(&"smoke", q + Vector3(0, 0.4 * u, 0), size * (0.7 + u), c, sd % 4, _h(sd, 9) * TAU)


## A crackle round `p`: a short forked bolt re-striking every 3 ticks (2 of 3 strikes lit), a spark at its tip.
static func _crackle(
	layer: VfxCore, p: Vector3, age: float, sd: int, reach: float, col: Color
) -> void:
	var strike := int(age / 3.0)
	if (strike + sd) % 3 == 0:
		return
	var a := TAU * _h(sd + strike, 1)
	var b := a + PI * (0.5 + 0.7 * _h(sd + strike, 2))
	var p0 := p + Vector3(cos(a), (_h(sd + strike, 3) - 0.5) * 0.6, sin(a)) * reach
	var p1 := p + Vector3(cos(b), (_h(sd + strike, 4) - 0.5) * 0.6, sin(b)) * reach
	var mid := (p0 + p1) * 0.5 + Vector3(0, 0.12, 0) * (_h(sd + strike, 5) - 0.5)
	var c := Color(col.r * 2.4, col.g * 2.4, col.b * 2.6, 1.0)
	var pool := &"fork" if layer.has_pool(&"fork") else &"bolt"
	layer.streak(pool, p0, mid, 0.16, c, (strike + sd) % 4)
	layer.streak(pool, mid, p1, 0.14, c, (strike + sd + 1) % 4)
	layer.sprite(&"spark", p1, 0.14, Color(2.0, 2.2, 2.6, 1.0), 0, _h(sd, strike) * TAU)


## A sharp ice shard drifting at `q`: a low-poly crystal turning, frosted (fx_frost_shards when installed).
static func _shard(
	layer: VfxCore, q: Vector3, dir: Vector3, u: float, sd: int, size: float
) -> void:
	var sz := size * (1.0 - 0.4 * u)
	var ice := Color(0.72, 0.95, 0.9)
	if layer.has_pool(&"shard"):
		layer.sprite(&"shard", q, sz * 2.0, Color(1.6, 1.9, 2.0, 1.0 - u), sd % 4, u * 3.0)
		return
	var tilt := Vector3(cos(TAU * _h(sd, 5) + u * 4.0), 0.6, sin(TAU * _h(sd, 5) + u * 4.0))
	layer._crystal(q, (tilt - dir * 0.5).normalized(), sz * 1.6, sz * 0.6, ice)


## A frosted glint at `q` on a short cycle: a four-point star flashing on and off.
static func _glint(layer: VfxCore, q: Vector3, age: float, sd: int, size: float) -> void:
	var u := fposmod(age + 20.0 * _h(sd, 1), 20.0) / 20.0
	if u > 0.35:
		return
	var s := size * sin(PI * u / 0.35)
	layer.sprite(&"spark", q, s, Color(1.7, 2.0, 2.1, 1.0), 0, 0.3)


## A glossy drop at `q` falling: a lit droplet (a tinted bubble's highlight, or fx_blood_drops) and its drip.
static func _drop(
	layer: VfxCore, q: Vector3, u: float, sd: int, size: float, kind: StringName
) -> void:
	var col := ElementLooks.core(&"bleed" if kind == &"bleed" else &"venom")
	var gloss := col.lerp(Color.WHITE, 0.12) if kind == &"bleed" else col.lightened(0.15)
	if layer.has_pool(&"drop"):
		layer.sprite(&"drop", q, size * 2.2, Color(gloss, 1.0 - u * 0.4), sd % 4, 0.0)
		return
	layer.sprite(&"bubble", q, size, Color(gloss, 1.0 - u * 0.4), 1, 0.0)
	layer.sprite(&"splash", q + Vector3(0, 0.08, 0), size * 1.6, Color(col, 0.9 - u * 0.5), 3, 0.0)


# --- V22: an element spray across a fan ---------------------------------------------------------------------------
## The element's pieces thrown across a fan from `o` along `dir` (unit, flat), `half` radians either side, `reach` m,
## `u` 0..1 through it: Fire an ember spray, Lightning a crackle arcing across the fan, Frost shards and glints, Venom
## and Bleed droplets. `n` pieces (4-6 a volley). None at Low.
static func spray(
	layer: VfxCore,
	kind: StringName,
	element: StringName,
	o: Vector3,
	dir: Vector3,
	half: float,
	reach: float,
	u: float,
	sd: int,
	n: int = 5
) -> void:
	if layer == null or kind == &"" or layer.density < LOW or u >= 1.0:
		return
	var t := 1.0 - (1.0 - u) * (1.0 - u)
	var yaw := atan2(-dir.z, dir.x)
	if kind == &"storm" and int(u * 9.0) % 3 != 2:
		var a0 := yaw - half * 0.8
		var a1 := yaw + half * 0.8
		var r := reach * (0.45 + 0.4 * t)
		var p0 := o + Vector3(cos(a0), 0.0, -sin(a0)) * r
		var p1 := o + Vector3(cos(a1), 0.0, -sin(a1)) * r
		var mid := o + dir * r * 1.08 + Vector3(0, 0.1 * (_h(sd, int(u * 9.0)) - 0.5), 0)
		var c := _lit(ElementLooks.core(element), 2.4, 1.0 - u)
		var pool := &"fork" if layer.has_pool(&"fork") else &"bolt"
		layer.streak(pool, p0, mid, 0.2, c, sd % 4)
		layer.streak(pool, mid, p1, 0.2, c, (sd + 1) % 4)
	for j in n:
		var a := yaw + (_h(sd, j) * 2.0 - 1.0) * half
		var d := Vector3(cos(a), 0.0, -sin(a))
		var q := o + d * reach * (0.25 + 0.75 * t * (0.6 + 0.4 * _h(sd, j + 7)))
		match kind:
			&"fire":
				_ember(layer, q + Vector3(0, 0.3 * t, 0), u, sd + j, 0.2)
			&"storm":
				layer.sprite(&"spark", q, 0.16 * (1.0 - u), _lit(COLD, 2.2, 1.0 - u), 0, a)
			&"frost":
				_shard(layer, q, d, u, sd + j, 0.15)
				if j % 2 == 0 and u < 0.5:
					layer.sprite(
						&"spark", q, 0.25 * sin(PI * u / 0.5), Color(1.7, 2.0, 2.1, 1.0), 0, 0.3
					)
			&"venom", &"bleed":
				_drop(layer, q + Vector3(0, -0.4 * u * u, 0), u, sd + j, 0.13, kind)
			&"void":
				layer.sprite(&"tendril", q, 0.5, Color(0.5, 0.26, 0.9, 1.0 - u), j % 4, 0.0)


# --- V4, V8, V19: an element's extra on a hit -------------------------------------------------------------------
## The element's extra at a hit at `p` (3D) along `dir` (unit, flat), `u` 0..1 through it, `s` its strength: Fire
## embers, a hot halo and a wisp of smoke; Lightning a short fork; Frost ice glints, a frost burst and shards; Venom
## a splash and droplets; Bleed a splash, droplets and a splatter mark. None at Low.
static func impact(
	layer: VfxCore, kind: StringName, p: Vector3, dir: Vector3, u: float, sd: int, s: float = 1.0
) -> void:
	if layer == null or kind == &"" or layer.density < LOW or u >= 1.0:
		return
	var t := 1.0 - (1.0 - u) * (1.0 - u)
	match kind:
		&"fire":
			layer.sprite(
				&"glow", p, 1.1 * s * (0.6 + 0.6 * t), _lit(WARM, 1.6, 0.6 * (1.0 - u)), 0, 0.0
			)
			for j in 2:
				var a := TAU * _h(sd, j)
				var q := p + Vector3(cos(a) * 0.3 * t, 0.15 + 0.7 * t, sin(a) * 0.3 * t) * s
				_ember(layer, q, u, sd + j, 0.18 * s)
			_wisp(layer, p, u, sd + 5, 0.4 * s)
		&"storm":
			if u < 0.55 and int(u * 12.0) % 3 != 2:
				for j in 3:
					var a := atan2(-dir.z, dir.x) + (_h(sd, j) - 0.5) * 2.2
					var q := p + Vector3(cos(a), (_h(sd, j + 3) - 0.5) * 0.5, -sin(a)) * 0.7 * s
					var mid := p.lerp(q, 0.5) + Vector3(0, (_h(sd, j + 6) - 0.5) * 0.3, 0)
					var c := _lit(COLD, 2.4, 1.0 - u)
					var pool := &"fork" if layer.has_pool(&"fork") else &"bolt"
					layer.streak(pool, p, mid, 0.2 * s, c, (sd + j) % 4)
					layer.streak(pool, mid, q, 0.16 * s, c, (sd + j + 1) % 4)
			layer.sprite(&"glow", p, 1.0 * s, _lit(COLD, 1.6, 0.5 * (1.0 - u)), 0, 0.0)
		&"frost":
			var frost := _lit(Color(0.8, 1.0, 0.95), 1.6, 1.0 - u)
			layer.sprite(&"flake", p, (0.5 + 0.6 * t) * s, frost, 0, _h(sd, 4) * TAU)
			for j in 3:
				var a := TAU * (j / 3.0 + _h(sd, j) * 0.2)
				var q := p + Vector3(cos(a), 0.3 + 0.5 * _h(sd, j + 3), sin(a)) * 0.45 * t * s
				if u < 0.5:
					var gs := 0.3 * s * sin(PI * u / 0.5)
					layer.sprite(&"spark", q, gs, Color(1.7, 2.0, 2.1, 1.0), 0, 0.3)
				_shard(layer, q + Vector3(0, -0.3 * u * u, 0), dir, u, sd + j, 0.14 * s)
		&"venom", &"bleed":
			var col := ElementLooks.core(kind if kind == &"bleed" else &"venom")
			var spl := Color(col.lerp(Color.WHITE, 0.08), 1.0 - u)
			layer.sprite(&"splash", p + dir * 0.1, (0.5 + 0.4 * t) * s, spl, 1, 0.0)
			for j in 3:
				var a := atan2(-dir.z, dir.x) + (_h(sd, j) - 0.5) * 1.8
				var q := (
					p + Vector3(cos(a) * 0.6 * t, 0.45 * t - 0.9 * t * t, -sin(a) * 0.6 * t) * s
				)
				_drop(layer, q, u, sd + j, 0.12 * s, kind)
			if kind == &"bleed":
				var g := Vector3(p.x, 0.0, p.z) + dir * 0.4
				layer.mark(sd * 8 + 6, SPLATS[posmod(sd, 4)], g, 0.45 * s, VfxLayer.BLOOD_MARK)
		&"void":
			layer.sprite(
				&"tendril", p, 0.8 * s * (0.6 + t), Color(0.5, 0.26, 0.9, 1.0 - u), sd % 4, 0.0
			)


# --- V3, V27, V35: a muzzle spark at a volley ---------------------------------------------------------------------
## A muzzle spark at `p` along `dir` (unit, flat), `u` 0..1 through it (6 ticks): a white-hot core star, a soft glow in
## the element's colour and two sparks streaking out along the shot. No light. None at Low.
static func muzzle(
	layer: VfxCore, p: Vector3, dir: Vector3, hot: Color, col: Color, u: float, sd: int
) -> void:
	if layer == null or layer.density < LOW or u >= 1.0:
		return
	var f := 1.0 - u
	if not layer.sprite(&"muzzle", p, 0.6 * (0.7 + 0.5 * u), _lit(hot, 2.0, f), sd % 4, 0.0):
		layer.sprite(&"spark", p, 0.45 * (0.8 + 0.4 * u), _lit(hot, 2.2, f), 0, _h(sd, 1) * 0.6)
	layer.sprite(&"glow", p, 0.8, _lit(col, 1.5, 0.55 * f), 0, 0.0)
	var t := 1.0 - f * f
	for j in 2:
		var side := Vector3(-dir.z, 0.0, dir.x) * (0.45 if j == 0 else -0.45) * (0.5 + _h(sd, j))
		var v := (dir + side + Vector3(0, 0.2, 0)).normalized()
		var a := p + v * 0.55 * t
		var b := p + v * 0.55 * maxf(0.0, t - 0.3)
		layer.streak(&"spark", b, a, 0.07, _lit(col, 2.0, f), 1)


# --- V14, V19, V26: a layered flash ---------------------------------------------------------------------------------
## A flash at `p` (`u` 0..1 through it), `size` m across: a white-hot core, a glow halo in `col`, an energy ring thrown
## out and `sparks` sparks streaking off, a light when `light` (merged into a light of its colour nearby).
static func flash(
	layer: VfxCore,
	p: Vector3,
	hot: Color,
	col: Color,
	u: float,
	size: float,
	sd: int,
	sparks: int = 4,
	light: bool = true
) -> void:
	if layer == null or u >= 1.0:
		return
	var f := 1.0 - u
	var t := 1.0 - f * f
	layer.sprite(&"spark", p, size * 0.7 * (0.6 + 0.6 * f), _lit(hot, 2.4, f), 0, _h(sd, 1) * TAU)
	layer.sprite(&"glow", p, size * (0.9 + 0.5 * t), _lit(col, 1.6, 0.7 * f), 0, 0.0)
	layer.sprite(&"ring", p, size * (0.4 + 1.1 * t), _lit(col.lerp(hot, 0.3), 1.8, f * f), 0, 0.0)
	var n := sparks if layer.density >= LOW else 1
	for j in n:
		var a := TAU * (j + _h(sd, j)) / maxf(n, 1)
		var v := Vector3(cos(a), 0.35 + 0.4 * _h(sd, j + 9), sin(a)).normalized()
		var q := p + v * size * 0.8 * t + Vector3(0, -0.3 * u * u, 0)
		var tail := p + v * size * 0.8 * maxf(0.0, t - 0.25)
		layer.streak(&"spark", tail, q, 0.07, _lit(col, 2.2, f), j % 4)
	if light:
		layer.light_merged(p + Vector3(0, 0.3, 0), col, 1.8 * f * f, 2.5, 1.2)


# --- V33: a ground ring -------------------------------------------------------------------------------------------
## A quick ring on the floor at `p` (`u` 0..1 through it) out to `r` m in `col` (a ground-safe colour, V49): an energy
## ring lying flat, its soft glow and sparks rising round its edge. None at Low.
static func ground_ring(
	layer: VfxCore, p: Vector3, r: float, col: Color, u: float, sd: int
) -> void:
	if layer == null or layer.density < LOW or u >= 1.0:
		return
	var f := 1.0 - u
	var t := 1.0 - f * f
	var g := Vector3(p.x, 0.06, p.z)
	layer.flat_sprite(
		&"ring", g, 2.0 * r * (0.35 + 0.65 * t), _lit(col, 1.8, f), 0, _h(sd, 2) * TAU
	)
	layer.flat_sprite(&"glow", g, 2.4 * r * (0.4 + 0.6 * t), _lit(col, 1.2, 0.35 * f), 0, 0.0)
	for j in 6:
		var a := TAU * (j + _h(sd, j)) / 6.0
		var q := g + Vector3(cos(a), 0.0, sin(a)) * r * (0.35 + 0.65 * t) + Vector3(0, 0.5 * t, 0)
		layer.sprite(&"spark", q, 0.12 * f, _lit(col, 2.0, f), 3, 0.0)
