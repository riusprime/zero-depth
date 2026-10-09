extends GutTest
## v0.5.0 SH (PLAN R1, R2): the shop and salvage in the sim. Prices by rarity x floor step; the interact button by
## the terminal opens it and the world waits; a bought card applies exactly as a picked card; the heal (once), the
## reroll (rising price); selling a mod or a stat card (40 % of its price; a stat stack removed, values rebuilt) and
## salvaging an ability (10 shards per level, M-LOOP; the slot frees for a later card); refusals change nothing; every
## action is deterministic, emits its SimEvent and is in the hash.

var _repo: ContentRepository
var _shop: ShopTable


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_shop = ContentCompiler.compile_shop(_repo.get_def(&"shop", &"terminal"))


func _world(seed_value: int, build: StringName = &"blade") -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	var w := World.new(seed_value, t)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.reward_table = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	w.shop_table = _shop
	w.shop.id = w.take_root()
	w.shop.pos = Vector2(1.2, 0.0)
	w.shards = 1000
	return w


func _press(w: World, bits: int) -> void:
	var f := InputFrame.new()
	f.pressed = bits
	f.held = bits
	w.step(f)


func _pick(w: World, value: int) -> void:
	var f := InputFrame.new()
	f.pick = value
	w.step(f)


func _open(w: World) -> void:
	_press(w, InputFrame.INTERACT)
	assert_true(w.shop.open, "the shop opened")


func _events(w: World, kind: int, after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind:
			out.append(e)
	return out


func _code_of_type(w: World, type: int) -> int:
	for k in w.shop.offer.size():
		if w.shop.offer[k] >= 0 and Offers.type_of(w.shop.offer[k]) == type:
			return k
	return -1


func test_the_data_compiles_to_the_starting_values() -> void:
	assert_eq(_repo.count(&"shop"), 1)
	assert_eq(_shop.offer_size, 4)
	assert_eq(_shop.rarity_prices, PackedInt32Array([30, 55, 90]))
	assert_eq([_shop.heal_permille, _shop.heal_price, _shop.reroll_price], [300, 40, 20])
	assert_eq([_shop.sell_permille, _shop.ability_refund_per_level], [400, 10])


func test_prices_by_rarity_and_floor() -> void:
	var by_floor := []
	for f in [1, 2, 3]:
		var row := []
		for r in 3:
			row.append(_shop.card_price(r, f))
		row.append(_shop.heal_cost(f))
		row.append(_shop.sell_price(1, f))
		by_floor.append(row)
	# v0.5.5 EC (owner S4): floors 2-3 x 1.5 on top of the floor step (x 2.25, x 3); refunds stay on the step.
	assert_eq(by_floor, [[30, 55, 90, 40, 22], [68, 124, 203, 90, 33], [90, 165, 270, 120, 44]])
	var rerolls := []
	for u in 5:
		rerolls.append(_shop.reroll_cost(u))
	assert_eq(rerolls, [20, 30, 45, 68, 102], "+50 % per use, rounded half up")


func test_interact_opens_it_and_the_world_waits() -> void:
	var w := _world(5)
	_open(w)
	assert_eq(w.shop.offer.size(), 4, "four cards")
	var tick := w.tick
	var run := w.run_ticks
	var at := w.player_pos()
	var f := InputFrame.make(Vector2i(127, 0), 0, 0, InputFrame.PRIMARY, InputFrame.PRIMARY)
	for k in 30:
		w.step(f)
	assert_eq(w.tick, tick + 30, "the tick count runs on")
	assert_eq(w.run_ticks, run, "the run clock waits")
	assert_eq(w.player_pos(), at, "no move while shopping")
	_pick(w, InputFrame.PICK_CANCEL)
	assert_false(w.shop.open, "cancel closes it")
	assert_eq(
		w.input_buffer, PackedInt32Array([0, 0, 0, 0]), "nothing pressed in the shop fires after"
	)
	var stock := w.shop.offer.duplicate()
	_open(w)
	assert_eq(w.shop.offer, stock, "reopening shows the same stock")


func test_out_of_reach_nothing_opens() -> void:
	var w := _world(5)
	w.shop.pos = Vector2(6, 0)
	_press(w, InputFrame.INTERACT)
	assert_false(w.shop.open)
	assert_false(w.shop.rolled, "no stock drawn")


func test_the_stock_follows_the_chest_rules_and_the_slot_rules() -> void:
	for s in 60:
		var w := _world(300 + s)
		if s % 2 == 1:
			for kind in [  # v0.6.0 MX2: the six modifier slots full
				AbilityTable.Kind.BOMB_LOBBER,
				AbilityTable.Kind.DRONE_BUDDY,
				AbilityTable.Kind.ORBIT_BLADES,
				AbilityTable.Kind.ARC_FIELD,
				AbilityTable.Kind.FROST_NOVA,
				AbilityTable.Kind.FLAME_TRAIL,
			]:
				Abilities.grant(w, Abilities.index_of_kind(w, kind))
		_open(w)
		var seen := {}
		for code in w.shop.offer:
			assert_true(Shop.can_apply(w, code), "seed %d: every card can apply" % s)
			var key := (
				code
				if Offers.type_of(code) != Offers.STAT
				else Offers.STAT_BASE + Offers.stat_of(code) * 10
			)
			assert_false(seen.has(key), "no card repeats")
			seen[key] = true
			if Offers.type_of(code) == Offers.ABILITY and s % 2 == 1:
				var t := w.ability_tables[Offers.ability_of(code)]
				assert_true(
					Abilities.owned(w, Offers.ability_of(code)) or t.is_utility(),
					"six held: a level-up, or the utility outside the slots"
				)
			if Offers.type_of(code) == Offers.MOD:
				assert_true(ItemPool.usable(w, code), "a mod only with its ability and weapon")


func test_a_bought_card_applies_exactly_as_a_picked_card() -> void:
	var bought := 0
	for s in 30:
		var w := _world(50 + s)
		_open(w)
		var k := s % 4
		var code := w.shop.offer[k]
		var cost := Shop.price(w, code)
		var twin := _world(50 + s)
		_open(twin)
		var seq := w.last_event_seq()
		_pick(w, k + 1)
		Offers.apply(twin, code)
		twin.shards -= cost
		assert_eq(w.shards, 1000 - cost, "seed %d: paid its price" % s)
		assert_eq(w.shop.offer[k], ShopState.SOLD, "sold out")
		assert_eq(
			[w.items_owned, w.ability_owned, w.ability_levels, w.stat_values, w.stat_cards],
			[
				twin.items_owned,
				twin.ability_owned,
				twin.ability_levels,
				twin.stat_values,
				twin.stat_cards
			],
			"the same as taking it from an altar"
		)
		assert_eq(w.actors.max_hp[0], twin.actors.max_hp[0])
		var pickups := _events(w, SimEvent.Kind.PICKUP, seq)
		var buys := _events(w, SimEvent.Kind.SHOP_BUY, seq)
		assert_eq(pickups.size(), 1, "a PICKUP")
		assert_eq(pickups[0].amount, code)
		assert_eq(buys.size(), 1, "a SHOP_BUY")
		assert_eq(buys[0].amount, cost)
		bought += 1
		var before := w.shards
		_pick(w, k + 1)
		assert_eq(w.shards, before, "a sold slot can't be bought twice")
		assert_eq(w.shop.denied_tick, w.tick - 1, "the refusal is noted")
	assert_eq(bought, 30)


func test_unaffordable_changes_nothing() -> void:
	var w := _world(9)
	_open(w)
	w.shards = 5
	var stock := w.shop.offer.duplicate()
	_pick(w, 1)
	_pick(w, InputFrame.PICK_SHOP_REROLL)
	w.actors.hp[0] = 10
	_pick(w, InputFrame.PICK_SHOP_HEAL)
	assert_eq(w.shards, 5)
	assert_eq(w.shop.offer, stock)
	assert_false(w.shop.heal_used)
	assert_eq(w.actors.hp[0], 10)
	assert_eq(w.shop.rerolls, 0)
	assert_eq(w.shop.denied_tick, w.tick - 1)


func test_the_heal_restores_thirty_percent_once() -> void:
	var w := _world(9)
	_open(w)
	var mx := w.actors.max_hp[0]
	_pick(w, InputFrame.PICK_SHOP_HEAL)
	assert_false(w.shop.heal_used, "at full HP the heal is refused")
	assert_eq(w.shards, 1000)
	w.actors.hp[0] = 10
	_pick(w, InputFrame.PICK_SHOP_HEAL)
	assert_eq(w.actors.hp[0], mini(mx, 10 + (mx * 300 + 500) / 1000), "30 % of max HP")
	assert_eq(w.shards, 1000 - 40, "40 shards on floor 1")
	var heals := _events(w, SimEvent.Kind.HEAL)
	assert_eq(heals.size(), 1)
	assert_eq(heals[0].effect_id, Shop.EFFECT_HEAL)
	w.actors.hp[0] = 10
	_pick(w, InputFrame.PICK_SHOP_HEAL)
	assert_eq(w.actors.hp[0], 10, "once per shop")


func test_the_reroll_draws_a_new_stock_at_a_rising_price() -> void:
	var w := _world(21)
	_open(w)
	var paid := []
	var stocks := [w.shop.offer.duplicate()]
	for k in 4:
		var before := w.shards
		var loot := w.rng_loot.state
		_pick(w, InputFrame.PICK_SHOP_REROLL)
		paid.append(before - w.shards)
		assert_ne(w.rng_loot.state, loot, "drawn from the loot stream")
		stocks.append(w.shop.offer.duplicate())
	assert_eq(paid, [20, 30, 45, 68])
	assert_eq(_events(w, SimEvent.Kind.SHOP_BUY).size(), 4)
	var twin := _world(21)
	_open(twin)
	for k in 4:
		_pick(twin, InputFrame.PICK_SHOP_REROLL)
	assert_eq(twin.shop.offer, stocks[4], "same seed, same rerolls")
	assert_eq(twin.state_hash(), w.state_hash())


func test_sell_a_mod_for_forty_percent_and_lose_its_combos() -> void:
	var w := _world(4)
	var c := 0
	while w.combo_tables[c].item_a < 0:  # v0.4.0 AB: skip the ability combos (they pair abilities, not items)
		c += 1
	var combo: ComboTable = w.combo_tables[c]
	w.add_item(combo.item_a)
	w.add_item(combo.item_b)
	assert_true(w.combos_owned.has(c), "the combo is on")
	_open(w)
	var list := Shop.sell_list(w)
	assert_eq(list[0][0], Shop.SELL_MOD)
	assert_eq(list[0][1], combo.item_a)
	var refund := _shop.sell_price(Shop.rarity(w, combo.item_a), 1)
	assert_eq(list[0][3], refund)
	_pick(w, InputFrame.PICK_SHOP_SELL + 0)
	assert_false(w.items_owned.has(combo.item_a), "sold")
	assert_true(w.items_owned.has(combo.item_b))
	assert_false(w.combos_owned.has(c), "its combo is gone")
	assert_eq(w.shards, 1000 + refund)
	var ev := _events(w, SimEvent.Kind.SHOP_SALVAGE)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0].amount, refund)
	assert_eq(ev[0].effect_id, w.item_tables[combo.item_a].id)
	assert_true(ItemPool.available(w).has(combo.item_a), "it can be found again")


func test_sell_a_stat_card_removes_one_stack_and_rebuilds() -> void:
	var w := _world(4)
	var dmg := Stats.Stat.DAMAGE
	var hp := Stats.Stat.MAX_HP
	Stats.add_card(w, dmg, 0)
	Stats.add_card(w, hp, 2)
	Stats.add_card(w, dmg, 2)
	Stats.add_card(w, dmg, 0)
	var only := _world(4)
	Stats.add_card(only, dmg, 0)
	Stats.add_card(only, hp, 2)
	Stats.add_card(only, dmg, 2)
	_open(w)
	var list := Shop.sell_list(w)
	var common_dmg := Offers.stat_code(dmg, 0)
	var n := -1
	for k in list.size():
		if list[k][0] == Shop.SELL_STAT and list[k][2] == common_dmg:
			n = k
	assert_gte(n, 0)
	assert_eq(list[n][1], 2, "two of that card held: one entry")
	_pick(w, InputFrame.PICK_SHOP_SELL + n)
	assert_eq(w.stat_values, only.stat_values, "as if the last one was never taken")
	assert_eq(w.stat_cards.count(common_dmg), 1, "one stack left")
	assert_eq(w.shards, 1000 + _shop.sell_price(0, 1))
	# Max HP follows the max HP card's sale; HP stays at most the new max.
	list = Shop.sell_list(w)
	for k in list.size():
		if list[k][2] == Offers.stat_code(hp, 2):
			n = k
	var before_max := w.actors.max_hp[0]
	w.actors.hp[0] = before_max
	_pick(w, InputFrame.PICK_SHOP_SELL + n)
	assert_lt(w.actors.max_hp[0], before_max, "max HP falls")
	assert_eq(w.actors.max_hp[0], (w.player.hp * Stats.value(w, hp) + 500) / 1000)
	assert_eq(w.actors.hp[0], w.actors.max_hp[0], "HP at most the new max")


func test_selling_at_the_cap_frees_the_stat_again() -> void:
	var w := _world(4)
	var s := Stats.Stat.CRIT_CHANCE
	var guard := 0
	while not Stats.at_cap(w, s) and guard < 60:
		Stats.add_card(w, s, 2)
		guard += 1
	assert_true(Stats.at_cap(w, s), "at the cap")
	_open(w)
	var list := Shop.sell_list(w)
	_pick(w, InputFrame.PICK_SHOP_SELL + list.size() - 1)
	assert_false(Stats.at_cap(w, s), "one stack fewer: under the cap again")


func test_salvage_an_ability_frees_its_slot() -> void:
	var w := _world(8)
	var bomb := Abilities.index_of_kind(w, AbilityTable.Kind.BOMB_LOBBER)
	var drone := Abilities.index_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)
	var orbit := Abilities.index_of_kind(w, AbilityTable.Kind.ORBIT_BLADES)
	var blink := Abilities.index_of_kind(w, AbilityTable.Kind.BLINK)
	for idx in [bomb, drone, orbit]:
		Abilities.grant(w, idx)
	Abilities.grant(w, drone)
	Abilities.grant(w, drone)
	assert_true(Abilities.can_take(w, blink), "v0.6.0 MX2: the utility pick sits outside the slots")
	_open(w)
	var list := Shop.sell_list(w)
	var kinds := []
	for e in list:
		if e[0] == Shop.SELL_ABILITY:
			kinds.append(w.ability_tables[w.ability_owned[e[1]]].kind)
	assert_eq(
		kinds,
		[
			AbilityTable.Kind.BOMB_LOBBER,
			AbilityTable.Kind.DRONE_BUDDY,
			AbilityTable.Kind.ORBIT_BLADES
		],
		"every ability but the weapon"
	)
	var n := list.size() - 2  # Drone Buddy, level 3
	assert_eq(list[n][3], 30, "10 shards per level")
	_pick(w, InputFrame.PICK_SHOP_SELL + n)
	assert_false(Abilities.owned(w, drone))
	assert_eq(w.ability_owned.size(), 3)
	assert_eq(w.ab.cd.size(), 3, "the cooldowns follow the slots")
	assert_true(w.ab.drone_pos.is_empty(), "the drones go")
	assert_eq(w.shards, 1030)
	assert_true(Abilities.can_take(w, blink), "a later ability card can take the slot")
	assert_eq(_events(w, SimEvent.Kind.SHOP_SALVAGE)[0].effect_id, w.ability_tables[drone].id)
	assert_true(Abilities.grant(w, blink))
	assert_eq(w.ability_owned.size(), 4)


func test_the_weapon_is_never_salvaged() -> void:
	var w := _world(8, &"gun")
	_open(w)
	for e in Shop.sell_list(w):
		assert_ne(e[0], Shop.SELL_ABILITY, "only the weapon is owned: nothing to salvage")
	_pick(w, InputFrame.PICK_SHOP_SELL + 0)
	assert_eq(w.ability_owned.size(), 1)
	assert_eq(w.shards, 1000)


func test_same_inputs_same_hash_and_the_shop_is_hashed() -> void:
	var a := _world(77)
	var b := _world(77)
	for w in [a, b]:
		Stats.add_card(w, Stats.Stat.AREA, 1)
		_open(w)
		_pick(w, 2)
		_pick(w, InputFrame.PICK_SHOP_REROLL)
		w.actors.hp[0] = 20
		_pick(w, InputFrame.PICK_SHOP_HEAL)
		_pick(w, InputFrame.PICK_SHOP_SELL)
		_pick(w, InputFrame.PICK_CANCEL)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")
	var h := a.state_hash()
	a.shop.heal_used = not a.shop.heal_used
	assert_ne(a.state_hash(), h, "the heal flag is hashed")
	a.shop.heal_used = not a.shop.heal_used
	a.shop.offer[0] = ShopState.SOLD if a.shop.offer[0] >= 0 else 0
	assert_ne(a.state_hash(), h, "the stock is hashed")
	var c := _world(77)
	var hc := c.state_hash()
	c.stat_cards.append(Offers.stat_code(Stats.Stat.AREA, 0))
	assert_ne(c.state_hash(), hc, "the stat cards taken are hashed")


func test_a_world_without_a_shop_is_unchanged() -> void:
	var w := _world(3)
	w.shop = ShopState.new()
	_press(w, InputFrame.INTERACT)
	assert_false(w.shop.open)
	assert_false(Shop.in_reach(w))


func test_the_stat_cards_carry_to_the_next_floor() -> void:
	var w := _world(3)
	Stats.add_card(w, Stats.Stat.AREA, 1)
	var carry := RunCarry.take(w, 0)
	var next := _world(4)
	RunCarry.apply(next, carry)
	assert_eq(next.stat_cards, w.stat_cards)


## v0.5.5 EC (owner S2, "the bought slots should stay bought"): a reroll redraws only the unsold slots; a bought
## slot stays SOLD; with every slot sold the reroll is refused and costs nothing.
func test_a_reroll_keeps_the_sold_slots_sold() -> void:
	var w := _world(33)
	_open(w)
	assert_eq(w.shop.offer.size(), 4)
	_pick(w, 2)
	assert_eq(w.shop.offer[1], ShopState.SOLD)
	var loot := w.rng_loot.state
	_pick(w, InputFrame.PICK_SHOP_REROLL)
	assert_eq(w.shop.rerolls, 1, "rerolled")
	assert_ne(w.rng_loot.state, loot, "the unsold slots were drawn again")
	assert_eq(w.shop.offer.size(), 4, "four slots still")
	assert_eq(w.shop.offer[1], ShopState.SOLD, "the bought slot stays sold")
	assert_eq(Shop.unsold(w), 3, "the other three hold new cards")
	for k in [0, 2, 3]:
		assert_gte(w.shop.offer[k], 0, "slot %d has a card" % k)
	for k in [1, 3, 4]:
		_pick(w, k)
	assert_eq(Shop.unsold(w), 0, "all four bought")
	var before := w.shards
	_pick(w, InputFrame.PICK_SHOP_REROLL)
	assert_eq(w.shards, before, "nothing left to reroll: refused, free")
	assert_eq(w.shop.offer, PackedInt32Array([-1, -1, -1, -1]))
	assert_eq(w.shop.denied_tick, w.tick - 1)


## v0.5.5 EC (owner S3, "only 4 max per floor"): at most max_buys cards bought at the floor's shop; the heal and
## rerolls don't count; past the limit a buy (and a reroll) is refused with the LIMIT reason the panel shows.
func test_at_most_max_buys_cards_per_floor() -> void:
	assert_eq(_shop.max_buys, 4, "the shipped limit")
	var w := _world(34)
	w.shop_table = ContentCompiler.compile_shop(_repo.get_def(&"shop", &"terminal"))
	w.shop_table.max_buys = 2  # a test-side table, so rerolls can refill slots under the limit
	_open(w)
	assert_eq(Shop.buys_left(w), 2)
	_pick(w, 1)
	w.actors.hp[0] = 10
	_pick(w, InputFrame.PICK_SHOP_HEAL)
	_pick(w, InputFrame.PICK_SHOP_REROLL)
	assert_eq([w.shop.bought, Shop.buys_left(w)], [1, 1], "the heal and the reroll don't count")
	_pick(w, 2)
	assert_eq([w.shop.bought, Shop.buys_left(w)], [2, 0])
	var before := w.shards
	var stock := w.shop.offer.duplicate()
	_pick(w, 3)
	assert_eq(w.shards, before, "a third buy is refused")
	assert_eq(w.shop.offer, stock)
	assert_eq(w.shop.denied_reason, ShopState.Deny.LIMIT, "for the limit")
	_pick(w, InputFrame.PICK_SHOP_REROLL)
	assert_eq(w.shards, before, "no reroll with no buys left")
	var r := Shop.read(w)
	assert_eq([r["bought"], r["max_buys"], r["buys_left"]], [2, 2, 0], "the panel reads the limit")
	var next := _world(35)
	_open(next)
	assert_eq(Shop.buys_left(next), 4, "a new floor's shop starts fresh")
