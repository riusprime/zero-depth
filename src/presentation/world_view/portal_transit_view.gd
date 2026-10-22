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
## v0.8.0 N11 (owner O69: "the screen shakes a little bit and wobbles, and then zoom, the main character pops, and …
## you feel it"): on a floor with a receiver (FloorReceiver) the arrival plays on it instead of the column, after the
## loading cover has opened (Main holds the sim until then):
## - floor 1 of a run: v0.9.0 SA (owner C §2, Q16: 4.0 s) plays it on the arrival altar (AltarStage) instead, below;
## - a later floor (~0.8 s, after the portal's iris opened): the receiver flares and the hero rises out of it with a
##   small burst and kick;
## - reduced motion: no shake, wobble, zoom or rise: the receiver's light flares and fades and the hero appears in it.
## The view's roll and zoom are IsoRig's flourish (off with shake off, like the shake and the kick).
## v0.9.0 SA (owner C §2: "1. Idle … 2. Activation … 3. Rotation … 4. Energy buildup … 5. Spawn … 6. Release"; "The
## shaking should increase slightly during the buildup and peak at the spawn, then fade out naturally"): floor 1 of a
## run lands on the altar (AltarStage.arrival's timeline, over the 4.0 s arrival): the empty altar; its runes and jewels
## light one after another; the runes orbit, faster and faster; the buildup (particles, the centre swirl, the glow, the
## hum: AudioEvents' arrival cue) with the vibration climbing and a slow zoom in; the existing pop (the overshoot, the
## flash, the burst ring, dust) on the sound's peak with a thud; then the release (the runes slow, the energy fades, the
## view settles). No roll wobble (it read as a sideways pull). Reduced motion: the runes just light and the hero
## appears (no orbit, vibration or zoom).

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
## v0.8.0 N11 (fractions of the arrival's progress): the pop's ring lasts BURST_SPAN. A later floor's flare ends at
## STEP_FLARE_END, the hero rises over STEP_RISE_FROM..STEP_RISE_TO from STEP_DEPTH m under the floor.
## v0.9.0 SA: floor 1's timeline is the altar's (AltarStage.Look: the pop at pop_at); the zoom climbs ZOOM_IN through
## its buildup and eases out over the release.
const ZOOM_IN := 0.14
const BURST_SPAN := 0.32
const POP_OVERSHOOT := 3.0
const TREMBLE := 0.08
const TREMBLE_PEAK := 0.32
## v0.9.0 CV (owner Q17): the arrival vibrates instead of shaking and kicking: the build-up's level climbs from
## TREMBLE to TREMBLE_PEAK, the pop and a later floor's step-out each land a thud.
const POP_THUD := 0.9
const STEP_FLARE_END := 0.3
const STEP_RISE_FROM := 0.22
const STEP_RISE_TO := 0.72
const STEP_DEPTH := 1.1
const STEP_THUD := 0.4
## v0.9.0 CV: the Ascension portal's pull vibrates up to this level (the final-boss travel).
const ASCENSION_VIBRATE := 0.5
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
## v0.5.0 RT: the Deep gate (null without one); the way in flares and draws the hero to the gate taken.
var deep_gate: PortalGate
## v0.7.5 AP: the Ascension portal (null on other floors); the way in flares it and flashes in its gold.
var ascension: AscensionPortal
## v0.8.0 P2 (owner O28): the Loop device (null on other floors); stepping onto it flares it and flashes in its green.
var loop_device: LoopDevice
## v0.8.0 N11 (O69): the floor's receiver (null without one: the final arena, the Playground) and the view's rig.
var receiver: FloorReceiver
## v0.9.0 SA: floor 1's arrival altar (null on other floors).
var altar: AltarStage
var rig: IsoRig
## v0.8.0 N11: this arrival is floor 1's (the big landing), and whether the hero has popped in (tests read both).
var first := false
var landed := false

var _actors: ActorViews
var _gate: PortalGate
var _blue := PortalGate.visor_blue()
## v0.7.5 AP: the way in's flash colour (the visor blue; the Ascension portal's gold through it).
var _flash := PortalGate.visor_blue()
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
		landed = false
		first = reader.arrival_first()
		var deep := reader.route_taken() == WorldReader.ROUTE_DEEP and deep_gate != null
		var taken := deep_gate if deep else _gate
		if phase == Phase.ENTER and taken != null:
			taken.flare()
		_flash = PortalGate.visor_blue()
		var looped := reader.ascension_choice() == WorldReader.ASCEND_LOOP
		if phase == Phase.ENTER and looped and loop_device != null:  # v0.8.0 P2
			loop_device.flare()
			_flash = LoopDevice.flash_color()
		elif phase == Phase.ENTER and ascension != null:  # v0.7.5 AP
			ascension.flare()
			_flash = AscensionPortal.flash_color()
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
			if receiver != null or altar != null:
				_land(avatar)
			else:
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
	if rig != null and ascension != null and reader.ascension_choice() != WorldReader.ASCEND_LOOP:
		rig.vibrate_to(ASCENSION_VIBRATE * smoothstep(0.0, FLASH_AT, p))  # v0.9.0 CV: the final-boss travel
	var centre := SimPlane.to_3d(
		reader.entered_portal_pos() + Kin.dir(reader.entered_portal_angle()) * PULL_DEPTH
	)
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
	_flash_mat.albedo_color = Color(_flash.lightened(0.6), 0.85 * f)
	light.position = at
	light.light_color = _flash
	_set_light(LIGHT_ENERGY * f)
	_set_overlay(_flash.lightened(0.5), SCREEN_FLASH * f * f)


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


## v0.8.0 N11: the arrival on the floor's receiver (see the header): floor 1's landing, a later floor's step-out, or
## reduced motion's flare.
func _land(avatar: Node3D) -> void:
	var q := progress
	column.visible = false
	if altar != null:  # v0.9.0 SA: floor 1
		_land_first(avatar, q)
		return
	var foot := receiver.position
	if calm:
		receiver.set_charge(1.0 - q)
		receiver.set_burst(-1.0)
		flash_ball.visible = false
		_set_light(0.0)
		_set_overlay(FloorReceiver.CORE, 0.22 * (1.0 - q))
		if avatar != null:
			_pose(avatar, Vector3.ZERO, 1.0, q >= 0.3)
		landed = q >= 0.3
		return
	_step_out(avatar, q, foot)


## v0.9.0 SA: floor 1 on the altar (see the header): the altar's own timeline, the vibration climbing through its
## buildup, the zoom, the pop with its thud, the release. Reduced motion: the runes light (AltarStage.calm) and the
## hero appears.
func _land_first(avatar: Node3D, q: float) -> void:
	var l := altar.look
	var pop := l.pop_at
	var foot := altar.position
	altar.calm = calm
	altar.pose(q)
	if calm:
		altar.set_burst(-1.0)
		flash_ball.visible = false
		_set_light(0.0)
		_set_overlay(l.core, 0.18 * (1.0 - q))
		if avatar != null:
			_pose(avatar, Vector3.ZERO, 1.0, q >= 0.3)
		landed = q >= 0.3
		return
	if rig != null:
		var zoom := (
			1.0 + ZOOM_IN * smoothstep(l.buildup_from, pop, q) * (1.0 - smoothstep(pop, 1.0, q))
		)
		rig.set_flourish(0.0, zoom)
		if q < pop:
			var b := smoothstep(l.buildup_from, pop, q)
			rig.vibrate_to(
				(
					TREMBLE * smoothstep(l.orbit_from, l.buildup_from, q)
					+ (TREMBLE_PEAK - TREMBLE) * b * b
				)
			)
	if q < pop:
		altar.set_burst(-1.0)
		flash_ball.visible = false
		_set_light(0.0)
		_set_overlay(FADE_COLOR, 0.0)
		if avatar != null:
			_pose(avatar, Vector3.ZERO, 0.001, false)
		return
	var u := clampf((q - pop) / l.pop_span, 0.0, 1.0)
	if not landed:
		landed = true
		altar.puff()
		if rig != null:
			rig.thud(POP_THUD)  # the peak: it eases out by itself
	altar.set_burst((q - pop) / l.burst_span)
	var f := 1.0 - smoothstep(0.0, 0.5, u)
	_flash_at(foot + Vector3(0, 0.9, 0), f, l.core, 0.4)
	if avatar != null:
		_pose(avatar, Vector3.ZERO, _overshoot(u, POP_OVERSHOOT), true)


## A later floor: the receiver flares and the hero rises out of it.
func _step_out(avatar: Node3D, q: float, foot: Vector3) -> void:
	if rig != null:
		rig.set_flourish(0.0, 1.0)
	receiver.set_charge(
		smoothstep(0.0, STEP_FLARE_END, q) * (1.0 - smoothstep(STEP_FLARE_END, 1.0, q))
	)
	var rise := smoothstep(STEP_RISE_FROM, STEP_RISE_TO, q)
	if q >= STEP_RISE_FROM and not landed:
		landed = true
		receiver.puff()
		if rig != null:
			rig.thud(STEP_THUD)
	receiver.set_burst((q - STEP_RISE_FROM) / BURST_SPAN if landed else -1.0)
	var f := 1.0 - smoothstep(STEP_RISE_FROM, STEP_RISE_FROM + 0.2, q) if landed else 0.0
	_flash_at(foot + Vector3(0, 0.6, 0), f, FloorReceiver.CORE, 0.2)
	if avatar != null:
		var s := 0.6 + 0.4 * rise
		_pose(avatar, Vector3(0, -STEP_DEPTH * (1.0 - rise), 0), s, landed)


## The hero model's pose for the landing: offset, uniform size, shown.
func _pose(avatar: Node3D, at: Vector3, size: float, shown: bool) -> void:
	avatar.position = at
	avatar.rotation = Vector3.ZERO
	avatar.scale = Vector3.ONE * maxf(size, 0.001)
	avatar.visible = shown


## The flash ball, the light and the screen flash at `f` (0..1) in colour `c`, the screen's at `screen` alpha at most.
func _flash_at(at: Vector3, f: float, c: Color, screen: float) -> void:
	flash_ball.visible = f > 0.0
	flash_ball.position = at
	flash_ball.scale = Vector3.ONE * (0.3 + 1.6 * (1.0 - f))
	_flash_mat.albedo_color = Color(c, 0.8 * f)
	light.position = at
	light.light_color = c
	_set_light(LIGHT_ENERGY * f)
	_set_overlay(c, screen * f * f)


## An overshooting ease (0..1 → 0..1, past 1 on the way): the pop's punch.
static func _overshoot(u: float, k: float) -> float:
	var v := u - 1.0
	return 1.0 + (k + 1.0) * v * v * v + k * v * v


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
	if receiver != null:  # v0.8.0 N11: the receiver back at rest, the view settled
		receiver.set_charge(0.0)
		receiver.set_burst(-1.0)
	if altar != null:  # v0.9.0 SA: the altar at rest, its runes dimly lit
		altar.pose(-1.0)
		altar.set_burst(-1.0)
	if rig != null:
		rig.set_flourish(0.0, 1.0)


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
