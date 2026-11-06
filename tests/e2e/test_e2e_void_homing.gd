extends GutTest
## v0.9.5 FC3 (FORM_COMBOS.md V4) through the real game (main.tscn, input by Input.parse_input_event only): a Gun run
## takes the Void at an altar (E and the pick panel) and Homing with the dev panel's Grant (real clicks), then holds the
## shoot button with the mouse on a clear line. Four standing dummies sit in a group 3 m to the side of that line, well
## outside a plain void's 1.0 m aura (and its pull leaves them outside it): the homing void drifts toward the group and
## damages all four.

const W := preload("res://tests/support/mx4_world.gd")
const VoidE2e := preload("res://tests/e2e/test_e2e_void.gd")


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


func test_a_homing_void_drifts_to_a_group_off_the_aim_and_damages_it() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await _take_at_altar(e, main, &"gun_void", [&"gun_twin"]), "took the Void")
	# TEST HELPER (labelled): the dev panel's Grant, by real clicks, takes Homing.
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, w, &"gun_homing")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(w.items_owned.has(W.item(w, &"gun_homing")), "Homing is in the wand")
	assert_true(VoidMods.mask(Modifiers.bolt(w)) & VoidMods.HOMING != 0, "the void reads Homing")
	# TEST HELPER (labelled): the floor's own enemies are cleared (they would shove the hero and feed the pull).
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.dead[i] = 1
	var far: Vector2 = VoidE2e.clear_spot(w, 6.0)
	assert_ne(far, Vector2.INF, "a clear line from the hero")
	if far == Vector2.INF:
		return
	var hero := w.player_pos()
	var dir := (far - hero).normalized()
	var side := dir.orthogonal()
	var centre := hero + dir * 5.0 + side * 3.0
	if not _free(w, centre):
		side = -side
		centre = hero + dir * 5.0 + side * 3.0
	assert_true(_free(w, centre), "a clear spot for the group")
	w.dummy_speed = 0.0
	var group: Array[int] = []
	for off: Vector2 in [Vector2(0, 0), Vector2(0.6, 0), Vector2(0, 0.6), Vector2(0.6, 0.6)]:
		group.append(w.add_dummy(centre + dir * off.x + side * off.y, 0.35, 5000))
	var cam := main.view.rig.camera
	var drawn := 0
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(far, SimPlane.CORE_HEIGHT)))
	for k in 150:
		await e.frames(1)
		drawn = maxi(drawn, main.view.voids.voids)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var a := w.actors
	var hurt := []
	for id: int in group:
		var j := a.index_of(id)
		hurt.append(j >= 0 and a.hp[j] < a.max_hp[j])
	gut.p("FC3 e2e: the four dummies hurt %s, voids drawn at most %d" % [hurt, drawn])
	for h: bool in hurt:
		assert_true(h, "a dummy of the group off the aim was damaged by the homing void")
	assert_gt(drawn, 0, "the void is drawn in flight")
