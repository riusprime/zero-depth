class_name EnemyLooks
extends RefCounted
## v0.8.0 HR (owner O89: "lag mostly comes from shooting hordes with multiple modifiers"): the horde enemies' materials,
## made once and shared by every enemy of a look, so the renderer draws a crowd's identical pieces as one instanced draw
## instead of one draw per piece per enemy (docs/roadmap/v0.4.0/evidence/HORDES.md: ~7,000 draws at 120 enemies).
## - body(): a body plate. The shading is StandardMaterial3D's as the horde built it (BaseMaterial3D's generated code
##   for roughness 1, specular 0.5, metallic 0, Burley diffuse, Schlick-GGX specular, emission on, the albedo texture
##   for the owner's models), reduced to the same arithmetic (the default textures it sampled are constants). The
##   rest glow (ActorViews N1 role glow, or none) is the material's; the hit flash and the status tints are an
##   `instance uniform` (HIT) each enemy sets on its own pieces (GeometryInstance3D.set_instance_shader_parameter), so
##   a flash changes no material and no shader. The stencil outline (STENCIL_MODE_OUTLINE's pass: unshaded, alpha,
##   grown by the thickness, drawn where the stencil is not 1) is a shared next pass; the owner's models draw none
##   (v0.7.5 on his models: no stroke) and write the stencil only (AvatarBase.write_stencil).
## - accent(): the glowing eye, seam, crystal, scope or muzzle: the same shading, its energy an `instance uniform`
##   (GLOW; < 0: the material's), never flashed.
## - xray(): the X-ray pass (was a second MeshInstance3D per piece, the "twin", with its own StandardMaterial3D in
##   STENCIL_MODE_XRAY: an opaque draw plus that pass): unshaded, alpha, no depth test, drawn where the stencil is
##   not 1, in the team colour at XRAY_ALPHA, shrunk as the twin was (the code bodies' twin scaled XRAY_SHRINK about the
##   piece's origin; the models' grown by AvatarBase / HordeAvatar XRAY_GROW). A next pass of the body's own material,
##   so the enemy shows through walls in its team colour, never through itself (its visible pieces write the stencil).
## Presentation only (EI-07).

## The instance uniforms: HIT (vec4: the flash or tint emission, linear and times its energy; w 1 = shown instead of
## the rest glow) on the body plates, GLOW (float: the accent's energy; < 0 = the material's) on the accents. Fixed
## instance indices, so a part carrying both kinds of surface (the owner's models) never mixes them up.
const HIT := &"zd_hit"
const GLOW := &"zd_glow"
const HIT_OFF := Vector4(0, 0, 0, 0)
## The X-ray twin's look before HR: its alpha in the team colour and the code bodies' shrink.
const XRAY_ALPHA := 0.85
const XRAY_SHRINK := 0.96
## The stencil passes draw after the body (StandardMaterial3D gives its stencil pass the body's priority + 1).
const PASS_PRIORITY := 1

const _LIT_HEAD := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
stencil_mode write, compare_always, 1;

uniform vec4 albedo : source_color;
uniform vec4 emission : source_color;
uniform float emission_energy;
"""
const _TEX := "uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;\n"
const _HIT_U := "instance uniform vec4 zd_hit : instance_index(0);\n"
const _GLOW_U := "instance uniform float zd_glow : instance_index(1) = -1.0;\n"
const _FRAG := """
void fragment() {
	ALBEDO = albedo.rgb%s;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ROUGHNESS = 1.0;
	EMISSION = %s;
}
"""
const _BODY_EMISSION := "mix(emission.rgb * emission_energy, zd_hit.rgb, zd_hit.a)"
const _ACCENT_EMISSION := "emission.rgb * (zd_glow < 0.0 ? emission_energy : zd_glow)"
const _OUTLINE := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded;
stencil_mode read, compare_not_equal, 1;

uniform vec4 albedo : source_color;
uniform float grow;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
"""
const _XRAY := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded,
	depth_test_disabled;
stencil_mode read, compare_not_equal, 1;

uniform vec4 albedo : source_color;
uniform float shrink = 1.0;
uniform float grow = 0.0;

void vertex() {
	VERTEX = VERTEX * shrink + NORMAL * grow;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
"""

static var _shaders := {}
static var _mats := {}


## The shared X-ray pass in `team` (at XRAY_ALPHA): shrunk `shrink` about the mesh's origin, then grown `grow` along
## its normals (mesh units).
static func xray(team: Color, shrink: float, grow: float) -> ShaderMaterial:
	var key := "x/%s/%.4f/%.5f" % [team.to_html(false), shrink, grow]
	if not _mats.has(key):
		var m := _material(&"xray", _XRAY)
		m.render_priority = PASS_PRIORITY
		m.set_shader_parameter("albedo", Color(team, XRAY_ALPHA))
		m.set_shader_parameter("shrink", shrink)
		m.set_shader_parameter("grow", grow)
		_mats[key] = m
	return _mats[key]


## A shared body plate: `albedo` (times `tex` when given), resting at `rest` x `rest_energy` emission, outlined in
## `outline` `outline_m` thick (0: no outline pass, the stencil only), then `xray_pass` (null: none); `two_sided`:
## drawn from both sides (the Charger's cull_disabled shell; its stencil passes still cull the back, as before).
static func body(
	albedo: Color,
	tex: Texture2D,
	rest: Color,
	rest_energy: float,
	outline: Color,
	outline_m: float,
	xray_pass: Material,
	two_sided := false
) -> ShaderMaterial:
	var key := (
		"b/%s/%d/%s/%.4f/%s/%.4f/%d/%d"
		% [
			albedo.to_html(),
			tex.get_instance_id() if tex != null else 0,
			rest.to_html(false),
			rest_energy,
			outline.to_html(),
			outline_m,
			xray_pass.get_instance_id() if xray_pass != null else 0,
			int(two_sided),
		]
	)
	if not _mats.has(key):
		var textured := tex != null
		var head := _LIT_HEAD.replace("cull_back", "cull_disabled") if two_sided else _LIT_HEAD
		var code := (
			head
			+ (_TEX if textured else "")
			+ _HIT_U
			+ _FRAG % [" * texture(texture_albedo, UV).rgb" if textured else "", _BODY_EMISSION]
		)
		var m := _material(&"body", code)
		m.set_shader_parameter("albedo", albedo)
		if textured:
			m.set_shader_parameter("texture_albedo", tex)
		m.set_shader_parameter("emission", rest)
		m.set_shader_parameter("emission_energy", rest_energy)
		m.next_pass = _outline_pass(outline, outline_m, xray_pass) if outline_m > 0.0 else xray_pass
		_mats[key] = m
	return _mats[key]


## The shared stencil outline pass (STENCIL_MODE_OUTLINE's), then `xray_pass`.
static func _outline_pass(outline: Color, outline_m: float, xray_pass: Material) -> ShaderMaterial:
	var key := (
		"o/%s/%.4f/%d"
		% [outline.to_html(), outline_m, xray_pass.get_instance_id() if xray_pass != null else 0]
	)
	if not _mats.has(key):
		var o := _material(&"outline", _OUTLINE)
		o.render_priority = PASS_PRIORITY
		o.set_shader_parameter("albedo", outline)
		o.set_shader_parameter("grow", outline_m)
		o.next_pass = xray_pass
		_mats[key] = o
	return _mats[key]


## A shared glowing accent: `albedo`, glowing `emission` at `energy` unless its piece sets GLOW, then `xray_pass`.
static func accent(
	albedo: Color, emission: Color, energy: float, xray_pass: Material
) -> ShaderMaterial:
	var key := (
		"a/%s/%s/%.4f/%d"
		% [
			albedo.to_html(),
			emission.to_html(false),
			energy,
			xray_pass.get_instance_id() if xray_pass != null else 0,
		]
	)
	if not _mats.has(key):
		var m := _material(&"accent", _LIT_HEAD + _GLOW_U + _FRAG % ["", _ACCENT_EMISSION])
		m.set_shader_parameter("albedo", albedo)
		m.set_shader_parameter("emission", emission)
		m.set_shader_parameter("emission_energy", energy)
		m.next_pass = xray_pass
		_mats[key] = m
	return _mats[key]


## The HIT value for a flash or tint of `c` at `energy` (shown instead of the rest glow), or HIT_OFF.
static func hit_value(on: bool, c: Color, energy: float) -> Vector4:
	if not on:
		return HIT_OFF
	var l := c.srgb_to_linear()
	return Vector4(l.r * energy, l.g * energy, l.b * energy, 1.0)


## Chains `xray_pass` after a StandardMaterial3D body's stencil outline pass (its next_pass while STENCIL_MODE_OUTLINE),
## or straight after the body when it has none.
static func chain_xray(mat: BaseMaterial3D, xray_pass: Material) -> void:
	var stencil_pass := mat.next_pass
	if stencil_pass != null and stencil_pass.has_meta(&"_stencil_owned"):
		stencil_pass.next_pass = xray_pass
	else:
		mat.next_pass = xray_pass


## The X-ray pass in `mat`'s chain of passes, or null (tests, tools).
static func xray_of(mat: Material) -> ShaderMaterial:
	var m := mat
	var guard := 0
	while m != null and guard < 8:
		if m is ShaderMaterial and (m as ShaderMaterial).shader == _shaders.get(&"xray"):
			return m
		m = m.next_pass
		guard += 1
	return null


## Whether `mat` is one of body()'s plates (it takes the hit flash; tests, tools).
static func is_body(mat: Material) -> bool:
	return mat is ShaderMaterial and String((mat as ShaderMaterial).shader.code).contains("zd_hit")


## The materials made so far (tests: a crowd shares them).
static func made() -> int:
	return _mats.size()


static func _material(id: StringName, code: String) -> ShaderMaterial:
	var key := "%s#%d" % [id, code.hash()]
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = code
		_shaders[key] = s
		if id == &"xray":
			_shaders[&"xray"] = s
	var m := ShaderMaterial.new()
	m.shader = _shaders[key]
	return m
