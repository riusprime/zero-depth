extends GutTest
## The Wire Weaver on the owner's model (WireWeaverAvatar): its parts load into their joints and it carries two posts,
## each clip moves the parts it should (the four-legged walk in two pairs, the tell lifting the posts, the plant
## launching them and the reload growing new ones, a hit, the death), reduced motion moves less and never shakes, a
## missing model falls back to the code-made body that plays the same clips, and the VAT bake matches the live pose (a
## VAT avatar keeps the same drives, lift and glows through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_WIRE_WEAVER
const W := preload("res://src/presentation/world_view/wire_weaver_avatar.gd")

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


## A Weaver under a facing node (the one ActorViews turns), its own processing off.
func _weaver() -> WireWeaverAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := WireWeaverAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## Ticks of a state: apply_state then a frame, `n` times; the place moves by `step` a tick.
func _run(a: WireWeaverAvatar, from: int, n: int, s: Dictionary, step := Vector2.ZERO) -> int:
	for k in n:
		var t := from + k
		var d := s.duplicate()
		d["tick"] = t
		d["pos"] = step * float(t)
		a.apply_state(d)
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


func _move(hp := 40) -> Dictionary:
	return {"state": WorldReader.STATE_MOVE, "windup": 0.0, "hp": hp}


func _windup(p: float) -> Dictionary:
	return {"state": WorldReader.STATE_WINDUP, "windup": p, "hp": 40}


## Through the whole tell (0.7 s) to the plant tick; returns the tick after.
func _tell_and_plant(a: WireWeaverAvatar, t: int) -> int:
	for k in 42:
		t = _run(a, t, 1, _windup(float(k + 1) / 42.0))
	return _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 40})


func _d(a: WireWeaverAvatar, j: int) -> float:
	return a.drives()[j]


func test_the_owner_s_model_is_cut_into_its_joints_and_carries_two_posts() -> void:
	assert_true(EnemyModels.has_model(&"wire_weaver"), "the model file is installed")
	assert_false(RuinsRocksAvatar.draws(KIND), "the code stand-in no longer draws it")
	var a := _weaver()
	assert_true(a.has_model)
	assert_eq(a.uppers.size(), 4, "four legs")
	assert_eq(a.lowers.size(), 4, "four shins")
	assert_eq(a.arms.size(), 2, "two arms")
	assert_eq(a.forearms.size(), 2, "two forearms")
	assert_eq(a.posts.size(), 2, "two carried posts")
	for k in 4:
		assert_eq(a.lowers[k].get_parent(), a.uppers[k], "a shin hangs from its leg")
	for k in 2:
		assert_eq(a.forearms[k].get_parent(), a.arms[k], "a forearm hangs from its arm")
		assert_eq(a.posts[k].get_parent(), a.rig, "a post rides the body")
	assert_eq(a.spool.get_parent(), a.rig, "the spool turns on the body")
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 15 + 6, "the model's 15 parts and each post's rod, foot and top")
	var visor := 0
	var sparks := 0
	for mi: MeshInstance3D in meshes:
		var ms: Array = [mi.material_override]
		for k in mi.mesh.get_surface_count():
			ms.append(mi.get_surface_override_material(k))
		for m: Variant in ms:
			var sm := m as StandardMaterial3D
			if sm != null and sm.has_meta(SoloVat.GLOW):
				visor += 1
				assert_eq(String(mi.name), "head", "the visor is the head's glow")
			elif sm != null and sm.emission_enabled and not sm in a.body_materials:
				sparks += 1
	assert_eq(visor, 1, "the gem visor")
	assert_eq(sparks, 2, "each post's glowing top")
	assert_eq(
		a.body_materials.size(),
		2,
		"the base and role plates take the flash (the posts wear the base plates' map)"
	)
	assert_true(a.carrying(), "it starts with its posts")


func test_the_walk_steps_its_legs_in_two_pairs_and_rocks_the_body() -> void:
	var a := _weaver()
	var step := Vector2(W.MOVE_SPEED / 60.0, 0)
	var t := _run(a, 0, 40, _move(), step)
	var lo := 99.0
	var hi := -99.0
	var same := 0.0
	var opposite := 0.0
	var roll := [99.0, -99.0]
	var r0 := a.uppers[1].rotation
	var moved := false
	for k in 40:
		t = _run(a, t, 1, _move(), step)
		var rr := _d(a, W.LEG0 + 3)
		lo = minf(lo, rr)
		hi = maxf(hi, rr)
		same += rr * _d(a, W.LEG0 + 6)  # ml: rr's pair
		opposite += rr * _d(a, W.LEG0 + 0)  # rc: the other pair
		roll[0] = minf(roll[0], _d(a, W.ROLL))
		roll[1] = maxf(roll[1], _d(a, W.ROLL))
		moved = moved or a.uppers[1].rotation.distance_to(r0) > 0.2
	assert_gt(hi - lo, 0.6, "a leg sweeps a stride: %.2f" % (hi - lo))
	assert_gt(same, 0.0, "the back-right and left legs step together")
	assert_lt(opposite, 0.0, "the back-right and rear legs step in turn")
	assert_gt(roll[1] - roll[0], 0.05, "the body rocks with the pairs")
	assert_true(moved, "the leg node follows its drives")


func test_backing_away_reverses_the_stride() -> void:
	var a := _weaver()
	var t := _run(a, 0, 40, _move(), Vector2(-W.MOVE_SPEED / 60.0, 0))
	assert_lt(a.get(&"_speed"), -1.5, "its speed along its facing is backwards")
	var lifted := 0.0
	for k in 30:
		t = _run(a, t, 1, _move(), Vector2(-W.MOVE_SPEED / 60.0, 0))
		lifted = maxf(lifted, _d(a, W.LEG0 + 1))
	assert_gt(lifted, 0.2, "its legs still step")


func test_the_tell_lifts_the_posts_sparking_and_raises_the_arms() -> void:
	var a := _weaver()
	var t := _run(a, 0, 30, _move())
	var spark0 := a.spark_energy()
	var crouch := 0.0
	var peak := 0.0
	for k in 42:
		t = _run(a, t, 1, _windup(float(k + 1) / 42.0))
		if k < 8:
			crouch = minf(crouch, a.vat_lift())
		peak = maxf(peak, a.visor_energy())
	assert_lt(crouch, -0.01, "a short crouch first")
	assert_gt(_d(a, W.POST0), 0.12, "the posts rise out of their straps")
	assert_gt(_d(a, W.POST0 + 1), 0.25, "and tip forward")
	assert_gt(a.spark_energy(), spark0 + 3.0, "their tops spark brighter")
	assert_gt(_d(a, W.ARM0 + 1), 0.5, "the arms raised")
	assert_gt(_d(a, W.PITCH), 0.1, "leaning back, braced")
	assert_gt(peak, W.VISOR_REST + 3.0, "the visor climbs and flashes")
	assert_true(a.carrying(), "still carrying them")


func test_the_plant_launches_the_posts_and_the_reload_grows_new_ones() -> void:
	var a := _weaver()
	var t := _run(a, 0, 30, _move())
	for k in 42:
		t = _run(a, t, 1, _windup(float(k + 1) / 42.0))
	assert_lt(_d(a, W.SPOOL), -0.25, "the drum wound back taut")
	t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 40})
	var out := -9.0
	for k in 12:
		t = _run(a, t, 1, {"state": WorldReader.STATE_RECOVER, "hp": 40})
		out = maxf(out, _d(a, W.SPOOL))
	assert_false(a.carrying(), "the posts are gone (they stand at the cable's ends)")
	assert_gt(_d(a, W.ARM0), 0.5, "the arms sweep apart along the cable")
	assert_gt(out, 0.15, "the drum jerks out paying the cable off")
	t = _run(a, t, 18, {"state": WorldReader.STATE_RECOVER, "hp": 40})
	t = _run(a, t, 10, _move())
	assert_false(a.carrying(), "empty-handed a while")
	t = _run(a, t, 60, _move())
	assert_true(a.carrying(), "new posts grown")
	assert_almost_eq(_d(a, W.POST0), 0.0, 0.01, "back in their straps")


func test_a_hit_jolts_the_body_and_scrabbles_a_leg() -> void:
	var a := _weaver()
	var b := _weaver()  # the same, not hit
	var t := _run(a, 0, 30, _move())
	_run(b, 0, 30, _move())
	_run(a, t, 4, _move(30))
	_run(b, t, 4, _move())
	assert_lt(_d(a, W.HEAD_P), _d(b, W.HEAD_P) - 0.15, "the head ducks")
	assert_gt(_d(a, W.PITCH), _d(b, W.PITCH) + 0.06, "the body jolts back")
	var leg := 0.0
	for j in 4:
		leg = maxf(leg, _d(a, W.LEG0 + 3 * j + 1) - _d(b, W.LEG0 + 3 * j + 1))
	assert_gt(leg, 0.3, "a leg scrabbles")


func test_the_death_drops_it_on_its_belly_and_puts_the_lights_out() -> void:
	var a := _weaver()
	_run(a, 0, 30, _move(10))
	assert_true(a.die())
	assert_true(a.dying())
	for k in int(W.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_lt(a.vat_lift(), -0.25, "dropped onto its belly")
	assert_gt(_d(a, W.LEG0 + 1), 0.8, "the legs buckled out")
	assert_lt(_d(a, W.ROLL), -0.2, "rolled aside")
	assert_lt(_d(a, W.POST0 + 1), -0.9, "the posts toppled back")
	assert_lt(a.visor_energy(), W.VISOR_REST * 0.2, "the visor dies")
	assert_lt(a.spark_energy(), W.SPARK_REST * 0.2, "the sparks fizzle out")


func test_reduced_motion_moves_less_and_never_shakes() -> void:
	var spans := []
	var step := Vector2(W.MOVE_SPEED / 60.0, 0)
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _weaver()
		var t := _run(a, 0, 40, _move(), step)
		var p := [99.0, -99.0]
		for k in 40:
			t = _run(a, t, 1, _move(), step)
			p[0] = minf(p[0], _d(a, W.ROLL))
			p[1] = maxf(p[1], _d(a, W.ROLL))
		t = _run(a, t, 30, _windup(0.7))
		spans.append([p[1] - p[0], _d(a, W.PITCH)])
	assert_lt(spans[1][0], spans[0][0] * 0.6, "the walk's rock is smaller: %s" % [spans])
	assert_lt(spans[1][1], spans[0][1] * 0.6, "the lean back is smaller: %s" % [spans])
	ViewPrefs.reduced_motion = true
	var b := _weaver()
	_run(b, 0, 30, _move(10))
	b.die()
	var worst := 0.0
	var last := b.drives().duplicate()
	var glow := b.spark_energy()
	var glow_jump := 0.0
	for k in 50:
		b.advance(DT)
		for j in [W.ROLL, W.PITCH, W.LEG0 + 2, W.LEG0 + 5]:
			worst = maxf(worst, absf(b.drives()[j] - last[j]))
		glow_jump = maxf(glow_jump, absf(b.spark_energy() - glow))
		glow = b.spark_energy()
		last = b.drives().duplicate()
	assert_lt(worst, 0.06, "no shake or scrabble: %.3f a frame at most" % worst)
	assert_lt(glow_jump, 0.2, "no fizzle flicker: %.3f a frame at most" % glow_jump)


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _weaver()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 8, "the code-made plates")
	assert_eq(a.uppers.size(), 4)
	var t := _run(a, 0, 30, _move())
	var r0 := a.uppers[0].rotation
	t = _run(a, t, 20, _move(), Vector2(W.MOVE_SPEED / 60.0, 0))
	assert_ne(a.uppers[0].rotation, r0, "its legs still walk")
	t = _tell_and_plant(a, t)
	_run(a, t, 10, {"state": WorldReader.STATE_RECOVER, "hp": 40})
	assert_false(a.carrying(), "and it still plants its posts")
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
	assert_eq(vat.find_children("*", "MeshInstance3D", true, false).size(), 0, "no pieces")
	var plan := [
		[WorldReader.STATE_SPAWN, 20, 0.0, 40],
		[WorldReader.STATE_MOVE, 60, 2.6, 40],
		[WorldReader.STATE_WINDUP, 42, 0.0, 40],
		[WorldReader.STATE_ACTIVE, 1, 0.0, 40],
		[WorldReader.STATE_RECOVER, 30, 0.0, 30],
		[WorldReader.STATE_MOVE, 60, -2.6, 12],
	]
	var t := 0
	var x := 0.0
	for step: Array in plan:
		for k in int(step[1]):
			x += float(step[2]) / 60.0
			var s := {
				"tick": t,
				"pos": Vector2(x, 0.0),
				"state": step[0],
				"windup": float(k + 1) / 42.0 if step[0] == WorldReader.STATE_WINDUP else 0.0,
				"hp": step[3],
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
