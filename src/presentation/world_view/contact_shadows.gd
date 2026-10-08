class_name ContactShadows
extends RefCounted
## Contact shadow on the ground around every block (v0.5.9 Step 1, owner L3: "the occlusion ambience"). Each
## footprint gets a soft dark falloff on the ground, like ambient occlusion where a block meets the floor. Godot's
## SSAO barely reaches the ground under the orthographic iso camera (evidence/LOOK.md: at its maximum it gave a
## faint, blurry darkening and no contact line), so this draws it from the geometry instead. That is the custom
## shader ARCHITECTURE §11 allows once a scene proves the need. One mesh for the whole floor, so one draw call.
## Presentation only.

## Just above the ground, under telegraphs and decals.
const LIFT := 0.012

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float radius = 0.9;
uniform float strength = 0.55;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// UV: this point's offset from the footprint's centre (m, in the footprint's frame); UV2: its half extents.
	vec2 outside = max(abs(UV) - UV2, vec2(0.0));
	float t = 1.0 - clamp(length(outside) / radius, 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = strength * t * t;
}
"""

static var _shader: Shader


## A mesh with one falloff quad per footprint. `boxes`: [center (Vector2, sim metres), half (Vector2), yaw
## (radians, as SimPlane.yaw_of)]. Returns null when there are no boxes.
static func build(boxes: Array, radius: float, strength: float) -> MeshInstance3D:
	if boxes.is_empty():
		return null
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var corners := [
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(1, 1),
		Vector2(-1, -1),
		Vector2(1, 1),
		Vector2(-1, 1)
	]
	for b: Array in boxes:
		var center := SimPlane.to_3d(b[0], LIFT)
		var half: Vector2 = b[1]
		var ext := half + Vector2(radius, radius)
		for c: Vector2 in corners:
			var local := Vector2(c.x * ext.x, c.y * ext.y)
			verts.append(center + Vector3(local.x, 0, local.y).rotated(Vector3.UP, b[2]))
			uvs.append(local)
			uv2s.append(half)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("strength", strength)
	mat.render_priority = -1
	var node := MeshInstance3D.new()
	node.name = "ContactShadows"
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
