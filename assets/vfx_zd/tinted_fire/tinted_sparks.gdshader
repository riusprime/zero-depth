// v0.10.5 W3-O7 (owner F6, F16): the Binbun fire pack's sparks (an emissive trail), coloured by the effect's primary.
shader_type spatial;
render_mode unshaded, particle_trails, cull_disabled, shadows_disabled;

uniform vec4 primary_color : source_color = vec4(1.0, 0.33, 0.0, 1.0);
uniform float energy = 2.0;

void fragment() {
	ALBEDO = primary_color.rgb * energy;
}
