extends GutTest
## The Star Warper on the owner's model (StarWarperAvatar): its parts load into their joints, it floats (never below
## the floor) and each clip moves the parts it should (the hover with its tail waving and shards circling, the glide
## leaning in with the tail trailing, the tell, the break into shards and the reform on the strike, the stun, a hit,
## the rise-in, the death), reduced motion keeps it from bobbing and its shards still, a missing model falls back to
## the code-made body that plays the same clips, and the VAT bake matches the live pose (a VAT avatar keeps the same
## drives, lift and glows through a fight). ActorViews draws the kind with it.

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_STAR_WARPER
const W := preload("res://src/presentation/world_view/star_warper_avatar.gd")

var _calm := false
var _vat := false
var _tick := 0


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


func _warper() -> StarWarperAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := StarWarperAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## `n` ticks: apply_state then a frame; `dx` metres a tick along +X (the facing's front at yaw 0).
func _run(a: StarWarperAvatar, n: int, state: int, extra := {}, dx := 0.0) -> void:
	for k in n:
		_tick += 1
		var s := {"tick": _tick, "state": state, "pos": Vector2(_tick * dx, 0), "hp": 45}
		s.merge(extra, true)
		a.apply_state(s)
		a.advance(DT)


func _lowest(a: StarWarperAvatar) -> float:
	var low := 99.0
	for v in VatVerify.live_vertices(a):
		low = minf(low, v.y)
	return low


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"star_warper"), "the model file is installed")
	var a := _warper()
	assert_true(a.has_model)
	for pname: String in [
		"head", "arm_l_u", "arm_l_l", "arm_r_u", "arm_r_l", "tail_a", "tail_b", "tail_c"
	]:
		assert_gt((a.parts[pname] as Node3D).get_child_count(), 0, "%s holds its part" % pname)
	for k in 3:
		var shard: Node3D = a.parts["shard_%d" % k]
		assert_eq(shard.get_parent(), a, "shard %d floats beside the body (not shrunk with it)" % k)
	var visor := 0
	var shards := 0
	for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		if mi == a.shadow:
			continue
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m == null or m in a.body_materials:
				continue
			if m.has_meta(SoloVat.GLOW):
				visor += 1
				assert_eq(String(mi.name), "head", "the visor is on the head")
			else:
				shards += 1
	assert_eq(visor, 1, "the visor")
	assert_eq(shards, 3, "the three shards glow")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")
	assert_true(a.shadow.has_meta(SoloVat.LIVE), "its ground disc stays live on VAT")


func test_it_floats_bobbing_its_tail_waving_and_shards_circling() -> void:
	var a := _warper()
	_run(a, 30, WorldReader.STATE_MOVE)
	var lift := [99.0, -99.0]
	var sway := [99.0, -99.0]
	var low := 99.0
	var orbit0 := a.drives()[W.ORBIT]
	for k in 150:
		_run(a, 1, WorldReader.STATE_MOVE)
		lift = [minf(lift[0], a.vat_lift()), maxf(lift[1], a.vat_lift())]
		var tip := a.drives()[W.TAIL0 + 4 + W.SWAY]
		sway = [minf(sway[0], tip), maxf(sway[1], tip)]
		if k % 15 == 0:
			low = minf(low, _lowest(a))
	assert_almost_eq((lift[0] + lift[1]) * 0.5, W.HOVER_LIFT, 0.03, "it floats: %s" % [lift])
	assert_gt(lift[1] - lift[0], 0.07, "and bobs")
	assert_gt(sway[1] - sway[0], 0.3, "the tail's tip waves: %s" % [sway])
	assert_ne(a.drives()[W.ORBIT], orbit0, "the shards circle the head")
	assert_gt(low, 0.1, "clear of the floor: %.3f" % low)


func test_the_glide_leans_in_and_trails_the_tail() -> void:
	var still := _warper()
	var moving := _warper()
	_run(still, 60, WorldReader.STATE_MOVE)
	_tick = 0
	_run(moving, 60, WorldReader.STATE_MOVE, {}, 3.0 / 60.0)
	var d0 := still.drives()
	var d1 := moving.drives()
	assert_gt(d1[W.PITCH], d0[W.PITCH] + 0.15, "it leans into the travel")
	assert_gt(d1[W.TAIL0 + W.SWING], d0[W.TAIL0 + W.SWING] + 0.2, "the tail trails back")
	assert_lt(d1[W.ARM_L + W.SWEEP], d0[W.ARM_L + W.SWEEP] - 0.2, "the arms swept back")


func test_the_tell_draws_the_claws_back_and_brightens_the_star() -> void:
	var a := _warper()
	_run(a, 30, WorldReader.STATE_MOVE)
	var rest := a.glow_energy()
	for k in 45:
		_run(a, 1, WorldReader.STATE_WINDUP, {"windup": (k + 1) / 60.0})
	assert_lt(a.drives()[W.ARM_R + W.SWEEP], -0.5, "the claws drawn back")
	assert_gt(a.drives()[W.ARM_R + W.RAISE], 0.3, "and up")
	assert_gt(a.glow_energy(), rest + 2.0, "the shards brighten")
	assert_gt(a.visor_energy(), W.VISOR_REST + 2.0, "the visor too")
	assert_almost_eq(a.gone(), 0.0, 0.001, "still whole")


func test_it_breaks_into_shards_and_reforms_striking_on_its_mark() -> void:
	var a := _warper()
	_run(a, 30, WorldReader.STATE_MOVE)
	for k in 60:
		_run(a, 1, WorldReader.STATE_WINDUP, {"windup": (k + 1) / 60.0})
	assert_gt(a.gone(), 0.95, "broken into its shards")
	assert_lt(a.drives()[W.FORM], -0.95, "the body shrunk away")
	assert_gt(a.drives()[W.SCATTER], 0.9, "the shards flown out")
	_run(a, 4, WorldReader.STATE_ACTIVE)
	assert_lt(a.gone(), 0.8, "reforming")
	assert_gt(a.drives()[W.ARM_R + W.SWEEP], 0.4, "the claws slashing forward")
	_run(a, 10, WorldReader.STATE_RECOVER)
	assert_almost_eq(a.gone(), 0.0, 0.001, "whole on its mark")
	assert_gt(a.drives()[W.PITCH], 0.12, "lunging")
	_run(a, 60, WorldReader.STATE_RECOVER)
	assert_lt(a.drives()[W.ARM_R + W.SWEEP], 0.3, "settled")


func test_a_cancelled_blink_reforms_it_reeling_and_dim() -> void:
	var a := _warper()
	_run(a, 30, WorldReader.STATE_MOVE)
	var lit := a.visor_energy()
	for k in 60:
		_run(a, 1, WorldReader.STATE_WINDUP, {"windup": (k + 1) / 60.0})
	_run(a, 30, WorldReader.STATE_RECOVER, {"stunned": true})
	assert_almost_eq(a.gone(), 0.0, 0.001, "reformed where it stands")
	assert_gt(a.drives()[W.HEAD_F], 0.3, "the head hangs")
	assert_lt(a.vat_lift(), W.HOVER_LIFT, "it sags")
	assert_lt(a.visor_energy(), lit * 0.6, "its star dim")
	var sides := {}
	for k in 60:
		_run(a, 1, WorldReader.STATE_RECOVER, {"stunned": true})
		sides[signf(a.drives()[W.ROLL])] = true
	assert_eq(sides.size(), 2, "it reels")


func test_a_hit_sags_and_wobbles_it_back() -> void:
	var calm := _warper()
	var hit := _warper()
	_run(calm, 30, WorldReader.STATE_MOVE)
	_tick = 0
	_run(hit, 30, WorldReader.STATE_MOVE)
	_tick = 30
	_run(calm, 4, WorldReader.STATE_MOVE)
	_tick = 30
	_run(hit, 4, WorldReader.STATE_MOVE, {"hp": 30})
	assert_lt(hit.vat_lift(), calm.vat_lift() - 0.04, "it sags in the air")
	assert_gt(absf(hit.drives()[W.ROLL] - calm.drives()[W.ROLL]), 0.1, "it rolls")
	var sides := {}
	for k in 45:
		_tick += 1
		calm.apply_state({"tick": _tick, "state": WorldReader.STATE_MOVE, "hp": 45})
		calm.advance(DT)
		hit.apply_state({"tick": _tick, "state": WorldReader.STATE_MOVE, "hp": 30})
		hit.advance(DT)
		var off := hit.drives()[W.ROLL] - calm.drives()[W.ROLL]
		if absf(off) > 0.03:
			sides[signf(off)] = true
	assert_eq(sides.size(), 2, "it wobbles back and forth")


func test_it_forms_out_of_its_shards_as_it_rises_in() -> void:
	var a := _warper()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "hp": 45})
	a.advance(DT)
	assert_gt(a.gone(), 0.9, "only its shards at first")
	_run(a, 30, WorldReader.STATE_SPAWN)
	_run(a, 90, WorldReader.STATE_MOVE)
	assert_almost_eq(a.gone(), 0.0, 0.001, "formed")
	assert_almost_eq(a.vat_lift(), W.HOVER_LIFT, 0.06, "risen to its hover")


func test_the_death_slumps_drops_and_breaks_it_into_shards() -> void:
	var a := _warper()
	_run(a, 30, WorldReader.STATE_MOVE)
	assert_true(a.die())
	var flare := 0.0
	var low := 99.0
	var limp := 0.0
	for k in int(W.DEATH_SECONDS / DT):
		a.advance(DT)
		flare = maxf(flare, a.glow_energy())
		limp = maxf(limp, a.drives()[W.HEAD_F])
		if k % 10 == 0:
			low = minf(low, _lowest(a))
	assert_gt(flare, W.SHARD_REST + 2.0, "a flare")
	assert_gt(limp, 0.4, "it slumps")
	assert_lt(a.vat_lift(), 0.1, "dropped toward the floor")
	assert_lt(a.drives()[W.FORM], -0.95, "broken into its shards")
	assert_lt(a.glow_energy(), 0.1, "the glow out")
	assert_gt(low, -0.01, "never under the floor: %.3f" % low)


func test_reduced_motion_no_bob_no_orbit() -> void:
	ViewPrefs.reduced_motion = true
	var a := _warper()
	_run(a, 30, WorldReader.STATE_MOVE)
	var orbit := a.drives()[W.ORBIT]
	var lift := [99.0, -99.0]
	for k in 120:
		_run(a, 1, WorldReader.STATE_MOVE)
		lift = [minf(lift[0], a.vat_lift()), maxf(lift[1], a.vat_lift())]
	assert_lt(lift[1] - lift[0], 0.002, "no bob: %s" % [lift])
	assert_eq(a.drives()[W.ORBIT], orbit, "the shards still")
	# A hit eases one dip and back: no wobble.
	var signs := {}
	_run(a, 1, WorldReader.STATE_MOVE, {"hp": 30})
	for k in 50:
		_run(a, 1, WorldReader.STATE_MOVE, {"hp": 30})
		if absf(a.drives()[W.ROLL]) > 0.05:
			signs[signf(a.drives()[W.ROLL])] = true
	assert_lt(signs.size(), 2, "one way only")


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _warper()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	var t0 := (a.parts["tail_c"] as Node3D).transform
	_run(a, 40, WorldReader.STATE_MOVE)
	assert_ne((a.parts["tail_c"] as Node3D).transform, t0, "its tail still waves")
	assert_null(a.vat_texture(), "no colour map")


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "drawn by the VAT crowd")
	assert_true(SoloVat.is_solo(KIND))
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var pose := VatBake.pose_for(KIND)
		var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(KIND)
		var e := VatVerify.pose_error(live, vat, pose, mesh, 40, 17)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
		assert_lt(float(e["max_m"]), 0.002, "within 2 mm (calm %s): %s" % [calm, e])
		assert_true(pose.has("albedo_tex"), "the owner's colour map")
		live.free()
		vat.free()


func test_a_vat_avatar_keeps_the_drives_lift_and_glows_through_a_fight() -> void:
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND)
	add_child_autofree(live)
	add_child_autofree(vat)
	live.set_process(false)
	vat.set_process(false)
	var pieces := vat.find_children("*", "MeshInstance3D", true, false)
	assert_eq(pieces.size(), 1, "no pieces but its live ground disc")
	var plan := [
		[WorldReader.STATE_SPAWN, 20, 0.0, 0.05, false],
		[WorldReader.STATE_MOVE, 60, 0.0, 0.05, false],
		[WorldReader.STATE_WINDUP, 60, 1.0, 0.0, false],
		[WorldReader.STATE_ACTIVE, 6, 0.0, 0.0, false],
		[WorldReader.STATE_RECOVER, 36, 0.0, 0.0, false],
		[WorldReader.STATE_WINDUP, 60, 1.0, 0.0, false],
		[WorldReader.STATE_RECOVER, 60, 0.0, 0.0, true],
	]
	var t := 0
	for step: Array in plan:
		for k in int(step[1]):
			t += 1
			var s := {
				"tick": t,
				"state": step[0],
				"windup": float(step[2]) * (k + 1) / float(step[1]),
				"pos": Vector2(t * float(step[3]), 0),
				"hp": 45 - t / 60,
				"stunned": step[4],
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)


func test_actor_views_draw_the_kind_with_it() -> void:
	var w := CombatLab.world()
	w.add_enemy(ActorStore.Kind.STAR_WARPER, Vector2(4, 0))
	var views := ActorViews.new()
	add_child_autofree(views)
	views.sync(WorldReader.new(w))
	var node := views.actor_node(w.actors.ids[1])
	assert_true(node.get_meta(&"enemy_avatar") is StarWarperAvatar)
