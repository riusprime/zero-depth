extends GutTest
## v0.9.5 BH2 (owner: "we have to modify 1 spell for each that will be hard to dodge"; BOSSES_HARD.md B1-B5):
## the Gatekeeper's Shock Lanes, the Warlord's Javelin Fan, the Brood Mother's Leap Chain, the Hive Lens's Focus Beam
## and the Siege Engine's Mortar Grid. Each test pins the spell's new numbers (telegraph, timing, lead, turn rate, safe
## cells, the swap) and plays the answer to it. Every telegraph is at least 0.55 s (33 ticks); no damage changed.

const S := EnemyAi.State
const LONG := 1 << 20
const MIN_TICKS := 33


func _fight(id: StringName, player_at: Vector2, boss_at := Vector2.ZERO, seed_value := 11) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, id, boss_at)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func _table(id: StringName) -> BossTable:
	var w := BossLab.world()
	return w.boss_tables[BossLab.table_index(w, id)]


func _atk(t: BossTable, id: StringName) -> BossAttackTable:
	return t.attacks[t.attack_index(id)]


func _step_at(w: World, at: Vector2) -> void:
	w.actors.set_pos(0, at)
	w.step(InputFrame.new())


## B1 ---------------------------------------------------------------------------------------------------------------


func test_the_shock_lanes_lock_for_0_55_s_and_phases_2_and_3_follow_them_with_a_second_cross(
) -> void:
	var t := _table(&"gatekeeper")
	for id: StringName in [&"shock_lanes", &"shock_lanes_follow", &"shock_lanes_2"]:
		var atk := _atk(t, id)
		assert_eq(atk.lock_ticks, 33, "%s: locks 0.55 s (was 0.8)" % id)
		assert_eq(atk.windup_ticks, 81, "%s: still tracks 0.8 s before the lock" % id)
		assert_eq(atk.damage, 30, "%s: damage unchanged" % id)
	assert_eq(_atk(t, &"shock_lanes").second_ticks, 0, "phase 1 has no second cross")
	for id: StringName in [&"shock_lanes_follow", &"shock_lanes_2"]:
		var atk := _atk(t, id)
		assert_eq(atk.second_ticks, 24, "%s: the second cross 0.4 s after the first" % id)
		assert_almost_eq(
			atk.second_offset_m, 0.6, 0.0001, "%s: half a lane width (1.2 m lanes)" % id
		)
		assert_gte(
			atk.active_ticks,
			(atk.count - 1) * atk.mark_gap_ticks + 24 + 2,
			"%s: active to the last" % id
		)
	var phase := func(p: int) -> Array:
		return Array(t.phase_attacks[p]).map(func(k: int) -> StringName: return t.attacks[k].id)
	assert_has(phase.call(0), &"shock_lanes")
	assert_has(phase.call(1), &"shock_lanes_follow")
	assert_has(phase.call(2), &"shock_lanes_2")
	assert_does_not_have(phase.call(1), &"shock_lanes")


func test_the_second_cross_shows_from_the_first_lock_and_sits_half_a_lane_toward_the_boss() -> void:
	var s := _fight(&"gatekeeper", Vector2(5, 3))
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	BossLab.start(w, i, &"shock_lanes_follow")
	var atk := BossAi.attack_of(w, i)
	var lock_at := atk.windup_ticks - atk.lock_ticks
	for t in lock_at + 2:
		i = w.actors.index_of(aid)
		var tg := BossAi.telegraph(w, i)
		var want := 1 if t < lock_at else 2
		assert_eq(
			(tg["items"] as Array).size(),
			want,
			"tick %d: the second cross appears when the first locks" % t
		)
		w.step(InputFrame.new())
	i = w.actors.index_of(aid)
	var first := BossDodge.mark_of(w, i, 0)
	var second := BossDodge.mark_of(w, i, 1)
	assert_eq(first, Vector2(5, 3), "the first cross is on the hero")
	assert_almost_eq(
		(second - first).x, -0.6, 0.001, "toward the boss on x (the hero stands still)"
	)
	assert_almost_eq((second - first).y, -0.6, 0.001, "and on y")
	assert_eq(
		BossHard.strike_at(atk, 1) - BossHard.strike_at(atk, 0), 24, "struck 0.4 s after the first"
	)
	var shown := atk.windup_ticks - atk.lock_ticks
	assert_gte(
		BossHard.strike_at(atk, 1) + atk.windup_ticks - shown, MIN_TICKS, "shown at least 0.55 s"
	)


func test_the_second_cross_leans_the_way_the_hero_is_heading() -> void:
	var s := _fight(&"gatekeeper", Vector2(5, 3))
	var w: World = s[0]
	var atk := _atk(w.boss_tables[BossLab.table_index(w, &"gatekeeper")], &"shock_lanes_follow")
	var b := w.bosses.index_of(s[1])
	w.vel = Vector2(0.1, 0.0)  # heading +x, still on y
	var at := BossHard.second_point(w, b, atk, Vector2(5, 3))
	assert_almost_eq(at.x, 5.6, 0.001, "ahead of the hero on x")
	assert_almost_eq(at.y, 2.4, 0.001, "toward the boss on y")


## The damage the hero takes over a whole Shock Lanes (a first cross, then a second), `then_at` after the lock.
func _lanes_damage(then_at: Vector2) -> int:
	var c := Vector2(5, 3)
	var s := _fight(&"gatekeeper", c)
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"shock_lanes_follow")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	for t in atk.windup_ticks - atk.lock_ticks:
		_step_at(w, c)
	for t in atk.windup_ticks + 40:
		_step_at(w, then_at)
		if w.actors.index_of(aid) < 0 or w.actors.state[w.actors.index_of(aid)] == S.RECOVER:
			break
	var lost := LONG - w.actors.hp[0]
	return lost


func test_stepping_just_out_of_the_first_cross_walks_into_the_second() -> void:
	var c := Vector2(5, 3)
	assert_gt(
		_lanes_damage(c + Vector2(-1.0, -1.0)),
		0,
		"1 m toward the boss: out of the first, inside the second"
	)
	assert_eq(_lanes_damage(c + Vector2(1.0, 1.0)), 0, "1 m the other way clears both")
	assert_eq(_lanes_damage(c + Vector2(-1.9, -1.9)), 0, "or 1.9 m toward the boss")


## B2 ---------------------------------------------------------------------------------------------------------------


func test_the_javelin_fan_winds_up_0_6_s_with_two_fans_0_3_s_apart() -> void:
	var t := _table(&"warlord")
	for id: StringName in [&"javelin_fan", &"javelin_fan_fast"]:
		var atk := _atk(t, id)
		assert_eq(atk.windup_ticks, 36, "%s: 0.6 s (was 0.45)" % id)
		assert_eq(atk.lead_ticks, 21, "%s: the first fan leads 0.35 s" % id)
		assert_eq(
			[atk.pattern.waves, atk.pattern.wave_gap_ticks],
			[2, 18],
			"%s: two fans, 0.3 s apart" % id
		)
		assert_eq(atk.damage, 25, "%s: damage unchanged" % id)


func test_the_first_fan_aims_ahead_of_the_hero_and_the_second_where_they_are() -> void:
	var s := _fight(&"warlord", Vector2(8, 0))
	var w: World = s[0]
	var i := w.actors.index_of(s[1])
	var atk := _atk(w.boss_tables[BossLab.table_index(w, &"warlord")], &"javelin_fan")
	w.vel = Vector2(0, 0.1)  # 6 m/s along +y: 2.1 m in 0.35 s
	BossHard.aim_fan(w, i, atk, 0)
	var lead := Kin.angle_of(Vector2(8, 2.1) - w.actors.pos(i))
	assert_lte(
		Kin.angle_diff(w.actors.lock_a[i], lead), 2, "the first fan aims at where they will be"
	)
	BossHard.aim_fan(w, i, atk, 1)
	assert_eq(
		w.actors.lock_a[i],
		Kin.angle_of(Vector2(8, 0) - w.actors.pos(i)),
		"the second where they are"
	)


func test_the_lead_is_cut_short_by_the_room() -> void:
	var s := _fight(&"warlord", Vector2(8, 0))
	var w: World = s[0]
	w.add_barrier(Obb.make(Vector2(10, 0), Vector2(0.5, 6.0), 0))  # a wall 2 m ahead
	w.vel = Vector2(0.2, 0.0)  # 12 m/s: 4.2 m ahead, through the wall
	var p := BossHard.lead_point(w, 21)
	assert_lt(p.x, 9.5 - w.player.radius_m + 0.01, "stopped at the wall, not behind it")
	assert_gt(p.x, 8.0, "but still ahead of the hero")
	w.vel = Vector2.ZERO
	assert_eq(BossHard.lead_point(w, 21), w.player_pos(), "a hero standing still is not led")


func test_a_javelin_fan_thrown_at_a_running_hero_is_aimed_ahead_of_them() -> void:
	var s := _fight(&"warlord", Vector2(8, -4))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"javelin_fan")
	var i := w.actors.index_of(aid)
	var atk := BossAi.attack_of(w, i)
	var f := InputFrame.new()
	f.move = Vector2i(0, SimTick.MOVE_MAX)  # runs along +y
	var fired := false
	for t in atk.windup_ticks + 4:
		w.step(f)
		if w.actors.state[i] == S.ACTIVE and not fired:
			fired = true
			var straight := Kin.angle_of(w.player_pos() - w.actors.pos(i))
			var diff := (w.actors.lock_a[i] - straight) & 4095
			assert_true(
				diff > 0 and diff < 1024, "aimed ahead (+y) of the hero, not at them: %d" % diff
			)
	assert_true(fired, "the fan fired")


## B3 ---------------------------------------------------------------------------------------------------------------


func test_the_leap_chain_is_three_leaps_the_last_led_and_wider() -> void:
	var t := _table(&"brood_mother")
	var atk := _atk(t, &"leap_chain")
	assert_eq(atk.chain, 3, "3 leaps (was 2)")
	assert_eq(atk.last_lead_ticks, 21, "the last aims 0.35 s ahead")
	assert_eq(atk.last_radius_bonus_permille, 200, "and lands +20 % wider")
	assert_eq(atk.windup_ticks, 60, "each leap still winds up 1.0 s")
	assert_eq(atk.damage, 50, "damage unchanged")
	assert_eq(_atk(t, &"leap").chain, 1, "the single leap is as it was")
	assert_eq(_atk(t, &"leap").last_radius_bonus_permille, 0)
	assert_eq(
		t.radius_m,
		_table(&"brood_mother").radius_m,
		"the body is not touched (an owner question is open)"
	)


func test_the_chain_lands_three_times_and_only_the_last_disc_is_wider_and_led() -> void:
	var s := _fight(&"brood_mother", Vector2(7, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	BossLab.start(w, i, &"leap_chain")
	var atk := BossAi.attack_of(w, i)
	var b := BossAi.entry_of(w, i)
	var radii := {}
	var f := InputFrame.new()
	for t in 600:
		i = w.actors.index_of(aid)
		if w.actors.state[i] == S.RECOVER or w.actors.state[i] == S.MOVE:
			break
		if w.actors.state[i] == S.ACTIVE or w.actors.state[i] == S.WINDUP:
			radii[w.bosses.step[b]] = BossAi.leap_disc(w, i)[1]
		w.actors.set_pos(0, Vector2(7, 0) + Vector2(0, 0.02) * t)
		w.vel = Vector2(0, 0.1)
		w.step(f)
	assert_eq(radii.keys().size(), 3, "three leaps")
	assert_almost_eq(float(radii[0]), 2.2, 0.0001)
	assert_almost_eq(float(radii[1]), 2.2, 0.0001)
	assert_almost_eq(float(radii[2]), 2.64, 0.0001, "the last: 2.2 x 1.2")
	assert_gt(atk.radius_m, 0.0)


func test_the_last_leap_aims_where_the_hero_is_going_and_the_others_where_they_are() -> void:
	var s := _fight(&"brood_mother", Vector2(7, 0))
	var w: World = s[0]
	var i := w.actors.index_of(s[1])
	var atk := _atk(w.boss_tables[BossLab.table_index(w, &"brood_mother")], &"leap_chain")
	var b := BossAi.entry_of(w, i)
	w.vel = Vector2(0, 0.1)
	w.bosses.step[b] = 0
	assert_false(BossHard.leap_target(w, b, atk)[0], "the first leap is not led")
	w.bosses.step[b] = 2
	var led := BossHard.leap_target(w, b, atk)
	assert_true(led[0], "the last is")
	assert_almost_eq((led[1] as Vector2).y, 2.1, 0.001, "0.35 s of 6 m/s ahead")
	assert_almost_eq(BossHard.leap_radius(w, b, atk), 2.64, 0.0001)
	w.bosses.step[b] = 1
	assert_almost_eq(BossHard.leap_radius(w, b, atk), 2.2, 0.0001)
