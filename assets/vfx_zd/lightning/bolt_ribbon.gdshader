// A lightning ribbon in the Binbun beam's style. Built from the pack's beam_core (hot centre, fresnel-like glow, pulse)
// and beam_outer (a scrolling noise shell) shaders. The mesh is one fixed strip (ZdBolt.strip_mesh: UV.x across, UV2 the
// point's line and index along it); the vertex stage lays the jagged line out from a few numbers (its two ends, its
// seed, its flicker count, its width) exactly as ZdBolt.lines() does on the CPU, and turns it to face the camera, so a
// bolt that moves or flickers rebuilds no geometry.
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
// The vertex stage works the length out from the line itself; this is left for the materials that set it.
uniform float beam_length = 4.0;

group_uniforms Pulse;
uniform float pulse_speed = 30.0;
uniform float pulse_strength = 0.3;

group_uniforms General;
uniform bool outer = false;
uniform float fade : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0, 0.01) = 0.8;

// The bolt (ZdBolt sets these): its ends in the node's space, its seed, its flicker count, its core width (m).
group_uniforms Bolt;
uniform vec3 end_a = vec3(0.0);
uniform vec3 end_b = vec3(0.0);
uniform int bolt_seed = 0;
uniform int flicks = 0;
uniform float width = 0.12;
uniform bool has_ends = false;

// ZdBolt's constants.
const int SEG_MIN = 6;
const float SEG_SPAN = 5.0;
const float JITTER = 0.12;
const float FORK_MAX = 2.0;
const float FORK_LEN = 0.25;
const float SHELL = 3.2;

varying float v_beam_length;

// ZdBolt.hash01 on 32-bit words: its masks keep only the low 31 bits, so the 64-bit and the 32-bit sums agree.
float hash01(int a, int b) {
	uint x = ((uint(a) * 73856093u) ^ (uint(b) * 19349663u) ^ 0x2545F491u) & 0x7FFFFFFFu;
	x = ((x ^ (x >> 13u)) * 1274126177u) & 0x7FFFFFFFu;
	x = x ^ (x >> 16u);
	return float(x & 0xFFFFu) / 65535.0;
}

struct Frame {
	vec3 d;
	vec3 u;
	vec3 side;
	vec3 up;
	float span;
	float amp;
	int n;
	int key;
	int forks;
};

Frame frame_of() {
	Frame f;
	f.d = end_b - end_a;
	f.span = length(f.d);
	f.u = f.d / max(f.span, 1e-9);
	vec3 s = cross(f.u, vec3(0.0, 1.0, 0.0));
	if (length(s) < 0.01) {
		s = cross(f.u, vec3(1.0, 0.0, 0.0));
	}
	f.side = normalize(s);
	f.up = normalize(cross(f.u, f.side));
	f.key = int(uint(bolt_seed) * 31u + uint(flicks));
	f.n = SEG_MIN + int(hash01(bolt_seed, 7) * (SEG_SPAN - 0.001));
	f.amp = f.span * JITTER;
	f.forks = int(hash01(bolt_seed, 11) * (FORK_MAX + 0.999));
	return f;
}

vec3 main_point(Frame f, int i) {
	if (i <= 0) {
		return end_a;
	}
	if (i >= f.n) {
		return end_b;
	}
	vec3 p = end_a + f.d * (float(i) / float(f.n));
	p += f.side * (hash01(f.key, i) * 2.0 - 1.0) * f.amp;
	p += f.up * (hash01(f.key, i + 40) * 2.0 - 1.0) * f.amp * 0.5;
	return p;
}

vec3 fork_point(Frame f, int k, int j) {
	int at = 1 + int(hash01(bolt_seed, 20 + k) * (float(f.n) - 2.001));
	vec3 root = main_point(f, at);
	if (j <= 0) {
		return root;
	}
	float sgn = hash01(bolt_seed, 30 + k) < 0.5 ? 1.0 : -1.0;
	vec3 bend = f.side * sgn * (0.6 + 0.5 * hash01(f.key, 60 + k));
	vec3 dir = normalize(f.u + bend + f.up * (hash01(f.key, 70 + k) - 0.5) * 0.6);
	vec3 q = root + dir * f.span * FORK_LEN * (float(j) / 3.0);
	q += f.side * (hash01(f.key, 80 + k * 4 + j) * 2.0 - 1.0) * f.amp * 0.5;
	return q;
}

// Point `i` of line `line` (0 the main line, 1 and 2 the forks).
vec3 line_point(Frame f, int line, int i) {
	return line == 0 ? main_point(f, i) : fork_point(f, line - 1, i);
}

// The length of line `line` from its first point to point `upto`.
float line_length(Frame f, int line, int upto) {
	float s = 0.0;
	vec3 prev = line_point(f, line, 0);
	for (int i = 1; i <= upto; i++) {
		vec3 p = line_point(f, line, i);
		s += distance(p, prev);
		prev = p;
	}
	return s;
}

void vertex() {
	Frame f = frame_of();
	int line = int(UV2.x + 0.5);
	int i = int(UV2.y + 0.5);
	v_beam_length = 1.0;
	if (!has_ends || f.span < 0.001 || line - 1 >= f.forks) {
		// No bolt, or a fork this bolt does not have: every vertex on one point, nothing drawn.
		VERTEX = end_a;
	} else {
		int last = line == 0 ? f.n : 3;
		// The strip's spare points past a shorter line's end stand on that end (their triangles have no area).
		i = min(i, last);
		float main_len = line_length(f, 0, f.n);
		float total = main_len;
		for (int k = 0; k < f.forks; k++) {
			total += line_length(f, k + 1, 3);
		}
		float run = 0.0;
		if (line > 0) {
			run = main_len;
			for (int k = 0; k < line - 1; k++) {
				run += line_length(f, k + 1, 3);
			}
		}
		float along = line_length(f, line, i);
		vec3 p = line_point(f, line, i);
		vec3 t = line_point(f, line, min(i + 1, last)) - line_point(f, line, max(i - 1, 0));
		// The way the camera looks, in world space, crossed with the line's local tangent (as ZdBolt did).
		vec3 view = -INV_VIEW_MATRIX[2].xyz;
		vec3 s = cross(t, view);
		s = length(s) > 0.0001 ? normalize(s) : vec3(0.0, 1.0, 0.0);
		float thin = line == 0 ? 1.0 : 0.55;
		float taper = line == 0 ? 1.0 : 1.0 - 0.8 * float(i) / 3.0;
		float w = width * (outer ? SHELL : 1.0) * 0.5;
		vec3 dd = s * w * thin * taper;
		VERTEX = UV.x < 0.5 ? p - dd : p + dd;
		UV = vec2(UV.x, (run + along) / max(total, 0.001));
		v_beam_length = max(total * 0.6, 1.0);
	}
}

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float pulse = 1.0 + sin(UV.y * v_beam_length * 6.0 - TIME * pulse_speed) * pulse_strength;
	vec3 color;
	float alpha;
	if (outer) {
		vec2 uv = UV * vec2(1.0, v_beam_length);
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
