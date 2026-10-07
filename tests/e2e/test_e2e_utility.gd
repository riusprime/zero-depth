extends GutTest
## The utility button with real input (Shift or the left bumper). v0.4.0 BS (owner F11, PD-01 flipped): a run starts
## without a utility; Blink and Aegis are ability cards. Here the dev panel's forced loadout grants them (its
## buttons clicked with the mouse); picking one from an altar is tests/e2e/test_e2e_abilities.gd. Blink goes the way
## you're moving and lands with a shock.


func after_each() -> void:
	for a in [&"utility", &"move_right", &"move_up"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


## Opens the dev panel and grants the ability `id` (cycling the panel's choice to it).
func _grant(e: E2e, main: Main, id: StringName) -> void:
	if not main.is_dev_panel_open():
		await e.tap(KEY_QUOTELEFT)
	var w := e.world()
	for k in w.ability_tables.size():
		if w.ability_tables[main.driver.debug.ability_choice].id == id:
			break
		await _click(e, main, "NextAbility")
	await _click(e, main, "GrantAbility")
	await e.frames(2)


func test_a_run_starts_without_a_utility_and_shift_does_nothing() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	assert_eq(
		main.driver.reader.utility(), PlayerTable.Utility.NONE, "no utility at the start (F11)"
	)
	assert_eq(w.ability_owned.size(), 1, "only the weapon in slot 1")
	var start := w.player_pos()
	e.key(KEY_SHIFT, true)
	await e.frames(4)
	assert_false(w.guarding(), "Shift doesn't guard")
	e.key(KEY_SHIFT, false)
	await e.frames(2)
	assert_eq(w.blink_tick, -1, "nor blink")
	assert_lt(w.player_pos().distance_to(start), 0.01)
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(hud.ability_hud.filled_count(), 1, "the HUD shows one filled slot")


func test_aegis_guards_with_shift_or_the_left_bumper() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await _grant(e, main, &"aegis")
	assert_eq(main.driver.reader.utility(), PlayerTable.Utility.GUARD, "Aegis is the guard")
	e.key(KEY_SHIFT, true)
	await e.frames(3)
	assert_true(e.world().guarding(), "holding Shift guards")
	e.key(KEY_SHIFT, false)
	await e.frames(2)
	assert_false(e.world().guarding())
	e.joy_button(JOY_BUTTON_LEFT_SHOULDER, true)
	await e.frames(3)
	assert_true(e.world().guarding(), "holding the left bumper guards")
	e.joy_button(JOY_BUTTON_LEFT_SHOULDER, false)


func test_blink_follows_movement_and_lands_with_a_shock() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await _grant(e, main, &"blink")
	await e.tap(KEY_QUOTELEFT)  # close the panel
	var w := e.world()
	assert_eq(main.driver.reader.utility(), PlayerTable.Utility.BLINK)
	e.key(KEY_D, true)  # move screen-right: sim angle 512
	await e.frames(3)
	var start := w.player_pos()
	e.key(KEY_SHIFT, true)
	e.key(KEY_SHIFT, false)
	await e.frames(3)
	e.key(KEY_D, false)
	var moved := w.player_pos() - start
	assert_gt(w.blink_cd, 0, "blinked: the cooldown runs")
	assert_gt(moved.length(), 3.0, "a full blink")
	assert_almost_eq(Kin.angle_of(moved), 512, 40, "the way you were moving")
	assert_eq(w.ab.shock_tick, w.blink_tick, "and landed with its shock")
	assert_eq(main.view.ability_fx.fx_count_of(&"shock"), 1, "the shock ring flashes")
