class_name DamageFlashKeys
extends RefCounted
## What picks a BaseMaterial3D's shader: its features, flags and modes, not its colours or energies. Changing any
## of these at run time makes the renderer compile another shader variant (PLAN v0.2.0 L11,
## docs/roadmap/v0.2.0/evidence/DAMAGE_LAG.md).


static func key(m: BaseMaterial3D) -> String:
	var parts: Array = [
		m.transparency,
		m.shading_mode,
		m.cull_mode,
		m.blend_mode,
		m.depth_draw_mode,
		m.billboard_mode,
		m.stencil_mode,
		m.diffuse_mode,
		m.specular_mode,
		m.texture_filter,
	]
	for f in BaseMaterial3D.FEATURE_MAX:
		parts.append(m.get_feature(f))
	for f in BaseMaterial3D.FLAG_MAX:
		parts.append(m.get_flag(f))
	return str(parts)


## The shader key of every material override under a node, by "<node path>": key.
static func of(n: Node) -> Dictionary:
	var out := {}
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var m := (c as MeshInstance3D).material_override as BaseMaterial3D
		if m != null:
			out[str(n.get_path_to(c))] = key(m)
	return out
