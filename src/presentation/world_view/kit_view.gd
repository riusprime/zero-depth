class_name KitView
extends Node3D
## The player's melee as the view shows it: a laser blade (v0.2.0 PLAN L1, owner: "add a sword element … the
## laser part from a laser sword … a dash trail that follows it … replace the cone completely"). Only the light
## is drawn, no hilt: a bright cyan-white core capsule inside a larger, faint additive glow capsule, held at body
## height. Each combo step moves it its own way (v0.3.0 L11; the step's WorldReader.MOTION_*), crossing the arc in the
## step's sweep ticks, then it fades out over the recovery:
## - SLASH_RIGHT_TO_LEFT / SLASH_LEFT_TO_RIGHT: sweeps -half_arc..+half_arc around the aim (or back), with a ribbon
##   built from the last `trail_count` blade positions behind it;
## - THRUST: held on the aim, it stabs out from pulled back to full length, leaving a narrow streak over the arc
##   (bright along the aim, clear at the arc's edges);
## - SPIN: one full turn from the aim, keeping the whole turn as a circular trail; the finisher's blade is thicker
##   and flares brighter for a few ticks when it hits.
##
## What you see is what hits: the blade's tip sits at own_radius + reach from the cube's centre (at full stab for
## the thrust) and it crosses +-half_arc around the swing angle, the step's own numbers that PlayerKit hits with
## (WorldReader.swing_shape).
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
const FINISHER_WIDTH := 1.35
const FINISHER_ENERGY := 1.5
## The finisher's flare when it hits: energy multiplier, for this many ticks from the hit.
const FINISHER_FLARE := 1.8
const FINISHER_FLARE_TICKS := 4
## The thrust starts this fraction of the blade's length pulled back toward the wanderer.
const THRUST_PULLBACK := 0.55
## Arc segments across a thrust's streak.
const STREAK_SEGMENTS := 8
const SPIN_SUBSTEPS := 8

var color := ThemePalette.color(&"player_core")
var length_scale := 1.0
var width_scale := 1.0
var trail_count := 6
## Overclock heat's tier (HeatLooks.TIER_*), read from the sim each sync: v0.5.5 LK (owner A2) the blade and its
## trail take the heat meter's tier colour (HeatLooks.attack_color): their own below Hot, orange at Hot, red at
## Overclock.
var heat_tier := HeatLooks.TIER_COOL

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
## The current swing's motion (WorldReader.MOTION_*), and the thrust streak's state: [aim yaw, half arc, strength].
var _motion := 0
var _streak: Array = [0.0, 0.0, 0.0]
## Trail samples, newest last: [centre: Vector3, yaw: float, alpha: float].
var _history: Array = []
var _last_t := 0
var _pivot_base := Vector3.ZERO


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


## Overclock heat (v0.5.5 LK, A2): the blade and its trail take the tier's colour (HeatLooks.attack_color). Only
## material parameters change (never the shader).
func set_heat_tier(tier: int) -> void:
	if tier == heat_tier:
		return
	heat_tier = tier
	_apply_colors()


## The blade's light as drawn: its own colour below Hot, the heat meter's tier colour from Hot up.
func hue() -> Color:
	return HeatLooks.attack_color(color, heat_tier)


func _apply_colors() -> void:
	var c := hue()
	# A hot blade whitens less at its core, so its orange or red still reads.
	var hot := heat_tier != HeatLooks.TIER_COOL
	_core_mat.emission = c.lightened(0.3 if hot else 0.75)
	_glow_mat.albedo_color = Color(c.lightened(0.2), _glow_mat.albedo_color.a)


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


## The blade's yaw (radians, SimPlane.yaw_of convention) and how far its pivot sits from the cube's centre (the
## thrust's pull-back), as of the last sync.
func blade_yaw() -> float:
	return _pivot.rotation.y


func blade_offset() -> float:
	return _pivot.position.distance_to(_pivot_base)


## The current swing's motion as drawn (WorldReader.MOTION_*).
func motion() -> int:
	return _motion


## The core's glow (emission energy) as of the last sync: brighter on the finisher, flaring when it hits.
func blade_energy() -> float:
	return _core_mat.emission_energy_multiplier


func sync(reader: WorldReader) -> void:
	set_heat_tier(HeatLooks.tier_of(reader.heat_state()))
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
	var finisher := reader.is_finisher()
	_motion = reader.swing_motion()
	var sweep := reader.swing_sweep_ticks()
	var half: float = TAU * float(shape[0]) / 4096.0
	var p := clampf(float(t - 1) / sweep, 0.0, 1.0)
	p = 1.0 - (1.0 - p) * (1.0 - p)  # ease out: fast first, settling at the arc's end
	var ticks := reader.swing_ticks()
	var fade := clampf(1.0 - float(t - 1 - sweep) / float(maxi(ticks - sweep, 1)), 0.0, 1.0)
	var aim := SimPlane.yaw_of(reader.swing_angle())
	var yaw := aim
	var pull := 0.0
	match _motion:
		WorldReader.MOTION_SLASH_RIGHT_TO_LEFT:
			yaw = aim - half + 2.0 * half * p
		WorldReader.MOTION_SLASH_LEFT_TO_RIGHT:
			yaw = aim + half - 2.0 * half * p
		WorldReader.MOTION_THRUST:
			pull = (1.0 - p) * THRUST_PULLBACK * (_span.y - _span.x)
		WorldReader.MOTION_SPIN:
			yaw = aim + TAU * p
	var at := SimPlane.to_3d(reader.player_pos(), BLADE_HEIGHT)
	_pivot_base = at
	_pivot.position = at - Vector3(cos(yaw), 0, -sin(yaw)) * pull
	_pivot.rotation = Vector3(0, yaw, 0)
	var thick := (FINISHER_WIDTH if finisher else 1.0) * lerpf(0.4, 1.0, fade)
	_pivot.scale = Vector3(1, thick, thick)
	var since_hit := t - reader.swing_active_tick()
	var flare := (
		FINISHER_FLARE if finisher and since_hit >= 0 and since_hit < FINISHER_FLARE_TICKS else 1.0
	)
	_core_mat.emission_energy_multiplier = (
		3.0 * (FINISHER_ENERGY if finisher else 1.0) * flare * fade
	)
	_core_mat.albedo_color.a = fade
	_glow_mat.albedo_color.a = 0.35 * fade * (1.25 if finisher else 1.0) * flare
	_streak = [aim, half, fade * p]
	# A new swing starts the trail over. Not "t == 1": a hit-stop on a swing's first tick (the wanderer hurt then)
	# syncs tick 1 again, and clearing it with the tick held left an empty trail whose head was read out of bounds,
	# a crash in release builds (v0.3.0 L28, docs/roadmap/v0.3.0/evidence/CRASH_ON_HIT.md).
	if t < _last_t or not was:
		_history.clear()
		_pivot.reset_physics_interpolation()
	if t != _last_t or _history.is_empty():  # hit-stop holds the tick: the trail holds too
		_history.append([at, yaw, fade * (1.3 if finisher else 1.0)])
		var keep := sweep + 2 if _motion == WorldReader.MOTION_SPIN else trail_count + 1
		while _history.size() > keep:
			_history.pop_front()
	_last_t = t
	_build_trail(_head())


## Rebuilds the trail every drawn frame so its head sits on the blade as drawn (interpolated between ticks);
## built from the tick samples alone, the trail would run up to a tick ahead of the blade.
func _process(_delta: float) -> void:
	if _pivot.visible and _history.size() >= 2 and _motion != WorldReader.MOTION_THRUST:
		_build_trail(_head())


## The blade as drawn this frame: [centre, yaw, strength], yaw unwrapped next to the newest sample's.
func _head() -> Array:
	if _history.is_empty():
		return []
	var newest: Array = _history[_history.size() - 1]
	var xf := _pivot.get_global_transform_interpolated() if is_inside_tree() else _pivot.transform
	var yaw := atan2(-xf.basis.x.z, xf.basis.x.x)
	yaw = newest[1] + wrapf(yaw - newest[1], -PI, PI)
	return [xf.origin, yaw, newest[2]]


func _apply_look() -> void:
	_apply_colors()
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
	if trail_count == 0:
		return
	if _motion == WorldReader.MOTION_THRUST:
		_build_streak()
		return
	if _history.size() < 2:
		return
	var pts: Array = _history.slice(0, _history.size() - 1)
	pts.append(head)
	var n := pts.size()
	var r_in := lerpf(_span.x, _span.y, TRAIL_INNER)
	var r_out := _span.y
	var tip_color := hue().lightened(0.15)
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var sub := SPIN_SUBSTEPS if _motion == WorldReader.MOTION_SPIN else TRAIL_SUBSTEPS
	var total := (n - 1) * sub
	for k in total + 1:
		var seg := mini(floori(float(k) / sub), n - 2)
		var f := float(k - seg * sub) / sub
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


## The thrust's streak: a thin fan over the step's arc around the aim, from the trail's inner radius out to the
## tip, bright along the aim and clear at the arc's edges and near the wanderer. World space, at the wanderer.
func _build_streak() -> void:
	var strength: float = _streak[2]
	if strength <= 0.01:
		return
	var aim: float = _streak[0]
	var half: float = _streak[1]
	var centre := _pivot_base
	var r_in := lerpf(_span.x, _span.y, TRAIL_INNER)
	var r_out := _span.y
	# The blade's own hue, not whitened: the streak lies under a white-hot blade on pale ground.
	var tip_color := hue()
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := centre + Vector3(cos(aim), 0, -sin(aim)) * r_in
	for k in STREAK_SEGMENTS:
		var f0 := -1.0 + 2.0 * k / STREAK_SEGMENTS
		var f1 := -1.0 + 2.0 * (k + 1) / STREAK_SEGMENTS
		_trail_mesh.surface_set_color(Color(tip_color, 0.05 * strength))
		_trail_mesh.surface_add_vertex(root)
		for f in [f0, f1]:
			var y: float = aim + half * f
			var edge := 1.0 - absf(f)
			_trail_mesh.surface_set_color(Color(tip_color, minf(strength * edge * 1.1, 1.0)))
			_trail_mesh.surface_add_vertex(centre + Vector3(cos(y), 0, -sin(y)) * r_out)
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
