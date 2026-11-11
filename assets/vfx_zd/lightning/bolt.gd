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
## The strip's points: the longest main line (SEG_MIN + SEG_SPAN - 1 segments) and a fork's.
const MAIN_POINTS := SEG_MIN + SEG_SPAN
const FORK_POINTS := 4
## How much nearer the core sorts than its shell (m): enough to win the tie, too little to pass anything else.
const CORE_SORT := 0.01
const MATERIALS: Array[String] = [
	"res://assets/vfx_zd/lightning/bolt_outer.tres", "res://assets/vfx_zd/lightning/bolt_core.tres"
]

static var _strip: ArrayMesh = null

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
## The shell's strip and the core's (the same mesh, one material each). The core sorts a hair nearer, so it always
## draws over its shell: one mesh with two surfaces left that order to the renderer's sort, which broke the tie
## differently from bolt to bolt.
var _mi := MeshInstance3D.new()
var _core_mi := MeshInstance3D.new()
var _mats: Array[ShaderMaterial] = []
## What the materials hold now (the line's [a, b, seed, width] and the fade), so an unchanged one is not written again.
var _line_set := []
var _fade_set := -1.0


func _init() -> void:
	for path in MATERIALS:
		# (each bolt owns its colours and its line)
		_mats.append((load(path) as ShaderMaterial).duplicate() as ShaderMaterial)
	for k in 2:
		var mi := _mi if k == 0 else _core_mi
		mi.mesh = strip_mesh()
		# (a surface override: PackHold.localize copies material overrides, and these are set every reshape)
		mi.set_surface_override_material(0, _mats[k])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_core_mi.sorting_offset = CORE_SORT
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
	if f != _fade_set:  # (each write is a material update; most frames the fade holds)
		_fade_set = f
		for m in _mats:
			m.set_shader_parameter(&"fade", f)
	var show := _has_ends and f > 0.01
	if _mi.visible != show:
		_mi.visible = show
		_core_mi.visible = show


func _on_visibility() -> void:
	if visible:  # (PackFx shows a bolt when it spawns it)
		_age = 0.0
		_clock = 0.0
		flicks = 0
		_has_ends = false
		_mi.visible = false
		_core_mi.visible = false
		for m in _mats:
			m.set_shader_parameter(&"has_ends", false)
		_line_set = []


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
## Array of Vector3. The shader (bolt_ribbon.gdshader) draws the same points; this is their CPU reference (the tests).
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


## The line's numbers into both layers' materials: the shader lays the strip out from them (bolt_ribbon.gdshader
## follows lines() step for step), so a moved or re-jittered bolt costs a few uniforms, not a new mesh.
func _rebuild() -> void:
	_dirty = false
	rebuilds += 1
	var la := to_local(_a) if is_inside_tree() else _a - position
	var lb := to_local(_b) if is_inside_tree() else _b - position
	var seed32 := _seed & 0xFFFFFFFF
	if seed32 >= 0x80000000:
		seed32 -= 0x100000000
	var line := [la, lb, seed32, width]
	if line == _line_set:  # A flicker alone: one number
		for m in _mats:
			m.set_shader_parameter(&"flicks", flicks & 0x7FFFFFFF)
		return
	_line_set = line
	for m in _mats:
		m.set_shader_parameter(&"end_a", la)
		m.set_shader_parameter(&"end_b", lb)
		m.set_shader_parameter(&"bolt_seed", seed32)
		m.set_shader_parameter(&"flicks", flicks & 0x7FFFFFFF)
		m.set_shader_parameter(&"width", width)
		m.set_shader_parameter(&"has_ends", true)
	# The strip's own vertices all sit at the origin: the renderer culls by this box (the line, its jitter and forks).
	var span := la.distance_to(lb)
	var box := AABB(la, Vector3.ZERO).expand(lb).grow(span * 0.5 + width * SHELL)
	if not _mi.custom_aabb.is_equal_approx(box):
		_mi.custom_aabb = box
		_core_mi.custom_aabb = box


## The strip every bolt draws (made once): MAIN_POINTS points of the main line then FORK_MAX forks of FORK_POINTS, two
## vertices a point (UV.x 0 and 1 across it, UV2 the line and the point's index), the same two triangles a segment as
## the mesh ZdBolt used to build. The shell and the core each draw it with their own material.
static func strip_mesh() -> ArrayMesh:
	if _strip != null:
		return _strip
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	for line in FORK_MAX + 1:
		var count := MAIN_POINTS if line == 0 else FORK_POINTS
		var base := uvs.size()
		for i in count:
			for x in 2:
				uvs.append(Vector2(x, 0.0))
				uv2s.append(Vector2(line, i))
		for i in count - 1:
			var o := base + i * 2
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o + 1, o + 3, o + 2]))
	var verts := PackedVector3Array()
	verts.resize(uvs.size())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	_strip = ArrayMesh.new()
	_strip.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _strip
