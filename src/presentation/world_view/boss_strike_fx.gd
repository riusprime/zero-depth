class_name BossStrikeFx
extends RefCounted
## v0.8.0 AV part 2: BossStrikeViews' share of the effects layer (VfxCore): each strike's sprites (debris, dust, smoke,
## sparks, flames from the owner's atlases), its light (merged, into the 10-light pool), its floor marks (the decal
## cap) and its explosions and acid splats (VfxLayer.burst: the frame's burst budget). Thinned with the layer's
## density. Presentation only.
## v0.10.0 VX5 (VFX_PACK R27, R36-R39): the strikes' decoration is the pack's (PackHold: each effect starts once per
## strike, the held ones follow the strike while it lasts); a full family keeps that instance's old sprites. The
## strikes' shapes, rocks, floor marks, lights and hit areas are untouched. A const to switch the old look back on.

const PACK_STRIKES := true
## Seconds the pack's dust puffs live (short, so a crater's cloud does not outlast its strike).
const DUST_LIFE_S := 1.1
## The pack's fire lanes: a flame about every FLAME_GAP_M, at most FLAMES_PER_LANE a lane.
const FLAME_GAP_M := 1.0
const FLAMES_PER_LANE := 8
const FLAME_SCALE := 0.4


static func draw(layer: VfxCore, strikes: Array[Dictionary], now: float) -> void:
	var fx := layer as VfxLayer
	var hold := _pack_hold(fx)
	if hold != null:
		hold.begin()
	for s in strikes:
		var age := now - float(s["tick"])
		var after := now - float(s["end"]) if int(s["end"]) >= 0 else -1.0
		var life: float = BossStrikeViews.LIFE[s["kind"]]
		var sd: int = s["seed"]
		var glow: Color = s["glow"]
		var u := clampf(age / life, 0.0, 1.0)
		match s["kind"]:
			&"crater", &"crack_impact", &"eruption":
				for k in (s["discs"] as Array).size():
					var d: Array = s["discs"][k]
					var c := SimPlane.to_3d(d[0])
					var r := float(d[1])
					var smoke := true
					if hold != null:  # R36: the pack's burst and dust (the rocks and the debris stay)
						var hit := (
							&"bx_impact_b" if s["kind"] == &"crack_impact" else &"bx_impact_a"
						)
						hold.once(_key(s, k, 0), hit, c, clampf(r / 3.0, 0.5, 2.5), _warm(glow))
						smoke = not hold.once(
							_key(s, k, 1),
							&"bx_smoke_big",
							c + Vector3.UP * 0.2,
							clampf(r / 2.0, 0.6, 2.0),
							{&"primary": BossStrikeShapes.DUST},
							DUST_LIFE_S
						)
					_dust_ring(layer, c, r, age, sd + k, 8, smoke)
					_rock_burst(layer, c, float(d[1]), age, sd + k)
					layer.light_merged(
						c + Vector3.UP * 0.8, glow, 3.0 * (1.0 - u) * (1.0 - u), 6.0, 2.0
					)
					layer.mark(
						BossStrikeViews.MARK_BASE + sd * 8 + k,
						crack_mark(),
						c,
						float(d[1]) * 1.1,
						BossStrikeViews.CRACK_MARK
					)
			&"shell", &"acid_splat":
				for k in (s["discs"] as Array).size():
					var d: Array = s["discs"][k]
					if fx != null and d.size() > 2 and bool(d[2]):
						var kind := &"fire" if s["kind"] == &"shell" else &"venom"
						fx.burst(kind, SimPlane.to_3d(d[0]), float(d[1]), u, sd + k)
			&"javelins":
				for k in (s["discs"] as Array).size():
					var d: Array = s["discs"][k]
					var c := SimPlane.to_3d(d[0])
					if age < 18.0:
						_dust_ring(layer, c, float(d[1]) * 0.6, age, sd + k, 5)
						_sparks(layer, c, age, sd + k, 6, glow)
					layer.mark(
						BossStrikeViews.MARK_BASE + sd * 8 + k,
						crack_mark(),
						c,
						float(d[1]) * 0.8,
						BossStrikeViews.CRACK_MARK
					)
			&"light_burst", &"light_ring":
				var c := SimPlane.to_3d(s["discs"][0][0] if s.has("discs") else s["ring"][0])
				if hold != null:  # R37: a pillar of light for the burst, a pulse for the ring
					var reach := float(s["discs"][0][1]) if s.has("discs") else float(s["ring"][2])
					var burst: bool = s["kind"] == &"light_burst"
					hold.once(
						_key(s, 0, 2),
						&"bx_pillar_light" if burst else &"bx_pulse_light",
						c,
						clampf(reach * 2.0 / (3.6 if burst else 4.5), 0.5, 5.0),
						_tint(glow)
					)
				_sparks(layer, c, age, sd, 10, glow)
				layer.light_merged(c + Vector3.UP, glow, 4.0 * (1.0 - u) * (1.0 - u), 9.0, 2.0)
			&"shock_ring", &"steam_ring":
				var g: Array = s["ring"]
				var c := SimPlane.to_3d(g[0])
				var steam: bool = s["kind"] == &"steam_ring"
				var r := lerpf(
					maxf(float(g[1]), 0.6),
					minf(float(g[2]), float(g[1]) + 16.0),
					clampf(age / (10.0 if steam else 24.0), 0.0, 1.0)
				)
				var puffs := true
				if hold != null:  # R38: a pulse of rings (and thin smoke for steam) in place of the puff ring
					var reach := clampf(minf(float(g[2]), float(g[1]) + 16.0) * 2.0 / 4.5, 0.5, 6.0)
					puffs = not hold.once(
						_key(s, 0, 3),
						&"bx_pulse_steam" if steam else &"bx_pulse_shock",
						c,
						reach,
						_tint(BossStrikeShapes.STEAM if steam else BossStrikeShapes.DUST)
					)
					if steam:
						hold.once(
							_key(s, 0, 4), &"bx_smoke_thin", c, reach * 0.6, {}, DUST_LIFE_S * 2.0
						)
				if puffs:
					_puff_ring(
						layer,
						c,
						r,
						age,
						sd,
						12,
						BossStrikeShapes.STEAM if steam else BossStrikeShapes.DUST,
						1.0 if steam else 0.5,
						&"steam" if steam and VfxCore.has_tex("fx_steam_puffs") else &"smoke"
					)
				layer.light_merged(c + Vector3.UP, glow, 3.0 * (1.0 - u), 8.0, 2.0)
			&"dust_arc", &"steel_arc":
				var g: Array = s["arc"]
				var mid := (float(g[3]) + float(g[4])) * 0.5
				var tip := SimPlane.to_3d(g[0] + Vector2(cos(mid), sin(mid)) * float(g[2]))
				if s["kind"] == &"steel_arc":
					_sparks(layer, tip, age, sd, 10, Color(1.0, 0.8, 0.5))
					layer.light_merged(tip + Vector3.UP * 0.6, glow, 2.0 * (1.0 - u), 5.0, 2.0)
				elif (
					hold == null
					or not hold.once(
						_key(s, 0, 5),
						&"bx_smoke_dust",
						tip + Vector3.UP * 0.3,
						clampf(float(g[2]) * 0.18, 0.5, 1.4),
						{&"primary": BossStrikeShapes.DUST},
						DUST_LIFE_S
					)
				):
					_dust_ring(layer, tip, float(g[2]) * 0.4, age, sd, 6)
			&"spears":
				for lane: Obb in s["lanes"]:
					if age < 14.0:
						_lane_puffs(layer, lane, age, sd, 5, BossStrikeShapes.DUST)
				if age < 10.0:
					var o: Obb = s["lanes"][0]
					layer.light_merged(
						SimPlane.to_3d(o.center, 0.8), glow, 2.5 * (1.0 - age / 10.0), 7.0, 3.0
					)
			&"beam", &"rail":
				var li := 0
				for lane: Obb in s["lanes"]:
					var on: bool = (after < 0.0 and s["kind"] == &"beam") or age < 10.0
					var far := SimPlane.to_3d(lane.center + lane.axis_u * lane.half.x, 0.7)
					var near := SimPlane.to_3d(lane.center - lane.axis_u * lane.half.x, 0.7)
					li += 1
					if on and hold != null and s["kind"] == &"rail":  # R27: the rail's blast along its lane
						var bn := hold.hold(_key(s, li, 6), &"bx_rail", near, 1.0, {}, false)
						if bn != null:
							PackHold.beam_place(bn, near, far, lane.half.y, PackHold.RAIL_NATIVE_R)
					if on:
						_sparks(layer, far, age, sd, 8, glow)
						layer.light_merged(near.lerp(far, 0.3), glow, 4.0, 8.0, 3.0)
					if s["kind"] == &"rail":
						var n := int(lane.half.x * 2.0 / 3.0)
						for k in n:
							var p := near.lerp(far, (k + 0.5) / maxf(n, 1))
							layer.mark(
								BossStrikeViews.MARK_BASE + sd * 8 + k,
								&"scorch",
								Vector3(p.x, 0.0, p.z),
								0.8,
								BossStrikeViews.CRACK_MARK
							)
			&"molten", &"fire_lanes":
				var hot := after < 0.0 or after < life * 0.5
				var lk := 0
				for lane: Obb in s["lanes"]:
					lk += 1
					if s["kind"] == &"fire_lanes" and after < 0.0:
						if hold == null or not _pack_flames(hold, s, lane, lk):
							_flames(layer, lane, age, sd)
					elif hot:
						_lane_embers(layer, lane, age, sd)
					else:
						_lane_puffs(layer, lane, age, sd, 3, Color(0.4, 0.38, 0.36))
					if hot:
						layer.light_merged(SimPlane.to_3d(lane.center, 0.6), glow, 2.2, 7.0, 3.0)
			&"skid":
				if after < 0.0:
					var p := SimPlane.to_3d(s["to"])
					_sparks(layer, p, age, sd, 8, Color(1.0, 0.75, 0.4))
					layer.light_merged(p + Vector3.UP * 0.4, glow, 1.6, 4.0, 2.0)
					if hold != null:  # R38: a small puff of dust every so often along the skid
						hold.once(
							_key(s, int(age / 14.0), 7),
							&"bx_smoke_dust",
							p + Vector3.UP * 0.2,
							0.6,
							{&"primary": BossStrikeShapes.DUST},
							DUST_LIFE_S
						)
	if hold != null:
		hold.end()


## The Mythic lanes' flames as the pack's fire, a row about FLAME_GAP_M apart along the lane. False when the family had
## no room for the first (the caller draws its old flames for this lane).
static func _pack_flames(hold: PackHold, s: Dictionary, lane: Obb, lk: int) -> bool:
	var n := clampi(int(lane.half.x * 2.0 / FLAME_GAP_M), 2, FLAMES_PER_LANE)
	for j in n:
		var t := (float(j) + 0.5) / n * 2.0 - 1.0
		var p := SimPlane.to_3d(lane.center + lane.axis_u * lane.half.x * t)
		var node := hold.hold(
			_key(s, lk * 16 + j, 8),
			&"bx_fire_lane_a" if j % 2 == 0 else &"bx_fire_lane_b",
			p,
			FLAME_SCALE
		)
		if node == null:
			return j > 0
	return true


## The pack's hold for `fx`'s PackFx (made again when the layer's changes); null without the pack or with
## PACK_STRIKES off.
static func _pack_hold(fx: VfxLayer) -> PackHold:
	if not PACK_STRIKES or fx == null or fx.pack_fx == null:
		return null
	var h: PackHold = fx.get_meta(&"vx5_hold") if fx.has_meta(&"vx5_hold") else null  # one hold a layer
	if h == null or h.pack != fx.pack_fx:
		h = PackHold.new(fx.pack_fx)
		fx.set_meta(&"vx5_hold", h)
	return h


## A strike's effect key: its tick and seed, the disc or lane, and the role.
static func _key(s: Dictionary, k: int, role: int) -> Vector3i:
	return Vector3i(int(s["tick"]) * 16 + role, int(s["seed"]), k)


## The strike glow as a burst's colours: the glow warm and its pale form.
static func _warm(c: Color) -> Dictionary:
	return {&"primary": c.lightened(0.55), &"secondary": c}


static func _tint(c: Color) -> Dictionary:
	return {&"primary": c.lightened(0.4), &"secondary": c, &"tertiary": c.darkened(0.2)}


static func _dust_ring(
	layer: VfxCore, c: Vector3, r: float, age: float, sd: int, n: int, smoke := true
) -> void:
	var t := clampf(age / 24.0, 0.0, 1.0)
	if t >= 1.0:
		return
	for k in n:
		if VfxCore.h(sd + 11, k) > layer.density:
			continue
		var a := TAU * (k + VfxCore.h(sd + 12, k)) / n
		var q := (
			c + Vector3(cos(a), 0.0, sin(a)) * r * (0.6 + 0.8 * t) + Vector3.UP * (0.3 + 0.7 * t)
		)
		if smoke:
			layer.sprite(
				&"smoke",
				q,
				0.8 + 1.2 * t,
				Color(BossStrikeShapes.DUST, 0.75 * sin(PI * t)),
				(sd + k) % 4,
				TAU * VfxCore.h(sd + 13, k)
			)
		if t < 0.6 and k % 2 == 0:
			var p := (
				c
				+ Vector3(cos(a), 0.0, sin(a)) * r * 0.5 * t / 0.6
				+ Vector3.UP * (0.2 + 1.8 * t - 2.4 * t * t)
			)
			layer.sprite(
				&"debris", p, 0.4, Color(0.85, 0.8, 0.76, 1.0 - t / 0.6), (sd + k) % 4, age * 0.2
			)


## v0.8.0 TX2: the cracks a crater or a javelin leaves (the owner's fx_ground_cracks; the code's scorch without it).
static func crack_mark() -> StringName:
	return &"cracks" if VfxCore.has_tex("fx_ground_cracks") else &"scorch"


## v0.8.0 TX2: the owner's rock burst (fx_rock_burst, seen from the side) blasting up out of a crater `r` round: it
## grows over its first ticks and fades by 26. Thinned with the layer's density like the rest.
static func _rock_burst(layer: VfxCore, c: Vector3, r: float, age: float, sd: int) -> void:
	var t := clampf(age / 26.0, 0.0, 1.0)
	if t >= 1.0 or not VfxCore.has_tex("fx_rock_burst") or VfxCore.h(sd + 30, 0) > layer.density:
		return
	var grow := 1.0 - (1.0 - minf(age / 6.0, 1.0)) * (1.0 - minf(age / 6.0, 1.0))
	var s := clampf(r * 1.5, 1.2, 5.0) * (0.55 + 0.45 * grow)
	layer.sprite(
		&"rockburst",
		c + Vector3.UP * s * 0.42,
		s,
		Color(1.0, 1.0, 1.0, (1.0 - t * t) * minf(age / 2.0 + 0.3, 1.0)),
		posmod(sd, 4),
		0.0
	)


static func _puff_ring(
	layer: VfxCore,
	c: Vector3,
	r: float,
	age: float,
	sd: int,
	n: int,
	col: Color,
	rise: float,
	pool: StringName = &"smoke"
) -> void:
	var t := clampf(age / 40.0, 0.0, 1.0)
	if t >= 1.0:
		return
	for k in n:
		if VfxCore.h(sd + 14, k) > layer.density:
			continue
		var a := TAU * (k + VfxCore.h(sd + 15, k)) / n
		var q := c + Vector3(cos(a), 0.0, sin(a)) * r + Vector3.UP * (0.4 + 1.6 * t * rise)
		layer.sprite(
			pool,
			q,
			(1.0 + 1.0 * t) * (1.3 if pool == &"steam" else 1.0),
			Color(col, 0.7 * (1.0 - t)),
			(sd + k) % 4,
			TAU * VfxCore.h(sd + 16, k)
		)


static func _sparks(layer: VfxCore, c: Vector3, age: float, sd: int, n: int, col: Color) -> void:
	for k in n:
		if VfxCore.h(sd + 17, k) > layer.density:
			continue
		var period := 10.0 + 6.0 * VfxCore.h(sd + 18, k)
		var t := fposmod(age + VfxCore.h(sd + 19, k) * period, period) / period
		var a := TAU * VfxCore.h(sd + 20, k)
		var q := c + Vector3(cos(a) * 1.2 * t, 0.2 + 1.4 * t - 1.6 * t * t, sin(a) * 1.2 * t)
		layer.sprite(
			&"spark", q, 0.1, Color(col.r * 2.2, col.g * 1.8, col.b * 1.4, 1.0 - t), k % 4, 0.0
		)


static func _lane_puffs(layer: VfxCore, o: Obb, age: float, sd: int, n: int, col: Color) -> void:
	for k in n:
		if VfxCore.h(sd + 21, k) > layer.density:
			continue
		var s := (float(k) + 0.5) / n * 2.0 - 1.0
		var p := SimPlane.to_3d(o.center + o.axis_u * o.half.x * s)
		var t := fposmod(age + VfxCore.h(sd + 22, k) * 24.0, 24.0) / 24.0
		layer.sprite(
			&"smoke",
			p + Vector3.UP * (0.3 + 1.0 * t),
			0.7 + 0.8 * t,
			Color(col, 0.6 * sin(PI * t)),
			(sd + k) % 4,
			TAU * VfxCore.h(sd + 23, k)
		)


static func _lane_embers(layer: VfxCore, o: Obb, age: float, sd: int) -> void:
	var n := maxi(2, int(o.half.x / 1.5))
	for k in n:
		if VfxCore.h(sd + 24, k) > layer.density:
			continue
		var s := VfxCore.h(sd + 25, k) * 2.0 - 1.0
		var p := SimPlane.to_3d(
			o.center + o.axis_u * o.half.x * s + o.axis_v * o.half.y * (VfxCore.h(sd + 26, k) - 0.5)
		)
		var t := fposmod(age + VfxCore.h(sd + 27, k) * 30.0, 30.0) / 30.0
		layer.sprite(
			&"spark",
			p + Vector3.UP * (0.1 + 1.2 * t),
			0.08,
			Color(2.2, 1.1, 0.35, 1.0 - t),
			k % 4,
			0.0
		)


static func _flames(layer: VfxCore, o: Obb, age: float, sd: int) -> void:
	var n := maxi(2, int(o.half.x / 1.6))
	for k in n:
		if VfxCore.h(sd + 28, k) > layer.density:
			continue
		var s := (float(k) + 0.5) / n * 2.0 - 1.0
		var p := SimPlane.to_3d(o.center + o.axis_u * o.half.x * s)
		var flick := 0.8 + 0.4 * VfxCore.h(sd + 29, int(age / 3.0) + k)
		layer.sprite(
			&"flame",
			p + Vector3.UP * 0.55 * flick,
			1.1 * flick,
			Color(1.6, 0.9, 0.45, 0.9),
			(sd + k + int(age / 4.0)) % 4,
			0.0
		)
