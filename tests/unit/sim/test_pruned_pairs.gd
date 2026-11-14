extends GutTest
## v0.10.5 W3-P7 (owner, 2026-11-04: P7 approved, "prune"; docs/roadmap/v0.10.5/W3_O4_PROGRESSION_G1.md section c):
## a card that measured no gain (or a loss) on a form is no longer offered while that form is the run's
## (AttackFormRow.pruned, read by AttackSlots.usable through ItemPool.usable). A held one still compiles, so an old save
## (or a card taken under another form) keeps working. Split and Mine stay offered on the Void (the lead, the owner
## plays them; their Void numbers were fixed instead).

const W := preload("res://tests/support/mx4_world.gd")
const VOID_PRUNED: Array[StringName] = [
	&"gun_ring",
	&"gun_backfire",
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_rapid_fire",
	&"orbit_rounds",
	&"chain_blast",
	&"shared_stress_mark",
]


func _world(weapon: StringName = &"gun") -> World:
	var w := W.world(weapon)
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 5
	w.run_floor = 5
	return w


func _take(w: World, ids: Array) -> void:
	for id: StringName in ids:
		assert_true(BuildSlots.take(w, W.item(w, id)), "took %s" % id)


func _compiled(w: World) -> Array:
	var ids: Array = []
	for m in Modifiers.build_modifiers(w):
		ids.append(m.id)
	return ids


func test_the_data_prunes_the_measured_dead_pairs() -> void:
	var def := W.repo().get_def(&"wand", &"attack_slots") as AttackSlotsDefinition
	var by_form := {}
	for r in def.forms:
		by_form[r.id] = r.pruned
	assert_eq(by_form[&"void"], VOID_PRUNED, "the Void: its no-ops and its losses (G1 c)")
	assert_eq(
		by_form[&"orbs"], [&"gun_ricochet"] as Array[StringName], "Orbs: Ricochet (1.00 / 1.00)"
	)
	for id: StringName in by_form:
		if not id in [&"void", &"orbs"]:
			assert_true((by_form[id] as Array).is_empty(), "%s prunes nothing" % id)
	assert_false(by_form[&"void"].has(&"split_shot"), "Split stays on the Void (the lead)")
	assert_false(by_form[&"void"].has(&"gun_mine"), "Mine stays on the Void (the lead)")


func test_a_pruned_card_is_never_offered_with_its_form() -> void:
	var w := _world()
	_take(w, [&"gun_void"])
	assert_eq(AttackSlots.form_id(w), &"void")
	for id: StringName in VOID_PRUNED:
		var idx := W.item(w, id)
		assert_false(ItemPool.usable(w, idx), "%s is not offered on the Void" % id)
		assert_false(ItemPool.available(w).has(idx), "%s is not in the pool" % id)
		assert_false(ItemPool.available(w, true, 5).has(idx), "nor the legendary or upgrade draw")
	for id: StringName in [&"split_shot", &"gun_mine", &"gun_big_shot", &"gun_twin", &"venom_core"]:
		assert_true(ItemPool.usable(w, W.item(w, id)), "%s is still offered on the Void" % id)
	for k in 200:
		w.rng_loot = RngStream.derive(k, "loot")
		for idx in ItemPool.draw_weighted(w, 3, 3):
			assert_false(
				VOID_PRUNED.has(w.item_tables[idx].id), "draw %d: %s" % [k, w.item_tables[idx].id]
			)


func test_the_prune_is_the_forms_own() -> void:
	var w := _world()
	var ricochet := W.item(w, &"gun_ricochet")
	var echo := W.item(w, &"gun_echo")
	assert_eq(AttackSlots.form_id(w), &"orbs")
	assert_false(ItemPool.usable(w, ricochet), "Ricochet is pruned on Orbs")
	assert_true(ItemPool.usable(w, echo), "Echo is a gain on Orbs: offered")
	assert_true(ItemPool.usable(w, W.item(w, &"chain_blast")), "Chain Blast too")
	_take(w, [&"gun_laser"])
	assert_true(ItemPool.usable(w, ricochet), "the Laser prunes nothing: Ricochet is offered again")
	var b := _world(&"blade")
	assert_true(
		ItemPool.usable(b, W.item(b, &"chain_blast")), "a Blade run has no form: nothing pruned"
	)


func test_a_held_pruned_card_still_compiles() -> void:
	var w := _world()
	_take(w, [&"gun_echo", &"chain_blast", &"gun_void"])  # taken under Orbs, then the Void
	assert_eq(AttackSlots.form_id(w), &"void")
	var ids := _compiled(w)
	assert_true(ids.has(&"gun_echo"), "a held pruned card keeps its effect")
	assert_true(ids.has(&"chain_blast"), "a held pruned Free card too")
	assert_false(ItemPool.usable(w, W.item(w, &"gun_echo")), "it is just not offered again")


func _ids(w: World) -> Array:
	var out := []
	for c in w.mod_slots:
		out.append(Offers.info(w, c)["id"])
	return out
