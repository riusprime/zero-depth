extends GutTest
## The four-slash combo in the real game (v0.3.0 L11), through real input only: the left stick walks the wanderer
## up to the nearest enemy, the right stick aims at it, and the left trigger swings again the moment each swing
## ends (inside the combo window). Read through WorldReader: four swings in a row are combo steps 0, 1, 2, 3, each
## lands a melee hit, and the fourth (the spinning finisher) hits for its 24 damage (+15 % on the Blade build).

const MAX_FRAMES := 5400
const CLOSE_M := 1.5


func after_each() -> void:
	Input.action_release(&"primary")


func _nearest_enemy(r: WorldReader) -> int:
	var best := -1
	var best_d := INF
	for i in range(1, r.actor_count()):
		if r.actor_dead(i):
			continue
		var d := r.actor_pos(i).distance_to(r.player_pos())
		if d < best_d:
			best_d = d
			best = i
	return best


## Left (move) or right (aim) stick toward a direction on the sim plane (the inverse of InputLatch.screen_to_sim).
func _stick(e: E2e, x_axis: JoyAxis, y_axis: JoyAxis, dir: Vector2) -> void:
	var c := InputLatch.C45
	e.joy_axis(x_axis, (dir.x + dir.y) * c)
	e.joy_axis(y_axis, -(dir.y - dir.x) * c)


func test_four_presses_in_the_window_are_the_four_slashes() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var r := WorldReader.new(w)
	var nav := NavField.new()
	nav.build(w.walls)
	# One record per swing: [combo step, melee HIT amounts, DAMAGE dealt].
	var swings: Array = []
	var last_t := 0
	var last_step := -1
	var seq := r.last_event_seq()
	var trigger := false
	var found := -1
	for k in MAX_FRAMES:
		var target := _nearest_enemy(r)
		var p := r.player_pos()
		if target >= 0:
			var to := r.actor_pos(target) - p
			if k % 20 == 0:
				nav.flood(r.actor_pos(target))
			# v0.3.0 L29: the swing goes the way the wanderer faces, so close in, a light push keeps it facing the enemy.
			var walk := to.normalized() * 0.4
			if to.length() > CLOSE_M:
				walk = to.normalized() if to.length() < 3.0 else nav.direction(p)
			_stick(e, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, walk)
			_stick(e, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, to.normalized())
			# Swing again as soon as the last swing ends (the combo window is open), while the enemy is close.
			if trigger:
				e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
				trigger = false
			elif r.swing_tick() == 0 and to.length() < CLOSE_M + 0.5:
				e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
				trigger = true
		await e.frames(1)
		if r.player_dead():
			break
		var t := r.swing_tick()
		if t > 0 and (last_t == 0 or t < last_t or r.combo_step() != last_step):
			swings.append([r.combo_step(), [], 0])
		last_t = t
		last_step = r.combo_step() if t > 0 else -1
		for ev in r.events_since(seq):
			seq = ev.seq
			if swings.is_empty() or ev.owner_id != r.actor_id(0) or ev.effect_id != &"":
				continue
			if (ev.tags & SimEvent.TAG_MELEE) == 0:
				continue
			if ev.kind == SimEvent.Kind.HIT:
				# v0.4.0 TU: a crit (5 %, v0.4.0 BS) is ×1.5 on top; the slash amounts below are the plain ones.
				if (ev.tags & SimEvent.TAG_CRIT) == 0:
					swings.back()[1].append(ev.amount)
			elif ev.kind == SimEvent.Kind.DAMAGE:
				swings.back()[2] += ev.amount
		found = _four_in_a_row(swings)
		if found >= 0 and r.swing_tick() == 0:
			break
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		e.joy_axis(axis, 0.0)
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	gut.p("swings (step, hits, damage): %s" % [swings])
	assert_gte(found, 0, "four swings in a row were steps 0, 1, 2, 3 and each landed")
	if found < 0:
		return
	var four: Array = swings.slice(found, found + 4)
	assert_eq(four.map(func(s: Array) -> int: return s[0]), [0, 1, 2, 3])
	# The Blade build's +15 % (v0.3.0 L16), its remainder carried hit to hit: 10 -> 11 or 12, 12 -> 13 or 14, 24 -> 27
	# or 28.
	assert_between((four[0][1] as Array).max(), 11, 12, "the slash")
	assert_between((four[1][1] as Array).max(), 11, 12, "the backhand")
	assert_between((four[2][1] as Array).max(), 13, 14, "the thrust")
	assert_between((four[3][1] as Array).max(), 27, 28, "the finisher hits for 24 + 15 %")
	assert_gt(four[3][2], 0, "and its hit took HP off an enemy")


## The index of the first run of four swings that are steps 0..3 and each landed a melee HIT (-1 if none).
func _four_in_a_row(swings: Array) -> int:
	for s in range(swings.size() - 3):
		var ok := true
		for k in 4:
			var rec: Array = swings[s + k]
			if rec[0] != k or (rec[1] as Array).is_empty():
				ok = false
				break
		if ok and swings[s + 3][2] > 0:
			return s
	return -1
