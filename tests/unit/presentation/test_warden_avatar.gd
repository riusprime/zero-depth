extends GutTest
## The Warden on the owner's model (WardenAvatar): its parts load into their joints, each clip moves the parts it
## should (the knuckle-walk with its feet and fists planted, the turn, the tell's raised fists and crouch, the slam
## with its dust ring, a hit, the rise-in, the death), the knees stay off the ground, reduced motion moves less, a
## missing model falls back to the code-made body that plays the same clips, and the VAT bake matches the live pose (a
## VAT avatar keeps the same drives, lift and glows through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_WARDEN
## A step a tick at its walking speed (the sim's plane, toward its front).
const WALK := Vector2(1.6 / 60.0, 0.0)

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


## A Warden under a facing node (the one ActorViews turns), its own processing off.
func _warden() -> WardenAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := WardenAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## Ticks of a state: apply_state then a frame, `n` times; the place moves by `step` a tick, the facing turns by `turn`.
func _run(
	a: WardenAvatar, from: int, n: int, s: Dictionary, step := Vector2.ZERO, turn := 0.0
) -> int:
	for k in n:
		var t := from + k
		var d := s.duplicate()
		d["tick"] = t
		d["pos"] = step * float(t)
		(a.get_parent() as Node3D).rotation.y += turn
		a.apply_state(d)
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


func _move(hp := 160) -> Dictionary:
	return {"state": WorldReader.STATE_MOVE, "windup": 0.0, "hp": hp}


func _state(st: int, p := 0.0) -> Dictionary:
	return {"state": st, "windup": p, "hp": 160, "radius": 2.4}


func _fist_y(a: WardenAvatar) -> float:
	return (a.limb_at(&"fist", 0).y + a.limb_at(&"fist", 1).y) * 0.5


func _ends(a: WardenAvatar) -> Array[Vector3]:
	return [
		a.limb_at(&"ankle", 0), a.limb_at(&"ankle", 1), a.limb_at(&"fist", 0), a.limb_at(&"fist", 1)
	]


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	var a := _warden()
	assert_true(a.has_model, "the owner's model is there")
	assert_not_null(a.rig)
	assert_not_null(a.head)
	assert_eq(a.arms.size(), 2, "two shoulders")
	assert_eq(a.fists.size(), 2, "two forearms with their fists")
	assert_eq(a.legs.size(), 2, "two thighs")
	assert_eq(a.shins.size(), 2, "two shins")
	assert_eq(a.feet.size(), 2, "two feet")
	for n: Node3D in [a.head, a.arms[0], a.fists[1], a.legs[0], a.shins[1], a.feet[0]]:
		var pieces := n.find_children("*", "MeshInstance3D", false, false)
		assert_gt(pieces.size(), 0, "%s has its piece" % n.name)
	assert_eq(a.body_materials.size(), 2, "the base and role plates take the hit flash")
	var bronze := EnemyPalettes.color(KIND, &"body")
	assert_eq(a.body_materials[1].albedo_color, bronze, "the shell in the role colour")
	var glows := 0
	for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.emission_enabled and m.emission_energy_multiplier > 1.0:
				glows += 1
	assert_gt(glows, 1, "the eye and the cracks glow")
	assert_not_null(a.dust, "the slam's dust ring")


func test_the_walk_plants_its_feet_and_fists_and_steps_them_in_turn() -> void:
	var a := _warden()
	var t := _run(a, 0, 40, _move(), WALK)
	var lifted := [0, 0, 0, 0]
	var worst := 0.0
	var last := _ends(a)
	for k in 60:
		t = _run(a, t, 1, _move(), WALK)
		var now := _ends(a)
		for j in 4:
			var q := fposmod(a._phase - float(WardenAvatar.STRIDE_AT[j]), 1.0)
			if q > 0.05 and q < WardenAvatar.DUTY - 0.05:  # down: it slides back as the body passes
				worst = maxf(worst, absf((now[j].x - last[j].x) + 1.6 * DT))
			elif q > WardenAvatar.DUTY + 0.1 and q < 0.9:
				var rest := 0.086 if j < 2 else 0.098
				if now[j].y > rest + 0.03:
					lifted[j] += 1
		last = now
	assert_lt(worst, 0.006, "a planted foot or fist keeps still: %.4f m a frame off" % worst)
	for j in 4:
		assert_gt(lifted[j], 3, "limb %d lifts as it swings" % j)


func test_turning_in_place_steps_its_limbs() -> void:
	var a := _warden()
	var t := _run(a, 0, 30, _move())
	var y0 := a.limb_at(&"ankle", 0).y
	var highest := y0
	for k in 40:
		t = _run(a, t, 1, _move(), Vector2.ZERO, 2.0 / 60.0)
		highest = maxf(highest, a.limb_at(&"ankle", 0).y)
	assert_gt(highest, y0 + 0.03, "a foot steps round as it turns")


func test_the_tell_raises_the_fists_overhead_and_crouches() -> void:
	var a := _warden()
	var t := _run(a, 0, 30, _move())
	var idle := _fist_y(a)
	var eye := a.visor_energy()
	for k in 36:
		t = _run(a, t, 1, _state(WorldReader.STATE_WINDUP, float(k + 1) / 36.0))
	assert_gt(a.raise_amount(), 0.8, "raised by late windup")
	assert_gt(_fist_y(a), idle + 0.8, "fists well above where they rest")
	assert_gt(_fist_y(a), 1.2, "fists over the head")
	assert_gt(a.crouch_amount(), 0.5, "the crouch deepens")
	assert_lt(a.vat_lift(), -0.04, "the knees bend")
	assert_gt(a.visor_energy(), eye * 1.5, "the eye brightens")


func test_the_slam_puts_the_fists_on_the_ground_in_front_and_kicks_up_dust() -> void:
	var a := _warden()
	var t := _run(a, 0, 30, _move())
	t = _run(a, t, 36, _state(WorldReader.STATE_WINDUP, 1.0))
	t = _run(a, t, 1, _state(WorldReader.STATE_ACTIVE))
	t = _run(a, t, 8, _state(WorldReader.STATE_RECOVER))
	assert_gt(a.slam_amount(), 0.9, "slammed")
	assert_lt(_fist_y(a), 0.25, "fists down at the ground")
	assert_gt(a.limb_at(&"fist", 0).x, 0.4, "in front")
	assert_gt(a.dust_amount(), 0.0, "the dust ring runs")
	assert_lt(a.drives()[WardenAvatar.PITCH], -0.3, "the chest pitched forward")
	_run(a, t, 60, _move())
	assert_lt(a.slam_amount(), 0.1, "back up after the recovery")


func test_a_hit_jolts_it_back() -> void:
	var a := _warden()
	var t := _run(a, 0, 40, _move())
	var surge := a.drives()[WardenAvatar.SURGE]
	t = _run(a, t, 1, _move(120))
	_run(a, t, 6, _move(120))
	assert_lt(a.drives()[WardenAvatar.SURGE], surge - 0.02, "jolted back")


func test_it_climbs_out_of_the_ground() -> void:
	var a := _warden()
	var t := _run(a, 0, 6, _state(WorldReader.STATE_SPAWN))
	assert_lt(a.vat_lift(), -0.8, "below the floor while spawning")
	assert_gt(_fist_y(a), a.vat_lift() + 0.6, "the fists reach up out of the ground first")
	_run(a, t, 40, _move())
	assert_gt(a.vat_lift(), -0.05, "risen")
	assert_gt(_fist_y(a), 0.05, "fists on the ground")


func test_the_death_buckles_it_forward_and_puts_the_glow_out() -> void:
	var a := _warden()
	_run(a, 0, 30, _move())
	var crack := a.glow_energy()
	assert_true(a.die(), "it plays a death")
	assert_true(a.dying())
	var peak := 0.0
	for k in roundi(WardenAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
		peak = maxf(peak, a.glow_energy())
	assert_gt(peak, crack + 1.0, "the cracks flare")
	assert_lt(a.glow_energy(), 0.2, "and go out")
	assert_lt(a.visor_energy(), 0.2, "the eye goes out")
	assert_lt(a.vat_lift(), -0.2, "it has dropped")
	assert_lt(a.drives()[WardenAvatar.PITCH], -0.4, "fallen forward")


func test_the_knees_stay_off_the_ground_through_every_clip() -> void:
	var a := _warden()
	var lowest := 9.0
	var t := _run(a, 0, 40, _move(), WALK)
	for plan: Array in [
		[_move(), 60, WALK],
		[_state(WorldReader.STATE_WINDUP, 1.0), 36, Vector2.ZERO],
		[_state(WorldReader.STATE_ACTIVE), 1, Vector2.ZERO],
		[_state(WorldReader.STATE_RECOVER), 30, Vector2.ZERO],
		[_move(120), 30, Vector2.ZERO],
	]:
		for k in int(plan[1]):
			t = _run(a, t, 1, plan[0], plan[2])
			for s in 2:
				lowest = minf(lowest, a.limb_at(&"knee", s).y)
	assert_gt(lowest, 0.04, "the knees stay over the floor: lowest %.3f m" % lowest)


func test_reduced_motion_moves_less_but_never_stands_still() -> void:
	var spans := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _warden()
		var t := _run(a, 0, 60, _move())
		var lo := 9.0
		var hi := -9.0
		for k in 120:
			t = _run(a, t, 1, _move())
			lo = minf(lo, a.drives()[WardenAvatar.ROLL])
			hi = maxf(hi, a.drives()[WardenAvatar.ROLL])
		spans.append(hi - lo)
	assert_gt(spans[0], 0.0, "idle sways")
	assert_lt(spans[1], spans[0] * 0.7, "reduced motion sways less")
	assert_gt(spans[1], 0.0, "but never stands still")


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _warden()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	var t := _run(a, 0, 30, _move())
	var r0 := a.legs[0].rotation
	_run(a, t, 20, _move(), WALK)
	assert_ne(a.legs[0].rotation, r0, "its legs still walk")
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
	assert_eq(pieces.size(), 1, "only the dust ring (a node of its own)")
	var plan := [
		[WorldReader.STATE_SPAWN, 20, 0.0, 160],
		[WorldReader.STATE_MOVE, 60, 1.6, 160],
		[WorldReader.STATE_WINDUP, 36, 0.0, 160],
		[WorldReader.STATE_ACTIVE, 1, 0.0, 160],
		[WorldReader.STATE_RECOVER, 40, 0.0, 120],
		[WorldReader.STATE_MOVE, 30, -1.6, 90],
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
				"windup": float(k + 1) / 36.0 if step[0] == WorldReader.STATE_WINDUP else 0.0,
				"hp": step[3],
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
