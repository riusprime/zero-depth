extends GutTest
## The Bomb Drone on the owner's model (BombDroneAvatar): its parts load into their joints, it hovers (never below the
## floor) and each clip moves the parts it should (the hover with its bob and spinning rotors, the glide tipping in and
## banking, the turn's bank, the lob with the bomb let go and a new one slung after, a hit, the rise-in, the death that
## drops and breaks it), reduced motion keeps it from bobbing and eases a hit once, a missing model falls back to the
## code-made body that plays the same clips, and the VAT bake matches the live pose (a VAT avatar keeps the same drives,
## lift and glows through a fight). ActorViews draws the kind with it.

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_BOMB_DRONE
const B := preload("res://src/presentation/world_view/bomb_drone_avatar.gd")

var _calm := false
var _vat := false
var _tick := 0


func before_each() -> void:
	_calm = ViewPrefs.reduced_motion
	_vat = ViewPrefs.enemy_vat
	ViewPrefs.reduced_motion = false
	VatBake.clear_cache()
	_tick = 0


func after_each() -> void:
	ViewPrefs.reduced_motion = _calm
	ViewPrefs.enemy_vat = _vat
	EnemyModels.dir = EnemyModels.DIR
	EnemyModels.clear_cache()


func _drone() -> BombDroneAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := BombDroneAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## `n` ticks: apply_state then a frame; `step` metres a tick on the sim plane.
func _run(a: BombDroneAvatar, n: int, state: int, extra := {}, step := Vector2.ZERO) -> void:
	for k in n:
		_tick += 1
		var s := {"tick": _tick, "state": state, "pos": step * _tick, "hp": 30}
		s.merge(extra, true)
		a.apply_state(s)
		a.advance(DT)


func _lowest(a: BombDroneAvatar) -> float:
	var low := 99.0
	for v in VatVerify.live_vertices(a):
		low = minf(low, v.y)
	return low


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"bomb_drone"), "the model file is installed")
	var a := _drone()
	assert_true(a.has_model)
	for pname: String in [
		"rig",
		"arm_ur",
		"arm_ul",
		"arm_dr",
		"arm_dl",
		"rotor_ur",
		"rotor_ul",
		"rotor_dr",
		"rotor_dl",
		"cradle",
		"bomb"
	]:
		assert_gt((a.parts[pname] as Node3D).get_child_count(), 0, "%s holds its part" % pname)
	assert_eq(a.rotors.size(), 4, "four rotors")
	for k in 4:
		assert_eq(a.rotors[k].get_parent(), a.parts["arm_%s" % B.ARMS[k]], "each on its arm")
	var visor := 0
	for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.has_meta(SoloVat.GLOW):
				visor += 1
				assert_eq(String(mi.name), "hull", "the visor is on the hull")
	assert_eq(visor, 1, "the visor's gem glows")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")
	assert_eq(
		a.body_materials[1].albedo_color,
		EnemyPalettes.color(KIND, &"body"),
		"the role plates in the palette's bomber yellow"
	)
	assert_true(a.shadow.has_meta(SoloVat.LIVE), "its ground disc stays live on VAT")
	assert_true(a.bomb_armed(), "a bomb slung in the cradle")


func test_it_hovers_bobbing_its_rotors_spinning() -> void:
	var a := _drone()
	_run(a, 30, WorldReader.STATE_MOVE)
	var hover := [99.0, -99.0]
	var low := 99.0
	var turns := {}
	for k in 150:
		_run(a, 1, WorldReader.STATE_MOVE)
		hover = [minf(hover[0], a.hover_height()), maxf(hover[1], a.hover_height())]
		turns[snappedf(a.drives()[B.ROTOR], 0.1)] = true
		if k % 15 == 0:
			low = minf(low, _lowest(a))
	assert_almost_eq((hover[0] + hover[1]) * 0.5, B.HOVER_Y, 0.03, "it hovers: %s" % [hover])
	assert_gt(hover[1] - hover[0], 0.12, "and bobs")
	assert_gt(turns.size(), 20, "the rotors spin")
	assert_almost_eq(a.spin_rate(), B.SPIN, 1.0, "at full speed")
	assert_gt(low, 1.0, "high off the floor: %.3f" % low)


func test_the_glide_tips_the_nose_in_and_banks() -> void:
	var still := _drone()
	var ahead := _drone()
	var side := _drone()
	_run(still, 60, WorldReader.STATE_MOVE)
	_tick = 0
	_run(ahead, 60, WorldReader.STATE_MOVE, {}, Vector2(2.6 / 60.0, 0))
	_tick = 0
	_run(side, 60, WorldReader.STATE_MOVE, {}, Vector2(0, 2.6 / 60.0))
	assert_gt(ahead.drives()[B.PITCH], still.drives()[B.PITCH] + 0.15, "nose down into the travel")
	assert_gt(
		absf(side.drives()[B.ROLL] - still.drives()[B.ROLL]), 0.12, "banked into a sideways glide"
	)


func test_a_turn_banks_it() -> void:
	var a := _drone()
	var facing := a.get_parent() as Node3D
	_run(a, 30, WorldReader.STATE_MOVE)
	var still := a.drives()[B.ROLL]
	for k in 20:
		facing.rotation.y += 0.05
		_run(a, 1, WorldReader.STATE_MOVE)
	assert_lt(a.drives()[B.ROLL], still - 0.1, "it banks into the turn")
	assert_lt(a.drives()[B.YAW], -0.05, "the hull trails it")


func test_the_lob_lets_the_bomb_go_and_slings_a_new_one() -> void:
	var a := _drone()
	_run(a, 30, WorldReader.STATE_MOVE)
	var rest := a.visor_energy()
	var snap := 0.0
	for k in 48:
		_run(a, 1, WorldReader.STATE_WINDUP)
		snap = maxf(snap, a.drives()[B.PITCH])
		if k == 10:
			assert_false(a.bomb_armed(), "the bomb let go")
			assert_gt(a.drives()[B.CLAW], 0.8, "the claws sprung open")
	assert_gt(snap, 0.3, "the nose snapped down to throw")
	assert_gt(a.visor_energy(), rest + 1.5, "the visor brightens as the circle fills")
	assert_gt(a.spin_rate(), B.SPIN * 1.25, "the rotors spin up")
	assert_eq(a.vat_drives()[B.BOMB_S], 0.0, "folded to a point")
	_run(a, 1, WorldReader.STATE_ACTIVE)
	_run(a, 20, WorldReader.STATE_RECOVER)
	assert_true(a.bomb_armed(), "a new bomb rising into the cradle")
	assert_lt(a.drives()[B.BOMB_S], 0.7, "still growing")
	_run(a, 60, WorldReader.STATE_RECOVER)
	assert_almost_eq(a.drives()[B.BOMB_S], 1.0, 0.001, "slung")
	assert_lt(a.drives()[B.CLAW], 0.15, "the claws closed on it")


func test_a_hit_sags_and_wobbles_it_back() -> void:
	var calm := _drone()
	var hit := _drone()
	_run(calm, 30, WorldReader.STATE_MOVE)
	_tick = 0
	_run(hit, 30, WorldReader.STATE_MOVE)
	_tick = 30
	_run(calm, 4, WorldReader.STATE_MOVE)
	_tick = 30
	_run(hit, 4, WorldReader.STATE_MOVE, {"hp": 20})
	assert_lt(hit.hover_height(), calm.hover_height() - 0.05, "it sags in the air")
	assert_gt(absf(hit.drives()[B.ROLL] - calm.drives()[B.ROLL]), 0.12, "it rolls")
	var sides := {}
	for k in 45:
		_tick += 1
		calm.apply_state({"tick": _tick, "state": WorldReader.STATE_MOVE, "hp": 30})
		calm.advance(DT)
		hit.apply_state({"tick": _tick, "state": WorldReader.STATE_MOVE, "hp": 20})
		hit.advance(DT)
		var off := hit.drives()[B.ROLL] - calm.drives()[B.ROLL]
		if absf(off) > 0.03:
			sides[signf(off)] = true
	assert_eq(sides.size(), 2, "it wobbles back and forth")


func test_it_rises_in_off_the_floor_unfolding() -> void:
	var a := _drone()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "hp": 30})
	a.advance(DT)
	assert_lt(a.hover_height(), 0.7, "it starts on the floor")
	assert_gt(a.drives()[B.DROOP0], 0.4, "its upper arms folded")
	assert_lt(a.spin_rate(), B.SPIN * 0.5, "its rotors slow")
	var low := _lowest(a)
	_run(a, 20, WorldReader.STATE_SPAWN)
	for k in 90:
		_run(a, 1, WorldReader.STATE_MOVE)
		if k % 10 == 0:
			low = minf(low, _lowest(a))
	assert_almost_eq(a.hover_height(), B.HOVER_Y, 0.1, "risen to its hover")
	assert_lt(absf(a.drives()[B.DROOP0]), 0.1, "the arms unfolded")
	assert_gt(low, -0.005, "never under the floor: %.3f" % low)


func test_the_death_drops_and_breaks_it() -> void:
	var a := _drone()
	_run(a, 30, WorldReader.STATE_MOVE)
	assert_true(a.die())
	assert_true(a.dying())
	var flare := 0.0
	var low := 99.0
	for k in int(B.DEATH_SECONDS / DT):
		a.advance(DT)
		flare = maxf(flare, a.glow_energy())
		if k % 6 == 0:
			low = minf(low, _lowest(a))
	assert_gt(flare, B.VISOR_REST + 1.0, "a flare")
	assert_lt(a.vat_lift(), 0.1, "dropped to the floor")
	assert_gt(a.drives()[B.BREAK], 0.95, "its arms broken off")
	assert_gt(a.drives()[B.CLAW], 0.95, "the claws burst open")
	assert_false(a.bomb_armed(), "the bomb dropped")
	assert_lt(a.spin_rate(), 3.0, "the rotors spun down")
	assert_lt(a.glow_energy(), 0.1, "the visor out")
	assert_gt(low, -0.01, "never under the floor: %.3f" % low)


func test_reduced_motion_no_bob_and_a_hit_eased_once() -> void:
	ViewPrefs.reduced_motion = true
	var a := _drone()
	_run(a, 60, WorldReader.STATE_MOVE)
	var hover := [99.0, -99.0]
	for k in 120:
		_run(a, 1, WorldReader.STATE_MOVE)
		hover = [minf(hover[0], a.hover_height()), maxf(hover[1], a.hover_height())]
	assert_lt(hover[1] - hover[0], 0.002, "no bob: %s" % [hover])
	assert_lt(a.spin_rate(), B.SPIN * 0.5, "slower rotors")
	var signs := {}
	_run(a, 1, WorldReader.STATE_MOVE, {"hp": 20})
	for k in 50:
		_run(a, 1, WorldReader.STATE_MOVE, {"hp": 20})
		if absf(a.drives()[B.ROLL]) > 0.05:
			signs[signf(a.drives()[B.ROLL])] = true
	assert_lt(signs.size(), 2, "one way only")


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _drone()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	var r0 := a.rotors[0].transform
	_run(a, 40, WorldReader.STATE_MOVE)
	assert_ne(a.rotors[0].transform, r0, "its rotors still spin")
	_run(a, 20, WorldReader.STATE_WINDUP)
	assert_false(a.bomb.visible, "its bomb let go")
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
		[WorldReader.STATE_SPAWN, 20, Vector2.ZERO],
		[WorldReader.STATE_MOVE, 60, Vector2(0.04, 0.01)],
		[WorldReader.STATE_WINDUP, 48, Vector2.ZERO],
		[WorldReader.STATE_ACTIVE, 1, Vector2.ZERO],
		[WorldReader.STATE_RECOVER, 36, Vector2.ZERO],
		[WorldReader.STATE_MOVE, 60, Vector2(-0.03, 0.02)],
	]
	var t := 0
	for step: Array in plan:
		for k in int(step[1]):
			t += 1
			var s := {
				"tick": t,
				"state": step[0],
				"pos": (step[2] as Vector2) * t,
				"hp": 30 - t / 60,
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)


func test_actor_views_draw_the_kind_with_it() -> void:
	var w := CombatLab.world()
	w.add_enemy(ActorStore.Kind.BOMB_DRONE, Vector2(4, 0))
	var views := ActorViews.new()
	add_child_autofree(views)
	views.sync(WorldReader.new(w))
	var node := views.actor_node(w.actors.ids[1])
	var a := node.get_meta(&"enemy_avatar") as BombDroneAvatar
	assert_not_null(a)
	assert_true(a.has_model or a.vat, "the owner's model")
