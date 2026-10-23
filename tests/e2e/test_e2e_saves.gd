extends GutTest
## v0.4.0 SV (PLAN "Saves (SV)", ROADMAP R3) through main.tscn with real input only: no Continue on a fresh start;
## the left stick walks into a neighbouring room (a first entry saves), on into the room, then Esc -> to the hub
## (v0.9.0 HB, owner 2026-10-23) -> the hub's pause -> Main menu; the menu now offers Continue (focused), and Enter
## lands back at that room's entry: the same tick and the same state hash as right after the entry tick, the room known
## on the minimap. A death deletes the save.

const LEG_FRAMES := 3000


func after_each() -> void:
	Input.action_release(&"pause")
	Input.action_release(&"ui_accept")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


## The main menu's Continue while it is offered (v0.9.0 HB: without a save it is greyed out), else null.
func _continue_button(main: Main) -> Node:
	var menu := main.get_node_or_null("UI/MainMenu")
	var b := menu.find_child("Continue", true, false) as Button if menu != null else null
	return b if b != null and not b.disabled else null


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## Walks the stick along a flow field toward `target` until `done` (or the frame limit).
func _walk(e: E2e, target: Vector2, done: Callable) -> bool:
	var w := e.world()
	var nav := NavField.new()
	nav.build(E2e.walk_walls(w, target))
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


## v0.9.0 HB (owner 2026-10-23): the pause menu leaves to the hub, then the hub's pause to the main menu.
func _to_main_menu(e: E2e) -> void:
	assert_true(await HubWalk.new(e).from_run(), "the pause menu leaves to the hub")
	assert_true(await HubWalk.new(e).to_main_menu(), "the hub's pause -> Main menu")


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
	# An open spot in the room (v0.5.9 L8: a themed room's centre can hold a vignette, e.g. Camp's burn barrel).
	var centre := f.spawn_points[room][0]
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
	assert_eq(tr("UI_CONTINUE"), "Continue")  # v0.5.5 A5: plain sentence case
	# Enter on Continue: read the resumed world before its first tick. v0.8.0 N3 (O45): the load waits a frame or two
	# behind the loading cover; the world is read in the frame it is built (before any physics tick).
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	assert_true(main.loads.cover.is_covered(), "Continue covers the screen first")
	# v0.8.0 N12 (O70): the load runs over frames behind the cover (the World on a worker); CoverLoads.finished
	# comes in the frame the floor goes live, before its first tick.
	await main.loads.finished
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


## v0.9.0 HB (owner 2026-10-23, "To the hub (Recommended)"): the pause menu's last row, "To the Rune Ring", leaves the
## run for the hub with the run saved; the hub's pause -> Main menu -> Continue resumes the same run on the same floor.
func test_the_pause_menu_leaves_to_the_hub_and_continue_resumes() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(30)
	var seed_value := e.world().seed_value
	var floor_index := main.run.floor_index
	var saved_tick := int(main.saves.last["tick"])
	await e.tap(KEY_ESCAPE)
	for k in 5:
		await e.tap(KEY_DOWN)
	var exit := _focused(main) as Button
	assert_eq(exit.name, &"Hub", "the pause menu's last row")
	assert_eq(tr(exit.text), "To the Rune Ring")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_false(main.is_playing(), "the run is left")
	assert_not_null(main.hub, "the hero is in the hub")
	assert_null(main.get_node_or_null("UI/MainMenu"), "not the main menu")
	assert_eq(main.hub.at, &"", "at the spawn")
	assert_true(main.saves.store.has_save(), "the run stays saved")
	assert_true(await HubWalk.new(e).to_main_menu(), "the hub's pause -> Main menu")
	assert_eq(_focused(main).name, &"Continue", "Continue is offered, focused")
	e.key(KEY_ENTER, true)  # read the resumed world in the frame it is built, before its first tick (as above)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	assert_true(main.is_playing(), "Continue resumes the run directly")
	assert_null(main.hub, "not through the hub")
	assert_eq(e.world().seed_value, seed_value, "the same run")
	assert_eq(main.run.floor_index, floor_index, "on the same floor")
	assert_eq(e.world().tick, saved_tick, "at its last save")
	assert_true(await e.landed(), "the floor's arrival plays out")
	await e.frames(3)
	assert_gt(e.world().tick, saved_tick, "and the run goes on")


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
	await e.tap(KEY_ENTER)  # v0.9.0 HB: the end panel's Hub, then the hub's pause -> Main menu
	await e.frames(2)
	assert_not_null(main.hub)
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/MainMenu"))
	assert_null(_continue_button(main), "no Continue after a death")
