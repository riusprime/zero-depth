extends GutTest
## v0.9.0 LZ (owner C §6.2, Q8; PLAN C48) through the real game (main.tscn, input by Input.parse_input_event only): a
## Gun run walks to an altar and opens it with E; its Laser card reads "Form"; Enter takes it and the Gun's shot is the
## beam. Holding the shoot button (right click) with the mouse on an enemy, the beam draws to it, hums, and the enemy
## takes damage; letting go, the beam is gone.


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _item(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## A spot `dist` m from the hero along one of 16 ways whose line from the hero crosses no wall (or INF).
static func clear_spot(w: World, dist: float) -> Vector2:
	var p := w.player_pos()
	for k in 16:
		var dir := Vector2.from_angle(TAU * k / 16.0)
		var to := p + dir * (dist + 1.0)
		var blocked := false
		for i in w.walls_along(p, to, 0.6):
			if Collide.sweep_vs_obb(p, to, 0.6, w.walls[i]) >= 0.0:
				blocked = true
				break
		if not blocked:
			return p + dir * dist
	return Vector2.INF


## Takes card `id` at the nearest altar (its offer forced: TEST HELPER), checking its slot tag. True when taken.
func take_at_altar(e: E2e, main: Main, id: StringName, others: Array) -> bool:
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	if i < 0:
		return false
	var offer := PackedInt32Array([_item(w, id)])
	for o: StringName in others:
		offer.append(_item(w, o))
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
	return w.items_owned.has(_item(w, id))


func test_the_laser_taken_at_an_altar_burns_an_enemy_while_held() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(
		await take_at_altar(e, main, &"gun_laser", [&"gun_pierce", &"ember_core"]), "took the Laser"
	)
	assert_eq(AttackSlots.form_id(w), &"laser", "the Gun's shot is the beam now")
	# TEST HELPER (labelled): a standing dummy 4 m away on a clear line (the floor's packs are other tests' job).
	var at := clear_spot(w, 4.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	w.dummy_speed = 0.0
	var dummy := w.add_dummy(at, 0.35, 5000)
	var cam := main.view.rig.camera
	var drawn := false
	var hummed := false
	# Right click held, then the mouse on the enemy at the aim plane's height (PlayerInput: SimPlane.CORE_HEIGHT), once:
	# the button's event and E2e.mouse_to's scale probe are mouse events of their own that move PlayerInput's mouse, so
	# the move comes last and isn't repeated.
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	for k in 90:
		await e.frames(1)
		drawn = drawn or main.view.laser.shown > 0
		hummed = hummed or main.audio.holding(&"laser_loop")
	var j := w.actors.index_of(dummy)
	assert_gte(j, 0)
	if j >= 0:
		gut.p(
			"LZ e2e: dummy hp %d / %d after 90 frames held" % [w.actors.hp[j], w.actors.max_hp[j]]
		)
		assert_lt(w.actors.hp[j], w.actors.max_hp[j], "the held beam burns the enemy")
	assert_true(drawn, "the beam is drawn")
	assert_true(hummed, "and hums")
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(4)
	assert_eq(main.view.laser.shown, 0, "let go: the beam is gone")
	assert_false(main.audio.holding(&"laser_loop"), "and silent")
