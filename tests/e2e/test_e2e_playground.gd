extends GutTest
## v0.7.5 PG (owner N19, docs/tools/PLAYGROUND.md): the Playground from the real main menu, by input only: the row,
## the weapon pick, the room; F1's panel holds the sim; a click places an endless dummy, a right click deletes; the
## basic attack on the dummy fills the DPS meter; a biome button redraws the room with its ice and keeps the dummy;
## the Boss tool places a boss; Add puts a card in the build at the level set; Esc shuts the panel, not the game.

var _e: E2e
var _scale := Vector2.ONE


func after_each() -> void:
	for a in [&"primary", &"shoot"]:
		Input.action_release(a)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## Where sim point `p` is on screen (a read of the camera).
func _screen(main: Main, p: Vector2) -> Vector2:
	return main.view.rig.camera.unproject_position(SimPlane.to_3d(p, SimPlane.CORE_HEIGHT))


func _press(main: Main, n: String) -> void:
	var b := main.playground.panel.find_child(n, true, false) as Button
	assert_not_null(b, n)
	b.grab_focus()  # GUT's output window lies over part of the screen in a test run and would take a click
	await _e.tap(KEY_ENTER)
	await _e.frames(2)


func _right_click(pos: Vector2) -> void:
	await _e.mouse_to(pos)
	for pressed in [true, false]:
		_mouse(pos, MOUSE_BUTTON_RIGHT, pressed)
		await _e.frames(1)


## A mouse button at `pos` (viewport coordinates, scaled like E2e.click_at): the aim stays where the mouse is.
func _mouse(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos / _scale
	ev.global_position = pos / _scale
	_e.send(ev)


func _tab(main: Main, i: int) -> void:
	var tabs := main.playground.panel.tabs
	var bar := tabs.get_tab_bar()
	await _e.click_at(bar.get_global_rect().position + bar.get_tab_rect(i).get_center())
	await _e.frames(2)
	assert_eq(tabs.current_tab, i, "tab %d" % i)


func test_the_playground_from_the_menu() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	_scale = await _e._mouse_scale()
	for k in 4:  # Play -> Options -> Credits -> Codex -> Playground
		await _e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Playground", "the Playground row is under the Codex")
	await _e.tap(KEY_ENTER)
	await _e.frames(2)
	await _e.tap(KEY_RIGHT)  # the Gun: its bolts reach the dummy from where the player stands
	await _e.tap(KEY_ENTER)
	await _e.frames(4)
	assert_not_null(main.playground, "in the Playground")
	var w := _e.world()
	assert_eq(w.floor_layout.room_count(), 1, "one room")
	assert_eq(w.floor_layout.room_cells[0].size, Vector2i(4, 4))
	assert_null(main.run, "not a run: nothing is saved or recorded")
	assert_null(main.view.gate, "no gate is drawn: the room has none")
	assert_not_null(main.get_node_or_null("UI/DpsMeter"), "the DPS meter")

	# F1: the panel, and the sim waits.
	await _e.tap(KEY_F1)
	assert_true(main.playground.is_panel_open(), "F1 opens the panel")
	assert_true(main.driver.paused)
	var tick := w.tick
	var spot := w.player_pos() + Vector2(2.5, -2.5)
	await _e.click_at(_screen(main, spot))
	await _e.frames(2)
	assert_eq(w.tick, tick, "still paused")
	assert_eq(w.actors.size(), 2, "a click on the floor places a dummy")
	assert_eq(w.actors.kinds[1], ActorStore.Kind.DUMMY)
	assert_lt(w.actors.pos(1).distance_to(spot), 1.0, "where the click was")
	var extra := w.player_pos() + Vector2(-4, 4)
	await _e.click_at(_screen(main, extra))
	await _e.frames(2)
	assert_eq(w.actors.size(), 3)
	await _right_click(_screen(main, extra))
	await _e.frames(2)
	assert_eq(w.actors.size(), 2, "a right click deletes")

	# Close it and hit the dummy: the meter counts, the dummy never dies.
	await _e.tap(KEY_F1)
	assert_false(main.driver.paused, "F1 again: the game runs")
	var aim := _screen(main, w.actors.pos(1))
	await _e.mouse_to(aim)
	_mouse(aim, MOUSE_BUTTON_RIGHT, true)  # the Gun shoots while the right button is held
	await _e.frames(30)
	await _e.frames(237)
	_mouse(aim, MOUSE_BUTTON_RIGHT, false)
	await _e.frames(2)
	var meter := main.playground.meter
	assert_gt(meter.tally.total, 0, "the basic attack counted")
	assert_true(meter.tally.by_source.has(DpsTally.BASIC))
	assert_gt(meter.tally.dps_recent(w.tick), 0.0)
	assert_eq(w.actors.size(), 2, "the endless dummy is still there")
	assert_eq(w.actors.hp[1], w.actors.max_hp[1], "and whole again before each tick")

	# Biome: the room is redrawn in Frozen Shore with its ice; the dummy stays.
	await _e.tap(KEY_F1)
	await _tab(main, 2)
	await _press(main, "Biome_frozen_shore")
	assert_eq(main.view.stage.prop_style, &"frozen_shore", "redrawn")
	assert_not_null(w.ice, "with ice")
	assert_eq(w.actors.size(), 2, "the dummy stays")

	# Spawn: the Boss tool places a boss where the click was.
	await _tab(main, 1)
	await _press(main, "ToolBoss")
	var boss_at := w.player_pos() + Vector2(-6, -6)
	await _e.click_at(_screen(main, boss_at))
	await _e.frames(2)
	assert_true(w.boss_alive(), "a boss")
	await _press(main, "ClearEnemies")
	assert_false(w.boss_alive(), "cleared")
	assert_eq(w.actors.size(), 2, "the dummy stays")

	# Build: a card at level 3.
	await _tab(main, 0)
	var panel := main.playground.panel
	var level_edit := panel.level.get_line_edit()
	level_edit.grab_focus()
	await _e.frames(2)
	level_edit.select_all()
	await _type("3")
	await _e.tap(KEY_ENTER)
	var cat := panel.catalog
	var first := cat.get_root().get_first_child().get_first_child()  # the first wand card
	var code := int(first.get_metadata(0))
	cat.scroll_to_item(first)
	await _e.frames(2)
	await _e.click_at(cat.get_global_rect().position + cat.get_item_area_rect(first).get_center())
	await _e.frames(2)
	await _press(main, "Add")
	assert_true(w.items_owned.has(code), "the card is in the build")
	assert_eq(CardLevels.level(w, code), 3, "at the level set")
	assert_gt(panel.held.get_root().get_child_count(), 0, "listed in your build")

	# Esc closes the panel, not the game.
	await _e.tap(KEY_ESCAPE)
	assert_false(main.playground.is_panel_open())
	assert_false(main.driver.paused)
	await _e.tap(KEY_ESCAPE)
	assert_true(main.driver.paused, "then Esc pauses as in a run")


func _type(text: String) -> void:
	for ch in text:
		for pressed in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = OS.find_keycode_from_string(ch)
			ev.physical_keycode = ev.keycode
			ev.unicode = ch.unicode_at(0)
			ev.pressed = pressed
			_e.send(ev)
		await _e.frames(1)
