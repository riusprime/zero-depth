class_name WardenDust
extends MeshInstance3D
## The Warden's slam dust ring: a flat band (unit outer radius) just above the floor, unshaded and see-through, laid
## flat on the ground under the Warden (its facing doesn't matter for a ring). It runs from START of the slam's radius
## to its full radius over SECONDS from the impact, fading out; its band is BAND of the radius wide. Neutral dust, not a
## reserved role. A node of a VAT Warden's too (not baked: SoloVat.LIVE); a batched Warden's is kept in the tree by
## BatchWarden. Presentation only (EI-07).

const SECONDS := 0.45
const START := 0.3
const BAND := 0.22
const ALPHA := 0.9
const COLOR := Color("#F4EEE2")
const SEGMENTS := 40

var _mat := StandardMaterial3D.new()


func _init() -> void:
	name = "SlamDust"
	set_meta(SoloVat.LIVE, true)
	mesh = _ring_mesh()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(COLOR, 0.0)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(0, 0.05, 0)
	visible = false


## The ring `t` seconds after the impact (-1: none showing), run out toward `radius`.
func show_at(t: float, radius: float) -> void:
	if t < 0.0:
		visible = false
		return
	var u := t / SECONDS
	var ease := 1.0 - (1.0 - u) * (1.0 - u)
	var r := radius * lerpf(START, 1.0, ease)
	visible = true
	scale = Vector3(r, 1.0, r)
	var c := COLOR
	c.a = ALPHA * (1.0 - u) * (1.0 - u * 0.5)
	_mat.albedo_color = c


static func _ring_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var inner := 1.0 - BAND
	for k in SEGMENTS:
		var a0 := TAU * k / SEGMENTS
		var a1 := TAU * (k + 1) / SEGMENTS
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		verts.append_array([o0, o1 * inner, o0 * inner, o0, o1, o1 * inner])
		for j in 6:
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
