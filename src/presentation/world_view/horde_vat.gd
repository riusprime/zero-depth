class_name HordeVat
extends RefCounted
## v0.10.5 W3-V4b (owner, 2026-11-06: "can we apply it to the rest of the enemies and test it?"): what the VAT path
## (VatBake, VatCrowd, VatLooks) needs to know about the horde kinds past the Swarmer: the Splitter and Splitling, the
## Shield Bearer and the Mender (the owner's models), the Mine Layer and the Sniper (code bodies). Each one's body
## (its pivot's place, lean and scale, the model's sway and death shrink) is the crowd's instance transform
## (HordeAvatar.vat_offset), worked out by the avatar's own pose code, so only the moving parts are baked, over drives
## that each set one part's pose (HordeAvatar._pose_parts):
## - Shield Bearer: x the windup raise, y the strike (the shield); w the legs' swing, as a stride's phase (the gait).
## - Splitter, Splitling: x the raise, y the strike, z the death (the halves and claws); w the legs (the gait).
## - Mender: x the crystal raised while it heals (0 / 1); w the cross's turn (the gait, one turn a loop).
## - Mine Layer: x the windup (the hopper lowers), y the mine shown (0 / 1: hidden, its joint folds to a point).
## - Sniper: x the barrel's angle, y the muzzle's size; w the muzzle's own glow (no gait).
## - v0.11.0 O9, the horde critters (CritterBodies): w the gait loop (the legs, wings, claws or tail); x, y, z unused.
## The Swarmer keeps the pilot's path (VatBake's own joint list and grids). Presentation only (EI-07).

## Per kind: the stance grid's samples over the drives' x, y, z and the gait loop's samples over w (0: no gait).
## Starting values; the error they give: scripts/checks/vat_bake_report.gd.
const GRIDS := {
	WorldReader.KIND_SPLITTER: [Vector3i(9, 17, 9), 48],
	WorldReader.KIND_SPLITLING: [Vector3i(9, 17, 9), 48],
	WorldReader.KIND_SHIELD_BEARER: [Vector3i(9, 9, 2), 48],
	WorldReader.KIND_MENDER: [Vector3i(2, 2, 2), 48],
	WorldReader.KIND_MINE_LAYER: [Vector3i(2, 2, 2), 0],
	WorldReader.KIND_SNIPER: [Vector3i(17, 2, 2), 0],
	# v0.11.0 O9: the horde critters: no stance (2 samples each way: unused), the gait loop poses their parts
	WorldReader.KIND_DUST_MITE: [Vector3i(2, 2, 2), CritterBodies.GAIT_SAMPLES],
	WorldReader.KIND_CAVE_BAT: [Vector3i(2, 2, 2), CritterBodies.GAIT_SAMPLES],
	WorldReader.KIND_EMBER_FLEA: [Vector3i(2, 2, 2), CritterBodies.GAIT_SAMPLES],
	WorldReader.KIND_ICE_CRAB: [Vector3i(2, 2, 2), CritterBodies.GAIT_SAMPLES],
	WorldReader.KIND_STAR_MOTE: [Vector3i(2, 2, 2), CritterBodies.GAIT_SAMPLES],
}


## v0.10.5 W3-V4b (on W3-V4a's general path): the VatBake rig of `a` (built with its pieces; see VatBake's class
## notes), its key "horde<kind>" as the pilot's. Four drives (vat_grid_drives): the stance grid over x, y, z, the gait
## loop over w (a kind without a gait has no gait grid; the Sniper's w is its muzzle's glow, read by VatLooks' mode 3).
## The body is the root joint, on the stance grid but always the identity (its moves are the instance's, vat_offset);
## a hidden joint (the dropped mine) is baked folded to a point (a zero basis), so its triangles draw nothing.
static func rig(a: HordeAvatar) -> Dictionary:
	var g: Array = grids(a.kind)
	var sn: Vector3i = g[0]
	var gait: int = g[1]
	var js: Array = []
	var index := {}
	for j: Array in joint_spec(a):
		var node: Node3D = j[0]
		var parent := -1
		var up := node.get_parent()
		while up != null and up != a:
			if index.has(up):
				parent = index[up]
				break
			up = up.get_parent()
		index[node] = js.size()
		var grid: int = j[1]
		js.append({"grid": maxi(grid, VatBake.GRID_STANCE), "parent": parent, "frame": node})
	var axes: Array = [[[0, sn.x, false], [1, sn.y, false], [2, sn.z, false]]]
	if gait > 0:
		axes.append([[3, gait, true]])
	var out := {
		"key": "horde%d" % a.kind,
		"drives": 4,
		"grids": axes,
		"joints": js,
		"row": func(gi: int, d: PackedFloat64Array) -> Array: return _row(a, js, gi, d),
		"scaled": false,
		"outline_m": HordeAvatar.OUTLINE_M,
	}
	var tex := texture(a)
	if tex != null:
		out["albedo_tex"] = tex
	return out


static func _row(a: HordeAvatar, js: Array, g: int, d: PackedFloat64Array) -> Array:
	a.vat_bake_pose(Vector3(d[0], d[1], d[2]), d[3])
	var out: Array = []
	for j: Dictionary in js:
		if j["grid"] != g:
			continue
		if j["frame"] == a.body:
			out.append(Transform3D.IDENTITY)
			continue
		var xf := VatBake.local_of(a, js, j)
		if not (j["frame"] as Node3D).visible:
			xf.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		out.append(xf)
	return out


## `kind`'s grids: [stance samples (Vector3i), gait samples] (the Swarmer's: VatBake.STANCE_N, GAIT_N).
static func grids(kind: int) -> Array:
	return GRIDS.get(kind, [VatBake.STANCE_N, VatBake.GAIT_N])


## The joints ([node, grid]) of `a` (built with its pieces), a parent before its children; the body is the root
## (VatBake.GRID_NONE: its moves are the instance's). [] for the Swarmer (VatBake's own list).
static func joint_spec(a: HordeAvatar) -> Array:
	var g0 := VatBake.GRID_STANCE
	var g1 := VatBake.GRID_GAIT
	var p := a.parts
	var out: Array = [[a.body, VatBake.GRID_NONE]]
	match a.kind:
		WorldReader.KIND_SHIELD_BEARER:
			out.append_array([[p["shield"], g0], [p["leg_l"], g1], [p["leg_r"], g1]])
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			for pname: String in ["half_l", "half_r", "arm_l", "arm_r"]:
				out.append([p[pname], g0])
			out.append_array([[p["leg_l"], g1], [p["leg_r"], g1]])
		WorldReader.KIND_MENDER:
			out.append_array([[p["crystal"], g0], [p["cross"], g1]])
		WorldReader.KIND_MINE_LAYER:
			out.append_array([[p["hopper"], g0], [p["mine"], g0]])
		WorldReader.KIND_SNIPER:
			out.append_array([[p["barrel"], g0], [p["muzzle"], g0]])
		_ when CritterBodies.is_critter(a.kind):  # v0.11.0 O9: legs, wings, claws or tail on the gait
			out.append_array(CritterBodies.joints(a))
		_:
			return []
	return out


## The drives `d` (HordeAvatar._pose_parts' natural units) of `a` in its grid's units: x, y, z 0..1 over the stance
## grid; w the gait loop's phase (any real: the shader wraps it) or, on the Sniper, the muzzle's glow.
static func grid_of(a: HordeAvatar, d: Vector4) -> Vector4:
	if CritterBodies.is_critter(a.kind):  # v0.11.0 O9: w is the gait's phase (0..1)
		return Vector4(0.0, 0.0, 0.0, fposmod(d.w, 1.0))
	match a.kind:
		WorldReader.KIND_MENDER:
			return Vector4(d.x, 0.0, 0.0, fposmod(d.w / TAU, 1.0))
		WorldReader.KIND_MINE_LAYER:
			return Vector4(d.x, d.y, 0.0, 0.0)
		WorldReader.KIND_SNIPER:
			return Vector4(
				(d.x - HordeAvatar.SNIPER_AIM_MIN) / HordeAvatar.SNIPER_AIM_SPAN,
				(d.y - 0.4) / 0.6,
				0.0,
				a.muzzle_energy()
			)
	# The owner's walking models: the swing (sin(stride) x walk, -1..1) as the phase of a full stride's loop (its asin),
	# so the loop baked at a full walk gives sin(asin(swing)) = the swing.
	return Vector4(d.x, d.y, d.z, asin(clampf(d.w, -1.0, 1.0)) / TAU)


## The inverse of grid_of: `kind`'s natural drives at stance grid point `u` and gait phase `phase` (0..1).
static func natural(kind: int, u: Vector3, phase: float) -> Vector4:
	if CritterBodies.is_critter(kind):  # v0.11.0 O9
		return Vector4(0.0, 0.0, 0.0, phase)
	match kind:
		WorldReader.KIND_MENDER:
			return Vector4(u.x, 0.0, 0.0, phase * TAU)
		WorldReader.KIND_MINE_LAYER:
			return Vector4(u.x, u.y, 0.0, 0.0)
		WorldReader.KIND_SNIPER:
			return Vector4(
				HordeAvatar.SNIPER_AIM_MIN + HordeAvatar.SNIPER_AIM_SPAN * u.x,
				0.4 + 0.6 * u.y,
				0.0,
				0.0
			)
	return Vector4(u.x, u.y, u.z, sin(phase * TAU))


## The owner's model's colour map for `a` (its plates are textured; VatLooks samples it), or null.
static func texture(avatar: Node3D) -> Texture2D:
	var lens := avatar as LensDroneAvatar  # v0.11.0 S4: the Lens Drone's model
	if lens != null:
		return EnemyModels.get_model(&"lens_drone").get("texture") if lens.has_model else null
	var a := avatar as HordeAvatar
	if a == null or not a.has_model():
		return null
	return EnemyModels.get_model(HordeAvatar.model_id(a.kind)).get("texture")


## True for the piece of `a` whose glow is the instance's second one (the Sniper's muzzle: the drives' w).
static func alt_glow(avatar: Node3D, piece: Node) -> bool:
	var a := avatar as HordeAvatar
	return (
		a != null
		and a.kind == WorldReader.KIND_SNIPER
		and piece != null
		and piece.name == &"Muzzle"
	)


## A random set of HordeAvatar.pose_with's inputs (the bake report, tests): about a third dying, a quarter fully risen.
static func sample(rng: RandomNumberGenerator, t_max := 20.0) -> Dictionary:
	var dying := rng.randf() < 0.3
	return {
		"wind": rng.randf(),
		"strike": rng.randf(),
		"crouch": rng.randf(),
		"t": rng.randf() * t_max,
		"rise": 1.0 if rng.randf() < 0.25 else rng.randf(),
		"die": rng.randf() * HordeAvatar.DEATH_SECONDS * 1.2 if dying else -1.0,
		"walk": rng.randf(),
		"walk_t": rng.randf() * t_max,
		"healing": rng.randf() < 0.5,
		"tell": rng.randf(),
		"winding": rng.randf() < 0.5,
	}
