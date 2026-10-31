class_name StormPack
extends RefCounted
## v0.10.0 VX6 (VFX_PACK N1, lightning in the pack's style): the VfxLayer's storm looks (a bolt or chain line, a shock
## field, a shock ring, a storm blast, the shock on an enemy), moved out of vfx_layer.gd. The layer asks here; every
## look draws the pack's version (ZdBolt, assets/vfx_zd/lightning: a jagged ribbon in the beam's shader, plus the
## pack's ripple, rim and pulse areas, ids vx6_* in data/vfx/pack_fx_vx6.tres and the VX1 storm spark) and falls back to
## the old sprite bolts for the instance whose family has no room (bolt 48, area 16). The layer's lights stay.
## - Bolts are held effects: a bolt is "touched" each frame its line is drawn (PackHold) and goes back to PackFx the
##   frame it is not. The layer draws every frame from the sim's state, so a bolt is keyed by its seed and by how many
##   bolts of that seed this frame asked first (a discharge draws one line per enemy under one seed).
## Cosmetic only (EI-07).

const PACK_STORM := true  # false: the old sprite bolts (the before shots)
const BOLT := &"vx6_bolt"
const FIELD := &"vx6_field"
const RING := &"vx6_ring"
const BURST := &"vx6_burst"
const SPARK := &"vx1_hit_storm"
## The old ribbon's width -> the bolt's core width, and its largest.
const WIDTH_PER_M := 0.25
const WIDTH_MAX := 0.14
## The area scenes' scale per metre of radius (their quads are 4 m across at 1).
const AREA_PER_M := 0.5
const SPARK_SCALE := 0.09
## The field's short bolts re-strike this often (ticks); a shocked enemy's forks too.
const FIELD_STRIKE_TICKS := 24.0
const SHOCK_STRIKE_TICKS := 18.0
const SHOCK_REACH_M := 0.5
const SHOCK_FORKS := 2

var layer: VfxLayer
var holds := PackHold.new()
var _seen := {}  # seed -> bolts asked for it this frame


func _init(p_layer: VfxLayer) -> void:
	layer = p_layer


## The storm's pack colours: the hot centre, the body and the deep edge of ElementLooks' storm.
static func colors() -> Dictionary:
	return {
		&"primary": ElementLooks.hot(&"storm"),
		&"secondary": ElementLooks.core(&"storm"),
		&"tertiary": ElementLooks.deep(&"storm"),
	}


## A frame starts (VfxLayer.begin).
func begin(fx: PackFx) -> void:
	holds.fx = fx
	holds.begin()
	_seen.clear()


## A frame ends (VfxLayer.finish): the bolts and areas nothing touched go back to PackFx.
func end() -> void:
	holds.end()


func _pack() -> bool:
	return PACK_STORM and layer.pack_fx != null


# --- Lines ---------------------------------------------------------------------------------------------------------
## Lightning from `a` to `b` (a strike, a chain jump, a beam): the pack's bolt, held while it is drawn, `fade` its
## brightness; `mix` varies the shape without changing which bolt it is (a field's re-strike). `spark`: the hit spark
## where it lands, once. Without room the old jagged sprites, re-struck every few ticks, a cold flicker light.
func lightning(
	a: Vector3,
	b: Vector3,
	fade: float,
	age: float,
	sd: int,
	cold: Color,
	width: float = 0.5,
	lit: bool = true,
	mix: int = 0,
	spark: bool = true
) -> void:
	if _bolt(a, b, fade, sd, width, mix, spark):
		if lit:
			var on := 0.75 + 0.25 * float((int(age / 3.0) + sd) % 2)
			layer._light(b + Vector3(0, 0.6, 0), cold, 1.8 * fade * on, 4.0)
		return
	sprite_bolt(a, b, fade, age, sd, cold, width, lit)


## The pack bolt for this line; false when there is no PackFx or no room in the bolt family.
func _bolt(
	a: Vector3, b: Vector3, fade: float, sd: int, width: float, mix: int, spark: bool
) -> bool:
	if not _pack():
		return false
	var n: int = _seen.get(sd, 0)
	_seen[sd] = n + 1
	var setup := Callable()
	if spark:
		setup = func(_node: Node3D) -> void: _spark(b)
	var node := (
		holds.touch(((sd * 64 + n) * 8) + 1, BOLT, &"bolt", a, 1.0, colors(), setup) as ZdBolt
	)
	if node == null:
		return false
	node.strength = fade
	node.set_ends(a, b, sd * 13 + n + mix, minf(width * WIDTH_PER_M, WIDTH_MAX))
	return true


## The storm hit spark at `at` (the VX1 hit, in the storm's colours), if its family has room.
func _spark(at: Vector3) -> void:
	var fx := layer.pack_fx
	if fx != null and fx.has_id(SPARK) and fx.has_room(&"hit"):
		fx.spawn(SPARK, at, SPARK_SCALE, colors())


## The old look: a jagged bolt of sprites that re-strikes every few ticks, sparks at its end, a cold flicker.
func sprite_bolt(
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
					VfxCore.h(sd + strike, s) - 0.5,
					(VfxCore.h(sd + strike, s + 9) - 0.5) * 0.6,
					VfxCore.h(sd + strike, s + 17) - 0.5
				)
				* minf(span * 0.25, 0.9)
			)
		layer._put(
			&"bolt",
			layer._ribbon(prev, nxt, width * (0.8 + 0.4 * VfxCore.h(sd, s))),
			Color(cold.r * 2.2, cold.g * 2.2, cold.b * 2.4, fade * on),
			(strike + s + sd) % 4,
			0.0,
			0.0
		)
		prev = nxt
	for j in layer._thin(&"spark", 3):
		var q := (
			b
			+ (
				Vector3(
					VfxCore.h(sd + strike, j + 30) - 0.5,
					VfxCore.h(sd + strike, j + 40) * 0.5,
					VfxCore.h(sd + strike, j + 50) - 0.5
				)
				* 0.5
			)
		)
		layer._put(
			&"spark",
			layer._facing(q, 0.16, 0.16, true, VfxCore.h(sd, j) * TAU),
			Color(cold.r * 2.0, cold.g * 2.0, cold.b * 2.2, fade),
			j % 4,
			0.0,
			0.0
		)
	if lit:
		layer._light(b + Vector3(0, 0.6, 0), cold, 1.8 * fade * on, 4.0)


# --- Field, ring, burst ----------------------------------------------------------------------------------------------
## A crackling field: the pack's ripple held over the patch with a few short bolts striking inside it, a cold light.
## Without room for the ripple: bolts arcing from near its middle out to its edge, re-striking.
func field(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var cold := VfxLayer.COLD
	var area: Node3D = null
	if _pack():
		area = holds.touch(
			VfxPackViews.zkey(sd, 31, c), FIELD, &"area", c, r * AREA_PER_M, colors()
		)
	if area != null:
		var strike := int(age / FIELD_STRIKE_TICKS)
		var phase := fposmod(age, FIELD_STRIKE_TICKS) / FIELD_STRIKE_TICKS
		var n := clampi(1 + int(r), 2, 4)
		for k in n:
			var a := TAU * VfxCore.h(sd + strike, k)
			var a2 := a + (VfxCore.h(sd + strike, k + 9) - 0.5)
			var p := c + Vector3(cos(a), 0.0, sin(a)) * r * 0.25 + Vector3(0, 0.5, 0)
			var q := c + Vector3(cos(a2), 0.08, sin(a2)) * r * (0.55 + 0.3 * VfxCore.h(sd, k))
			lightning(
				p, q, fade * (1.0 - phase * 0.7), age, sd + k * 7, cold, 0.45, false, strike, false
			)
		layer._light(c + Vector3(0, 0.8, 0), cold, (1.4 + r * 0.5) * fade, r + 3.0)
		return
	var strike := int(age / 4.0)
	var n := clampi(int(round((3.0 + r * 2.0) * layer.density)), 2, 10)
	for k in n:
		var a := TAU * (k + VfxCore.h(sd + strike, k)) / n
		var p := (
			c
			+ Vector3(
				(VfxCore.h(sd + strike, k + 3) - 0.5) * r * 0.5,
				0.3 + 0.5 * VfxCore.h(sd + strike, k + 7),
				(VfxCore.h(sd + strike, k + 5) - 0.5) * r * 0.5
			)
		)
		var q := c + Vector3(cos(a) * r * 0.9, 0.08, sin(a) * r * 0.9)
		sprite_bolt(p, q, fade * 0.9, age, sd + k * 7, VfxLayer.COLD, 0.45, false)
	layer._light(c + Vector3(0, 0.8, 0), cold, (1.4 + r * 0.5) * fade, r + 3.0)


## A shock ring: the pack's rim held at the front with bolts running along its edge at waist height, no ground fill.
## Without room for the rim: sprite lightning round the edge.
func ring(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var cold := VfxLayer.COLD
	var y := Vector3(0, 0.35, 0)
	var rim: Node3D = null
	if _pack():
		rim = holds.touch(VfxPackViews.zkey(sd, 32, c), RING, &"area", c, r * AREA_PER_M, colors())
	if rim != null:
		var n := clampi(int(r * 1.5 * layer.density), 3, 8)
		for k in n:
			var a0 := TAU * k / n
			var a1 := a0 + TAU / n * 0.8
			var p := c + y + Vector3(cos(a0), 0, sin(a0)) * r
			var q := c + y + Vector3(cos(a1), 0, sin(a1)) * r
			var f := fade * (0.7 + 0.3 * VfxCore.h(sd + int(age / 3.0), k))
			lightning(p, q, f, age, sd + k * 5, cold, 0.4, false, 0, false)
		layer._light(c + Vector3(0, 0.6, 0), cold, 1.6 * fade, r + 2.5)
		return
	var n := clampi(int(r * 3.0 * layer.density), 6, 18)  # P-13: Effects density, as its siblings
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p := c + y + Vector3(cos(a0), 0, sin(a0)) * r
		var q := c + y + Vector3(cos(a1), 0, sin(a1)) * r
		layer._put(
			&"bolt",
			layer._ribbon(p, q, 0.45),
			Color(
				cold.r * 2.2,
				cold.g * 2.2,
				cold.b * 2.4,
				fade * (0.7 + 0.3 * VfxCore.h(sd + int(age / 3.0), k))
			),
			(k + int(age / 3.0)) % 4,
			0.0,
			0.0
		)
	layer._light(c + Vector3(0, 0.6, 0), cold, 1.6 * fade, r + 2.5)


## A storm blast: the pack's pulse once (a ring out to the radius) and 3-5 bolts striking from its middle to its edge,
## a cold flash. Without room for the pulse: six bolts of sprites.
func burst(c: Vector3, r: float, u: float, sd: int) -> void:
	var cold := VfxLayer.COLD
	var fade := 1.0 - u
	var top := c + Vector3(0, 0.9, 0)
	var mode := VfxPackViews.ONCE_OLD
	if _pack():
		mode = layer._views.once(VfxPackViews.bkey(sd, 11), &"area")
		if mode == VfxPackViews.ONCE_SPAWN:
			var scale := r * AREA_PER_M * (VfxLayer.PACK_THIN_SCALE if layer._lights_off else 1.0)
			PackHold.play(layer.pack_fx, BURST, c, scale, colors())
	if mode != VfxPackViews.ONCE_OLD:
		var n := 3 + absi(sd) % 3
		for k in n:
			var a := TAU * (k + VfxCore.h(sd, k)) / n
			var to := c + Vector3(cos(a), 0.05, sin(a)) * r * (0.6 + 0.4 * u)
			lightning(top, to, fade * fade, u * 70.0, sd + k, cold, 0.5, false)
	else:
		for k in 6:
			var a := TAU * (k + VfxCore.h(sd, k)) / 6.0
			var to := c + Vector3(cos(a), 0.05, sin(a)) * r * (0.6 + 0.4 * u)
			sprite_bolt(top, to, fade, u * 70.0, sd + k, cold, 0.5, false)
	layer._light(top, cold, 5.0 * fade * fade, r * 2.5 + 2.0)


# --- Status ----------------------------------------------------------------------------------------------------------
## A shocked enemy at `p` (its feet), body radius `r`, `top` high: two small forks from the body's middle outwards,
## striking somewhere new about every 0.3 s (held, following it). False: no room, the old arcs over it draw.
func shock(p: Vector3, r: float, sd: int, age: float, top: float) -> bool:
	if not _pack():
		return false
	var strike := int(age / SHOCK_STRIKE_TICKS)
	var phase := fposmod(age, SHOCK_STRIKE_TICKS) / SHOCK_STRIKE_TICKS
	var centre := p + Vector3(0, maxf(top * 0.5, 0.3), 0)
	var reach := maxf(SHOCK_REACH_M, r + 0.2)
	var nodes: Array[ZdBolt] = []
	for k in SHOCK_FORKS:
		var node := holds.touch(VfxPackViews.skey(sd, 40 + k), BOLT, &"bolt", centre, 1.0, colors())
		if node == null:
			return false  # (the forks already drawn go back when this frame ends)
		nodes.append(node as ZdBolt)
	for k in SHOCK_FORKS:
		var ang := TAU * (VfxCore.h(sd + strike, k + 1) + 0.5 * k)
		var dir := Vector3(cos(ang), 0.25 * (VfxCore.h(sd + strike, k + 5) - 0.5), sin(ang))
		var node := nodes[k]
		node.strength = 1.0 - 0.7 * phase
		node.set_ends(centre + dir * r * 0.5, centre + dir * reach, sd * 9 + strike * 3 + k, 0.09)
	return true
