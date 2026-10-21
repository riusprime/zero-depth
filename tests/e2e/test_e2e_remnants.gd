extends GutTest
## v0.8.0 RM (owner O91: "Threadline: consecutive projectiles connect briefly with damaging threads"): a remnant card in
## a real Gun run, through main.tscn and real input only. The dev panel (real clicks; TEST HELPER, as test_e2e_void.gd)
## grants Threadline; holding right click shoots; consecutive shots link with threads (the sim's remnant store, at
## most its cap), which the view draws; the wand's read-back names what its threads release; the card's text names
## the mechanic without numbers.


func after_each() -> void:
	Input.action_release(&"shoot")


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## TEST HELPER (labelled): the dev panel's NextMod until card `id` is chosen, then GrantMod.
func _grant(e: E2e, main: Main, id: StringName) -> void:
	var w := e.world()
	var guard := 0
	while (
		(main.driver.debug.mod_choice < 0 or w.item_tables[main.driver.debug.mod_choice].id != id)
		and guard < 200
	):
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


func test_threadline_links_shots_with_threads_the_view_draws() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var reader: WorldReader = main.driver.reader
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"gun_threadline")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var cards: Array = reader.wand()["cards"]
	assert_eq(StringName(cards[0]["id"]), &"gun_threadline", "Threadline in the wand")
	var read := Wand.render(Wand.describe(reader.wand()), tr)
	assert_true(read.contains(tr("ITEM_GUN_THREADLINE")), "the read-back names it: %s" % read)
	assert_false(
		tr("ITEM_GUN_THREADLINE_DESC").contains("%"), "its text says what it does, no numbers"
	)
	var seen := 0
	var drawn := 0
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	for f in 600:
		await e.frames(1)
		var n := (reader.remnants()["remnants"] as Array).size()
		seen = maxi(seen, n)
		drawn = maxi(drawn, main.view.remnants.drawn_segments)
		assert_lte(n, 6, "6 threads at most")
		if seen >= 2 and drawn >= 2:
			break
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	assert_gt(seen, 0, "consecutive shots linked")
	assert_gt(drawn, 0, "the view draws the threads")
	assert_false(w.player_dead())
	assert_eq(get_errors().size(), 0, "no engine or script error")
