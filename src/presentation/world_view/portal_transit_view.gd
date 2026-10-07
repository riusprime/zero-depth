class_name PortalTransitView
extends Node3D
## The portal's way in and the arrival on a new floor (v0.3.5 PT; owner F19, F20), in the visor's light blue.
## Way in (~1.0 s): the hero is drawn to the portal's centre, spins, and shrinks into light-blue motes with a flash.
## Arrival (~0.8 s): a light-blue column stands on the hero's spot and the hero materialises from the same motes.
## Reduced motion (ViewPrefs): no pull, spin or motes; the screen fades out on the way in and in on the arrival.
## Presentation only (EI-07): the sim owns both lengths in ticks (BossFlow: the world holds still, input is ignored,
## EI-03); sync() reads the progress through WorldReader and only poses the hero's model and these effects.
## Cheap: two small one-shot CPU particle bursts, one light, two meshes; every material is built once here and only
## its colour or a uniform changes afterwards (never a feature flag: the damage-lag rule).

## The phase showing (tests read it): none, the way in, the arrival.
enum Phase { NONE, ENTER, ARRIVE }

## Way in (fractions of the progress): the pull ends, the shrink runs, the motes burst, the flash peaks.
const PULL_END := 0.55
const SHRINK_FROM := 0.45
const SHRINK_TO := 0.85
const BURST_AT := 0.6
const FLASH_AT := 0.82
const FLASH_WIDTH := 0.18
## Turns the hero spins on the way in, and on the arrival (unwinding).
const SPINS_IN := 3.0
const SPINS_OUT := 1.5
## How far in front of the gate's centre line (m) the hero is drawn to, and how high it rises.
const PULL_DEPTH := 0.3
const LIFT := 0.45
## Arrival: the hero grows over this part of the progress; the column fades out after COLUMN_FADE.
const GROW_FROM := 0.2
const GROW_TO := 0.8
const COLUMN_FADE := 0.7
const COLUMN_HEIGHT := 5.0
const COLUMN_RADIUS := 0.6
const MOTES := 28
const LIGHT_ENERGY := 6.0
## The screen flash at its peak (alpha), and the reduced-motion fade colour.
const SCREEN_FLASH := 0.35
const FADE_COLOR := Color(0.0, 0.0, 0.0)

const COLUMN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.17, 0.77, 0.89, 1.0);
uniform float strength = 0.0;

void fragment() {
	// Bright at the foot, gone at the top; brighter at the silhouette's edges.
	float up = 1.0 - UV.y;
	float fall = 1.0 - smoothstep(0.0, 1.0, 1.0 - UV.y);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = tint.rgb * strength * (0.35 + 0.9 * rim) * (0.25 + 1.2 * fall * fall) * (0.6 + 0.4 * up);
}
"""

var phase := Phase.NONE
## The progress last read from the sim (0..1).
var progress := 0.0
var calm := false
var motes_out := CPUParticles3D.new()
var motes_in := CPUParticles3D.new()
var column := MeshInstance3D.new()
var flash_ball := MeshInstance3D.new()
var light := OmniLight3D.new()
var overlay := ColorRect.new()

var _actors: ActorViews
var _gate: PortalGate
var _blue := PortalGate.visor_blue()
var _column_mat := ShaderMaterial.new()
var _flash_mat := StandardMaterial3D.new()
var _mote_mat := StandardMaterial3D.new()
var _layer := CanvasLayer.new()
var _burst_done := false
var _hidden: Array[Node3D] = []


func _init() -> void:
	name = "PortalTransit"
	_build()


func setup(p_actors: ActorViews, p_gate: PortalGate) -> void:
	_actors = p_actors
	_gate = p_gate


## Reads the transit after a tick and poses the hero and the effects for it.
func sync(reader: WorldReader) -> void:
	var enter := reader.portal_enter_progress()
	var arrive := reader.arrival_progress()
	var was := phase
	calm = ViewPrefs.reduced_motion
	if enter >= 0.0:
		phase = Phase.ENTER
		progress = enter
	elif arrive >= 0.0:
		phase = Phase.ARRIVE
		progress = arrive
	else:
		phase = Phase.NONE
		progress = 0.0
	if phase != was:
		_burst_done = false
		if phase == Phase.ENTER and _gate != null:
			_gate.flare()
	var node := _player_node(reader)
	var avatar := (
		node.get_meta(&"avatar") as Node3D if node != null and node.has_meta(&"avatar") else null
	)
	match phase:
		Phase.ENTER:
			_hide_extras(node, avatar)
			_enter(reader, node, avatar)
		Phase.ARRIVE:
			_hide_extras(node, avatar)
			_arrive(node, avatar)
		_:
			if was != Phase.NONE:
				_rest(avatar)


## The hero model's root (ActorViews), or null.
func _player_node(reader: WorldReader) -> Node3D:
	if _actors == null or reader.actor_count() == 0:
		return null
	return _actors.actor_node(reader.actor_id(0))


func _enter(reader: WorldReader, node: Node3D, avatar: Node3D) -> void:
	var p := progress
	column.visible = false
	if calm:
		_set_overlay(FADE_COLOR, smoothstep(0.0, 1.0, p))
		_set_light(0.0)
		flash_ball.visible = false
		if avatar != null:
			avatar.visible = p < 1.0
		return
	var centre := SimPlane.to_3d(reader.portal_pos() + Kin.dir(reader.portal_angle()) * PULL_DEPTH)
	var start := node.position if node != null else centre
	if avatar != null:
		var pull := smoothstep(0.0, PULL_END, p)
		avatar.position = (centre - start) * pull
		avatar.position.y = LIFT * smoothstep(0.2, 0.7, p)
		avatar.rotation = Vector3(0, TAU * SPINS_IN * p * p, 0)
		var size := 1.0 - smoothstep(SHRINK_FROM, SHRINK_TO, p)
		avatar.scale = Vector3.ONE * maxf(size, 0.001)
		avatar.visible = size > 0.01
	var at := centre + Vector3(0, 1.0, 0)
	if p >= BURST_AT and not _burst_done:
		_burst_done = true
		motes_out.position = at
		motes_out.restart()
	var f := maxf(0.0, 1.0 - absf(p - FLASH_AT) / FLASH_WIDTH)
	flash_ball.visible = f > 0.0
	flash_ball.position = at
	flash_ball.scale = Vector3.ONE * (0.2 + 1.1 * f)
	_flash_mat.albedo_color = Color(_blue.lightened(0.6), 0.85 * f)
	light.position = at
	_set_light(LIGHT_ENERGY * f)
	_set_overlay(_blue.lightened(0.5), SCREEN_FLASH * f * f)


func _arrive(node: Node3D, avatar: Node3D) -> void:
	var q := progress
	var foot := node.position if node != null else Vector3.ZERO
	flash_ball.visible = false
	if calm:
		column.visible = false
		_set_light(0.0)
		_set_overlay(FADE_COLOR, 1.0 - smoothstep(0.0, 1.0, q))
		if avatar != null:
			avatar.visible = true
		return
	_set_overlay(FADE_COLOR, 0.0)
	var c := smoothstep(0.0, 0.15, q) * (1.0 - smoothstep(COLUMN_FADE, 1.0, q))
	column.visible = c > 0.0
	column.position = foot + Vector3(0, COLUMN_HEIGHT * 0.5, 0)
	_column_mat.set_shader_parameter("strength", 1.4 * c)
	light.position = foot + Vector3(0, 1.2, 0)
	_set_light(LIGHT_ENERGY * 0.6 * c)
	if not _burst_done:
		_burst_done = true
		motes_in.position = foot + Vector3(0, 0.9, 0)
		motes_in.restart()
	if avatar != null:
		var grow := smoothstep(GROW_FROM, GROW_TO, q)
		avatar.position = Vector3(0, 0.6 * (1.0 - grow), 0)
		avatar.rotation = Vector3(0, TAU * SPINS_OUT * (1.0 - grow) * (1.0 - grow), 0)
		avatar.scale = Vector3.ONE * maxf(grow, 0.001)
		avatar.visible = grow > 0.01


## Back to normal: the hero's model and its ring and bar as ActorViews leaves them, the effects off.
func _rest(avatar: Node3D) -> void:
	if avatar != null:
		avatar.position = Vector3.ZERO
		avatar.rotation = Vector3.ZERO
		avatar.scale = Vector3.ONE
		avatar.visible = true
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	column.visible = false
	flash_ball.visible = false
	_set_light(0.0)
	_set_overlay(FADE_COLOR, 0.0)


## The contact disc, team ring and HP bar stay off while the hero is not all there.
func _hide_extras(node: Node3D, avatar: Node3D) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Node3D and child != avatar:
			(child as Node3D).visible = false
			if not _hidden.has(child):
				_hidden.append(child)


func _set_light(energy: float) -> void:
	light.light_energy = energy
	light.visible = energy > 0.0


func _set_overlay(c: Color, alpha: float) -> void:
	overlay.color = Color(c, clampf(alpha, 0.0, 1.0))
	overlay.visible = alpha > 0.001


func _build() -> void:
	_column_mat.shader = Shader.new()
	_column_mat.shader.code = COLUMN_SHADER
	_column_mat.set_shader_parameter("tint", _blue)
	var cyl := CylinderMesh.new()
	cyl.top_radius = COLUMN_RADIUS * 0.7
	cyl.bottom_radius = COLUMN_RADIUS
	cyl.height = COLUMN_HEIGHT
	cyl.cap_top = false
	cyl.cap_bottom = false
	column.mesh = cyl
	column.material_override = _column_mat
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.visible = false
	add_child(column)
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(_blue.lightened(0.6), 0.0)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	flash_ball.mesh = ball
	flash_ball.material_override = _flash_mat
	flash_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_ball.visible = false
	add_child(flash_ball)
	light.light_color = _blue
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	_mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mote_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mote_mat.vertex_color_use_as_albedo = true
	_mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	quad.material = _mote_mat
	var fade := Gradient.new()
	fade.set_color(0, Color(_blue.lightened(0.7), 1.0))
	fade.set_color(1, Color(_blue, 0.0))
	# Out: a burst from the hero's last spot, rising and spreading. In: a ring of motes pulled to the hero's spot.
	for m: CPUParticles3D in [motes_out, motes_in]:
		m.mesh = quad
		m.amount = MOTES
		m.one_shot = true
		m.emitting = false
		m.explosiveness = 0.85
		m.lifetime = 0.7
		m.local_coords = false
		m.color_ramp = fade
		m.scale_amount_min = 0.6
		m.scale_amount_max = 1.4
		add_child(m)
	motes_out.direction = Vector3.UP
	motes_out.spread = 180.0
	motes_out.initial_velocity_min = 1.2
	motes_out.initial_velocity_max = 3.0
	motes_out.gravity = Vector3(0, 1.5, 0)
	motes_out.damping_min = 1.5
	motes_out.damping_max = 2.5
	motes_in.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	motes_in.emission_sphere_radius = 1.3
	motes_in.radial_accel_min = -9.0
	motes_in.radial_accel_max = -6.0
	motes_in.gravity = Vector3.ZERO
	motes_in.lifetime = 0.6
	_layer.layer = 0
	add_child(_layer)
	overlay.name = "TransitOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	_layer.add_child(overlay)
