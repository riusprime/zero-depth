extends GutTest
## v0.10.5 W3-P10c (owner W7, docs/roadmap/v0.10.5/W3_W7_LOOP_POWER_G1.md §C, Q2, Q3): a new loop's free Constellation
## pick (1 of 3, on a named stream, no repeats, Prism twice at most, no skip), carried, saved and hashed; and the
## effects of Prism (a Gun's Element slots, a Blade's softer falloff), Twin Star (overlevels × 2), Glass Sky (× 2
## damage, × 0.5 max HP) and Hunter's Sky (× 1.5 on elites and bosses).


func _loop_two_run(run_seed: int, build: StringName = &"blade") -> RunState:
	var run := SaveLab.run_state(run_seed, SaveLab.floors(), build)
	var w := SaveLab.build_floor(run)
	w.boss_flow.ascend_choice = Ascension.Choice.LOOP
	run.finish_floor(w)
	return run


func _pick(c: int) -> InputFrame:
	var f := InputFrame.new()
	f.pick = c
	return f


func test_an_offer_is_three_held_never_and_prism_twice_at_most() -> void:
	for s in 40:
		var got := Constellations.offer(500 + s, 2, PackedInt32Array())
		assert_eq(got.size(), Constellations.OFFER_SIZE, "three cards")
		for id in got:
			assert_true(Constellations.ALL.has(id), "a Constellation id")
			assert_eq(got.count(id), 1, "no repeats in one offer")
	assert_eq(
		Constellations.offer(77, 2, PackedInt32Array()),
		Constellations.offer(77, 2, PackedInt32Array()),
		"a seed's loop: same offer"
	)
	var seen := {}
	for s in 40:
		seen[str(Constellations.offer(900 + s, 2, PackedInt32Array()))] = true
	assert_gt(seen.size(), 1, "seeds differ")
	var held := PackedInt32Array(
		[Constellations.TWIN_STAR, Constellations.GLASS_SKY, Constellations.PRISM]
	)
	for s in 40:
		for id in Constellations.offer(s, 3, held):
			assert_false(
				id in [Constellations.TWIN_STAR, Constellations.GLASS_SKY],
				"a held one is never offered again"
			)
	assert_true(
		Constellations.offerable(held).has(Constellations.PRISM), "Prism is offered again once held"
	)
	held.append(Constellations.PRISM)
	assert_false(Constellations.offerable(held).has(Constellations.PRISM), "but not past PRISM_MAX")
	var nearly := PackedInt32Array(
		[
			Constellations.PRISM,
			Constellations.PRISM,
			Constellations.TWIN_STAR,
			Constellations.GLASS_SKY,
			Constellations.STARFALL,
			Constellations.DEEP_WOUNDS
		]
	)
	var last := Constellations.offer(5, 7, nearly)
	assert_eq(last.size(), 2, "fewer left: what is left")
	assert_true(last.has(Constellations.SUPERNOVA) and last.has(Constellations.HUNTERS_SKY))
	nearly.append_array(PackedInt32Array([Constellations.SUPERNOVA, Constellations.HUNTERS_SKY]))
	assert_eq(Constellations.offer(5, 8, nearly).size(), 0, "none left: no pick")


func test_the_loop_device_opens_the_pick_and_only_a_pick_closes_it() -> void:
	var run := _loop_two_run(321)
	var w := SaveLab.build_floor(run)
	var offer := Constellations.offer(run.run_seed, 2, PackedInt32Array())
	assert_eq(w.constellation_offer, offer, "loop 2's floor 1 opens with the loop's offer")
	assert_true(WorldReader.new(w).constellation_open())
	var at := w.player_pos()
	var still := w.state_hash()
	for k in 20:
		var f := InputFrame.new()
		f.move = Vector2i(1, 0)
		f.pick = InputFrame.PICK_CANCEL if k == 3 else InputFrame.PICK_NONE
		w.step(f)
	assert_true(Constellations.open(w), "a cancel or nothing: it waits (no skip, owner Q3)")
	assert_eq(w.player_pos(), at, "the world waits on it")
	assert_ne(w.state_hash(), still, "the tick still counts")
	w.step(_pick(2))
	assert_eq(w.constellations, PackedInt32Array([offer[1]]), "the second card taken")
	assert_false(Constellations.open(w), "the pick closed")
	assert_eq(WorldReader.new(w).constellations(), w.constellations, "the reader names it")
	# carried into the next floor, which opens no pick
	w.boss_flow.ascend_choice = Ascension.Choice.NONE
	run.finish_floor(w)
	var w2 := SaveLab.build_floor(run)
	assert_eq(w2.constellations, w.constellations, "carried")
	assert_false(Constellations.open(w2), "floor 2 opens no pick")


func test_a_loop_one_floor_holds_none_and_hashes_as_before() -> void:
	var w := SaveLab.floor_world(4242, 1)
	assert_false(Constellations.open(w), "loop 1 offers none")
	var h := w.state_hash()
	var probe := StateHasher.new()
	Constellations.hash_into(w, probe)
	assert_eq(probe.finish_hex(), StateHasher.new().finish_hex(), "nothing hashed while none")
	assert_eq(w.state_hash(), h)
	w.constellations.append(Constellations.PRISM)
	assert_ne(w.state_hash(), h, "a held one is hashed")


func test_the_pick_round_trips_through_a_save() -> void:
	var run := _loop_two_run(321)
	var w := SaveLab.build_floor(run)
	CombatLab.idle(w, 5)
	var p := RunSaver.payload_of(w, run, 99, PackedByteArray([1]))
	var q: Dictionary = (RunSaveStore.decode(RunSaveStore.encode(p))[0] as Dictionary)["payload"]
	var w2 := SaveLab.build_floor(SaveLab.run_from(q))
	assert_eq(WorldSnapshot.apply(w2, q["world"]), "", "the snapshot fits")
	assert_eq(w2.constellation_offer, w.constellation_offer, "the open pick comes back")
	assert_eq(w2.state_hash(), w.state_hash())
	w.step(_pick(1))
	w2.step(_pick(1))
	assert_eq(w2.constellations, w.constellations, "and takes the same card")
	assert_eq(w2.state_hash(), w.state_hash(), "replay-exact")


func _take(w: World, id: int) -> void:
	w.constellation_offer = PackedInt32Array([id])
	Constellations.take(w, 0)


func test_prism_opens_a_guns_third_and_fourth_element_slot() -> void:
	var w := SaveLab.floor_world(4242, 1, &"gun")
	assert_true(AttackSlots.gun(w), "a Gun run")
	assert_eq(AttackSlots.limit(w, AttackSlots.ELEMENT), 2, "data: 2 Element slots")
	_take(w, Constellations.PRISM)
	assert_eq(AttackSlots.limit(w, AttackSlots.ELEMENT), 3, "one Prism: 3")
	_take(w, Constellations.PRISM)
	assert_eq(AttackSlots.limit(w, AttackSlots.ELEMENT), 4, "two: 4")
	assert_eq(AttackSlots.limit(w, AttackSlots.SECONDARY), 2, "the other limits stay")


func test_prism_softens_a_blades_element_falloff_one_step_each() -> void:
	var w := SaveLab.floor_world(4242, 1, &"blade")
	assert_lt(AttackSlots.limit(w, AttackSlots.ELEMENT), 0, "a Blade run: no Element limit")
	assert_eq(w.pair_table.prism_falloff_steps, 1, "data: one step a Prism")
	var i := w.actors.index_of(
		w.add_enemy(CombatLab.tables()[0].kind, w.player_pos() + Vector2(3, 0))
	)
	w.actors.burn_stacks[i] = 1
	w.actors.poison_stacks[i] = 1
	var e := ElementStack.BLEED
	assert_eq(ElementStack.falloff_permille(w, i, e), 500, "two others: 500")
	_take(w, Constellations.PRISM)
	assert_eq(ElementStack.falloff_permille(w, i, e), 700, "one Prism: one step softer")
	_take(w, Constellations.PRISM)
	assert_eq(ElementStack.falloff_permille(w, i, e), 1000, "two: none")


func test_twin_star_doubles_each_overlevel() -> void:
	var w := SaveLab.floor_world(4242, 1, &"gun")
	var idx := -1
	for k in w.item_tables.size():
		if LootPacing.category(w, k) > 0:
			idx = k
			break
	assert_gte(idx, 0, "a wand card")
	var step := w.loot_pacing.overlevel_permille[LootPacing.category(w, idx) - 1]
	assert_eq(step, 150, "data: + 15 % an overlevel")
	assert_eq(CardLevels.overlevel_permille(w, idx, 2), 1300)
	_take(w, Constellations.TWIN_STAR)
	assert_eq(CardLevels.overlevel_permille(w, idx, 1), 1300, "Twin Star: + 30 %")
	assert_eq(CardLevels.overlevel_permille(w, idx, 2), 1600)
	assert_eq(CardLevels.overlevel_permille(w, idx, 0), 1000, "no overlevel: none")


func test_glass_sky_doubles_damage_and_halves_max_hp() -> void:
	var w := SaveLab.floor_world(4242, 1)
	var dmg := Stats.damage_permille(w)
	var mx := w.actors.max_hp[0]
	_take(w, Constellations.GLASS_SKY)
	assert_eq(Stats.damage_permille(w), dmg * 2, "× 2 damage")
	assert_eq(w.actors.max_hp[0], (mx + 1) / 2, "× 0.5 max HP at the pick")
	assert_eq(w.actors.max_hp[0], Stats.max_hp(w), "the stat reads the same")
	assert_lte(w.actors.hp[0], w.actors.max_hp[0], "HP clamped to the new max")
	var low := SaveLab.floor_world(4242, 1)
	low.actors.hp[0] = 1
	_take(low, Constellations.GLASS_SKY)
	assert_eq(low.actors.hp[0], 1, "never below 1")


func test_hunters_sky_hits_elites_and_bosses_harder() -> void:
	var w := SaveLab.floor_world(4242, 1)
	var i := w.actors.index_of(
		w.add_enemy(CombatLab.tables()[0].kind, w.player_pos() + Vector2(3, 0))
	)
	w.actors.invuln[i] = 0
	var me := w.actors.ids[0]
	assert_eq(Constellations.hunt_permille(w, i), 1000, "not held: none")
	_take(w, Constellations.HUNTERS_SKY)
	assert_eq(Constellations.hunt_permille(w, i), 1000, "a normal enemy: none")
	var hp := w.actors.hp[i]
	var plain := Damage.tick_dot(w, i, 10, me, me, &"")
	assert_eq(hp - w.actors.hp[i], plain)
	w.actors.kinds[i] = ActorStore.Kind.BREAKER  # an elite
	assert_eq(
		Constellations.hunt_permille(w, i), Constellations.HUNTERS_SKY_PERMILLE, "an elite: × 1.5"
	)
	var hunted := Damage.tick_dot(w, i, 10, me, me, &"")
	assert_eq(hunted, Constellations.scale(plain, 1500), "its damage-over-time too")
	w.actors.kinds[i] = ActorStore.Kind.GATEKEEPER
	assert_eq(Constellations.hunt_permille(w, i), 1500, "a boss: × 1.5")
	assert_eq(Constellations.hunt_permille(w, 0), 1000, "never the hero")
