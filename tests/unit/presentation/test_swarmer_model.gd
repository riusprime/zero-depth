extends GutTest
## The Swarmer on the owner's model (HordeAvatar with SwarmerModel): its parts load into their joints at the horde's
## small size, each clip moves the parts it should (the tripod scuttle, the idle working of the mandibles, the tell's
## rear with the wing cases opening, the strike's snap and lunge, the death's roll onto its back), the knees stay off
## the ground, reduced motion keeps it still at rest, a missing model falls back to the code body, and the VAT bake on
## the horde path matches the live pose (within 2 mm), through a fight and a death.

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_SWARMER
const RUN_MPS := 4.6

var _calm := false
var _vat := false


func before_each() -> void:
	_calm = ViewPrefs.reduced_motion
	_vat = ViewPrefs.enemy_vat
	ViewPrefs.reduced_motion = false
	VatBake.clear_cache()


func after_each() -> void:
	ViewPrefs.reduced_motion = _calm
	ViewPrefs.enemy_vat = _vat
	EnemyModels.dir = EnemyModels.DIR
	EnemyModels.clear_cache()
	VatBake.clear_cache()


## A Swarmer under a holder node (what moves it on the ground), its own processing off; `vat`: the crowd's kind.
func _swarmer(vat := false) -> HordeAvatar:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var a := HordeAvatar.new()
	a.vat = vat
	a.setup(KIND)
	holder.add_child(a)
	a.set_process(false)
	return a


## `n` ticks of `state` (apply_state then a frame each), the holder moved `mps` along +X; returns the next tick.
func _run(a: HordeAvatar, from: int, n: int, state: int, windup := 0.0, mps := 0.0) -> int:
	for k in n:
		(a.get_parent() as Node3D).position.x += mps * DT
		a.apply_state({"tick": from + k, "state": state, "windup": windup})
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


## Leg `leg`'s foot tip in the avatar's space (the lowest point of its lower half at rest, carried by its joints).
func _foot(a: HordeAvatar, leg: StringName) -> Vector3:
	var low := a.parts["leg_%s_l" % leg] as Node3D
	var mi := low.get_child(0) as MeshInstance3D
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tip := v[0]
	for p in v:
		if p.y < tip.y:
			tip = p
	return a.global_transform.affine_inverse() * (mi.global_transform * tip)


func _knee(a: HordeAvatar, leg: StringName) -> Vector3:
	var low := a.parts["leg_%s_l" % leg] as Node3D
	return a.global_transform.affine_inverse() * low.global_position


func _yaw(n: Node3D) -> float:
	return n.transform.basis.get_euler().y


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	var a := _swarmer()
	_run(a, 0, 1, WorldReader.STATE_MOVE)  # (risen: met past its spawn)
	assert_true(a.has_model(), "the owner's model")
	for p: String in ["body", "shell_l", "shell_r", "mand_l", "mand_r", "shell_l_g", "mand_r_g"]:
		assert_true(a.parts.has(p), p)
	for leg: StringName in SwarmerModel.LEGS:
		assert_true(a.parts.has("leg_%s_u" % leg) and a.parts.has("leg_%s_l" % leg), leg)
		assert_eq(
			(a.parts["leg_%s_l" % leg] as Node3D).get_parent().get_parent() != null, true, leg
		)
	assert_true(a.parts.has("leg_fr_r") and a.parts.has("leg_fl_r"), "the front pair's raise")
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in VatVerify.live_vertices(a):
		lo = lo.min(v)
		hi = hi.max(v)
	assert_almost_eq(hi.y - lo.y, 0.25, 0.02, "about 0.25 m tall (%s .. %s)" % [lo, hi])
	assert_almost_eq(hi.x - lo.x, 0.5, 0.03, "about 0.5 m long")
	assert_almost_eq(lo.y, 0.0, 0.01, "on the ground")
	var tris := 0
	for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_len(s) / 3
	assert_between(tris, 2500, 3300, "simplified for the horde: %d triangles" % tris)


func test_the_scuttle_swings_the_tripods_in_turn_and_lifts_each_foot() -> void:
	var a := _swarmer()
	var t := _run(a, 0, 40, WorldReader.STATE_MOVE, 0.0, RUN_MPS)
	var lifted := {}
	var apart := 0
	for k in 40:
		t = _run(a, t, 1, WorldReader.STATE_MOVE, 0.0, RUN_MPS)
		var fr := _foot(a, &"fr").y
		var fl := _foot(a, &"fl").y
		if absf(fr - fl) > 0.01:
			apart += 1
		for leg: StringName in SwarmerModel.LEGS:
			if _foot(a, leg).y > 0.02:
				lifted[leg] = true
	assert_eq(lifted.size(), 6, "every foot lifts in its step: %s" % [lifted])
	assert_gt(apart, 10, "the front pair step in turn")


func test_at_rest_the_mandibles_work_and_the_wing_cases_breathe() -> void:
	var a := _swarmer()
	var t := _run(a, 0, 30, WorldReader.STATE_MOVE)
	var m0 := _yaw(a.parts["mand_r_g"])
	var s0 := (a.parts["shell_r_g"] as Node3D).transform
	_run(a, t, 17, WorldReader.STATE_MOVE)
	assert_gt(absf(_yaw(a.parts["mand_r_g"]) - m0), 0.01, "the mandibles work")
	assert_ne((a.parts["shell_r_g"] as Node3D).transform, s0, "the wing cases breathe")


func test_the_tell_rears_it_and_opens_the_wing_cases_and_mandibles() -> void:
	var a := _swarmer()
	var t := _run(a, 0, 30, WorldReader.STATE_MOVE)
	var rest_front := _foot(a, &"fr").y
	for k in 40:
		t = _run(a, t, 1, WorldReader.STATE_WINDUP, float(k + 1) / 40.0)
	assert_gt(-_yaw(a.parts["mand_r"]), 0.15, "the right mandible gapes out")
	assert_gt(_yaw(a.parts["mand_l"]), 0.15, "the left mandible gapes out")
	assert_gt(
		absf((a.parts["shell_r"] as Node3D).transform.basis.get_euler().z), 0.1, "the case opens"
	)
	assert_gt(a.body.rotation.z, 0.05, "it rears, nose up")
	assert_gt(_foot(a, &"fr").y, rest_front + 0.03, "its front feet lift")
	assert_lt(absf(_foot(a, &"br").y), 0.015, "on its hind feet, planted")


func test_the_strike_snaps_the_mandibles_shut_and_lunges() -> void:
	var a := _swarmer()
	var t := _run(a, 0, 30, WorldReader.STATE_MOVE)
	for k in 40:
		t = _run(a, t, 1, WorldReader.STATE_WINDUP, float(k + 1) / 40.0)
	var x0 := a.body.position.x
	t = _run(a, t, 4, WorldReader.STATE_ACTIVE)
	assert_lt(-_yaw(a.parts["mand_r"]), 0.0, "the mandibles cross shut")
	assert_lt(a.body.rotation.z, 0.0, "nose down onto its front feet")
	assert_gt(a.body.position.x, x0 + 0.03, "it lunges")
	assert_lt(absf(_foot(a, &"fr").y), 0.02, "its front feet down")


func test_the_death_rolls_it_onto_its_back_and_curls_its_legs() -> void:
	var a := _swarmer()
	_run(a, 0, 30, WorldReader.STATE_MOVE)
	var glow := a.glow_energy()
	assert_true(a.die(), "the model falls")
	for k in roundi(HordeAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_true(a.dying())
	assert_lt(a.model.rotation.x, -2.0, "rolled onto its back")
	var curl := (a.parts["leg_mr_l"] as Node3D).transform.basis.get_rotation_quaternion()
	assert_gt(curl.get_angle(), 1.0, "its legs curled")
	assert_lt(a.glow_energy(), glow * 0.05, "the eye goes out")


func test_the_knees_stay_off_the_ground_through_every_clip() -> void:
	var a := _swarmer()
	var t := 0
	var low := 1.0
	var clips := [
		[WorldReader.STATE_MOVE, 30, 0.0],
		[WorldReader.STATE_MOVE, 40, RUN_MPS],
		[WorldReader.STATE_WINDUP, 40, 0.0],
		[WorldReader.STATE_ACTIVE, 10, 0.0],
		[WorldReader.STATE_RECOVER, 30, 0.0],
	]
	for c: Array in clips:
		for k in int(c[1]):
			var p := float(k + 1) / float(c[1]) if c[0] == WorldReader.STATE_WINDUP else 0.0
			t = _run(a, t, 1, c[0], p, c[2])
			if k == 5:
				a.flinch(Vector2(-1, 0.3), 1.0)
			for leg: StringName in SwarmerModel.LEGS:
				low = minf(low, _knee(a, leg).y)
	assert_gt(low, 0.03, "the lowest knee: %f m" % low)


func test_reduced_motion_keeps_it_still_at_rest() -> void:
	ViewPrefs.reduced_motion = true
	var a := _swarmer()
	var t := _run(a, 0, 30, WorldReader.STATE_MOVE)
	var m0 := (a.parts["mand_r_g"] as Node3D).transform
	var b0 := a.body.transform
	_run(a, t, 20, WorldReader.STATE_MOVE)
	assert_eq((a.parts["mand_r_g"] as Node3D).transform, m0, "no working mandibles")
	assert_eq(a.body.transform, b0, "no bob")


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _swarmer()
	assert_false(a.has_model())
	assert_true(a.parts.has("mandible0"), "the code body")
	assert_true(VatCrowd.supports(KIND), "still drawn by the crowd (the pilot's rig)")
	assert_false(a.die(), "the code body goes at once")


func test_the_vat_bake_matches_the_live_pose() -> void:
	var pose := VatBake.pose_for(KIND)
	var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var live := VatBake.reference_avatar(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND) as HordeAvatar
	assert_eq(pose["key"], "horde%d" % KIND, "the horde path's bake")
	assert_eq(int(pose["drives"]), 4, "four drives: no drive texture")
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var e := VatVerify.pose_error_full(live, vat, pose, mesh, 60, 23)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
		assert_lt(float(e["max_m"]), 0.002, "within 2 mm (calm %s): %s" % [calm, e])
	live.free()
	vat.free()


func test_a_vat_swarmer_keeps_the_live_pose_through_a_fight_and_a_death() -> void:
	var live := _swarmer()
	var vat := _swarmer(true)
	assert_eq(vat.find_children("*", "MeshInstance3D", true, false).size(), 0, "no pieces")
	var pose := VatBake.pose_for(KIND)
	var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var states := [
		WorldReader.STATE_MOVE,
		WorldReader.STATE_WINDUP,
		WorldReader.STATE_ACTIVE,
		WorldReader.STATE_RECOVER
	]
	var worst := 0.0
	for k in 160:
		var st: int = states[mini(int(k / 30.0), 3)] if k < 120 else WorldReader.STATE_MOVE
		var p := clampf(float(k - 30) / 30.0, 0.0, 1.0) if st == WorldReader.STATE_WINDUP else 0.0
		if k == 135:
			assert_true(live.die() and vat.die(), "both fall")
		var mps := RUN_MPS if k < 30 else 0.0
		for a: HordeAvatar in [live, vat]:
			(a.get_parent() as Node3D).position.x += mps * DT
			a.apply_state({"tick": k, "state": st, "windup": p})
			a.advance(DT)
		assert_eq(vat.glow_energy(), live.glow_energy(), "tick %d: the glow" % k)
		var a_v := VatVerify.live_vertices(live)
		var b_v := VatVerify.eval_vertices_at(pose, mesh, vat.vat_grid_drives(), vat.vat_offset())
		for v in a_v.size():
			worst = maxf(worst, a_v[v].distance_to(b_v[v]))
	assert_lt(worst, 0.002, "the VAT pose follows the live one (%f m)" % worst)
	assert_true(vat.dying() and live.dying())
