class_name AffinityRunes
extends Node3D
## v0.9.0 RB (owner, PLAN "Owner decisions" RB: "The rune could be under the feet matching the color of the element
## being used" and "Rune on the robe's back"; the VX bar: "every VFX has a high quality layered effect"): the hero's
## rune affinity drawn twice in its colour, none for None.
## - Under the feet: a rune circle, layered: a soft ground glow (halo), the circle itself (a white-hot core line over
##   a coloured glow: two rings, a band of 24 rune strokes, the affinity's glyph in the middle, a shimmer running round
##   it), a small light, and motes rising off the ring. It turns slowly and breathes.
## - On the robe's back (PlayerAvatar places `back` on the cloak each frame): the glyph alone in a thin ring, over a
##   glow, pulsing gently.
## Effects density (ViewPrefs.effects_density): Low keeps both shapes (circle, glyph, halo) and drops the motes and the
## light; Medium halves the motes. Reduced motion stills the turn and the pulses.
## A5 Guardian: the ward up, the circle burns full; spent, it dims (WARD_SPENT); the tick it breaks, a gold ring flashes
## out from the feet (FLASH_SECONDS). Presentation only (EI-07): set from values the avatar reads.

## The glyphs (AffinityDefinition.glyph): 0 none, 1 ember (a flame), 2 storm (a bolt), 3 venom (a drop), 4 astral (a
## four-point star), 5 guardian (a shield).
const GLYPHS := 6
const CIRCLE_M := 1.25
const HALO_M := 2.1
const BACK_M := 0.17
const MOTES_HIGH := 14
const LIGHT_ENERGY := 0.55
const WARD_SPENT := 0.38
const FLASH_SECONDS := 0.5

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.67, 0.2, 1.0);
uniform int glyph = 1;
// 0: the circle under the feet, 1: the glyph on the back, 2: the soft ground glow, 3: the ward's flash ring.
uniform int mode = 0;
uniform float strength = 1.0;
uniform float spin = 0.0;
uniform float pulse = 1.0;
uniform float flash = 0.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float ring(vec2 p, float r) {
	return abs(length(p) - r);
}

float glyph_d(vec2 p, int g) {
	float d = 10.0;
	if (g == 1) {
		d = min(d, seg(p, vec2(0.0, 0.72), vec2(0.3, 0.12)));
		d = min(d, seg(p, vec2(0.3, 0.12), vec2(0.26, -0.34)));
		d = min(d, seg(p, vec2(0.26, -0.34), vec2(0.0, -0.58)));
		d = min(d, seg(p, vec2(0.0, -0.58), vec2(-0.26, -0.34)));
		d = min(d, seg(p, vec2(-0.26, -0.34), vec2(-0.3, 0.12)));
		d = min(d, seg(p, vec2(-0.3, 0.12), vec2(0.0, 0.72)));
		d = min(d, seg(p, vec2(0.0, 0.18), vec2(0.12, -0.2)));
		d = min(d, seg(p, vec2(0.12, -0.2), vec2(0.0, -0.36)));
		d = min(d, seg(p, vec2(0.0, -0.36), vec2(-0.12, -0.2)));
		d = min(d, seg(p, vec2(-0.12, -0.2), vec2(0.0, 0.18)));
	} else if (g == 2) {
		d = min(d, seg(p, vec2(0.26, 0.74), vec2(-0.16, 0.06)));
		d = min(d, seg(p, vec2(-0.16, 0.06), vec2(0.16, 0.06)));
		d = min(d, seg(p, vec2(0.16, 0.06), vec2(-0.26, -0.74)));
		d = min(d, seg(p, vec2(-0.42, 0.42), vec2(-0.26, 0.3)));
		d = min(d, seg(p, vec2(0.42, -0.42), vec2(0.26, -0.3)));
	} else if (g == 3) {
		d = min(d, ring(p - vec2(0.0, -0.18), 0.32));
		d = min(d, seg(p, vec2(0.0, 0.72), vec2(0.28, -0.04)));
		d = min(d, seg(p, vec2(0.0, 0.72), vec2(-0.28, -0.04)));
		d = min(d, length(p - vec2(0.0, -0.18)) - 0.04);
	} else if (g == 4) {
		d = min(d, seg(p, vec2(0.0, 0.76), vec2(0.14, 0.14)));
		d = min(d, seg(p, vec2(0.14, 0.14), vec2(0.76, 0.0)));
		d = min(d, seg(p, vec2(0.76, 0.0), vec2(0.14, -0.14)));
		d = min(d, seg(p, vec2(0.14, -0.14), vec2(0.0, -0.76)));
		d = min(d, seg(p, vec2(0.0, -0.76), vec2(-0.14, -0.14)));
		d = min(d, seg(p, vec2(-0.14, -0.14), vec2(-0.76, 0.0)));
		d = min(d, seg(p, vec2(-0.76, 0.0), vec2(-0.14, 0.14)));
		d = min(d, seg(p, vec2(-0.14, 0.14), vec2(0.0, 0.76)));
		d = min(d, ring(p, 0.1));
	} else if (g == 5) {
		d = min(d, seg(p, vec2(-0.46, 0.56), vec2(0.46, 0.56)));
		d = min(d, seg(p, vec2(0.46, 0.56), vec2(0.46, 0.02)));
		d = min(d, seg(p, vec2(0.46, 0.02), vec2(0.0, -0.72)));
		d = min(d, seg(p, vec2(0.0, -0.72), vec2(-0.46, 0.02)));
		d = min(d, seg(p, vec2(-0.46, 0.02), vec2(-0.46, 0.56)));
		d = min(d, seg(p, vec2(0.0, 0.4), vec2(0.0, -0.42)));
		d = min(d, seg(p, vec2(-0.26, 0.2), vec2(0.26, 0.2)));
	}
	return d;
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// A stroke: a white-hot core over a wide glow in the tint.
vec3 stroke(float d, float w, float glow_w) {
	float core = 1.0 - smoothstep(w * 0.4, w, d);
	float glow = exp(-d / glow_w);
	return mix(tint.rgb * glow * 0.9, vec3(1.0, 0.97, 0.9), core * 0.3) + tint.rgb * core;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float r = length(p);
	vec3 col = vec3(0.0);
	if (mode == 2) {
		float g = exp(-r * r * 3.2) * (1.0 - smoothstep(0.85, 1.0, r));
		col = tint.rgb * g * 0.35;
	} else if (mode == 3) {
		float rr = mix(0.25, 0.98, flash);
		col = stroke(ring(p, rr), 0.03, 0.06) * (1.0 - flash);
	} else if (mode == 1) {
		vec2 q = p / 0.78;
		float dg = glyph_d(q, glyph) * 0.78;
		col = stroke(dg, 0.05, 0.07);
		col += stroke(ring(p, 0.9), 0.025, 0.05) * 0.6;
		col += tint.rgb * exp(-r * 2.6) * 0.18;
		col *= pulse;
	} else {
		float a = atan(p.y, p.x) + spin;
		float d = min(ring(p, 0.93), ring(p, 0.7));
		col = stroke(d, 0.018, 0.035);
		// The band of rune strokes between the rings: 24 cells, each a radial bar and one of three notches.
		float cells = 24.0;
		float t = a / 6.2831853 * cells;
		float cell = floor(t);
		float u = fract(t) - 0.5;
		float h = hash(mod(cell, cells));
		vec2 lp = vec2(u * 0.36, (r - 0.815) / 0.11);
		float band = 10.0;
		if (r > 0.71 && r < 0.92) {
			band = seg(lp, vec2(0.0, -0.7), vec2(0.0, 0.7));
			if (h < 0.34) {
				band = min(band, seg(lp, vec2(0.0, 0.2), vec2(0.07, 0.55)));
			} else if (h < 0.67) {
				band = min(band, seg(lp, vec2(-0.07, -0.1), vec2(0.07, -0.1)));
			} else {
				band = min(band, seg(lp, vec2(0.0, -0.3), vec2(-0.07, -0.6)));
			}
			band *= 0.11;
		}
		col += stroke(band, 0.012, 0.022) * 0.85;
		// The glyph in the middle, held still against the turn.
		float dg = glyph_d(p / 0.42, glyph) * 0.42;
		col += stroke(dg, 0.022, 0.04) * 0.95;
		// A shimmer running round the band, and the inner glow.
		float run = 0.5 + 0.5 * sin(a * 3.0 - spin * 4.0);
		col *= 0.78 + 0.32 * run;
		col += tint.rgb * exp(-r * 3.0) * 0.12;
		col *= pulse * (1.0 - smoothstep(0.97, 1.0, r));
	}
	// Over the floor as a coloured glow (mixed, not added, so it keeps its hue on light ground): the brightest
	// channel is its cover, the colour its hue at full strength.
	vec3 c = col * strength;
	float a = clamp(max(max(c.r, c.g), c.b), 0.0, 1.0);
	ALBEDO = c / max(a, 0.001);
	ALPHA = a;
}
"""

static var _shader: Shader = null
static var _mote_tex: GradientTexture2D = null

## The glyph drawn (0: none, nothing shows) and its colour.
var glyph := 0
var tint := Color.WHITE
## The parts (tests read them): the circle, the halo, the ward's flash ring, the back glyph, the light, the motes.
var circle: MeshInstance3D
var halo: MeshInstance3D
var flash_ring: MeshInstance3D
var back: MeshInstance3D
var light: OmniLight3D
var motes: CPUParticles3D
## A5 Guardian's ward as last set: whether the run has wards at all, how many are up, and the time since one broke.
var has_ward := false
var ward_up := 0
var _flash_t := -1.0
var _last_ward_tick := -1
var _ward_seen := false
var _t := 0.0
var _mats: Array[ShaderMaterial] = []


func _init() -> void:
	name = "AffinityRunes"
	halo = _quad("Halo", HALO_M, 2)
	halo.position.y = 0.012
	add_child(halo)
	circle = _quad("Circle", CIRCLE_M, 0)
	circle.position.y = 0.022
	add_child(circle)
	flash_ring = _quad("WardFlash", CIRCLE_M * 1.6, 3)
	flash_ring.position.y = 0.03
	flash_ring.visible = false
	add_child(flash_ring)
	back = _quad("BackRune", BACK_M, 1)
	back.rotation = Vector3.ZERO
	visible = false


func _quad(n: String, size_m: float, mode: int) -> MeshInstance3D:
	var mi := quad(n, size_m, mode)
	_mats.append(mi.material_override as ShaderMaterial)
	return mi


## One of the rune shader's quads (`mode`: 0 the circle, 1 a standing glyph, 2 the soft ground glow, 3 the flash
## ring), flat on the floor unless it is a glyph. AstralSenseView draws its pulses with it too.
static func quad(n: String, size_m: float, mode: int) -> MeshInstance3D:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var q := QuadMesh.new()
	q.size = Vector2(size_m, size_m)
	if mode != 1:
		q.orientation = PlaneMesh.FACE_Y
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"mode", mode)
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Rising motes in colour `c` off a ring of `radius_m` (`amount` of them).
static func motes_of(c: Color, radius_m: float, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Motes"
	p.amount = maxi(1, amount)
	p.lifetime = 1.5
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius_m
	p.emission_ring_inner_radius = radius_m * 0.78
	p.emission_ring_height = 0.02
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.55
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.albedo_color = c.lightened(0.25)
	mm.albedo_texture = _mote_texture()
	mm.disable_receive_shadows = true
	q.material = mm
	p.mesh = q
	p.position.y = 0.04
	return p


## The rune's look: `p_glyph` (0 hides everything) in colour `c`.
func set_rune(p_glyph: int, c: Color) -> void:
	glyph = clampi(p_glyph, 0, GLYPHS - 1)
	tint = c
	for m in _mats:
		m.set_shader_parameter(&"tint", c)
		m.set_shader_parameter(&"glyph", glyph)
	visible = glyph > 0
	back.visible = glyph > 0
	_build_extras()


## Effects density: the light and the motes from Medium up (Low keeps the shapes).
func _build_extras() -> void:
	for n: Node in [light, motes]:
		if n != null:
			n.queue_free()
	light = null
	motes = null
	if glyph == 0:
		return
	var dens := ViewPrefs.effects_density
	if dens == "low":
		return
	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = tint
	light.light_energy = LIGHT_ENERGY
	light.omni_range = 1.8
	light.shadow_enabled = false
	light.position.y = 0.35
	add_child(light)
	motes = motes_of(tint, CIRCLE_M * 0.46, MOTES_HIGH if dens == "high" else MOTES_HIGH / 2)
	add_child(motes)


static func _mote_texture() -> GradientTexture2D:
	if _mote_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_mote_tex = GradientTexture2D.new()
		_mote_tex.gradient = g
		_mote_tex.fill = GradientTexture2D.FILL_RADIAL
		_mote_tex.fill_from = Vector2(0.5, 0.5)
		_mote_tex.fill_to = Vector2(1.0, 0.5)
		_mote_tex.width = 32
		_mote_tex.height = 32
	return _mote_tex


## A5 Guardian (WorldReader.affinity_ward and its break tick): the ward state after a sim tick.
func set_ward(p_has: bool, up: int, broke_tick: int) -> void:
	has_ward = p_has
	ward_up = up
	# The first state seen only records the tick (a floor resumed after its ward broke doesn't flash).
	if _ward_seen and broke_tick >= 0 and broke_tick != _last_ward_tick:
		_flash_t = 0.0
	_last_ward_tick = broke_tick
	_ward_seen = true


## How strongly the circle burns now (1 full; the spent ward's dim).
func strength() -> float:
	return WARD_SPENT if has_ward and ward_up <= 0 else 1.0


## Frame time: the turn, the breath, the ward's flash.
func advance(dt: float) -> void:
	if glyph == 0:
		return
	var calm := ViewPrefs.reduced_motion
	_t += dt
	var spin := 0.0 if calm else _t * 0.35
	var breath := 1.0 if calm else 0.88 + 0.12 * sin(_t * 2.2)
	var s := strength()
	for m in _mats:
		m.set_shader_parameter(&"spin", spin)
		m.set_shader_parameter(&"pulse", breath)
		m.set_shader_parameter(&"strength", s)
	if light != null:
		light.light_energy = LIGHT_ENERGY * s * breath
	if motes != null:
		motes.emitting = s >= 1.0
	if _flash_t >= 0.0:
		_flash_t += dt
		var k := _flash_t / FLASH_SECONDS
		flash_ring.visible = k < 1.0
		(flash_ring.material_override as ShaderMaterial).set_shader_parameter(&"flash", k)
		(flash_ring.material_override as ShaderMaterial).set_shader_parameter(&"strength", 1.6)
		if k >= 1.0:
			_flash_t = -1.0
