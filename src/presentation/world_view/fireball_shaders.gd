class_name FireballShaders
extends RefCounted
## v0.8.0 AV (owner O8): the shaders of the hostile fireballs (FireballViews), shared by every look. Per look only
## the uniforms change, so each look is still three MultiMeshes (one draw each).
## - core: a lit 3D body (faceted stone, gem, plasma, a glob) with a noise swirl and flicker inside, glowing veins
##   (`crack`), a hot centre that falls off to the look's dark edge colour at the rim (fresnel: a bright core and a
##   dark edge, the readability rule), and the body's own turn (`spin` about the flight, `tumble` across it) and
##   wobble. `motion` 0 (reduced motion) stills the swirl, the turn and the wobble.
## - edge: the dark shell drawn from the inside behind the core (the outline), turning with it.
## - trail: a tapered strip that faces the camera about its own length (one instance per ball), noise scrolled down
##   it; `drips` breaks it into falling drops. Additive for fire, mixed for smoke and acid.
## Presentation only (EI-07). Instance seeds come from INSTANCE_ID, so neighbours differ without per-instance data.

const CORE := """
shader_type spatial;
render_mode %s, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 body_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float energy = 3.0;
uniform float crack = 0.0;
uniform float swirl = 1.0;
uniform float noise_scale = 1.5;
uniform float spin = 0.0;
uniform float tumble = 0.0;
uniform float wobble = 0.0;
uniform float facets = 0.0;
uniform float opacity = 1.0;
uniform float motion = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 lp;
varying float seed;

%s

void fragment() {
	float t = TIME * motion;
	vec2 a = lp.xy * noise_scale * 0.5 + vec2(seed, t * 0.21 * swirl);
	vec2 b = lp.zy * noise_scale * 0.5 + vec2(t * 0.17 * swirl, seed * 3.0);
	float n = texture(noise_tex, a).r * 0.6 + texture(noise_tex, b).r * 0.4;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = 1.0 - facing;
	float veins = 1.0 - smoothstep(0.012, 0.055, abs(n - 0.5));
	float inner = pow(facing, 4.0);
	float mask = mix(1.0, max(veins, inner * 0.45), crack);
	float sparkle = facets * (0.5 + 0.5 * sin(dot(floor(NORMAL * 3.0), vec3(12.9, 78.2, 37.7)) + t * 3.0));
	float flick = 0.85 + 0.3 * texture(noise_tex, vec2(seed * 7.0, t * 0.9)).r;
	vec3 hot = core_color.rgb * (0.55 + 1.0 * n + sparkle);
	vec3 glow = mix(hot, edge_color.rgb, smoothstep(0.3, 0.95, fres));
	ALBEDO = mix(core_color.rgb * 0.25, body_color.rgb, crack);
	EMISSION = glow * energy * mask * flick;
	ROUGHNESS = mix(0.3, 0.9, crack);
	SPECULAR = 0.45;
	%s
}
"""

## The shared vertex code: each instance turns and wobbles on its own seed.
const VERTEX := """
mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.618034);
	float t = (TIME + seed * 40.0) * motion;
	mat3 r = rot_x(t * spin + seed * 6.28) * rot_z(t * tumble);
	vec3 v = r * VERTEX;
	float w = sin(t * 7.0 + v.y * 6.0 + v.x * 3.0) * sin(t * 5.0 + v.z * 5.0);
	v *= 1.0 + wobble * w * motion;
	lp = VERTEX;
	VERTEX = v;
	NORMAL = r * NORMAL;
}
"""

const EDGE := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float spin = 0.0;
uniform float tumble = 0.0;
uniform float wobble = 0.0;
uniform float motion = 1.0;

varying vec3 lp;
varying float seed;

%s

void fragment() {
	ALBEDO = edge_color.rgb;
}
"""

const TRAIL := """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 head : source_color = vec4(1.0);
uniform float glow = 1.5;
uniform float tail_width = 0.25;
uniform float drips = 0.0;
uniform float scroll = 2.0;
uniform float opacity = 0.8;
uniform float motion = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying float seed;

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.618034);
	vec3 axis = MODEL_MATRIX[0].xyz;
	float w = length(MODEL_MATRIX[1].xyz);
	vec3 view_z = INV_VIEW_MATRIX[2].xyz;
	vec3 c = cross(axis, view_z);
	vec3 side = length(c) > 0.00001 ? normalize(c) * w : MODEL_MATRIX[1].xyz;
	float taper = mix(tail_width, 1.0, UV.x);
	vec3 world = MODEL_MATRIX[3].xyz + axis * VERTEX.x + side * VERTEX.y * taper;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float u = UV.x;
	float v = abs(UV.y * 2.0 - 1.0);
	float t = TIME * motion;
	float n = texture(noise_tex, vec2(u * 1.2 - t * scroll * 0.5 + seed, UV.y * 0.7 + seed * 2.0)).r;
	float body = 1.0 - smoothstep(0.3 + 0.35 * n, 1.0, v);
	float along = smoothstep(0.0, 0.85, u);
	float a = body * along * opacity * (0.55 + 0.7 * n);
	if (drips > 0.0) {
		float cell = fract(u * 4.0 + t * 1.3 + seed);
		float blob = 1.0 - smoothstep(0.2, 0.34, length(vec2((cell - 0.5) * 1.6, v * 0.9)));
		a = mix(a, max(a * 0.3, blob * along * opacity), drips);
	}
	ALBEDO = mix(tint.rgb, head.rgb, smoothstep(0.55, 1.0, u)) * glow;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

static var _shaders := {}


## The core shader: opaque, or `translucent` (the acid globs: the rim a little more solid than the middle).
static func core(translucent: bool) -> Shader:
	var key := "core_t" if translucent else "core"
	if not _shaders.has(key):
		var alpha := "ALPHA = mix(opacity, 1.0, fres * 0.6);" if translucent else ""
		var mode := "blend_mix, depth_draw_always" if translucent else "blend_mix"
		_shaders[key] = _make(CORE % [mode, VERTEX, alpha])
	return _shaders[key]


static func edge() -> Shader:
	if not _shaders.has("edge"):
		_shaders["edge"] = _make(EDGE % VERTEX)
	return _shaders["edge"]


## The trail shader: `additive` (fire, plasma) or mixed (smoke, acid).
static func trail(additive: bool) -> Shader:
	var key := "trail_add" if additive else "trail_mix"
	if not _shaders.has(key):
		_shaders[key] = _make(TRAIL % ("blend_add" if additive else "blend_mix"))
	return _shaders[key]


static func _make(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s
