extends GutTest
## The Lantern Shade's look. The owner's model (PLAN NB "Keep the empty hood") loads at the art list's 3.4 m, front
## turned to +X, one mesh skinned to a full skeleton; it plays the animations in its file (the hover, the glide, its
## four attacks) for the clips they stand for, its lantern's light riding the lantern's bone, flaring for Lights Out
## and burning low in the dark; the clips it has no animation for show over the file's idle; with the file missing a
## code stand-in of the same parts poses from the same inputs. ShadeViews draws, from the reader only, the dark
## (ramping in over Lights Out, drawn before every
## marker), the four lanterns lit, burnt out and relit, each lit one a light circle of the dark pass, and the outline
## of every wisp within 4 m of the hero, never thinned by Effects density. Presentation only.

const DT := 1.0 / 60.0
const LONG := 1 << 20


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	BossModels.clear_cache()
	ViewPrefs.effects_density = "high"


func _avatar() -> LanternShadeAvatar:
	var a := LanternShadeAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


func _drive(a: LanternShadeAvatar, s: Dictionary, frames: int) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = t + 1
		d["pos"] = Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


func test_the_model_loads_skinned_at_its_height() -> void:
	var m := BossModels.get_model(&"boss_lantern_shade")
	assert_false(m.is_empty(), "loads")
	var box: AABB = m["aabb"]
	assert_almost_eq(box.size.y, 3.4, 0.01, "3.4 m (the art list's)")
	assert_almost_eq(box.position.y, 0.3, 0.01, "it floats: its hem off the ground")
	assert_true(bool(m.get("skinned", false)), "it keeps its skeleton")
	var a := _avatar()
	assert_eq(a.skeleton.get_bone_count(), 57, "its bones")
	for bone: StringName in [&"hips", &"chest", &"head", &"lantern", &"chain1"]:
		assert_true(a.poser.has_bone(bone), "the %s bone" % bone)
	for bone: StringName in LanternShadeAvatar.HEM:
		assert_true(a.poser.has_bone(bone), "the robe's %s chain" % bone)
	# At rest the lantern hangs in its right hand (+Z), below the shoulder; the hood is the top of the figure.
	var lamp := a.model.transform.affine_inverse() * a.anchor(&"lantern")
	assert_gt(lamp.z, 0.8, "the lantern in its right hand")
	assert_lt(lamp.y, 2.0, "hanging below the shoulder")
	assert_gt(
		(a.model.transform.affine_inverse() * a.anchor(&"hood")).y,
		lamp.y + 1.0,
		"the hood above it"
	)


## Every bone a clip turns is a bone of the model: BonePoser skips a name it does not know, so a wrong name would
## stop that part moving without a word.
func test_every_bone_the_clips_turn_is_in_the_model() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	var lib := LanternShadeClips.library()
	for c: BossClip in lib.values():
		for k in c.track_count():
			if c.channels[k] == BossClip.PARAM or c.targets[k] == BossClip.BODY:
				continue
			assert_true(a.poser.has_bone(c.targets[k]), "%s turns %s" % [c.name, c.targets[k]])


func test_it_plays_its_files_animations() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	for clip: StringName in [
		&"idle", &"walk", &"pattern_shielded", &"pattern", &"marks", &"slam_ring"
	]:
		assert_true(a.animator.owner_has(clip), "%s plays the file's animation" % clip)
	for clip: StringName in [&"shielded", &"flinch", &"stagger", &"roar", &"rise", &"death"]:
		assert_false(a.animator.owner_has(clip), "%s keeps its code clip" % clip)
	var arm := a.skeleton.find_bone("upper_arm_R")
	var hips := a.skeleton.find_bone("hips")
	# The hover: the file's idle bobs the hips and swings the lantern, with nothing added in code.
	var heights := []
	var lamps := []
	for k in 12:
		_drive(a, {"state": WorldReader.STATE_MOVE, "move": -1}, 20)
		heights.append(a.skeleton.get_bone_global_pose(hips).origin.y)
		lamps.append(a.anchor(&"lantern"))
	assert_gt(heights.max() - heights.min(), 0.03, "a slow floating bob")
	var swung := 0.0
	for p: Vector3 in lamps:
		swung = maxf(swung, p.distance_to(lamps[0]))
	assert_gt(swung, 0.03, "the lantern swings on its chain")
	assert_eq(a.lantern_swing(), 0.0, "and the avatar adds no swing of its own")
	var idle_pose := a.skeleton.get_bone_pose_rotation(arm)
	var idle_lamp := a.anchor(&"lantern")
	# Lights Out: the lantern raised high beside the hood, held through the active part.
	var lights_out := {"move": WorldReader.MOVE_PATTERN, "shielded": true, "dark": 0.0}
	lights_out["state"] = WorldReader.STATE_WINDUP
	lights_out["windup"] = 0.95
	_drive(a, lights_out, 40)
	assert_gt(
		a.skeleton.get_bone_pose_rotation(arm).angle_to(idle_pose), 0.5, "the lantern arm comes up"
	)
	assert_gt(a.anchor(&"lantern").y, idle_lamp.y + 0.8, "the lantern anchor rides its bone up")
	assert_gt(a.lantern_light.position.y, 2.4, "and its light goes with it")
	assert_gt(
		a.animator.param(&"flare"), 1.0, "the code clip's flare still plays under the animation"
	)
	# The Lantern Sweep swings it round to the front.
	_drive(a, {"state": WorldReader.STATE_MOVE, "move": -1}, 40)
	var sweep := {"state": WorldReader.STATE_ACTIVE, "move": WorldReader.MOVE_SLAM_RING}
	_drive(a, sweep, 3)
	assert_gt(a.anchor(&"lantern").distance_to(idle_lamp), 0.5, "the sweep carries the lantern")


func test_the_code_clips_show_over_the_files_idle() -> void:
	var a := _avatar()
	var arm := a.skeleton.find_bone("upper_arm_L")
	var hips := a.skeleton.find_bone("hips")
	_drive(a, {"state": WorldReader.STATE_MOVE, "move": -1}, 30)
	var calm_arm := a.skeleton.get_bone_pose_rotation(arm)
	var calm_hips := a.skeleton.get_bone_global_pose(hips).origin.y
	var calm_hem := a.skeleton.get_bone_pose_rotation(a.skeleton.find_bone("strip_side1_L"))
	# The phase gate: the stagger sags it, the roar flings its arms wide and billows the hem.
	_drive(a, {"state": WorldReader.STATE_GATE, "move": -1, "gate": 0.5}, 40)
	assert_gt(a.skeleton.get_bone_pose_rotation(arm).angle_to(calm_arm), 0.5, "the arms flung wide")
	assert_gt(
		a.skeleton.get_bone_pose_rotation(a.skeleton.find_bone("strip_side1_L")).angle_to(calm_hem),
		0.1,
		"the robe's hem billows"
	)
	assert_gt(
		absf(a.skeleton.get_bone_global_pose(hips).origin.y - calm_hips), 0.08, "the figure shifts"
	)
	# Left alone again it comes back to the file's idle: nothing laid over is left behind.
	_drive(a, {"state": WorldReader.STATE_MOVE, "move": -1}, 240)
	assert_lt(
		a.skeleton.get_bone_pose_rotation(arm).angle_to(calm_arm),
		0.15,
		"the arm hangs as in the idle"
	)


func test_its_lantern_flares_and_burns_low_in_the_dark() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	_drive(a, {"state": WorldReader.STATE_MOVE, "dark": 0.0}, 60)
	var lit := a.lantern_glow()
	_drive(
		a,
		{
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_PATTERN,
			"windup": 0.9,
			"shielded": true,
			"dark": 0.0
		},
		40
	)
	assert_gt(
		a.lantern_glow(), lit * 1.3, "Lights Out: the lantern flares as the room drains into it"
	)
	_drive(a, {"state": WorldReader.STATE_MOVE, "dark": 1.0}, 90)
	assert_lt(a.lantern_glow(), lit * 0.75, "it burns low in the dark")
	assert_gt(a.lantern_glow(), 0.08, "but never out: the Shade is found by its lantern")
	# A hit kicks the lantern on its chain (the flinch's swing), over what the file's idle already swings it.
	_drive(a, {"state": WorldReader.STATE_MOVE, "dark": 0.0}, 60)
	var swings := []
	for k in 8:
		_drive(a, {"state": WorldReader.STATE_GATE, "move": -1}, 8)
		swings.append(a.lantern_swing())
	assert_gt(swings.max() - swings.min(), 0.05, "the stagger sets the lantern swinging")


func test_the_stand_in_poses_without_the_file() -> void:
	BossModels.clear_cache()
	BossModels.dir = "res://nowhere/"
	var a := _avatar()
	assert_null(a.imported, "no file: the stand-in")
	assert_not_null(a.lantern.get_parent(), "with its lantern")
	var bobs := []
	for k in 6:
		_drive(a, {"state": WorldReader.STATE_MOVE, "dark": 0.0}, 20)
		bobs.append(a.bob_height())
	assert_gt(bobs.max() - bobs.min(), 0.03, "it floats in code")
	_drive(
		a, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_MARKS, "windup": 0.8}, 30
	)
	assert_gt(a.arm_l.rotation.z, 0.5, "the arms reach for the Snuff")
	assert_gt(a.arm_r.rotation.z, 0.5)


func _fight() -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"lantern_shade")
	var t := BossAi.table_of(w, i)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.sig_every_ticks = 0
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.speed = 0.0
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func _step(w: World, view: ShadeViews, r: WorldReader, p: Vector2, n: int) -> void:
	for k in n:
		w.actors.set_pos(0, p)
		w.actors.hp[0] = LONG
		w.step(InputFrame.new())
		view.sync(r)
		view.advance(DT)


func test_the_dark_falls_over_lights_out_lifts_and_falls_again() -> void:
	var s := _fight()
	var w: World = s[0]
	var aid: int = s[1]
	var view := ShadeViews.new()
	add_child_autofree(view)
	view.set_process(false)
	var r := WorldReader.new(w)
	_step(w, view, r, Vector2(-1, -1), 2)
	assert_eq(view.lamps_shown(), 4, "four lanterns on the room's edge")
	assert_eq(view.lamps_lit(), 0, "v0.11.0 O4: out until stepped on")
	assert_almost_eq(view.dark_strength(), 0.0, 0.001, "the room lit before Lights Out")
	assert_false(view.dark_quad.visible)
	BossLab.start(w, w.actors.index_of(aid), &"lights_out")
	_step(w, view, r, Vector2(-1, -1), 120)
	assert_between(view.dark_strength(), 0.05, 0.95, "the dark ramping in as the light drains")
	_step(w, view, r, Vector2(-1, -1), 180)
	assert_almost_eq(view.dark_strength(), 1.0, 0.001, "dark")
	assert_true(view.dark_quad.visible)
	assert_eq(view.lights_used(), 1, "only your light cuts the dark (O4: the lanterns are out)")
	assert_lt(view.dark_priority(), 0, "the dark draws before every marker (markers always draw)")
	_step(w, view, r, Vector2(4.5, 0), 2)
	assert_eq(view.lamps_lit(), 1, "the east lantern lit as you step on it")
	assert_eq(view.lights_used(), 2)
	_step(w, view, r, Vector2(4.5, 0), 358)
	assert_eq(view.lamps_lit(), 1, "it stays lit while you stand on it")
	# NB4b (owner: "Dark comes and goes"): 9 s after it fell (step 781 here) the dark lifts with a short fade.
	_step(w, view, r, Vector2(4.5, 0), 118)
	assert_almost_eq(view.dark_strength(), 1.0, 0.001, "still dark just before 9 s")
	_step(w, view, r, Vector2(4.5, 0), 12)
	assert_false(bool(r.boss_light()["dark"]), "the sim's dark has lifted")
	assert_between(view.dark_strength(), 0.05, 0.95, "the dark fading out")
	assert_eq(view.lights_used(), 2, "the lit lantern's pool fades with it")
	_step(w, view, r, Vector2(4.5, 0), 24)
	assert_almost_eq(view.dark_strength(), 0.0, 0.001, "the room lit again within 0.4 s")
	assert_false(view.dark_quad.visible)
	# v0.11.0 O4 (owner Q10 a: "dark 9 s / light 4 s"): 4 s after it lifted the dark falls again, on its own.
	_step(w, view, r, Vector2(4.5, 0), 210)
	assert_true(bool(r.boss_light()["dark"]), "dark again 4 s after the lift")
	_step(w, view, r, Vector2(4.5, 0), 60)
	assert_almost_eq(view.dark_strength(), 1.0, 0.001, "drawn at full again")


func test_wisps_near_you_always_show_their_outline() -> void:
	var s := _fight()
	var w: World = s[0]
	var aid: int = s[1]
	var view := ShadeViews.new()
	add_child_autofree(view)
	view.set_process(false)
	var r := WorldReader.new(w)
	BossLab.start(w, w.actors.index_of(aid), &"wisp_bloom")
	var most := 0
	var low_most := 0
	for k in 150:
		ViewPrefs.effects_density = "low" if k % 2 == 1 else "high"
		_step(w, view, r, Vector2(-3, 0), 1)
		var near := 0
		for j in r.projectile_count():
			if (
				r.projectile_look(j) == "shade_wisp"
				and r.projectile_pos(j).distance_to(Vector2(-3, 0)) <= 4.0
			):
				near += 1
		assert_eq(view.outlined_wisps(), near, "every wisp within 4 m outlined (tick %d)" % k)
		most = maxi(most, near)
		if k % 2 == 1:
			low_most = maxi(low_most, view.outlined_wisps())
	assert_gt(most, 0, "the bloom reached you")
	assert_gt(low_most, 0, "Effects density Low keeps the outlines")
