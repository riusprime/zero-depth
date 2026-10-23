extends GutTest
## v0.9.0 NB3: The Clockwork Judge's look. The owner's model (cut into parts by nb_prep.py; its broken skeleton
## ignored, PLAN NB) loads at the art list's 3.6 m, front turned to +X, each part one bone (the pendulum arms at the
## shoulders, the gears at the waist, the clock's two hands on its chest); the avatar plays its clips and the sim's
## echo moves it (the hands sweep faster as the echo records, the gears turn); with the file missing a code stand-in of
## the same parts poses from the same inputs. JudgeViews draws, from the reader only, the recording's glints, the
## whole path (a marker per point and the ribbon joining them) before the first strike, a ghost afterimage with its
## ring and filings at each strike (the filings halved on Low), and the Verdict's pendulum. Presentation only.

const DT := 1.0 / 60.0


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	BossModels.clear_cache()
	ViewPrefs.effects_density = "high"


func _avatar() -> ClockworkJudgeAvatar:
	var a := ClockworkJudgeAvatar.new()
	a.setup(Color("#1A1A22"), &"xray")
	add_child_autofree(a)
	a.set_process(false)
	return a


func _drive(a: ClockworkJudgeAvatar, s: Dictionary, frames: int) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = t + 1
		d["pos"] = Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


func test_the_model_loads_cut_into_its_parts_at_its_height() -> void:
	var m := BossModels.get_model(&"boss_clockwork_judge")
	assert_false(m.is_empty(), "loads")
	var box: AABB = m["aabb"]
	assert_almost_eq(box.size.y, 3.6, 0.01, "3.6 m (the art list's)")
	assert_almost_eq(box.position.y, 0.0, 0.01, "feet on the ground")
	var rig: BossRig = m["rig"]
	var names := []
	for b: Array in rig.bones:
		names.append(String(b[0]))
	names.sort()
	assert_eq(names, ["arm_l", "arm_r", "body", "gears", "hand_hour", "hand_minute"])
	assert_eq(rig.bones[0][0], &"body", "the body is the root")
	var arm_l: Vector3 = rig.bones[rig.index_of(&"arm_l")][2]
	var arm_r: Vector3 = rig.bones[rig.index_of(&"arm_r")][2]
	var hand: Vector3 = rig.bones[rig.index_of(&"hand_minute")][2]
	assert_lt(arm_l.z, -0.5, "the left arm on its left (-Z)")
	assert_gt(arm_r.z, 0.5, "the right arm on its right")
	assert_gt(arm_l.y, 2.0, "pivoting at the shoulder")
	assert_gt(hand.x, 0.0, "the clock faces front (+X)")
	assert_between(hand.y, 2.0, 2.6, "on its chest")


func test_the_echo_sweeps_the_hands_faster_and_turns_the_gears() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	_drive(
		a,
		{
			"state": WorldReader.STATE_MOVE,
			"echo_phase": WorldReader.ECHO_NONE,
			"echo_recording": 0.0
		},
		30
	)
	var rest := a.hand_speed()
	var m0 := a.minute_angle()
	_drive(
		a,
		{
			"state": WorldReader.STATE_MOVE,
			"echo_phase": WorldReader.ECHO_NONE,
			"echo_recording": 0.9
		},
		60
	)
	assert_gt(a.hand_speed(), rest * 5.0, "the hands race as the echo records")
	assert_ne(a.minute_angle(), m0, "the minute hand moves")
	var minute := a.poser.index_of(&"hand_minute")
	assert_gt(
		a.skeleton.get_bone_pose_rotation(minute).angle_to(
			a.skeleton.get_bone_rest(minute).basis.get_rotation_quaternion()
		),
		0.0,
		"its bone turns"
	)
	var g0 := a.gear_angle()
	_drive(
		a,
		{
			"state": WorldReader.STATE_ACTIVE,
			"move": WorldReader.MOVE_ECHO,
			"echo_phase": WorldReader.ECHO_REPLAY,
			"shielded": true,
		},
		30
	)
	assert_ne(a.gear_angle(), g0, "the gears turn")
	assert_gt(a.hand_speed(), rest * 5.0, "racing through the replay")


func test_the_stand_in_poses_without_the_file() -> void:
	BossModels.clear_cache()
	BossModels.dir = "res://nowhere/"
	var a := _avatar()
	assert_null(a.imported, "no file: the stand-in")
	assert_not_null(a.minute.get_parent(), "with its clock hands")
	_drive(
		a, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_VERDICT, "windup": 0.6}, 30
	)
	assert_lt(a.arm_r.rotation.z, -0.3, "the gavel hauled back for the Verdict")
	_drive(
		a,
		{
			"state": WorldReader.STATE_ACTIVE,
			"move": WorldReader.MOVE_ECHO,
			"echo_phase": WorldReader.ECHO_REPLAY
		},
		30
	)
	assert_gt(a.arm_l.rotation.x, 0.3, "the arms spread for the echo")
	assert_ne(a.minute.rotation.x, 0.0, "the stand-in's hands sweep")


func _fight() -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"clockwork_judge")
	var t := BossAi.table_of(w, i)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.sig_every_ticks = 0
	t.punish_ticks = 0
	t.gap_ticks = 0
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	return [w, w.actors.ids[i]]


func test_the_echo_view_shows_the_whole_path_then_the_ghost_trail() -> void:
	var s := _fight()
	var w: World = s[0]
	var aid: int = s[1]
	var view := JudgeViews.new()
	add_child_autofree(view)
	view.set_process(false)
	var r := WorldReader.new(w)
	for k in 240:  # the player walks a line while it records
		w.actors.set_pos(0, Vector2(-8.0 + 0.05 * k, 4.0))
		w.step(InputFrame.new())
	w.bosses.sig_boss.append(aid)  # the cadence due now: the recording window is full
	w.bosses.sig_due.append(w.tick)
	view.sync(r)
	view.advance(DT)
	assert_gt(view.glints_shown(), 6, "the recording's glints")
	ViewPrefs.effects_density = "low"
	view.advance(DT)
	assert_eq(view.glints_shown(), 6, "half on Low")
	ViewPrefs.effects_density = "high"
	BossLab.start(w, w.actors.index_of(aid), &"the_echo")
	view.sync(r)
	for k in 10:
		view.advance(DT)
	var path: Array = r.boss_echo(w.actors.index_of(aid))["path"]
	assert_gt(path.size(), 6)
	assert_eq(view.markers_shown(), path.size(), "every point shows before the first strike")
	assert_eq(view.ribbon_segments(), path.size() - 1, "joined in the order walked")
	assert_eq(view.ghosts_shown(), 0, "no ghost yet")
	assert_eq(view.glints_shown(), 0, "the glints give way to the path")
	var ghosts := 0
	var filings := 0
	for k in 48 + 30:
		w.actors.set_pos(0, Vector2(0, -9))
		w.step(InputFrame.new())
		view.sync(r)
		view.advance(DT)
		ghosts = maxi(ghosts, view.ghosts_shown())
		filings = maxi(filings, view.filings_shown())
	assert_gt(ghosts, 0, "a ghost rises at each strike")
	assert_gt(filings, 0, "gear filings spray")
	assert_lt(view.markers_shown(), path.size(), "struck points leave the path")
	assert_lte(filings, JudgeViews.FILINGS_PER * 3, "a bounded spray")


func test_the_verdict_pendulum_hangs_locks_back_and_drops() -> void:
	var s := _fight()
	var w: World = s[0]
	var aid: int = s[1]
	w.actors.set_pos(0, Vector2(5, 0))
	var view := JudgeViews.new()
	add_child_autofree(view)
	view.set_process(false)
	var r := WorldReader.new(w)
	BossLab.start(w, w.actors.index_of(aid), &"verdict")
	for k in 20:
		w.step(InputFrame.new())
		view.sync(r)
		view.advance(DT)
	assert_true(view.pendulum_shown(), "over the tracked square")
	assert_lt(absf(view.pendulum_swing()), 0.4, "swaying while it tracks")
	for k in 70:
		w.step(InputFrame.new())
		view.sync(r)
		view.advance(DT)
	assert_gt(view.pendulum_swing(), 1.0, "hauled back to its apex as the square locks")
	CombatLab.until(
		w,
		func(x: World) -> bool:
			return x.actors.state[x.actors.index_of(aid)] != EnemyAi.State.WINDUP,
		60
	)
	view.sync(r)
	for k in 15:
		view.advance(DT)
	assert_lt(view.pendulum_swing(), 0.1, "swung down onto the square")
	for k in 60:
		view.advance(DT)
	assert_false(view.pendulum_shown(), "and gone")
