extends GutTest
## The Clockwork Judge's time mechanics as the player sees them, each view built from WorldReader only:
## JudgeTimeViews (the cast, the wave's ring, the hour orbs and their clocks, the stopped gears on their walls'
## footprints, the slow fields), JudgeRewindViews (the pale copy, the Bell's closing ring and line, the throw's
## flashes), AttackSlowHud (the loss and the pips won back), the hint arrows on the orbs, the borrowed sounds and
## the cast's clip. Nothing stays once the Judge is gone.

const DT := 1.0 / 60.0


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## A hushed fight in `phase` (the Judge at (6, 0), standing still). Returns [world, the Judge's id, a reader].
func _fight(phase: int, hero_at := Vector2(-6, 0), boss_at := Vector2(6, 0)) -> Array:
	var s := JudgeLab.fight(hero_at, boss_at)
	var w: World = s[0]
	JudgeLab.hush(w, s[1])
	JudgeLab.set_phase(w, s[1], phase)
	BossAi.table_of(w, _i(w, s[1])).speed = 0.0
	w.step(InputFrame.new())
	return [w, s[1], WorldReader.new(w)]


## The Time Wave cast and landed; the Bell and the fields kept out of the way.
func _wave(w: World, aid: int) -> void:
	w.boss_fight.time_bell_due = 1 << 29
	w.boss_fight.time_field_due = 1 << 29
	BossLab.start(w, _i(w, aid), &"time_wave")
	assert_not_null(JudgeLab.until_effect(w, &"time_wave", 95), "the wave lands")


func _time_view() -> JudgeTimeViews:
	var v := JudgeTimeViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func _rewind_view() -> JudgeRewindViews:
	var v := JudgeRewindViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func _kill(w: World, aid: int) -> void:
	var me := w.actors.ids[0]
	for k in 1200:  # through its gates: a hit never takes it past one
		var i := _i(w, aid)
		if i < 0:
			break
		Damage.hit(w, i, 1 << 24, me, me, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
		w.step(InputFrame.new())
	assert_lt(_i(w, aid), 0, "the Judge is gone")


func test_the_cast_shows_then_the_ring_runs_out_and_the_orbs_lie() -> void:
	var s := _fight(0)
	var w: World = s[0]
	var r: WorldReader = s[2]
	var view := _time_view()
	view.sync(r)
	view.advance(DT)
	assert_false(view.cast_shown(), "no cast yet")
	assert_eq(view.orbs_shown(), 0)
	w.boss_fight.time_bell_due = 1 << 29
	w.boss_fight.time_field_due = 1 << 29
	BossLab.start(w, _i(w, s[1]), &"time_wave")
	CombatLab.idle(w, 45)
	view.sync(r)
	view.advance(DT)
	assert_true(view.cast_shown(), "the dial and the closing ring through the cast")
	assert_false(view.wave_live(), "no ring before it lands")
	assert_not_null(JudgeLab.until_effect(w, &"time_wave", 60), "it lands")
	view.sync(r)
	view.advance(DT)
	assert_false(view.cast_shown(), "the cast is over")
	assert_true(view.wave_live(), "the ring leaves the Judge")
	var r0 := view.wave_radius()
	for k in 20:
		view.advance(DT)
	assert_gt(view.wave_radius(), r0 + 8.0, "running out across the room")
	for k in 60:
		view.advance(DT)
	assert_false(view.wave_live(), "and gone")
	var rows := r.boss_pickups()
	assert_eq(rows.size(), 3)
	assert_eq(view.orbs_shown(), 3, "an orb view per orb")
	for k in rows.size():
		assert_eq(view.orb_position(k), SimPlane.to_3d(rows[k]["centre"]), "orb %d on its spot" % k)
		assert_almost_eq(
			view.orb_dial_radius(k), float(rows[k]["radius"]), 0.001, "its dial the disc to touch"
		)


func test_an_orb_goes_when_taken_and_a_late_one_runs_down() -> void:
	var s := _fight(2)
	var w: World = s[0]
	var r: WorldReader = s[2]
	var view := _time_view()
	_wave(w, s[1])
	view.sync(r)
	view.advance(DT)
	assert_eq(view.orbs_shown(), 3)
	assert_almost_eq(view.orb_hand_turn(0), 0.0, 0.05, "a fresh orb's hand at twelve")
	CombatLab.idle(w, 300)
	view.sync(r)
	view.advance(DT)
	assert_almost_eq(view.orb_hand_turn(0), PI, 0.1, "half its 10 s gone: the hand half-way round")
	w.actors.set_pos(0, r.boss_pickups()[0]["centre"])
	w.step(InputFrame.new())
	view.sync(r)
	view.advance(DT)
	assert_eq(view.orbs_shown(), 2, "the one taken is gone")
	w.actors.set_pos(0, Vector2(-11, 11))
	CombatLab.idle(w, 320)
	view.sync(r)
	view.advance(DT)
	assert_eq(r.boss_pickups().size(), 0, "the others ran out")
	assert_eq(view.orbs_shown(), 0)


func test_each_gear_stands_on_its_walls_footprint_rises_and_sinks() -> void:
	var s := _fight(1)
	var w: World = s[0]
	var r: WorldReader = s[2]
	var view := _time_view()
	_wave(w, s[1])
	view.sync(r)
	view.advance(DT)
	var gears: Array = r.boss_time()["gears"]
	assert_between(gears.size(), 3, 4, "the walls stand")
	assert_eq(view.gears_shown(), gears.size(), "a cog per wall")
	for k in gears.size():
		var g: Dictionary = gears[k]
		var fp := view.gear_footprint(k)
		var half: Vector2 = g["half"]
		assert_almost_eq(fp["centre"], g["centre"], Vector2(0.001, 0.001), "gear %d centred" % k)
		assert_almost_eq(fp["half"], half, Vector2(0.001, 0.001), "its strip the wall's size")
		assert_almost_eq(float(fp["yaw"]), SimPlane.yaw_of(int(g["angle"])), 0.001, "along it")
		assert_lt(float(fp["raised"]), half.x * 0.3, "just placed: still rising")
	CombatLab.idle(w, 60)
	view.sync(r)
	view.advance(DT)
	var hx: float = gears[0]["half"].x
	var top := hx * 0.6 / sqrt(0.84)
	assert_almost_eq(
		float(view.gear_footprint(0)["raised"]), top, 0.001, "risen: lower than the hero"
	)
	assert_lt(top, 1.7)
	for k in gears.size():
		var half: Vector2 = gears[k]["half"]
		assert_almost_eq(
			view.gear_footprint(k)["wheel"],
			half,
			Vector2(0.001, 0.001),
			"the cog as long and as thick"
		)
	CombatLab.idle(w, int(r.boss_time()["gears"][0]["left"]) - 9)
	view.sync(r)
	view.advance(DT)
	assert_eq(int(r.boss_time()["gears"][0]["left"]), 9)
	assert_lt(float(view.gear_footprint(0)["raised"]), hx * 0.5, "sinking in its last moments")
	CombatLab.idle(w, 10)
	view.sync(r)
	view.advance(DT)
	assert_eq(view.gears_shown(), 0, "gone with the wall")


func test_a_slow_field_is_its_radius_and_fades_with_its_life() -> void:
	var s := _fight(1)
	var w: World = s[0]
	var r: WorldReader = s[2]
	var view := _time_view()
	w.boss_fight.time_bell_due = 1 << 29
	w.boss_fight.time_field_due = 1 << 29
	BossShotFields.place(w, s[1], BossAi.table_of(w, _i(w, s[1])).time.field, Vector2(0, 0))
	view.sync(r)
	view.advance(DT)
	assert_eq(view.fields_shown(), 1)
	assert_almost_eq(view.field_radius(0), 1.75, 0.001, "drawn at the radius that slows")
	assert_lt(view.field_alpha(0), 0.1, "fading in")
	CombatLab.idle(w, 30)
	view.sync(r)
	view.advance(DT)
	var full := view.field_alpha(0)
	assert_gt(full, 0.6, "there")
	CombatLab.idle(w, int(r.boss_shot_fields()[0]["left"]) - 20)
	view.sync(r)
	view.advance(DT)
	assert_lt(view.field_alpha(0), full * 0.5, "fading out over its last second")
	CombatLab.idle(w, 21)
	view.sync(r)
	view.advance(DT)
	assert_eq(view.fields_shown(), 0)


func test_reduced_motion_stills_the_gears_roll() -> void:
	var s := _fight(1)
	var w: World = s[0]
	var view := _time_view()
	_wave(w, s[1])
	ViewPrefs.reduced_motion = true
	view.sync(s[2])
	view.advance(DT)
	assert_gt(view.gears_shown(), 0)
	assert_eq(view._gear_wheels[0].rotation.z, 0.0, "it rises without turning")


func test_nothing_of_the_wave_stays_after_the_judge() -> void:
	var s := _fight(1)
	var w: World = s[0]
	var r: WorldReader = s[2]
	var view := _time_view()
	_wave(w, s[1])
	BossShotFields.place(w, s[1], BossAi.table_of(w, _i(w, s[1])).time.field, Vector2(0, 0))
	view.sync(r)
	view.advance(DT)
	assert_gt(view.orbs_shown() + view.gears_shown() + view.fields_shown(), 6)
	_kill(w, s[1])
	view.sync(r)
	for k in 70:
		view.advance(DT)
	assert_eq(
		[view.orbs_shown(), view.gears_shown(), view.fields_shown(), view.cast_shown()],
		[0, 0, 0, false],
		"the orbs, the gears, the fields and the cast"
	)
	assert_false(view.wave_live())
	assert_eq(view.hold.count(), 0, "no pack effect held")
	assert_true(view.quiet, "and the view rests")


func _line(tick: int) -> Vector2:
	return Vector2(-10.0 + 0.01 * tick, -8.0)


func _walk_line(w: World, n: int) -> void:
	for k in n:
		w.actors.set_pos(0, _line(w.tick))
		w.step(InputFrame.new())


func test_the_pale_copy_follows_and_the_bell_closes_on_it() -> void:
	var s := _fight(0, Vector2(-10, -8), Vector2(6, 6))
	var w: World = s[0]
	var aid: int = s[1]
	var r: WorldReader = s[2]
	var view := _rewind_view()
	_walk_line(w, 300)
	view.sync(r)
	view.advance(DT)
	assert_false(view.copy_shown(), "no copy before the Rewind")
	JudgeLab.set_phase(w, aid, 1)
	w.boss_fight.time_field_due = 1 << 29
	_walk_line(w, 1)
	view.sync(r)
	view.advance(DT)
	assert_true(view.copy_shown(), "the Rewind is on: the copy stands")
	var copy: Vector2 = r.boss_time()["copy"]
	assert_almost_eq(view.copy_position(), copy, Vector2(0.001, 0.001), "on the copy's point")
	assert_false(view.bell_shown(), "no bell yet")
	_walk_line(w, 90)
	view.sync(r)
	for k in 60:
		view.advance(DT)
	copy = r.boss_time()["copy"]
	assert_gt(copy.distance_to(w.player_pos()), 1.0, "it trails the hero")
	assert_almost_eq(view.copy_position(), copy, Vector2(0.01, 0.01), "and the figure follows it")
	w.boss_fight.time_bell_due = w.tick
	_walk_line(w, 2)
	assert_gte(int(r.boss_time()["bell"]), 0, "the Bell is cast")
	view.sync(r)
	view.advance(DT)
	assert_true(view.bell_shown(), "its ring round the copy")
	var radius := view.bell_radius()
	var link := view.link_alpha()
	var body := view.copy_alpha()
	_walk_line(w, 100)
	view.sync(r)
	view.advance(DT)
	assert_lt(view.bell_radius(), radius - 2.0, "closing as the toll nears")
	assert_gt(view.link_alpha(), link + 0.3, "the line to the copy brightening")
	assert_gt(view.copy_alpha(), body, "the copy too")
	for k in 30:
		_walk_line(w, 1)
		if not JudgeLab.effects(w, &"judge_rewind").is_empty():
			break
	assert_eq(JudgeLab.effects(w, &"judge_rewind").size(), 1, "the toll throws the hero")
	view.sync(r)
	view.advance(DT)
	assert_eq(view.flashes_shown(), 2, "a flash where the hero was and where it landed")
	assert_true(view.streak_shown(), "the streak between them")
	assert_false(view.bell_shown(), "the ring is done")
	for k in 40:
		view.advance(DT)
	assert_eq(view.flashes_shown(), 0)
	assert_false(view.streak_shown())
	_kill(w, aid)
	view.sync(r)
	for k in 40:
		view.advance(DT)
	assert_false(view.copy_shown(), "no copy once the Judge is gone")
	assert_true(view.quiet)


func test_the_judges_return_flashes_at_both_ends() -> void:
	var s := _fight(0)
	var w: World = s[0]
	var aid: int = s[1]
	var view := _rewind_view()
	view.sync(s[2])
	view.advance(DT)
	assert_eq(view.flashes_shown(), 0)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, aid, aid, aid, Vector2(-6, 0))
	e.effect_id = &"judge_return"
	ViewPrefs.reduced_motion = true
	view.sync(s[2])
	view.advance(DT)
	assert_eq(view.flashes_shown(), 2, "where it stood and where it stands")
	assert_false(view.streak_shown(), "no streak with reduced motion")


func test_the_hud_shows_the_loss_and_a_pip_per_orb_won_back() -> void:
	var s := _fight(0)
	var w: World = s[0]
	var r: WorldReader = s[2]
	var hud := AttackSlowHud.new()
	add_child_autofree(hud)
	hud.sync(r)
	assert_false(hud.visible, "nothing taken: nothing shown")
	_wave(w, s[1])
	hud.sync(r)
	assert_true(hud.visible)
	assert_eq([hud.percent(), hud.pips(), hud.pips_won()], [75, 3, 0], "75 % lost, three hours")
	assert_string_contains(hud.line(), "75")
	assert_ne(hud.line(), "HUD_ATTACK_SLOW", "the line is translated")
	for n in 3:
		w.actors.set_pos(0, r.boss_pickups()[0]["centre"])
		w.step(InputFrame.new())
		hud.sync(r)
		if n < 2:
			assert_eq([hud.percent(), hud.pips_won()], [75 - 25 * (n + 1), n + 1], "an orb back")
	assert_eq(r.boss_attack_slow(), 0)
	assert_false(hud.visible, "whole again: it hides")
	assert_eq(hud.pips(), 0)


func test_the_orbs_carry_hint_arrows_without_a_line() -> void:
	var s := _fight(0)
	var w: World = s[0]
	var r: WorldReader = s[2]
	_wave(w, s[1])
	var hints := ObjectiveHints.new()
	add_child_autofree(hints)
	var centre := hints.get_viewport().get_visible_rect().size * 0.5
	hints.project = func(sim: Vector2) -> Vector2: return centre + sim * 10.0
	hints.gate = func(_reason: StringName) -> bool: return true
	hints.sync(r)
	var orb := MechanicHints.JUDGE_ORB
	assert_eq(hints.shown().size(), 3, "one per orb")
	assert_true(hints.showing(orb, ObjectiveHints.PING), "on screen")
	assert_true(orb in ObjectiveHints.DOWN_ARROW, "drawn as the pillars' small arrow above it")
	assert_eq(hints.line(orb), "", "no line of text")
	hints.project = func(sim: Vector2) -> Vector2: return centre + sim * 1000.0
	hints.sync(r)
	assert_true(hints.showing(orb, ObjectiveHints.ARROW), "off screen: an arrow at the edge")
	assert_false(orb in MechanicHints.ALWAYS, "shown the first runs that meet it")


func test_the_sounds_borrow_cues_that_exist() -> void:
	var ids := [JudgeTimeCues.ORB_TAKEN]
	for effect: StringName in JudgeTimeCues.CUES:
		var e := SimEvent.new()
		e.effect_id = effect
		e.pos = Vector2(3, 4)
		var out := []
		assert_true(JudgeTimeCues.add(e, out), "%s has a cue" % effect)
		assert_eq(out.size(), 1)
		ids.append(out[0][0])
	for id: StringName in ids:
		assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % id), "cue %s" % id)
	var other := SimEvent.new()
	other.effect_id = &"time_field"
	assert_false(JudgeTimeCues.add(other, []), "a slow field has no sound")


func test_the_cast_plays_the_files_spread() -> void:
	var a := ClockworkJudgeAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	assert_true(ClockworkJudgeClips.library().has(&"time_wave"), "a clip for the move")
	assert_eq(
		BossAnimator.clip_name_for(WorldReader.MOVE_TIME_WAVE, false, a.animator.clips),
		&"time_wave"
	)
	assert_true(a.animator.owner_has(&"time_wave"), "it plays the file's animation")


func test_the_pack_rows_name_the_owners_effect() -> void:
	var def := PackFx.shared_def()
	var k := def.row(JudgeTimeViews.ORB_ID)
	assert_gte(k, 0)
	assert_string_ends_with(def.scenes[k], "basic_area/basic_area_vfx_04.tscn", "Basic Area 04")
	for id: StringName in [
		JudgeTimeViews.FIELD_ID, JudgeTimeViews.CAST_ID, JudgeTimeViews.PULSE_ID
	]:
		assert_gte(def.row(id), 0, "%s is in the table" % id)


## The middle and the width of a square's drawn edge (world x and z).
func _square_box(n: Node3D) -> Rect2:
	var bb: AABB = ((n.get_node("Edge") as MeshInstance3D).mesh as ImmediateMesh).get_aabb()
	return Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)


## A world with the Rewind on and the Bell cast (its unlocked square on the copy). Returns [world, id, reader, view].
func _bell_cast() -> Array:
	var s := _fight(0, Vector2(-10, -8), Vector2(6, 6))
	var w: World = s[0]
	var view := _rewind_view()
	JudgeLab.set_phase(w, s[1], 1)
	w.boss_fight.time_field_due = 1 << 29
	_walk_line(w, 100)
	w.boss_fight.time_bell_due = w.tick
	_walk_line(w, 2)
	assert_gte(int(s[2].boss_time()["bell"]), 0, "the Bell is cast")
	return [w, s[1], s[2], view]


func test_a_bell_square_is_drawn_where_the_sim_puts_it_and_follows_the_copy() -> void:
	var c := _bell_cast()
	var w: World = c[0]
	var r: WorldReader = c[2]
	var view: JudgeRewindViews = c[3]
	view.sync(r)
	var squares: Array = r.boss_time()["bell_squares"]
	assert_eq(squares.size(), 1, "one toll pending: one square")
	assert_false(squares[0]["locked"], "it follows the copy")
	var nodes := view._squares.extra_nodes()
	assert_eq(nodes.size(), 1, "one view")
	var box := _square_box(nodes[0])
	var at := SimPlane.to_3d(squares[0]["center"])
	var half := float(squares[0]["half"])
	assert_almost_eq(box.get_center().x, at.x, 0.2, "at its centre")
	assert_almost_eq(box.get_center().y, at.z, 0.2)
	assert_almost_eq(box.size.x, half * 2.0, 0.3, "its size")
	for k in w.boss_fight.time_px.size():  # the hero's past moves, and the copy with it
		w.boss_fight.time_px[k] += 3.0
	view.sync(r)
	var moved: Vector2 = r.boss_time()["bell_squares"][0]["center"]
	assert_gt(moved.distance_to(squares[0]["center"]), 1.0, "the copy moved")
	box = _square_box(view._squares.extra_nodes()[0])
	assert_almost_eq(box.get_center().x, SimPlane.to_3d(moved).x, 0.2, "the view followed")
	assert_almost_eq(box.get_center().y, SimPlane.to_3d(moved).z, 0.2)


func test_a_locked_bell_square_stays_and_two_squares_are_two_views() -> void:
	var c := _bell_cast()
	var w: World = c[0]
	var r: WorldReader = c[2]
	var view: JudgeRewindViews = c[3]
	var held := Vector2(2.0, -3.0)
	w.boss_fight.time_bv_at = w.tick + 200
	w.boss_fight.time_bv_x = held.x
	w.boss_fight.time_bv_y = held.y
	view.sync(r)
	var squares: Array = r.boss_time()["bell_squares"]
	assert_eq(squares.size(), 2, "the locked one and the next toll's")
	assert_true(squares[0]["locked"], "the locked one first")
	assert_eq(view._squares.extra_nodes().size(), 2, "two views")
	_walk_line(w, 30)
	view.sync(r)
	var box := _square_box(view._squares.extra_nodes()[0])
	assert_almost_eq(box.get_center().x, SimPlane.to_3d(held).x, 0.2, "the locked square stays")
	assert_almost_eq(box.get_center().y, SimPlane.to_3d(held).z, 0.2)


func test_a_bell_square_goes_when_the_reader_has_none_and_its_drop_strikes() -> void:
	var c := _bell_cast()
	var w: World = c[0]
	var r: WorldReader = c[2]
	var view: JudgeRewindViews = c[3]
	var strikes := BossStrikeViews.new()
	add_child_autofree(strikes)
	strikes.set_process(false)
	view.sync(r)
	strikes.sync(r)
	assert_eq(view._squares.extra_nodes().size(), 1)
	assert_eq(strikes.strike_count(), 0, "nothing strikes yet")
	var dropped: SimEvent = null
	for k in 400:
		_walk_line(w, 1)
		view.sync(r)
		strikes.sync(r)
		dropped = JudgeLab.effects(w, &"judge_bell_verdict").pop_back()
		if dropped != null:
			break
	assert_not_null(dropped, "the Bell's Verdict drops")
	assert_eq(strikes.strike_count(), 1, "it strikes its square as the Judge's Verdict does")
	assert_eq(strikes.strikes()[0][0], &"cj_verdict")
	assert_eq(strikes.strikes()[0][1], &"beam")
	w.boss_fight.time_bell_at = -1
	w.boss_fight.time_bv_at = -1
	view.sync(r)
	assert_eq(view._squares.extra_nodes().size(), 0, "no square, no view")
