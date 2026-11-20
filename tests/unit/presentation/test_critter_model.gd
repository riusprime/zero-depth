extends GutTest
## The Dust Mite, the Ember Flea and the Ice Crab on the owner's models (HordeAvatar with CritterModel, and the
## CritterCrowd that draws them in the game): each loads into its joints, small and simplified for the horde; each clip
## moves what it should (the mite's two sets of legs stepping, the flea's hop with its legs kicking and tucking and its
## glow pulsing, the crab's raised snapping claws, its side-on scuttle and slide, the hit's fling, the death's roll onto
## its back), nothing goes below the floor, reduced motion keeps them still at rest, a missing model falls back to the
## code body, the VAT bake matches the live pose within 2 mm, and the crowd plays the flinch and the death.

const DT := 1.0 / 60.0
const MITE := WorldReader.KIND_DUST_MITE
const FLEA := WorldReader.KIND_EMBER_FLEA
const CRAB := WorldReader.KIND_ICE_CRAB
const KINDS: Array[int] = [MITE, FLEA, CRAB]
const RUN_MPS := 4.8

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


## A critter under a holder node (what moves it on the ground), its own processing off; `vat`: the crowd's kind.
func _critter(kind: int, vat := false) -> HordeAvatar:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var a := HordeAvatar.new()
	a.vat = vat
	a.setup(kind)
	holder.add_child(a)
	a.set_process(false)
	return a


## `n` frames moving `mps` along +X (a MOVE state each); returns the next tick.
func _run(a: HordeAvatar, from: int, n: int, mps := 0.0) -> int:
	for k in n:
		(a.get_parent() as Node3D).position.x += mps * DT
		a.apply_state({"tick": from + k, "state": WorldReader.STATE_MOVE})
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


## Part `pname`'s lowest point (its mesh at rest, carried by its joints) in the avatar's space.
func _tip(a: HordeAvatar, pname: String) -> Vector3:
	var mi := (a.parts[pname] as Node3D).get_child(0) as MeshInstance3D
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tip := v[0]
	for p in v:
		if p.y < tip.y:
			tip = p
	return a.global_transform.affine_inverse() * (mi.global_transform * tip)


func _lowest(a: HordeAvatar) -> float:
	var lo := INF
	for v in VatVerify.live_vertices(a):
		lo = minf(lo, v.y)
	return lo


func test_each_model_is_cut_into_its_joints_small_and_simplified() -> void:
	ViewPrefs.reduced_motion = true  # (at rest: no hop, no bob)
	var limbs := {MITE: 8, FLEA: 6, CRAB: 10}
	for kind in KINDS:
		var a := _critter(kind)
		_run(a, 0, 1)
		assert_true(a.has_model(), "kind %d: the owner's model" % kind)
		assert_eq(
			(a.get_meta(&"critter_limbs") as Array).size(), limbs[kind], "kind %d limbs" % kind
		)
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for v in VatVerify.live_vertices(a):
			lo = lo.min(v)
			hi = hi.max(v)
		var h: float = EnemyModels.SPECS[CritterModel.KINDS[kind]]["height"]
		assert_almost_eq(hi.y - lo.y, h, 0.02, "kind %d: %s .. %s" % [kind, lo, hi])
		assert_lte(
			h, float(CritterBodies.HEIGHTS[kind]), "kind %d no taller than its code body" % kind
		)
		assert_lt(maxf(hi.x - lo.x, hi.z - lo.z), 0.5, "kind %d small across" % kind)
		assert_almost_eq(lo.y, 0.0, 0.015, "kind %d on the ground" % kind)
		var tris := 0
		for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_len(s) / 3
		assert_between(tris, 1300, 1700, "kind %d for the horde: %d triangles" % [kind, tris])
	var flea := _critter(FLEA)
	for p: String in ["thigh_r", "thigh_l", "shin_r", "shin_l", "thigh_r_g"]:
		assert_true(flea.parts.has(p), p)
	assert_eq(
		(flea.parts["shin_r"] as Node3D).get_parent(),
		flea.parts["thigh_r"],
		"the shin on its thigh"
	)
	var crab := _critter(CRAB)
	assert_true(crab.parts.has("claw_r") and crab.parts.has("claw_l_g"), "the crab's claws")


func test_the_mite_scuttles_in_two_sets_lifting_each_foot() -> void:
	var a := _critter(MITE)
	var t := _run(a, 0, 30, RUN_MPS)
	var lifted := {}
	var apart := 0
	var low := 1.0
	for k in 40:
		t = _run(a, t, 1, RUN_MPS)
		var r1 := _tip(a, "leg_r1").y
		var r2 := _tip(a, "leg_r2").y
		if absf(r1 - r2) > 0.006:
			apart += 1
		for limb: Array in a.get_meta(&"critter_limbs"):
			var y := _tip(a, limb[0]).y
			low = minf(low, y)
			if y > 0.012:
				lifted[limb[0]] = true
	assert_eq(lifted.size(), 8, "every foot lifts in its step: %s" % [lifted])
	assert_gt(apart, 8, "neighbouring legs step in turn")
	assert_gt(low, -0.01, "no foot through the floor (%f)" % low)


func test_the_mite_shuffles_at_rest() -> void:
	var a := _critter(MITE)
	var t := _run(a, 0, 40)
	var g0 := (a.parts["leg_r2_g"] as Node3D).transform
	_run(a, t, 13)
	assert_ne((a.parts["leg_r2_g"] as Node3D).transform, g0, "the feet shuffle")


func test_the_flea_hops_kicks_tucks_and_pulses() -> void:
	var a := _critter(FLEA)
	var t := _run(a, 0, 2)
	var hi := 0.0
	var lo := 1.0
	var thigh := {}
	var front := {}
	var glow := {}
	for k in 48:
		t = _run(a, t, 1, RUN_MPS)
		hi = maxf(hi, a.body.position.y)
		lo = minf(lo, a.body.position.y)
		thigh[snappedf((a.parts["thigh_r_g"] as Node3D).rotation.z, 0.05)] = true
		front[snappedf((a.parts["fleg_r1_g"] as Node3D).transform.basis.get_euler().length(), 0.05)] = true
		glow[snappedf(a.glow_energy(), 0.05)] = true
	assert_gt(hi, CritterBodies.HOP_M * 0.8, "it hops up")
	assert_lt(lo, 0.03, "and lands")
	assert_gt(thigh.size(), 6, "the back legs kick and fold: %s" % [thigh.keys()])
	assert_gt(front.size(), 4, "the front legs tuck and reach")
	assert_gt(glow.size(), 4, "its glow pulses")


func test_the_crab_snaps_its_raised_claws_turns_side_on_and_slides() -> void:
	var a := _critter(CRAB)
	var t := _run(a, 0, 20)
	var claw := {}
	for k in 45:
		t = _run(a, t, 1)
		claw[snappedf((a.parts["claw_r"] as Node3D).transform.basis.get_euler().y, 0.04)] = true
		assert_gt((a.parts["claw_r_g"] as Node3D).rotation.z, 0.2, "its claws held up")
	assert_gt(claw.size(), 5, "its claws snap at rest: %s" % [claw.keys()])
	t = _run(a, t, 40, RUN_MPS)
	assert_gt(a.body.rotation.y, CritterModel.SIDE_YAW * 0.7, "it scuttles side-on")
	var x0 := a.body.position.x
	var slid := 0.0
	for k in 20:
		t = _run(a, t, 1)
		slid = maxf(slid, a.body.position.x - x0)
	assert_gt(slid, CritterBodies.SLIDE_M * 0.6, "it slides as it stops")


func test_a_hit_flings_the_limbs() -> void:
	for kind in KINDS:
		var a := _critter(kind)
		var t := _run(a, 0, 20)
		var limb: String = (a.get_meta(&"critter_limbs") as Array)[0][0]
		var rest := (a.parts[limb] as Node3D).transform
		a.flinch(Vector2(-1, 0), 1.0)
		_run(a, t, 3)
		assert_ne((a.parts[limb] as Node3D).transform, rest, "kind %d: %s flung" % [kind, limb])


func test_the_death_rolls_it_over_curls_its_legs_and_puts_out_the_eye() -> void:
	for kind in KINDS:
		var a := _critter(kind)
		_run(a, 0, 20)
		var glow := a.glow_energy()
		assert_true(a.die(), "kind %d: the model falls" % kind)
		var low := 1.0
		for k in roundi(HordeAvatar.DEATH_SECONDS / DT):
			a.advance(DT)
			low = minf(low, _lowest(a))
		assert_true(a.dying())
		var roll := a.body.transform.basis.orthonormalized().get_euler().x
		assert_lt(roll, -1.5, "kind %d rolled over (%f)" % [kind, roll])
		var limb: String = (a.get_meta(&"critter_limbs") as Array)[-1][0]
		var curl := (a.parts[limb + "_g"] as Node3D).transform.basis.get_rotation_quaternion()
		assert_gt(curl.get_angle(), 0.5, "kind %d: its legs curled" % kind)
		assert_lt(a.glow_energy(), glow * 0.05, "kind %d: the eye goes out" % kind)
		assert_gt(low, -0.02, "kind %d: not through the floor as it falls (%f)" % [kind, low])


func test_nothing_goes_below_the_floor_while_it_lives() -> void:
	for kind in KINDS:
		var a := _critter(kind)
		var t := _run(a, 0, 5)
		var low := 1.0
		for k in 90:
			t = _run(a, t, 1, RUN_MPS if k < 50 else 0.0)
			if k % 20 == 3:
				a.flinch(Vector2(-1, 0.2), 1.0)
			low = minf(low, _lowest(a))
		assert_gt(low, -0.01, "kind %d: the lowest point %f m" % [kind, low])


func test_reduced_motion_keeps_them_still_at_rest() -> void:
	ViewPrefs.reduced_motion = true
	for kind in KINDS:
		var a := _critter(kind)
		var t := _run(a, 0, 30)
		var limb: String = (a.get_meta(&"critter_limbs") as Array)[0][0]
		var g0 := (a.parts[limb + "_g"] as Node3D).transform
		var n0 := (a.parts[limb] as Node3D).transform
		var b0 := a.body.transform
		var e0 := a.glow_energy()
		_run(a, t, 20)
		assert_eq((a.parts[limb + "_g"] as Node3D).transform, g0, "kind %d: no shuffle" % kind)
		assert_eq((a.parts[limb] as Node3D).transform, n0, "kind %d: no snapping" % kind)
		assert_eq(a.body.transform, b0, "kind %d: no bob, no hop" % kind)
		assert_eq(a.glow_energy(), e0, "kind %d: no pulse" % kind)


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var code_part := {MITE: "legs_a", FLEA: "legs", CRAB: "claw_l"}
	for kind in KINDS:
		var a := _critter(kind)
		assert_false(a.has_model(), "kind %d" % kind)
		assert_false(CritterModel.on_model(kind))
		assert_true(a.parts.has(code_part[kind]), "kind %d: the code body" % kind)
		assert_true(VatCrowd.supports(kind), "kind %d: still drawn through VAT" % kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		assert_gt(mesh.surface_get_array_len(0), 0, "kind %d: its code body bakes" % kind)


func test_the_vat_bake_matches_the_live_pose() -> void:
	for kind in KINDS:
		var pose := VatBake.pose_for(kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_avatar(kind, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(kind) as HordeAvatar
		assert_eq(pose["key"], "horde%d" % kind, "the horde path's bake")
		assert_eq(int(pose["drives"]), 4, "four drives")
		for calm: bool in [false, true]:
			ViewPrefs.reduced_motion = calm
			var e := VatVerify.pose_error_full(live, vat, pose, mesh, 60, 31)
			assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
			assert_lt(
				float(e["max_m"]), 0.002, "kind %d within 2 mm (calm %s): %s" % [kind, calm, e]
			)
		live.free()
		vat.free()


## A VAT avatar's pose (its drives and body offset into the bake) follows the live one through a run, a stop, hits and
## a death.
func test_a_vat_critter_keeps_the_live_pose_through_a_run_and_a_death() -> void:
	for kind in KINDS:
		var live := _critter(kind)
		var vat := _critter(kind, true)
		var pose := VatBake.pose_for(kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var worst := 0.0
		for k in 110:
			if k == 85:
				assert_true(live.die() and vat.die(), "both fall")
			for a: HordeAvatar in [live, vat]:
				(a.get_parent() as Node3D).position.x += (RUN_MPS if k < 50 else 0.0) * DT
				a.apply_state({"tick": k, "state": WorldReader.STATE_MOVE})
				a.advance(DT)
			assert_eq(
				vat.glow_energy(), live.glow_energy(), "kind %d tick %d: the glow" % [kind, k]
			)
			var a_v := VatVerify.live_vertices(live)
			var b_v := VatVerify.eval_vertices_at(
				pose, mesh, vat.vat_grid_drives(), vat.vat_offset()
			)
			for v in a_v.size():
				worst = maxf(worst, a_v[v].distance_to(b_v[v]))
		assert_lt(worst, 0.002, "kind %d: the VAT pose follows the live one (%f m)" % [kind, worst])


## The crowd (what the game draws them with): the legs' drive follows the walk, a hit flinches the instance, and one
## gone from the sim plays its death before it goes.
func test_the_crowd_walks_flinches_and_plays_the_death() -> void:
	ViewPrefs.enemy_vat = true
	var w := CombatLab.world()
	var ids: Array[int] = []
	for k in KINDS.size():
		ids.append(w.add_enemy(KINDS[k], Vector2(2.0 + k * 1.5, 3.0)))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	views.critters.advance(DT)
	var mite := ids[0]
	var rest: Vector4 = views.critters.instance_of(mite)["custom"]
	assert_almost_eq(rest.z, 0.5, 0.01, "at rest: the legs' drive at no pace")
	for f in 20:  # It runs
		w.actors.pos_x[w.actors.index_of(mite)] += RUN_MPS * DT
		views.sync(WorldReader.new(w))
		views.critters.advance(DT)
	var run: Vector4 = views.critters.instance_of(mite)["custom"]
	assert_gt(run.z, 0.75, "running: the legs' drive at a pace (%s)" % run)
	for id in ids:  # The crowd's inline reckoning is CritterModel's
		_assert_crowd_matches_the_model(views.critters, id)
	var b0: Basis = (views.critters.instance_of(ids[1])["xf"] as Transform3D).basis
	views.flash(ids[1])
	views.critters.advance(DT)
	views.critters.advance(DT)
	var hit: Vector4 = views.critters.instance_of(ids[1])["custom"]
	assert_gt(hit.x, 0.1, "a hit flings the flea's legs (%s)" % hit)
	assert_ne(
		(views.critters.instance_of(ids[1])["xf"] as Transform3D).basis, b0, "and squashes it"
	)
	w.actors.remove_sorted(PackedInt32Array([w.actors.index_of(ids[2])]))
	views.sync(WorldReader.new(w))
	views.critters.advance(DT)
	assert_eq(views.critters.count(), 2, "the dead crab is no longer live")
	assert_false(views.draws(ids[2]))
	assert_eq(views.critters.dying_count(), 1, "it dies")
	assert_eq(views.critters.drawn, 3, "still drawn, falling")
	for f in roundi(HordeAvatar.DEATH_SECONDS / DT) + 2:
		views.critters.advance(DT)
	assert_eq(views.critters.dying_count(), 0, "and goes")
	assert_eq(views.critters.drawn, 2)


## Critter `id`'s instance in `crowd` (live, unhit) as CritterModel reckons it from the same slot.
func _assert_crowd_matches_the_model(crowd: CritterCrowd, id: int) -> void:
	var k: int = crowd._slot_of[id]
	var kind := crowd._kind[k]
	var t := crowd._t[k]
	var ph := CritterModel.phase(kind, t, crowd._ph[k])
	var walk := crowd._walk[k]
	var body := CritterModel.body_xf(
		kind, t, ph, walk, crowd._slide[k], -1.0, 0.0, crowd._rise[k], false
	)
	var at := Vector3(crowd._lx[k], 0.0, -crowd._ly[k])  # (where it was drawn)
	var want := Transform3D(Basis(Vector3.UP, crowd._yaw1[k]), at) * body
	var got: Dictionary = crowd.instance_of(id)
	assert_true((got["xf"] as Transform3D).is_equal_approx(want), "kind %d: the body" % kind)
	var d := CritterModel.grid_of(CritterModel.drives(kind, t, ph, walk, -1.0, 0.0, false))
	assert_true((got["custom"] as Vector4).is_equal_approx(d), "kind %d: the drives %s" % [kind, d])
	var e := CritterModel.energy(kind, t, crowd._rise[k], -1.0, false)
	assert_almost_eq((got["color"] as Color).a, e, 1e-5, "kind %d: the glow" % kind)
