class_name BossSignatureShaders
extends RefCounted
## v0.8.0 BS2 (owner O5; BOSS_SIGNATURES.md S4-S6): the shaders BossSignatureViews draws the new signature pieces
## with (kept apart so the view stays readable): the Gaze's beam (a hot core and glow with scrolling noise, additive)
## and the strip it burns on the floor, the scorch marks it leaves, a ricochet's spark (a camera-facing star), the
## Foundry's molten floor (churning, crusting over as it cools) and its meltdown (the floor beyond a radius molten,
## a cool bridge left out, the next ring pulsing while warned). Presentation only.

const BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.22, 0.52, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.86, 0.95, 1.0);
uniform float strength = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
void fragment() {
	float n = texture(noise_tex, vec2(UV.x * 2.0 + TIME * 0.4, UV.y * 4.0 - TIME * 2.5)).r;
	float rim = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float body = rim * rim * mix(0.5, 1.2, n);
	float hot = pow(rim, 6.0);
	ALBEDO = mix(color.rgb, core.rgb, hot) * body * strength * 1.1;
}
"""

const FLOOR := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.22, 0.52, 1.0);
void fragment() {
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float flick = 0.8 + 0.2 * sin(TIME * 23.0 + UV.x * 40.0);
	ALBEDO = color.rgb * smoothstep(0.0, 0.7, across) * 0.55 * flick;
}
"""

const SCORCH := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying float age;
varying float seed;
void vertex() {
	age = INSTANCE_CUSTOM.r;
	seed = INSTANCE_CUSTOM.g;
}
void fragment() {
	vec2 d = UV - 0.5;
	float n = texture(noise_tex, UV * 0.8 + vec2(seed * 0.13, seed * 0.29)).r;
	float blot = 1.0 - smoothstep(0.18, 0.5, length(d) + (n - 0.5) * 0.25);
	ALBEDO = vec3(0.06, 0.03, 0.03);
	EMISSION = vec3(1.0, 0.35, 0.15) * blot * (1.0 - age) * (1.0 - age) * 1.6;
	ALPHA = blot * (1.0 - age * age) * 0.8;
	ROUGHNESS = 1.0;
}
"""

const SPARK := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
varying float age;
void vertex() {
	age = INSTANCE_CUSTOM.r;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
	VERTEX *= 1.0 + age * 0.6;
}
void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d);
	float star = max(1.0 - abs(d.x) * 14.0, 0.0) + max(1.0 - abs(d.y) * 14.0, 0.0);
	float glow = (1.0 - smoothstep(0.0, 0.5, r)) * (0.6 + star);
	ALBEDO = vec3(1.0, 0.62, 0.22) * glow * (1.0 - age) * 2.2;
}
"""

const LAVA := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float cool = 0.0;
uniform float fade = 1.0;
uniform sampler2D lava_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D crust_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float lava_on = 0.0;
uniform float crust_on = 0.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wp.xz * 0.32;
	float n = texture(noise_tex, uv + vec2(TIME * 0.03, TIME * 0.02)).r;
	float n2 = texture(noise_tex, uv * 2.3 - vec2(TIME * 0.05, -TIME * 0.01)).r;
	float heat = smoothstep(0.3, 0.75, n * 0.6 + n2 * 0.4);
	float crust = smoothstep(0.62 - cool * 0.55, 0.68 - cool * 0.55, n2);
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.08, min(e.x, e.y));
	vec3 hot = mix(vec3(0.85, 0.14, 0.02), vec3(1.0, 0.62, 0.12), heat);
	vec3 crust_rgb = vec3(0.08, 0.04, 0.03);
	if (lava_on > 0.5) {  // v0.8.0 TX2: the owner's lava (fx_lava_flow), its crust (tex_lava_crust) closing as it cools
		vec4 lv = texture(lava_tex, wp.xz * 0.22 + vec2(TIME * 0.02, TIME * 0.012));
		hot = lv.rgb * mix(0.45, 0.9, lv.a);  // kept dim: the stage's exposure turns a bright bed to cream
		if (crust_on > 0.5) {
			vec4 cr = texture(crust_tex, wp.xz * 0.3);
			crust = smoothstep(1.02 - cool, 1.1 - cool, 1.0 - cr.a);
			crust_rgb = cr.rgb * 0.5;
		}
	}
	ALBEDO = mix(hot * 0.35, crust_rgb, crust * 0.9);
	EMISSION = hot * (1.0 - crust) * (1.3 - cool * 0.8);
	ROUGHNESS = mix(0.4, 0.95, crust);
	ALPHA = fade * mix(0.35, 1.0, edge);
}
"""

const MELT := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 centre = vec2(0.0);
uniform float radius = 100000.0;
uniform float next = 0.0;
uniform float warn = -1.0;
uniform float bridge = 0.0;
uniform vec2 bridge_to = vec2(0.0);
uniform float bridge_half = 1.0;
uniform sampler2D lava_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D crust_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float lava_on = 0.0;
uniform float crust_on = 0.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 d = b - a;
	float l = max(dot(d, d), 0.0001);
	float f = clamp(dot(p - a, d) / l, 0.0, 1.0);
	return length(p - (a + d * f));
}
void fragment() {
	vec2 p = wp.xz;
	float d = length(p - centre);
	bool cool_way = bridge > 0.5 && seg(p, centre, bridge_to) <= bridge_half;
	bool molten = d > radius && !cool_way;
	bool warned = warn >= 0.0 && d > next && d <= radius && !cool_way;
	if (!molten && !warned) {
		discard;
	}
	vec2 uv = p * 0.3;
	float n = texture(noise_tex, uv + vec2(TIME * 0.025, TIME * 0.015)).r;
	float n2 = texture(noise_tex, uv * 2.1 - vec2(TIME * 0.04, 0.0)).r;
	float heat = smoothstep(0.3, 0.75, n * 0.6 + n2 * 0.4);
	vec3 hot = mix(vec3(0.85, 0.14, 0.02), vec3(1.0, 0.62, 0.12), heat);
	if (molten) {
		float crust = smoothstep(0.62, 0.7, n2);
		vec3 crust_rgb = vec3(0.08, 0.04, 0.03);
		if (lava_on > 0.5) {  // v0.8.0 TX2: the owner's lava, a few crust plates (tex_lava_crust) floating on it
			vec4 lv = texture(lava_tex, p * 0.22 + vec2(TIME * 0.018, TIME * 0.01));
			hot = lv.rgb * mix(0.45, 0.9, lv.a);
			if (crust_on > 0.5) {
				vec4 cr = texture(crust_tex, p * 0.27);
				crust = smoothstep(0.9, 0.98, 1.0 - cr.a) * smoothstep(0.55, 0.7, n);
				crust_rgb = cr.rgb * 0.5;
			}
		}
		ALBEDO = mix(hot * 0.35, crust_rgb, crust * 0.85);
		EMISSION = hot * (1.0 - crust) * 1.3;
		ALPHA = 1.0;
	} else {
		float pulse = 0.5 + 0.5 * sin(TIME * (6.0 + 10.0 * warn));
		ALBEDO = vec3(0.35, 0.08, 0.02);
		EMISSION = vec3(1.0, 0.3, 0.05) * (0.6 + 1.8 * warn) * (0.45 + 0.55 * pulse);
		ALPHA = (0.35 + 0.5 * warn) * (0.55 + 0.45 * pulse);
	}
	ROUGHNESS = 0.7;
}
"""
