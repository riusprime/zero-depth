shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
// v0.10.0 VX8: the Blade's swing ribbon in the VFX pack's style. Adapted from the beam pack's beam_outer.gdshader
// (assets/BinbunVFX/beam_vfx/src/shader/, not edited): the same scrolling noise mixed between the primary and secondary
// colours, with the beam's axis (UV.y) turned into the ribbon's (UV.x, 0 at the oldest sample, 1 at the blade) and the
// scroll driven by `phase` (the view adds to it only while it is not held, so a hit-stop holds the noise too). The
// ribbon's own fade (vertex alpha: clear inside and at the tail, bright at the tip edge) is kept.

group_uniforms Color;
uniform vec3 primary_color : source_color = vec3(0.72, 0.94, 1.0);
uniform vec3 secondary_color : source_color = vec3(0.0, 0.81, 0.96);
uniform vec3 tertiary_color : source_color = vec3(0.19, 0.36, 0.89);
uniform float emission : hint_range(0.0, 10.0, 0.01) = 1.6;

group_uniforms Noise;
uniform sampler2D noise_texture : repeat_enable;
uniform float noise_twist = 0.5;
uniform float noise_tiles = 2.0;
uniform float phase = 0.0;

group_uniforms Transparency;
uniform float edge_softness : hint_range(0.0, 1.0, 0.01) = 0.8;

void fragment() {
	vec2 uv = vec2(UV.x * noise_tiles - phase, UV.y * 1.8 + UV.x * noise_twist);
	float noise = texture(noise_texture, uv).r;
	vec3 color = mix(secondary_color, primary_color, smoothstep(0.35, 0.85, noise));
	color = mix(tertiary_color, color, smoothstep(0.0, 0.5, COLOR.a));
	ALBEDO = color * emission;
	float shaped = mix(1.0, smoothstep(0.15, 0.75, noise) * 1.3, edge_softness);
	ALPHA = clamp(COLOR.a * (0.1 + 1.5 * shaped), 0.0, 1.0) * smoothstep(0.0, 0.06, COLOR.a);
}
