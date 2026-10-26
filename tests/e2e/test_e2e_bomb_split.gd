extends GutTest
## v0.9.5 FC2 (FORM_COMBOS.md B9) through the real game (main.tscn, input by Input.parse_input_event only): a Gun run
## takes the Bomb at an altar (E and the pick panel) and Split with the dev panel's Grant (real clicks), then holds the
## shoot button with the mouse on a standing dummy: the bomb bursts on it and throws bomblets 2 m out; one more dummy
## standing 3.2 m past the blast (outside the 2.2 m blast, inside a bomblet's 1.2 m) takes bomblet damage.

const W := preload("res://tests/support/mx4_world.gd")
const BombE2e := preload("res://tests/e2e/test_e2e_bomb.gd")


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


func test_a_split_bomb_throws_bomblets_that_hurt_enemies_2_m_off_the_blast() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await _take_at_altar(e, main, &"gun_bomb", [&"gun_twin"]), "took the Bomb")
	# TEST HELPER (labelled): the dev panel's Grant, by real clicks, takes Split.
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, w, &"split_shot")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(w.items_owned.has(W.item(w, &"split_shot")), "Split is in the wand")
	var s := Modifiers.bolt(w)
	assert_true(BombMods.mask(s) & BombMods.SPLIT != 0, "the bomb reads Split")
	assert_gte(BombMods.bomblet_count(s), 2, "its level sets the bomblets")
	# TEST HELPER (labelled): the floor's own enemies are cleared (they would shove the hero), then two standing
	# dummies stand on a clear line: one to burst on, two 3.2 m to either side of where it bursts.
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.dead[i] = 1
	var far := BombE2e.clear_spot(w, 7.5)
	assert_ne(far, Vector2.INF, "a clear line from the hero")
	if far == Vector2.INF:
		return
	var dir := (far - w.player_pos()).normalized()
	var at := w.player_pos() + dir * 4.0
	var burst := at - dir * 0.65
	w.dummy_speed = 0.0
	var cam := main.view.rig.camera
	# A mouse button event carries no position, so the first throw (on the press) goes where the cursor was; the cursor
	# then moves to the dummy's place, and the second throw (a second later) flies true. The dummies are placed once the
	# first bomb and its bomblets are done and the second is in the air.
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	var pressed := w.tick
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	while w.tick < pressed + 64:
		await e.frames(1)
	var ids := [
		w.add_dummy(at, 0.35, 5000),
		w.add_dummy(burst + dir * 3.2, 0.35, 5000),
	]
	var before := W.events(w, SimEvent.Kind.BLAST).size()
	var drew := false
	for n in 50:
		await e.frames(1)
		drew = drew or main.view.bombs.blasts >= 2
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var hurt := []
	for id: int in ids:
		var j := w.actors.index_of(id)
		hurt.append(j >= 0 and w.actors.hp[j] < w.actors.max_hp[j])
	var blasts := W.events(w, SimEvent.Kind.BLAST).size() - before
	for b in W.events(w, SimEvent.Kind.BLAST).slice(before):
		gut.p("blast at %s r %d (dummy %s, expected burst %s)" % [b.pos, b.amount, at, burst])
	gut.p(
		(
			"FC2 e2e: hurt %s, %d blasts after 50 frames held; two blasts drawn at once: %s"
			% [hurt, blasts, drew]
		)
	)
	assert_true(hurt[0], "the dummy the bomb burst on")
	assert_true(hurt[1], "the dummy 3.2 m past the blast (outside it) took a bomblet")
	assert_gte(blasts, 1 + BombMods.bomblet_count(s), "the blast and its bomblets")
	assert_true(drew, "the bomblets' blasts are drawn")
