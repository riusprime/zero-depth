extends GutTest
## v0.9.0 AF3 (owner Q7; ATTACK_FORMS.md F9, F10) through the real game (main.tscn, input by Input.parse_input_event
## only): a Gun run walks to an altar and opens it with E; the card reads "Form"; Enter takes it.
## - The Wave: holding the shoot button (right click) with the mouse on a spread of enemies ahead rolls wide waves
##   through all of them (drawn as bands, heard as a whoosh), each enemy hurt.
## - The Wisps: three wisps are drawn circling the hero; with the shoot button never pressed they hurt an enemy close by
##   on their own (their chirp heard); holding the button adds the hero's own orbs on top.

const E2eVoid := preload("res://tests/e2e/test_e2e_void.gd")


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## (as test_e2e_lance_scatter.gd's) Takes card `id` at the nearest altar (its offer forced: TEST HELPER), checking its
## slot tag.
## True when taken.
func _take_at_altar(e: E2e, main: Main, id: StringName, others: Array) -> bool:
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	if i < 0:
		return false
	var offer := PackedInt32Array([AttackScenario.item_index(w.item_tables, id)])
	for o: StringName in others:
		offer.append(AttackScenario.item_index(w.item_tables, o))
	w.rewards.set_offer(i, offer)
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_true(panel.is_open(), "E opened the altar")
	for k in 240:
		if panel.deal.done():
			break
		await e.frames(1)
	assert_eq(panel.slot(0).slot_text(), tr("UI_SLOT_FORM"), "the card wears the Form tag")
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(70)
	return w.items_owned.has(AttackScenario.item_index(w.item_tables, id))


## The cursor to `pos` (viewport pixels, `scale` from E2e._mouse_scale measured once), then one frame. E2e.mouse_to
## measures the scale again on every call with a probe event at (100, 100) that the game takes as a real cursor move,
## so a held shoot button aims at the probe every other frame; this sends the one motion only.
func _aim_at(e: E2e, pos: Vector2, scale: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos / scale
	ev.global_position = pos / scale
	e.send(ev)
	await e.frames(1)


## Presses or lets go of the right button with the cursor at `pos` (as test_e2e_lance_scatter.gd's _release_at: a
## real button event carries the cursor's position; E2e's mouse_button sends none, which the game reads as the
## top-left corner and aims there).
func _button_at(e: E2e, pos: Vector2, scale: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pressed
	ev.position = pos / scale
	ev.global_position = pos / scale
	e.send(ev)


## Boots a Gun run in god mode and takes card `id` at an altar.
func _boot_with(e: E2e, id: StringName) -> Main:
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await _take_at_altar(e, main, id, [&"gun_twin", &"ember_core"]), "took %s" % id)
	return main


func test_the_wave_rolls_through_a_spread_of_enemies() -> void:
	var e := E2e.new(self)
	var main := await _boot_with(e, &"gun_wave")
	var w := e.world()
	assert_eq(AttackSlots.form_id(w), &"wave", "the Gun's shot is the Wave now")
	# TEST HELPER (labelled): three standing dummies 3, 5 and 7 m out on a clear line, the outer two 1 m off it.
	var at: Vector2 = E2eVoid.clear_spot(w, 7.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var hero := w.player_pos()
	var dir := (at - hero).normalized()
	var side := Vector2(-dir.y, dir.x)
	w.dummy_speed = 0.0
	var spread: Array[int] = []
	for p: Array in [[3.0, 1.0], [5.0, 0.0], [7.0, -1.0]]:
		spread.append(w.add_dummy(hero + dir * float(p[0]) + side * float(p[1]), 0.35, 5000))
	var cam := main.view.rig.camera
	var scale: Vector2 = await e._mouse_scale()
	await _aim_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)), scale)
	_button_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)), scale, true)
	var waves := 0
	for k in 150:
		await _aim_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)), scale)
		waves = maxi(waves, main.view.waves.waves)
	_button_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)), scale, false)
	var a := w.actors
	var hurt := []
	for id in spread:
		var j := a.index_of(id)
		hurt.append(a.max_hp[j] - a.hp[j])
	(
		gut
		. p(
			(
				"AF3 e2e Wave: damage to the spread at 3 / 5 / 7 m (1 m either side) %s; most waves drawn %d"
				% [hurt, waves]
			)
		)
	)
	for h: int in hurt:
		assert_gt(h, 0, "the wave rolled through every enemy")
	assert_gt(waves, 0, "the bands are drawn")
	assert_true(main.audio.played_log.has(&"wave_fire"), "its whoosh is heard")


func test_the_wisps_fire_on_their_own_and_the_hero_fires_too() -> void:
	var e := E2e.new(self)
	var main := await _boot_with(e, &"gun_wisps")
	var w := e.world()
	assert_eq(AttackSlots.form_id(w), &"wisps", "the Gun has the Wisps now")
	await e.frames(2)
	assert_eq(main.view.wisps.wisps, 3, "three wisps drawn round the hero")
	# TEST HELPER (labelled): a standing dummy 3.5 m out on a clear line.
	var at: Vector2 = E2eVoid.clear_spot(w, 7.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var hero := w.player_pos()
	var dir := (at - hero).normalized()
	w.dummy_speed = 0.0
	var foe := w.add_dummy(hero + dir * 3.5, 0.35, 50000)
	var a := w.actors
	await e.frames(120)
	var j := a.index_of(foe)
	var alone: int = a.max_hp[j] - a.hp[j]
	var cam := main.view.rig.camera
	var scale: Vector2 = await e._mouse_scale()
	await _aim_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)), scale)
	_button_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)), scale, true)
	for k in 120:
		await _aim_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)), scale)
	_button_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)), scale, false)
	j = a.index_of(foe)
	var both: int = a.max_hp[j] - a.hp[j] - alone
	(
		gut
		. p(
			(
				"AF3 e2e Wisps: 120 frames without shooting: %d damage; 120 frames holding shoot: %d more"
				% [alone, both]
			)
		)
	)
	assert_gt(alone, 0, "the wisps hurt it on their own")
	assert_gt(both, alone, "holding shoot adds the hero's own orbs")
	assert_true(main.audio.played_log.has(&"wisp_fire"), "their chirp is heard")
	assert_true(main.audio.played_log.has(&"bolt_fire"), "and the Gun's own shot")
