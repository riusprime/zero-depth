extends GutTest
## v0.9.0 NB2: The Twin Wardens' look. The owner's two models load at the art list's 2.2 m each, the same size: the
## amber one is skinned to a full skeleton and plays the animations in its file (idle, walk, cast, swipe) for the
## clips they stand for; the violet one is cut into Body, Helm, Shield and Sword bones and plays the code clips. The
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
	a.setup()
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


func test_the_amber_plays_its_files_animations() -> void:
	var a := _avatar(false)
	var v := _avatar(true)
	assert_not_null(a.imported, "the owner's amber model")
	assert_not_null(v.imported, "the owner's violet model")
	for clip: StringName in [&"idle", &"walk", &"crossfire", &"pattern", &"chain_sweep"]:
		assert_true(a.animator.owner_has(clip), "%s plays the file's animation" % clip)
		assert_false(
			v.animator.owner_has(clip), "the violet file has none: %s is its code clip" % clip
		)
	assert_false(a.animator.owner_has(&"slam_ring"), "the shield bash keeps its code clip")
	var arm := a.skeleton.find_bone("upper_arm_R")
	assert_gt(arm, -1, "the sword arm's bone")
	_drive(a, {"state": WorldReader.STATE_MOVE, "move": -1}, 30)
	var idle_pose := a.skeleton.get_bone_pose_rotation(arm)
	var shackle := a.anchor(&"shackle")
	var cast := {
		"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_CROSSFIRE, "windup": 0.95
	}
	_drive(a, cast, 30)
	assert_gt(
		a.skeleton.get_bone_pose_rotation(arm).angle_to(idle_pose),
		0.5,
		"the sword arm comes up to cast"
	)
	assert_gt(
		a.animator.param(&"glow"), 0.3, "the code clip's glow still plays under the animation"
	)
	var sweep := {
		"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_CHAIN_SWEEP, "windup": 0.95
	}
	_drive(a, sweep, 30)
	assert_gt(a.anchor(&"shackle").distance_to(shackle), 0.02, "the chain's end rides the shield")
	# A move both still play from code moves the two figures alike.
	var bash := {"state": WorldReader.STATE_ACTIVE, "move": WorldReader.MOVE_SLAM_RING}
	_drive(a, bash, 30)
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
	# Crossfire (v0.11.0 O5: the violet's alone): its lane and the spot through the windup.
	var vid := w.actors.ids[BossTwin.partner_of(w, i)]
	BossLab.start(w, BossTwin.partner_of(w, i), &"crossfire")
	step.call(10)
	assert_eq(view.lanes_shown(), 1, "its gap lane")
	assert_true(view.spot_shown(), "the safe spot")
	for k in 400:
		var s := w.actors.state[w.actors.index_of(vid)]
		if s != EnemyAi.State.WINDUP and s != EnemyAi.State.ACTIVE:
			break
		step.call(1)
	step.call(10)
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


## v0.11.0 O5 (owner L7, Q11 a, Q29): the roles read out. The bar names whose bar it is (amber, violet, both) and in
## phase 3 which Warden is exposed; the Warden to hit glows brighter than the one standing back, and the exposed
## one brightest.
func test_the_bar_names_the_phase_s_warden_and_the_one_to_hit_glows() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"twin_wardens")
	var bid := w.actors.ids[i]
	var r := WorldReader.new(w)
	var bar := BossBar.new()
	add_child_autofree(bar)
	w.step(InputFrame.new())
	bar.sync(r)
	var line := bar.get_node("PhaseLine") as Label
	assert_string_contains(line.text, tr("HUD_TWIN_LEADS_AMBER"), "phase 1: the amber's bar")
	for p in [1, 2]:
		i = w.actors.index_of(bid)
		var hp := BossAi.table_of(w, i).phase_threshold[p] * w.actors.max_hp[i] / 1000
		w.actors.hp[i] = hp
		w.actors.hp[BossTwin.partner_of(w, i)] = hp
		w.step(InputFrame.new())
		BossLab.through_gate(w, bid)
		bar.sync(r)
		var key := "HUD_TWIN_LEADS_VIOLET" if p == 1 else "HUD_TWIN_LEADS_BOTH"
		assert_string_contains(line.text, tr(key), "phase %d" % (p + 1))
	assert_eq(bar.hp_fraction(), 1.0, "a new full bar")
	assert_eq(bar.status_line(), tr("HUD_TWIN_EXPOSED_AMBER"), "the amber exposed first")
	var focus := _avatar(false)
	var rest := _avatar(true)
	var exposed := _avatar(false)
	var idle := {"state": WorldReader.STATE_MOVE, "move": -1}
	_drive(focus, idle.merged({"focus": true}), 60)
	_drive(rest, idle.merged({"resting": true}), 60)
	_drive(exposed, idle.merged({"exposed": true}), 60)
	assert_gt(focus.role_glow(), rest.role_glow(), "the one to hit outshines the one standing back")
	assert_gt(exposed.role_glow(), focus.role_glow(), "the exposed one brightest")
