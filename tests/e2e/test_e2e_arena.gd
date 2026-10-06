extends GutTest
## The arena's ending through real input (PLAN v0.1.0 Step 5): stand still, die, see why, restart; or go back to
## the menu. The HUD shows the wave.


func _wait_for_end(e: E2e, main: Main) -> EndPanel:
	for k in 4000:
		await e.frames(1)
		var p := main.get_node_or_null("UI/EndPanel")
		if p != null:
			return p
	return null


func test_die_see_the_cause_and_restart() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(60)
	assert_not_null(main.get_node_or_null("UI/Hud"), "the HUD is up")
	var seed_before := e.world().seed_value
	var panel := await _wait_for_end(e, main)
	assert_not_null(panel, "standing still, you die")
	if panel == null:
		return
	assert_eq((panel.find_child("Title", true, false) as Label).text, "UI_YOU_DIED")
	assert_not_null(panel.find_child("Cause", true, false), "the cause is shown")
	await e.tap(KEY_ENTER)  # Restart has focus
	await e.frames(3)
	assert_null(main.get_node_or_null("UI/EndPanel"))
	assert_eq(e.world().actors.hp[0], 100, "a fresh fight")
	assert_eq(e.world().seed_value, seed_before + 1, "with the next seed")


func test_after_dying_main_menu_goes_home() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var panel := await _wait_for_end(e, main)
	assert_not_null(panel)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_not_null(main.get_node_or_null("UI/MainMenu"))
	assert_false(main.is_playing())


func test_the_cleared_panel_reads_cleared() -> void:
	var p := EndPanel.new(true, -1)
	assert_eq((p.find_child("Title", true, false) as Label).text, "UI_ARENA_CLEARED")
	assert_null(p.find_child("Cause", true, false))
	p.free()
