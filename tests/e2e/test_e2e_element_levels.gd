extends GutTest
## v0.9.5 EE1 (ELEMENTS.md E1) through the real game (main.tscn, input by Input.parse_input_event only): a Gun run
## takes the Venom card at an altar, then again at another altar (Lv 2: Contagion), and shoots a standing group with
## the shoot button held; poison reaches an enemy the bolt never touched.

const W := preload("res://tests/support/mx4_world.gd")


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## The altar nearest the hero that is not in `used` (its index), or -1.
func _altar(w: World, used: Array) -> int:
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] != RewardStore.Kind.ALTAR or used.has(i) or Arenas.locked(w, i):
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


## Takes Venom at altar `i` (its offer forced: TEST HELPER). True when the card's level or ownership moved.
func _take_venom(e: E2e, main: Main, i: int) -> bool:
	var w := e.world()
	var k := W.item(w, &"venom_core")
	var before := CardLevels.level(w, k) if w.items_owned.has(k) else 0
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
	return w.items_owned.has(k) and CardLevels.level(w, k) > before


func test_venom_at_level_two_spreads_to_an_enemy_the_bolt_never_touched() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var k := W.item(w, &"venom_core")
	var a1 := _altar(w, [])
	assert_gte(a1, 0, "an altar on the floor")
	if a1 < 0:
		return
	assert_true(await _take_venom(e, main, a1), "took Venom")
	assert_eq(CardLevels.level(w, k), 1)
	var a2 := _altar(w, [a1])
	if a2 >= 0:
		assert_true(await _take_venom(e, main, a2), "took Venom again")
	else:  # TEST HELPER (labelled): floor 1 has one altar; the dev panel's Grant (real clicks) is the second take
		await e.tap(KEY_QUOTELEFT)
		await e.frames(2)
		var guard := 0
		while main.driver.debug.mod_choice != k and guard < 300:
			await _click(e, main, "NextMod")
			guard += 1
		await _click(e, main, "GrantMod")
		await e.frames(3)
		await e.tap(KEY_QUOTELEFT)
		await e.frames(2)
	assert_eq(CardLevels.level(w, k), 2, "Venom Lv 2")
	# TEST HELPER (labelled): three standing dummies 4 m away on a clear line, 1.5 m apart across it.
	var bomb := load("res://tests/e2e/test_e2e_bomb.gd")
	var at: Vector2 = bomb.clear_spot(w, 4.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var side := (at - w.player_pos()).normalized().orthogonal()
	w.dummy_speed = 0.0
	var group: Array[int] = [
		w.add_dummy(at, 0.35, 9000),
		w.add_dummy(at + side * 1.5, 0.35, 9000),
		w.add_dummy(at + side * 3.0, 0.35, 9000),
	]
	var cam := main.view.rig.camera
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	for n in 420:
		await e.frames(1)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var pid := w.actors.ids[0]
	var hit := {}
	for ev in w.events_since(0):
		if (
			ev.kind == SimEvent.Kind.DAMAGE
			and ev.owner_id == pid
			and not (ev.tags & SimEvent.TAG_DOT)
		):
			hit[ev.target_id] = true
	var spread := 0
	for id in group:
		var j := w.actors.index_of(id)
		if j >= 0 and w.actors.poison_stacks[j] > 0 and not hit.has(id):
			spread += 1
	gut.p("EE1 e2e: %d poisoned dummies never hit by a bolt; %d jumps" % [spread, _jumps(w)])
	assert_gt(_jumps(w), 0, "a Contagion jump happened")
	assert_gte(spread, 1, "poison reached an enemy that was never hit")


func _jumps(w: World) -> int:
	var n := 0
	for ev in w.events_since(0):
		if ev.kind == SimEvent.Kind.STATUS_APPLY and ev.effect_id == SimEvent.EFFECT_VENOM_JUMP:
			n += 1
	return n
