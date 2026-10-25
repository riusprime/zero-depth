extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F5, F6) through the real game (main.tscn, input by Input.parse_input_event
## only): a Gun run walks to an altar and opens it with E; the card reads "Form"; Enter takes it.
## - The Lance: holding the shoot button (right click) with the mouse on a row of enemies charges it (v0.9.0 AF1b: the
##   swirling circle drawn in front of the hero) and nothing fires; letting go fires one energy ball that pierces and
##   hurts every enemy in the row, its muzzle burst drawn, and pushes the hero back a small step.
## - v0.9.5 FC0, the Rune Explosion (it replaced the Scatter): holding the shoot button bursts a violet rune ring from
##   the hero (drawn, heard) that hurts and shoves an enemy 2 m out; one 6 m out is never touched.
## The retired Charge card is never offered.

const E2eVoid := preload("res://tests/e2e/test_e2e_void.gd")


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## (as test_e2e_void.gd's) Takes card `id` at the nearest altar (its offer forced: TEST HELPER), checking its slot tag.
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


## Lets go of the right button with the cursor at `pos` (a real release carries the cursor's position; E2e's
## mouse_button sends none, which the game reads as the top-left corner).
func _release_at(e: E2e, pos: Vector2) -> void:
	var scale: Vector2 = await e._mouse_scale()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = false
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


func test_the_lance_charges_while_held_and_its_release_pierces_the_row() -> void:
	var e := E2e.new(self)
	var main := await _boot_with(e, &"gun_lance")
	var w := e.world()
	assert_eq(AttackSlots.form_id(w), &"lance", "the Gun's shot is the Lance now")
	assert_does_not_have(
		ItemPool.available(w),
		AttackScenario.item_index(w.item_tables, &"gun_charge"),
		"the retired Charge card is never offered"
	)
	# TEST HELPER (labelled): three standing dummies in a row 3, 5 and 7 m out on a clear line.
	var at: Vector2 = E2eVoid.clear_spot(w, 7.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var hero := w.player_pos()
	var dir := (at - hero).normalized()
	w.dummy_speed = 0.0
	var row: Array[int] = []
	for d in [3.0, 5.0, 7.0]:
		row.append(w.add_dummy(hero + dir * d, 0.35, 5000))
	var cam := main.view.rig.camera
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	var circle := false
	var size := 0.0
	for k in 90:  # the mouse kept on the row while the camera settles after the walk
		await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
		circle = circle or main.view.lances.circle
		size = maxf(size, main.view.lances.circle_size)
	var a := w.actors
	var charge := main.view.reader.lance_charge()
	for id in row:
		assert_eq(a.hp[a.index_of(id)], a.max_hp[a.index_of(id)], "held: nothing fired yet")
	var before := w.player_pos()
	await _release_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	var bursts := 0
	var balls := 0
	for k in 60:  # the ball flies the row (7 m)
		await e.frames(1)
		bursts = maxi(bursts, main.view.lances.bursts)
		balls = maxi(balls, w.projectiles.size())
	var back := (before - w.player_pos()).dot(dir)
	var hurt := []
	for id in row:
		var j := a.index_of(id)
		hurt.append(a.max_hp[j] - a.hp[j])
	(
		gut
		. p(
			(
				"AF1b e2e Lance: charge %.2f when let go; circle %.2f m; damage to the row at 3 / 5 / 7 m %s; pushed back %.3f m"
				% [charge, size, hurt, back]
			)
		)
	)
	assert_gt(charge, 0.9, "it charged while held")
	assert_true(circle, "the charging circle is drawn while held")
	assert_eq(balls, 1, "the release fires one ball")
	for h: int in hurt:
		assert_gt(h, 0, "the ball pierced every enemy in the row")
	assert_gt(bursts, 0, "the release burst is drawn")
	assert_gt(back, 0.3, "the hero was pushed back, away from the aim")


func test_the_rune_explosion_hurts_and_shoves_what_is_near_and_spares_what_is_far() -> void:
	var e := E2e.new(self)
	var main := await _boot_with(e, &"gun_rune_explosion")
	var w := e.world()
	assert_eq(AttackSlots.form_id(w), &"rune_explosion", "the Gun's shot is the Rune Explosion now")
	# TEST HELPER (labelled): a standing dummy 2 m out and one 6 m out on the same clear line.
	var at: Vector2 = E2eVoid.clear_spot(w, 7.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var hero := w.player_pos()
	var dir := (at - hero).normalized()
	w.dummy_speed = 0.0
	var near := w.add_dummy(hero + dir * 2.0, 0.35, 5000)
	var far := w.add_dummy(hero + dir * 6.0, 0.35, 5000)
	var near_from := w.actors.pos(w.actors.index_of(near))
	var cam := main.view.rig.camera
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	var shown := 0
	var widest := 0.0
	for k in 100:
		await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
		shown = maxi(shown, main.view.runes.bursts)
		for edge in main.view.runes.edges:
			widest = maxf(widest, edge)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var a := w.actors
	var n := a.index_of(near)
	var f := a.index_of(far)
	var pushed := (a.pos(n) - near_from).length()
	(
		gut
		. p(
			(
				"FC0 e2e Rune Explosion: near (2 m) took %d, far (6 m) took %d; shoved %.2f m; bursts drawn %d, widest edge %.2f m"
				% [a.max_hp[n] - a.hp[n], a.max_hp[f] - a.hp[f], pushed, shown, widest]
			)
		)
	)
	assert_lt(a.hp[n], a.max_hp[n], "the near one is hurt")
	assert_gt(pushed, 0.2, "and shoved outward")
	assert_eq(a.hp[f], a.max_hp[f], "the far one is past the ring's 3.5 m")
	assert_gt(shown, 0, "the rune ring is drawn")
	assert_gt(widest, 3.0, "it grows to its full size")
	assert_true(main.audio.played_log.has(&"rune_burst"), "its boom is heard")
