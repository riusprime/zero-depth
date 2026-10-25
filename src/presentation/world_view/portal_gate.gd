class_name PortalGate
extends Node3D
## The gateway to the next floor. v0.9.0 PT (owner C1-C5, Q15: "shape it into a vertical oval shaped portal like rick
## and morty with a bit of random swirl at edges … and add some particles of the color portal"): no stone frame; the
## swirl (v0.2.0 L8's shader: fbm noise, two counter-rotating layers, three arms, a bright rim) fills a tall, narrow
## vertical oval OVAL_W × OVAL_H whose edge is never flat (noise round the rim, drifting with time), with a soft glow
## round it, its light, its floor glow and motes in its colour drifting off the rim.
## The swirl, its light and its floor glow are the hero visor's light blue (v0.3.5 PT, F19: ThemePalette
## "player_core"); set_deep() makes it the Deep gate (v0.5.0 RT): violet with a red rim on the swirl.
##
## Growth (Q15: "it should appear from a point and grow out of it in a circle that grows into the full oval … the
## edges should have an effect while they grow from that point like the cards burning but reversed, same way to
## dissapear, it collapses into a specific point"): form() runs 0 (nothing: hidden) .. 1 (the full oval). From a dot
## of light it grows as a circle the oval's width (up to CIRCLE_AT), then stretches to its full height, its edge a
## ragged glowing burn front (CardFx's BURN_SHADER, reversed) that calms once formed. Collapsing runs it backwards.
## form() = min(growth, 1 - collapse): growth comes from the sim (WorldReader.portal_form_progress: the hero can walk
## in once it is 1, EI-03); collapse from the way in (PortalTransitView) or, for the gate not taken, close() over
## CLOSE_SECONDS (presentation time: by then the sim has already closed it).
## Reduced motion (ViewPrefs): no growth or collapse of the shape: the full oval fades in and out, no motes.
## Presentation only (EI-07): it reads nothing from the sim and decides nothing.
##
## Local frame: the oval spans local Z (across) and Y (up), the gate faces local +X; setup() turns +X to the sim facing.

## v0.9.0 PT (starting values): the oval's width and height (m), its centre's height, and the quad it is drawn on
## (QUAD_MARGIN times the oval, room for the ragged edge and its glow).
const OVAL_W := 1.6
const OVAL_H := 3.4
const OVAL_Y := OVAL_H * 0.5 + 0.06
const QUAD_MARGIN := 1.4
## The growth's shape: a circle the oval's width by CIRCLE_AT, then the stretch to its full height from STRETCH_FROM.
const CIRCLE_AT := 0.45
const STRETCH_FROM := 0.35
## The burning edge fades out over the last part of the growth (from BURN_CALM_FROM).
const BURN_CALM_FROM := 0.82
## The burn's ember colour (CardFx's, mixed into the portal's own light shade by BURN_MIX).
const BURN_ORANGE := Color("#FF8A3D")
const BURN_MIX := 0.3
## The gate not taken closes over this long (presentation time; the sim closed it already).
const CLOSE_SECONDS := 0.6
const LIGHT_ENERGY_OPEN := 2.2
## The arrival portal's light (a later floor's step-out: PortalTransitView).
const LIGHT_ENERGY_ARRIVAL := 1.4
## The flare when the hero goes in: extra light energy, fading over FLARE_SECONDS.
const FLARE_ENERGY := 5.0
const FLARE_SECONDS := 1.2
## v0.5.0 RT, the Deep gate (starting values): violet swirl and light, a red rim.
const DEEP_VIOLET := Color("#8B3DFF")
const DEEP_RIM := Color("#FF2A3D")
## The rim motes: how many live at once, how long each lives (s), the points round the oval they leave from.
const MOTES := 28
const MOTE_LIFE := 1.5
const MOTE_POINTS := 40
## The motes emit only once the portal is (nearly) whole.
const MOTES_FROM := 0.97

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha, shadows_disabled, fog_disabled;

uniform vec2 quad_size = vec2(2.24, 4.76);
uniform vec2 half_now = vec2(0.8, 1.7);
uniform vec4 color_deep : source_color = vec4(0.03, 0.08, 0.52, 1.0);
uniform vec4 color_mid : source_color = vec4(0.13, 0.36, 1.0, 1.0);
uniform vec4 color_light : source_color = vec4(0.74, 0.9, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float swirl_speed = 1.0;
uniform float energy = 1.6;
uniform float burn = 0.0;
uniform float fade = 1.0;
uniform vec4 rim_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	// Metres from the oval's centre (y up), then the oval's own frame: 1 on its edge.
	vec2 p = (UV - 0.5) * quad_size * vec2(1.0, -1.0);
	vec2 hs = max(half_now, vec2(0.002));
	vec2 q = p / hs;
	float r = length(q);
	float t = TIME * swirl_speed * 1.25;
	// The edge swirls: noise round the rim (seamless round the angle) drifting with time, never a flat border.
	float ang = atan(q.y, q.x);
	vec2 ring = vec2(cos(ang), sin(ang));
	float wob = (fbm(ring * 1.7 + vec2(t * 0.32, -t * 0.21)) - 0.5) * 0.2 + 0.03 * sin(ang * 7.0 - t * 2.4);
	// CardFx's burn front, reversed: while forming the edge is ragged by a finer noise and glows like an ember.
	float bn = vnoise(p * 5.0 + vec2(t * 0.6, -t * 0.4)) * 0.32 + vnoise(p * 13.0) * 0.14;
	float edge = 1.0 + wob - burn * (bn - 0.12);
	float d = edge - r;
	// Outside the edge: a soft glow (metres: it keeps its width as the oval grows), else nothing.
	float dm = -d * min(hs.x, hs.y);
	float halo = d < 0.0 ? 1.0 - smoothstep(0.0, 0.16 + 0.22 * burn, dm) : 0.0;
	if (d < 0.0 && halo <= 0.002) {
		discard;
	}
	// Two noise layers twisted into a vortex that turns faster near the centre.
	vec2 s1 = rot(q, t * 1.3 + 1.4 / (r + 0.45));
	vec2 s2 = rot(q, -t * 0.7 + 0.9 / (r + 0.6));
	float n1 = fbm(s1 * 2.2 + vec2(0.0, t * 0.15));
	float n2 = fbm(s2 * 3.6 - vec2(t * 0.1, 0.0));
	// Spiral arms: bands that wind round the centre.
	float arms = 0.5 + 0.5 * sin(ang * 3.0 + log(r + 0.05) * 5.0 - t * 4.0 + n1 * 3.0);
	float v = clamp(arms * 0.6 + n1 * 0.5 + n2 * 0.25 - 0.2, 0.0, 1.0);
	vec3 col = mix(color_deep.rgb, color_mid.rgb, smoothstep(0.15, 0.6, v));
	col = mix(col, color_light.rgb, smoothstep(0.62, 0.95, v));
	// A lighter core and a bright rim along the edge.
	float core = 1.0 - smoothstep(0.0, 0.55, r);
	col = mix(col, color_light.rgb, core * 0.75);
	float rim = 1.0 - smoothstep(0.0, 0.16, d + (n2 - 0.5) * 0.06);
	vec3 rim_col = mix(color_light.rgb * 1.4, rim_color.rgb * 1.6, rim_color.a);
	col = mix(col, rim_col, rim * 0.9);
	// The burning edge: a hot band just inside the front while it grows or collapses.
	float ember = burn * (1.0 - smoothstep(0.0, 0.1 + 0.12 * burn, d));
	col = mix(col, edge_color.rgb * 1.8, ember);
	col *= energy * 1.15;
	if (d < 0.0) {
		vec3 glow = mix(rim_col, edge_color.rgb * 1.6, burn);
		ALBEDO = glow * energy;
		ALPHA = fade * halo * (0.5 + 0.3 * burn);
	} else {
		ALBEDO = col;
		ALPHA = fade * mix(0.6, 1.0, smoothstep(0.0, 0.06, d));
	}
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(0.16, 0.36, 1.0, 1.0);
uniform float strength = 0.55;

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float a = pow(1.0 - smoothstep(0.0, 1.0, r), 1.6);
	ALBEDO = glow_color.rgb * a * strength;
}
"""

var portal: MeshInstance3D
var portal_material: ShaderMaterial
var glow_material: ShaderMaterial
var glow_disc: MeshInstance3D
var light: OmniLight3D
## v0.9.0 PT: the motes drifting off the rim, in the portal's colour.
var motes: CPUParticles3D
## v0.5.0 RT: the Deep gate's look is on.
var deep := false
## v0.9.0 PT: a later floor's arrival portal (PortalTransitView): no floor glow or motes, a softer light.
var arrival := false
## v0.9.0 PT: the growth (0..1, the sim's forming) and the collapse (0 whole .. 1 gone to a point).
var growth := 0.0
var collapse := 0.0
var _sealed := true
var _closing := false
var _flare := 0.0
var _mote_ramp := Gradient.new()


## The visor's light blue (v0.3.5 PT), and the swirl's shades of it, dark to light.
static func visor_blue() -> Color:
	return ThemePalette.color(&"player_core")


static func swirl_colors() -> Array[Color]:
	var c := visor_blue()
	return [c.darkened(0.78), c, c.lightened(0.78)]


static func deep_colors() -> Array[Color]:
	return [DEEP_VIOLET.darkened(0.75), DEEP_VIOLET, DEEP_VIOLET.lightened(0.55)]


## v0.9.0 PT: the oval's half extents (m: across, up) at form `f` (0..1): a point, a circle the oval's width by
## CIRCLE_AT, then stretched to the full height. Reduced motion (`calm`) keeps the full oval (it fades instead).
static func half_extents(f: float, calm: bool = false) -> Vector2:
	if calm:
		return Vector2(OVAL_W, OVAL_H) * 0.5
	var a := smoothstep(0.0, CIRCLE_AT, f)
	var b := smoothstep(STRETCH_FROM, 1.0, f)
	return Vector2(OVAL_W * 0.5 * a, lerpf(OVAL_W * 0.5, OVAL_H * 0.5, b) * a)


func _init() -> void:
	_build_portal()
	_build_glow()
	_build_motes()
	_apply()


## Places the gate at `sim_pos` facing the sim direction `facing_angle` (1/4096 turn).
func setup(sim_pos: Vector2, facing_angle: int) -> void:
	position = SimPlane.to_3d(sim_pos)
	rotation = Vector3(0, SimPlane.yaw_of(facing_angle), 0)


## v0.5.0 RT: the Deep gate's colours (once, at setup).
func set_deep() -> void:
	if deep:
		return
	deep = true
	var shades := deep_colors()
	portal_material.set_shader_parameter("color_deep", shades[0])
	portal_material.set_shader_parameter("color_mid", shades[1])
	portal_material.set_shader_parameter("color_light", shades[2])
	portal_material.set_shader_parameter("rim_color", Color(DEEP_RIM, 1.0))
	portal_material.set_shader_parameter("edge_color", DEEP_RIM.lerp(BURN_ORANGE, BURN_MIX))
	light.light_color = DEEP_VIOLET
	glow_material.set_shader_parameter("glow_color", DEEP_VIOLET)
	_tint_motes(DEEP_VIOLET)


## v0.9.0 PT: a later floor's arrival portal (no floor glow, no motes, a softer light).
func set_arrival() -> void:
	arrival = true
	glow_disc.visible = false
	_apply()


## The portal's own colour (its light's).
func portal_color() -> Color:
	return light.light_color


## Sealed: the sim hasn't opened it (the boss lives), or it closed (the other gate was taken). Opening shows it at
## its growth (set_growth); sealing an open gate collapses it into a point over CLOSE_SECONDS.
func set_sealed(sealed: bool) -> void:
	if sealed and not _sealed:
		_closing = is_inside_tree() and form() > 0.0
		if not _closing:
			collapse = 1.0
	elif not sealed:
		_closing = false
		collapse = 0.0
	_sealed = sealed
	_apply()


func is_sealed() -> bool:
	return _sealed


## v0.9.0 PT: the growth from the sim (0..1; WorldReader.portal_form_progress).
func set_growth(k: float) -> void:
	growth = clampf(k, 0.0, 1.0)
	_apply()


## v0.9.0 PT: the collapse (0 whole .. 1 gone to a point): the way in (PortalTransitView), the arrival's end.
func set_collapse(k: float) -> void:
	collapse = clampf(k, 0.0, 1.0)
	_apply()


## v0.9.0 PT: how formed the portal is now (0 nothing .. 1 the full oval).
func form() -> float:
	return minf(growth, 1.0 - collapse)


## Shown at all (a point of light or more).
func is_shown() -> bool:
	return visible


## A flare of light (the hero going in: PortalTransitView).
func flare() -> void:
	_flare = FLARE_SECONDS


func _process(delta: float) -> void:
	if _closing:
		collapse = minf(1.0, collapse + delta / CLOSE_SECONDS)
		_closing = collapse < 1.0
		_apply()
	if _flare <= 0.0:
		return
	_flare = maxf(0.0, _flare - delta)
	_apply()


## Shows the oval at form(): its shape and burning edge (or, with reduced motion, its fade), its light, its floor
## glow and whether the motes emit.
func _apply() -> void:
	var calm := ViewPrefs.reduced_motion
	var f := form()
	visible = f > 0.0
	var hs := half_extents(f, calm)
	portal_material.set_shader_parameter("half_now", hs)
	portal_material.set_shader_parameter(
		"burn", 0.0 if calm else 1.0 - smoothstep(BURN_CALM_FROM, 1.0, f)
	)
	portal_material.set_shader_parameter("fade", smoothstep(0.0, 1.0, f) if calm else 1.0)
	var k := _flare / FLARE_SECONDS
	var base := LIGHT_ENERGY_ARRIVAL if arrival else LIGHT_ENERGY_OPEN
	# The light grows with the oval, from the dot of light up.
	light.light_energy = base * (0.35 + 0.65 * f) * (1.0 if f > 0.0 else 0.0) + FLARE_ENERGY * k * k
	glow_material.set_shader_parameter("strength", 0.55 * f + 0.6 * k)
	motes.emitting = visible and not arrival and not calm and f >= MOTES_FROM


func _build_portal() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(OVAL_W, OVAL_H) * QUAD_MARGIN
	portal_material = ShaderMaterial.new()
	portal_material.shader = Shader.new()
	portal_material.shader.code = SHADER
	portal_material.set_shader_parameter("quad_size", quad.size)
	var shades := swirl_colors()
	portal_material.set_shader_parameter("color_deep", shades[0])
	portal_material.set_shader_parameter("color_mid", shades[1])
	portal_material.set_shader_parameter("color_light", shades[2])
	portal_material.set_shader_parameter("edge_color", shades[2].lerp(BURN_ORANGE, BURN_MIX))
	portal = MeshInstance3D.new()
	portal.name = "Oval"
	portal.mesh = quad
	portal.material_override = portal_material
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quad faces +Z; a quarter turn makes it face the gate's +X, spanning local Z.
	portal.rotation = Vector3(0, PI * 0.5, 0)
	portal.position = Vector3(0, OVAL_Y, 0)
	add_child(portal)
	light = OmniLight3D.new()
	light.light_color = visor_blue()
	light.omni_range = 5.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0.9, 1.5, 0)
	add_child(light)


func _build_glow() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.6, 3.0)
	glow_material = ShaderMaterial.new()
	glow_material.shader = Shader.new()
	glow_material.shader.code = GLOW_SHADER
	glow_material.set_shader_parameter("glow_color", visor_blue())
	glow_disc = MeshInstance3D.new()
	glow_disc.mesh = plane
	glow_disc.material_override = glow_material
	glow_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Mostly in front of the gate (+X), a little behind it.
	glow_disc.position = Vector3(0.6, 0.02, 0)
	add_child(glow_disc)


## v0.9.0 PT (Q15: "add some particles of the color portal"): motes leave points round the oval and drift out and
## up, fading, in the portal's colour; local to the gate (they stand with it).
func _build_motes() -> void:
	motes = CPUParticles3D.new()
	motes.name = "RimMotes"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = FxTextures.soft_dot()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = mat
	motes.mesh = quad
	motes.amount = MOTES
	motes.lifetime = MOTE_LIFE
	motes.local_coords = true
	motes.emitting = false
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in MOTE_POINTS:
		var a := TAU * float(i) / float(MOTE_POINTS)
		var out := Vector2(cos(a), sin(a))
		points.append(Vector3(0.04, OVAL_Y + out.y * OVAL_H * 0.5, out.x * OVAL_W * 0.5))
		normals.append(Vector3(0.25, out.y, out.x).normalized())
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	motes.emission_points = points
	motes.emission_normals = normals
	motes.spread = 25.0
	motes.initial_velocity_min = 0.12
	motes.initial_velocity_max = 0.4
	motes.gravity = Vector3(0, 0.22, 0)
	motes.damping_min = 0.1
	motes.damping_max = 0.3
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.5
	motes.color_ramp = _mote_ramp
	add_child(motes)
	_tint_motes(visor_blue())


func _tint_motes(c: Color) -> void:
	_mote_ramp.set_color(0, Color(c.lightened(0.55), 0.95))
	_mote_ramp.set_color(1, Color(c, 0.0))
