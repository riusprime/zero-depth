extends GutTest
## v0.9.0 VP (owner C §6.4, Q10; PLAN C54–C58) through the real game (main.tscn, input by Input.parse_input_event only):
## a Gun run walks to an altar and opens it with E; its Void card reads "Form"; Enter takes it and the Gun's shot is the
## Void. Holding the shoot button (right click) with the mouse on a group of enemies, the Void shots fly (drawn as
## lensing spheres, heard), pass through the one on their path hurting it, and the two beside the path drift toward it
## (subtly: still well off it). The old floor black hole is never offered.


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _item(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## (as test_e2e_bomb.gd's)
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


## The distance from `p` to the line from `a` along `dir` (unit).
static func _off(p: Vector2, a: Vector2, dir: Vector2) -> float:
	var d := p - a
	return absf(d.x * dir.y - d.y * dir.x)


func test_the_void_taken_at_an_altar_hurts_its_path_and_tugs_the_group() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(
		await take_at_altar(e, main, &"gun_void", [&"gun_twin", &"ember_core"]), "took the Void"
	)
	assert_eq(AttackSlots.form_id(w), &"void", "the Gun's shot is the Void now")
	assert_does_not_have(
		ItemPool.available(w),
		AttackScenario.item_index(w.item_tables, &"gravity_well"),
		"the old floor black hole is never offered"
	)
	# TEST HELPER (labelled): three standing dummies 5 m away on a clear line: one on the path, two 1.9 m beside it.
	var at: Vector2 = clear_spot(w, 5.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var hero := w.player_pos()
	var dir := (at - hero).normalized()
	var side := dir.orthogonal()
	w.dummy_speed = 0.0
	var group: Array[int] = []
	for off in [0.0, 1.9, -1.9]:
		group.append(w.add_dummy(at + side * off, 0.35, 5000))
	var cam := main.view.rig.camera
	var drawn := 0
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	for k in 150:
		await e.frames(1)
		drawn = maxi(drawn, main.view.voids.voids)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var a := w.actors
	var mid := a.index_of(group[0])
	assert_lt(a.hp[mid], a.max_hp[mid], "the one on the path is hurt")
	var drift := []
	for k in [1, 2]:
		var j := a.index_of(group[k])
		drift.append(1.9 - _off(a.pos(j), hero, dir))
	(
		gut
		. p(
			(
				"VP e2e: on-path dummy hp %d / %d; the side ones drifted %.2f m and %.2f m toward the path in 150 frames"
				% [a.hp[mid], a.max_hp[mid], drift[0], drift[1]]
			)
		)
	)
	for d: float in drift:
		assert_gt(d, 0.1, "a side dummy drifted toward the path")
		assert_lt(d, 1.4, "subtly: it isn't dragged onto it")
	assert_gt(drawn, 0, "a Void shot is drawn in flight")
	assert_true(main.audio.played_log.has(&"void_hum"), "its hum is heard")
