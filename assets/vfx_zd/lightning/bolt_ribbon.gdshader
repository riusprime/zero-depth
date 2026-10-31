// v0.10.0 VX6: a lightning ribbon in the Binbun beam's style. Built from the pack's beam_core (hot centre, fresnel-like
// glow, pulse) and beam_outer (a scrolling noise shell) shaders; the mesh is a flat strip (UV.x across, UV.y along its
// length) that ZdBolt turns to face the camera.
shader_type spatial;
render_mode unshaded, cull_disabled;

group_uniforms Color;
uniform vec3 primary_color : source_color = vec3(1.0);
uniform vec3 secondary_color : source_color = vec3(0.5, 0.7, 1.0);
uniform vec3 tertiary_color : source_color = vec3(0.2, 0.3, 0.9);
uniform float emission : hint_range(0.0, 10.0, 0.01) = 4.0;

group_uniforms Noise;
uniform sampler2D noise_texture;
uniform vec2 scroll_speed = vec2(0.5, 3.0);
uniform float beam_length = 4.0;

group_uniforms Pulse;
uniform float pulse_speed = 30.0;
uniform float pulse_strength = 0.3;

group_uniforms General;
uniform bool outer = false;
uniform float fade : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0, 0.01) = 0.8;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float pulse = 1.0 + sin(UV.y * beam_length * 6.0 - TIME * pulse_speed) * pulse_strength;
	vec3 color;
	float alpha;
	if (outer) {
		vec2 uv = UV * vec2(1.0, beam_length);
		uv -= vec2(TIME) * scroll_speed;
		float noise = texture(noise_texture, uv).r;
		color = mix(tertiary_color, secondary_color, pow(noise, 0.5)) * emission * 0.6;
		alpha = (1.0 - across) * mix(0.35, 1.0, noise);
		alpha = smoothstep(0.7 - edge_softness * 0.7, 0.7 + edge_softness * 0.3, alpha) * 0.7;
	} else {
		float glow = clamp(1.0 - across, 0.0, 1.0);
		color = mix(secondary_color, primary_color, pow(glow, 0.7)) * emission * pulse;
		alpha = smoothstep(0.0, 0.45, glow);
	}
	ALBEDO = color;
	ALPHA = alpha * fade;
}
