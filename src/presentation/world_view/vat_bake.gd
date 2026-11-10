class_name VatBake
extends RefCounted
## Bakes an enemy kind's
## pose code into a texture, so a VatCrowd can draw every enemy of that kind as one MultiMesh whose shader poses it.
## Nothing is recorded by hand: the bake builds the kind's real avatar (its real pieces) and runs its own pose code over
## a grid of the inputs the pose is made of. The bake is made once per rig and session (the first VAT enemy, or the
## shader warm-up behind the loading cover), so it can never go stale against the pose code.
##
## Any avatar can be baked. Its RIG says how
## (rig_of), a Dictionary:
## - "key": the bake's name (kinds that pose alike share one: the Charger and the Hatchling);
## - "drives": how many continuous numbers the pose is made of (each 0..1; a loop's a phase 0..1). The first four go to
##   the instance's INSTANCE_CUSTOM, the rest to a per-instance row of a small drive texture (VatCrowd);
## - "grids": per grid, its axes [[drive, samples, loops], ...] (1 to 3; multilinear in the shader, a loop wraps);
## - "joints": [{grid, parent (index or -1), frame (the node whose frame the joint's chain is, or null)}, ...], a
##   parent before its children. A joint is a transform relative to its parent, baked on its grid; a vertex is posed
##   by its joint's chain (joint after parent, any depth), as the scene tree composed the nodes;
## - "row": Callable(grid, drives: PackedFloat64Array) -> Array of Transform3D: that grid's joints (in joint order)
##   posed by the avatar's own code at those drives (the other drives 0);
## - "scaled": whether a joint scales (the normals then take the inverse transpose);
## - plus what the kind's crowd reads (a HordeAvatar's "period").
## The part of the pose that is a plain lift of the whole body (an idle bob, a rise-in's sink) is not baked: it is the
## avatar's vat_lift(), sent with the instance's transform (exact).
## A HordeAvatar's rig is horde_rig (the pilot's: its joints by kind, joint_spec; GRID_STANCE over the windup raise,
## the strike and the crouch, GRID_GAIT the legs' loop); any other avatar gives its own (vat_rig(): the Charger's).
##
## The texture (RGBA32F): row 0 the joint table (texel j: grid, slot, parent), row 1 the grid table (texel 2g: each
## axis's drive and the grid's first row; 2g + 1: each axis's samples and the loop mask), then each grid's rows (one per
## sample, the first axis fastest), three texels per joint slot (the 3x4 matrix's rows: basis row and origin). The
## mesh: every piece's surfaces merged into one surface in its joint's space, with per-vertex CUSTOM0 = albedo (linear)
## + mode (0 a body plate: the hit flash and rest glow; 1 an accent: the glow; 2 a plain plate: neither), CUSTOM1 =
## emission (linear; a plate's times its rest energy) + 0 (unused), CUSTOM2 = joint, one-sided (1: its back faces are
## not drawn, in a mesh that also has two-sided pieces), v0.10.5 W3-V4c: glow source (0: the instance's glow; k: drive
## k - 1), unshaded (1: VatLooks draws its albedo as is). the stand-alone kinds' StandardMaterial3D
## pieces take their looks from SoloVat.surface_look (with vertex colours where their material takes them). VatVerify
## (tests/support) runs the shader's arithmetic on the CPU (the bake report's pose error, the tests). Presentation only
## (EI-07).

const GRID_NONE := -1
const GRID_STANCE := 0
const GRID_GAIT := 1
## The pilot's stance grid's samples along the windup raise, the strike, the crouch. Starting values (the error
## report: scripts/checks/vat_bake_report.gd).
const STANCE_N := Vector3i(9, 9, 5)
## The pilot's gait loop's samples.
const GAIT_N := 48
## The rows before the grids' (the joint and grid tables).
const TABLE_ROWS := 2
## The deepest joint chain the shader follows.
const MAX_CHAIN := 32

## The baked poses by rig key, the rig key by kind, and the meshes by look (see pose_for, mesh_for).
static var _poses := {}
static var _kind_keys := {}
static var _meshes := {}


static func clear_cache() -> void:
	_poses.clear()
	_kind_keys.clear()
	_meshes.clear()


## The legs' loop (s) for horde `kind` (0: no gait).
static func gait_period(kind: int) -> float:
	if kind == WorldReader.KIND_SWARMER:
		return TAU / HordeAvatar.SWARMER_LEG_RATE
	return 0.0


## A reference avatar of horde `kind`, built with its pieces as ActorViews builds one (not in the tree; the caller
## frees it).
static func reference_avatar(kind: int, tint: Color, role_glow: float) -> HordeAvatar:
	var a := HordeAvatar.new()
	a.enemy_tint = tint
	a.role_glow = role_glow
	a.setup(kind)
	a.set_process(false)
	return a


## A reference avatar of any VAT `kind` (reference_avatar's, or a ChargerAvatar for the Charger and
## the Hatchling).
static func reference_of(kind: int, tint: Color, role_glow: float) -> AvatarBase:
	if SoloVat.is_solo(kind):  # The Needle, Warden, Arc Caster, Bomb Drone
		return SoloVat.reference_of(kind, tint, role_glow)
	if is_charger(kind):
		var c := ChargerAvatar.new()
		c.enemy_tint = tint
		c.role_glow = role_glow
		c.setup(kind)
		c.set_process(false)
		return c
	return reference_avatar(kind, tint, role_glow)


## A VAT avatar of `kind` (no pieces), as ActorViews builds one with the switch on (tools, tests; not
## in the tree; the caller frees it).
static func vat_avatar_of(kind: int) -> AvatarBase:
	if SoloVat.is_solo(kind):  # v0.10.5 W3-V4c
		return SoloVat.vat_avatar_of(kind)
	if is_charger(kind):
		var c := ChargerAvatar.new()
		c.vat = true
		c.setup(kind)
		return c
	var h := HordeAvatar.new()
	h.vat = true
	h.setup(kind)
	return h


## The kinds a ChargerAvatar draws.
static func is_charger(kind: int) -> bool:
	return kind == WorldReader.KIND_CHARGER or kind == WorldReader.KIND_HATCHLING


## The joints of horde `avatar` (built with its pieces): [[node, grid], ...] in bone order (a parent before its
## children).
static func joint_spec(avatar: HordeAvatar) -> Array:
	var out: Array = []
	match avatar.kind:
		WorldReader.KIND_SWARMER:
			out.append([avatar.body, GRID_STANCE])
			for k in 2:
				out.append([avatar.parts["mandible%d" % k], GRID_STANCE])
			for k in 6:
				out.append([avatar.parts["leg%d" % k], GRID_GAIT])
	return out


## The rig of `avatar` (see the class notes): its own (vat_rig()), or a HordeAvatar's (horde_rig).
static func rig_of(avatar: Node3D) -> Dictionary:
	if avatar.has_method(&"vat_rig"):
		return avatar.call(&"vat_rig")
	if avatar is HordeAvatar:
		return horde_rig(avatar)
	return {}


## The pilot's rig for horde `avatar`: its joint_spec joints (each parented to the nearest joint above it) on the
## stance grid (drives 0, 1, 2: the windup raise, the strike, the crouch; at the clock 0, fully risen) and the gait
## grid (drive 3: the legs' phase over gait_period), each read from its nodes after HordeAvatar.pose_at.
static func horde_rig(avatar: HordeAvatar) -> Dictionary:
	if avatar.kind != WorldReader.KIND_SWARMER:  # The other horde kinds' (HordeVat)
		return HordeVat.rig(avatar)
	var js: Array = []
	var index := {}
	for j: Array in joint_spec(avatar):
		var node: Node3D = j[0]
		var parent := -1
		var up := node.get_parent()
		while up != null and up != avatar:
			if index.has(up):
				parent = index[up]
				break
			up = up.get_parent()
		index[node] = js.size()
		js.append({"grid": j[1], "parent": parent, "frame": node})
	return {
		"key": "horde%d" % avatar.kind,
		"drives": 4,
		"grids":
		[
			[[0, STANCE_N.x, false], [1, STANCE_N.y, false], [2, STANCE_N.z, false]],
			[[3, GAIT_N, true]],
		],
		"joints": js,
		"row": func(g: int, d: PackedFloat64Array) -> Array: return _horde_row(avatar, js, g, d),
		"scaled": false,
		"period": gait_period(avatar.kind),
	}


static func _horde_row(avatar: HordeAvatar, js: Array, g: int, d: PackedFloat64Array) -> Array:
	avatar.pose_at(d[0], d[1], d[2], gait_period(avatar.kind) * d[3], 1.0)
	var out: Array = []
	for j: Dictionary in js:
		if j["grid"] == g:
			out.append(local_of(avatar, js, j))
	return out


## The joint table of `avatar`'s rig: [{grid, slot, parent, frame, node}, ...] (node: the frame, the pilot's name).
static func joints(avatar: Node3D) -> Array:
	return _slotted(rig_of(avatar))


static func _slotted(rig: Dictionary) -> Array:
	var out: Array = []
	var slots := {}
	for j: Dictionary in rig.get("joints", []):
		var g: int = j["grid"]
		var e := j.duplicate()
		e["slot"] = slots.get(g, 0)
		e["node"] = j["frame"]
		slots[g] = int(e["slot"]) + 1
		out.append(e)
	return out


## The baked poses of `kind`: {texture (ImageTexture), image, data (its floats), width, joints, grids, drives,
## drive_texels, scaled, key}, and for a horde kind the pilot's stance / gait / gait_row / period.
static func pose_for(kind: int) -> Dictionary:
	if _kind_keys.has(kind) and _poses.has(_kind_keys[kind]):
		return _poses[_kind_keys[kind]]
	var a := reference_of(kind, Color(0, 0, 0, 0), 0.0)
	var key: String = rig_of(a).get("key", "kind%d" % kind)
	if not _poses.has(key):
		_poses[key] = bake(a)
	a.free()
	_kind_keys[kind] = key
	return _poses[key]


## Bakes `avatar`'s pose code (see the class notes) over its rig's grids. The avatar is posed and left posed; reduced
## motion is ignored (what it changes is in the drives or the lift, not in what a grid bakes).
static func bake(avatar: Node3D) -> Dictionary:
	var rig := rig_of(avatar)
	var js := _slotted(rig)
	var grids: Array = rig["grids"]
	var n_drives: int = rig["drives"]
	var slots: Array[int] = []
	slots.resize(grids.size())
	for j: Dictionary in js:
		slots[j["grid"]] = maxi(slots[j["grid"]], int(j["slot"]) + 1)
	var table: Array = []  # per grid: {axes, n (Vector3i), loops, row0, rows}
	var row := TABLE_ROWS
	var width := maxi(js.size(), grids.size() * 2)
	for g in grids.size():
		var axes: Array = grids[g]
		var n := Vector3i.ONE
		var loops := 0
		for a in axes.size():
			n[a] = int(axes[a][1])
			if bool(axes[a][2]):
				loops |= 1 << a
		var rows := n.x * n.y * n.z if slots[g] > 0 else 0
		table.append({"axes": axes, "n": n, "loops": loops, "row0": row, "rows": rows})
		row += rows
		width = maxi(width, slots[g] * 3)
	var height := maxi(row, TABLE_ROWS + 1)
	var data := PackedFloat32Array()
	data.resize(width * height * 4)
	for i in js.size():
		var j: Dictionary = js[i]
		_put(data, width, i, 0, Vector4(j["grid"], j["slot"], j["parent"], 0))
	for g in grids.size():
		var t: Dictionary = table[g]
		var axes: Array = t["axes"]
		var di := Vector3(-1, -1, -1)
		for a in axes.size():
			di[a] = int(axes[a][0])
		var n: Vector3i = t["n"]
		_put(data, width, g * 2, 1, Vector4(di.x, di.y, di.z, t["row0"]))
		_put(data, width, g * 2 + 1, 1, Vector4(n.x, n.y, n.z, t["loops"]))
	var row_of: Callable = rig["row"]
	var d := PackedFloat64Array()
	d.resize(maxi(n_drives, 4))
	for g in grids.size():
		var t: Dictionary = table[g]
		if int(t["rows"]) == 0:
			continue
		var axes: Array = t["axes"]
		var n: Vector3i = t["n"]
		for iz in n.z:
			for iy in n.y:
				for ix in n.x:
					var at := Vector3i(ix, iy, iz)
					for a in axes.size():
						var na: int = n[a]
						d[int(axes[a][0])] = (
							float(at[a]) / float(na)
							if bool(axes[a][2])
							else float(at[a]) / float(na - 1)
						)
					var xfs: Array = row_of.call(g, d)
					var r := int(t["row0"]) + ix + n.x * (iy + n.y * iz)
					for s in xfs.size():
						_write(data, width, s, r, xfs[s])
		for a in axes.size():
			d[int(axes[a][0])] = 0.0
	var img := Image.create_from_data(
		width, height, false, Image.FORMAT_RGBAF, data.to_byte_array()
	)
	var out := {
		"texture": ImageTexture.create_from_image(img),
		"image": img,
		"data": data,
		"width": width,
		"joints": js,
		"grids": table,
		"drives": n_drives,
		"drive_texels": maxi(0, ceili((n_drives - 4) / 4.0)),
		"scaled": bool(rig.get("scaled", false)),
		"key": rig.get("key", ""),
	}
	if rig.has("albedo_tex"):  # The owner's model's colour map (VatLooks' textured variant)
		out["albedo_tex"] = rig["albedo_tex"]
	if rig.has("period"):  # the pilot's (VatCrowd's horde drives, tests)
		var gait: Dictionary = table[GRID_GAIT]
		out["period"] = rig["period"]
		out["stance"] = STANCE_N
		out["gait"] = GAIT_N if int(gait["rows"]) > 0 else 0
		out["gait_row"] = gait["row0"]
	return out


static func _put(data: PackedFloat32Array, width: int, x: int, y: int, v: Vector4) -> void:
	var o := (y * width + x) * 4
	data[o] = v.x
	data[o + 1] = v.y
	data[o + 2] = v.z
	data[o + 3] = v.w


## Joint `j`'s transform now, relative to its parent joint (or the avatar): the chain of node transforms between.
static func local_of(avatar: Node3D, js: Array, j: Dictionary) -> Transform3D:
	var stop: Node = avatar if j["parent"] < 0 else (js[j["parent"]] as Dictionary)["frame"]
	var xf := Transform3D.IDENTITY
	var n: Node = j["frame"]
	while n != stop and n != null:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _write(
	data: PackedFloat32Array, width: int, slot: int, row: int, xf: Transform3D
) -> void:
	var b := xf.basis
	for r in 3:
		_put(data, width, slot * 3 + r, row, Vector4(b.x[r], b.y[r], b.z[r], xf.origin[r]))


## The merged body of `kind` in this look (the biome's cast `tint`, the role glow; `outline`, the biome's outline
## colour, only keeps each biome's cache entry its own): an ArrayMesh (one surface, see the class notes; meta
## "two_sided": some piece is drawn from both sides), cached by look.
static func mesh_for(kind: int, tint: Color, role_glow: float, outline: Color) -> ArrayMesh:
	var key := look_key(kind, tint, role_glow, outline)
	if _meshes.has(key):
		return _meshes[key]
	var a := reference_of(kind, tint, role_glow)
	var mesh := build_mesh(a)
	a.free()
	_meshes[key] = mesh
	return mesh


## The key of a look (what changes the merged mesh's colours).
static func look_key(kind: int, tint: Color, role_glow: float, outline: Color) -> String:
	var cols := PackedStringArray()
	for slot: StringName in [&"body", &"trim", &"grey", &"eye"]:
		cols.append(EnemyPalettes.color(kind, slot).to_html())
	return (
		"%d|%s|%.4f|%s|%s"
		% [
			kind,
			tint.to_html(),
			role_glow,
			outline.to_html(),
			",".join(cols),
		]
	)


## The pieces of `avatar` in merge order: [{node, surface, joint (index or -1), xf (the piece in its joint's space)}];
## a piece hangs in the nearest joint frame at or above it.
static func pieces(avatar: Node3D, js: Array) -> Array:
	var index := {}
	for i in js.size():
		var f: Variant = (js[i] as Dictionary)["frame"]
		if f != null:
			index[f] = i
	var out: Array = []
	_collect(avatar, avatar, index, out)
	return out


static func _collect(n: Node, avatar: Node, index: Dictionary, out: Array) -> void:
	for c in n.get_children():
		if c.has_meta(SoloVat.LIVE):  # A node the VAT avatar keeps (a ground disc, the dust)
			continue
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			var xf := Transform3D.IDENTITY
			var up: Node = mi
			while up != avatar and not index.has(up):
				xf = (up as Node3D).transform * xf
				up = up.get_parent()
			for s in mi.mesh.get_surface_count():
				out.append({"node": mi, "surface": s, "joint": index.get(up, -1), "xf": xf})
		_collect(c, avatar, index, out)


## The merged mesh of `avatar` (built with its pieces).
static func build_mesh(avatar: Node3D) -> ArrayMesh:
	var js := joints(avatar)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var index := PackedInt32Array()
	var ps := pieces(avatar, js)
	var looks: Array = []
	var any_two := false
	var textured := HordeVat.texture(avatar) != null  # UVs too
	var uvs := PackedVector2Array()
	for p: Dictionary in ps:
		var look := surface_look(p["node"], p["surface"])
		if HordeVat.alt_glow(avatar, p["node"]):  # The Sniper's muzzle (VatLooks' mode 3)
			(look[0] as Array)[3] = 3.0
		looks.append(look)
		any_two = any_two or bool(look[2])
	for i in ps.size():
		var p: Dictionary = ps[i]
		var mi: MeshInstance3D = p["node"]
		var s: int = p["surface"]
		var look: Array = looks[i]
		var l0 := PackedFloat32Array(look[0])
		var l1 := PackedFloat32Array(look[1])
		var arrays := mi.mesh.surface_get_arrays(s)
		var xf: Transform3D = p["xf"]
		var nb := xf.basis.inverse().transposed()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if textured:
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			if uv is PackedVector2Array and (uv as PackedVector2Array).size() == v.size():
				uvs.append_array(uv)
			else:
				var zero := PackedVector2Array()
				zero.resize(v.size())
				uvs.append_array(zero)
		var nr: Variant = arrays[Mesh.ARRAY_NORMAL]
		var base := verts.size()
		# An accent's glow source (0: the instance's; k: drive k - 1) and the unshaded flag
		var jp := PackedFloat32Array(
			[
				float(p["joint"]),
				1.0 if any_two and not bool(look[2]) else 0.0,
				float(look[3]) if look.size() > 3 else 0.0,
				float(look[4]) if look.size() > 4 else 0.0,
			]
		)
		# A material taking its mesh's vertex colours as albedo (the Warden's facets): albedo x colour
		var vc: Variant = arrays[Mesh.ARRAY_COLOR] if look.size() > 5 and bool(look[5]) else null
		var has_vc := vc is PackedColorArray and (vc as PackedColorArray).size() == v.size()
		for k in v.size():
			verts.append(xf * v[k])
			var n := Vector3.UP
			if nr is PackedVector3Array and (nr as PackedVector3Array).size() == v.size():
				n = (nb * (nr as PackedVector3Array)[k]).normalized()
			norms.append(n)
			if has_vc:
				var col: Color = (vc as PackedColorArray)[k]
				c0.append_array([l0[0] * col.r, l0[1] * col.g, l0[2] * col.b, l0[3]])
			else:
				c0.append_array(l0)
			c1.append_array(l1)
			c2.append_array(jp)
		var ix: Variant = arrays[Mesh.ARRAY_INDEX]
		var flip := xf.basis.determinant() < 0.0
		if ix is PackedInt32Array and not (ix as PackedInt32Array).is_empty():
			var src: PackedInt32Array = ix
			var t := 0
			while t + 2 < src.size():
				index.append_array(
					(
						[base + src[t], base + src[t + 2], base + src[t + 1]]
						if flip
						else [base + src[t], base + src[t + 1], base + src[t + 2]]
					)
				)
				t += 3
		else:
			var t := 0
			while t + 2 < v.size():
				index.append_array(
					(
						[base + t, base + t + 2, base + t + 1]
						if flip
						else [base + t, base + t + 1, base + t + 2]
					)
				)
				t += 3
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_CUSTOM0] = c0
	out[Mesh.ARRAY_CUSTOM1] = c1
	out[Mesh.ARRAY_CUSTOM2] = c2
	out[Mesh.ARRAY_INDEX] = index
	if textured:
		out[Mesh.ARRAY_TEX_UV] = uvs
	var flags := (
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, flags)
	mesh.set_meta(&"two_sided", any_two)
	return mesh


## A piece surface's look: [albedo (linear) rgb + mode, emission (linear) rgb + 0, two-sided], read from its
## EnemyLooks material (a body plate: zd_hit; an accent: zd_glow), or (the Charger's face) a plain
## untextured StandardMaterial3D: its albedo, no emission, no flash. A material of any other kind is drawn as a dark
## plate and reported (the kind is then not VAT-ready).
static func surface_look(mi: MeshInstance3D, s: int) -> Array:
	var std := mi.material_override as StandardMaterial3D
	if std == null:
		std = mi.get_surface_override_material(s) as StandardMaterial3D
	if (
		std != null
		and std.has_meta(SoloVat.LOOK)
		and (std.albedo_texture == null or std.has_meta(&"enemy_tex"))
	):
		return SoloVat.surface_look(std)
	if std != null and std.albedo_texture == null and not std.emission_enabled:
		var c := std.albedo_color.srgb_to_linear()
		return [
			[c.r, c.g, c.b, 2.0],
			[0.0, 0.0, 0.0, 0.0],
			std.cull_mode == BaseMaterial3D.CULL_DISABLED
		]
	var m := mi.material_override as ShaderMaterial
	if m == null:
		m = mi.get_surface_override_material(s) as ShaderMaterial
	if m == null or m.shader == null:
		push_error("VatBake: %s has no EnemyLooks material" % mi.get_path())
		return [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0], false]
	var code := m.shader.code  # (a textured plate's map is the pose's albedo_tex, VatLooks)
	var albedo: Color = m.get_shader_parameter("albedo")
	var emission: Color = m.get_shader_parameter("emission")
	var energy := float(m.get_shader_parameter("emission_energy"))
	var accent := code.contains(EnemyLooks.GLOW)
	var a := albedo.srgb_to_linear()
	var e := emission.srgb_to_linear()
	var k := 1.0 if accent else energy
	return [
		[a.r, a.g, a.b, 1.0 if accent else 0.0],
		[e.r * k, e.g * k, e.b * k, 0.0],
		code.contains("cull_disabled"),
	]


## The gait phase (0..1) the crowd sends for a horde avatar at clock `t`.
static func gait_phase(pose: Dictionary, t: float) -> float:
	var period: float = pose.get("period", 0.0)
	if period <= 0.0:
		return 0.0
	var u: float = t / period
	return u - floor(u)


## The drives VatCrowd sends for `avatar` now: its own (vat_drives()), or a horde avatar's four (the
## windup raise, the strike, the crouch, the gait phase).
static func drives_of(avatar: Node3D, pose: Dictionary) -> PackedFloat32Array:
	if avatar.has_method(&"vat_drives"):
		return avatar.call(&"vat_drives")
	var h := avatar as HordeAvatar
	if h.kind != WorldReader.KIND_SWARMER:  # The other horde kinds' (HordeVat)
		return h.vat_grid_drives()
	return PackedFloat32Array(
		[
			clampf(h.windup_pose(), 0.0, 1.0),
			clampf(h.strike_pose(), 0.0, 1.0),
			clampf(h.crouch_amount(), 0.0, 1.0),
			gait_phase(pose, h.anim_time()),
		]
	)
