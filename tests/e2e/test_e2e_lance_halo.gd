extends GutTest
## v0.9.5 FC4 (FORM_COMBOS.md N1) through the real game (main.tscn, input by Input.parse_input_event only): a Gun run
## takes the Lance at an altar (E and the pick panel) and Halo with the dev panel's Grant (real clicks), then holds the
## shoot button to a full charge with the mouse on a clear line and lets go. Six standing dummies sit 3 m from the hero,
## one every 60 degrees round it (only one on the aim line): the release fires six lances and all six are hurt.

const W := preload("res://tests/support/mx4_world.gd")


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## Takes card `id` at the nearest altar (its offer forced: TEST HELPER). True when taken.
func _take_at_altar(e: E2e, main: Main, id: StringName, others: Array) -> bool:
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	if i < 0:
		return false
	var offer := PackedInt32Array([W.item(w, id)])
	for o: StringName in others:
		offer.append(W.item(w, o))
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
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(70)
	return w.items_owned.has(W.item(w, id))


func _grant(e: E2e, main: Main, w: World, id: StringName) -> void:
	var k := W.item(w, id)
	var guard := 0
	while main.driver.debug.mod_choice != k and guard < 300:
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


## Lets go of the right button with the cursor at `pos` (a real release carries the cursor's position).
func _release_at(e: E2e, pos: Vector2) -> void:
	var scale: Vector2 = await e._mouse_scale()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = false
	ev.position = pos / scale
	ev.global_position = pos / scale
	e.send(ev)


## The six spots 3 m round `p`, the first on the angle `a0`, when every one is clear of walls and reachable in a line.
func _ring_spots(w: World, p: Vector2, a0: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in 6:
		var spot := p + Vector2.from_angle(a0 + k * TAU / 6.0) * 3.0
		for i in w.walls_along(p, spot, 0.7):
			if Collide.sweep_vs_obb(p, spot, 0.5, w.walls[i]) >= 0.0:
				return []
		for i in w.walls_along(spot, spot, 0.8):
			if Collide.circle_vs_obb(spot, 0.8, w.walls[i]) != Vector2.ZERO:
				return []
		out.append(spot)
	return out


func test_a_full_halo_charge_hurts_enemies_all_around_the_hero() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var start := w.player_pos()  # the floor's open start
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await _take_at_altar(e, main, &"gun_lance", [&"gun_twin"]), "took the Lance")
	# TEST HELPER (labelled): the dev panel's Grant, by real clicks, takes Halo.
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, w, &"halo_shot")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(w.items_owned.has(W.item(w, &"halo_shot")), "Halo is in the wand")
	assert_true(LanceMods.mask(Modifiers.bolt(w)) & LanceMods.HALO != 0, "the lance reads Halo")
	# TEST HELPER (labelled): the floor's own enemies are cleared (they would add damage of their own).
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.dead[i] = 1
	# TEST HELPER (labelled): the hero walks (real keys) to the nearest open place with a clear ring of six spots.
	var from := start
	var spots: Array[Vector2] = []
	var centre := from
	for d in [0.0, 3.0, 5.0, 7.0]:
		for k in 16:
			var c: Vector2 = from + Vector2.from_angle(TAU * k / 16.0) * d
			for r in 6:
				spots = _ring_spots(w, c, r * TAU / 12.0)
				if not spots.is_empty():
					break
			if not spots.is_empty():
				centre = c
				break
		if not spots.is_empty():
			break
	assert_eq(spots.size(), 6, "a clear ring of six spots round an open place")
	if spots.size() != 6:
		return
	assert_true(await e.walk_to(centre, 0.3), "walked to the middle of the ring")
	var hero := w.player_pos()
	for k in 6:
		spots[k] += hero - centre
	w.dummy_speed = 0.0
	var ids: Array[int] = []
	for s in spots:
		ids.append(w.add_dummy(s, 0.35, 5000))
	var cam := main.view.rig.camera
	var at := spots[0]
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	for k in 100:  # a full charge is 72 ticks
		await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	var charge := main.view.reader.lance_charge()
	await _release_at(e, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	var most := 0
	for k in 40:
		await e.frames(1)
		most = maxi(most, w.projectiles.size())
	var a := w.actors
	var hurt := []
	for id in ids:
		var j := a.index_of(id)
		hurt.append(j >= 0 and a.hp[j] < a.max_hp[j])
	gut.p(
		(
			"FC4 e2e: charge %.2f; lances in the air at most %d; the six dummies hurt %s"
			% [charge, most, hurt]
		)
	)
	assert_gt(charge, 0.9, "it charged while held")
	assert_gte(most, 6, "six lances fly")
	for h: bool in hurt:
		assert_true(h, "every dummy round the hero was hurt")
