extends GutTest
## v0.6.5 WN1 (docs/design/WAND.md rules 4–5, 9; owner W6 "Grows during the run"; SIM_CONTRACTS §8e): the wand as the
## build holds it. Its slots grow 4 → 6 → 8 by floor (data), a new card with every slot full opens the Swap, the held
## cards keep their order; a reorder is an InputFrame action applied at its tick (replays stay exact); the reads
## (WorldReader.wand) and the plain-words read-back (Wand.describe, en + es); saves keep the order and older saves
## migrate; CatchUp.power reads the wand whatever its order.

## v0.6.5 WN5b: Blade wand cards (the v0.6 cards these tests held are retired and migrate at a floor's start).
const FOUR: Array = [&"heavy", &"fissure", &"wide_arc", &"double_slash"]

var _repo: ContentRepository


func before_all() -> void:
	_repo = AttackScenario.repo()


## A Blade (or Gun) run's world on floor `f` with the shipped wand, items, abilities and stat cards.
func _world(f: int = 1, build: StringName = &"blade") -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	t.crit_chance_permille = 0
	var w := World.new(5, t)
	w.floor_index = f
	w.dummy_speed = 0.0
	w.wand_table = WandCompiler.from_repo(_repo)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _it(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _take(w: World, ids: Array) -> void:
	for id: StringName in ids:
		assert_true(BuildSlots.take(w, WandLab.code(w, id)), "takes %s" % id)


func _pick(v: int) -> InputFrame:
	var f := InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0)
	f.pick = v
	return f


func _ids(w: World) -> Array:
	var out := []
	for c in w.mod_slots:
		out.append(Offers.info(w, c)["id"])
	return out


# --- The slots grow -------------------------------------------------------------------------------------------
## v0.9.0 FV (owner Q24, "4, 5, 6, 7, 8"): one more slot a floor over the five floors (was 4 → 6 → 8).
func test_the_wand_grows_one_slot_a_floor() -> void:
	var got := []
	for f in [1, 2, 3, 4, 5, 6]:
		got.append(Wand.slots(_world(f)))
	assert_eq(got, [4, 5, 6, 7, 8, 8], "4 on floor 1, one more after each boss (the last repeats)")
	var lab := _world()
	lab.wand_table = null
	assert_eq(Wand.slots(lab), BuildSlots.SLOTS, "a world without the table keeps six")
	var def: WandDefinition = _repo.get_def(&"wand", &"wand")
	assert_eq(def.validate(), [], "the shipped wand validates")
	assert_eq(def.slots_per_floor, PackedInt32Array([4, 5, 6, 7, 8]), "starting values (data)")


func test_with_every_slot_full_a_new_card_opens_the_swap() -> void:
	var w := _world(1)
	_take(w, FOUR)
	assert_true(BuildSlots.full(w), "four cards fill floor 1's wand")
	var next := _it(w, &"flurry")
	assert_true(BuildSlots.needs_swap(w, next))
	Offers.apply(w, next)
	assert_true(BuildSlots.swapping(w), "the Swap opens")
	w.step(_pick(InputFrame.PICK_SWAP_BASE + 3))
	assert_eq(_ids(w), [&"heavy", &"fissure", &"wide_arc", &"flurry"], "in place")
	var f2 := _world(2)
	_take(f2, FOUR)
	assert_false(BuildSlots.needs_swap(f2, _it(f2, &"flurry")), "floor 2 has five slots (FV)")


func test_the_held_cards_keep_their_order_into_the_next_floor() -> void:
	var w := _world(1)
	_take(w, [&"heavy", &"shared_bleed", &"wide_arc", &"double_slash"])
	Wand.move(w, 3, 0)
	var next := _world(2)
	RunCarry.apply(next, RunCarry.take(w, 0))
	Abilities.start_floor(next)
	assert_eq(next.mod_slots, w.mod_slots, "the carry keeps the wand's order")
	assert_eq(Wand.slots(next), 5, "and the wand has grown (v0.9.0 FV: one slot a floor)")


func test_utility_and_stat_cards_stay_outside_the_wand() -> void:
	var w := _world(1)
	_take(w, FOUR)
	var blink := WandLab.code(w, &"blink")
	assert_true(BuildSlots.take(w, blink), "the utility needs no slot")
	assert_true(BuildSlots.take(w, Offers.stat_code(0, 0)), "a stat card needs none")
	assert_eq(w.mod_slots.size(), 4)
	assert_false(BuildSlots.swapping(w))


# --- The reorder is input ---------------------------------------------------------------------------------------
func test_a_reorder_is_an_input_applied_at_its_tick() -> void:
	var w := _world(1)
	_take(w, [&"ember_core", &"fissure", &"wide_arc", &"flurry"])
	var before := Modifiers.book(w).digest
	var t0 := w.tick
	w.step(_pick(InputFrame.wand_move(0, 2)))
	assert_eq(w.tick, t0 + 1)
	assert_eq(_ids(w), [&"fissure", &"wide_arc", &"ember_core", &"flurry"], "0 → 2: the rest shift")
	var b := Modifiers.book(w)
	assert_ne(b.digest, before, "the wand compiled again in its new order")
	assert_eq(b.modifier_ids[0], "fissure")


func test_a_move_to_or_from_an_empty_slot_changes_nothing() -> void:
	var w := _world(1)
	_take(w, [&"ember_core", &"wide_arc"])
	var ref := _world(1)
	_take(ref, [&"ember_core", &"wide_arc"])
	for v in [InputFrame.wand_move(0, 3), InputFrame.wand_move(5, 0), InputFrame.wand_move(1, 1)]:
		w.step(_pick(v))
		ref.step(_pick(InputFrame.PICK_NONE))
	assert_eq(w.mod_slots, ref.mod_slots)
	assert_eq(w.state_hash(), ref.state_hash(), "a refused move is no state")


func test_a_reorder_while_a_choice_waits_moves_and_answers_nothing() -> void:
	var w := _world(1)
	_take(w, FOUR)
	Offers.apply(w, _it(w, &"flurry"))
	assert_true(BuildSlots.swapping(w))
	w.step(_pick(InputFrame.wand_move(3, 0)))
	assert_true(BuildSlots.swapping(w), "the Swap still waits: the move is not its answer")
	assert_eq(_ids(w), [&"double_slash", &"heavy", &"fissure", &"wide_arc"])
	w.step(_pick(InputFrame.PICK_SWAP_BASE + 0))
	assert_eq(_ids(w), [&"flurry", &"heavy", &"fissure", &"wide_arc"])


func test_a_run_with_reorders_replays_exactly() -> void:
	var runs := []
	for n in 3:
		var w := WandLab.fight(&"gun", [&"ember_core", &"gun_pierce", &"split_shot"])
		for t in 400:
			var f := AttackScenario.frame(t)
			if n < 2 and t == 120:
				f.pick = InputFrame.wand_move(0, 2)
			if n < 2 and t == 260:
				f.pick = InputFrame.wand_move(1, 0)
			w.step(f)
		runs.append([w.state_hash(), w.mod_slots.duplicate()])
	assert_eq(runs[0], runs[1], "the same inputs, the same run")
	assert_ne(runs[0][0], runs[2][0], "the reorders changed the run")


func test_cards_past_a_third_trigger_read_as_unused() -> void:
	var wand := {
		"weapon": &"blade",
		"cards":
		[
			{"name_key": &"A", "trigger": AttackSpec.Trigger.ON_HIT},
			{"name_key": &"B", "trigger": AttackSpec.Trigger.ON_KILL},
			{"name_key": &"C", "trigger": AttackSpec.Trigger.ON_END},
			{"name_key": &"D", "trigger": -1},
		],
	}
	var keys := []
	for l: Dictionary in Wand.describe(wand):
		keys.append(l["key"])
	assert_eq(
		keys, [&"WAND_READ_FIRE", &"WAND_READ_ON_HIT", &"WAND_READ_ON_KILL", &"WAND_READ_UNUSED"]
	)


# --- Saves --------------------------------------------------------------------------------------------------------
func test_a_snapshot_keeps_the_order_with_equal_hashes() -> void:
	var w := WandLab.fight(&"gun", [&"ember_core", &"gun_pierce", &"split_shot"])
	for t in 150:
		w.step(AttackScenario.frame(t))
	w.step(_pick(InputFrame.wand_move(2, 0)))
	var snap := w.to_snapshot()
	var base := WandLab.fight(&"gun", [&"ember_core", &"gun_pierce", &"split_shot"])
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.mod_slots, w.mod_slots, "the slot order")
	assert_eq(base.state_hash(), w.state_hash(), "equal hashes")
	for t in range(151, 300):
		w.step(AttackScenario.frame(t))
		base.step(AttackScenario.frame(t))
	assert_eq(base.state_hash(), w.state_hash(), "and they play on the same")


func test_an_older_save_keeps_its_pick_order_and_every_card() -> void:
	# A v0.6.0 save (payload 3): six cards in pick order on floor 1, where the wand now has four. v0.6.5 WN5b: they
	# are v0.6 cards, so each maps onto its wand card in that order or is refunded (WandMigration).
	var old := _world(1)
	old.wand_table = null  # v0.6.0: six slots
	var six := [&"ember_edge", &"long_edge", &"twin_arc", &"overcharge", &"conductor", &"shatter"]
	_take(old, six)
	var carry := RunCarry.take(old, 0)
	var w := _world(1)
	RunCarry.apply(w, carry)
	var shards := w.shards
	Abilities.start_floor(w)
	assert_eq(
		_ids(w),
		[&"ember_core", &"wide_arc", &"double_slash", &"finisher_plus", &"storm_core"],
		"each in its pick order: S1, B1, B5, B14, S2; Shatter has no wand row (refunded)"
	)
	assert_gt(w.shards, shards, "the one without a wand row is refunded")


func test_a_v0_5_carry_migrates_into_the_floor_reached_slot_count() -> void:
	for f in [1, 2]:
		var probe := _world(f)
		var items := PackedInt32Array()
		for id: StringName in [&"heavy", &"whirl", &"flurry", &"thrust", &"wide_arc"]:  # v0.6.5 WN5b
			items.append(_it(probe, id))
		var w := _world(f)
		RunCarry.apply(w, {&"items_owned": items, &"hp": 50})
		Abilities.start_floor(w)
		assert_eq(
			w.mod_slots.size(),
			mini(5, Wand.slots(w)),
			"floor %d: the floor's slots, in pickup order" % f
		)
		assert_eq(w.mod_slots[0], items[0])


func test_catch_up_reads_the_wand_whatever_its_order() -> void:
	var w := _world(1)
	w.catch_up_table = CatchUpTable.new()
	var p0 := CatchUp.power(w)
	_take(w, FOUR)
	var p1 := CatchUp.power(w)
	assert_gt(p1, p0, "the wand's cards raise P")
	w.step(_pick(InputFrame.wand_move(0, 3)))
	assert_eq(CatchUp.power(w), p1, "a reorder never changes P")
