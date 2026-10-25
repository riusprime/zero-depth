extends GutTest
## v0.8.0 RR (owner O33, PLAN step RR; docs/roadmap/v0.8.0/evidence/RARITY.md): four card tiers (Common, Rare, Epic,
## Legendary); the build-breaking cards are Legendary, mostly the boss's (a chance per boss altar that rises per loop,
## and one more pick per loop); altars, chests and the shop draw each tier at its weight (a Legendary rarely); Chain
## Blast is the Legendary pre-nerf Explosive (its splits and casts explode, its blasts never merge).

const LEGENDARY_IDS := [
	"chain_blast",
]
const EPIC_IDS := ["blade_storm", "gun_twin", "riposte_chain", "split_shot"]

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(build: StringName = &"gun", seed_value: int = 11) -> World:
	var w := CardPoolSurvey.world(_repo, seed_value, build, [])
	w.wand_table = WandCompiler.from_repo(_repo)
	w.legendary_table = RunContentCompiler.compile_legendary(
		_repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	return w


func _idx(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


func _press(w: World, bits: int, pick: int = InputFrame.PICK_NONE) -> void:
	var f := InputFrame.make(Vector2i.ZERO, 0, 0, 0, bits)
	f.pick = pick
	w.step(f)


func test_the_shipped_tiers() -> void:
	var w := _world()
	var legend := []
	var epic := []
	for t in w.item_tables:
		if t.retired:
			continue
		match t.rarity:
			ItemTable.LEGENDARY:
				legend.append(String(t.id))
			ItemTable.EPIC:
				epic.append(String(t.id))
	legend.sort()
	epic.sort()
	assert_eq(legend, LEGENDARY_IDS, "the build-breaking cards are Legendary")
	assert_eq(epic, EPIC_IDS, "the multipliers are Epic")
	assert_eq(w.item_tables[_idx(w, &"chain_blast")].tier(), ItemTable.TIER_LEGENDARY)
	assert_eq(w.item_tables[_idx(w, &"split_shot")].tier(), ItemTable.TIER_EPIC)
	assert_eq(int(Offers.info(w, _idx(w, &"chain_blast"))["rarity"]), Offers.LEGENDARY)
	assert_eq(int(Offers.info(w, _idx(w, &"gun_twin"))["rarity"]), Offers.EPIC)
	assert_eq(ItemDefinition.Rarity.values().size(), 4, "four tiers")


func test_tier_weights_keep_common_and_rare_draws() -> void:
	var w := _world()
	var t := w.reward_table
	var common := _idx(w, &"executioner")  # a common passive (no weapon)
	var rare := _idx(w, &"wildfire")
	var epic := _idx(w, &"gun_twin")  # a Gun wand card: × the weapon's own 1.5
	var legend := _idx(w, &"chain_blast")
	assert_eq(ItemPool.card_weight(w, common, 3), 1000, "a common one: 1 × 1000 as before")
	assert_eq(ItemPool.card_weight(w, rare, 3), 3000, "a rare one: rare_weight × 1000 as before")
	assert_eq(
		ItemPool.card_weight(w, epic, 3, t.epic_permille_chest), t.epic_permille_chest * 3 / 2
	)
	assert_eq(
		ItemPool.card_weight(w, legend, 3, 1500, t.legendary_permille_chest),
		t.legendary_permille_chest
	)
	assert_eq(ItemPool.card_weight(w, legend, 3), 0, "no legendary weight: never drawn")
	assert_eq(
		ItemPool.card_weight(w, epic, 3),
		4500,
		"a world without tier weights: an epic one as a rare one"
	)


func test_altars_and_chests_offer_a_legendary_card_rarely_and_never_without_its_weight() -> void:
	var seen := 0
	var draws := 0
	for s in 300:
		var w := _world(&"gun", 500 + s)
		for c in Offers.draw(w, true, 3):
			draws += 1
			if Offers.type_of(c) == Offers.MOD and w.item_tables[c].rarity == ItemTable.LEGENDARY:
				seen += 1
		var off := _world(&"gun", 500 + s)
		off.reward_table.legendary_permille_chest = 0
		for c in Offers.draw(off, true, 3):
			assert_false(
				(
					Offers.type_of(c) == Offers.MOD
					and off.item_tables[c].rarity == ItemTable.LEGENDARY
				),
				"weight 0: never"
			)
	assert_lt(seen, draws / 20, "rarely (under 1 card in 20)")
	gut.p("Legendary cards in 300 chest offers: %d of %d cards" % [seen, draws])


func test_the_boss_altar_holds_a_legendary_card_at_its_chance() -> void:
	var w := _world()
	w.legendary_table.card_permille = 1000
	var offer := Offers.roll_legendary(w)
	assert_eq(offer.size(), 3)
	assert_eq(
		w.item_tables[offer[0]].rarity, ItemTable.LEGENDARY, "chance 1: the first card is Legendary"
	)
	for k in range(1, offer.size()):
		var c := offer[k]
		assert_false(
			Offers.type_of(c) == Offers.MOD and w.item_tables[c].rarity == ItemTable.LEGENDARY,
			"the other cards are the boss's upgrade and legendary stat cards (v0.8.0 FL)"
		)
	var none := _world()
	none.legendary_table.card_permille = 0
	for c in Offers.roll_legendary(none):
		assert_false(
			Offers.type_of(c) == Offers.MOD and none.item_tables[c].rarity == ItemTable.LEGENDARY
		)


func test_the_chance_and_the_picks_grow_per_loop() -> void:
	var t := _world().legendary_table
	assert_eq(t.chance(2) - t.chance(1), t.card_loop_permille, "one step a loop")
	assert_eq(t.chance(99), 1000, "capped at 1")
	assert_eq(t.extra_picks(1), 0, "loop 1: one pick")
	assert_eq(t.extra_picks(2), t.extra_picks_per_loop, "loop 2: one more")
	assert_eq(t.extra_picks(99), t.extra_picks_max, "capped")
	assert_gt(t.card_permille, 0, "the shipped boss offers Legendary cards")


func test_a_later_loops_boss_altar_stays_for_its_extra_picks() -> void:
	var w := _world()
	var id := w.add_reward(RewardStore.Kind.LEGENDARY, Vector2(1.0, 0.0), 0)
	w.legendary_id = id
	w.legendary_picks = 1
	_press(w, InputFrame.INTERACT)
	assert_eq(w.choosing, id, "it opens")
	var first := w.rewards.offer_of(w.rewards.index_of(id))
	_press(w, 0, 1)
	assert_eq(w.choosing, -1, "the pick closes the choice")
	var r := w.rewards.index_of(id)
	assert_gte(r, 0, "the altar stays for the next pick")
	assert_eq(w.legendary_picks, 0, "one pick used")
	assert_eq(w.rewards.rolled[r], 0, "its offer cleared")
	assert_true(
		w.items_owned.has(first[0]) or Offers.type_of(first[0]) != Offers.MOD, "the card taken"
	)
	var h := w.state_hash()
	_press(w, InputFrame.INTERACT)
	assert_eq(w.choosing, id, "it opens again with a fresh offer")
	_press(w, 0, 1)
	assert_eq(w.rewards.index_of(id), -1, "the last pick takes it")
	assert_ne(h, w.state_hash())


func test_loop_one_boss_altar_gives_one_pick() -> void:
	var w := _world()
	w.loop = 1
	assert_eq(w.legendary_table.extra_picks(w.loop), 0)
	var id := w.add_reward(RewardStore.Kind.LEGENDARY, Vector2(1.0, 0.0), 0)
	_press(w, InputFrame.INTERACT)
	_press(w, 0, 1)
	assert_eq(w.rewards.index_of(id), -1, "one pick, then it is gone (as before RR)")


func test_chain_blast_is_the_pre_nerf_explosive() -> void:
	var w := WandLab.fight(&"gun", [&"gun_spread", &"split_shot", &"chain_blast"])
	var bolt := Modifiers.bolt(w)
	var blast: AttackHook = null
	var split: AttackHook = null
	for k in bolt.hooks:
		if k.id == &"chain_blast":
			blast = k
		elif k.id == &"split_shot":
			split = k
	assert_not_null(blast, "the shot explodes")
	assert_not_null(split, "the shot splits")
	var split_blast := false
	for k in split.child.hooks:
		split_blast = split_blast or k.id == &"chain_blast"
	assert_true(split_blast, "its splits explode too (Explosive's don't: BL B6)")
	var k := AttackHook.new()
	k.id = &"chain_blast"
	k.child = AttackSpec.new()
	k.child.radius_m = 1.4
	for n in 12:
		assert_false(
			Attacks.merged(w, k, Vector2(0.05 * n, 0.0)), "Chain Blast's blasts never merge"
		)


func test_legendary_picks_is_saved_and_an_older_save_lacks_it() -> void:
	assert_has(WorldSnapshot.ADDED_SINCE_V05[&"World"], &"legendary_picks")
	var w := _world()
	w.legendary_picks = 2
	var snap := WorldSnapshot.take(w)
	var back := _world()
	WorldSnapshot.apply(back, snap)
	assert_eq(back.legendary_picks, 2, "restored")
