# gdlint: disable=max-public-methods
extends GutTest
## v0.3.0 E: shards per kill and their tier scaling, altars and chests on the floor, the 3-card pick (offers
## deterministic and distinct, rarity weighting, prices per floor, can't afford, consumed, no duplicates, item
## granted, the world waits while choosing), with the shipped data's numbers.

const I := InputFrame.INTERACT
const KIND := ActorStore.Kind

var _items: Array[ItemTable] = []
var _enemies: Array[EnemyTable] = []
var _rewards: RewardTable


func before_all() -> void:
	var repo := ContentRepository.load_all()
	_items = ContentCompiler.compile_items(repo)
	_enemies = ContentCompiler.compile_enemies(repo)
	_rewards = ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor"))


## A world with the real enemies and items, the shipped reward rules, and no rewards placed.
func _world(seed_value: int = 5) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(_enemies)
	w.set_item_tables(_items)
	w.reward_table = _rewards
	return w


func _press(w: World, bits: int, pick: int = InputFrame.PICK_NONE) -> void:
	var f := InputFrame.make(Vector2i.ZERO, 0, 0, 0, bits)
	f.pick = pick
	w.step(f)


func _pick(w: World, pick: int) -> void:
	_press(w, 0, pick)


## Kills a fresh enemy of `kind` at (6, 0) this tick (it leaves the world in phase 9).
func _kill(w: World, kind: int) -> int:
	w.add_enemy(kind, Vector2(6, 0))
	var i := w.actors.size() - 1
	w.actors.hp[i] = 0
	w.actors.dead[i] = 1
	var before := w.shards
	CombatLab.idle(w, 1)
	return w.shards - before


func test_the_shipped_data() -> void:
	var by_kind := {}
	for e in _enemies:
		by_kind[e.kind] = e.shards
	assert_eq(
		by_kind,
		{
			KIND.CHARGER: 3,
			KIND.NEEDLE: 4,
			KIND.WARDEN: 6,
			KIND.HATCHLING: 1,
			KIND.ARC_CASTER: 4,
			KIND.BOMB_DRONE: 4,
			KIND.SWARMER: 1,
			KIND.SPLITTER: 3,
			KIND.SPLITLING: 1,
			KIND.SHIELD_BEARER: 6,
			KIND.MENDER: 5,
			KIND.MINE_LAYER: 4,
			KIND.SNIPER: 5,
			KIND.LENS_DRONE: 3,
		},
		"shards per kind (PLAN E; hatchlings 1; v0.3.5 Arc Caster and Bomb Drone 4; v0.4.0 EN horde; v0.4.0 BO Lens Drone 3)"
	)
	assert_eq(_rewards.chest_prices, PackedInt32Array([40, 60, 80]))
	assert_eq([_rewards.altars_min, _rewards.altars_max], [2, 3])
	assert_eq([_rewards.chests_min, _rewards.chests_max], [2, 3])
	assert_eq(_rewards.rare_weight_chest, 3)
	assert_eq(_rewards.shard_tier_bonus_permille, 250)
	var rare := []
	for it in _items:
		if it.rarity == ItemTable.RARE:
			rare.append(String(it.id))
		var need := PlayerTable.Utility.GUARD if it.id == &"bulwark" else -1
		assert_eq(it.requires_utility, need, "%s: utility requirement" % it.id)
	rare.sort()
	assert_eq(
		rare,
		["bulwark", "cold_snap", "conductor", "meltdown", "wildfire"],
		"the rare items (lead, 2026-10-07; Meltdown, v0.3.0 L18)"
	)


func test_a_kill_pays_its_kinds_shards() -> void:
	var w := _world()
	assert_eq(_kill(w, KIND.CHARGER), 3)
	assert_eq(_kill(w, KIND.NEEDLE), 4)
	assert_eq(_kill(w, KIND.WARDEN), 6)
	assert_eq(w.shards, 13)
	assert_eq(w.kills, 3)
	var paid := w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.SHARDS
	)
	assert_eq(paid.map(func(e: SimEvent) -> int: return e.amount), [3, 4, 6], "a SHARDS event each")
	assert_eq(paid[0].pos, Vector2(6, 0), "at the body (the gems fly from there)")


func test_shards_scale_with_the_danger_tier() -> void:
	var w := _world()
	w.spawner = SpawnTable.new()
	w.spawner.tier_ticks = 100
	w.spawner.cap_by_floor = PackedInt32Array([0])
	w.spawner.cap_max = 0
	# × (1 + 0.25 × tier), rounded half up: Charger 3 → 3, 4 (3.75), 5 (4.5), 5 (5.25), 6; Warden 6 → 6, 8 (7.5), 9.
	var want := {0: [3, 6], 1: [4, 8], 2: [5, 9], 3: [5, 11], 4: [6, 12]}
	for tier: int in want:
		w.run_ticks = tier * 100
		assert_eq(
			[Rewards.shards_for_kill(w, KIND.CHARGER), Rewards.shards_for_kill(w, KIND.WARDEN)],
			want[tier],
			"tier %d" % tier
		)


func test_a_boss_kind_pays_by_floor_not_tier() -> void:
	var w := _world()
	var boss := EnemyTable.new()
	boss.kind = KIND.WARDEN
	boss.shards = 60
	boss.shards_by_floor = true
	w.enemy_tables[KIND.WARDEN] = boss
	w.spawner = SpawnTable.new()
	w.run_ticks = w.spawner.tier_ticks * 3
	for f in [1, 2, 3]:
		w.floor_index = f
		assert_eq(Rewards.shards_for_kill(w, KIND.WARDEN), 60 * f, "floor %d" % f)


func test_chest_prices_by_order_and_floor() -> void:
	var t := _rewards
	assert_eq([t.chest_price(0, 1), t.chest_price(1, 1), t.chest_price(2, 1)], [40, 60, 80])
	assert_eq([t.chest_price(0, 2), t.chest_price(1, 2), t.chest_price(2, 2)], [60, 90, 120])
	assert_eq([t.chest_price(0, 3), t.chest_price(1, 3), t.chest_price(2, 3)], [80, 120, 160])
	assert_eq(t.chest_price(5, 1), 80, "the last price repeats")


func test_the_floor_places_altars_and_chests_in_different_rooms() -> void:
	var enemies := _enemies
	for s in [20261006, 7, 99, 1234]:
		var w := FloorScenario.build(
			s, PlayerTable.starting_values(), enemies, SpawnTable.new(), _items, _rewards
		)
		var layout := w.floor_layout
		var altars := 0
		var chests := 0
		var prices := []
		var rooms := {}
		for i in w.rewards.size():
			var room := layout.room_of(w.rewards.pos(i))
			assert_ne(room, layout.start_room, "seed %d: none in the start hall" % s)
			assert_false(rooms.has(room), "seed %d: one per room" % s)
			rooms[room] = true
			if w.rewards.kind[i] == RewardStore.Kind.ALTAR:
				altars += 1
				assert_eq(w.rewards.price[i], 0, "altars are free")
			else:
				chests += 1
				prices.append(w.rewards.price[i])
		assert_between(altars, 2, 3, "seed %d altars" % s)
		assert_between(chests, 2, 3, "seed %d chests" % s)
		assert_eq(prices, [40, 60, 80].slice(0, chests), "seed %d: prices by chest order" % s)
		assert_eq(w.pickups.size(), 0, "no v0.2.0 pedestals")
		var again := FloorScenario.build(
			s, PlayerTable.starting_values(), enemies, SpawnTable.new(), _items, _rewards
		)
		assert_eq(again.state_hash(), w.state_hash(), "seed %d: placement is deterministic" % s)


func test_floor_two_prices() -> void:
	var w := FloorScenario.build(
		7, PlayerTable.starting_values(), _enemies, SpawnTable.new(), _items, _rewards, 2
	)
	var prices := []
	for i in w.rewards.size():
		if w.rewards.kind[i] == RewardStore.Kind.CHEST:
			prices.append(w.rewards.price[i])
	assert_eq(prices, [60, 90, 120].slice(0, prices.size()))


func test_interact_by_an_altar_opens_three_different_items_and_the_world_waits() -> void:
	var w := _world()
	var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(1.0, 0), 0)
	var charger := w.add_enemy(KIND.CHARGER, Vector2(8, 0))
	CombatLab.idle(w, 2)
	_press(w, I)
	assert_eq(w.choosing, id, "interact within reach opens it")
	var offer := w.rewards.offer_of(0)
	assert_eq(offer.size(), 3)
	assert_ne(offer[0], offer[1])
	assert_ne(offer[1], offer[2])
	assert_ne(offer[0], offer[2])
	var enemy_at := w.actors.pos(w.actors.ids.find(charger))
	var tick := w.tick
	var run := w.run_ticks
	CombatLab.idle(w, 120)
	assert_eq(w.tick, tick + 120, "ticks still count")
	assert_eq(w.actors.pos(w.actors.ids.find(charger)), enemy_at, "enemies wait")
	assert_eq(w.run_ticks, run, "the danger clock waits")
	assert_eq(w.choosing, id, "still waiting for the pick")
	_pick(w, 2)
	assert_eq(w.choosing, -1)
	assert_eq(w.items_owned, PackedInt32Array([offer[1]]), "the 2nd card was granted")
	assert_eq(w.rewards.size(), 0, "the altar is consumed")
	var picks := w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.PICKUP
	)
	assert_eq(picks.size(), 1)
	assert_eq(picks[0].amount, offer[1])
	assert_eq(picks[0].source_id, id)
	var pool := ItemPool.available(w)
	assert_true(offer[0] in pool and offer[2] in pool, "the other two went back to the pool")
	assert_false(offer[1] in pool, "the taken one did not")


func test_too_far_does_nothing() -> void:
	var w := _world()
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(_rewards.interact_radius_m + 0.3, 0), 0)
	_press(w, I)
	assert_eq(w.choosing, -1)
	assert_eq(w.rewards.rolled[0], 0, "nothing rolled")


func test_cancel_keeps_the_altar_and_its_offer() -> void:
	var w := _world()
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1.0, 0), 0)
	_press(w, I)
	var offer := w.rewards.offer_of(0)
	var loot := w.rng_loot.state
	_pick(w, InputFrame.PICK_CANCEL)
	assert_eq(w.choosing, -1, "cancel closes the choice")
	assert_eq(w.rewards.size(), 1, "the altar stays")
	assert_eq(w.items_owned.size(), 0)
	for k in offer:
		assert_false(k in ItemPool.available(w), "its offer stays reserved")
	_press(w, I)
	assert_eq(w.rewards.offer_of(0), offer, "reopening shows the same cards (no reroll)")
	assert_eq(w.rng_loot.state, loot, "no new draw")


func test_a_chest_you_cant_afford_stays_shut() -> void:
	var w := _world()
	var id := w.add_reward(RewardStore.Kind.CHEST, Vector2(1.0, 0), 40)
	w.shards = 39
	_press(w, I)
	assert_eq(w.choosing, -1, "not opened")
	assert_eq(w.rewards.rolled[0], 0, "nothing rolled")
	assert_eq(w.reward_denied_id, id, "the refusal is recorded for the view")
	assert_eq(w.reward_denied_tick, w.tick - 1)
	assert_eq(w.shards, 39)


func test_buying_a_chest_pays_on_the_pick() -> void:
	var w := _world()
	w.add_reward(RewardStore.Kind.CHEST, Vector2(1.0, 0), 40)
	w.shards = 55
	_press(w, I)
	assert_eq(w.shards, 55, "opening is free; cancel costs nothing")
	var offer := w.rewards.offer_of(0)
	_pick(w, 3)
	assert_eq(w.shards, 15, "40 paid")
	assert_eq(w.items_owned, PackedInt32Array([offer[2]]))
	assert_eq(w.rewards.size(), 0, "the chest is consumed")


func test_an_out_of_range_pick_waits() -> void:
	var w := _world()
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1.0, 0), 0)
	_press(w, I)
	_pick(w, 4)
	_pick(w, 0)
	assert_ne(w.choosing, -1, "still choosing")


func test_offers_are_deterministic_and_never_repeat_across_rewards() -> void:
	var a := _world(77)
	var b := _world(77)
	for w in [a, b]:
		for k in 5:
			w.add_reward(RewardStore.Kind.ALTAR, Vector2(30 + 10 * k, 0), 0)
	var seen := {}
	for k in 5:
		for w in [a, b]:
			w.actors.set_pos(0, w.rewards.pos(k) - Vector2(1, 0))
			_press(w, I)
		assert_eq(a.rewards.offer_of(k), b.rewards.offer_of(k), "same seed, same cards")
		for idx in a.rewards.offer_of(k):
			assert_false(seen.has(idx), "item %d offered twice" % idx)
			seen[idx] = true
		for w in [a, b]:
			_pick(w, InputFrame.PICK_CANCEL)
	assert_eq(seen.size(), 15)
	assert_eq(a.state_hash(), b.state_hash())


func test_owned_items_are_never_offered() -> void:
	var w := _world()
	var keep := [_index(&"long_edge"), _index(&"twin_arc")]
	for k in _items.size():
		if not k in keep:
			w.add_item(k)
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1.0, 0), 0)
	_press(w, I)
	var offer := w.rewards.offer_of(0)
	assert_eq(offer.size(), 2, "only two items left")
	for idx in offer:
		assert_has(keep, idx)
	_pick(w, 2)
	assert_eq(w.items_owned.size(), _items.size() - 1)


func test_items_for_another_utility_are_never_offered() -> void:
	var bulwark := _index(&"bulwark")
	var w := _world()
	w.player.utility = PlayerTable.Utility.BLINK
	assert_false(bulwark in ItemPool.available(w), "Bulwark needs the guard")
	for s in 40:
		var v := _world(s + 1)
		v.player.utility = PlayerTable.Utility.BLINK
		assert_false(bulwark in ItemPool.draw_weighted(v, 3, 3), "seed %d" % (s + 1))
	var g := _world()
	g.player.utility = PlayerTable.Utility.GUARD
	assert_true(bulwark in ItemPool.available(g), "with the guard it can be offered")


func _index(id: StringName) -> int:
	for k in _items.size():
		if _items[k].id == id:
			return k
	return -1


func test_an_empty_pool_doesnt_open() -> void:
	var w := _world()
	for k in _items.size():
		w.add_item(k)
	var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(1.0, 0), 0)
	_press(w, I)
	assert_eq(w.choosing, -1)
	assert_eq(w.reward_denied_id, id)


func test_chests_weight_rare_items() -> void:
	# Two rare items among all of them: over many single-card draws a chest (× 3) shows them about 3× as often as an
	# altar (× 1). Counts are from the loot stream, so they are exact for these seeds.
	var rare_hits := {"chest": 0, "altar": 0}
	for s in 400:
		for kind in ["chest", "altar"]:
			var w := _world(s + 1)
			var tables: Array[ItemTable] = []
			for k in _items.size():
				var t := ItemTable.new()
				t.id = _items[k].id
				t.rarity = ItemTable.RARE if k < 2 else ItemTable.COMMON
				tables.append(t)
			w.set_item_tables(tables)
			var weight := (
				_rewards.rare_weight_chest if kind == "chest" else _rewards.rare_weight_altar
			)
			var got := ItemPool.draw_weighted(w, 1, weight)
			if got[0] < 2:
				rare_hits[kind] += 1
	# Expected shares with 24 items: chest 6 / 28 = 21 %, altar 2 / 24 = 8.3 %.
	assert_between(rare_hits["chest"], 55, 115, "chest rare share ~21 % of 400")
	assert_between(rare_hits["altar"], 13, 53, "altar rare share ~8 % of 400")
	gut.p("rare hits in 400 draws: chest %d, altar %d" % [rare_hits["chest"], rare_hits["altar"]])


func test_a_press_during_the_choice_doesnt_fire_after_it() -> void:
	var w := _world()
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1.0, 0), 0)
	_press(w, I)
	_press(w, InputFrame.DASH)
	_pick(w, 1)
	CombatLab.idle(w, 1)
	assert_eq(w.dash_ticks_left, 0, "the dash pressed while choosing was dropped")


func test_reward_state_is_hashed() -> void:
	var a := _world()
	var b := _world()
	assert_eq(a.state_hash(), b.state_hash())
	b.shards = 1
	assert_ne(a.state_hash(), b.state_hash(), "shards")
	var c := _world()
	c.add_reward(RewardStore.Kind.CHEST, Vector2(3, 3), 40)
	var d := _world()
	d.add_reward(RewardStore.Kind.CHEST, Vector2(3, 3), 60)
	assert_ne(c.state_hash(), d.state_hash(), "rewards")
	var e := _world()
	e.floor_index = 2
	assert_ne(a.state_hash(), e.state_hash(), "floor index")


func test_validation() -> void:
	var d := RewardsDefinition.new()
	d.id = &"x"
	assert_eq(d.validate().size(), 0)
	d.altars_min = 4
	d.chest_prices = PackedInt32Array()
	d.offer_size = 4
	var codes := d.validate().map(func(i: ValidationIssue) -> StringName: return i.code)
	assert_has(codes, &"range")
	assert_has(codes, &"missing")
	var e := EnemyDefinition.new()
	e.shards = -1
	assert_true(
		e.validate().any(func(i: ValidationIssue) -> bool: return i.message.contains("shards")),
		"negative shards are an error"
	)
	var it := ItemDefinition.new()
	it.id = &"x"
	it.name_key = &"A"
	it.desc_key = &"B"
	it.kind = ItemDefinition.Kind.LONG_EDGE
	it.reach_bonus_permille = 1
	it.tags = PackedStringArray(["blade"])
	assert_eq(it.validate().size(), 0)
	it.set("rarity", 7)
	assert_eq(it.validate().size(), 1, "rarity is common or rare")
	it.rarity = ItemDefinition.Rarity.COMMON
	it.requires_utility = &"jetpack"
	assert_eq(it.validate().size(), 1, "requires_utility is empty, guard or blink")


func test_a_boss_pays_its_shards_times_the_floor() -> void:
	var w := _world()
	assert_eq(_rewards.boss_shards, 60, "PLAN E: a boss drops 60 × floor")
	w.reward_table = _rewards
	w.floor_index = 1
	assert_eq(Rewards.shards_for_kill(w, KIND.GATEKEEPER), 60)
	w.floor_index = 3
	assert_eq(Rewards.shards_for_kill(w, KIND.SIEGE_ENGINE), 180)
