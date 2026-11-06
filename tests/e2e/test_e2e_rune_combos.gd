extends GutTest
## v0.9.5 FC5 (FORM_COMBOS.md R6, R8) through the real game (main.tscn, Input.parse_input_event only): a Gun run
## takes the Rune Explosion at an altar (E and the pick panel), then Big Shot and Split with the dev panel's Grant (real
## clicks), and holds the shoot button. A dummy stands 4.6 m out, past a plain burst's 3.5 m (Big Shot's 5 m reaches
## it), and two more stand 3 m from it at plus and minus 30 degrees about the hero-to-dummy line, past even Big Shot's
## reach: only Split's shards, thrown off the first dummy, can hurt them.

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


## `p` is clear of every wall (a 0.6 m body fits).
func _free(w: World, p: Vector2) -> bool:
	for i in w.walls_along(p, p, 0.8):
		if Collide.circle_vs_obb(p, 0.8, w.walls[i]) != Vector2.ZERO:
			return false
	return true


func test_big_shot_and_split_reach_a_dummy_past_the_plain_burst_and_two_off_the_line() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(
		await _take_at_altar(e, main, &"gun_rune_explosion", [&"gun_twin"]),
		"took the Rune Explosion"
	)
	# TEST HELPER (labelled): the dev panel's Grant, by real clicks, takes the two cards.
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, w, &"gun_big_shot")
	await _grant(e, main, w, &"split_shot")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var mask := RuneMods.mask(Modifiers.bolt(w))
	assert_true(
		mask & RuneMods.BIG != 0 and mask & RuneMods.SPLIT != 0, "the burst reads both cards"
	)
	# TEST HELPER (labelled): the floor's own enemies are cleared (they would shove the hero and take the hits).
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.dead[i] = 1
	var hero := w.player_pos()
	var dir := Vector2.ZERO
	for k in 16:  # the first direction whose three dummy spots are clear
		var d := Vector2.from_angle(TAU * k / 16.0)
		var f := hero + d * 4.6
		var ok := true
		for q: Vector2 in [f, f + d.rotated(0.5236) * 3.0, f + d.rotated(-0.5236) * 3.0]:
			ok = ok and _free(w, q)  # (the bursts and shards pass through walls in the sim)
		if ok:
			dir = d
			break
	assert_ne(dir, Vector2.ZERO, "a clear place for the three dummies")
	if dir == Vector2.ZERO:
		return
	var far := hero + dir * 8.0
	var first := hero + dir * 4.6
	var up := first + dir.rotated(0.5236) * 3.0
	var down := first + dir.rotated(-0.5236) * 3.0
	w.dummy_speed = 0.0
	var ids: Array[int] = []
	for p: Vector2 in [first, up, down]:
		ids.append(w.add_dummy(p, 0.35, 100000))
	var cam := main.view.rig.camera
	var drawn := 0
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(far, SimPlane.CORE_HEIGHT)))
	for k in 200:
		await e.frames(1)
		drawn = maxi(drawn, main.view.runes.shards)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var a := w.actors
	var hurt := []
	for id: int in ids:
		var j := a.index_of(id)
		hurt.append(j >= 0 and a.hp[j] < a.max_hp[j])
	gut.p("FC5 e2e: the dummies (4.6 m, +30, -30) hurt %s, shards drawn at most %d" % [hurt, drawn])
	assert_true(hurt[0], "Big Shot's 5 m reaches the first dummy")
	assert_true(hurt[1] and hurt[2], "Split's shards reach the two off the line")
	assert_gt(drawn, 0, "the shards are drawn in flight")
