extends GutTest
## v0.10.5 W3-P1 + W3-P2 (docs/roadmap/v0.10.5/W3_O4_PROGRESSION_G1.md P1, P2; owner approved 2026-11-04;
## ElementStack, LootPacing.element_ceiling): elements add with diminishing returns on one target (an element's damage
## on an enemy carrying k other elements counts at 100 / 70 / 50 / 35 %), an element card's own damage moves from Lv 1
## to Lv 2-3 (el_level_permille), and element levels follow the floor (Lv 1 on floor 1, Lv 2 on floors 2-3, Lv 3 from
## floor 4; Lv 3 from floor 1 of loop 2). Old saves keep their levels.

const W := preload("res://tests/support/mx4_world.gd")
const BIG := 9000000
const CARDS := ElementPairs.CARDS

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


## A Gun world holding the element cards `ids` at `lv`, a standing dummy at 4 m, the pairs' table loaded.
func _world(ids: Array, lv: int = 1) -> World:
	var w := W.world(&"gun", ids, [[Vector2(4, 0), BIG]])
	w.pair_table = WandCompiler.pairs(W.repo())
	for id: StringName in ids:
		CardLevels.set_level(w, W.item(w, id), lv)
	ElementPairs.refresh(w)
	W.run(w, 1)
	return w


func _carry(w: World, i: int, elements: Array) -> void:
	var a := w.actors
	for e: int in elements:
		match e:
			ElementStack.FIRE:
				a.burn_stacks[i] = 1
				a.burn_t[i] = 600
			ElementStack.VENOM:
				a.poison_stacks[i] = 1
				a.poison_t[i] = 600
			ElementStack.BLEED:
				a.bleed_stacks[i] = 1
				a.bleed_t[i] = 600
			ElementStack.FROST:
				a.frost_stacks[i] = 1
				a.frost_t[i] = 600
			ElementStack.STORM:
				a.shock_stacks[i] = 1
				a.shock_t[i] = 600


func _tick(w: World, i: int, amount: int, element: StringName) -> int:
	var a := w.actors
	var before := a.hp[i]
	Damage.tick_dot(w, i, amount, a.ids[0], a.ids[0], &"test", element)
	return before - a.hp[i]


# --- P1: the falloff ----------------------------------------------------------------------------------------------
func test_the_falloff_is_data_and_follows_the_other_elements_on_the_target() -> void:
	var def := _repo.get_def(&"element_pairs", &"element_pairs") as ElementPairsDefinition
	assert_eq(
		def.stack_falloff_permille, PackedInt32Array([1000, 700, 500, 350]), "the shipped row"
	)
	var w := _world([])
	var others := [ElementStack.VENOM, ElementStack.BLEED, ElementStack.FROST, ElementStack.STORM]
	var want := [1000, 700, 500, 350, 350]
	for k in 5:
		_carry(w, 1, others.slice(0, k))
		assert_eq(ElementStack.falloff_permille(w, 1, ElementStack.FIRE), want[k], "%d others" % k)
	_carry(w, 1, [ElementStack.FIRE])
	assert_eq(ElementStack.others(w, 1, ElementStack.FIRE), 4, "its own element is not counted")


func test_a_burn_tick_on_a_poisoned_enemy_counts_at_70_and_a_plain_one_in_full() -> void:
	var w := _world([])  # no element card held: the level share is 1000
	assert_eq(_tick(w, 1, 100, &"ember"), 100, "nothing else on it")
	_carry(w, 1, [ElementStack.VENOM])
	assert_eq(_tick(w, 1, 100, &"ember"), 70, "one other element")
	_carry(w, 1, [ElementStack.BLEED])
	assert_eq(_tick(w, 1, 100, &"ember"), 50, "two")
	_carry(w, 1, [ElementStack.FROST])
	assert_eq(_tick(w, 1, 100, &"ember"), 35, "three")
	assert_eq(_tick(w, 1, 100, &""), 100, "a tick of no element is untouched")


func test_an_elements_hits_fall_off_and_the_plain_attack_does_not() -> void:
	var w := _world([])
	_carry(w, 1, [ElementStack.FIRE, ElementStack.VENOM])
	var a := w.actors
	for pair: Array in [
		[&"storm_core", 500], [&"storm_strike", 500], [&"ember_core", 700], [&"", 1000]
	]:
		a.charged_t[1] = 0  # v0.10.5 W3-P1b: a Lightning hit charges its enemy; each hit here reads the same two
		var before := a.hp[1]
		Damage.hit(w, 1, 1000, a.ids[0], a.ids[0], w.take_root(), 0, a.pos(0), a.pos(1), pair[0])
		assert_eq(before - a.hp[1], pair[1], "%s on a burning, poisoned enemy" % pair[0])


func test_heat_sync_s_bonus_falls_off_on_a_target_with_other_elements() -> void:
	var w := _world([&"ember_core"], 3)
	var heat := w.item_tables[W.item(w, &"ember_core")].el_heat_permille
	_carry(w, 1, [ElementStack.FIRE])
	assert_eq(ElementLevelsFsf.attacker_mult(w, 1, w.actors.ids[0]), 1000 + heat, "fire alone")
	_carry(w, 1, [ElementStack.VENOM])
	assert_eq(
		ElementLevelsFsf.attacker_mult(w, 1, w.actors.ids[0]),
		1000 + heat * 700 / 1000,
		"its bonus at 70 % on a poisoned enemy"
	)


func test_without_the_pairs_table_nothing_falls_off() -> void:
	var w := _world([])
	w.pair_table = null
	_carry(w, 1, [ElementStack.VENOM, ElementStack.BLEED])
	assert_eq(_tick(w, 1, 100, &"ember"), 100)


func test_a_bad_falloff_row_is_refused() -> void:
	var def := (
		_repo.get_def(&"element_pairs", &"element_pairs").duplicate() as ElementPairsDefinition
	)
	var base := def.validate().size()
	for row in [
		PackedInt32Array([1000, 1100]), PackedInt32Array([0]), PackedInt32Array([9, 8, 7, 6, 5])
	]:
		def.stack_falloff_permille = row
		assert_gt(def.validate().size(), base, "%s refused" % row)


# --- P2: the level shift ------------------------------------------------------------------------------------------
func test_an_elements_damage_moves_from_lv1_to_lv3() -> void:
	for pair: Array in [
		[&"ember_core", &"ember", [750, 900, 1150]],
		[&"venom_core", &"venom", [750, 900, 1150]],
		[&"shared_bleed", &"bleed", [850, 950, 1050]],
	]:
		for lv in [1, 2, 3]:
			var w := _world([pair[0]], lv)
			var want: int = pair[2][lv - 1]
			assert_eq(ElementStack.level_permille(w, ElementStack.of_id(pair[1])), want)
			assert_eq(_tick(w, 1, 1000, pair[1]), want, "%s Lv %d" % [pair[0], lv])
	var storm := _world([&"storm_core"], 3)
	assert_eq(ElementStack.level_permille(storm, ElementStack.STORM), 1100, "Lightning Lv 3")
	var frost := _world([&"frost_core"], 1)
	assert_eq(ElementStack.level_permille(frost, ElementStack.FROST), 1000, "Frost: no row")


func test_a_bad_level_row_is_refused() -> void:
	var def := _repo.get_def(&"items", &"venom_core").duplicate() as ItemDefinition
	var base := def.validate().size()
	for row in [PackedInt32Array([750, 900]), PackedInt32Array([50, 900, 1150])]:
		def.el_level_permille = row
		assert_gt(def.validate().size(), base, "%s refused" % row)


# --- P2: the ceilings by floor ------------------------------------------------------------------------------------
func _run_world(floor_index: int, loop: int = 1) -> World:
	var w := CardPoolSurvey.world(_repo, 7, &"gun", [])
	w.floor_index = floor_index
	w.loop = loop
	w.wand_table = WandCompiler.from_repo(_repo)
	w.legendary_table = RunContentCompiler.compile_legendary(
		_repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	w.loot_pacing = RunContentCompiler.compile_loot_pacing(_repo.get_def(&"loot_pacing", &"pacing"))
	return w


func _hold(w: World, id: StringName, lv: int) -> int:
	var k := AttackScenario.item_index(w.item_tables, id)
	assert_true(BuildSlots.take(w, k), "takes %s" % id)
	if lv > 1:
		assert_true(CardLevels.set_level(w, k, lv))
	return k


func test_element_ceilings_follow_the_floor_and_the_loop() -> void:
	for pair: Array in [
		[1, 1, 1], [2, 1, 2], [3, 1, 2], [4, 1, 3], [5, 1, 3], [1, 2, 3], [3, 3, 3]
	]:
		var w := _run_world(pair[0], pair[1])
		assert_eq(
			LootPacing.element_ceiling(w), pair[2], "floor %d of loop %d" % [pair[0], pair[1]]
		)
	var plain := _run_world(1)
	plain.loot_pacing = null
	assert_eq(LootPacing.element_ceiling(plain), CardLevels.MAX_LEVEL, "no table: no ceiling")


func test_a_held_element_at_its_floors_ceiling_waits_for_the_next_floor() -> void:
	for pair: Array in [[1, 1], [2, 2], [3, 2]]:
		var w := _run_world(pair[0])
		var k := _hold(w, &"venom_core", pair[1])
		assert_does_not_have(ItemPool.available(w), k, "floor %d: Lv %d waits" % pair)
		assert_false(Shop.can_apply(w, k), "nor sold")
		assert_true(CardLevels.can_take(w, k, CardLevels.MAX_LEVEL), "the dev grant's rule")
		var later := _run_world(pair[0] + 1 if pair[0] < 3 else 4)
		var k2 := _hold(later, &"venom_core", pair[1])
		if pair[0] != 2:
			assert_has(
				ItemPool.available(later), k2, "the floor after offers Lv %d" % [pair[1] + 1]
			)
	var f1 := _run_world(1)
	var twin := _hold(f1, &"gun_twin", 1)
	assert_has(ItemPool.available(f1), twin, "a card that is no element keeps the stage's ceiling")


func test_the_boss_upgrade_reaches_the_next_floors_element_ceiling() -> void:
	var w := _run_world(1)
	var k := _hold(w, &"venom_core", 1)
	assert_has(Offers.boss_upgrades(w, PackedInt32Array()), k, "floor 1's boss: to Lv 2")
	CardLevels.set_level(w, k, 2)
	assert_does_not_have(Offers.boss_upgrades(w, PackedInt32Array()), k, "never to Lv 3")
	var f3 := _run_world(3)
	var k3 := _hold(f3, &"venom_core", 2)
	assert_has(
		Offers.boss_upgrades(f3, PackedInt32Array()), k3, "floor 3's boss: to floor 4's Lv 3"
	)


func test_a_jackpot_lifts_an_element_one_past_its_own_ceiling() -> void:
	var w := _run_world(1)
	var k := _hold(w, &"venom_core", 1)
	assert_has(LootPacing.jackpot_pool(w, PackedInt32Array()), k, "at its ceiling: a jackpot card")
	CardLevels.set_level(w, k, 2)
	assert_does_not_have(LootPacing.jackpot_pool(w, PackedInt32Array()), k, "one past: no more")


# --- Old saves ----------------------------------------------------------------------------------------------------
func test_an_old_save_with_an_element_above_its_new_ceiling_keeps_its_level() -> void:
	var w := _run_world(1)
	w.pair_table = WandCompiler.pairs(_repo)
	var k := _hold(w, &"venom_core", 3)  # a floor-1 save from before P2
	var base := _run_world(1)
	base.pair_table = WandCompiler.pairs(_repo)
	var snap := WorldSnapshot.take(w)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "it loads (%s)" % WorldSnapshot.apply(base, snap))
	if restored == null:
		return
	assert_eq(restored.state_hash(), w.state_hash(), "the same world")
	assert_eq(CardLevels.level(restored, k), 3, "its Lv 3 stays")
	assert_eq(
		ElementStack.level_permille(restored, ElementStack.VENOM), 1150, "and deals Lv 3's share"
	)
	assert_does_not_have(ItemPool.available(restored), k, "it is just not offered again")
