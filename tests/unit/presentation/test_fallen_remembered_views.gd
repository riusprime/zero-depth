extends GutTest
## The Fallen remembering a boss the run killed, as the player sees it, each view built from WorldReader only, in the
## final arena with no source boss in the room (FallenLab): the ghost of that boss rising through the cast in its
## colours, the ring of its colour while the mechanic runs, and each mechanic's own views drawing it on The Fallen:
## the Time Wave (JudgeTimeViews' ring and orbs, AttackSlowHud, the orbs' hint arrows), the Riptide (TideDanceViews'
## strips inside the round floor), the quake pillars (StoneSpikeViews, the dash line through one, BossVulnerableViews'
## stun) and the ward (WardenWardViews' dome and lane, the shade, ChargeBurstViews' end circle). Nothing stays once
## a mechanic ends or the fight is over; the sounds borrow cues that exist.

const L := preload("res://tests/support/fallen_lab.gd")
const R := preload("res://src/sim/ai/boss_remembered.gd")
const SEED := 811
const DT := 1.0 / 60.0

var _w: World
var _r: WorldReader
var _fallen: FallenRememberedViews
var _time: JudgeTimeViews
var _slow: AttackSlowHud
var _tide: TideDanceViews
var _spikes: StoneSpikeViews
var _stun: BossVulnerableViews
var _ward: WardenWardViews
var _bursts: ChargeBurstViews


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _views(w: World) -> void:
	_w = w
	_r = WorldReader.new(w)
	_fallen = FallenRememberedViews.new()
	_time = JudgeTimeViews.new()
	_slow = AttackSlowHud.new()
	_tide = TideDanceViews.new()
	_spikes = StoneSpikeViews.new()
	_stun = BossVulnerableViews.new()
	_ward = WardenWardViews.new()
	_bursts = ChargeBurstViews.new()
	for v: Node in [_fallen, _time, _slow, _tide, _spikes, _stun, _ward, _bursts]:
		add_child_autofree(v)
		v.set_process(false)
	_sync()


func _sync() -> void:
	for v: Node in [_fallen, _time, _slow, _tide, _spikes, _stun, _ward, _bursts]:
		v.call(&"sync", _r)
	for v: Node in [_fallen, _time, _tide, _ward, _bursts]:
		v.call(&"advance", DT)
	_stun.advance()


func _step(n: int = 1) -> void:
	for k in n:
		_w.step(InputFrame.new())
	_sync()


## Makes `kind` due and steps into its cast, syncing the views each tick.
func _to_cast(kind: int) -> void:
	L.due(_w, kind)
	for k in 300:
		if _w.boss_fight.fl_stage == R.STAGE_CAST:
			break
		_step()
	assert_eq(_w.boss_fight.fl_stage, R.STAGE_CAST, "the cast begins")
	_step(10)


func _to_run() -> void:
	for k in 200:
		if _w.boss_fight.fl_stage == R.STAGE_RUN:
			break
		_step()
	assert_eq(_w.boss_fight.fl_stage, R.STAGE_RUN, "the mechanic runs")
	_step()


func _body_at() -> Vector2:
	return _r.actor_pos(L.body(_w))


func _assert_cast_of(source: StringName) -> void:
	assert_eq(_fallen.emblem_shown(), source, "the ghost of %s rises over it" % source)
	assert_eq(_fallen.emblem_tint(source), FallenLooks.colours(source)[0], "in its colour")
	assert_eq(_fallen.pillar_shown(), source, "its pillar of light, in that colour")


func _assert_runs_as(source: StringName) -> void:
	assert_eq(_fallen.emblem_shown(), &"", "the ghost is gone once the mechanic runs")
	assert_eq(_fallen.aura_shown(), source, "a ring of its colour at The Fallen's feet")


func test_every_source_has_a_ghost_and_colours() -> void:
	_views(L.world(SEED))
	assert_eq(_fallen.emblems_built(), 4, "a ghost for each boss it can remember")
	for source: StringName in WorldReader.FALLEN_SOURCES.values():
		assert_true(FallenLooks.COLOURS.has(source), "%s has colours" % source)
		assert_true(FallenLooks.MODELS.has(source), "%s has a ghost" % source)
	assert_true(_fallen.shade_shown() == false, "no shade before the ward")
	assert_true(FallenRememberedViews.emblem_alpha(0.5) > FallenRememberedViews.emblem_alpha(0.98))


func test_the_time_wave_on_the_fallen() -> void:
	_views(L.world(SEED, &"blade", [&"clockwork_judge"]))
	_to_cast(R.TIME)
	_assert_cast_of(&"clockwork_judge")
	_to_run()
	_assert_runs_as(&"clockwork_judge")
	assert_true(_time.wave_live(), "the gold ring runs out")
	var orbs := _r.boss_pickups()
	assert_eq(orbs.size(), 3)
	assert_eq(_time.orbs_shown(), 3, "the three hour orbs, each with its clock")
	for k in orbs.size():
		assert_almost_eq(
			SimPlane.to_sim(_time.orb_position(k)).distance_to(orbs[k]["centre"]), 0.0, 0.01
		)
	assert_eq(_time.orb_dial_radius(0), float(orbs[0]["radius"]), "the dial is the orb's radius")
	assert_true(_slow.visible, "the HUD's clock and pips, no words")
	assert_eq(_slow.pips(), 3)
	var hints := ObjectiveHints.new()
	add_child_autofree(hints)
	var centre := hints.get_viewport().get_visible_rect().size * 0.5
	hints.project = func(sim: Vector2) -> Vector2: return centre + sim * 1000.0
	hints.gate = func(_reason: StringName) -> bool: return true
	hints.sync(_r)
	assert_true(hints.showing(MechanicHints.JUDGE_ORB, ObjectiveHints.ARROW), "arrows to the orbs")
	for o: Dictionary in orbs:
		_w.actors.set_pos(0, o["centre"])
		_step()
	_w.actors.set_pos(0, _w.final_fight.home)
	_step()
	assert_eq(_w.boss_fight.fl_stage, R.STAGE_NONE, "every orb taken: it is over")
	assert_eq(_time.orbs_shown(), 0, "no orb left")
	assert_false(_slow.visible, "the weapon whole: the mark hides")
	assert_eq(_fallen.aura_shown(), &"", "the ring goes with it")


func test_the_riptide_on_the_round_floor() -> void:
	_views(L.world(SEED, &"blade", [&"tidecaller"]))
	_to_cast(R.RIPTIDE)
	_assert_cast_of(&"tidecaller")
	_to_run()
	_assert_runs_as(&"tidecaller")
	var d := _r.boss_dance()
	assert_eq(_tide.strips_shown(), 4, "the four strips")
	var room: Rect2 = _r.boss_fallen()["room"]
	for k in 4:
		var want: Rect2 = d["strips"][k]
		var got := _tide.strip_rect(k)
		assert_almost_eq(
			got.position.distance_to(want.position), 0.0, 0.01, "strip %d where it is" % k
		)
		assert_almost_eq(got.size.distance_to(want.size), 0.0, 0.01)
	var struck: Array = d["riptide"]["struck"]
	assert_eq(struck.size(), 3, "three struck, one dry")
	for k in 4:
		assert_eq(_tide.strip_struck(k), struck.has(k), "strip %d marked as the sim says" % k)
	var c: Array = _tide.clip()
	assert_almost_eq((c[0] as Vector2).distance_to(room.get_center()), 0.0, 0.01)
	assert_almost_eq(float(c[1]), room.size.x * 0.5, 0.01, "drawn inside the round floor")
	var walled := false
	for t in 400:
		_step()
		if _w.boss_fight.fl_stage != R.STAGE_RUN:
			break
		for k in 4:
			if not _tide.wall_shown(k):
				continue
			walled = true
			var crest := _tide.wall_crest(k)
			assert_lte(
				crest.distance_to(room.get_center()), float(c[1]) + 0.01, "the wall on the floor"
			)
	assert_true(walled, "the wall of water runs")
	for t in 900:
		if _w.boss_fight.fl_stage == R.STAGE_NONE:
			break
		_step()
	_step()
	assert_eq(_tide.strips_shown(), 0, "the strips go with it")
	assert_eq(float(_tide.clip()[1]), 0.0)


func test_the_wall_is_cut_to_the_round_floor() -> void:
	var inside := TideDanceViews.wall_chord(Vector2(0, 0), true, 4.0, Vector2.ZERO, 10.0)
	assert_eq(inside, Vector2(0, 4.0), "a wall well inside keeps its width")
	var edge := TideDanceViews.wall_chord(Vector2(8, 6), true, 4.0, Vector2.ZERO, 10.0)
	assert_almost_eq(edge.y, 6.0 - 4.0, 0.001, "near the rim it is cut to the circle")
	assert_eq(TideDanceViews.wall_chord(Vector2(11, 0), true, 4.0, Vector2.ZERO, 10.0).y, 0.0)
	assert_eq(
		TideDanceViews.wall_chord(Vector2(30, 0), true, 4.0, Vector2.ZERO, 0.0).y, 4.0, "no clip"
	)


func _pillar_way(c: Vector2, h: float, need: float) -> Vector2:
	for k in 16:
		var d := Kin.dir(k * 256)
		if (
			EnemyAi.clear_run(_w, c + d * (h + 0.6), k * 256, need, 0.5) >= need - 0.01
			and (
				EnemyAi.clear_run(_w, c - d * (h + 0.6), (k * 256 + 2048) & 4095, need, 0.5)
				>= need - 0.01
			)
		):
			return d
	return Vector2.ZERO


func test_the_quake_pillars_the_dash_through_one_and_the_stun() -> void:
	_views(L.world(SEED, &"blade", [&"gatekeeper"], false))
	_to_cast(R.QUAKE)
	_assert_cast_of(&"gatekeeper")
	_to_run()
	_assert_runs_as(&"gatekeeper")
	assert_eq(_spikes.quake_count(), 3, "the three pillars, their rings")
	var i := L.body(_w)
	var q := BossAi.table_of(_w, i).quake
	var mine := BossQuake.pillars_of(_w, _w.actors.ids[i])
	var c0 := BossQuake.center(_w.bosses, mine[0])
	var way := _pillar_way(c0, q.half_m, 4.0)
	assert_ne(way, Vector2.ZERO, "room both sides of a pillar")
	var hero := c0 - way * (q.half_m + _w.player.radius_m + 1.2)
	_w.actors.set_pos(i, c0 + way * (q.half_m + _w.actors.radius[i] + 2.0))
	_w.actors.set_pos(0, hero)
	_w.boss_fight.fl_dash_at = _w.tick
	var lined := false
	var hot := false
	var stunned := false
	for k in 160:
		_w.actors.set_pos(0, hero)
		_w.actors.hp[0] = _w.actors.max_hp[0]
		_step()
		var dash: Dictionary = _r.boss_fallen()["pillar_dash"]
		if not dash.is_empty():
			lined = lined or _fallen.line_shown()
			hot = hot or (bool(dash["through"]) and _fallen.line_hot())
		if _r.boss_stunned(i):
			stunned = true
			break
	assert_true(lined, "the dash's line shows while the pillars stand")
	assert_true(hot, "white-hot where it meets the pillar")
	assert_true(stunned, "the dash shatters the pillar and stuns it")
	assert_eq(_spikes.quake_count(), 2, "one shattered")
	assert_eq(_stun.shown(), 1, "the stunned read on The Fallen, no words")
	assert_false(_fallen.line_shown(), "no line while it is stunned")


func test_the_ward_the_shade_and_its_lane() -> void:
	var w := L.world(SEED, &"blade", [&"twin_wardens"], false)
	var i := L.body(w)
	w.actors.set_pos(i, w.final_fight.home + Vector2(0.0, 6.0))
	w.actors.set_pos(0, w.final_fight.home + Vector2(4.0, 0.0))
	_views(w)
	_to_cast(R.WARD)
	_assert_cast_of(&"twin_wardens")
	_to_run()
	assert_true(_ward.full_shown(), "the whole ward on The Fallen")
	assert_almost_eq(_ward.full_at().distance_to(_body_at()), 0.0, 0.01)
	assert_eq(_fallen.aura_shown(), &"", "the dome stands instead of the ring")
	var sh: Dictionary = _r.boss_fallen()["shade"]
	assert_true(_fallen.shade_shown(), "the amber Warden's shade")
	assert_almost_eq(_fallen.shade_position().distance_to(sh["position"]), 0.0, 0.01)
	assert_true(_ward.lane_shown(), "its charge lane")
	assert_false(_ward.lane_breaks(), "off The Fallen: not white-hot")
	var circles := _bursts.circles()
	assert_eq(circles.size(), 1, "the end circle")
	assert_almost_eq((circles[0][0] as Vector2).distance_to(sh["end"]), 0.0, 0.01)
	# The hero behind The Fallen on the shade's line: the lane crosses it
	var shade := Vector2(sh["position"])
	var line := (_body_at() - shade).normalized()
	var hero := _body_at() + line * 4.0
	var hot := false
	var broke := false
	for k in 300:
		_w.actors.set_pos(0, hero)
		_step()
		hot = hot or _ward.lane_breaks()
		if _w.boss_fight.fl_ward == 0:
			broke = true
			break
	assert_true(hot, "the lane turns white-hot once it would cross The Fallen")
	assert_true(broke, "the charge breaks the ward")
	_step()
	assert_false(_ward.full_shown(), "the dome is gone")
	assert_false(_fallen.shade_shown(), "and the shade")
	assert_eq(_stun.shown(), 1, "the stunned read on it")


func test_nothing_stays_after_the_fight() -> void:
	for kind in [R.TIME, R.RIPTIDE, R.QUAKE, R.WARD]:
		_views(L.world(SEED, &"blade", [R.SOURCES[kind]]))
		_to_cast(kind)
		_to_run()
		FinalLab.end_segment(_w)
		_step(2)
		assert_eq(_fallen.emblem_shown(), &"", "kind %d: no ghost" % kind)
		assert_eq(_fallen.aura_shown(), &"", "no ring")
		assert_false(_fallen.shade_shown(), "no shade")
		assert_false(_fallen.line_shown(), "no line")
		assert_eq(_time.orbs_shown(), 0, "no orb")
		assert_eq(_tide.strips_shown(), 0, "no strip")
		assert_eq(_spikes.quake_count(), 0, "no pillar")
		assert_false(_ward.full_shown(), "no ward")
		assert_false(_slow.visible, "no mark")


func test_reduced_motion_builds_and_draws() -> void:
	ViewPrefs.reduced_motion = true
	_views(L.world(SEED, &"blade", [&"twin_wardens"]))
	_to_cast(R.WARD)
	_assert_cast_of(&"twin_wardens")
	_to_run()
	assert_true(_fallen.shade_shown(), "the shade, still")


func test_the_sounds_borrow_cues_that_exist() -> void:
	var out := []
	for kind in [R.TIME, R.RIPTIDE, R.QUAKE, R.WARD]:
		var e := SimEvent.new()
		e.kind = SimEvent.Kind.STATUS_APPLY
		e.effect_id = WorldReader.EFFECT_FALLEN_CAST
		e.amount_applied = kind
		assert_true(FallenCues.add(e, out), "the cast of kind %d sounds" % kind)
	assert_eq(out.size(), 4)
	assert_eq(out[0][0], &"boss_telegraph_clockwork_judge", "the Judge's own clock")
	for id: StringName in FallenCues.CUES:
		var e := SimEvent.new()
		e.effect_id = id
		assert_true(FallenCues.add(e, out), "%s sounds" % id)
	for row: Array in out:
		assert_true(
			ResourceLoader.exists("res://data/audio/cues/%s.tres" % row[0]), "cue %s" % row[0]
		)
	var other := SimEvent.new()
	other.effect_id = WorldReader.EFFECT_FALLEN_END
	assert_false(FallenCues.add(other, []), "its end has no sound")
