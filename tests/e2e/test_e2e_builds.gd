extends GutTest
## Starting builds through real input (v0.3.0 L15, L16, L25, L29): Play opens the two-card build screen; the pad,
## the keyboard and the mouse each pick a card; the run then has only that weapon. Melee goes the way the character
## faces while shots go along the aim; out of combat the HP regenerates with a green pulse on the bar.


func after_each() -> void:
	for a in [&"primary", &"shoot", &"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _press(e: E2e, button: JoyButton) -> void:
	e.joy_button(button, true)
	await e.frames(1)
	e.joy_button(button, false)
	await e.frames(2)


func _player_bolts(w: World) -> int:
	var n := 0
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			n += 1
	return n


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## Left (move) or right (aim) stick toward a direction on the sim plane (the inverse of InputLatch.screen_to_sim).
func _stick(e: E2e, x_axis: JoyAxis, y_axis: JoyAxis, dir: Vector2) -> void:
	var c := InputLatch.C45
	e.joy_axis(x_axis, (dir.x + dir.y) * c)
	e.joy_axis(y_axis, -(dir.y - dir.x) * c)


func _sticks_off(e: E2e) -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		e.joy_axis(axis, 0.0)
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)


func test_the_build_screen_shows_both_cards() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_ENTER)  # Play
	await e.frames(2)
	var picker := main.get_node_or_null("UI/BuildPicker") as BuildPicker
	assert_not_null(picker, "Play opens the build screen")
	assert_eq(picker.cards.size(), 2)
	assert_eq(picker.cards[0].title_key, &"BUILD_BLADE")
	assert_eq(picker.cards[1].title_key, &"BUILD_GUN")
	assert_eq([picker.cards[0].damage_text(), picker.cards[1].damage_text()], ["+15 %", "+0 %"])  # owner 2026-10-08: no Gun -15 %
	assert_lt(
		picker.cards[1].appear(), picker.cards[0].appear() + 0.001, "the cards come in staggered"
	)
	await e.frames(60)
	assert_eq(picker.cards[1].appear(), 1.0, "and land within a second")
	assert_eq(picker.focused_id(), &"blade", "Blade has focus on a fresh profile")


func test_pick_gun_with_the_pad_then_melee_does_nothing_and_shooting_works() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _press(e, JOY_BUTTON_A)  # Play
	var picker := main.get_node_or_null("UI/BuildPicker") as BuildPicker
	assert_not_null(picker)
	await _press(e, JOY_BUTTON_DPAD_RIGHT)
	assert_eq(picker.focused_id(), &"gun", "the d-pad moves to Gun")
	await _press(e, JOY_BUTTON_A)  # Gun: v0.4.0 BS (F11) has no utility pick, the run starts
	assert_true(main.is_playing())
	var w := e.world()
	assert_eq(w.player.weapons, PlayerTable.WEAPON_GUN, "a Gun run")
	assert_eq(main.run.build_id, &"gun", "the run holds the build")
	assert_eq(main.profile.section("loadout")["build"], "gun", "remembered")
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await e.frames(2)
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await e.frames(10)
	assert_eq(w.swing_t, 0, "the melee trigger does nothing")
	assert_eq(w.combo_step, 0)
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await e.frames(20)
	assert_gte(_player_bolts(w), 2, "the right trigger shoots")
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)


func test_pick_blade_with_the_keyboard_then_shooting_does_nothing() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_ENTER)  # Play
	await e.frames(2)
	var picker := main.get_node_or_null("UI/BuildPicker") as BuildPicker
	await e.tap(KEY_RIGHT)
	assert_eq(picker.focused_id(), &"gun", "Right moves to Gun")
	await e.tap(KEY_LEFT)
	assert_eq(picker.focused_id(), &"blade", "Left back to Blade")
	await e.tap(KEY_ENTER)  # Blade, and the run (no utility pick since v0.4.0 BS)
	await e.frames(2)
	var w := e.world()
	assert_eq(w.player.weapons, PlayerTable.WEAPON_BLADE, "a Blade run")
	assert_eq(w.player.melee_damage_permille, 1150, "with the Blade's damage factor")
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.frames(20)
	assert_eq(_player_bolts(w), 0, "right click shoots nothing")
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	e.mouse_button(MOUSE_BUTTON_LEFT, true)
	e.mouse_button(MOUSE_BUTTON_LEFT, false)
	await e.frames(2)
	assert_gt(w.swing_t, 0, "left click swings")


func test_a_click_picks_a_card_and_esc_goes_back() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_ENTER)  # Play
	await e.frames(40)
	var picker := main.get_node_or_null("UI/BuildPicker") as BuildPicker
	await e.tap(KEY_ESCAPE)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "Esc goes back to the menu")
	await e.tap(KEY_ENTER)  # Play again
	await e.frames(40)
	picker = main.get_node_or_null("UI/BuildPicker") as BuildPicker
	await e.click_at(picker.cards[1].get_global_rect().get_center())
	await e.frames(2)
	assert_true(main.is_playing(), "a click on Gun picks it and starts the run")
	assert_eq(main.profile.section("loadout")["build"], "gun")


## L29: the swing goes where the character faces (the left stick), the aim (right stick) points elsewhere; a
## Gun's shot goes along the aim.
func test_melee_follows_the_move_stick_and_shots_the_aim_stick() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu(&"blade")
	var w := e.world()
	var r := WorldReader.new(w)
	var nav := NavField.new()
	nav.build(w.walls)
	var hit_toward := false
	var swing_dir_ok := false
	var trigger := false
	for k in 5400:
		var target := -1
		var best := INF
		for i in range(1, w.actors.size()):
			var d := w.actors.pos(i).distance_to(w.player_pos())
			if w.actors.dead[i] == 0 and d < best:
				best = d
				target = i
		if target >= 0:
			var to := w.actors.pos(target) - w.player_pos()
			if k % 20 == 0:
				nav.flood(w.actors.pos(target))
			var walk := to.normalized() if to.length() < 3.0 else nav.direction(w.player_pos())
			# Move toward the enemy (a light push when close), aim the opposite way.
			_stick(e, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, walk * (0.4 if to.length() < 1.6 else 1.0))
			_stick(e, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, -to.normalized())
			if trigger:
				e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
				trigger = false
			elif r.swing_tick() == 0 and to.length() < 1.9:
				var seq := r.last_event_seq()
				e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
				trigger = true
				await e.frames(1)
				if r.swing_tick() > 0:
					var off := Kin.angle_diff(r.swing_angle(), Kin.angle_of(to))
					var off_aim := Kin.angle_diff(r.swing_angle(), r.aim_angle())
					swing_dir_ok = off < 400 and off_aim > 1200
				for f in 12:
					await e.frames(1)
				for ev in r.events_since(seq):
					if ev.kind == SimEvent.Kind.HIT and ev.tags & SimEvent.TAG_MELEE:
						hit_toward = true
				if swing_dir_ok and hit_toward:
					break
				continue
		await e.frames(1)
		if w.player_dead():
			break
	_sticks_off(e)
	assert_true(swing_dir_ok, "the swing went toward the move stick, away from the aim")
	assert_true(hit_toward, "and hit the enemy the character faced")


func test_gun_shots_follow_the_aim_stick_while_moving_the_other_way() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var left := Vector2(-1, 0)
	_stick(e, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, left)
	_stick(e, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, -left)
	await e.frames(4)
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await e.frames(3)
	var found := false
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			found = true
			assert_gt(w.projectiles.vel_x[i], 0.0, "the bolt goes along the aim (+x)")
	assert_true(found, "a bolt flew")
	assert_lt(w.vel.x, 0.0, "while the character moves the other way (-x)")
	_sticks_off(e)


## L25: hurt, then out of combat (God mode from the dev panel keeps enemies from landing hits), the HP climbs back
## and the HP bar pulses green.
func test_out_of_combat_regen_heals_and_the_bar_pulses() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"blade")
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	for k in 3600:
		if w.actors.hp[0] < w.actors.max_hp[0] - 2:
			break
		await e.frames(1)
	assert_lt(w.actors.hp[0], w.actors.max_hp[0], "an enemy hurt the player")
	await e.tap(KEY_QUOTELEFT)
	var b := main.get_node("UI/DevPanel").find_child("God", true, false) as Button
	await e.click_at(b.get_global_rect().get_center())
	assert_true(main.driver.debug.god)
	var hurt := w.actors.hp[0]
	var pulsed := false
	for k in 60 * 14:
		await e.frames(1)
		pulsed = pulsed or (hud.find_child("RegenPulse", true, false) as RegenPulse).is_pulsing()
		if w.actors.hp[0] >= hurt + 2 and pulsed:
			break
	assert_false(w.player_dead())
	assert_gte(w.actors.hp[0], hurt + 2, "regen healed after 10 s out of combat")
	assert_true(pulsed, "the HP bar pulsed green while it healed")


func test_the_left_stick_moves_between_the_cards() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _press(e, JOY_BUTTON_A)  # Play
	var picker := main.get_node_or_null("UI/BuildPicker") as BuildPicker
	assert_eq(picker.focused_id(), &"blade")
	# A stick push counts in the frame after it arrives, as a real pad's does (see test_e2e_pad_menus).
	await get_tree().process_frame
	e.joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await e.frames(1)
	e.joy_axis(JOY_AXIS_LEFT_X, 0.0)
	await e.frames(1)
	assert_eq(picker.focused_id(), &"gun", "the left stick moves to Gun")
	assert_eq(_focused(main), picker.cards[1])
