extends GutTest
## v0.10.5 W3-P3 (docs/roadmap/v0.10.5/W3_O4_PROGRESSION_G1.md P3, owner-approved; loops stay "a wall"): overlevels.
## From loop 2 every wand card's cap rises by one a loop past its own level_max (pacing.tres overlevels_per_loop), the
## offers bring a held card at its old cap again, and each overlevel adds +15 % (overlevel_permille, per category) to
## the card's main number: a damage or share op, a hook's share, an element's damage, else the damage of the attacks
## the card shapes. The forecasts read the same functions. Old saves (levels at most level_max) load unchanged.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


## A run's card world on `loop` (the pacing table, the element pairs), as test_loot_pacing's.
func _world(loop: int, build: StringName = &"gun", pacing: bool = true) -> World:
	var w := CardPoolSurvey.world(_repo, 7, build, [])
	w.floor_index = 1
	w.loop = loop
	w.wand_table = WandCompiler.from_repo(_repo)
	w.pair_table = WandCompiler.pairs(_repo)
	if pacing:
		w.loot_pacing = RunContentCompiler.compile_loot_pacing(
			_repo.get_def(&"loot_pacing", &"pacing")
		)
	return w


func _it(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _hold(w: World, id: StringName, level: int = 1) -> int:
	var k := _it(w, id)
	assert_true(BuildSlots.take(w, k), "takes %s" % id)
	if level > 1:
		assert_true(CardLevels.set_level(w, k, level))
	return k


func test_the_data_ships_one_overlevel_a_loop_at_15_percent() -> void:
	var t := RunContentCompiler.compile_loot_pacing(_repo.get_def(&"loot_pacing", &"pacing"))
	assert_eq(t.overlevels_per_loop, 1)
	assert_eq(
		Array(t.overlevel_permille),
		[150, 150, 150, 150, 150],
		"form, element, advanced, trigger, mutation"
	)


func test_caps_rise_one_a_loop_past_the_cards_own_max() -> void:
	for loop in [1, 2, 3]:
		var w := _world(loop)
		var up: int = loop - 1
		assert_eq(CardLevels.cap(w, _it(w, &"gun_void")), 1 + up, "a Gun form, loop %d" % loop)
		assert_eq(
			CardLevels.cap(w, _it(w, &"gun_pierce")), 1 + up, "a one-level card, loop %d" % loop
		)
		assert_eq(CardLevels.cap(w, _it(w, &"ember_core")), 3 + up, "an element, loop %d" % loop)
		assert_eq(
			CardLevels.cap(w, _it(w, &"chain_blast")), 5 + up, "a five-level card, loop %d" % loop
		)
		assert_eq(CardLevels.max_level(w, _it(w, &"gun_void")), 1, "max_level is the card's own")
	var lab := _world(3, &"gun", false)
	assert_eq(
		CardLevels.cap(lab, _it(lab, &"gun_void")), 1, "no pacing table (the labs): no overlevels"
	)
	var blade := _world(3, &"blade")
	assert_eq(CardLevels.cap(blade, _it(blade, &"wide_arc")), 7, "a Blade card Lv 7 at loop 3")


func test_a_held_card_at_its_old_cap_is_offered_again_from_loop_2() -> void:
	var w := _world(1)
	var k := _hold(w, &"gun_void")
	assert_false(CardLevels.can_take(w, k), "loop 1: a one-level card is not offered again")
	assert_does_not_have(ItemPool.available(w), k)
	w.loop = 2
	assert_true(CardLevels.can_take(w, k), "loop 2: its overlevel is offered")
	assert_has(ItemPool.available(w), k, "altars and chests draw it (ItemPool.available)")
	assert_true(Shop.can_apply(w, k), "the shop sells it")
	assert_eq(CardLevels.level_after(w, k), 2)
	assert_true(BuildSlots.take(w, k), "taking it again levels it up")
	assert_eq(CardLevels.level(w, k), 2)
	assert_eq(CardLevels.overlevels(w, k), 1)
	assert_eq(CardLevels.base_level(w, k), 1, "its ops stay at its own max")
	assert_false(CardLevels.can_take(w, k), "Lv 2 is loop 2's cap")
	assert_false(CardLevels.level_up(w, k))
	w.loop = 3
	assert_true(CardLevels.can_take(w, k), "loop 3 lifts it to Lv 3")


func test_an_element_climbs_past_its_loop_ceiling_and_the_jackpot_never_passes_the_cap() -> void:
	var w := _world(2)
	var k := _hold(w, &"ember_core", 3)
	assert_eq(LootPacing.element_ceiling(w), 3, "loop 2's element ceiling")
	assert_true(CardLevels.can_take(w, k), "Lv 3 → 4 is offered")
	assert_true(CardLevels.level_up(w, k))
	assert_eq(CardLevels.level(w, k), 4)
	assert_false(
		CardLevels.can_take(w, k, CardLevels.MAX_LEVEL + 1, 5),
		"a jackpot's higher ceiling stops at the cap"
	)
	assert_does_not_have(
		LootPacing.jackpot_pool(w, PackedInt32Array()), k, "no jackpot past the cap"
	)


func test_an_overlevel_adds_15_percent_to_a_forms_damage() -> void:
	var w := _world(2)
	var k := _hold(w, &"gun_void")
	var before := PlayerBuild.bolt_permille(w)
	assert_true(CardLevels.level_up(w, k))
	assert_eq(CardLevels.overlevel_now(w, k), 1150)
	assert_eq(CardLevels.weapon_overlevel_permille(w), 1150)
	assert_eq(
		PlayerBuild.bolt_permille(w),
		before * 1150 / 1000,
		"Void's shot × 1.15 (the weapon's factor)"
	)
	var sum := 0
	for n in 20:  # the factor's remainder carries: a 5-point shot lands 5.75 on average
		sum += PlayerBuild.bolt_damage(w, 5)
	assert_eq(
		sum,
		5 * 20 * PlayerBuild.bolt_permille(w) / 1000,
		"exact on average (the carried remainder)"
	)


func test_a_card_without_a_share_grows_the_attack_it_shapes() -> void:
	var w := _world(2)
	var p := _hold(w, &"gun_pierce")
	var h := _hold(w, &"gun_homing")
	assert_true(CardLevels.level_up(w, p))
	assert_eq(CardLevels.weapon_overlevel_permille(w), 1150, "Pierce Lv 2: the shot × 1.15")
	assert_true(CardLevels.level_up(w, h))
	assert_eq(
		CardLevels.weapon_overlevel_permille(w),
		1150 * 1150 / 1000,
		"two cards: their steps multiply"
	)
	var blade := _world(2, &"blade")
	var a := _hold(blade, &"wide_arc", 5)
	var before := PlayerBuild.melee_permille(blade)
	assert_true(CardLevels.level_up(blade, a))
	assert_eq(CardLevels.level(blade, a), 6)
	assert_eq(
		PlayerBuild.melee_permille(blade), before * 1150 / 1000, "Wide Arc Lv 6: the swing × 1.15"
	)


func test_a_share_card_grows_its_share_not_the_weapon() -> void:
	var w := _world(2)
	var k := _hold(w, &"split_shot", 3)
	assert_true(CardLevels.level_up(w, k))
	assert_eq(CardLevels.weapon_overlevel_permille(w), 1000, "Split's overlevel is its share's")
	var split: ModifierTable = w.item_tables[k].modifiers[0].at(3)
	var hook := split.overlevelled(1150).ops[0]
	assert_eq(hook.damage_permille, 500 * 1150 / 1000, "Split's share 500 → 575")
	var twin: ModifierTable = w.item_tables[_it(w, &"gun_twin")].modifiers[0].at(3)
	var grown := twin.overlevelled(1300)
	assert_eq(int(grown.ops[1].value), 750 * 1300 / 1000, "Twin's Lv 3 share 750 at two overlevels")
	assert_eq(int(grown.ops[0].value), int(twin.ops[0].value), "its copies stay")
	assert_eq(split.overlevelled(1000), split, "no overlevel: the card itself")
	var pierce: ModifierTable = w.item_tables[_it(w, &"gun_pierce")].modifiers[0]
	assert_eq(
		pierce.overlevelled(1150), pierce, "no share: the table itself (the weapon's factor grows)"
	)
	var found := false
	for m in Modifiers.build_modifiers(w):
		if m.id == &"split_shot":
			found = true
			assert_eq(m.ops[0].damage_permille, 575, "the compiled wand holds the grown share")
	assert_true(found)


func test_an_element_overlevel_grows_its_damage_share() -> void:
	var w := _world(2)
	var k := _hold(w, &"ember_core", 3)
	var e := ElementPairs.CARDS.find(&"ember_core")
	assert_gte(e, 0)
	var lv3 := ElementStack.level_permille(w, e)
	assert_eq(lv3, 1150, "Fire Lv 3: 1150 ‰ (W3-P2's row)")
	assert_true(CardLevels.level_up(w, k))
	assert_eq(
		ElementStack.level_permille(w, e), 1150 * 1150 / 1000, "Lv 4: × 1.15 on the row's last"
	)
	assert_eq(CardLevels.base_level(w, k), 3, "its rules stay at Lv 3")


func test_the_forecasts_show_the_overlevel_through_the_sim_functions() -> void:
	var w := _world(2)
	var k := _hold(w, &"gun_void")
	var f := CardForecast.of(w, k)
	assert_eq(int(f["old"]), 1)
	assert_eq(int(f["new"]), 2)
	assert_eq(int(f["over_old"]), 1000)
	assert_eq(int(f["over_new"]), CardLevels.overlevel_permille(w, k, 1))
	assert_eq(int(f["over_new"]), 1150)
	var before: Dictionary = WandForecast.of(w, w.mod_slots)["numbers"]
	CardLevels.level_up(w, k)
	var after: Dictionary = WandForecast.of(w, w.mod_slots)["numbers"]
	assert_gt(
		int(after["per_second_x10"]), int(before["per_second_x10"]), "the wand forecast's DPS rises"
	)
	var info := Offers.info(w, k)
	assert_eq(int(info["max_level"]), 2, "the card's cap now")
	assert_eq(int(info["base_max"]), 1, "its own max")
	assert_true(bool(info["wand"]), "a one-level card shows its level once it can overlevel")


func test_the_catch_up_does_not_count_overlevels() -> void:
	var w := _world(2)
	var k := _hold(w, &"chain_blast", 5)
	w.catch_up_table = ContentCompiler.compile_catch_up(_repo.get_def(&"scaling", &"catch_up"))
	var p := CatchUp.power(w)
	assert_true(CardLevels.level_up(w, k))
	assert_eq(CardLevels.level(w, k), 6)
	assert_eq(CatchUp.power(w), p, "P reads the card's own levels (the catch-up unchanged)")


func test_an_old_save_loads_with_its_levels_and_overlevels_wait_for_offers() -> void:
	var w := _world(2)
	var k := _hold(w, &"gun_void")
	var e := _hold(w, &"ember_core", 3)
	var h := w.state_hash()
	var snap := WorldSnapshot.take(w)
	var back := _world(2)
	assert_eq(WorldSnapshot.apply(back, snap), "", "restores")
	assert_eq(back.state_hash(), h, "the hash round-trips")
	assert_eq(CardLevels.level(back, k), 1, "no overlevel granted on load")
	assert_eq(CardLevels.level(back, e), 3)
	assert_true(CardLevels.can_take(back, k), "the next offer can lift it")
