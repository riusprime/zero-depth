class_name ZdBolt
extends Node3D
## v0.10.0 VX6 (VFX_PACK N1, "gaps built in the pack's style"): one lightning bolt, drawn the way the Binbun beams
## are: a flat strip (a hot core in the laser's look and a wider scrolling-noise shell, both from bolt_ribbon.gdshader)
## along a jagged line, turned to face the camera. It is a PackFx scene (family bolt): PackFx sets the three colours
## and spawns, moves and releases it.
## - set_ends(a, b, seed, width): the jagged line from a to b, 6-10 segments, up to 12 % of its length off the straight
##   line, plus 0-2 thin forks; all of it a hash of `seed` and the flicker count (no randomness).
## - Flicker: the line is re-jittered every FLICKER_S while the bolt lives.
## - Fade: `fade_time` > 0 fades the bolt out over that many seconds from its spawn (a strike); 0 keeps it as bright as
##   `strength` says (a held bolt that something else fades).
## Cosmetic only (EI-07): nothing here reads or writes the sim.

const FLICKER_S := 0.06
const SEG_MIN := 6
const SEG_SPAN := 5  # (6..10)
const JITTER := 0.12  # of the bolt's length
const FORK_MAX := 2
const FORK_LEN := 0.25  # of the bolt's length
const SHELL := 3.2  # the shell's width over the core's
const MATERIALS: Array[String] = [
	"res://assets/vfx_zd/lightning/bolt_outer.tres", "res://assets/vfx_zd/lightning/bolt_core.tres"
]

@export var primary_color := Color(0.97, 0.98, 1.0):
	set(v):
		primary_color = v
		_paint()
@export var secondary_color := Color(0.5, 0.7, 1.0):
	set(v):
		secondary_color = v
		_paint()
@export var tertiary_color := Color(0.24, 0.48, 1.0):
	set(v):
		tertiary_color = v
		_paint()
## Seconds the bolt takes to fade out from its spawn; 0: it does not fade by itself.
var fade_time := 0.0
## 0..1, how bright a held bolt is (the caller's fade).
var strength := 1.0
var width := 0.12
var rebuilds := 0  # (tests)
var flicks := 0

var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _seed := 0
var _has_ends := false
var _age := 0.0
var _clock := 0.0
var _dirty := false
var _mi := MeshInstance3D.new()
var _mesh := ArrayMesh.new()
var _mats: Array[ShaderMaterial] = []


func _init() -> void:
	_mi.mesh = _mesh
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	for path in MATERIALS:
		# (each bolt owns its colours)
		_mats.append((load(path) as ShaderMaterial).duplicate() as ShaderMaterial)
	_paint()
	visibility_changed.connect(_on_visibility)


## The jagged line from `a` to `b` (world positions) for `p_seed`, `p_width` metres across at its core.
func set_ends(a: Vector3, b: Vector3, p_seed: int, p_width := 0.12) -> void:
	width = p_width
	if _has_ends and p_seed == _seed and a.is_equal_approx(_a) and b.is_equal_approx(_b):
		return
	_a = a
	_b = b
	_seed = p_seed
	_has_ends = true
	_rebuild()


## The brightness now, 0..1 (the fade out, the flicker).
func brightness() -> float:
	var f := strength
	if fade_time > 0.0:
		f *= pow(clampf(1.0 - _age / fade_time, 0.0, 1.0), 0.7)
	return f * (0.8 + 0.2 * float((flicks + _seed) % 2))


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not _has_ends:
		return
	_age += delta
	_clock += delta
	while _clock >= FLICKER_S:
		_clock -= FLICKER_S
		flicks += 1
		_dirty = true
	if _dirty:
		_rebuild()
	var f := brightness()
	for m in _mats:
		m.set_shader_parameter(&"fade", f)
	_mi.visible = f > 0.01


func _on_visibility() -> void:
	if visible:  # (PackFx shows a bolt when it spawns it)
		_age = 0.0
		_clock = 0.0
		flicks = 0
		_has_ends = false
		_mesh.clear_surfaces()


func _paint() -> void:
	for m in _mats:
		m.set_shader_parameter(&"primary_color", primary_color)
		m.set_shader_parameter(&"secondary_color", secondary_color)
		m.set_shader_parameter(&"tertiary_color", tertiary_color)


## A deterministic 0..1 from two ints (no randomness: EI-05).
static func hash01(a: int, b: int) -> float:
	var x := ((a * 73856093) ^ (b * 19349663) ^ 0x2545F491) & 0x7FFFFFFF
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7FFFFFFF
	x = x ^ (x >> 16)
	return float(x & 0xFFFF) / 65535.0


## The bolt's points (local space) for the current seed and flicker: [main line, fork, fork...]; each is an
## Array of Vector3. Public for the tests.
func lines() -> Array[Array]:
	var la := to_local(_a) if is_inside_tree() else _a - position
	var lb := to_local(_b) if is_inside_tree() else _b - position
	var d := lb - la
	var span := d.length()
	var out: Array[Array] = []
	if span < 0.001:
		return out
	var u := d / span
	var side := u.cross(Vector3.UP)
	if side.length() < 0.01:
		side = u.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := u.cross(side).normalized()
	var key := _seed * 31 + flicks
	var n := SEG_MIN + int(hash01(_seed, 7) * (SEG_SPAN - 0.001))
	var amp := span * JITTER
	var main: Array = [la]
	for i in range(1, n):
		var p := la + d * (float(i) / n)
		p += side * (hash01(key, i) * 2.0 - 1.0) * amp
		p += up * (hash01(key, i + 40) * 2.0 - 1.0) * amp * 0.5
		main.append(p)
	main.append(lb)
	out.append(main)
	var forks := int(hash01(_seed, 11) * (FORK_MAX + 0.999))
	for f in forks:
		var at := 1 + int(hash01(_seed, 20 + f) * (n - 2.001))
		var sgn := 1.0 if hash01(_seed, 30 + f) < 0.5 else -1.0
		var bend := side * sgn * (0.6 + 0.5 * hash01(key, 60 + f))
		var dir := (u + bend + up * (hash01(key, 70 + f) - 0.5) * 0.6).normalized()
		var root: Vector3 = main[at]
		var fork: Array = [root]
		for j in range(1, 4):
			var q := root + dir * span * FORK_LEN * (float(j) / 3.0)
			q += side * (hash01(key, 80 + f * 4 + j) * 2.0 - 1.0) * amp * 0.5
			fork.append(q)
		out.append(fork)
	return out


func _rebuild() -> void:
	_dirty = false
	rebuilds += 1
	_mesh.clear_surfaces()
	var polys := lines()
	if polys.is_empty():
		return
	var view := _view_dir()
	var total := 0.0
	for poly in polys:
		total += _poly_len(poly)
	# v0.10.5 W3-Q7 (a strike's bolts are rebuilt every frame they grow): each point's side, half-width factor and v
	# are worked out once for both layers, its length along the line kept as it goes (it re-summed the line up to every
	# point, through a new Array each); the same sums in the same order, so the same mesh.
	var pts := PackedVector3Array()
	var sides := PackedVector3Array()
	var thins := PackedFloat32Array()
	var tapers := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var run := 0.0
	for pi in polys.size():
		var poly: Array = polys[pi]
		var thin := 1.0 if pi == 0 else 0.55
		var base := pts.size() * 2
		var along := 0.0
		for i in poly.size():
			var p: Vector3 = poly[i]
			if i > 0:
				along += p.distance_to(poly[i - 1] as Vector3)
			var t: Vector3 = (
				(poly[mini(i + 1, poly.size() - 1)] as Vector3) - (poly[maxi(i - 1, 0)] as Vector3)
			)
			var s := t.cross(view)
			s = s.normalized() if s.length() > 0.0001 else Vector3.UP
			var taper := 1.0 if pi == 0 else 1.0 - 0.8 * float(i) / (poly.size() - 1)
			pts.append(p)
			sides.append(s)
			thins.append(thin)
			tapers.append(taper)
			var v := (run + along) / maxf(total, 0.001)
			uvs.append(Vector2(0.0, v))
			uvs.append(Vector2(1.0, v))
		for i in poly.size() - 1:
			var o := base + i * 2
			idx.append(o)
			idx.append(o + 1)
			idx.append(o + 2)
			idx.append(o + 1)
			idx.append(o + 3)
			idx.append(o + 2)
		run += along
	for layer in 2:
		var w := width * (SHELL if layer == 0 else 1.0) * 0.5
		var verts := PackedVector3Array()
		verts.resize(pts.size() * 2)
		for k in pts.size():
			var s := sides[k]
			var d := s * w * thins[k] * tapers[k]
			verts[k * 2] = pts[k] - d
			verts[k * 2 + 1] = pts[k] + d
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = idx
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mesh.surface_set_material(layer, _mats[layer])
		_mats[layer].set_shader_parameter(&"beam_length", maxf(total * 0.6, 1.0))


static func _poly_len(poly: Array) -> float:
	var s := 0.0
	for i in range(1, poly.size()):
		s += (poly[i] as Vector3).distance_to(poly[i - 1] as Vector3)
	return s


## The way the camera looks (the iso camera's, or a stand-in).
func _view_dir() -> Vector3:
	if is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			return -cam.global_transform.basis.z
	return Vector3(-0.5, -0.7, -0.5).normalized()
