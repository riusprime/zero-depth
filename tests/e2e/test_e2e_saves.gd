extends GutTest
## v0.4.0 SV (PLAN "Saves (SV)", ROADMAP R3) through main.tscn with real input only: no Continue on a fresh start;
## the left stick walks into a neighbouring room (a first entry saves), on into the room, then Esc -> Main menu; the
## menu now offers Continue (focused), and Enter lands back at that room's entry: the same tick and the same state
## hash as right after the entry tick, the room known on the minimap. A death deletes the save.

const LEG_FRAMES := 3000


func after_each() -> void:
	Input.action_release(&"pause")
	Input.action_release(&"ui_accept")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _continue_button(main: Main) -> Node:
	var menu := main.get_node_or_null("UI/MainMenu")
	return menu.find_child("Continue", true, false) if menu != null else null


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## Walks the stick along a flow field toward `target` until `done` (or the frame limit).
func _walk(e: E2e, target: Vector2, done: Callable) -> bool:
	var w := e.world()
	var nav := NavField.new()
	nav.build(w.walls)
	nav.flood(target)
	for k in LEG_FRAMES:
		if done.call() or w.player_dead():
			break
		var p := w.player_pos()
		var dir := nav.direction(p)
		if (target - p).length() < 1.5 or dir == Vector2.ZERO:
			dir = (target - p).normalized()
		e.stick_toward(dir)
		await e.frames(1)
	e.stick_toward(Vector2.ZERO)
	return done.call()


func _to_main_menu(e: E2e) -> void:
	await e.tap(KEY_ESCAPE)
	for k in 3:  # Resume -> Restart run -> Options -> Main menu
		await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)


func test_quit_mid_room_and_continue_at_its_entry() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	assert_not_null(main.get_node_or_null("UI/MainMenu"))
	assert_null(_continue_button(main), "no Continue without a save")
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	assert_eq(main.saves.entries, 1, "the start hall saved as the floor began")
	# Record the hash right after the tick that saves (Main's handler runs first: it connected first).
	var at_entry := {}
	var start_entries := main.saves.entries
	main.driver.ticked.connect(
		func() -> void:
			if main.saves.entries > start_entries and at_entry.is_empty():
				at_entry["tick"] = w.tick
				at_entry["hash"] = w.state_hash()
	)
	var room := f.neighbours(f.start_room)[0]
	var centre := f.rooms[room].get_center()
	var entered: bool = await _walk(e, centre, func() -> bool: return not at_entry.is_empty())
	assert_true(entered, "walked into room %d" % room)
	if not entered:
		return
	assert_eq(main.saves.rooms[room], 1, "the room counts as entered")
	assert_eq(
		int(main.saves.last["tick"]), int(at_entry["tick"]), "saved right after the entry tick"
	)
	# On into the room: the state moves past the entry before quitting.
	await _walk(e, centre, func() -> bool: return w.player_pos().distance_to(centre) < 1.5)
	await e.frames(20)
	assert_gt(w.tick, int(at_entry["tick"]) + 10, "quitting mid-room, past the entry")
	assert_ne(w.state_hash(), at_entry["hash"])
	await _to_main_menu(e)
	assert_false(main.is_playing(), "Main menu ends the stage")
	assert_not_null(_continue_button(main), "the menu has Continue")
	assert_not_null(main.get_node_or_null("UI/MainMenu"))
	assert_eq(
		_focused(main).name, &"Continue", "Continue shows, focused first, while a save exists"
	)
	assert_eq(tr("UI_CONTINUE"), "CONTINUE")
	# Enter on Continue: read the resumed world before its first tick.
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	assert_true(main.is_playing(), "Continue starts the saved run")
	var r := e.world()
	assert_ne(r, w, "a new world")
	assert_eq(r.tick, int(at_entry["tick"]), "back at the room's entry tick")
	assert_eq(r.state_hash(), at_entry["hash"], "with the same state hash")
	assert_eq(main.run.floor_index, 1)
	await e.frames(3)
	assert_gt(r.tick, int(at_entry["tick"]), "and the run goes on")
	var hud: Hud = main.get_node("UI/Hud")
	assert_true(hud.minimap.state.is_discovered(room), "the minimap knows the room")
	assert_true(hud.minimap.state.is_discovered(f.start_room), "and the start hall")


func test_a_death_deletes_the_save() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_true(main.saves.store.has_save(), "a run in progress has a save")
	var panel: EndPanel = null
	for k in 4000:
		await e.frames(1)
		panel = main.get_node_or_null("UI/EndPanel")
		if panel != null:
			break
	assert_not_null(panel, "standing still, you die")
	assert_false(main.saves.store.has_save(), "the death deleted the save")
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/MainMenu"))
	assert_null(_continue_button(main), "no Continue after a death")
