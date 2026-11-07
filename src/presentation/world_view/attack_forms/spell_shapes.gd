class_name SpellShapes
extends Node3D
## v0.11.0 O11 (SPELLS.md "Readability"): a pool of plain unshaded strips and orbs the spells' looks are drawn from,
## each frame anew (begin, strip/orb, finish). Each strip and orb has its own material, so it takes any colour and
## fade. Past the pool a shape is skipped (never an error). Presentation only (EI-07).

const STRIPS := 384
const ORBS := 64

var _strips: Array[MeshInstance3D] = []
var _orbs: Array[MeshInstance3D] = []
var _n_strip := 0
var _n_orb := 0


func _init() -> void:
	name = "SpellShapes"
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	for k in STRIPS:
		_strips.append(_node(box))
	for k in ORBS:
		_orbs.append(_node(ball))


func _node(mesh: Mesh) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


func begin() -> void:
	_n_strip = 0
	_n_orb = 0


## A flat strip from `a` to `b`, `w` wide, in `c` at `alpha`.
func strip(a: Vector3, b: Vector3, w: float, c: Color, alpha: float) -> void:
	var d := b - a
	if d.length() < 0.03 or _n_strip >= STRIPS or alpha <= 0.0:
		return
	var n := _strips[_n_strip]
	_n_strip += 1
	n.visible = true
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var basis := Basis.looking_at(d.normalized(), up)
	n.transform = Transform3D(basis.scaled_local(Vector3(w, w * 0.4, d.length())), (a + b) * 0.5)
	(n.material_override as StandardMaterial3D).albedo_color = Color(c, clampf(alpha, 0.0, 1.0))


## An orb at `at`, `r` in radius, in `c` at `alpha`.
func orb(at: Vector3, r: float, c: Color, alpha: float) -> void:
	if _n_orb >= ORBS or alpha <= 0.0 or r <= 0.0:
		return
	var n := _orbs[_n_orb]
	_n_orb += 1
	n.visible = true
	n.transform = Transform3D(Basis().scaled(Vector3.ONE * r * 2.0), at)
	(n.material_override as StandardMaterial3D).albedo_color = Color(c, clampf(alpha, 0.0, 1.0))


## A polygon outline of `sides` strips around `o` at radius `r` (turned `turn` radians).
func polygon(
	o: Vector3, r: float, sides: int, w: float, c: Color, alpha: float, turn := 0.0
) -> void:
	for k in sides:
		var a := turn + TAU * k / sides
		var b := turn + TAU * (k + 1) / sides
		strip(o + Vector3(cos(a), 0, sin(a)) * r, o + Vector3(cos(b), 0, sin(b)) * r, w, c, alpha)


## `n` spokes out from `o` to `r` (rising `lift` at the tip).
func spokes(
	o: Vector3, r: float, n: int, w: float, c: Color, alpha: float, lift := 0.0, turn := 0.0
) -> void:
	for k in n:
		var a := turn + TAU * k / n
		strip(o, o + Vector3(cos(a) * r, lift, sin(a) * r), w, c, alpha)


func finish() -> void:
	for k in range(_n_strip, STRIPS):
		if _strips[k].visible:
			_strips[k].visible = false
	for k in range(_n_orb, ORBS):
		if _orbs[k].visible:
			_orbs[k].visible = false


func strips_used() -> int:
	return _n_strip


func orbs_used() -> int:
	return _n_orb
