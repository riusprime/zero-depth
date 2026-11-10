class_name VatLooks
extends RefCounted
## v0.10.5 W3-V1 (the enemy VAT pilot): the material a VatCrowd draws a kind with. Its vertex stage poses each vertex
## from the baked joint transforms (VatBake: each joint on its grid, multilinear over the instance's drives, a loop
## wrapped; a joint after its parent, up its chain, as the scene tree composed the nodes); its fragment stage is
## EnemyLooks' body and accent shading, unchanged (the same render modes, ALBEDO / METALLIC / SPECULAR / ROUGHNESS, a
## plate's emission mix(rest, hit, shown), an accent's colour x its glow), with the per-piece colours from the mesh's
## CUSTOM0 / CUSTOM1 instead of one material per piece.
## Per instance (VatCrowd): INSTANCE_CUSTOM = the drives 0..3 (the Swarmer's: windup raise, strike, crouch, gait phase);
## v0.10.5 W3-V4a: a rig with more drives reads the rest from zd_drives, the instance's row (INSTANCE_ID), four a
## texel. COLOR = the hit value's rgb (EnemyLooks.hit_value) and in alpha the accent glow g, as g when the hit is off
## and -(1 + g) when it shows. The mesh has no vertex colours, so COLOR in the vertex stage is the instance's alone.
## v0.10.5 W3-V4a: a plain plate (mode 2: the Charger's face) takes neither the flash nor a glow; a rig whose joints
## scale (the Charger's lunge stretch) turns its normals by the inverse transpose, as the scene does; a mesh with
## two-sided pieces (the Charger's cull_disabled shell) draws with cull_disabled and drops the back faces of its
## one-sided ones (CUSTOM2.y).
## v0.10.5 W3-V4b: mode 3 is an accent glowing at the instance's drive 3 (INSTANCE_CUSTOM.w) instead of COLOR's (the
## Sniper's muzzle: its own glow; that rig has no gait); a pose with an `albedo_tex` (the owner's models) draws the
## textured variant: each plate's (mode 0) albedo times that map at the mesh's UV, as EnemyLooks.body's textured plates.
## v0.10.5 W3-V4c: up to 32 drives (the drive texture's first three texels fill d, the next four e); CUSTOM2.z > 0
## makes an accent glow at drive CUSTOM2.z - 1 instead of the instance's glow (the Needle's muzzle: a second glow), and
## CUSTOM2.w = 1 draws a piece unshaded, as an unshaded StandardMaterial3D shows it: its albedo as is, no light, no
## flash (the Warden's cracks, the Arc Caster's crystal, the Bomb Drone's fuse). Flags, not new mode numbers.
## Presentation only (EI-07).

## The joint chain is followed up to VatBake.MAX_CHAIN (32) joints.
const _POSE := """
uniform sampler2D zd_pose : filter_nearest;
uniform sampler2D zd_drives : filter_nearest;
uniform int zd_drive_texels = 0;
uniform bool zd_scaled = false;

float zd_drive(int di, mat4 d, mat4 e) {
	int k = di < 16 ? di : di - 16;
	return di < 16 ? d[k / 4][k - (k / 4) * 4] : e[k / 4][k - (k / 4) * 4];
}

mat4 zd_local(int slot, int grid, mat4 d, mat4 e) {
	if (grid < 0) {
		return mat4(1.0);
	}
	vec4 ga = texelFetch(zd_pose, ivec2(grid * 2, 1), 0);
	vec4 gb = texelFetch(zd_pose, ivec2(grid * 2 + 1, 1), 0);
	int row0 = int(ga.w);
	ivec3 n = ivec3(gb.xyz);
	int loops = int(gb.w);
	ivec3 i0 = ivec3(0);
	ivec3 i1 = ivec3(0);
	vec3 f = vec3(0.0);
	for (int a = 0; a < 3; a++) {
		int di = int(ga[a]);
		int na = n[a];
		if (di < 0 || na < 2) {
			continue;
		}
		float v = zd_drive(di, d, e);
		if (((loops >> a) & 1) == 1) {
			float u = fract(v) * float(na);
			int k0 = int(floor(u)) % na;
			i0[a] = k0;
			i1[a] = (k0 + 1) % na;
			f[a] = u - floor(u);
		} else {
			float g = clamp(v, 0.0, 1.0) * float(na - 1);
			int k0 = min(int(floor(g)), na - 2);
			i0[a] = k0;
			i1[a] = k0 + 1;
			f[a] = g - float(k0);
		}
	}
	vec4 r0 = vec4(0.0);
	vec4 r1 = vec4(0.0);
	vec4 r2 = vec4(0.0);
	int x = slot * 3;
	for (int c = 0; c < 8; c++) {
		ivec3 o = ivec3(c & 1, (c >> 1) & 1, (c >> 2) & 1);
		vec3 wv = mix(vec3(1.0) - f, f, vec3(o));
		float w = wv.x * wv.y * wv.z;
		if (w == 0.0) {
			continue;
		}
		ivec3 ix = ivec3(o.x == 1 ? i1.x : i0.x, o.y == 1 ? i1.y : i0.y, o.z == 1 ? i1.z : i0.z);
		int row = row0 + ix.x + n.x * (ix.y + n.y * ix.z);
		r0 += texelFetch(zd_pose, ivec2(x, row), 0) * w;
		r1 += texelFetch(zd_pose, ivec2(x + 1, row), 0) * w;
		r2 += texelFetch(zd_pose, ivec2(x + 2, row), 0) * w;
	}
	return mat4(
		vec4(r0.x, r1.x, r2.x, 0.0),
		vec4(r0.y, r1.y, r2.y, 0.0),
		vec4(r0.z, r1.z, r2.z, 0.0),
		vec4(r0.w, r1.w, r2.w, 1.0)
	);
}

mat4 zd_chain(int j, mat4 d, mat4 e) {
	mat4 m = mat4(1.0);
	for (int k = 0; k < 32; k++) {
		if (j < 0) {
			break;
		}
		vec4 jt = texelFetch(zd_pose, ivec2(j, 0), 0);
		m = zd_local(int(jt.y), int(jt.x), d, e) * m;
		j = int(jt.z);
	}
	return m;
}

vec3 zd_normal(mat4 m, vec3 n) {
	mat3 b = mat3(m);
	if (zd_scaled) {
		b = transpose(inverse(b));
	}
	return normalize(b * n);
}
"""
## The instance's drives and its pose (vertex stage only: INSTANCE_CUSTOM, INSTANCE_ID).
const _DRIVES := """
	mat4 d = mat4(INSTANCE_CUSTOM, vec4(0.0), vec4(0.0), vec4(0.0));
	mat4 e = mat4(0.0);
	for (int k = 0; k < min(zd_drive_texels, 3); k++) {
		d[k + 1] = texelFetch(zd_drives, ivec2(k, INSTANCE_ID), 0);
	}
	for (int k = 3; k < min(zd_drive_texels, 7); k++) {
		e[k - 3] = texelFetch(zd_drives, ivec2(k, INSTANCE_ID), 0);
	}
	mat4 m = zd_chain(int(CUSTOM2.x), d, e);
"""
const _BODY_HEAD := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
"""
const _BODY_VARYINGS := """
varying vec3 zd_albedo;
varying vec3 zd_emit;
varying vec3 zd_hit;
varying flat float zd_mode;
varying flat float zd_shown;
varying flat float zd_glow;
varying flat float zd_one_sided;
varying flat float zd_unshaded;

void vertex() {"""
const _BODY_VERTEX := """
	VERTEX = (m * vec4(VERTEX, 1.0)).xyz;
	NORMAL = zd_normal(m, NORMAL);
	zd_albedo = CUSTOM0.rgb;
	zd_mode = CUSTOM0.a;
	zd_emit = CUSTOM1.rgb;
	zd_hit = COLOR.rgb;
	zd_shown = COLOR.a < 0.0 ? 1.0 : 0.0;
	zd_glow = COLOR.a < 0.0 ? -COLOR.a - 1.0 : COLOR.a;
	zd_glow = CUSTOM0.a > 2.5 ? INSTANCE_CUSTOM.w : zd_glow;
	zd_one_sided = CUSTOM2.y;
	zd_glow = CUSTOM2.z > 0.5 ? zd_drive(int(CUSTOM2.z + 0.5) - 1, d, e) : zd_glow;
	zd_unshaded = CUSTOM2.w;
}

void fragment() {"""
## v0.10.5 W3-V4a: in the two-sided variant, a one-sided piece's back faces are not drawn.
const _ONE_SIDED := """
	if (!FRONT_FACING && zd_one_sided > 0.5) {
		discard;
	}"""
const _BODY_FRAGMENT := """
	ALBEDO = zd_albedo;
	METALLIC = 0.0;
	SPECULAR = zd_unshaded > 0.5 ? 0.0 : 0.5;
	ROUGHNESS = 1.0;
	EMISSION = zd_mode > 2.5 || (zd_mode > 0.5 && zd_mode < 1.5)
		? zd_emit * zd_glow
		: (zd_mode > 1.5 ? vec3(0.0) : mix(zd_emit, zd_hit, zd_shown));
	if (zd_unshaded > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = zd_albedo;
	}
}
"""
## v0.10.5 W3-V4b: the textured variant (the owner's models: their plates are textured, their accents are not), the
## map sampled for every fragment, outside the branch, so its mip level is never read from a neighbour that skipped it.
const _TEX := "uniform sampler2D zd_tex : source_color, filter_linear_mipmap, repeat_enable;\n"
const _TEX_ALBEDO := (
	"vec3 zd_tx = texture(zd_tex, UV).rgb;\n"
	+ "\tALBEDO = zd_albedo * (zd_mode > 0.5 ? vec3(1.0) : zd_tx);"
)

static var _shaders := {}


static func _shader(id: String, code: String) -> Shader:
	if not _shaders.has(id):
		var s := Shader.new()
		s.code = code
		_shaders[id] = s
	return _shaders[id]


## The body material for the baked `pose` (VatBake.pose_for); `two_sided` (the mesh's "two_sided" meta): the
## cull_disabled variant. A new material per crowd look (its uniforms are the pose's and the look's drive texture,
## set_drives).
static func material(pose: Dictionary, two_sided := false) -> ShaderMaterial:
	var head := _BODY_HEAD
	if two_sided:
		head = head.replace("cull_back", "cull_disabled")
	var m := ShaderMaterial.new()
	var tex: Texture2D = pose.get("albedo_tex")
	m.shader = _shader(
		"body%d%d" % [int(two_sided), int(tex != null)],
		(
			head
			+ (_TEX if tex != null else "")
			+ _POSE
			+ _BODY_VARYINGS
			+ _DRIVES
			+ _BODY_VERTEX
			+ (_ONE_SIDED if two_sided else "")
			+ (
				_BODY_FRAGMENT.replace("ALBEDO = zd_albedo;", _TEX_ALBEDO)
				if tex != null
				else _BODY_FRAGMENT
			)
		)
	)
	if tex != null:
		m.set_shader_parameter("zd_tex", tex)
	_set_pose(m, pose)
	return m


static func _set_pose(m: ShaderMaterial, pose: Dictionary) -> void:
	m.set_shader_parameter("zd_pose", pose["texture"])
	m.set_shader_parameter("zd_drive_texels", int(pose.get("drive_texels", 0)))
	m.set_shader_parameter("zd_scaled", bool(pose.get("scaled", false)))


## v0.10.5 W3-V4a: the drive texture (one row per instance) `m` reads the drives past the fourth from.
static func set_drives(m: ShaderMaterial, tex: Texture2D) -> void:
	m.set_shader_parameter("zd_drives", tex)


## The value an instance's COLOR carries (see the class notes): the hit value's rgb, the glow and whether it shows.
static func instance_color(hit: Vector4, glow: float) -> Color:
	var g := maxf(glow, 0.0)
	return Color(hit.x, hit.y, hit.z, -1.0 - g if hit.w > 0.5 else g)
