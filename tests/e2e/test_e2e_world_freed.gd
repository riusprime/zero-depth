extends GutTest
## v0.10.5 W3-O14: floor 1's World is freed once floor 2 loads, through main.tscn with real input only (the dev
## panel's God and Kill boss stand in for the fight, as in test_e2e_portal; the left stick walks through the boss
## door and into the portal). The view's build queue held its jobs, and a job binds the queue and the view's reader:
## a cycle that kept each floor's whole World alive for the rest of the session. (The walks' conditions read
## e.world(), not a local: a lambda that captures the World would hold it from this test's own stack.)

const LEG_FRAMES := 7000


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


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


func test_floor_one_world_is_freed_once_floor_two_loads() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var wr: WeakRef = weakref(w)
	var f := w.floor_layout
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")
	assert_true(await e.open_boss_door(), "E opened the boss door")
	var sealed: bool = await _walk(
		e,
		f.boss_door_inside(2.0),
		func() -> bool: return e.world().boss_flow.door_sealed(),
		Kin.dir(f.boss_door_angle)
	)
	e.stick_toward(Vector2.ZERO)
	assert_true(sealed, "walked through the boss door")
	if not sealed:
		return
	await e.frames(30)
	await e.click_dev("KillBoss")
	await e.frames(3)
	assert_true(main.driver.reader.portal_active(), "the portal is open")
	var entered: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return e.world().boss_flow.state == BossFlow.State.ENTERING,
		-f.portal_facing()
	)
	assert_true(entered, "the portal takes the hero")
	if not entered:
		return
	e.stick_toward(Vector2.ZERO)
	var frames := 0
	while main.run.floor_index == 1 and frames < 600:
		frames += 1
		await e.frames(1)
	assert_eq(main.run.floor_index, 2, "the next floor started")
	assert_ne(e.world(), w, "a new World")
	f = null
	w = null
	var waited := 0
	while wr.get_ref() != null and waited < 1200:
		waited += 1
		await e.frames(1)
	gut.p("W3-O14 frames until freed: %d" % waited)
	gut.p(
		(
			"W3-O14 objects on floor 2: %d (floor 1's World %s)"
			% [
				Performance.get_monitor(Performance.OBJECT_COUNT),
				"alive" if wr.get_ref() != null else "freed"
			]
		)
	)
	assert_null(wr.get_ref(), "floor 1's World is freed once floor 2 runs")
	assert_eq(get_errors().size(), 0, "no engine or script error")
