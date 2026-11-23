extends GutTest
## The Arc Caster on the owner's model (ArcCasterAvatar): its parts load into their joints, each clip moves the parts
## it should (the idle with its shards circling, the stepping glide, the gather, the cast, a hit, the rise-in, the
## death), nothing dips under the floor, reduced motion moves less and keeps the shards still, a missing model falls
## back to the code-made body that plays the same clips, and the VAT bake matches the live pose (a VAT avatar keeps
## the same drives, lift and glows through a fight). ActorViews draws the kind with it.

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_ARC_CASTER
const A := preload("res://src/presentation/world_view/arc_caster_avatar.gd")

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


## A caster under a facing node (the one ActorViews turns), its own processing off.
func _caster() -> ArcCasterAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := ArcCasterAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## `n` ticks of a state: apply_state then a frame; `dx` metres a tick along +X (the facing's front at yaw 0).
func _run(a: ArcCasterAvatar, n: int, state: int, windup := 0.0, dx := 0.0) -> void:
	for k in n:
		_tick += 1
		var x := float(_tick) * dx
		a.apply_state({"tick": _tick, "state": state, "pos": Vector2(x, 0), "windup": windup})
		a.advance(DT)
		a.advance_flinch(DT)


## A part's mesh's middle in the world (a shard's frame sits on the hood's axis).
func _centre(frame: Node3D) -> Vector3:
	var mi := frame.get_child(0) as MeshInstance3D
	return mi.global_transform * mi.get_aabb().get_center()


func _lowest(a: ArcCasterAvatar) -> float:
	var low := 99.0
	for v in VatVerify.live_vertices(a):
		low = minf(low, v.y)
	return low


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"arc_caster"), "the model file is installed")
	var a := _caster()
	assert_true(a.has_model)
	for pname: String in [
		"torso",
		"hem_u",
		"hem_l",
		"hood",
		"arm_r",
		"staff",
		"arm_l_u",
		"arm_l_l",
		"shard_0",
		"shard_1",
		"shard_2"
	]:
		var frame: Node3D = a.parts.get(pname)
		assert_not_null(frame, pname)
		if frame != null:
			assert_eq(frame.get_child_count() > 0, true, "%s holds its part" % pname)
	var glows := {}
	for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.emission_enabled and not m in a.body_materials:
				glows[String(mi.name)] = m.has_meta(SoloVat.GLOW)
	assert_eq(glows.get("staff"), false, "the crystal glows at the instance's glow")
	assert_eq(glows.get("hood"), true, "the visor at its own drive")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")
	assert_eq(a.body_materials[1].albedo_color, A.COLOR, "the plates in the request's violet")
	var staff_box := (a.parts["staff"].get_child(0) as MeshInstance3D).get_aabb()
	assert_gt(
		staff_box.size.y * float(EnemyModels.get_model(&"arc_caster")["scale"]), 1.4, "a tall staff"
	)


func test_it_hovers_and_its_shards_circle_the_hood() -> void:
	var a := _caster()
	_run(a, 30, WorldReader.STATE_MOVE)
	var lift := [99.0, -99.0]
	var hem := [99.0, -99.0]
	var orbit0 := a.drives()[A.ORBIT]
	var shards := []
	for k in 3:
		shards.append(_centre(a.parts["shard_%d" % k]))
	for k in 120:
		_run(a, 1, WorldReader.STATE_MOVE)
		lift = [minf(lift[0], a.vat_lift()), maxf(lift[1], a.vat_lift())]
		hem = [minf(hem[0], a.drives()[A.HEM_L_F]), maxf(hem[1], a.drives()[A.HEM_L_F])]
	assert_gt(lift[0], 0.0, "it floats off the floor: %s" % [lift])
	assert_gt(lift[1] - lift[0], 0.03, "and bobs")
	assert_gt(hem[1] - hem[0], 0.05, "the hem sways: %s" % [hem])
	assert_ne(a.drives()[A.ORBIT], orbit0, "the shards turn round the hood")
	var moved := 0.0
	for k in 3:
		var at := _centre(a.parts["shard_%d" % k])
		moved = maxf(moved, at.distance_to(shards[k]))
	assert_gt(moved, 0.05, "the shards moved: %.3f" % moved)
	assert_gt(_lowest(a), -0.005, "nothing under the floor")


func test_the_glide_leans_into_the_travel_and_the_hem_steps_and_trails() -> void:
	var a := _caster()
	_run(a, 30, WorldReader.STATE_MOVE)
	var steps := {}
	var lean := 0.0
	var trail := 0.0
	for k in 90:
		_run(a, 1, WorldReader.STATE_MOVE, 0.0, 3.0 / 60.0)
		lean = maxf(lean, a.drives()[A.LEAN_F])
		trail = minf(trail, a.drives()[A.HEM_F])
		if absf(a.drives()[A.HEM_L_S]) > 0.08:
			steps[signf(a.drives()[A.HEM_L_S])] = true
	assert_gt(lean, 0.12, "it leans into the travel")
	assert_lt(trail, -0.15, "the robe trails")
	assert_eq(steps.size(), 2, "the hem steps side to side")
	assert_gt(_lowest(a), -0.005, "nothing under the floor")


func test_the_gather_raises_the_staff_and_charges_the_crystal() -> void:
	var a := _caster()
	_run(a, 40, WorldReader.STATE_MOVE)
	var rest := a.glow_energy()
	var arm := a.drives()[A.ARM_R_F]
	for k in 30:
		_run(a, 1, WorldReader.STATE_WINDUP, (k + 1) / 30.0)
	assert_almost_eq(a.gather_pose(), 1.0, 0.001)
	assert_gt(a.glow_energy(), rest + 3.0, "the crystal brightens")
	assert_gt(a.drives()[A.ARM_R_F], arm + 0.8, "the staff arm lifts")
	assert_gt(a.drives()[A.ELBOW_L], 0.9, "the free arm drawn back, claws cocked")
	assert_lt(a.drives()[A.ARM_L_F], -0.3, "back")
	assert_lt(a.drives()[A.SCATTER], -0.3, "the shards drawn in")
	assert_gt(a.visor_energy(), A.VISOR_REST + 1.0, "the visor too")


func test_the_cast_thrusts_the_staff_and_flares_then_settles() -> void:
	var a := _caster()
	_run(a, 40, WorldReader.STATE_MOVE)
	var rest := a.glow_energy()
	_run(a, 30, WorldReader.STATE_WINDUP, 1.0)
	_run(a, 2, WorldReader.STATE_ACTIVE)
	assert_gt(a.glow_energy(), rest + 5.0, "the crystal flares")
	_run(a, 6, WorldReader.STATE_ACTIVE)
	assert_gt(a.drives()[A.STAFF_F], 0.8, "the staff thrust crystal first")
	assert_gt(a.drives()[A.ARM_L_F], 1.0, "the free hand flung after it")
	assert_gt(a.drives()[A.LEAN_F], 0.08, "it lunges")
	assert_gt(a.drives()[A.SCATTER], 0.5, "the shards flung out")
	_run(a, 70, WorldReader.STATE_RECOVER)
	assert_lt(a.glow_energy(), rest + 1.0, "and settles back")
	assert_lt(absf(a.drives()[A.STAFF_F]), 0.2, "the staff upright again")


func test_a_hit_snaps_the_hood_back() -> void:
	var a := _caster()
	_run(a, 30, WorldReader.STATE_MOVE)
	var hood := a.drives()[A.HOOD_F]
	a.flinch(Vector2.LEFT, 1.0)
	_run(a, 3, WorldReader.STATE_MOVE)
	assert_lt(a.drives()[A.HOOD_F], hood - 0.3, "the hood snaps back")
	assert_gt(a.drives()[A.SCATTER], 0.1, "the shards start out")


func test_it_rises_out_of_its_robe_and_the_shards_gather() -> void:
	var a := _caster()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN})
	a.advance(DT)
	assert_gt(a.drives()[A.CRUMPLE], 0.8, "crumpled into its robe")
	assert_gt(a.drives()[A.SCATTER], 0.8, "its shards far out")
	assert_lt(a.glow_energy(), 0.3, "unlit")
	assert_gt(_lowest(a), -0.005, "nothing under the floor")
	_run(a, 60, WorldReader.STATE_MOVE)
	assert_almost_eq(a.drives()[A.CRUMPLE], 0.0, 0.001, "risen")
	assert_lt(absf(a.drives()[A.SCATTER]), 0.05, "the shards home")


func test_the_death_drops_the_staff_crumples_and_flings_the_shards() -> void:
	var a := _caster()
	_run(a, 30, WorldReader.STATE_MOVE)
	assert_true(a.die())
	assert_true(a.dying())
	var flare := 0.0
	var low := 99.0
	for k in int(A.DEATH_SECONDS / DT):
		a.advance(DT)
		flare = maxf(flare, a.glow_energy())
		low = minf(low, _lowest(a))
	assert_gt(flare, A.CRYSTAL_REST + 2.0, "a last flare")
	assert_gt(a.drives()[A.CRUMPLE], 0.85, "crumpled")
	assert_gt(a.drives()[A.STAFF_S], 1.3, "the staff fallen across the floor")
	assert_almost_eq(a.drives()[A.SCATTER], 1.0, 0.001, "the shards flown off")
	assert_lt(a.glow_energy(), 0.2, "the crystal out")
	assert_lt(a.visor_energy(), 0.2, "the visor out")
	assert_gt(low, -0.03, "the robe stays on the floor: %.3f" % low)


func test_reduced_motion_moves_less_and_keeps_the_shards_still() -> void:
	var out := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _caster()
		_run(a, 30, WorldReader.STATE_MOVE)
		var orbit := a.drives()[A.ORBIT]
		var hem := [99.0, -99.0]
		var lift := [99.0, -99.0]
		for k in 120:
			_run(a, 1, WorldReader.STATE_MOVE, 0.0, 3.0 / 60.0)
			hem = [minf(hem[0], a.drives()[A.HEM_L_S]), maxf(hem[1], a.drives()[A.HEM_L_S])]
			lift = [minf(lift[0], a.vat_lift()), maxf(lift[1], a.vat_lift())]
		out.append([hem[1] - hem[0], lift[1] - lift[0], a.drives()[A.ORBIT] - orbit])
	assert_lt(out[1][0], out[0][0] * 0.5, "a smaller hem step: %s" % [out])
	assert_lt(out[1][1], out[0][1] * 0.5, "a smaller bob")
	assert_eq(out[1][2], 0.0, "the shards still")
	# The gather keeps its pose (it is the tell).
	var b := _caster()
	_run(b, 30, WorldReader.STATE_WINDUP, 1.0)
	assert_gt(b.drives()[A.ARM_R_F], 0.8, "the staff still lifts")


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _caster()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	var t0 := (a.parts["staff"] as Node3D).transform
	_run(a, 30, WorldReader.STATE_WINDUP, 1.0)
	assert_ne((a.parts["staff"] as Node3D).transform, t0, "its staff still moves")
	assert_null(a.vat_texture(), "no colour map")


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "drawn by the VAT crowd")
	assert_true(SoloVat.is_solo(KIND))
	assert_true(SoloVat.vat_avatar_of(KIND) is ArcCasterAvatar, "its own avatar")
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
	assert_eq(vat.find_children("*", "MeshInstance3D", true, false).size(), 0, "no pieces")
	var plan := [
		[WorldReader.STATE_SPAWN, 20, 0.0, 0.0],
		[WorldReader.STATE_MOVE, 60, 0.0, 0.05],
		[WorldReader.STATE_WINDUP, 30, 1.0, 0.0],
		[WorldReader.STATE_ACTIVE, 2, 0.0, 0.0],
		[WorldReader.STATE_RECOVER, 40, 0.0, 0.0],
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
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)


func test_actor_views_draw_the_kind_with_it() -> void:
	var w := CombatLab.world()
	w.add_enemy(ActorStore.Kind.ARC_CASTER, Vector2(4, 0))
	var views := ActorViews.new()
	add_child_autofree(views)
	views.sync(WorldReader.new(w))
	var node := views.actor_node(w.actors.ids[1])
	assert_true(node.get_meta(&"enemy_avatar") is ArcCasterAvatar)
