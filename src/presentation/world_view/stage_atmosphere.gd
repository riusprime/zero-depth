class_name StageAtmosphere
extends Node3D
## v0.8.0 GX (owner O86, feedback/2026-10-19_graphics_upgrade.md §1, §3): the air of a floor on the "high" lighting
## tier. A low layer of volumetric fog that follows the view (the fire props' lights hang in it), warm embers drifting
## round each light prop, and a sparse cool dust over the view. Presentation only: frame time, nothing decides an
## outcome; the sim never reads it.
##
## Bounded: one emitter per light prop (EMBERS_PER_LIGHT motes) and one dust emitter (DUST_COUNT). An ember emitter
## is parented to its light, so when StageKit hides a light out of the view's reach its embers hide with it, and they
## stop emitting. Reduced motion freezes the motes where they are (as the void's stars stay still).

const EMBERS_PER_LIGHT := 28
const EMBER_LIFETIME := 4.5
## The embers' box round the light: this share of the light's range across (capped at EMBER_REACH_MAX m), and
## EMBER_HALF_HEIGHT m up and down round a point EMBER_DROP m under the light.
const EMBER_REACH := 0.3
const EMBER_REACH_MAX := 2.6
const EMBER_HALF_HEIGHT := 0.9
const EMBER_DROP := 0.5
const EMBER_SIZE := 0.07
## The ember's HDR brightness (a touch over 1 so the glow just catches it; the flames were tamed in v0.8.0 P3).
const EMBER_HDR := 1.25
const DUST_COUNT := 90
const DUST_LIFETIME := 9.0
const DUST_SIZE := 0.05
## The dust's box: the camera's ortho size times this across, DUST_HALF_HEIGHT m up and down round DUST_Y.
const DUST_REACH := 0.9
const DUST_HALF_HEIGHT := 1.4
const DUST_Y := 1.6
const DUST_COOL := Color(0.62, 0.72, 0.9)
const DUST_ALPHA := 0.45
## The fog layer: a box the camera's ortho size times FOG_REACH across, from FOG_FLOOR up to the mood's
## volumetric_height, following the view's focus on the ground.
const FOG_REACH := 4.0
const FOG_FLOOR := -1.0
const FOG_EDGE_FADE := 0.35
const FOG_HEIGHT_FALLOFF := 0.3
## How often (frames) the emitters follow their lights' visibility and the reduced-motion preference.
const CHECK_EVERY := 10

static var _dot: GradientTexture2D

var enabled := false
var fog_layer: FogVolume
var dust: GPUParticles3D
var embers: Array[GPUParticles3D] = []
var _lights: Array[OmniLight3D] = []
var _fog_mat: FogMaterial
var _fog_top := 3.5
var _frame := 0
var _calm := false


## Builds the layer, the dust and one ember emitter per light in `lights` (StageKit.lights), from `mood`.
func setup(mood: BiomeMood, lights: Array[OmniLight3D]) -> void:
	_lights = lights
	_fog_mat = FogMaterial.new()
	fog_layer = FogVolume.new()
	fog_layer.name = "FogLayer"
	fog_layer.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog_layer.material = _fog_mat
	add_child(fog_layer)
	var ember_draw := _draw_mesh(EMBER_SIZE, Color(EMBER_HDR, EMBER_HDR, EMBER_HDR))
	var ember_proc := _ember_process(mood)
	for k in lights.size():
		var em := GPUParticles3D.new()
		em.name = "Embers"
		em.amount = EMBERS_PER_LIGHT
		em.lifetime = EMBER_LIFETIME
		em.preprocess = EMBER_LIFETIME
		em.local_coords = true
		em.process_material = ember_proc
		em.draw_pass_1 = ember_draw
		em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		em.position = Vector3(0, -EMBER_DROP, 0)
		var reach := _ember_reach(mood)
		em.visibility_aabb = AABB(
			Vector3(-reach - 0.5, -EMBER_HALF_HEIGHT - 0.5, -reach - 0.5),
			Vector3(reach * 2.0 + 1.0, EMBER_HALF_HEIGHT * 2.0 + 2.0, reach * 2.0 + 1.0)
		)
		em.emitting = false
		lights[k].add_child(em)
		embers.append(em)
	dust = GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = DUST_COUNT
	dust.lifetime = DUST_LIFETIME
	dust.preprocess = DUST_LIFETIME
	dust.local_coords = false
	dust.process_material = _dust_process()
	dust.draw_pass_1 = _draw_mesh(DUST_SIZE, Color(1, 1, 1))
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 10, 80))
	dust.emitting = false
	add_child(dust)
	retune(mood)
	set_enabled(enabled)


## The mood's values on the layer and the lights (the dev panel's lighting page re-applies them live).
func retune(mood: BiomeMood) -> void:
	if _fog_mat == null:
		return
	_fog_mat.density = mood.volumetric_density
	_fog_mat.albedo = mood.volumetric_albedo
	_fog_mat.height_falloff = FOG_HEIGHT_FALLOFF
	_fog_mat.edge_fade = FOG_EDGE_FADE
	_fog_top = mood.volumetric_height
	for l in _lights:
		if is_instance_valid(l):
			l.light_volumetric_fog_energy = mood.volumetric_light_energy
	var dust_mat := dust.process_material as ParticleProcessMaterial
	dust_mat.color = Color(mood.ambient_color.lerp(DUST_COOL, 0.6), DUST_ALPHA)
	var ember_mat := _ember_mat()
	if ember_mat != null:
		ember_mat.color = mood.warm_light_color


## On ("high" with a mood) or off: everything hides and stops emitting when off, so "low" pays nothing for it.
func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	_sync()
	if on:
		_follow()


func _process(_delta: float) -> void:
	if not enabled:
		return
	_follow()
	_frame += 1
	if _frame % CHECK_EVERY == 1:
		_sync()


## The fog layer and the dust follow the camera's focus on the ground.
func _follow() -> void:
	var at := _focus()
	if at.is_empty() or fog_layer == null:
		return
	var focus: Vector3 = at[0]
	var size: float = at[1]
	var top := _fog_top
	var side := size * FOG_REACH
	fog_layer.size = Vector3(side, top - FOG_FLOOR, side)
	fog_layer.global_position = Vector3(focus.x, (top + FOG_FLOOR) * 0.5, focus.z)
	dust.global_position = Vector3(focus.x, DUST_Y, focus.z)
	var dm := dust.process_material as ParticleProcessMaterial
	var reach := size * DUST_REACH
	if absf(dm.emission_box_extents.x - reach) > 0.5:
		dm.emission_box_extents = Vector3(reach, DUST_HALF_HEIGHT, reach)


## Each ember emitter emits only while on and its light is shown; reduced motion freezes the motes.
func _sync() -> void:
	_calm = ViewPrefs.reduced_motion
	var speed := 0.0 if _calm else 1.0
	for k in embers.size():
		var em := embers[k]
		var lit := k < _lights.size() and is_instance_valid(_lights[k]) and _lights[k].visible
		var want := enabled and lit
		if em.emitting != want:
			em.emitting = want
		em.speed_scale = speed
	if dust != null:
		if dust.emitting != enabled:
			dust.emitting = enabled
		dust.speed_scale = speed


func _ember_mat() -> ParticleProcessMaterial:
	return embers[0].process_material as ParticleProcessMaterial if not embers.is_empty() else null


static func _ember_reach(mood: BiomeMood) -> float:
	return minf(mood.warm_light_range * EMBER_REACH, EMBER_REACH_MAX)


static func _ember_process(mood: BiomeMood) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	var reach := _ember_reach(mood)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(reach, EMBER_HALF_HEIGHT, reach)
	m.direction = Vector3(0, 1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.04
	m.initial_velocity_max = 0.22
	m.gravity = Vector3(0, 0.12, 0)  # embers rise, slowly
	m.damping_min = 0.02
	m.damping_max = 0.08
	m.scale_min = 0.5
	m.scale_max = 1.4
	m.color = mood.warm_light_color
	m.color_ramp = _fade_ramp()
	return m


static func _dust_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(15, DUST_HALF_HEIGHT, 15)
	m.direction = Vector3(1, 0, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.02
	m.initial_velocity_max = 0.09
	m.gravity = Vector3(0, -0.01, 0)  # dust settles, barely
	m.scale_min = 0.6
	m.scale_max = 1.3
	m.color_ramp = _fade_ramp()
	return m


## Alpha in, hold, out over a mote's life (no pop at birth or death).
static func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	g.colors = PackedColorArray(
		[Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A small additive camera-facing quad with a soft round dot, coloured by the particle.
static func _draw_mesh(size: float, tint: Color) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = tint
	mat.albedo_texture = _soft_dot()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	return q


static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot


## The camera's focus on the ground (its ray onto y = 0) and its ortho size; [] without a camera (StageKit._focus).
func _focus() -> Array:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return []
	var fwd := -cam.global_transform.basis.z
	var origin := cam.global_position
	var focus := origin
	if absf(fwd.y) > 0.001:
		focus = origin + fwd * (-origin.y / fwd.y)
	return [focus, cam.size if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else 30.0]
