extends GutTest
## Optional routes (v0.5.0 RT, R5) through main.tscn with real input only: the dev panel (backtick, mouse clicks:
## God mode for the walk, Kill boss) stands in for the fight as in test_e2e_portal; the left stick walks through the
## boss door and the boss dies. v0.9.0 DP (owner Q26b: "the purple portal should be linked to one of the new puzzles
## or events, not be there as default"; "never in floor 1"): floor 1 has no purple runes, so its boss opens the gate
## alone: no Deep gate is built, the HUD names one portal and the minimap has none. Earning it and taking it into a
## Deep floor (the card, the ×1.25, the epic altar) is test_e2e_purple_portal's.

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


func test_floor_one_opens_the_gate_alone() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	var reader := main.driver.reader
	assert_false(reader.has_deep_portal(), "floor 1 has no Deep gate")
	assert_null(w.purple, "and no purple runes to earn one")
	assert_null(main.view.deep_gate, "none is built")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	assert_true(await e.open_boss_door(), "v0.8.0 BD (O83): E opened the boss door")
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
	assert_true(reader.gate_open(WorldReader.ROUTE_NORMAL), "the gate is open")
	assert_false(reader.gate_open(WorldReader.ROUTE_DEEP), "alone")
	assert_true(
		(main.get_node("UI/Hud") as Hud).gate_text().begins_with(tr("HUD_PORTAL_OPEN")),
		"the HUD names one portal"
	)
	assert_eq(get_errors().size(), 0, "no engine or script error")
