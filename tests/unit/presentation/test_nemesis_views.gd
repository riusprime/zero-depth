extends GutTest
## v0.8.0 FB3 (owner F6; FINAL_BOSS.md F6): the Nemesis read in 3D, from the sim (EI-07). Its placeholder clips in the
## hero's motion vocabulary (run, dash, slash, shoot, cast, hit, death), each attack move playing its own; the run's
## weapon in its hand; its dash leaning in and leaving afterimages; a card's cast naming the card over its head with a
## sigil at its feet; a card's parts drawn on the ground (its swing, its lines, its blast) and struck in its own look on
## the sim's strike tick; its shots in its own fireball looks, never the hero's colours.

const DT := 1.0 / 60.0
const GUN_CARDS := [[&"gun_spread", 2], [&"shared_explosive", 3], [&"halo_shot", 1]]


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _avatar() -> NemesisAvatar:
	var a := NemesisAvatar.new()
	a.setup(Color("#1A1A22"))
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
	var rest := a.weapon.rotation
	NemesisLab.start(w, &"nemesis_combo")
	var most := 0.0
	for k in 70:
		w.step(InputFrame.new())
		a.sync(reader, i)
		a.advance(DT)
		most = maxf(most, a.weapon.rotation.distance_to(rest))
	assert_gt(most, 0.5, "the blade swings across")


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
		if w.final_fight.casts[n].card_id == &"shared_explosive":
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
	var info := reader.card_info(NemesisLab.card(w, &"shared_explosive"))
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
