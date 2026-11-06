class_name BiomeBackdrop
extends Node3D
## v0.9.5 BG: every biome has a deep, slowly drifting background under its floor.
##
## Owner (2026-10-25, line 8): "We are missing something for the background of the different biomes, for example in
## the astral one a universe starts or something that gives a little bit more ambience." Q5: layered parallax planes,
## owner-made images (assets/textures/backgrounds/bg_<biome>_deep.png and _mid.png; docs/art/requests/
## v0.9.5_BACKGROUNDS.md).
##
## The camera is orthographic, so a skybox cannot work and planes at different depths do not parallax by
## themselves. Two horizontal 160 m planes (Deep, opaque; Mid, transparent) sit far under the floor and follow the
## camera's focus point; the parallax is faked in the shader by scrolling the UV: the layer appears to move at
## `parallax` of the camera's speed. Presentation only: it reads the camera, never writes to anything the sim sees.
## Frozen Shore's sea (BiomeEdge, y -0.45) hides everything under it, so there the Deep image is painted onto the sea
## material and only the Mid plane is added, just above the water.

const BIOMES: Array[StringName] = [
	&"ruins", &"night_rocks", &"red_canyon", &"frozen_shore", &"starfall"
]
const TEXTURE_DIR := "res://assets/textures/backgrounds/"
const PLANE_M := 160.0
## UV = (world_xz - focus * (1 - parallax)) / tile_m + drift * TIME.
const DEEP_Y := -14.0
const DEEP_TILE_M := 42.0
const DEEP_PARALLAX := 0.35
const DEEP_DRIFT := 0.010
const DEEP_DRIFT_DIR := Vector2(1.0, 0.4)
const DEEP_BRIGHTNESS := 0.65
const MID_Y := -6.0
## Night Rocks' drifting islands hang down to about -7 m: its Mid plane goes below them.
const MID_Y_BY_BIOME := {&"night_rocks": -8.0, &"frozen_shore": -0.40}
const MID_TILE_M := 30.0
const MID_PARALLAX := 0.6
const MID_DRIFT := 0.020
const MID_DRIFT_DIR := Vector2(-0.6, 1.0)
const MID_ALPHA := 0.8
const MID_ALPHA_BY_BIOME := {&"frozen_shore": 0.5}
## v0.9.5 (owner, 2026-10-25: "just a bit dimmer so they don't take up as much protagonism"): about 25 % down.
const MID_BRIGHTNESS := {
	&"frozen_shore": 0.35,
	&"night_rocks": 0.3,
	&"ruins": 0.6,
	&"red_canyon": 0.7,
	&"starfall": 0.7,
}
## The plane fades to the void colour by distance from the camera focus, so its edge never shows (m).
const FADE_FROM := 45.0
const FADE_TO := 75.0
## How much of the sea's own colour the Deep image replaces (Frozen Shore).
const SEA_MIX := 0.65

const SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled__EXTRA__;

uniform sampler2D tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 void_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec2 focus = vec2(0.0);
uniform float tile_m = 40.0;
uniform float parallax = 0.5;
uniform vec2 drift = vec2(0.0);
uniform float brightness = 1.0;
uniform float alpha = 1.0;
uniform float fade_from = 45.0;
uniform float fade_to = 75.0;

varying vec2 wxz;

void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = (wxz - focus * (1.0 - parallax)) / tile_m + drift * TIME;
	vec4 c = texture(tex, uv);
	float f = smoothstep(fade_from, fade_to, distance(wxz, focus));
	ALBEDO = mix(c.rgb * brightness, void_color.rgb, f);
	ALPHA = __ALPHA__;
}
"""

## The layers in order (Deep first, when it is a plane): MeshInstance3D with a ShaderMaterial.
var layers: Array[MeshInstance3D] = []
var deep: MeshInstance3D
var mid: MeshInstance3D
var biome := &""
var void_color := Color(0.05, 0.05, 0.08)
## Frozen Shore's sea material, when the Deep image is painted onto it (null elsewhere).
var sea: ShaderMaterial
## "deep" / "mid" -> true when the image was missing and the code stand-in is on the plane.
var stand_in := {}
## ViewPrefs.reduced_motion at build time: 1.0 drifts, 0.0 holds still.
var motion := 1.0
var _sea_y := 0.0


## Whether `id` is one of the biomes with a backdrop (any other, and the hub, take Ruins').
static func key_for(id: StringName) -> StringName:
	return id if id in BIOMES else &"ruins"


## Builds the biome's layers. `p_sea` / `p_sea_y`: Frozen Shore's sea material and height (BiomeEdge), when it has one.
func build(
	p_biome: StringName, p_void: Color, p_sea: ShaderMaterial = null, p_sea_y := -0.45
) -> void:
	name = "Backdrop"
	biome = key_for(p_biome)
	void_color = p_void
	motion = 0.0 if ViewPrefs.reduced_motion else 1.0
	if p_sea != null and biome == &"frozen_shore":
		sea = p_sea
		_sea_y = p_sea_y
		var t := load_texture(texture_path(biome, "deep"), void_color)
		stand_in["deep"] = t["stand_in"]
		sea.set_shader_parameter("bd_tex", t["texture"])
		sea.set_shader_parameter("bd_tile", DEEP_TILE_M)
		sea.set_shader_parameter("bd_parallax", DEEP_PARALLAX)
		sea.set_shader_parameter("bd_drift", DEEP_DRIFT_DIR.normalized() * DEEP_DRIFT * motion)
		sea.set_shader_parameter("bd_bright", DEEP_BRIGHTNESS)
		sea.set_shader_parameter("bd_mix", SEA_MIX)
	else:
		deep = _plane("Deep", "deep", DEEP_Y)
	mid = _plane("Mid", "mid", float(MID_Y_BY_BIOME.get(biome, MID_Y)))
	set_process(true)


func _process(_delta: float) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam != null:
		follow(cam)


## Moves each plane under the camera's focus (where its view ray meets the plane's height) and tells the shaders.
func follow(cam: Camera3D) -> void:
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	if absf(d.y) < 0.001:
		return
	for mi in layers:
		var hit := _hit(o, d, mi.position.y)
		mi.position = Vector3(hit.x, mi.position.y, hit.z)
		(mi.material_override as ShaderMaterial).set_shader_parameter(
			"focus", Vector2(hit.x, hit.z)
		)
	if sea != null:
		var s := _hit(o, d, _sea_y)
		sea.set_shader_parameter("bd_focus", Vector2(s.x, s.z))


## The shader's numbers for the layer ("deep", "mid"; "sea" for Frozen Shore's sea): for the tests and the dev panel.
func params(layer: String) -> Dictionary:
	var out := {}
	if layer == "sea":
		if sea != null:
			for k in ["bd_tile", "bd_parallax", "bd_drift", "bd_bright", "bd_mix", "bd_focus"]:
				out[k.trim_prefix("bd_")] = sea.get_shader_parameter(k)
			out["tex"] = sea.get_shader_parameter("bd_tex")
		return out
	var mi := deep if layer == "deep" else mid
	if mi == null:
		return out
	var m := mi.material_override as ShaderMaterial
	for k in ["tex", "tile_m", "parallax", "drift", "brightness", "alpha", "focus"]:
		out[k] = m.get_shader_parameter(k)
	return out


## StageView's one call: adds the backdrop of `stage`'s biome (the hub, with no biome set, takes Ruins') as a child,
## painting Frozen Shore's sea when the stage has drawn one.
static func attach(stage: StageView) -> BiomeBackdrop:
	var b := BiomeBackdrop.new()
	stage.add_child(b)
	var p_sea: ShaderMaterial = null
	if stage.edge != null and stage.edge.water != null:
		p_sea = stage.edge.water.material_override as ShaderMaterial
	var void_c: Color = stage.mood.void_color if stage.mood != null else stage.palette["edge"]
	b.build(stage.prop_style, void_c, p_sea)
	return b


static func texture_path(p_biome: StringName, layer: String) -> String:
	return "%sbg_%s_%s.png" % [TEXTURE_DIR, p_biome, layer]


## The image at `path`, or a dark vertical gradient in `void_color` when it is missing (an editor without the
## imported assets, a test): {"texture": Texture2D, "stand_in": bool}.
static func load_texture(path: String, p_void: Color) -> Dictionary:
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			return {"texture": t, "stand_in": false}
	var g := Gradient.new()
	g.set_color(0, p_void.lightened(0.08))
	g.set_color(1, p_void.darkened(0.4))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	gt.width = 4
	gt.height = 64
	return {"texture": gt, "stand_in": true}


static func _hit(o: Vector3, d: Vector3, y: float) -> Vector3:
	return o + d * ((y - o.y) / d.y)


func _plane(label: String, layer: String, y: float) -> MeshInstance3D:
	var is_mid := layer == "mid"
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2.ONE * PLANE_M
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = q
	mi.position = Vector3(0.0, y, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = (
		SHADER
		. replace("__EXTRA__", ", blend_mix, depth_draw_never" if is_mid else "")
		. replace("__ALPHA__", "alpha * c.a * (1.0 - f)" if is_mid else "1.0")
	)
	var t := load_texture(texture_path(biome, layer), void_color)
	stand_in[layer] = t["stand_in"]
	if is_mid and t["stand_in"]:  # the stand-in has no wisps to show: nothing drawn
		m.set_shader_parameter("alpha", 0.0)
	else:
		m.set_shader_parameter(
			"alpha", float(MID_ALPHA_BY_BIOME.get(biome, MID_ALPHA)) if is_mid else 1.0
		)
	m.set_shader_parameter("tex", t["texture"])
	m.set_shader_parameter("void_color", void_color)
	m.set_shader_parameter("tile_m", MID_TILE_M if is_mid else DEEP_TILE_M)
	m.set_shader_parameter("parallax", MID_PARALLAX if is_mid else DEEP_PARALLAX)
	var dir := MID_DRIFT_DIR if is_mid else DEEP_DRIFT_DIR
	m.set_shader_parameter(
		"drift", dir.normalized() * (MID_DRIFT if is_mid else DEEP_DRIFT) * motion
	)
	m.set_shader_parameter(
		"brightness", float(MID_BRIGHTNESS.get(biome, 0.8)) if is_mid else DEEP_BRIGHTNESS
	)
	m.set_shader_parameter("fade_from", FADE_FROM)
	m.set_shader_parameter("fade_to", FADE_TO)
	mi.material_override = m
	add_child(mi)
	layers.append(mi)
	return mi
