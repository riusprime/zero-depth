class_name BossStrikeMeshes
extends RefCounted
## v0.8.0 AV part 2: the code-made meshes and shaders of BossStrikeViews' pools (procedural: nothing downloaded, the
## noise is ProjectileMeshes.noise()). Each pool is one MultiMesh (one draw): rock chunks and blades (lit), rings and
## beams (glowing, or mixed for dust and steam), and ground quads (craters, splats, skids, molten metal, shadows).
## v0.8.0 TX2: the ground quads draw the owner's textures (GROUND_TEX) where they are installed, the code look kept as
## the fallback.

## Ground quad patterns (the GROUND shader's INSTANCE_CUSTOM.r).
const G_CRATER := 0.0
const G_SCORCH := 1.0
const G_SPLAT := 2.0
const G_MOLTEN := 3.0
const G_SHADOW := 4.0
## v0.8.0 TX2: the owner's dust ring (a slam's shockwave), light ring (the lens flare) and skid marks (the lunge).
const G_DUST_RING := 5.0
const G_LIGHT_RING := 6.0
const G_SKID := 7.0
## v0.8.0 TX2: the owner's textures the ground quads draw with (sampler -> [texture id, the flag that turns it on]);
## the code look stays the fallback while a texture is missing.
const GROUND_TEX := {
	"cracks_tex": ["fx_ground_cracks", "cracks_on"],
	"splat_tex": ["fx_acid_splat", "splat_on"],
	"skid_tex": ["fx_skid_marks", "skid_on"],
	"lava_tex": ["fx_lava_flow", "lava_on"],
	"crust_tex": ["tex_lava_crust", "crust_on"],
	"dust_tex": ["fx_dust_ring", "dust_on"],
	"light_tex": ["fx_light_ring", "light_on"],
}
const KIT_DIR := "res://assets/textures/kit/"

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

varying vec4 cd;

// The instance's colour, packed by BossStrikeMeshes.pack (six bits a channel, 0..2).
vec3 unpack(float v) {
	float b = mod(v, 64.0);
	float g = mod(floor(v / 64.0), 64.0);
	float r = floor(v / 4096.0);
	return vec3(r, g, b) / 63.0 * 2.0;
}

void vertex() {
	cd = INSTANCE_CUSTOM;
}

void fragment() {
	float t = TIME * motion;
	vec3 tint = unpack(cd.a);
	if (cd.r < 1.5) {
		float alpha = cd.r;
		float n = texture(noise_tex, vec2(UV.x * 3.0 + cd.g, UV.y * 0.8 - t * 0.6)).r;
		float band = pow(1.0 - UV.y, 1.6) * smoothstep(0.0, 0.08, UV.y);
		ALBEDO = tint * cd.b * mix(0.7, 1.3, n);
		float puff = texture(noise_tex, vec2(UV.x * 7.0 - cd.g, UV.y * 1.5 - t * 0.9)).r;
		ALPHA = clamp(alpha * band * smoothstep(0.42, 0.72, n * 0.6 + puff * 0.6), 0.0, 1.0);
	} else {
		float alpha = cd.r - 2.0;
		float core = pow(abs(dot(NORMAL, VIEW)), 2.5);
		float n = texture(noise_tex, vec2(UV.x * 6.0 - t * 2.5 + cd.g, UV.y)).r;
		ALBEDO = mix(tint, vec3(1.0), core * 0.75) * cd.b * mix(0.75, 1.35, n);
		ALPHA = clamp(alpha * (0.2 + 0.8 * core) * mix(0.6, 1.0, n), 0.0, 1.0);
	}
}
"""

## A flat quad on the floor: a crater, a scorch line, an acid splat, molten metal, a shadow; v0.8.0 TX2: a dust ring,
## a light ring, a skid. Unshaded; the noise is in world space so a stretched quad isn't stretched. INSTANCE_CUSTOM:
## r pattern (G_*) plus sub / 16 (sub: the atlas cell of a 2 x 2 sheet, or a skid's repeats down its length), g heat
## 0..1, b the glow (pack), a alpha.
## v0.8.0 TX2: the owner's textures: the crater's cracks (fx_ground_cracks, tinted by the glow), the acid splat
## (fx_acid_splat), molten metal (fx_lava_flow crusting over into tex_lava_crust as it cools), the skid
## (fx_skid_marks), the dust and light rings; each falls back to the code look while its `*_on` is 0.
const GROUND := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cracks_tex : source_color, filter_linear_mipmap;
uniform sampler2D splat_tex : source_color, filter_linear_mipmap;
uniform sampler2D skid_tex : source_color, filter_linear_mipmap;
uniform sampler2D lava_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D crust_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dust_tex : source_color, filter_linear_mipmap;
uniform sampler2D light_tex : source_color, filter_linear_mipmap;
uniform float cracks_on = 0.0;
uniform float splat_on = 0.0;
uniform float skid_on = 0.0;
uniform float lava_on = 0.0;
uniform float crust_on = 0.0;
uniform float dust_on = 0.0;
uniform float light_on = 0.0;
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

// One cell of a 2 x 2 sheet at the quad's UV.
vec4 cell(sampler2D t, vec2 uv, float k) {
	vec2 c = vec2(mod(k, 2.0), floor(k / 2.0));
	return texture(t, (clamp(uv, 0.004, 0.996) + c) * 0.5);
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
	int p = int(floor(cd.r + 0.001));
	float sub = floor(fract(cd.r + 0.001) * 16.0 + 0.5);
	if (p == 0) {  // crater: a dark bowl, a hot cracked rim
		float d = length(uv) + (n - 0.5) * 0.35;
		a = 1.0 - smoothstep(0.78, 1.0, d);
		float rim = smoothstep(0.45, 0.85, d);
		if (cracks_on > 0.5) {  // the owner's cracks, glowing in the strike's colour as it cools
			vec4 k = cell(cracks_tex, UV, sub);
			c = mix(dark * mix(0.6, 1.0, d), glow * (0.85 + 1.2 * k.g), clamp(k.a * (0.35 + heat), 0.0, 1.0));
			c = mix(c, glow * 1.2, rim * 0.2 * heat * (1.0 - k.a));
		} else {
			c = mix(dark * mix(0.6, 1.0, d), glow * 1.8, clamp((veins + rim * 0.4) * heat, 0.0, 1.0));
		}
	} else if (p == 1) {  // scorch line: charred down the middle, embers in its cracks
		float across = abs(uv.y) + (n - 0.5) * 0.5;
		a = 1.0 - smoothstep(0.55, 1.0, across);
		c = mix(dark, glow * 2.2, clamp(veins * heat * 1.4 + (1.0 - across) * heat * 0.3, 0.0, 1.0));
	} else if (p == 2) {  // acid splat: a blobby pool, bright bubbles in it
		if (splat_on > 0.5) {  // the owner's splat, in its own greens
			vec4 k = cell(splat_tex, UV, sub);
			a = k.a * 0.95;
			c = k.rgb * mix(0.75, 1.25, heat);
		} else {
			float d = length(uv) + (n - 0.5) * 0.9;
			a = (1.0 - smoothstep(0.55, 0.8, d)) * 0.9;
			float bub = smoothstep(0.62, 0.7, n2);
			c = mix(glow * 0.35, glow * (1.2 + heat), clamp(bub + heat * 0.4, 0.0, 1.0));
		}
	} else if (p == 3) {  // molten metal: flowing, a crust closing in as it cools
		float f = texture(noise_tex, wp.xz * 0.22 + vec2(t * 0.12, t * 0.05) + vec2(fract(cd.b / 97.0))).r;
		float across = abs(uv.y) + (n - 0.5) * 0.25;
		a = 1.0 - smoothstep(0.8, 1.0, across);
		if (lava_on > 0.5) {
			// The owner's lava flowing down the lane, kept dim over the area (the stage's exposure turns a bright bed
			// to cream); as it cools the crust's plates close in, its seams the last to go dark.
			vec4 lv = texture(lava_tex, wp.xz * 0.28 + vec2(t * 0.05, t * 0.02));
			vec3 molten = lv.rgb * mix(0.45, 0.85, lv.a) * mix(0.6, 1.0, heat);
			c = molten;
			if (crust_on > 0.5) {
				vec4 cr = texture(crust_tex, wp.xz * 0.3);
				float close = smoothstep(heat, heat + 0.3, 1.0 - cr.a);
				c = mix(molten, cr.rgb * 0.7, close * (1.0 - cr.a));
			}
		} else {
			float seam = 1.0 - smoothstep(0.0, mix(0.02, 0.25, heat), abs(f - 0.5));
			float hotness = clamp(seam + heat * 0.3 * f, 0.0, 1.0);
			// Kept dim over the area (the stage's exposure turns a bright bed to cream); only the seams run hot.
			vec3 molten = mix(glow * vec3(0.55, 0.3, 0.2), vec3(1.2, 0.45, 0.08), seam * heat);
			c = mix(vec3(0.09, 0.05, 0.04), molten, hotness);
		}
	} else if (p == 5) {  // v0.8.0 TX2: the owner's dust ring blasting out (its own dust and stones)
		vec4 k = cell(dust_tex, UV, sub);
		a = k.a * dust_on;
		c = k.rgb * 1.15;
	} else if (p == 6) {  // v0.8.0 TX2: the owner's light ring, tinted toward the strike's glow
		vec4 k = texture(light_tex, UV);
		a = k.a * light_on;
		c = mix(k.rgb, glow, 0.35) * 1.6;
	} else if (p == 7) {  // v0.8.0 TX2: the owner's skid (its first cell: two straight grooves) down the lane
		// Sampled with the unwrapped coordinate's gradients, so the repeat's wrap shows no mip seam.
		vec2 run = vec2(UV.y, UV.x * max(sub, 1.0));
		vec2 q = (clamp(vec2(run.x, fract(run.y)), 0.004, 0.996)) * 0.5;
		vec4 k = textureGrad(skid_tex, q, dFdx(run) * 0.5, dFdy(run) * 0.5);
		float ember = clamp((k.r - k.b) * 2.0, 0.0, 1.0);
		a = k.a * skid_on;
		c = mix(k.rgb, k.rgb * 0.25, ember * (1.0 - heat));
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


## v0.8.0 TX2: an owner texture by id (VfxCore.DIR for the fx_ ones, KIT_DIR for the surfaces), or null.
static func texture(id: String) -> Texture2D:
	var path := tex_path(id)
	return load(path) if ResourceLoader.exists(path) else null


static func tex_path(id: String) -> String:
	return (VfxCore.DIR if id.begins_with("fx_") else KIT_DIR) + id + ".png"


## v0.8.0 TX2: true when the owner's texture `id` is installed (the shapes pick their geometry by it).
static func textured(id: String) -> bool:
	return ResourceLoader.exists(tex_path(id))


## v0.8.0 TX2: gives a GROUND material the owner's textures, turning on each one that is installed.
## `slots` limits it to those samplers (the Foundry's lava and meltdown take only the lava and the crust).
static func set_ground_textures(m: ShaderMaterial, slots: Array = GROUND_TEX.keys()) -> void:
	for slot: String in slots:
		var spec: Array = GROUND_TEX[slot]
		var tex := texture(spec[0])
		m.set_shader_parameter(slot, tex)
		m.set_shader_parameter(spec[1], 1.0 if tex != null else 0.0)


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
