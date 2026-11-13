extends GutTest
## The Tidecaller's look. The owner's model loads at the art list's 3.2 m, front turned to +X, skinned to a full
## skeleton (the staff in its right hand with the bell hanging from it, the reaching arm on its left, the shell on its
## back), and plays the animations in its file for its stance, its walk and its moves, each move's glow still playing
## under its animation; the sim's tide is added on top (the bell swings in the pull, the shell pulses in the push), as
## are the clips still played from code; with the file missing a code stand-in of the same parts poses from the same
## inputs. The tide view draws the moving water (in for the pull, out for the push), its bubbles and the bell's toll
## from the reader only, and its bubbles thin out on Low density. Presentation only: nothing here writes the sim.

const DT := 1.0 / 60.0


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	BossModels.clear_cache()
	ViewPrefs.effects_density = "high"


func _avatar() -> TidecallerAvatar:
	var a := TidecallerAvatar.new()
	a.setup()
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


## Where `bone`'s pivot is at rest, in the avatar's model frame.
func _rest_at(a: TidecallerAvatar, bone: String) -> Vector3:
	var k := a.skeleton.find_bone(bone)
	return (
		BossModels.relative_transform(a.pivot, a.skeleton)
		* a.skeleton.get_bone_global_rest(k).origin
	)


func test_the_model_loads_skinned_at_its_height() -> void:
	var m := BossModels.get_model(&"boss_tidecaller")
	assert_false(m.is_empty(), "loads")
	assert_true(m.get("skinned", false), "kept with its skeleton")
	var box: AABB = m["aabb"]
	assert_almost_eq(box.size.y, 3.2, 0.01, "3.2 m (the art list's)")
	assert_almost_eq(box.position.y, 0.0, 0.01, "feet on the ground")
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	assert_eq(a.skeleton.get_bone_count(), 46, "its 46 bones")
	for bone: String in [
		"chest", "head", "upper_arm_L", "hand_L", "hand_R", "staff", "bell", "shell"
	]:
		assert_gt(a.skeleton.find_bone(bone), -1, "the %s bone" % bone)
	assert_eq(
		a.skeleton.get_bone_parent(a.skeleton.find_bone("bell")),
		a.skeleton.find_bone("staff"),
		"the bell hangs from the staff"
	)
	assert_gt(_rest_at(a, "staff").z, 0.5, "the staff in its right hand (+Z)")
	assert_lt(_rest_at(a, "hand_L").z, -0.3, "the reaching arm on its left")
	assert_lt(_rest_at(a, "shell").x, 0.0, "the shell on its back: it faces +X")
	var mesh := (a.imported as MeshInstance3D).mesh
	assert_eq(mesh.surface_get_array_index_len(0) / 3, 18928, "every triangle kept")


func test_it_plays_its_files_animations() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	for clip: StringName in [
		&"idle", &"walk", &"tide", &"pattern", &"wave", &"marks", &"slam_ring"
	]:
		assert_true(a.animator.owner_has(clip), "%s plays the file's animation" % clip)
	for clip: StringName in [&"shielded", &"flinch", &"stagger", &"roar", &"rise", &"death"]:
		assert_false(a.animator.owner_has(clip), "%s is still a code clip" % clip)
		assert_true(a.animator.has_clip(clip), "%s exists" % clip)
	assert_eq(
		BossAnimator.MOVE_CLIPS[WorldReader.MOVE_WAVE], &"wave", "the wave is a move with a clip"
	)
	var arm := a.skeleton.find_bone("upper_arm_R")
	_drive(a, {"state": WorldReader.STATE_MOVE, "move": -1}, 30)
	var idle_pose := a.skeleton.get_bone_pose_rotation(arm)
	var bell := a.anchor(&"bell")
	var mask := a.anchor(&"mask")
	var hand := a.anchor(&"hand")
	var light := a.sea_light.light_energy
	_drive(a, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_TIDE, "windup": 0.6}, 30)
	assert_gt(
		a.skeleton.get_bone_pose_rotation(arm).angle_to(idle_pose),
		0.3,
		"the staff arm lifts the bell for the Pull"
	)
	assert_gt(a.anchor(&"bell").y, bell.y + 0.3, "the bell's anchor rides the bell bone up")
	assert_gt(
		a.animator.param(&"glow"), 0.3, "the code clip's glow still plays under the animation"
	)
	assert_gt(a.sea_light.light_energy, light * 1.1, "the sea light follows it")
	_drive(
		a,
		{"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_SLAM_RING, "windup": 0.99},
		30
	)
	assert_lt(
		a.anchor(&"mask").y, mask.y - 0.2, "the mask's anchor rides the head down into the slam"
	)
	_drive(a, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_WAVE, "windup": 0.6}, 30)
	assert_gt(a.anchor(&"hand").distance_to(hand), 0.2, "the hand's anchor rides the claws' sweep")


func test_the_code_clips_show_on_top_of_the_animations() -> void:
	var a := _avatar()
	var staff_arm := a.skeleton.find_bone("upper_arm_R")
	var arm := a.skeleton.find_bone("upper_arm_L")
	var still := {"state": WorldReader.STATE_MOVE, "move": -1}
	_drive(a, still, 30)
	var staff_idle := a.skeleton.get_bone_pose_rotation(staff_arm)
	var arm_idle := a.skeleton.get_bone_pose_rotation(arm)
	# The roar at the phase gate: the idle animation plays at full weight under it, and it still reads.
	_drive(a, {"state": WorldReader.STATE_GATE, "move": -1, "gate": 0.5}, 30)
	assert_gt(
		a.skeleton.get_bone_pose_rotation(staff_arm).angle_to(staff_idle),
		0.2,
		"the staff arm swings out"
	)
	assert_gt(a.skeleton.get_bone_pose_rotation(arm).angle_to(arm_idle), 0.4, "the arm thrown wide")
	_drive(a, still, 90)
	assert_almost_eq(
		a.skeleton.get_bone_pose_rotation(arm).angle_to(arm_idle), 0.0, 0.2, "and it settles back"
	)
	# Every bone a code clip turns is one the model has.
	for c: BossClip in a.animator.clips.values():
		for k in c.track_count():
			var target := c.targets[k]
			if target == BossClip.BODY or c.channels[k] == BossClip.PARAM:
				continue
			assert_true(a.poser.has_bone(target), "%s: bone %s" % [c.name, target])


func test_the_tide_moves_the_owner_model() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	var bell := a.poser.index_of(&"bell")
	var shell := a.poser.index_of(&"shell")
	assert_gt(bell, -1, "the bell's bone")
	assert_gt(shell, -1, "the shell's bone")
	var pull := {
		"state": WorldReader.STATE_ACTIVE,
		"move": WorldReader.MOVE_TIDE,
		"tide_phase": WorldReader.TIDE_PULL,
		"tide_progress": 0.3,
		"shielded": true,
	}
	_drive(a, pull, 40)
	assert_gt(a.pull_amount(), 0.5, "the pull reads")
	var swings := 0
	var last := a.bell_swing()
	var turned := 0.0
	var before := a.skeleton.get_bone_pose_rotation(bell)
	for k in 30:
		_drive(a, pull, 1)
		if signf(a.bell_swing()) != signf(last):
			swings += 1
		last = a.bell_swing()
		turned = maxf(turned, a.skeleton.get_bone_pose_rotation(bell).angle_to(before))
	assert_gt(swings, 0, "the bell swings back and forth in the pull")
	assert_gt(turned, 0.3, "its bone swings with it, over the animation")
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
