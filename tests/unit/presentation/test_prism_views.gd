extends GutTest
## The Prism read in 3D, from the sim (EI-07). The owner's model is one mesh skinned to a full skeleton and plays the
## animations in its file; her nine crystals float in place (their parent bone is never turned, though the sim's shard
## ring turns), and the one nearest the sim shard that fires flares, where the views put the flash; she stands over
## the boss's place through the fight, her forming and her breaking. The Cross is drawn where the sim's beams are
## (aim lines through the spin-up, beams through the spin, nothing but the window's ring after); a bolt's aim line
## shows through its 0.4 s, from the sim's shard, and goes as it fires; her clips and her fireball looks.

const LONG := 1 << 24
const DT := 1.0 / 60.0


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	if BossModels.dir != BossModels.DIR:
		BossModels.dir = BossModels.DIR
		BossModels.clear_cache()


func _prism(seed_value: int = 301) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value))
	w.actors.invuln[0] = LONG
	w.actors.max_hp[0] = LONG
	w.actors.hp[0] = LONG
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	return w


func _avatar() -> PrismAvatar:
	var a := PrismAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


func _views() -> PrismViews:
	var v := PrismViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func _start(w: World, id: StringName = &"cross_ring") -> BossAttackTable:
	var i := FinalLab.body(w)
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(id))
	return BossAi.attack_of(w, i)


func _drive(a: PrismAvatar, s: Dictionary, frames: int, from_tick: int = 0) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = from_tick + t + 1
		if not d.has("pos"):
			d["pos"] = Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


## The body bone's place across the floor in the avatar's space (m): the boss's place is the origin.
func _axis(a: PrismAvatar) -> Vector2:
	var k := a.skeleton.find_bone("body")
	var p := a.model.transform * (a._skel_to_model() * a.skeleton.get_bone_global_pose(k).origin)
	return Vector2(p.x, p.z)


func _height_of(a: PrismAvatar, bone: String) -> float:
	var k := a.skeleton.find_bone(bone)
	return (a._skel_to_model() * a.skeleton.get_bone_global_pose(k).origin).y


func test_the_model_loads_skinned_at_its_height_over_her_own_axis() -> void:
	var m := BossModels.get_model(&"final_boss_prism")
	assert_false(m.is_empty(), "the owner's Prism is installed")
	assert_true(bool(m.get("skinned", false)), "it keeps its skeleton")
	var box: AABB = m["aabb"]
	assert_almost_eq(box.size.y, 3.0, 0.01, "3.0 m to her crown")
	assert_almost_eq(box.position.y, 0.35, 0.01, "she floats")
	var a := _avatar()
	assert_eq(a.skeleton.get_bone_count(), 50, "her bones")
	assert_eq(a.shard_count(), 9, "nine floating crystals, each its own bone")
	for bone: StringName in [
		&"root", &"body", &"chest", &"head", &"core", &"shards_lift", &"shards"
	]:
		assert_true(a.poser.has_bone(bone), "the %s bone" % bone)
	# Her box is centred on her crystals, which hang wider on her left: the model stands by her body bone.
	var to_model := BossModels.relative_transform(a.pivot, a.skeleton)
	var rest := to_model * a.skeleton.get_bone_global_rest(a.skeleton.find_bone("body")).origin
	assert_almost_eq(Vector2(rest.x, rest.z).length(), 0.0, 0.001, "her axis is the model's origin")
	assert_gt(absf(box.get_center().z), 0.3, "which is not the middle of her box")
	var core := a.model.transform.affine_inverse() * a.anchor(&"core")
	assert_gt(core.x, 0.1, "the core's anchor on her chest, in front")
	assert_between(core.y, 1.8, 2.5, "at chest height")


func test_every_bone_the_clips_and_the_avatar_name_is_in_the_model() -> void:
	var a := _avatar()
	var named := 0
	for c: BossClip in PrismClips.library().values():
		for k in c.targets.size():
			if c.channels[k] != BossClip.PARAM and c.targets[k] != BossClip.BODY:
				assert_true(a.poser.has_bone(c.targets[k]), "%s moves %s" % [c.name, c.targets[k]])
				named += 1
	assert_gt(named, 10, "the clips that still play turn her bones")
	for bone: StringName in [PrismAvatar.AXIS_BONE, a._weak_bone(), &"core"]:
		assert_true(a.poser.has_bone(bone), "the avatar's %s" % bone)
	for clip: StringName in PrismAvatar.OWNER_PLAYS:
		assert_true(PrismClips.library().has(clip), "the %s clip a file's animation plays" % clip)


func test_she_plays_her_files_animations() -> void:
	var a := _avatar()
	for clip: StringName in [&"idle", &"walk"]:
		assert_true(a.animator.owner_has(clip), "the file's %s" % clip)
	for clip: StringName in PrismAvatar.OWNER_PLAYS:
		assert_true(a.animator.owner_has(clip), "%s plays a file's animation" % clip)
	for clip: StringName in [&"shielded", &"flinch", &"stagger", &"roar", &"death"]:
		assert_false(a.animator.owner_has(clip), "%s is played from the code" % clip)
	assert_eq(a._idle_seconds(), 10.0, "the idle plays at the length it was made")
	assert_almost_eq(
		a._stride() / a._walk_speed(), 10.0, 0.01, "one float loop takes 10 s at her speed"
	)
	var head := a.skeleton.find_bone("head")
	_drive(a, {"state": WorldReader.STATE_MOVE}, 30)
	var idle := a.skeleton.get_bone_global_pose(head).origin
	var moves := {
		WorldReader.MOVE_CROSS: &"cross",
		WorldReader.MOVE_PATTERN: &"pattern",
		WorldReader.MOVE_BOLT_FAN: &"bolt_fan",
		WorldReader.MOVE_LANCES: &"lances",
		WorldReader.MOVE_KNEEL: &"kneel",
	}
	for move: int in moves:
		var b := _avatar()
		var s := {
			"state": WorldReader.STATE_ACTIVE,
			"move": move,
			"attack_ticks": Vector4i(60, 240, 30, 0),
			"state_ticks": 120
		}
		_drive(b, {"state": WorldReader.STATE_WINDUP, "move": move, "windup": 0.5}, 2)
		_drive(b, s, 30, 2)
		assert_eq(b.animator.action_clip().name, moves[move], "the %s clip" % moves[move])
		var at := b.skeleton.get_bone_global_pose(head).origin
		assert_gt(
			at.distance_to(idle) * b.poser._scale,
			0.05,
			"%s moves her hood off the idle" % moves[move]
		)


func test_her_crystals_float_in_place_and_their_parent_is_never_turned() -> void:
	var w := _prism(302)
	var i := FinalLab.body(w)
	var reader := WorldReader.new(w)
	var a := _avatar()
	var shards := a.skeleton.find_bone("shards")
	var rest := a.skeleton.get_bone_rest(shards)
	var rest_turn := rest.basis.get_rotation_quaternion()
	var seen := {"frames": 0, "moved": 0}
	var check := func() -> void:
		a.sync(reader, i)
		a.advance(DT)
		seen["frames"] += 1
		if not a.skeleton.get_bone_pose_rotation(shards).is_equal_approx(rest_turn):
			seen["moved"] += 1
		elif not a.skeleton.get_bone_pose_position(shards).is_equal_approx(rest.origin):
			seen["moved"] += 1
	check.call()
	var ring0 := reader.boss_shards(i)[0]
	for k in 90:
		w.step(InputFrame.new())
		check.call()
	assert_gt(
		reader.boss_shards(i)[0].distance_to(ring0), 1.5, "1.5 s on, the sim's ring has turned"
	)
	for id: StringName in [&"cross_ring", &"crown_ring"]:  # the Cross (its spin, its window), an orb volley
		var atk := _start(w, id)
		for k in atk.windup_ticks + atk.active_ticks + 30:
			w.step(InputFrame.new())
			check.call()
	assert_gt(int(seen["frames"]), 600, "through the idle, a Cross and a volley")
	assert_eq(int(seen["moved"]), 0, "the crystals' parent bone kept its rest pose every frame")
	# Through a whole idle loop every crystal floats near its own place, and turns about its own axis.
	var b := _avatar()
	_drive(b, {"state": WorldReader.STATE_MOVE}, 1)
	var first := []
	var turn0 := b.skeleton.get_bone_pose_rotation(b._crystals[0])
	for k in b.shard_count():
		first.append(b.crystal_place(k))
	var far := 0.0
	var turned := 0.0
	for t in 600:
		_drive(b, {"state": WorldReader.STATE_MOVE}, 1, t + 1)
		for k in b.shard_count():
			far = maxf(far, b.crystal_place(k).distance_to(first[k]))
		turned = maxf(turned, b.skeleton.get_bone_pose_rotation(b._crystals[0]).angle_to(turn0))
	assert_lt(far, 0.4, "no crystal leaves its place (%.2f m at most)" % far)
	assert_gt(turned, 2.5, "each turns on itself")


func test_the_crystal_nearest_the_sim_shard_that_fires_flares() -> void:
	var a := _avatar()
	_drive(a, {"state": WorldReader.STATE_MOVE}, 10)
	var tick := 10
	for want: int in [0, 4, 7]:
		var at := a.crystal_place(want)
		_drive(a, {"state": WorldReader.STATE_MOVE, "firing": at}, 30, tick)
		for k in a.shard_count():
			if k == want:
				assert_gt(a.shard_flare(k), 0.9, "crystal %d, the nearest, flares" % k)
				assert_gt(
					a.skeleton.get_bone_pose_scale(a._crystals[k]).x, 1.5, "and swells on its bone"
				)
			else:
				assert_lt(a.shard_flare(k), 0.3, "crystal %d does not" % k)
		_drive(a, {"state": WorldReader.STATE_MOVE, "firing": null}, 40, tick + 30)
		assert_lt(a.shard_flare(want), 0.01, "it fades once nothing fires")
		tick += 70
	# From the sim: through a Cross's window, whenever a shard aims a bolt, the crystal that swells is the nearest.
	var w := _prism(303)
	var i := FinalLab.body(w)
	var atk := _start(w)
	var reader := WorldReader.new(w)
	var b := _avatar()
	var flared := 0.0
	var fired := 0
	for k in atk.windup_ticks + atk.active_ticks:
		w.step(InputFrame.new())
		b.sync(reader, i)
		b.advance(DT)
		if not b.is_firing():
			continue
		fired += 1
		var near := b.nearest_crystal_index(b.firing_place())
		flared = maxf(flared, b.shard_flare(near))
	assert_gt(fired, 20, "her shards aimed bolts")
	assert_gt(flared, 0.9, "the nearest crystal flares as its shard fires")


func test_the_firing_flash_is_drawn_on_a_crystal_and_the_aim_line_stays_on_the_sim() -> void:
	var w := _prism(305)
	var i := FinalLab.body(w)
	_start(w)
	var reader := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var v := _views()
	v.actors = actors
	var seen := 0
	var farthest := 0.0
	for k in 520:
		w.step(InputFrame.new())
		actors.sync(reader)
		var bolt: Dictionary = reader.boss_cross(i).get("bolt", {})
		if bolt.is_empty():
			continue
		var avatar: PrismAvatar = actors.actor_node(reader.actor_id(i)).get_meta(&"enemy_avatar")
		avatar.advance(DT)
		v.sync(reader)
		seen += 1
		assert_true(v.shard_flash_drawn(), "the flash shows while a shard aims")
		var sim := SimPlane.to_3d(reader.boss_shards(i)[int(bolt["shard"])], PrismViews.SHARD_Y)
		var want := avatar.nearest_crystal(sim)
		assert_almost_eq(v.shard_flash_at().distance_to(want), 0.0, 0.001, "on the nearest crystal")
		farthest = maxf(farthest, Vector2(want.x - sim.x, want.z - sim.z).length())
		# The aim line is a forecast: it starts at the sim's shard, wherever the crystal is drawn.
		var line := v._bolt_line.transform
		var from := line.origin - line.basis.y * 0.5
		assert_almost_eq(
			from.distance_to(SimPlane.to_3d(bolt["from"], PrismViews.SHARD_Y)),
			0.0,
			0.001,
			"the aim line starts where the sim fires from"
		)
	assert_gte(seen, 24, "bolts aimed")
	assert_gt(farthest, 0.05, "the crystals are not on the sim's ring (%.2f m)" % farthest)
	assert_lt(farthest, 3.2, "but one is always near (%.2f m)" % farthest)


func test_she_stays_over_the_boss_through_the_fight_her_forming_and_her_breaking() -> void:
	var a := _avatar()
	# She forms: the sim's 1 s intro, then the flourish. "form" plays; she is on the floor, not under it.
	var worst := 0.0
	var low := 0.0
	var spawn := {"pos": Vector2.ZERO, "state": WorldReader.STATE_SPAWN}
	for t in 60:
		spawn["tick"] = t + 1
		spawn["intro"] = (t + 1) / 60.0
		a.apply_state(spawn)
		a.advance(DT)
		worst = maxf(worst, absf(_axis(a).y))
		low = minf(low, a.model.position.y)
		if t == 0:
			assert_eq(a.animator.slot_clip[BossAnimator.RISE].name, &"rise", "the rise")
			assert_true(a.animator.owner_has(&"rise"), "is the file's form")
			var rest_k := a.skeleton.find_bone("head")
			var rest_y := (a._skel_to_model() * a.skeleton.get_bone_global_rest(rest_k).origin).y
			assert_lt(_height_of(a, "head"), rest_y * 0.9, "she starts folded low")
	assert_almost_eq(a.animator.slot_t[BossAnimator.RISE], 0.55, 0.01, "55 % of it over the intro")
	for t in 70:
		a.apply_state({"tick": 61 + t, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE})
		a.advance(DT)
		worst = maxf(worst, absf(_axis(a).y))
	assert_lt(worst, 0.04, "no slide to her side as she forms (%.3f m)" % worst)
	assert_almost_eq(low, 0.0, 0.001, "she forms in sight, not out of the floor")
	assert_almost_eq(a.animator.slot_w[BossAnimator.RISE], 0.0, 0.001, "the rise is over")
	# The fight: idling, her axis stays over the boss.
	_drive(a, {"state": WorldReader.STATE_MOVE}, 120, 131)
	assert_lt(_axis(a).length(), 0.15, "idling over the boss (%.3f m)" % _axis(a).length())
	# She breaks: the file's break plays by the shatter's progress, sinks to a heap, and holds. Reduced motion takes
	# FinalBodyAvatar's tremble off, so what is measured is the slide alone.
	ViewPrefs.reduced_motion = true
	var up := _height_of(a, "head")
	worst = 0.0
	var breaking := {"pos": Vector2.ZERO, "state": WorldReader.STATE_SHATTER}
	for t in 90:
		breaking["tick"] = 300 + t
		breaking["shatter"] = (t + 1) / 90.0
		a.apply_state(breaking)
		a.advance(DT)
		worst = maxf(worst, absf(_axis(a).y))
	assert_eq(a.animator.slot_clip[BossAnimator.DEATH].name, &"shatter", "the shatter")
	assert_true(a.animator.owner_has(&"shatter"), "is the file's break")
	assert_almost_eq(a.animator.slot_w[BossAnimator.DEATH], 1.0, 0.001)
	assert_lt(worst, 0.04, "no slide to her side as she breaks (%.3f m)" % worst)
	var heap := _height_of(a, "head")
	assert_lt(heap, up * 0.65, "a low heap: her hood at %.2f m, from %.2f m" % [heap, up])
	var hood := a.skeleton.find_bone("head")
	var held := a.skeleton.get_bone_pose_rotation(hood)
	for t in 30:
		breaking["tick"] = 390 + t
		a.apply_state(breaking)
		a.advance(DT)
	assert_true(a.skeleton.get_bone_pose_rotation(hood).is_equal_approx(held), "the heap holds")
	assert_false(a.die(), "a shattered body leaves at once (the shards burst)")


func test_the_code_clips_show_over_the_files_idle() -> void:
	var a := _avatar()
	_drive(a, {"state": WorldReader.STATE_MOVE, "hp": 100}, 20)
	var head := a.skeleton.find_bone("head")
	var before := a.skeleton.get_bone_pose_rotation(head)
	_drive(a, {"state": WorldReader.STATE_MOVE, "hp": 90}, 6, 20)
	assert_gt(a.flinch_amount(), 0.0, "a hit flinches")
	assert_gt(
		a.skeleton.get_bone_pose_rotation(head).angle_to(before), 0.05, "her hood is thrown back"
	)
	_drive(a, {"state": WorldReader.STATE_MOVE, "hp": 90}, 90, 26)
	var rest_y := _height_of(a, "shards_lift")
	_drive(a, {"state": WorldReader.STATE_GATE, "gate": 0.5, "hp": 90}, 30, 116)
	assert_gt(_height_of(a, "shards_lift"), rest_y + 0.2, "the roar lifts her crystals")


func test_the_stand_in_floats_its_crystals_in_place() -> void:
	BossModels.dir = "res://tests/no_such_dir/"
	BossModels.clear_cache()
	var a := _avatar()
	assert_null(a.imported, "the code stand-in")
	assert_eq(a.shard_count(), 6)
	_drive(a, {"state": WorldReader.STATE_MOVE}, 5)
	var p0 := a.crystal_place(2)
	_drive(a, {"state": WorldReader.STATE_MOVE, "firing": p0}, 60, 5)
	assert_almost_eq(
		a.crystal_place(2).distance_to(p0), 0.0, 0.001, "its crystals do not circle her"
	)
	assert_gt(a.shard_flare(2), 0.9, "the nearest one flares")


func test_the_cross_is_drawn_where_the_sim_beams_are() -> void:
	var w := _prism(304)
	var i := FinalLab.body(w)
	var atk := _start(w)
	var reader := WorldReader.new(w)
	var v := _views()
	for k in 20:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.aim_count(), 4, "the spin-up: four aim lines")
	assert_eq(v.beam_count(), 0)
	while w.actors.state[i] != EnemyAi.State.ACTIVE or w.actors.state_t[i] < 60:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.beam_count(), 4, "four beams turning")
	var arms: Array = reader.boss_cross(i)["arms"]
	var ends := v.arm_ends()
	for k in 4:
		var to: Vector3 = ends[k][1]
		var want := SimPlane.to_3d(arms[k][1], to.y)
		assert_almost_eq(to.distance_to(want), 0.0, 0.001, "beam %d ends where the sim's does" % k)
	assert_false(v.window_drawn())
	while w.actors.state_t[i] < atk.spin_ticks + 10:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.beam_count(), 0, "the window: the beams are out")
	assert_true(v.window_drawn(), "her ring says strike now")
	assert_false(reader.boss_shielded(i))


func test_a_bolts_aim_line_shows_then_goes() -> void:
	var w := _prism(305)
	var i := FinalLab.body(w)
	_start(w)
	var reader := WorldReader.new(w)
	var v := _views()
	var shown := 0
	var gone_after := false
	for k in 520:  # v0.8.0 PR: the bolts aim in the window (from 1.3 s after the spin-up's 6.0 s)
		w.step(InputFrame.new())
		v.sync(reader)
		var aiming := not BossPrism.bolt_state(w, i).is_empty()
		assert_eq(v.bolt_line_drawn(), aiming, "drawn exactly while the sim aims")
		if aiming:
			shown += 1
		elif shown > 0:
			gone_after = true
	assert_gte(shown, 24, "it shows through its 0.4 s")
	assert_true(gone_after, "and goes as the bolt flies")


func test_reduced_motion_keeps_the_cross() -> void:
	ViewPrefs.reduced_motion = true
	var w := _prism(306)
	var i := FinalLab.body(w)
	_start(w)
	var reader := WorldReader.new(w)
	var v := _views()
	while w.actors.state[i] != EnemyAi.State.ACTIVE:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.beam_count(), 4, "still drawn, only stilled")


func test_her_clips() -> void:
	var lib := PrismClips.library()
	for n: StringName in PrismClips.NAMES:
		assert_true(lib.has(n), "the %s clip" % n)
	for n: StringName in BossAnimator.COMMON:
		assert_true(lib.has(n), "the common %s clip" % n)
	assert_eq(BossAnimator.clip_name_for(WorldReader.MOVE_CROSS, true, lib), &"cross")
	var c: BossClip = lib[&"cross"]
	var spin := c.track_of(&"spin", BossClip.PARAM)
	var open := c.track_of(&"open", BossClip.PARAM)
	assert_almost_eq(c.value(spin, 0.5), 1.0, 0.01, "the shards race through the spin")
	assert_almost_eq(c.value(open, 0.9), 1.0, 0.01, "she sags open in the window")


func test_her_orbs_and_bolts_have_their_looks() -> void:
	var orb := FireballViews.look_of(&"crown_orb")
	var bolt := FireballViews.look_of(&"crown_bolt")
	assert_eq(orb["mesh"], &"gem", "crystal orbs")
	assert_gt(float(orb["facets"]), 0.0)
	assert_eq(bolt["mesh"], &"spear", "the bolts are long crystal spears")
	assert_gt(float(bolt["tip"]), 2.0)
	assert_ne(orb["core"], FireballViews.look_of(&"prism_orb")["core"], "not the Hive Lens's")


func test_her_views_and_avatar_leave_no_orphan_nodes() -> void:
	# v0.8.0 fix: a node made in a member's initializer and then replaced in _init was never in the tree (the damage
	# soak's 6 orphans: 2 per fight). Built and put in the tree, every node they made is in it.
	var before := Node.get_orphan_node_ids().size()
	var v := _views()
	var a := _avatar()
	assert_not_null(v)
	assert_not_null(a)
	assert_eq(Node.get_orphan_node_ids().size(), before, "no node left outside the tree")


# --- v0.10.5 O3: her last phase (owner L6; O3_PRISM.md) ---------------------------------------------------------


func test_the_facet_lances_are_drawn_where_the_sim_has_them() -> void:
	var w := _prism(311)
	var i := FinalLab.body(w)
	var reader := WorldReader.new(w)
	var v := _views()
	var atk := _start(w, &"facet_lances")
	v.sync(reader)
	assert_eq(v.last.facets_drawn(), 6, "six facets gather at the rim")
	assert_eq(v.last.lance_lines(), 0, "no line in the gather")
	while w.actors.state[i] != EnemyAi.State.ACTIVE or w.actors.state_t[i] < 58:
		w.step(InputFrame.new())
	v.sync(reader)
	var s := reader.boss_lances(i)
	var lines := 0
	var strikes := 0
	for row: Dictionary in s["lances"]:
		if int(row["phase"]) == BossPrismLast.STRIKING:
			strikes += 1
		else:
			lines += 1
	assert_gt(lines, 0)
	assert_eq(v.last.lance_lines(), lines, "each tracking or locked lance shows its line")
	assert_eq(v.last.lance_strikes(), strikes, "the striking one shows its beam")
	assert_eq(strikes, 1, "one lance strikes at a time")
	while w.actors.state[i] == EnemyAi.State.ACTIVE:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.last.lance_lines() + v.last.lance_strikes() + v.last.facets_drawn(), 0, "all spent")
	assert_gt(atk.active_ticks, 0)


func test_the_kneel_shows_her_core_and_its_crack() -> void:
	var w := _prism(312)
	var i := FinalLab.body(w)
	var reader := WorldReader.new(w)
	var v := _views()
	var atk := _start(w, &"prism_kneel")
	while w.actors.state[i] != EnemyAi.State.ACTIVE or w.actors.state_t[i] < 2:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_true(v.last.core_drawn(), "her core shows while she is down")
	assert_eq(v.last.crack_lit(), 0)
	FinalLab.hit(w, w.actors.max_hp[i] * atk.crack_permille / 1000 / 2)
	w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.last.crack_lit(), PrismLastViews.CRACK_MARKS / 2, "half the crack lit")
	FinalLab.hit(w, w.actors.max_hp[i] * atk.crack_permille / 1000)
	w.step(InputFrame.new())
	w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(reader.boss_kneel(i)["stage"], 2, "she rises once her core bursts")
	assert_true(v.last.core_drawn(), "the burst's flash")
	assert_eq(v.last.crack_lit(), PrismLastViews.CRACK_MARKS)


func test_her_last_phase_clips() -> void:
	var lib := PrismClips.library()
	assert_eq(BossAnimator.clip_name_for(WorldReader.MOVE_LANCES, true, lib), &"lances")
	assert_eq(BossAnimator.clip_name_for(WorldReader.MOVE_KNEEL, false, lib), &"kneel")
	var c: BossClip = lib[&"kneel"]
	assert_almost_eq(c.value(c.track_of(&"open", BossClip.PARAM), 0.5), 1.0, 0.01, "her core shows")
