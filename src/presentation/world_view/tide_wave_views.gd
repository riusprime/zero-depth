class_name TideWaveViews
extends Node3D
## v0.9.5 BH4 (BOSSES_HARD.md T3; owner: "spawning waves crossing the room, small like 2-4 meters that the player has to
## dodge during all fight"): the Tidecaller's crossing waves, drawn from WorldReader.boss_waves (EI-07: it reads; the
## wave, its hit and its shove are the sim's, BossStream).
## - The foam line: for the 0.7 s telegraph a flat white-cyan strip lies on the floor at the wall the wave forms at, as
##   long as the wave will be, pulsing faster and brighter as the wave nears (a shader on a plane).
## - The wave: a low curling band of water (a code-made extruded profile, 0.5 m tall at the crest, curling forward)
##   translucent cyan with a white foam top edge and streaks drifting along it, ends faded by an edge mask; it rises out
##   of the floor as it leaves the wall and sinks at the far wall (the sim removes it there).
## - Spray: a few motes thrown up off the crest and falling back (a MultiMesh shared by every wave, thinned on Low
##   density, still on reduced motion).
## Both shaders are unshaded with fog_disabled and an edge mask, so the band never shows a hard cut. Reduced
## motion slows the streaks and stills the motes. Nothing here decides an outcome.

const SLOTS := 6
const MOTES_HIGH := 8
const MOTES_LOW := 3
const SEA := Color(0.45, 1.0, 0.86)
const DEEP := Color(0.06, 0.45, 0.62)
const FOAM := Color(0.92, 1.0, 1.0)
## The crest's height (m) and the foam line's width along the wave's travel (m).
const CREST_M := 0.5
const LINE_M := 0.9
## A wave rises out of the floor over this part of its run (per mille) and sinks over the last of it.
const RISE_PERMILLE := 40
const SINK_PERMILLE := 60
const BAND_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 deep : source_color = vec4(0.06, 0.45, 0.62, 1.0);
uniform vec4 sea : source_color = vec4(0.45, 1.0, 0.86, 1.0);
uniform vec4 foam : source_color = vec4(0.92, 1.0, 1.0, 1.0);
uniform float clock = 0.0;
uniform float alpha = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	float u = UV.x;  // along the wave's length
	float v = UV.y;  // 0 at the floor, 1 at the crest
	float edge = smoothstep(0.0, 0.14, u) * smoothstep(1.0, 0.86, u);
	float n = texture(noise_tex, vec2(u * 3.0 - clock * 0.35, v * 1.5 + clock * 0.12)).r;
	float streak = smoothstep(0.55, 0.9, n) * smoothstep(0.1, 0.6, v);
	float top = smoothstep(0.78, 0.98, v + (n - 0.5) * 0.18);
	vec3 body = mix(deep.rgb, sea.rgb, smoothstep(0.0, 0.8, v) * 0.8 + streak * 0.5);
	ALBEDO = mix(body, foam.rgb, clamp(top, 0.0, 1.0));
	ALPHA = clamp(edge * alpha * (0.42 + 0.35 * v + 0.5 * top), 0.0, 0.9);
}
"""
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 sea : source_color = vec4(0.45, 1.0, 0.86, 1.0);
uniform vec4 foam : source_color = vec4(0.92, 1.0, 1.0, 1.0);
uniform float clock = 0.0;
uniform float near = 0.0;   // 0..1, how close the wave is to leaving
uniform float alpha = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float edge = smoothstep(1.0, 0.7, abs(q.x)) * smoothstep(1.0, 0.45, abs(q.y));
	float n = texture(noise_tex, vec2(UV.y * 4.0 + clock * 0.2, UV.x * 1.2)).r;
	float pulse = 0.55 + 0.45 * sin(clock * (7.0 + near * 11.0));
	float streak = smoothstep(0.45, 0.85, n);
	vec3 col = mix(sea.rgb, foam.rgb, 0.35 + 0.5 * streak + 0.25 * near);
	ALBEDO = col * (1.0 + 0.4 * near);
	ALPHA = clamp(edge * alpha * (0.35 + 0.4 * pulse + 0.35 * near) * (0.7 + 0.3 * streak), 0.0, 0.92);
}
"""

var _bands: Array[MeshInstance3D] = []
var _band_mats: Array[ShaderMaterial] = []
var _lines: Array[MeshInstance3D] = []
var _line_mats: Array[ShaderMaterial] = []
var _motes := MultiMeshInstance3D.new()
var _mote_mat := StandardMaterial3D.new()
var _waves: Array[Dictionary] = []
var _clock := 0.0
var _shown_bands := 0
var _shown_lines := 0


func _init() -> void:
	name = "TideWaveViews"
	var noise := ProjectileMeshes.noise()
	var band_shader := Shader.new()
	band_shader.code = BAND_SHADER
	var line_shader := Shader.new()
	line_shader.code = LINE_SHADER
	var band_mesh := wave_mesh()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	for k in SLOTS:
		var bm := ShaderMaterial.new()
		bm.shader = band_shader
		bm.set_shader_parameter("noise_tex", noise)
		bm.set_shader_parameter("deep", DEEP)
		bm.set_shader_parameter("sea", SEA)
		bm.set_shader_parameter("foam", FOAM)
		var band := MeshInstance3D.new()
		band.mesh = band_mesh
		band.material_override = bm
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		band.visible = false
		add_child(band)
		_bands.append(band)
		_band_mats.append(bm)
		var lm := ShaderMaterial.new()
		lm.shader = line_shader
		lm.set_shader_parameter("noise_tex", noise)
		lm.set_shader_parameter("sea", SEA)
		lm.set_shader_parameter("foam", FOAM)
		var line := MeshInstance3D.new()
		line.mesh = plane
		line.material_override = lm
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.visible = false
		add_child(line)
		_lines.append(line)
		_line_mats.append(lm)
	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.radial_segments = 6
	drop.rings = 3
	_mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mote_mat.albedo_color = Color(FOAM, 0.8)
	_mote_mat.disable_fog = true
	drop.material = _mote_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = drop
	mm.instance_count = SLOTS * MOTES_HIGH
	mm.visible_instance_count = 0
	_motes.multimesh = mm
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)


## The wave's profile (x along its travel -0.5..0.5, y up to CREST_M), extruded over z -0.5..0.5: a ramp up the back, a
## crest and a lip curling forward, then down the front. UV.x runs along the length, UV.y is the height over the crest.
static func wave_mesh() -> ArrayMesh:
	var profile: Array[Vector2] = [
		Vector2(-0.5, 0.0),
		Vector2(-0.3, 0.16),
		Vector2(-0.05, 0.38),
		Vector2(0.2, CREST_M),
		Vector2(0.4, 0.44),
		Vector2(0.5, 0.26),
		Vector2(0.46, 0.0)
	]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for p in profile:
		for side in 2:
			verts.append(Vector3(p.x, p.y, float(side) - 0.5))
			uvs.append(Vector2(float(side), p.y / CREST_M))
	for k in profile.size() - 1:
		var a := k * 2
		idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func sync(reader: WorldReader) -> void:
	_waves = reader.boss_waves()
	_place()


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	_clock += delta * (0.35 if ViewPrefs.reduced_motion else 1.0)
	for k in SLOTS:
		(_band_mats[k] as ShaderMaterial).set_shader_parameter("clock", _clock)
		(_line_mats[k] as ShaderMaterial).set_shader_parameter("clock", _clock)
	_draw_motes()


## Puts a foam line or a band on each wave (the sim's tick, so the water pauses with the game).
func _place() -> void:
	_shown_bands = 0
	_shown_lines = 0
	for k in SLOTS:
		_bands[k].visible = false
		_lines[k].visible = false
	for wv in _waves:
		if _shown_bands + _shown_lines >= SLOTS:
			break
		var yaw := TAU * float(int(wv["dir"])) / 4096.0
		var length := float(wv["length"])
		var thick := float(wv["thick"])
		var telegraph := int(wv["telegraph"])
		if telegraph >= 0:
			var k := _shown_lines
			_shown_lines += 1
			var at := (wv["start"] as Vector2) + Kin.dir(int(wv["dir"])) * (LINE_M * 0.5)
			var line := _lines[k]
			line.visible = true
			line.position = SimPlane.to_3d(at, 0.04)
			line.rotation = Vector3(0.0, yaw, 0.0)
			line.scale = Vector3(LINE_M, 1.0, length)
			var m := _line_mats[k]
			m.set_shader_parameter("near", clampf(float(telegraph) / 1000.0, 0.0, 1.0))
			m.set_shader_parameter("alpha", 1.0)
		else:
			var k := _shown_bands
			_shown_bands += 1
			var prog := int(wv["progress"])
			var rise := clampf(float(prog) / RISE_PERMILLE, 0.0, 1.0)
			var sink := clampf(float(1000 - prog) / SINK_PERMILLE, 0.0, 1.0)
			var f := minf(ease(rise, 0.5), ease(sink, 0.5))
			var band := _bands[k]
			band.visible = f > 0.01
			band.position = SimPlane.to_3d(wv["pos"] as Vector2, 0.0)
			band.rotation = Vector3(0.0, yaw, 0.0)
			band.scale = Vector3(thick, maxf(f, 0.01), length)
			(_band_mats[k] as ShaderMaterial).set_shader_parameter("alpha", f)


## Spray: a few motes per wave thrown up off its crest and falling back, each on its own phase along the wave's length.
func _draw_motes() -> void:
	var mm := _motes.multimesh
	var per := MOTES_LOW if ViewPrefs.effects_density == "low" else MOTES_HIGH
	var n := 0
	for wv in _waves:
		if int(wv["telegraph"]) >= 0:
			continue
		var yaw := TAU * float(int(wv["dir"])) / 4096.0
		var fwd := Vector3(cos(yaw), 0.0, -sin(yaw))
		var side := Vector3(sin(yaw), 0.0, cos(yaw))
		var mid := SimPlane.to_3d(wv["pos"] as Vector2, 0.0)
		var half := float(wv["length"]) * 0.5
		for j in per:
			if n >= mm.instance_count:
				break
			var phase := fposmod(
				j * 0.618034 + (0.0 if ViewPrefs.reduced_motion else _clock * 0.9), 1.0
			)
			var lateral := (
				(fposmod(j * 0.381966 + int(wv["formed"]) * 0.137, 1.0) * 2.0 - 1.0) * half
			)
			var rise := sin(phase * PI)
			var at := (
				mid
				+ side * lateral
				+ fwd * (0.15 + phase * 0.4)
				+ Vector3(0.0, 0.25 + rise * 0.45, 0.0)
			)
			var s := (0.5 + 0.5 * fposmod(j * 0.77, 1.0)) * clampf(rise * 1.6, 0.0, 1.0)
			mm.set_instance_transform(
				n, Transform3D(Basis().scaled(Vector3.ONE * maxf(s, 0.01)), at)
			)
			n += 1
	mm.visible_instance_count = n


## Tests: how many foam lines and bands are shown, and how many motes.
func lines_shown() -> int:
	return _shown_lines


func bands_shown() -> int:
	var n := 0
	for b in _bands:
		if b.visible:
			n += 1
	return n


func motes_drawn() -> int:
	return _motes.multimesh.visible_instance_count


## Tests: the shader of a foam line / a band.
func line_material(k: int) -> ShaderMaterial:
	return _line_mats[k]


func band_material(k: int) -> ShaderMaterial:
	return _band_mats[k]


func band(k: int) -> MeshInstance3D:
	return _bands[k]


func line(k: int) -> MeshInstance3D:
	return _lines[k]
