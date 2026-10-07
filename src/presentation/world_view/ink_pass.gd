class_name InkPass
extends MeshInstance3D
## A thin, dark, hand-drawn-feeling outline on every edge (owner, 2026-10-07: "a light and thin black stroke …
## closer to a hand draw sketch … just the feeling"). A full-screen quad in front of the camera finds edges in
## the depth buffer (and, on Forward+, the normal buffer) and blends ink over them, so telegraphs and bars that
## draw later stay on top. Styles: OFF, INK (clean lines), SKETCH (lines wobble and break a little),
## PAPER (sketch plus a faint paper grain). Static noise: the lines don't flicker. Edges are tested one-sided
## (+x, +y), so a line is one pixel wide; the owner asked for thinner, more precise lines with 20% less
## hand-drawn wobble and breakup (2026-10-07).

enum Style { OFF, INK, SKETCH, PAPER }

const STYLE_NAMES := {
	"off": Style.OFF, "ink": Style.INK, "sketch": Style.SKETCH, "paper": Style.PAPER
}

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
%s
uniform int style = 2;
uniform vec4 ink : source_color = vec4(0.06, 0.06, 0.08, 1.0);
uniform float thickness = 1.0;
uniform float depth_threshold = 0.12;
uniform float normal_threshold = 0.35;
uniform float strength = 0.8;
uniform float wobble_px = 1.04;
uniform float breakup = 0.36;
uniform float paper = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float view_z(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

%s

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	if (style >= 2) {
		vec2 n = vec2(vnoise(uv * vec2(90.0, 55.0)), vnoise(uv * vec2(55.0, 90.0) + 7.3)) - 0.5;
		uv += n * 2.0 * wobble_px * px;
	}
	vec2 o = px * thickness;
	float zc = view_z(uv, INV_PROJECTION_MATRIX);
	float dz = 0.0;
	dz = max(dz, abs(zc - view_z(uv + vec2(o.x, 0.0), INV_PROJECTION_MATRIX)));
	dz = max(dz, abs(zc - view_z(uv + vec2(0.0, o.y), INV_PROJECTION_MATRIX)));
	float edge = smoothstep(depth_threshold, depth_threshold * 2.5, dz);
	edge = max(edge, normal_edge(uv, o));
	if (style >= 2) {
		float b = vnoise(uv * vec2(38.0, 38.0) + 3.1);
		edge *= mix(1.0, smoothstep(0.15, 0.65, b), breakup);
	}
	float a = edge * strength;
	if (style == 3) {
		float grain = vnoise(uv * vec2(520.0, 300.0)) * 0.6 + vnoise(uv * vec2(120.0, 70.0)) * 0.4;
		a = max(a, paper * grain);
	}
	ALBEDO = ink.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * ink.a;
}
"""

const NORMALS_UNIFORM := "uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;"
const NORMALS_FN := """
float normal_edge(vec2 uv, vec2 o) {
	vec3 nc = texture(normal_tex, uv).xyz * 2.0 - 1.0;
	float m = 1.0;
	m = min(m, dot(nc, texture(normal_tex, uv + vec2(o.x, 0.0)).xyz * 2.0 - 1.0));
	m = min(m, dot(nc, texture(normal_tex, uv + vec2(0.0, o.y)).xyz * 2.0 - 1.0));
	return smoothstep(normal_threshold, normal_threshold + 0.25, 1.0 - m);
}
"""
## The Compatibility renderer has no normal buffer: silhouettes from depth only.
const DEPTH_ONLY_FN := "float normal_edge(vec2 uv, vec2 o) { return 0.0; }"

var style := Style.SKETCH
var _mat := ShaderMaterial.new()


func _init() -> void:
	name = "InkPass"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.flip_faces = true
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	var shader := Shader.new()
	shader.code = (
		SHADER % [NORMALS_UNIFORM if forward else "", NORMALS_FN if forward else DEPTH_ONLY_FN]
	)
	_mat.shader = shader
	_mat.render_priority = 100
	material_override = _mat
	set_style(style)


func set_style(s: int) -> void:
	style = s
	visible = s != Style.OFF
	_mat.set_shader_parameter("style", s)


static func style_from_setting(value: String) -> int:
	return STYLE_NAMES.get(value, Style.SKETCH)
