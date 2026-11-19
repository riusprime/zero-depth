extends GutTest
## The Frost Spitter on the owner's model (FrostSpitterAvatar): its parts load into their joints, each clip moves the
## parts it should (the trot with its feet planted, the stepping turn, the tell's swelling sac and rearing, the spit,
## a hit, the rise-in, the death), reduced motion moves less and never shakes, a missing model falls back to the
## code-made body that plays the same clips, and the VAT bake matches the live pose (a VAT avatar keeps the same
## drives, lift and glows through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_FROST_SPITTER
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


## A spitter under a facing node (the one ActorViews turns), its own processing off.
func _spitter() -> FrostSpitterAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := FrostSpitterAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## Ticks of a state: apply_state then a frame, `n` times; the place moves by `step` a tick (sim plane), the facing
## turns by `turn` (radians) a tick.
func _run(
	a: FrostSpitterAvatar, from: int, n: int, s: Dictionary, step := Vector2.ZERO, turn := 0.0
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


func _windup(p: float) -> Dictionary:
	return {"state": WorldReader.STATE_WINDUP, "windup": p, "hp": 40}


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"frost_spitter"), "the model file is installed")
	var a := _spitter()
	assert_true(a.has_model)
	assert_eq(a.uppers.size(), 4, "four upper legs")
	assert_eq(a.lowers.size(), 4, "four feet")
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 12, "the body, the shell, the head, the sac and eight leg halves")
	for k in 4:
		assert_eq(a.lowers[k].get_parent(), a.uppers[k], "a foot hangs from its leg")
	for n: Node3D in [a.shell, a.head, a.sac]:
		assert_eq(n.get_parent(), a.rig, "%s sits on the body" % n.name)
	var sac_glow := 0
	var visor := 0
	for mi: MeshInstance3D in meshes:
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.has_meta(SoloVat.GLOW):
				visor += 1
				assert_eq(String(mi.name), "head", "the visor is the head's glow")
			elif m != null and m.emission_enabled and not m in a.body_materials:
				sac_glow += 1
	assert_gt(sac_glow, 1, "the sac and the throat under it glow")
	assert_eq(visor, 1, "the gem visor")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")


func test_the_trot_plants_its_feet_and_steps_the_diagonals_together() -> void:
	var a := _spitter()
	var t := _run(a, 0, 40, _move(), RUN)
	var low := 99.0
	var high := -99.0
	var span := [99.0, -99.0]
	var same := 0.0
	var opposite := 0.0
	var roll := [99.0, -99.0]
	var r0 := a.uppers[0].rotation
	var moved := false
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
		roll[0] = minf(roll[0], a.drives()[FrostSpitterAvatar.ROLL])
		roll[1] = maxf(roll[1], a.drives()[FrostSpitterAvatar.ROLL])
		moved = moved or a.uppers[0].rotation.distance_to(r0) > 0.2
	assert_lt(low, 0.035, "the front foot comes down to the ground: %.3f" % low)
	assert_gt(high, 0.06, "and lifts in its swing: %.3f" % high)
	assert_gt(span[1] - span[0], 0.2, "the foot sweeps a stride: %s" % [span])
	assert_gt(same, 0.0, "fr and bl step together")
	assert_lt(opposite, 0.0, "fr and fl step in turn")
	assert_gt(roll[1] - roll[0], 0.04, "the body rocks with the pairs")
	assert_true(moved, "the leg node follows its drives")


func test_a_planted_foot_stays_put_on_the_ground_while_the_body_moves() -> void:
	var a := _spitter()
	var t := _run(a, 0, 40, _move(), RUN)
	# While a foot is down its tip keeps still on the ground (the body passes over it: in the avatar's frame it slides
	# back at the speed), whatever the body's bob, roll and pitch.
	var worst := 0.0
	var down := 0
	var last := a.foot_at(2)
	for k in 60:
		t = _run(a, t, 1, _move(), RUN)
		var f := a.foot_at(2)
		var q := fposmod(a._phase - float(FrostSpitterAvatar.STRIDE_AT[2]), 1.0)
		if q > 0.05 and q < FrostSpitterAvatar.DUTY - 0.05:
			down += 1
			assert_lt(f.y, 0.03, "a planted foot on the ground")
			worst = maxf(worst, absf((f.x - last.x) + 2.6 * DT))
		last = f
	assert_gt(down, 10)
	assert_lt(worst, 0.006, "a planted foot keeps still on the ground: %.4f m a frame off" % worst)


func test_turning_in_place_steps_its_legs() -> void:
	var a := _spitter()
	var t := _run(a, 0, 20, _move())
	var span := [99.0, -99.0]
	var lifted := 0.0
	var turn := 2.5 / 60.0
	t = _run(a, t, 20, _move(), Vector2.ZERO, turn)
	for k in 60:
		t = _run(a, t, 1, _move(), Vector2.ZERO, turn)
		span[0] = minf(span[0], a.drives()[FrostSpitterAvatar.LEG0])
		span[1] = maxf(span[1], a.drives()[FrostSpitterAvatar.LEG0])
		lifted = maxf(lifted, a.foot_at(0).y)
	assert_gt(span[1] - span[0], 0.1, "its legs swing round while it turns: %s" % [span])
	assert_gt(lifted, 0.05, "lifting off the ground")
	_run(a, t, 60, _move())
	var rest: Vector3 = FrostSpitterAvatar.FEET[0]
	assert_lt(a.foot_at(0).distance_to(rest), 0.04, "and its foot settles when the turn stops")


func test_the_tell_swells_the_sac_in_gulps_and_rears_it_back() -> void:
	var a := _spitter()
	var t := _run(a, 0, 30, _move())
	var rest_glow := a.sac_energy()
	var hind := a.foot_at(2)
	var swell := []
	var peak := 0.0
	for k in 40:
		var p := float(k + 1) / 40.0
		t = _run(a, t, 1, _windup(p))
		peak = maxf(peak, a.visor_energy())
		if k in [7, 19, 35]:
			swell.append(FrostSpitterAvatar.gulps(p))
	assert_true(swell[0] < swell[1] and swell[1] < swell[2], "the sac fills in steps: %s" % [swell])
	assert_gt(a.sac_swell(), 0.45, "the sac is full")
	assert_gt(a.sac_energy(), rest_glow + 0.3, "and glows brighter")
	assert_gt(a.drives()[FrostSpitterAvatar.PITCH], 0.15, "reared back")
	assert_gt(a.drives()[FrostSpitterAvatar.HEAD_P], 0.2, "the head tipped up")
	assert_gt(peak, FrostSpitterAvatar.VISOR_REST + 3.0, "the visor climbs and flashes")
	assert_gt(a.foot_at(0).y, 0.05, "the front feet off the ground")
	assert_lt(a.foot_at(2).y, 0.03, "the hind feet stay down")
	assert_almost_eq(a.foot_at(2).x, hind.x, 0.03, "and where they stood")


func test_the_spit_empties_the_sac_with_the_mouth_wide_and_it_refills() -> void:
	var a := _spitter()
	var t := _run(a, 0, 30, _move())
	t = _run(a, t, 40, _windup(1.0))
	var glow0 := a.sac_energy()
	t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 40})
	t = _run(a, t, 5, {"state": WorldReader.STATE_RECOVER, "hp": 40})
	assert_lt(a.sac_swell(), -0.3, "the sac emptied: %.2f" % a.sac_swell())
	assert_gt(a.drives()[FrostSpitterAvatar.HEAD_P], 0.25, "the mouth wide")
	assert_gt(a.drives()[FrostSpitterAvatar.SURGE], 0.01, "the body lunged after the head")
	assert_gt(a.sac_energy(), glow0, "the sac flashes as it empties")
	_run(a, t, 60, _move())
	assert_almost_eq(a.sac_swell(), 0.0, 0.25, "and it fills again")
	assert_almost_eq(a.drives()[FrostSpitterAvatar.PITCH], 0.0, 0.05, "the body settled")


func test_a_hit_jolts_it_back_and_squashes_the_sac() -> void:
	var calm := _spitter()  # the same moments with no hit
	var hit := _spitter()
	var t := _run(calm, 0, 30, _move())
	_run(hit, 0, 30, _move())
	_run(calm, t, 3, _move())
	_run(hit, t, 3, _move(30))
	var d0 := calm.drives()
	var d1 := hit.drives()
	assert_lt(
		d1[FrostSpitterAvatar.SURGE], d0[FrostSpitterAvatar.SURGE] - 0.02, "the body jolts back"
	)
	assert_lt(d1[FrostSpitterAvatar.HEAD_P], d0[FrostSpitterAvatar.HEAD_P] - 0.1, "the head ducks")
	assert_lt(d1[FrostSpitterAvatar.SAC], d0[FrostSpitterAvatar.SAC] - 0.05, "the sac squashes")


func test_it_rises_in_from_a_crouch_on_its_feet() -> void:
	var a := _spitter()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO, "hp": 40})
	a.advance(DT)
	assert_lt(a.vat_lift(), -0.1, "crouched")
	for k in 4:
		assert_lt(
			absf(a.foot_at(k).y - FrostSpitterAvatar.FEET[k].y), 0.02, "foot %d on the ground" % k
		)
	_run(a, 1, 60, _move())
	assert_almost_eq(a.vat_lift(), 0.0, 0.02, "risen")


func test_the_death_bursts_the_sac_and_drops_it_on_its_belly() -> void:
	var a := _spitter()
	_run(a, 0, 30, _move(10))
	assert_true(a.die())
	assert_true(a.dying())
	var flash := 0.0
	for k in int(FrostSpitterAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
		flash = maxf(flash, a.sac_energy())
	assert_gt(flash, FrostSpitterAvatar.SAC_FLASH, "the sac flashes as it bursts")
	assert_lt(a.sac_swell(), -0.5, "and empties")
	assert_lt(a.sac_energy(), 0.3, "its glow gone")
	assert_lt(a.visor_energy(), 0.5, "the visor out")
	assert_lt(a.vat_lift(), -0.12, "the body dropped")
	assert_gt(absf(a.drives()[FrostSpitterAvatar.ROLL]), 0.08, "tipped to one side")


func test_the_knees_stay_off_the_ground_through_every_clip() -> void:
	var a := _spitter()
	var lowest := [99.0, -1]
	var check := func(at: String) -> void:
		for k in 4:
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
		check.call("trot")
	for k in 40:
		t = _run(a, t, 1, _windup(float(k + 1) / 40.0))
		check.call("tell")
	t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 40})
	for k in 40:
		t = _run(a, t, 1, {"state": WorldReader.STATE_RECOVER, "hp": 30})
		check.call("spit")
	a.die()
	for k in 60:
		a.advance(DT)
		check.call("death")
	assert_gt(float(lowest[0]), 0.03, "the lowest knee: %s" % [lowest])


func test_reduced_motion_moves_less_and_never_shakes() -> void:
	var spans := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _spitter()
		var t := _run(a, 0, 40, _move(), RUN)
		var p := [99.0, -99.0]
		for k in 40:
			t = _run(a, t, 1, _move(), RUN)
			p[0] = minf(p[0], a.drives()[FrostSpitterAvatar.ROLL])
			p[1] = maxf(p[1], a.drives()[FrostSpitterAvatar.ROLL])
		t = _run(a, t, 30, _windup(0.7))
		spans.append([p[1] - p[0], a.drives()[FrostSpitterAvatar.PITCH]])
	assert_lt(spans[1][0], spans[0][0] * 0.6, "the trot's rock is smaller: %s" % [spans])
	assert_lt(spans[1][1], spans[0][1] * 0.6, "the rearing is lower: %s" % [spans])
	# No shake in the death with reduced motion: the body, the sac and the legs move smoothly frame to frame.
	ViewPrefs.reduced_motion = true
	var b := _spitter()
	_run(b, 0, 30, _move(10))
	b.die()
	var worst := 0.0
	var last := b.drives().duplicate()
	for k in 50:
		b.advance(DT)
		for j in [
			FrostSpitterAvatar.ROLL,
			FrostSpitterAvatar.PITCH,
			FrostSpitterAvatar.SAC,
			FrostSpitterAvatar.LEG0 + 7,
			FrostSpitterAvatar.LEG0 + 8
		]:
			worst = maxf(worst, absf(b.drives()[j] - last[j]))
		last = b.drives().duplicate()
	assert_lt(worst, 0.08, "no shake or kick: %.3f a frame at most" % worst)


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _spitter()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	assert_eq(a.uppers.size(), 4)
	var t := _run(a, 0, 30, _move())
	var r0 := a.uppers[0].rotation
	_run(a, t, 20, _move(), RUN)
	assert_ne(a.uppers[0].rotation, r0, "its legs still walk")
	assert_null(a.vat_texture(), "no colour map")


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "drawn by the VAT crowd")
	assert_true(SoloVat.is_solo(KIND))
	assert_false(CanyonShoreBodies.is_kind(KIND), "no stand-in body left")
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
		[WorldReader.STATE_WINDUP, 40, 0.0, 40],
		[WorldReader.STATE_ACTIVE, 1, 0.0, 40],
		[WorldReader.STATE_RECOVER, 36, 0.0, 30],
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
				"windup": float(k + 1) / 40.0 if step[0] == WorldReader.STATE_WINDUP else 0.0,
				"hp": step[3],
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
