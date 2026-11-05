extends GutTest
## v0.10.5 W3-P10b (owner W7; docs/roadmap/v0.10.5/W3_W7_LOOP_POWER_G1.md §B): the Starbound cards with the shipped
## data. The offer (B0: none at loop 1, about 20 % of regular altars at loop 2 and 30 % at loop 3, never a chest, its
## own stream so loop 1 and the loot stream are untouched), the pick (a stack each, no cap), C6 Supernova doubling
## every stack, and each card: Arc Jump's jumps, Rising Edge's and Fervour's ramps, caps and room resets, Echo Cast's
## repeats (sure past 100 %, at most 3, never repeating, Gun and Blade), Detonation's burst, its chain and its cap.
## Crit is off (crit_chance_permille = 0) so the numbers are exact.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(build: StringName = &"blade", seed_value: int = 31, loop: int = 2) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	t.crit_chance_permille = 0
	var w := World.new(seed_value, t)
	w.dummy_speed = 0.0
	w.dummy_fire_period = 100000
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.reward_table = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	w.starbound_tables = ContentCompiler.compile_starbound(_repo)
	w.loop = loop
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _take(w: World, k: int, n: int = 1) -> void:
	for i in n:
		Offers.apply(w, Offers.starbound_code(k))


func _hit(w: World, id: int, amount: int, tags := SimEvent.TAG_MELEE) -> int:
	var pid := w.actors.ids[0]
	var i := w.actors.index_of(id)
	return Damage.hit(w, i, amount, pid, pid, w.take_root(), tags, Vector2.ZERO, w.actors.pos(i))


func _lost(w: World, id: int) -> int:
	var i := w.actors.index_of(id)
	return w.actors.max_hp[i] - w.actors.hp[i]


func _starbound_in(offer: PackedInt32Array) -> int:
	var n := 0
	for c in offer:
		if Offers.type_of(c) == Offers.STARBOUND:
			n += 1
	return n


func test_the_five_cards_compile_with_their_numbers() -> void:
	var w := _world()
	assert_true(Starbound.enabled(w), "five cards")
	var arc := Starbound.table(w, Starbound.ARC_JUMP)
	assert_eq(
		[arc.id, arc.amount, arc.reach_m, arc.share_permille], [&"starbound_arc_jump", 1, 4.0, 700]
	)
	var rise := Starbound.table(w, Starbound.RISING_EDGE)
	assert_eq([rise.amount, rise.cap], [30, 1500], "+3 % a crit, at most +150 %")
	var echo := Starbound.table(w, Starbound.ECHO_CAST)
	assert_eq([echo.amount, echo.cap], [250, 3], "+25 %, at most 3 repeats")
	var fer := Starbound.table(w, Starbound.FERVOUR)
	assert_eq([fer.amount, fer.cap], [20, 600], "+2 % a kill, at most +60 %")
	var det := Starbound.table(w, Starbound.DETONATION)
	assert_eq([det.amount, det.reach_m, det.share_permille], [200, 2.0, 500])
	assert_eq(
		w.reward_table.starbound_permille, PackedInt32Array([200, 300]), "B0: 20 %, then 30 %"
	)


func test_no_starbound_card_at_loop_one_and_the_offer_is_unchanged() -> void:
	for s in 60:
		var w := _world(&"blade", s, 1)
		var plain := _world(&"blade", s, 1)
		plain.starbound_tables.clear()
		var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
		var pid := plain.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
		var offer := Offers.roll(w, w.rewards.index_of(id))
		assert_eq(_starbound_in(offer), 0, "seed %d: loop 1 offers none" % s)
		assert_eq(
			offer, Offers.roll(plain, plain.rewards.index_of(pid)), "seed %d: the same offer" % s
		)
		assert_eq(w.rng_loot.state, plain.rng_loot.state, "the loot stream as it was")


func test_loop_two_and_three_offer_one_at_their_rates_never_in_a_chest() -> void:
	var by_loop := {2: 0, 3: 0}
	var rolls := 400
	for loop: int in by_loop:
		for s in rolls:
			var w := _world(&"blade", 1000 + s, loop)
			var plain := _world(&"blade", 1000 + s, loop)
			plain.starbound_tables.clear()
			var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
			var i := w.rewards.index_of(id)
			var predicted := Starbound.offer_card(w, i)
			assert_eq(predicted, Starbound.offer_card(w, i), "pure: the same answer twice")
			var offer := Offers.roll(w, i)
			var n := _starbound_in(offer)
			assert_lte(n, 1, "at most one a pick")
			assert_eq(n == 1, predicted >= 0, "as offer_card said")
			if n == 1:
				by_loop[loop] += 1
				assert_true(offer.has(Offers.starbound_code(predicted)), "the card it said")
				assert_eq(offer.size(), 3, "in place of a card")
			plain.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
			Offers.roll(plain, 0)
			assert_eq(
				w.rng_loot.state, plain.rng_loot.state, "its own stream: the loot stream untouched"
			)
			var chest := w.add_reward(RewardStore.Kind.CHEST, Vector2(90, 90), 0)
			assert_eq(_starbound_in(Offers.roll(w, w.rewards.index_of(chest))), 0, "never a chest")
			assert_eq(_starbound_in(Offers.draw(w, true, 4)), 0, "never the shop's stock")
	gut.p(
		"Starbound offers: loop 2 %d / %d, loop 3 %d / %d" % [by_loop[2], rolls, by_loop[3], rolls]
	)
	assert_between(by_loop[2], rolls * 14 / 100, rolls * 26 / 100, "about 20 % at loop 2")
	assert_between(by_loop[3], rolls * 24 / 100, rolls * 36 / 100, "about 30 % at loop 3")


func test_each_pick_adds_a_stack_with_no_cap_and_supernova_doubles_them() -> void:
	var w := _world()
	var code := Offers.starbound_code(Starbound.FERVOUR)
	assert_eq(Offers.type_of(code), Offers.STARBOUND)
	assert_eq(int(Offers.info(w, code)["level"]), 1, "the first pick: stack 1")
	assert_false(BuildSlots.needs_swap(w, code), "no slot")
	_take(w, Starbound.FERVOUR, 12)
	assert_eq(Starbound.picks(w, Starbound.FERVOUR), 12, "twelve picks, twelve stacks: no cap")
	assert_eq(int(Offers.info(w, code)["level"]), 13)
	assert_eq(Starbound.stacks(w, Starbound.FERVOUR), 12)
	assert_eq(Starbound.stacks(w, Starbound.ARC_JUMP), 0, "the others none")
	w.constellations.append(Constellations.SUPERNOVA)
	assert_eq(Starbound.stacks(w, Starbound.FERVOUR), 24, "C6 Supernova: each stack counts twice")
	assert_eq(RunCarry.take(w, 0)[&"starbound"], w.starbound, "run-long: the carry keeps the picks")


func test_arc_jump_jumps_to_the_nearest_new_enemy_at_seventy_percent() -> void:
	var w := _world()
	var a := w.add_dummy(Vector2(2, 0), 0.3, 100000)
	var b := w.add_dummy(Vector2(5, 0), 0.3, 100000)  # 3 m from a
	var c := w.add_dummy(Vector2(8.5, 0), 0.3, 100000)  # 3.5 m from b
	var far := w.add_dummy(Vector2(30, 0), 0.3, 100000)
	_hit(w, a, 1000)
	assert_eq(_lost(w, b), 0, "no card: no jump")
	_take(w, Starbound.ARC_JUMP)
	_hit(w, a, 1000)
	assert_eq(_lost(w, b), 700, "one stack: one jump at 70 %")
	assert_eq(_lost(w, c), 0, "a jump never jumps again")
	_take(w, Starbound.ARC_JUMP, 2)
	_hit(w, a, 1000)
	assert_eq(_lost(w, b), 1400, "three stacks: b again (a new chain)")
	assert_eq(_lost(w, c), 490, "then c at 70 % of 70 %")
	assert_eq(_lost(w, a), 3000, "never back to a: the chain hit it")
	assert_eq(_lost(w, far), 0, "beyond 4 m: the chain stops")
	assert_eq(w.starbound_fx_kind.count(Starbound.FX_JUMP), 3, "the view's lines (V3)")
	_hit(w, a, 1000, SimEvent.TAG_DOT)
	assert_eq(_lost(w, b), 1400, "a DoT tick never jumps")


func test_rising_edge_ramps_crit_damage_to_its_cap_and_resets_when_the_room_clears() -> void:
	var w := _world()
	var d := w.add_dummy(Vector2(2, 0), 0.3, 1000000)
	var base := Stats.crit_mult(w)
	_take(w, Starbound.RISING_EDGE)
	var i := w.actors.index_of(d)
	Starbound.on_player_hit(w, i, 10, SimEvent.TAG_MELEE | SimEvent.TAG_CRIT, &"", 100, 1)
	assert_eq(Stats.crit_mult(w), base + 30, "a crit: +3 % crit damage")
	Starbound.on_player_hit(w, i, 10, SimEvent.TAG_MELEE, &"", 100, 1)
	assert_eq(Stats.crit_mult(w), base + 30, "a plain hit adds nothing")
	for k in 80:
		Starbound.on_player_hit(w, i, 10, SimEvent.TAG_MELEE | SimEvent.TAG_CRIT, &"", 100, 1)
	assert_eq(Stats.crit_mult(w), base + 1500, "at most +150 % a stack")
	_take(w, Starbound.RISING_EDGE)
	assert_eq(Stats.crit_mult(w), base + 3000, "two stacks: twice")
	Starbound.advance(w)
	assert_eq(Stats.crit_mult(w), base + 3000, "an enemy left in the room: kept")
	w.actors.dead[i] = 1
	Starbound.advance(w)
	assert_eq(Stats.crit_mult(w), base, "the room cleared: reset")


func test_fervour_ramps_haste_per_kill_to_its_cap_and_resets() -> void:
	var w := _world()
	var rate0 := AttackRate.weapon_rate(w)
	var keep := w.add_dummy(Vector2(10, 10), 0.3, 1000000)
	_take(w, Starbound.FERVOUR)
	for k in 3:
		_hit(w, w.add_dummy(Vector2(2, 0), 0.3, 10), 100)
	assert_eq(w.starbound_kills, 3)
	assert_eq(Starbound.haste_bonus(w), 60, "three kills: +6 % haste")
	assert_gt(AttackRate.weapon_rate(w), rate0, "the weapon attacks faster")
	for k in 40:
		_hit(w, w.add_dummy(Vector2(2, 0), 0.3, 10), 100)
	assert_eq(Starbound.haste_bonus(w), 600, "at most +60 % a stack")
	w.constellations.append(Constellations.SUPERNOVA)
	assert_eq(Starbound.haste_bonus(w), 1200, "Supernova: twice")
	Starbound.advance(w)
	assert_eq(Starbound.haste_bonus(w), 1200, "kept while one lives")
	w.actors.dead[w.actors.index_of(keep)] = 1
	Starbound.advance(w)
	assert_eq(Starbound.haste_bonus(w), 0, "the room cleared: reset")
	assert_eq(AttackRate.weapon_rate(w), rate0)


func _launches(w: World, spec: AttackSpec, step: int = -1) -> int:
	var before := w.mx.q_key.size()
	var ctx := AttackContext.make(w.player_pos(), 0, 50, w.take_root(), SimEvent.TAG_MELEE, &"")
	ctx.step = step
	Attacks.launch(w, spec, ctx)
	return w.mx.q_key.size() - before


func test_echo_cast_repeats_sure_past_a_hundred_percent_at_most_three() -> void:
	for build: StringName in [&"blade", &"gun"]:
		var w := _world(build)
		var spec := Modifiers.step(w, 0) if build == &"blade" else Modifiers.bolt(w)
		var step := 0 if build == &"blade" else -1
		assert_eq(_launches(w, spec, step), 0, "%s: no card, no repeat" % build)
		_take(w, Starbound.ECHO_CAST, 4)
		assert_eq(_launches(w, spec, step), 1, "%s: 4 x 25 %% = 100 %%: one sure repeat" % build)
		_take(w, Starbound.ECHO_CAST)
		var seen := {}
		for k in 60:
			w.tick += 1
			w.mx.q_key.clear()
			seen[_launches(w, spec, step)] = true
		assert_eq(seen.keys().size(), 2, "%s: 125 %%: one sure and a chance of a second" % build)
		assert_true(seen.has(1) and seen.has(2))
		_take(w, Starbound.ECHO_CAST, 20)
		w.mx.q_key.clear()
		assert_eq(_launches(w, spec, step), 3, "%s: at most 3 repeats" % build)
		assert_eq(
			w.mx.q_flags[0] & ModifierState.FLAG_REPEAT, ModifierState.FLAG_REPEAT, "a repeat"
		)
		w.tick += 200
		var left := w.mx.q_key.size()
		ModifierRuntime.advance(w)
		assert_eq(
			w.mx.q_key.size(),
			left - 3,
			"%s: the repeats ran and queued none: a repeat never repeats" % build
		)


func test_detonation_bursts_a_kill_halves_on_elites_and_chains() -> void:
	var w := _world()
	var dead := w.add_dummy(Vector2(2, 0), 0.3, 1000)
	var near := w.add_dummy(Vector2(3, 0), 0.3, 100000)
	var elite_i := w.actors.add(
		w.take_id(), ActorStore.Kind.BREAKER, ActorStore.TEAM_ENEMY, Vector2(2, 1), 0.3, 100000, 0
	)
	var elite := w.actors.ids[elite_i]
	var out := w.add_dummy(Vector2(6, 0), 0.3, 100000)
	_take(w, Starbound.DETONATION)
	_hit(w, dead, 1000)
	assert_eq(_lost(w, near), 200, "20 % of its 1000 max HP")
	assert_eq(_lost(w, elite), 100, "an elite takes half")
	assert_eq(_lost(w, out), 0, "beyond 2 m: none")
	assert_eq(w.starbound_fx_kind.count(Starbound.FX_BURST), 1, "one burst drawn (V1)")
	var w2 := _world()
	var first := w2.add_dummy(Vector2(2, 0), 0.3, 1000)
	var second := w2.add_dummy(Vector2(3.5, 0), 0.3, 150)
	var third := w2.add_dummy(Vector2(5, 0), 0.3, 100000)
	_take(w2, Starbound.DETONATION, 2)
	_hit(w2, first, 1000)
	assert_eq(
		w2.actors.dead[w2.actors.index_of(second)], 1, "its burst (40 %: 400) killed the next"
	)
	assert_eq(_lost(w2, third), 60, "whose burst (40 % of 150) hit the third")


func test_at_most_twenty_four_bursts_a_tick_and_one_limit_event() -> void:
	var w := _world()
	var first := w.add_dummy(Vector2(2, 0), 0.3, 100)
	for k in 39:
		w.add_dummy(Vector2(2, 0), 0.3, 100)
	_take(w, Starbound.DETONATION, 5)  # 5 x 20 %: a burst of its whole max HP kills the next
	var seq := w.events_since(-1).size()
	_hit(w, first, 100)
	var limits := 0
	for e in w.events_since(-1).slice(seq):
		if e.kind == SimEvent.Kind.LIMIT and e.effect_id == Starbound.EFFECT_BURST_CAP:
			limits += 1
			assert_eq(e.amount, Starbound.BURSTS_PER_TICK)
	assert_eq(w.starbound_bursts, 40, "forty kills, forty bursts asked")
	assert_eq(w.starbound_fx_kind.count(Starbound.FX_BURST), 24, "24 burst, the rest dropped")
	assert_eq(limits, 1, "one LIMIT event")
	w.tick += 1
	_hit(w, w.add_dummy(Vector2(9, 9), 0.3, 100), 100)
	assert_eq(w.starbound_bursts, 1, "a new tick, a new budget")


func test_the_picks_are_hashed_and_saved_and_loop_one_hashes_as_before() -> void:
	var w := _world()
	var plain := _world()
	plain.starbound_tables.clear()
	assert_eq(w.state_hash(), plain.state_hash(), "no pick: hashed as a world without the cards")
	_take(w, Starbound.ARC_JUMP)
	assert_ne(w.state_hash(), plain.state_hash(), "a pick is hashed")
	var base := _world()
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors.size(), 0, "%s" % [errors])
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.starbound, w.starbound, "restored")
	assert_eq(base.state_hash(), w.state_hash(), "replay-exact")
