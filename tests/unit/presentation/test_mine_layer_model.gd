extends GutTest
## The Mine Layer on the owner's model (HordeAvatar posed by MineLayerModel): its parts load into the rig's chain,
## each clip moves the parts it should (the scuttle and the sidestep with planted feet, the idle never still, the
## drop's windup, the mine out through the hatch and a new one grown back, a hit, the rise-in, the death rolling it
## over with its legs flailing), the knees stay off the floor, reduced motion moves less, a missing model falls back to
## the code body, and the VAT bake (its own rig, five drives) matches the live pose.

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_MINE_LAYER

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


## A Mine Layer under a facing node under an actor node (as ActorViews builds one), its own processing off.
func _layer(yaw := 0.0) -> HordeAvatar:
	var actor := Node3D.new()
	add_child_autofree(actor)
	var facing := Node3D.new()
	facing.rotation.y = yaw
	actor.add_child(facing)
	var a := HordeAvatar.new()
	a.setup(KIND)
	facing.add_child(a)
	a.set_process(false)
	return a


## `n` ticks of `state` (apply_state, then a frame); the actor moves `step` (m, world) a tick.
func _run(
	a: HordeAvatar, from: int, n: int, state := WorldReader.STATE_MOVE, step := Vector3.ZERO
) -> int:
	var actor := a.get_parent().get_parent() as Node3D
	for k in n:
		actor.position += step
		a.apply_state({"tick": from + k, "state": state})
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


## Leg `k`'s claw tip in the world.
func _tip(a: HordeAvatar, k: int) -> Vector3:
	var leg: StringName = MineLayerModel.LEGS[k]
	var low := a.parts["leg_%s_l" % leg] as Node3D
	return low.global_transform * (MineLayerModel.TIPS[k] - MineLayerModel.pivot("leg_%s_l" % leg))


func _knee(a: HordeAvatar, k: int) -> Vector3:
	return (a.parts["leg_%s_l" % MineLayerModel.LEGS[k]] as Node3D).global_position


func test_the_owner_s_model_is_cut_into_the_rig_s_chain() -> void:
	var a := _layer()
	assert_true(a.has_model(), "the owner's model")
	for pname: String in ["breath", "body", "head", "hopper", "hatch", "mine"]:
		assert_true(a.parts.has(pname), pname)
	assert_eq(
		(a.parts["hatch"] as Node).get_parent(), a.parts["hopper"], "the hatch hangs on the hopper"
	)
	assert_eq(
		(a.parts["mine"] as Node).get_parent(), a.parts["hopper"], "the mine sits in the hopper"
	)
	assert_eq((a.parts["head"] as Node).get_parent(), a.parts["body"], "the head on the body")
	for leg: StringName in MineLayerModel.LEGS:
		var low := a.parts["leg_%s_l" % leg] as Node
		assert_eq(
			low.get_parent(), a.parts["leg_%s_u" % leg], "leg %s: the lower half on the upper" % leg
		)
	var tris := 0
	for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		tris += mi.mesh.get_faces().size() / 3
	assert_lt(tris, 3800, "about 3k triangles (with the caps): %d" % tris)
	assert_eq(BatchAvatars.class_of(a), 0, "a node avatar is not native")


func test_the_scuttle_plants_its_feet() -> void:
	var a := _layer()
	var step := Vector3(2.4 / 60.0, 0, 0)
	var t := _run(a, 0, 40, WorldReader.STATE_MOVE, step)
	var worst := 0.0
	var down := 0
	var lifted := 0
	var last: Array[Vector3] = []
	for k in 6:
		last.append(_tip(a, k))
	for f in 40:
		t = _run(a, t, 1, WorldReader.STATE_MOVE, step)
		for k in 6:
			var tip := _tip(a, k)
			var q := fposmod(a._walk_t - float(MineLayerModel.STRIDE_AT[k]), 1.0)
			if q > 0.08 and q < MineLayerModel.DUTY - 0.08:
				down += 1
				worst = maxf(worst, Vector2(tip.x - last[k].x, tip.z - last[k].z).length())
				assert_lt(tip.y, 0.02, "a planted claw is on the ground")
			elif tip.y > 0.015:
				lifted += 1
			last[k] = tip
	assert_gt(down, 40)
	assert_gt(lifted, 20, "the swinging feet lift")
	assert_lt(worst, 0.006, "a planted claw keeps still on the ground: %.4f m a frame" % worst)


func test_it_sidesteps_and_backs_off_on_planted_feet() -> void:
	for way: Vector3 in [Vector3(0, 0, 1), Vector3(-1, 0, 0)]:
		var a := _layer(0.6)
		var step := way * 2.0 / 60.0
		var t := _run(a, 0, 40, WorldReader.STATE_MOVE, step)
		var worst := 0.0
		var last := _tip(a, 2)
		for f in 30:
			t = _run(a, t, 1, WorldReader.STATE_MOVE, step)
			var tip := _tip(a, 2)
			var q := fposmod(a._walk_t - float(MineLayerModel.STRIDE_AT[2]), 1.0)
			if q > 0.08 and q < MineLayerModel.DUTY - 0.08:
				worst = maxf(worst, Vector2(tip.x - last.x, tip.z - last.z).length())
			last = tip
		assert_lt(worst, 0.006, "going %s, a planted claw keeps still: %.4f m" % [way, worst])


func test_the_idle_is_never_still_and_its_feet_stay_down() -> void:
	var a := _layer()
	var t := _run(a, 0, 30)
	var head := (a.parts["head"] as Node3D).transform
	var breath := (a.parts["breath"] as Node3D).transform
	var tip := _tip(a, 0)
	t = _run(a, t, 50)
	assert_ne((a.parts["head"] as Node3D).transform, head, "the head looks round")
	assert_ne((a.parts["breath"] as Node3D).transform, breath, "it breathes")
	assert_lt(_tip(a, 0).distance_to(tip), 0.002, "the feet stay where they are")


func test_the_windup_tips_the_hopper_opens_the_hatch_and_rolls_the_mine_back() -> void:
	var a := _layer()
	var t := _run(a, 0, 30)
	var hatch := (a.parts["hatch"] as Node3D).transform
	var mine := (a.parts["mine"] as Node3D).position
	t = _run(a, t, 30, WorldReader.STATE_WINDUP)
	assert_gt(a.windup_pose(), 0.9)
	var open := (a.parts["hatch"] as Node3D).transform.basis.get_euler().z
	assert_gt(open, hatch.basis.get_euler().z + 0.3, "the hatch eases open")
	assert_gt(
		(a.parts["hopper"] as Node3D).transform.basis.get_euler().z, 0.15, "the hopper tips back"
	)
	assert_lt((a.parts["mine"] as Node3D).position.x, mine.x - 0.02, "the mine rolls to the hatch")


func test_the_mine_drops_through_the_hatch_and_a_new_one_grows_back() -> void:
	var a := _layer()
	var t := _run(a, 0, 30)
	t = _run(a, t, 30, WorldReader.STATE_WINDUP)
	t = _run(a, t, 1, WorldReader.STATE_ACTIVE)
	var gone := false
	var flung := 0.0
	for k in 30:
		t = _run(a, t, 1, WorldReader.STATE_RECOVER)
		var s := (a.parts["mine"] as Node3D).transform.basis.get_scale().x
		gone = gone or s < 0.01
		flung = maxf(flung, (a.parts["hatch"] as Node3D).transform.basis.get_euler().z)
	assert_true(gone, "the mine went out")
	assert_gt(flung, 1.0, "the hatch was flung open")
	t = _run(a, t, 30)
	assert_almost_eq(
		(a.parts["mine"] as Node3D).transform.basis.get_scale().x, 1.0, 0.01, "a new mine"
	)
	assert_almost_eq((a.parts["hatch"] as Node3D).transform.basis.get_euler().z, 0.0, 0.01, "shut")


func test_it_climbs_out_of_the_ground() -> void:
	var a := _layer()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN})
	var t := _run(a, 1, 3, WorldReader.STATE_SPAWN)
	assert_lt(a.body.position.y, -0.3, "under the floor")
	_run(a, t, 40)
	assert_almost_eq(a.body.position.y, 0.0, 0.001, "risen")


func test_the_death_rolls_it_over_with_its_legs_flailing() -> void:
	var a := _layer()
	_run(a, 0, 30)
	var knee := (a.parts["leg_fr_u"] as Node3D).transform
	assert_true(a.die(), "the owner's model plays a death")
	for k in roundi(HordeAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_gt(absf(a.model.rotation.x), 2.0, "on its back")
	assert_gt(a.body.position.y, 0.1, "rolled over the ground, not through it")
	assert_ne((a.parts["leg_fr_u"] as Node3D).transform, knee, "the legs flail")


func test_the_knees_stay_off_the_floor() -> void:
	var a := _layer()
	var lowest := 9.0
	var t := 0
	for plan: Array in [
		[WorldReader.STATE_MOVE, 60, Vector3(2.4 / 60.0, 0, 0)],
		[WorldReader.STATE_MOVE, 40, Vector3(0, 0, -2.0 / 60.0)],
		[WorldReader.STATE_WINDUP, 30, Vector3.ZERO],
		[WorldReader.STATE_ACTIVE, 1, Vector3.ZERO],
		[WorldReader.STATE_RECOVER, 24, Vector3.ZERO],
	]:
		for k in int(plan[1]):
			t = _run(a, t, 1, plan[0], plan[2])
			for j in 6:
				lowest = minf(lowest, _knee(a, j).y)
	assert_gt(lowest, 0.08, "the knees stay over the floor: lowest %.3f m" % lowest)


func test_reduced_motion_idles_slower_and_never_flails() -> void:
	var swings := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _layer()
		var t := _run(a, 0, 20)
		var h0 := (a.parts["head"] as Node3D).transform.basis.get_euler().y
		var moved := 0.0
		for k in 60:
			t = _run(a, t, 1)
			moved = maxf(
				moved, absf((a.parts["head"] as Node3D).transform.basis.get_euler().y - h0)
			)
		swings.append(moved)
		var phase := a._walk_t
		a.die()
		for k in 12:
			a.advance(DT)
		if calm:
			assert_eq(a._walk_t, phase, "no flailing")
		else:
			assert_gt(a._walk_t, phase + 0.5, "the legs flail")
	assert_gt(swings[1], 0.0, "it still looks round")
	assert_lt(swings[1], swings[0], "but slower")


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _layer()
	assert_false(a.has_model())
	assert_true(a.parts.has("hopper") and a.parts.has("mine"), "the code body's hopper and mine")
	assert_false(VatCrowd.supports(KIND), "the code body stays off the VAT crowd")
	assert_eq(BatchAvatars.class_of(a), 0)


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "drawn by the VAT crowd")
	assert_true(EnemyBatch.KINDS.has(KIND), "on the batched path")
	var pose := VatBake.pose_for(KIND)
	assert_eq(pose["drives"], 5, "five drives: one in the drive texture")
	assert_true(pose.has("albedo_tex"), "the owner's colour map")
	var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var live := VatBake.reference_avatar(KIND, Color(0, 0, 0, 0), 0.0)
		var vat := HordeAvatar.new()
		vat.vat = true
		vat.setup(KIND)
		var e := VatVerify.pose_error_full(live, vat, pose, mesh, 300, 23)
		assert_lt(float(e["max_m"]), 0.002, "within 2 mm (calm %s): %s" % [calm, e])
		assert_eq(vat.vat_grid_drives().size(), 5)
		live.free()
		vat.free()


func test_a_vat_mine_layer_is_native_and_keeps_the_live_drives() -> void:
	var live := _layer()
	var vat := HordeAvatar.new()
	vat.vat = true
	vat.setup(KIND)
	var facing := Node3D.new()
	(live.get_parent().get_parent() as Node3D).add_child(facing)
	facing.add_child(vat)
	vat.set_process(false)
	assert_eq(
		BatchAvatars.class_of(vat), BatchAvatars.CLASS_OF[KIND], "a VAT Mine Layer runs native"
	)
	var t := 0
	for plan: Array in [
		[WorldReader.STATE_MOVE, 40, Vector3(2.4 / 60.0, 0, 0)],
		[WorldReader.STATE_WINDUP, 30, Vector3.ZERO],
		[WorldReader.STATE_ACTIVE, 1, Vector3.ZERO],
		[WorldReader.STATE_RECOVER, 24, Vector3.ZERO],
	]:
		for k in int(plan[1]):
			t = _run(live, t, 1, plan[0], plan[2])
			vat.apply_state({"tick": t - 1, "state": plan[0]})
			vat.advance(DT)
			assert_eq(vat.vat_grid_drives(), live.vat_grid_drives(), "tick %d: drives" % t)
			assert_eq(vat.glow_energy(), live.glow_energy(), "tick %d: glow" % t)
