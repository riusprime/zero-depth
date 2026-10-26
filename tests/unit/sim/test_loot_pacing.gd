extends GutTest
## v0.8.0 FL (owner O91, "floor-paced loot"; docs/roadmap/v0.8.0/BALANCE_PASS.md "FL"; LootPacing): the pacing table
## (data/rewards/pacing.tres, the dev panel's economy group), the stage by floor, loop and Deep floor, the category
## weights per stage, the level ceilings 2/3/5 across every card source (altars, chests, the shop's restock and
## reroll, the events' and cores' rule, the boss's upgrade). Part 2 (test_loot_rewards.gd): the guarantee, the
## jackpot, the boss's altar and the saves. Mechanics only.

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


# --- The table and the categories ----------------------------------------------------------------------------------
func test_the_table_compiles_from_the_data_and_the_dev_panel_shows_it() -> void:
	var def: LootPacingDefinition = _repo.get_def(&"loot_pacing", &"pacing")
	assert_not_null(def, "data/rewards/pacing.tres")
	assert_eq(def.validate().size(), 0, "valid")
	var t := RunContentCompiler.compile_loot_pacing(def)
	assert_eq(t.ceilings, PackedInt32Array([2, 3, 5, 5]), "ceilings 2/3/5, 5 deep")
	assert_eq(t.guaranteed_altars, PackedInt32Array([2, 0, 0, 0]), "two altars on floor 1")
	assert_eq(t.jackpot_permille, 15)
	assert_eq(t.weights[0], PackedInt32Array([1400, 1400, 400, 600, 20]), "floor 1")
	assert_eq(t.weights[1], PackedInt32Array([1000, 1000, 1000, 1200, 100]), "floor 2")
	assert_eq(t.weights[2], PackedInt32Array([900, 900, 1200, 1200, 300]), "floor 3")
	assert_eq(t.weights[3], PackedInt32Array([800, 800, 1300, 1200, 600]), "deep and loops")
	var economy: Array = []
	for g: Array in DevFields.GROUPS:
		if g[0] == "economy":
			economy = g
	assert_has(DevFields.sources(economy), "res://data/rewards/pacing.tres", "in the economy group")
	var paths := []
	for row: Dictionary in DevFields.rows(def):
		paths.append(row["path"])
	for p in ["level_ceilings/0", "floor_1_weights_permille/4", "jackpot_permille"]:
		assert_has(paths, p, "the panel tunes %s" % p)


func test_a_bad_table_is_refused() -> void:
	var def := LootPacingDefinition.new()
	def.id = &"bad"
	def.level_ceilings = PackedInt32Array([3, 2, 5, 5])
	def.floor_2_weights_permille = PackedInt32Array([1000])
	def.jackpot_permille = 2000
	assert_gte(def.validate().size(), 3, "a falling ceiling, a short row, a jackpot over 1000")


func test_every_wand_and_trigger_card_has_a_category() -> void:
	var w := _world()
	assert_eq(ItemDefinition.LOOT_CATEGORIES.size(), LootPacing.Category.size(), "the same order")
	var seen := {}
	for k in w.item_tables.size():
		var t := w.item_tables[k]
		var cat := t.loot_category
		seen[cat] = true
		if t.retired:
			continue
		if t.tags.has("wand") or t.kind == ItemTable.Kind.TRIGGER:
			assert_ne(cat, LootPacing.Category.OTHER, "%s names a category" % t.id)
		if t.tags.has("mutation"):
			assert_eq(cat, LootPacing.Category.MUTATION, "%s" % t.id)
		if t.kind == ItemTable.Kind.TRIGGER:
			var want := (
				LootPacing.Category.ADVANCED
				if t.rarity == ItemTable.LEGENDARY
				else LootPacing.Category.TRIGGER
			)
			assert_eq(cat, want, "%s: T1–T4 trigger, the ×2 triggers advanced" % t.id)
	for c in LootPacing.Category.values():
		assert_true(seen.has(c), "category %d is used" % c)
	for pair: Array in [
		[&"gun_big_shot", LootPacing.Category.FORM],
		[&"gun_spread", LootPacing.Category.FORM],
		[&"wide_arc", LootPacing.Category.FORM],
		[&"ember_core", LootPacing.Category.ELEMENT],
		[&"gravity_well", LootPacing.Category.ELEMENT],
		[&"gun_twin", LootPacing.Category.ADVANCED],
		[&"gun_echo", LootPacing.Category.ADVANCED],
		[&"finisher_plus", LootPacing.Category.ADVANCED],
		[&"shared_faultline", LootPacing.Category.ADVANCED],
		[&"trigger_on_hit", LootPacing.Category.TRIGGER],
		[&"mut_grand_finale", LootPacing.Category.MUTATION],
	]:
		assert_eq(LootPacing.category(w, _it(w, pair[0])), pair[1], "%s" % pair[0])


func test_a_card_definition_without_its_category_is_refused() -> void:
	var def: ItemDefinition = (
		(_repo.get_def(&"items", &"gun_big_shot") as ItemDefinition).duplicate()
	)
	def.loot_category = &""
	assert_gt(def.validate().size(), 0, "a wand card names a category")
	def.loot_category = &"trigger"
	assert_gt(def.validate().size(), 0, "only a trigger card is a trigger")
	def.loot_category = &"form"
	assert_eq(def.validate().size(), 0)


# --- The stage and the weights -------------------------------------------------------------------------------------
func test_the_stage_follows_the_floor_the_loop_and_a_deep_floor() -> void:
	var w := _world()
	for f in [1, 2, 3, 4]:
		w.floor_index = f
		assert_eq(LootPacing.stage(w), mini(f - 1, LootPacing.Stage.FLOOR_3), "floor %d" % f)
	w.floor_index = 3
	assert_eq(LootPacing.next_stage(w), LootPacing.Stage.DEEP, "after floor 3: the next loop")
	w.floor_index = 1
	w.loop = 2
	assert_eq(LootPacing.stage(w), LootPacing.Stage.DEEP, "a later loop's first floor")
	assert_eq(LootPacing.ceiling(w), 5)
	var plain := _world()
	plain.loot_pacing = null
	assert_eq(LootPacing.ceiling(plain), CardLevels.MAX_LEVEL, "no table: no ceiling")
	assert_eq(LootPacing.weight_permille(plain, _it(plain, &"gun_twin")), 1000, "no table: × 1")


func test_each_stage_weighs_each_category() -> void:
	var w := _world()
	var plain := _world()
	plain.loot_pacing = null
	var rt := w.reward_table
	var ids := [&"gun_big_shot", &"ember_core", &"gun_twin", &"trigger_on_hit"]  # form, element, advanced, trigger
	for s in 4:
		w.floor_index = mini(s + 1, 3)
		w.loop = 2 if s == 3 else 1
		for n in ids.size():
			var k := _it(w, ids[n])
			var base := ItemPool.card_weight(plain, k, rt.rare_weight_altar, rt.epic_permille_altar)
			var mult: int = w.loot_pacing.weights[s][n]
			assert_eq(
				ItemPool.card_weight(w, k, rt.rare_weight_altar, rt.epic_permille_altar),
				base * mult / 1000,
				"stage %d: %s × %d per mille" % [s, ids[n], mult]
			)
	var stat := Offers.stat_code(0, 0)
	assert_eq(LootPacing.weight_permille(w, stat), 1000, "a stat card keeps its weight")


func test_a_mutation_is_out_of_floor_ones_regular_draws() -> void:
	var w := _world()
	var rt := w.reward_table
	for id: StringName in [&"mut_double_exposure", &"mut_grand_finale"]:
		var k := _it(w, id)
		var wt := ItemPool.card_weight(
			w, k, rt.rare_weight_altar, rt.epic_permille_altar, rt.legendary_permille_altar
		)
		assert_eq(
			wt, 0, "%s: floor 1's altar weight rounds to nothing (the jackpot lets one in)" % id
		)


# --- The ceilings across the sources -------------------------------------------------------------------------------
func test_a_held_card_at_the_floors_ceiling_is_offered_no_more() -> void:
	# v0.9.5 CLV: Big Shot has one level now; Twin (3 levels) stands in on floor 1, a Blade card (5) on floors 2-3
	var cases := [
		[1, 2, &"gun", &"gun_twin"],
		[2, 3, &"blade", &"blade_storm"],
		[3, 5, &"blade", &"blade_storm"]
	]
	for pair: Array in cases:
		var w := _world(pair[2], 7, pair[0])
		var k := _hold(w, pair[3], pair[1] - 1)
		assert_has(ItemPool.available(w), k, "floor %d: below the ceiling, offered" % pair[0])
		assert_true(Shop.can_apply(w, k), "the shop's, the events' and the cores' rule agree")
		CardLevels.set_level(w, k, pair[1])
		if pair[1] < CardLevels.MAX_LEVEL:
			assert_does_not_have(
				ItemPool.available(w), k, "floor %d: at %d, no more" % [pair[0], pair[1]]
			)
			assert_false(Shop.can_apply(w, k), "nor bought, nor an event's, nor a core's drop")
			assert_true(CardLevels.can_take(w, k, CardLevels.MAX_LEVEL), "the dev grant's rule")
		var later := _world(pair[2], 7, mini(pair[0] + 1, 3))
		var k2 := _hold(later, pair[3], pair[1])
		if pair[1] < CardLevels.MAX_LEVEL:
			assert_has(ItemPool.available(later), k2, "the next floor offers it again")


func test_no_source_draws_a_card_past_the_ceiling() -> void:
	for s in SEEDS:
		var w := _world(&"gun", 400 + s)
		w.loot_pacing.jackpot_permille = 0  # the jackpot's exception has its own test
		w.shop_table = ContentCompiler.compile_shop(_repo.get_def(&"shop", &"terminal"))
		var capped := PackedInt32Array()
		for id: StringName in [&"gun_big_shot", &"gun_pierce", &"ember_core"]:
			capped.append(_hold(w, id, 2))
		for kind: int in [RewardStore.Kind.ALTAR, RewardStore.Kind.CHEST]:
			var id := w.add_reward(kind, Vector2(100, 100), 0)
			for c in Offers.roll(w, w.rewards.index_of(id)):
				assert_false(capped.has(c), "seed %d: an altar or chest offered a capped card" % s)
		Shop.restock(w)
		for c in w.shop.offer:
			assert_false(capped.has(c), "seed %d: the shop's stock" % s)
		Shop.restock_unsold(w)  # the reroll's draw
		for c in w.shop.offer:
			assert_false(capped.has(c), "seed %d: the reroll" % s)
		for n in 6:
			var c := CoreTheft.draw_card(w, w.rng_loot, Stats.Rarity.RARE)
			assert_false(capped.has(c), "seed %d: a core" % s)
		var lid := w.add_reward(RewardStore.Kind.LEGENDARY, Vector2(90, 90), 0)
		w.legendary_table.card_permille = 0
		for c in Offers.roll(w, w.rewards.index_of(lid)):
			if capped.has(c):
				assert_eq(CardLevels.level(w, c), 2, "the boss's upgrade: below floor 2's 3")


func test_the_overrun_and_the_epic_altar_offer_no_wand_card() -> void:
	for s in 6:
		var w := _world(&"blade", 600 + s)
		for c in Overrun.offer(w):
			assert_eq(Offers.type_of(c), Offers.ABILITY, "the Overrun: ability cards only")
		for c in Offers.roll_epic(w):
			assert_ne(
				Offers.type_of(c), Offers.MOD, "the epic altar: ability level-ups and stat cards"
			)
