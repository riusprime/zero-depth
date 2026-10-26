extends GutTest
## v0.9.0 NB4: The Lantern Shade's look. The owner's model (cut into parts by nb_prep.py; PLAN NB "Keep the empty
## hood") loads at the art list's 3.4 m, front turned to +X, each part one bone (the arms at the shoulders, the held
## lantern hanging from the right arm); it floats (a bob), its cloak sways, its lantern swings on its chain and flares
## for Lights Out and burns low in the dark; with the file missing a code stand-in of the same parts poses from the
## same inputs. ShadeViews draws, from the reader only, the dark (ramping in over Lights Out, drawn before every
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
	a.setup(Color("#1A1A22"), &"xray")
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


func test_the_model_loads_cut_into_its_parts_at_its_height() -> void:
	var m := BossModels.get_model(&"boss_lantern_shade")
	assert_false(m.is_empty(), "loads")
	var box: AABB = m["aabb"]
	assert_almost_eq(box.size.y, 3.4, 0.01, "3.4 m (the art list's)")
	var rig: BossRig = m["rig"]
	var names := []
	for b: Array in rig.bones:
		names.append(String(b[0]))
	names.sort()
	assert_eq(names, ["arm_l", "arm_r", "body", "hand_lantern"], "the empty hood: no head lanterns")
	assert_eq(rig.bones[0][0], &"body", "the body is the root")
	var arm_l: Vector3 = rig.bones[rig.index_of(&"arm_l")][2]
	var arm_r: Vector3 = rig.bones[rig.index_of(&"arm_r")][2]
	var lamp: Vector3 = rig.bones[rig.index_of(&"hand_lantern")][2]
	assert_lt(arm_l.z, -0.5, "the left arm on its left (-Z)")
	assert_gt(arm_r.z, 0.5, "the right arm on its right")
	assert_gt(lamp.z, 0.8, "the lantern in its right hand")
	assert_lt(lamp.y, arm_r.y, "hanging below the shoulder")


func test_it_floats_and_its_lantern_swings_flares_and_burns_low_in_the_dark() -> void:
	var a := _avatar()
	assert_not_null(a.imported, "the owner's model")
	var bobs := []
	for k in 6:
		_drive(a, {"state": WorldReader.STATE_MOVE, "dark": 0.0}, 20)
		bobs.append(a.bob_height())
	assert_gt(bobs.max() - bobs.min(), 0.03, "a slow floating bob")
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
	var swings := []
	for k in 8:
		_drive(
			a,
			{"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_SLAM_RING, "windup": 0.8},
			8
		)
		swings.append(a.lantern_swing())
	assert_gt(swings.max() - swings.min(), 0.05, "the lantern swings on its chain")


func test_the_stand_in_poses_without_the_file() -> void:
	BossModels.clear_cache()
	BossModels.dir = "res://nowhere/"
	var a := _avatar()
	assert_null(a.imported, "no file: the stand-in")
	assert_not_null(a.lantern.get_parent(), "with its lantern")
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


func test_the_dark_falls_over_lights_out_and_the_lanterns_burn() -> void:
	var s := _fight()
	var w: World = s[0]
	var aid: int = s[1]
	var view := ShadeViews.new()
	add_child_autofree(view)
	view.set_process(false)
	var r := WorldReader.new(w)
	_step(w, view, r, Vector2(-1, -1), 2)
	assert_eq(view.lamps_shown(), 4, "four lanterns on the room's edge")
	assert_eq(view.lamps_lit(), 4, "lit")
	assert_almost_eq(view.dark_strength(), 0.0, 0.001, "the room lit before Lights Out")
	assert_false(view.dark_quad.visible)
	BossLab.start(w, w.actors.index_of(aid), &"lights_out")
	_step(w, view, r, Vector2(-1, -1), 120)
	assert_between(view.dark_strength(), 0.05, 0.95, "the dark ramping in as the light drains")
	_step(w, view, r, Vector2(-1, -1), 180)
	assert_almost_eq(view.dark_strength(), 1.0, 0.001, "dark")
	assert_true(view.dark_quad.visible)
	assert_eq(view.lights_used(), 5, "your light and four lit lanterns cut the dark")
	assert_lt(view.dark_priority(), 0, "the dark draws before every marker (markers always draw)")
	_step(w, view, r, Vector2(-1, -1), 360)
	assert_eq(view.lamps_lit(), 0, "burnt out after 4 s")
	assert_eq(view.lights_used(), 1, "only your light")
	_step(w, view, r, Vector2(4.5, 0), 2)
	assert_eq(view.lamps_lit(), 1, "the east lantern relit as you pass")
	assert_eq(view.lights_used(), 2)
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
