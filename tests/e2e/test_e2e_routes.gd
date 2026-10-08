extends GutTest
## Optional routes (v0.5.0 RT, R5) through main.tscn with real input only: the dev panel (backtick, mouse clicks:
## God mode for the walk, Kill boss) stands in for the fight as in test_e2e_portal; the left stick walks through the
## boss door, the boss dies, and two portals open: the gate and the violet Deep gate. The stick walks into the Deep
## gate: the gate closes, the way in plays, and floor 2 starts once as a Deep floor (its card and floor label say
## so, its enemies are scaled ×1.25 on top of the floor, and it has the epic altar and an extra chest).

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


func test_into_the_deep_portal_and_floor_two_is_deep() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	assert_true(main.driver.reader.has_deep_portal(), "floor 1 of 3 has the Deep gate")
	assert_not_null(main.view.deep_gate, "and shows it")
	assert_false(main.run.is_deep(), "floor 1 is normal")
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
	var reader := main.driver.reader
	assert_true(reader.gate_open(WorldReader.ROUTE_NORMAL), "the gate is open")
	assert_true(reader.gate_open(WorldReader.ROUTE_DEEP), "and the Deep gate beside it")
	assert_false(main.view.gate.is_sealed())
	assert_false(main.view.deep_gate.is_sealed())
	assert_true(
		(main.get_node("UI/Hud") as Hud).gate_text().begins_with(tr("HUD_PORTALS_OPEN")),
		"the HUD names both"
	)
	var floors_started := [0]
	main.child_entered_tree.connect(
		func(n: Node) -> void:
			if n is SimDriver:
				floors_started[0] += 1
	)
	var facing := Kin.dir(f.deep_portal_angle)
	var entered: bool = await _walk(
		e,
		f.deep_portal_pos + facing * 1.0,
		func() -> bool: return w.boss_flow.state == BossFlow.State.ENTERING,
		-facing
	)
	assert_true(entered, "the Deep gate takes the hero")
	if not entered:
		return
	assert_eq(w.boss_flow.route_taken, Routes.Route.DEEP, "the Deep route")
	await e.frames(1)
	assert_true(main.view.gate.is_sealed(), "the other gate closes")
	var held := 0
	while main.run.floor_index == 1 and held < 200:
		held += 1
		await e.frames(1)
	assert_eq(main.run.floor_index, 2, "floor 2 started")
	assert_eq(floors_started[0], 1, "exactly once")
	var w2 := e.world()
	assert_true(main.run.is_deep(), "the run took the Deep route")
	assert_eq(main.run.routes, PackedInt32Array([Routes.Route.NORMAL, Routes.Route.DEEP]))
	assert_true(Routes.is_deep(w2), "floor 2 is Deep")
	assert_true(
		(main.get_node("UI/Hud") as Hud).floor_card_text().begins_with(
			tr("HUD_FLOOR_CARD_DEEP") % 2
		),
		"the card says so"
	)
	await e.frames(2)
	assert_true(
		(main.get_node("UI/Hud") as Hud).floor_text().begins_with(
			tr("HUD_FLOOR_DEEP").split("%s")[0] % 2
		),
		"the label too"
	)
	assert_gte(w2.boss_flow.epic_altar_id, 0, "the epic altar stands on the floor")
	var t := main.run.table
	var hp_pm := SpawnTable.scale(SpawnTable.per_floor(t.enemy_hp_floor_permille, 2), 1250)
	var base := ContentCompiler.compile_enemies(ContentRepository.load_all())
	for b in base:
		assert_eq(
			w2.enemy_table(b.kind).hp, maxi(1, SpawnTable.scale(b.hp, hp_pm)), "×1.25 on the floor"
		)
	assert_true(main.driver.reader.has_deep_portal(), "floor 2 of 3 offers the choice again")
	var recap := main.run_recap()
	assert_eq(recap["routes"], PackedInt32Array([0, 1]), "the recap carries the routes")
	assert_eq(get_errors().size(), 0, "no engine or script error")
