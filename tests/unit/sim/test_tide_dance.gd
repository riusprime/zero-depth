# gdlint: disable=max-public-methods
extends GutTest
## The Tidecaller's dance (BossDance, BossMaelstrom, SafeArea; BossTide's stronger Pull; the tide pools), in
## TideLab's walled 24 m room: the Pull as a share of the hero's run speed and the push as a throw; Riptide's row
## of four casts over three strips of four in the written order; High Tide's dry circle and what standing outside it
## costs; the Maelstrom's drag, its eye and its throw; the tide pools the crossing waves leave; what ends with the
## fight; determinism and a save.

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


func test_the_data_is_valid_and_compiles_to_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"tidecaller")
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	var d := t.dance
	assert_not_null(d)
	assert_eq([d.pull, d.pull_late, d.pull_late_phase], [750, 850, 2], "the Pull's share")
	assert_almost_eq(d.push_m, 6.0, 0.0001)
	assert_eq(t.attacks[t.attack_index(&"the_pull")].tide_push_ticks, 30, "thrown in 0.5 s")
	assert_eq(
		[d.rip_phase, d.rip_first_ticks, d.rip_every_ticks, d.rip_casts],
		[1, 600, 1200, 4],
		"Riptide"
	)
	assert_eq(
		[d.rip_warn_ticks, d.rip_last_warn_ticks, d.rip_wave_ticks, d.rip_hit], [120, 150, 36, 350]
	)
	assert_eq(
		[d.ht_phase, d.ht_every_ticks, d.ht_cast_ticks, d.ht_flood_ticks], [2, 1500, 150, 360]
	)
	assert_eq([d.ht_step_ticks, d.ht_hit], [30, 30], "6 % a second in 0.5 s steps")
	assert_almost_eq(d.ht_radius_m, 4.0, 0.0001)
	assert_almost_eq(d.ht_gap_m, 12.0, 0.0001)
	assert_eq(
		[d.mael_phase, d.mael_spin, d.mael_in, d.mael_hit], [2, 450, 250, 400], "the Maelstrom"
	)
	assert_eq([d.mael_throw_ticks, d.mael_grace_ticks], [30, 180])
	assert_almost_eq(d.mael_throw_m, 10.0, 0.0001)
	assert_eq(t.attacks[d.rip_cause].move, BossAttackTable.Move.WAVE, "Riptide's recap line")
	assert_eq(t.attacks[d.tide_cause].move, BossAttackTable.Move.TIDE, "the tide's recap line")
	for hit in [d.rip_hit, d.mael_hit, d.ht_hit]:
		assert_lte(hit, DanceRules.MAX_HIT, "no single hit over 40 % of max HP")
	assert_eq(t.phase_entry[2], -1, "the last phase opens with no Pull")
	assert_not_null(t.hazard, "the tide pools")
	assert_eq([t.hazard.kind, t.hazard.max_count], [HazardTable.Kind.SLOW, 5])
	assert_eq(t.hazard.life_ticks, 600)
	assert_almost_eq(t.hazard.radius_m, 2.0, 0.0001)


func test_the_rules_refuse_a_bad_dance() -> void:
	var repo := ContentRepository.load_all()
	var base: BossDefinition = repo.get_def(&"bosses", &"tidecaller")
	var bad := {
		"an unknown key": {"riptide_strength": 3},
		"a hit over 40 %": {"riptide_permille": 401},
		"an eye over 40 %": {"maelstrom_permille": 500},
		"a row longer than its period": {"riptide_every_seconds": 9.0},
		"a tide longer than its period": {"high_tide_every_seconds": 8.0},
		"a warning under the minimum": {"riptide_warn_seconds": 0.3},
		"a pull you cannot walk out of": {"pull_permille": 1000},
	}
	for why: String in bad:
		var def: BossDefinition = base.duplicate(true)
		var dance: Dictionary = base.dance.duplicate()
		dance.merge(bad[why], true)
		def.dance = dance
		assert_gt(def.validate().size(), 0, why)


# --- the Pull -------------------------------------------------------------------------------------------------


func _pulling(hero_at: Vector2, phase: int = 0) -> Array:
	var s := TideLab.fight(hero_at, Vector2.ZERO)
	var w: World = s[0]
	TideLab.hush(w, s[1])
	TideLab.dance(w, s[1]).mael_phase = NEVER
	if phase > 0:
		TideLab.set_phase(w, s[1], phase)
	BossLab.start(w, _i(w, s[1]), &"the_pull" if phase < 2 else &"the_pull_3")
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, s[1])] == S.ACTIVE, 200)
	return s


func test_the_pull_is_a_share_of_the_heros_own_run_speed() -> void:
	var s := _pulling(Vector2(8, 0))
	var w: World = s[0]
	var run := w.player.move_speed
	assert_almost_eq(BossTide.run_speed(w), run, 0.00001, "the base hero's 6 m/s")
	var x := w.player_pos().x
	w.step(InputFrame.new())
	assert_almost_eq(x - w.player_pos().x, run * 0.75, 0.0001, "75 % of it a tick, toward the boss")
	assert_almost_eq(float(WorldReader.new(w).boss_tide(_i(w, s[1]))["speed"]), 4.5, 0.001)
	w.item_mods.move_speed_bonus_permille = 500
	x = w.player_pos().x
	w.step(InputFrame.new())
	assert_almost_eq(
		x - w.player_pos().x, run * 1.5 * 0.75, 0.0001, "a faster hero is pulled harder"
	)


func test_walking_straight_out_of_the_pull_barely_gains_ground() -> void:
	var s := _pulling(Vector2(6, 0))
	var w: World = s[0]
	for k in 30:  # The walk reaches its full speed
		w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	var x := w.player_pos().x
	for k in 60:
		w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	var gained := w.player_pos().x - x
	assert_gt(gained, 0.5, "it gains ground")
	assert_lt(gained, 2.0, "but about a quarter of its 6 m a second")


func test_the_last_phases_pull_takes_85_percent() -> void:
	var s := _pulling(Vector2(8, 0), 2)
	var w: World = s[0]
	var x := w.player_pos().x
	w.step(InputFrame.new())
	assert_almost_eq(x - w.player_pos().x, w.player.move_speed * 0.85, 0.0001)


func test_the_push_is_a_throw_of_6_m_in_half_a_second() -> void:
	var s := _pulling(Vector2(8, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var nearest := INF
	var push_ticks := 0
	var far := 0.0
	for k in 400:
		var i := _i(w, aid)
		var tide := WorldReader.new(w).boss_tide(i)
		if tide.is_empty():
			break
		var dist := w.player_pos().distance_to(w.actors.pos(i))
		nearest = minf(nearest, dist)
		far = dist
		if tide["phase"] == WorldReader.TIDE_PUSH:
			push_ticks += 1
		w.step(InputFrame.new())
	assert_almost_eq(far - nearest, 6.0, 0.25, "thrown about 6 m out")
	assert_between(push_ticks, 29, 31, "over 0.5 s, then nothing")
	var here := w.player_pos()
	_idle(w, 30)
	assert_eq(w.player_pos(), here, "no drift after it")


func test_a_boss_without_a_dance_keeps_its_own_speeds() -> void:
	var s := TideLab.fight(Vector2(8, 0), Vector2.ZERO)
	var w: World = s[0]
	TideLab.hush(w, s[1])
	TideLab.table(w, s[1]).dance = null
	BossLab.start(w, _i(w, s[1]), &"the_pull")
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, s[1])] == S.ACTIVE, 200)
	var x := w.player_pos().x
	w.step(InputFrame.new())
	assert_almost_eq(x - w.player_pos().x, 1.7 * TICK, 0.0001, "pull_mps, under its cap")
	assert_eq(_state(w), {}, "and no dance runs")


# --- Riptide --------------------------------------------------------------------------------------------------


## Steps a Riptide-only fight to its first cast. Returns [world, id, the cast's event, the tick before the first
## step].
func _to_riptide(hero_at: Vector2, seed_value: int = 11) -> Array:
	var s := _only(hero_at, 1, ["riptide"], seed_value)
	var w: World = s[0]
	var t0 := w.tick
	var cast := JudgeLab.until_effect(w, BossDance.RIP_CAST, 700)
	return [w, s[1], cast, t0]


## A strip struck in the row's first three casts and safe in its last, by the row's mirror.
func _edge_strip(w: World) -> int:
	return 3 if w.bosses.dance_rip_mirror == 0 else 0


func test_a_row_is_four_casts_three_strips_each_tick_exact() -> void:
	var s := _to_riptide(Vector2(0, 0))
	var w: World = s[0]
	var d := TideLab.dance(w, s[1])
	var first: SimEvent = s[2]
	assert_not_null(first, "the first row begins")
	assert_between(first.tick - int(s[3]), 600, 601, "10 s into the phase")
	var st := _state(w)
	assert_eq((st["strips"] as Array).size(), 4)
	assert_eq(st["strips"][0], Rect2(-12, -12, 24, 6), "strips along the room, 6 m wide")
	assert_eq(st["strips"][3], Rect2(-12, 6, 24, 6))
	assert_eq((st["riptide"]["struck"] as Array).size(), 3, "three are warned")
	assert_false((st["riptide"]["struck"] as Array).has(st["riptide"]["safe"]))
	var edge := _edge_strip(w)
	var cost := TideLab.LONG * 350 / 1000
	var lost := 0
	for k in 700:
		w.actors.set_pos(0, TideLab.in_strip(edge))
		w.step(InputFrame.new())
		lost += TideLab.take_lost(w)
		w.actors.invuln[0] = 0
		if w.bosses.dance_rip_from < 0:
			break
	var casts := _fx(w, BossDance.RIP_CAST)
	var waves := _fx(w, BossDance.RIP_WAVE)
	var hits := _fx(w, BossDance.RIP_HIT)
	assert_eq(casts.size(), 4, "four casts")
	assert_eq(waves.size(), 4)
	var order: Array[int] = []
	for k in casts.size():
		order.append(casts[k].amount_applied)
		assert_eq(casts[k].amount, 150 if k == 3 else 120, "2.0 s of warning, the last 2.5 s")
		assert_eq(waves[k].tick - casts[k].tick, casts[k].amount, "then its wave")
		if k > 0:
			assert_eq(casts[k].tick - waves[k - 1].tick, 36, "the next warning as the wave ends")
	var written: Array[int] = [1, 2, 0, 3]
	var mirror: Array[int] = [2, 1, 3, 0]
	assert_true(order == written or order == mirror, "2, 3, 1, 4 or its mirror: %s" % [order])
	assert_eq(hits.size(), 3, "hit in the three casts its strip was warned, not in the last")
	for k in hits.size():
		assert_eq(hits[k].tick - waves[k].tick, 18, "as the front reaches the middle of the strip")
		assert_eq(hits[k].amount, cost, "35 % of max HP")
	assert_eq(lost, cost * 3)
	assert_eq(w.tick - waves[3].tick, 37, "the row ends with its last wave")
	assert_eq(_state(w)["riptide"], {})
	assert_eq(
		w.bosses.dance_rip_due, first.tick + d.rip_every_ticks, "the next row 20 s after this began"
	)
	var again := JudgeLab.until_effect(w, BossDance.RIP_CAST, 700, casts[3].seq)
	assert_eq(again.tick, first.tick + 1200)


func test_the_dry_strip_costs_nothing() -> void:
	var s := _to_riptide(Vector2(0, 0))
	var w: World = s[0]
	var lost := 0
	for k in 700:
		var rip: Dictionary = _state(w)["riptide"]
		if rip.is_empty():
			break
		w.actors.set_pos(0, TideLab.in_strip(rip["safe"]))
		w.step(InputFrame.new())
		lost += TideLab.take_lost(w)
	assert_eq(lost, 0)
	assert_eq(_fx(w, BossDance.RIP_HIT).size(), 0)
	assert_eq(_fx(w, BossDance.RIP_WAVE).size(), 4, "all four waves ran")


func test_a_hero_that_steps_in_behind_the_front_is_not_hit() -> void:
	var s := _to_riptide(Vector2(0, 0))
	var w: World = s[0]
	var safe: int = _state(w)["riptide"]["safe"]
	var struck: int = _state(w)["riptide"]["struck"][0]
	w.actors.set_pos(0, TideLab.in_strip(safe))
	JudgeLab.until_effect(w, BossDance.RIP_WAVE, 200)
	_idle(w, 29)  # The front the reader shows (the tick to come) is 20 m down the 24 m strips
	assert_almost_eq(float(_state(w)["riptide"]["front"]), 20.0, 0.01)
	w.actors.set_pos(0, TideLab.in_strip(struck, -6.0))  # 6 m down: behind it
	assert_eq(_idle(w, 5), 0)
	assert_eq(_fx(w, BossDance.RIP_HIT).size(), 0)


func test_a_dash_through_the_front_follows_the_games_dash_rule() -> void:
	for dash: bool in [false, true]:
		var s := _to_riptide(Vector2(0, 0))
		var w: World = s[0]
		w.actors.set_pos(0, TideLab.in_strip(_edge_strip(w)))
		JudgeLab.until_effect(w, BossDance.RIP_WAVE, 200)
		_idle(w, 16)
		var f := InputFrame.make(Vector2i(-127, 0), 2048, 300, 0, InputFrame.DASH)
		w.step(f if dash else InputFrame.new())
		for k in 12:
			w.step(
				InputFrame.make(Vector2i(-127, 0), 2048, 300, 0, 0) if dash else InputFrame.new()
			)
		var hits := _fx(w, BossDance.RIP_HIT).size()
		if dash:
			assert_lt(w.player_pos().x, -1.0, "it dashed against the wave")
			assert_eq(hits, 0, "the dash's invulnerability holds as for any boss strike")
		else:
			assert_eq(hits, 1, "standing there, the same front hits")


func test_the_safe_order_is_one_of_the_two_written_over_seeds() -> void:
	var seen := {}
	var written: Array[int] = [1, 2, 0, 3]
	var mirror: Array[int] = [2, 1, 3, 0]
	var seeds := Seeds.count(1000)
	for sv in seeds:
		var s := _only(Vector2(0, 0), 1, ["riptide"], sv + 1)
		var w: World = s[0]
		var d := TideLab.dance(w, s[1])
		d.rip_first_ticks = 1
		d.rip_warn_ticks = 2
		d.rip_last_warn_ticks = 3
		d.rip_wave_ticks = 2
		_idle(w, 24)
		var order: Array[int] = []
		for e in _fx(w, BossDance.RIP_CAST):
			order.append(e.amount_applied)
		if order != written and order != mirror:
			fail_test("seed %d: %s" % [sv + 1, order])
			return
		seen[order[0]] = int(seen.get(order[0], 0)) + 1
	assert_eq(seen.size(), 2, "both orders come up: %s" % [seen])
	assert_gt(int(seen.get(1, 0)), seeds / 4)
	assert_gt(int(seen.get(2, 0)), seeds / 4)


func test_the_pull_and_a_row_never_run_together_before_the_maelstrom() -> void:
	var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	TideLab.set_phase(w, aid, 1)
	var pulls := 0
	var rows := 0
	var both := 0
	for k in 60 * 50:
		w.step(InputFrame.new())
		TideLab.take_lost(w)
		var i := _i(w, aid)
		w.actors.hp[i] = maxi(w.actors.hp[i], 1200)
		var pull := not BossTide.state(w, i).is_empty()
		var row := w.bosses.dance_rip_from >= 0
		pulls += 1 if pull else 0
		rows += 1 if row else 0
		both += 1 if pull and row else 0
	assert_gt(pulls, 0, "it pulled")
	assert_gt(rows, 0, "it cast a row")
	assert_eq(both, 0, "never both")
	assert_gte(_fx(w, BossDance.RIP_CAST).size(), 8, "two rows in 50 s")


# --- High Tide ------------------------------------------------------------------------------------------------


func _to_high_tide(hero_at: Vector2, seed_value: int = 11) -> Array:
	var s := _only(hero_at, 2, ["high_tide"], seed_value)
	var w: World = s[0]
	var t0 := w.tick
	var cast := JudgeLab.until_effect(w, BossDance.HT_CAST, 600)
	return [w, s[1], cast, t0]


func test_high_tide_shows_a_dry_circle_far_from_the_hero_and_points_at_it() -> void:
	var s := _to_high_tide(Vector2(9, -4))
	var w: World = s[0]
	var cast: SimEvent = s[2]
	assert_not_null(cast)
	assert_between(cast.tick - int(s[3]), 480, 481, "8 s into the phase")
	assert_eq(cast.amount, 150, "a 2.5 s cast")
	var st: Dictionary = _state(w)["high_tide"]
	var c: Vector2 = st["centre"]
	assert_eq(c, cast.pos)
	assert_almost_eq(float(st["radius"]), 4.0, 0.0001)
	assert_gte(c.distance_to(Vector2(9, -4)), 12.0, "at least 12 m from the hero")
	assert_true(w.bosses.arena.grow(-4.0).has_point(c), "the whole circle inside the room")
	assert_false(st["inside"])
	assert_eq(st["flood"], -1, "the water is not up yet")
	assert_true(w.objectives.has(ObjectiveMarkers.TIDE_DRY), "the marker")
	var marks := WorldReader.new(w).objectives()
	assert_eq(marks.size(), 1)
	assert_eq(marks[0]["reason"], ObjectiveMarkers.TIDE_DRY)
	assert_eq(_idle(w, 149), 0, "the cast costs nothing")


func test_outside_the_circle_costs_6_percent_a_second_for_6_s() -> void:
	var s := _to_high_tide(Vector2(9, -4))
	var w: World = s[0]
	var cast: SimEvent = s[2]
	var step := TideLab.LONG * 30 / 1000
	var paid: Array[int] = []
	var total := 0
	for k in 600:
		w.step(InputFrame.new())
		var lost := TideLab.take_lost(w)
		w.actors.invuln[0] = 0
		if lost > 0:
			paid.append(w.tick)
			assert_eq(lost, step, "3 % of max HP a step")
		total += lost
		if w.bosses.dance_ht_from < 0:
			break
	var flood := _fx(w, BossDance.HT_FLOOD)
	var done := _fx(w, BossDance.HT_END)
	assert_eq(flood.size(), 1)
	assert_eq(flood[0].tick - cast.tick, 150, "the water is up as the cast ends")
	assert_eq(paid.size(), 12, "twelve steps in 6 s")
	assert_eq(paid[1] - paid[0], 30, "0.5 s apart")
	assert_eq(total, step * 12, "36 % of max HP in all: never a kill from full")
	assert_eq(done.size(), 1)
	assert_eq(done[0].tick - flood[0].tick, 360)
	assert_false(w.objectives.has(ObjectiveMarkers.TIDE_DRY), "the marker goes")
	assert_eq(_state(w)["high_tide"], {})
	assert_eq(w.bosses.dance_ht_due, cast.tick + 1500, "the next 25 s after this began")
	assert_eq(_idle(w, 120), 0, "and nothing after it")


func test_reaching_the_circle_stops_the_loss() -> void:
	var s := _to_high_tide(Vector2(9, -4))
	var w: World = s[0]
	var c: Vector2 = _state(w)["high_tide"]["centre"]
	JudgeLab.until_effect(w, BossDance.HT_FLOOD, 200)
	TideLab.take_lost(w)
	var step := TideLab.LONG * 30 / 1000
	assert_eq(_idle(w, 95), step * 3, "three steps outside")
	w.actors.set_pos(0, c + Vector2(3.9, 0))  # Its centre inside the circle
	assert_true(_state(w)["high_tide"]["inside"])
	assert_eq(_idle(w, 300), 0, "none inside")


func test_the_dry_circle_is_12_m_away_and_reachable_over_seeds() -> void:
	var rng := RandomNumberGenerator.new()
	for sv in Seeds.count(1000):
		rng.seed = sv + 1
		# A hero at least 4.5 m from the room's middle (nearer, no floor of this room is 12 m away) and a boss
		# within 1 m of it.
		var hero := Vector2.ZERO
		while hero.length() < 4.5:
			hero = Vector2(rng.randf_range(-11.0, 11.0), rng.randf_range(-11.0, 11.0))
		var boss := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
		var s := TideLab.fight(hero, boss, sv + 1)
		var w: World = s[0]
		var i := _i(w, s[1])
		var d := TideLab.dance(w, s[1])
		var c := BossDance.dry_spot(w, i, d)
		var ok := (
			c.is_finite()
			and c.distance_to(hero) >= 12.0
			and w.bosses.arena.grow(-d.ht_radius_m).has_point(c)
			and EnemyAi.clear_of_walls(w, c, d.ht_radius_m)
			and c.distance_to(boss) >= w.actors.radius[i] + d.mael_eye_m + d.ht_radius_m * 0.5
			and JudgeLab.reachable(w, hero, c, w.player.radius_m, 0.5, d.ht_radius_m)
		)
		if not ok:
			fail_test("seed %d: hero %s boss %s circle %s" % [sv + 1, hero, boss, c])
			return
	pass_test("every circle 12 m away, inside the room, off the eye and reachable")


func test_a_hero_in_the_middle_of_a_small_room_still_gets_a_circle() -> void:
	# No floor of a 24 m room is 12 m from its middle: the gap is halved rather than the cast skipped.
	var s := TideLab.fight(Vector2(0.5, 0), Vector2(-9, 9))
	var w: World = s[0]
	var c := BossDance.dry_spot(w, _i(w, s[1]), TideLab.dance(w, s[1]))
	assert_true(c.is_finite())
	assert_gte(c.distance_to(Vector2(0.5, 0)), 6.0)
	assert_lt(c.distance_to(Vector2(0.5, 0)), 12.0)


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
	assert_eq(w.bosses.dance_spin, spin)


func test_both_ways_come_up_over_seeds() -> void:
	var seen := {}
	for sv in 40:
		var s := _whirl(Vector2(8, 0), Vector2.ZERO, sv + 1)
		(s[0] as World).step(InputFrame.new())
		seen[(s[0] as World).bosses.dance_spin] = true
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
		both += 1 if w.bosses.dance_rip_from >= 0 and w.bosses.dance_ht_from >= 0 else 0
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
			if w.bosses.dance_ht_from < 0:
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


# --- the tide pools ---------------------------------------------------------------------------------------------


func test_each_crossing_wave_leaves_a_tide_pool_at_most_five() -> void:
	var s := _only(Vector2(0, 0), 0, [])
	var w: World = s[0]
	TideLab.table(w, s[1]).streams = true
	var most := 0
	var first: Dictionary = {}
	var ended := 0
	var waves := 0
	for k in 60 * 45:
		var before := w.bosses.wv_boss.size()
		w.step(InputFrame.new())
		TideLab.take_lost(w)
		w.actors.set_pos(0, Vector2(0, 0))
		ended += maxi(0, before - w.bosses.wv_boss.size())
		waves = maxi(waves, w.bosses.wv_boss.size())
		var rows := WorldReader.new(w).boss_hazards()
		most = maxi(most, rows.size())
		if first.is_empty() and not rows.is_empty():
			first = rows[0]
			assert_eq(ended, 1, "with the first wave to reach the far wall")
	assert_gt(waves, 0)
	assert_gt(ended, 5)
	assert_between(most, 2, 5, "they gather, never more than 5")
	assert_almost_eq(float(first["radius"]), 2.0, 0.0001)
	assert_false(first["armed"], "it warns first")
	var c: Vector2 = first["centre"]
	assert_true(w.bosses.arena.grow(-1.99).has_point(c), "the whole disc on the floor")
	var wall := minf(TideLab.HALF_M - absf(c.x), TideLab.HALF_M - absf(c.y))
	assert_between(wall, 2.0, 2.26, "against the wall the wave broke on")
	assert_between(int(first["left"]), 647, 648, "0.8 s of warning, then 10 s")


func test_a_tide_pool_slows_and_never_hurts() -> void:
	var s := _only(Vector2(0, 0), 0, [])
	var w: World = s[0]
	var i := _i(w, s[1])
	assert_true(BossHazard.place(w, i, Vector2(5, 5)))
	w.actors.set_pos(0, Vector2(5, 5))
	assert_eq(_idle(w, 47), 0)
	assert_almost_eq(BossHazard.move_factor(w), 1.0, 0.0001, "not while it warns")
	assert_eq(_idle(w, 120), 0, "it never hurts")
	assert_almost_eq(BossHazard.move_factor(w), 0.6, 0.0001, "60 % of the hero's speed inside")
	assert_almost_eq(
		BossTide.run_speed(w), w.player.move_speed * 0.6, 0.0001, "the Pull follows that speed"
	)
	for k in 7:
		BossHazard.place(w, i, Vector2(-8.0 + k * 2.5, -6.0))
	assert_eq(WorldReader.new(w).boss_hazards().size(), 5, "at most 5: the oldest go")


# --- the end of a fight, determinism, a save --------------------------------------------------------------------


func _mid_fight(seed_value: int, ticks: int = 60 * 40) -> World:
	var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0), seed_value)
	var w: World = s[0]
	TideLab.set_phase(w, s[1], 2)
	for k in ticks:
		var f := InputFrame.make(Vector2i(90, 50), 0, 300, InputFrame.SHOOT, 0)
		w.step(f if k % 120 < 60 else InputFrame.make(Vector2i(-90, -50), 0, 300, 0, 0))
		w.actors.hp[0] = TideLab.LONG
		w.actors.hp[w.actors.index_of(s[1])] = 400
	return w


func test_everything_goes_when_the_tidecaller_dies() -> void:
	var w := _mid_fight(7, 60 * 12)
	var aid := w.bosses.dance_boss
	assert_gte(aid, 0)
	assert_gte(w.bosses.dance_ht_from, 0, "a High Tide runs")
	assert_true(w.objectives.has(ObjectiveMarkers.TIDE_DRY))
	assert_gt(WorldReader.new(w).boss_hazards().size(), 0, "tide pools lie")
	var me := w.actors.ids[0]
	for k in 1200:
		var i := _i(w, aid)
		if i < 0:
			break
		Damage.hit(w, i, 1 << 24, me, me, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
		w.step(InputFrame.new())
		w.actors.hp[0] = TideLab.LONG
	assert_lt(_i(w, aid), 0, "it is gone")
	var bs := w.bosses
	assert_eq([bs.dance_boss, bs.dance_rip_from, bs.dance_ht_from], [-1, -1, -1], "the casts")
	assert_eq([bs.dance_spin, bs.dance_throw, bs.dance_grace], [0, 0, 0], "the whirlpool")
	assert_false(w.objectives.has(ObjectiveMarkers.TIDE_DRY), "the marker")
	assert_eq(WorldReader.new(w).boss_hazards().size(), 0, "the pools")
	assert_eq(_state(w), {})
	var seq := w.events_since(0).back().seq as int
	CombatLab.idle(w, 120)
	assert_eq(_fx(w, BossDance.RIP_CAST, seq).size() + _fx(w, BossDance.HT_CAST, seq).size(), 0)
	assert_eq(_fx(w, BossMaelstrom.THROW, seq).size(), 0, "and no cast or throw afterwards")


func test_dying_or_leaving_the_room_ends_the_casts() -> void:
	for dead in [false, true]:
		var s := _only(Vector2(9, -4), 2, ["riptide", "high_tide"])
		var w: World = s[0]
		JudgeLab.until_effect(w, BossDance.HT_CAST, 600)
		w.bosses.dance_rip_from = w.tick  # A row too, as if both could run
		if dead:
			w.actors.hp[0] = 0
			w.actors.dead[0] = 1
		else:
			w.actors.set_pos(0, Vector2(0, 20))
		w.step(InputFrame.new())
		assert_eq([w.bosses.dance_rip_from, w.bosses.dance_ht_from], [-1, -1])
		assert_false(w.objectives.has(ObjectiveMarkers.TIDE_DRY))
		assert_eq(_fx(w, BossDance.HT_END).size(), 1)
		var seq := w.events_since(0).back().seq as int
		CombatLab.idle(w, 400)
		assert_eq(_fx(w, BossDance.RIP_HIT, seq).size(), 0, "and nothing strikes afterwards")


func test_one_mistake_never_kills_from_full() -> void:
	# The base hero (100 HP, no armour) against each single piece.
	var s := _to_riptide(Vector2(0, 0))
	var w: World = s[0]
	w.actors.max_hp[0] = 100
	w.actors.hp[0] = 100
	w.actors.set_pos(0, TideLab.in_strip(_edge_strip(w)))
	JudgeLab.until_effect(w, BossDance.RIP_HIT, 200)
	assert_eq(w.actors.hp[0], 65, "one wave: 35")
	var t := _whirl(Vector2(-8, 0) + Vector2(2.6, 0), Vector2(-8, 0))
	var v: World = t[0]
	v.actors.max_hp[0] = 100
	v.actors.hp[0] = 100
	v.step(InputFrame.new())
	assert_eq(v.actors.hp[0], 60, "the eye: 40")
	var u: World = _to_high_tide(Vector2(9, -4))[0]
	u.actors.max_hp[0] = 100
	u.actors.hp[0] = 100
	CombatLab.idle(u, 150 + 360 + 5)
	assert_eq(u.actors.hp[0], 64, "a whole High Tide outside: 36")


func test_a_riptide_kill_names_the_wave_and_the_eye_the_pull() -> void:
	var s := _to_riptide(Vector2(0, 0))
	var w: World = s[0]
	w.actors.max_hp[0] = 100
	w.actors.hp[0] = 10
	w.actors.set_pos(0, TideLab.in_strip(_edge_strip(w)))
	CombatLab.until(w, func(x: World) -> bool: return x.player_dead(), 300)
	assert_true(w.player_dead())
	assert_eq(BossCauses.key(w), &"CAUSE_TIDECALLER_WAVE")
	var t := _whirl(Vector2(-8, 0) + Vector2(2.6, 0), Vector2(-8, 0))
	var v: World = t[0]
	v.actors.max_hp[0] = 100
	v.actors.hp[0] = 10
	v.step(InputFrame.new())
	assert_true(v.player_dead())
	assert_eq(BossCauses.key(v), &"CAUSE_TIDECALLER_PULL")


func test_deterministic_hashed_and_a_save_mid_fight_restores() -> void:
	var a := _mid_fight(7)
	var b := _mid_fight(7)
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	assert_ne(a.state_hash(), _mid_fight(8).state_hash(), "another seed, another fight")
	assert_gt(_fx(a, BossDance.RIP_CAST).size(), 0, "a row was cast")
	assert_gt(_fx(a, BossDance.HT_CAST).size(), 0, "a High Tide too")
	var before := a.state_hash()
	a.bosses.dance_grace += 1
	assert_ne(a.state_hash(), before, "the clocks are hashed")
	a.bosses.dance_grace -= 1
	a.bosses.dance_ht_x += 0.5
	assert_ne(a.state_hash(), before, "and the dry circle")
	# A save with a High Tide running, then one with a row running
	for ticks: int in [60 * 12, 60 * 26]:
		var c := _mid_fight(7, ticks)
		var bs := c.bosses
		assert_true(bs.dance_ht_from >= 0 or bs.dance_rip_from >= 0, "a cast runs at %d" % ticks)
		var snap := WorldSnapshot.take(c)
		var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), JudgeLab.world(7))
		assert_not_null(restored, "restores")
		if restored == null:
			return
		assert_eq(restored.state_hash(), c.state_hash(), "same hash restored")
		assert_eq(WorldReader.new(restored).boss_dance(), WorldReader.new(c).boss_dance())
		for k in 600:
			var f := InputFrame.make(Vector2i(60, -40), 0, 300, InputFrame.SHOOT, 0)
			c.step(f)
			restored.step(f)
			c.actors.hp[0] = TideLab.LONG
			restored.actors.hp[0] = TideLab.LONG
		assert_eq(restored.state_hash(), c.state_hash(), "same hash 600 ticks on")


func test_a_world_without_a_dance_keeps_no_dance_state() -> void:
	var s := JudgeLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	CombatLab.idle(w, 120)
	assert_eq(w.bosses.dance_boss, -1)
	assert_eq(WorldReader.new(w).boss_dance(), {})
