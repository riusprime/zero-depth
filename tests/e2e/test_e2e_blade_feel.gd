extends GutTest
## v0.8.0 GF3 (owner O22): the Blade's feel in the real game, through main.tscn and real input only. In the
## Playground (the menu's row, the Blade, F1's panel places a dummy by a click), left clicks swing at the dummy: each
## slash hit throws a slash impact, the hero model accents the swing, and the view's hit-stop holds the hero's swing
## for a moment while the sim's clock ticks on, one tick a physics frame. Options -> Accessibility -> "Hit-stop"
## (keyboard) turns it off: the slashes still land, nothing is held.

var _e: E2e
var _scale := Vector2.ONE


func after_each() -> void:
	ViewPrefs.hit_stop = true
	for a in [&"primary", &"ui_accept"]:
		Input.action_release(a)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _key_to(main: Main, keycode: Key, target: StringName, limit: int = 16) -> bool:
	for k in limit:
		if _focused(main) != null and _focused(main).name == target:
			return true
		await _e.tap(keycode)
		await _e.frames(1)
	return _focused(main) != null and _focused(main).name == target


func _screen(main: Main, p: Vector2) -> Vector2:
	return main.view.rig.camera.unproject_position(SimPlane.to_3d(p, SimPlane.CORE_HEIGHT))


func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos / _scale
	ev.global_position = pos / _scale
	_e.send(ev)


## Main menu -> Playground -> the Blade; F1 places a dummy a step ahead and shuts the panel.
func _playground_with_a_dummy(main: Main) -> World:
	for k in 4:  # Play -> Options -> Credits -> Codex -> Playground
		await _e.tap(KEY_DOWN)
	await _e.tap(KEY_ENTER)
	await _e.frames(2)
	await _e.tap(KEY_LEFT)  # the Blade (left of the Gun)
	await _e.tap(KEY_ENTER)
	await _e.frames(4)
	assert_not_null(main.playground, "in the Playground")
	assert_eq(main.driver.reader.weapon_id(), &"combo_sword", "with the Blade")
	var w := _e.world()
	await _e.tap(KEY_F1)
	await _e.click_at(_screen(main, w.player_pos() + Vector2(0.9, -0.9)))
	await _e.frames(2)
	await _e.tap(KEY_F1)
	await _e.frames(2)
	assert_eq(w.actors.size(), 2, "a dummy to swing at")
	return w


## Swings at the dummy `swings` times; returns [slash impacts seen, freezes, frames held, ticks while held,
## accent peak (swing part)].
func _swing_at_dummy(main: Main, w: World, swings: int) -> Array:
	var root: WorldViewRoot = main.view
	var feel := root.hit_feel
	var aim := _screen(main, w.actors.pos(1))
	await _e.mouse_to(aim)
	var hero := root.actors.actor_node(w.actors.ids[0]).get_meta(&"avatar") as PlayerAvatar
	var slashes := 0
	var held := 0
	var held_ticks := 0
	var accent := 0.0
	var seen := 0
	for k in swings:
		_mouse(aim, true)
		await _e.frames(1)
		_mouse(aim, false)
		for f in 30:
			var tick := w.tick
			var holding := feel.hit_stop.holding()
			await _e.frames(1)
			if holding:
				held += 1
				held_ticks += w.tick - tick
			accent = maxf(accent, hero.swing_accent_now().y)
			if feel.impacts.added > seen:
				seen = feel.impacts.added
				for imp: Array in feel.impacts._live:
					if int(imp[6]) == ImpactFx.SLASH:
						slashes += 1
						break
	return [slashes, feel.hit_stop.freezes, held, held_ticks, accent]


func test_slash_hits_cut_and_hold_the_view_while_the_sim_ticks_on() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	_scale = await _e._mouse_scale()
	var w := await _playground_with_a_dummy(main)
	var got := await _swing_at_dummy(main, w, 4)
	assert_gt(got[0], 0, "slash hits throw slash impacts")
	assert_gt(got[1], 0, "and hold the view (the hit-stop)")
	assert_gt(got[2], 0, "for a frame or two at a time")
	assert_eq(got[3], got[2], "the sim ticked once a physics frame through every held frame")
	assert_gt(got[4], 0.5, "the hero model swings through")
	assert_false(main.driver.paused, "the game never paused")
	assert_eq(get_errors().size(), 0, "no engine or script error")


func test_the_hit_stop_option_in_accessibility_turns_it_off() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	_scale = await _e._mouse_scale()
	await _e.tap(KEY_DOWN)
	await _e.tap(KEY_ENTER)
	var options := main.get_node_or_null("UI/OptionsMenu") as OptionsMenu
	assert_not_null(options, "Options from the main menu")
	assert_true(await _key_to(main, KEY_DOWN, &"TabAccessibility"))
	await _e.tap(KEY_RIGHT)
	assert_true(await _key_to(main, KEY_DOWN, &"hit_stop"), "down to Hit-stop")
	await _e.tap(KEY_ENTER)
	await _e.frames(2)
	assert_eq(GameSettings.get_value(main.profile, "hit_stop"), "off", "Enter flips it off")
	assert_false(ViewPrefs.hit_stop, "the view takes it at once")
	await _e.tap(KEY_ESCAPE)
	await _e.tap(KEY_ESCAPE)
	await _e.frames(2)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "back on the main menu")
	var w := await _playground_with_a_dummy(main)
	var got := await _swing_at_dummy(main, w, 3)
	assert_gt(got[0], 0, "the slashes still land and cut")
	assert_eq(got[1], 0, "nothing is held")
	assert_eq(get_errors().size(), 0, "no engine or script error")
