extends GutTest
## v0.8.0 FL (owner O91, "floor-paced loot"; docs/roadmap/v0.8.0/BALANCE_PASS.md "FL"; LootPacing), part 2 (part 1:
## test_loot_pacing.gd): the floor-1 compatible-card guarantee, the explicit jackpot, the boss altar's choices without
## a level-5 grant, and the new state's save round trip and hash. Mechanics only.

const SEEDS := 24

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


## A run's card world for `build` on floor `floor_index` (as Main: items, rewards, abilities, stat cards, heat, the
## wand, the legendary tier, the pacing table).
func _world(build: StringName = &"gun", seed_value: int = 7, floor_index: int = 1) -> World:
	var w := CardPoolSurvey.world(_repo, seed_value, build, [])
	w.floor_index = floor_index
	w.wand_table = WandCompiler.from_repo(_repo)
	w.legendary_table = RunContentCompiler.compile_legendary(
		_repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	w.loot_pacing = RunContentCompiler.compile_loot_pacing(_repo.get_def(&"loot_pacing", &"pacing"))
	return w


func _it(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _hold(w: World, id: StringName, level: int) -> int:
	var k := _it(w, id)
	assert_true(BuildSlots.take(w, k), "takes %s" % id)
	if level > 1:
		assert_true(CardLevels.set_level(w, k, level))
	return k


# --- The guarantee -------------------------------------------------------------------------------------------------
func test_the_first_two_altars_of_floor_one_show_a_compatible_card() -> void:
	for build: StringName in [&"gun", &"blade"]:
		for s in SEEDS:
			var w := _world(build, 800 + s)
			for n in 2:
				var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(100 + n, 100), 0)
				var offer := Offers.roll(w, w.rewards.index_of(id))
				var fits := 0
				for c in offer:
					fits += 1 if LootPacing.compatible(w, c) else 0
				assert_gt(fits, 0, "%s seed %d altar %d: a compatible card" % [build, s, n])
				w.rewards.set_offer(w.rewards.index_of(id), offer)  # held in the offer, as interact does
			assert_eq(w.loot_guaranteed, 2, "two used")
			var third := w.add_reward(RewardStore.Kind.ALTAR, Vector2(110, 100), 0)
			Offers.roll(w, w.rewards.index_of(third))
			assert_eq(w.loot_guaranteed, 2, "the third altar has none")
	var later := _world(&"gun", 3, 2)
	Offers.roll(
		later, later.rewards.index_of(later.add_reward(RewardStore.Kind.ALTAR, Vector2.ONE, 0))
	)
	assert_eq(later.loot_guaranteed, 0, "floor 2 guarantees nothing")


func test_the_guarantee_replaces_a_card_when_none_fits() -> void:
	var w := _world(&"gun")
	var triggers := PackedInt32Array(
		[_it(w, &"trigger_on_hit"), _it(w, &"trigger_on_kill"), _it(w, &"trigger_on_end")]
	)
	var out := LootPacing.guarantee(w, triggers.duplicate())
	assert_eq(out.slice(0, 2), triggers.slice(0, 2), "the first two cards stay")
	assert_true(LootPacing.compatible(w, out[2]), "the last one is a compatible card")
	assert_ne(out[2], triggers[2])
	var again := _world(&"gun")
	again.loot_guaranteed = 2
	assert_eq(LootPacing.guarantee(again, triggers.duplicate()), triggers, "used up: no change")


func test_a_trigger_a_mutation_and_a_dead_card_are_not_compatible() -> void:
	var w := _world(&"gun")
	assert_false(LootPacing.compatible(w, _it(w, &"trigger_on_hit")), "a trigger")
	assert_false(LootPacing.compatible(w, _it(w, &"mut_double_exposure")), "a mutation")
	assert_false(LootPacing.compatible(w, _it(w, &"wide_arc")), "the Blade's card on a Gun run")
	assert_true(LootPacing.compatible(w, _it(w, &"gun_echo")), "Echo, nothing left of it")
	assert_true(w.wand_table.after_trigger_dead.has(&"gun_echo"))
	_hold(w, &"trigger_on_hit", 1)
	assert_false(
		LootPacing.compatible(w, _it(w, &"gun_echo")), "Echo right of a trigger does nothing"
	)
	assert_true(LootPacing.compatible(w, _it(w, &"gun_big_shot")), "Big Shot still acts there")


# --- The jackpot ---------------------------------------------------------------------------------------------------
func test_a_jackpot_lifts_a_card_past_the_ceiling_and_says_so() -> void:
	var w := _world(&"gun")
	w.loot_pacing.jackpot_permille = 1000
	w.loot_pacing.guaranteed_altars = PackedInt32Array([0, 0, 0, 0])
	var big := _hold(w, &"gun_big_shot", 2)
	var pool := LootPacing.jackpot_pool(w, PackedInt32Array())
	assert_has(pool, big, "the held card at the ceiling")
	for c in pool:
		assert_true(
			c == big or LootPacing.category(w, c) == LootPacing.Category.MUTATION, "only those"
		)
	var id := w.add_reward(RewardStore.Kind.ALTAR, w.player_pos() + Vector2(0.5, 0), 0)
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)
	assert_eq(w.choosing, id, "it opens")
	var r := w.rewards.index_of(id)
	var offer := w.rewards.offer_of(r)
	var reader := WorldReader.new(w)
	var marked := -1
	for k in offer.size():
		if reader.choice_jackpot(k):
			marked = k
	assert_gte(marked, 0, "one card is the jackpot's")
	assert_has(pool, offer[marked])
	assert_eq(w.loot_jackpots, PackedInt32Array([id, offer[marked]]), "stored with the offer")
	if offer[marked] == big:
		var pick := InputFrame.new()
		pick.pick = marked + 1
		w.step(pick)
		assert_eq(CardLevels.level(w, big), 3, "one level past floor 1's ceiling")


func test_no_jackpot_draw_without_its_chance() -> void:
	var w := _world(&"gun")
	w.loot_pacing.jackpot_permille = 0
	for n in 8:
		var id := w.add_reward(RewardStore.Kind.CHEST, Vector2(100 + n, 100), 0)
		Offers.roll(w, w.rewards.index_of(id))
	assert_true(w.loot_jackpots.is_empty())


func test_the_shipped_jackpot_is_rare() -> void:
	var hits := 0
	var offers := 0
	for s in 200:
		var w := _world(&"blade", 1000 + s)
		for n in 3:
			var id := w.add_reward(RewardStore.Kind.CHEST, Vector2(100 + n, 100), 0)
			Offers.roll(w, w.rewards.index_of(id))
			offers += 1
		hits += w.loot_jackpots.size() / 2
	gut.p("jackpots: %d in %d chest offers (shipped 15 per mille)" % [hits, offers])
	assert_lt(hits, offers / 20, "rare (under 1 in 20)")


# --- The boss's altar ----------------------------------------------------------------------------------------------
func test_the_boss_altar_offers_an_upgrade_an_advanced_or_trigger_card_and_a_legendary_stat(
) -> void:
	var w := _world(&"gun")
	w.legendary_table.card_permille = 0
	var big := _hold(w, &"gun_big_shot", 2)
	var offer := Offers.roll_legendary(w)
	assert_eq(offer.size(), 3)
	assert_eq(
		offer[0], big, "the upgrade: the only held wand card, past floor 1's ceiling to floor 2's"
	)
	var cat := LootPacing.category(w, offer[1])
	assert_true(
		cat == LootPacing.Category.ADVANCED or cat == LootPacing.Category.TRIGGER,
		"an advanced or trigger card"
	)
	assert_ne(w.item_tables[offer[1]].rarity, ItemTable.LEGENDARY, "never a Legendary one here")
	assert_eq(Offers.type_of(offer[2]), Offers.STAT)
	assert_eq(Offers.rarity_of(offer[2]), Offers.LEGENDARY, "a legendary stat card")
	BuildSlots.take(w, offer[0])
	assert_eq(CardLevels.level(w, big), 3, "one level up, no level-5 grant")
	BuildSlots.take(w, offer[1])
	if CardLevels.is_card(w, offer[1]):
		assert_eq(CardLevels.level(w, offer[1]), 1, "a new card at level 1")
	var top := _world(&"gun")
	top.legendary_table.card_permille = 0
	_hold(top, &"gun_big_shot", 3)
	for c in Offers.roll_legendary(top):
		assert_ne(
			c, _it(top, &"gun_big_shot"), "at floor 2's ceiling: no upgrade from floor 1's boss"
		)


func test_the_boss_altars_legendary_chance_takes_the_cards_place() -> void:
	var w := _world(&"gun")
	w.legendary_table.card_permille = 1000
	var offer := Offers.roll_legendary(w)
	assert_eq(w.item_tables[offer[0]].rarity, ItemTable.LEGENDARY, "the Legendary card first")
	for k in range(1, offer.size()):
		assert_eq(Offers.type_of(offer[k]), Offers.STAT, "no upgrade held: legendary stat cards")


func test_the_boss_data_retires_the_level_five_grant() -> void:
	var def: LegendaryDefinition = _repo.get_def(&"legendary", &"boss")
	assert_eq(def.wand_level, 0, "retired")
	assert_true(def.upgrade_choice)
	assert_eq(def.card_categories, [&"advanced", &"trigger"] as Array[StringName])
	var bad := def.duplicate() as LegendaryDefinition
	bad.wand_level = 5
	assert_gt(bad.validate().size(), 0, "a level-5 grant is refused")


# --- Saves and the hash --------------------------------------------------------------------------------------------
func test_the_guarantee_and_jackpots_are_saved_hashed_and_an_older_save_lacks_them() -> void:
	for f: StringName in [&"loot_guaranteed", &"loot_jackpots"]:
		assert_has(WorldSnapshot.ADDED_SINCE_V05[&"World"], f)
	var w := _world()
	var h := w.state_hash()
	w.loot_guaranteed = 1
	assert_ne(w.state_hash(), h, "hashed once used")
	w.loot_jackpots = PackedInt32Array([4, 9])
	var snap := WorldSnapshot.take(w)
	var back := _world()
	assert_eq(WorldSnapshot.apply(back, snap), "")
	assert_eq(back.loot_guaranteed, 1)
	assert_eq(back.loot_jackpots, PackedInt32Array([4, 9]))
	assert_eq(back.state_hash(), w.state_hash())
	var old := WorldSnapshot.take(_world())
	(old["world"] as Dictionary).erase(&"loot_guaranteed")
	(old["world"] as Dictionary).erase(&"loot_jackpots")
	var restored := _world()
	assert_eq(WorldSnapshot.apply(restored, old), "", "an older save loads")
	assert_eq(restored.loot_guaranteed, 0)
	assert_true(restored.loot_jackpots.is_empty())
	assert_eq(
		restored.state_hash(), _world().state_hash(), "an untouched world hashes as before FL"
	)
