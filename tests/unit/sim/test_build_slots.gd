extends GutTest
## v0.6.0 MX2 (owner B7; docs/design/MODIFIER_ENGINE.md "The build"; BuildSlots): the build is the weapon, one utility
## pick, up to six modifier slots in pick order and unlimited stat cards. A held modifier levels up without a slot; a
## new one with the six full needs a swap (the altar's pick, the shop, a grant with no panel), which replaces the
## chosen slot in place or skips. Saves from before MX2 migrate deterministically; the slots round-trip a snapshot.

## v0.10.5 O1: the six ability modifiers are gone; six live Blade cards fill the slots (none shares a slot category
## that would replace another).
const MODS: Array = [
	&"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed", &"echo_slash"
]
## A seventh card, one the six don't hold.
const SEVENTH := &"blade_orbit"

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
		assert_true(BuildSlots.take(w, _it(w, id)), "takes %s" % id)


func _pick(v: int) -> InputFrame:
	var f := InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0)
	f.pick = v
	return f


func test_what_takes_a_slot() -> void:
	var w := _world()
	for id: StringName in MODS:
		assert_true(BuildSlots.is_modifier(w, _it(w, id)), "%s is a modifier" % id)
	for id: StringName in [&"combo_sword", &"pulse_gun", &"blink", &"aegis"]:
		assert_false(BuildSlots.is_modifier(w, _ab(w, id)), "%s takes no slot" % id)
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
	BuildSlots.take(w, _it(w, &"ember_core"))
	BuildSlots.take(w, _it(w, &"frost_core"))
	BuildSlots.take(w, _it(w, &"echo_slash"))
	assert_eq(
		w.mod_slots,
		PackedInt32Array([_it(w, &"ember_core"), _it(w, &"frost_core"), _it(w, &"echo_slash")])
	)
	assert_eq(
		Modifiers.book(w).modifier_ids,
		PackedStringArray(["ember_core", "frost_core", "echo_slash"]),
		"the layer order is the pick order"
	)


func test_a_held_modifier_levels_up_without_a_slot() -> void:
	var w := _world()
	var ember := _it(w, &"ember_core")
	BuildSlots.take(w, ember)
	BuildSlots.take(w, ember)
	BuildSlots.take(w, ember)
	assert_eq(w.mod_slots.size(), 1)
	assert_eq(BuildSlots.level_at(w, 0), 3)
	_fill(w)  # five more new ones: Ember's level-ups never took a slot
	assert_eq(w.mod_slots.size(), 6)
	assert_eq(BuildSlots.level_at(w, 0), 3, "Ember is at its top level (3)")
	assert_false(BuildSlots.needs_swap(w, ember), "a held card with the six full needs no swap")


func test_the_utility_and_stat_cards_take_no_slot() -> void:
	var w := _world()
	_fill(w)
	assert_true(BuildSlots.full(w))
	assert_false(BuildSlots.needs_swap(w, _ab(w, &"blink")))
	BuildSlots.take(w, _ab(w, &"blink"))
	assert_eq(
		Abilities.utility(w), PlayerTable.Utility.BLINK, "the utility pick, outside the slots"
	)
	for k in 12:
		BuildSlots.take(w, Offers.stat_code(Stats.Stat.DAMAGE, 0))
	assert_eq(w.stat_cards.size(), 12, "unlimited stat cards")
	assert_eq(w.mod_slots.size(), 6)


func test_a_seventh_modifier_needs_a_swap_and_replaces_in_place() -> void:
	var w := _world()
	_fill(w)
	var ember := _it(w, &"blade_orbit")
	assert_true(BuildSlots.needs_swap(w, ember))
	assert_false(BuildSlots.take(w, ember), "no slot named: nothing changes")
	assert_false(w.items_owned.has(ember))
	var dropped := w.mod_slots[2]
	assert_true(BuildSlots.take(w, ember, 2))
	assert_eq(w.mod_slots[2], ember, "it takes the replaced slot's place in the order")
	assert_false(BuildSlots.held(w, dropped), "the replaced one left the build")
	assert_eq(w.mod_slots.size(), 6)
	assert_true(Modifiers.book(w).modifier_ids.has("blade_orbit"))


func test_a_grant_with_no_panel_opens_the_swap_and_waits() -> void:
	var w := _world()
	_fill(w)
	var ember := _it(w, &"blade_orbit")
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
	Offers.apply(w, _it(w, &"blade_orbit"))
	w.step(_pick(InputFrame.PICK_SWAP_SKIP))
	assert_false(BuildSlots.swapping(w))
	assert_eq(w.mod_slots, before)
	assert_false(w.items_owned.has(_it(w, &"blade_orbit")))


func test_the_altar_pick_swaps_or_skips_back_to_the_cards() -> void:
	var w := _world()
	_fill(w)
	var ember := _it(w, &"blade_orbit")
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
	var ember := _it(w, &"heavy")  # v0.6.5 WN5b: a card the shop sells (Ember Edge is retired)
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


## Removing a held modifier (Shop.remove_item: the playground's removal, a migrated card's) frees its slot.
func test_removing_a_modifier_frees_its_slot() -> void:
	var w := _world()
	_fill(w)
	assert_true(BuildSlots.full(w))
	Shop.remove_item(w, w.items_owned[0])
	assert_eq(w.mod_slots.size(), 5, "its slot is free")
	assert_false(BuildSlots.full(w))


func _fresh_floor() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	return w


func test_a_carry_with_slots_keeps_their_order() -> void:
	var w := _world()
	BuildSlots.take(w, _it(w, &"blade_orbit"))
	BuildSlots.take(w, _it(w, &"ember_core"))
	BuildSlots.take(w, _it(w, &"echo_slash"))
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
	Offers.apply(w, _it(w, &"blade_orbit"))  # a swap waiting
	var snap := w.to_snapshot()
	var base := _world()
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.mod_slots, w.mod_slots)
	assert_eq(base.swap_code, w.swap_code)
	assert_eq(base.state_hash(), w.state_hash())


func test_a_snapshot_without_the_slots_migrates() -> void:
	var w := _world()
	for id: StringName in MODS + [SEVENTH]:
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
	assert_eq(base.mod_slots[0], _it(w, &"ember_core"), "the first pick first")
	assert_eq(
		base.mod_slots[5], _it(w, &"echo_slash"), "then in pickup order, the last past six dropped"
	)
	assert_false(base.items_owned.has(_it(w, SEVENTH)))


func test_catch_up_reads_the_modifier_levels() -> void:
	var w := _world()
	w.catch_up_table = CatchUpTable.new()
	var p0 := CatchUp.power(w)
	BuildSlots.take(w, _ab(w, &"blink"))  # the utility's levels count (the modifier abilities are gone)
	var p1 := CatchUp.power(w)
	BuildSlots.take(w, _ab(w, &"blink"))
	var p2 := CatchUp.power(w)
	assert_eq(p1 - p0, p0 * w.catch_up_table.ability_level_permille / 1000, "+ one modifier level")
	assert_eq(p2 - p1, p1 - p0, "+ per level")
	BuildSlots.take(w, _it(w, &"momentum"))
	assert_eq(CatchUp.power(w) - p2, p0 * w.catch_up_table.item_permille / 1000, "a plain item")
