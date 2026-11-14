class_name VatVerify
extends RefCounted
## v0.11.1 Step 16 (audit D7): the VAT bake verifier, moved out of the shipped game (VatBake and the avatars' vat_sample
## and vat_set) unchanged. It runs the shader's arithmetic on the CPU and measures how far a baked pose is from the
## live one; only the tests, scripts/checks/vat_bake_report.gd and scripts/shots/vat_sheet.gd call it. It reads the
## public VatBake API the game keeps (GRID_NONE, MAX_CHAIN, gait_phase, drives_of, pieces, joints).

# --- the shader's arithmetic on the CPU (the bake report, tests) -------------------------------------------------


## The drives as the shader reads them, from a Vector4 (the pilot's four) or a packed array.
static func _drives(d: Variant) -> PackedFloat32Array:
	if d is Vector4:
		var v: Vector4 = d
		return PackedFloat32Array([v.x, v.y, v.z, v.w])
	return PackedFloat32Array(d)


## Joint (`slot`, `grid`)'s baked local transform at the drives `d`, as the shader samples it (VatLooks: multilinear
## over the grid's axes, a loop linear and wrapped).
static func eval_local(pose: Dictionary, slot: int, grid: int, dv: Variant) -> Transform3D:
	if grid == VatBake.GRID_NONE:
		return Transform3D.IDENTITY
	var d := _drives(dv)
	var t: Dictionary = (pose["grids"] as Array)[grid]
	var axes: Array = t["axes"]
	var n: Vector3i = t["n"]
	var i0 := Vector3i.ZERO
	var i1 := Vector3i.ZERO
	var f := Vector3.ZERO
	for a in axes.size():
		var na: int = n[a]
		if na < 2:
			continue
		var di: int = axes[a][0]
		var v: float = d[di] if di < d.size() else 0.0
		if bool(axes[a][2]):
			var u: float = (v - floor(v)) * na
			var k0 := int(floor(u)) % na
			i0[a] = k0
			i1[a] = (k0 + 1) % na
			f[a] = u - floor(u)
		else:
			var g := clampf(v, 0.0, 1.0) * (na - 1)
			var k0 := mini(int(floor(g)), na - 2)
			i0[a] = k0
			i1[a] = k0 + 1
			f[a] = g - k0
	var rows: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	var data: PackedFloat32Array = pose["data"]
	var width: int = pose["width"]
	var row0: int = t["row0"]
	for c in 8:
		var o := Vector3i(c & 1, (c >> 1) & 1, (c >> 2) & 1)
		var w := (
			(f.x if o.x == 1 else 1.0 - f.x)
			* (f.y if o.y == 1 else 1.0 - f.y)
			* (f.z if o.z == 1 else 1.0 - f.z)
		)
		if w == 0.0:
			continue
		var ix := Vector3i(
			i1.x if o.x == 1 else i0.x, i1.y if o.y == 1 else i0.y, i1.z if o.z == 1 else i0.z
		)
		var r := row0 + ix.x + n.x * (ix.y + n.y * ix.z)
		for k in 3:
			var p := (r * width + slot * 3 + k) * 4
			rows[k] += Vector4(data[p], data[p + 1], data[p + 2], data[p + 3]) * w
	return Transform3D(
		Basis(
			Vector3(rows[0].x, rows[1].x, rows[2].x),
			Vector3(rows[0].y, rows[1].y, rows[2].y),
			Vector3(rows[0].z, rows[1].z, rows[2].z)
		),
		Vector3(rows[0].w, rows[1].w, rows[2].w)
	)


## Joint `j`'s chain at the drives `d` (joint after parent, to the root), as the shader composes it.
static func eval_chain(pose: Dictionary, j: int, dv: Variant) -> Transform3D:
	var d := _drives(dv)
	var js: Array = pose["joints"]
	var m := Transform3D.IDENTITY
	var k := 0
	while j >= 0 and k < VatBake.MAX_CHAIN:
		var e: Dictionary = js[j]
		m = eval_local(pose, e["slot"], e["grid"], d) * m
		j = e["parent"]
		k += 1
	return m


## Every vertex of `mesh` (build_mesh's) in the avatar's space at the drives `d` and the lift, as the shader poses it.
static func eval_vertices(
	pose: Dictionary, mesh: ArrayMesh, dv: Variant, lift: float
) -> PackedVector3Array:
	return eval_vertices_at(pose, mesh, dv, Transform3D(Basis.IDENTITY, Vector3(0, lift, 0)))


## v0.10.5 W3-V4b: eval_vertices with the body's whole instance transform `offset` (HordeAvatar.vat_offset) for the
## lift.
static func eval_vertices_at(
	pose: Dictionary, mesh: ArrayMesh, dv: Variant, offset: Transform3D
) -> PackedVector3Array:
	var d := _drives(dv)
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c2: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM2]
	var out := PackedVector3Array()
	out.resize(v.size())
	var cache := {}
	for k in v.size():
		var j := int(c2[k * 4])
		if not cache.has(j):
			cache[j] = offset * eval_chain(pose, j, d)
		out[k] = (cache[j] as Transform3D) * v[k]
	return out


## Every piece vertex of `avatar` (posed, with its pieces) in its own space, in build_mesh's order. v0.10.5 W3-V4c: a
## hidden node folds what hangs from it to its origin (what a VAT kind draws for it: the Bomb Drone's dropped bomb).
static func live_vertices(avatar: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Dictionary in VatBake.pieces(avatar, VatBake.joints(avatar)):
		var mi: MeshInstance3D = p["node"]
		var xf := Transform3D.IDENTITY
		var up: Node = mi
		while up != avatar:
			xf = (up as Node3D).transform * xf
			if not (up as Node3D).visible:
				xf = Transform3D(Basis() * 0.0, (up as Node3D).position)
			up = up.get_parent()
		var v: PackedVector3Array = mi.mesh.surface_get_arrays(p["surface"])[Mesh.ARRAY_VERTEX]
		out.append_array(xf * v)
	return out


## The largest distance (m) between `live`'s and the VAT avatar `vat`'s pose over `samples` random states, each posed
## on both by the avatar's own code, the VAT side through the baked texture: {max_m, mean_m, worst (the state),
## vertices, samples}. A horde avatar's state: the windup raise, the strike, the crouch, the clock up to `t_max` s and
## the rise-in (HordeAvatar.pose_at); any other's: sample (every drive anywhere in its range, mixed freely).
static func pose_error(
	live: Node3D,
	vat: Node3D,
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
		var state := {}
		var d := PackedFloat32Array()
		if live is HordeAvatar:
			var w := rng.randf()
			var s := rng.randf()
			var c := rng.randf()
			var t := rng.randf() * t_max
			var r := rng.randf()
			if i % 4 == 0:  # a quarter fully risen and still (the commonest pose)
				r = 1.0
			(live as HordeAvatar).pose_at(w, s, c, t, r)
			(vat as HordeAvatar).pose_at(w, s, c, t, r)
			state = {"wind": w, "strike": s, "crouch": c, "t": t, "rise": r}
			d = PackedFloat32Array([w, s, c, VatBake.gait_phase(pose, t)])
		else:
			state = sample(live, rng)
			apply(vat, state)
			d = VatBake.drives_of(vat, pose)
		var a := live_vertices(live)
		var b := eval_vertices(pose, mesh, d, float(vat.call(&"vat_lift")))
		for k in a.size():
			var e := a[k].distance_to(b[k])
			sum += e
			count += 1
			if e > worst:
				worst = e
				at = state.duplicate()
				at["vertex"] = k
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
	var ps := VatBake.pieces(live, VatBake.joints(live))
	for i in samples:
		var s := HordeVat.sample(rng, t_max)
		live.pose_with(s)
		vat.pose_with(s)
		var a := live_vertices(live)
		var b := eval_vertices_at(pose, mesh, vat.vat_grid_drives(), vat.vat_offset())
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


# --- the stand-alone kinds' random states (were each avatar's vat_sample and vat_set) ----------------------------


## Poses `a` (a stand-alone VAT avatar) in a random state, every input its pose reads mixed freely, and returns the
## state: the Charger's from ChargerVat.sample, the rest from their ranges (ranges) through SoloVat.sample.
static func sample(a: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	if a is ChargerAvatar:
		return ChargerVat.sample(a, rng)
	return SoloVat.sample(a, rng, ranges(a, rng), _pose_of(a))


## Poses `a` in the state sample made.
static func apply(a: Node3D, s: Dictionary) -> void:
	if a is ChargerAvatar:
		ChargerVat.apply(a, s)
		return
	SoloVat.apply(a, s, _pose_of(a))


## The avatar's own pose code (the Needle's and the Warden's take a frame time: 0).
static func _pose_of(a: Node3D) -> Callable:
	if a is NeedleAvatar or a is WardenAvatar:
		return Callable(a, &"_pose").bind(0.0)
	return Callable(a, &"_pose")


## The inputs each stand-alone kind's pose reads ({private var: [lo, hi]}, or [values...] to pick from; SoloVat.sample).
## The Needle's velocity is drawn from `rng` first.
static func ranges(a: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var states4 := [
		WorldReader.STATE_MOVE,
		WorldReader.STATE_WINDUP,
		WorldReader.STATE_ACTIVE,
		WorldReader.STATE_RECOVER
	]
	if a is BombDroneAvatar:
		return {"_t": [0.0, 40.0], "_rise": [0.0, 1.0], "_armed": [0.0, 1.0], "_fuse": [0.0, 1.0]}
	if a is LensDroneAvatar:
		return {"_t": [0.0, 40.0], "_rise": [0.0, 1.0], "_charge": [0.0, 1.0]}
	if a is CinderPriestAvatar:
		var death := CinderPriestAvatar.DEATH_SECONDS
		return {
			"_t": [0.0, 40.0],
			"_rise": [0.0, 1.0],
			"_pulse": [0.0, 1.0],
			"_erupt_s": [-0.5, CinderPriestAvatar.STRIKE_END_S],
			"_glide": [0.0, 1.0],
			"_dir": [Vector2.RIGHT, Vector2(-0.6, 0.8), Vector2(0.0, -1.0), Vector2(-1.0, 0.0)],
			"_turn": [0.0, 1.0],
			"_yaw": [-CinderPriestAvatar.TURN_MAX, CinderPriestAvatar.TURN_MAX],
			"_die_t": [-1.0, -1.0, death * 0.3, death * 0.7, death],
		}
	if a is KilnBeetleAvatar:
		return {
			"_t": [0.0, 40.0],
			"_phase": [0.0, 1.0],
			"_speed": [0.0, 2.0],
			"_omega": [-2.0, 2.0],
			"_stride": [0.0, 1.0],
			"_heat": [0.0, 1.0],
			"_coil": [0.0, 1.0],
			"_tell": [0.0, 1.0],
			"_rise": [0.0, 1.0],
			"_slam_t": [-0.3, KilnBeetleAvatar.SLAM_SECONDS],
			"_hurt_t": [-0.2, KilnBeetleAvatar.HURT_SECONDS],
			"_hurt_leg": [0, 1, 2, 3, 4, 5, 6, 7],
			"_die_t": [-0.6, KilnBeetleAvatar.DEATH_SECONDS],
			"_state": states4,
		}
	if a is NeedleAvatar:
		var dir := rng.randf() * TAU
		return {
			"_vel_s": Vector3(cos(dir), 0, sin(dir)) * rng.randf() * 4.0,
			"_t": [0.0, 40.0],
			"_walk": [0.0, 1.0],
			"_phase": [0.0, 1.0],
			"_rise": [0.0, 1.0],
			"_brace": [0.0, 1.0],
			"_charge": [0.0, 1.0],
			"_kick": [0.0, 1.0],
			"_heat": [0.0, 1.0],
			"_tell_p": [0.0, 1.0],
			"_state": states4,
		}
	if a is RockLurkerAvatar:
		return {
			"_t": [0.0, 40.0],
			"_phase": [0.0, 40.0],
			"_walk": [0.0, 1.2],
			"_tuck": [0.0, 1.0],
			"_rumble": [0.0, 1.0],
			"_rear": [0.0, 1.0],
			"_slam": [0.0, 1.0],
			"_impact": [-1.0, 1.5],
			"_burst": [-0.6, 0.6],
			"_burst_slam": [true, false, true],
			"_die": [-1.0, 1.2],
			"_windup": [0.0, 1.0],
			"_state": [WorldReader.STATE_MOVE, WorldReader.STATE_WINDUP],
			"_rise": [0.0, 1.0],
			"_flinch_t": [0.0, 0.25],
			"_flinch_s": [0.0, 1.5],
		}
	if a is ScrapHoundAvatar:
		return {
			"_t": [0.0, 40.0],
			"_phase": [0.0, 1.0],
			"_speed": [0.0, 14.0],
			"_gallop": [0.0, 1.0],
			"_yaw": [-PI, PI],
			"_bank": [-1.0, 1.0],
			"_coil": [0.0, 1.0],
			"_tell": [0.0, 1.0],
			"_dart": [0.0, 1.0],
			"_rise": [0.0, 1.0],
			"_bite_t": [-0.3, ScrapHoundAvatar.BITE_SECONDS],
			"_yelp_t": [-0.4, ScrapHoundAvatar.YELP_SECONDS],
			"_hurt_t": [-0.15, ScrapHoundAvatar.HURT_SECONDS],
			"_die_t": [-0.6, ScrapHoundAvatar.DEATH_SECONDS],
			"_state": states4,
		}
	if a is StoneThrowerAvatar:
		return {
			"_t": [0.0, 40.0],
			"_phase": [0.0, 40.0],
			"_walk": [0.0, 1.0],
			"_speed": [-1.8, 1.8],
			"_puff": [0.0, 1.0],
			"_rise": [0.0, 1.0],
			"_atk": [-1.0, 2.3],
			"_atk_sim": [-1.0, 2.3],
			"_die_t": [-1.0, 1.8],
			"_drop": [false, true, false],
			"_flinch_t": [0.0, 0.25],
			"_flinch_s": [0.0, 1.0],
			"_state": [WorldReader.STATE_MOVE, WorldReader.STATE_WINDUP, WorldReader.STATE_ACTIVE],
		}
	if a is WardenAvatar:
		return {
			"_t": [0.0, 40.0],
			"_phase": [0.0, 40.0],
			"_walk": [0.0, 1.0],
			"_raise": [0.0, 1.0],
			"_slam": [0.0, 1.0],
			"_rise": [0.0, 1.0],
			"_shake": [0.0, 1.0],
			"_windup": [0.0, 1.0],
			"_state": [WorldReader.STATE_MOVE, WorldReader.STATE_WINDUP],
		}
	push_error("VatVerify.ranges: no ranges for %s" % a)
	return {}
