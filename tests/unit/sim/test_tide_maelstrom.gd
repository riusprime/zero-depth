extends GutTest
## The Tidecaller's Maelstrom (BossMaelstrom), in TideLab's walled 24 m room: the drag round and in, the eye and its
## throw, and the Tidecaller walking to the room's centre and holding it. The rest of the dance: test_tide_dance.gd.

const S := EnemyAi.State
const TICK := 1.0 / 60.0
const NEVER := 9


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _fx(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	return JudgeLab.effects(w, effect, seq)


func _state(w: World) -> Dictionary:
	return WorldReader.new(w).boss_dance()


## Steps `n` ticks, the hero idle and refilled each tick. Returns the HP it lost.
func _idle(w: World, n: int) -> int:
	var lost := 0
	for k in n:
		w.step(InputFrame.new())
		lost += TideLab.take_lost(w)
	return lost


## A hushed, still Tidecaller in a corner, in phase index `phase`, with only the named parts of its dance on.
func _only(hero_at: Vector2, phase: int, parts: Array, seed_value: int = 11) -> Array:
	var s := TideLab.fight(hero_at, Vector2(-9.0, 9.0), seed_value)
	var w: World = s[0]
	TideLab.hush(w, s[1])
	var d := TideLab.dance(w, s[1])
	if not parts.has("riptide"):
		d.rip_phase = NEVER
	if not parts.has("high_tide"):
		d.ht_phase = NEVER
	if not parts.has("maelstrom"):
		d.mael_phase = NEVER
	TideLab.set_phase(w, s[1], phase)
	return s


# --- content --------------------------------------------------------------------------------------------------

# --- the Maelstrom ----------------------------------------------------------------------------------------------


func _whirl(hero_at: Vector2, boss_at := Vector2.ZERO, seed_value: int = 11) -> Array:
	var s := TideLab.fight(hero_at, boss_at, seed_value)
	var w: World = s[0]
	TideLab.hush(w, s[1])
	var d := TideLab.dance(w, s[1])
	d.rip_phase = NEVER
	d.ht_phase = NEVER
	TideLab.set_phase(w, s[1], 2)
	return s


func test_the_maelstrom_carries_the_hero_round_and_in() -> void:
	var s := _whirl(Vector2(8, 0))
	var w: World = s[0]
	w.step(InputFrame.new())
	var begun := _fx(w, BossMaelstrom.BEGIN)
	assert_eq(begun.size(), 1, "it begins with the phase")
	var spin: int = begun[0].amount
	assert_true(spin == 1 or spin == -1)
	var run := w.player.move_speed
	var at := w.player_pos()
	w.step(InputFrame.new())
	var moved := w.player_pos() - at
	# The line to the boss is -x here, so its perpendicular (-y, x) is -y.
	assert_almost_eq(moved.x, -run * 0.25, 0.001, "25 % of its run speed toward the boss")
	assert_almost_eq(moved.y, -run * 0.45 * spin, 0.001, "45 % round it")
	var st: Dictionary = _state(w)["maelstrom"]
	assert_eq(st["spin"], spin)
	assert_almost_eq(float(st["around"]), 2.7, 0.001)
	assert_almost_eq(float(st["inward"]), 1.5, 0.001)
	assert_almost_eq(float(st["eye"]), 3.1, 0.001, "1.5 m from its 1.6 m body")
	# Round the boss one way for the rest of the fight: the turn never changes sign.
	var turn := 0.0
	for k in 240:
		var a := w.player_pos()
		w.step(InputFrame.make(Vector2i(127, 0) if a.x > 0.0 else Vector2i(-127, 0), 0, 300, 0, 0))
		TideLab.take_lost(w)
		var b := w.player_pos()
		if k % 20 == 0 and a.length() > 3.5:
			var cross := a.x * b.y - a.y * b.x
			assert_true(cross * turn >= 0.0, "one way")
			turn = cross if cross != 0.0 else turn
	assert_eq(_fx(w, BossMaelstrom.BEGIN).size(), 1, "one whirlpool, one way")
	assert_eq(w.boss_fight.dance_spin, spin)


func test_both_ways_come_up_over_seeds() -> void:
	var seen := {}
	for sv in 40:
		var s := _whirl(Vector2(8, 0), Vector2.ZERO, sv + 1)
		(s[0] as World).step(InputFrame.new())
		seen[(s[0] as World).boss_fight.dance_spin] = true
	assert_eq(seen.size(), 2)
	assert_true(seen.has(1) and seen.has(-1))


func test_the_eye_takes_40_percent_once_and_throws_the_hero_out() -> void:
	var boss := Vector2(-8, 0)
	var s := _whirl(boss + Vector2(2.6, 0), boss)
	var w: World = s[0]
	var cost := TideLab.LONG * 400 / 1000
	w.step(InputFrame.new())
	var hits := _fx(w, BossMaelstrom.THROW)
	assert_eq(hits.size(), 1, "within 1.5 m of its edge")
	assert_eq(hits[0].amount, cost, "40 % of max HP")
	assert_eq(TideLab.take_lost(w), cost)
	w.actors.invuln[0] = 0
	var more := 0
	for k in 60:  # The throw's 30 ticks (the hit's hit-stop freezes a few steps first)
		if int(_state(w)["maelstrom"]["thrown"]) == 0:
			break
		more += _idle(w, 1)
	assert_eq(more, 0, "once")
	assert_almost_eq(w.player_pos().distance_to(boss), 12.6, 0.05, "thrown 10 m straight out")
	assert_almost_eq(w.player_pos().y, 0.0, 0.01, "the whirlpool does not carry it meanwhile")
	# Back in the eye: it leaves the hero alone until 3 s after the hit.
	for k in 400:
		w.actors.set_pos(0, boss + Vector2(2.6, 0))
		w.step(InputFrame.new())
		TideLab.take_lost(w)
		w.actors.invuln[0] = 0
		if _fx(w, BossMaelstrom.THROW).size() > 1:
			break
	hits = _fx(w, BossMaelstrom.THROW)
	assert_eq(hits.size(), 2)
	assert_eq(hits[1].tick - hits[0].tick, 180, "a 3 s grace")


func test_the_throw_never_puts_the_hero_in_a_wall() -> void:
	var boss := Vector2(6, 0)
	var s := _whirl(boss + Vector2(2.6, 0), boss)
	var w: World = s[0]
	_idle(w, 40)
	assert_eq(_fx(w, BossMaelstrom.THROW).size(), 1)
	var p := w.player_pos()
	assert_true(EnemyAi.clear_of_walls(w, p, w.player.radius_m), "clear of the wall")
	assert_lt(p.x, TideLab.HALF_M - w.player.radius_m, "inside the room")


func test_outside_the_eye_costs_nothing_and_a_dashing_hero_is_not_carried() -> void:
	var s := _whirl(Vector2(3.4, 0))
	var w: World = s[0]
	w.step(InputFrame.new())
	assert_eq(
		_fx(w, BossMaelstrom.THROW).size(), 0, "3.4 m from its centre is outside the 3.1 m eye"
	)
	var t := _whirl(Vector2(8, 0))
	var v: World = t[0]
	v.step(InputFrame.new())
	v.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, InputFrame.DASH))
	assert_true(v.is_dashing())
	var y := v.player_pos().y
	v.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	assert_almost_eq(v.player_pos().y, y, 0.0001, "the dash goes straight")


func test_no_pull_is_cast_in_the_maelstrom_and_its_casts_never_overlap() -> void:
	var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	TideLab.set_phase(w, aid, 2)
	var both := 0
	var pulls := 0
	for k in 60 * 70:
		var hero := w.player_pos()
		var away := hero - w.actors.pos(_i(w, aid))
		var mv := Vector2i.ZERO
		if away.length() < 6.0:  # It keeps out of the eye
			mv = Vector2i(roundi(away.normalized().x * 127.0), roundi(away.normalized().y * 127.0))
		w.step(InputFrame.make(mv, 0, 300, 0, 0))
		TideLab.take_lost(w)
		var i := _i(w, aid)
		w.actors.hp[i] = maxi(w.actors.hp[i], 400)
		var atk := BossAi.attack_of(w, i)
		pulls += 1 if atk != null and atk.move == BossAttackTable.Move.TIDE else 0
		both += 1 if w.boss_fight.dance_rip_from >= 0 and w.boss_fight.dance_ht_from >= 0 else 0
	assert_eq(pulls, 0, "no Pull")
	assert_eq(both, 0, "a row and a High Tide never run together")
	assert_gte(_fx(w, BossDance.RIP_CAST).size(), 4, "Riptide is cast on top of it")
	assert_gte(_fx(w, BossDance.HT_CAST).size(), 1, "and High Tide")


# --- the anchor: the Tidecaller holds the room's centre through the Maelstrom -------------------------------------


## A Tidecaller in a corner that walks but casts nothing (its dance off), in the Maelstrom's phase.
func _walker(hero_at: Vector2, boss_at: Vector2, seed_value: int = 11) -> Array:
	var s := TideLab.fight(hero_at, boss_at, seed_value)
	var w: World = s[0]
	TideLab.hush(w, s[1], false)
	var d := TideLab.dance(w, s[1])
	d.rip_phase = NEVER
	d.ht_phase = NEVER
	TideLab.set_phase(w, s[1], 2)
	return s


func test_in_the_maelstrom_it_walks_straight_to_the_rooms_centre_tick_exact() -> void:
	var boss := Vector2(-9, 9)
	var s := _walker(Vector2(8, 6), boss)
	var w: World = s[0]
	var i := _i(w, s[1])
	var t := TideLab.table(w, s[1])
	var centre := w.bosses.arena.get_center()
	assert_eq(centre, Vector2.ZERO, "the lab's room is centred on the origin")
	var step := t.speed * t.phase_speed_permille[2] / 1000.0
	assert_almost_eq(step * 60.0, 1.4 * 0.99, 0.0001, "its phase's own walking speed")
	var start := boss.distance_to(centre)
	var walked := 0
	while w.actors.pos(i) != centre and walked < 2000:
		var at := w.actors.pos(i)
		w.actors.set_pos(0, Vector2(8, 6))  # Held off the eye's path: no hit, no hit-stop
		w.step(InputFrame.new())
		TideLab.take_lost(w)
		walked += 1
		i = _i(w, s[1])
		var now := w.actors.pos(i)
		if now == centre:
			break
		assert_almost_eq(at.distance_to(now), step, 0.0002, "one step a tick")
		assert_almost_eq(
			now.distance_to(centre), at.distance_to(centre) - step, 0.0002, "straight at it"
		)
	assert_eq(w.actors.pos(i), centre, "it lands on the centre exactly")
	assert_eq(walked, ceili(start / step), "in its distance over its speed, rounded up")
	assert_true(_state(w)["maelstrom"]["anchored"])


func test_it_stands_on_the_centre_for_the_rest_of_the_fight_whatever_it_does() -> void:
	var s := TideLab.fight(Vector2(8, 6), Vector2(-9, 9))
	var w: World = s[0]
	var aid: int = s[1]
	TideLab.set_phase(w, aid, 2)
	var centre := w.bosses.arena.get_center()
	var t := TideLab.table(w, aid)
	var walk := ceili(Vector2(-9, 9).length() / (t.speed * t.phase_speed_permille[2] / 1000.0))
	var t0 := w.tick
	var arrived := -1
	var moves := {}
	for k in 60 * 80:  # The hero stands and shoots: the whirlpool brings it in, the eye throws it out
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, InputFrame.SHOOT, 0))
		TideLab.take_lost(w)
		var i := _i(w, aid)
		w.actors.hp[i] = maxi(w.actors.hp[i], 400)
		var atk := BossAi.attack_of(w, i)
		if atk != null:
			moves[atk.move] = true
		if arrived < 0 and w.actors.pos(i) == centre:
			arrived = w.tick
		elif arrived >= 0 and w.actors.pos(i) != centre:
			fail_test("tick %d: it left the centre for %s" % [w.tick, w.actors.pos(i)])
			return
		var st: Dictionary = _state(w)["maelstrom"]
		if arrived >= 0 and not st.is_empty():
			assert_eq(st["centre"], centre, "the eye's centre is the room's centre")
	assert_gte(arrived, 0, "it reached the centre")
	# It walks on through its attacks: its walk's ticks, plus the few the hits' hit-stop freezes
	assert_between(arrived - t0, walk, walk + 60, "its walk takes %d ticks" % walk)
	assert_true(moves.has(BossAttackTable.Move.MARKS), "Undertow still comes")
	assert_true(moves.has(BossAttackTable.Move.SLAM_RING), "and Shell Slam")
	assert_gt(_fx(w, BossMaelstrom.BEGIN).size(), 0, "the whirlpool runs")


func test_before_the_maelstrom_it_still_walks_at_the_hero() -> void:
	var s := _walker(Vector2(8, 6), Vector2(-9, 9))
	var w: World = s[0]
	TideLab.set_phase(w, s[1], 1)
	var hero := w.player_pos()
	var from := w.actors.pos(_i(w, s[1])).distance_to(hero)
	_idle(w, 60)
	assert_lt(w.actors.pos(_i(w, s[1])).distance_to(hero), from - 1.0, "it chases")


func test_the_dry_circle_keeps_clear_of_the_eye_on_its_walk_over_seeds() -> void:
	var rng := RandomNumberGenerator.new()
	var placed := 0
	for sv in Seeds.count(1000):
		rng.seed = sv + 1
		var hero := Vector2(rng.randf_range(-11.0, 11.0), rng.randf_range(-11.0, 11.0))
		var boss := Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
		var s := TideLab.fight(hero, boss, sv + 1)
		var w: World = s[0]
		var i := _i(w, s[1])
		var d := TideLab.dance(w, s[1])
		TideLab.set_phase(w, s[1], 2)
		var c := BossDance.dry_spot(w, i, d)
		if not c.is_finite():
			continue
		placed += 1
		# The eye plus the hero's width and a metre never reaches the circle, wherever on its walk the boss is.
		var keep := (
			w.actors.radius[i] + d.mael_eye_m + w.player.radius_m * 2.0 + 1.0 + d.ht_radius_m
		)
		var centre := w.bosses.arena.get_center()
		for k in 21:
			var eye := boss.lerp(centre, k / 20.0)
			if c.distance_to(eye) < keep - 0.0001:
				fail_test(
					"seed %d: hero %s boss %s circle %s eye at %s" % [sv + 1, hero, boss, c, eye]
				)
				return
	assert_gt(placed, Seeds.count(1000) * 9 / 10, "nearly every High Tide finds its floor")
	pass_test("%d circles, none within the eye's reach" % placed)


func test_a_live_high_tide_never_floods_the_eye_over_seeds() -> void:
	for sv in 4:
		var s := TideLab.fight(Vector2(8, -6), Vector2(-9, 9), sv + 1)
		var w: World = s[0]
		var aid: int = s[1]
		TideLab.set_phase(w, aid, 2)
		var d := TideLab.dance(w, aid)
		var floods := 0
		for k in 60 * 40:
			w.step(InputFrame.new())
			TideLab.take_lost(w)
			var i := _i(w, aid)
			w.actors.hp[i] = maxi(w.actors.hp[i], 400)
			if w.boss_fight.dance_ht_from < 0:
				continue
			floods += 1
			var gap := BossDance.dry_centre(w).distance_to(w.actors.pos(i))
			if gap < BossDance.eye_keep_m(w, i, d) - 0.0001:
				fail_test(
					(
						"seed %d tick %d: the eye is %.2f m from the dry circle's centre"
						% [sv + 1, w.tick, gap]
					)
				)
				return
		assert_gt(floods, 0, "seed %d: a High Tide ran" % (sv + 1))


func test_the_walk_is_deterministic() -> void:
	var runs: Array[String] = []
	for r in 2:
		var s := TideLab.fight(Vector2(8, 6), Vector2(-9, 9), 5)
		var w: World = s[0]
		TideLab.set_phase(w, s[1], 2)
		_idle(w, 60 * 15)
		runs.append(w.state_hash())
	assert_eq(runs[0], runs[1])
