class_name StarboundFx
extends Node3D
## The Starbound Detonation burst and Arc
## Jump line, drawn plainly so they read. A burst is one moon-blue ground ring that grows from about 0.3 m to the burst
## radius over BURST_TICKS (the Chain Blast's ring shader, BombView.RING_SHADER) with its soft disc; a jump is a
## moon-blue line, thick and unshaded with a bright core, for JUMP_TICKS between the two enemies' chests. No shake, no
## flash, no particles; at most BURSTS / JUMPS live at once. Presentation only (EI-07): lives are sim ticks.

const BURSTS := 8
const JUMPS := 16
const BURST_TICKS := 15.0
const JUMP_TICKS := 9.0
const JUMP_W := 0.08
const CORE_W := 0.03
const CHEST_M := 0.9
const BLUE := Color("#8FB8E8")
const CORE := Color("#C4DCFA")

## Live: bursts [pos, start tick, radius m]; jumps [from, to, start tick].
var _bursts: Array = []
var _jumps: Array = []
var _rings: Array[MeshInstance3D] = []
var _ring_mat: Array[ShaderMaterial] = []
var _lines: Array[MeshInstance3D] = []
var _cores: Array[MeshInstance3D] = []


func _init() -> void:
	name = "StarboundFx"
	var flat := PlaneMesh.new()
	flat.size = Vector2.ONE * 2.0
	var shader := Shader.new()
	shader.code = BombView.RING_SHADER
	for k in BURSTS:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"has_tex", 0.0)
		m.set_shader_parameter(&"core", BLUE * 0.6)
		m.set_shader_parameter(&"edge", BLUE * 0.45)
		var r := _node(flat, m)
		_rings.append(r)
		_ring_mat.append(m)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var blue := _flat_material(BLUE)
	var core := _flat_material(CORE)
	for k in JUMPS:
		_lines.append(_node(box, blue))
		_cores.append(_node(box, core))


func _node(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


func _flat_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func add_burst(at: Vector2, tick: int, radius_m: float) -> void:
	_bursts.append([at, tick, maxf(radius_m, 0.5)])
	while _bursts.size() > BURSTS:
		_bursts.pop_front()


func add_jump(from: Vector2, to: Vector2, tick: int) -> void:
	_jumps.append([from, to, tick])
	while _jumps.size() > JUMPS:
		_jumps.pop_front()


## Every live ring and line where `tick` puts it; the finished ones are dropped.
func sync(tick: int) -> void:
	_bursts = _bursts.filter(func(b: Array) -> bool: return float(tick - int(b[1])) < BURST_TICKS)
	_jumps = _jumps.filter(func(j: Array) -> bool: return float(tick - int(j[2])) < JUMP_TICKS)
	for k in BURSTS:
		_rings[k].visible = k < _bursts.size()
		if k >= _bursts.size():
			continue
		var b: Array = _bursts[k]
		var r: float = b[2] * 1.03  # the plane is 2 m across (half 1) and the shader ring reaches 0.97 of its half
		_rings[k].transform = Transform3D(
			Basis.from_scale(Vector3(r, 1.0, r)), SimPlane.to_3d(b[0], 0.06)
		)
		_ring_mat[k].set_shader_parameter(&"u", clampf((tick - int(b[1])) / BURST_TICKS, 0.0, 1.0))
	for k in JUMPS:
		_lines[k].visible = k < _jumps.size()
		_cores[k].visible = k < _jumps.size()
		if k >= _jumps.size():
			continue
		var j: Array = _jumps[k]
		var a := SimPlane.to_3d(j[0], CHEST_M)
		var c := SimPlane.to_3d(j[1], CHEST_M)
		var d := c - a
		if d.length() < 0.05:
			_lines[k].visible = false
			_cores[k].visible = false
			continue
		var basis := Basis.looking_at(d.normalized(), Vector3.UP)
		var mid := (a + c) * 0.5
		_lines[k].transform = Transform3D(
			basis.scaled_local(Vector3(JUMP_W, JUMP_W, d.length())), mid
		)
		_cores[k].transform = Transform3D(
			basis.scaled_local(Vector3(CORE_W, CORE_W, d.length() + 0.02)), mid
		)
