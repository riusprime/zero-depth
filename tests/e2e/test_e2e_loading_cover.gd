extends GutTest
## v0.8.0 N3 (owner O45: "we have to add loading screens so the game does not freeze when you start the game and take a
## portal … fades into black and a little loading symbol on a corner, and the load between floors in portal an
## animation that covers the screen with the color and animation style of the portal you cross and then unveils it
## back at the new floor"), through main.tscn and real input only: picking the build covers the screen black with the
## corner mark before the floor is built, and the cover fades away on the running floor; walking into the open portal
## (the dev panel's God and Kill boss stand in for the fight, as in test_e2e_portal) closes the gate's iris over the
## screen as the hero goes in, floor 2 loads under the closed cover, and the cover opens on floor 2.
## v0.8.0 N12 (owner O70: "the loading screens still freeze the game … never stop moving or freezing"): each load is
## built over several frames (the World on a worker thread, the view in slices) and the cover's clock, which turns
## the mark and moves the iris, advanced on every one of them.

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


## Waits for the load in progress frame by frame (wall clock, at most E2e.LOAD_MS): the frames it took and whether the
## cover's clock moved on every one of them while it showed.
func _watch_load(main: Main) -> Dictionary:
	var cover := main.loads.cover
	var frames := 0
	var still := 0
	var last := cover.clock()
	var from := Time.get_ticks_msec()
	while main.loads.busy() and Time.get_ticks_msec() - from < E2e.LOAD_MS:
		await get_tree().physics_frame  # the load's own frames (e.frames skips over a load)
		frames += 1
		if cover.showing() and cover.clock() <= last:
			still += 1
		last = cover.clock()
	return {"frames": frames, "still": still, "done": not main.loads.busy()}


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


func test_a_run_starts_behind_the_black_cover_and_a_portal_covers_in_its_colours() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	var cover := main.loads.cover
	assert_false(cover.showing(), "no cover on the menu")
	await HubWalk.new(e).to_build_screen()  # v0.9.0 HB: Play, then the Portal Machine
	await e.frames(2)
	e.key(KEY_ENTER, true)  # the build picker's pick (Blade)
	e.key(KEY_ENTER, false)
	assert_true(
		await HubWalk.new(e).through_portal(), "v0.9.0 HB2: the hero walks into the portal first"
	)
	assert_true(cover.is_covered(), "the screen is covered at once")
	assert_eq(cover.style, LoadingCover.Style.BLACK, "in black")
	assert_true(cover.mark.visible, "with the loading mark")
	assert_null(main.driver, "before the floor is built")
	var first: Dictionary = await _watch_load(main)
	assert_true(first["done"], "the run's first floor loaded")
	assert_not_null(main.driver, "the floor was built behind the cover")
	assert_true(cover.showing(), "still covered as the floor starts")
	assert_gt(int(first["frames"]), 3, "the load ran over many drawn frames, not in one")
	assert_eq(int(first["still"]), 0, "the cover moved on every frame of the load")
	assert_gt(main.loads.frames, 3, "CoverLoads counted them too")
	gut.p("new run: %d frames, %.0f ms" % [main.loads.frames, float(main.loads.phases["total"])])
	var gone := 0
	while cover.showing() and gone < 120:
		await e.frames(1)
		gone += 1
	assert_false(cover.showing(), "the cover faded away (%d frames)" % gone)
	var w := e.world()
	await e.landed()  # v0.8.0 N11: the hero lands on the receiver first
	assert_gt(w.tick, 0, "the run is on")
	# Into the portal.
	var f := w.floor_layout
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
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.driver.reader.portal_active(), "the portal is open")
	assert_true(main.driver.reader.portal_loads(), "to floor 2")
	var entered: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return w.boss_flow.state == BossFlow.State.ENTERING,
		-f.portal_facing()
	)
	assert_true(entered, "the portal takes the hero")
	if not entered:
		return
	var mid := false
	var closed_on_floor_1 := false
	var held := 0
	while main.run.floor_index == 1 and held < 200:
		if cover.amount > 0.05 and cover.amount < 0.95:
			mid = true
			assert_eq(cover.style, LoadingCover.Style.GATE, "in the gate's colours")
		closed_on_floor_1 = closed_on_floor_1 or cover.is_covered()
		held += 1
		await get_tree().physics_frame
	assert_true(mid, "the iris closed over several frames")
	assert_true(closed_on_floor_1, "and was closed before the load")
	assert_eq(main.run.floor_index, 2, "floor 2 loads")
	var portal_load: Dictionary = await _watch_load(main)
	assert_true(portal_load["done"], "floor 2 loaded")
	assert_gt(int(portal_load["frames"]), 3, "the portal's load ran over many drawn frames")
	assert_eq(int(portal_load["still"]), 0, "the iris kept moving on every frame of it")
	gut.p("gate: %d frames, %.0f ms" % [main.loads.frames, float(main.loads.phases["total"])])
	assert_ne(e.world(), w, "a new world")
	assert_true(cover.showing(), "the cover is over floor 2 as it starts")
	assert_eq(cover.style, LoadingCover.Style.GATE, "the gate's cover opens on it")
	var opened := 0
	while cover.showing() and opened < 120:
		await e.frames(1)
		opened += 1
	assert_false(cover.showing(), "then it unveils floor 2 (%d frames)" % opened)
	assert_eq(get_errors().size(), 0, "no engine or script error")
