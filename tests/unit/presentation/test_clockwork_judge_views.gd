extends GutTest
## The Clockwork Judge's look. The owner's model loads at the art list's 3.6 m, front turned to +X, skinned to its
## skeleton; the avatar plays the animations in its file (idle, walk, and one per move) for the clips they stand
## for, its shins sliding as it walks; its anchors ride their bones; the reactions that have no animation play from
## code on top of the file's idle; and the sim's echo moves the clock hands (they sweep faster as the echo
## records). With the file missing a code stand-in of the same parts poses from the same inputs. JudgeViews draws,
## from the reader only, the recording's glints, the whole path (a marker per point and the ribbon joining them)
## before the first strike, a ghost afterimage with its ring and filings at each strike (the filings halved on
## Low), and the Verdict's pendulum. Presentation only.

const DT := 1.0 / 60.0
const IDLE := {"state": WorldReader.STATE_MOVE, "move": -1}


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	BossModels.clear_cache()
	ViewPrefs.effects_density = "high"


func _avatar() -> ClockworkJudgeAvatar:
	var a := ClockworkJudgeAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


## Drives `frames` frames of state `s`, the boss moving at `speed` m/s.
func _drive(a: ClockworkJudgeAvatar, s: Dictionary, frames: int, speed: float = 0.0) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = t + 1
		d["pos"] = Vector2(speed * DT * t, 0.0)
		a.apply_state(d)
		a.advance(DT)


func test_the_model_loads_skinned_at_its_height() -> void:
	var m := BossModels.get_model(&"boss_clockwork_judge")
	assert_false(m.is_empty(), "loads")
	assert_true(bool(m.get("skinned", false)), "it keeps its skeleton")
	var box: AABB = m["aabb"]
	assert_almost_eq(box.size.y, 3.6, 0.01, "3.6 m (the art list's)")
	assert_almost_eq(box.position.y, 0.0, 0.01, "feet on the ground")
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	for bone: StringName in [
		&"body", &"chest", &"head", &"gear", &"hand_hour", &"hand_minute", &"gavel_L", &"shin_R"
	]:
		assert_true(a.poser.has_bone(bone), "the bone %s" % bone)
	# The clips address only bones the model has: a missing one would silently not move.
	for c: BossClip in ClockworkJudgeClips.library().values():
		for k in c.track_count():
			if c.channels[k] != BossClip.PARAM and c.targets[k] != BossClip.BODY:
				assert_true(a.poser.has_bone(c.targets[k]), "%s moves %s" % [c.name, c.targets[k]])
	var skel := a.skeleton
	var to_model := BossModels.relative_transform(a.pivot, skel)
	var left := to_model * skel.get_bone_global_rest(skel.find_bone("upper_arm_L")).origin
	var right := to_model * skel.get_bone_global_rest(skel.find_bone("upper_arm_R")).origin
	var hand := to_model * skel.get_bone_global_rest(skel.find_bone("hand_minute")).origin
	assert_lt(left.z, -0.5, "the left arm on its left (-Z)")
	assert_gt(right.z, 0.5, "the right arm on its right")
	assert_gt(left.y, 2.0, "pivoting at the shoulder")
	assert_gt(hand.x, 0.0, "the clock faces front (+X)")
	assert_between(hand.y, 2.0, 2.6, "on its chest")


func test_it_plays_its_files_animations() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	for clip: StringName in [&"idle", &"walk", &"verdict", &"slam_ring", &"echo", &"pattern"]:
		assert_true(a.animator.owner_has(clip), "%s plays the file's animation" % clip)
	for clip: StringName in [&"flinch", &"stagger", &"roar", &"rise", &"death", &"shielded"]:
		assert_false(a.animator.owner_has(clip), "%s is a code clip" % clip)
	var arm := a.skeleton.find_bone("upper_arm_R")
	_drive(a, IDLE, 30)
	var idle_arm := a.skeleton.get_bone_pose_rotation(arm)
	var gavel := a.anchor(&"gavel_r")
	var eye := a.anchor(&"eye")
	# The Verdict's haul: the right gavel up over the shoulder, late in the windup.
	var haul := {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_VERDICT, "windup": 0.6}
	_drive(a, haul, 40)
	assert_gt(
		a.skeleton.get_bone_pose_rotation(arm).angle_to(idle_arm), 0.8, "the right arm hauls up"
	)
	assert_gt(a.animator.param(&"glow"), 0.3, "the code clip's glow plays under the animation")
	assert_gt(a.anchor(&"gavel_r").y, gavel.y + 1.0, "the gavel's anchor rides its bone up")
	# The Gavel Slam's strike: the chest and the head drop forward onto the gavels.
	var slam := {
		"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_SLAM_RING, "windup": 0.999
	}
	_drive(a, slam, 40)
	assert_lt(a.anchor(&"eye").y, eye.y - 0.1, "the eye's anchor rides the head down")
	assert_gt(a.anchor(&"eye").x, eye.x + 0.1, "and forward")


func test_the_shins_slide_as_it_walks() -> void:
	var a := _avatar()
	var shin := a.skeleton.find_bone("shin_L")
	var rest := a.skeleton.get_bone_rest(shin).origin
	var gear := a.skeleton.find_bone("gear")
	var gear_rest := a.skeleton.get_bone_rest(gear).basis.get_rotation_quaternion()
	var slide := 0.0
	var gear_turn := 0.0
	for k in 12:  # samples over about three strides
		_drive(a, IDLE, 10, ClockworkJudgeAvatar.WALK_SPEED)
		slide = maxf(slide, a.skeleton.get_bone_pose_position(shin).distance_to(rest))
		gear_turn = maxf(gear_turn, a.skeleton.get_bone_pose_rotation(gear).angle_to(gear_rest))
	assert_gt(slide, 0.02, "the shin slides along the leg (the file's position track plays)")
	assert_gt(gear_turn, 0.3, "the file's animation turns the gear")
	# One loop of the walk covers the stride: the file's 1.2 m at the size the game draws the model.
	assert_almost_eq(ClockworkJudgeAvatar.STRIDE, 1.2 * BossModels.SIZE_SCALE, 0.001)


func test_a_reaction_plays_on_top_of_the_files_idle() -> void:
	var a := _avatar()
	var b := _avatar()
	var head := a.skeleton.find_bone("head")
	var shin := a.skeleton.find_bone("shin_L")
	var foot := a.skeleton.find_bone("foot_L")
	_drive(a, IDLE, 90)
	_drive(b, {"state": WorldReader.STATE_STAGGERED}, 90)
	var idle_head := a.skeleton.get_bone_pose_rotation(head)
	var stalled_head := b.skeleton.get_bone_pose_rotation(head)
	assert_gt(stalled_head.angle_to(idle_head), 0.15, "the stall hangs the head over the idle")
	assert_lt(stalled_head.angle_to(idle_head), 0.6, "added to the idle's pose, not run away")
	assert_gt(
		b.skeleton.get_bone_pose_position(shin).distance_to(
			a.skeleton.get_bone_pose_position(shin)
		),
		0.05,
		"it sinks on its sliding shins"
	)
	assert_almost_eq(
		b.skeleton.get_bone_global_pose(foot).origin.y,
		a.skeleton.get_bone_global_pose(foot).origin.y,
		0.03,
		"its feet stay on the ground"
	)
	# The stall over, the head is the idle's again: nothing of the reaction stays in the pose.
	_drive(b, IDLE, 120)
	_drive(a, IDLE, 120)
	assert_almost_eq(
		b.skeleton.get_bone_pose_rotation(head).angle_to(a.skeleton.get_bone_pose_rotation(head)),
		0.0,
		0.02,
		"back to the idle"
	)


func test_the_echo_sweeps_the_hands_faster() -> void:
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
	var hour := a.poser.index_of(&"hand_hour")
	var minute_rest := a.skeleton.get_bone_rest(minute).basis.get_rotation_quaternion()
	var hour_rest := a.skeleton.get_bone_rest(hour).basis.get_rotation_quaternion()
	var turned := a.skeleton.get_bone_pose_rotation(minute) * minute_rest.inverse()
	var chest := a.skeleton.get_bone_global_rest(a.skeleton.get_bone_parent(minute)).basis
	assert_almost_eq(
		turned.get_angle(), minf(a.minute_angle(), TAU - a.minute_angle()), 0.01, "its bone turns"
	)
	# The clock faces down the skeleton's Z (the model's front): the hand turns in the face's plane.
	assert_almost_eq(absf((chest * turned.get_axis()).z), 1.0, 0.01, "about the face's axis")
	assert_gt(a.skeleton.get_bone_pose_rotation(hour).angle_to(hour_rest), 0.0, "the hour hand too")
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
