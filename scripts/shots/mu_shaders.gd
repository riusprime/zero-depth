extends RefCounted
## v0.8.0 MU (G2, owner O14): the three mockup directions' canvas shaders, drawn in code (no image assets). A tool
## for the G2 shots only (scripts/shots/mock_*.gd through mu_kit.gd); nothing in the shipped game loads it.
## Every plate shader draws its shape inset by `pad` px inside its rect, so a drop shadow and the focus glow fit
## around it; `rect_size` is the rect's size in px (MuKit.Plate keeps it current).

## Shared noise (value noise and fbm on px coordinates).
const NOISE := """
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}
// A box with its corners cut by `c` (positive outside, px).
float sd_chamfer(vec2 p, vec2 h, float c) {
	vec2 q = abs(p) - h;
	float box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	float ch = (abs(p.x) + abs(p.y) - (h.x + h.y - c)) * 0.70710678;
	return max(box, ch);
}
float sd_box(vec2 p, vec2 h) {
	vec2 q = abs(p) - h;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}
float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * t);
}
"""

## A "Salvage": a weathered gunmetal plate: mottled metal with a brushed grain, rust creeping in from the edges and in
## spots, light scratches, a bevel lit from the upper left, a dark rim, rivets at the corners, an optional worn paint
## band along the top (`band`), a paint stripe down the left (`stripe`), a hazard-striped strip along the bottom
## (`hazard` px tall), a punched tag hole with a washer (`hole`), and the focus: an amber rim and glow.
const SALVAGE := (
	"""
shader_type canvas_item;
uniform vec2 rect_size = vec2(100.0);
uniform float pad = 16.0;
uniform float cut = 10.0;
uniform vec4 base : source_color = vec4(0.23, 0.23, 0.22, 1.0);
uniform vec4 band : source_color = vec4(0.0);
uniform float band_h = 0.0;
uniform vec4 stripe : source_color = vec4(0.0);
uniform float stripe_w = 0.0;
uniform float hazard = 0.0;
uniform float hole = 0.0;
uniform float rivets = 1.0;
uniform float rust = 1.0;
uniform float focus = 0.0;
uniform float seed = 0.0;
const vec3 AMBER = vec3(0.96, 0.66, 0.16);
"""
	+ NOISE
	+ """
vec3 paint(vec3 under, vec3 pc, vec2 px, float wear) {
	float chip = smoothstep(0.64, 0.7, fbm(px / 13.0 + seed * 3.1) + wear);
	vec3 worn = pc * (0.82 + 0.25 * noise(px / 3.0));
	return mix(worn, under, chip);
}
void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = rect_size * 0.5;
	vec2 h = c - vec2(pad);
	float d = sd_chamfer(px - c, h, cut);
	float ds = sd_chamfer(px - c - vec2(3.0, 7.0), h, cut);
	vec4 o = vec4(0.0, 0.0, 0.0, (1.0 - smoothstep(-3.0, min(12.0, pad * 0.9), ds)) * 0.6);
	if (focus > 0.0 && d > 0.0) {
		float g = focus * exp(-d / 9.0) * (1.0 - smoothstep(pad * 0.45, pad * 0.95, d));
		o = vec4(mix(o.rgb, AMBER, g / max(o.a + g, 0.001)), max(o.a, g * 0.9));
	}
	if (d > 0.0) {
		COLOR = o;
	} else {
		float e = -d;
		vec2 n = normalize(vec2(dFdx(d), dFdy(d)) + vec2(1e-5));
		vec3 col = base.rgb * (0.78 + 0.42 * fbm(px / 90.0 + seed));
		col += (noise(vec2(px.x / 60.0, px.y * 1.7) + seed) - 0.5) * 0.05;
		if (band.a > 0.0 && px.y - pad < band_h) {
			col = paint(col, band.rgb, px, 0.0);
		}
		if (stripe.a > 0.0 && px.x - pad < stripe_w) {
			col = paint(col, stripe.rgb, px, 0.05);
		}
		if (hazard > 0.0 && px.y > rect_size.y - pad - hazard - 3.0 && px.y < rect_size.y - pad - 3.0) {
			float s = step(0.5, fract((px.x + px.y) / 26.0));
			col = paint(col, mix(vec3(0.07), AMBER * 0.9, s), px, 0.08);
		}
		float r = fbm(px / 24.0 + seed * 7.0);
		float edge = smoothstep(16.0, 1.0, e);
		float rm = smoothstep(0.62, 0.8, r * 0.7 + edge * 0.5) * rust;
		rm = max(rm, smoothstep(0.76, 0.84, fbm(px / 46.0 + seed * 2.0 + 3.0)) * rust * 0.55);
		vec3 rc = mix(vec3(0.22, 0.11, 0.06), vec3(0.48, 0.23, 0.1), noise(px / 5.0 + seed));
		col = mix(col, rc, rm * 0.9);
		float sc = 0.0;
		for (int i = 0; i < 14; i++) {
			float fi = float(i) + seed * 17.0;
			vec2 a = vec2(hash(vec2(fi, 1.3)), hash(vec2(fi, 7.7))) * rect_size;
			vec2 b = a + (vec2(hash(vec2(fi, 2.9)), hash(vec2(fi, 5.1))) - 0.5) * vec2(160.0, 60.0);
			sc += (1.0 - smoothstep(0.0, 1.1, sd_segment(px, a, b))) * (0.4 + 0.6 * hash(vec2(fi, 9.0)));
		}
		col += min(sc, 1.0) * 0.16 * (1.0 - rm);
		float bev = smoothstep(4.0, 0.5, e);
		col += bev * 0.2 * dot(n, normalize(vec2(-0.45, -1.0)));
		if (rivets > 0.0) {
			float ins = cut * 0.5 + 13.0;
			vec2 rv[4] = vec2[4](vec2(pad + ins, pad + ins), vec2(rect_size.x - pad - ins, pad + ins),
				vec2(pad + ins, rect_size.y - pad - ins), vec2(rect_size.x - pad - ins, rect_size.y - pad - ins));
			for (int i = 0; i < 4; i++) {
				vec2 q = px - rv[i];
				float l = length(q);
				col = mix(col, vec3(0.04), (1.0 - smoothstep(4.6, 6.6, l)) * 0.6);
				if (l < 4.8) {
					float lit = clamp(0.55 - dot(q / 4.8, vec2(0.5, 0.75)) * 0.5, 0.0, 1.0);
					col = mix(vec3(0.2, 0.19, 0.18), vec3(0.78, 0.74, 0.68), lit);
				}
			}
		}
		bool punched = false;
		if (hole > 0.0) {
			vec2 hc = vec2(c.x, pad + 22.0);
			float l = length(px - hc);
			if (l < 15.0) {
				col = mix(vec3(0.62, 0.6, 0.56), vec3(0.18), smoothstep(10.0, 15.0, l) * 0.6);
				col += 0.12 * dot(normalize(px - hc + vec2(1e-4)), vec2(-0.5, -0.8));
			}
			punched = l < 8.5;
		}
		col = mix(col, vec3(0.03), smoothstep(2.2, 0.6, e) * 0.85);
		if (focus > 0.0) {
			col = mix(col, AMBER, smoothstep(4.5, 1.5, e) * focus);
		}
		COLOR = punched ? vec4(0.0) : vec4(col, 1.0);
	}
}
"""
)

## B "Ember stone": a dark carved stone slab with chipped, uneven edges, a bevel lit warm from below (the embers) and
## cool and faint from above, cracks and grit, a warm glow rising from its foot (`under`), a glowing inlay in the
## card's element colour (`inlay`: a groove round `inlay_rect` and a line at `inlay_y`), an optional gold rim inlay
## (`rim`), and the focus: a stronger ember glow under the slab and on its lower bevel.
const EMBER_STONE := (
	"""
shader_type canvas_item;
uniform vec2 rect_size = vec2(100.0);
uniform float pad = 18.0;
uniform float cut = 12.0;
uniform vec4 base : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform vec4 inlay : source_color = vec4(0.0);
uniform vec4 inlay_rect = vec4(0.0);
uniform float inlay_round = 0.0;
uniform float inlay_y = -1.0;
uniform vec4 rim : source_color = vec4(0.0);
uniform float under = 0.35;
uniform float focus = 0.0;
uniform float seed = 0.0;
const vec3 EMBER = vec3(0.95, 0.54, 0.23);
"""
	+ NOISE
	+ """
float groove(float dist, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.2, abs(dist));
}
void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = rect_size * 0.5;
	vec2 h = c - vec2(pad);
	float chip = (noise(px / 9.0 + seed) - 0.5) * 4.0 + max(0.0, noise(px / 26.0 + seed * 3.0) - 0.62) * 22.0;
	float d = sd_chamfer(px - c, h, cut) + chip;
	float below = clamp((px.y - c.y) / h.y, -1.0, 1.6);
	if (d > 0.0) {
		float ds = sd_chamfer(px - c - vec2(2.0, 8.0), h, cut);
		float sh = (1.0 - smoothstep(-2.0, min(14.0, pad * 0.9), ds)) * 0.55;
		float g = (under * 0.5 + focus * 0.9) * exp(-d / 16.0) * smoothstep(-0.3, 1.0, below);
		g *= 1.0 - smoothstep(pad * 0.4, pad * 0.95, d);
		vec3 gc = EMBER * 1.1;
		float a = max(sh, g);
		COLOR = vec4(mix(vec3(0.0), gc, g / max(sh + g, 0.001)), a);
	} else {
		float e = -d;
		vec2 n = normalize(vec2(dFdx(d), dFdy(d)) + vec2(1e-5));
		vec3 col = base.rgb * (0.72 + 0.55 * fbm(px / 70.0 + seed));
		col *= 0.92 + 0.16 * noise(px / 4.0 + seed * 5.0);
		col += step(0.985, hash(floor(px / 2.0) + seed)) * 0.06;
		float cr = 1.0 - abs(fbm(px / 110.0 + seed * 9.0) * 2.0 - 1.0);
		col *= 1.0 - smoothstep(0.965, 0.995, cr) * 0.5;
		float bev = smoothstep(8.0, 1.0, e);
		float up = dot(n, vec2(0.0, -1.0));
		float down = dot(n, vec2(0.0, 1.0));
		col += bev * max(up, 0.0) * vec3(0.10, 0.10, 0.12);
		col += bev * max(down, 0.0) * EMBER * (0.35 + 0.6 * focus);
		col -= bev * abs(n.x) * 0.03;
		float foot = pow(clamp((px.y - pad) / (2.0 * h.y), 0.0, 1.0), 3.0);
		col += EMBER * foot * (0.08 + 0.22 * under + 0.25 * focus);
		if (inlay.a > 0.0) {
			float glow = 0.0;
			if (inlay_rect.z > 0.0) {
				vec2 ic = inlay_rect.xy + inlay_rect.zw * 0.5;
				float di = inlay_round > 0.0
					? length(px - ic) - inlay_rect.z * 0.5
					: sd_chamfer(px - ic, inlay_rect.zw * 0.5, inlay_rect.z * 0.18);
				glow += groove(di, 2.4) + exp(-abs(di) / 5.0) * 0.35;
			}
			if (inlay_y >= 0.0 && px.x > pad + 30.0 && px.x < rect_size.x - pad - 30.0) {
				float dl = px.y - inlay_y;
				float fade = smoothstep(pad + 30.0, pad + 70.0, px.x) * smoothstep(rect_size.x - pad - 30.0,
					rect_size.x - pad - 70.0, px.x);
				glow += (groove(dl, 1.8) + exp(-abs(dl) / 4.0) * 0.3) * fade;
			}
			col = mix(col, inlay.rgb * 1.15, clamp(glow, 0.0, 1.0) * inlay.a);
		}
		if (rim.a > 0.0) {
			float dr = e - 11.0;
			col = mix(col, rim.rgb * 1.1, (groove(dr, 1.8) + exp(-abs(dr) / 4.0) * 0.25) * rim.a);
		}
		col = mix(col, vec3(0.02, 0.015, 0.01), smoothstep(2.0, 0.4, e) * 0.85);
		COLOR = vec4(col, 1.0);
	}
}
"""
)

## C "Field kit": a dark charcoal panel, cut on two corners like a faceted kit piece, a soft inner vignette, a thin
## warm-orange edge light on its top and left (all round and glowing on focus), and an optional coloured top band
## (`band`, `band_h`) with a slanted, two-tone faceted lower edge.
const FIELD_KIT := (
	"""
shader_type canvas_item;
uniform vec2 rect_size = vec2(100.0);
uniform float pad = 16.0;
uniform float cut = 14.0;
uniform vec4 base : source_color = vec4(0.09, 0.095, 0.105, 1.0);
uniform vec4 band : source_color = vec4(0.0);
uniform float band_h = 0.0;
uniform float edge = 0.45;
uniform float focus = 0.0;
const vec3 WARM = vec3(0.95, 0.55, 0.24);
"""
	+ NOISE
	+ """
void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = rect_size * 0.5;
	vec2 h = c - vec2(pad);
	vec2 p = px - c;
	float cc = (p.x * p.y > 0.0) ? cut : cut * 0.3;
	float d = sd_chamfer(p, h, cc);
	if (d > 0.0) {
		float ds = sd_chamfer(p - vec2(0.0, 8.0), h, cc);
		float sh = (1.0 - smoothstep(-4.0, min(18.0, pad * 0.9), ds)) * 0.5;
		float g = focus * exp(-d / 11.0) * 0.75 * (1.0 - smoothstep(pad * 0.45, pad * 0.95, d));
		COLOR = vec4(mix(vec3(0.0), WARM, g / max(sh + g, 0.001)), max(sh, g));
	} else {
		float e = -d;
		vec2 n = normalize(vec2(dFdx(d), dFdy(d)) + vec2(1e-5));
		vec3 col = base.rgb * (1.12 - 0.25 * (px.y - pad) / (2.0 * h.y));
		col *= 1.0 - 0.32 * smoothstep(0.35, 1.25, length(p / h));
		col += (noise(px / 2.0) - 0.5) * 0.012;
		if (band.a > 0.0) {
			float lx = (px.x - pad) / (2.0 * h.x);
			float edge_y = pad + band_h - lx * 10.0;
			if (px.y < edge_y) {
				float facet = step(px.x - pad, (px.y - pad) * 1.6 + h.x * 0.9);
				vec3 bc = band.rgb * mix(0.78, 1.0, facet);
				bc *= 0.9 + 0.1 * (1.0 - (px.y - pad) / band_h);
				col = mix(col, bc, band.a);
			}
			col = mix(col, vec3(0.0), (1.0 - smoothstep(0.0, 2.0, abs(px.y - edge_y))) * 0.5 * band.a);
		}
		float lit = clamp(dot(n, normalize(vec2(-0.55, -0.85))), 0.0, 1.0);
		float amount = mix(edge * (0.25 + 0.75 * lit), 1.0, focus);
		float line = 1.0 - smoothstep(0.6, 2.0, e);
		col = mix(col, WARM * (1.0 + focus * 0.3), line * amount);
		col += WARM * exp(-e / 6.0) * 0.12 * (lit * edge + focus);
		COLOR = vec4(col, base.a);
	}
}
"""
)

## The full-screen backdrop over the game, one per direction (`mode` 0 Salvage, 1 Ember stone, 2 Field kit): the game
## blurred (a lower mip of the screen) and dimmed, then: 0, a warm grey wash, darker on the left, with a fine grain;
## 1, a near-black warm wash, darker at the top, a low ember glow rising from the bottom and a few sparks; 2, a cool
## charcoal wash with a deep soft vignette.
const BACKDROP := (
	"""
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int mode = 0;
uniform float lod = 2.4;
uniform float strength = 1.0;
uniform vec2 screen = vec2(1920.0, 1080.0);
const vec3 EMBER = vec3(0.95, 0.5, 0.2);
"""
	+ NOISE
	+ """
void fragment() {
	vec3 g = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	vec2 px = SCREEN_UV * screen;
	vec2 uv = SCREEN_UV;
	vec3 col = g;
	if (mode == 0) {
		float lum = dot(g, vec3(0.3, 0.59, 0.11));
		col = mix(g, vec3(lum) * vec3(1.05, 0.98, 0.9), 0.4);
		col = mix(col, vec3(0.03, 0.028, 0.025), mix(0.8, 0.42, smoothstep(0.0, 0.8, uv.x)));
		col += (hash(floor(px)) - 0.5) * 0.035;
	} else if (mode == 1) {
		col = mix(g, vec3(0.018, 0.012, 0.01), mix(0.85, 0.5, smoothstep(0.0, 0.85, uv.x)));
		col *= 0.75 + 0.25 * uv.y;
		col += EMBER * pow(uv.y, 3.2) * 0.22;
		float spark = step(0.9988, hash(floor(px / 3.0))) * smoothstep(0.45, 1.0, uv.y) * step(0.5, noise(px / 90.0));
		col += EMBER * spark * (0.6 + 0.6 * noise(px / 30.0));
	} else {
		col = mix(g, vec3(0.03, 0.035, 0.04), mix(0.8, 0.5, smoothstep(0.0, 0.85, uv.x)));
		float v = length((uv - vec2(0.5)) * vec2(1.6, 1.0));
		col *= 1.0 - smoothstep(0.35, 1.05, v) * 0.75;
	}
	COLOR = vec4(mix(g, col, strength), 1.0);
}
"""
)

## Spray-stencil type (A's titles): the glyphs eroded by a fine noise, as paint sprayed through a stencil onto metal.
const STENCIL_TYPE := (
	"""
shader_type canvas_item;
"""
	+ NOISE
	+ """
void fragment() {
	vec2 px = FRAGCOORD.xy;
	float n = fbm(px / 3.0) * 0.7 + fbm(px / 26.0) * 0.5;
	COLOR.a *= smoothstep(0.36, 0.5, n);
	COLOR.rgb *= 0.86 + 0.2 * noise(px / 2.0);
}
"""
)
