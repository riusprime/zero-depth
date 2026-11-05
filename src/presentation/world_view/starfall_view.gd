class_name StarfallView
extends Node3D
## v0.10.5 W3-P10e (owner W7: "don't get crazy with visuals for explosions"; G1 V1, V2): the Starfall Constellation.
## A star (STAR event) is a thin moon-blue line falling onto its target for STAR_TICKS (0.2 s). A meteor
## (METEOR_LAUNCH, then METEOR_LAND METEOR_DELAY_TICKS later) is one warm falling streak during its flight and, at
## the impact, the existing small blast ring (BombView.RING_SHADER, the Chain Blast's look) at the meteor's radius.
## No shake, no flash, no lingering particles; at most MAX_DRAWN of each are drawn a frame, the rest deal their damage
## undrawn. Presentation only (EI-07): it reads the sim's events, never writes; every life is sim ticks.

const MAX_DRAWN := 8
const STAR_TICKS := 12
const BLAST_TICKS := 20.0
const FALL_M := 9.0
const STAR_LEN_M := 3.0
const STAR_W := 0.06
const METEOR_LEN_M := 3.5
const METEOR_W := 0.16
const STAR_COLOR := Color("#8FB8E8")
const METEOR_COLOR := Color("#FFA24A")
const METEOR_EDGE := Color("#E0602A")

## What the last sync showed (tests read them).
var stars := 0
var meteors := 0
var blasts := 0

var _star_nodes: Array[MeshInstance3D] = []
var _meteor_nodes: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _ring_mat: Array[ShaderMaterial] = []
## Live: stars [pos, start tick]; meteors [pos, start tick, ticks]; blasts [pos, start tick, radius m].
var _stars: Array = []
var _meteors: Array = []
var _blasts: Array = []
var _last_seq := 0
var _primed := false


func _init() -> void:
	name = "StarfallView"
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var star_mat := _line_material(STAR_COLOR)
	var meteor_mat := _line_material(METEOR_COLOR)
	for k in MAX_DRAWN:
		_star_nodes.append(_line(box, star_mat))
		_meteor_nodes.append(_line(box, meteor_mat))
	var flat := PlaneMesh.new()
	flat.size = Vector2(2.0, 2.0)
	var shader := Shader.new()
	shader.code = BombView.RING_SHADER
	for k in MAX_DRAWN:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"has_tex", 0.0)
		m.set_shader_parameter(&"core", METEOR_COLOR)
		m.set_shader_parameter(&"edge", METEOR_EDGE)
		var r := MeshInstance3D.new()
		r.mesh = flat
		r.material_override = m
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		_rings.append(r)
		_ring_mat.append(m)


func _line_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _line(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


## Each tick: the new events, then every live line and ring where its tick puts it.
func sync(reader: WorldReader) -> void:
	var tick := reader.tick()
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # attaching mid-run draws nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		match e.kind:
			SimEvent.Kind.STAR:
				_stars.append([e.pos, e.tick])
			SimEvent.Kind.METEOR_LAUNCH:
				_meteors.append([e.pos, e.tick, maxi(1, e.amount)])
			SimEvent.Kind.METEOR_LAND:
				_blasts.append([e.pos, e.tick, e.amount / 1000.0])
	_stars = _stars.filter(func(s: Array) -> bool: return tick - int(s[1]) < STAR_TICKS)
	_meteors = _meteors.filter(func(s: Array) -> bool: return tick - int(s[1]) < int(s[2]))
	_blasts = _blasts.filter(func(s: Array) -> bool: return float(tick - int(s[1])) < BLAST_TICKS)
	while _stars.size() > MAX_DRAWN:
		_stars.pop_front()
	while _meteors.size() > MAX_DRAWN:
		_meteors.pop_front()
	while _blasts.size() > MAX_DRAWN:
		_blasts.pop_front()
	stars = _stars.size()
	meteors = _meteors.size()
	blasts = _blasts.size()
	for k in MAX_DRAWN:
		_place_fall(_star_nodes[k], _stars, k, tick, STAR_TICKS, STAR_LEN_M, STAR_W)
		_place_fall(_meteor_nodes[k], _meteors, k, tick, 0, METEOR_LEN_M, METEOR_W)
		var ring := _rings[k]
		ring.visible = k < blasts
		if k >= blasts:
			continue
		var b: Array = _blasts[k]
		var u := clampf(float(tick - int(b[1])) / BLAST_TICKS, 0.0, 1.0)
		var r: float = b[2]
		ring.transform = Transform3D(
			Basis.from_scale(Vector3(r, 1.0, r)), SimPlane.to_3d(b[0], 0.08)
		)
		_ring_mat[k].set_shader_parameter(&"u", u)


## Line `k` of `rows` as a vertical segment whose foot falls from FALL_M to the floor over its life.
func _place_fall(
	node: MeshInstance3D, rows: Array, k: int, tick: int, life: int, length: float, width: float
) -> void:
	node.visible = k < rows.size()
	if k >= rows.size():
		return
	var row: Array = rows[k]
	var span := life if life > 0 else int(row[2])
	var u := clampf(float(tick - int(row[1])) / float(maxi(span, 1)), 0.0, 1.0)
	var foot := FALL_M * (1.0 - u)
	var base := SimPlane.to_3d(row[0], 0.0)
	node.transform = Transform3D(
		Basis.from_scale(Vector3(width, length, width)), base + Vector3.UP * (foot + length * 0.5)
	)
