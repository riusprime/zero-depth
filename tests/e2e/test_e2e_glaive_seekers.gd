extends GutTest
## v0.9.0 AF2 (owner Q7; ATTACK_FORMS.md F7, F8) through the real game (main.tscn, input by Input.parse_input_event
## only): a Gun run walks to an altar and opens it with E; the card reads "Form"; Enter takes it.
## - The Glaive: holding the shoot button (right click) with the mouse past an enemy throws spinning discs (drawn, and
##   drawn coming back, heard) that hurt it going out and coming back.
## - The Seekers: holding the shoot button with the mouse ahead throws volleys of darts (drawn with their trails,
##   heard) that curve to three enemies, one ahead and two off the aim, and hurt all three.
## The retired Boomerang card is never offered.

const E2eVoid := preload("res://tests/e2e/test_e2e_void.gd")


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## (as test_e2e_lance_scatter.gd's) Takes card `id` at the nearest altar (its offer forced: TEST HELPER), checking
## its slot tag. True when taken.
func _take_at_altar(e: E2e, main: Main, id: StringName, others: Array) -> bool:
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	if i < 0:
		return false
	var offer := PackedInt32Array([AttackScenario.item_index(w.item_tables, id)])
	for o: StringName in others:
		offer.append(AttackScenario.item_index(w.item_tables, o))
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
	return w.items_owned.has(AttackScenario.item_index(w.item_tables, id))


## Boots a Gun run in god mode and takes card `id` at an altar.
func _boot_with(e: E2e, id: StringName) -> Main:
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await _take_at_altar(e, main, id, [&"gun_twin", &"ember_core"]), "took %s" % id)
	return main


## Keeps the cursor at `pos` for one frame. (E2e.mouse_to probes the cursor at (100, 100) first, every call: for one
## tick in each frame the hero aims there, and a form whose period is an even number of ticks always fired on it.)
func _hover(e: E2e, scale: Vector2, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos / scale
	ev.global_position = pos / scale
	e.send(ev)
	await e.frames(1)


## Damage events on actor `id` so far (not DoT).
func _hits(w: World, id: int) -> int:
	var n := 0
	for ev in w.events_since(0):
		if (
			ev.kind == SimEvent.Kind.DAMAGE
			and ev.target_id == id
			and ev.source_id != 0  # discs only: a hero-sourced hit is a proc
			and not (ev.tags & SimEvent.TAG_DOT)
		):
			n += 1
	return n


func test_the_glaive_flies_out_and_back_through_an_enemy() -> void:
	var e := E2e.new(self)
	var main := await _boot_with(e, &"gun_glaive")
	var w := e.world()
	assert_eq(AttackSlots.form_id(w), &"glaive", "the Gun's shot is the Glaive now")
	assert_does_not_have(
		ItemPool.available(w),
		AttackScenario.item_index(w.item_tables, &"boomerang"),
		"the retired Boomerang card is never offered"
	)
	# TEST HELPER (labelled): a standing dummy 3 m out on a clear line, the mouse 7 m out past it.
	var at: Vector2 = E2eVoid.clear_spot(w, 7.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var hero := w.player_pos()
	var dir := (at - hero).normalized()
	w.dummy_speed = 0.0
	var foe := w.add_dummy(hero + dir * 3.0, 0.35, 5000)
	var cam := main.view.rig.camera
	var scale: Vector2 = await e._mouse_scale()
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	var discs := 0
	var back := 0
	for k in 100:
		await _hover(e, scale, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
		discs = maxi(discs, main.view.glaives.discs)
		back = maxi(back, main.view.glaives.returning)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(60)
	var a := w.actors
	var j := a.index_of(foe)
	var hits := _hits(w, foe)
	(
		gut
		. p(
			(
				"AF2 e2e Glaive: the enemy at 3 m took %d in %d hits; most discs drawn %d, coming back %d"
				% [a.max_hp[j] - a.hp[j], hits, discs, back]
			)
		)
	)
	assert_gte(hits, 2, "hit going out and coming back")
	assert_eq(hits % 2, 0, "every disc hit it both ways")
	assert_gt(discs, 0, "the disc is drawn")
	assert_gt(back, 0, "and drawn coming back")
	assert_true(main.audio.played_log.has(&"glaive_throw"), "its throw is heard")


func test_the_seekers_curve_onto_three_enemies() -> void:
	var e := E2e.new(self)
	var main := await _boot_with(e, &"gun_seekers")
	var w := e.world()
	assert_eq(AttackSlots.form_id(w), &"seekers", "the Gun's shot is the Seekers now")
	# TEST HELPER (labelled): three standing dummies, one 3.5 m ahead on a clear line and two 2.5 m out, 1.2 m either
	# side of the aim.
	var at: Vector2 = E2eVoid.clear_spot(w, 7.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var hero := w.player_pos()
	var dir := (at - hero).normalized()
	var side := Vector2(-dir.y, dir.x)
	w.dummy_speed = 0.0
	var foes: Array[int] = [
		w.add_dummy(hero + dir * 3.5, 0.35, 5000),
		w.add_dummy(hero + dir * 2.5 + side * 1.2, 0.35, 5000),
		w.add_dummy(hero + dir * 2.5 - side * 1.2, 0.35, 5000),
	]
	var cam := main.view.rig.camera
	var scale: Vector2 = await e._mouse_scale()
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	var darts := 0
	var motes := 0
	for k in 90:
		await _hover(e, scale, cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
		darts = maxi(darts, main.view.seekers.darts)
		motes = maxi(motes, main.view.seekers.motes)
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(30)
	var hits := []
	for id in foes:
		hits.append(_hits(w, id))
	(
		gut
		. p(
			(
				"AF2 e2e Seekers: hits on the enemy ahead / left / right %s; most darts drawn %d, trail motes %d"
				% [hits, darts, motes]
			)
		)
	)
	for h: int in hits:
		assert_gt(h, 0, "every one of the three is hit")
	assert_gt(darts, 0, "the darts are drawn")
	assert_gt(motes, 0, "with their trails")
	assert_true(main.audio.played_log.has(&"seekers_fire"), "the volley is heard")
