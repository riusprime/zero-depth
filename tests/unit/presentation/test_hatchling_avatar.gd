extends GutTest
## The Hatchling on the owner's model (HatchlingAvatar, on the Charger's state and drives): its parts load into their
## joints at the horde's small size, each clip moves the parts it should (the scurry, the idle breath, the tell's rear
## with the front legs raised, the charge, the daze, the rise-in, the death's roll onto its back), the knees stay off
## the ground, reduced motion never trembles, a missing model falls back to the Charger's code body at two thirds, and
## the VAT bake matches the live pose (within 2 mm), through a fight and a death.

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_HATCHLING
const RUN := Vector2(3.6 / 60.0, 0.0)

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


func _hatchling(vat := false) -> HatchlingAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := HatchlingAvatar.new()
	a.vat = vat
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## `n` ticks of `state` (apply_state then a frame each), its place moving `step` a tick; returns the next tick.
func _run(
	a: HatchlingAvatar, from: int, n: int, state: int, windup := 0.0, step := Vector2.ZERO
) -> int:
	for k in n:
		var t := from + k
		a.apply_state({"tick": t, "state": state, "windup": windup, "pos": step * float(t)})
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


func _node(a: HatchlingAvatar, pname: String) -> Node3D:
	return a.find_child(pname, true, false) as Node3D


## Leg `leg`'s foot tip in the avatar's space (its lower half's lowest rest point, carried by its joints).
func _foot(a: HatchlingAvatar, leg: String) -> Vector3:
	var mi := _node(a, "Leg%sL" % leg.capitalize()) as MeshInstance3D
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tip := v[0]
	for p in v:
		if p.y < tip.y:
			tip = p
	return a.global_transform.affine_inverse() * (mi.global_transform * tip)


## Leg `leg`'s knee (its lower half's joint) in the avatar's space.
func _knee(a: HatchlingAvatar, leg: String) -> Vector3:
	var j := _node(a, "Leg%sL" % leg.to_upper())
	return a.global_transform.affine_inverse() * j.global_position


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	var a := _hatchling()
	assert_true(a.has_model, "the owner's model")
	assert_eq(a.scale, Vector3.ONE, "at its own size")
	assert_eq(a._joints.size(), 65, "the root's three, the carapace's two, ten a leg")
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 14, "body, carapace, six legs in two halves")
	assert_not_null(a.visor, "the eye glows")
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var tris := 0
	for v in VatVerify.live_vertices(a):
		lo = lo.min(v)
		hi = hi.max(v)
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_len(s) / 3
	assert_almost_eq(hi.y - lo.y, 0.4, 0.03, "about 0.4 m tall (%s .. %s)" % [lo, hi])
	assert_almost_eq(maxf(hi.x - lo.x, hi.z - lo.z), 0.58, 0.04, "about 0.56 m across")
	assert_between(tris, 2500, 3300, "simplified for the horde: %d triangles" % tris)


func test_the_scurry_lifts_every_foot_in_two_tripods() -> void:
	var a := _hatchling()
	var t := _run(a, 0, 40, WorldReader.STATE_MOVE, 0.0, RUN)
	var lifted := {}
	var apart := 0
	for k in 30:
		t = _run(a, t, 1, WorldReader.STATE_MOVE, 0.0, RUN)
		if absf(_foot(a, "fr").y - _foot(a, "fl").y) > 0.01:
			apart += 1
		for leg in ["fr", "fl", "mr", "ml", "br", "bl"]:
			if _foot(a, leg).y > 0.025:
				lifted[leg] = true
	assert_eq(lifted.size(), 6, "every foot lifts: %s" % [lifted])
	assert_gt(apart, 8, "the front pair step in turn")


func test_at_rest_the_carapace_breathes() -> void:
	var a := _hatchling()
	var t := _run(a, 0, 30, WorldReader.STATE_MOVE)
	var b0 := _node(a, "Breath").position.y
	_run(a, t, 90, WorldReader.STATE_MOVE)
	assert_gt(absf(_node(a, "Breath").position.y - b0), 0.001, "the carapace rises and falls")


func test_the_tell_rears_it_and_raises_its_front_legs() -> void:
	var a := _hatchling()
	var t := _run(a, 0, 30, WorldReader.STATE_MOVE)
	var front := _foot(a, "fr").y
	var shell := _node(a, "Shell").position.y
	for k in 40:
		t = _run(a, t, 1, WorldReader.STATE_WINDUP, float(k + 1) / 40.0)
	assert_gt(_node(a, "Lean").transform.basis.get_euler().z, 0.1, "nose up")
	assert_gt(_foot(a, "fr").y, front + 0.05, "the front claws raised")
	assert_lt(absf(_foot(a, "br").y), 0.03, "on its hind feet")
	assert_gt(_node(a, "Shell").position.y, shell + 0.01, "the carapace bristles up")


func test_the_charge_pitches_it_forward_and_the_daze_lists_it() -> void:
	var a := _hatchling()
	var t := _run(a, 0, 30, WorldReader.STATE_MOVE)
	for k in 40:
		t = _run(a, t, 1, WorldReader.STATE_WINDUP, float(k + 1) / 40.0)
	t = _run(a, t, 8, WorldReader.STATE_ACTIVE, 0.0, Vector2(13.0 / 60.0, 0.0))
	assert_lt(_node(a, "Lean").transform.basis.get_euler().z, -0.05, "nose down")
	t = _run(a, t, 40, WorldReader.STATE_RECOVER)
	assert_gt(absf(_node(a, "Lean").transform.basis.get_euler().x), 0.05, "it lists, dazed")
	assert_lt(a.visor_energy(), ChargerAvatar.VISOR_ENERGY * 0.6, "the eye dims")


func test_it_rises_in_with_its_legs_folded() -> void:
	var a := _hatchling()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO})
	a.advance(DT)
	assert_lt(a.vat_lift(), -0.3, "sunk")
	var tucked := _foot(a, "ml").y - a.vat_lift()
	_run(a, 1, 40, WorldReader.STATE_MOVE)
	assert_almost_eq(a.vat_lift(), 0.0, 1e-6, "risen")
	assert_gt(tucked, _foot(a, "ml").y + 0.015, "its legs were tucked up under it")


func test_the_death_rolls_it_onto_its_back_and_curls_its_legs() -> void:
	var a := _hatchling()
	_run(a, 0, 30, WorldReader.STATE_MOVE)
	assert_true(a.die(), "the model falls")
	for k in roundi(HatchlingAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_true(a.dying())
	assert_almost_eq(a.dead(), 1.0, 1e-6)
	assert_gt(absf(_node(a, "Fall").transform.basis.get_euler().x), 2.0, "on its back")
	assert_lt(a.visor_energy(), 0.01, "the eye goes out")
	assert_almost_eq(a.vat_drives()[ChargerVat.DEATH], 1.0, 1e-6, "the death's drive")


func test_the_knees_stay_off_the_ground_through_every_clip() -> void:
	var a := _hatchling()
	var t := 0
	var low := 1.0
	var clips := [
		[WorldReader.STATE_MOVE, 30, Vector2.ZERO],
		[WorldReader.STATE_MOVE, 40, RUN],
		[WorldReader.STATE_WINDUP, 40, Vector2.ZERO],
		[WorldReader.STATE_ACTIVE, 15, Vector2(13.0 / 60.0, 0.0)],
		[WorldReader.STATE_RECOVER, 50, Vector2.ZERO],
		[WorldReader.STATE_MOVE, 120, Vector2.ZERO],
	]
	for c: Array in clips:
		for k in int(c[1]):
			var p := float(k + 1) / float(c[1]) if c[0] == WorldReader.STATE_WINDUP else 0.0
			t = _run(a, t, 1, c[0], p, c[2])
			if k == 5:
				a.flinch(Vector2(-1, 0.3), 1.0)
			for leg in ["fr", "fl", "mr", "ml", "br", "bl"]:
				low = minf(low, _knee(a, leg).y)
	assert_gt(low, 0.03, "the lowest knee: %f m" % low)


func test_reduced_motion_never_trembles() -> void:
	ViewPrefs.reduced_motion = true
	var a := _hatchling()
	var t := _run(a, 0, 30, WorldReader.STATE_MOVE)
	for k in 40:
		t = _run(a, t, 1, WorldReader.STATE_WINDUP, float(k + 1) / 40.0)
	var ys: Array[float] = []
	for k in 6:  # held at the top: the raise held, no tremble
		t = _run(a, t, 1, WorldReader.STATE_WINDUP, 1.0)
		ys.append(_node(a, "Lift").position.y)
	for k in range(1, ys.size()):
		assert_almost_eq(ys[k], ys[k - 1], 0.0015, "no tremble")


func test_a_missing_model_falls_back_to_the_charger_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _hatchling()
	assert_false(a.has_model)
	assert_eq(a.legs.size(), 4, "the Charger's code body")
	assert_false(a.die(), "the code body goes at once")
	assert_eq(a.vat_rig()["key"], "charger", "the Charger's bake")
	var views: ActorViews = add_child_autofree(ActorViews.new())
	var root := Node3D.new()
	var facing := Node3D.new()
	root.add_child(facing)
	add_child_autofree(root)
	assert_almost_eq(
		HatchlingAvatar.attach(views, root, facing), ChargerAvatar.HEIGHT * 0.66, 1e-6, "its bar"
	)
	assert_eq((root.get_meta(&"enemy_avatar") as Node3D).scale, Vector3.ONE * 0.66, "two thirds")


func test_the_vat_bake_matches_the_live_pose() -> void:
	var pose := VatBake.pose_for(KIND)
	var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND)
	assert_eq(pose["key"], "hatchling", "its own bake")
	assert_eq(VatBake.joints(live).size(), 65, "65 joints (the Charger's code body: 78)")
	var e := VatVerify.pose_error(live, vat, pose, mesh, 80, 31)
	assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
	assert_lt(float(e["max_m"]), 0.002, "within 2 mm: %s" % [e])
	live.free()
	vat.free()


func test_a_vat_hatchling_keeps_the_live_pose_through_a_fight_and_a_death() -> void:
	var live := _hatchling()
	var vat := _hatchling(true)
	assert_eq(vat.find_children("*", "Node3D", true, false).size(), 0, "no nodes at all")
	var pose := VatBake.pose_for(KIND)
	var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var states := [
		WorldReader.STATE_SPAWN,
		WorldReader.STATE_MOVE,
		WorldReader.STATE_WINDUP,
		WorldReader.STATE_ACTIVE,
		WorldReader.STATE_RECOVER,
		WorldReader.STATE_MOVE,
	]
	var worst := 0.0
	for k in 200:
		var st: int = states[mini(int(k / 30.0), 5)]
		var p := clampf(float(k - 60) / 30.0, 0.0, 1.0) if st == WorldReader.STATE_WINDUP else 0.0
		if k == 170:
			assert_true(live.die() and vat.die(), "both fall")
		for a: HatchlingAvatar in [live, vat]:
			a.apply_state({"tick": k, "pos": Vector2(0.05 * k, 0.0), "state": st, "windup": p})
			a.advance(DT)
		assert_eq(vat.vat_drives(), live.vat_drives(), "tick %d: the drives" % k)
		assert_eq(vat.visor_energy(), live.visor_energy(), "tick %d: the eye" % k)
		var a_v := VatVerify.live_vertices(live)
		var b_v := VatVerify.eval_vertices(pose, mesh, vat.vat_drives(), vat.vat_lift())
		for v in a_v.size():
			worst = maxf(worst, a_v[v].distance_to(b_v[v]))
	assert_lt(worst, 0.002, "the VAT pose follows the live one (%f m)" % worst)
