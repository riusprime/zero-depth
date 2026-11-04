// v0.10.5 W3-O7 (owner F6, F16): the Binbun fire pack's fire_ball_03 shader (fire_ball_04's ball), its molten dark and
// light and its rim glow taken from the effect's colours: tertiary the dark, primary the light, secondary the rim.
shader_type spatial;
render_mode blend_mix;

uniform sampler2D noise_texture_1;
uniform vec2 texture_scale = vec2(1.0, 1.0);
uniform vec4 primary_color : source_color = vec4(1.0, 0.9, 0.2, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.4, 0.0, 1.0);
uniform vec4 tertiary_color : source_color = vec4(0.5, 0.0, 0.0, 1.0);

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void vertex() {
	vec3 displace = vec3(1.0);
	displace.y = sin(NORMAL.z * TIME);
	displace.x = sin(NORMAL.z * TIME);
	displace.z = sin(NORMAL.x * TIME);
	displace *= 0.005;
	displace += sin(UV.y * TIME * 0.4 * 20.0) * 0.01;
	VERTEX += NORMAL * displace;
}

void fragment() {
	float noise = texture(noise_texture_1, UV * texture_scale + vec2(0.0, TIME * .1)).r;
	float mask = texture(noise_texture_1, UV * texture_scale + vec2(0.0, -TIME * .1)).r;
	float masked_noise = smoothstep(0.1, .3, pow(mask * noise, 2.0));
	vec3 dark = tertiary_color.rgb * (0.6 + noise * 0.5);
	vec3 light = mix(primary_color.rgb, vec3(1.0), noise * .5);
	vec3 main_color = mix(dark, light, masked_noise);
	main_color = mix(main_color, secondary_color.rgb, fresnel(2.0, NORMAL, VIEW));
	ALBEDO = main_color;
	EMISSION = ALBEDO * 2.0;
}
