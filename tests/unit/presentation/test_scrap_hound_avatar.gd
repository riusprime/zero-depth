extends GutTest
## v0.11.0 O17a: the Scrap Hound on the owner's model (ScrapHoundAvatar): its parts load into their joints, each clip
## moves the parts it should (the gait, the turn to the way it runs, the tell, the dart, the bite, the yelp, a plain
## hit, the death), reduced motion moves less, a missing model falls back to the code-made body that plays the same
## clips, and the VAT bake matches the live pose (a VAT avatar keeps the same drives, lift and glow through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_SCRAP_HOUND

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


func _hound() -> ScrapHoundAvatar:
	var a := ScrapHoundAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


## Ticks of a state: apply_state then a frame, `n` times; `pos_of(k)` the place at tick k.
func _run(a: ScrapHoundAvatar, from: int, n: int, s: Dictionary, step := Vector2.ZERO) -> int:
	for k in n:
		var t := from + k
		var d := s.duplicate()
		d["tick"] = t
		d["pos"] = step * float(t)
		a.apply_state(d)
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


func _move() -> Dictionary:
	return {"state": WorldReader.STATE_MOVE, "windup": 0.0, "hp": 30}


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"scrap_hound"), "the model file is installed")
	var a := _hound()
	assert_true(a.has_model)
	assert_eq(a.uppers.size(), 4, "four upper legs")
	assert_eq(a.lowers.size(), 4, "four lower legs")
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 12, "chest, hips, head, tail and eight leg halves")
	for leg in a.lowers:
		assert_eq(
			leg.get_parent(), a.uppers[a.lowers.find(leg)], "a lower leg hangs from its upper"
		)
	assert_eq(a.tail.get_parent(), a.hips, "the tail hangs from the hips")
	var glows := 0
	for mi: MeshInstance3D in meshes:
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.emission_energy_multiplier >= ScrapHoundAvatar.VISOR_REST:
				glows += 1
	assert_gt(glows, 0, "the visor is its glowing surface")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")


func test_the_gait_runs_the_legs_and_the_body_turns_to_the_way_it_runs() -> void:
	var a := _hound()
	var t := _run(a, 0, 30, _move())
	var still := a.drives().duplicate()
	var lo := 99.0
	var hi := -99.0
	var r0 := a.uppers[0].rotation.z
	var moved := false
	for k in 60:
		t = _run(a, t, 1, _move(), Vector2(0.0, 6.5 / 60.0))  # running along sim +y, facing +x
		var u := a.drives()[ScrapHoundAvatar.LEG0]
		lo = minf(lo, u)
		hi = maxf(hi, u)
		moved = moved or absf(a.uppers[0].rotation.z - r0) > 0.2
	assert_gt(hi - lo, 0.8, "the front leg sweeps through a gallop's stride: %.2f" % (hi - lo))
	assert_true(moved, "the leg node follows its drive")
	assert_gt(a.stride_hz(), 3.0, "a gallop's stride rate at 6.5 m/s")
	assert_almost_eq(a.body_yaw(), PI * 0.5, 0.15, "the body turns to the way it runs")
	assert_almost_eq(a.rotation.y, a.body_yaw(), 0.001, "as its own node's yaw")
	assert_ne(a.drives()[ScrapHoundAvatar.SPINE], still[ScrapHoundAvatar.SPINE], "the spine flexes")


func test_the_tell_sinks_it_and_flashes_the_visor() -> void:
	var a := _hound()
	var t := _run(a, 0, 30, _move())
	var lift0 := a.vat_lift()
	var peak := 0.0
	for k in 24:
		t = _run(
			a, t, 1, {"state": WorldReader.STATE_WINDUP, "windup": float(k + 1) / 24.0, "hp": 30}
		)
		peak = maxf(peak, a.visor_energy())
	assert_gt(peak, ScrapHoundAvatar.VISOR_REST + 3.0, "the visor climbs and flashes")
	assert_lt(a.vat_lift(), lift0 - 0.04, "it sinks low")
	assert_gt(a.drives()[ScrapHoundAvatar.PITCH], 0.08, "its weight back")
	assert_gt(a.drives()[ScrapHoundAvatar.LEG0 + 4], 0.3, "the hind legs coiled under it")


func test_the_dart_reaches_and_the_bite_snaps_the_head() -> void:
	var a := _hound()
	var t := _run(a, 0, 30, _move())
	t = _run(a, t, 24, {"state": WorldReader.STATE_WINDUP, "windup": 1.0, "hp": 30})
	t = _run(a, t, 12, {"state": WorldReader.STATE_ACTIVE, "hp": 30}, Vector2(14.0 / 60.0, 0))
	assert_gt(a.drives()[ScrapHoundAvatar.LEG0], 0.6, "the front legs reach")
	assert_lt(a.drives()[ScrapHoundAvatar.LEG0 + 4], -0.4, "the hind legs drive back")
	assert_lt(a.drives()[ScrapHoundAvatar.SPINE], -0.15, "the spine stretched")
	var head := a.drives()[ScrapHoundAvatar.HEAD_P]
	t = _run(a, t, 5, {"state": WorldReader.STATE_RECOVER, "hp": 30})
	assert_lt(a.drives()[ScrapHoundAvatar.HEAD_P], head - 0.1, "the head snaps down: the bite")


func test_a_hit_in_the_tell_yelps_and_tucks_the_tail() -> void:
	var a := _hound()
	var t := _run(a, 0, 30, _move())
	t = _run(a, t, 10, {"state": WorldReader.STATE_WINDUP, "windup": 0.4, "hp": 30})
	var yelp := {"state": WorldReader.STATE_RECOVER, "yelped": true, "hp": 20}
	t = _run(a, t, 4, yelp)
	assert_gt(a.drives()[ScrapHoundAvatar.HEAD_P], 0.15, "the head flung up")
	t = _run(a, t, 12, yelp)
	assert_lt(a.drives()[ScrapHoundAvatar.TAIL_P], -0.5, "the tail tucked")
	assert_lt(a.drives()[ScrapHoundAvatar.SHIFT], -0.05, "it hops back")
	_run(a, t, 60, _move())
	assert_gt(a.drives()[ScrapHoundAvatar.TAIL_P], -0.2, "and settles")


func test_a_plain_hit_jerks_the_head() -> void:
	var a := _hound()
	var t := _run(a, 0, 30, _move())
	var head := a.drives()[ScrapHoundAvatar.HEAD_P]
	var hit := _move()
	hit["hp"] = 25
	_run(a, t, 4, hit)
	assert_gt(a.drives()[ScrapHoundAvatar.HEAD_P], head + 0.1, "the head jerks up")


func test_the_death_rolls_it_onto_its_side_and_puts_the_visor_out() -> void:
	var a := _hound()
	var t := _run(a, 0, 30, _move())
	assert_true(a.die())
	assert_true(a.dying())
	for k in int(ScrapHoundAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_lt(a.drives()[ScrapHoundAvatar.ROLL], -1.2, "on its side")
	assert_lt(a.visor_energy(), ScrapHoundAvatar.VISOR_REST * 0.2, "the visor out")
	assert_gt(t, 0)


func test_reduced_motion_moves_less_and_never_shakes() -> void:
	var spans := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _hound()
		var t := _run(a, 0, 60, _move(), Vector2(6.5 / 60.0, 0))
		var p := [99.0, -99.0]
		for k in 40:
			t = _run(a, t, 1, _move(), Vector2(6.5 / 60.0, 0) * 1.0)
			p[0] = minf(p[0], a.drives()[ScrapHoundAvatar.PITCH])
			p[1] = maxf(p[1], a.drives()[ScrapHoundAvatar.PITCH])
		t = _run(a, t, 10, {"state": WorldReader.STATE_WINDUP, "windup": 0.4, "hp": 30})
		t = _run(a, t, 4, {"state": WorldReader.STATE_RECOVER, "yelped": true, "hp": 20})
		spans.append([p[1] - p[0], a.drives()[ScrapHoundAvatar.HEAD_P]])
	assert_lt(spans[1][0], spans[0][0] * 0.6, "the gallop's rock is smaller: %s" % [spans])
	assert_lt(spans[1][1], spans[0][1] * 0.6, "the yelp's head jerk is smaller: %s" % [spans])
	# no shiver in the tell's end with reduced motion: the roll holds still between frames
	ViewPrefs.reduced_motion = true
	var b := _hound()
	var u := _run(b, 0, 30, _move())
	u = _run(b, u, 22, {"state": WorldReader.STATE_WINDUP, "windup": 0.95, "hp": 30})
	var r := b.drives()[ScrapHoundAvatar.ROLL]
	_run(b, u, 1, {"state": WorldReader.STATE_WINDUP, "windup": 0.96, "hp": 30})
	assert_almost_eq(b.drives()[ScrapHoundAvatar.ROLL], r, 0.002, "no shiver")


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _hound()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 4, "the code-made plates")
	assert_eq(a.uppers.size(), 4)
	var t := _run(a, 0, 30, _move())
	var r0 := a.uppers[0].rotation.z
	_run(a, t, 20, _move(), Vector2(6.5 / 60.0, 0))
	assert_ne(a.uppers[0].rotation.z, r0, "its legs still run")
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
		var e := VatVerify.pose_error(live, vat, pose, mesh, 60, 17)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
		assert_lt(float(e["max_m"]), 0.002, "within 2 mm (calm %s): %s" % [calm, e])
		assert_true(pose.has("albedo_tex"), "the owner's colour map")
		live.free()
		vat.free()


func test_a_vat_avatar_keeps_the_drives_lift_and_glow_through_a_fight() -> void:
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND)
	add_child_autofree(live)
	add_child_autofree(vat)
	live.set_process(false)
	vat.set_process(false)
	assert_eq(vat.find_children("*", "MeshInstance3D", true, false).size(), 0, "no pieces")
	var plan := [
		[WorldReader.STATE_SPAWN, 20, 0.0],
		[WorldReader.STATE_MOVE, 60, 6.5],
		[WorldReader.STATE_WINDUP, 24, 0.0],
		[WorldReader.STATE_ACTIVE, 20, 14.0],
		[WorldReader.STATE_RECOVER, 36, 0.0],
		[WorldReader.STATE_MOVE, 30, 6.5],
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
				"windup": float(k + 1) / 24.0 if step[0] == WorldReader.STATE_WINDUP else 0.0,
				"hp": 30,
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
