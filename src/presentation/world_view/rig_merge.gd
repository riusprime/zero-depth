class_name RigMerge
extends RefCounted
## v0.9.5 PF5 (owner, 2026-10-26: "merge the enemy's pieces only if that does not change how animations look, the
## idea is to keep the animations as they are"): one enemy's many rigid mesh pieces become a few skinned meshes, so a
## crowd of them costs a few draw calls each instead of dozens. Every Node3D from the avatar down to a piece becomes
## one bone of a MergedRig (the same hierarchy, the same transforms), each piece's vertices are bound entirely to its
## own bone (rigid skinning) and baked in the avatar's space at the moment of merging, which is the skeleton's rest.
## The avatar keeps animating its own nodes exactly as before; only where the pieces are drawn changes. The original
## piece nodes stay in the tree with no mesh (they cost nothing to draw), and keep their materials.
##
## Pieces that need a node of their own stay as they are (AvatarBase.rig_spec): a piece with a per-instance shader
## value that differs from the rest, a mesh swapped at runtime, a node added or freed at runtime.
## One surface per distinct material; the pieces are split into a mesh per (shadow casting, takes the hit flash)
## so a group's instance parameters and shadow setting are right for all its surfaces.

## How far (metres) the merged mesh's culling box is grown beyond the rest pose (poses move parts past it).
const CULL_GROW := 1.2

## The merged meshes and skins already built, by avatar script and kind (see _meshes_for).
static var _cache: Dictionary = {}
## false: nothing is merged (the pre-PF5 rigs); tools flip it to compare.
static var enabled := true
## Kinds (WorldReader.KIND_*) whose rig is left as built (a rig that could not be merged without a visible change).
static var skip_kinds: Dictionary = {}


## Forgets the cached merged meshes (tests).
static func clear_cache() -> void:
	_cache.clear()


## The MeshInstance3D nodes under `n` (a subtree an avatar keeps whole: AvatarBase.rig_spec).
static func pieces_under(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(pieces_under(c))
	return out


## Merges an actor's enemy avatar (not a boss, not the hero) and refreshes the actor's flash materials.
static func merge_actor(root: Node3D, kind: int) -> void:
	if root.has_meta(&"boss") or not root.has_meta(&"enemy_avatar"):
		return
	var avatar := root.get_meta(&"enemy_avatar") as AvatarBase
	if avatar != null and not merge(avatar, kind).is_empty():
		root.set_meta(&"mats", avatar.body_materials.duplicate())


## Merges `avatar`'s rig. Returns {} when nothing was merged, else {pieces, bones, surfaces, instances}.
static func merge(avatar: AvatarBase, kind: int) -> Dictionary:
	if not enabled or skip_kinds.has(kind):
		return {}
	var spec := avatar.rig_spec()
	var keep := {}
	for k in spec["keep"]:
		keep[k] = true
	var has_piece := {}
	for c in avatar.get_children():
		_mark(c, keep, has_piece)
	var bones: Array[Node3D] = []
	var parents := PackedInt32Array()
	var rels: Array[Transform3D] = []
	var pieces: Array = []
	for c in avatar.get_children():
		_walk(c, -1, Transform3D.IDENTITY, has_piece, keep, bones, parents, rels, pieces)
	if pieces.is_empty():
		return {}
	var sets: Array = spec["sets"]
	var body_ids := {}
	for m in avatar.body_materials:
		body_ids[m] = true
	# Group by (shadow setting, which per-instance parameter sets it is in), then by material.
	var groups := {}
	var firsts := {}  # group key -> its first piece (its per-instance values are copied)
	var canon := {}  # signature -> the surviving body material
	var replaced := {}  # a body material that was merged -> the surviving one
	for piece: Dictionary in pieces:
		var mi: MeshInstance3D = piece["node"]
		var mask := 0
		for si in sets.size():
			if (sets[si] as Array).has(mi):
				mask |= 1 << si
		var gkey := [mi.cast_shadow, mask]
		firsts[gkey] = firsts.get(gkey, mi)
		if not groups.has(gkey):
			groups[gkey] = {"mats": {}, "order": []}
		var g: Dictionary = groups[gkey]
		for s in mi.mesh.get_surface_count():
			var mat: Material = _surface_material(mi, s)
			var mkey: Variant = mat
			if body_ids.has(mat) and mat is StandardMaterial3D:
				var sig := _signature(mat as StandardMaterial3D)
				if not canon.has(sig):
					canon[sig] = mat
				replaced[mat] = canon[sig]
				mat = canon[sig]
				mkey = sig
			if not g["mats"].has(mkey):
				g["mats"][mkey] = {"mat": mat, "parts": []}
				g["order"].append(mkey)
			g["mats"][mkey]["parts"].append([mi, s, piece["bone"]])
	var rig := _build_skeleton(bones, parents)
	avatar.add_child(rig)
	rig.bind_nodes(bones)
	avatar.merged_rig = rig
	var entry := _meshes_for(avatar, kind, groups, pieces, rels, bones.size())
	var skin: Skin = entry["skin"]
	var built: Array = entry["meshes"]
	var surfaces := 0
	var instances := 0
	for gkey: Array in groups:
		var g: Dictionary = groups[gkey]
		var mesh: ArrayMesh = built[instances]
		var mats: Array[Material] = []
		for mkey in g["order"]:
			mats.append(g["mats"][mkey]["mat"])
		var mi := MeshInstance3D.new()
		mi.name = "Merged%d" % instances
		instances += 1
		mi.mesh = mesh
		for k in mats.size():
			mi.set_surface_override_material(k, mats[k])
		mi.cast_shadow = gkey[0]
		rig.add_child(mi)
		mi.skin = skin
		mi.skeleton = NodePath("..")
		mi.custom_aabb = mesh.get_aabb().grow(CULL_GROW)
		surfaces += mats.size()
		var first: MeshInstance3D = firsts[gkey]
		for pname in [EnemyLooks.HIT, EnemyLooks.GLOW]:
			var pv: Variant = first.get_instance_shader_parameter(pname)
			if pv != null:
				mi.set_instance_shader_parameter(pname, pv)
		for si in sets.size():
			if (gkey[1] as int) & (1 << si):
				(sets[si] as Array).append(mi)
	# The originals stop drawing (the node stays: the animation code writes its transform).
	for si in sets.size():
		var live: Array = sets[si]
		for piece: Dictionary in pieces:
			live.erase(piece["node"])
	for piece: Dictionary in pieces:
		var orig: MeshInstance3D = piece["node"]
		orig.set_meta(&"merged_mesh", orig.mesh)
		orig.mesh = null
	var mats: Array[StandardMaterial3D] = []
	for m in avatar.body_materials:
		var s: StandardMaterial3D = replaced.get(m, m)
		if not mats.has(s):
			mats.append(s)
	avatar.body_materials = mats
	var stats := {
		"pieces": pieces.size(),
		"bones": bones.size(),
		"surfaces": surfaces,
		"instances": groups.size(),
	}
	rig.set_meta(&"stats", stats)
	return stats


## The merged meshes and skin for this rig: the cached ones when the same kind of avatar was merged before into the same
## layout and the same geometry (a spawn then builds nothing), else built from the pieces' surfaces now.
static func _meshes_for(
	avatar: AvatarBase,
	kind: int,
	groups: Dictionary,
	pieces: Array,
	rels: Array[Transform3D],
	bone_count: int
) -> Dictionary:
	var layout := ""
	for gkey: Array in groups:
		var g: Dictionary = groups[gkey]
		layout += "|%s:" % [gkey]
		for mkey in g["order"]:
			layout += "["
			for part: Array in g["mats"][mkey]["parts"]:
				layout += "%d.%d," % [part[2], part[1]]
			layout += "]"
	var check := float(bone_count)
	for i in pieces.size():
		var mi: MeshInstance3D = pieces[i]["node"]
		check += mi.mesh.get_aabb().size.length() * 13.0
		if mi.mesh is ArrayMesh:
			for s in mi.mesh.get_surface_count():
				check += float((mi.mesh as ArrayMesh).surface_get_array_len(s)) * (1.0 + 0.001 * i)
	for r in rels:
		check += (
			r.origin.dot(Vector3(3.1, 5.3, 7.7))
			+ r.basis.x.dot(Vector3(1.0, 2.0, 3.0))
			+ r.basis.y.dot(Vector3(2.0, 3.0, 1.0))
			+ r.basis.z.dot(Vector3(3.0, 1.0, 2.0))
		)
	var ckey := "%s|%d" % [avatar.get_script().resource_path, kind]
	var entry: Dictionary = _cache.get(ckey, {})
	if (
		not entry.is_empty()
		and entry["layout"] == layout
		and is_equal_approx(entry["check"], check)
	):
		return entry
	var skin := Skin.new()
	for i in bone_count:
		skin.add_bind(i, rels[i].affine_inverse())
		skin.set_bind_bone(i, i)
	var built: Array[ArrayMesh] = []
	for gkey: Array in groups:
		var g: Dictionary = groups[gkey]
		var mesh := ArrayMesh.new()
		for mkey in g["order"]:
			var parts: Array = []
			for part: Array in g["mats"][mkey]["parts"]:
				var mi: MeshInstance3D = part[0]
				parts.append([mi.mesh.surface_get_arrays(part[1]), rels[part[2]], part[2]])
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _combine(parts))
		built.append(mesh)
	entry = {"layout": layout, "check": check, "meshes": built, "skin": skin}
	_cache[ckey] = entry
	return entry


static func _mark(n: Node, keep: Dictionary, has_piece: Dictionary) -> bool:
	var found := false
	for c in n.get_children():
		if _mark(c, keep, has_piece):
			found = true
	if n is Node3D and _mergeable(n, keep):
		found = true
	if found:
		has_piece[n] = true
	return found


static func _mergeable(n: Node, keep: Dictionary) -> bool:
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null or keep.has(mi) or mi.skin != null:
		return false
	if mi.material_overlay != null or mi.layers != 1 or mi.get_blend_shape_count() > 0:
		return false
	for s in mi.mesh.get_surface_count():
		if (
			mi.mesh is ArrayMesh
			and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES
		):
			return false
		var m := _surface_material(mi, s)
		if m == null or m.next_pass != null:
			return false
		# A see-through surface sorts by its own node: it keeps it.
		if (
			m is BaseMaterial3D
			and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		):
			return false
	return mi.mesh.get_surface_count() > 0


static func _surface_material(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var o := mi.get_surface_override_material(s)
	if o != null:
		return o
	return mi.mesh.surface_get_material(s)


static func _walk(
	n: Node,
	parent_bone: int,
	parent_rel: Transform3D,
	has_piece: Dictionary,
	keep: Dictionary,
	bones: Array[Node3D],
	parents: PackedInt32Array,
	rels: Array[Transform3D],
	pieces: Array
) -> void:
	if not has_piece.has(n):
		return
	var n3 := n as Node3D
	var rel := parent_rel * n3.transform
	var idx := bones.size()
	bones.append(n3)
	parents.append(parent_bone)
	rels.append(rel)
	if _mergeable(n, keep):
		pieces.append({"node": n, "bone": idx})
	for c in n.get_children():
		_walk(c, idx, rel, has_piece, keep, bones, parents, rels, pieces)


static func _build_skeleton(bones: Array[Node3D], parents: PackedInt32Array) -> MergedRig:
	var rig := MergedRig.new()
	rig.name = "MergedRig"
	for i in bones.size():
		rig.add_bone("b%d" % i)
	for i in bones.size():
		rig.set_bone_parent(i, parents[i])
		rig.set_bone_rest(i, bones[i].transform)
		rig.set_bone_pose(i, bones[i].transform)
	return rig


## A key for "the same body material": its look at merging (the flash and tints are applied to all alike).
static func _signature(m: StandardMaterial3D) -> String:
	return (
		"%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s"
		% [
			m.albedo_color,
			m.vertex_color_use_as_albedo,
			m.albedo_texture.get_instance_id() if m.albedo_texture != null else 0,
			m.roughness,
			m.metallic,
			m.cull_mode,
			m.transparency,
			m.shading_mode,
			m.emission_enabled,
			m.emission,
			m.emission_energy_multiplier,
		]
	)


## One surface's arrays from many pieces' [arrays, transform to the avatar's space, bone].
static func _combine(parts: Array) -> Array:
	var has_tan := false
	var has_col := false
	var has_uv := false
	var has_uv2 := false
	for p: Array in parts:
		var a: Array = p[0]
		has_tan = has_tan or a[Mesh.ARRAY_TANGENT] != null
		has_col = has_col or a[Mesh.ARRAY_COLOR] != null
		has_uv = has_uv or a[Mesh.ARRAY_TEX_UV] != null
		has_uv2 = has_uv2 or a[Mesh.ARRAY_TEX_UV2] != null
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bone_ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	for p: Array in parts:
		var a: Array = p[0]
		var xf: Transform3D = p[1]
		var bone: int = p[2]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var count := v.size()
		var base := verts.size()
		verts.append_array(xf * v)
		var nb := xf.basis.inverse().transposed()
		var flip := xf.basis.determinant() < 0.0
		var nr: Variant = a[Mesh.ARRAY_NORMAL]
		if nr != null:
			var nv := Transform3D(nb, Vector3.ZERO) * (nr as PackedVector3Array)
			if not _unit(nb):
				for k in nv.size():
					nv[k] = nv[k].normalized()
			norms.append_array(nv)
		else:
			var z := PackedVector3Array()
			z.resize(count)
			norms.append_array(z)
		if has_tan:
			var tg: Variant = a[Mesh.ARRAY_TANGENT]
			if tg != null:
				var src: PackedFloat32Array = tg
				for k in count:
					var t3 := (
						(xf.basis * Vector3(src[k * 4], src[k * 4 + 1], src[k * 4 + 2]))
						. normalized()
					)
					tans.append_array(
						[t3.x, t3.y, t3.z, -src[k * 4 + 3] if flip else src[k * 4 + 3]]
					)
			else:
				for k in count:
					tans.append_array([1.0, 0.0, 0.0, 1.0])
		if has_col:
			var cl: Variant = a[Mesh.ARRAY_COLOR]
			if cl != null:
				cols.append_array(cl as PackedColorArray)
			else:
				for k in count:
					cols.append(Color.WHITE)
		if has_uv:
			var u: Variant = a[Mesh.ARRAY_TEX_UV]
			if u != null:
				uvs.append_array(u as PackedVector2Array)
			else:
				var z2 := PackedVector2Array()
				z2.resize(count)
				uvs.append_array(z2)
		if has_uv2:
			var u2: Variant = a[Mesh.ARRAY_TEX_UV2]
			if u2 != null:
				uv2s.append_array(u2 as PackedVector2Array)
			else:
				var z3 := PackedVector2Array()
				z3.resize(count)
				uv2s.append_array(z3)
		var at := bone_ids.size()
		bone_ids.resize(at + count * 4)
		weights.resize(at + count * 4)
		for k in count:
			bone_ids[at + k * 4] = bone
			weights[at + k * 4] = 1.0
		var ix: Variant = a[Mesh.ARRAY_INDEX]
		if ix != null:
			var src_i: PackedInt32Array = ix
			var n_i := src_i.size()
			var at_i := index.size()
			index.resize(at_i + n_i)
			if flip:
				var t := 0
				while t < n_i:
					index[at_i + t] = src_i[t] + base
					index[at_i + t + 1] = src_i[t + 2] + base
					index[at_i + t + 2] = src_i[t + 1] + base
					t += 3
			else:
				for t in n_i:
					index[at_i + t] = src_i[t] + base
		else:
			var at_i := index.size()
			index.resize(at_i + count)
			if flip:
				var t := 0
				while t < count:
					index[at_i + t] = base + t
					index[at_i + t + 1] = base + t + 2
					index[at_i + t + 2] = base + t + 1
					t += 3
			else:
				for t in count:
					index[at_i + t] = base + t
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	if has_tan:
		out[Mesh.ARRAY_TANGENT] = tans
	if has_col:
		out[Mesh.ARRAY_COLOR] = cols
	if has_uv:
		out[Mesh.ARRAY_TEX_UV] = uvs
	if has_uv2:
		out[Mesh.ARRAY_TEX_UV2] = uv2s
	out[Mesh.ARRAY_BONES] = bone_ids
	out[Mesh.ARRAY_WEIGHTS] = weights
	out[Mesh.ARRAY_INDEX] = index
	return out


## Whether a normal matrix keeps lengths (so the transformed normals are already unit).
static func _unit(b: Basis) -> bool:
	var s := b.get_scale()
	return absf(s.x - 1.0) < 1e-4 and absf(s.y - 1.0) < 1e-4 and absf(s.z - 1.0) < 1e-4
