class_name LaserView
extends Node3D
## v0.9.0 LZ (owner C §6.2; PLAN C48, C49): the Laser's beams while it fires. Each beam (WorldReader.beams: the sim's
## own trace, so the drawn beam ends where the hits are) is a camera-facing ribbon at the shot's height with the
## look's scrolling strip (BeamLooks: core and edge colour, the owner's beam_core_<look> PNG or the code strip), a
## muzzle glow at the hero, and an impact where it ends (on an enemy or a wall): a flickering star in the look's
## colours and spikes. With the effects layer (VfxLayer) the element adds its accent along the beam (Fire's layered
## flames, Lightning's arcs, Frost's motes, Venom's and Bleed's drips: VfxLayer.line) and sparks and a light at the
## impact. Presentation only (EI-07): it reads the reader, never writes; the scroll and flicker use the shader clock.

const BEAMS_MAX := 3
const HEIGHT := SimPlane.CORE_HEIGHT
const IMPACT_SIZE := 0.9
const MUZZLE_SIZE := 0.55
## The strip tiles this many times a metre along the beam.
const TILES_PER_M := 0.6
## v0.9.0 VX V8: the impact's element extra plays every EXTRA_EVERY ticks (twice a second) for EXTRA_TICKS.
const EXTRA_EVERY := 30.0
const EXTRA_TICKS := 18.0

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D strip : source_color, repeat_enable, filter_linear;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.1, 0.3, 0.8, 1.0);
uniform float length_m = 1.0;
uniform float tiles = 0.6;
uniform float scroll = 2.0;
uniform float energy = 1.7;
void fragment() {
	vec2 uv = vec2(UV.x * length_m * tiles - TIME * scroll, UV.y);
	vec4 t = texture(strip, uv);
	float ends = smoothstep(0.0, 0.04, UV.x) * smoothstep(1.0, 0.97, UV.x);
	// v0.9.0 VX: three tones, the outer glow in the element's deep tone, the body its colour, the centre white-hot.
	vec3 body = mix(deep.rgb, edge.rgb, smoothstep(0.0, 0.35, t.r));
	ALBEDO = mix(body, core.rgb, smoothstep(0.35, 1.0, t.r)) * t.a * energy * ends;
}
"""
const IMPACT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float spikes = 4.0;
uniform float soft = 0.5;
uniform float flicker = 9.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = atan(d.y, d.x) + TIME * 1.3;
	float star = spikes > 0.5 ? pow(abs(cos(a * spikes * 0.5)), 6.0) * (1.0 - r) : 0.0;
	float pulse = 0.8 + 0.2 * sin(TIME * flicker * 6.2832);
	float glow = exp(-r * r * (3.0 + 6.0 * (1.0 - soft)));
	float hot = exp(-r * r * 22.0);
	ALBEDO = (edge.rgb * (glow + star * 1.4) + core.rgb * hot * 1.6) * pulse * 1.5;
}
"""

static var _shaders := {}

## What the last sync showed (tests read them): the beams drawn, their look, and the impacts.
var shown := 0
var look := &"default"
var impacts := 0
## The effects layer for the element accents (WorldViewRoot hands it in; null: the ribbons and impacts alone).
var vfx: VfxLayer = null

var _ribbons: Array[MeshInstance3D] = []
var _impacts: Array[MeshInstance3D] = []
var _muzzle: MeshInstance3D
var _beam_mat: Array[ShaderMaterial] = []
var _impact_mat: Array[ShaderMaterial] = []
var _beams: Array[Dictionary] = []
var _look_set := &""
var _form := FormLook.new()


func _init() -> void:
	name = "LaserView"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in BEAMS_MAX:
		var bm := ShaderMaterial.new()
		bm.shader = _shader(BEAM_SHADER)
		var r := MeshInstance3D.new()
		r.mesh = quad
		r.material_override = bm
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		_ribbons.append(r)
		_beam_mat.append(bm)
		var im := ShaderMaterial.new()
		im.shader = _shader(IMPACT_SHADER)
		var i := MeshInstance3D.new()
		i.mesh = quad
		i.material_override = im
		i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		i.visible = false
		add_child(i)
		_impacts.append(i)
		_impact_mat.append(im)
	_muzzle = MeshInstance3D.new()
	_muzzle.mesh = quad
	_muzzle.material_override = _impact_mat[0].duplicate()
	_muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle.visible = false
	add_child(_muzzle)


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## Each tick: the beams now and their look (v0.9.0 VX V48: read again only when the build changes).
func sync(reader: WorldReader) -> void:
	_beams = reader.beams()
	var d := reader.attack_digest()
	if not _form.read_once or d != _form.digest:
		_form.read_once = true
		_form.digest = d
		_form.set_elements(reader.beam_elements())
		look = _form.look
		_set_look(look)
	shown = mini(_beams.size(), BEAMS_MAX)
	impacts = 0
	for k in BEAMS_MAX:
		_ribbons[k].visible = k < shown
		_impacts[k].visible = false
	_muzzle.visible = shown > 0
	if shown == 0:
		return
	_muzzle.position = SimPlane.to_3d(_beams[0]["from"], HEIGHT)
	_muzzle.scale = Vector3.ONE * MUZZLE_SIZE * (1.0 + 0.4 * (shown - 1))
	for k in shown:
		var b: Dictionary = _beams[k]
		var hits: PackedInt32Array = b["hits"]
		if hits.size() > 0 or bool(b["wall"]):
			_impacts[k].visible = true
			_impacts[k].position = SimPlane.to_3d(b["to"], HEIGHT)
			_impacts[k].scale = Vector3.ONE * IMPACT_SIZE
			impacts += 1
	_place_ribbons()


func _process(_delta: float) -> void:
	if shown > 0:
		_place_ribbons()


## The ribbons face the camera along their beams (each frame: the camera moves between ticks).
func _place_ribbons() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := Vector3(0, 1, 1).normalized() if cam == null else cam.global_transform.basis.z
	var w := BeamLooks.width(look)
	for k in shown:
		var b: Dictionary = _beams[k]
		var a := SimPlane.to_3d(b["from"], HEIGHT)
		var e := SimPlane.to_3d(b["to"], HEIGHT)
		var along := e - a
		var len := along.length()
		if len < 0.01:
			_ribbons[k].visible = false
			continue
		var x := along / len
		var y := x.cross(view).normalized()
		if y.length_squared() < 0.5:
			y = Vector3.UP.cross(x).normalized()
		var n := x.cross(y).normalized()
		_ribbons[k].transform = Transform3D(Basis(x * len, y * w, n), (a + e) * 0.5)
		_beam_mat[k].set_shader_parameter(&"length_m", len)


## The look's strip, scroll and impact shape (its first element), in the V2 colours (the first element's centre, the
## second's edge: FormLook).
func _set_look(l: StringName) -> void:
	_look_set = l
	var tex := BeamLooks.texture(l)
	var imp := BeamLooks.impact(l)
	for k in BEAMS_MAX:
		var bm := _beam_mat[k]
		bm.set_shader_parameter(&"strip", tex)
		bm.set_shader_parameter(&"core", _form.core)
		bm.set_shader_parameter(&"edge", _form.edge)
		bm.set_shader_parameter(&"deep", _form.glow)
		bm.set_shader_parameter(&"scroll", BeamLooks.scroll(l))
		bm.set_shader_parameter(&"tiles", TILES_PER_M)
		for m: ShaderMaterial in [_impact_mat[k], _muzzle.material_override as ShaderMaterial]:
			m.set_shader_parameter(&"core", _form.core)
			m.set_shader_parameter(&"edge", _form.edge)
			m.set_shader_parameter(&"spikes", float(imp[0]))
			m.set_shader_parameter(&"soft", float(imp[1]))
			m.set_shader_parameter(&"flicker", float(imp[2]))


## VfxLayer's drawer (WorldViewRoot appends it): the element's accent along each beam and the impact's sparks and
## light. The default energy beam adds sparks and its light only.
func draw_fx(layer: VfxCore) -> void:
	if shown == 0:
		return
	var fx := layer as VfxLayer
	var kind: StringName = BeamLooks.VFX_KIND[look]
	var now := layer.now()
	var col := _form.edge
	for k in shown:
		var b: Dictionary = _beams[k]
		var a := SimPlane.to_3d(b["from"], HEIGHT)
		var e := SimPlane.to_3d(b["to"], HEIGHT)
		var sd := 7001 + k * 131
		if kind != &"" and fx != null:
			fx.line(kind, a, e, 1.0, now, sd)
		if not _impacts[k].visible:
			continue
		for j in 3:
			var t := fposmod(now * 0.37 + j * 0.33, 1.0)
			var off := (
				Vector3(cos(j * 2.1 + now * 0.3), 0.3 + t, sin(j * 2.1 + now * 0.3)) * 0.35 * t
			)
			var c := Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 1.0 - t)
			layer.sprite(&"spark", e + off, 0.22 * (1.0 - t), c, j % 4, 0.0)
		layer.light_merged(e + Vector3(0, 0.4, 0), col, 1.6, 3.0, 1.5)
		# v0.9.0 VX V8: the element's extra at the beam's end (HeroFx.impact, V4's), at most twice a second per beam,
		# never on every damage tick: one plays every EXTRA_EVERY ticks and lasts EXTRA_TICKS.
		var u := fposmod(now + k * 7.0, EXTRA_EVERY) / EXTRA_TICKS
		if u < 1.0:
			var dir := (e - a).normalized()
			var cyc := int((now + k * 7.0) / EXTRA_EVERY)
			HeroFx.impact(layer, _form.kind, e, dir, u, sd + cyc * 31, 0.9)
