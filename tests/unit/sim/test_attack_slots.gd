extends GutTest
## v0.9.0 AS (owner Q2–Q7, Q13, Q14; PLAN C36–C67, C78, C87; docs/roadmap/v0.9.0/ATTACK_FORMS.md): the wand's slot
## categories (AttackSlots), the form × card table (SlotTable, data/wand/attack_slots.tres) and the projectile caps
## (ShotCap). Equip: a Pattern replaces the Pattern (Twin then Halo: Twin leaves), a full Secondary or Element slot
## asks which of its cards goes (AS2: the Swap, limited to that slot; a skip keeps the card un-taken), Ring + Swirl
## ride together, the Blade gets only the one-Pattern rule; compile: two forms never coexist; offers: an incompatible
## card is never offered nor compiled; caps: at most 12 shots an attack (merged, the damage kept) and at most 40
## player projectiles a second for the worst legal builds at the top attack speed; an old save over its limits is
## trimmed and plays on.

const W := preload("res://tests/support/mx4_world.gd")
const TRIGGERS: Array[StringName] = [&"trigger_on_hit_twice", &"trigger_on_hit", &"trigger_on_kill"]


## A world of `weapon` with the shipped wand, its slot table and floor `f`'s slots (v0.9.0 FV: 5: eight), holding
## nothing yet.
func _world(weapon: StringName = &"gun", f: int = 5) -> World:
	var w := W.world(weapon)
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = f
	w.run_floor = f
	return w


## Takes each of `ids` through the one way a card enters the build (BuildSlots.take).
func _take(w: World, ids: Array) -> void:
	for id: StringName in ids:
		assert_true(BuildSlots.take(w, W.item(w, id)), "took %s" % id)


func _ids(w: World) -> Array:
	var out := []
	for c in w.mod_slots:
		out.append(Offers.info(w, c)["id"])
	return out


# --- The data ------------------------------------------------------------------------------------------------------
func test_the_data_holds_the_owners_limits_caps_and_the_orbs_row() -> void:
	var w := _world()
	var t := w.slot_table
	assert_not_null(t, "data/wand/attack_slots.tres ships")
	assert_eq(
		t.gun_limits,
		PackedInt32Array([1, 1, 2, 2]),
		"Q4: Form 1, Pattern 1, Secondary 2, Element 2"
	)
	assert_eq(
		t.blade_limits,
		PackedInt32Array([-1, 1, -1, -1]),
		"Q6: the Blade, the one-pattern rule only"
	)
	assert_eq([t.shots_per_attack_max, t.shots_per_second_max], [12, 40], "Q13")
	assert_eq(
		t.form_ids,
		[&"orbs", &"laser", &"bomb"] as Array[StringName],
		"Q7: Orbs, and the forms built so far (LZ)"
	)
	assert_eq(t.default_form, 0)
	assert_eq(t.form_cards[0], -1, "Orbs is the Gun's own shot, no card")
	assert_eq(AttackSlots.form_id(w), &"orbs")
	for idx in w.item_tables.size():  # C61: Orbs takes every live Gun Pattern, Secondary and Element card
		var it := w.item_tables[idx]
		if it.retired or it.requires_weapon == PlayerTable.WEAPON_BLADE:
			continue
		if it.slot_category in [AttackSlots.PATTERN, AttackSlots.SECONDARY, AttackSlots.ELEMENT]:
			assert_eq(t.cell(0, idx), SlotTable.CELL_ON, "%s is on for Orbs" % it.id)


func test_every_live_card_has_the_slot_the_owner_gave_it() -> void:
	var w := _world()
	var want := {
		AttackSlots.PATTERN:
		[
			&"gun_twin",
			&"halo_shot",
			&"gun_ring",
			&"gun_backfire",
			&"wide_arc",
			&"double_slash",
			&"whirl",
			&"thrust"
		],
		AttackSlots.SECONDARY:
		[
			&"gun_pierce",
			&"gun_ricochet",
			&"gun_homing",
			&"gun_echo",
			&"gun_big_shot",
			&"gun_rapid_fire",
			&"split_shot",
			&"gun_mine",
			&"gun_charge",
			&"orbit_rounds",
			&"boomerang",
			&"gun_threadline",
			&"gun_spiral",
			&"gun_swirl"
		],
		AttackSlots.ELEMENT:
		[
			&"ember_core",
			&"storm_core",
			&"frost_core",
			&"venom_core",
			&"shared_bleed",
			&"gravity_well"
		],
		AttackSlots.FREE:
		[
			&"trigger_on_hit",
			&"trigger_on_kill_twice",
			&"mut_grand_finale",
			&"echo_slash",
			&"chain_blast"
		],
	}
	for cat: int in want:
		for id: StringName in want[cat]:
			assert_eq(w.item_tables[W.item(w, id)].slot_category, cat, "%s's slot" % id)


# --- Equip ---------------------------------------------------------------------------------------------------------
func test_twin_then_halo_halo_takes_twins_place_and_twin_leaves() -> void:
	var w := _world()
	_take(w, [&"gun_pierce", &"gun_twin", &"ember_core"])
	var halo := W.item(w, &"halo_shot")
	var twin := W.item(w, &"gun_twin")
	var info := Offers.info(w, halo)
	assert_eq(int(info["slot"]), AttackSlots.PATTERN, "the card carries its slot tag")
	assert_eq(int(info["replaces"]), twin, "and says it replaces Twin")
	assert_eq(
		int(Offers.info(w, W.item(w, &"gun_homing"))["replaces"]),
		-1,
		"a Secondary with room: nothing"
	)
	assert_true(BuildSlots.take(w, halo))
	assert_eq(_ids(w), [&"gun_pierce", &"halo_shot", &"ember_core"], "Halo in Twin's slot")
	assert_false(w.items_owned.has(twin), "Twin left the build (it burns)")
	assert_eq(CardLevels.level(w, halo), 1)
	var s := Modifiers.bolt(w)
	assert_eq([s.count, s.twin], [3, 0], "the shot is Halo's, no Twin lane")
	assert_true(BuildSlots.take(w, twin), "and back: Twin replaces Halo")
	assert_eq(_ids(w), [&"gun_pierce", &"gun_twin", &"ember_core"])


func test_a_held_pattern_levels_up_and_replaces_nothing() -> void:
	var w := _world()
	_take(w, [&"gun_twin"])
	var twin := W.item(w, &"gun_twin")
	assert_eq(int(Offers.info(w, twin)["replaces"]), -1)
	_take(w, [&"gun_twin"])
	assert_eq(CardLevels.level(w, twin), 2, "a duplicate levels it")
	assert_eq(w.mod_slots.size(), 1)


func test_ring_and_swirl_ride_together() -> void:
	var w := _world()
	_take(w, [&"gun_ring", &"gun_swirl", &"gun_spiral"])
	assert_eq(
		_ids(w), [&"gun_ring", &"gun_swirl", &"gun_spiral"], "Q3: Spiral and Swirl are Secondaries"
	)
	var s := Modifiers.bolt(w)
	assert_eq(
		[s.form, s.swirl, s.count], [AttackSpec.Form.RING, 1, 1], "Ring · Swirl: one ring, thrown"
	)
	assert_eq(int(Offers.info(w, W.item(w, &"halo_shot"))["replaces"]), W.item(w, &"gun_ring"))


func test_a_full_secondary_or_element_slot_asks_which_card_goes() -> void:
	var w := _world()
	_take(w, [&"gun_pierce", &"ember_core", &"gun_homing", &"storm_core"])
	var ric := W.item(w, &"gun_ricochet")
	var info := Offers.info(w, ric)
	assert_eq(int(info["replaces"]), -1, 'AS2 (owner "Let me choose"): it names no card')
	assert_true(info["chooses"], "it asks which Secondary goes")
	assert_eq(Array(AttackSlots.choices(w, ric)), [0, 2], "Pierce's and Homing's slots")
	assert_true(BuildSlots.needs_swap(w, ric), "the Swap, with room in the wand")
	assert_false(BuildSlots.take(w, ric), "no slot named: nothing changes")
	assert_false(BuildSlots.take(w, ric, 1), "Ember Core's slot is not a Secondary's")
	assert_false(w.items_owned.has(ric))
	assert_true(BuildSlots.take(w, ric, 2))
	assert_eq(
		_ids(w),
		[&"gun_pierce", &"ember_core", &"gun_ricochet", &"storm_core"],
		"Ricochet in Homing's slot; Homing left (it burns)"
	)
	var venom := W.item(w, &"venom_core")
	assert_eq(Array(AttackSlots.choices(w, venom)), [1, 3], "the Elements' slots")
	assert_true(BuildSlots.take(w, venom, 3))
	assert_eq(_ids(w), [&"gun_pierce", &"ember_core", &"gun_ricochet", &"venom_core"])
	assert_false(BuildSlots.needs_swap(w, W.item(w, &"gun_pierce")), "a held card levels up")
	assert_eq(Array(AttackSlots.choices(w, W.item(w, &"halo_shot"))), [], "a Pattern doesn't ask")


func _pick(v: int) -> InputFrame:
	var f := InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0)
	f.pick = v
	return f


func test_the_choice_arrives_as_the_swaps_input_and_a_skip_keeps_the_card_untaken() -> void:
	var w := _world()
	_take(w, [&"gun_pierce", &"ember_core", &"gun_homing"])
	var ric := W.item(w, &"gun_ricochet")
	var rid := w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	var i := w.rewards.index_of(rid)
	w.rewards.set_offer(i, PackedInt32Array([ric, W.item(w, &"storm_core")]))
	w.choosing = rid
	w.step(_pick(1))
	assert_true(BuildSlots.swapping(w), "a third Secondary opens the Swap")
	assert_eq(w.swap_source, BuildSlots.Source.REWARD)
	assert_eq(int(Wand.read(w)["swap_slot"]), AttackSlots.SECONDARY, "limited to the Secondaries")
	w.step(_pick(InputFrame.PICK_SWAP_BASE + 1))
	assert_true(BuildSlots.swapping(w), "Ember Core's slot is no answer: it still waits")
	assert_true(w.items_owned.has(W.item(w, &"ember_core")))
	w.step(_pick(InputFrame.PICK_SWAP_SKIP))
	assert_false(BuildSlots.swapping(w), "skip")
	assert_eq(w.choosing, rid, "back to the cards, the card un-taken")
	assert_false(w.items_owned.has(ric))
	assert_eq(_ids(w), [&"gun_pierce", &"ember_core", &"gun_homing"])
	w.step(_pick(1))
	w.step(_pick(InputFrame.PICK_SWAP_BASE + 0))
	assert_eq(w.choosing, -1, "taken: the altar closes")
	assert_eq(_ids(w), [&"gun_ricochet", &"ember_core", &"gun_homing"], "Pierce chosen: it left")
	assert_eq(int(Wand.read(w)["swap_slot"]), 0)


func test_a_full_wand_asks_for_the_swap_only_for_a_card_whose_slot_has_room() -> void:
	var w := _world()
	_take(w, [&"gun_twin", &"gun_pierce", &"gun_homing", &"ember_core", &"storm_core"])
	_take(w, TRIGGERS)
	assert_true(BuildSlots.full(w), "eight cards, eight slots")
	assert_false(BuildSlots.needs_swap(w, W.item(w, &"halo_shot")), "a Pattern replaces Twin")
	for id: StringName in [&"gun_ricochet", &"frost_core"]:
		assert_true(BuildSlots.needs_swap(w, W.item(w, id)), "%s: choose in its slot" % id)
	var frost := W.item(w, &"frost_core")
	assert_eq(Array(AttackSlots.choices(w, frost)), [3, 4], "only the Elements, not any slot")
	assert_true(BuildSlots.needs_swap(w, W.item(w, &"trigger_on_end")), "a free card still swaps")
	assert_false(BuildSlots.take(w, frost, 0), "Twin's slot is not an Element's")
	assert_true(BuildSlots.take(w, frost, 3))
	assert_eq(w.mod_slots.size(), 8)
	assert_false(w.items_owned.has(W.item(w, &"ember_core")), "Ember made room for Frost")


func test_the_blade_gets_only_the_one_pattern_rule() -> void:
	var w := _world(&"blade")
	_take(w, [&"wide_arc", &"ember_core", &"storm_core", &"frost_core", &"echo_slash"])
	assert_eq(int(Offers.info(w, W.item(w, &"whirl"))["replaces"]), W.item(w, &"wide_arc"))
	assert_eq(
		int(Offers.info(w, W.item(w, &"ember_core"))["slot"]),
		AttackSlots.FREE,
		"no Element tag here"
	)
	assert_eq(int(Offers.info(w, W.item(w, &"wide_arc"))["slot"]), AttackSlots.PATTERN)
	_take(w, [&"whirl", &"venom_core"])
	assert_eq(
		_ids(w),
		[&"whirl", &"ember_core", &"storm_core", &"frost_core", &"echo_slash", &"venom_core"],
		"Whirl replaced Wide Arc; the Blade's elements have no limit"
	)
	assert_eq(AttackSlots.form_id(w), &"", "the forms are the Gun's")


# --- Compile -------------------------------------------------------------------------------------------------------
func test_two_forms_never_coexist_in_a_spell() -> void:
	var w := _world()
	var ring := w.item_tables[W.item(w, &"gun_ring")].modifiers[0]
	var zone := ModifierTable.new()
	zone.id = &"lab_zone_form"
	zone.target = PackedStringArray(["projectile"])
	zone.stage = ModifierTable.Stage.FORM
	var op := ModifierOp.new()
	op.op = ModifierOp.Op.SET_FORM
	op.form = AttackSpec.Form.ZONE
	zone.ops.append(op)
	var mods: Array[ModifierTable] = [ring, zone]
	var s := Modifiers.compile_for(w, mods).spec(Modifiers.GUN_BOLT)
	assert_eq(s.form, AttackSpec.Form.RING, "the first form holds")
	assert_eq(s.form_layers, 1, "one form")
	for k in s.hooks:
		assert_ne(k.id, zone.id, "C63: no layered attack in the second form")


func test_a_second_form_card_replaces_the_first_and_its_table_rules_the_rest() -> void:
	var w := _world()
	var a := W.item(w, &"gun_big_shot")  # lab: two cards play two forms (the forms ship in later steps)
	var b := W.item(w, &"gun_charge")
	var twin := W.item(w, &"gun_twin")
	var ember := W.item(w, &"ember_core")
	var t := w.slot_table
	for idx in [a, b]:
		w.item_tables[idx].slot_category = AttackSlots.FORM
		t.form_ids.append(&"lab_%d" % idx)
		t.form_cards.append(idx)
		t.form_cells.append({ember: SlotTable.CELL_ON})
	_take(w, [&"gun_twin", &"ember_core"])
	assert_true(ItemPool.usable(w, a), "a form card with a row is offered")
	_take(w, [&"gun_big_shot"])
	assert_eq(AttackSlots.form_id(w), &"lab_%d" % a, "its form fires now")
	assert_false(AttackSlots.compatible(w, twin), "Twin is off for it")
	assert_false(ItemPool.usable(w, W.item(w, &"halo_shot")), "so no Pattern is offered")
	var ids: Array = []
	for m in Modifiers.build_modifiers(w):
		ids.append(m.id)
	assert_false(ids.has(&"gun_twin"), "a held card off for the form is not compiled")
	assert_true(ids.has(&"ember_core"), "one on is")
	assert_eq(int(Offers.info(w, b)["replaces"]), a, "the second form says it replaces the first")
	_take(w, [&"gun_charge"])
	assert_false(w.items_owned.has(a), "two forms never coexist")
	assert_eq(AttackSlots.form_id(w), &"lab_%d" % b)


# --- Offers --------------------------------------------------------------------------------------------------------
func test_an_incompatible_card_is_never_offered() -> void:
	var w := _world()
	var pierce := W.item(w, &"gun_pierce")
	assert_true(ItemPool.usable(w, pierce), "on for Orbs")
	(w.slot_table.form_cells[w.slot_table.default_form] as Dictionary).erase(pierce)  # C62: an off cell
	assert_false(ItemPool.usable(w, pierce))
	assert_false(ItemPool.available(w).has(pierce), "not in the pool")
	assert_false(ItemPool.available(w, true, 5).has(pierce), "nor the legendary or upgrade draw")
	assert_false(Shop.can_apply(w, pierce), "nor the shop's, an event's or a core's")
	for k in 200:
		w.rng_loot = RngStream.derive(k, "loot")
		assert_false(ItemPool.draw_weighted(w, 3, 3).has(pierce), "draw %d" % k)
	for idx in w.item_tables.size():  # the live table shuts nothing else on a Gun run
		var it := w.item_tables[idx]
		if idx != pierce and not it.retired and it.requires_weapon != PlayerTable.WEAPON_BLADE:
			assert_true(AttackSlots.usable(w, idx), "%s still offered" % it.id)


# --- Caps ----------------------------------------------------------------------------------------------------------
func test_twelve_shots_an_attack_extra_copies_merge_and_keep_the_damage() -> void:
	var w := _world()
	_take(w, [&"halo_shot", &"split_shot"])
	for id: StringName in [&"halo_shot", &"split_shot"]:
		CardLevels.set_level(w, W.item(w, id), CardLevels.MAX_LEVEL)
	var lab := W.world(&"gun", [&"halo_shot", &"split_shot"])  # no table: as before AS
	for id: StringName in [&"halo_shot", &"split_shot"]:
		CardLevels.set_level(lab, W.item(lab, id), CardLevels.MAX_LEVEL)
	var free := Modifiers.bolt(lab)
	var free_shards := W.hook_of(free, &"split_shot").child
	assert_eq(
		[ShotCap.shots(free), ShotCap.shots(free_shards)], [7, 7], "Halo 5 × Split 5 = 49 before AS"
	)
	var s := Modifiers.bolt(w)
	var shards := W.hook_of(s, &"split_shot").child
	assert_eq(ShotCap.shots(s), 7, "Halo's seven fit")
	assert_lte(ShotCap.shots(s) * ShotCap.shots(shards), 12, "pattern × Split children ≤ 12")
	assert_eq(ShotCap.shots(shards), 1, "the seven shards merged into one")
	var base := free_shards.share_permille if free_shards.share_permille > 0 else 1000
	assert_eq(shards.share_permille, base * 7, "it carries the seven's damage")
	assert_gt(shards.radius_m, free_shards.radius_m, "and is bigger")
	var big := AttackSpec.new()
	big.form = AttackSpec.Form.BOLT
	big.count = 20
	big.radius_m = 0.2
	ShotCap.merge(big, 12, 2000)
	assert_eq([big.count, big.share_permille], [12, 1667], "20 → 12, each ×20/12")
	assert_almost_eq(big.radius_m, 0.2 * 1.29, 0.001, "radius × √(20/12)")


## Player projectiles (bolts and rings) launched each tick of `ticks`, holding fire at the dummies.
func _launches(w: World, ticks: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := -1
	var rings := {}
	for t in ticks:
		W.run(w, 1, 0, W.S)
		var n := 0
		var top := seen
		var p := w.projectiles
		for k in p.ids.size():
			if p.team[k] == ActorStore.TEAM_PLAYER and p.ids[k] > seen:
				n += 1
				top = maxi(top, p.ids[k])
		seen = top
		for k in w.ab.ring_pos.size():
			var key := "%d:%d:%d" % [w.ab.ring_start[k], w.ab.ring_root[k], w.ab.ring_k[k]]
			if not rings.has(key):
				rings[key] = true
				n += 1
		out.append(n)
	return out


func _most_in_a_second(per_tick: PackedInt32Array) -> int:
	var most := 0
	var sum := 0
	for k in per_tick.size():
		sum += per_tick[k]
		if k >= ShotCap.WINDOW:
			sum -= per_tick[k - ShotCap.WINDOW]
		most = maxi(most, sum)
	return most


## A fight world for build `ids` at level 5, the top attack speed (20 Epic Attack Speed cards: the stat's cap) and a
## wall of tough dummies in front.
func _fight(ids: Array, per_second: int) -> World:
	var w := _world()
	w.slot_table.shots_per_second_max = per_second
	_take(w, ids)
	for idx in w.mod_slots:
		if CardLevels.is_card(w, idx):
			CardLevels.set_level(w, idx, CardLevels.MAX_LEVEL)
	for k in 20:
		Stats.add_card(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
	Modifiers.invalidate(w)
	for x in 6:
		for y in 3:
			w.add_dummy(w.player_pos() + Vector2(2.5 + x * 1.2, (y - 1) * 1.4), 0.45, 1000000)
	return w


func test_the_worst_legal_builds_launch_at_most_forty_projectiles_a_second() -> void:
	# Every Pattern with the two Secondaries that add shots (Split's children, Echo's repeat or Rapid Fire's rate),
	# two Elements and three triggers that cast small shots on hits and kills, the Pattern left of the triggers and
	# right of them (then every hit casts the whole Pattern). All at level 5 at the top attack speed.
	var builds := {
		"halo_split_rapid":
		[&"halo_shot", &"split_shot", &"gun_rapid_fire", &"ember_core", &"storm_core"] + TRIGGERS,
		"hit_then_halo_split_echo":
		[
			&"trigger_on_hit_twice",
			&"halo_shot",
			&"split_shot",
			&"gun_echo",
			&"storm_core",
			&"ember_core"
		],
		"twin_split_echo":
		[&"gun_twin", &"split_shot", &"gun_echo", &"ember_core", &"storm_core"] + TRIGGERS,
		"ring_split_rapid":
		[&"gun_ring", &"split_shot", &"gun_rapid_fire", &"ember_core", &"storm_core"] + TRIGGERS,
		"backfire_split_echo":
		[&"gun_backfire", &"split_shot", &"gun_echo", &"ember_core", &"storm_core"] + TRIGGERS,
	}
	var report := PackedStringArray()
	for name: String in builds:
		var w := _fight(builds[name], 40)
		assert_eq(w.mod_slots.size(), (builds[name] as Array).size(), "%s is a legal wand" % name)
		var most := _most_in_a_second(_launches(w, 360))
		var uncapped := _most_in_a_second(_launches(_fight(builds[name], 100000), 360))
		report.append("%s %d/s (12-per-attack cap alone: %d/s)" % [name, most, uncapped])
		assert_lte(most, 40, "%s: at most 40 a second (%d)" % [name, most])
		assert_gt(most, 0, "%s fires" % name)
	gut.p("AS shots a second: " + "; ".join(report))


func test_the_shot_budget_keeps_the_players_own_shot_and_the_damage() -> void:
	var w := _fight([&"halo_shot"], 40)
	var per := _launches(w, 120)
	assert_lte(_most_in_a_second(per), 40)
	var gaps := 0
	for k in range(60, per.size()):
		gaps += 1 if per[k] == 0 else 0
	assert_lt(gaps, per.size() - 60, "the Gun keeps firing past the budget")
	assert_lte(ShotCap.last_second(w) + ShotCap.reserve(w), 40, "the sim's window agrees")


# --- Old saves -----------------------------------------------------------------------------------------------------
func test_an_over_full_wand_is_trimmed_leftmost_first_and_refunded() -> void:
	var w := _world()
	for id: StringName in [
		&"gun_twin", &"gun_pierce", &"halo_shot", &"gun_homing", &"gun_ricochet", &"ember_core"
	]:
		w.add_item(W.item(w, id))  # a save from before AS: no rule held these back
	BuildSlots.sync(w)
	var expect := (
		WandMigration.refund_of(w, W.item(w, &"halo_shot"))
		+ WandMigration.refund_of(w, W.item(w, &"gun_ricochet"))
	)
	var shards := w.shards
	var refund := AttackSlots.trim(w)
	assert_eq(
		_ids(w), [&"gun_twin", &"gun_pierce", &"gun_homing", &"ember_core"], "the leftmost stay"
	)
	assert_eq(refund, expect, "the rest are refunded at the salvage price")
	assert_eq(w.shards, shards + refund)
	assert_eq(AttackSlots.trim(w), 0, "idempotent")


func test_a_run_saved_before_as_loads_trimmed_and_plays_on() -> void:
	# The save: a Gun run on floor 2 whose wand the code before AS let hold two Patterns and three Secondaries (TEST
	# HELPER: the cards added without the slot rules, as that code took them), snapshotted mid-fight.
	var old := SaveLab.floor_world(7, 2, &"gun")
	old.slot_table = null
	for id: StringName in [
		&"gun_twin", &"gun_pierce", &"halo_shot", &"gun_homing", &"gun_ricochet", &"ember_core"
	]:
		old.add_item(W.item(old, id))
	BuildSlots.sync(old)
	for t in 30:
		old.step(AttackScenario.frame(t))
	var snap := WorldSnapshot.take(old)
	var w := SaveLab.floor_world(7, 2, &"gun")  # the load, as FloorPlan's resume
	assert_eq(WorldSnapshot.apply(w, snap), "", "the save restores")
	assert_eq(w.mod_slots.size(), 6, "over-full as saved")
	var shards := w.shards
	var expect := (
		WandMigration.refund_of(w, W.item(w, &"halo_shot"))
		+ WandMigration.refund_of(w, W.item(w, &"gun_ricochet"))
	)
	WandMigration.run(w)
	var refund := AttackSlots.trim(w)
	assert_eq(
		_ids(w),
		[&"gun_twin", &"gun_pierce", &"gun_homing", &"ember_core"],
		"the leftmost of each stay"
	)
	assert_eq(refund, expect, "Halo and Ricochet are refunded as shards")
	assert_eq(w.shards, shards + refund)
	for t in 120:
		w.step(AttackScenario.frame(t))
	assert_false(w.player_dead(), "the run plays on")
	assert_eq(w.mod_slots.size(), 4, "with a legal wand")
