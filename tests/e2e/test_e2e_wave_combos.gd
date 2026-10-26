extends GutTest
## v0.9.5 FC8 (FORM_COMBOS.md W3, W4) through the real game (main.tscn, input by Input.parse_input_event only): a Gun
## run takes the Wave at an altar (E and the pick panel) and Big Shot and Echo with the dev panel's Grant (real clicks;
## both are Secondary cards, limit 2), then holds the shoot button with the mouse on a clear line. A standing dummy sits
## 5 m out and 2.4 m off the aim line, where only a 5 m wide wave reaches (a plain 3 m one stops at 1.85 m): it is
## hurt twice (the wave at 48, its echo at 24), and two waves are drawn at once.

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


## Keeps the cursor at `pos` for one frame.
func _hover(e: E2e, scale: Vector2, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos / scale
	ev.global_position = pos / scale
	e.send(ev)
	await e.frames(1)


## The point is clear of walls (a 0.8 m circle).
func _open(w: World, p: Vector2) -> bool:
	for i in w.walls_along(p, p, 0.8):
		if Collide.circle_vs_obb(p, 0.8, w.walls[i]) != Vector2.ZERO:
			return false
	return true


## From `p` along the angle `a`: a 9 m strip 6.4 m wide is clear of walls (sampled every metre).
func _strip_clear(w: World, p: Vector2, a: float) -> bool:
	var dir := Vector2.from_angle(a)
	var side := Vector2(-dir.y, dir.x)
	for d in range(1, 10):
		for s in [-3.2, 0.0, 3.2]:
			if not _open(w, p + dir * d + side * s):
				return false
	return true


func test_big_shot_and_echo_hurt_a_dummy_only_a_wide_wave_reaches() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var start := w.player_pos()  # the floor's open start
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await _take_at_altar(e, main, &"gun_wave", [&"gun_twin"]), "took the Wave")
	# TEST HELPER (labelled): the dev panel's Grant, by real clicks, takes Big Shot and Echo.
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, w, &"gun_big_shot")
	await _grant(e, main, w, &"gun_echo")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(w.items_owned.has(W.item(w, &"gun_big_shot")), "Big Shot is in the wand")
	assert_true(w.items_owned.has(W.item(w, &"gun_echo")), "Echo is in the wand")
	var mask := WaveMods.mask(Modifiers.bolt(w))
	assert_true(mask & WaveMods.BIG != 0, "the wave reads Big Shot")
	assert_true(mask & WaveMods.ECHO != 0, "and Echo")
	# TEST HELPER (labelled): the floor's own enemies are cleared (they would add damage of their own).
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.dead[i] = 1
	# TEST HELPER (labelled): the hero walks (real keys) to the nearest open place with a clear strip along some aim.
	var centre := start
	var angle := 0.0
	var found := false
	for d in [0.0, 3.0, 5.0, 7.0]:
		for k in 16:
			var c: Vector2 = start + Vector2.from_angle(TAU * k / 16.0) * d
			for r in 12:
				if _open(w, c) and _strip_clear(w, c, r * TAU / 12.0):
					centre = c
					angle = r * TAU / 12.0
					found = true
					break
			if found:
				break
		if found:
			break
	assert_true(found, "a clear strip along some aim from an open place")
	if not found:
		return
	assert_true(await e.walk_to(centre, 0.3), "walked to the start of the strip")
	var hero := w.player_pos()
	var dir := Vector2.from_angle(angle)
	var side := Vector2(-dir.y, dir.x)
	w.dummy_speed = 0.0
	var id := w.add_dummy(hero + dir * 5.0 + side * 2.4, 0.35, 5000)
	var cam := main.view.rig.camera
	var scale: Vector2 = await e._mouse_scale()
	var pix := cam.unproject_position(SimPlane.to_3d(hero + dir * 2.0, SimPlane.CORE_HEIGHT))
	await e.mouse_to(pix)
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	var drawn := 0
	for k in 60:
		await _hover(e, scale, pix)
		drawn = maxi(drawn, main.view.waves.waves)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(90)
	var a := w.actors
	var j := a.index_of(id)
	var lost: int = a.max_hp[j] - a.hp[j] if j >= 0 else 0
	gut.p("FC8 e2e: most waves drawn %d; the dummy lost %d of 5000" % [drawn, lost])
	assert_gte(drawn, 2, "the wave and its echo are drawn together")
	assert_gte(lost, 48 + 24, "hit by the 5 m wave (48) and by its echo (24)")
