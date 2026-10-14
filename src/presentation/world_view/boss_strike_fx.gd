class_name BossStrikeFx
extends RefCounted
## v0.8.0 AV part 2: BossStrikeViews' share of the effects layer (VfxCore): each strike's sprites (debris, dust, smoke,
## sparks, flames from the owner's atlases), its light (merged, into the 10-light pool), its floor marks (the decal
## cap) and its explosions and acid splats (VfxLayer.burst: the frame's burst budget). Thinned with the layer's
## density. Presentation only.


static func draw(layer: VfxCore, strikes: Array[Dictionary], now: float) -> void:
	var fx := layer as VfxLayer
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
					_dust_ring(layer, c, d[1], age, sd + k, 8)
					layer.light_merged(
						c + Vector3.UP * 0.8, glow, 3.0 * (1.0 - u) * (1.0 - u), 6.0, 2.0
					)
					layer.mark(
						BossStrikeViews.MARK_BASE + sd * 8 + k,
						&"scorch",
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
						&"scorch",
						c,
						float(d[1]) * 0.8,
						BossStrikeViews.CRACK_MARK
					)
			&"light_burst", &"light_ring":
				var c := SimPlane.to_3d(s["discs"][0][0] if s.has("discs") else s["ring"][0])
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
				_puff_ring(
					layer,
					c,
					r,
					age,
					sd,
					12,
					BossStrikeShapes.STEAM if steam else BossStrikeShapes.DUST,
					1.0 if steam else 0.5
				)
				layer.light_merged(c + Vector3.UP, glow, 3.0 * (1.0 - u), 8.0, 2.0)
			&"dust_arc", &"steel_arc":
				var g: Array = s["arc"]
				var mid := (float(g[3]) + float(g[4])) * 0.5
				var tip := SimPlane.to_3d(g[0] + Vector2(cos(mid), sin(mid)) * float(g[2]))
				if s["kind"] == &"steel_arc":
					_sparks(layer, tip, age, sd, 10, Color(1.0, 0.8, 0.5))
					layer.light_merged(tip + Vector3.UP * 0.6, glow, 2.0 * (1.0 - u), 5.0, 2.0)
				else:
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
				for lane: Obb in s["lanes"]:
					var on: bool = (after < 0.0 and s["kind"] == &"beam") or age < 10.0
					var far := SimPlane.to_3d(lane.center + lane.axis_u * lane.half.x, 0.7)
					var near := SimPlane.to_3d(lane.center - lane.axis_u * lane.half.x, 0.7)
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
				for lane: Obb in s["lanes"]:
					if s["kind"] == &"fire_lanes" and after < 0.0:
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


static func _dust_ring(layer: VfxCore, c: Vector3, r: float, age: float, sd: int, n: int) -> void:
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


static func _puff_ring(
	layer: VfxCore, c: Vector3, r: float, age: float, sd: int, n: int, col: Color, rise: float
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
			&"smoke",
			q,
			1.0 + 1.0 * t,
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
