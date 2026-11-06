class_name VatBake
extends RefCounted
## v0.10.5 W3-V1 (owner, 2026-11-06: the enemy VAT pilot, "keeping their current animation"): bakes a horde kind's
## pose code into a texture, so a VatCrowd can draw every enemy of that kind as one MultiMesh whose shader poses it.
## Nothing is recorded by hand: the bake builds the kind's real avatar (HordeAvatar, its real pieces) and runs its own
## _pose() (HordeAvatar.pose_at) over a grid of the inputs the pose is made of. The bake is made once per kind and
## session (the first VAT enemy, or the shader warm-up behind the loading cover), so it can never go stale against
## the pose code.
##
## What is baked: each joint's local transform (a Node3D the pose moves: the body, a hinge, a hip), relative to the
## joint above it, not per vertex: the body is rigid pieces on a few joints, so a few matrices per pose carry it all,
## and the shader composes them (joint after parent) as the scene tree did. Two grids:
## - "stance" (GRID_STANCE): a 3D grid over the windup raise, the strike swing and the windup crouch (0..1 each,
##   STANCE_N samples), at the clock 0 (no bob) and fully risen; trilinear in the shader;
## - "gait" (GRID_GAIT): one loop of the legs over their period (GAIT_N samples), linear and wrapped in the shader.
## The rest of the body's pose is a lift of the whole body (the idle bob and the rise-in's sink,
## HordeAvatar.vat_lift): the crowd moves the instance by it (exact: the body is the root joint, the lift a pure
## translation in its parent's frame).
##
## The texture (RGBA32F): one row per pose (the stance rows, then the gait rows), three texels per joint (the 3x4
## matrix's rows: basis row and origin). The mesh: every piece's surfaces merged into one surface in its joint's space,
## with per-vertex CUSTOM0 = albedo (linear) + mode (0 a body plate: the hit flash and rest glow; 1 an accent: the
## glow), CUSTOM1 = emission (linear; a plate's times its rest energy) + outline flag, CUSTOM2 = joint slot, joint
## grid, parent slot, parent grid (-1: none). eval_* run the shader's arithmetic on the CPU (the bake report's pose
## error, the tests). Presentation only (EI-07).

const GRID_NONE := -1
const GRID_STANCE := 0
const GRID_GAIT := 1
## The stance grid's samples along the windup raise, the strike, the crouch. Starting values (the error report:
## scripts/checks/vat_bake_report.gd).
const STANCE_N := Vector3i(9, 9, 5)
## The gait loop's samples.
const GAIT_N := 48

## The baked poses by kind (see pose_for) and the meshes by look (see mesh_for).
static var _poses := {}
static var _meshes := {}


static func clear_cache() -> void:
	_poses.clear()
	_meshes.clear()


## The legs' loop (s) for `kind` (0: no gait).
static func gait_period(kind: int) -> float:
	if kind == WorldReader.KIND_SWARMER:
		return TAU / HordeAvatar.SWARMER_LEG_RATE
	return 0.0


## A reference avatar of `kind`, built with its pieces as ActorViews builds one (not in the tree; the caller frees it).
static func reference_avatar(
	kind: int, tint: Color, role_glow: float, outline: Color
) -> HordeAvatar:
	var a := HordeAvatar.new()
	a.enemy_tint = tint
	a.role_glow = role_glow
	a.setup(kind, outline, &"outline")
	a.set_process(false)
	return a


## The joints of `avatar` (built with its pieces): [[node, grid], ...] in bone order (a parent before its children).
static func joint_spec(avatar: HordeAvatar) -> Array:
	var out: Array = HordeVat.joint_spec(avatar)  # v0.10.5 W3-V4b: the other horde kinds declare theirs
	if not out.is_empty():
		return out
	match avatar.kind:
		WorldReader.KIND_SWARMER:
			out.append([avatar.body, GRID_STANCE])
			for k in 2:
				out.append([avatar.parts["mandible%d" % k], GRID_STANCE])
			for k in 6:
				out.append([avatar.parts["leg%d" % k], GRID_GAIT])
	return out


## The joint table of `avatar`: [{node, grid, slot, parent (index or -1)}, ...].
static func joints(avatar: HordeAvatar) -> Array:
	var spec := joint_spec(avatar)
	var out: Array = []
	var slots := {GRID_NONE: 0, GRID_STANCE: 0, GRID_GAIT: 0}
	var index := {}
	for j: Array in spec:
		var node: Node3D = j[0]
		var grid: int = j[1]
		var parent := -1
		var up := node.get_parent()
		while up != null and up != avatar:
			if index.has(up):
				parent = index[up]
				break
			up = up.get_parent()
		index[node] = out.size()
		out.append({"node": node, "grid": grid, "slot": slots[grid], "parent": parent})
		slots[grid] += 1
	return out


## The baked poses of `kind`: {texture (ImageTexture), image, stance (Vector3i), gait (int), gait_row (int), period}.
static func pose_for(kind: int) -> Dictionary:
	if _poses.has(kind):
		return _poses[kind]
	var a := reference_avatar(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var entry := bake(a)
	a.free()
	_poses[kind] = entry
	return entry


## Bakes `avatar`'s pose code (see the class notes). The avatar is posed and left posed; reduced motion is ignored
## (the bake is at the clock 0, no bob, and the legs' swing has no calm variant).
static func bake(avatar: HordeAvatar) -> Dictionary:
	var js := joints(avatar)
	var n_stance := 0
	var n_gait := 0
	for j: Dictionary in js:
		if j["grid"] == GRID_STANCE:
			n_stance += 1
		elif j["grid"] == GRID_GAIT:
			n_gait += 1
	# v0.10.5 W3-V4b: each kind's own grids (HordeVat.grids; the Swarmer's: STANCE_N, GAIT_N) and its own
	# pose over them (vat_bake_pose; the Swarmer's: pose_at, as before).
	var grids := HordeVat.grids(avatar.kind)
	var sn: Vector3i = grids[0]
	var rows_stance := sn.x * sn.y * sn.z
	var gait_n: int = grids[1] if n_gait > 0 else 0
	var period := gait_period(avatar.kind)
	var img := Image.create_empty(
		maxi(maxi(n_stance, n_gait), 1) * 3,
		rows_stance + maxi(gait_n, 1),
		false,
		Image.FORMAT_RGBAF
	)
	for ic in sn.z:
		for i_s in sn.y:
			for iw in sn.x:
				avatar.vat_bake_pose(
					Vector3(
						float(iw) / float(sn.x - 1),
						float(i_s) / float(sn.y - 1),
						float(ic) / float(sn.z - 1)
					),
					0.0
				)
				var row := iw + sn.x * (i_s + sn.y * ic)
				for j: Dictionary in js:
					if j["grid"] == GRID_STANCE:
						_write(img, j["slot"], row, local_of(avatar, js, j))
	for it in gait_n:
		avatar.vat_bake_pose(Vector3.ZERO, float(it) / float(gait_n))
		for j: Dictionary in js:
			if j["grid"] == GRID_GAIT:
				_write(img, j["slot"], rows_stance + it, local_of(avatar, js, j))
	var out := {
		"texture": ImageTexture.create_from_image(img),
		"image": img,
		"stance": sn,
		"gait": gait_n,
		"gait_row": rows_stance,
		"period": period,
	}
	var tex := HordeVat.texture(avatar)  # v0.10.5 W3-V4b: the owner's model's colour map (VatLooks samples it)
	if tex != null:
		out["albedo_tex"] = tex
	return out


## Joint `j`'s transform now, relative to its parent joint (or the avatar): the chain of node transforms between.
## v0.10.5 W3-V4b: a hidden joint (the Mine Layer's mine once dropped) is folded to a point (a zero basis), so its
## triangles draw nothing.
static func local_of(avatar: Node3D, js: Array, j: Dictionary) -> Transform3D:
	var stop: Node = avatar if j["parent"] < 0 else (js[j["parent"]] as Dictionary)["node"]
	var xf := Transform3D.IDENTITY
	var n: Node = j["node"]
	var hidden := not (n as Node3D).visible
	while n != stop and n != null:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	if hidden:
		xf.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	return xf


static func _write(img: Image, slot: int, row: int, xf: Transform3D) -> void:
	var b := xf.basis
	for r in 3:
		img.set_pixel(slot * 3 + r, row, Color(b.x[r], b.y[r], b.z[r], xf.origin[r]))


## The merged body of `kind` in this look (the biome's cast `tint`, the role glow, the outline colour): an ArrayMesh
## (one surface, see the class notes), cached by look.
static func mesh_for(kind: int, tint: Color, role_glow: float, outline: Color) -> ArrayMesh:
	var key := look_key(kind, tint, role_glow, outline)
	if _meshes.has(key):
		return _meshes[key]
	var a := reference_avatar(kind, tint, role_glow, outline)
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
		"%d|%s|%.4f|%s|%s|%d"
		% [
			kind,
			tint.to_html(),
			role_glow,
			outline.to_html(),
			",".join(cols),
			int(ActorLooks.OUTLINES)
		]
	)


## The pieces of `avatar` in merge order: [{node, surface, joint (index or -1), xf (the piece in its joint's space)}].
static func pieces(avatar: HordeAvatar, js: Array) -> Array:
	var index := {}
	for i in js.size():
		index[(js[i] as Dictionary)["node"]] = i
	var out: Array = []
	_collect(avatar, avatar, index, out)
	return out


static func _collect(n: Node, avatar: Node, index: Dictionary, out: Array) -> void:
	for c in n.get_children():
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
static func build_mesh(avatar: HordeAvatar) -> ArrayMesh:
	var js := joints(avatar)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var index := PackedInt32Array()
	var textured := HordeVat.texture(avatar) != null  # v0.10.5 W3-V4b: the owner's model's UVs too
	var uvs := PackedVector2Array()
	for p: Dictionary in pieces(avatar, js):
		var mi: MeshInstance3D = p["node"]
		var s: int = p["surface"]
		var look := surface_look(mi, s)
		var l0 := PackedFloat32Array(look[0])
		var l1 := PackedFloat32Array(look[1])
		if HordeVat.alt_glow(avatar, mi):  # v0.10.5 W3-V4b: the Sniper's muzzle (mode 2: VatLooks' second glow)
			l0[3] = 2.0
		var arrays := mi.mesh.surface_get_arrays(s)
		if textured:
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var nv: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if uv is PackedVector2Array and (uv as PackedVector2Array).size() == nv:
				uvs.append_array(uv)
			else:
				var zero := PackedVector2Array()
				zero.resize(nv)
				uvs.append_array(zero)
		var xf: Transform3D = p["xf"]
		var nb := xf.basis.inverse().transposed()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nr: Variant = arrays[Mesh.ARRAY_NORMAL]
		var base := verts.size()
		var j: int = p["joint"]
		var jd: Dictionary = js[j] if j >= 0 else {}
		var pd: Dictionary = js[jd["parent"]] if j >= 0 and jd["parent"] >= 0 else {}
		var jp := PackedFloat32Array(
			[
				float(jd.get("slot", 0)),
				float(jd.get("grid", GRID_NONE)),
				float(pd.get("slot", -1)),
				float(pd.get("grid", GRID_NONE)),
			]
		)
		for k in v.size():
			verts.append(xf * v[k])
			var n := Vector3.UP
			if nr is PackedVector3Array and (nr as PackedVector3Array).size() == v.size():
				n = (nb * (nr as PackedVector3Array)[k]).normalized()
			norms.append(n)
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
	return mesh


## A piece surface's look as two per-vertex vec4s: [albedo (linear) rgb + mode, emission (linear) rgb + outline],
## read from its EnemyLooks material (a body plate: zd_hit; an accent: zd_glow). A material of any other kind is drawn
## as a dark plate and reported (the kind is then not VAT-ready).
static func surface_look(mi: MeshInstance3D, s: int) -> Array:
	var m := mi.material_override as ShaderMaterial
	if m == null:
		m = mi.get_surface_override_material(s) as ShaderMaterial
	if m == null or m.shader == null:
		push_error("VatBake: %s has no EnemyLooks material" % mi.get_path())
		return [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]
	var code := m.shader.code  # (v0.10.5 W3-V4b: a textured plate's map is the pose's albedo_tex, VatLooks)
	var albedo: Color = m.get_shader_parameter("albedo")
	var emission: Color = m.get_shader_parameter("emission")
	var energy := float(m.get_shader_parameter("emission_energy"))
	var accent := code.contains(EnemyLooks.GLOW)
	var a := albedo.srgb_to_linear()
	var e := emission.srgb_to_linear()
	var k := 1.0 if accent else energy
	var outline := 1.0 if m.next_pass != null else 0.0
	return [[a.r, a.g, a.b, 1.0 if accent else 0.0], [e.r * k, e.g * k, e.b * k, outline]]


# --- the shader's arithmetic on the CPU (the bake report, tests) -------------------------------------------------


## Joint (`slot`, `grid`)'s baked local transform at the drives `d` (wind, strike, crouch, gait phase 0..1), as the
## shader samples it (VatLooks: trilinear over the stance grid, linear and wrapped over the gait).
static func eval_local(pose: Dictionary, slot: int, grid: int, d: Vector4) -> Transform3D:
	if grid == GRID_NONE:
		return Transform3D.IDENTITY
	var img: Image = pose["image"]
	var rows: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	if grid == GRID_STANCE:
		var n: Vector3i = pose["stance"]
		var g := Vector3(
			clampf(d.x, 0.0, 1.0) * (n.x - 1),
			clampf(d.y, 0.0, 1.0) * (n.y - 1),
			clampf(d.z, 0.0, 1.0) * (n.z - 1)
		)
		var i0 := Vector3i(
			mini(int(floor(g.x)), n.x - 2),
			mini(int(floor(g.y)), n.y - 2),
			mini(int(floor(g.z)), n.z - 2)
		)
		var f := g - Vector3(i0)
		for c in 8:
			var o := Vector3i(c & 1, (c >> 1) & 1, (c >> 2) & 1)
			var w := (
				(f.x if o.x == 1 else 1.0 - f.x)
				* (f.y if o.y == 1 else 1.0 - f.y)
				* (f.z if o.z == 1 else 1.0 - f.z)
			)
			var ix := i0 + o
			_add_rows(rows, img, slot, ix.x + n.x * (ix.y + n.y * ix.z), w)
	else:
		var nt: int = pose["gait"]
		var u: float = (d.w - floor(d.w)) * nt
		var i0 := int(floor(u)) % nt
		var f: float = u - floor(u)
		_add_rows(rows, img, slot, int(pose["gait_row"]) + i0, 1.0 - f)
		_add_rows(rows, img, slot, int(pose["gait_row"]) + (i0 + 1) % nt, f)
	return Transform3D(
		Basis(
			Vector3(rows[0].x, rows[1].x, rows[2].x),
			Vector3(rows[0].y, rows[1].y, rows[2].y),
			Vector3(rows[0].z, rows[1].z, rows[2].z)
		),
		Vector3(rows[0].w, rows[1].w, rows[2].w)
	)


static func _add_rows(rows: Array[Vector4], img: Image, slot: int, row: int, w: float) -> void:
	if w == 0.0:
		return
	for r in 3:
		var c := img.get_pixel(slot * 3 + r, row)
		rows[r] += Vector4(c.r, c.g, c.b, c.a) * w


## The gait phase (0..1) the crowd sends for an avatar at clock `t`.
static func gait_phase(pose: Dictionary, t: float) -> float:
	var period: float = pose["period"]
	if period <= 0.0:
		return 0.0
	var u: float = t / period
	return u - floor(u)


## Every vertex of `mesh` (build_mesh's) in the avatar's space at the drives `d` and the lift, as the shader poses it.
static func eval_vertices(
	pose: Dictionary, mesh: ArrayMesh, d: Vector4, lift: float
) -> PackedVector3Array:
	return eval_vertices_at(pose, mesh, d, Transform3D(Basis.IDENTITY, Vector3(0, lift, 0)))


## v0.10.5 W3-V4b: eval_vertices with the body's whole instance transform `offset` (HordeAvatar.vat_offset) for the
## lift.
static func eval_vertices_at(
	pose: Dictionary, mesh: ArrayMesh, d: Vector4, offset: Transform3D
) -> PackedVector3Array:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c2: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM2]
	var out := PackedVector3Array()
	out.resize(v.size())
	var cache := {}
	for k in v.size():
		var key := Vector4i(
			int(c2[k * 4]), int(c2[k * 4 + 1]), int(c2[k * 4 + 2]), int(c2[k * 4 + 3])
		)
		if not cache.has(key):
			var m := eval_local(pose, key.x, key.y, d)
			if key.z >= 0:
				m = eval_local(pose, key.z, key.w, d) * m
			cache[key] = offset * m
		out[k] = (cache[key] as Transform3D) * v[k]
	return out


## Every piece vertex of `avatar` (posed, with its pieces) in its own space, in build_mesh's order.
static func live_vertices(avatar: HordeAvatar) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Dictionary in pieces(avatar, joints(avatar)):
		var mi: MeshInstance3D = p["node"]
		var xf := Transform3D.IDENTITY
		var up: Node = mi
		while up != avatar:
			xf = (up as Node3D).transform * xf
			up = up.get_parent()
		var v: PackedVector3Array = mi.mesh.surface_get_arrays(p["surface"])[Mesh.ARRAY_VERTEX]
		out.append_array(xf * v)
	return out


## The largest distance (m) between `live`'s and the VAT avatar `vat`'s pose over `samples` random drive sets (the
## windup raise, the strike, the crouch, the clock up to `t_max` s, the rise-in), each posed by pose_at on both, the
## VAT side through the baked texture: {max_m, mean_m, worst (the drives), vertices, samples}.
static func pose_error(
	live: HordeAvatar,
	vat: HordeAvatar,
	pose: Dictionary,
	mesh: ArrayMesh,
	samples: int,
	seed_value: int,
	t_max := 20.0
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var worst := 0.0
	var sum := 0.0
	var count := 0
	var at := {}
	for i in samples:
		var w := rng.randf()
		var s := rng.randf()
		var c := rng.randf()
		var t := rng.randf() * t_max
		var r := rng.randf()
		if i % 4 == 0:  # a quarter fully risen and still (the commonest pose)
			r = 1.0
		live.pose_at(w, s, c, t, r)
		vat.pose_at(w, s, c, t, r)
		var a := live_vertices(live)
		var b := eval_vertices(pose, mesh, Vector4(w, s, c, gait_phase(pose, t)), vat.vat_lift())
		for k in a.size():
			var e := a[k].distance_to(b[k])
			sum += e
			count += 1
			if e > worst:
				worst = e
				at = {"wind": w, "strike": s, "crouch": c, "t": t, "rise": r, "vertex": k}
	return {
		"max_m": worst,
		"mean_m": sum / maxf(1.0, count),
		"worst": at,
		"vertices": count / maxi(1, samples),
		"samples": samples,
	}


## v0.10.5 W3-V4b: pose_error for the kinds past the Swarmer: over `samples` random sets of every input the pose reads
## (HordeVat.sample: the windup raise, the strike, the crouch, the clock, the rise-in, the death, the walk,
## the heal, the tell), both avatars posed by pose_with, the VAT side through the baked texture at its own drives and
## instance transform (vat_drives, vat_offset). A vertex of a hidden piece (the dropped mine) must fold to its joint's
## point on the VAT side instead: `hidden_spread_m` is how far apart those land (0: drawn as nothing). {max_m, mean_m,
## worst (the inputs), vertices, samples, hidden, hidden_spread_m}.
static func pose_error_full(
	live: HordeAvatar,
	vat: HordeAvatar,
	pose: Dictionary,
	mesh: ArrayMesh,
	samples: int,
	seed_value: int,
	t_max := 20.0
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var worst := 0.0
	var sum := 0.0
	var count := 0
	var hidden := 0
	var spread := 0.0
	var at := {}
	var ps := pieces(live, joints(live))
	for i in samples:
		var s := HordeVat.sample(rng, t_max)
		live.pose_with(s)
		vat.pose_with(s)
		var a := live_vertices(live)
		var b := eval_vertices_at(pose, mesh, vat.vat_drives(pose), vat.vat_offset())
		var k0 := 0
		for p: Dictionary in ps:
			var mi: MeshInstance3D = p["node"]
			var nv: int = (
				(mi.mesh.surface_get_arrays(p["surface"])[Mesh.ARRAY_VERTEX] as PackedVector3Array)
				. size()
			)
			if not _shown(mi, live):
				hidden += nv
				for k in range(k0, k0 + nv):
					spread = maxf(spread, b[k].distance_to(b[k0]))
			else:
				for k in range(k0, k0 + nv):
					var e := a[k].distance_to(b[k])
					sum += e
					count += 1
					if e > worst:
						worst = e
						at = s.duplicate()
						at["vertex"] = k
			k0 += nv
	return {
		"max_m": worst,
		"mean_m": sum / maxf(1.0, count),
		"worst": at,
		"vertices": (count + hidden) / maxi(1, samples),
		"samples": samples,
		"hidden": hidden,
		"hidden_spread_m": spread,
	}


## Whether `n` and every node above it up to `avatar` is visible (the avatar may be out of the tree).
static func _shown(n: Node, avatar: Node) -> bool:
	while n != null and n != avatar:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true
