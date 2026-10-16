class_name BossStrikeMeshes
extends RefCounted
## v0.8.0 AV part 2: the code-made meshes and shaders of BossStrikeViews' pools (procedural: nothing downloaded, the
## noise is ProjectileMeshes.noise()). Each pool is one MultiMesh (one draw): rock chunks and blades (lit), rings and
## beams (glowing, or mixed for dust and steam), and ground quads (craters, splats, skids, molten metal, shadows).

## Ground quad patterns (the GROUND shader's INSTANCE_CUSTOM.r).
const G_CRATER := 0.0
const G_SCORCH := 1.0
const G_SPLAT := 2.0
const G_MOLTEN := 3.0
const G_SHADOW := 4.0

## A lit rock chunk (or egg shell, or a shell casing): the colour is the instance's, its veins glow with heat.
## INSTANCE_CUSTOM: r heat 0..1, g seed, b glow index (GLOWS), a unused.
const ROCK := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
const vec3 GLOWS[4] = vec3[4](vec3(1.0, 0.42, 0.18), vec3(0.62, 1.0, 0.22), vec3(1.0, 0.86, 0.5),
		vec3(1.0, 0.55, 0.1));

varying vec4 cd;
varying vec3 lp;

// The instance's colour, packed by BossStrikeMeshes.pack (six bits a channel, 0..2).
vec3 unpack(float v) {
	float b = mod(v, 64.0);
	float g = mod(floor(v / 64.0), 64.0);
	float r = floor(v / 4096.0);
	return vec3(r, g, b) / 63.0 * 2.0;
}

void vertex() {
	cd = INSTANCE_CUSTOM;
	lp = VERTEX;
}

void fragment() {
	float n = texture(noise_tex, vec2(lp.x * 1.7 + lp.z + cd.g, lp.y * 1.3 + cd.g * 3.0)).r;
	float veins = 1.0 - smoothstep(0.015, 0.06, abs(n - 0.5));
	ALBEDO = unpack(cd.a) * mix(0.55, 1.15, n);
	EMISSION = GLOWS[int(cd.b + 0.5)] * (veins * cd.r * 4.0 + cd.r * 0.25);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
"""

## A lit blade (a spear, a javelin): steel with a bright edge, red-hot near the floor while it is fresh.
## INSTANCE_CUSTOM: r heat, g seed.
const BLADE := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 hot : source_color = vec4(1.0, 0.5, 0.18, 1.0);

varying vec4 cd;
varying vec3 lp;

// The instance's colour, packed by BossStrikeMeshes.pack (six bits a channel, 0..2).
vec3 unpack(float v) {
	float b = mod(v, 64.0);
	float g = mod(floor(v / 64.0), 64.0);
	float r = floor(v / 4096.0);
	return vec3(r, g, b) / 63.0 * 2.0;
}

void vertex() {
	cd = INSTANCE_CUSTOM;
	lp = VERTEX;
}

void fragment() {
	float low = 1.0 - smoothstep(0.0, 0.35, lp.y);
	ALBEDO = vec3(0.72, 0.7, 0.68);
	METALLIC = 0.75;
	ROUGHNESS = 0.32;
	EMISSION = hot.rgb * cd.r * (low * low * 2.5 + 0.15);
}
"""

## A ring (an open band one unit round and tall) or a beam (a tube along +x): unshaded, `%s` the blend. The band
## fades to its top and breaks up in noise; a beam is brightest down its middle (facing the camera).
## INSTANCE_CUSTOM: r the alpha (plus 2 for a beam), g seed, b brightness, a the colour (pack).
const GLOW := """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float motion = 1.0;
// v0.8.0 TX1: the owner's beam strip (fx_beam row tex_row), for a beam whose r is 4 + alpha (FxTextures).
uniform sampler2D beam_tex : filter_linear_mipmap, repeat_enable;
uniform float tex_on = 0.0;
uniform float tex_row = 2.0;
uniform float tex_tile = 5.0;

varying vec4 cd;
varying float along_m;
varying vec3 perp;

// The instance's colour, packed by BossStrikeMeshes.pack (six bits a channel, 0..2).
vec3 unpack(float v) {
	float b = mod(v, 64.0);
	float g = mod(floor(v / 64.0), 64.0);
	float r = floor(v / 4096.0);
	return vec3(r, g, b) / 63.0 * 2.0;
}

void vertex() {
	cd = INSTANCE_CUSTOM;
	along_m = VERTEX.x * length(MODEL_MATRIX[0].xyz);
	vec3 axis = (MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	vec3 c = cross(axis, vec3(0.0, 0.0, 1.0));
	perp = length(c) > 0.00001 ? normalize(c) : vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float t = TIME * motion;
	vec3 tint = unpack(cd.a);
	if (cd.r > 3.5 && tex_on > 0.5) {
		float alpha = cd.r - 4.0;
		float across = dot(normalize(NORMAL), perp);
		float y = (tex_row + clamp(0.5 + 0.5 * across, 0.03, 0.97)) * 0.25;
		vec4 s = texture(beam_tex, vec2(along_m / tex_tile - t * 0.5 + cd.g, y));
		ALBEDO = mix(tint, vec3(1.0), s.r * 0.7) * cd.b * 0.55;
		ALPHA = clamp(alpha * s.a, 0.0, 1.0);
	} else if (cd.r < 1.5) {
		float alpha = cd.r;
		float n = texture(noise_tex, vec2(UV.x * 3.0 + cd.g, UV.y * 0.8 - t * 0.6)).r;
		float band = pow(1.0 - UV.y, 1.6) * smoothstep(0.0, 0.08, UV.y);
		ALBEDO = tint * cd.b * mix(0.7, 1.3, n);
		float puff = texture(noise_tex, vec2(UV.x * 7.0 - cd.g, UV.y * 1.5 - t * 0.9)).r;
		ALPHA = clamp(alpha * band * smoothstep(0.42, 0.72, n * 0.6 + puff * 0.6), 0.0, 1.0);
	} else {
		float alpha = cd.r - (cd.r > 3.5 ? 4.0 : 2.0);
		float core = pow(abs(dot(NORMAL, VIEW)), 2.5);
		float n = texture(noise_tex, vec2(UV.x * 6.0 - t * 2.5 + cd.g, UV.y)).r;
		ALBEDO = mix(tint, vec3(1.0), core * 0.75) * cd.b * mix(0.75, 1.35, n);
		ALPHA = clamp(alpha * (0.2 + 0.8 * core) * mix(0.6, 1.0, n), 0.0, 1.0);
	}
}
"""

## A flat quad on the floor: a crater, a scorch line, an acid splat, molten metal, a shadow. Unshaded; the noise is in
## world space so a stretched quad isn't stretched. INSTANCE_CUSTOM: r pattern (G_*), g heat 0..1, b the glow (pack),
## a alpha.
const GROUND := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float motion = 1.0;

varying vec4 cd;
varying vec3 wp;

// The instance's colour, packed by BossStrikeMeshes.pack (six bits a channel, 0..2).
vec3 unpack(float v) {
	float b = mod(v, 64.0);
	float g = mod(floor(v / 64.0), 64.0);
	float r = floor(v / 4096.0);
	return vec3(r, g, b) / 63.0 * 2.0;
}

void vertex() {
	cd = INSTANCE_CUSTOM;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME * motion;
	float heat = cd.g;
	float n = texture(noise_tex, wp.xz * 0.16 + vec2(fract(cd.b / 97.0))).r;
	float n2 = texture(noise_tex, wp.xz * 0.45 - vec2(fract(cd.b / 53.0))).r;
	float veins = 1.0 - smoothstep(0.0, 0.05, abs(n2 - 0.5));
	vec3 dark = vec3(0.06, 0.05, 0.045);
	vec3 glow = unpack(cd.b);
	float a = 0.0;
	vec3 c = dark;
	int p = int(cd.r + 0.5);
	if (p == 0) {  // crater: a dark bowl, a hot cracked rim
		float d = length(uv) + (n - 0.5) * 0.35;
		a = 1.0 - smoothstep(0.78, 1.0, d);
		float rim = smoothstep(0.45, 0.85, d);
		c = mix(dark * mix(0.6, 1.0, d), glow * 1.8, clamp((veins + rim * 0.4) * heat, 0.0, 1.0));
	} else if (p == 1) {  // scorch line: charred down the middle, embers in its cracks
		float across = abs(uv.y) + (n - 0.5) * 0.5;
		a = 1.0 - smoothstep(0.55, 1.0, across);
		c = mix(dark, glow * 2.2, clamp(veins * heat * 1.4 + (1.0 - across) * heat * 0.3, 0.0, 1.0));
	} else if (p == 2) {  // acid splat: a blobby pool, bright bubbles in it
		float d = length(uv) + (n - 0.5) * 0.9;
		a = (1.0 - smoothstep(0.55, 0.8, d)) * 0.9;
		float bub = smoothstep(0.62, 0.7, n2);
		c = mix(glow * 0.35, glow * (1.2 + heat), clamp(bub + heat * 0.4, 0.0, 1.0));
	} else if (p == 3) {  // molten metal: flowing, a crust closing in as it cools
		float f = texture(noise_tex, wp.xz * 0.22 + vec2(t * 0.12, t * 0.05) + vec2(fract(cd.b / 97.0))).r;
		float across = abs(uv.y) + (n - 0.5) * 0.25;
		a = 1.0 - smoothstep(0.8, 1.0, across);
		float seam = 1.0 - smoothstep(0.0, mix(0.02, 0.25, heat), abs(f - 0.5));
		float hotness = clamp(seam + heat * 0.3 * f, 0.0, 1.0);
		// Kept dim over the area (the stage's exposure turns a bright bed to cream); only the seams run hot.
		vec3 molten = mix(glow * vec3(0.55, 0.3, 0.2), vec3(1.2, 0.45, 0.08), seam * heat);
		c = mix(vec3(0.09, 0.05, 0.04), molten, hotness);
	} else {  // shadow: a soft dark disc
		float d = length(uv);
		a = (1.0 - smoothstep(0.45, 1.0, d)) * 0.7;
		c = vec3(0.0);
	}
	ALBEDO = c;
	ALPHA = clamp(a * cd.a, 0.0, 1.0);
}
"""

## The colours ride in INSTANCE_CUSTOM (pack), not in the MultiMesh instance colours: on the build machine's renderer
## COLOR came through white in these shaders (the shots showed it); the custom data is what is proven to arrive.

static var _rock: ArrayMesh
static var _blade: ArrayMesh
static var _band: ArrayMesh
static var _tube: ArrayMesh
static var _shaders := {}


## A colour (0..2 a channel) packed into one float, six bits a channel (exact in a 32-bit float).
static func pack(c: Color) -> float:
	var r := clampi(roundi(c.r * 31.5), 0, 63)
	var g := clampi(roundi(c.g * 31.5), 0, 63)
	var b := clampi(roundi(c.b * 31.5), 0, 63)
	return float(r * 4096 + g * 64 + b)


static func shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## A rough rock chunk about one unit across, centred: a jittered octahedron with a few cut corners.
static func rock() -> ArrayMesh:
	if _rock == null:
		var pts := [
			Vector3(0.5, 0.05, 0.08),
			Vector3(-0.46, -0.04, -0.1),
			Vector3(0.06, 0.44, -0.05),
			Vector3(-0.08, -0.4, 0.04),
			Vector3(0.1, 0.02, 0.48),
			Vector3(-0.04, 0.08, -0.5),
		]
		var faces := [
			[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]
		]
		var tris := []
		for f: Array in faces:
			tris.append([pts[f[0]], pts[f[1]], pts[f[2]]])
		_rock = AvatarBase.flat_mesh(tris, Vector3.ZERO)
	return _rock


## A spear one unit tall standing on y = 0 (planted a little below): a four-sided shaft, a broad leaf head, a point.
static func blade() -> ArrayMesh:
	if _blade == null:
		var ring := func(y: float, r: float) -> Array:
			return [Vector3(r, y, 0), Vector3(0, y, r), Vector3(-r, y, 0), Vector3(0, y, -r)]
		var levels: Array = [
			ring.call(-0.1, 0.05), ring.call(0.6, 0.04), ring.call(0.7, 0.13), ring.call(0.86, 0.08)
		]
		var tris := []
		for l in levels.size() - 1:
			var a: Array = levels[l]
			var b: Array = levels[l + 1]
			for k in 4:
				tris.append([a[k], a[(k + 1) % 4], b[k]])
				tris.append([a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
		var top: Array = levels[levels.size() - 1]
		for k in 4:
			tris.append([top[k], top[(k + 1) % 4], Vector3(0, 1.0, 0)])
		_blade = AvatarBase.flat_mesh(tris, Vector3(0, 0.5, 0))
	return _blade


## An open band one unit round and one unit tall on y = 0..1, UV x round, y up.
static func band() -> ArrayMesh:
	if _band == null:
		_band = _tube_mesh(48, false)
	return _band


## A tube of radius one along +x from 0 to 1, UV x along, y round.
static func tube() -> ArrayMesh:
	if _tube == null:
		_tube = _tube_mesh(12, true)
	return _tube


static func _tube_mesh(n: int, along_x: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var quad := []
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var a := a0 if corner.x == 0.0 else a1
			var u := float(k + corner.x) / n
			var nrm := Vector3(0, cos(a), sin(a)) if along_x else Vector3(cos(a), 0, sin(a))
			var v := nrm + (Vector3(corner.y, 0, 0) if along_x else Vector3(0, corner.y, 0))
			var uv := Vector2(corner.y, u) if along_x else Vector2(u, corner.y)
			quad.append([v, nrm, uv])
		for idx: int in [0, 1, 2, 0, 2, 3]:
			var q: Array = quad[idx]
			st.set_normal(q[1])
			st.set_uv(q[2])
			st.add_vertex(q[0])
	return st.commit()


## A flat quad one unit square on the floor (normal up), UV 0..1.
static func ground() -> PlaneMesh:
	var m := PlaneMesh.new()
	m.size = Vector2(1, 1)
	return m
