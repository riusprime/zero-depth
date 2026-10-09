extends GutTest
## v0.6.0 MX2 (owner B7; docs/design/MODIFIER_ENGINE.md "The build"; BuildSlots): the build is the weapon, one utility
## pick, up to six modifier slots in pick order and unlimited stat cards. A held modifier levels up without a slot; a
## new one with the six full needs a swap (the altar's pick, the shop, a grant with no panel), which replaces the
## chosen slot in place or skips. Saves from before MX2 migrate deterministically; the slots round-trip a snapshot.

const MODS: Array = [
	&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
]

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(build: StringName = &"blade") -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	if build != &"":
		ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	t.crit_chance_permille = 0
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _ab(w: World, id: StringName) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].id == id:
			return Offers.ability_code(k)
	return -1


func _it(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _fill(w: World) -> void:
	for id: StringName in MODS:
		assert_true(BuildSlots.take(w, _ab(w, id)), "takes %s" % id)


func _pick(v: int) -> InputFrame:
	var f := InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0)
	f.pick = v
	return f


func test_what_takes_a_slot() -> void:
	var w := _world()
	for id: StringName in MODS:
		assert_true(BuildSlots.is_modifier(w, _ab(w, id)), "%s is a modifier" % id)
	for id: StringName in [&"combo_sword", &"pulse_gun", &"blink", &"aegis"]:
		assert_false(BuildSlots.is_modifier(w, _ab(w, id)), "%s takes no slot" % id)
	for id: StringName in [&"ricochet_core", &"ember_edge", &"razor_orbit", &"cluster_payload"]:
		assert_true(BuildSlots.is_modifier(w, _it(w, id)), "item %s is a modifier" % id)
	for id: StringName in [&"momentum", &"executioner", &"bulwark", &"kinetic_dash", &"wildfire"]:
		assert_false(BuildSlots.is_modifier(w, _it(w, id)), "item %s takes no slot" % id)
	assert_false(BuildSlots.is_modifier(w, Offers.stat_code(0, 0)), "a stat card takes no slot")


func test_the_start_holds_the_weapon_and_no_slot() -> void:
	var w := _world()
	assert_eq(w.mod_slots.size(), 0)
	assert_eq(w.ability_owned.size(), 1, "the weapon")
	assert_true(w.ability_tables[w.ability_owned[0]].start_weapon != 0)


func test_six_slots_fill_in_pick_order_and_compile_in_that_order() -> void:
	var w := _world()
	BuildSlots.take(w, _it(w, &"ember_edge"))
	BuildSlots.take(w, _ab(w, &"frost_nova"))
	BuildSlots.take(w, _it(w, &"long_edge"))
	assert_eq(
		w.mod_slots,
		PackedInt32Array([_it(w, &"ember_edge"), _ab(w, &"frost_nova"), _it(w, &"long_edge")])
	)
	assert_eq(
		Modifiers.book(w).modifier_ids,
		PackedStringArray(["ember_edge", "frost_nova", "long_edge"]),
		"the layer order is the pick order"
	)


func test_a_held_modifier_levels_up_without_a_slot() -> void:
	var w := _world()
	var bomb := _ab(w, &"bomb_lobber")
	BuildSlots.take(w, bomb)
	BuildSlots.take(w, bomb)
	BuildSlots.take(w, bomb)
	assert_eq(w.mod_slots.size(), 1)
	assert_eq(BuildSlots.level_at(w, 0), 3)
	_fill(w)  # five more new ones: the bomb's level-ups never took a slot
	assert_eq(w.mod_slots.size(), 6)
	assert_eq(BuildSlots.level_at(w, 0), 4, "_fill took the bomb once more: a level-up")
	assert_true(BuildSlots.take(w, bomb), "a level-up with the six full needs no swap")
	assert_eq(BuildSlots.level_at(w, 0), 5)


func test_the_utility_and_stat_cards_take_no_slot() -> void:
	var w := _world()
	_fill(w)
	assert_true(BuildSlots.full(w))
	assert_false(BuildSlots.needs_swap(w, _ab(w, &"blink")))
	BuildSlots.take(w, _ab(w, &"blink"))
	assert_eq(Abilities.utility(w), PlayerTable.Utility.BLINK, "the utility pick, outside the slots")
	for k in 12:
		BuildSlots.take(w, Offers.stat_code(Stats.Stat.DAMAGE, 0))
	assert_eq(w.stat_cards.size(), 12, "unlimited stat cards")
	assert_eq(w.mod_slots.size(), 6)


func test_a_seventh_modifier_needs_a_swap_and_replaces_in_place() -> void:
	var w := _world()
	_fill(w)
	var ember := _it(w, &"ember_edge")
	assert_true(BuildSlots.needs_swap(w, ember))
	assert_false(BuildSlots.take(w, ember), "no slot named: nothing changes")
	assert_false(w.items_owned.has(ember))
	var dropped := w.mod_slots[2]
	assert_true(BuildSlots.take(w, ember, 2))
	assert_eq(w.mod_slots[2], ember, "it takes the replaced slot's place in the order")
	assert_false(BuildSlots.held(w, dropped), "the replaced one left the build")
	assert_eq(w.mod_slots.size(), 6)
	assert_true(Modifiers.book(w).modifier_ids.has("ember_edge"))


func test_a_grant_with_no_panel_opens_the_swap_and_waits() -> void:
	var w := _world()
	_fill(w)
	var ember := _it(w, &"ember_edge")
	Offers.apply(w, ember)
	assert_true(BuildSlots.swapping(w))
	assert_eq(w.swap_source, BuildSlots.Source.GRANT)
	var t0 := w.tick
	w.step(_pick(InputFrame.PICK_NONE))
	assert_true(BuildSlots.swapping(w), "it waits for the answer")
	assert_eq(w.tick, t0 + 1, "the tick still counts")
	w.step(_pick(InputFrame.PICK_SWAP_BASE + 5))
	assert_false(BuildSlots.swapping(w))
	assert_eq(w.mod_slots[5], ember)


func test_a_grant_skip_leaves_the_card() -> void:
	var w := _world()
	_fill(w)
	var before := w.mod_slots.duplicate()
	Offers.apply(w, _it(w, &"ember_edge"))
	w.step(_pick(InputFrame.PICK_SWAP_SKIP))
	assert_false(BuildSlots.swapping(w))
	assert_eq(w.mod_slots, before)
	assert_false(w.items_owned.has(_it(w, &"ember_edge")))


func test_the_altar_pick_swaps_or_skips_back_to_the_cards() -> void:
	var w := _world()
	_fill(w)
	var ember := _it(w, &"ember_edge")
	var dmg := Offers.stat_code(Stats.Stat.DAMAGE, 0)
	var rid := w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	var i := w.rewards.index_of(rid)
	w.rewards.set_offer(i, PackedInt32Array([ember, dmg]))
	w.choosing = rid
	w.step(_pick(1))
	assert_true(BuildSlots.swapping(w), "a new modifier with six full: Swap")
	assert_eq(w.swap_source, BuildSlots.Source.REWARD)
	assert_eq(w.choosing, rid, "the altar stays open")
	w.step(_pick(InputFrame.PICK_SWAP_SKIP))
	assert_false(BuildSlots.swapping(w), "skip")
	assert_eq(w.choosing, rid, "back to the cards")
	assert_false(w.items_owned.has(ember))
	w.step(_pick(1))
	w.step(_pick(InputFrame.PICK_SWAP_BASE + 3))
	assert_eq(w.choosing, -1, "taken: the altar closes")
	assert_eq(w.mod_slots[3], ember)
	assert_eq(w.rewards.index_of(rid), -1, "the altar is spent")


func test_the_shop_buy_swaps_and_pays_only_then() -> void:
	var w := _world()
	w.shop_table = ContentCompiler.compile_shop(_repo.get_def(&"shop", &"terminal"))
	_fill(w)
	var ember := _it(w, &"ember_edge")
	w.shop.offer = PackedInt32Array([ember])
	w.shop.rolled = true
	w.shop.open = true
	w.shards = 1000
	w.step(_pick(1))
	assert_true(BuildSlots.swapping(w))
	assert_eq(w.shards, 1000, "nothing paid yet")
	w.step(_pick(InputFrame.PICK_SWAP_BASE))
	assert_false(BuildSlots.swapping(w))
	assert_eq(w.mod_slots[0], ember)
	assert_lt(w.shards, 1000, "paid on the swap")


func test_salvage_frees_a_modifier_slot() -> void:
	var w := _world()
	_fill(w)
	w.shop_table = ContentCompiler.compile_shop(_repo.get_def(&"shop", &"terminal"))
	var sells := Shop.sell_list(w)
	var n := -1
	for k in sells.size():
		if sells[k][0] == Shop.SELL_ABILITY:
			n = k
			break
	assert_gt(n, -1, "a modifier on the salvage list")
	Shop.salvage_ability(w, sells[n][1])
	assert_eq(w.mod_slots.size(), 5, "its slot is free")
	assert_false(BuildSlots.full(w))


# --- Migration and saves ----------------------------------------------------------------------------------------
## A v0.5 carry: the weapon, three ability slots and five attack items, no mod_slots.
func _old_carry(w: World) -> Dictionary:
	var owned := PackedInt32Array([Offers.ability_of(_ab(w, &"combo_sword"))])
	for id: StringName in [&"bomb_lobber", &"orbit_blades", &"arc_field"]:
		owned.append(Offers.ability_of(_ab(w, id)))
	var items := PackedInt32Array()
	for id: StringName in [&"long_edge", &"ember_edge", &"twin_arc", &"momentum", &"overcharge", &"conductor"]:
		items.append(_it(w, id))
	return {
		&"ability_owned": owned,
		&"ability_levels": PackedInt32Array([1, 2, 3, 1]),
		&"items_owned": items,
		&"hp": 50,
	}


func _fresh_floor() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	return w


func test_a_v0_5_carry_migrates_into_six_slots_deterministically() -> void:
	var runs: Array = []
	for n in 2:
		var w := _fresh_floor()
		var probe := _world()
		RunCarry.apply(w, _old_carry(probe))
		w.ability_tables = ContentCompiler.compile_abilities(_repo)  # as Main: after the carry
		w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
		Abilities.start_floor(w)
		runs.append([w.mod_slots.duplicate(), w.items_owned.duplicate(), w.ability_levels.duplicate()])
	var w := _world()
	var want := PackedInt32Array(
		[
			_ab(w, &"bomb_lobber"),
			_ab(w, &"orbit_blades"),
			_ab(w, &"arc_field"),
			_it(w, &"long_edge"),
			_it(w, &"ember_edge"),
			_it(w, &"twin_arc"),
		]
	)
	assert_eq(runs[0][0], want, "the abilities in slot order, then the attack items in pickup order")
	assert_false((runs[0][1] as PackedInt32Array).has(_it(w, &"overcharge")), "past six: dropped")
	assert_false((runs[0][1] as PackedInt32Array).has(_it(w, &"conductor")))
	assert_true((runs[0][1] as PackedInt32Array).has(_it(w, &"momentum")), "a plain item stays")
	assert_eq(runs[0][2], PackedInt32Array([1, 2, 3, 1]), "levels kept")
	assert_eq(runs[0], runs[1], "deterministic")


func test_a_carry_with_slots_keeps_their_order() -> void:
	var w := _world()
	BuildSlots.take(w, _it(w, &"ember_edge"))
	BuildSlots.take(w, _ab(w, &"bomb_lobber"))
	BuildSlots.take(w, _it(w, &"long_edge"))
	var carry := RunCarry.take(w, 0)
	var next := _fresh_floor()
	RunCarry.apply(next, carry)
	next.ability_tables = ContentCompiler.compile_abilities(_repo)
	next.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.start_floor(next)
	assert_eq(next.mod_slots, w.mod_slots)


func test_the_slots_round_trip_a_snapshot_with_equal_hashes() -> void:
	var w := _world()
	_fill(w)
	Offers.apply(w, _it(w, &"long_edge"))  # a swap waiting
	var snap := w.to_snapshot()
	var base := _world()
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.mod_slots, w.mod_slots)
	assert_eq(base.swap_code, w.swap_code)
	assert_eq(base.state_hash(), w.state_hash())


func test_a_snapshot_without_the_slots_migrates() -> void:
	var w := _world()
	for id: StringName in [&"bomb_lobber", &"orbit_blades", &"arc_field"]:
		Abilities.grant(w, Offers.ability_of(_ab(w, id)))
	for id: StringName in [&"long_edge", &"ember_edge", &"twin_arc", &"overcharge"]:
		w.add_item(_it(w, id))
	assert_eq(w.mod_slots.size(), 7, "add_item never caps (tests and labs)")
	var snap := w.to_snapshot()
	var data: Dictionary = snap["world"]
	for f: StringName in WorldSnapshot.ADDED_SINCE_V05[&"World"]:
		data.erase(f)
	(data[&"projectiles"] as Dictionary).erase(&"spec_key")
	var base := _world()
	assert_eq(WorldSnapshot.apply(base, snap), "", "an older snapshot restores")
	assert_eq(base.mod_slots.size(), 6, "into six slots")
	assert_eq(base.mod_slots[0], _ab(w, &"bomb_lobber"), "the abilities first")
	assert_eq(base.mod_slots[5], _it(w, &"twin_arc"), "then the items, the last past six dropped")
	assert_false(base.items_owned.has(_it(w, &"overcharge")))


func test_catch_up_reads_the_modifier_levels() -> void:
	var w := _world()
	w.catch_up_table = CatchUpTable.new()
	var p0 := CatchUp.power(w)
	BuildSlots.take(w, _ab(w, &"bomb_lobber"))
	var p1 := CatchUp.power(w)
	BuildSlots.take(w, _ab(w, &"bomb_lobber"))
	var p2 := CatchUp.power(w)
	assert_eq(p1 - p0, p0 * w.catch_up_table.ability_level_permille / 1000, "+ one modifier level")
	assert_eq(p2 - p1, p1 - p0, "+ per level")
	BuildSlots.take(w, _it(w, &"momentum"))
	assert_eq(CatchUp.power(w) - p2, p0 * w.catch_up_table.item_permille / 1000, "a plain item")
