class_name WaveView
extends Node3D
## v0.9.0 AF3 (owner Q7; ATTACK_FORMS.md F9 "A wide slow wave that rolls forward through everything"): the Wave's look.
## Each Wave shot in flight (WorldReader.wave_shots) is drawn as a band as wide as the sim's (its half width, the area
## stat on it) square to its flight:
## - a standing crest: a curved sheet of light up to body height (alpha-blended, so it reads on a light floor too),
##   bright along its top edge, its core and edge in the element's colours (BeamLooks: default energy, Fire,
##   Lightning, Frost, Venom, Bleed), its ends fading;
## - a wash on the ground behind it: a flat fan of the edge colour trailing the crest, so the band's width and way read
##   from the iso camera.
## Pooled (WAVES_MAX drawn, the rest skipped). Presentation only (EI-07): the sim decides where, how wide and which
## way; the shimmer's clock is the shader's.

const WAVES_MAX := 12
const CREST_H := 1.0
const WASH_LEN := 1.6
const LIFT := 0.04

const CREST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float ends = smoothstep(1.0, 0.7, across);
	float up = UV.y;
	float lip = exp(-pow((1.0 - up) * 6.0, 2.0));
	float body = smoothstep(0.0, 0.9, 1.0 - up) * 0.45;
	float ripple = 0.75 + 0.25 * sin(UV.x * 40.0 - TIME * 9.0);
	ALBEDO = mix(edge.rgb * 1.3, core.rgb * 1.5, lip) * ripple;
	ALPHA = clamp((body * 1.4 + lip) * ends, 0.0, 0.95);
}
"""
const WASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float ends = smoothstep(1.0, 0.75, across);
	float fade = UV.y * UV.y;
	ALBEDO = edge.rgb * 1.2;
	ALPHA = fade * ends * 0.45;
}
"""

static var _shaders := {}

## What the last sync showed (tests read them): the waves drawn, their widths (m), the look.
var waves := 0
var widths: Array[float] = []
var look := &"default"

var _crests: Array[MeshInstance3D] = []
var _crest_mat: Array[ShaderMaterial] = []
var _washes: Array[MeshInstance3D] = []
var _wash_mat: Array[ShaderMaterial] = []


func _init() -> void:
	name = "WaveView"
	var crest := crest_mesh()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	for k in WAVES_MAX:
		var c := _node(crest, CREST_SHADER)
		_crests.append(c)
		_crest_mat.append(c.material_override as ShaderMaterial)
		var w := _node(quad, WASH_SHADER)
		_washes.append(w)
		_wash_mat.append(w.material_override as ShaderMaterial)


func _node(mesh: Mesh, code: String) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = _shader(code)
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## A unit crest: a sheet across z from -1 to 1, 0 to 1 up, bowed forward along +x at its middle (a rolling front).
## UV.x = across (0..1), UV.y = up (0..1).
static func crest_mesh() -> ArrayMesh:
	var steps := 12
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for k in steps:
		var a := float(k) / steps
		var b := float(k + 1) / steps
		var za := a * 2.0 - 1.0
		var zb := b * 2.0 - 1.0
		var xa := 0.25 * (1.0 - za * za)
		var xb := 0.25 * (1.0 - zb * zb)
		var p0 := Vector3(xa, 0.0, za)
		var p1 := Vector3(xb, 0.0, zb)
		var p2 := Vector3(xb + 0.1, 1.0, zb)
		var p3 := Vector3(xa + 0.1, 1.0, za)
		verts.append_array([p0, p1, p2, p0, p2, p3])
		uvs.append_array(
			[
				Vector2(a, 0.0),
				Vector2(b, 0.0),
				Vector2(b, 1.0),
				Vector2(a, 0.0),
				Vector2(b, 1.0),
				Vector2(a, 1.0)
			]
		)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Each tick: the Wave shots in flight.
func sync(reader: WorldReader) -> void:
	var spec := reader.attack_spec(WorldReader.ATTACK_BOLT)
	look = BeamLooks.look_of(PackedStringArray(spec.get("elements", [])))
	var shots := reader.wave_shots()
	waves = mini(shots.size(), WAVES_MAX)
	widths.clear()
	for k in WAVES_MAX:
		var on := k < waves
		_crests[k].visible = on
		_washes[k].visible = on
		if not on:
			continue
		var s: Dictionary = shots[k]
		var half := float(s["half"])
		widths.append(half * 2.0)
		_place(k, s["pos"], s["dir"], half)


func _place(k: int, pos: Vector2, dir: Vector2, half: float) -> void:
	var x := SimPlane.to_3d(dir, 0.0).normalized()
	var z := SimPlane.to_3d(Vector2(-dir.y, dir.x), 0.0).normalized()
	var base := SimPlane.to_3d(pos, LIFT)
	_crests[k].transform = Transform3D(Basis(x, Vector3.UP * CREST_H, z * half), base)
	var behind := base - x * (WASH_LEN * 0.5)
	_washes[k].transform = Transform3D(Basis(z * half * 2.0, Vector3.UP, x * WASH_LEN), behind)
	var core := BeamLooks.core(look)
	var edge := BeamLooks.edge(look)
	_crest_mat[k].set_shader_parameter(&"core", core)
	_crest_mat[k].set_shader_parameter(&"edge", edge)
	_wash_mat[k].set_shader_parameter(&"edge", edge)
