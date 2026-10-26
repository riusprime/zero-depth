extends GutTest
## v0.9.5 EE2 (ELEMENTS.md E5) through the real game (main.tscn, input by Input.parse_input_event only): a Gun run takes
## the Frost card at an altar and again at the dev panel (real clicks) until it is Lv 3, and shoots a standing dummy
## with the shoot button held: the third stack freezes it, the next hit shatters it, and a dummy beside it that no bolt
## touches takes a shard.

const W := preload("res://tests/support/mx4_world.gd")


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## The altar nearest the hero (its index), or -1.
func _altar(w: World) -> int:
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] != RewardStore.Kind.ALTAR or Arenas.locked(w, i):
			continue
		if (
			best < 0
			or (
				w.rewards.pos(i).distance_to(w.player_pos())
				< w.rewards.pos(best).distance_to(w.player_pos())
			)
		):
			best = i
	return best


func test_frost_at_level_three_shatters_and_a_shard_hits_the_neighbour() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var k := W.item(w, &"frost_core")
	var i := _altar(w)
	assert_gte(i, 0, "an altar on the floor")
	if i < 0:
		return
	# The altar's offer is forced to Frost (TEST HELPER); the take itself is the real E key and pick panel.
	w.rewards.set_offer(i, PackedInt32Array([k, W.item(w, &"gun_twin")]))
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	var panel := hud.pick_panel()
	assert_true(panel.is_open(), "E opened the altar")
	for n in 240:
		if panel.deal.done():
			break
		await e.frames(1)
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(70)
	assert_true(w.items_owned.has(k), "took Frost")
	# TEST HELPER (labelled): floor 1 has one altar; the dev panel's Grant (real clicks) takes it again, to Lv 3.
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var guard := 0
	while main.driver.debug.mod_choice != k and guard < 300:
		await _click(e, main, "NextMod")
		guard += 1
	for n in 2:
		await _click(e, main, "GrantMod")
		await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_eq(CardLevels.level(w, k), 3, "Frost Lv 3")
	# TEST HELPER (labelled): two standing dummies 4 m away on a clear line, 1.5 m apart across it.
	var bomb := load("res://tests/e2e/test_e2e_bomb.gd")
	var at: Vector2 = bomb.clear_spot(w, 4.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var side := (at - w.player_pos()).normalized().orthogonal()
	w.dummy_speed = 0.0
	var target := w.add_dummy(at, 0.35, 90000)
	var beside := w.add_dummy(at + side * 1.5, 0.35, 90000)
	var cam := main.view.rig.camera
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	for n in 420:
		await e.frames(1)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var pid := w.actors.ids[0]
	var bolts_on_beside := 0
	var shards := 0
	var shatters := 0
	for ev in w.events_since(0):
		if ev.kind == SimEvent.Kind.DAMAGE and ev.owner_id == pid and ev.target_id == beside:
			if ev.effect_id == SimEvent.EFFECT_FROST_SHARD:
				shards += 1
			elif not (ev.tags & SimEvent.TAG_DOT):
				bolts_on_beside += 1
		if ev.kind == SimEvent.Kind.STATUS_APPLY and ev.effect_id == SimEvent.EFFECT_FROST_SHATTER:
			if ev.target_id == target:
				shatters += 1
	gut.p(
		(
			"EE2 e2e: %d shatters, %d shards on the neighbour, %d bolts on it"
			% [shatters, shards, bolts_on_beside]
		)
	)
	assert_gt(shatters, 0, "the frozen dummy shattered")
	assert_gt(shards, 0, "the neighbour took a shard")
	assert_eq(bolts_on_beside, 0, "and no bolt touched it")
