extends GutTest
## v0.9.0 NB1: The Tidecaller's look. The owner's model (cut into parts by nb_prep.py) loads at the art list's 3.2 m,
## front turned to +X, each part one bone (the bell hanging from the staff, the staff in its right hand, the reaching
## arm on its left); the avatar plays its clips and the sim's tide moves it (the bell swings in the pull, the shell
## pulses in the push); with the file missing a code stand-in of the same parts poses from the same inputs. The tide
## view draws the moving water (in for the pull, out for the push), its bubbles and the bell's toll from the reader
## only, and its bubbles thin out on Low density. Presentation only: nothing here writes the sim.

const DT := 1.0 / 60.0


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	BossModels.clear_cache()
	ViewPrefs.effects_density = "high"


func _avatar() -> TidecallerAvatar:
	var a := TidecallerAvatar.new()
	a.setup(Color("#1A1A22"), &"outline")
	add_child_autofree(a)
	a.set_process(false)
	return a


func _drive(a: TidecallerAvatar, s: Dictionary, frames: int) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = t + 1
		d["pos"] = Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


func test_the_model_loads_cut_into_its_parts_at_its_height() -> void:
	var m := BossModels.get_model(&"boss_tidecaller")
	assert_false(m.is_empty(), "loads")
	var box: AABB = m["aabb"]
	assert_almost_eq(box.size.y, 3.2, 0.01, "3.2 m (the art list's)")
	assert_almost_eq(box.position.y, 0.0, 0.01, "feet on the ground")
	var rig: BossRig = m["rig"]
	var names := []
	for b: Array in rig.bones:
		names.append(String(b[0]))
	names.sort()
	assert_eq(names, ["arm_l", "bell", "body", "shell", "staff"])
	assert_eq(rig.bones[0][0], &"body", "the body is the root")
	assert_eq(
		rig.bones[rig.index_of(&"bell")][1], rig.index_of(&"staff"), "the bell hangs from the staff"
	)
	var staff: Vector3 = rig.bones[rig.index_of(&"staff")][2]
	var arm: Vector3 = rig.bones[rig.index_of(&"arm_l")][2]
	var shell: Vector3 = rig.bones[rig.index_of(&"shell")][2]
	assert_gt(staff.z, 0.5, "the staff in its right hand (+Z)")
	assert_lt(arm.z, -0.3, "the reaching arm on its left")
	assert_lt(shell.x, 0.0, "the shell on its back: it faces +X")
	assert_eq(
		(m["mesh"] as ArrayMesh).surface_get_array_index_len(0) / 3, 18928, "every triangle kept"
	)


func test_the_tide_moves_the_owner_model() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	var bell := a.poser.index_of(&"bell")
	var shell := a.poser.index_of(&"shell")
	_drive(
		a,
		{
			"state": WorldReader.STATE_ACTIVE,
			"move": WorldReader.MOVE_TIDE,
			"tide_phase": WorldReader.TIDE_PULL,
			"tide_progress": 0.3,
			"shielded": true,
		},
		40
	)
	assert_gt(a.pull_amount(), 0.5, "the pull reads")
	var swings := 0
	var last := a.bell_swing()
	for k in 30:
		_drive(
			a,
			{
				"state": WorldReader.STATE_ACTIVE,
				"move": WorldReader.MOVE_TIDE,
				"tide_phase": WorldReader.TIDE_PULL
			},
			1
		)
		if signf(a.bell_swing()) != signf(last):
			swings += 1
		last = a.bell_swing()
	assert_gt(swings, 0, "the bell swings back and forth in the pull")
	assert_gt(
		a.skeleton.get_bone_pose_rotation(bell).angle_to(
			a.skeleton.get_bone_rest(bell).basis.get_rotation_quaternion()
		),
		0.0,
		"its bone turns"
	)
	var scales := []
	for k in 60:
		_drive(
			a,
			{
				"state": WorldReader.STATE_ACTIVE,
				"move": WorldReader.MOVE_TIDE,
				"tide_phase": WorldReader.TIDE_PUSH
			},
			1
		)
		scales.append(a.skeleton.get_bone_pose_scale(shell).x)
	assert_gt(a.push_amount(), 0.5, "the push reads")
	assert_gt(scales.max() - scales.min(), 0.02, "the shell pulses with the push")


func test_the_stand_in_poses_without_the_file() -> void:
	BossModels.clear_cache()
	BossModels.dir = "res://nowhere/"
	var a := _avatar()
	assert_null(a.imported, "no file: the stand-in")
	assert_not_null(a.bell.get_parent(), "with its bell")
	_drive(a, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_TIDE, "windup": 0.5}, 20)
	_drive(
		a,
		{
			"state": WorldReader.STATE_ACTIVE,
			"move": WorldReader.MOVE_TIDE,
			"tide_phase": WorldReader.TIDE_PULL
		},
		40
	)
	assert_ne(a.bell.rotation.x, 0.0, "the stand-in's bell swings")
	assert_gt(a.arm.rotation.x, 0.2, "its arm reaches out in the pull")


func test_the_tide_view_follows_the_reader() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"tidecaller")
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(-8, 0))
	var t := BossAi.table_of(w, i)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.sig_every_ticks = 0
	t.punish_ticks = 0
	BossLab.start(w, i, &"the_pull")
	var view := TideViews.new()
	add_child_autofree(view)
	view.set_process(false)
	var r := WorldReader.new(w)
	CombatLab.idle(w, 30)
	view.sync(r)
	view.advance(DT)
	assert_eq(view.strength(), 0.0, "no current while the bell tolls")
	CombatLab.until(
		w,
		func(x: World) -> bool:
			return x.actors.state[x.actors.index_of(aid)] == EnemyAi.State.ACTIVE
	)
	for k in 60:
		w.step(InputFrame.new())
		view.sync(r)
		view.advance(DT)
	assert_gt(view.strength(), 0.5, "the current runs in the pull")
	assert_gt(view.flow(), 0.9, "flowing in")
	assert_eq(view.bubbles_drawn(), TideViews.BUBBLES, "every bubble on High")
	ViewPrefs.effects_density = "low"
	view.advance(DT)
	assert_eq(view.bubbles_drawn(), TideViews.BUBBLES / 2, "half on Low")
	ViewPrefs.effects_density = "high"
	for k in 150:
		w.step(InputFrame.new())
		view.sync(r)
		view.advance(DT)
	assert_lt(view.flow(), -0.9, "flowing out in the push")
	for k in 200:
		w.step(InputFrame.new())
		view.sync(r)
		view.advance(DT)
	assert_lt(view.strength(), 0.05, "gone after the tide")
