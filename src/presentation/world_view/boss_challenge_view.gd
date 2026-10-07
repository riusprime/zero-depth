class_name BossChallengeView
extends Node3D
## The boss challenge's own visuals (PLAN v0.3.0 BX; owner lines L17, L20), read through WorldReader only (EI-07):
## - the closing arena: the band that hurts now (a solid hazard strip along the walls) and, while the next step is
##   marked, its outline with a fill that grows with the warning, from WorldReader.boss_arena_band (the same shape
##   BossChallenge.resolve_arena hits with);
## - the vortex of a pull (a telegraph whose move is MOVE_PULL): spiral arms turning inward out to its reach;
## - enemies dissolving as the boss is summoned (ENEMY_DISSOLVED): a column of motes rising from where each stood and
##   a ring that fades.
## Meshes are rebuilt each tick (ImmediateMesh) with kept materials; only colours change. Nothing here feeds back.

const Y := 0.04
const EDGE := 0.08
const VORTEX_ARMS := 5
const VORTEX_STEPS := 24
## Motes per dissolving enemy and their life (frames).
const MOTES := 10
const MOTE_FRAMES := 45
const BAND_COLOR := Color("#FF5A2A")
const DISSOLVE_COLOR := Color("#8FE6FF")

var band_mesh := MeshInstance3D.new()
var warn_mesh := MeshInstance3D.new()
var vortex_mesh := MeshInstance3D.new()
var _band_mat := StandardMaterial3D.new()
var _warn_fill_mat := StandardMaterial3D.new()
var _warn_edge_mat := StandardMaterial3D.new()
var _vortex_mat := StandardMaterial3D.new()
var _mote_mat := StandardMaterial3D.new()
var _ring_mat := StandardMaterial3D.new()
var _mote_mesh := BoxMesh.new()
var _last_seq := 0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
## Live dissolve pieces: [node, velocity, frames left, kind (0 mote, 1 ring)].
var _fx: Array = []
var _band := {}
var _vortices: Array = []
var _dissolved := 0


func _init() -> void:
	name = "BossChallengeView"
	_rng.seed = 7  # cosmetic only (EI-05)
	for m: StandardMaterial3D in [
		_band_mat, _warn_fill_mat, _warn_edge_mat, _vortex_mat, _mote_mat, _ring_mat
	]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_band_mat.albedo_color = Color(BAND_COLOR, 0.55)
	_warn_fill_mat.albedo_color = Color(BAND_COLOR, 0.22)
	_warn_edge_mat.albedo_color = Color(BAND_COLOR, 0.95)
	_vortex_mat.albedo_color = Color(ThemePalette.color(&"telegraph_hostile"), 0.8)
	_mote_mat.albedo_color = Color(DISSOLVE_COLOR, 0.9)
	_ring_mat.albedo_color = Color(DISSOLVE_COLOR, 0.6)
	_mote_mesh.size = Vector3.ONE * 0.12
	for mi: MeshInstance3D in [band_mesh, warn_mesh, vortex_mesh]:
		mi.mesh = ImmediateMesh.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	band_mesh.name = "Band"
	warn_mesh.name = "BandWarning"
	vortex_mesh.name = "Vortex"


func sync(reader: WorldReader) -> void:
	_band = reader.boss_arena_band()
	_vortices.clear()
	for i in reader.actor_count():
		if not WorldReader.is_boss_kind(reader.actor_kind(i)):
			continue
		var tg := reader.telegraph(i)
		if not tg.is_empty() and tg.get("move", -1) == WorldReader.MOVE_PULL:
			_vortices.append([tg["center"], float(tg["pull_m"]), float(tg["progress"]) / 1000.0])
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.ENEMY_DISSOLVED:
			_dissolve(e.pos)
	_draw_band()


## The band showing now: {} or the reader's dictionary (tests).
func band() -> Dictionary:
	return _band


## How many vortices are drawn (tests).
func vortex_count() -> int:
	return _vortices.size()


## How many enemies have dissolved on screen so far (tests).
func dissolved_count() -> int:
	return _dissolved


func _process(delta: float) -> void:
	_t += delta
	_draw_vortices()
	for k in range(_fx.size() - 1, -1, -1):
		var f: Array = _fx[k]
		var node: Node3D = f[0]
		f[2] -= 1
		var life := float(f[2]) / MOTE_FRAMES
		if f[3] == 0:
			node.position += (f[1] as Vector3) * delta
			node.scale = Vector3.ONE * maxf(life, 0.05)
		else:
			node.scale = Vector3(2.4 - life * 1.4, 1, 2.4 - life * 1.4)
		if f[2] <= 0:
			node.queue_free()
			_fx.remove_at(k)


func _dissolve(at: Vector2) -> void:
	_dissolved += 1
	for k in MOTES:
		var m := MeshInstance3D.new()
		m.mesh = _mote_mesh
		m.material_override = _mote_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var off := Vector3(_rng.randf_range(-0.35, 0.35), 0, _rng.randf_range(-0.35, 0.35))
		m.position = SimPlane.to_3d(at, _rng.randf_range(0.1, 1.0)) + off
		add_child(m)
		_fx.append([m, Vector3(0, _rng.randf_range(1.2, 2.6), 0), MOTE_FRAMES, 0])
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.55
	ring.mesh = torus
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = SimPlane.to_3d(at, Y)
	add_child(ring)
	_fx.append([ring, Vector3.ZERO, MOTE_FRAMES, 1])


func _draw_band() -> void:
	var fill: ImmediateMesh = band_mesh.mesh
	var warn: ImmediateMesh = warn_mesh.mesh
	fill.clear_surfaces()
	warn.clear_surfaces()
	if _band.is_empty():
		return
	var arena: Rect2 = _band["arena"]
	var depth: Vector2 = _band["depth"]
	var bt := []
	_strips(bt, arena, depth)
	_emit(fill, bt, _band_mat)
	if int(_band["warn"]) < 0:
		return
	var next: Vector2 = _band["next"]
	var p := float(_band["warn"]) / 1000.0
	var wt := []
	_strips(wt, arena, depth + (next - depth) * p)
	_emit(warn, wt, _warn_fill_mat)
	var et := []
	var inner := Rect2(arena.position + next, arena.size - next * 2.0)
	_outline(et, inner)
	_emit(warn, et, _warn_edge_mat)


## The band `depth` deep inside `arena` (per axis), as triangles: two strips along x's ends, two along y's.
func _strips(out: Array, arena: Rect2, depth: Vector2) -> void:
	var a := arena.position
	var b := arena.end
	if depth.x > 0.0:
		_quad(out, a, Vector2(a.x + depth.x, a.y), Vector2(a.x + depth.x, b.y), Vector2(a.x, b.y))
		_quad(out, Vector2(b.x - depth.x, a.y), Vector2(b.x, a.y), b, Vector2(b.x - depth.x, b.y))
	if depth.y > 0.0:
		_quad(out, a, Vector2(b.x, a.y), Vector2(b.x, a.y + depth.y), Vector2(a.x, a.y + depth.y))
		_quad(out, Vector2(a.x, b.y - depth.y), Vector2(b.x, b.y - depth.y), b, Vector2(a.x, b.y))


func _outline(out: Array, r: Rect2) -> void:
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		var p: Vector2 = c[k]
		var q: Vector2 = c[(k + 1) % 4]
		var d := (q - p).normalized()
		var side := Vector2(-d.y, d.x) * EDGE * 0.5
		_quad(out, p - side, q - side, q + side, p + side)


func _draw_vortices() -> void:
	var im: ImmediateMesh = vortex_mesh.mesh
	im.clear_surfaces()
	var pts := []
	for v: Array in _vortices:
		var c: Vector2 = v[0]
		var reach: float = v[1]
		var turn := -_t * 2.4
		for arm in VORTEX_ARMS:
			var base := TAU * arm / VORTEX_ARMS + turn
			for k in VORTEX_STEPS:
				var f0 := float(k) / VORTEX_STEPS
				var f1 := float(k + 1) / VORTEX_STEPS
				var p0 := _spiral(c, reach, base, f0)
				var p1 := _spiral(c, reach, base, f1)
				var d := (p1 - p0).normalized()
				var w := 0.08 + 0.16 * (1.0 - f0)
				var side := Vector2(-d.y, d.x) * w
				_quad(pts, p0 - side, p1 - side, p1 + side, p0 + side)
	_emit(im, pts, _vortex_mat)


## A point on a vortex arm: f = 0 at the rim, 1 at the centre, curling a third of a turn inward.
func _spiral(c: Vector2, reach: float, base: float, f: float) -> Vector2:
	var r := reach * (1.0 - f) + 0.4 * f
	var a := base + f * TAU * 0.35
	return c + Vector2(cos(a), sin(a)) * r


func _quad(out: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	out.append_array([a, b, c, a, c, d])


func _emit(im: ImmediateMesh, pts: Array, mat: Material) -> void:
	if pts.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for q: Vector2 in pts:
		im.surface_set_normal(Vector3.UP)
		im.surface_add_vertex(SimPlane.to_3d(q, Y))
	im.surface_end()
