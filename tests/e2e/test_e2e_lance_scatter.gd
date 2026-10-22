extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F5, F6) through the real game (main.tscn, input by Input.parse_input_event
## only): a Gun run walks to an altar and opens it with E; the card reads "Form"; Enter takes it.
## - The Lance: holding the shoot button (right click) with the mouse on a row of enemies charges it (the glow and aim
##   line drawn) and nothing fires; letting go fires one line that hurts every enemy in the row, its flash drawn.
## - The Scatter: holding the shoot button on an enemy close by fires cones of pellets (drawn as slugs and a muzzle
##   cone, heard) that hurt it, and one far past 5 m on the same line is never touched.
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
	var aims := 0
	for k in 90:  # the mouse kept on the row while the camera settles after the walk
		await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
		aims = maxi(aims, main.view.lances.aims)
	var a := w.actors
	var charge := main.view.reader.lance_charge()
	for id in row:
		assert_eq(a.hp[a.index_of(id)], a.max_hp[a.index_of(id)], "held: nothing fired yet")
	await _release_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	var flashes := 0
	for k in 6:
		await e.frames(1)
		flashes = maxi(flashes, main.view.lances.flashes)
	var hurt := []
	for id in row:
		var j := a.index_of(id)
		hurt.append(a.max_hp[j] - a.hp[j])
	gut.p(
		(
			"AF1 e2e Lance: charge %.2f when let go; damage to the row at 3 / 5 / 7 m %s"
			% [charge, hurt]
		)
	)
	assert_gt(charge, 0.9, "it charged while held")
	assert_gt(aims, 0, "the aim line is drawn while charging")
	for h: int in hurt:
		assert_gt(h, 0, "the release pierced every enemy in the row")
	assert_gt(flashes, 0, "the release flash is drawn")


func test_the_scatter_shreds_up_close_and_never_reaches_far() -> void:
	var e := E2e.new(self)
	var main := await _boot_with(e, &"gun_scatter")
	var w := e.world()
	assert_eq(AttackSlots.form_id(w), &"scatter", "the Gun's shot is the Scatter now")
	# TEST HELPER (labelled): a standing dummy 2 m out and one 7 m out on the same clear line.
	var at: Vector2 = E2eVoid.clear_spot(w, 7.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var hero := w.player_pos()
	var dir := (at - hero).normalized()
	w.dummy_speed = 0.0
	var near := w.add_dummy(hero + dir * 2.0, 0.35, 5000)
	var far := w.add_dummy(hero + dir * 7.0, 0.35, 5000)
	var cam := main.view.rig.camera
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	var pellets := 0
	var cones := 0
	for k in 120:
		await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
		pellets = maxi(pellets, main.view.scatter.pellets)
		cones = maxi(cones, main.view.scatter.cones)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var a := w.actors
	var n := a.index_of(near)
	var f := a.index_of(far)
	(
		gut
		. p(
			(
				"AF1 e2e Scatter: near (2 m) took %d, far (7 m) took %d; most pellets drawn %d, cones %d"
				% [a.max_hp[n] - a.hp[n], a.max_hp[f] - a.hp[f], pellets, cones]
			)
		)
	)
	assert_lt(a.hp[n], a.max_hp[n], "the near one is hurt")
	assert_eq(a.hp[f], a.max_hp[f], "the far one is past the pellets' 5 m")
	assert_gt(pellets, 0, "the pellets are drawn")
	assert_gt(cones, 0, "the muzzle cone is drawn")
	assert_true(main.audio.played_log.has(&"skill_scatter_blast"), "its bark is heard")
