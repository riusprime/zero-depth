# gdlint: disable=max-public-methods
extends GutTest
## v0.5.0 EV (PLAN R4; PD-05): the six curses, each one's effect where the sim computes it; threat T (one per curse,
## its peak, the carry to the next floor, the run's record per floor); cursed chest offers (how many, what they hold,
## taking the cursed card takes the curse, the other cards are clean); the shop's cleanse hook; and the Ambush Cache
## fight, plus an elite curse floor, pass the readable-cause check with the same bars as test_readable_cause.gd.

const SEED := 515


func _world(curses: Array = [], seed_value: int = SEED) -> World:
	return EventLab.world(seed_value, 1, &"blade", curses)


func test_the_shipped_curses() -> void:
	var w := _world()
	var ids := []
	for c in w.ev.curses:
		ids.append(String(c.id))
		assert_eq(c.threat, 1, "%s raises T by 1" % c.id)
	ids.sort()
	assert_eq(
		ids, ["leaky_core", "marked_hunt", "price_gouge", "swarm_call", "swift_foes", "withering"]
	)


func test_swift_foes_enemies_move_15_percent_faster() -> void:
	var steps := []
	var curses := EventCompiler.compile_curses(EventLab.repo())
	for cursed in [false, true]:
		var w := CombatLab.world()
		Events.setup(w, [] as Array[EventTable], curses, null)
		if cursed:
			Curses.add(w, EventLab.curse_index(w, &"swift_foes"))
		var id := w.add_enemy(ActorStore.Kind.WARDEN, Vector2(8, 0))
		w.actors.invuln[0] = 1 << 20
		CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 4)
		var i := w.actors.index_of(id)
		var a := w.actors.pos(i)
		CombatLab.idle(w, 10)
		steps.append(w.actors.pos(w.actors.index_of(id)).distance_to(a))
	gut.p("a Warden walks %.3f m in 10 ticks, %.3f m cursed" % steps)
	assert_gt(steps[0], 0.05, "it walked")
	assert_almost_eq(steps[1] / steps[0], 1.15, 0.02, "x1.15")


func test_withering_cuts_both_regen_sources_by_20_percent() -> void:
	var w := _world([&"withering"])
	var v := _world()
	assert_eq(PlayerRegen.rate_permille(w), PlayerRegen.rate_permille(v) * 800 / 1000)
	assert_eq(Curses.regen(w, 50), 40)


func test_leaky_core_heat_decays_twice_as_fast() -> void:
	var drops := []
	for curses in [[], [&"leaky_core"]]:
		var w := _world(curses)
		w.heat.milli = 40 * HeatTable.MILLI  # test setup
		w.heat.idle = w.heat.table.decay_delay_ticks + 1
		var before := w.heat.milli
		Heat.advance(w)
		drops.append(before - w.heat.milli)
	assert_eq(drops[1], drops[0] * 2)


func test_swarm_call_brings_one_more_enemy_per_arrival() -> void:
	var counts := []
	for curses in [[], [&"swarm_call"]]:
		var w := _world(curses)
		w.actors.invuln[0] = 1 << 20
		w.actors.set_pos(0, w.floor_layout.rooms[w.ev.room[0]].get_center())  # a room with spawn points around
		var n := 0
		for t in 400:
			var before := w.actors.size()
			w.step(InputFrame.new())
			if w.actors.size() > before:
				n = w.actors.size() - before
				break
		counts.append(n)
	assert_gt(counts[0], 0, "a spawn arrived")
	assert_eq(counts[1], counts[0] + 1, "one more in the arrival")


func test_price_gouge_raises_chest_shrine_and_event_prices_by_25_percent() -> void:
	var w := _world([&"price_gouge"])
	var v := _world()
	for i in w.rewards.size():
		assert_eq(Rewards.price_of(w, i), (v.rewards.price[i] * 1250 + 500) / 1000)
	assert_eq(Gamble.price(w), (Gamble.price(v) * 1250 + 500) / 1000)
	assert_eq(Curses.price(w, 100), 125, "shops call the same hook")
	EventLab.set_event(w, &"scrap_heap")
	assert_eq(Events.shard_cost(w, 0, 0), 44, "35 shards x 1.25, half up")
	var chest := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
	if chest >= 0:
		w.shards = Rewards.price_of(w, chest) - 1  # test setup: one short of the cursed price
		assert_false(Rewards.can_afford(w, chest))


func test_marked_hunt_makes_about_12_percent_of_spawns_elite() -> void:
	var w := _world([&"marked_hunt"])
	var elites := 0
	var n := 3000
	for k in n:
		var id := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(k % 7, 0))
		var i := w.actors.index_of(id)
		var hp := w.actors.max_hp[i]
		Curses.maybe_elite(w, i)
		if Curses.is_elite(w, id):
			elites += 1
			assert_eq(w.actors.max_hp[i], hp * 2, "an elite has double HP")
	assert_between(elites, 290, 430, "about 12 % of 3000")
	var v := _world()
	var id := v.add_enemy(ActorStore.Kind.CHARGER, Vector2.ZERO)
	Curses.maybe_elite(v, v.actors.index_of(id))
	assert_false(Curses.is_elite(v, id), "no elites without the curse")


func test_threat_counts_curses_and_carries_to_the_next_floor() -> void:
	var w := _world()
	assert_eq(Curses.threat(w), 0)
	assert_true(Curses.add(w, 2))
	assert_false(Curses.add(w, 2), "never the same curse twice")
	assert_true(Curses.add(w, 4))
	assert_eq(Curses.threat(w), 2)
	assert_eq(w.threat_peak, 2)
	assert_true(Curses.cleanse(w), "the shop's hook lifts one")
	assert_eq(w.curses_owned, PackedInt32Array([2]), "the latest goes first")
	assert_eq(Curses.threat(w), 1)
	assert_eq(w.threat_peak, 2, "the peak keeps what was chosen")
	assert_true(Curses.cleanse(w, 2))
	assert_false(Curses.cleanse(w), "nothing left to lift")
	Curses.add(w, 1)
	var run := RunState.start(
		SEED, ContentCompiler.compile_run(EventLab.repo().get_def(&"run", &"three_floors"))
	)
	run.finish_floor(w)
	assert_eq(run.threat_by_floor, PackedInt32Array([1]), "T recorded per floor (M-THREAT)")
	var next := World.new(1, PlayerTable.starting_values())
	RunCarry.apply(next, run.carry)
	assert_eq(next.curses_owned, PackedInt32Array([1]), "curses carry")
	assert_eq(next.threat_peak, 2, "and so does the peak")


func test_cursed_chest_offers_hold_one_cursed_epic_card() -> void:
	var cursed := 0
	var rolled := 0
	for s in 120:
		var w := _world([], 900 + s)
		for i in w.rewards.size():
			if w.rewards.kind[i] != RewardStore.Kind.CHEST:
				continue
			w.rewards.set_offer(i, Offers.roll(w, i))
			Curses.on_offer_rolled(w, i)
			rolled += 1
			var offer := w.rewards.offer_of(i)
			var marks := 0
			for k in offer.size():
				marks += 1 if Curses.offer_curse(w, w.rewards.ids[i], k) >= 0 else 0
			if marks == 0:
				continue
			cursed += 1
			assert_eq(marks, 1, "one cursed card")
			var card := offer[Curses.CURSED_SLOT]
			assert_eq(Offers.type_of(card), Offers.STAT, "a stat card")
			assert_eq(Offers.rarity_of(card), Stats.Rarity.EPIC, "always epic")
			for k in range(1, offer.size()):
				var other := offer[k]
				var same := (
					Offers.type_of(other) == Offers.STAT
					and Offers.stat_of(other) == Offers.stat_of(card)
				)
				assert_false(same, "its stat isn't offered twice")
		for i in w.rewards.size():
			assert_true(
				(
					w.rewards.kind[i] == RewardStore.Kind.CHEST
					or w.ev.cursed_ids.find(w.rewards.ids[i]) < 0
				),
				"altars are never cursed"
			)
	gut.p("cursed chest offers: %d of %d" % [cursed, rolled])
	assert_between(cursed * 1000 / maxi(1, rolled), 150, 350, "about 25 % of chests")


func test_taking_the_cursed_card_takes_its_curse_and_the_others_are_clean() -> void:
	for slot in [0, 1]:
		var w := _world()
		var chest := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
		w.ev.force_curse = true  # the dev route (DebugApi.curse_next_chest)
		w.shards = 999  # test setup
		w.actors.set_pos(0, w.rewards.pos(chest))
		var f := InputFrame.new()
		f.pressed = InputFrame.INTERACT
		w.step(f)
		assert_gte(w.choosing, 0, "the chest opened")
		var curse := Curses.offer_curse(w, w.choosing, 0)
		assert_gte(curse, 0, "forced cursed")
		assert_false(w.ev.force_curse, "once")
		EventLab.pick(w, slot + 1)
		if slot == 0:
			assert_eq(
				w.curses_owned, PackedInt32Array([curse]), "the cursed card brought its curse"
			)
			assert_eq(Curses.threat(w), 1)
		else:
			assert_true(w.curses_owned.is_empty(), "a clean card brings none")
		assert_true(w.ev.cursed_ids.is_empty(), "the chest is gone, and its mark")


func test_ambush_cache_and_elite_spawns_are_readable() -> void:
	var damage := 0
	var jobs := [
		[4242, 1, []],
		[4242, 2, []],
		[77, 2, [&"marked_hunt", &"swift_foes"]],
		[78, 3, [&"swarm_call", &"marked_hunt"]],
	]
	for job: Array in jobs:
		var w := EventLab.world(job[0], job[1], &"blade", job[2])
		EventLab.set_event(w, &"ambush_cache")
		var check := ReadableCause.new(w)
		check.context = {"seed": job[0], "floor": job[1], "curses": job[2]}
		EventLab.open(w)
		EventLab.pick(w, 1)
		assert_eq(w.ev.ambush_ids.size(), 3)
		var bot := FightBot.new(job[0])
		for t in 3000:
			w.step(bot.frame(w))
			check.observe(w)
			if not w.player_dead():
				w.actors.hp[0] = w.actors.max_hp[0]  # test-side top-up, as CauseRun
		damage += check.damage_count
		for v: Dictionary in check.violations:
			fail_test("unreadable hit: %s" % JSON.stringify(v))
	gut.p("hits taken in the ambush runs: %d" % damage)
	assert_gt(damage, 20, "the bot was hit often enough for the check to mean something")
