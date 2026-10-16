extends GutTest
## v0.8.0 P2 (owner O24): Void's black holes in a real Gun run, through main.tscn and real input only. The dev panel
## (real clicks; TEST HELPER, as test_e2e_gun_pool.gd) grants Void five times (level 5: a 20 % chance a shot); holding
## right click shoots; shots that end leave small black holes (at most 3 stand), which the view draws as dark swirling
## holes; the card's text names the new mechanic.


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
		and guard < 160
	):
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


func test_void_shots_leave_black_holes_the_view_draws() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var reader: WorldReader = main.driver.reader
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	for n in 5:
		await _grant(e, main, &"gravity_well")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var cards: Array = reader.wand()["cards"]
	assert_eq(int(cards[0]["level"]), 5, "Void at level 5")
	assert_eq(int(reader.attack_spec(WorldReader.ATTACK_BOLT)["hole_permille"]), 200, "20 % a shot")
	assert_true(tr("ITEM_GRAVITY_WELL_DESC").contains("8 %"), "its text names the chance")
	var seen := 0
	var drawn := 0
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	for f in 900:
		await e.frames(1)
		seen = maxi(seen, reader.black_holes().size())
		drawn = maxi(drawn, main.view.black_holes.drawn)
		assert_lte(reader.black_holes().size(), 3, "at most 3 stand")
		if seen >= 2 and drawn >= 2:
			break
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	assert_gt(seen, 0, "shots left black holes")
	assert_gt(drawn, 0, "the view draws them")
	assert_eq(
		main.view.black_holes.drawn, reader.black_holes().size(), "one drawn for each standing"
	)
	assert_false(w.player_dead())
	assert_eq(get_errors().size(), 0, "no engine or script error")
