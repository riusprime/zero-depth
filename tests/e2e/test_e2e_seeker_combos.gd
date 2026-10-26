extends GutTest
## v0.9.5 FC7 (FORM_COMBOS.md S1, S6) through the real game (main.tscn, input by Input.parse_input_event only): a Gun
## run takes the Seekers at an altar (E and the pick panel) and Twin and Echo with the dev panel's Grant (real clicks;
## Twin is a Pattern card and Echo a Secondary one), then holds the shoot button with the mouse on a clear line. Four
## standing dummies sit 3 m from the hero, one every 90 degrees round it: Twin's six darts curve to the three ahead
## and beside the hero (the one behind is a 180-degree turn away), they are hurt, and at least six darts are drawn.

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


## Keeps the cursor at `pos` for one frame (a form whose period is even would otherwise always fire on the probe).
func _hover(e: E2e, scale: Vector2, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos / scale
	ev.global_position = pos / scale
	e.send(ev)
	await e.frames(1)


## The four spots 3 m round `p`, the first on the angle `a0`, when every one is clear of walls and reachable in a line
## (the darts curve up to 10 m: the line out to 4 m is clear too).
func _cross_spots(w: World, p: Vector2, a0: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in 4:
		var spot := p + Vector2.from_angle(a0 + k * TAU / 4.0) * 3.0
		var far := p + Vector2.from_angle(a0 + k * TAU / 4.0) * 4.0
		for i in w.walls_along(p, far, 0.7):
			if Collide.sweep_vs_obb(p, far, 0.5, w.walls[i]) >= 0.0:
				return []
		for i in w.walls_along(spot, spot, 0.8):
			if Collide.circle_vs_obb(spot, 0.8, w.walls[i]) != Vector2.ZERO:
				return []
		out.append(spot)
	return out


func test_twin_and_echo_hurt_enemies_all_around_the_hero() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var start := w.player_pos()  # the floor's open start
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await _take_at_altar(e, main, &"gun_seekers", [&"gun_pierce"]), "took the Seekers")
	# TEST HELPER (labelled): the dev panel's Grant, by real clicks, takes Twin and Echo.
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, w, &"gun_twin")
	await _grant(e, main, w, &"gun_echo")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(w.items_owned.has(W.item(w, &"gun_twin")), "Twin is in the wand")
	assert_true(w.items_owned.has(W.item(w, &"gun_echo")), "Echo is in the wand")
	var mask := SeekerMods.mask(Modifiers.bolt(w))
	assert_true(mask & SeekerMods.TWIN != 0, "the darts read Twin")
	assert_true(mask & SeekerMods.ECHO != 0, "and Echo")
	# TEST HELPER (labelled): the floor's own enemies are cleared (they would add damage of their own).
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.dead[i] = 1
	# TEST HELPER (labelled): the hero walks (real keys) to the nearest open place with a clear cross of four spots.
	var spots: Array[Vector2] = []
	var centre := start
	for d in [0.0, 3.0, 5.0, 7.0]:
		for k in 16:
			var c: Vector2 = start + Vector2.from_angle(TAU * k / 16.0) * d
			for r in 6:
				spots = _cross_spots(w, c, r * TAU / 24.0)
				if not spots.is_empty():
					break
			if not spots.is_empty():
				centre = c
				break
		if not spots.is_empty():
			break
	assert_eq(spots.size(), 4, "a clear cross of four spots round an open place")
	if spots.size() != 4:
		return
	assert_true(await e.walk_to(centre, 0.3), "walked to the middle of the cross")
	var hero := w.player_pos()
	for k in 4:
		spots[k] += hero - centre
	w.dummy_speed = 0.0
	var ids: Array[int] = []
	for s in spots:
		ids.append(w.add_dummy(s, 0.35, 5000))
	var cam := main.view.rig.camera
	var scale: Vector2 = await e._mouse_scale()
	var at := hero + (spots[0] - hero) * 2.0
	var pix := cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT))
	await e.mouse_to(pix)
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	var darts := 0
	for k in 70:
		await _hover(e, scale, pix)
		darts = maxi(darts, main.view.seekers.darts)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(60)
	var a := w.actors
	var hurt := []
	for id in ids:
		var j := a.index_of(id)
		hurt.append(j >= 0 and a.hp[j] < a.max_hp[j])
	gut.p("FC7 e2e: most darts drawn %d; the four dummies hurt %s" % [darts, hurt])
	assert_gte(darts, 6, "six darts are drawn")
	# the dummy straight behind the aim (index 2) is a turn of 180 degrees away, past a dart's 1.6 m circle: not asserted
	for k in [0, 1, 3]:
		assert_true(hurt[k], "the dummy ahead and the two beside the hero were hurt (%d)" % k)
