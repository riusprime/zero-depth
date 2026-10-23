extends GutTest
## v0.7.5 AC (owner N7): local achievements through real input only. A Gun run starts: its biome's own achievement
## unlocks and its toast shows; an enemy shot dead unlocks First Blood, whose toast follows; the pause menu's Codex
## turns (E) to the Achievements page, where First Blood is lit and a locked one is dimmed with its sentence; back in
## the main menu the Codex's Achievements tab (a mouse click) still has it (the profile, outside the run), the pad's
## LB turns back to Biomes and B leaves.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"shoot", &"pause"]:
		Input.action_release(a)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _pad(e: E2e, b: JoyButton) -> void:
	e.joy_button(b, true)
	await e.frames(1)
	e.joy_button(b, false)
	await e.frames(2)


func _nearest_enemy(w: World) -> int:
	var best := -1
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or w.actors.teams[i] != ActorStore.TEAM_ENEMY:
			continue
		var d := w.actors.pos(i).distance_to(w.player_pos())
		if best < 0 or d < w.actors.pos(best).distance_to(w.player_pos()):
			best = i
	return best


## Holds the right trigger, aiming the right stick at the nearest enemy, until something died (or the budget ends).
func _shoot_until_a_kill(e: E2e) -> void:
	var w := e.world()
	var shooting := false
	for k in 3600:
		var target := _nearest_enemy(w)
		if target >= 0:
			var d := (w.actors.pos(target) - w.player_pos()).normalized()
			var c := InputLatch.C45
			var screen := Vector2((d.x + d.y) * c, (d.y - d.x) * c)
			e.joy_axis(JOY_AXIS_RIGHT_X, screen.x)
			e.joy_axis(JOY_AXIS_RIGHT_Y, -screen.y)
			if not shooting:
				e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
				shooting = true
		await e.frames(1)
		if w.kills > 0 or w.player_dead():
			break
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	e.joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	e.joy_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await e.frames(2)


## Waits (real frames) until the toast shows `id`; false if it never did.
func _toast_shows(e: E2e, toast: AchievementToast, id: StringName) -> bool:
	for k in 900:
		if toast.current_id() == id:
			return true
		await e.frames(1)
	return false


func test_an_achievement_unlocks_by_play_toasts_and_is_on_the_codex_page() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	assert_eq(main.achievements.unlocked_count(), 0, "a fresh profile")
	await e.start_from_menu(&"gun")
	assert_true(main.is_playing())
	var biome := main.run_biome_id()
	var biome_ach := StringName("biome_%s" % biome)
	assert_true(main.achievements.is_unlocked(biome_ach), "the floor's biome: its achievement")
	var toast := main.get_node("UI/AchievementToast") as AchievementToast
	assert_true(await _toast_shows(e, toast, biome_ach), "its toast shows")
	assert_true(toast.visible)
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the toast blocks nothing")
	var w := e.world()
	await _shoot_until_a_kill(e)
	assert_false(w.player_dead(), "survived")
	assert_gt(w.kills, 0, "shot something dead")
	assert_true(main.achievements.is_unlocked(&"kills_1"), "First Blood unlocked by the kill")
	assert_true(await _toast_shows(e, toast, &"kills_1"), "and its toast follows")
	assert_eq(toast.name_label.text, tr("ACH_KILLS_1_NAME"))
	assert_eq(toast.header.text, tr("UI_ACH_TOAST"), "under its translated line")
	assert_true(main.driver != null and not main.driver.paused, "the toast never paused the game")
	# Pause -> Codex (Resume, Build, Restart, Options, Codex) -> E x4: Achievements.
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	for k in 4:
		await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Codex")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var codex := main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex, "the Codex over the paused run")
	for k in 4:
		await e.tap(KEY_E)
	assert_eq(codex.page, CodexView.ACHIEVEMENTS, "E turns to the Achievements page")
	var page := codex.achievements_page
	assert_true(page.is_visible_in_tree())
	assert_true(_focused(main) is AchievementRow, "a row has the focus")
	var row := page.row(&"kills_1")
	assert_not_null(row)
	assert_true(row.unlocked, "First Blood is lit")
	assert_eq(row.state_label.text, tr("UI_ACH_UNLOCKED"))
	assert_true(page.row(biome_ach).unlocked, "so is the biome's")
	var locked := page.row(&"win_run")
	assert_false(locked.unlocked, "a run not won")
	assert_eq(locked.desc_label.text, tr("ACH_WIN_RUN_DESC"), "dimmed with its sentence")
	assert_eq(page.row(&"ascend_1").name_label.text, "???", "a hidden one")
	assert_eq(
		codex.progress.text,
		tr("UI_ACH_PROGRESS") % [main.achievements.unlocked_count(), page.rows.size()],
		"how many of all"
	)
	var before := _focused(main)
	await e.tap(KEY_DOWN)
	await e.frames(1)
	assert_ne(_focused(main), before, "arrows move through the rows")
	assert_true(_focused(main) is AchievementRow)
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/CodexView"), "Esc leaves")
	assert_true((main.get_node("UI/PauseMenu") as Control).visible, "back to the pause menu")
	# Main menu, then the hub's Rune Archive (v0.9.0 HB): the Codex there, the Achievements tab by mouse.
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_false(main.is_playing(), "Main menu ends the run")
	await e.tap(KEY_DOWN)  # Continue (the run's save) -> Play
	var walk := HubWalk.new(e)
	assert_true(await walk.enter(), "Play: the hub")
	await walk.use(&"archive")
	codex = main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex)
	var tab := codex.tabs[CodexView.ACHIEVEMENTS] as Button
	await e.click_at(tab.get_global_rect().get_center())
	await e.frames(2)
	assert_eq(codex.page, CodexView.ACHIEVEMENTS, "a click on the tab")
	assert_true(codex.achievements_page.row(&"kills_1").unlocked, "still there: the profile")
	await _pad(e, JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(codex.page, &"biomes", "LB turns back to Biomes")
	await _pad(e, JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(codex.page, CodexView.ACHIEVEMENTS, "RB to Achievements")
	await _pad(e, JOY_BUTTON_B)
	assert_null(main.get_node_or_null("UI/CodexView"), "pad B leaves")
	assert_not_null(main.hub, "back in the hub")
