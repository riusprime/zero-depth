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
## v0.9.0 VX (VFX_AUDIT.md V30, owner: Wave and Wisps get V30/V31's intent and the element accents): the band unrolls
## from the hero over UNROLL_TICKS; its colours are the first element's centre and the second's edge (V2); at its foot
## a skim of dust, or with an element its accent (HeroFx.accent), Medium and High only (V47).
## Pooled (WAVES_MAX drawn, the rest skipped). Presentation only (EI-07): the sim decides where, how wide and which
## way; the shimmer's clock is the shader's.

const WAVES_MAX := 12
const CREST_H := 1.0
const WASH_LEN := 1.6
const LIFT := 0.04
const UNROLL_TICKS := 4.0
## v0.9.0 VX: the foot's pieces a wave a frame at High (half at Medium).
const FOOT_PIECES := 4

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
var _form := FormLook.new()
## v0.9.0 VX: each shot's first tick (the unroll), and this sync's waves for the effects layer (place, way, half width).
var _born := {}
var _seen := {}
var _pos: Array[Vector2] = []
var _dir: Array[Vector2] = []
var _half: PackedFloat32Array = PackedFloat32Array()
var _ids: PackedInt32Array = PackedInt32Array()
var _tick := 0.0


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
	_tick = float(reader.tick())
	var changed := _form.refresh(reader)
	look = _form.look
	var shots := reader.wave_shots()
	waves = mini(shots.size(), WAVES_MAX)
	widths.clear()
	_pos.clear()
	_dir.clear()
	_half.clear()
	_ids.clear()
	_seen.clear()
	for k in WAVES_MAX:
		var on := k < waves
		_crests[k].visible = on
		_washes[k].visible = on
		if changed:
			_crest_mat[k].set_shader_parameter(&"core", _form.core)
			_crest_mat[k].set_shader_parameter(&"edge", _form.edge)
			_wash_mat[k].set_shader_parameter(&"edge", _form.edge)
		if not on:
			continue
		var s: Dictionary = shots[k]
		var half := float(s["half"])
		var id := int(s.get("id", k))
		_seen[id] = true
		if not _born.has(id):
			_born[id] = _tick
		var grow := clampf((_tick - float(_born[id]) + 1.0) / UNROLL_TICKS, 0.0, 1.0)
		widths.append(half * 2.0)
		_pos.append(s["pos"])
		_dir.append(s["dir"])
		_half.append(half)
		_ids.append(id)
		_place(k, s["pos"], s["dir"], half * maxf(grow, 0.05))
	for id: int in _born.keys():
		if not _seen.has(id):
			_born.erase(id)


func _place(k: int, pos: Vector2, dir: Vector2, half: float) -> void:
	var x := SimPlane.to_3d(dir, 0.0).normalized()
	var z := SimPlane.to_3d(Vector2(-dir.y, dir.x), 0.0).normalized()
	var base := SimPlane.to_3d(pos, LIFT)
	_crests[k].transform = Transform3D(Basis(x, Vector3.UP * CREST_H, z * half), base)
	var behind := base - x * (WASH_LEN * 0.5)
	_washes[k].transform = Transform3D(Basis(z * half * 2.0, Vector3.UP, x * WASH_LEN), behind)


## The effects layer's drawer (WorldViewRoot appends it): at each wave's foot its element's accent, or a skim of dust
## (lit matter) without one; Medium and High only.
func draw_fx(layer: VfxCore) -> void:
	if layer.density < HeroFx.LOW:
		return
	var n := FOOT_PIECES if layer.density >= 0.7 else FOOT_PIECES / 2
	var now := layer.now()
	for k in _pos.size():
		var x := SimPlane.to_3d(_dir[k], 0.0).normalized()
		var z := SimPlane.to_3d(Vector2(-_dir[k].y, _dir[k].x), 0.0).normalized()
		var base := SimPlane.to_3d(_pos[k], 0.15)
		for j in n:
			var sd := _ids[k] * 17 + j
			var across := (VfxCore.h(sd, int(now / 9.0)) * 2.0 - 1.0) * _half[k] * 0.9
			var q := base + z * across
			if _form.kind != &"":
				HeroFx.accent(layer, _form.kind, _form.element, q + Vector3(0, 0.25, 0), x, sd, 0.9)
				continue
			var u := fposmod(now + VfxCore.h(sd, 3) * 24.0, 24.0) / 24.0
			var dust := Color(0.62, 0.58, 0.52, 0.32 * sin(PI * u))
			var dq := q - x * (0.3 + 0.6 * u) + Vector3(0, 0.3 * u, 0)
			layer.sprite(&"smoke", dq, 0.45 + 0.4 * u, dust, sd % 4, VfxCore.h(sd, 5) * TAU)
