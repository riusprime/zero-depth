extends GutTest
## The Gatekeeper's Shock Lanes rise out of its edge toward you and run outward one slice a tick: the sim hurts the
## slice that rises, so what is drawn is what hits (EI-07), and the wave reaches the lane's end in about a second.

const LONG := 1 << 20


func _fight(player_at: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func _atk(w: World, aid: int) -> BossAttackTable:
	return BossAi.attack_of(w, w.actors.index_of(aid))


func test_the_lanes_start_at_the_bosses_edge_and_run_through_your_point() -> void:
	var s := _fight(Vector2(10, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	BossLab.start(w, i, &"shock_lanes")
	var lanes := BossDodge.row_lanes_of(w, i, 0)
	assert_eq(lanes.size(), 3, "one through you and one each side")
	var first: Obb = lanes[0]
	var start := first.center - first.axis_u * first.half.x
	assert_almost_eq(start.distance_to(w.actors.pos(i)), w.actors.radius[i], 0.01, "from its edge")
	assert_lt(start.distance_to(w.actors.pos(i)) - w.actors.radius[i], 1.5, "next to the boss")
	assert_almost_eq(absf(first.center.y), 0.0, 0.05, "aimed at your point")
	assert_gt(first.axis_u.x, 0.99, "outward")


func test_the_wave_runs_out_in_about_a_second_in_data() -> void:
	var s := _fight(Vector2(10, 0))
	var w: World = s[0]
	BossLab.start(w, w.actors.index_of(s[1]), &"shock_lanes")
	var atk := _atk(w, s[1])
	var seconds := atk.lane_wave_ticks() / 60.0
	assert_between(seconds, 0.8, 1.0, "the wave reaches the lane's end in %.2f s" % seconds)


func test_the_slices_run_outward_without_a_gap_from_the_boss_to_the_lane_end() -> void:
	var s := _fight(Vector2(10, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	BossLab.start(w, i, &"shock_lanes")
	var atk := _atk(w, aid)
	var lane: Obb = BossDodge.row_lanes_of(w, i, 0)[0]
	var start := lane.center - lane.axis_u * lane.half.x
	var waves := atk.lane_wave_ticks()
	var reached := 0.0
	var prev_far := -1.0
	for local in waves:
		var slice := BossDodge.lane_slice(lane, atk, local)
		assert_not_null(slice, "a slice on tick %d" % local)
		var near := (slice.center - start).dot(lane.axis_u) - slice.half.x
		var far := near + slice.half.x * 2.0
		if local == 0:
			assert_lt(near, 0.01, "the first slice starts at the boss's edge")
		else:
			assert_almost_eq(
				near, prev_far, 0.01, "slice %d begins where %d ended" % [local, local - 1]
			)
		assert_gt(far, near, "slice %d moves outward" % local)
		prev_far = far
		reached = far
	assert_almost_eq(reached, lane.half.x * 2.0, 0.01, "the last slice reaches the lane's end")
	assert_null(BossDodge.lane_slice(lane, atk, waves), "nothing rises after the wave ran out")
	assert_null(BossDodge.lane_slice(lane, atk, -1), "nothing rises before the strike")


func test_you_are_hurt_when_the_wave_reaches_you_not_before() -> void:
	var s := _fight(Vector2(12, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	BossLab.start(w, i, &"shock_lanes")
	var atk := _atk(w, aid)
	CombatLab.idle(w, atk.windup_ticks)  # to the first strike tick
	var hp0 := w.actors.hp[0]
	var hurt_at := -1
	for local in atk.lane_wave_ticks() + 4:
		if w.actors.hp[0] < hp0 and hurt_at < 0:
			hurt_at = local
		CombatLab.idle(w, 1)
	assert_gt(hurt_at, 0, "you are hurt")
	var along := 12.0 - w.actors.radius[i]
	var due := int(along / atk.speed)
	assert_between(
		hurt_at, due - 4, due + 4, "when the wave reaches %.1f m out (tick %d)" % [along, due]
	)
	assert_gt(hurt_at, 10, "not at the start of the strike, with the first spikes at the boss")
