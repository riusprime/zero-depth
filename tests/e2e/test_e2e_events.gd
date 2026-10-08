extends GutTest
## Event rooms and cursed rewards through real input (v0.5.0 EV, PLAN R3-R4): start a run from the menu, turn on
## god mode in the dev panel (so the walk survives the floor's spawns), walk (left stick only) to the floor's event
## pedestal: its name floats over it and the prompt names it; E opens the panel (the world waits): one card per
## choice with its cost and reward, and Leave; Esc leaves it for later, E opens it again, Enter takes the first
## choice and its outcome lands. Then the dev route curses the next chest: walk to a chest, open it with the pad's
## X, the first card is marked cursed; take it with A: the curse is held, threat T shows 1 on the HUD and in the
## pause menu.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_take_an_event_choice_and_a_cursed_chest_card() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_gt(w.ev.size(), 0, "the floor has an event room")
	assert_eq(main.view.events.pedestal_count(), w.ev.size(), "its pedestal is drawn")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	assert_true(await e.walk_to(w.ev.pos(0), 0.6), "walked to the pedestal")
	await e.frames(2)
	var name := tr(Events.table(w, 0).name_key)
	gut.p("event: %s" % Events.table(w, 0).id)
	assert_eq(hud.events.prompt_text(), tr("UI_EVENT_OPEN") % name, "the prompt names it")
	assert_true(main.view.events.name_label(0).visible, "its name floats over it")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.ev.open, 0, "E opened it")
	var panel := hud.events.panel
	assert_true(panel.is_open() and panel.visible, "the panel shows")
	var n := Events.table(w, 0).choice_count()
	assert_eq(panel.card_count(), n + 1, "one card per choice and Leave")
	assert_eq(panel.card_text(n, "Title"), tr("UI_EVENT_LEAVE"))
	assert_false(panel.card_text(0, "Cost").is_empty(), "the cost is on the card")
	assert_true(CardStyle.is_plain(panel.card_box(0)), "the pick cards' look")
	var run := w.run_ticks
	await e.frames(20)
	assert_eq(w.run_ticks, run, "the world waits")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_eq(w.ev.open, -1, "Esc left it")
	assert_null(main.get_node_or_null("UI/PauseMenu"), "and didn't pause")
	assert_eq(w.ev.state[0], Events.State.READY, "still there for later")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.ev.open, 0, "open again")
	assert_true(panel.card_enabled(0), "the first choice can be taken")
	var before := w.state_hash()
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_eq(w.ev.open, -1, "Enter took it")
	assert_ne(w.ev.state[0], Events.State.READY, "the event is spent (or running)")
	assert_eq(w.ev.result_choice, 0, "the first choice")
	assert_ne(w.state_hash(), before)
	assert_false(panel.visible, "the panel closed")
	# The cursed chest: the dev route marks the next chest offer cursed.
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "CurseChest")
	await e.tap(KEY_QUOTELEFT)
	var chest := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
	assert_gte(chest, 0, "a chest on the floor")
	# TEST HELPER (labelled): grant the shards directly; earning them is test_e2e_rewards' job.
	w.shards = 500
	assert_true(await e.walk_to(w.rewards.pos(chest), 0.6), "walked to the chest")
	e.joy_button(JOY_BUTTON_X, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_X, false)
	await e.frames(3)
	assert_gte(w.choosing, 0, "the pad's X opened the chest")
	var pick := hud.pick_panel()
	var curse := Curses.offer_curse(w, w.choosing, 0)
	assert_gte(curse, 0, "its first card is cursed")
	var line := pick.slot(0).curse_text()
	gut.p("cursed card: %s" % line)
	assert_true(line.begins_with(tr(w.ev.curses[curse].name_key)), "the card names its curse")
	assert_eq(pick.slot(1).curse_text(), "", "the others are clean")
	e.joy_button(JOY_BUTTON_A, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_A, false)
	await e.frames(3)
	assert_eq(w.choosing, -1, "A took it")
	assert_eq(w.curses_owned, PackedInt32Array([curse]), "the curse is held")
	assert_true(hud.events.threat.visible, "threat shows on the HUD")
	assert_eq(hud.events.threat.title_text(), tr("UI_THREAT") % 1)
	assert_eq(hud.events.threat.row_count(), 1, "one curse listed")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	var pause := main.get_node_or_null("UI/PauseMenu")
	assert_not_null(pause, "paused")
	var tp: ThreatPanel = pause.get_node_or_null("Threat")
	assert_not_null(tp, "the pause menu shows threat")
	if tp != null:
		assert_eq(tp.row_count(), 1)
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_eq(main.run_recap()["threat"], 1, "the recap counts T")
