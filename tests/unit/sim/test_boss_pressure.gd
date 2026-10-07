extends GutTest
## Faster, smarter bosses (PLAN v0.3.5 AI; owner line F3): +30 % move speed, windups that track the player until
## their last 12 ticks, the attack after a dash aimed at its landing point, shorter recoveries (test_boss_challenge)
## and a gap-closer when the player stays out of reach for 2 s.

const S := EnemyAi.State
## The speeds before v0.3.5 (data/bosses, v0.3.0), in metres per second.
const OLD_SPEED := {&"gatekeeper": 1.5, &"brood_mother": 2.4, &"siege_engine": 1.1}


func test_bosses_move_thirty_percent_faster() -> void:
	for t in BossLab.tables():
		assert_almost_eq(t.speed * 60.0, OLD_SPEED[t.id] * 1.3, 0.001, String(t.id))


func test_the_new_numbers_compile() -> void:
	for t in BossLab.tables():
		assert_eq(t.commit_ticks, 12, "%s commits 12 ticks before it strikes" % t.id)
		assert_eq(t.dash_read_ticks, 30, String(t.id))
		assert_eq(t.gap_ticks, 120, "%s: 2 s out of reach" % t.id)
		assert_gte(t.gap_attack, 0, "%s has a gap-closer" % t.id)


func _boss(id: StringName, player_at: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	return [w, i, w.actors.ids[i]]


func test_a_windup_tracks_the_player_then_commits() -> void:
	var s := _boss(&"gatekeeper", Vector2(8, 0))
	var w: World = s[0]
	var aid: int = s[2]
	var t := BossAi.table_of(w, s[1])
	var k := t.attack_index(&"shock_lanes")
	BossLab.start(w, s[1], &"shock_lanes")
	var windup := t.attacks[k].windup_ticks
	var aims := []
	for n in windup:
		var i := w.actors.index_of(aid)
		w.actors.set_pos(0, Vector2(8, 0).rotated(n * 0.02))  # the player circles the boss
		w.step(InputFrame.new())
		i = w.actors.index_of(aid)
		if w.actors.state[i] != S.WINDUP:
			break
		aims.append([w.actors.state_t[i], w.actors.lock_a[i]])
	var early := []
	var late := []
	for pair: Array in aims:
		(late if pair[0] >= windup - t.commit_ticks else early).append(pair[1])
	assert_gt(early.size(), 10)
	assert_ne(early[0], early[-1], "it follows the player while it winds up")
	for a: int in late:
		assert_eq(a, late[0], "committed for the last %d ticks" % t.commit_ticks)


func test_after_a_dash_the_aim_goes_to_its_landing_point() -> void:
	var s := _boss(&"gatekeeper", Vector2(8, 0))
	var w: World = s[0]
	var aid: int = s[2]
	w.actors.cd[s[1]] = 9999
	var dash := InputFrame.make(Vector2i(0, 127), 0, 0, 0, InputFrame.DASH)
	w.step(dash)
	var landing := Vector2.ZERO
	for n in 30:
		var b := BossAi.entry_of(w, w.actors.index_of(aid))
		if w.is_dashing():
			landing = BossChallenge.dash_landing(w)
		w.step(InputFrame.new())
		if not w.is_dashing() and landing != Vector2.ZERO:
			assert_gt(w.bosses.dash_t[b], 0, "it remembers the dash for a while")
			break
	var b := BossAi.entry_of(w, w.actors.index_of(aid))
	assert_almost_eq(w.bosses.dash_x[b], landing.x, 0.05)
	assert_almost_eq(w.bosses.dash_y[b], landing.y, 0.05)
	# The player has walked on since; an aimed attack started now goes at the landing point all the same.
	w.actors.set_pos(0, landing + Vector2(0, 3))
	var aim := BossChallenge.aim_point(w, b, BossAttackTable.Move.LANES)
	assert_eq(aim, Vector2(w.bosses.dash_x[b], w.bosses.dash_y[b]))
	CombatLab.idle(w, 40)
	b = BossAi.entry_of(w, w.actors.index_of(aid))
	assert_eq(w.bosses.dash_t[b], 0, "and forgets it after half a second")


func test_out_of_reach_for_two_seconds_brings_the_gap_closer() -> void:
	for id: StringName in [&"gatekeeper", &"brood_mother", &"siege_engine"]:
		var t := BossLab.tables()[BossLab.table_index(BossLab.world(), id)]
		var far := t.radius_m + t.gap_distance_m + 1.0
		var s := _boss(id, Vector2(far, 0))
		var w: World = s[0]
		var aid: int = s[2]
		var started := -1
		for n in 300:
			var i := w.actors.index_of(aid)
			w.actors.set_pos(0, w.actors.pos(i) + Vector2(far, 0))  # always just out of reach
			w.actors.cd[i] = 9999  # no other attack
			w.step(InputFrame.new())
			i = w.actors.index_of(aid)
			var b := BossAi.entry_of(w, i)
			if w.actors.state[i] == S.WINDUP and w.bosses.attack[b] == t.gap_attack:
				started = n
				break
		assert_between(started, t.gap_ticks - 2, t.gap_ticks + 2, "%s: after 2 s" % id)


func test_coming_into_reach_resets_the_gap_clock() -> void:
	var s := _boss(&"gatekeeper", Vector2(9, 0))
	var w: World = s[0]
	var b := BossAi.entry_of(w, s[1])
	for n in 100:
		w.actors.cd[w.actors.index_of(s[2])] = 9999
		w.actors.set_pos(0, w.actors.pos(w.actors.index_of(s[2])) + Vector2(9, 0))
		w.step(InputFrame.new())
	assert_gt(w.bosses.gap_t[b], 90)
	w.actors.set_pos(0, w.actors.pos(w.actors.index_of(s[2])) + Vector2(2, 0))
	w.step(InputFrame.new())
	assert_eq(w.bosses.gap_t[b], 0)
