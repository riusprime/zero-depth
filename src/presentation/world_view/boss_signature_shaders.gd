class_name BossSignatureShaders
extends RefCounted
## The shaders BossSignatureViews draws the new signature pieces
## with (kept apart so the view stays readable): the Gaze's beam (a hot core and glow with scrolling noise, additive)
## and the strip it burns on the floor, the scorch marks it leaves, a ricochet's spark (a camera-facing star), the
## Foundry's molten floor (churning, crusting over as it cools) and its meltdown (the floor beyond a radius molten in
## the floods' own lava crust, lit by the room and dimmer than a flood, a dark crust band along the safe line with a
## thin hot rim on it, a cool bridge left out, the next ring pulsing while warned). Presentation only.

const BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.22, 0.52, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.86, 0.95, 1.0);
uniform float strength = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// v0.8.0 TX1 (FxTextures.texture_beam): the owner's beam or aim-line strip, one row of a 1 x 4 sheet, across the
// cylinder as the camera sees it (its middle the row's middle), along it tiled every tex_tile m (or once).
uniform sampler2D beam_tex : filter_linear_mipmap, repeat_enable;
uniform float tex_on = 0.0;
uniform float tex_row = 0.0;
uniform float tex_tile = 4.0;
uniform float tex_once = 0.0;
uniform float tex_scroll = 0.0;
varying float along;
varying float along_m;
varying vec3 perp;
void vertex() {
	along = VERTEX.y + 0.5;
	along_m = along * length(MODEL_MATRIX[1].xyz);
	vec3 axis = (MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	vec3 c = cross(axis, vec3(0.0, 0.0, 1.0));
	perp = length(c) > 0.00001 ? normalize(c) : vec3(1.0, 0.0, 0.0);
}
void fragment() {
	float rim = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	if (tex_on > 0.5) {
		float across = dot(normalize(NORMAL), perp);  // -1 .. 1 across the beam as it is seen
		float x = tex_once > 0.5 ? clamp(along, 0.004, 0.996) : along_m / tex_tile - TIME * tex_scroll;
		float y = (tex_row + clamp(0.5 + 0.5 * across, 0.03, 0.97)) * 0.25;
		vec4 t = texture(beam_tex, vec2(x, y));
		ALBEDO = mix(color.rgb, core.rgb, t.r) * t.a * strength * 1.8;
	} else {
		float n = texture(noise_tex, vec2(UV.x * 2.0 + TIME * 0.4, UV.y * 4.0 - TIME * 2.5)).r;
		float body = rim * rim * mix(0.5, 1.2, n);
		float hot = pow(rim, 6.0);
		ALBEDO = mix(color.rgb, core.rgb, hot) * body * strength * 1.1;
	}
}
"""

const FLOOR := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
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
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
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
	// The floods' lava crust (tex_lava_crust: its alpha the hot seams between the plates), as the flood markers draw
	// it (BossStrikeLooks MOLTEN), kept dimmer: dark plates lit by the room, the seams glowing between them.
	float seam = smoothstep(0.55, 0.8, n2 * 0.7 + n * 0.3);
	vec3 plate = vec3(0.13, 0.06, 0.04);
	if (crust_on > 0.5) {
		vec4 cr = texture(crust_tex, p * 0.1 + vec2(TIME * 0.004, 0.0));
		seam = cr.a;
		plate = mix(vec3(0.1, 0.035, 0.02), cr.rgb * 0.5, 0.45);
		hot = mix(cr.rgb, vec3(1.0, 0.55, 0.1), 0.45);
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.3;
	if (molten) {
		// Along the safe line (and the bridge's sides) the crust closes into a dark band, a thin hot rim on its edge.
		float edge_d = d - radius;
		if (bridge > 0.5) {
			edge_d = min(edge_d, seg(p, centre, bridge_to) - bridge_half);
		}
		float band = 1.0 - smoothstep(0.3, 1.1, edge_d);
		float rim = 1.0 - smoothstep(0.04, 0.16, edge_d);
		seam *= 1.0 - band * 0.9;
		ALBEDO = mix(mix(plate, hot * 0.3, seam), vec3(0.06, 0.03, 0.02), band * (1.0 - rim));
		EMISSION = hot * seam * (0.45 + 0.15 * heat) + vec3(1.0, 0.42, 0.1) * rim * 1.4;
		ALPHA = 1.0;
	} else {
		// The ring that melts next: the same crust heating through the floor, its seams and the line it will stop at
		// pulsing faster as the warning runs out.
		float pulse = 0.5 + 0.5 * sin(TIME * (6.0 + 10.0 * warn));
		float rim = 1.0 - smoothstep(0.05, 0.2, d - next);
		ALBEDO = mix(plate, hot * 0.3, seam * warn);
		EMISSION = hot * seam * (0.2 + 0.7 * warn) * (0.5 + 0.5 * pulse) + vec3(1.0, 0.42, 0.1) * rim * (0.5 + pulse);
		ALPHA = max((0.4 + 0.4 * warn) * (0.75 + 0.25 * pulse), rim);
	}
}
"""
