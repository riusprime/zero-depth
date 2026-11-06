// v0.10.5 W3-O7 (owner F6, F16): the Binbun fire pack's flame_01 particle flame (fire_ball_04's trail), its red and
// yellow taken from the effect's colours: secondary the flame, primary its hottest young puffs, tertiary what it fades to
// (times smoke_level). Unshaded and unfogged, so a cold colour keeps its hue under the stage's warm light and haze.
shader_type spatial;
render_mode blend_mix, unshaded, fog_disabled;

uniform sampler2D noise_texture_1;
uniform sampler2D noise_texture_2;
uniform float edge_softness = 1.0;
uniform vec2 texture_scale = vec2(1.0, 1.0);
uniform vec4 primary_color : source_color = vec4(1.0, 0.9, 0.8, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.1, 0.0, 1.0);
uniform vec4 tertiary_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float smoke_level = 1.0;
uniform float hot_share = 0.12;
uniform vec2 mask_from = vec2(0.5);
uniform float mask_scale = 0.4;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float warp_noise = 1.0 - (texture(noise_texture_2, (UV + vec2(-TIME * 0.5, 0.0))).r * .0003);
	vec2 uv_offset = vec2(COLOR.r * 2.0);
	uv_offset = uv_offset + (vec2(sin(TIME * 1.0) * .1, COLOR.a * .1) * warp_noise);
	float noise = texture(noise_texture_1, (UV * .3 * texture_scale) + uv_offset).r;
	float mask = smoothstep(1.0 - mask_scale, 1.0, 1.0 - distance(mask_from, UV));
	float masked_noise = mask * noise;
	vec3 young = mix(secondary_color.rgb, primary_color.rgb, pow(COLOR.a, 16.0) * hot_share);
	vec3 main_color = mix(mix(secondary_color.rgb, tertiary_color.rgb, 0.5) * smoke_level, young, pow(COLOR.a, 8.0));
	ALBEDO = main_color * (1.0 + 0.25 * pow(COLOR.a, 16.0));  // (unshaded: the lit original's emission folded in)
	ALPHA = smoothstep(0.3, edge_softness, masked_noise) * pow(COLOR.a, 2.0);
}
