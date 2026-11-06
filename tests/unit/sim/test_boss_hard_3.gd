extends GutTest
## v0.9.5 BH3 (owner: "we have to modify 1 spell for each that will be hard to dodge"; BOSSES_HARD.md B6, B8-B10):
## the Foundry's Furnace Waves, the Twin Wardens' Crossfire, the Clockwork Judge's Gear Spiral and the Lantern Shade's
## Lights Out. Each test pins the spell's new numbers and plays the answer to it. Every telegraph is at least 0.55 s
## (33 ticks); no damage changed.

const LONG := 1 << 20
const MIN_TICKS := 33
## The test world has no sealed room: the Shade's lanterns stand 5.5 m north, east, south and west of it.
const LAMPS := [Vector2(0, -5.5), Vector2(5.5, 0), Vector2(0, 5.5), Vector2(-5.5, 0)]


func _table(id: StringName) -> BossTable:
	var w := BossLab.world()
	return w.boss_tables[BossLab.table_index(w, id)]


func _atk(t: BossTable, id: StringName) -> BossAttackTable:
	return t.attacks[t.attack_index(id)]


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## The boss picks nothing on its own (no phase list, no cadence, no punish, no walking).
func _hush(w: World, aid: int) -> void:
	var t := BossAi.table_of(w, _i(w, aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0
	t.speed = 0.0


## A world with boss `id` ready at the origin and the hero at `player_at`; [world, boss actor id].
func _fight(id: StringName, player_at: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	_hush(w, w.actors.ids[i])
	return [w, w.actors.ids[i]]


## Steps n ticks keeping the hero at p; returns the HP lost.
func _hold(w: World, p: Vector2, n: int) -> int:
	var hp := w.actors.hp[0]
	for k in n:
		w.actors.set_pos(0, p)
		w.step(InputFrame.new())
	return hp - w.actors.hp[0]


func _ppos(w: World, k: int) -> Vector2:
	return Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])


func _pvel(w: World, k: int) -> Vector2:
	return Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])


## B6 ---------------------------------------------------------------------------------------------------------------


func test_furnace_waves_come_as_two_walls_the_second_0_3_s_after_the_first() -> void:
	var t := _table(&"foundry")
	var atk := _atk(t, &"furnace_waves")
	var p := atk.pattern
	assert_eq(p.kind, BulletPatternTable.Kind.WALL, "walls, not rings")
	assert_true(p.crossing, "a second wall at right angles")
	assert_eq(p.cross_delay_ticks, 18, "the second wall 0.3 s after the first")
	assert_gte(atk.windup_ticks, MIN_TICKS, "telegraph >= 0.55 s")
	assert_eq(atk.windup_ticks, 48, "still 0.8 s")
	assert_eq(atk.damage, 22, "damage unchanged")
	assert_eq(p.waves, 4)
	var gap := p.wave_gap_ticks
	assert_eq(BulletPatterns.wave_at(p, 0), 0, "the first wall leaves at once")
	assert_eq(BulletPatterns.cross_wave_at(p, 0), -1, "the second does not")
	assert_eq(BulletPatterns.wave_at(p, 18), -1)
	assert_eq(BulletPatterns.cross_wave_at(p, 18), 0, "it leaves 18 ticks on")
	assert_eq(BulletPatterns.cross_wave_at(p, 3 * gap + 18), 3, "every wave")
	assert_eq(p.duration_ticks(), 3 * gap + 18 + 1, "the attack covers the last crossing wall")
	assert_gte(atk.active_ticks, p.duration_ticks(), "and stays active for it")


func test_the_two_walls_run_at_right_angles_and_each_keeps_a_gap() -> void:
	var p := _atk(_table(&"foundry"), &"furnace_waves").pattern
	for k in p.waves:
		var a := BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 2.0, 0)
		var b := BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 2.0, 1)
		assert_gt(a[0].size(), 20, "wall A has shots")
		assert_gt(b[0].size(), 20, "wall B has shots")
		for v: Vector2 in a[1]:
			assert_almost_eq(
				v.normalized(), Vector2(1, 0), Vector2(0.01, 0.01), "A marches along the aim"
			)
		for v: Vector2 in b[1]:
			assert_almost_eq(
				v.normalized(), Vector2(0, 1), Vector2(0.01, 0.01), "B at a right angle"
			)
		# Each wall's gap: the widest hole between neighbouring shots (across its line) is the gap, >= 2.4 m.
		var ys: Array = []
		for q: Vector2 in a[0]:
			ys.append(q.y)
		var xs: Array = []
		for q: Vector2 in b[0]:
			xs.append(q.x)
		ys.sort()
		xs.sort()
		assert_gte(_widest(ys) - 0.4, 2.0, "wall A wave %d leaves a lane" % k)
		assert_gte(_widest(xs) - 0.4, 2.0, "wall B wave %d leaves a lane" % k)
	# Both walls together are what the old single call made.
	var all := BulletPatterns.wave_shots(p, 0, Vector2.ZERO, 0, 2.0)
	assert_eq(
		all[0].size(),
		(
			BulletPatterns.wave_shots(p, 0, Vector2.ZERO, 0, 2.0, 0)[0].size()
			+ BulletPatterns.wave_shots(p, 0, Vector2.ZERO, 0, 2.0, 1)[0].size()
		)
	)


func _widest(sorted: Array) -> float:
	var best := 0.0
	for k in range(1, sorted.size()):
		best = maxf(best, float(sorted[k]) - float(sorted[k - 1]))
	return best


func test_one_quadrant_is_never_crossed_by_either_wall() -> void:
	var p := _atk(_table(&"foundry"), &"furnace_waves").pattern
	# Aimed along +x from a body 2 m wide: wall A only ever holds x >= 2, wall B only y >= 2, so the quadrant behind
	# the body (x < 1.9 and y < 1.9) is never struck, however long the shots fly.
	var min_a_x := INF
	var min_b_y := INF
	var spread_a := [INF, -INF]
	var spread_b := [INF, -INF]
	for k in p.waves:
		for q: Vector2 in BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 2.0, 0)[0]:
			min_a_x = minf(min_a_x, q.x)
			spread_a = [minf(spread_a[0], q.y), maxf(spread_a[1], q.y)]
		for q: Vector2 in BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 2.0, 1)[0]:
			min_b_y = minf(min_b_y, q.y)
			spread_b = [minf(spread_b[0], q.x), maxf(spread_b[1], q.x)]
	assert_gte(min_a_x, 1.9, "wall A starts at the body's far edge and marches away")
	assert_gte(min_b_y, 1.9, "wall B too, at a right angle")
	assert_lt(spread_a[0], -6.0, "A spans both sides of the aim line")
	assert_gt(spread_a[1], 6.0)
	assert_lt(spread_b[0], -6.0, "B spans both sides of its line")
	assert_gt(spread_b[1], 6.0)


func test_furnace_waves_live_the_walls_leave_apart_and_the_quadrant_is_safe() -> void:
	var s := _fight(&"foundry", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, _i(w, aid), &"furnace_waves")
	var atk := BossAi.attack_of(w, _i(w, aid))
	_hold(w, Vector2(6, 0), atk.windup_ticks + 1)
	assert_gt(w.projectiles.size(), 0, "the first wall is out")
	for k in w.projectiles.size():
		assert_almost_eq(_pvel(w, k).y, 0.0, 0.0001, "only wall A: along the aim")
	_hold(w, Vector2(6, 0), 18)
	var across := 0
	for k in w.projectiles.size():
		if absf(_pvel(w, k).y) > 0.01:
			across += 1
	assert_gt(across, 20, "0.3 s later wall B is out, at a right angle")
	# The hero behind the body, in the quadrant neither wall crosses, takes nothing through the whole attack.
	var s2 := _fight(&"foundry", Vector2(6, 0))
	var w2: World = s2[0]
	BossLab.start(w2, _i(w2, s2[1]), &"furnace_waves")
	var hp := w2.actors.hp[0]
	var aim_at := BossAi.attack_of(w2, _i(w2, s2[1])).windup_ticks
	_hold(w2, Vector2(6, 0), aim_at)  # the aim follows you until the lock; then the lines are set
	w2.actors.set_pos(0, Vector2(-5, -5))
	for k in 500:
		w2.step(InputFrame.new())
	assert_eq(w2.actors.hp[0], hp, "the uncrossed quadrant is safe")
	# Standing where the boss aimed is not: a later wave's shifted gap (or the crossing wall) finds you.
	var s3 := _fight(&"foundry", Vector2(6, 0))
	var w3: World = s3[0]
	BossLab.start(w3, _i(w3, s3[1]), &"furnace_waves")
	assert_gt(_hold(w3, Vector2(6, 0), 500), 0, "standing still in front is hit")


## B8 ---------------------------------------------------------------------------------------------------------------


func _twins(player_at: Vector2) -> Array:
	var w := BossLab.world()
	w.actors.set_pos(0, player_at)
	var i := BossLab.ready_boss(w, &"twin_wardens", Vector2.ZERO)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	var aid := w.actors.ids[i]
	var pid := w.actors.ids[BossTwin.partner_of(w, i)]
	_hush(w, aid)
	w.actors.set_pos(_i(w, aid), Vector2(-3, 0))
	w.actors.set_pos(_i(w, pid), Vector2(3, 0))
	w.step(InputFrame.new())
	return [w, aid, pid]


func test_crossfire_lines_follow_you_for_1_2_s_at_up_to_60_degrees_a_second() -> void:
	var t := _table(&"twin_wardens")
	for id: StringName in [&"crossfire", &"crossfire_3"]:
		var atk := _atk(t, id)
		assert_eq(atk.lines_ticks, 72, "%s: the lines follow for 1.2 s" % id)
		assert_eq(atk.windup_ticks, 72, "%s: and are drawn that whole time" % id)
		assert_gte(atk.windup_ticks, MIN_TICKS)
		assert_eq(atk.lines_turn_milli, 11378, "%s: 60 degrees a second" % id)
		assert_eq(atk.damage, 22, "%s: damage unchanged" % id)


func test_the_lines_start_on_you_then_the_crossing_follows_at_a_limited_turn() -> void:
	var s := _twins(Vector2(0, -5))
	var w: World = s[0]
	BossLab.start(w, _i(w, s[1]), &"crossfire")
	var i := _i(w, s[1])
	var j := _i(w, s[2])
	var e := BossAi.entry_of(w, i)
	assert_almost_eq(
		w.bosses.pt(e, 0), Vector2(0, -5), Vector2(0.001, 0.001), "crossing on the hero"
	)
	assert_almost_eq(
		w.actors.lock_a[i], Kin.angle_of(Vector2(3, -5)), 1, "the amber line aims at the hero"
	)
	assert_almost_eq(w.actors.lock_a[j], Kin.angle_of(Vector2(-3, -5)), 1, "so does the violet")
	# The hero walks off at 2 m/s: the crossing keeps up with them.
	var a0: int = w.actors.lock_a[i]
	var p := Vector2(0, -5)
	for k in 71:
		p += Vector2(2.0 / 60.0, 0)
		w.actors.set_pos(0, p)
		var before: int = w.actors.lock_a[i]
		w.step(InputFrame.new())
		assert_lte(
			Kin.angle_diff(w.actors.lock_a[i], before), 12, "never more than 60 degrees a second"
		)
	assert_lt(w.bosses.pt(e, 0).distance_to(p), 0.6, "the crossing is on the hero at the end")
	assert_ne(w.actors.lock_a[i], a0, "the line turned")
	# Then they fire along the last aim: the lines no longer move.
	var locked: int = w.actors.lock_a[i]
	var spot := w.bosses.pt(e, 0)
	for k in 30:
		p += Vector2(0.2, 0)
		w.actors.set_pos(0, p)
		w.step(InputFrame.new())
	assert_eq(w.actors.lock_a[i], locked, "locked after 1.2 s")
	assert_eq(w.bosses.pt(e, 0), spot, "and so is the crossing")


func test_a_hero_who_outruns_the_turn_is_not_at_the_crossing() -> void:
	var s := _twins(Vector2(0, -5))
	var w: World = s[0]
	BossLab.start(w, _i(w, s[1]), &"crossfire")
	var e := BossAi.entry_of(w, _i(w, s[1]))
	var p := Vector2(0, -5)
	for k in 71:
		p += Vector2(0.15, 0)  # 9 m/s
		w.actors.set_pos(0, p)
		w.step(InputFrame.new())
	assert_gt(w.bosses.pt(e, 0).distance_to(p), 2.0, "the lines lag behind a hard run")
	var hp := w.actors.hp[0]
	for k in 200:
		w.actors.set_pos(0, p)
		w.step(InputFrame.new())
	assert_lt(w.actors.hp[0], hp, "so the fans find them")


func test_the_crossing_is_drawn_the_whole_1_2_s_and_standing_on_it_is_safe() -> void:
	var s := _twins(Vector2(0, -5))
	var w: World = s[0]
	BossLab.start(w, _i(w, s[1]), &"crossfire")
	for k in 72:
		var tw := BossTwin.state(w, _i(w, s[1]))
		assert_true(
			tw.has("gap") and tw.has("safe"), "the lines and the crossing show at tick %d" % k
		)
		assert_false(BossAi.telegraph(w, _i(w, s[1])).is_empty(), "and the telegraph is up")
		w.actors.set_pos(0, w.bosses.pt(BossAi.entry_of(w, _i(w, s[1])), 0))
		w.step(InputFrame.new())
	var hp := w.actors.hp[0]
	var spot := w.bosses.pt(BossAi.entry_of(w, _i(w, s[1])), 0)
	for k in 240:
		w.actors.set_pos(0, spot)
		w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], hp, "no shot lands on the crossing")


## B9 ---------------------------------------------------------------------------------------------------------------


func test_from_phase_2_the_gear_spiral_is_two_spirals_turning_opposite_ways() -> void:
	var t := _table(&"clockwork_judge")
	assert_eq(_atk(t, &"gear_spiral").pattern.counter_arms, 0, "phase 1 is unchanged: one spiral")
	for id: StringName in [&"gear_spiral_2", &"gear_spiral_3"]:
		var atk := _atk(t, id)
		var p := atk.pattern
		assert_gt(p.counter_arms, 0, "%s: a second spiral" % id)
		assert_lt(p.spin_milli * p.counter_spin_milli, 0, "%s: the other way round" % id)
		assert_gte(atk.windup_ticks, MIN_TICKS, "%s: telegraph >= 0.55 s" % id)
		assert_eq(atk.damage, 22, "%s: damage unchanged" % id)
		var shots := BulletPatterns.wave_shots(p, 3, Vector2.ZERO, 0, 1.5)
		assert_eq(shots[0].size(), p.arms + p.counter_arms, "%s: both spirals fire every wave" % id)


## The widest arc (metres between shot edges) left open on the ring R metres out, over every moment of the pattern,
## counting the shots within 0.8 m of the ring (a hero's step either side).
func _narrowest_path(p: BulletPatternTable, ring_m: float) -> float:
	var shots: Array = []  # [wave tick, position, velocity]
	for k in p.waves:
		var ws := BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 1.5)
		for n in ws[0].size():
			shots.append([k * p.wave_gap_ticks, ws[0][n], ws[1][n]])
	var narrowest := INF
	var end := p.waves * p.wave_gap_ticks + int(ring_m / p.speed) + 20
	for now in range(int(ring_m / p.speed), end, 4):
		var angles: Array = []
		for sh in shots:
			var age: int = now - sh[0]
			if age < 0 or age > p.life_ticks:
				continue
			var at: Vector2 = sh[1] + sh[2] * age
			if absf(at.length() - ring_m) <= 0.8:
				angles.append(atan2(at.y, at.x))
		if angles.size() < 3:
			continue
		angles.sort()
		var widest: float = TAU - (angles[angles.size() - 1] - angles[0])
		for n in range(1, angles.size()):
			widest = maxf(widest, angles[n] - angles[n - 1])
		narrowest = minf(narrowest, widest * ring_m - 2.0 * p.radius_m)
	return narrowest


func test_the_two_spirals_gaps_still_leave_a_path_at_least_1_6_m_wide() -> void:
	var t := _table(&"clockwork_judge")
	for id: StringName in [&"gear_spiral_2", &"gear_spiral_3"]:
		var p := _atk(t, id).pattern
		for ring in [3.0, 5.0, 7.0, 9.0, 11.0]:
			var open := _narrowest_path(p, ring)
			gut.p("narrowest path %s %.0f m out: %.2f m" % [id, ring, open])
			assert_gte(
				open,
				HardRules.MIN_SPIRAL_PATH_M,
				"%s: %.0f m out the narrowest gap is %.2f m" % [id, ring, open]
			)


func test_content_rejects_a_counter_spiral_that_turns_the_same_way() -> void:
	var d := BulletPatternDefinition.new()
	d.kind = BulletPatternDefinition.Kind.SPIRAL
	d.look = &"gear_spark"
	d.arms = 2
	d.spin_dps = 80.0
	d.counter_arms = 2
	d.counter_spin_dps = 80.0
	var bad := d.validate()
	var codes := []
	for v in bad:
		codes.append(v.code)
	assert_has(codes, &"range", "a counter spiral must turn the other way")
	d.counter_spin_dps = -80.0
	codes = []
	for v in d.validate():
		codes.append(v.code)
	assert_does_not_have(codes, &"range", "the other way is fine")


## B10 --------------------------------------------------------------------------------------------------------------


func _dark(p: Vector2) -> Array:
	var s := _fight(&"lantern_shade", p)
	var w: World = s[0]
	_hold(w, p, 2)
	BossLab.start(w, _i(w, s[1]), &"lights_out")
	_hold(w, p, 241)
	return s


func test_lanterns_burn_4_s_the_dark_lasts_9_s_and_each_snuff_puts_out_two() -> void:
	var t := _table(&"lantern_shade")
	assert_eq(t.lamp_ticks, 240, "a lantern burns 4 s (was 6)")
	assert_eq(t.dark_hold_ticks, 540, "the dark lasts 9 s (was 8)")
	assert_gt(t.sig_every_ticks, t.dark_hold_ticks, "and still lifts before the next Lights Out")
	for id: StringName in [&"snuff", &"snuff_3"]:
		var atk := _atk(t, id)
		assert_eq(atk.snuff_count, 2, "%s puts out the 2 nearest lit lanterns (was 1)" % id)
		assert_eq(atk.damage, 30, "%s: damage unchanged" % id)
		assert_gte(atk.lock_ticks, MIN_TICKS, "%s: lock >= 0.55 s" % id)
		assert_gte(atk.windup_ticks, MIN_TICKS)
	for id: StringName in [&"lights_out", &"lights_out_3"]:
		assert_gte(_atk(t, id).windup_ticks, MIN_TICKS)


func test_a_snuff_leaves_the_two_farthest_lanterns_lit_and_you_can_relight_the_rest() -> void:
	var p := LAMPS[1] + Vector2(-1.5, 0.5)
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var t := BossAi.table_of(w, _i(w, s[1]))
	BossShade.snuff(w, _atk(t, &"snuff"), p)
	var lit: Array = []
	for k in 4:
		lit.append(w.bosses.lamp_t[k] > 0)
	assert_eq(
		lit,
		[true, false, false, true],
		"east and south (the two nearest) are out, north and west burn"
	)
	# If fewer than two are lit, it puts out what there is.
	var lt := w.bosses.lamp_t
	lt.fill(0)
	lt[3] = 100
	w.bosses.lamp_t = lt
	BossShade.snuff(w, _atk(t, &"snuff"), p)
	assert_eq(w.bosses.lamp_t[3], 0, "the last one goes too")
	# The answer: walk to a dead lantern and it burns again for 4 s.
	_hold(w, LAMPS[1] + Vector2(-1.0, 0), 1)
	assert_eq(w.bosses.lamp_t[1], 240, "passing within reach relights it for 4 s")


func test_in_the_dark_four_seconds_after_it_falls_every_lantern_has_burnt_out() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	_hold(w, Vector2(-1.5, -1.5), 239)
	assert_eq(w.bosses.lamp_t[0], 1, "alight a tick before 4 s")
	_hold(w, Vector2(-1.5, -1.5), 1)
	for k in 4:
		assert_eq(w.bosses.lamp_t[k], 0, "lantern %d out at 4 s" % k)
	_hold(w, Vector2(-1.5, -1.5), 299)
	assert_true(BossShade.dark(w), "still dark at 9 s")
	_hold(w, Vector2(-1.5, -1.5), 2)
	assert_false(BossShade.dark(w), "the dark lifts after 9 s")
