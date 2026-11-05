class_name StarfallView
extends Node3D
## v0.10.5 W3-P10e (owner W7: "don't get crazy with visuals for explosions"; G1 V1, V2): the Starfall Constellation.
## A star (STAR event) is a small bright moon-blue point with a short thin tail, falling fast onto its target for
## STAR_TICKS (0.2 s). A meteor (METEOR_LAUNCH, then METEOR_LAND METEOR_DELAY_TICKS later) is a glowing warm rock
## (a 0.4 m ball) with a short tapered tail, falling diagonally from high up onto its landing point and, at
## the impact, the existing small blast ring (BombView.RING_SHADER, the Chain Blast's look) at the meteor's radius.
## No shake, no flash, no lingering particles; at most MAX_DRAWN of each are drawn a frame, the rest deal their damage
## undrawn. Presentation only (EI-07): it reads the sim's events, never writes; every life is sim ticks.

const MAX_DRAWN := 8
const STAR_TICKS := 12
const BLAST_TICKS := 20.0
const FALL := Vector3(5.0, 10.0, 0.0)  # where a fall starts, from its landing point: high up and to one side
const STAR_BALL := 0.14
const STAR_TAIL_M := 1.4
const STAR_TAIL_R := 0.05
const METEOR_BALL := 0.4  # a sphere 0.4 m across
const METEOR_TAIL_M := 2.4
const METEOR_TAIL_R := 0.2
const STAR_COLOR := Color("#8FB8E8")
const METEOR_COLOR := Color("#FFA24A")
const METEOR_CORE := Color("#FFE2B8")
const METEOR_EDGE := Color("#E0602A")

## What the last sync showed (tests read them).
var stars := 0
var meteors := 0
var blasts := 0

var _star_nodes: Array[MeshInstance3D] = []
var _star_tails: Array[MeshInstance3D] = []
var _meteor_nodes: Array[MeshInstance3D] = []
var _meteor_tails: Array[MeshInstance3D] = []
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
	var star_mat := _line_material(STAR_COLOR)
	var rock_mat := _line_material(METEOR_CORE)
	var tail_mat := _line_material(METEOR_COLOR)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	var star_tail := _cone(STAR_TAIL_R)
	var meteor_tail := _cone(METEOR_TAIL_R)
	for k in MAX_DRAWN:
		_star_nodes.append(_line(ball, star_mat))
		_star_tails.append(_line(star_tail, star_mat))
		_meteor_nodes.append(_line(ball, rock_mat))
		_meteor_tails.append(_line(meteor_tail, tail_mat))
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


## A cone one unit tall, its base at the bottom (the ball's side) and its tip at the top.
func _cone(radius: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = 1.0
	c.radial_segments = 8
	c.rings = 1
	return c


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
		_place_fall(
			_star_nodes[k], _star_tails[k], _stars, k, tick, STAR_TICKS, STAR_BALL, STAR_TAIL_M
		)
		_place_fall(
			_meteor_nodes[k], _meteor_tails[k], _meteors, k, tick, 0, METEOR_BALL, METEOR_TAIL_M
		)
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


## Ball and tail `k` of `rows`: the ball falls along FALL from high up to its landing point over its life; its tail
## trails behind it up the same line, thick at the ball and tapering to nothing.
func _place_fall(
	ball: MeshInstance3D,
	tail: MeshInstance3D,
	rows: Array,
	k: int,
	tick: int,
	life: int,
	size: float,
	tail_m: float
) -> void:
	ball.visible = k < rows.size()
	tail.visible = ball.visible
	if k >= rows.size():
		return
	var row: Array = rows[k]
	var span := life if life > 0 else int(row[2])
	var u := clampf(float(tick - int(row[1])) / float(maxi(span, 1)), 0.0, 1.0)
	var at := SimPlane.to_3d(row[0], 0.0) + FALL * (1.0 - u)
	at.y = maxf(at.y, size * 0.5)
	ball.transform = Transform3D(Basis.from_scale(Vector3.ONE * size), at)
	var dir := FALL.normalized()
	var basis := Basis(Quaternion(Vector3.UP, dir)).scaled_local(Vector3(1.0, tail_m, 1.0))
	tail.transform = Transform3D(basis, at + dir * tail_m * 0.5)
