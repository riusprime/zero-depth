extends GutTest
## The Needle on the owner's model (NeedleAvatar): its parts load into their joints, each clip moves the parts it
## should (the trot with its feet planted, the stepping turn, the plant's brace, the burst's three kicks with the feet
## still down, the vent, a hit, the rise-in, the death), reduced motion moves less and never shakes, a missing model
## falls back to the code-made body that plays the same clips, its biome's version wears its own colours, and the VAT
## bake matches the live pose (a VAT avatar keeps the same drives, lift and glows through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_NEEDLE
const N = preload("res://src/presentation/world_view/needle_avatar.gd")
## A step a tick at its run speed (the sim's plane, toward its front).
const RUN := Vector2(3.2 / 60.0, 0.0)

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


## A Needle under a facing node (the one ActorViews turns), its own processing off.
func _needle(look := -1) -> NeedleAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := NeedleAvatar.new()
	a.look_kind = look
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## Ticks of a state: apply_state then a frame, `n` times; the place moves by `step` a tick, the facing turns by `turn`.
func _run(
	a: NeedleAvatar, from: int, n: int, s: Dictionary, step := Vector2.ZERO, turn := 0.0
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


func _move(hp := 30) -> Dictionary:
	return {"state": WorldReader.STATE_MOVE, "windup": 0.0, "hp": hp}


func _windup(p: float) -> Dictionary:
	return {"state": WorldReader.STATE_WINDUP, "windup": p, "hp": 30}


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"needle"), "the model file is installed")
	var a := _needle()
	assert_true(a.has_model)
	assert_eq(a.uppers.size(), 4, "four upper legs")
	assert_eq(a.lowers.size(), 4, "four clawed feet")
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 11, "the body, the hood, the barrel and eight leg halves")
	for k in 4:
		assert_eq(a.lowers[k].get_parent(), a.uppers[k], "a foot hangs from its leg")
	for n: Node3D in [a.shell, a.barrel]:
		assert_eq(n.get_parent(), a.rig, "%s sits on the body" % n.name)
	var glows := {}
	for mi: MeshInstance3D in meshes:
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.emission_enabled and not m in a.body_materials:
				glows[String(mi.name)] = m.has_meta(SoloVat.GLOW)
	assert_eq(
		glows, {"body": false, "barrel": true}, "the gem on the body; the muzzle at its drive"
	)
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")
	assert_eq(
		a.body_materials[1].albedo_color, Color("#3A6BD4"), "the role plates in the ranged blue"
	)


func test_the_muzzle_is_the_barrel_s_tip_and_slides_back_with_it() -> void:
	var a := _needle()
	var t := _run(a, 0, 60, _move())
	assert_almost_eq(a.muzzle_at().x, N.MUZZLE_AT.x, 0.03, "at the barrel's tip")
	assert_almost_eq(a.muzzle_at().y, N.MUZZLE_AT.y, 0.03)
	var rest := a.muzzle_at().x
	t = _run(a, t, 30, _windup(1.0))
	_run(a, t, 2, {"state": WorldReader.STATE_ACTIVE, "hp": 30})
	assert_lt(a.muzzle_at().x, rest - 0.05, "the tip slides back with the kick")


func test_the_trot_plants_its_feet_and_steps_the_diagonals_together() -> void:
	var a := _needle()
	var t := _run(a, 0, 40, _move(), RUN)
	var low := 99.0
	var high := -99.0
	var span := [99.0, -99.0]
	var same := 0.0
	var opposite := 0.0
	for k in 60:
		t = _run(a, t, 1, _move(), RUN)
		var f := a.foot_at(0)
		low = minf(low, f.y)
		high = maxf(high, f.y)
		span[0] = minf(span[0], f.x)
		span[1] = maxf(span[1], f.x)
		var h0 := f.y - 0.03
		same += h0 * (a.foot_at(3).y - 0.03)  # bl: fr's diagonal
		opposite += h0 * (a.foot_at(1).y - 0.03)  # fl: the other pair
	assert_lt(low, 0.03, "the front foot comes down to the ground: %.3f" % low)
	assert_gt(high, 0.06, "and lifts in its swing: %.3f" % high)
	assert_gt(span[1] - span[0], 0.15, "the foot sweeps a stride: %s" % [span])
	assert_gt(same, 0.0, "fr and bl step together")
	assert_lt(opposite, 0.0, "fr and fl step in turn")


func test_a_planted_foot_stays_put_on_the_ground_while_the_body_moves() -> void:
	var a := _needle()
	var t := _run(a, 0, 40, _move(), RUN)
	var worst := 0.0
	var down := 0
	var last := a.foot_at(2)
	var was_down := false
	for k in 60:
		t = _run(a, t, 1, _move(), RUN)
		var f := a.foot_at(2)
		var q := fposmod(a._phase - float(N.STRIDE_AT[2]), 1.0)
		var down_now := q > 0.02 and q < N.DUTY - 0.02
		if down_now and was_down:  # (a frame and the one before it both on the ground)
			down += 1
			assert_lt(f.y, 0.03, "a planted foot on the ground")
			worst = maxf(worst, absf((f.x - last.x) + 3.2 * DT))
		last = f
		was_down = down_now
	assert_gt(down, 10)
	assert_lt(worst, 0.008, "a planted foot keeps still on the ground: %.4f m a frame off" % worst)


func test_turning_in_place_steps_its_legs() -> void:
	var a := _needle()
	var t := _run(a, 0, 20, _move())
	var lifted := 0.0
	var turn := 2.5 / 60.0
	t = _run(a, t, 20, _move(), Vector2.ZERO, turn)
	for k in 60:
		t = _run(a, t, 1, _move(), Vector2.ZERO, turn)
		lifted = maxf(lifted, a.foot_at(0).y)
	assert_gt(lifted, 0.05, "its feet lift as it steps round")
	_run(a, t, 60, _move())
	assert_lt(a.foot_at(0).distance_to(N.FEET[0]), 0.04, "and settle when the turn stops")


func test_the_plant_braces_it_and_charges_the_gem_and_the_muzzle() -> void:
	var a := _needle()
	var t := _run(a, 0, 30, _move())
	var rest_gem := a.eye_energy()
	var feet := []
	for k in 4:
		feet.append(a.foot_at(k))
	var peak := 0.0
	for k in 30:
		t = _run(a, t, 1, _windup(float(k + 1) / 30.0))
		peak = maxf(peak, a.eye_energy())
	assert_lt(a.vat_lift(), -0.05, "the body dropped between its legs: %.3f" % a.vat_lift())
	assert_lt(a.drives()[N.PITCH], -0.03, "its nose tipped down the aim")
	assert_gt(a.drives()[N.BARREL], 0.02, "the barrel ran out")
	assert_gt(peak, rest_gem * 2.5, "the gem climbs and flashes")
	assert_gt(a.muzzle_energy(), N.MUZZLE_CHARGE * 0.7, "the muzzle charged")
	assert_gt(a.crouch_amount(), 0.9)
	for k in 4:
		assert_lt(a.foot_at(k).y, 0.03, "foot %d stays on the ground" % k)
		var out := Vector2(a.foot_at(k).x, a.foot_at(k).z).length()
		assert_gt(out, Vector2(feet[k].x, feet[k].z).length() + 0.01, "foot %d dug in wider" % k)


func test_the_burst_kicks_the_barrel_once_a_bolt_with_the_feet_planted() -> void:
	var a := _needle()
	var t := _run(a, 0, 30, _move())
	t = _run(a, t, 30, _windup(1.0))
	var feet := []
	for k in 4:
		feet.append(a.foot_at(k))
	var kicks := 0
	var back := false
	var flare := 0.0
	var drift := 0.0
	for k in 33:  # (the burst's third bolt leaves 12 ticks into the attack: 13 active ticks)
		var st := WorldReader.STATE_ACTIVE if k < 13 else WorldReader.STATE_RECOVER
		t = _run(a, t, 1, {"state": st, "hp": 30})
		flare = maxf(flare, a.muzzle_energy())
		var far := a.barrel_recoil() > 0.04
		if far and not back:
			kicks += 1
		back = far
		if k < 13:
			for j in 4:
				drift = maxf(drift, a.foot_at(j).distance_to(feet[j]))
	assert_eq(kicks, N.BURST_COUNT, "a kick for each bolt")
	assert_gt(flare, N.MUZZLE_CHARGE, "the muzzle flares")
	assert_lt(drift, 0.02, "the feet stay where they stood: %.3f" % drift)
	assert_gt(a.drives()[N.SHELL_UP], 0.01, "the hood lifts to vent after the burst")
	_run(a, t, 60, _move())
	assert_almost_eq(a.barrel_recoil(), 0.0, 0.005, "the barrel back at rest")


func test_a_hit_jolts_it_back() -> void:
	var calm := _needle()
	var hit := _needle()
	var t := _run(calm, 0, 30, _move())
	_run(hit, 0, 30, _move())
	_run(calm, t, 3, _move())
	_run(hit, t, 3, _move(20))
	assert_lt(hit.drives()[N.SURGE], calm.drives()[N.SURGE] - 0.02, "the body jolts back")
	assert_gt(absf(hit.drives()[N.ROLL] - calm.drives()[N.ROLL]), 0.02, "and rolls")


func test_it_rises_in_from_a_crouch_on_its_feet() -> void:
	var a := _needle()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO, "hp": 30})
	a.advance(DT)
	assert_lt(a.vat_lift(), -0.1, "crouched")
	for k in 4:
		assert_lt(absf(a.foot_at(k).y - N.FEET[k].y), 0.02, "foot %d on the ground" % k)
	_run(a, 1, 60, _move())
	assert_almost_eq(a.vat_lift(), 0.0, 0.02, "risen")


func test_the_death_drops_it_and_puts_its_lights_out() -> void:
	var a := _needle()
	_run(a, 0, 30, _move(10))
	assert_true(a.die())
	assert_true(a.dying())
	for k in int(N.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_lt(a.vat_lift(), -0.12, "the body dropped")
	assert_lt(a.drives()[N.PITCH], -0.1, "nose first")
	assert_gt(a.drives()[N.SHELL_P], 0.1, "the hood slid back off it")
	assert_lt(a.eye_energy(), 0.3, "the gem out")
	assert_lt(a.muzzle_energy(), 0.05, "the muzzle cold")


func test_the_knees_stay_off_the_ground_through_every_clip() -> void:
	var a := _needle()
	var lowest := [99.0, ""]
	var check := func(at: String) -> void:
		for k in 4:
			var y := a.knee_at(k).y
			if y < lowest[0]:
				lowest[0] = y
				lowest[1] = "%s, leg %d" % [at, k]
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO, "hp": 30})
	a.advance(DT)
	check.call("rise-in")
	var t := 1
	for k in 60:
		t = _run(a, t, 1, _move(), RUN)
		check.call("trot")
	for k in 30:
		t = _run(a, t, 1, _windup(float(k + 1) / 30.0))
		check.call("plant")
	for k in 12:
		t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 30})
		check.call("burst")
	a.die()
	for k in 60:
		a.advance(DT)
		check.call("death")
	assert_gt(float(lowest[0]), 0.03, "the lowest knee: %s" % [lowest])


func test_reduced_motion_moves_less_and_never_shakes() -> void:
	var spans := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _needle()
		var t := _run(a, 0, 40, _move(), RUN)
		var p := [99.0, -99.0]
		for k in 40:
			t = _run(a, t, 1, _move(), RUN)
			p[0] = minf(p[0], a.drives()[N.ROLL])
			p[1] = maxf(p[1], a.drives()[N.ROLL])
		t = _run(a, t, 30, _windup(1.0))
		var base := a.drives()[N.PITCH]
		t = _run(a, t, 4, {"state": WorldReader.STATE_ACTIVE, "hp": 30})
		spans.append([p[1] - p[0], a.drives()[N.PITCH] - base])
	assert_lt(spans[1][0], spans[0][0] * 0.6, "the trot's rock is smaller: %s" % [spans])
	assert_lt(spans[1][1], spans[0][1] * 0.7, "the burst's rock is smaller: %s" % [spans])
	ViewPrefs.reduced_motion = true
	var b := _needle()
	_run(b, 0, 30, _move(10))
	b.die()
	var worst := 0.0
	var last := b.drives().duplicate()
	for k in 60:
		b.advance(DT)
		for j in [N.ROLL, N.PITCH, N.SHELL_P, N.LEG0 + 7, N.LEG0 + 8]:
			worst = maxf(worst, absf(b.drives()[j] - last[j]))
		last = b.drives().duplicate()
	assert_lt(worst, 0.08, "no shake or kick: %.3f a frame at most" % worst)


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _needle()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	assert_eq(a.uppers.size(), 4)
	var t := _run(a, 0, 30, _move())
	var r0 := a.uppers[0].rotation
	_run(a, t, 20, _move(), RUN)
	assert_ne(a.uppers[0].rotation, r0, "its legs still walk")
	assert_null(a.vat_texture(), "no colour map")


func test_the_dim_needle_wears_its_own_colours_on_the_same_model() -> void:
	var a := _needle(WorldReader.KIND_DIM_NEEDLE)
	assert_true(a.has_model)
	var c := EnemyPalettes.color(WorldReader.KIND_DIM_NEEDLE, &"body")
	assert_eq(a.body_materials[1].albedo_color, c, "its plates in its biome's colour")
	assert_false(VatCrowd.supports(WorldReader.KIND_DIM_NEEDLE), "drawn as its own nodes")


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
		[WorldReader.STATE_SPAWN, 20, 0.0, 30],
		[WorldReader.STATE_MOVE, 60, 3.2, 30],
		[WorldReader.STATE_WINDUP, 30, 0.0, 30],
		[WorldReader.STATE_ACTIVE, 12, 0.0, 30],
		[WorldReader.STATE_RECOVER, 20, 0.0, 22],
		[WorldReader.STATE_MOVE, 30, -3.2, 12],
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
				"windup": float(k + 1) / 30.0 if step[0] == WorldReader.STATE_WINDUP else 0.0,
				"hp": step[3],
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
