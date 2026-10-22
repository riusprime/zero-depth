extends GutTest
## v0.6.5 WN5b (docs/design/WAND.md "What happens to the v0.6 cards"; SIM_CONTRACTS §8i): the retired v0.6 cards are
## never offered (altars, chests, the shop, events, cores, the legendary tier, the overrun's ability cards); a build
## that still holds one maps each onto its new card in pick order (a duplicate levels up, no match refunds shards at
## the salvage price); the legendary tier offers (v0.8.0 FL) an upgrade, an advanced or trigger card and the legendary
## triggers, whose child spell is cast twice. Mechanics only, no bots (P1).

const SEEDS := 12


## A floor as Main builds it (SaveLab): items, abilities, stat cards, the wand and its migration, the shop, events,
## the legendary tier.
func _floor(build: StringName, run_seed: int = 21) -> World:
	return SaveLab.floor_world(run_seed, 1, build)


func _it(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _ids(w: World) -> Array:
	var out := []
	for c in w.mod_slots:
		out.append(Offers.info(w, c)["id"])
	return out


func _levels(w: World) -> Array:
	var out := []
	for s in w.mod_slots.size():
		out.append(BuildSlots.level_at(w, s))
	return out


func _take(w: World, ids: Array) -> void:
	for id: StringName in ids:
		assert_true(BuildSlots.take(w, WandLab.code(w, id)), "takes %s" % id)


func _retired_code(w: World, code: int) -> bool:
	match Offers.type_of(code):
		Offers.MOD:
			return w.item_tables[code].retired
		Offers.ABILITY:
			return w.ability_tables[Offers.ability_of(code)].retired
	return false


# --- Retired: never offered ----------------------------------------------------------------------------------------
func test_the_table_retires_43_cards_and_marks_them() -> void:
	var w := _floor(&"blade")
	var items := 0
	var abilities := 0
	for t in w.item_tables:
		items += 1 if t.retired else 0
	for t in w.ability_tables:
		abilities += 1 if t.retired else 0
	assert_eq(
		[items, abilities],
		[40, 6],
		"46 rows: 40 items (v0.9.0: Spread, Explosive, the old Void) and the six old ability modifiers"
	)
	assert_eq(w.wand_table.migrate_ids.size(), items + abilities)
	for id: StringName in [&"echo_slash", &"split_shot", &"wide_arc", &"blade_orbit"]:
		assert_false(w.item_tables[_it(w, id)].retired, "%s kept its id as a wand card" % id)
	for id: StringName in [&"ember_core", &"storm_core", &"frost_core", &"venom_core"]:
		assert_false(w.item_tables[_it(w, id)].retired, "%s kept as a shared-pool card (WN5a)" % id)


func test_no_source_offers_a_retired_card() -> void:
	for build: StringName in [&"blade", &"gun"]:
		for s in SEEDS:
			var w := _floor(build, 100 + s)
			for idx in ItemPool.available(w, true):
				assert_false(w.item_tables[idx].retired, "%s: %s in the pool" % [build, idx])
			for a in w.ability_tables.size():
				if w.ability_tables[a].retired:
					assert_false(Abilities.can_take(w, a), "%s: never an ability card" % build)
			for kind: int in [
				RewardStore.Kind.ALTAR, RewardStore.Kind.CHEST, RewardStore.Kind.LEGENDARY
			]:
				var id := w.add_reward(kind, Vector2(100, 100), 0)
				for c in Offers.roll(w, w.rewards.index_of(id)):
					assert_false(
						_retired_code(w, c), "%s: reward kind %d offers %d" % [build, kind, c]
					)
			for c in Offers.draw(w, true, 6):  # the shop's stock draws as a chest
				assert_false(_retired_code(w, c), "%s: the shop stocks %d" % [build, c])
			for c in Overrun.offer(w):
				assert_false(_retired_code(w, c), "%s: the overrun offers %d" % [build, c])
			var core := CoreTheft.draw_card(w, w.ev.rng_elite, 1)
			assert_false(_retired_code(w, core), "%s: a core holds %d" % [build, core])


func test_the_dev_panel_can_still_grant_a_retired_card() -> void:
	var w := _floor(&"gun")
	var k := _it(w, &"conductor")
	assert_false(ItemPool.usable(w, k), "not offered")
	Offers.apply(w, k)
	assert_true(w.items_owned.has(k), "a direct grant still takes it (the dev panel's TEST HELPER)")


# --- The migration -------------------------------------------------------------------------------------------------
func test_a_blade_build_maps_in_pick_order_and_refunds_the_rest() -> void:
	var w := _floor(&"blade")
	w.shards = 0
	w.wand_table.slots_per_floor = PackedInt32Array([8])  # room for the old build's six
	_take(
		w, [&"long_edge", &"conductor", &"overcharge", &"orbit_blades", &"rearguard", &"echo_storm"]
	)
	_take(w, [&"orbit_blades", &"orbit_blades"])  # Orbit Blades to level 3
	var expect := WandMigration.refund_of(w, WandLab.code(w, &"rearguard"))
	var refund := WandMigration.run(w)
	assert_eq(
		_ids(w),
		[&"wide_arc", &"storm_core", &"finisher_plus", &"blade_orbit", &"echo_slash"],
		"Long Edge → B1, Conductor → S2, Overcharge → B14, Orbit Blades → B15, Echo Storm → B2"
	)
	assert_eq(
		_levels(w), [1, 1, 1, 3, 5], "the ability's level 3 carries; a legendary version is level 5"
	)
	assert_eq(refund, expect, "Rearguard (no Blade row) refunded")
	assert_eq(w.shards, refund)
	assert_gt(refund, 0)


func test_a_gun_build_maps_onto_the_gun_pool() -> void:
	var w := _floor(&"gun")
	w.wand_table.slots_per_floor = PackedInt32Array([8])
	_take(w, [&"seeker", &"twin_cast", &"rearguard", &"ascension", &"ricochet_core", &"aftershock"])
	var refund := WandMigration.run(w)
	assert_eq(
		_ids(w),
		[
			&"gun_homing",
			&"gun_echo",
			&"gun_backfire",
			&"gun_charge",
			&"gun_ricochet",
			&"ember_core"
		],
		(
			"Seeker → G8, Twin Cast → G14, Rearguard → G15, Ascension → G13, Ricochet Core → G7,"
			+ " Aftershock → S1 Fire (v0.9.0 XP: Explosive retired)"
		)
	)
	assert_eq(refund, 0, "every card has a Gun row")


func test_a_held_target_or_two_old_cards_level_it_up() -> void:
	var w := _floor(&"blade")
	_take(w, [&"wide_arc", &"long_edge", &"twin_arc", &"twin_cast"])
	WandMigration.run(w)
	assert_eq(_ids(w), [&"wide_arc", &"double_slash"])
	assert_eq(
		_levels(w), [2, 2], "Wide Arc + Long Edge; Twin Arc + Twin Cast: each a duplicate, level 2"
	)


func test_a_pending_target_maps_once_it_is_in_the_data() -> void:
	var w := _floor(&"blade")
	_take(w, [&"serrated_edge"])
	var row := w.wand_table.migrate_ids.find(&"serrated_edge")
	assert_eq(w.wand_table.migrate_blade[row], &"shared_bleed", "S5, built by WN5a")
	assert_gt(_it(w, &"shared_bleed"), -1, "in the data since the WN5a merge: no longer pending")
	assert_eq(WandMigration.run(w), 0, "no refund once the target exists")
	assert_eq(_ids(w), [&"shared_bleed"])


func test_it_is_deterministic_idempotent_and_needs_the_wand_table() -> void:
	var cards := [&"long_edge", &"ember_core", &"orbit_blades", &"twin_cast"]
	var a := _floor(&"blade")
	var b := _floor(&"blade")
	_take(a, cards)
	_take(b, cards)
	WandMigration.run(a)
	WandMigration.run(b)
	assert_eq(a.state_hash(), b.state_hash(), "the same build migrates the same")
	var h := a.state_hash()
	assert_eq(WandMigration.run(a), 0)
	assert_eq(a.state_hash(), h, "a migrated build holds no retired card")
	var lab := _floor(&"blade")
	_take(lab, cards)
	lab.wand_table = null
	var before := lab.mod_slots.duplicate()
	assert_eq(WandMigration.run(lab), 0, "a lab world without the wand keeps the old cards")
	assert_eq(lab.mod_slots, before)


func test_a_carry_into_the_next_floor_migrates_at_its_start() -> void:
	var old := _floor(&"gun")
	old.wand_table = null  # a v0.6.0/v0.6.1 world: six slots, the old cards
	_take(old, [&"splinter_shot", &"rapid_coil", &"bomb_lobber", &"cluster_payload"])
	var carry := RunCarry.take(old, 0)
	var w := _floor(&"gun")
	RunCarry.apply(w, carry)
	Abilities.start_floor(w)
	assert_eq(_ids(w), [&"gun_twin", &"gun_rapid_fire", &"gun_mine"], "v0.9.0 TW: Spread is Twin")
	assert_eq(_levels(w), [1, 1, 2], "Bomb Lobber and its Cluster Payload: Mine at level 2")


## v0.9.0 TW (owner Q8: Twin and Spread merged into one card): Spread is retired; a held Spread becomes Twin in its
## place (the table's rule: a card already held levels up by 1), and Spread is never offered again.
func test_a_held_spread_becomes_twin_and_is_never_offered() -> void:
	var w := _floor(&"gun")
	var spread := _it(w, &"gun_spread")
	assert_true(w.item_tables[spread].retired, "Spread is retired")
	assert_does_not_have(ItemPool.available(w), spread, "never offered")
	_take(w, [&"gun_homing", &"gun_spread"])
	CardLevels.set_level(w, spread, 3)
	WandMigration.run(w)
	assert_eq(_ids(w), [&"gun_homing", &"gun_twin"], "in Spread's place")
	assert_eq(_levels(w), [1, 1], "a new Twin at level 1, as every retired card")
	var both := _floor(&"gun")
	_take(both, [&"gun_twin", &"gun_spread"])
	WandMigration.run(both)
	assert_eq(_ids(both), [&"gun_twin"])
	assert_eq(_levels(both), [2], "a Twin already held levels up")


## v0.9.0 XP (owner Q11: "Both": Fire's kill blast and the Explosive card go): Explosive is retired, never offered on
## either weapon; a held Explosive becomes Fire (the element it was closest to), as do the rows that pointed at it.
func test_explosive_is_retired_never_offered_and_becomes_fire() -> void:
	for weapon: StringName in [&"gun", &"blade"]:
		var w := _floor(weapon)
		var boom := _it(w, &"shared_explosive")
		assert_true(w.item_tables[boom].retired, "Explosive is retired")
		assert_does_not_have(ItemPool.available(w), boom, "never offered on a %s run" % weapon)
		_take(w, [&"shared_explosive"])
		WandMigration.run(w)
		assert_eq(_ids(w), [&"ember_core"], "a held Explosive becomes Fire (%s)" % weapon)
	var t := _floor(&"gun").wand_table
	for id: StringName in t.migrate_blade + t.migrate_gun:
		assert_ne(id, &"shared_explosive", "no row lands on Explosive")


## v0.9.0 VP (owner C §6.4: "That specific ground-spawning gravity modifier should be deleted from the item pool and
## associated attack behavior"; C54): the old Void (gravity_well, the floor black hole) is retired, never offered on
## either weapon. The table's rule for a held one: on a Gun run it becomes the Void form card in its place (Lv 1, as
## every retired card; a Void already held levels up); on a Blade run (the form is Gun only) it is refunded as shards
## at the shop's salvage price. No row lands on it.
func test_the_old_void_is_retired_becomes_the_void_form_on_the_gun_and_shards_on_the_blade(
) -> void:
	for weapon: StringName in [&"gun", &"blade"]:
		var w := _floor(weapon)
		var old := _it(w, &"gravity_well")
		assert_true(w.item_tables[old].retired, "the old Void is retired")
		assert_does_not_have(ItemPool.available(w), old, "never offered on a %s run" % weapon)
	var g := _floor(&"gun")
	_take(g, [&"gun_homing", &"gravity_well"])
	CardLevels.set_level(g, _it(g, &"gravity_well"), 3)
	assert_eq(WandMigration.run(g), 0, "no refund on the Gun")
	assert_eq(_ids(g), [&"gun_homing", &"gun_void"], "the Void form in its place")
	assert_eq(_levels(g), [1, 1])
	assert_eq(AttackSlots.form_id(g), &"void")
	var b := _floor(&"blade")
	_take(b, [&"gravity_well"])
	var expect := WandMigration.refund_of(b, _it(b, &"gravity_well"))
	assert_gt(expect, 0)
	assert_eq(WandMigration.run(b), expect, "refunded on the Blade")
	assert_eq(_ids(b), [], "nothing in its place")
	var t := g.wand_table
	for id: StringName in t.migrate_blade + t.migrate_gun:
		assert_ne(id, &"gravity_well", "no row lands on the old Void")


# --- The legendary tier --------------------------------------------------------------------------------------------
## v0.8.0 FL (owner O91): the boss's altar offers an upgrade of a held wand card, an advanced or trigger card and a
## legendary stat card (the Legendary chance's card in the second's place); never a retired card, never a form or
## element card it doesn't hold, and a wand card only from the run's pool.
func test_the_legendary_tier_offers_advanced_and_trigger_cards_and_the_legendary_triggers() -> void:
	for build: StringName in [&"blade", &"gun"]:
		var picked := 0
		var weapons := 0
		for s in 40:
			var w := _floor(build, 300 + s)
			weapons = w.player.weapons
			var id := w.add_reward(RewardStore.Kind.LEGENDARY, Vector2(100, 100), 0)
			for c in Offers.roll(w, w.rewards.index_of(id)):
				if Offers.type_of(c) != Offers.MOD:
					continue
				var t := w.item_tables[c]
				assert_false(t.retired, "%s: %s retired" % [build, t.id])
				assert_true(
					t.requires_weapon == 0 or (t.requires_weapon & weapons) != 0,
					"%s: %s from the run's pool" % [build, t.id]
				)
				var cat := LootPacing.category(w, c)
				var legend := t.rarity == ItemTable.LEGENDARY
				assert_true(
					(
						legend
						or cat == LootPacing.Category.ADVANCED
						or cat == LootPacing.Category.TRIGGER
					),
					"%s: %s an advanced or trigger card (or the Legendary chance's)" % [build, t.id]
				)
				picked += 0 if legend else 1
		assert_gt(picked, 20, "%s: the card choice is there (%d seen)" % [build, picked])


## v0.8.0 FL (owner O91: "remove automatic level-5 grants"): a wand card taken at the boss's altar levels as anywhere.
func test_a_wand_card_taken_at_the_legendary_altar_is_one_level_up() -> void:
	var w := _floor(&"gun")
	var big := _it(w, &"gun_big_shot")
	_take(w, [&"gun_big_shot"])
	var id := w.add_reward(RewardStore.Kind.LEGENDARY, w.player_pos() + Vector2(0.5, 0), 0)
	var r := w.rewards.index_of(id)
	w.rewards.set_offer(r, PackedInt32Array([big]))  # the roll is the loot stream's; this test needs Big Shot
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)
	assert_eq(w.choosing, id, "it opens")
	assert_eq(CardForecast.of(w, big, r)["new"], 2, "the forecast says level 2")
	var pick := InputFrame.new()
	pick.pick = 1
	w.step(pick)
	assert_eq(CardLevels.level(w, big), 2, "one level up, no level-5 version")
	var alt := _floor(&"gun")
	var id2 := alt.add_reward(RewardStore.Kind.LEGENDARY, alt.player_pos() + Vector2(0.5, 0), 0)
	alt.rewards.set_offer(alt.rewards.index_of(id2), PackedInt32Array([big]))
	alt.step(f)
	alt.step(pick)
	assert_eq(CardLevels.level(alt, big), 1, "a fresh card is level 1")


func test_the_legendary_triggers_cast_their_spell_twice() -> void:
	var w := WandLab.fight(&"gun", [&"trigger_on_hit_twice"])
	var hooks := []
	for k in Modifiers.bolt(w).hooks:
		if k.id == &"trigger_on_hit_twice":
			hooks.append(k.delay_ticks)
	assert_eq(hooks, [0, 9], "two casts per hit, the second 0.15 s later")
	var once := WandLab.run(WandLab.fight(&"gun", [&"trigger_on_hit"]), 600)
	var twice := WandLab.run(WandLab.fight(&"gun", [&"trigger_on_hit_twice"]), 600)
	var n1 := int((once["hits_by_effect"] as Dictionary).get(&"trigger_on_hit", 0))
	var n2 := int((twice["hits_by_effect"] as Dictionary).get(&"trigger_on_hit_twice", 0))
	assert_gt(n1, 0)
	assert_gt(n2, n1, "×2 lands more child hits than On Hit (%d vs %d)" % [n2, n1])
	var again := WandLab.run(WandLab.fight(&"gun", [&"trigger_on_hit_twice"]), 600)
	assert_eq([again["digest"], again["hash"]], [twice["digest"], twice["hash"]], "replays")
	for id: StringName in [&"trigger_on_kill_twice", &"trigger_on_end_twice"]:
		var r := WandLab.run(WandLab.fight(&"blade", [id]), 900)
		assert_gt(int((r["hits_by_effect"] as Dictionary).get(id, 0)), 0, "%s casts" % id)
