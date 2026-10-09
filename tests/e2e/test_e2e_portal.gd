extends GutTest
## The portal's way in and the arrival (v0.3.5 PT; owner F19, F20), through main.tscn with real input only: the
## dev panel (backtick, mouse clicks: God mode for the long walk, Kill boss) stands in for the fight as in
## test_e2e_run_flow; the left stick walks through the boss door and into the open portal. The way in plays (the
## world holds, the stick does nothing, the hero shrinks into light), then floor 2 loads exactly once and opens on
## the arrival (held, the hero grows in its column) before the stick moves the hero again.
## v0.5.5 EC (owner Q-S4, "Keep half"): the portal carries half the unspent shards (rounded down) and floor 2's
## arrival card says how many it kept.

const LEG_FRAMES := 7000


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


## Walks the left stick along the flow field toward `target` until `done` is true (or the frame limit).
func _walk(e: E2e, target: Vector2, done: Callable, push: Vector2 = Vector2.ZERO) -> bool:
	var w := e.world()
	var nav := NavField.new()
	nav.build(E2e.walk_walls(w, target))
	nav.flood(target)
	for k in LEG_FRAMES:
		if done.call():
			break
		var p := w.player_pos()
		var dir := nav.direction(p)
		if (target - p).length() < 1.5 or dir == Vector2.ZERO:
			dir = (target - p).normalized() if (target - p).length() > 0.2 else push
		e.stick_toward(dir)
		await e.frames(1)
		if w.player_dead():
			break
	return done.call()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


func test_into_the_portal_and_out_on_floor_two() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	assert_eq(main.view.transit.phase, PortalTransitView.Phase.NONE, "floor 1 starts at once")
	assert_false(main.driver.reader.transit_holds())
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	e.stick_toward(Vector2.ZERO)
	assert_true(sealed, "walked through the boss door")
	if not sealed:
		return
	await e.frames(30)
	await _click(e, main, "KillBoss")
	await e.frames(3)
	assert_true(main.driver.reader.portal_active(), "the portal is open")
	# TEST HELPER (labelled): a known shard count to carry. Earning shards by input is test_e2e_rewards'.
	w.shards = 41
	var floors_started := [0]
	main.child_entered_tree.connect(
		func(n: Node) -> void:
			if n is SimDriver:
				floors_started[0] += 1
	)
	# Into the portal, holding the stick toward the gate the whole time.
	var entered: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return w.boss_flow.state == BossFlow.State.ENTERING,
		-f.portal_facing()
	)
	assert_true(entered, "the portal takes the hero")
	if not entered:
		return
	var view := main.view
	var avatar: Node3D = view.actors.actor_node(main.driver.reader.actor_id(0)).get_meta(&"avatar")
	await e.frames(1)
	assert_eq(view.transit.phase, PortalTransitView.Phase.ENTER, "the way in plays")
	var at := w.player_pos()
	e.stick_toward(Vector2(1, 0))  # the stick does nothing now
	var held := 0
	var smallest := 1.0
	var flash := false
	while main.run.floor_index == 1 and held < 200:
		assert_eq(w.player_pos(), at, "the world holds")
		assert_eq(main.driver.reader.outcome(), 0 if not w.boss_flow.exited() else 3)
		smallest = minf(smallest, avatar.scale.x)
		flash = flash or view.transit.light.light_energy > 1.0
		held += 1
		await e.frames(1)
	assert_eq(main.run.floor_index, 2, "the next floor started")
	assert_almost_eq(held, BossFlow.ENTER_TICKS, 3, "after about ENTER_TICKS ticks")
	assert_lt(smallest, 0.05, "the hero shrank into the light")
	assert_true(flash, "with a flash")
	# Arrival on floor 2, the stick still pushed.
	var w2 := e.world()
	assert_ne(w2, w)
	assert_eq(floors_started[0], 1, "one new floor")
	assert_eq(w2.shards, 20, "Q-S4: half of 41 shards carried, rounded down")
	var hud := main.get_node("UI/Hud") as Hud
	assert_true(hud.floor_card_showing(), "the arrival card shows")
	assert_true(
		hud.floor_card_text().ends_with(tr("HUD_SHARDS_HALVED") % 21),
		"it says the portal kept 21 shards: %s" % hud.floor_card_text()
	)
	assert_eq(main.view.transit.phase, PortalTransitView.Phase.ARRIVE, "the arrival plays")
	assert_true(main.driver.reader.transit_holds())
	var start := w2.player_pos()
	var arrive_frames := 0
	var column := false
	while main.driver.reader.transit_holds() and arrive_frames < 200:
		assert_eq(w2.player_pos(), start, "no control while the hero materialises")
		column = column or main.view.transit.column.visible
		arrive_frames += 1
		await e.frames(1)
	assert_true(column, "a light-blue column")
	assert_almost_eq(arrive_frames, BossFlow.ARRIVE_TICKS, 3, "about ARRIVE_TICKS ticks")
	await e.frames(20)
	e.stick_toward(Vector2.ZERO)
	assert_ne(w2.player_pos(), start, "control returns: the stick moves the hero")
	assert_eq(main.run.floor_index, 2, "floor 2, exactly once")
	assert_eq(floors_started[0], 1)
	assert_eq(main.view.transit.phase, PortalTransitView.Phase.NONE)
	assert_eq(get_errors().size(), 0, "no engine or script error")
