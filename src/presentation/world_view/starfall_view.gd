class_name StarfallView
extends Node3D
## v0.10.5 W3-P10e (owner W7: "don't get crazy with visuals for explosions"; G1 V1, V2): the Starfall Constellation.
## A star (STAR event) falls fast onto its target for STAR_TICKS (0.2 s). A meteor (METEOR_LAUNCH, then METEOR_LAND
## METEOR_DELAY_TICKS later) falls diagonally from high up onto its landing point and bursts there at its radius.
## v0.10.5 W3-P10l (owner, 2026-11-05: "for the meteor we could use some of the new vfx premade pack"; "same with
## starfall, let's rely on those that look better"): with the pack (PackFx), the meteor is the pack's cannon fire ball
## (fire_ball_03: a fiery head whose world-space flames trail behind it as it falls) and lands in the pack's fire
## impact (vfx_impact_01: a fire core, a ring and rays, played whole in 0.4 s); the star is a moon-blue magic bolt
## (mprojectile_basic_vfx_03, head and short trail, aimed down its fall) with a small moon-blue hit sparkle
## (vfx_hit_01, 0.2 s) on its target.
## The falling heads are held effects (PackHold: pooled, one per falling row); the bursts are PackFx's pooled one-shots.
## Without the pack (or with its family full) the old look draws: a small ball with a tapered tail, and the small blast
## ring (BombView.RING_SHADER) at the meteor's radius.
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
## W3-P10l: the pack's effects (data/vfx/pack_fx_p10l.tres) and their sizes (starting values).
const METEOR_HEAD := &"p10l_meteor_head"
const METEOR_LAND := &"p10l_meteor_land"
const STAR_HEAD := &"p10l_star_head"
const STAR_HIT := &"p10l_star_hit"
const METEOR_HEAD_SCALE := 0.55
const STAR_HEAD_SCALE := 0.8
const STAR_HIT_SCALE := 0.8
## The landing burst's scale per metre of the meteor's radius (vfx_impact_01's ring is ~1.7 m in radius at 1).
const BURST_PER_M := 0.45
## How long a star's sparkle counts against MAX_DRAWN (ticks; PackFx.SHORT ends it at the same tick).
const SPARK_TICKS := 15

## What the last sync showed (tests read them).
var stars := 0
var meteors := 0
var blasts := 0
## W3-P10l: of those, the falling heads the pack drew this sync, and the pack bursts and sparkles started so far.
var pack_heads := 0
var pack_bursts := 0
var pack_sparks := 0
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		_hold.fx = v

var _star_nodes: Array[MeshInstance3D] = []
var _star_tails: Array[MeshInstance3D] = []
var _meteor_nodes: Array[MeshInstance3D] = []
var _meteor_tails: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _ring_mat: Array[ShaderMaterial] = []
## Live: stars [pos, start tick, seq]; meteors [pos, start tick, ticks, seq]; blasts [pos, start tick, radius m, by
## the pack]; sparks [start tick].
var _stars: Array = []
var _meteors: Array = []
var _blasts: Array = []
var _sparks: Array = []
var _last_seq := 0
var _primed := false
var _hold := PackHold.new()
## The star head's basis: its +x (the pack bolt's forward) down the fall.
var _star_aim := Basis(Quaternion(Vector3.RIGHT, -FALL.normalized()))


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


## Each tick: the new events, then every live head, burst and ring where its tick puts it.
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
				_stars.append([e.pos, e.tick, e.seq])
			SimEvent.Kind.METEOR_LAUNCH:
				_meteors.append([e.pos, e.tick, maxi(1, e.amount), e.seq])
			SimEvent.Kind.METEOR_LAND:
				var r := e.amount / 1000.0
				_blasts.append([e.pos, e.tick, r, _burst(e.pos, r)])
	_sparks = _sparks.filter(func(t: int) -> bool: return tick - t < SPARK_TICKS)
	for s: Array in _stars:
		if tick - int(s[1]) >= STAR_TICKS:
			_sparkle(s[0], tick)  # the star reached its target
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
	pack_heads = 0
	_hold.begin()
	for k in MAX_DRAWN:
		_place_fall(
			_star_nodes[k], _star_tails[k], _stars, k, tick, STAR_TICKS, STAR_BALL, STAR_TAIL_M
		)
		_place_fall(
			_meteor_nodes[k], _meteor_tails[k], _meteors, k, tick, 0, METEOR_BALL, METEOR_TAIL_M
		)
		var ring := _rings[k]
		ring.visible = k < blasts and not bool(_blasts[k][3])
		if not ring.visible:
			continue
		var b: Array = _blasts[k]
		var u := clampf(float(tick - int(b[1])) / BLAST_TICKS, 0.0, 1.0)
		var r: float = b[2]
		ring.transform = Transform3D(
			Basis.from_scale(Vector3(r, 1.0, r)), SimPlane.to_3d(b[0], 0.08)
		)
		_ring_mat[k].set_shader_parameter(&"u", u)
	_hold.end()


## The meteor's landing burst at `at`, `r` metres across its radius: true when the pack plays it (once; it ends
## itself in 0.4 s, PackFx.SHORT), false for the old ring.
func _burst(at: Vector2, r: float) -> bool:
	if pack_fx == null or not pack_fx.has_id(METEOR_LAND) or not pack_fx.has_room(&"impact"):
		return false
	var live := 0
	for b: Array in _blasts:
		live += 1 if bool(b[3]) else 0
	if live >= MAX_DRAWN:
		return false
	if pack_fx.spawn(METEOR_LAND, SimPlane.to_3d(at, 0.05), r * BURST_PER_M) == null:
		return false
	pack_bursts += 1
	return true


## The star's small hit sparkle on its target (0.2 s, PackFx.SHORT); none without the pack or past MAX_DRAWN.
func _sparkle(at: Vector2, tick: int) -> void:
	if pack_fx == null or _sparks.size() >= MAX_DRAWN or not pack_fx.has_room(&"hit"):
		return
	if pack_fx.spawn(STAR_HIT, SimPlane.to_3d(at, 0.3), STAR_HIT_SCALE) != null:
		_sparks.append(tick)
		pack_sparks += 1


## Head `k` of `rows`: it falls along FALL from high up to its landing point over its life. With the pack it is the
## row's held pack effect (its trail is the pack's own); without it the ball and a tail up the same line, thick at the
## ball and tapering to nothing.
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
	var shown := k < rows.size()
	ball.visible = shown
	tail.visible = shown
	if not shown:
		return
	var row: Array = rows[k]
	var star := life > 0
	var span := life if star else int(row[2])
	var u := clampf(float(tick - int(row[1])) / float(maxi(span, 1)), 0.0, 1.0)
	var at := SimPlane.to_3d(row[0], 0.0) + FALL * (1.0 - u)
	at.y = maxf(at.y, size * 0.5)
	if _pack_head(int(row[-1]), star, at):
		ball.visible = false
		tail.visible = false
		return
	ball.transform = Transform3D(Basis.from_scale(Vector3.ONE * size), at)
	var dir := FALL.normalized()
	var basis := Basis(Quaternion(Vector3.UP, dir)).scaled_local(Vector3(1.0, tail_m, 1.0))
	tail.transform = Transform3D(basis, at + dir * tail_m * 0.5)


## The pack head of the row with event `seq` (a star's or a meteor's) at `at`: false without the pack or room.
func _pack_head(seq: int, star: bool, at: Vector3) -> bool:
	if pack_fx == null:
		return false
	var id := STAR_HEAD if star else METEOR_HEAD
	var s := STAR_HEAD_SCALE if star else METEOR_HEAD_SCALE
	var setup := Callable() if star else _meteor_setup
	var node := _hold.touch(seq * 2 + (0 if star else 1), id, &"projectile", at, s, {}, setup)
	if node == null:
		return false
	if star:
		node.basis = _star_aim.scaled(Vector3.ONE * s)
	pack_heads += 1
	return true


## A new meteor head keeps flaming while it falls, its world-space flames sized to the head.
func _meteor_setup(node: Node3D) -> void:
	FireballPack.keep_playing(node, METEOR_HEAD_SCALE)
