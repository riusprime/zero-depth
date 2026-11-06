class_name VatLooks
extends RefCounted
## v0.10.5 W3-V1 (the enemy VAT pilot): the material a VatCrowd draws a horde kind with. Its vertex stage poses each
## vertex from the baked joint transforms (VatBake: the stance grid trilinear over the instance's windup raise, strike
## and crouch, the gait loop over its phase; a joint after its parent, as the scene tree composed the nodes); its
## fragment stage is EnemyLooks' body and accent shading, unchanged (the same render modes, ALBEDO / METALLIC /
## SPECULAR / ROUGHNESS, a plate's emission mix(rest, hit, shown), an accent's colour x its glow), with the per-piece
## colours from the mesh's CUSTOM0 / CUSTOM1 instead of one material per piece.
## Per instance (VatCrowd): INSTANCE_CUSTOM = (windup raise, strike, crouch, gait phase 0..1); COLOR = the hit value's
## rgb (EnemyLooks.hit_value) and in alpha the accent glow g, as g when the hit is off and -(1 + g) when it shows. The
## mesh has no vertex colours, so COLOR in the vertex stage is the instance's alone.
## The stencil outline pass (EnemyLooks._OUTLINE: grown along the normal, drawn where the stencil is not 1) follows
## when ActorLooks.OUTLINES is on, posed the same way; an accent draws none (its triangles fold to a point there).
## Presentation only (EI-07).

const _POSE := """
uniform sampler2D zd_pose : filter_nearest;
uniform ivec3 zd_stance = ivec3(2, 2, 2);
uniform int zd_gait = 1;
uniform int zd_gait_row = 0;

void zd_rows(int slot, int row, float w, inout vec4 r0, inout vec4 r1, inout vec4 r2) {
	int x = slot * 3;
	r0 += texelFetch(zd_pose, ivec2(x, row), 0) * w;
	r1 += texelFetch(zd_pose, ivec2(x + 1, row), 0) * w;
	r2 += texelFetch(zd_pose, ivec2(x + 2, row), 0) * w;
}

mat4 zd_local(int slot, int grid, vec4 d) {
	if (grid < 0) {
		return mat4(1.0);
	}
	vec4 r0 = vec4(0.0);
	vec4 r1 = vec4(0.0);
	vec4 r2 = vec4(0.0);
	if (grid == 0) {
		vec3 g = clamp(d.xyz, 0.0, 1.0) * vec3(zd_stance - ivec3(1));
		ivec3 i0 = min(ivec3(floor(g)), zd_stance - ivec3(2));
		vec3 f = g - vec3(i0);
		for (int c = 0; c < 8; c++) {
			ivec3 o = ivec3(c & 1, (c >> 1) & 1, (c >> 2) & 1);
			vec3 wv = mix(vec3(1.0) - f, f, vec3(o));
			ivec3 ix = i0 + o;
			zd_rows(slot, ix.x + zd_stance.x * (ix.y + zd_stance.y * ix.z), wv.x * wv.y * wv.z, r0, r1, r2);
		}
	} else {
		float u = fract(d.w) * float(zd_gait);
		int i0 = int(floor(u)) % zd_gait;
		float f = u - floor(u);
		zd_rows(slot, zd_gait_row + i0, 1.0 - f, r0, r1, r2);
		zd_rows(slot, zd_gait_row + (i0 + 1) % zd_gait, f, r0, r1, r2);
	}
	return mat4(
		vec4(r0.x, r1.x, r2.x, 0.0),
		vec4(r0.y, r1.y, r2.y, 0.0),
		vec4(r0.z, r1.z, r2.z, 0.0),
		vec4(r0.w, r1.w, r2.w, 1.0)
	);
}

mat4 zd_joint(vec4 jp, vec4 d) {
	mat4 m = zd_local(int(jp.x), int(jp.y), d);
	if (jp.z >= 0.0) {
		m = zd_local(int(jp.z), int(jp.w), d) * m;
	}
	return m;
}
"""
const _BODY_HEAD := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
stencil_mode write, compare_always, 1;
"""
const _BODY := """
varying vec3 zd_albedo;
varying vec3 zd_emit;
varying vec3 zd_hit;
flat varying float zd_accent;
flat varying float zd_shown;
flat varying float zd_glow;

void vertex() {
	mat4 m = zd_joint(CUSTOM2, INSTANCE_CUSTOM);
	VERTEX = (m * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(mat3(m) * NORMAL);
	zd_albedo = CUSTOM0.rgb;
	zd_accent = CUSTOM0.a;
	zd_emit = CUSTOM1.rgb;
	zd_hit = COLOR.rgb;
	zd_shown = COLOR.a < 0.0 ? 1.0 : 0.0;
	zd_glow = COLOR.a < 0.0 ? -COLOR.a - 1.0 : COLOR.a;
}

void fragment() {
	ALBEDO = zd_albedo;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ROUGHNESS = 1.0;
	EMISSION = zd_accent > 0.5 ? zd_emit * zd_glow : mix(zd_emit, zd_hit, zd_shown);
}
"""
const _OUTLINE := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded;
stencil_mode read, compare_not_equal, 1;

uniform vec4 albedo : source_color;
uniform float grow;
%s
void vertex() {
	mat4 m = zd_joint(CUSTOM2, INSTANCE_CUSTOM);
	vec3 n = normalize(mat3(m) * NORMAL);
	VERTEX = CUSTOM1.a > 0.5 ? (m * vec4(VERTEX, 1.0)).xyz + n * grow : vec3(0.0);
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
"""

static var _shaders := {}


static func _shader(id: String, code: String) -> Shader:
	if not _shaders.has(id):
		var s := Shader.new()
		s.code = code
		_shaders[id] = s
	return _shaders[id]


## The body material for the baked `pose` (VatBake.pose_for), outlined in `outline` `outline_m` thick when
## ActorLooks.OUTLINES is on (0: none). A new material per crowd look (its uniforms are the pose's).
static func material(pose: Dictionary, outline: Color, outline_m: float) -> ShaderMaterial:
	var head := _BODY_HEAD
	if not ActorLooks.OUTLINES:
		head = head.replace("stencil_mode write, compare_always, 1;\n", "")
	var m := ShaderMaterial.new()
	m.shader = _shader("body%d" % int(ActorLooks.OUTLINES), head + _POSE + _BODY)
	_set_pose(m, pose)
	if ActorLooks.OUTLINES and outline_m > 0.0:
		var o := ShaderMaterial.new()
		o.shader = _shader("outline", _OUTLINE % _POSE)
		o.render_priority = EnemyLooks.PASS_PRIORITY
		o.set_shader_parameter("albedo", outline)
		o.set_shader_parameter("grow", outline_m)
		_set_pose(o, pose)
		m.next_pass = o
	return m


static func _set_pose(m: ShaderMaterial, pose: Dictionary) -> void:
	m.set_shader_parameter("zd_pose", pose["texture"])
	m.set_shader_parameter("zd_stance", pose["stance"])
	m.set_shader_parameter("zd_gait", maxi(int(pose["gait"]), 1))
	m.set_shader_parameter("zd_gait_row", int(pose["gait_row"]))


## The value an instance's COLOR carries (see the class notes): the hit value's rgb, the glow and whether it shows.
static func instance_color(hit: Vector4, glow: float) -> Color:
	var g := maxf(glow, 0.0)
	return Color(hit.x, hit.y, hit.z, -1.0 - g if hit.w > 0.5 else g)
