extends GutTest
## v0.10.5 O1 (owner L23: "remove them from the game to have a cleaner code"): the deleted cards, combos and curses keep
## their saved indices (CardOrder's frozen orders, EventCompiler.RETIRED_CURSES), so a save written before O1 still
## names the same live cards, and the deleted ones are retired stubs that no run offers.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func test_every_item_keeps_its_index() -> void:
	var t := ContentCompiler.compile_items(_repo)
	assert_eq(
		t.size(),
		CardOrder.ITEMS.size(),
		"no card was added since O1 (a new one appends after these)"
	)
	for k in CardOrder.ITEMS.size():
		assert_eq(t[k].id, CardOrder.ITEMS[k], "item %d" % k)
		var gone := CardOrder.RETIRED_ITEMS.has(t[k].id)
		assert_eq(
			gone,
			_repo.get_def(&"items", t[k].id) == null,
			"%s: a stub exactly when deleted" % t[k].id
		)
		if gone:
			assert_true(t[k].retired, "%s is never offered" % t[k].id)
			assert_true(t[k].modifiers.is_empty(), "%s does nothing" % t[k].id)


func test_every_ability_and_combo_keeps_its_index() -> void:
	var a := ContentCompiler.compile_abilities(_repo)
	assert_eq(a.size(), CardOrder.ABILITIES.size())
	for k in a.size():
		assert_eq(a[k].id, CardOrder.ABILITIES[k])
		assert_eq(a[k].retired, CardOrder.RETIRED_ABILITIES.has(a[k].id), String(a[k].id))
	var c := ContentCompiler.compile_combos(_repo)
	assert_eq(c.size(), CardOrder.COMBOS.size())
	for k in c.size():
		assert_eq(c[k].id, CardOrder.COMBOS[k])
		assert_eq(c[k].retired, CardOrder.RETIRED_COMBOS.has(c[k].id), String(c[k].id))
	var live := []
	for t in c:
		if not t.retired:
			live.append(t.id)
	assert_eq(
		live,
		[&"blood_harvest", &"shatter_dash", &"slipstream", &"spiked_phase"],
		"owner: keep those 4"
	)


func test_the_curse_indices_stay() -> void:
	var ids := EventCompiler.curse_ids(_repo)
	assert_eq(
		ids,
		[
			&"blood_price",
			&"brittle",
			&"fevered",
			&"glass_heart",
			&"heavy_hands",
			&"leaky_core",
			&"marked_hunt",
			&"price_gouge",
			&"rooted",
			&"swarm_call",
			&"swift_foes",
			&"tunnel_vision",
			&"withering",
		],
		"the order World.ev.curses' indices name"
	)
	for gone: StringName in [
		&"leaky_core", &"price_gouge", &"swarm_call", &"swift_foes", &"withering"
	]:
		assert_null(_repo.get_def(&"curses", gone), "%s deleted" % gone)
		assert_true(EventCompiler.RETIRED_CURSES.has(gone))


func test_every_migration_row_names_a_stub_or_a_live_card() -> void:
	var m := WandCompiler.migration(_repo)
	assert_eq(m.old_ids.size(), 60, "the record of what each old card becomes stays")
	for id in m.old_ids:
		assert_true(
			CardOrder.RETIRED_ITEMS.has(id) or CardOrder.RETIRED_ABILITIES.has(id),
			"%s has a stub" % id
		)


func test_the_dev_panel_never_picks_a_deleted_card() -> void:
	var w := SaveLab.floor_world(3, 1)
	var api := DebugApi.new(w)
	for k in w.item_tables.size() + 2:
		api.next_mod()
		assert_false(
			w.item_tables[api.mod_choice].retired, "mod %s" % w.item_tables[api.mod_choice].id
		)
	for k in w.ability_tables.size() + 2:
		api.next_ability()
		assert_false(
			w.ability_tables[api.ability_choice].retired,
			"ability %s" % w.ability_tables[api.ability_choice].id
		)
