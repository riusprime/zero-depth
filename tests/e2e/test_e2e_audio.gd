extends GutTest
## Sounds in the real game (v0.3.0 AU, L27), through real input only. Headless runs on the Dummy audio driver, so
## these read which cues the director chose (Main.audio.played_log), never what is heard: the menu confirms, the
## floor's biome loop starts, a swing plays its slash, and with captions on a boss telegraph shows its caption.

const MAX_FRAMES := 1500


func after_each() -> void:
	Input.action_release(&"primary")


func _click(e: E2e, c: Control) -> void:
	var at := c.get_global_rect().get_center()
	await e.mouse_to(at)
	var scale := await e._mouse_scale()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at / scale
		ev.global_position = at / scale
		e.send(ev)
		await e.frames(1)


func test_menus_floor_and_blade_have_their_sounds() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var log := main.audio.played_log
	assert_has(log, &"ui_confirm", "the menu confirm")
	assert_has(log, &"floor_enter", "the floor's arrival")
	assert_eq(main.audio.ambience_id(), main.run_biome_id(), "the biome's loop")
	assert_not_null(main.audio.ambience_player().stream)
	await e.frames(30)
	var before := log.size()
	for k in 3:
		e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
		await e.frames(2)
		e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
		await e.frames(40)
	var swings := main.audio.played_log.slice(before).filter(
		func(id: StringName) -> bool: return String(id).begins_with("blade_")
	)
	assert_gt(swings.size(), 0, "a swing plays a blade sound: %s" % [swings])
	if swings.size() > 0:
		assert_eq(swings[0], &"blade_slash_1", "the first slash")


func test_captions_on_show_the_boss_telegraph() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["captions"] = "on"
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	var panel := main.ui.find_child("DevPanel", true, false) as Control
	await e.frames(2)
	await _click(e, panel.find_child("God", true, false) as Control)
	await _click(e, panel.find_child("SpawnBoss", true, false) as Control)
	await e.frames(4)
	assert_true(e.world().boss_alive(), "a boss came")
	var shown := ""
	for k in MAX_FRAMES:
		await e.frames(1)
		if main.audio.played_log.has(&"boss_telegraph") and main.audio.caption_text != "":
			shown = main.audio.caption_text
			break
	assert_has(main.audio.played_log, &"boss_telegraph", "the boss's windup is heard")
	var telegraphs := ["GATEKEEPER", "BROOD_MOTHER", "SIEGE_ENGINE"].map(
		func(b: String) -> String: return tr("CAPTION_TELEGRAPH_" + b)
	)
	assert_has(telegraphs, shown, "the telegraph's caption shows: %s" % shown)
	var label := main.audio.find_child("Caption", true, false) as Label
	assert_true(label.is_visible_in_tree(), "drawn on screen")
	assert_eq(label.text, shown)
