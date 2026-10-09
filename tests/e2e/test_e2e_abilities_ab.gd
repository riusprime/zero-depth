extends GutTest
## v0.4.0 AB through the real game (main.tscn, input only: keys, the stick and mouse clicks on the dev panel):
## - the dev panel grants Bomb Lobber and Arc Field to level 3: the pair evolves into Storm Bombs, its combo card
##   shows with both abilities, its badge joins the HUD row, and in play its blasts chain lightning;
## - the dev route puts the hero by the Overrun door, the stick walks through the red frame: the banner shows, the
##   room's enemies arrive as Overrun enemies.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## Clicks NextAbility until the panel's choice is `id`, then GrantAbility `times` times.
func _grant(e: E2e, main: Main, id: StringName, times: int) -> void:
	var w := e.world()
	for k in w.ability_tables.size():
		if w.ability_tables[main.driver.debug.ability_choice].id == id:
			break
		await _click(e, main, "NextAbility")
	assert_eq(w.ability_tables[main.driver.debug.ability_choice].id, id)
	for k in times:
		await _click(e, main, "GrantAbility")
		await e.frames(1)


func test_dev_panel_grants_a_pair_and_storm_bombs_evolve() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"bomb_lobber", 3)
	await _grant(e, main, &"arc_field", 2)
	assert_false(Engines.has_combo(w, ComboTable.Effect.STORM_BOMBS), "L3 + L2: not yet")
	await _grant(e, main, &"arc_field", 1)
	await e.frames(3)
	assert_true(Engines.has_combo(w, ComboTable.Effect.STORM_BOMBS), "both at L3: evolved")
	assert_true(hud.combo_card().is_showing(), "the combo card shows")
	assert_eq(hud.combo_card().pair_ids(), [&"bomb_lobber", &"arc_field"], "with both abilities")
	assert_gte(hud.combo_badge_count(), 1, "and its badge")
	for k in 2:
		await _click(e, main, "SpawnEnemy")
		await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	var seq := w.last_event_seq()
	var storm := false
	var drawn := false
	for k in 1800:
		await e.frames(1)
		if k % 15 == 0:  # v0.6.0 MX2: Bomb Lobber lobs on every 4th attack (left mouse swings)
			await e.mouse_button(MOUSE_BUTTON_LEFT, true)
			await e.mouse_button(MOUSE_BUTTON_LEFT, false)
		for ev in w.events_since(seq):
			storm = storm or (ev.kind == SimEvent.Kind.DAMAGE and ev.effect_id == &"storm_bombs")
		seq = w.last_event_seq()
		drawn = drawn or main.view.element_fx.fx_count_of(&"storm") > 0
		if storm and drawn:
			break
	assert_true(storm, "a blast chained lightning (Storm Bombs)")
	assert_true(drawn, "and the chain was drawn")


func test_walk_through_the_red_door_into_an_overrun() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var o := main.driver.reader.overrun()
	assert_true(o["active"], "this floor has an Overrun room")
	assert_gte(main.view.overrun_doors.frame_count(), 1, "its doorway is framed")
	assert_true(main.view.overrun_doors.is_lit(), "in red")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _click(e, main, "GoOverrun")  # the dev route: by the door, outside the room
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	assert_ne(w.floor_layout.room_of(w.player_pos()), w.floor_layout.overrun_room, "outside it")
	assert_false(hud.overrun_hud.visible)
	assert_true(await e.walk_to(Overrun.reward_spot(w.floor_layout), 1.0), "walked in")
	assert_true(main.driver.reader.overrun()["inside"], "inside the Overrun")
	assert_true(hud.overrun_hud.visible, "the banner shows")
	assert_eq(hud.overrun_hud.title.text, tr("HUD_OVERRUN"))
	var boosted := false
	for k in 1200:
		await e.frames(1)
		if not w.overrun.boosted.is_empty():
			boosted = true
			break
	assert_true(boosted, "an enemy arrived as an Overrun enemy")
	if boosted:
		var i := w.actors.index_of(w.overrun.boosted[0])
		var base := w.enemy_table(w.actors.kinds[i]).hp
		# v0.4.0 TU: on top of the curve's HP (the calm minute eases it below the table's).
		assert_gt(w.actors.max_hp[i], w.spawner.hp_now(base, w.run_ticks), "with more HP")
