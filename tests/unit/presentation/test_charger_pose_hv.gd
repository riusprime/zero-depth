extends GutTest
## v0.8.0 HV (owner O89, the horde lag): the Charger's pose without Arrays (ChargerAvatar._pose / _pose_leg in plain
## floats, one transform write per segment) is the same pose as before. The old formula is copied here as the
## reference and both run on the same state; every transform must match exactly.

## [phase, t, walk, wind, lunge, daze, rise, state, windup progress]
const CASES := [
	[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, WorldReader.STATE_MOVE, 0.0],
	[1.3, 2.7, 0.8, 0.0, 0.0, 0.0, 1.0, WorldReader.STATE_MOVE, 0.0],
	[4.1, 9.35, 0.2, 0.7, 0.0, 0.0, 1.0, WorldReader.STATE_WINDUP, 0.6],
	[7.9, 13.2, 1.0, 0.1, 0.9, 0.0, 1.0, WorldReader.STATE_ACTIVE, 0.0],
	[2.2, 5.5, 0.0, 0.0, 0.3, 0.8, 1.0, WorldReader.STATE_RECOVER, 0.0],
	[0.6, 0.4, 0.0, 0.0, 0.0, 0.0, 0.35, WorldReader.STATE_SPAWN, 0.0],
	[11.0, 31.7, 0.55, 0.45, 0.25, 0.15, 0.8, WorldReader.STATE_WINDUP, 0.97],
]


func _avatar() -> ChargerAvatar:
	var a := ChargerAvatar.new()
	a.setup(Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	return a


func _apply(a: ChargerAvatar, c: Array) -> void:
	a._phase = c[0]
	a._t = c[1]
	a._walk = c[2]
	a._wind = c[3]
	a._lunge = c[4]
	a._daze = c[5]
	a._rise = c[6]
	a._state = c[7]
	a._tell_p = c[8]


func test_the_new_pose_matches_the_old_formula_exactly() -> void:
	for c: Array in CASES:
		var fresh := _avatar()
		var ref := _avatar()
		_apply(fresh, c)
		_apply(ref, c)
		fresh._pose()
		_ref_pose(ref)
		var what := str(c)
		assert_eq(fresh._model.transform, ref._model.transform, "the model's sink " + what)
		assert_eq(fresh.body.transform, ref.body.transform, "the body " + what)
		assert_almost_eq(fresh.visor_energy(), ref.visor_energy(), 1e-4, "the visor " + what)
		for k in 4:
			assert_eq(fresh.legs[k].transform, ref.legs[k].transform, "hip %d %s" % [k, what])
			assert_eq(
				fresh._femurs[k].transform, ref._femurs[k].transform, "femur %d %s" % [k, what]
			)
			assert_eq(
				fresh._tibias[k].transform, ref._tibias[k].transform, "tibia %d %s" % [k, what]
			)
			assert_eq(
				fresh._talons[k].transform, ref._talons[k].transform, "talon %d %s" % [k, what]
			)


func test_an_unchanged_visor_is_not_written_again() -> void:
	var a := _avatar()
	_apply(a, CASES[0])
	a._pose()
	var mat: StandardMaterial3D = a.visor.material_override
	mat.emission_energy_multiplier = 9.0  # a marker: an unchanged glow leaves it
	a._pose()
	assert_eq(mat.emission_energy_multiplier, 9.0, "the same glow: no write")
	a._wind = 0.5
	a._pose()
	assert_ne(mat.emission_energy_multiplier, 9.0, "a new glow is written")


# --- The reference: ChargerAvatar._pose and _pose_leg as they were at 07af5d59 ----------------------------------
func _ref_pose(a: ChargerAvatar) -> void:
	# The old code only ever set position, rotation and scale, so its nodes kept an exact unit scale; setup() posed
	# them with the new code (one transform write), so the reference's scale is put back to exactly one first (a
	# rotation set after a transform write keeps the scale read back from the basis, off by an ulp).
	for n: Node3D in [a.body] + a._femurs + a._tibias + a._talons:
		n.scale = Vector3.ONE
	var rise := smoothstep(0.0, 1.0, a._rise)
	var lunge := a._lunge * (1.0 - a._daze)
	var bob := absf(sin(a._phase * 2.0)) * 0.02 * a._walk
	var breath := sin(a._t * 2.4) * 0.008 * (1.0 - a._walk)
	var calm := ViewPrefs.reduced_motion
	var tremble := 0.0 if calm else sin(a._t * 47.0) * 0.006 * a._wind
	var crouch := a.crouch_amount()
	var drop := a._daze * 0.09 - a._wind * 0.05 + lunge * 0.07 + crouch * 0.09
	var y := bob + breath + tremble - drop
	a._model.position = Vector3(0, -(1.0 - rise) * 0.45, 0)
	a.body.position = Vector3(-a._wind * 0.06 - crouch * 0.07 + lunge * 0.16, y, 0)
	a.body.rotation = Vector3(a._daze * 0.16, 0, a._wind * 0.3 - lunge * 0.3 - a._daze * 0.1)
	a.body.scale = Vector3(1.0 + lunge * 0.14, 1.0 - lunge * 0.06, 1.0 - lunge * 0.04)
	var shimmer := 0.0 if calm else 0.5 * sin(a._t * 30.0)
	var tell := (
		AvatarBase.tell_glow(a._tell_p, a._t, calm) if a._state == WorldReader.STATE_WINDUP else 1.0
	)
	var glow := (
		ChargerAvatar.VISOR_ENERGY
		* (1.0 + a._wind * (1.6 + shimmer) + lunge * 1.2)
		* tell
		* (1.0 - a._daze * 0.7)
	)
	(a.visor.material_override as StandardMaterial3D).emission_energy_multiplier = glow
	for k in a.legs.size():
		_ref_pose_leg(a, k, y, lunge, rise)


func _ref_pose_leg(a: ChargerAvatar, k: int, body_y: float, lunge: float, rise: float) -> void:
	var front := k < 2
	var side := 1.0 if k % 2 == 0 else -1.0
	var hip: Vector3 = ChargerAvatar.FRONT_HIP if front else ChargerAvatar.BACK_HIP
	var lens: Array = ChargerAvatar.FRONT_LEN if front else ChargerAvatar.BACK_LEN
	var yaw: Array = (ChargerAvatar.FRONT_YAW if front else ChargerAvatar.BACK_YAW).duplicate()
	var pitch: Array = (
		(ChargerAvatar.FRONT_PITCH if front else ChargerAvatar.BACK_PITCH).duplicate()
	)
	var off := 0.0 if (k == 0 or k == 3) else PI
	var lift := maxf(0.0, cos(a._phase + off)) * 0.45 * a._walk
	var fidget := (
		maxf(0.0, sin(a._t * 0.9 + k * 1.6 + 4.0) - 0.85) * 2.2 * (1.0 - a._walk) * (1.0 - a._wind)
	)
	var sweep := sin(a._phase + off) * 0.3 * a._walk
	var hold := clampf(-body_y / float(lens[0]), -0.6, 0.6)
	var add_yaw := [sweep, sweep, sweep]
	var add_pitch := [lift + fidget + hold, lift * 0.5, 0.0]
	var wind := a._wind
	var daze := a._daze
	if front:
		add_yaw = _plus(
			add_yaw, [wind * 0.3 + lunge * 0.55, wind * 0.2 + lunge * 0.2, -lunge * 0.5]
		)
		add_pitch = _plus(
			add_pitch,
			[wind * 0.9 + lunge * 0.55, wind * 1.7 + lunge * 1.1, wind * 1.5 + lunge * 0.7]
		)
	else:
		add_yaw = _plus(add_yaw, [-wind * 0.15 - lunge * 0.35, -lunge * 0.3, -lunge * 0.3])
		add_pitch = _plus(add_pitch, [-wind * 0.1 + lunge * 0.3, lunge * 0.5, lunge * 0.3])
	var twitch := sin(a._t * 9.0 + k) * 0.05 * daze
	add_yaw = _plus(add_yaw, [-daze * 0.15, -daze * 0.15, -daze * 0.2])
	add_pitch = _plus(add_pitch, [daze * 0.3, 0.0, daze * 0.35 + twitch])
	add_pitch = _plus(add_pitch, [(1.0 - rise) * 1.2, (1.0 - rise) * 1.4, (1.0 - rise) * 1.0])
	a.legs[k].position = Vector3(hip.x + a.body.position.x, hip.y + body_y, hip.z * side)
	var at := Vector3.ZERO
	var segs: Array[Node3D] = [a._femurs[k], a._tibias[k], a._talons[k]]
	for j in 3:
		var y: float = (yaw[j] + add_yaw[j]) * side
		var p: float = pitch[j] + add_pitch[j]
		segs[j].position = at
		segs[j].rotation = Vector3(0, y, p)
		var reach: float = lens[j]
		at += Vector3(cos(p) * cos(y), sin(p), -cos(p) * sin(y)) * reach


static func _plus(a: Array, b: Array) -> Array:
	return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
