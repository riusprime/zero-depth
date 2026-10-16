class_name FxTextures
extends RefCounted
## v0.8.0 TX1 (owner 2026-10-15: "real textures like with the player animations"; docs/art/requests/
## v0.8.0_textures.md): the owner's attack textures in place of the code-made looks, and the small shaders that draw
## them. Each texture is a greyscale mask (scripts/assets/vfx_prep_attacks.py: L the whiteness or lightness, A the
## coverage) tinted by the colours the code already gives each boss, enemy and look, so palette A and the enemy colours
## are unchanged. A missing texture keeps the code look (`get_tex` returns null; every user checks it).
## Presentation only (EI-07). No new draw: each texture goes on a mesh that was already drawn (a uniform swap, the
## same MultiMeshes and nodes).
## - fx_orb_cores, fx_orb_cores_2, fx_orb_cores_final (2 x 2): the hostile fireballs' cores (FireballViews.TEX_CORES);
## - fx_trails (1 x 4: flame, smoke, acid drips, crystal): their trails (FireballViews.trail_row);
## - fx_beam (1 x 4): the Hive Lens's Gaze and Focus Beam, the Prism's Cross;
## - fx_beam_impact (2 x 2): the flare where the Gaze or a Cross arm strikes the wall (FLARE);
## - fx_aim_lines (1 x 4: dashed, laser with an end point, chevrons, shimmer): the Gaze's and the Cross's spin-up aim
##   lines and the Prism's bolt line;
## - fx_cast_sigils (2 x 2): the Nemesis's card-cast sigil and the Arc Caster's rune (SIGIL).

const DIR := "res://assets/textures/vfx/"
## The fx_aim_lines rows.
const AIM_DASHED := 0
const AIM_LASER := 1
const AIM_CHEVRONS := 2
const AIM_SHIMMER := 3

## A camera-facing quad (the impact flare): one cell of a 2 x 2 sheet, turning slowly, tinted from `color` (its
## coloured parts) to `core` (its white-hot parts).
const FLARE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D sheet : filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 core : source_color = vec4(1.0);
uniform float cell = 0.0;
uniform float strength = 1.0;
uniform float motion = 1.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	float a = TIME * 0.7 * motion;
	vec2 d = UV - 0.5;
	vec2 uv = vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a)) + 0.5;
	vec2 c = vec2(mod(cell, 2.0), floor(cell / 2.0));
	vec4 t = texture(sheet, (clamp(uv, 0.01, 0.99) + c) * 0.5);
	ALBEDO = mix(color.rgb, core.rgb, t.r) * t.a * strength * 1.6;
}
"""

## A flat quad on the floor (the cast sigil): one cell of a 2 x 2 sheet, turning slowly, faded by `alpha`.
const SIGIL := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D sheet : filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 core : source_color = vec4(1.0);
uniform float cell = 0.0;
uniform float alpha = 1.0;
uniform float turn = 0.0;
void fragment() {
	vec2 d = UV - 0.5;
	vec2 uv = vec2(d.x * cos(turn) - d.y * sin(turn), d.x * sin(turn) + d.y * cos(turn)) + 0.5;
	vec2 c = vec2(mod(cell, 2.0), floor(cell / 2.0));
	vec4 t = texture(sheet, (clamp(uv, 0.01, 0.99) + c) * 0.5);
	ALBEDO = mix(color.rgb, core.rgb, t.r * 0.8) * t.a * alpha * 2.4;
}
"""

## Where the textures are looked up (tests point it elsewhere to see the code looks).
static var dir := DIR
static var _shaders := {}


## The texture `id` (assets/textures/vfx/<id>.png), or null when it isn't installed (the code look stays).
static func get_tex(id: String) -> Texture2D:
	var path := dir + id + ".png"
	return load(path) if ResourceLoader.exists(path) else null


static func shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## The impact flare's quad and material (null when fx_beam_impact isn't installed): `cell` of the sheet, tinted.
static func flare_material(color: Color, core: Color, cell: int) -> ShaderMaterial:
	var t := get_tex("fx_beam_impact")
	if t == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = shader(FLARE)
	m.set_shader_parameter("sheet", t)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("cell", float(cell))
	return m


## The flare quad (1.0 m, scaled by its node): the art is wider than the code sphere it replaces.
static func flare_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 2.4
	return q


## A cast sigil's material (null when fx_cast_sigils isn't installed).
static func sigil_material(color: Color, cell: int) -> ShaderMaterial:
	var t := get_tex("fx_cast_sigils")
	if t == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = shader(SIGIL)
	m.set_shader_parameter("sheet", t)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("core", color.lerp(Color.WHITE, 0.6))
	m.set_shader_parameter("cell", float(cell))
	return m


## A flat quad on the floor, `size` m across (the sigil).
static func floor_quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.orientation = PlaneMesh.FACE_Y
	return q


## Puts a beam texture (fx_beam or fx_aim_lines) on a BossSignatureShaders.BEAM material: `row` of the sheet, tiled
## every `tile_m` metres along the beam (or stretched once from end to end when `once`), scrolling at `scroll`.
## Returns false (the code look stays) when the texture isn't installed.
static func texture_beam(
	m: ShaderMaterial, id: String, row: int, tile_m: float, once := false, scroll := 0.0
) -> bool:
	var t := get_tex(id)
	if t == null:
		return false
	m.set_shader_parameter("beam_tex", t)
	m.set_shader_parameter("tex_on", 1.0)
	m.set_shader_parameter("tex_row", float(row))
	m.set_shader_parameter("tex_tile", tile_m)
	m.set_shader_parameter("tex_once", 1.0 if once else 0.0)
	m.set_shader_parameter("tex_scroll", scroll)
	return true
