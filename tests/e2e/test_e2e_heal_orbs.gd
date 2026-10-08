extends GutTest
## v0.4.0 TU (owner D8) through the real game (main.tscn, input only: the sticks and the trigger): the hero fights
## the floor's enemies until a kill drops a heal orb; the view draws it; walking onto it heals a hurt hero (or, at
## full HP, leaves it lying).
## v0.5.5 EC (owner D9): orbs drop only with the Lifesprout stat card. First, with no card, kills drop none; then
## the card is granted (a labelled test helper: that chests offer it is test_card_pool_reach, that a picked card
## applies is test_e2e_rewards) and the fight goes on until an orb drops.

const MAX_FRAMES := 14000


func _stick(e: E2e, x_axis: JoyAxis, y_axis: JoyAxis, dir: Vector2) -> void:
	var c := InputLatch.C45
	e.joy_axis(x_axis, (dir.x + dir.y) * c)
	e.joy_axis(y_axis, -(dir.y - dir.x) * c)


func after_each() -> void:
	Input.action_release(&"primary")


func test_a_kill_drops_a_heal_orb_and_walking_onto_it_heals() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var r := main.driver.reader
	var nav := NavField.new()
	nav.build(E2e.walk_walls(w, w.player_pos()))  # v0.5.5 AR: around the arenas
	var trigger := false
	var kills_without := -1
	for k in MAX_FRAMES:
		if not r.heal_orbs().is_empty() or r.player_dead():
			break
		if kills_without < 0 and w.kills >= 5:
			kills_without = w.kills
			assert_true(r.heal_orbs().is_empty(), "D9: no Lifesprout, no orb from 5 kills")
			# TEST HELPER (labelled): the Lifesprout card, as a chest pick would give it.
			Stats.add_card(w, Stats.Stat.LIFESPROUT, Stats.Rarity.COMMON)
			assert_eq(Stats.heal_orb_chance(w), 100, "the card: 10 % of kills")
			# More copies up to the cap, so the fight needs few kills on any floor layout (v0.5.9 themed rooms).
			for _n in 4:
				Stats.add_card(w, Stats.Stat.LIFESPROUT, Stats.Rarity.COMMON)
			assert_eq(Stats.heal_orb_chance(w), 300, "stacked copies: the 30 % cap")
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
				e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
				trigger = false
			elif to.length() < 2.0:
				e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
				trigger = true
		await e.frames(1)
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		e.joy_axis(axis, 0.0)
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	assert_gte(kills_without, 5, "five kills before the card")
	assert_false(
		r.heal_orbs().is_empty(),
		(
			"with the card a kill dropped a heal orb (kills %d, before the card %d, dead %s, tick %d)"
			% [w.kills, kills_without, r.player_dead(), w.tick]
		)
	)
	if r.heal_orbs().is_empty():
		return
	await e.frames(2)
	assert_gte(main.view.heal_orbs.count(), 1, "the view draws it")
	var id := r.heal_orb_ids()[0]
	var seq := r.last_event_seq()
	assert_true(await e.walk_to(r.heal_orbs()[0], 0.3), "walked onto it")
	if r.heal_orb_ids().has(id):
		assert_eq(r.player_hp(), r.player_max_hp(), "only a hero at full HP leaves it lying")
	else:
		var healed := 0
		for ev in r.events_since(seq):
			if ev.kind == SimEvent.Kind.HEAL and ev.effect_id == HealOrbs.EFFECT:
				healed += ev.amount_applied
		assert_gt(healed, 0, "taking it healed the hurt hero")
