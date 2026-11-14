extends GutTest
## v0.4.0 TU (owner D8) through the real game (main.tscn, input only: the sticks and the trigger): the hero fights the
## floor's enemies until the kills earn a heal orb.
## v0.11.0 F3 (owner's playtest §6): with no card at all, kills fill the meter and an orb drops; the view draws it;
## walking onto it heals a hurt hero and starts the 30 s cooldown, during which no further kill earns anything.

const MAX_FRAMES := 30000


func _stick(e: E2e, x_axis: JoyAxis, y_axis: JoyAxis, dir: Vector2) -> void:
	var c := InputLatch.C45
	e.joy_axis(x_axis, (dir.x + dir.y) * c)
	e.joy_axis(y_axis, -(dir.y - dir.x) * c)


func after_each() -> void:
	Input.action_release(&"primary")


func test_kills_earn_an_orb_with_no_card_and_a_pickup_starts_the_cooldown() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var r := main.driver.reader
	assert_eq(w.stat_cards.size(), 0, "no card in this run")
	var nav := NavField.new()
	nav.build(E2e.walk_walls(w, w.player_pos()))  # v0.5.5 AR: around the arenas
	var trigger := false
	for k in MAX_FRAMES:
		if not r.heal_orbs().is_empty() or r.player_dead():
			break
		var best := -1
		var best_d := INF
		for i in range(1, r.actor_count()):
			if not r.actor_dead(i):
				var d := r.actor_pos(i).distance_to(r.player_pos())
				if d < best_d:
					best_d = d
					best = i
		if best >= 0:
			var to := r.actor_pos(best) - r.player_pos()
			if k % 20 == 0:
				nav.flood(r.actor_pos(best))
			var walk := to.normalized() * 0.4
			if to.length() > 1.5:
				walk = to.normalized() if to.length() < 3.0 else nav.direction(r.player_pos())
			_stick(e, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, walk)
			_stick(e, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, to.normalized())
			if trigger:
				e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
				trigger = false
			elif to.length() < 2.0:
				e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
				trigger = true
		await e.frames(1)
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		e.joy_axis(axis, 0.0)
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	assert_eq(w.stat_cards.size(), 0, "still no card when the orb appeared")
	assert_false(
		r.heal_orbs().is_empty(),
		(
			"kills earned an orb with no card (kills %d, dead %s, tick %d)"
			% [w.kills, r.player_dead(), w.tick]
		)
	)
	if r.heal_orbs().is_empty():
		return
	await e.frames(2)
	assert_eq(r.heal_orbs().size(), 1, "one orb, at most")
	assert_eq(main.view.heal_orbs.count(), 1, "the view draws it")
	var id := r.heal_orb_ids()[0]
	var seq := r.last_event_seq()
	# TEST HELPER (labelled): the hero is hurt, so walking onto it (input only) heals; a hero at full HP leaves it lying.
	w.actors.hp[0] = maxi(1, w.actors.max_hp[0] / 2)
	assert_true(await e.walk_to(r.heal_orbs()[0], 0.3), "walked onto it")
	await e.frames(2)
	assert_false(r.heal_orb_ids().has(id), "the hurt hero took it")
	var healed := 0
	for ev in r.events_since(seq):
		if ev.kind == SimEvent.Kind.HEAL and ev.effect_id == HealOrbs.EFFECT:
			healed += ev.amount_applied
	assert_eq(healed, w.actors.max_hp[0] / 5, "a fifth of max HP")
	var ready := w.orbs.ready_tick
	assert_between(
		ready - w.tick, 1500, w.reward_table.heal_orb_cooldown_ticks, "the cooldown runs"
	)
	assert_eq(r.heal_orbs().size(), 0, "no orb during the cooldown")
