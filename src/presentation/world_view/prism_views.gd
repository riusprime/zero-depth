class_name PrismViews
extends Node3D
## v0.8.0 FB2 (owner O17: "rays that go in a cross and turn with her in the middle around the room … quick, fast
## attacks"; FINAL_BOSS.md F5): the Prism's Cross and her shards' fire, read from the sim (WorldReader.boss_cross,
## boss_shards; EI-07), never decided here. Built like the Hive Lens's Gaze (BossSignatureViews: its beam shaders and
## cylinder placement), one set per arm:
## - the spin-up (the windup): a thin aim line down each arm, brightening, and her core flaring;
## - the spin: each beam a hot core and a wider glow (two cylinders, the scrolling beam shader) from her edge to where
##   the wall stops it, a burning strip on the floor under it, a flare and a light where it strikes the wall;
## - the window (beams out, shield down): a gold ring pulsing round her feet (strike now);
## - a bolt's aim line: a thin red line in the air from its shard down its locked way, brightening and tightening over
##   its 0.4 s, then gone as the bolt flies (FireballViews draws the bolt);
## - a shard firing (an orb volley, a bolt's aim): a flash and a small light at the sim shard.
## Ticks are the sim's (the views pause with it); reduced motion: no flicker or pulse.

const BEAM := Color(1.0, 0.16, 0.3)
const BEAM_CORE := Color(1.0, 0.88, 0.92)
const BOLT := Color(1.0, 0.25, 0.35)
const OPEN := Color(1.0, 0.82, 0.36)
## Heights (m): the beams leave her at BEAM_Y and reach the wall at END_Y; the shards fly at SHARD_Y.
const BEAM_Y := 1.3
const END_Y := 0.8
const SHARD_Y := 1.9
const AIM_RADIUS := 0.06
const BOLT_RADIUS := 0.035
const MAX_ARMS := 8

var _cross := {}
var _shards := PackedVector2Array()
var _at := Vector2.ZERO
var _radius := 1.5
var _tick := 0
var _arms: Array[Dictionary] = []
var _bolt_line := MeshInstance3D.new()
var _shard_flash := MeshInstance3D.new()
var _shard_light := OmniLight3D.new()
var _core_light := OmniLight3D.new()
var _ring := MeshInstance3D.new()
var _ring_mat := StandardMaterial3D.new()
var _ends: Array = []


func _init() -> void:
	name = "PrismViews"
	var beam_sh := Shader.new()
	beam_sh.code = BossSignatureShaders.BEAM
	var floor_sh := Shader.new()
	floor_sh.code = BossSignatureShaders.FLOOR
	for k in MAX_ARMS:
		var arm := {
			"core": _cylinder(beam_sh, BEAM, 1.0),
			"glow": _cylinder(beam_sh, BEAM, 0.35),
			"aim": _cylinder(beam_sh, BEAM, 0.6),
			"floor": MeshInstance3D.new(),
			"impact": _flare(BEAM_CORE),
			"light": OmniLight3D.new(),
		}
		var strip := QuadMesh.new()
		strip.size = Vector2.ONE
		strip.orientation = PlaneMesh.FACE_Y
		var fl: MeshInstance3D = arm["floor"]
		fl.mesh = strip
		var fm := ShaderMaterial.new()
		fm.shader = floor_sh
		fm.set_shader_parameter("color", BEAM)
		fl.material_override = fm
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fl.visible = false
		add_child(fl)
		var l: OmniLight3D = arm["light"]
		l.light_color = BEAM
		l.omni_range = 4.5
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_arms.append(arm)
	_bolt_line = _cylinder(beam_sh, BOLT, 0.8)
	_bolt_line.name = "BoltAim"
	_shard_flash = _flare(BEAM_CORE)
	_shard_flash.name = "ShardFlash"
	for l: OmniLight3D in [_shard_light, _core_light]:
		l.light_color = BEAM
		l.omni_range = 4.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 40
	_ring.mesh = torus
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(OPEN, 0.0)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.name = "WindowRing"
	_ring.visible = false
	add_child(_ring)


func _cylinder(sh: Shader, c: Color, strength: float) -> MeshInstance3D:
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
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("core", BEAM_CORE)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.extra_cull_margin = 64.0
	add_child(mi)
	return mi


func _flare(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 5
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


func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	_cross = {}
	_shards = PackedVector2Array()
	var i := reader.boss_index()
	if i >= 0 and reader.final_fight():
		_cross = reader.boss_cross(i)
		_shards = reader.boss_shards(i)
		_at = reader.actor_pos(i)
		_radius = reader.actor_radius(i)
	_draw(float(_tick))


func _process(_delta: float) -> void:
	if not _cross.is_empty():
		_draw(float(_tick))


## True while any arm is drawn (an aim line or a beam; tests and the tour).
func cross_drawn() -> bool:
	for arm in _arms:
		if (arm["core"] as Node3D).visible or (arm["aim"] as Node3D).visible:
			return true
	return false


## Arms drawn as beams now (tests).
func beam_count() -> int:
	var n := 0
	for arm in _arms:
		n += 1 if (arm["core"] as Node3D).visible else 0
	return n


## Arms drawn as aim lines now (the spin-up; tests).
func aim_count() -> int:
	var n := 0
	for arm in _arms:
		n += 1 if (arm["aim"] as Node3D).visible else 0
	return n


## Each drawn arm's ends in 3D [[from, to] …] (tests: on the sim's beams).
func arm_ends() -> Array:
	return _ends


## The bolt's aim line is drawn (tests).
func bolt_line_drawn() -> bool:
	return _bolt_line.visible


## The window's ring shows (tests).
func window_drawn() -> bool:
	return _ring.visible


## A shard's firing flash shows (tests).
func shard_flash_drawn() -> bool:
	return _shard_flash.visible


func _draw(now: float) -> void:
	_ends = []
	var still := ViewPrefs.reduced_motion
	for arm in _arms:
		for key in ["core", "glow", "aim", "floor", "impact", "light"]:
			(arm[key] as Node3D).visible = false
	for n: Node3D in [_bolt_line, _shard_flash, _shard_light, _core_light, _ring]:
		n.visible = false
	if _cross.is_empty():
		return
	var c := _cross
	var p := float(c["progress"]) / 1000.0
	var flicker := 1.0 if still else 0.85 + 0.15 * sin(now * 0.9)
	var centre := SimPlane.to_3d(_at, BEAM_Y)
	if c["window"]:
		_ring.visible = true
		var pulse := 1.0 if still else 0.75 + 0.25 * sin(now * 0.35)
		_ring.transform = Transform3D(
			Basis.from_scale(Vector3.ONE * (_radius + 0.5)), SimPlane.to_3d(_at, 0.05)
		)
		_ring_mat.albedo_color = Color(OPEN, 0.85 * pulse * (1.0 - 0.6 * p))
	else:
		_core_light.visible = true
		_core_light.position = centre
		_core_light.light_energy = (0.5 + 2.5 * p if c["winding"] else 3.0) * flicker
		_draw_arms(c, p, now, still, flicker)
	_draw_bolt(c)
	_draw_shard(c, flicker)


func _draw_arms(c: Dictionary, p: float, now: float, still: bool, flicker: float) -> void:
	var hw := float(c["half_width"])
	var arms: Array = c["arms"]
	for k in mini(arms.size(), MAX_ARMS):
		var row: Array = arms[k]
		var arm: Dictionary = _arms[k]
		var from2: Vector2 = row[0]
		var to2: Vector2 = row[1]
		var a := SimPlane.to_3d(from2, BEAM_Y)
		var b := SimPlane.to_3d(to2, END_Y)
		_ends.append([a, b])
		if c["winding"]:
			var aim: MeshInstance3D = arm["aim"]
			aim.visible = true
			_place(aim, a, b, AIM_RADIUS * (0.6 + 0.6 * p))
			(aim.material_override as ShaderMaterial).set_shader_parameter(
				"strength", 0.5 + 1.5 * p
			)
			continue
		var core: MeshInstance3D = arm["core"]
		var glow: MeshInstance3D = arm["glow"]
		core.visible = true
		glow.visible = true
		_place(core, a, b, hw * 0.45)
		_place(glow, a, b, hw * (1.05 + (0.0 if still else 0.08 * sin(now * 1.7 + k))))
		var fl: MeshInstance3D = arm["floor"]
		fl.visible = true
		var len := Kin.length(to2 - from2)
		var yaw := atan2(-(b - a).z, (b - a).x)
		fl.transform = Transform3D(
			Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(len, 1, hw * 2.0)),
			SimPlane.to_3d((from2 + to2) * 0.5, 0.03)
		)
		if row[2]:
			var imp: MeshInstance3D = arm["impact"]
			var l: OmniLight3D = arm["light"]
			imp.visible = true
			l.visible = true
			imp.position = b
			imp.scale = Vector3.ONE * (0.7 + (0.0 if still else 0.2 * sin(now * 2.3 + k)))
			l.position = b + Vector3(0, 0.4, 0)
			l.light_energy = 3.0 * flicker


func _draw_bolt(c: Dictionary) -> void:
	var bolt: Dictionary = c.get("bolt", {})
	if bolt.is_empty():
		return
	var p := float(bolt["progress"]) / 1000.0
	var a := SimPlane.to_3d(bolt["from"], SHARD_Y)
	var b := SimPlane.to_3d(bolt["to"], SHARD_Y)
	_bolt_line.visible = true
	_place(_bolt_line, a, b, BOLT_RADIUS * (1.6 - 0.8 * p))
	(_bolt_line.material_override as ShaderMaterial).set_shader_parameter("strength", 0.4 + 1.8 * p)


func _draw_shard(c: Dictionary, flicker: float) -> void:
	var k := int(c.get("orb_shard", -1))
	var bolt: Dictionary = c.get("bolt", {})
	if k < 0 and not bolt.is_empty():
		k = int(bolt["shard"])
	if k < 0 or k >= _shards.size():
		return
	var at := SimPlane.to_3d(_shards[k], SHARD_Y)
	_shard_flash.visible = true
	_shard_flash.position = at
	_shard_flash.scale = Vector3.ONE * 0.6
	_shard_light.visible = true
	_shard_light.position = at
	_shard_light.light_energy = 2.0 * flicker


## Puts a unit cylinder (its axis +Y, height 1, radius 1) from a to b with radius r (as the Gaze's).
static func _place(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	var y := b - a
	var len := maxf(y.length(), 0.001)
	var yn := y / len
	var side := Vector3.UP if absf(yn.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := yn.cross(side).normalized()
	var z := x.cross(yn).normalized()
	mi.transform = Transform3D(Basis(x * r, yn * len, z * r), (a + b) * 0.5)
