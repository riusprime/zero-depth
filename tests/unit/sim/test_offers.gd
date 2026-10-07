extends GutTest
## The offers rework (v0.4.0 BS, owner F8, F9, F13): an altar's first card is a new ability while a slot is free;
## once the four slots are full ability cards only level up; stat cards are most cards (chests roll more rare and
## epic); the 27 items are rarer mods; no card repeats in one offer; the roll is deterministic on the loot stream;
## picking applies the card; a world without abilities and stats rolls items exactly as before.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(seed_value: int, build: StringName = &"blade") -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	var w := World.new(seed_value, t)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.reward_table = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _roll(w: World, kind: int) -> PackedInt32Array:
	var id := w.add_reward(kind, Vector2(100, 100), 0)
	return Offers.roll(w, w.rewards.index_of(id))


func test_every_altar_offers_a_new_ability_while_a_slot_is_free() -> void:
	for s in 40:
		var w := _world(s)
		var offer := _roll(w, RewardStore.Kind.ALTAR)
		assert_eq(offer.size(), 3, "three cards")
		assert_eq(
			Offers.type_of(offer[0]), Offers.ABILITY, "seed %d: the first card is an ability" % s
		)
		assert_false(Abilities.owned(w, Offers.ability_of(offer[0])), "a new one")
		var seen := {}
		for c in offer:
			var key := (
				c if Offers.type_of(c) != Offers.STAT else Offers.STAT_BASE + Offers.stat_of(c) * 10
			)
			assert_false(seen.has(key), "seed %d: no card repeats" % s)
			seen[key] = true


func test_full_slots_offer_only_level_ups() -> void:
	var w := _world(3)
	for kind in [
		AbilityTable.Kind.BOMB_LOBBER, AbilityTable.Kind.DRONE_BUDDY, AbilityTable.Kind.ORBIT_BLADES
	]:
		Abilities.grant(w, Abilities.index_of_kind(w, kind))
	for s in 60:
		for c in _roll(w, RewardStore.Kind.ALTAR if s % 2 == 0 else RewardStore.Kind.CHEST):
			if Offers.type_of(c) == Offers.ABILITY:
				assert_true(
					Abilities.owned(w, Offers.ability_of(c)), "only owned abilities level up"
				)


func test_the_mix_by_source() -> void:
	var counts := {
		RewardStore.Kind.ALTAR: [0, 0, 0, 0, 0, 0], RewardStore.Kind.CHEST: [0, 0, 0, 0, 0, 0]
	}
	for s in 120:
		var w := _world(1000 + s)
		for kind in counts:
			for c in _roll(w, kind):
				var row: Array = counts[kind]
				row[Offers.type_of(c)] += 1
				if Offers.type_of(c) == Offers.STAT:
					row[3 + Offers.rarity_of(c)] += 1
	var altar: Array = counts[RewardStore.Kind.ALTAR]
	var chest: Array = counts[RewardStore.Kind.CHEST]
	gut.p("altar [mod, ability, stat, common, rare, epic] %s; chest %s" % [altar, chest])
	assert_gt(altar[Offers.STAT], altar[Offers.MOD] * 3, "stat cards are most altar cards")
	assert_gt(chest[Offers.MOD], altar[Offers.MOD], "mods come mostly from chests")
	var altar_rare: float = float(altar[4] + altar[5]) / maxi(1, altar[Offers.STAT])
	var chest_rare: float = float(chest[4] + chest[5]) / maxi(1, chest[Offers.STAT])
	assert_gt(chest_rare, altar_rare + 0.15, "chests roll more rare and epic stat cards")


func test_the_roll_is_deterministic_and_draws_only_the_loot_stream() -> void:
	var a := _world(77)
	var b := _world(77)
	var crit := a.rng_crit.state
	var ability := a.rng_ability.state
	assert_eq(_roll(a, RewardStore.Kind.CHEST), _roll(b, RewardStore.Kind.CHEST))
	assert_eq([a.rng_crit.state, a.rng_ability.state], [crit, ability])


func test_picking_applies_each_card_type() -> void:
	var w := _world(5)
	var bomb := Abilities.index_of_kind(w, AbilityTable.Kind.BOMB_LOBBER)
	Offers.apply(w, Offers.ability_code(bomb))
	assert_true(Abilities.owned(w, bomb), "an ability card takes a slot")
	Offers.apply(w, Offers.ability_code(bomb))
	assert_eq(Abilities.level_of(w, bomb), 2, "and a second one levels it up")
	Offers.apply(w, Offers.stat_code(Stats.Stat.DAMAGE, Stats.Rarity.RARE))
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1150, "a stat card")
	Offers.apply(w, 4)
	assert_eq(w.items_owned, PackedInt32Array([4]), "a mod is an item, as before")
	var info := Offers.info(w, Offers.stat_code(Stats.Stat.DAMAGE, Stats.Rarity.EPIC))
	assert_eq(
		[info["type"], info["id"], info["rarity"], info["amount"]], [Offers.STAT, &"damage", 2, 250]
	)


func test_a_world_without_build_tables_rolls_items_as_before() -> void:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	var a := World.new(9, t)
	var b := World.new(9, t)
	for w in [a, b]:
		w.set_item_tables(ContentCompiler.compile_items(_repo))
		w.reward_table = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	var offer := _roll(a, RewardStore.Kind.CHEST)
	assert_eq(
		offer, ItemPool.draw_weighted(b, 3, b.reward_table.rare_weight_chest), "the v0.3.0 draw"
	)
	for c in offer:
		assert_eq(Offers.type_of(c), Offers.MOD)


func test_zero_weights_are_allowed_and_never_drawn() -> void:
	var w := _world(31)
	w.reward_table.chest_card_weights = PackedInt32Array([0, 1, 0])
	w.reward_table.chest_rarity_weights = PackedInt32Array([0, 0, 1])
	for s in 10:
		for c in _roll(w, RewardStore.Kind.CHEST):
			assert_eq(Offers.type_of(c), Offers.STAT, "only stat cards")
			assert_eq(Offers.rarity_of(c), Stats.Rarity.EPIC, "all epic")
	assert_eq(Offers.pick(w.rng_loot, PackedInt32Array([0, 0])), -1, "nothing to pick")
