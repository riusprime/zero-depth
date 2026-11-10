class_name EnemyLooks
extends RefCounted
## The horde enemies' materials,
## made once and shared by every enemy of a look, so the renderer draws a crowd's identical pieces as one instanced draw
## instead of one draw per piece per enemy (docs/roadmap/v0.4.0/evidence/HORDES.md: ~7,000 draws at 120 enemies).
## - body(): a body plate. The shading is StandardMaterial3D's as the horde built it (BaseMaterial3D's generated code
##   for roughness 1, specular 0.5, metallic 0, Burley diffuse, Schlick-GGX specular, emission on, the albedo texture
##   for the owner's models), reduced to the same arithmetic (the default textures it sampled are constants). The
##   rest glow (ActorViews N1 role glow, or none) is the material's; the hit flash and the status tints are an
##   `instance uniform` (HIT) each enemy sets on its own pieces (GeometryInstance3D.set_instance_shader_parameter), so
##   a flash changes no material and no shader. A body plate has no stencil and no outline pass.
## - accent(): the glowing eye, seam, crystal, scope or muzzle: the same shading, its energy an `instance uniform`
##   (GLOW; < 0: the material's), never flashed.
## Presentation only (EI-07).

## The instance uniforms: HIT (vec4: the flash or tint emission, linear and times its energy; w 1 = shown instead of
## the rest glow) on the body plates, GLOW (float: the accent's energy; < 0 = the material's) on the accents. Fixed
## instance indices, so a part carrying both kinds of surface (the owner's models) never mixes them up.
const HIT := &"zd_hit"
const GLOW := &"zd_glow"
const HIT_OFF := Vector4(0, 0, 0, 0)

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
static var _shaders := {}
static var _mats := {}


## A shared body plate: `albedo` (times `tex` when given), resting at `rest` x `rest_energy` emission, `two_sided`:
## drawn from both sides (the Charger's cull_disabled shell).
static func body(
	albedo: Color, tex: Texture2D, rest: Color, rest_energy: float, two_sided := false
) -> ShaderMaterial:
	var key := (
		"b/%s/%d/%s/%.4f/%d"
		% [
			albedo.to_html(),
			tex.get_instance_id() if tex != null else 0,
			rest.to_html(false),
			rest_energy,
			int(two_sided),
		]
	)
	if not _mats.has(key):
		var textured := tex != null
		var head := _LIT_HEAD.replace("cull_back", "cull_disabled") if two_sided else _LIT_HEAD
		head = head.replace("stencil_mode write, compare_always, 1;\n", "")
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
		_mats[key] = m
	return _mats[key]


## A shared glowing accent: `albedo`, glowing `emission` at `energy` unless its piece sets GLOW.
static func accent(albedo: Color, emission: Color, energy: float) -> ShaderMaterial:
	var key := "a/%s/%s/%.4f" % [albedo.to_html(), emission.to_html(false), energy]
	if not _mats.has(key):
		var m := _material(&"accent", _LIT_HEAD + _GLOW_U + _FRAG % ["", _ACCENT_EMISSION])
		m.set_shader_parameter("albedo", albedo)
		m.set_shader_parameter("emission", emission)
		m.set_shader_parameter("emission_energy", energy)
		_mats[key] = m
	return _mats[key]


## The HIT value for a flash or tint of `c` at `energy` (shown instead of the rest glow), or HIT_OFF.
static func hit_value(on: bool, c: Color, energy: float) -> Vector4:
	if not on:
		return HIT_OFF
	var l := c.srgb_to_linear()
	return Vector4(l.r * energy, l.g * energy, l.b * energy, 1.0)


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
	var m := ShaderMaterial.new()
	m.shader = _shaders[key]
	return m
