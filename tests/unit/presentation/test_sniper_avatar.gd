extends GutTest
## The Sniper on the owner's model (SniperAvatar): its parts load into their joints, each clip moves the parts it
## should (the tripod walk with its feet planted, the stepping turn, the aim's settled tripod and its sweep that locks
## onto the line, the shot's kick with the feet still down (twice for the Split Sniper), the vent, a hit, the rise-in,
## the death), reduced motion moves less and never shakes, a missing model falls back to the code-made body, its
## biome's version wears its own colours, the shot's tracer leaves at the barrel's height, and the VAT bake matches the
## live pose (a VAT avatar keeps the same drives, lift and glows through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_SNIPER
const S = preload("res://src/presentation/world_view/sniper_avatar.gd")
## A step a tick at its run speed (the sim's plane, toward its front).
const RUN := Vector2(2.6 / 60.0, 0.0)

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


## A Sniper under a facing node (the one ActorViews turns), its own processing off.
func _sniper(look := -1) -> SniperAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := SniperAvatar.new()
	a.look_kind = look
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## Ticks of a state: apply_state then a frame, `n` times; the place moves by `step` a tick, the facing turns by `turn`.
func _run(
	a: SniperAvatar, from: int, n: int, s: Dictionary, step := Vector2.ZERO, turn := 0.0
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


func _move(hp := 40) -> Dictionary:
	return {"state": WorldReader.STATE_MOVE, "windup": 0.0, "hp": hp}


func _aim(p: float) -> Dictionary:
	return {"state": WorldReader.STATE_WINDUP, "windup": p, "hp": 40}


## The aim (60 ticks), the shot's tick and `after` ticks of its recovery.
func _fire(a: SniperAvatar, t: int, after := 30) -> int:
	for k in 60:
		t = _run(a, t, 1, _aim(float(k + 1) / 60.0))
	t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 40})
	return _run(a, t, after, {"state": WorldReader.STATE_RECOVER, "hp": 40})


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"sniper"), "the model file is installed")
	var a := _sniper()
	assert_true(a.has_model)
	assert_eq(a.uppers.size(), 3, "three legs: a tripod")
	assert_eq(a.lowers.size(), 3)
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 9, "the body, the shell, the barrel and six leg halves")
	for k in 3:
		assert_eq(a.lowers[k].get_parent(), a.uppers[k], "a lower leg hangs from its upper")
	for n: Node3D in [a.shell, a.barrel]:
		assert_eq(n.get_parent(), a.rig, "%s sits on the body" % n.name)
	var glows := {}
	for mi: MeshInstance3D in meshes:
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.emission_enabled and not m in a.body_materials:
				glows[String(mi.name)] = m.has_meta(SoloVat.GLOW)
	assert_eq(
		glows, {"body": false, "barrel": true}, "the lens on the body; the muzzle at its drive"
	)
	assert_eq(
		a.body_materials[1].albedo_color, Color("#3A55C0"), "the role plates in the deeper blue"
	)
	assert_gt(S.MUZZLE_AT.x, S.HEIGHT * 0.75, "the barrel is the longest thing on it")


func test_the_muzzle_is_the_barrel_s_tip_and_the_tracer_leaves_level_with_it() -> void:
	var a := _sniper()
	_run(a, 0, 60, _move())
	assert_almost_eq(a.muzzle_at().x, S.MUZZLE_AT.x, 0.04, "at the barrel's tip")
	assert_almost_eq(a.muzzle_at().y, S.MUZZLE_AT.y, 0.04)
	var fx := HordeVisuals.new()
	add_child_autofree(fx)
	var o := Obb.new()
	o.center = Vector2(5, 0)
	o.half = Vector2(5, 0.1)
	fx._tracer(o)
	assert_almost_eq(
		fx.get_child(fx.get_child_count() - 1).position.y, S.MUZZLE_AT.y, 0.001, "the tracer"
	)


func test_the_tripod_walk_lifts_one_leg_at_a_time_with_the_others_planted() -> void:
	var a := _sniper()
	var t := _run(a, 0, 40, _move(), RUN)
	var high := 0.0
	var span := [99.0, -99.0]
	var most_up := 0
	for k in 60:
		t = _run(a, t, 1, _move(), RUN)
		var up := 0
		for j in 3:
			if a.foot_at(j).y > 0.03:
				up += 1
		most_up = maxi(most_up, up)
		var f := a.foot_at(0)
		high = maxf(high, f.y)
		span[0] = minf(span[0], f.x)
		span[1] = maxf(span[1], f.x)
	assert_eq(most_up, 1, "never more than one foot in the air")
	assert_gt(high, 0.07, "a foot lifts in its swing: %.3f" % high)
	assert_gt(span[1] - span[0], 0.2, "and sweeps a stride: %s" % [span])


func test_a_planted_foot_stays_put_on_the_ground_while_the_body_moves() -> void:
	var a := _sniper()
	var t := _run(a, 0, 40, _move(), RUN)
	var worst := 0.0
	var down := 0
	var last := a.foot_at(1)
	var was_down := false
	for k in 90:
		t = _run(a, t, 1, _move(), RUN)
		var f := a.foot_at(1)
		var q := fposmod(a._phase - float(S.STRIDE_AT[1]), 1.0)
		var down_now := q > 0.02 and q < S.DUTY - 0.02
		if down_now and was_down:
			down += 1
			assert_lt(f.y, 0.03, "a planted foot on the ground")
			worst = maxf(worst, absf((f.x - last.x) + 2.6 * DT))
		last = f
		was_down = down_now
	assert_gt(down, 20)
	assert_lt(worst, 0.008, "a planted foot keeps still on the ground: %.4f m a frame off" % worst)


func test_turning_in_place_steps_its_legs() -> void:
	var a := _sniper()
	var t := _run(a, 0, 20, _move())
	var lifted := 0.0
	var turn := 2.5 / 60.0
	t = _run(a, t, 20, _move(), Vector2.ZERO, turn)
	for k in 60:
		t = _run(a, t, 1, _move(), Vector2.ZERO, turn)
		lifted = maxf(lifted, a.foot_at(0).y)
	assert_gt(lifted, 0.05, "its feet lift as it steps round")
	_run(a, t, 60, _move())
	assert_lt(a.foot_at(0).distance_to(S.FEET[0]), 0.04, "and settle when the turn stops")


func test_the_aim_settles_the_tripod_sweeps_then_locks_on_and_charges() -> void:
	var a := _sniper()
	var t := _run(a, 0, 30, _move())
	var feet := []
	for k in 3:
		feet.append(a.foot_at(k))
	var early := [99.0, -99.0]
	var late := [99.0, -99.0]
	var peak := 0.0
	for k in 60:
		var p := float(k + 1) / 60.0
		t = _run(a, t, 1, _aim(p))
		var sway := a.drives()[S.SWAY]
		var span: Array = early if p < 0.45 else (late if p > 0.7 else [0.0, 0.0])
		span[0] = minf(span[0], sway)
		span[1] = maxf(span[1], sway)
		peak = maxf(peak, a.lens_energy())
		for j in 3:
			assert_lt(a.foot_at(j).y, 0.03, "foot %d stays down through the aim" % j)
	assert_gt(early[1] - early[0], 0.08, "it sweeps the barrel across the line: %s" % [early])
	assert_lt(late[1] - late[0], 0.01, "then holds it still on the line: %s" % [late])
	assert_lt(a.vat_lift(), -0.05, "the body sank onto its tripod: %.3f" % a.vat_lift())
	assert_lt(a.drives()[S.PITCH], -0.02, "the barrel tipped onto the aim")
	assert_gt(peak, S.LENS_REST * 2.5, "the lens climbs and flashes")
	assert_gt(a.muzzle_energy(), S.MUZZLE_CHARGE * 0.7, "the muzzle charged")
	for k in 3:
		var out := Vector2(a.foot_at(k).x, a.foot_at(k).z).length()
		assert_gt(out, Vector2(feet[k].x, feet[k].z).length() + 0.01, "foot %d pressed out" % k)


func test_the_shot_kicks_the_barrel_with_the_feet_planted() -> void:
	var a := _sniper()
	var t := _run(a, 0, 30, _move())
	for k in 60:
		t = _run(a, t, 1, _aim(float(k + 1) / 60.0))
	var feet := []
	for k in 3:
		feet.append(a.foot_at(k))
	var recoil := 0.0
	var pitch := 0.0
	var flare := 0.0
	var drift := 0.0
	for k in 31:
		var st := WorldReader.STATE_ACTIVE if k == 0 else WorldReader.STATE_RECOVER
		t = _run(a, t, 1, {"state": st, "hp": 40})
		recoil = maxf(recoil, a.barrel_recoil())
		pitch = maxf(pitch, a.drives()[S.PITCH])
		flare = maxf(flare, a.muzzle_energy())
		for j in 3:
			drift = maxf(drift, a.foot_at(j).distance_to(feet[j]))
	assert_gt(recoil, 0.08, "the barrel slams back: %.3f" % recoil)
	assert_gt(pitch, 0.04, "the nose kicks up")
	assert_gt(flare, S.MUZZLE_CHARGE, "the muzzle flares")
	assert_lt(drift, 0.02, "the feet stay where they stood: %.3f" % drift)
	assert_gt(a.drives()[S.SHELL_UP], 0.01, "the shell lifts to vent")
	_run(a, t, 60, _move())
	assert_almost_eq(a.barrel_recoil(), 0.0, 0.005, "the barrel back at rest")


func test_the_split_sniper_kicks_twice() -> void:
	var counts := []
	for look: int in [-1, WorldReader.KIND_SPLIT_SNIPER]:
		var a := _sniper(look)
		var t := _run(a, 0, 30, _move())
		for k in 60:
			t = _run(a, t, 1, _aim(float(k + 1) / 60.0))
		var kicks := 0
		var back := false
		for k in 30:
			var st := WorldReader.STATE_ACTIVE if k == 0 else WorldReader.STATE_RECOVER
			t = _run(a, t, 1, {"state": st, "hp": 40})
			var far := a.barrel_recoil() > 0.06
			if far and not back:
				kicks += 1
			back = far
		counts.append(kicks)
	assert_eq(counts, [1, 2], "the Sniper kicks once, the Split Sniper twice")


func test_a_hit_jolts_it_back() -> void:
	var calm := _sniper()
	var hit := _sniper()
	var t := _run(calm, 0, 30, _move())
	_run(hit, 0, 30, _move())
	_run(calm, t, 3, _move())
	_run(hit, t, 3, _move(30))
	assert_lt(hit.drives()[S.SURGE], calm.drives()[S.SURGE] - 0.02, "the body jolts back")
	assert_gt(absf(hit.drives()[S.ROLL] - calm.drives()[S.ROLL]), 0.02, "and rolls")


func test_it_rises_in_from_a_crouch_on_its_feet() -> void:
	var a := _sniper()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO, "hp": 40})
	a.advance(DT)
	assert_lt(a.vat_lift(), -0.15, "crouched")
	for k in 3:
		assert_lt(absf(a.foot_at(k).y - S.FEET[k].y), 0.02, "foot %d on the ground" % k)
	_run(a, 1, 70, _move())
	assert_almost_eq(a.vat_lift(), 0.0, 0.02, "risen")


func test_the_death_collapses_the_tripod_and_puts_its_lights_out() -> void:
	var a := _sniper()
	_run(a, 0, 30, _move(10))
	assert_true(a.die())
	assert_true(a.dying())
	for k in int(S.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_lt(a.vat_lift(), -0.25, "the body dropped")
	assert_lt(a.drives()[S.PITCH], -0.05, "its nose dropped as it landed")
	assert_lt(a.lens_energy(), 0.3, "the lens out")
	assert_lt(a.muzzle_energy(), 0.05, "the muzzle cold")


func test_the_knees_stay_off_the_ground_through_every_clip() -> void:
	var a := _sniper()
	var lowest := [99.0, ""]
	var check := func(at: String) -> void:
		for k in 3:
			var y := a.knee_at(k).y
			if y < lowest[0]:
				lowest[0] = y
				lowest[1] = "%s, leg %d" % [at, k]
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO, "hp": 40})
	a.advance(DT)
	check.call("rise-in")
	var t := 1
	for k in 60:
		t = _run(a, t, 1, _move(), RUN)
		check.call("walk")
	t = _fire(a, t)
	check.call("shot")
	a.die()
	for k in 66:
		a.advance(DT)
		check.call("death")
	assert_gt(float(lowest[0]), 0.1, "the lowest knee: %s" % [lowest])


func test_reduced_motion_moves_less_and_never_shakes() -> void:
	var spans := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _sniper()
		var t := _run(a, 0, 40, _move(), RUN)
		var p := [99.0, -99.0]
		for k in 60:
			t = _run(a, t, 1, _move(), RUN)
			p[0] = minf(p[0], a.drives()[S.ROLL])
			p[1] = maxf(p[1], a.drives()[S.ROLL])
		for k in 60:
			t = _run(a, t, 1, _aim(float(k + 1) / 60.0))
		var base := a.drives()[S.PITCH]
		t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 40})
		t = _run(a, t, 8, {"state": WorldReader.STATE_RECOVER, "hp": 40})
		spans.append([p[1] - p[0], a.drives()[S.PITCH] - base])
	assert_lt(spans[1][0], spans[0][0] * 0.6, "the walk's rock is smaller: %s" % [spans])
	assert_lt(spans[1][1], spans[0][1] * 0.7, "the shot's kick is smaller: %s" % [spans])
	ViewPrefs.reduced_motion = true
	var b := _sniper()
	_run(b, 0, 30, _move(10))
	b.die()
	var worst := 0.0
	var last := b.drives().duplicate()
	for k in 66:
		b.advance(DT)
		for j in [S.ROLL, S.PITCH, S.SHELL_P, S.LEG0 + 4, S.LEG0 + 5]:
			worst = maxf(worst, absf(b.drives()[j] - last[j]))
		last = b.drives().duplicate()
	assert_lt(worst, 0.08, "no shake or kick: %.3f a frame at most" % worst)


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _sniper()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	assert_eq(a.uppers.size(), 3)
	var t := _run(a, 0, 30, _move())
	var r0 := a.uppers[0].rotation
	_run(a, t, 20, _move(), RUN)
	assert_ne(a.uppers[0].rotation, r0, "its legs still walk")
	assert_null(a.vat_texture(), "no colour map")


func test_the_split_sniper_wears_its_own_colours_on_the_same_model() -> void:
	var a := _sniper(WorldReader.KIND_SPLIT_SNIPER)
	assert_true(a.has_model)
	var c := EnemyPalettes.color(WorldReader.KIND_SPLIT_SNIPER, &"body")
	assert_eq(a.body_materials[1].albedo_color, c, "its plates in its biome's colour")
	assert_false(VatCrowd.supports(WorldReader.KIND_SPLIT_SNIPER), "drawn as its own nodes")


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "drawn by the VAT crowd")
	assert_true(SoloVat.is_solo(KIND))
	assert_false(HordeAvatar.is_horde_kind(KIND), "no horde body left")
	assert_true(EnemyBatch.KINDS.has(KIND), "batched (no node in the tree)")
	assert_false(EnemyBatch.KINDS.has(WorldReader.KIND_SPLIT_SNIPER), "its variant keeps its nodes")
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
		[WorldReader.STATE_WINDUP, 60, 0.0, 40],
		[WorldReader.STATE_ACTIVE, 1, 0.0, 40],
		[WorldReader.STATE_RECOVER, 30, 0.0, 30],
		[WorldReader.STATE_MOVE, 30, -2.6, 12],
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
				"windup": float(k + 1) / 60.0 if step[0] == WorldReader.STATE_WINDUP else 0.0,
				"hp": step[3],
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
