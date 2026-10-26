extends GutTest
## v0.9.0 BM (owner C §6.3, Q9; PLAN C51) through the real game (main.tscn, input by Input.parse_input_event only): a
## Gun run walks to an altar and opens it with E; its Bomb card reads "Form"; Enter takes it and the Gun's shot is the
## bomb. Holding the shoot button (right click) with the mouse on a group of enemies, a bomb flies (drawn as a bomb),
## bursts on them (its ring drawn, its blast heard) and several take damage.


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
			if (
				Collide.circle_vs_obb(p, 0.6, w.walls[i]) != Vector2.ZERO
				and Collide.circle_vs_obb(p + dir * 1.0, 0.6, w.walls[i]) == Vector2.ZERO
			):
				continue  # v0.9.5 SB: a prop the hero stands against (an altar), when the line leads away from it
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


func test_the_bomb_taken_at_an_altar_bursts_on_a_group() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(
		await take_at_altar(e, main, &"gun_bomb", [&"gun_twin", &"ember_core"]), "took the Bomb"
	)
	assert_eq(AttackSlots.form_id(w), &"bomb", "the Gun's shot is the bomb now")
	# TEST HELPER (labelled): a group of three standing dummies 4 m away on a clear line.
	var at := clear_spot(w, 4.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var side := (at - w.player_pos()).normalized().orthogonal()
	w.dummy_speed = 0.0
	var group: Array[int] = []
	for off in [0.0, 1.1, -1.1]:
		group.append(
			w.add_dummy(
				at + side * off + (at - w.player_pos()).normalized() * absf(off) * 0.4, 0.35, 5000
			)
		)
	var cam := main.view.rig.camera
	var flew := false
	var rang := false
	# Right click held, then the mouse on the group (see test_e2e_laser: the move comes last, once).
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	for k in 90:
		await e.frames(1)
		flew = flew or main.view.bombs.bombs > 0
		rang = rang or main.view.bombs.blasts > 0
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var hurt := 0
	for id in group:
		var j := w.actors.index_of(id)
		if j >= 0 and w.actors.hp[j] < w.actors.max_hp[j]:
			hurt += 1
	gut.p("BM e2e: %d of 3 dummies hurt after 90 frames held" % hurt)
	assert_gte(hurt, 2, "the blast hits several")
	assert_true(flew, "a bomb is drawn in flight")
	assert_true(rang, "its blast ring is drawn")
	assert_true(main.audio.played_log.has(&"bomb_throw"), "the toss is heard")
	assert_true(main.audio.played_log.has(&"bomb_blast"), "and the blast")
