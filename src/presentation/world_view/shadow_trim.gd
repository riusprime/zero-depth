class_name ShadowTrim
extends RefCounted
## v0.9.5 PF4 (owner, 2026-10-26: "Simpler enemy shadows"): an enemy's small rig pieces (feet, collars, eyes, pods) are
## each drawn again for every shadow cascade. Only the actor's largest `keep` pieces, by mesh bounding-box volume at
## the pieces' scale in the avatar, keep casting; the rest stop. Presentation only (EI-07).

## false: every piece casts, as before PF4.
const ENABLED := true
const ENEMY_KEEP := 2
const BOSS_KEEP := 4


## Turns shadows off on every shadow-casting MeshInstance3D under `top` except the `keep` largest.
## Returns [pieces that cast before, pieces that cast after].
static func trim(top: Node3D, keep: int) -> Array[int]:
	if not ENABLED:
		return [0, 0]
	var found: Array = []
	_collect(top, Vector3.ONE, found)
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in found.size():
		if k >= keep:
			((found[k] as Array)[1] as MeshInstance3D).cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
	return [found.size(), mini(found.size(), keep)]


static func _collect(n: Node, scale_in: Vector3, out: Array) -> void:
	var s := scale_in
	var n3 := n as Node3D
	if n3 != null:
		s = scale_in * n3.scale
	var mi := n as MeshInstance3D
	if (
		mi != null
		and mi.mesh != null
		and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	):
		var size := mi.mesh.get_aabb().size * s.abs()
		out.append([size.x * size.y * size.z, mi])
	for c in n.get_children():
		_collect(c, s, out)
