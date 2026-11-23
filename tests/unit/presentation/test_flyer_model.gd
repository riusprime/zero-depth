extends GutTest
## The Cave Bat and the Star Mote on the owner's models (HordeAvatar with FlyerModel through CritterModel, and the
## CritterCrowd that draws them in the game): each loads into its joints, small and simplified for the horde; the bat's
## wings beat with a quicker downstroke, its body bobs with the beat, banks into a turn and glides now and then at
## idle; the mote spins its points, wobbles its tail, bobs, drifts, tilts into its travel and pulses; the hit flings and
## flares; the bat's death folds its wings and drops it to the floor, the mote's flares, breaks it apart and shrinks it;
## nothing goes below the floor; reduced motion (an even beat, nothing else moving); a missing model falls back to the
## code body; the VAT bake matches the live pose within 2 mm; and the crowd reckons the same and plays the death.

const DT := 1.0 / 60.0
const BAT := WorldReader.KIND_CAVE_BAT
const MOTE := WorldReader.KIND_STAR_MOTE
const KINDS: Array[int] = [BAT, MOTE]
const RUN_MPS := 4.0

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


func _flyer(kind: int, vat := false) -> HordeAvatar:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var a := HordeAvatar.new()
	a.vat = vat
	a.setup(kind)
	holder.add_child(a)
	a.set_process(false)
	return a


## `n` frames moving `mps` along +X and turning `turn` rad a second (a MOVE state each); returns the next tick.
func _run(a: HordeAvatar, from: int, n: int, mps := 0.0, turn := 0.0) -> int:
	for k in n:
		var holder := a.get_parent() as Node3D
		holder.position.x += mps * DT
		holder.rotation.y += turn * DT
		a.apply_state({"tick": from + k, "state": WorldReader.STATE_MOVE})
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


func _lowest(a: HordeAvatar) -> float:
	var lo := INF
	for v in VatVerify.live_vertices(a):
		lo = minf(lo, v.y)
	return lo


## The right wing's tip height in the avatar's space (its outer wing's farthest point out).
func _wing_tip_y(a: HordeAvatar) -> float:
	var mi := (a.parts["wtip_r"] as Node3D).get_child(0) as MeshInstance3D
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var far := v[0]
	for p in v:
		if p.z > far.z:
			far = p
	return (a.global_transform.affine_inverse() * (mi.global_transform * far)).y


func test_each_model_is_cut_into_its_joints_small_and_simplified() -> void:
	for kind in KINDS:
		var a := _flyer(kind)
		_run(a, 0, 1)
		assert_true(a.has_model(), "kind %d: the owner's model" % kind)
		assert_true(CritterModel.on_model(kind))
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for v in VatVerify.live_vertices(a):
			lo = lo.min(v)
			hi = hi.max(v)
		var h: float = EnemyModels.SPECS[FlyerModel.KINDS[kind]]["height"]
		var fly := CritterBodies.BAT_FLY_M if kind == BAT else CritterBodies.MOTE_FLOAT_M
		assert_lte(
			h + fly, float(CritterBodies.HEIGHTS[kind]), "kind %d no taller in flight" % kind
		)
		assert_lt(maxf(hi.x - lo.x, hi.z - lo.z), 0.6, "kind %d small across" % kind)
		assert_gt(lo.y, fly * 0.4, "kind %d off the ground" % kind)
		var tris := 0
		for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_len(s) / 3
		assert_between(tris, 1300, 1800, "kind %d for the horde: %d triangles" % [kind, tris])
	var bat := _flyer(BAT)
	for side: String in ["r", "l"]:
		assert_eq((bat.parts["wing_" + side] as Node3D).get_parent(), bat.parts["wing_%s_g" % side])
		assert_eq((bat.parts["wtip_" + side] as Node3D).get_parent(), bat.parts["wing_" + side])
	var mote := _flyer(MOTE)
	for k in 5:
		assert_true(mote.parts.has("pt_%d" % (k + 1)), "point %d" % (k + 1))
	assert_eq((mote.parts["tail_2"] as Node3D).get_parent(), mote.parts["tail_1"])
	assert_eq((mote.parts["tail_3"] as Node3D).get_parent(), mote.parts["tail_2"])
	assert_eq(FlyerModel.joints(bat).size(), 6)
	assert_eq(FlyerModel.joints(mote).size(), 9)


func test_the_bat_beats_down_faster_than_up_and_bobs_with_the_beat() -> void:
	var a := _flyer(BAT)
	var t := _run(a, 0, 20, RUN_MPS)
	var down := 0
	var up := 0
	var y0 := _wing_tip_y(a)
	var lo := 9.0
	var hi := -9.0
	for k in 120:
		t = _run(a, t, 1, RUN_MPS)
		var y := _wing_tip_y(a)
		if y < y0:
			down += 1
		else:
			up += 1
		y0 = y
		lo = minf(lo, a.body.position.y)
		hi = maxf(hi, a.body.position.y)
	assert_lt(
		float(down), up * 0.8, "the downstroke is quicker (%d frames down, %d up)" % [down, up]
	)
	assert_gt(hi - lo, FlyerModel.BEAT_BOB, "the body rises and falls with the beat")
	assert_gt(lo, CritterBodies.BAT_FLY_M * 0.85, "in flight")


func test_the_bat_banks_into_a_turn() -> void:
	var a := _flyer(BAT)
	var t := _run(a, 0, 10, RUN_MPS)
	_run(a, t, 30, RUN_MPS, 3.0)  # Turning to its left
	var right := a.body.transform.basis.z
	assert_gt(right.y, 0.15, "the right wing up, the left down (%s)" % right)


func test_the_bat_glides_now_and_then_at_idle() -> void:
	var a := _flyer(BAT)
	var t := _run(a, 0, 10)
	var g := a.parts["wing_r_g"] as Node3D
	var last := g.transform.basis.z.y
	var held := 0
	var longest := 0
	for k in 300:
		t = _run(a, t, 1)
		var now := g.transform.basis.z.y
		held = held + 1 if absf(now - last) < 0.012 else 0
		longest = maxi(longest, held)
		last = now
	assert_gt(longest, 15, "the wings held spread for a while (%d frames)" % longest)


func test_the_mote_spins_wobbles_bobs_tilts_and_pulses() -> void:
	var a := _flyer(MOTE)
	var t := _run(a, 0, 5)
	var pts := {}
	var tail := {}
	var bod := {}
	var glow := {}
	for k in 60:
		t = _run(a, t, 1)
		pts[snappedf(a.body.transform.basis.y.z, 0.02)] = true
		tail[snappedf((a.parts["tail_1_g"] as Node3D).transform.basis.get_euler().y, 0.02)] = true
		bod[snappedf(a.body.position.y, 0.002)] = true
		glow[snappedf(a.glow_energy(), 0.05)] = true
	assert_gt(pts.size(), 8, "the star spins")
	assert_gt(tail.size(), 8, "its tail wobbles")
	assert_gt(bod.size(), 8, "it bobs")
	assert_gt(glow.size(), 4, "its glow pulses")
	_run(a, t, 40, RUN_MPS)
	assert_lt(a.body.transform.basis.x.y, -0.15, "it tilts into its travel")


func test_a_hit_flings_and_flares() -> void:
	for kind in KINDS:
		var a := _flyer(kind)
		ViewPrefs.reduced_motion = true  # (only the hit moves)
		var t := _run(a, 0, 20)
		var pname := "wing_r" if kind == BAT else "tail_1"
		var rest := (a.parts[pname] as Node3D).transform
		var e := a.glow_energy()
		a.flinch(Vector2(-1, 0), 1.0)
		_run(a, t, 3)
		assert_ne((a.parts[pname] as Node3D).transform, rest, "kind %d: %s flung" % [kind, pname])
		if kind == MOTE:
			assert_gt(a.glow_energy(), e * 1.3, "the mote flares")
		ViewPrefs.reduced_motion = false


func test_the_bat_folds_its_wings_and_drops_to_the_floor() -> void:
	var a := _flyer(BAT)
	_run(a, 0, 20, RUN_MPS)
	assert_true(a.die())
	var low := 1.0
	for k in roundi(HordeAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
		low = minf(low, _lowest(a))
	assert_true(a.dying())
	assert_lt(a.body.position.y, 0.03, "on the floor (%f)" % a.body.position.y)
	assert_gt(low, -0.02, "not through it (%f)" % low)
	var fold := (a.parts["wing_r_g"] as Node3D).transform.basis.get_rotation_quaternion()
	assert_gt(fold.get_angle(), 1.0, "its wings folded")
	assert_lt(a.glow_energy(), 0.05, "the eye goes out")


func test_the_mote_flares_breaks_apart_and_shrinks() -> void:
	var a := _flyer(MOTE)
	_run(a, 0, 20)
	var e := a.glow_energy()
	var p0 := (a.parts["pt_1"] as Node3D).position
	assert_true(a.die())
	var flare := 0.0
	for k in roundi(HordeAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
		flare = maxf(flare, a.glow_energy())
	assert_gt(flare, e * 1.5, "it flares")
	assert_gt((a.parts["pt_1"] as Node3D).position.distance_to(p0), 0.06, "its points break off")
	assert_lt(a.body.transform.basis.get_scale().x, 0.4, "it shrinks away")
	assert_lt(a.glow_energy(), 0.05, "and goes out")


func test_nothing_goes_below_the_floor_while_it_lives() -> void:
	for kind in KINDS:
		var a := _flyer(kind)
		var t := _run(a, 0, 5)
		var low := 1.0
		for k in 120:
			t = _run(a, t, 1, RUN_MPS if k < 60 else 0.0, 4.0 if k < 30 else 0.0)
			if k % 20 == 3:
				a.flinch(Vector2(-1, 0.2), 1.0)
			low = minf(low, _lowest(a))
		assert_gt(low, 0.1, "kind %d: the lowest point %f m" % [kind, low])


func test_reduced_motion_an_even_beat_and_a_still_mote() -> void:
	ViewPrefs.reduced_motion = true
	var a := _flyer(BAT)
	var t := _run(a, 0, 20)
	var y0 := _wing_tip_y(a)
	var down := 0
	var up := 0
	var b0 := a.body.transform
	for k in 150:
		t = _run(a, t, 1)
		var y := _wing_tip_y(a)
		if y < y0:
			down += 1
		else:
			up += 1
		y0 = y
		assert_eq(a.body.transform, b0, "no bob, no hover")
	assert_almost_eq(float(down), float(up), 12.0, "an even beat (%d down, %d up)" % [down, up])
	var m := _flyer(MOTE)
	t = _run(m, 0, 20)
	var p0 := (m.parts["tail_1_g"] as Node3D).transform
	var t0 := (m.parts["tail_2"] as Node3D).transform
	var mb := m.body.transform
	var e0 := m.glow_energy()
	_run(m, t, 30)
	assert_eq((m.parts["tail_1_g"] as Node3D).transform, p0, "no spin")
	assert_eq((m.parts["tail_2"] as Node3D).transform, t0, "no wobble")
	assert_eq(m.body.transform, mb, "no bob or drift")
	assert_eq(m.glow_energy(), e0, "no pulse")


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var code_part := {BAT: "wing_l", MOTE: "tail"}
	for kind in KINDS:
		var a := _flyer(kind)
		assert_false(a.has_model(), "kind %d" % kind)
		assert_false(CritterModel.on_model(kind))
		assert_true(a.parts.has(code_part[kind]), "kind %d: the code body" % kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		assert_gt(mesh.surface_get_array_len(0), 0, "kind %d: its code body bakes" % kind)


func test_the_vat_bake_matches_the_live_pose() -> void:
	for kind in KINDS:
		var pose := VatBake.pose_for(kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_avatar(kind, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(kind) as HordeAvatar
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


func test_a_vat_flyer_keeps_the_live_pose_through_a_flight_and_a_death() -> void:
	for kind in KINDS:
		var live := _flyer(kind)
		var vat := _flyer(kind, true)
		var pose := VatBake.pose_for(kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var worst := 0.0
		for k in 110:
			if k == 85:
				assert_true(live.die() and vat.die(), "both fall")
			for a: HordeAvatar in [live, vat]:
				var holder := a.get_parent() as Node3D
				holder.position.x += (RUN_MPS if k < 50 else 0.0) * DT
				holder.rotation.y += (2.0 if k < 30 else 0.0) * DT
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


func test_the_crowd_flies_banks_flinches_and_plays_the_death() -> void:
	ViewPrefs.enemy_vat = true
	var w := CombatLab.world()
	var ids: Array[int] = []
	for k in KINDS.size():
		ids.append(w.add_enemy(KINDS[k], Vector2(2.0 + k * 1.5, 3.0)))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	views.critters.advance(DT)
	var bat := ids[0]
	var bi := w.actors.index_of(bat)
	for f in 30:  # It flies and turns
		w.actors.pos_x[bi] += RUN_MPS * DT
		w.actors.facing[bi] = (w.actors.facing[bi] + 34) % 4096
		views.sync(WorldReader.new(w))
		views.critters.advance(DT)
	var k: int = views.critters._slot_of[bat]
	assert_gt(absf(views.critters._bank[k]), 0.1, "it banks (%f)" % views.critters._bank[k])
	views.sync(WorldReader.new(w))  # (its facing held a tick: the instance's facing is the last one, whatever the
	views.critters.advance(DT)  # frame's interpolation)
	for id in ids:
		_assert_crowd_matches_the_model(views.critters, id)
	views.flash(ids[1])
	views.critters.advance(DT)
	views.critters.advance(DT)
	assert_gt((views.critters.instance_of(ids[1])["custom"] as Vector4).x, 0.1, "a hit flinches")
	w.actors.remove_sorted(PackedInt32Array([w.actors.index_of(ids[1])]))
	views.sync(WorldReader.new(w))
	views.critters.advance(DT)
	assert_eq(views.critters.dying_count(), 1, "the mote dies")
	assert_eq(views.critters.drawn, 2, "still drawn, breaking apart")
	for f in roundi(HordeAvatar.DEATH_SECONDS / DT) + 2:
		views.critters.advance(DT)
	assert_eq(views.critters.dying_count(), 0, "and goes")
	assert_eq(views.critters.drawn, 1)


## Flyer `id`'s instance in `crowd` (live, unhit) as FlyerModel reckons it from the same slot.
func _assert_crowd_matches_the_model(crowd: CritterCrowd, id: int) -> void:
	var k: int = crowd._slot_of[id]
	var kind := crowd._kind[k]
	var t := crowd._t[k]
	var ph := crowd._ph[k]
	var walk := crowd._walk[k]
	var body := FlyerModel.body_xf(
		kind, t, ph, walk, crowd._bank[k], -1.0, 0.0, crowd._rise[k], false
	)
	var at := Vector3(crowd._lx[k], 0.0, -crowd._ly[k])
	var want := Transform3D(Basis(Vector3.UP, crowd._yaw1[k]), at) * body
	var got: Dictionary = crowd.instance_of(id)
	assert_true(
		(got["xf"] as Transform3D).is_equal_approx(want),
		"kind %d: the body %s, want %s" % [kind, got["xf"], want]
	)
	var d := CritterModel.grid_of(FlyerModel.drives(ph, walk, -1.0, 0.0))
	assert_true((got["custom"] as Vector4).is_equal_approx(d), "kind %d: the drives %s" % [kind, d])
	var e := FlyerModel.energy(kind, t, crowd._rise[k], -1.0, 0.0, false)
	assert_almost_eq((got["color"] as Color).a, e, 1e-5, "kind %d: the glow" % kind)
