extends GutTest
## v0.3.0 G presentation: status effects on enemies (embers, shock pips, drips, frost crystals, the frozen shell),
## guard-charge orbs, payoff effects, the combo card and the HUD's combo badges. Materials are kept, never switched
## to another shader (the v0.2.0 DAMAGE_LAG rule).


func _views(w: World) -> Array:
	var reader := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := StatusVisuals.new(actors)
	add_child_autofree(fx)
	actors.sync(reader)
	fx.sync(reader)
	return [reader, actors, fx]


func _world() -> World:
	var w := World.new(3, PlayerTable.starting_values())
	var repo := SharedContent.repo()
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	for k in w.item_tables.size():
		w.add_item(k)
	w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	w.add_dummy(Vector2(-2, 0), 0.35, 500)
	return w


func _keys(node: Node) -> Dictionary:
	var stat := node.get_node_or_null("Statuses")
	return DamageFlashKeys.of(stat) if stat != null else {}


func test_each_status_shows_its_pieces_and_they_go_when_it_ends() -> void:
	var w := _world()
	var s := _views(w)
	var actors: ActorViews = s[1]
	var fx: StatusVisuals = s[2]
	var id := w.actors.ids[1]
	assert_eq(fx.view_count(), 0, "no status, nothing built")
	var a := w.actors
	a.burn_stacks[1] = 5
	a.shock_stacks[1] = 3
	a.bleed_stacks[1] = 7
	a.frost_stacks[1] = 2
	w.guard_charges = 2
	fx.sync(s[0])
	assert_eq(fx.shown(id, &"embers"), StatusVisuals.EMBERS, "a full burn: every ember")
	assert_eq(fx.badge(id, &"shock"), 3, "v0.10.0 FX: the shock badge reads x3")
	assert_eq(fx.badge(id, &"burn"), 5, "the burn badge x5")
	assert_eq(fx.shown(id, &"drips"), 3)
	assert_eq(fx.shown(id, &"crystals"), 2, "one crystal per frost stack")
	assert_eq(fx.shown(id, &"shell"), 0)
	assert_eq(fx.shown(w.actors.ids[0], &"orbs"), 2, "guard charges circle the player")
	var keys := _keys(actors.actor_node(id))
	assert_gt(keys.size(), 10)
	a.frost_stacks[1] = 0
	a.frozen_t[1] = 30
	fx.sync(s[0])
	assert_eq(fx.shown(id, &"shell"), 1, "frozen: the ice shell")
	assert_eq(fx.shown(id, &"crystals"), StatusVisuals.CRYSTALS)
	assert_eq(_keys(actors.actor_node(id)), keys, "no material changed its shader")
	for m in [&"burn_stacks", &"shock_stacks", &"bleed_stacks", &"frozen_t"]:
		var arr: PackedInt32Array = a.get(m)
		arr[1] = 0
		a.set(m, arr)
	w.guard_charges = 0
	fx.sync(s[0])
	assert_eq(fx.view_count(), 0, "statuses over: the pieces go")


func test_payoffs_draw_once_each() -> void:
	var w := _world()
	var s := _views(w)
	var fx: StatusVisuals = s[2]
	w.discharge_tick = 5
	w.discharge_from = Vector2(1, 0)
	w.discharge_to = PackedVector2Array([Vector2(3, 1), Vector2(2, -2)])
	w.shatter_tick = 5
	fx.sync(s[0])
	assert_eq(
		fx.fx_count(), 4 * 2 + 1 + 1, "two lightning lines, the discharge ring, the shatter ring"
	)
	fx.sync(s[0])
	assert_eq(fx.fx_count(), 10, "the same payoff doesn't draw twice")
	for k in StatusVisuals.FX_FRAMES:
		fx._process(1.0 / 60.0)
	assert_eq(fx.fx_count(), 0, "they fade")


func test_combo_card_shows_both_icons_in_a_special_frame() -> void:
	var card := ComboCard.new()
	add_child_autofree(card)
	card.show_combo(
		&"blood_harvest", &"vampiric_core", &"executioner", "Blood Harvest", "Kills burst.", "Combo"
	)
	assert_true(card.is_showing())
	assert_eq(card.title_text(), "Blood Harvest")
	assert_eq(card.caption_text(), "Combo")
	assert_eq(card.pair_ids(), [&"vampiric_core", &"executioner"])
	assert_false(card.icon.visible, "the pair replaces the single icon")
	# v0.6.1 R1 (on purpose): the plaque nearest the combo's own colour replaces the thin outline
	assert_eq(card.plaque_box().plaque, Plaques.nearest(ItemLooks.combo_color(&"blood_harvest")))
	assert_true(card.text_fits(), "its text fits the plaque")
	await wait_process_frames(2)
	assert_eq(
		card.pair.drawn,
		ItemIcons.shapes(&"vampiric_core").size() + ItemIcons.shapes(&"executioner").size()
	)


func test_hud_shows_the_combo_ticker_line_and_a_badge_when_a_combo_unlocks() -> void:
	var repo := SharedContent.repo()
	var player := PlayerTable.starting_values()
	var w := FloorScenario.build(
		4,
		player,
		ContentCompiler.compile_enemies(repo),
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo)
	)
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	var reader := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(reader)
	assert_eq(hud.combo_badge_count(), 0)
	assert_true(hud.notices.is_empty())
	for id: StringName in [&"thorn_mantle", &"phase_strike"]:
		for k in w.item_tables.size():
			if w.item_tables[k].id == id:
				w.add_item(k)
	hud.sync(reader)
	await wait_process_frames(1)
	assert_eq(
		hud.notices.texts(), PackedStringArray([tr("ITEM_COMBO_SPIKED_PHASE")]), "a ticker line"
	)
	assert_eq(hud.combo_badge_count(), 1)
	assert_eq(hud.item_icon_count(), 2)
	hud.notices.advance(NoticeTicker.HOLD + NoticeTicker.FADE_OUT + 0.1)
	assert_true(hud.notices.is_empty(), "it goes after its time")
	assert_eq(hud.combo_badge_count(), 1, "the badge stays")


## Audit P-14: a rebuilt icon row holds only the new icons in the same frame (the old ones leave the row before they
## are freed, so they are never laid out or drawn beside their replacements). (The boss bar's phase marks went in
## v0.8.0 N4: one full bar per phase, WorldReader.boss_phase_permille.)
func test_rebuilt_rows_drop_the_old_children_at_once() -> void:
	var repo := SharedContent.repo()
	var w := FloorScenario.build(
		4,
		PlayerTable.starting_values(),
		ContentCompiler.compile_enemies(repo),
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo)
	)
	var reader := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	w.add_item(AttackScenario.item_index(w.item_tables, &"momentum"))  # v0.10.5 O1: indices 0 and 1 are tombstones
	hud.sync(reader)
	w.add_item(AttackScenario.item_index(w.item_tables, &"swift_feet"))
	hud.sync(reader)  # same frame: no process frame between the rebuilds
	assert_eq(hud.item_icon_count(), 2)
	for c in hud._items.get_children():
		assert_false(c.is_queued_for_deletion(), "no freed icon left in the row")


## v0.9.5 EE1: the stack count shows (v0.10.0 FX: as an icon and "xN", not a dot a stack), a Contagion jump draws
## an arc, the Exsanguinate burst a red ring and a deep red number.
func test_element_level_visuals() -> void:
	var w := _world()
	var s := _views(w)
	var fx: StatusVisuals = s[2]
	var a := w.actors
	var id := a.ids[1]
	a.poison_stacks[1] = 3
	a.bleed_stacks[1] = 4
	fx.sync(s[0])
	assert_eq(fx.badge(id, &"poison"), 3, "poison x3")
	assert_eq(fx.badge(id, &"bleed"), 4, "bleed x4")
	a.poison_stacks[1] = 0
	a.bleed_stacks[1] = 9
	fx.sync(s[0])
	assert_eq(fx.badge(id, &"poison"), 0, "gone with its stacks")
	assert_eq(fx.badge(id, &"bleed"), 9, "the count follows, past the old 5 dots")
	var before := fx.fx_count()
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, a.ids[0], a.ids[2], a.pos(2))
	e.effect_id = SimEvent.EFFECT_VENOM_JUMP
	fx.sync(s[0])
	assert_eq(fx.fx_count(), before + 4, "a jump draws its arc (4 segments)")
	var d := w.emit_event(SimEvent.Kind.DAMAGE, a.ids[0], a.ids[0], id, a.pos(1))
	d.effect_id = SimEvent.EFFECT_EXSANGUINATE
	d.amount = 40
	d.tags = SimEvent.TAG_DOT
	fx.sync(s[0])
	assert_eq(fx.fx_count(), before + 5, "the burst adds its ring")
	var nums := DamageNumbers.new()
	add_child_autofree(nums)
	nums.sync(s[0])
	assert_eq(nums.showing(), 1, "the burst's number shows although it is a DoT")
	var label: Label3D = null
	for c in nums.get_children():
		if c is Label3D and (c as Label3D).visible:
			label = c
	assert_eq(label.modulate, DamageNumbers.EXSANGUINATE_COLOR, "in deep red")


## v0.9.5 EE2: a burning enemy at Fire Lv 3 (Heat sync) and a frozen one at Frost Lv 3 (Shatter) carry a "+" by the bar;
## an Overcharge strike, a Shatter and its shard draw their bolt, rings and streak.
func test_fire_storm_frost_level_visuals() -> void:
	var w := _world()
	var s := _views(w)
	var fx: StatusVisuals = s[2]
	var a := w.actors
	var fire := AttackScenario.item_index(w.item_tables, &"ember_core")
	var frost := AttackScenario.item_index(w.item_tables, &"frost_core")
	a.burn_stacks[1] = 2
	a.frozen_t[2] = 100
	CardLevels.set_level(w, fire, 2)
	CardLevels.set_level(w, frost, 2)
	fx.sync(s[0])
	assert_eq(fx.shown(a.ids[1], &"dots_plus_fire"), 0, "no + at Lv 2")
	assert_eq(fx.shown(a.ids[2], &"dots_plus_frost"), 0)
	CardLevels.set_level(w, fire, 3)
	CardLevels.set_level(w, frost, 3)
	fx.sync(s[0])
	assert_eq(fx.shown(a.ids[1], &"dots_plus_fire"), 1, "a + on the burning enemy at Lv 3")
	assert_eq(fx.shown(a.ids[2], &"dots_plus_frost"), 1, "and on the frozen one")
	a.burn_stacks[1] = 0
	fx.sync(s[0])
	assert_eq(fx.shown(a.ids[1], &"dots_plus_fire"), 0, "it goes with the burn")
	var before := fx.fx_count()
	var strike := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[1], a.pos(1))
	strike.effect_id = SimEvent.EFFECT_STORM_STRIKE
	strike.amount = 1500
	fx.sync(s[0])
	assert_gt(fx.fx_count(), before, "a strike draws its bolt and ring")
	before = fx.fx_count()
	var shatter := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[2], a.pos(2))
	shatter.effect_id = SimEvent.EFFECT_FROST_SHATTER
	var shard := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[2], a.ids[0], a.ids[1], a.pos(1))
	shard.effect_id = SimEvent.EFFECT_FROST_SHARD
	fx.sync(s[0])
	assert_gt(fx.fx_count(), before + 1, "a shatter's ring and its shard's streak")
