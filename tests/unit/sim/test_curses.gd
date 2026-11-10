# gdlint: disable=max-public-methods
extends GutTest
## v0.5.0 EV (PLAN R4; PD-05): the plain curses, each one's effect where the sim computes it; threat T (one per curse,
## its peak, the carry to the next floor, the run's record per floor); cursed chest offers (how many, what they hold,
## taking the cursed card takes the curse, the other cards are clean); the cleanse hook (the Cleansing Font's; the
## shop's lift is gone, v0.10.5 W3-O9); and (v0.9.0 EL) the
## three elite archetypes' fights pass the readable-cause check with the same bars as test_readable_cause.gd.
## v0.6.0 CU (owner S6): a cursed offer's card is a trade-off curse card (no epic stat card); the trade-off curses
## themselves are tested in test_trade_off_curses.gd. v0.9.0 EL (owner Q25): Marked (C8) and the Ambush Cache are
## deleted; their places in the tables stay retired (EventCompiler), never drawn, and a save holding them drops them.

const SEED := 515


func _world(curses: Array = [], seed_value: int = SEED) -> World:
	return EventLab.world(seed_value, 1, &"blade", curses)


func test_the_shipped_curses() -> void:
	var w := _world()
	var ids := []
	for c in w.ev.curses:
		if c.retired:  # v0.9.0 EL: Marked's place, kept for the saves' indices
			assert_eq(
				[c.weight, c.threat, c.effect],
				[0, 0, -1],
				"%s is retired: never drawn, no effect" % c.id
			)
			continue
		ids.append(String(c.id))
		assert_eq(c.threat, 1, "%s raises T by 1" % c.id)
	ids.sort()
	assert_eq(
		ids,
		[
			"blood_price",
			"brittle",
			"fevered",
			"glass_heart",
			"heavy_hands",
			"rooted",
			"tunnel_vision",
		],
		"the seven trade-offs (v0.6.0 CU; v0.9.0 EL: Marked deleted; v0.10.5 O1: the five plain ones deleted)"
	)
	var plain := []
	for c in w.ev.curses:
		if not c.is_trade_off() and not c.retired:
			plain.append(String(c.id))
	plain.sort()
	assert_eq(plain, [], 'v0.10.5 O1 (owner P1: "Yes, cut the 5"): no plain curse is left')


## v0.10.5 O1: the prices curse (Price Gouge) is gone, so a cursed run's shop prices are the plain ones.
## v0.10.5 W3-O9 (owner, 2026-11-04: "lifting the curse and selling is too broken"): the shop no longer lifts a
## curse. With curses held, the old cleanse pick (22) is refused: nothing paid, nothing lifted, T unchanged.
func test_the_shop_no_longer_lifts_a_curse() -> void:
	var w := _world([&"heavy_hands", &"rooted"])
	var v := _world()
	assert_true(Shop.present(w), "the floor has a shop")
	assert_eq(Shop.heal_price(w), Shop.heal_price(v), "no curse raises a price")
	assert_false(Shop.read(w).has("cleanse_curse"), "no lift tile to show")
	w.shards = 200  # test setup
	var held := w.curses_owned.duplicate()
	var t := Curses.threat(w)
	var f := InputFrame.new()
	f.pick = 22  # the retired PICK_SHOP_CLEANSE
	w.shop.open = true
	w.step(f)
	assert_eq(w.shards, 200, "nothing paid")
	assert_eq(w.curses_owned, held, "both curses held")
	assert_eq(Curses.threat(w), t)
	assert_eq(w.shop.denied_tick, w.tick - 1, "refused")


## v0.9.0 EL (owner Q25): Marked is deleted. Its place in the curse table stays (a save's indices still name the same
## curses), retired: never drawn by an event or a cursed chest.
func test_the_marked_curse_is_retired() -> void:
	var w := _world()
	var k := EventLab.curse_index(w, &"marked_hunt")
	assert_gte(k, 0, "its place is kept")
	assert_true(w.ev.curses[k].retired)
	for n in 200:
		var c := Curses.roll(w)
		assert_ne(c, k, "never drawn")


func test_threat_counts_curses_and_carries_to_the_next_floor() -> void:
	var w := _world()
	assert_eq(Curses.threat(w), 0)
	assert_true(Curses.add(w, 2))
	assert_false(Curses.add(w, 2), "never the same curse twice")
	assert_true(Curses.add(w, 4))
	assert_eq(Curses.threat(w), 2)
	assert_eq(w.threat_peak, 2)
	assert_true(Curses.cleanse(w), "the hook (the Cleansing Font) lifts one")
	assert_eq(w.curses_owned, PackedInt32Array([2]), "the latest goes first")
	assert_eq(Curses.threat(w), 1)
	assert_eq(w.threat_peak, 2, "the peak keeps what was chosen")
	assert_true(Curses.cleanse(w, 2))
	assert_false(Curses.cleanse(w), "nothing left to lift")
	Curses.add(w, 1)
	var run := RunState.start(
		SEED, ContentCompiler.compile_run(EventLab.repo().get_def(&"run", RunSaver.RUN_ID))
	)
	run.finish_floor(w)
	assert_eq(run.threat_by_floor, PackedInt32Array([1]), "T recorded per floor (M-THREAT)")
	var next := World.new(1, PlayerTable.starting_values())
	RunCarry.apply(next, run.carry)
	assert_eq(next.curses_owned, PackedInt32Array([1]), "curses carry")
	assert_eq(next.threat_peak, 2, "and so does the peak")


func test_cursed_chest_offers_hold_one_trade_off_curse_card() -> void:
	var cursed := 0
	var rolled := 0
	var floors_cursed := 0
	for s in 120:
		var w := _world([], 900 + s)
		var on_floor := 0
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
			on_floor += 1
			assert_eq(marks, 1, "one cursed card")
			var card := offer[Curses.CURSED_SLOT]
			assert_eq(Offers.type_of(card), Offers.CURSE, "S6: a trade-off curse card")
			var c := Curses.offer_curse(w, w.rewards.ids[i], Curses.CURSED_SLOT)
			assert_eq(Offers.curse_of(card), c, "the card is its curse")
			assert_true(w.ev.curses[c].is_trade_off(), "a trade-off, never a plain curse")
			assert_eq(int(Offers.info(w, card)["rarity"]), 1, "rare-level, not epic")
			for k in range(1, offer.size()):
				assert_ne(Offers.type_of(offer[k]), Offers.CURSE, "the other cards are clean")
		for i in w.rewards.size():
			assert_true(
				(
					w.rewards.kind[i] == RewardStore.Kind.CHEST
					or w.ev.cursed_ids.find(w.rewards.ids[i]) < 0
				),
				"altars are never cursed"
			)
		assert_lte(on_floor, 1, "v0.7.5 MG (N10): at most one cursed chest on a floor")
		assert_eq(w.ev.cursed_rolled, on_floor, "counted")
		floors_cursed += on_floor
	gut.p(
		(
			"cursed chest offers: %d of %d; floors with one: %d of 120"
			% [cursed, rolled, floors_cursed]
		)
	)
	# Floor 1 is a curse floor: each chest rolls 25 % until one is cursed (about 3 chests: about 58 % of floors).
	assert_between(floors_cursed, 40, 100, "most curse floors have one")


## v0.7.5 MG (owner N10, "the curse appear too often we're gonna have one every two floors"): chests roll the curse
## only on floors 1, 3, 5 … (the data's cursed_chest_first_floor 1, every 2) and at most once a floor; floor 2 has
## none even with every chest rolled; the dev route still forces one there. The 25 % draw is taken on every floor, so
## `loot:event` moves as before until a chest is refused.
func test_cursed_chests_every_two_floors_at_most_one() -> void:
	var rules := EventCompiler.compile_rules(EventLab.repo().get_def(&"event_rules", &"floor"))
	assert_eq(
		[
			rules.cursed_chest_first_floor,
			rules.cursed_chest_every_floors,
			rules.cursed_chests_per_floor
		],
		[1, 2, 1]
	)
	var on := []
	for f in range(1, 10):
		if rules.curse_floor(f):
			on.append(f)
	assert_eq(on, [1, 3, 5, 7, 9])
	var by_floor := [0, 0, 0, 0]
	for s in 40:
		for f in [1, 2, 3]:
			var w := EventLab.world(700 + s, f)
			var here := 0
			for i in w.rewards.size():
				if w.rewards.kind[i] != RewardStore.Kind.CHEST:
					continue
				w.rewards.set_offer(i, Offers.roll(w, i))
				Curses.on_offer_rolled(w, i)
				here += 1 if w.ev.cursed_ids.has(w.rewards.ids[i]) else 0
			assert_lte(here, 1, "seed %d floor %d: at most one" % [700 + s, f])
			by_floor[f] += here
	gut.p(
		(
			"cursed chests over 40 runs, floors 1/2/3: %d/%d/%d"
			% [by_floor[1], by_floor[2], by_floor[3]]
		)
	)
	assert_eq(by_floor[2], 0, "floor 2 never has one")
	assert_gt(by_floor[1], 0)
	assert_gt(by_floor[3], 0)
	var w2 := EventLab.world(701, 2)
	var chest := E2e.nearest_reward(w2, RewardStore.Kind.CHEST)
	w2.ev.force_curse = true  # the dev route (DebugApi.curse_next_chest)
	w2.rewards.set_offer(chest, Offers.roll(w2, chest))
	Curses.on_offer_rolled(w2, chest)
	assert_true(
		w2.ev.cursed_ids.has(w2.rewards.ids[chest]), "the dev route still curses one on floor 2"
	)


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


## v0.9.0 EL: the three elites (one at a time, beside the floor's horde) hit only through telegraphed attacks or a touch
## of their visible body, each with its own recap line.
func test_elite_fights_are_readable() -> void:
	var damage := 0
	var causes := {}
	var jobs := [
		[4242, 4, ActorStore.Kind.BREAKER, []],
		# v0.10.5 O1: Swift Foes and Swarm Call are gone; Rooted (no dash) keeps the bot in reach
		[4243, 5, ActorStore.Kind.RIFT_HUNTER, [&"rooted"]],
		[4244, 4, ActorStore.Kind.CONDUIT, [&"rooted"]],
	]
	for job: Array in jobs:
		var w := EventLab.world(job[0], job[1], &"blade", job[3])
		var check := ReadableCause.new(w)
		check.context = {"seed": job[0], "floor": job[1], "elite": job[2]}
		Elites.spawn(w, job[2], w.player_pos() + Vector2(5, 0), Elites.Source.DEV)
		var bot := FightBot.new(job[0])
		for t in 3000:
			w.step(bot.frame(w))
			check.observe(w)
			if not w.player_dead():
				w.actors.hp[0] = w.actors.max_hp[0]  # test-side top-up, as CauseRun
		damage += check.damage_count
		causes.merge(check.by_cause)
		for v: Dictionary in check.violations:
			fail_test("unreadable hit: %s" % JSON.stringify(v))
	gut.p("hits taken in the elite runs: %d %s" % [damage, causes])
	for key in ["CAUSE_ELITE_BREAKER_SLAM", "CAUSE_ELITE_RIFT_HUNTER_SLASH"]:
		assert_true(causes.has(key), "%s landed in the runs" % key)
	assert_true(
		causes.has("CAUSE_ELITE_CONDUIT_BEAM") or causes.has("CAUSE_ELITE_CONDUIT_ORBS"),
		"the Conduit landed something (the bot sidesteps its locked beam)"
	)
	assert_gt(damage, 20, "the bot was hit often enough for the check to mean something")
