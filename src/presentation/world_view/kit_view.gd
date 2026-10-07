class_name KitView
extends Node3D
## The player's melee as the view shows it: a laser blade (v0.2.0 PLAN L1, owner: "add a sword element … the
## laser part from a laser sword … a dash trail that follows it … replace the cone completely"). Only the light
## is drawn, no hilt: a bright cyan-white core capsule inside a larger, faint additive glow capsule, held at body
## height. It sweeps through the swing's arc in the first SWEEP_TICKS ticks, alternating direction each combo hit
## (the finisher's blade is thicker and brighter), then fades out over the recovery. A ribbon built from the last
## `trail_count` blade positions follows it and fades with age.
##
## What you see is what hits: the blade's tip sits at own_radius + reach from the cube's centre and it sweeps
## +-half_arc around the swing angle, the same numbers PlayerKit hits with (WorldReader.swing_shape).
##
## Idle: the blade is hidden between swings. It ignites with the swing and goes out with it, so a lit blade
## always means "this is hitting now"; a blade held at the side would read as a standing hitbox and clutter the
## cube's silhouette while shooting and dashing.
##
## Restyling (for items): set_look(color, length_scale, width_scale, trail_count).
##   color        the light's hue; the core is this lightened toward white, the glow and trail are this.
##   length_scale multiplies the blade's length; keep it 1.0 unless the item also changes the hit reach, or the
##                blade stops matching what hits.
##   width_scale  multiplies the core and glow thickness and the trail's inner width.
##   trail_count  how many ticks of blade positions the trail keeps (0 hides the trail).

const SWEEP_TICKS := 5
## Height of the blade above the ground (the cube's middle).
const BLADE_HEIGHT := 0.45
## The blade's hidden root: inside the cube, as a fraction of own_radius.
const ROOT_FRACTION := 0.5
const CORE_RADIUS := 0.035
const GLOW_RADIUS := 0.1
## The trail covers the blade from this fraction of its length out to the tip.
const TRAIL_INNER := 0.35
## Arc subdivisions between two trail samples, so the ribbon curves instead of cutting chords.
const TRAIL_SUBSTEPS := 4
const FINISHER_STEP := 2
const FINISHER_WIDTH := 1.35
const FINISHER_ENERGY := 1.5

var color := ThemePalette.color(&"player_core")
var length_scale := 1.0
var width_scale := 1.0
var trail_count := 6

var _pivot := Node3D.new()
var _core := MeshInstance3D.new()
var _glow := MeshInstance3D.new()
var _trail := MeshInstance3D.new()
var _core_mesh := CapsuleMesh.new()
var _glow_mesh := CapsuleMesh.new()
var _trail_mesh := ImmediateMesh.new()
var _core_mat := StandardMaterial3D.new()
var _glow_mat := StandardMaterial3D.new()
var _trail_mat := StandardMaterial3D.new()
var _shape: Array = [0, 0.0, 0.0]
var _span := Vector2.ZERO
## Trail samples, newest last: [centre: Vector3, yaw: float, alpha: float].
var _history: Array = []
var _last_t := 0


func _init() -> void:
	name = "KitView"
	_core_mat.albedo_color = Color.BLACK
	_core_mat.emission_enabled = true
	_core_mat.roughness = 1.0
	_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for m: StandardMaterial3D in [_glow_mat, _trail_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_trail_mat.vertex_color_use_as_albedo = true
	# Mixed, not added: an additive trail vanishes on the pale sand biomes.
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	for pair: Array in [[_core, _core_mesh, _core_mat], [_glow, _glow_mesh, _glow_mat]]:
		var n: MeshInstance3D = pair[0]
		n.mesh = pair[1]
		n.material_override = pair[2]
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.rotation = Vector3(0, 0, -PI * 0.5)  # the capsule's axis (Y) along the pivot's +X
		_pivot.add_child(n)
	_core.name = "BladeCore"
	_glow.name = "BladeGlow"
	_pivot.name = "Blade"
	_pivot.visible = false
	add_child(_pivot)
	_trail.name = "BladeTrail"
	_trail.mesh = _trail_mesh
	_trail.material_override = _trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.top_level = true  # samples are in world space, so the trail stays where the blade was
	_trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_trail.extra_cull_margin = 16.0
	add_child(_trail)
	_apply_look()


## Restyles the blade (see the class doc). Safe to call at any time; the next sync uses the new look.
func set_look(
	p_color: Color, p_length_scale: float = 1.0, p_width_scale: float = 1.0, p_trail_count: int = 6
) -> void:
	color = p_color
	length_scale = maxf(p_length_scale, 0.05)
	width_scale = maxf(p_width_scale, 0.05)
	trail_count = maxi(p_trail_count, 0)
	_apply_look()


## Sets the swing shape [half_arc, reach_m, own_radius_m] and rebuilds the blade to match it.
func set_shape(shape: Array) -> void:
	_shape = shape.duplicate()
	_span = blade_span(shape, length_scale)
	_size_blade()


## Distance of the blade's root and tip from the cube's centre (metres): the tip is the hit reach.
static func blade_span(shape: Array, p_length_scale: float = 1.0) -> Vector2:
	var own_r: float = shape[2]
	var reach: float = shape[1]
	return Vector2(own_r * ROOT_FRACTION, (own_r + reach) * p_length_scale)


## The tip's distance from the cube's centre, as drawn (core capsule's far end).
func blade_tip_m() -> float:
	return _core.position.x + _core_mesh.height * 0.5


func blade_visible() -> bool:
	return _pivot.visible


func trail_samples() -> int:
	return _history.size()


func sync(reader: WorldReader) -> void:
	var shape := reader.swing_shape()
	if shape != _shape:
		set_shape(shape)
	var t := reader.swing_tick()
	var on := t > 0 and not reader.player_dead()
	var was := _pivot.visible
	_pivot.visible = on
	if not on:
		_last_t = 0
		_history.clear()
		_trail_mesh.clear_surfaces()
		return
	var step := reader.combo_step()
	var finisher := step == FINISHER_STEP
	var half: float = TAU * float(shape[0]) / 4096.0
	var dir := 1.0 if step % 2 == 0 else -1.0
	var p := clampf(float(t - 1) / SWEEP_TICKS, 0.0, 1.0)
	p = 1.0 - (1.0 - p) * (1.0 - p)  # ease out: fast first, settling at the arc's end
	var ticks := reader.swing_ticks()
	var fade := clampf(
		1.0 - float(t - 1 - SWEEP_TICKS) / float(maxi(ticks - SWEEP_TICKS, 1)), 0.0, 1.0
	)
	var yaw := SimPlane.yaw_of(reader.swing_angle()) + (-half + 2.0 * half * p) * dir
	var at := SimPlane.to_3d(reader.player_pos(), BLADE_HEIGHT)
	_pivot.position = at
	_pivot.rotation = Vector3(0, yaw, 0)
	var thick := (FINISHER_WIDTH if finisher else 1.0) * lerpf(0.4, 1.0, fade)
	_pivot.scale = Vector3(1, thick, thick)
	_core_mat.emission_energy_multiplier = 3.0 * (FINISHER_ENERGY if finisher else 1.0) * fade
	_core_mat.albedo_color.a = fade
	_glow_mat.albedo_color.a = 0.35 * fade * (1.25 if finisher else 1.0)
	if t == 1 or t < _last_t or not was:
		_history.clear()
		_pivot.reset_physics_interpolation()
	if t != _last_t:  # hit-stop holds the tick: the trail holds too
		_history.append([at, yaw, fade * (1.3 if finisher else 1.0)])
		while _history.size() > trail_count + 1:
			_history.pop_front()
	_last_t = t
	_build_trail(_head())


## Rebuilds the trail every drawn frame so its head sits on the blade as drawn (interpolated between ticks);
## built from the tick samples alone, the trail would run up to a tick ahead of the blade.
func _process(_delta: float) -> void:
	if _pivot.visible and _history.size() >= 2:
		_build_trail(_head())


## The blade as drawn this frame: [centre, yaw, strength], yaw unwrapped next to the newest sample's.
func _head() -> Array:
	var newest: Array = _history[_history.size() - 1]
	var xf := _pivot.get_global_transform_interpolated() if is_inside_tree() else _pivot.transform
	var yaw := atan2(-xf.basis.x.z, xf.basis.x.x)
	yaw = newest[1] + wrapf(yaw - newest[1], -PI, PI)
	return [xf.origin, yaw, newest[2]]


func _apply_look() -> void:
	_core_mat.emission = color.lightened(0.75)
	_glow_mat.albedo_color = Color(color.lightened(0.2), _glow_mat.albedo_color.a)
	_trail_mat.albedo_color = Color.WHITE
	_span = blade_span(_shape, length_scale)
	_size_blade()


func _size_blade() -> void:
	var length := maxf(_span.y - _span.x, CORE_RADIUS * 2.0 * width_scale)
	_core_mesh.radius = CORE_RADIUS * width_scale
	_core_mesh.height = length
	_glow_mesh.radius = GLOW_RADIUS * width_scale
	_glow_mesh.height = maxf(length, GLOW_RADIUS * 2.0 * width_scale)
	_core.position = Vector3(_span.x + length * 0.5, 0, 0)
	_glow.position = _core.position


## A ribbon through the stored blade positions, ending at `head` (the blade as drawn): tip edge bright, inner
## edge clear, older samples fainter. The newest tick sample is replaced by the head, which lies between it and
## the one before.
func _build_trail(head: Array) -> void:
	_trail_mesh.clear_surfaces()
	if _history.size() < 2 or trail_count == 0:
		return
	var pts: Array = _history.slice(0, _history.size() - 1)
	pts.append(head)
	var n := pts.size()
	var r_in := lerpf(_span.x, _span.y, TRAIL_INNER)
	var r_out := _span.y
	var tip_color := color.lightened(0.15)
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var total := (n - 1) * TRAIL_SUBSTEPS
	for k in total + 1:
		var seg := mini(floori(float(k) / TRAIL_SUBSTEPS), n - 2)
		var f := float(k - seg * TRAIL_SUBSTEPS) / TRAIL_SUBSTEPS
		var a: Array = pts[seg]
		var b: Array = pts[seg + 1]
		var centre: Vector3 = (a[0] as Vector3).lerp(b[0], f)
		var yaw: float = lerpf(a[1], b[1], f)
		var strength: float = lerpf(a[2], b[2], f)
		var age := float(k) / float(total)  # 0 oldest, 1 newest
		var out := Vector3(cos(yaw), 0, -sin(yaw))
		_trail_mesh.surface_set_color(Color(tip_color, 0.12 * age * strength))
		_trail_mesh.surface_add_vertex(centre + out * r_in)
		_trail_mesh.surface_set_color(Color(tip_color, minf(0.95 * pow(age, 1.3) * strength, 1.0)))
		_trail_mesh.surface_add_vertex(centre + out * r_out)
	_trail_mesh.surface_end()


## A flat fan facing +X (sim angle 0): from the cube's edge out to edge + reach, across +-half_arc. The melee no
## longer draws it (v0.2.0 L1); UtilityView's guard arc still uses it.
static func fan_mesh(half_arc: int, own_r: float, reach: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var half := TAU * half_arc / 4096.0
	var steps := 16
	for k in steps:
		var a0 := -half + 2.0 * half * k / steps
		var a1 := -half + 2.0 * half * (k + 1) / steps
		var i0 := Vector3(cos(a0), 0, -sin(a0)) * own_r
		var i1 := Vector3(cos(a1), 0, -sin(a1)) * own_r
		var o0 := Vector3(cos(a0), 0, -sin(a0)) * (own_r + reach)
		var o1 := Vector3(cos(a1), 0, -sin(a1)) * (own_r + reach)
		verts.append_array([i0, o0, o1, i0, o1, i1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
