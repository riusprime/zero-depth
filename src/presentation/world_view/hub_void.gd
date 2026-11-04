class_name HubVoid
extends Node3D
## v0.10.5 W3-O5 (owner F2, 2026-11-04: "The hub currently lacks a proper background"; asked a sky or a dark void with
## fog, the owner picked "Dark void + fog"): the space past the Rune Ring's walls. The biome's backdrop is left out
## (StageView.build_lighting_only); instead:
## - the apron: one flat opaque disc just under the plaza's paving reaching past the walls and past the view (under the
##   sunk south rim, the Training Room's lane and the gate's alcove), its paving darkening to black a little past the
##   walls and then to the mood's void colour (the background's), so the plaza ends in darkness, not at an edge, and
##   nothing under the floor shows (opaque: the ink pass sees it too);
## - the fog: FOG_LAYERS low horizontal sheets of soft drifting noise past the walls, each starting a little farther
##   out the higher it hangs (so none drifts over the plaza in the iso view) and thinning out far away.
## Cheap on purpose: one flat sheet per layer, two samples of one small tiling noise texture per pixel (made once), no
## volumetric fog and no particles. Presentation only (EI-07): nothing here is read by the sim; reduced motion
## stills the drift.

## The apron's reach past the plaza's radius (m), where its paving starts to darken, and where it is fully dark.
const APRON_REACH := 30.0
const APRON_DARK_FROM := 1.5
const APRON_DARK_TO := 7.0
## Where the dark apron turns to the void's own colour (m past the plaza's radius).
const APRON_FADE_FROM := 9.0
const APRON_FADE_TO := 22.0
const APRON_Y := -0.07
## The fog sheets: height (m), where each starts past the plaza's radius (m), its strength, its noise scale (noise tiles
## per m) and its drift (tiles per second).
const FOG_LAYERS: Array[Dictionary] = [
	{"y": 0.12, "from": 1.6, "strength": 0.5, "scale": 0.037, "drift": Vector2(0.012, 0.004)},
	{"y": 0.75, "from": 3.0, "strength": 0.35, "scale": 0.025, "drift": Vector2(-0.007, 0.009)},
	{"y": 1.7, "from": 5.0, "strength": 0.25, "scale": 0.017, "drift": Vector2(0.005, -0.007)},
]
## How far the fog's start softens in, and its far edge (m past the plaza's radius) where it has thinned out.
const FOG_SOFT := 4.0
const FOG_OUTER := 34.0
const FOG_OUTER_SOFT := 16.0
## The fog's colour: a warm grey a step over the void, in the hub's (Ruins') palette.
const FOG_TINT := Color(0.31, 0.27, 0.25)
## The fog's noise: one seamless tile (px), its features per tile; a layer's `scale` is tiles per metre.
const NOISE_PX := 256
const NOISE_FREQ := 0.012
## How often (frames) the drift follows the reduced-motion preference.
const CHECK_EVERY := 30

const APRON_SHADER := """
shader_type spatial;
render_mode cull_back;

uniform sampler2D tex : source_color, repeat_enable, filter_linear_mipmap;
uniform bool has_tex = false;
uniform vec4 tint : source_color = vec4(0.5, 0.45, 0.4, 1.0);
uniform float tile_m = 6.0;
uniform float dark_from = 17.5;
uniform float dark_to = 23.0;
uniform vec4 void_color : source_color = vec4(0.05, 0.04, 0.035, 1.0);
uniform float fade_from = 25.0;
uniform float fade_to = 38.0;

varying vec2 lxz;

void vertex() {
	lxz = VERTEX.xz;
}

void fragment() {
	float d = length(lxz);
	vec3 base = tint.rgb;
	if (has_tex) {
		base *= texture(tex, lxz / tile_m).rgb;
	}
	float f = smoothstep(fade_from, fade_to, d);
	ALBEDO = base * (1.0 - smoothstep(dark_from, dark_to, d)) * (1.0 - f);
	ROUGHNESS = 0.95;
	EMISSION = void_color.rgb * f;
}
"""

const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 tint : source_color = vec4(0.33, 0.27, 0.24, 1.0);
uniform float strength = 0.5;
uniform float inner = 18.0;
uniform float inner_soft = 4.0;
uniform float outer = 50.0;
uniform float outer_soft = 16.0;
uniform float scale = 0.08;
uniform vec2 drift = vec2(0.02, 0.01);
uniform float speed = 1.0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;

varying vec2 lxz;

void vertex() {
	lxz = VERTEX.xz;
}

void fragment() {
	float d = length(lxz);
	float mask = smoothstep(inner, inner + inner_soft, d) * (1.0 - smoothstep(outer - outer_soft, outer, d));
	float t = TIME * speed;
	vec2 p = lxz * scale;
	float n = texture(noise, p + drift * t).r * 0.6;
	n += texture(noise, p * 1.7 - drift.yx * t * 1.3 + vec2(0.37, 0.61)).r * 0.4;
	ALBEDO = tint.rgb;
	ALPHA = strength * mask * smoothstep(0.38, 0.8, n);
}
"""

var apron: MeshInstance3D
var fog: Array[MeshInstance3D] = []
var _calm := false
var _frame := 0


## Builds the apron and the fog round a plaza of `radius_m` (the plan's centre is this node's origin); `ground_tex` the
## paving (null: a plain tint), `tint` the paving's tint at the walls.
func setup(
	radius_m: float, ground_tex: Texture2D, tint: Color, tile_m: float, void_color: Color
) -> void:
	name = "Void"
	var sm := Shader.new()
	sm.code = APRON_SHADER
	var am := ShaderMaterial.new()
	am.shader = sm
	am.set_shader_parameter(&"has_tex", ground_tex != null)
	if ground_tex != null:
		am.set_shader_parameter(&"tex", ground_tex)
	am.set_shader_parameter(&"tint", tint)
	am.set_shader_parameter(&"tile_m", tile_m)
	am.set_shader_parameter(&"void_color", void_color)
	am.set_shader_parameter(&"dark_from", radius_m + APRON_DARK_FROM)
	am.set_shader_parameter(&"dark_to", radius_m + APRON_DARK_TO)
	am.set_shader_parameter(&"fade_from", radius_m + APRON_FADE_FROM)
	am.set_shader_parameter(&"fade_to", radius_m + APRON_FADE_TO)
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * (radius_m + APRON_REACH) * 2.0
	apron = HubProps.mesh(self, "Apron", disc, am, Vector3(0, APRON_Y, 0))
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fs := Shader.new()
	fs.code = FOG_SHADER
	var noise := fog_noise()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2.ONE * (radius_m + FOG_OUTER) * 2.0
	for i in FOG_LAYERS.size():
		var layer: Dictionary = FOG_LAYERS[i]
		var fm := ShaderMaterial.new()
		fm.shader = fs
		fm.render_priority = i
		fm.set_shader_parameter(&"tint", FOG_TINT)
		fm.set_shader_parameter(&"strength", layer["strength"])
		fm.set_shader_parameter(&"inner", radius_m + float(layer["from"]))
		fm.set_shader_parameter(&"inner_soft", FOG_SOFT)
		fm.set_shader_parameter(&"outer", radius_m + FOG_OUTER)
		fm.set_shader_parameter(&"outer_soft", FOG_OUTER_SOFT)
		fm.set_shader_parameter(&"scale", layer["scale"])
		fm.set_shader_parameter(&"drift", layer["drift"])
		fm.set_shader_parameter(&"noise", noise)
		var mi := HubProps.mesh(self, "Fog%d" % i, sheet, fm, Vector3(0, layer["y"], 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fog.append(mi)
	_sync()


## The fog's tiling noise (smooth simplex, three octaves; generated on a worker thread when first drawn).
static func fog_noise() -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = NOISE_FREQ
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	fn.seed = 5
	var t := NoiseTexture2D.new()
	t.width = NOISE_PX
	t.height = NOISE_PX
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = fn
	return t


func _process(_delta: float) -> void:
	_frame += 1
	if _frame % CHECK_EVERY == 0:
		_sync()


## Reduced motion stills the fog's drift.
func _sync() -> void:
	var calm := ViewPrefs.reduced_motion
	if calm == _calm and _frame > 0:
		return
	_calm = calm
	for mi in fog:
		(mi.material_override as ShaderMaterial).set_shader_parameter(
			&"speed", 0.0 if calm else 1.0
		)
