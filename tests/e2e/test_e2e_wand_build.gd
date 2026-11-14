extends GutTest
## v0.6.5 WN2 (docs/design/WAND.md rule 4: "Moving cards between slots is free and immediate … Keyboard, mouse and pad
## all work") through main.tscn and real input only (Input.parse_input_event):
## - the dev panel (real clicks) fills floor 1's four wand slots; Esc pauses, ↓ Enter opens the Build page; a card
##   moves with the keyboard (Enter, →, →, Enter), the mouse (a drag, then a click-click) and the pad (d-pad, A, d-pad,
##   A); the forecast (F11: the cards' icons) follows each move while the sim stays paused (no tick, the wand
##   unchanged); B goes back, Esc resumes, and the sim's wand order is the page's: the moves arrived as input on the
##   first ticks.
## - the run is replayed from a snapshot taken before the pause with the frames the driver stepped: the same order
##   and the same state hash (the moves are input, EI-04).
## - a run continued on its last floor (v0.9.0 FV: floor 5; a save on disk: 8 slots full) opens the Swap at 8
##   slots: it fits the screen, and an insert with the pad (X, d-pad, A, then the card that leaves, A) gives the
##   order the panel previewed. v0.10.5 O13: the Build page's and the Swap's wand forecast (F11: the cards' icons in
##   firing order) follows the reorder and is the wand the sim then holds. v0.8.0 N11 fix: the
##   card comes while the hero is still arriving (under the cover); the arrival still ends, then the Swap shows.
## - v0.11.0 F11: carrying a card shows the lifted card, its ghost and the landing bar on every input, and the mouse
##   still works while the tiles glide.

## v0.6.5 WN5b: Blade wand cards only (a save holding retired v0.6 cards migrates when it is continued). v0.9.0 AS
## (owner Q6): one Pattern on the Blade (Whirl), so Thrust and Wide Arc gave way to Parry Edge and Frost.
const EIGHT: Array = [
	&"heavy",
	&"chain_blast",
	&"whirl",
	&"flurry",
	&"shared_bleed",
	&"parry_edge",
	&"frost_core",
	&"echo_slash",
]


func after_each() -> void:
	Input.action_release(&"pause")
	Input.action_release(&"ui_accept")


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
	return page.row.slot_rect(k).get_center()  # v0.11.0 F11: where the slot rests, whatever its tile is doing


## The card ids of a wand read, in slot order: what the forecast's icons should be.
static func _ids(read: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Dictionary in read["cards"]:
		out.append(c["id"])
	return out


## `ids` with the card at `from` moved to `to` (the page's preview of the same move).
static func _ids_moved(ids: Array[StringName], from: int, to: int) -> Array[StringName]:
	var out := ids.duplicate()
	var c: StringName = out.pop_at(from)
	out.insert(to, c)
	return out


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
	await e.click_dev("God")
	# v0.10.5 D1: Fire + Frost (Thermal Shock) in the replay
	for id: StringName in [&"frost_core", &"blade_orbit", &"echo_slash", &"ember_core"]:
		var guard := 0
		while (
			(
				main.driver.debug.mod_choice < 0
				or w.item_tables[main.driver.debug.mod_choice].id != id
			)
			and guard < 80
		):
			await e.click_dev("NextMod")
			guard += 1
		await e.click_dev("GrantMod")
		await e.frames(2)
	await e.click_dev("God")  # off again: God outlasts the panel now, and the replay below has no debug hooks
	await e.tap(KEY_QUOTELEFT)  # the dev panel closes (and with it the debug hooks: the frames alone drive the sim)
	await e.frames(2)
	assert_eq(w.mod_slots.size(), 4, "four wand cards fill floor 1's wand")
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
	# v0.11.0 F11: the forecast is the held wand's card icons, in order
	var cast := _ids(main.driver.reader.wand())
	gut.p("forecast at open: %s" % [page.forecast_ids()])
	assert_eq(page.forecast_ids(), cast, "the forecast's icons are the held wand's cards, in order")
	assert_eq(
		page.forecast.icon_texture(0),
		AstralCardArt.icon(cast[0]),
		"the card's own icon, the one the cards draw"
	)
	assert_eq(page.row.slot_count(), 4, "floor 1's four slots")
	var want := start.duplicate()
	# Keyboard: Enter picks up slot 1, → → carries it to slot 3, Enter puts it down.
	await e.tap(KEY_ENTER)
	assert_eq(page.held_index(), 0, "Enter picked the card up")
	assert_eq(page.row.ghost_slot(), 0, "the ghost marks where it came from")
	await e.tap(KEY_RIGHT)
	await e.tap(KEY_RIGHT)
	assert_eq(page.row.marker_slot(), 2, "the marker shows where it lands: slot 3")
	assert_gt(
		page.row.marker_rect().get_center().x,
		page.row.slot_rect(2).get_center().x,
		"coming from the left it lands after slot 3's card"
	)
	assert_lt(page.row.marker_rect().get_center().x, page.row.slot_rect(3).get_center().x)
	assert_eq(page.forecast_ids(), _ids_moved(cast, 0, 2), "the forecast previews the move")
	assert_eq(page.order(), _moved(want, 0, 2), "the order is the preview")
	await e.tap(KEY_ENTER)
	want = _moved(want, 0, 2)
	assert_eq(page.order(), want, "the keyboard moved slot 1 to slot 3")
	assert_eq(page.held_index(), -1)
	assert_eq(page.row.marker_slot(), -1, "dropped: no marker")
	assert_eq(page.row.ghost_slot(), -1, "and no ghost")
	assert_eq(page.forecast_ids(), _ids_moved(cast, 0, 2), "the forecast follows the move")
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
	var preview := page.forecast_ids()
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
	assert_eq(
		_ids(WorldReader.new(w).wand()), preview, "the forecast's icons are the wand the sim holds"
	)
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


## v0.11.0 F11: a card carried with the mouse: pressed and dragged, or clicked then pointed at; the lifted card, its
## ghost and the landing bar show the target, and the drop gives the order the marker showed.
func test_carrying_a_card_shows_where_it_lands_and_the_mouse_works_while_tiles_glide() -> void:
	var e := E2e.new(self)
	var main := await _four(e)
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var page := main.get_node_or_null("UI/BuildPage") as BuildPage
	assert_not_null(page, "the Build page")
	if page == null:
		return
	var want := page.order()
	var ids := page.forecast_ids()
	# A drag: press slot 4, travel to slot 2: picked up, the ghost on slot 4, the marker before slot 2's card.
	var scale := await e._mouse_scale()
	var from := _centre(page, 3)
	var to := _centre(page, 1)
	await e.mouse_to(from)
	_button(e, from / scale, true)
	await e.frames(1)
	await e.mouse_to(from.lerp(to, 0.5))
	await e.mouse_to(to)
	assert_eq(page.row.lifted_tile(), 3, "the drag lifted the card from slot 4")
	assert_eq(page.row.ghost_slot(), 3, "its ghost stays on slot 4")
	assert_eq(page.row.ghost_card(), ids[3], "and shows that card")
	assert_eq(page.row.marker_slot(), 1, "the marker is on slot 2")
	assert_lt(page.row.marker_rect().get_center().x, _centre(page, 1).x, "before slot 2's card")
	assert_gt(page.row.marker_rect().get_center().x, _centre(page, 0).x, "after slot 1's card")
	assert_eq(page.forecast_ids(), _ids_moved(ids, 3, 1), "the forecast previews the landing")
	_button(e, to / scale, false)
	await e.frames(1)
	want = _moved(want, 3, 1)
	ids = _ids_moved(ids, 3, 1)
	assert_eq(page.order(), want, "the drop gives the order the marker showed")
	assert_eq(page.row.ghost_slot(), -1, "and the marks go")
	# Click, point, click: the marker follows the pointer. The second click comes while the tiles are still gliding.
	await e.click_at(_centre(page, 0))
	assert_eq(page.row.ghost_slot(), 0, "the click picked it up")
	await e.mouse_to(_centre(page, 2))
	assert_eq(page.row.marker_slot(), 2, "the marker follows the pointer")
	assert_true(page.row.animating(), "the tiles are still gliding")
	await e.click_at(_centre(page, 2))
	want = _moved(want, 0, 2)
	assert_eq(page.order(), want, "the click landed during the animation")
	# A drag released away from every slot puts the card back.
	from = _centre(page, 2)
	var away := _centre(page, 2) + Vector2(0, 400)
	await e.mouse_to(from)
	_button(e, from / scale, true)
	await e.frames(1)
	await e.mouse_to(from.lerp(away, 0.5))
	await e.mouse_to(away)
	_button(e, away / scale, false)
	await e.frames(1)
	assert_eq(page.order(), want, "released off the slots: the card went back")
	assert_eq(page.row.ghost_slot(), -1)


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


## Boots main.tscn with a run saved on its last floor (v0.9.0 FV: floor 5; eight wand slots, all full), and continues
## it from the menu.
func _floor_three(e: E2e) -> Main:
	var run := SaveLab.run_state(777, SaveLab.floors(), &"blade")
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
	assert_true(main.is_playing(), "the floor 5 run continues")
	if not main.is_playing():
		return
	var w := e.world()
	assert_eq(main.run.floor_index, 5)
	assert_eq(w.mod_slots.size(), 8, "eight cards in eight slots")
	# v0.8.0 N11 (O69): the floor opens under the cover and the hero's arrival; the card is given before it landed.
	assert_true(main.driver.reader.arriving(), "the grant comes while the hero is still arriving")
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")
	await e.click_dev("GrantMod")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	assert_true(await e.landed(), "the Swap waiting never stops the arrival: the hero lands")
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	assert_true(hud.visible, "the HUD shows once landed, the Swap in it")
	assert_true(hud.swap.is_open(), "a ninth card: the Swap panel")
	assert_eq(hud.swap.slot_count(), 8)
	var screen := main.get_viewport().get_visible_rect()
	var rect := hud.swap.content_rect()
	gut.p("swap at 8 slots: %s on %s" % [rect, screen])
	assert_true(screen.encloses(rect), "the Swap at 8 slots fits the screen")
	assert_true(rect.size.x <= 1920.0 and rect.size.y <= 1080.0, "inside the 1920 x 1080 base")
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
	var cast := hud.swap.forecast_ids()  # v0.11.0 F11: the forecast after the swap, as card icons
	gut.p("swap forecast: %s" % [cast])
	assert_false(cast.is_empty(), "the Swap shows a forecast")
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
	assert_eq(_ids(WorldReader.new(w).wand()), cast, "the Swap's forecast was the outcome's cards")
