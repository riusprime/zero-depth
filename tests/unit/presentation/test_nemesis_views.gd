extends GutTest
## The Nemesis read in 3D, from the sim (EI-07). The owner's model is one mesh skinned to a full skeleton and plays
## the animations in its file in the hero's motion vocabulary (run, dash, slash, shoot, cast, hit, rise, death), each
## attack move playing its own; the run's weapon rides its right hand's bone; its dash holds the file's dash pose and
## leaves afterimages; it rises from one knee on the floor and is standing when the intro ends; a card's cast names
## the card over its head with a sigil at its feet; a card's parts drawn on the ground (its swing, its lines, its
## blast) and struck in its own look on the sim's strike tick; its shots in its own fireball looks, never the hero's
## colours. Without the file, a code stand-in with the same weapon.

const DT := 1.0 / 60.0
## Twin and Fire in Spread's and Explosive's places (both retired, never cast).
const GUN_CARDS := [[&"gun_twin", 2], [&"ember_core", 3], [&"halo_shot", 1]]


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	BossModels.clear_cache()
	ViewPrefs.reduced_motion = false


func _drive(a: NemesisAvatar, s: Dictionary, frames: int, from_tick: int = 0) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = from_tick + t + 1
		d["pos"] = Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


## Where a bone's pivot is now, in the avatar's space.
func _bone_at(a: NemesisAvatar, bone: String) -> Vector3:
	var k := a.skeleton.find_bone(bone)
	return (
		a.model.transform
		* a.pivot.transform
		* BossModels.relative_transform(a.pivot, a.skeleton)
		* a.skeleton.get_bone_global_pose(k).origin
	)


## Where its weapon's grip is now, in the avatar's space.
func _weapon_at(a: NemesisAvatar) -> Vector3:
	return a.model.transform * a.pivot.transform * a.weapon.position


func _avatar() -> NemesisAvatar:
	var a := NemesisAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


func _views() -> NemesisViews:
	var v := NemesisViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_its_views_and_avatar_leave_no_orphan_nodes() -> void:
	var before := Node.get_orphan_node_ids().size()
	var v := _views()
	var a := _avatar()
	assert_not_null(v)
	assert_not_null(a)
	assert_eq(Node.get_orphan_node_ids().size(), before, "no node left outside the tree")


func test_its_clips_are_the_heros_motion_vocabulary() -> void:
	var lib := NemesisClips.library()
	for n: StringName in NemesisClips.NAMES:
		assert_true(lib.has(n), "%s is a clip" % n)
	for n: StringName in BossAnimator.COMMON:
		assert_true(lib.has(n), "%s (every boss has it)" % n)
	assert_eq(BossAnimator.MOVE_CLIPS[WorldReader.MOVE_MIMIC_COMBO], &"mimic_combo", "the slash")
	assert_eq(BossAnimator.MOVE_CLIPS[WorldReader.MOVE_MIMIC_SHOTS], &"mimic_shots", "the shot")
	assert_eq(BossAnimator.MOVE_CLIPS[WorldReader.MOVE_CARD_CAST], &"card_cast", "the cast")
	var a := _avatar()
	assert_not_null(a.imported, "the owner's small dark figure")
	assert_true(a.animator.has_clip(&"mimic_combo"))


func test_it_holds_the_runs_weapon() -> void:
	for pair: Array in [[&"blade", "Blade"], [&"gun", "Gun"]]:
		var w := NemesisLab.world(401, pair[0])
		var reader := WorldReader.new(w)
		var i := FinalLab.body(w)
		var a := _avatar()
		a.sync(reader, i)
		a.advance(DT)
		assert_eq(a.weapon_kind, pair[0], "the run's weapon")
		assert_not_null(a.weapon, "in its hand")
		assert_true((a.weapon.get_node(pair[1]) as Node3D).visible, "%s shown" % pair[1])


func test_the_slash_swings_its_blade_with_the_sims_attack() -> void:
	var w := NemesisLab.world(402, &"blade")
	var reader := WorldReader.new(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(2.2, 0))
	var a := _avatar()
	a.sync(reader, i)
	a.advance(DT)
	var rest := _weapon_at(a)
	var rest_way := a.weapon.basis.x
	NemesisLab.start(w, &"nemesis_combo")
	var most := 0.0
	var turned := 0.0
	for k in 70:
		w.step(InputFrame.new())
		a.sync(reader, i)
		a.advance(DT)
		assert_almost_eq(
			_weapon_at(a).distance_to(_bone_at(a, "hand_R")), 0.0, 0.001, "the blade is in its hand"
		)
		most = maxf(most, _weapon_at(a).distance_to(rest))
		turned = maxf(turned, a.weapon.basis.x.angle_to(rest_way))
	assert_gt(most, 0.4, "the hand carries the blade through the cut")
	assert_gt(turned, 1.5, "the blade swings across")


func test_it_plays_its_files_animations() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	assert_eq(a.skeleton.get_bone_count(), 44, "its skeleton")
	for clip: StringName in [
		&"idle",
		&"walk",
		&"mimic_combo",
		&"mimic_shots",
		&"card_cast",
		&"dash",
		&"flinch",
		&"rise",
		&"death"
	]:
		assert_true(a.animator.owner_has(clip), "%s plays an animation of the file" % clip)
	for clip: StringName in [&"shielded", &"stagger", &"roar"]:
		assert_false(a.animator.owner_has(clip), "%s is a code clip" % clip)
	# Standing still and running are different poses of the legs.
	var thigh := a.skeleton.find_bone("thigh_R")
	_drive(a, {"state": WorldReader.STATE_MOVE}, 30)
	var idle := a.skeleton.get_bone_pose_rotation(thigh)
	var swing := 0.0
	for t in 40:
		a.apply_state(
			{"tick": 31 + t, "pos": Vector2(5.2 * DT * t, 0), "state": WorldReader.STATE_MOVE}
		)
		a.advance(DT)
		swing = maxf(swing, a.skeleton.get_bone_pose_rotation(thigh).angle_to(idle))
	assert_gt(swing, 0.4, "its legs run")


func test_the_gun_points_ahead_on_the_shots_strike() -> void:
	var a := _avatar()
	var tk := Vector4i(48, 1, 30, 0)
	var shot := {"move": WorldReader.MOVE_MIMIC_SHOTS, "attack_ticks": tk, "weapon": &"gun"}
	var wind := shot.duplicate()
	wind["state"] = WorldReader.STATE_WINDUP
	for t in 48:
		wind["state_ticks"] = t
		_drive(a, wind, 1, t)
	shot["state"] = WorldReader.STATE_ACTIVE
	shot["state_ticks"] = 0
	_drive(a, shot, 1, 48)
	assert_true((a.weapon.get_node("Gun") as Node3D).visible, "the gun")
	assert_gt(a.weapon.basis.x.dot(Vector3.RIGHT), 0.95, "aimed along its front")
	assert_almost_eq(_weapon_at(a).distance_to(_bone_at(a, "hand_R")), 0.0, 0.001, "in its hand")


func test_the_dash_holds_its_pose_while_the_sim_dashes() -> void:
	var a := _avatar()
	_drive(a, {"state": WorldReader.STATE_MOVE}, 20)
	var chest := a.skeleton.find_bone("chest")
	var standing := _bone_at(a, "head")
	_drive(a, {"state": WorldReader.STATE_MOVE, "dashing": true}, 30, 20)
	var held := a.skeleton.get_bone_global_pose(chest)
	assert_almost_eq(a.dash_seconds(), NemesisAvatar.DASH_HELD, 0.0001, "at the end of the hold")
	assert_almost_eq(a.dash_amount(), 1.0, 0.0001, "in its dash")
	assert_lt(_bone_at(a, "head").y, standing.y - 0.15, "low")
	assert_gt(_bone_at(a, "head").x, standing.x + 0.15, "and leaning into its way")
	_drive(a, {"state": WorldReader.STATE_MOVE, "dashing": true}, 30, 50)
	assert_true(
		a.skeleton.get_bone_global_pose(chest).is_equal_approx(held),
		"the pose holds while it dashes"
	)
	_drive(a, {"state": WorldReader.STATE_MOVE, "dashing": false}, 40, 80)
	assert_eq(a.dash_amount(), 0.0, "out of it once the dash ends")
	assert_almost_eq(_bone_at(a, "head").y, standing.y, 0.08, "standing again")


func test_it_rises_from_one_knee_and_stands_by_the_end_of_the_intro() -> void:
	var still := _avatar()
	_drive(still, {"state": WorldReader.STATE_MOVE}, 2)
	var tall := _bone_at(still, "head").y
	var a := _avatar()
	var lows := []
	for t in 60:
		a.apply_state(
			{
				"tick": t + 1,
				"pos": Vector2.ZERO,
				"state": WorldReader.STATE_SPAWN,
				"intro": float(t + 1) / 60.0
			}
		)
		a.advance(DT)
		assert_almost_eq(a.model.position.y, 0.0, 0.001, "on the floor, never under it")
		lows.append(_bone_at(a, "head").y)
	assert_lt(float(lows[0]), tall * 0.7, "it starts low, on one knee")
	assert_gt(float(lows[59]), tall * 0.93, "standing when the intro ends")
	_drive(a, {"state": WorldReader.STATE_MOVE}, 70, 60)
	assert_eq(a.animator.slot_w[BossAnimator.RISE], 0.0, "then the rise is over")


func test_its_death_plays_and_holds() -> void:
	var a := _avatar()
	_drive(a, {"state": WorldReader.STATE_MOVE}, 10)
	var tall := _bone_at(a, "head").y
	assert_true(a.die(), "the last body falls (no shatter)")
	_drive(a, {"state": WorldReader.STATE_MOVE}, 80, 10)
	assert_eq(a.death_amount(), 1.0, "the fall has played")
	var down := _bone_at(a, "head")
	assert_lt(down.y, tall * 0.6, "it is down")
	_drive(a, {"state": WorldReader.STATE_MOVE}, 16, 90)
	assert_almost_eq(_bone_at(a, "head").distance_to(down), 0.0, 0.001, "and stays down")
	assert_almost_eq(_weapon_at(a).distance_to(_bone_at(a, "hand_R")), 0.0, 0.001, "weapon in hand")


func test_every_bone_a_clip_names_is_in_its_skeleton() -> void:
	var a := _avatar()
	var named := 0
	for c: BossClip in NemesisClips.library().values():
		for k in c.track_count():
			if c.targets[k] == BossClip.BODY or c.channels[k] == BossClip.PARAM:
				continue
			named += 1
			assert_true(
				a.poser.has_bone(c.targets[k]), "%s's %s is a bone" % [c.name, c.targets[k]]
			)
	assert_gt(named, 0, "the code clips turn bones")
	assert_true(a.poser.has_bone(NemesisAvatar.GRIP), "the weapon's hand")
	assert_true(a.poser.has_bone(a._weak_bone()), "the weak point's bone")
	# A code clip shows over the file's idle: the roar throws the hood back.
	var still := _avatar()
	_drive(still, {"state": WorldReader.STATE_MOVE}, 30)
	_drive(a, {"state": WorldReader.STATE_GATE, "gate": 0.5}, 30)
	var head := a.skeleton.find_bone("head")
	assert_gt(
		a.skeleton.get_bone_pose_rotation(head).angle_to(
			still.skeleton.get_bone_pose_rotation(head)
		),
		0.1,
		"the roar turns the hood"
	)


func test_the_stand_in_poses_without_the_file() -> void:
	BossModels.clear_cache()
	BossModels.dir = "res://nowhere/"
	var a := _avatar()
	assert_null(a.imported, "no file: the stand-in")
	assert_not_null(a.stand_in.get_parent(), "its hooded shape")
	assert_not_null(a.weapon, "with the weapon")
	_drive(a, {"state": WorldReader.STATE_MOVE, "weapon": &"gun", "dashing": true}, 20)
	assert_true((a.weapon.get_node("Gun") as Node3D).visible, "the run's gun")
	assert_gt(a.dash_amount(), 0.5, "it still reads the dash")
	assert_false(a.die(), "and has no fall")


func test_its_dash_leans_in_and_leaves_afterimages() -> void:
	var w := NemesisLab.world(403)
	var reader := WorldReader.new(w)
	var i := FinalLab.body(w)
	for k in 300:
		if w.actors.state[i] == EnemyAi.State.MOVE:
			break
		w.step(InputFrame.new())
	w.actors.cd[i] = 1 << 20
	var a := _avatar()
	var v := _views()
	w.step(NemesisLab.dash(Vector2(1, 0)))
	var leaned := 0.0
	var ghosts := 0
	for k in 40:
		w.step(InputFrame.new())
		a.sync(reader, i)
		a.advance(DT)
		v.sync(reader)
		leaned = maxf(leaned, a.dash_amount())
		ghosts = maxi(ghosts, v.ghost_count())
	assert_gt(leaned, 0.5, "the dash pose")
	assert_gt(ghosts, 1, "afterimages along its way")
	for k in 40:
		w.step(InputFrame.new())
		v.sync(reader)
	assert_eq(v.ghost_count(), 0, "they fade")


func test_a_card_cast_names_the_card_and_draws_its_parts() -> void:
	var w := NemesisLab.world(404, &"gun", GUN_CARDS)
	var reader := WorldReader.new(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(6, 0))
	var k := -1
	for n in w.final_fight.casts.size():
		if w.final_fight.casts[n].card_id == &"ember_core":
			k = n
	var v := _views()
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	var sv := BossStrikeViews.new()
	add_child_autofree(sv)
	var atk := NemesisLab.start(w, StringName("nemesis_card_%d" % (k + 1)))
	var named := ""
	var marks := 0
	var cast_strikes := 0
	for t in atk.windup_ticks + 4:
		w.step(InputFrame.new())
		v.sync(reader)
		tv.sync(reader)
		sv.sync(reader)
		if v.card_shown() != "":
			named = v.card_shown()
			assert_true(v.sigil_shown(), "its sigil at its feet")
		marks = maxi(marks, tv.count())
		for st: Array in sv.strikes():
			if st[0] == &"nm_cast":
				cast_strikes += 1
	var info := reader.card_info(NemesisLab.card(w, &"ember_core"))
	assert_eq(named, tr(StringName(info["name_key"])), "your card's own name")
	assert_gt(marks, 0, "its parts on the ground")
	assert_gt(cast_strikes, 0, "its blast struck in its look")
	for n in 40:
		w.step(InputFrame.new())
		v.sync(reader)
	assert_eq(v.card_shown(), "", "gone once cast")


func test_its_swings_strike_in_its_own_look_on_the_sims_tick() -> void:
	var w := NemesisLab.world(405, &"blade")
	var reader := WorldReader.new(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(2.2, 0))
	var sv := BossStrikeViews.new()
	add_child_autofree(sv)
	var atk := NemesisLab.start(w, &"nemesis_combo")
	var seen := 0
	for t in atk.windup_ticks + atk.active_ticks:
		var before := sv.strike_count()
		w.step(InputFrame.new())
		sv.sync(reader)
		var tg := reader.telegraph(i)
		if bool(tg.get("striking", false)):
			assert_gt(sv.strike_count(), before, "drawn on the sim's strike tick")
			seen += 1
	assert_eq(seen, atk.count, "every swing")
	for st: Array in sv.strikes():
		assert_eq(st[0], &"nm_slash")
	assert_eq(BossStrikeLooks.pattern_of(&"nm_slash"), BossStrikeLooks.Pattern.VOID)


func test_its_shots_wear_its_own_looks_never_the_heros() -> void:
	var hero := ThemePalette.color(&"player_core")
	for key: StringName in [NemesisCast.LOOK_BOLT, NemesisCast.LOOK_CRESCENT]:
		assert_true(FireballViews.LOOKS.has(key), "%s is a look" % key)
		var look := FireballViews.look_of(key)
		assert_gt(_dist(look["core"], hero), 0.3, "%s is never the hero's cyan" % key)
	assert_eq(FireballViews.look_of(NemesisCast.LOOK_CRESCENT)["mesh"], &"crescent")
	assert_not_null(ProjectileMeshes.get_mesh(&"crescent"), "the flying slash's mesh")
	var w := NemesisLab.world(406, &"blade")
	var reader := WorldReader.new(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(8, 0))
	var fv := FireballViews.new()
	add_child_autofree(fv)
	NemesisLab.start(w, &"nemesis_crescents")
	NemesisLab.to_active(w, 2)
	fv.sync(reader)
	assert_gt(fv.ball_count(NemesisCast.LOOK_CRESCENT), 0, "the crescents fly in its look")


func test_reduced_motion_keeps_its_poses() -> void:
	ViewPrefs.reduced_motion = true
	var w := NemesisLab.world(407)
	var reader := WorldReader.new(w)
	var i := FinalLab.body(w)
	var a := _avatar()
	var v := _views()
	for k in 30:
		w.step(InputFrame.new())
		a.sync(reader, i)
		a.advance(DT)
		v.sync(reader)
	assert_not_null(a.weapon, "posed")
