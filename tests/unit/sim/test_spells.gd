extends GutTest
## v0.11.0 O10 (owner Q17-Q20; docs/roadmap/v0.11.0/SPELLS.md): the spell slots and the first spells with the shipped
## data. The offer (no element card: no spell; an element card held: its spell, about SpellRules.offer_permille of the
## regular altars, its own stream so the loot stream is untouched; the rune affinity doubles its weight, measured over
## many seeded offers), the 4 slots and the Replace when full, the cooldown runner, the densest pack, each spell's Lv 1
## (Frost Nova's freeze and push within 3.5 m, Fireball's 3 m burst and burn on the densest pack, Sky Strike's 3 bolts
## each jumping once), the level-up by taking it again (Lv 3 in loop 1, Lv 5 from loop 2), the hash, the snapshot and
## the carry. Crit is off (crit_chance_permille = 0) so the numbers are exact.

const W := preload("res://tests/support/mx4_world.gd")


func _world(items: Array = [], enemies: Array = [], seed_value: int = 9, loop: int = 1) -> World:
	var w := W.world(&"gun", items, enemies, [], false, seed_value)
	w.reward_table = ContentCompiler.compile_rewards(W.repo().get_def(&"rewards", &"floor"))
	w.spell_tables = SpellCompiler.compile(W.repo(), w.item_tables)
	w.spell_rules = SpellCompiler.compile_rules(W.repo())
	w.loop = loop
	return w


func _affinity(w: World, id: StringName) -> void:
	Affinities.setup(
		w, RunContentCompiler.compile_affinity(W.repo().get_def(&"affinity", id), w.item_tables)
	)


func _take(w: World, k: int, n: int = 1) -> void:
	for i in n:
		Offers.apply(w, Offers.spell_code(k))


func _lost(w: World, id: int) -> int:
	var i := w.actors.index_of(id)
	return w.actors.max_hp[i] - w.actors.hp[i]


func _hits(w: World, effect: StringName) -> Array[SimEvent]:
	return W.events(w, SimEvent.Kind.HIT, effect)


func _spell_in(offer: PackedInt32Array) -> int:
	var n := 0
	for c in offer:
		if Offers.type_of(c) == Offers.SPELL:
			n += 1
	return n


func test_the_three_spells_compile_with_their_numbers() -> void:
	var w := _world()
	assert_true(Spells.enabled(w))
	assert_eq(w.spell_rules.slots, 4, "4 slots")
	var nova := Spells.table(w, Spells.FROST_NOVA)
	assert_eq([nova.id, nova.cooldown_ticks, nova.damage[0]], [&"spell_frost_nova", 720, 20])
	assert_eq([nova.radius_m[0], nova.ticks[0], nova.push_m], [3.5, 60, 1.0], "3.5 m, 1 s, 1 m")
	assert_eq(nova.element_item, W.item(w, &"frost_core"))
	var ball := Spells.table(w, Spells.FIREBALL)
	assert_eq([ball.damage[0], ball.radius_m[0], ball.count[0]], [20, 3.0, 1], "one ball, 3 m")
	assert_eq([ball.element_item, ball.affinity], [W.item(w, &"ember_core"), &"ember"])
	var sky := Spells.table(w, Spells.SKY_STRIKE)
	assert_eq([sky.damage[0], sky.count[0], sky.reach_m], [10, 3, 10.0], "3 bolts within 10 m")
	for t: SpellTable in [nova, ball, sky]:
		assert_eq(t.damage.size(), 5, "%s: levels 1-5 in data" % t.id)
		assert_eq(t.level_keys.size(), 5)


func test_no_element_card_no_spell_is_ever_offered() -> void:
	for s in 120:
		var w := _world([], [], 500 + s)
		assert_true(Spells.pool(w).is_empty(), "no element card: an empty pool")
		var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
		assert_eq(Spells.offer_card(w, w.rewards.index_of(id)), -1)
		assert_eq(_spell_in(Offers.roll(w, w.rewards.index_of(id))), 0, "seed %d: none" % s)


func test_an_element_card_held_offers_its_spell_from_its_own_stream() -> void:
	var rolls := 400
	var got := 0
	for s in rolls:
		var w := _world([&"ember_core"], [], 2000 + s)
		var plain := _world([&"ember_core"], [], 2000 + s)
		plain.spell_rules = null
		var fire := PackedInt32Array([Spells.FIREBALL, Spells.BURNING_GROUND, Spells.METEOR])
		assert_eq(Spells.pool(w), fire, "Fire: its three spells (O11)")
		var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
		var i := w.rewards.index_of(id)
		var predicted := Spells.offer_card(w, i)
		assert_eq(predicted, Spells.offer_card(w, i), "pure: the same answer twice")
		var offer := Offers.roll(w, i)
		assert_eq(_spell_in(offer) == 1, predicted >= 0, "as offer_card said")
		if predicted >= 0:
			got += 1
			assert_true(offer.has(Offers.spell_code(predicted)))
			assert_true(fire.has(predicted), "a Fire spell")
			assert_eq(offer.size(), w.reward_table.offer_size, "in place of a card")
		plain.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
		Offers.roll(plain, 0)
		assert_eq(
			w.rng_loot.state, plain.rng_loot.state, "its own stream: the loot stream untouched"
		)
		var chest := w.add_reward(RewardStore.Kind.CHEST, Vector2(90, 90), 0)
		assert_eq(_spell_in(Offers.roll(w, w.rewards.index_of(chest))), 0, "never a chest")
	gut.p("Fireball offered at %d / %d altars" % [got, rolls])
	assert_between(got, rolls * 28 / 100, rolls * 42 / 100, "about 35 %")


## O11: Fire's three spells against Frost's and Lightning's six (each weight 10).
func test_the_rune_affinity_raises_its_spells_weight() -> void:
	var fire := [Spells.FIREBALL, Spells.BURNING_GROUND, Spells.METEOR]
	var counts := {false: [0, 0], true: [0, 0]}  # [fire, the others]
	for aff: bool in [false, true]:
		for s in 1500:
			var w := _world([&"ember_core", &"frost_core", &"storm_core"], [], 7000 + s)
			if aff:
				_affinity(w, &"ember")
			var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
			var k := Spells.offer_card(w, w.rewards.index_of(id))
			if k >= 0:
				counts[aff][0 if fire.has(k) else 1] += 1
	gut.p("spell offers [Fire, others], no affinity %s; Ember %s" % [counts[false], counts[true]])
	var fb := float(counts[false][0]) / float(counts[false][1])
	assert_between(fb, 0.38, 0.62, "no affinity: the Fire three about half the other six (3 : 6)")
	var fe := float(counts[true][0]) / float(counts[true][1])
	assert_between(fe, 0.8, 1.25, "Ember: the Fire three weigh ×2 (6 : 6)")
	var w := _world([&"ember_core"])
	_affinity(w, &"ember")
	assert_eq(Spells.weight_of(w, Spells.table(w, Spells.FIREBALL)), 20, "10 × 2000 ‰")


func test_four_slots_then_the_lowest_level_spell_is_replaced() -> void:
	var w := _world([&"ember_core", &"frost_core", &"storm_core"])
	_take(w, Spells.FIREBALL, 2)
	_take(w, Spells.FROST_NOVA)
	_take(w, Spells.SKY_STRIKE, 2)
	assert_false(Spells.full(w), "three held, one slot free")
	assert_eq(Offers.info(w, Offers.spell_code(0))["replaces"], -1, "a free slot: replaces nothing")
	_take(w, 0, 2)
	assert_true(Spells.full(w), "four held")
	assert_eq(
		w.spell_slots, PackedInt32Array([Spells.FIREBALL, Spells.FROST_NOVA, Spells.SKY_STRIKE, 0])
	)
	assert_eq(w.spell_levels, PackedInt32Array([2, 1, 2, 2]))
	assert_eq(w.mod_slots.has(Offers.spell_code(Spells.FIREBALL)), false, "not in the wand")
	# a fifth spell: the lowest level (Frost Nova's Lv 1) goes; the card says so first
	var info := Offers.info(w, Offers.spell_code(2))
	assert_eq(info["replaces"], Offers.spell_code(Spells.FROST_NOVA), "replaces Frost Nova")
	_take(w, 2)
	assert_eq(
		w.spell_slots, PackedInt32Array([Spells.FIREBALL, 2, Spells.SKY_STRIKE, 0]), "in its slot"
	)
	assert_eq(w.spell_levels[1], 1, "at Lv 1")
	assert_eq(w.spell_slots.size(), 4, "still four")


func test_taking_a_held_spell_levels_it_up_to_three_in_loop_one_five_after() -> void:
	var w := _world([&"ember_core"])
	_take(w, Spells.FIREBALL)
	assert_eq(Spells.level(w, Spells.FIREBALL), 1)
	assert_eq(Offers.info(w, Offers.spell_code(Spells.FIREBALL))["level"], 2, "the card says Lv 2")
	assert_eq(
		CardForecast.of(w, Offers.spell_code(Spells.FIREBALL))["new"], 2, "the forecast's own"
	)
	_take(w, Spells.FIREBALL, 4)
	assert_eq(Spells.level(w, Spells.FIREBALL), 3, "loop 1: Lv 3 at most")
	assert_false(Spells.can_offer(w, Spells.FIREBALL), "at its cap: out of the pool")
	w.loop = 2
	assert_true(Spells.can_offer(w, Spells.FIREBALL), "loop 2: Lv 4-5 open")
	_take(w, Spells.FIREBALL, 4)
	assert_eq(Spells.level(w, Spells.FIREBALL), 5, "Lv 5 at most")
	assert_eq(w.spell_slots.size(), 1, "one slot")


func test_the_densest_pack_is_the_most_enemies_in_3_m_within_10_m() -> void:
	var w := _world(
		[],
		[
			[Vector2(2, 0), 1000],  # alone, nearest
			[Vector2(0, 7), 1000],  # a pack of three around (0, 8)
			[Vector2(0, 8), 1000],
			[Vector2(1.5, 8.5), 1000],
			[Vector2(14, 0), 1000],  # five beyond 10 m
			[Vector2(14, 1), 1000],
			[Vector2(15, 0), 1000],
			[Vector2(15, 1), 1000],
			[Vector2(14.5, 0.5), 1000],
		]
	)
	var c := Spells.densest_pack(w, w.player_pos(), 10.0)
	assert_true([2, 3, 4].has(c), "a pack-of-three member (got index %d)" % c)
	assert_eq(c, 2, "ties: the nearest to the hero")
	var w2 := _world([], [[Vector2(2, 0), 1000], [Vector2(-4, 0), 1000]])
	assert_eq(Spells.densest_pack(w2, w2.player_pos(), 10.0), 1, "one each: the nearest")
	var w3 := _world([], [[Vector2(12, 0), 1000]])
	assert_eq(Spells.densest_pack(w3, w3.player_pos(), 10.0), -1, "none within 10 m")


func test_frost_nova_freezes_pushes_and_hits_within_3_5_m_on_its_cooldown() -> void:
	var w := _world(
		[&"frost_core"], [[Vector2(2, 0), 1000], [Vector2(0, 3.4), 1000], [Vector2(4, 0), 1000]]
	)
	var near := w.actors.ids[1]
	var edge := w.actors.ids[2]
	var far := w.actors.ids[3]
	_take(w, Spells.FROST_NOVA)
	W.run(w, 1)
	assert_eq(_hits(w, &"spell_frost_nova").size(), 2, "two within 3.5 m")
	assert_eq(_lost(w, near), 20, "Lv 1: 20")
	assert_eq(_lost(w, far), 0, "4 m: untouched")
	assert_eq(
		w.actors.frozen_t[w.actors.index_of(near)], 59, "frozen 1 s (60 ticks, one gone this tick)"
	)
	assert_gt(w.actors.frozen_t[w.actors.index_of(edge)], 0)
	assert_eq(w.actors.frozen_t[w.actors.index_of(far)], 0)
	var cd := w.spell_cd[0]
	assert_eq(cd, 720, "12 s")
	W.run(w, Spells.PUSH_TICKS + 1)
	var p := w.actors.pos(w.actors.index_of(near))
	assert_almost_eq(p.x, 3.0, 0.05, "pushed 1 m away")
	assert_almost_eq(w.actors.pos(w.actors.index_of(far)).x, 4.0, 0.001, "not pushed")
	W.run(w, 720 - Spells.PUSH_TICKS - 2)
	assert_eq(_hits(w, &"spell_frost_nova").size(), 2, "still cooling")
	W.run(w, 1)
	assert_gt(_hits(w, &"spell_frost_nova").size(), 2, "casts again 720 ticks later")


func test_a_ready_spell_waits_for_a_target() -> void:
	var w := _world([&"frost_core"])
	_take(w, Spells.FROST_NOVA)
	W.run(w, 120)
	assert_eq(w.spell_cd[0], 0, "no enemy: ready, waiting")
	assert_eq(w.spell_cast_tick[0], -1, "never cast")
	w.add_dummy(Vector2(1.5, 0), 0.35, 1000)
	W.run(w, 1)
	assert_gte(w.spell_cast_tick[0], 0, "cast the tick one came near")
	assert_eq(w.spell_cd[0], 720)


func test_fireball_flies_to_the_densest_pack_and_bursts_3_m_with_burn() -> void:
	var w := _world(
		[&"ember_core"],
		[
			[Vector2(2, 0), 1000],
			[Vector2(0, 7), 1000],
			[Vector2(0, 8), 1000],
			[Vector2(1.5, 8.5), 1000],
			[Vector2(-3.2, 7), 1000],  # 3.2 m from the burst point (0, 7): outside it
		]
	)
	var lone := w.actors.ids[1]
	var pack := [w.actors.ids[2], w.actors.ids[3], w.actors.ids[4]]
	var out := w.actors.ids[5]
	_take(w, Spells.FIREBALL)
	W.run(w, 1)
	assert_eq(w.spell_ball_pos.size(), 1, "one ball in the air")
	assert_eq(w.spell_ball_to[0], Vector2(0, 7), "locked on the pack")
	assert_eq(_hits(w, &"spell_fireball").size(), 0, "it flies first")
	W.run(w, 60)
	assert_eq(w.spell_ball_pos.size(), 0, "burst")
	for id: int in pack:
		assert_eq(_lost(w, id) >= 20, true, "the pack takes 20 (and its burn)")
		assert_gt(w.actors.burn_stacks[w.actors.index_of(id)], 0, "set on fire")
	assert_eq(_lost(w, lone), 0, "the lone one at 2 m: untouched")
	assert_eq(_lost(w, out), 0, "past 3 m: untouched")


func test_sky_strike_three_bolts_each_jump_once_and_charge() -> void:
	var enemies := []
	for k in 6:
		enemies.append([Vector2(2 + k * 1.2, 0), 100000])
	var w := _world([&"storm_core"], enemies, 41)
	w.pair_table = WandCompiler.pairs(W.repo())  # the charge needs the pair table (the game's)
	_take(w, Spells.SKY_STRIKE)
	W.run(w, 1)
	var hits := _hits(w, &"spell_sky_strike")
	assert_eq(hits.size(), 6, "3 bolts and their 3 jumps")
	var bolts := 0
	for k in w.spell_fx_kind.size():
		if w.spell_fx_kind[k] == Spells.FX_BOLT:
			bolts += 1
	assert_eq(bolts, 3, "3 bolts from the sky")
	var shocked := 0
	for i in range(1, w.actors.size()):
		if w.actors.charged_t[i] > 0:
			shocked += 1
	var struck := {}
	for h in hits:
		struck[h.target_id] = true
	assert_eq(shocked, struck.size(), "each enemy struck is charged, as a Storm hit leaves it")
	assert_gte(struck.size(), 3, "3 bolts at 3 enemies")
	for h in hits:
		assert_eq(h.amount, 10, "Lv 1: 10 a hit")


func test_sky_strike_targets_are_its_own_seeded_draw() -> void:
	var picks := {}
	for s in 12:
		var enemies := []
		for k in 8:
			enemies.append([Vector2(-6 + k * 1.7, 2), 100000])
		var w := _world([&"storm_core"], enemies, 300 + s)
		var twin := _world([&"storm_core"], enemies, 300 + s)
		_take(w, Spells.SKY_STRIKE)
		_take(twin, Spells.SKY_STRIKE)
		W.run(w, 1)
		W.run(twin, 1)
		assert_eq(w.state_hash(), twin.state_hash(), "seed %d: deterministic" % s)
		picks[str(W.targets(_hits(w, &"spell_sky_strike")))] = true
	assert_gt(picks.size(), 1, "the targets vary by seed")


func test_hash_snapshot_and_carry_keep_the_spells() -> void:
	var enemies := [[Vector2(2, 0), 100000], [Vector2(0, 6), 100000], [Vector2(0, 7), 100000]]
	var w := _world([&"ember_core", &"frost_core"], enemies)
	var plain := _world([&"ember_core", &"frost_core"], enemies)
	assert_eq(w.state_hash(), plain.state_hash(), "no spell: hashed as a world without them")
	_take(w, Spells.FIREBALL, 2)
	_take(w, Spells.FROST_NOVA)
	assert_ne(w.state_hash(), plain.state_hash(), "a spell is hashed")
	W.run(w, 5)  # a Fireball in the air, pushes running
	var base := _world([&"ember_core", &"frost_core"], enemies)
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray())
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.state_hash(), w.state_hash(), "replay-exact")
	W.run(w, 900)
	W.run(base, 900)
	assert_eq(base.state_hash(), w.state_hash(), "the same 900 ticks later")
	var carry := RunCarry.take(w, 0)
	var next := _world([&"ember_core", &"frost_core"], [[Vector2(1.5, 0), 100000]])
	RunCarry.apply(next, carry)
	assert_eq(next.spell_slots, PackedInt32Array([Spells.FIREBALL, Spells.FROST_NOVA]), "carried")
	assert_eq(next.spell_levels, PackedInt32Array([2, 1]))
	W.run(next, 1)
	assert_eq(next.spell_cd.size(), 2, "the cooldowns padded on the new floor")
	assert_gt(_hits(next, &"spell_frost_nova").size(), 0, "ready on arrival")


## The soak (every spell at Lv 3 with every element card, a crowd of 40): no watchdog LIMIT, a bounded log and balls,
## the same hash replayed.
func test_every_spell_together_runs_bounded_and_replays() -> void:
	var enemies := []
	for k in 40:
		enemies.append([Vector2(-6 + (k % 8) * 1.6, -4 + (k / 8) * 1.8), 400])
	var items := [&"ember_core", &"frost_core", &"storm_core"]
	var runs: Array[World] = []
	for r in 2:
		var w := _world(items, enemies, 77)
		w.pair_table = WandCompiler.pairs(W.repo())
		for k in [Spells.FROST_NOVA, Spells.FIREBALL, Spells.SKY_STRIKE]:
			_take(w, k, 3)
		for n in 1800:
			W.run(w, 1)
			assert_lte(w.spell_ball_pos.size(), 8, "balls bounded")
			if n % 600 == 0:
				for _e in 5:
					w.add_dummy(Vector2(1 + _e, 2), 0.35, 400)
		assert_eq(W.events(w, SimEvent.Kind.LIMIT).size(), 0, "no watchdog LIMIT")
		assert_lte(w.spell_fx_kind.size(), Spells.FX_MAX, "the view's log bounded")
		runs.append(w)
	assert_eq(runs[0].state_hash(), runs[1].state_hash(), "the same hash replayed")
	assert_gt(W.events(runs[0], SimEvent.Kind.HIT, &"spell_fireball").size(), 0)
	assert_gt(W.events(runs[0], SimEvent.Kind.HIT, &"spell_sky_strike").size(), 0)
	assert_gt(W.events(runs[0], SimEvent.Kind.HIT, &"spell_frost_nova").size(), 0)
