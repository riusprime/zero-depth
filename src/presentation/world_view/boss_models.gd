class_name BossModels
extends RefCounted
## The owner's boss models (PLAN v0.3.0 L13; docs/art/ART_DIRECTION.md §5.2): assets/models/bosses/<id>.glb, one
## textured mesh each, normalised to about one unit. Each is read once per boss type and turned into our facing
## frame (+X the front, Y up, metres, feet on the ground) at the boss's in-game height: the mesh and its material are
## cached, so a spawn only instances them. A missing file gives {} and the boss keeps its code-built body.
## Orientation and size were read from renders of the raw models next to the sheet (evidence/BOSSES.md).
## v0.7.5 BM: the Warlord and the Hive Lens come rigged (a skin and a Tripo skeleton, no animations; owner N14): they
## are kept as delivered ("skinned" in SPECS) and an avatar instances the scene under a node that does the turn, the
## scale and the lift, so the bones animate the owner's own skin; the Foundry is one static mesh, rigged in code like
## the first three (BossRig). Orientation and size from renders of the raw models (v0.7.5 evidence/BOSS_MODELS.md).

const DIR := "res://assets/models/bosses/"
## Per model: its front's direction turned to +X (a yaw in radians about Y) and its height in metres (the
## code-built bodies' heights, which match the sheet's in-game inset against the hero). Each is also rigged here,
## once per type (BossRig).
const SPECS := {
	&"stone_sentinel": {"yaw": 0.0, "height": 2.95},
	&"crawler_queen": {"yaw": -PI * 0.5, "height": 2.4},
	&"fortress_turret": {"yaw": 0.0, "height": 2.5},
	# v0.7.5 BM (evidence/BOSS_MODELS.md): all three face +X as delivered. The Warlord is 2.7 m to its spear's tip;
	# the Hive Lens is 1.9 m across its pods (2.08 m tall) and floats with its sphere's centre 1.75 m up (lift: the
	# metres its lowest point is raised off the ground); the Foundry is 2.6 m.
	&"warlord": {"yaw": 0.0, "height": 2.7, "skinned": true},
	&"hive_lens": {"yaw": 0.0, "height": 2.08, "lift": 0.62, "skinned": true},
	&"foundry": {"yaw": 0.0, "height": 2.6},
	# v0.8.0 FB1 (FINAL_BOSS.md "The models"; evidence/FINAL_BOSS_1.md): the final boss's three bodies, split from the
	# owner's one file, all facing +X as split (raw renders). The Colossus 3.2 m to its halo; the Prism 3.0 m to its
	# crown, floating (lift) above its hanging shards; the Nemesis, the hero's small shadow, 1.5 m.
	&"final_boss_colossus": {"yaw": 0.0, "height": 3.2, "final": true},
	&"final_boss_prism": {"yaw": 0.0, "height": 3.0, "lift": 0.35, "final": true},
	&"final_boss_nemesis": {"yaw": 0.0, "height": 1.5, "final": true},
	# v0.9.0 NB1 (scripts/assets/nb_prep.py): the Tidecaller, front +Z as prepared (turned to +X here), 3.2 m (the art
	# list's), cut into parts in the file: each part is one bone (its node's origin the pivot), the bell hanging from
	# the staff.
	&"boss_tidecaller":
	# v0.9.0 NB2: the Twin Wardens, front +Z as prepared, 2.2 m each (the art list's): the amber one keeps its Mixamo
	{"yaw": PI * 0.5, "height": 3.2, "parts": true, "parents": {&"bell": &"staff"}},
	# skeleton (NB1 rebuilt its joint rests; nearly every vertex weighs on the hips), the violet one is cut into parts.
	&"boss_twin_warden_amber": {"yaw": PI * 0.5, "height": 2.2, "skinned": true},
	&"boss_twin_warden_violet": {"yaw": PI * 0.5, "height": 2.2, "parts": true},
	# v0.9.0 NB3 (PLAN NB: "can you ignore the skeleton?"): the Clockwork Judge, front +Z as prepared, 3.6 m (the art
	# list's), cut into parts in the file (its skin unusable): body, both pendulum arms, the gears, the two hands.
	&"boss_clockwork_judge": {"yaw": PI * 0.5, "height": 3.6, "parts": true},
	# v0.9.0 NB4 (PLAN NB: "Keep the empty hood"): the Lantern Shade, front +Z as prepared, 3.4 m (the art list's),
	# cut into parts in the file: body (the cloak and empty hood), both arms, the held lantern hanging from the right
	# arm; it floats (lift: its ragged hem off the ground).
	&"boss_lantern_shade":
	{
		"yaw": PI * 0.5,
		"height": 3.4,
		"lift": 0.3,
		"parts": true,
		"parents": {&"hand_lantern": &"arm_r"},
	},
}

## v0.7.5 BM (owner N18, 2026-10-13: "Bosses could be a bit bigger so we could see the model better"): every boss
## draws this much bigger than its SPECS height. The one place the scale lives: BossAvatar scales its whole model
## node by it (the owner's model or the code-built fallback, the weak point's core, the Hive Lens's hover, the
## anchors), so SPECS keep the heights the renders were measured at.
const SIZE_SCALE := 1.3

## Where models are looked up (tests point it elsewhere to see the fallback).
static var dir := DIR
static var _cache := {}


## {"mesh": ArrayMesh in our frame, "material": the model's StandardMaterial3D, "aabb": its bounds} or {} if the
## file is missing. A skinned model gives {"skinned": true, "scene": its PackedScene, "transform": what turns,
## scales and lifts it into our frame, "frame": that turn as a Quaternion, "scale", "material", "aabb" (our frame)}.
static func get_model(id: StringName) -> Dictionary:
	var path := dir + String(id) + ".glb"
	if _cache.has(path):
		return _cache[path]
	var out := {}
	if ResourceLoader.exists(path):
		var spec: Dictionary = SPECS.get(id, {"yaw": 0.0, "height": 2.5})
		var scene := load(path) as PackedScene
		if spec.get("parts", false):  # v0.9.0 NB1: a model cut into parts in its file
			out = _convert_parts(scene, spec)
		else:
			out = (
				_convert_skinned(scene, spec)
				if spec.get("skinned", false)
				else _convert(scene, spec, id)
			)
	_cache[path] = out
	return out


## Reads every boss model now (the stage build), so no spawn waits on an import. v0.8.0 FB1: the final boss's three
## (their textures are big) only with `final` (a world that holds the fight: the final arena, the Playground).
static func preload_all(final: bool = false) -> void:
	for id: StringName in SPECS:
		if final or not (SPECS[id] as Dictionary).get("final", false):
			get_model(id)


## How many models were read from disk (tests check each is read once).
static func loaded_count() -> int:
	var n := 0
	for k in _cache:
		if not (_cache[k] as Dictionary).is_empty():
			n += 1
	return n


static func clear_cache() -> void:
	_cache.clear()


static func _convert(scene: PackedScene, spec: Dictionary, id: StringName) -> Dictionary:
	var surface := ModelLibrary.first_surface(scene)
	if surface.is_empty():
		return {}
	var mat: StandardMaterial3D = surface["material"]
	var arrays: Array = surface["arrays"]
	var aabb: AABB = surface["aabb"]
	var s: float = spec["height"] / maxf(aabb.size.y, 0.0001)
	var turn := Basis(Vector3.UP, spec["yaw"])
	var lift := -aabb.position.y * s + float(spec.get("lift", 0.0))  # v0.8.0 FB1: the Prism floats
	var centre := aabb.get_center()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in verts.size():
		var v := verts[k] - Vector3(centre.x, 0.0, centre.z)
		verts[k] = turn * (v * s) + Vector3(0, lift, 0)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for k in ns.size():
			ns[k] = turn * ns[k]
		arrays[Mesh.ARRAY_NORMAL] = ns
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var ts: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for k in range(0, ts.size(), 4):
			var t := turn * Vector3(ts[k], ts[k + 1], ts[k + 2])
			ts[k] = t.x
			ts[k + 1] = t.y
			ts[k + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = ts
	# The rig (v0.3.0 L13): bones and weights from the mesh's geometry, written into the mesh (4 per vertex).
	var rig := BossRig.build(id, verts, _indices(arrays))
	arrays[Mesh.ARRAY_BONES] = rig.bone_ids
	arrays[Mesh.ARRAY_WEIGHTS] = rig.weights
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var box := out.get_aabb()
	# Bones move parts beyond the rest pose's bounds (a raised fist, a leap's tucked legs): never cull them early.
	out.custom_aabb = box.grow(1.5)
	var skin := Skin.new()
	for k in rig.bones.size():
		skin.add_named_bind(
			String(rig.bones[k][0]), Transform3D(Basis(), -(rig.bones[k][2] as Vector3))
		)
	return {"mesh": out, "material": mat, "aabb": box, "arrays": arrays, "rig": rig, "skin": skin}


## The surface's triangle indices (empty for a non-indexed surface: each three vertices a triangle).
static func _indices(arrays: Array) -> PackedInt32Array:
	if arrays[Mesh.ARRAY_INDEX] != null:
		return arrays[Mesh.ARRAY_INDEX]
	var out := PackedInt32Array()
	for k in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		out.append(k)
	return out


## v0.9.0 NB1: a model cut into parts in its file (nb_prep.py: one node per part, its origin the part's pivot) as one
## mesh in our frame at its height, rigged with one bone per part (named in snake case: Body -> body, ArmL -> arm_l;
## every vertex wholly its part's; a part hangs from `parents`' bone, else from body), so the avatar poses it like the
## code-rigged models. Same result keys as _convert.
static func _convert_parts(scene: PackedScene, spec: Dictionary) -> Dictionary:
	if scene == null:
		return {}
	var root := scene.instantiate()
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	var parts := []  # [bone name, pivot (file frame), arrays (file frame)]
	var mat: StandardMaterial3D = null
	var box := AABB()
	for n: Node in found:
		var mi := n as MeshInstance3D
		var xf := relative_transform(root, mi)
		var arrays := mi.mesh.surface_get_arrays(0)
		if mat == null:
			mat = mi.mesh.surface_get_material(0) as StandardMaterial3D
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for k in verts.size():
			verts[k] = xf * verts[k]
		arrays[Mesh.ARRAY_VERTEX] = verts
		var part_box := AABB(verts[0], Vector3.ZERO) if not verts.is_empty() else AABB()
		for v in verts:
			part_box = part_box.expand(v)
		box = part_box if parts.is_empty() else box.merge(part_box)
		parts.append([StringName(String(mi.name).to_snake_case()), xf.origin, arrays])
	root.free()
	if parts.is_empty():
		return {}
	var parents: Dictionary = spec.get("parents", {})
	# The body first, then the parts hanging from it, then those hanging from another part (a parent before its child).
	var rank := func(p: Array) -> int:
		return 0 if p[0] == &"body" else (2 if parents.has(p[0]) else 1)
	parts.sort_custom(
		func(a: Array, b: Array) -> bool:
			return [rank.call(a), String(a[0])] < [rank.call(b), String(b[0])]
	)
	var s: float = spec["height"] / maxf(box.size.y, 0.0001)
	var turn := Basis(Vector3.UP, spec["yaw"])
	var centre := Vector3(box.get_center().x, 0.0, box.get_center().z)
	var lift := -box.position.y * s + float(spec.get("lift", 0.0))
	var to_ours := func(v: Vector3) -> Vector3:
		return turn * ((v - centre) * s) + Vector3(0, lift, 0)
	var rig := BossRig.new()
	BossRig.builds += 1
	for p: Array in parts:
		var up: StringName = parents.get(p[0], &"body") if p[0] != &"body" else &""
		rig.bones.append([p[0], rig.index_of(up) if up != &"" else -1, to_ours.call(p[1])])
	var merged := []
	merged.resize(Mesh.ARRAY_MAX)
	var mv := PackedVector3Array()
	var mn := PackedVector3Array()
	var mt := PackedFloat32Array()
	var mu := PackedVector2Array()
	var mx := PackedInt32Array()
	for b in parts.size():
		var arrays: Array = parts[b][2]
		var base := mv.size()
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			mv.append(to_ours.call(v))
			rig.bone_ids.append_array([b, 0, 0, 0])
			rig.weights.append_array([1.0, 0.0, 0.0, 0.0])
		for nv: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			mn.append(turn * nv)
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var ts: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for k in range(0, ts.size(), 4):
				var t := turn * Vector3(ts[k], ts[k + 1], ts[k + 2])
				mt.append_array([t.x, t.y, t.z, ts[k + 3]])
		mu.append_array(arrays[Mesh.ARRAY_TEX_UV])
		for k in _indices(arrays):
			mx.append(base + k)
	merged[Mesh.ARRAY_VERTEX] = mv
	merged[Mesh.ARRAY_NORMAL] = mn
	if mt.size() == mv.size() * 4:
		merged[Mesh.ARRAY_TANGENT] = mt
	merged[Mesh.ARRAY_TEX_UV] = mu
	merged[Mesh.ARRAY_INDEX] = mx
	merged[Mesh.ARRAY_BONES] = rig.bone_ids
	merged[Mesh.ARRAY_WEIGHTS] = rig.weights
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged)
	var aabb := out.get_aabb()
	out.custom_aabb = aabb.grow(1.5)
	var skin := Skin.new()
	for k in rig.bones.size():
		skin.add_named_bind(
			String(rig.bones[k][0]), Transform3D(Basis(), -(rig.bones[k][2] as Vector3))
		)
	return {"mesh": out, "material": mat, "aabb": aabb, "arrays": merged, "rig": rig, "skin": skin}


## A rigged model kept as delivered: the transform that puts its skinned mesh (as its rest pose draws it) in our
## frame at its height, centred in x and z, its lowest point `lift` metres up.
static func _convert_skinned(scene: PackedScene, spec: Dictionary) -> Dictionary:
	if scene == null:
		return {}
	var root := scene.instantiate()
	var skel: Skeleton3D = null
	var found: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		skel = found[0]
	var mi: MeshInstance3D = null
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin != null:
			mi = n
			break
	if skel == null or mi == null or mi.skin.get_bind_count() == 0:
		root.free()
		return {}
	# A skinned vertex lands at skeleton * its bone's pose * the bind; at rest every bind gives the same mesh to
	# skeleton map, so bind 0 places the whole mesh.
	var skin := mi.skin
	var b := skin.get_bind_bone(0)
	if b < 0:
		b = skel.find_bone(String(skin.get_bind_name(0)))
	var to_root := (
		relative_transform(root, skel) * skel.get_bone_global_rest(b) * skin.get_bind_pose(0)
	)
	var box := to_root * mi.mesh.get_aabb()
	var s: float = spec["height"] / maxf(box.size.y, 0.0001)
	var turn := Basis(Vector3.UP, spec["yaw"])
	var centre := box.get_center()
	var xf := Transform3D(turn.scaled(Vector3.ONE * s), Vector3.ZERO)
	xf.origin = (
		turn * (-Vector3(centre.x, 0.0, centre.z) * s)
		+ Vector3(0, -box.position.y * s + float(spec.get("lift", 0.0)), 0)
	)
	var mat := mi.get_active_material(0) as StandardMaterial3D
	root.free()
	return {
		"skinned": true,
		"scene": scene,
		"transform": xf,
		"frame": turn.get_rotation_quaternion(),
		"scale": s,
		"material": mat,
		"aabb": xf * box,
	}


## `node`'s transform in `root`'s space (neither needs to be in the tree).
static func relative_transform(root: Node, node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
