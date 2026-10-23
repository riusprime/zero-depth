extends GutTest
## v0.9.0 MP (PLAN W49-W50): the Rune Fragments a run earns in the sim (RuneFragments, RunState.fragments_done): a
## boss beaten, a floor cleared, each secret found, the Purple Portal travelled, the final boss, a collectible (CL's
## hook); none without a FragmentTable (goldens, sims, saves before MP); and the Void kept out of every draw while
## World.locked_items holds it.

const SEED := 4242


func _table() -> FragmentTable:
	return MetaProgress.compile_table(ContentRepository.load_all())


func test_the_table_is_the_content() -> void:
	var t := _table()
	var d := MetaProgress.definition(ContentRepository.load_all())
	assert_eq(
		[t.floor_cleared, t.boss, t.secret, t.purple_portal, t.final_boss, t.collectible],
		[d.floor_cleared, d.boss, d.secret, d.purple_portal, d.final_boss, d.collectible]
	)


func test_a_fresh_floor_earns_nothing_and_a_boss_earns() -> void:
	var t := _table()
	var w := SaveLab.floor_world(SEED, 1)
	assert_eq(RuneFragments.of_floor(w, t, false), 0, "nothing done yet")
	assert_eq(RuneFragments.of_floor(w, null, true), 0, "no table: none")
	w.boss_flow.state = BossFlow.State.OPEN
	assert_eq(RuneFragments.of_floor(w, t, false), t.boss, "the boss beaten")
	assert_eq(RuneFragments.of_floor(w, t, true), t.boss + t.floor_cleared, "and the floor cleared")
	w.boss_flow.route_taken = Routes.Route.DEEP
	assert_eq(
		RuneFragments.of_floor(w, t, true),
		t.boss + t.floor_cleared + t.purple_portal,
		"the Purple Portal travelled"
	)


func test_each_secret_found_earns() -> void:
	var t := _table()
	var found := 0
	var w := SaveLab.floor_world(SEED, 2)
	if w.timed != null:
		w.timed.opened = 1
		found += 1
	if w.runes != null:
		w.runes.solved = 1
		found += 1
	if w.breakables != null and w.breakables.has_crack():
		w.breakables.crack_broken = 1
		found += 1
	if w.purple != null:
		w.purple.lit = 1
		found += 1
	assert_eq(RuneFragments.secrets_found(w), found, "every secret counted")
	assert_eq(RuneFragments.of_floor(w, t, false), found * t.secret)


func test_finish_floor_adds_the_floor_and_total_adds_the_current() -> void:
	var t := _table()
	var run := SaveLab.run_state(SEED, 1)
	run.fragment_table = t
	var w := SaveLab.build_floor(run)
	w.boss_flow.state = BossFlow.State.OPEN
	assert_eq(RuneFragments.total(run, w), t.boss, "the current floor so far")
	run.finish_floor(w)
	assert_eq(run.fragments_done, t.boss + t.floor_cleared, "banked into the run's tally")
	assert_eq(RuneFragments.total(run, null), run.fragments_done)
	RuneFragments.add_collectibles(run, 2)
	assert_eq(run.fragments_done, t.boss + t.floor_cleared + 2 * t.collectible, "CL's hook")
	var bare := SaveLab.run_state(SEED, 1)
	var w2 := SaveLab.build_floor(bare)
	w2.boss_flow.state = BossFlow.State.OPEN
	bare.finish_floor(w2)
	RuneFragments.add_collectibles(bare)
	assert_eq(bare.fragments_done, 0, "a run without a table earns none")


func test_a_locked_card_is_never_drawn() -> void:
	var w := SaveLab.floor_world(SEED, 1, &"gun")
	var idx := -1
	for k in w.item_tables.size():
		if w.item_tables[k].id == &"gun_void":
			idx = k
	assert_gte(idx, 0)
	var before := w.state_hash()
	w.locked_items = PackedInt32Array([idx])
	assert_ne(w.state_hash(), before, "a lock is part of the floor's state")
	w.locked_items = PackedInt32Array()
	assert_eq(w.state_hash(), before, "no lock: the hash as before MP")
	assert_true(ItemPool.usable(w, idx), "a Gun run may draw the Void unlocked")
	w.locked_items = PackedInt32Array([idx])
	assert_false(ItemPool.usable(w, idx), "locked: never")
	var drawn := 0
	for n in 300:
		if ItemPool.draw(w, 6).has(idx):
			drawn += 1
	assert_eq(drawn, 0, "300 draws of 6: never the Void")
