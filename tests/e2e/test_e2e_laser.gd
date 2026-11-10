extends GutTest
## v0.9.0 LZ (owner C §6.2, Q8; PLAN C48) through the real game (main.tscn, input by Input.parse_input_event only): a
## Gun run walks to an altar and opens it with E; its Laser card reads "Form"; Enter takes it and the Gun's shot is the
## beam. Holding the shoot button (right click) with the mouse on an enemy, the beam draws to it, hums, and the enemy
## takes damage; letting go, the beam is gone.


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _item(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


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


func test_the_laser_taken_at_an_altar_burns_an_enemy_while_held() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(
		await take_at_altar(e, main, &"gun_laser", [&"gun_pierce", &"ember_core"]), "took the Laser"
	)
	assert_eq(AttackSlots.form_id(w), &"laser", "the Gun's shot is the beam now")
	# TEST HELPER (labelled): a standing dummy 4 m away on a clear line (the floor's packs are other tests' job).
	var at := clear_spot(w, 4.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	w.dummy_speed = 0.0
	var dummy := w.add_dummy(at, 0.35, 5000)
	var cam := main.view.rig.camera
	var drawn := false
	var hummed := false
	# Right click held, then the mouse on the enemy at the aim plane's height (PlayerInput: SimPlane.CORE_HEIGHT), once:
	# the button's event and E2e.mouse_to's scale probe are mouse events of their own that move PlayerInput's mouse, so
	# the move comes last and isn't repeated.
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	for k in 220:  # v0.11.0 O1: past the 3 s cooldown, so a shot fires with the aim on the enemy
		await e.frames(1)
		drawn = drawn or main.view.laser.shown > 0
		hummed = hummed or main.audio.holding(&"laser_loop")
	var j := w.actors.index_of(dummy)
	assert_gte(j, 0)
	if j >= 0:
		gut.p(
			"O1 e2e: dummy hp %d / %d after 220 frames held" % [w.actors.hp[j], w.actors.max_hp[j]]
		)
		assert_lt(w.actors.hp[j], w.actors.max_hp[j], "the held lance hits the enemy")
	assert_true(drawn, "the beam is drawn")
	assert_true(hummed, "and hums")
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(WorldReader.LANCE_GLOW_TICKS + 4)  # v0.11.0 O1 (Q7): the last shot's glow fades in 0.5 s
	assert_eq(main.view.laser.shown, 0, "let go: the lance is gone")
	assert_false(main.audio.holding(&"laser_loop"), "and silent")


## v0.11.0 O1 (owner Q4, Q28: "a 3 second cooldown"; PLAN L1): held, the Laser fires an instant lance every 3 s, each
## one drawn. The same run as above (the Laser taken at an altar with the keyboard; the standing dummy a TEST HELPER);
## right click held with the mouse on the dummy for four periods. The sim's firing ticks (read) are 3 s apart, and the
## view draws each lance as it fires.
func test_the_held_laser_fires_a_lance_every_3_seconds() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(
		await take_at_altar(e, main, &"gun_laser", [&"gun_pierce", &"ember_core"]), "took the Laser"
	)
	var at := clear_spot(w, 4.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	w.dummy_speed = 0.0  # TEST HELPER (labelled): a standing dummy, as above
	w.add_dummy(at, 0.35, 50000)
	var cam := main.view.rig.camera
	var period := SimTick.seconds_to_ticks(3.0)
	var fired := PackedInt32Array()
	var held := PackedInt32Array()  # the hit-stop ticks since the lance before (none for the first)
	var frozen := 0
	var drawn := 0
	var last := w.mx.lz_shot_tick
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	for k in period * 4 + 30:
		var stopped := w.freeze_ticks > 0  # this tick is hit-stop: the world, the cooldown too, holds
		await e.frames(1)
		if stopped and not fired.is_empty():
			frozen += 1
		if w.mx.lz_shot_tick != last:
			last = w.mx.lz_shot_tick
			fired.append(last)
			held.append(frozen)
			frozen = 0
		if not fired.is_empty() and main.view.laser.shown > 0 and drawn < fired.size():
			drawn = fired.size()
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	gut.p(
		(
			"O1 e2e: lance firing ticks %s, hit-stop ticks between %s (period %d ticks)"
			% [str(fired), str(held), period]
		)
	)
	assert_gte(fired.size(), 4, "four lances in four periods held")
	# Exactly every 3 s of the sim's clock. A hit-stop holds everything, the cooldown too (SIM_CONTRACTS), so its
	# ticks don't count: the floor's own enemies may touch the hero meanwhile (God ends when the dev panel closes). A
	# Swarmer's touch did (4 ticks of hurt hit-stop), which made the first gap 184 (fix1, 2026-11-08).
	for k in range(1, fired.size()):
		assert_eq(
			fired[k] - fired[k - 1] - held[k],
			period,
			"lance %d came 3 s (hit-stop aside) after the one before" % k
		)
	assert_eq(drawn, fired.size(), "every lance was drawn")
