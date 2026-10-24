class_name EpicRobeParts
extends RefCounted
## v0.9.0 MP2: the epic robes' made-in-code parts for EpicRobeView: the crown, gem and halo-bead meshes (flat-shaded,
## the hood's frame), and the layered materials (a fresnel sheen shell, the trim's additive glow, the halo's ring glow,
## the trail's camera-facing sprites) with their shaders and textures, each made once. Presentation only (EI-07).

const SHEEN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.5;
uniform float power = 3.0;
uniform float push = 0.004;
void vertex() {
	VERTEX += NORMAL * push;
}
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = tint.rgb * f * strength;
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float energy = 1.5;
uniform float pulse = 1.0;
void fragment() {
	ALBEDO = COLOR.rgb * COLOR.a * energy * pulse;
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ring = 0.3;
uniform float width = 0.07;
uniform float strength = 1.0;
void fragment() {
	float r = length(UV - vec2(0.5));
	float d = (r - ring) / width;
	float glow = exp(-d * d);
	float core = exp(-d * d * 16.0);
	float inner = exp(-r * r * 30.0) * 0.18;
	ALBEDO = tint.rgb * (glow * 0.55 + core * 0.9 + inner) * strength * smoothstep(0.5, 0.4, r);
}
"""

const SPRITE_SHADER := """
shader_type spatial;
render_mode unshaded, BLEND, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D tex : source_color, hint_default_white;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 world = centre + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = COLOR.rgb * t.rgb;
	ALPHA = COLOR.a * t.a;
}
"""

static var _shaders := {}
static var _textures := {}


## The crown in the hood's frame (+X the front): a band round the hood's top, flaring a little, and its points:
## fallen nine jagged spikes (the front tallest, every other one short), divine twelve slender rays (long and short).
static func crown_mesh(fallen: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var seg := 24
	var y0 := 0.12
	var y1 := 0.185
	var rx := 0.255
	var rz := 0.142
	var centre := Vector3(0, (y0 + y1) * 0.5, 0)
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var lo0 := Vector3(cos(a0) * rx, y0, sin(a0) * rz)
		var lo1 := Vector3(cos(a1) * rx, y0, sin(a1) * rz)
		var hi0 := Vector3(cos(a0) * rx * 1.06, y1, sin(a0) * rz * 1.08)
		var hi1 := Vector3(cos(a1) * rx * 1.06, y1, sin(a1) * rz * 1.08)
		AvatarBase._tri(verts, normals, lo0, hi0, hi1, centre)
		AvatarBase._tri(verts, normals, lo0, hi1, lo1, centre)
		# The band's inside (a thin wall: the inner ring 1.2 cm in), facing in.
		var in0 := Vector3(lo0.x * 0.93, y0, lo0.z * 0.9)
		var in1 := Vector3(lo1.x * 0.93, y0, lo1.z * 0.9)
		var ih0 := Vector3(hi0.x * 0.93, y1, hi0.z * 0.9)
		var ih1 := Vector3(hi1.x * 0.93, y1, hi1.z * 0.9)
		var far := Vector3(cos(a0 + PI) * 2.0, centre.y, sin(a0 + PI) * 2.0)
		AvatarBase._tri(verts, normals, in0, ih0, ih1, far)
		AvatarBase._tri(verts, normals, in0, ih1, in1, far)
		# The band's top rim.
		var above := Vector3(0, y1 - 0.2, 0)
		AvatarBase._tri(verts, normals, hi0, ih0, ih1, above)
		AvatarBase._tri(verts, normals, hi0, ih1, hi1, above)
	var points := 9 if fallen else 12
	for i in points:
		var a := TAU * i / points
		var front := (1.0 + cos(a)) * 0.5
		var h := 0.0
		var w := 0.0
		if fallen:
			h = (0.1 + 0.13 * front * front) * (1.0 if i % 2 == 0 else 0.6)
			w = 0.046
		else:
			h = (0.16 if i % 2 == 0 else 0.09) * (0.78 + 0.22 * front)
			w = 0.026
		spike(
			verts,
			normals,
			Vector3(cos(a) * rx * 1.06, y1 - 0.004, sin(a) * rz * 1.08),
			a,
			h,
			w,
			fallen
		)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## One crown point at `at` on the band (angle `a` round it): a four-sided pyramid `h` tall and `w` wide, leaning
## out; fallen ones bend a little sideways at the tip (a jagged, hand-forged look).
static func spike(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	at: Vector3,
	a: float,
	h: float,
	w: float,
	fallen: bool
) -> void:
	var radial := Vector3(cos(a), 0, sin(a))
	var tangent := Vector3(-sin(a), 0, cos(a))
	var base := [
		at + tangent * w * 0.5,
		at + radial * w * 0.3,
		at - tangent * w * 0.5,
		at - radial * w * 0.3,
	]
	var lean := 0.22 if fallen else 0.12
	var tip := at + Vector3.UP * h + radial * h * lean
	if fallen:
		tip += tangent * h * 0.12 * (1.0 if int(round(a * 10.0)) % 2 == 0 else -1.0)
	var centre := at + Vector3.UP * h * 0.25
	for k in 4:
		AvatarBase._tri(verts, normals, base[k], base[(k + 1) % 4], tip, centre)


## The crown's gems (hood frame): fallen one large red-violet stone at the front and two small at the sides; divine
## a white-hot stone at the base of every long ray. Octahedra.
static func gem_mesh(fallen: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var rx := 0.255 * 1.03 + 0.008
	var rz := 0.142 * 1.04 + 0.008
	var spots := []
	if fallen:
		spots = [[0.0, 0.026], [0.9, 0.015], [-0.9, 0.015]]
	else:
		for i in 6:
			spots.append([TAU * i / 6.0, 0.017 if i > 0 else 0.026])
	for s: Array in spots:
		var a: float = s[0]
		var r: float = s[1]
		var c := Vector3(cos(a) * rx, 0.146, sin(a) * rz)
		var out := Vector3(cos(a), 0, sin(a)) * r * 0.7
		var side := Vector3(-sin(a), 0, cos(a)) * r * 0.75
		var up := Vector3.UP * r
		var ring := [c + side, c + up, c - side, c - up]
		for k in 4:
			AvatarBase._tri(verts, normals, ring[k], ring[(k + 1) % 4], c + out, c)
			AvatarBase._tri(verts, normals, ring[k], ring[(k + 1) % 4], c - out * 0.4, c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## `count` small diamonds round a ring of `r` (the halo's beads), each `s` across.
static func bead_mesh(count: int, r: float, s: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in count:
		var a := TAU * i / count
		var c := Vector3(cos(a) * r, 0.022, sin(a) * r)
		var tangent := Vector3(-sin(a), 0, cos(a)) * s
		var radial := Vector3(cos(a), 0, sin(a)) * s * 0.5
		var up := Vector3.UP * s * 0.6
		var ring := [c + tangent, c + radial, c - tangent, c - radial]
		for k in 4:
			AvatarBase._tri(verts, normals, ring[k], ring[(k + 1) % 4], c + up, c)
			AvatarBase._tri(verts, normals, ring[k], ring[(k + 1) % 4], c - up, c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# --- materials ------------------------------------------------------------------------------------------------------


static func material(key: StringName, code: String) -> ShaderMaterial:
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = code
		_shaders[key] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[key]
	return m


## A fresnel sheen shell over `mesh` (pushed a few millimetres out along its normals): `c` at the grazing edges.
static func shell(n: String, mesh: Mesh, c: Color, strength: float, power: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	var m := material(&"sheen", SHEEN_SHADER)
	m.set_shader_parameter(&"tint", c)
	m.set_shader_parameter(&"strength", strength)
	m.set_shader_parameter(&"power", power)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A soft additive glow (a camera-facing quad `size_m` across) in `c`.
static func glow_quad(n: String, c: Color, size_m: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var q := QuadMesh.new()
	q.size = Vector2(size_m, size_m)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.albedo_color = Color(c, 0.9)
	m.albedo_texture = texture(&"soft")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The trail's and the motes' sprite: fallen smoke (blended, a ragged soft blob), else light (additive, a soft dot).
## Its own camera-facing shader: each MultiMesh instance turned to the camera about its own centre, at its own scale.
static func sprite_material(smoke: bool) -> ShaderMaterial:
	var m := material(
		&"smoke" if smoke else &"spark",
		SPRITE_SHADER.replace("BLEND", "blend_mix" if smoke else "blend_add")
	)
	m.set_shader_parameter(&"tex", texture(&"smoke" if smoke else &"soft"))
	return m


## The sprites' textures, made once: "soft" a radial falloff, "smoke" a ragged blob (fixed-seed noise).
static func texture(key: StringName) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.08
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			if key == &"smoke":
				a *= clampf(0.55 + 0.9 * noise.get_noise_2d(x, y), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex
