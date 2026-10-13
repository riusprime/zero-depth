extends GutTest
## v0.6.5 WN2 (docs/design/WAND.md rule 4: "Moving cards between slots is free and immediate … Keyboard, mouse and pad
## all work") through main.tscn and real input only (Input.parse_input_event):
## - the dev panel (real clicks) fills floor 1's four wand slots; Esc pauses, ↓ Enter opens the Build page; a card
##   moves with the keyboard (Enter, →, →, Enter), the mouse (a drag, then a click-click) and the pad (d-pad, A, d-pad,
##   A); the read-back follows each move while the sim stays paused (no tick, the wand unchanged); B goes back, Esc
##   resumes, and the sim's wand order is the page's: the moves arrived as input on the first ticks.
## - the run is replayed from a snapshot taken before the pause with the frames the driver stepped: the same order
##   and the same state hash (the moves are input, EI-04).
## - a run continued on floor 3 (a save on disk: 8 slots full) opens the Swap at 8 slots: it fits the screen, and an
##   insert with the pad (X, d-pad, A, then the card that leaves, A) gives the order the panel previewed.

const FOUR: Array = [&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field"]
## v0.6.5 WN5b: Blade wand cards only (a save holding retired v0.6 cards migrates when it is continued).
const EIGHT: Array = [
	&"heavy",
	&"trigger_on_hit",
	&"whirl",
	&"flurry",
	&"trigger_on_kill",
	&"thrust",
	&"wide_arc",
	&"echo_slash",
]


func after_each() -> void:
	Input.action_release(&"pause")
	Input.action_release(&"ui_accept")


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _pad(e: E2e, button: JoyButton) -> void:
	await e.joy_button(button, true)
	await e.joy_button(button, false)


## A left-button drag from `a` to `b` (viewport coordinates), scaled like E2e.click_at.
func _drag(e: E2e, a: Vector2, b: Vector2) -> void:
	var scale := await e._mouse_scale()
	await e.mouse_to(a)
	_button(e, a / scale, true)
	await e.frames(1)
	await e.mouse_to(a.lerp(b, 0.5))
	await e.mouse_to(b)
	_button(e, b / scale, false)
	await e.frames(1)


func _button(e: E2e, at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	e.send(ev)


func _centre(page: BuildPage, k: int) -> Vector2:
	return page.row.tile(k).get_global_rect().get_center()


static func _moved(order: PackedInt32Array, from: int, to: int) -> PackedInt32Array:
	var out := order.duplicate()
	var c := out[from]
	out.remove_at(from)
	out.insert(to, c)
	return out


## Boots a Blade run and fills floor 1's four slots with the dev panel's real clicks; the panel closes again.
func _four(e: E2e) -> Main:
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	for id: StringName in FOUR:
		var guard := 0
		while w.ability_tables[main.driver.debug.ability_choice].id != id and guard < 20:
			await _click(e, main, "NextAbility")
			guard += 1
		await _click(e, main, "GrantAbility")
		await e.frames(2)
	await e.tap(KEY_QUOTELEFT)  # the dev panel closes (and with it the debug hooks: the frames alone drive the sim)
	await e.frames(2)
	assert_eq(w.mod_slots.size(), 4, "four ability modifiers fill floor 1's wand")
	return main


func test_the_build_page_moves_cards_with_keyboard_mouse_and_pad_and_the_sim_gets_them() -> void:
	var e := E2e.new(self)
	var main := await _four(e)
	var w := e.world()
	var start := w.mod_slots.duplicate()
	# The replay's start: the world now, and every frame the driver steps from here on.
	var snap := WorldSnapshot.take(w)
	var frames: Array[InputFrame] = []
	var rec := func() -> void: frames.append(main.driver.last_frame)
	main.driver.ticked.connect(rec)
	await e.tap(KEY_ESCAPE)
	assert_not_null(main.get_node_or_null("UI/PauseMenu"), "Esc pauses")
	await e.tap(KEY_DOWN)
	assert_eq(main.get_viewport().gui_get_focus_owner().name, &"Build", "Build is under Resume")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var page := main.get_node_or_null("UI/BuildPage") as BuildPage
	assert_not_null(page, "Enter on Build opens the Build page")
	if page == null:
		return
	assert_false(
		(main.get_node("UI/PauseMenu") as Control).visible, "the pause menu hides under it"
	)
	var tick := w.tick
	var first := page.read_back_text()
	assert_true(first.begins_with("You fire a slash"), "the read-back: '%s'" % first)
	assert_eq(page.row.slot_count(), 4, "floor 1's four slots")
	var want := start.duplicate()
	# Keyboard: Enter picks up slot 1, → → carries it to slot 3, Enter puts it down.
	await e.tap(KEY_ENTER)
	assert_eq(page.held_index(), 0, "Enter picked the card up")
	await e.tap(KEY_RIGHT)
	await e.tap(KEY_RIGHT)
	await e.tap(KEY_ENTER)
	want = _moved(want, 0, 2)
	assert_eq(page.order(), want, "the keyboard moved slot 1 to slot 3")
	assert_eq(page.held_index(), -1)
	assert_ne(page.read_back_text(), first, "the read-back follows the move")
	# Mouse: a drag from slot 4 onto slot 1.
	await _drag(e, _centre(page, 3), _centre(page, 0))
	want = _moved(want, 3, 0)
	assert_eq(page.order(), want, "the drag moved slot 4 to slot 1")
	# Mouse: click slot 2, then click slot 3.
	await e.click_at(_centre(page, 1))
	assert_eq(page.held_index(), 1, "the first click picked it up")
	await e.click_at(_centre(page, 2))
	want = _moved(want, 1, 2)
	assert_eq(page.order(), want, "click-click moved slot 2 to slot 3")
	# Pad: d-pad to slot 1, A picks up, d-pad right carries, A drops.
	for k in 4:
		await _pad(e, JOY_BUTTON_DPAD_LEFT)
	assert_eq(page.focus_index(), 0)
	await _pad(e, JOY_BUTTON_A)
	await _pad(e, JOY_BUTTON_DPAD_RIGHT)
	await _pad(e, JOY_BUTTON_A)
	want = _moved(want, 0, 1)
	assert_eq(page.order(), want, "the pad moved slot 1 to slot 2")
	var preview := page.read_back_text()
	await e.frames(10)
	assert_eq(w.tick, tick, "the sim stays paused on the Build page")
	assert_eq(w.mod_slots, start, "and its wand waits for the moves as input")
	# B back to the pause menu, Esc resumes; the moves reach the sim on the first ticks.
	await _pad(e, JOY_BUTTON_B)
	await e.frames(1)
	assert_null(main.get_node_or_null("UI/BuildPage"), "B closed the Build page")
	assert_true((main.get_node("UI/PauseMenu") as Control).visible, "the pause menu is back")
	assert_eq(w.mod_slots, start, "still paused")
	await e.tap(KEY_ESCAPE)
	assert_null(main.get_node_or_null("UI/PauseMenu"), "Esc resumed")
	await e.frames(12)
	assert_gt(w.tick, tick, "the sim runs again")
	assert_eq(w.mod_slots, want, "the sim's wand is in the page's order")
	var r := WorldReader.new(w)
	var words := WorldReader.wand_render(
		r.wand_read_back(), func(k: StringName) -> String: return tr(k)
	)
	assert_eq(words, preview, "the sim's read-back is the page's preview")
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(hud.build_hud.filled_pips(), 4)
	# Replay: the snapshot plus the recorded frames give the same wand and the same state hash.
	main.driver.ticked.disconnect(rec)
	var live_hash := w.state_hash()
	var moves := 0
	for f in frames:
		if f.pick >= WorldReader.PICK_WAND_MOVE_BASE:
			moves += 1
	assert_true(moves >= 1 and moves <= 3, "the change arrived as %d wand moves" % moves)
	var base := SaveLab.floor_world(main.run.run_seed, 1, &"blade")
	assert_eq(WorldSnapshot.apply(base, snap), "", "the snapshot applies")
	for f in frames:
		base.step(f)
	assert_eq(base.mod_slots, want, "the replay reorders the same way")
	assert_eq(base.tick, w.tick)
	assert_eq(base.state_hash(), live_hash, "the replay is exact")


func test_the_build_page_opened_twice_in_one_pause_keeps_the_first_change() -> void:
	var e := E2e.new(self)
	var main := await _four(e)
	var w := e.world()
	var start := w.mod_slots.duplicate()
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	for key: Key in [KEY_ENTER, KEY_RIGHT, KEY_ENTER, KEY_ESCAPE]:  # slot 1 → 2, then Esc back
		await e.tap(key)
	await e.frames(1)
	assert_null(main.get_node_or_null("UI/BuildPage"), "Esc with nothing held goes back")
	assert_not_null(main.get_node_or_null("UI/PauseMenu"), "to the pause menu, still paused")
	await e.tap(KEY_ENTER)  # Build is focused again
	await e.frames(2)
	var page := main.get_node_or_null("UI/BuildPage") as BuildPage
	assert_not_null(page)
	if page == null:
		return
	var once := _moved(start, 0, 1)
	assert_eq(page.order(), once, "the page opens on the change not yet delivered")
	await e.tap(KEY_3)
	for key: Key in [KEY_ENTER, KEY_LEFT, KEY_LEFT, KEY_ENTER]:  # slot 3 → 1
		await e.tap(key)
	var twice := _moved(once, 2, 0)
	assert_eq(page.order(), twice)
	# Back out with the mouse, then resume with the pad's Start.
	await e.click_at(page.back_button().get_global_rect().get_center())
	await e.frames(1)
	assert_null(main.get_node_or_null("UI/BuildPage"), "the Back button closes it")
	await _pad(e, JOY_BUTTON_START)
	await e.frames(12)
	assert_null(main.get_node_or_null("UI/PauseMenu"))
	assert_eq(w.mod_slots, twice, "both changes reached the sim, in order")


## Boots main.tscn with a run saved on floor 3 (eight wand slots, all full), and continues it from the menu.
func _floor_three(e: E2e) -> Main:
	var run := SaveLab.run_state(777, 3, &"blade")
	var w := SaveLab.build_floor(run)
	for id: StringName in EIGHT:
		assert_true(BuildSlots.take(w, WandLab.code(w, id)), "takes %s" % id)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(w, run, 777, PackedByteArray())))
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(store)
	var main: Main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	e.main = main
	add_child_autofree(main)
	await e.frames(2)
	assert_eq(
		main.get_viewport().gui_get_focus_owner().name, &"Continue", "the save offers Continue"
	)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	return main


func test_the_swap_at_eight_slots_fits_the_screen_and_inserts_with_the_pad() -> void:
	var e := E2e.new(self)
	var main := await _floor_three(e)
	assert_true(main.is_playing(), "the floor 3 run continues")
	if not main.is_playing():
		return
	var w := e.world()
	assert_eq(main.run.floor_index, 3)
	assert_eq(w.mod_slots.size(), 8, "eight cards in eight slots")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _click(e, main, "GrantMod")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	assert_true(hud.swap.is_open(), "a ninth card: the Swap panel")
	assert_eq(hud.swap.slot_count(), 8)
	var screen := main.get_viewport().get_visible_rect()
	var rect := hud.swap.content_rect()
	gut.p("swap at 8 slots: %s on %s" % [rect, screen])
	assert_true(screen.encloses(rect), "the Swap at 8 slots fits the screen")
	assert_true(rect.size.x <= 1920.0 and rect.size.y <= 1080.0, "inside the 1920 x 1080 base")
	assert_eq(Array(hud.build_hud.cut_slots()), [1, 4], "the HUD's pips show the two cuts")
	var before := w.mod_slots.duplicate()
	var code := w.swap_code
	# Insert: X puts the new card in the row at the focus (slot 1); d-pad right twice: before slot 3; A fixes it.
	await _pad(e, JOY_BUTTON_X)
	assert_eq(hud.swap.mode(), SwapPanel.Mode.PLACE)
	await _pad(e, JOY_BUTTON_DPAD_RIGHT)
	await _pad(e, JOY_BUTTON_DPAD_RIGHT)
	await _pad(e, JOY_BUTTON_A)
	assert_eq(hud.swap.mode(), SwapPanel.Mode.LEAVE)
	assert_eq(hud.swap.row.slot_count(), 9, "the new card stands in the row: nine tiles")
	rect = hud.swap.content_rect()
	assert_true(screen.encloses(rect), "nine tiles still fit: %s" % rect)
	# The card that leaves: d-pad right to the row's last tile (slot 8's card), A.
	for k in 8:
		await _pad(e, JOY_BUTTON_DPAD_RIGHT)
	var forecast := hud.swap.read_back_text()
	await _pad(e, JOY_BUTTON_A)
	await e.frames(6)
	assert_false(hud.swap.is_open(), "answered")
	var want := before.duplicate()
	want.remove_at(7)
	want.insert(2, code)
	assert_eq(w.mod_slots, want, "the new card sits in slot 3; the last card left")
	var words := WorldReader.wand_render(
		WorldReader.new(w).wand_read_back(), func(k: StringName) -> String: return tr(k)
	)
	assert_eq(words, forecast, "the panel's read-back forecast the outcome")
