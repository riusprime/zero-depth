class_name ElementVisuals
extends Node3D
## Arc Field, Frost Nova, Flame Trail and the ability combos' looks in the world (v0.4.0 AB). Reads
## WorldReader.element_fx() and ability_fx() only (EI-07); every size is the sim's own number (nova radius, patch
## radius, bolt ends). Materials are unshaded and transparent, made once; nothing toggles emission at runtime.
## - Arc Field: a jagged pale-blue bolt from the hero to each enemy struck (Superconductor: cyan-white and thicker).
## - Frost Nova: a frost ring and a pale disc out to the nova's radius.
## - Fire patches: flat orange discs (Napalm Drone's deeper red) that shrink as they burn out.
## - Storm Bombs: violet bolts from the blast to each enemy chained. Ember Ward: an orange ring burst. Blink Charge: a
##   violet flash where you left. Wingman: a cyan flash at each drone.

const ARC_COLOR := Color("#9FC8FF")
const SUPER_COLOR := Color("#7CF6FF")
const NOVA_COLOR := Color("#BFF4FF")
const FIRE_COLOR := Color("#FF7A3D")
const NAPALM_COLOR := Color("#E8401A")
const STORM_COLOR := Color("#C8B4FF")
const WARD_COLOR := Color("#FFB03A")
const CHARGE_COLOR := Color("#D88CFF")
const FX_FRAMES := 16
const FIRE_Y := 0.025
const BOLT_SEGMENTS := 4

var _fires: Array[MeshInstance3D] = []
var _fx: Array = []
var _template := SkillVisuals._make_template()
var _fire_mat := _template.duplicate() as StandardMaterial3D
var _napalm_mat := _template.duplicate() as StandardMaterial3D
var _disc_mesh := CylinderMesh.new()
var _last := {}


func _init() -> void:
	name = "ElementVisuals"
	_fire_mat.albedo_color = Color(FIRE_COLOR, 0.55)
	_napalm_mat.albedo_color = Color(NAPALM_COLOR, 0.6)
	_disc_mesh.height = 0.01
	_disc_mesh.top_radius = 1.0
	_disc_mesh.bottom_radius = 1.0
	_disc_mesh.radial_segments = 20
	for k in [&"arc", &"nova", &"storm", &"ward", &"charge", &"wing"]:
		_last[k] = -1


func sync(reader: WorldReader) -> void:
	var fx := reader.element_fx()
	_sync_fires(fx)
	if _edge(&"arc", fx["arc_tick"]):
		var sup: bool = fx["arc_super"]
		for to: Vector2 in fx["arc_to"]:
			_bolt(
				fx["arc_from"], to, SUPER_COLOR if sup else ARC_COLOR, 0.09 if sup else 0.05, &"arc"
			)
	if _edge(&"nova", fx["nova_tick"]):
		_ring(fx["nova_pos"], fx["nova_r"], NOVA_COLOR, &"nova")
		_disc(fx["nova_pos"], fx["nova_r"], NOVA_COLOR, 0.25, &"nova")
	if _edge(&"storm", fx["storm_tick"]):
		for to: Vector2 in fx["storm_to"]:
			_bolt(fx["storm_from"], to, STORM_COLOR, 0.07, &"storm")
	if _edge(&"ward", fx["ward_tick"]):
		_ring(fx["ward_pos"], fx["ward_r"], WARD_COLOR, &"ward")
		_disc(fx["ward_pos"], fx["ward_r"], WARD_COLOR, 0.35, &"ward")
	if _edge(&"charge", fx["charge_tick"]):
		_disc(fx["charge_pos"], 0.9, CHARGE_COLOR, 0.6, &"charge")
	if _edge(&"wing", fx["wing_tick"]):
		for p: Vector2 in reader.ability_fx()["drones"]:
			_disc(p, 0.3, SUPER_COLOR, 0.8, &"wing", AbilityVisuals.DRONE_Y)


# --- Reads (tests) ------------------------------------------------------------------------------------------------
func fire_count() -> int:
	return _fires.filter(func(f: MeshInstance3D) -> bool: return f.visible).size()


func fx_count_of(kind: StringName) -> int:
	return _fx.filter(func(f: Array) -> bool: return f[4] == kind).size()


## The drawn radius of fire patch k.
func fire_radius(k: int) -> float:
	return _fires[k].scale.x


func _edge(kind: StringName, tick: int) -> bool:
	if tick == _last[kind]:
		return false
	_last[kind] = tick
	return tick >= 0


# --- Fire ---------------------------------------------------------------------------------------------------------
func _sync_fires(fx: Dictionary) -> void:
	var pos: PackedVector2Array = fx["fire_pos"]
	var r: PackedFloat32Array = fx["fire_r"]
	var kind: PackedInt32Array = fx["fire_kind"]
	var left: PackedInt32Array = fx["fire_left"]
	while _fires.size() < pos.size():
		var m := MeshInstance3D.new()
		m.mesh = _disc_mesh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_fires.append(m)
	for k in _fires.size():
		var f := _fires[k]
		f.visible = k < pos.size()
		if not f.visible:
			continue
		var napalm := kind[k] == WorldReader.FIRE_NAPALM
		f.material_override = _napalm_mat if napalm else _fire_mat
		var s := r[k] * (0.55 + 0.45 * left[k] / 1000.0)
		f.position = SimPlane.to_3d(pos[k], FIRE_Y + 0.002 * (k % 4))
		f.scale = Vector3(s, 1, s)


# --- Flashes ------------------------------------------------------------------------------------------------------
## A jagged bolt: BOLT_SEGMENTS boxes through points nudged off the straight line (a fixed zigzag, no randomness).
func _bolt(from: Vector2, to: Vector2, c: Color, thick: float, kind: StringName) -> void:
	var d := to - from
	if d.length() < 0.05:
		return
	var side := Vector2(-d.y, d.x).normalized()
	var pts: Array[Vector2] = [from]
	for k in range(1, BOLT_SEGMENTS):
		var off := 0.25 if k % 2 == 1 else -0.25
		pts.append(from + d * (float(k) / BOLT_SEGMENTS) + side * off)
	pts.append(to)
	for k in BOLT_SEGMENTS:
		var a := pts[k]
		var b := pts[k + 1]
		var seg := b - a
		var n := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		n.mesh = box
		n.position = SimPlane.to_3d((a + b) * 0.5, SimPlane.CORE_HEIGHT + 0.3)
		n.rotation = Vector3(0, atan2(seg.y, seg.x), 0)
		n.scale = Vector3(seg.length(), thick, thick)
		_add(n, c, 0.95, kind)


func _ring(at: Vector2, r: float, c: Color, kind: StringName) -> void:
	var n := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.01, r - 0.14)
	torus.outer_radius = r
	torus.rings = 40
	n.mesh = torus
	n.scale = Vector3(1, 0.08, 1)
	n.position = SimPlane.to_3d(at, FIRE_Y + 0.03)
	_add(n, c, 0.9, kind)


func _disc(
	at: Vector2, r: float, c: Color, alpha: float, kind: StringName, y: float = FIRE_Y + 0.02
) -> void:
	var n := MeshInstance3D.new()
	n.mesh = _disc_mesh
	n.scale = Vector3(r, 1, r)
	n.position = SimPlane.to_3d(at, y)
	_add(n, c, alpha, kind)


func _add(n: MeshInstance3D, c: Color, alpha: float, kind: StringName) -> void:
	var m := _template.duplicate() as StandardMaterial3D
	m.albedo_color = Color(c, alpha)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(n)
	_fx.append([n, m, FX_FRAMES, FX_FRAMES, kind, alpha])


func _process(_delta: float) -> void:
	for k in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[k]
		fx[2] -= 1
		(fx[1] as StandardMaterial3D).albedo_color.a = fx[5] * float(fx[2]) / fx[3]
		if fx[2] <= 0:
			(fx[0] as Node).queue_free()
			_fx.remove_at(k)
