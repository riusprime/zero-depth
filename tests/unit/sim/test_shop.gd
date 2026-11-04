extends GutTest
## v0.5.0 SH (PLAN R1, R2): the shop in the sim. Prices by rarity x floor step; the interact button by the terminal
## opens it and the world waits; a bought card applies exactly as a picked card; the heal (once), the reroll (rising
## price); refusals change nothing; every action is deterministic, emits its SimEvent and is in the hash.
## v0.10.5 W3-O9 (owner, 2026-11-04: "it should only show the heal, reroll and the 4 cards"): selling and the curse
## lift are gone; their old pick values are refused.

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
	assert_eq(_shop.rarity_prices, PackedInt32Array([30, 55, 90, 150]), "v0.8.0 RR: + legendary")
	assert_eq([_shop.heal_permille, _shop.heal_price, _shop.reroll_price], [300, 40, 20])


func test_prices_by_rarity_and_floor() -> void:
	var by_floor := []
	for f in [1, 2, 3]:
		var row := []
		for r in 3:
			row.append(_shop.card_price(r, f))
		row.append(_shop.heal_cost(f))
		by_floor.append(row)
	# v0.5.5 EC (owner S4): floors 2-3 x 1.5 on top of the floor step (x 2.25, x 3).
	assert_eq(by_floor, [[30, 55, 90, 40], [68, 124, 203, 90], [90, 165, 270, 120]])
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


## v0.10.5 W3-O9 (owner, 2026-11-04: "it should only show the heal, reroll and the 4 cards, lifting the curse and
## selling is too broken"): the open shop offers exactly its 4 cards, the heal and the reroll. A sellable build adds
## nothing; the retired picks (22: the curse lift; 100 and up: selling) are refused and change nothing but the
## refusal's tick (test_curses: the same with a curse held).
func test_the_shop_offers_only_the_heal_the_reroll_and_four_cards() -> void:
	var w := _world(8)
	Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.DRONE_BUDDY))
	Stats.add_card(w, Stats.Stat.DAMAGE, 0)
	_open(w)
	var r := Shop.read(w)
	assert_eq((r["stock"] as Array).size(), 4, "four cards")
	for key in ["sell", "cleanse_price", "cleanse_curse", "cleanse_name_key"]:
		assert_false(r.has(key), "%s is gone" % key)
	for key in ["heal_price", "heal_amount", "reroll_price"]:
		assert_true(r.has(key), "%s stays" % key)
	var owned := w.ability_owned.duplicate()
	var cards := w.stat_cards.duplicate()
	for v in [22, 100, 101]:
		var shards := w.shards
		_pick(w, v)
		assert_eq(w.shop.denied_tick, w.tick - 1, "pick %d is refused" % v)
		assert_eq(w.shards, shards, "pick %d: no shards move" % v)
		assert_eq(w.ability_owned, owned, "pick %d: the build stays" % v)
		assert_eq(w.stat_cards, cards)
		assert_true(w.shop.open, "still shopping")
	assert_eq(_events(w, SimEvent.Kind.SHOP_SALVAGE).size(), 0, "nothing is ever sold")


## Shop.remove_stat_card (the playground's card removal; it was selling's): one stack goes and the values rebuild.
func test_removing_a_stat_card_drops_one_stack_and_rebuilds() -> void:
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
	var common_dmg := Offers.stat_code(dmg, 0)
	Shop.remove_stat_card(w, common_dmg)
	assert_eq(w.stat_values, only.stat_values, "as if the last one was never taken")
	assert_eq(w.stat_cards.count(common_dmg), 1, "one stack left")
	var before_max := w.actors.max_hp[0]
	w.actors.hp[0] = before_max
	Shop.remove_stat_card(w, Offers.stat_code(hp, 2))
	assert_lt(w.actors.max_hp[0], before_max, "max HP falls")
	assert_eq(w.actors.max_hp[0], (w.player.hp * Stats.value(w, hp) + 500) / 1000)
	assert_eq(w.actors.hp[0], w.actors.max_hp[0], "HP at most the new max")


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


## v0.10.5 W3-O9: sell_share and ability_refund_per_level left ShopDefinition, and cleanse_price
## EventRulesDefinition. A .tres written before (the pre-W3-O9 data, kept as text here) still loads and validates.
func test_an_old_shop_tres_with_the_sell_fields_still_loads() -> void:
	var old := (
		FileAccess.get_file_as_string("res://data/shop/terminal.tres")
		+ "sell_share = 0.4\nability_refund_per_level = 10\n"
	)
	var path := "user://w3o9_old_terminal.tres"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(old)
	f.close()
	var def := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShopDefinition
	assert_not_null(def, "it loads")
	assert_eq(def.validate().size(), 0, "and validates")
	assert_eq(ContentCompiler.compile_shop(def).offer_size, 4)
	assert_false("sell_share" in def, "the field is gone")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
