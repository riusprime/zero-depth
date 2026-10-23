extends GutTest
## v0.9.0 NB2: The Twin Wardens' look. The owner's two models load at the art list's 2.2 m each, the same size: the
## amber one keeps its skeleton (posed through the whole figure), the violet one is cut into Body, Helm, Shield and
## Sword bones. Both play the same clips, so they move together: driven alike, their figures hold the same pose. The
## angry one shows it; without the files code stand-ins of the same parts pose from the same inputs. The chain view
## draws the chain between the two from the reader, hot while it burns, its embers thinned on Low; Crossfire's two gap
## lanes and its safe spot through the windup; the Chain Sweep's lash on its strike. Presentation only.

const DT := 1.0 / 60.0


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	BossModels.clear_cache()
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false


func _avatar(violet: bool) -> TwinWardenAvatar:
	var a: TwinWardenAvatar = TwinWardenVioletAvatar.new() if violet else TwinWardenAvatar.new()
	a.setup(Color("#1A1A22"), &"xray")
	add_child_autofree(a)
	a.set_process(false)
	return a


func _drive(a: TwinWardenAvatar, s: Dictionary, frames: int) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = t + 1
		d["pos"] = Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


func test_the_two_models_load_as_a_matched_pair() -> void:
	var amber := BossModels.get_model(&"boss_twin_warden_amber")
	var violet := BossModels.get_model(&"boss_twin_warden_violet")
	assert_false(amber.is_empty(), "the amber loads")
	assert_false(violet.is_empty(), "the violet loads")
	assert_true(bool(amber.get("skinned", false)), "the amber keeps its skeleton")
	assert_almost_eq((amber["aabb"] as AABB).size.y, 2.2, 0.02, "2.2 m")
	assert_almost_eq((violet["aabb"] as AABB).size.y, 2.2, 0.02, "the same height")
	var rig: BossRig = violet["rig"]
	var names := []
	for b: Array in rig.bones:
		names.append(String(b[0]))
	names.sort()
	assert_eq(names, ["body", "helm", "shield", "sword"], "the violet cut into its parts")


func test_driven_alike_they_move_alike() -> void:
	var a := _avatar(false)
	var v := _avatar(true)
	assert_not_null(a.imported, "the owner's amber model")
	assert_not_null(v.imported, "the owner's violet model")
	for s: Dictionary in [
		{"state": WorldReader.STATE_MOVE, "move": -1},
		{"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_CHAIN_SWEEP, "windup": 0.7},
		{"state": WorldReader.STATE_ACTIVE, "move": WorldReader.MOVE_SLAM_RING},
	]:
		_drive(a, s, 30)
		_drive(v, s, 30)
		assert_almost_eq(
			a.pivot.position, v.pivot.position, Vector3.ONE * 0.001, "one figure's pose"
		)
		assert_almost_eq(a.pivot.rotation, v.pivot.rotation, Vector3.ONE * 0.001, "the same lean")
	_drive(
		a,
		{"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_CHAIN_SWEEP, "windup": 0.7},
		1
	)
	assert_ne(a.pivot.rotation, Vector3.ZERO, "the figure moves")


func test_the_angry_one_shows_it() -> void:
	var a := _avatar(true)
	_drive(a, {"state": WorldReader.STATE_MOVE, "move": -1}, 20)
	var calm := a.crack_light.light_energy
	_drive(a, {"state": WorldReader.STATE_MOVE, "move": -1, "angry": true}, 30)
	assert_gt(a.anger_amount(), 0.9)
	assert_gt(a.crack_light.light_energy, calm * 1.5, "its light flares")


func test_the_stand_ins_pose_without_the_files() -> void:
	BossModels.clear_cache()
	BossModels.dir = "res://nowhere/"
	for violet in [false, true]:
		var a := _avatar(violet)
		assert_null(a.imported, "no file: the stand-in")
		assert_not_null(a.shield.get_parent(), "with its shield")
		_drive(
			a,
			{"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_SLAM_RING, "windup": 0.8},
			20
		)
		assert_gt(a.shield.position.y, 1.05, "the shield lifts for the bash")
		assert_eq(signf(a.shield.position.z), -a.shield_side(), "its shield arm")


func test_the_chain_view_follows_the_reader() -> void:
	var w := BossLab.world()
	w.actors.set_pos(0, Vector2(0, -5))
	var i := BossLab.ready_boss(w, &"twin_wardens")
	var t := BossAi.table_of(w, i)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.speed = 0.0
	w.actors.set_pos(i, Vector2(-3, 0))
	w.actors.set_pos(BossTwin.partner_of(w, i), Vector2(3, 0))
	var view := TwinViews.new()
	add_child_autofree(view)
	view.set_process(false)
	var r := WorldReader.new(w)
	var step := func(n: int) -> void:
		for k in n:
			w.step(InputFrame.new())
			view.sync(r)
			view.advance(DT)
	step.call(30)
	assert_gt(view.links_drawn(), 15, "the chain's links between them")
	assert_gt(view.heat(), 0.9, "hot: it burns")
	assert_eq(view.embers_drawn(), TwinViews.EMBERS, "every ember on High")
	ViewPrefs.effects_density = "low"
	view.advance(DT)
	assert_eq(view.embers_drawn(), TwinViews.EMBERS / 2, "half on Low")
	ViewPrefs.effects_density = "high"
	assert_almost_eq(view.chain_point(0.0).x, -3.0, 0.01, "from the amber Warden")
	assert_lt(view.chain_point(0.5).y, view.chain_point(0.0).y, "it sags")
	# Crossfire: the two lanes and the spot through the windup.
	BossLab.start(w, i, &"crossfire")
	step.call(10)
	assert_eq(view.lanes_shown(), 2, "both gap lanes")
	assert_true(view.spot_shown(), "the safe spot")
	BossLab.until_open(w, w.actors.ids[i])
	step.call(100)
	assert_eq(view.lanes_shown(), 0, "gone after it")
	# The Chain Sweep: cooled while it holds the chain, the lash on its strike.
	BossLab.start(w, w.actors.index_of(w.actors.ids[i]), &"chain_sweep")
	step.call(40)
	assert_lt(view.heat(), 0.6, "the sweep holds it: cooled")
	var lashed := false
	for k in 120:
		step.call(1)
		lashed = lashed or view.lashing()
	assert_true(lashed, "the lash ran on the strike")
	# A burn flashes where it touched the hero.
	CombatLab.idle(w, 120)
	w.actors.set_pos(0, Vector2(0, 0.2))
	w.actors.invuln[0] = 0
	var flashed := false
	for k in 40:
		w.actors.set_pos(0, Vector2(0, 0.2))
		step.call(1)
		flashed = flashed or view.burn_flashing()
	assert_true(flashed, "the burn's flash")
