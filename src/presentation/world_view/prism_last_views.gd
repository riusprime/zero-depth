class_name PrismLastViews
extends Node3D
## v0.10.5 O3 (owner L6, 2026-11-01: "Needs something cooler while he's down and not on the dodging pattern"; "Boring
## pattern"; O3_PRISM.md): the Prism's last phase, read from the sim (WorldReader.boss_lances, boss_kneel; EI-07),
## never decided here. PrismViews owns it (one per fight) and draws it inside its own frame (its BossPackHold).
## - The Facet Lances: a violet facet glowing at each lance's rim spot (brightening through the gather; gone once its
##   lance has struck); a lance tracking: a thin chevron aim line from its facet across the room; locked: a bright
##   laser line and the lane's width burning faintly on the floor (where it will strike), tightening as it nears;
##   striking: the beam itself (the pack's beam, else two cylinders) and an impact flare at its far end (once).
## - The Shattered Kneel: her core a white-gold flare low at her centre that swells as the crack fills; the crack's
##   progress as CRACK_MARKS shards in a ring at her feet, lit one by one; a gold ring on the floor at the core's reach
##   (hit from inside it); a light pillar while she is down (the pack's); her core's burst: the pack's shatter and
##   shock pulse (once) and a flash that fades over BURST_FLASH_TICKS.
## Ticks are the sim's; reduced motion: no flicker or pulse.

const LANCE := Color(0.72, 0.4, 1.0)
const LANCE_CORE := Color(0.96, 0.9, 1.0)
const CORE := Color(1.0, 0.86, 0.5)
const CORE_HOT := Color(1.0, 0.97, 0.88)
const MAX_LANCES := 8
const CRACK_MARKS := 16
const BURST_FLASH_TICKS := 40
const BEAM_Y := 1.2
const FACET_Y := 1.6
const AIM_RADIUS := 0.05

var _lances := {}
var _kneel := {}
var _at := Vector2.ZERO
var _radius := 1.5
var _tick := 0
var _rows: Array[Dictionary] = []
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _core_light := OmniLight3D.new()
var _reach := MeshInstance3D.new()
var _reach_mat := StandardMaterial3D.new()
var _marks: Array[MeshInstance3D] = []
var _mark_on := StandardMaterial3D.new()
var _mark_off := StandardMaterial3D.new()
var _strikes := 0
var _lit := 0


func _init() -> void:
	name = "PrismLastViews"
	var beam_sh := Shader.new()
	beam_sh.code = BossSignatureShaders.BEAM
	var floor_sh := Shader.new()
	floor_sh.code = BossSignatureShaders.FLOOR
	for k in MAX_LANCES:
		var row := {
			"aim": _cylinder(beam_sh, 0.6),
			"lock": _cylinder(beam_sh, 1.0),
			"core": _cylinder(beam_sh, 1.2),
			"glow": _cylinder(beam_sh, 0.4),
			"floor": MeshInstance3D.new(),
			"facet": _sphere(LANCE),
			"light": OmniLight3D.new(),
		}
		FxTextures.texture_beam(
			_mat_of(row["aim"]), "fx_aim_lines", FxTextures.AIM_CHEVRONS, 7.0, false, 0.4
		)
		FxTextures.texture_beam(
			_mat_of(row["lock"]), "fx_aim_lines", FxTextures.AIM_LASER, 1.0, true
		)
		for key in ["core", "glow"]:
			FxTextures.texture_beam(_mat_of(row[key]), "fx_beam", 0, 5.0, false, 0.5)
		var strip := QuadMesh.new()
		strip.size = Vector2.ONE
		strip.orientation = PlaneMesh.FACE_Y
		var fl: MeshInstance3D = row["floor"]
		fl.mesh = strip
		var fm := ShaderMaterial.new()
		fm.shader = floor_sh
		fm.set_shader_parameter("color", LANCE)
		fl.material_override = fm
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fl.visible = false
		add_child(fl)
		var l: OmniLight3D = row["light"]
		l.light_color = LANCE
		l.omni_range = 3.5
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_rows.append(row)
	_core = _sphere(CORE_HOT)
	_core.name = "PrismCore"
	_core_mat = _core.material_override as StandardMaterial3D
	_core_light.light_color = CORE
	_core_light.omni_range = 6.0
	_core_light.shadow_enabled = false
	_core_light.visible = false
	add_child(_core_light)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.0
	torus.rings = 48
	_reach.mesh = torus
	_reach_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reach_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reach_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_reach_mat.albedo_color = Color(CORE, 0.0)
	_reach.material_override = _reach_mat
	_reach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reach.name = "CoreReach"
	_reach.visible = false
	add_child(_reach)
	for m: StandardMaterial3D in [_mark_on, _mark_off]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mark_on.albedo_color = CORE_HOT
	_mark_off.albedo_color = Color(0.3, 0.2, 0.45)
	var shard := PrismMesh.new()
	shard.size = Vector3(0.16, 0.55, 0.16)
	for k in CRACK_MARKS:
		var mi := MeshInstance3D.new()
		mi.mesh = shard
		mi.material_override = _mark_off
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_marks.append(mi)


func _cylinder(sh: Shader, strength: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 4
	mi.mesh = cyl
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", LANCE)
	m.set_shader_parameter("core", LANCE_CORE)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.extra_cull_margin = 64.0
	add_child(mi)
	return mi


func _sphere(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


static func _mat_of(mi: MeshInstance3D) -> ShaderMaterial:
	return mi.material_override as ShaderMaterial


## PrismViews.sync: this tick's last-phase state.
func set_state(
	lances: Dictionary, kneel: Dictionary, at: Vector2, radius: float, tick: int
) -> void:
	_lances = lances
	_kneel = kneel
	_at = at
	_radius = radius
	_tick = tick


## Anything to draw (PrismViews redraws every frame while so).
func active() -> bool:
	return not _lances.is_empty() or not _kneel.is_empty()


## Lances drawn as lines now (tracking or locked; tests).
func lance_lines() -> int:
	var n := 0
	for row in _rows:
		n += 1 if (row["aim"] as Node3D).visible or (row["lock"] as Node3D).visible else 0
	return n


## Lances drawn striking now (tests).
func lance_strikes() -> int:
	return _strikes


## The lit facets at the rim (tests).
func facets_drawn() -> int:
	var n := 0
	for row in _rows:
		n += 1 if (row["facet"] as Node3D).visible else 0
	return n


## The kneel's core shows (tests).
func core_drawn() -> bool:
	return _core.visible


## The crack's marks lit now (tests).
func crack_lit() -> int:
	return _lit


## PrismViews._draw, between its hold's begin and end (hold may be null: the old looks only).
func draw(now: float, hold: BossPackHold) -> void:
	_strikes = 0
	_lit = 0
	for row in _rows:
		for key in ["aim", "lock", "core", "glow", "floor", "facet", "light"]:
			(row[key] as Node3D).visible = false
	for n: Node3D in [_core, _core_light, _reach]:
		n.visible = false
	for m in _marks:
		m.visible = false
	var still := ViewPrefs.reduced_motion
	if not _lances.is_empty():
		_draw_lances(now, still, hold)
	if not _kneel.is_empty():
		_draw_kneel(now, still, hold)


func _draw_lances(now: float, still: bool, hold: BossPackHold) -> void:
	var c := _lances
	var p := float(c["progress"]) / 1000.0
	var hw := float(c["half_width"])
	var rims: PackedVector2Array = c["rims"]
	var live := {}
	for row: Dictionary in c["lances"]:
		live[int(row["k"])] = row
	var flicker := 1.0 if still else 0.85 + 0.15 * sin(now * 1.1)
	for k in mini(rims.size(), MAX_LANCES):
		var r: Dictionary = _rows[k]
		var lr: Dictionary = live.get(k, {})
		var spent := k < int(c["done"])
		if not spent and (lr.is_empty() or int(lr["phase"]) != WorldReader.LANCE_STRIKING):
			var f: MeshInstance3D = r["facet"]
			f.visible = true
			f.position = SimPlane.to_3d(rims[k], FACET_Y)
			var grow := (0.35 + 0.35 * p) if c["winding"] else 0.75
			f.scale = Vector3(0.7, 1.4, 0.7) * grow * flicker
		if lr.is_empty():
			continue
		var a := SimPlane.to_3d(lr["from"], BEAM_Y)
		var b := SimPlane.to_3d(lr["to"], BEAM_Y * 0.7)
		var q := float(lr["progress"]) / 1000.0
		match int(lr["phase"]):
			WorldReader.LANCE_TRACKING:
				var aim: MeshInstance3D = r["aim"]
				aim.visible = true
				_place(aim, a, b, AIM_RADIUS * (0.6 + 0.4 * q))
				_mat_of(aim).set_shader_parameter("strength", 0.4 + 0.6 * q)
			WorldReader.LANCE_LOCKED:
				var lock: MeshInstance3D = r["lock"]
				lock.visible = true
				_place(lock, a, b, AIM_RADIUS * (1.8 - 0.8 * q))
				_mat_of(lock).set_shader_parameter("strength", 1.0 + 1.5 * q)
				_floor(r, lr, hw, 0.25 + 0.55 * q)
			WorldReader.LANCE_STRIKING:
				_strikes += 1
				_strike(r, k, lr, a, b, hw, now, still, hold)


func _floor(r: Dictionary, lr: Dictionary, hw: float, alpha: float) -> void:
	var fl: MeshInstance3D = r["floor"]
	fl.visible = true
	var from2: Vector2 = lr["from"]
	var to2: Vector2 = lr["to"]
	var len := Kin.length(to2 - from2)
	var a3 := SimPlane.to_3d(from2, 0.0)
	var b3 := SimPlane.to_3d(to2, 0.0)
	var yaw := atan2(-(b3 - a3).z, (b3 - a3).x)
	fl.transform = Transform3D(
		Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(len, 1, hw * 2.0)),
		SimPlane.to_3d((from2 + to2) * 0.5, 0.03)
	)
	(fl.material_override as ShaderMaterial).set_shader_parameter("color", Color(LANCE, alpha))


func _strike(
	r: Dictionary,
	k: int,
	lr: Dictionary,
	a: Vector3,
	b: Vector3,
	hw: float,
	now: float,
	still: bool,
	hold: BossPackHold
) -> void:
	var packed: Node3D = null
	if hold != null:
		packed = hold.hold(["lance", k], BossPackHold.beam_id(LANCE), a, 1.0, {}, false)
	if packed != null:
		BossPackHold.beam_place(packed, a, b, hw)
	else:
		var core: MeshInstance3D = r["core"]
		var glow: MeshInstance3D = r["glow"]
		core.visible = true
		glow.visible = true
		_place(core, a, b, hw * 0.5)
		_place(glow, a, b, hw * (1.1 + (0.0 if still else 0.1 * sin(now * 1.9 + k))))
	_floor(r, lr, hw, 0.9)
	var l: OmniLight3D = r["light"]
	l.visible = true
	l.position = b + Vector3(0, 0.4, 0)
	l.light_energy = 3.5
	if hold != null:
		var key := ["lance_hit", k, roundi(b.x * 10.0), roundi(b.z * 10.0)]
		hold.once(key, &"bx_impact_a", b, 1.0)


func _draw_kneel(now: float, still: bool, hold: BossPackHold) -> void:
	var c := _kneel
	var stage := int(c["stage"])
	var crack := float(c["crack"]) / 1000.0
	var burst := int(c["burst_tick"])
	var since := _tick - burst if burst >= 0 else 1 << 20
	var pulse := 1.0 if still else 0.8 + 0.2 * sin(now * 0.45)
	var centre := SimPlane.to_3d(_at, 0.7)
	if stage == 1 or (burst >= 0 and since < BURST_FLASH_TICKS):
		_core.visible = true
		_core.position = centre
		var flash := (
			1.0 - float(since) / BURST_FLASH_TICKS
			if burst >= 0 and since < BURST_FLASH_TICKS
			else 0.0
		)
		_core.scale = Vector3.ONE * (0.5 + 0.9 * crack + 2.5 * flash) * pulse
		_core_mat.albedo_color = CORE.lerp(CORE_HOT, clampf(crack + flash, 0.0, 1.0))
		_core_light.visible = true
		_core_light.position = centre + Vector3(0, 0.5, 0)
		_core_light.light_energy = (1.5 + 3.5 * crack + 8.0 * flash) * pulse
	if stage == 1 and burst < 0:
		_reach.visible = true
		var rr := float(c["range"])
		_reach.transform = Transform3D(
			Basis.from_scale(Vector3.ONE * rr), SimPlane.to_3d(_at, 0.05)
		)
		_reach_mat.albedo_color = Color(CORE, 0.55 * pulse)
		if hold != null:
			hold.hold("kneel_pillar", &"bx_pillar_light", SimPlane.to_3d(_at, 0.0), 1.2)
	if stage >= 1:
		_lit = int(floor(crack * CRACK_MARKS + 0.0001))
		for k in CRACK_MARKS:
			var m := _marks[k]
			m.visible = true
			var ang := TAU * k / CRACK_MARKS
			var ring := _radius + 0.8
			m.position = SimPlane.to_3d(_at + Vector2(cos(ang), sin(ang)) * ring, 0.25)
			m.rotation = Vector3(0.0, -ang, 0.5)
			m.material_override = _mark_on if k < _lit else _mark_off
	if burst >= 0 and hold != null:
		hold.once(["core_burst", burst], &"bx_shatter", centre, 1.8)
		hold.once(["core_shock", burst], &"bx_pulse_shock", SimPlane.to_3d(_at, 0.05), 1.6)


## Puts a unit cylinder (its axis +Y, height 1, radius 1) from a to b with radius r (as PrismViews').
static func _place(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	var y := b - a
	var len := maxf(y.length(), 0.001)
	var yn := y / len
	var side := Vector3.UP if absf(yn.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := yn.cross(side).normalized()
	var z := x.cross(yn).normalized()
	mi.transform = Transform3D(Basis(x * r, yn * len, z * r), (a + b) * 0.5)
