class_name BossBodyGlow
extends RefCounted
## The glows a boss's own body shows, in the boss's accent colour so the body keeps its flat colours and its ink:
## - The windup rim: a material overlay on the owner's model that lights only the facets turned side-on to the camera
##   (a thin rim round the silhouette), its strength the windup's. A whole-body fill stays only for the reads that
##   need the whole figure (the Twin Warden's charge flash and sheltered sheen, a final body cracking as it shatters,
##   the Warlord in its banner); it is 0 for every ordinary windup.
## - The weak point: a small faceted gem, glowing a little (opaque, so the ink pass outlines it like the model).
## - The body itself matte (matte()): a model file's metallic and roughness maps made the bodies glossy, out of the
##   game's flat look.
## Looks only (EI-07): the overlay's uniforms are the only thing that changes at run time.

## The overlay: `rim` (0..1) lights the side-on facets in `rim_color`; `fill` (0..1) tints the whole body
## `fill_color`. Unshaded, so the rim reads the same in every biome's light.
const OVERLAY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec4 rim_color : source_color = vec4(1.0, 0.7, 0.35, 1.0);
uniform float rim : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(1.0, 0.06, 0.03, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float side = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.58, 0.95, side) * rim;
	float a = max(edge, fill);
	ALBEDO = mix(fill_color.rgb, rim_color.rgb, edge / max(a, 0.0001));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
## How strong the rim is at its edge for a full windup.
const RIM_MAX := 0.9
## The weak point's gem: its radius and height (m).
const GEM_R := 0.17
const GEM_H := 0.42
## Each body's accent: its pattern shell's colour (BossShieldView.COLORS), by the avatar's class.
const KIND_OF := {
	&"GatekeeperAvatar": WorldReader.KIND_GATEKEEPER,
	&"WarlordAvatar": WorldReader.KIND_WARLORD,
	&"BroodMotherAvatar": WorldReader.KIND_BROOD_MOTHER,
	&"HiveLensAvatar": WorldReader.KIND_HIVE_LENS,
	&"SiegeEngineAvatar": WorldReader.KIND_SIEGE_ENGINE,
	&"FoundryAvatar": WorldReader.KIND_FOUNDRY,
	&"ColossusAvatar": WorldReader.KIND_COLOSSUS,
	&"PrismAvatar": WorldReader.KIND_PRISM,
	&"NemesisAvatar": WorldReader.KIND_NEMESIS,
	&"TidecallerAvatar": WorldReader.KIND_TIDECALLER,
	&"TwinWardenAvatar": WorldReader.KIND_TWIN_WARDEN,
	&"TwinWardenVioletAvatar": WorldReader.KIND_TWIN_WARDEN_VIOLET,
	&"ClockworkJudgeAvatar": WorldReader.KIND_CLOCKWORK_JUDGE,
	&"LanternShadeAvatar": WorldReader.KIND_LANTERN_SHADE,
}

static var _shader: Shader


## The accent of the boss body `avatar` (its class's pattern-shell colour; a warm amber for any other).
static func accent_of(avatar: Object) -> Color:
	var s := avatar.get_script() as Script
	while s != null:
		var kind: Variant = KIND_OF.get(s.get_global_name())
		if kind != null:
			return BossShieldView.COLORS.get(kind, BossShieldView.DEFAULT_COLOR)
		s = s.get_base_script()
	return BossShieldView.COLORS[WorldReader.KIND_GATEKEEPER]


## A fresh overlay for one body (each body its own: its uniforms are its own windup's).
static func overlay(accent: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OVERLAY_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("rim_color", accent)
	m.set_shader_parameter("rim", 0.0)
	m.set_shader_parameter("fill_color", Color(1.0, 0.06, 0.03))
	m.set_shader_parameter("fill", 0.0)
	return m


## Makes a model file's body material matte, as every body in the game is (EnemyLooks.body: metallic 0,
## roughness 1, specular 0.5, no clearcoat): its metallic and roughness maps dropped; its albedo and normal map kept.
static func matte(m: StandardMaterial3D) -> StandardMaterial3D:
	m.metallic = 0.0
	m.metallic_texture = null
	m.metallic_specular = 0.5
	m.roughness = 1.0
	m.roughness_texture = null
	m.clearcoat_enabled = false
	m.rim_enabled = false
	return m


## The weak point's gem: a six-sided double point round its centre, flat-shaded.
static func gem_mesh() -> ArrayMesh:
	return BossParts.loft(
		BossParts.ngon(6),
		[[-0.5, 0.05, 0.05], [-0.08, 1.0, 1.0], [0.5, 0.05, 0.05]],
		Vector3(GEM_R, GEM_H, GEM_R),
		17,
		0.12
	)
