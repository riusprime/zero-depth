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
}


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
		_:
			return []
	return out


## The drives `d` (HordeAvatar._pose_parts' natural units) of `a` in its grid's units: x, y, z 0..1 over the stance
## grid; w the gait loop's phase (any real: the shader wraps it) or, on the Sniper, the muzzle's glow.
static func grid_of(a: HordeAvatar, d: Vector4) -> Vector4:
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
static func texture(a: HordeAvatar) -> Texture2D:
	if not a.has_model():
		return null
	return EnemyModels.get_model(HordeAvatar.model_id(a.kind)).get("texture")


## True for the piece of `a` whose glow is the instance's second one (the Sniper's muzzle: the drives' w).
static func alt_glow(a: HordeAvatar, piece: Node) -> bool:
	return a.kind == WorldReader.KIND_SNIPER and piece != null and piece.name == &"Muzzle"


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
