extends GutTest
## v0.9.5 BK (owner Q17 a: "Breakables solid until broken; kept 1.5 m from doorways") through main.tscn with real input
## only: the hero walks into a crate (or urn or barrel) and stops against it, hits it (the mouse), and then walks on
## through where it stood.

const SEED := 40


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_walk_into_a_crate_stop_break_it_and_walk_through() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu()
	var w := e.world()
	var b := w.breakables
	assert_not_null(b, "this floor has props")
	if b == null:
		return
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	var tried := 0
	var done := false
	for i in b.pos.size():
		if b.kind[i] == Breakables.Kind.EXPLOSIVE or b.broken[i] == 1 or tried >= 6:
			continue
		for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var start: Vector2 = b.pos[i] - dir * 1.8
			tried += 1
			if not await e.walk_to(start, 0.4):
				continue
			e.stick_toward(dir)
			await e.frames(70)
			var gap := (b.pos[i] - w.player_pos()).length()
			assert_eq(b.broken[i], 0, "walking into it does not break it")
			assert_gt(
				gap, w.actors.radius[0] + 0.25, "the hero stopped against it (gap %.2f)" % gap
			)
			assert_lt(gap, 1.6, "and was walking at it")
			await e.mouse_button(MOUSE_BUTTON_LEFT, true)
			await e.mouse_button(MOUSE_BUTTON_LEFT, false)
			await e.frames(30)
			assert_eq(b.broken[i], 1, "one hit breaks it")
			e.stick_toward(dir)
			await e.frames(90)
			e.stick_toward(Vector2.ZERO)
			var past := (w.player_pos() - b.pos[i]).dot(dir)
			assert_gt(past, 0.3, "and the hero walked through where it stood (%.2f m past)" % past)
			done = true
			break
		if done:
			break
	assert_true(done, "a prop with a clear approach was found (%d tried)" % tried)
	gut.p("BK_E2E| seed=%d tried=%d" % [SEED, tried])
