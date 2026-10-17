extends GutTest
## v0.8.0 N11 (owner O69: "the spawning enemies would be paused, right? And there would be no main character yet …
## the main character pops"; "Nothing spawns until you land"), through main.tscn with real input only. A new run: the
## floor opens behind the loading cover with the receiver in the first room and no hero on it; the sim waits while the
## cover fades, then the arrival plays (~1.6 s of ticks: the stick does nothing, the HUD and the hints wait, nothing
## spawns), the hero pops in on the receiver, the HUD shows, the stick moves the hero and only then do enemies come.
## Then the dev panel (God mode, Kill boss; as test_e2e_portal) stands in for the fight, the stick walks into the
## gate and floor 2 opens on the shorter arrival: the hero rises out of floor 2's receiver (~0.8 s of ticks).

const LEG_FRAMES := 7000


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _enemies(w: World) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		if EnemyAi.is_enemy_kind(w.actors.kinds[i]) and w.actors.dead[i] == 0:
			n += 1
	return n


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


## Plays the arrival from its first tick: [ticks it took, the hero moved during it, enemies seen, hero shown before
## the end, HUD shown during it, the receiver's highest charge, the lowest the hero stood].
func _watch_arrival(e: E2e, main: Main) -> Array:
	var w := e.world()
	var reader := main.driver.reader
	var avatar: Node3D = main.view.actors.actor_node(reader.actor_id(0)).get_meta(&"avatar")
	var at := w.player_pos()
	var t0 := w.tick
	var moved := false
	var enemies := 0
	var shown_at := -1
	var hud_seen := false
	var charge := 0.0
	var lowest := 0.0
	var hud := main.get_node("UI/Hud") as Hud
	e.stick_toward(Vector2(1, 0))  # pushed the whole time: it does nothing yet
	for k in 400:
		if not reader.arriving():
			break
		moved = moved or w.player_pos() != at
		enemies = maxi(enemies, _enemies(w))
		if avatar.visible and shown_at < 0:
			shown_at = w.tick - t0
		if avatar.visible:
			lowest = minf(lowest, avatar.position.y)
		hud_seen = hud_seen or hud.visible
		charge = maxf(charge, main.view.receiver.charge)
		await e.frames(1)
	return [w.tick - t0, moved, enemies, shown_at, hud_seen, charge, lowest]


func test_the_hero_lands_on_the_receiver_then_the_floor_starts() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"blade", false)
	var w := e.world()
	assert_not_null(w, "a floor started")
	if w == null:
		return
	var reader := main.driver.reader
	var view := main.view
	assert_true(reader.floor_receiver(), "the floor has a receiver")
	assert_not_null(view.receiver, "it is drawn")
	assert_eq(
		Vector2(view.receiver.position.x, view.receiver.position.z),
		Vector2(
			SimPlane.to_3d(reader.floor_start_pos()).x, SimPlane.to_3d(reader.floor_start_pos()).z
		),
		"in the middle of the first room, where the hero starts"
	)
	assert_true(reader.arriving(), "the floor opens on the arrival")
	var avatar: Node3D = view.actors.actor_node(reader.actor_id(0)).get_meta(&"avatar")
	assert_false(avatar.visible, "no hero yet")
	assert_false((main.get_node("UI/Hud") as Hud).visible, "the HUD waits")
	# The sim waits under the loading cover: the arrival starts once the cover has opened.
	var covered := 0
	while main.loads.cover.showing() and covered < 200:
		assert_eq(w.tick, 0, "no tick while the cover shows")
		covered += 1
		await e.frames(1)
	assert_gt(covered, 0, "the cover showed first")
	assert_false(main.loads.cover.showing(), "the cover opened")
	var got: Array = await _watch_arrival(e, main)
	assert_almost_eq(got[0], 96, 1, "floor 1's arrival: ~1.6 s of ticks (%d)" % got[0])
	assert_false(got[1], "the stick did nothing while the hero arrived")
	assert_eq(got[2], 0, "nothing spawned")
	assert_gt(got[3], 30, "the hero popped in late in it (tick %d)" % got[3])
	assert_false(got[4], "the HUD waited")
	assert_gt(got[5], 0.8, "the receiver charged")
	assert_eq(w.run_ticks, 0, "the run's clock waited")
	var landed_tick := w.tick
	# Play: the stick moves the hero, the HUD shows, and the horde comes after.
	var at := w.player_pos()
	await e.frames(20)
	assert_ne(w.player_pos(), at, "the stick moves the hero now")
	e.stick_toward(Vector2.ZERO)
	assert_true(avatar.visible, "the hero stands there")
	assert_eq(avatar.scale, Vector3.ONE)
	assert_true((main.get_node("UI/Hud") as Hud).visible, "the HUD shows")
	var spawned := -1
	for k in 1800:
		if _enemies(w) > 0:
			spawned = w.tick
			break
		await e.frames(1)
	assert_gt(spawned, landed_tick, "enemies come only after the landing (tick %d)" % spawned)
	assert_eq(get_errors().size(), 0, "no engine or script error")


func test_through_the_gate_floor_two_steps_out_of_its_receiver() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
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
	await e.tap(KEY_QUOTELEFT)  # the panel closes: the run goes on
	var entered: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return main.run.floor_index == 2,
		-f.portal_facing()
	)
	assert_true(entered, "the gate took the hero to floor 2")
	if not entered:
		return
	var w2 := e.world()
	assert_ne(w2, w)
	assert_true(main.driver.reader.floor_receiver(), "floor 2 has its receiver")
	assert_true(main.driver.reader.arriving(), "floor 2 opens on its arrival")
	assert_false(main.driver.reader.arrival_first(), "the short one")
	var covered := 0
	while main.loads.cover.showing() and covered < 200:
		assert_eq(w2.tick, 0, "no tick while the portal's cover opens")
		covered += 1
		await e.frames(1)
	var got: Array = await _watch_arrival(e, main)
	assert_almost_eq(got[0], 48, 1, "floor 2's arrival: ~0.8 s of ticks (%d)" % got[0])
	assert_false(got[1], "the stick did nothing")
	assert_eq(got[2], 0, "nothing spawned")
	assert_lt(got[6], -0.3, "the hero rose out of the receiver")
	await e.frames(20)
	e.stick_toward(Vector2.ZERO)
	assert_eq(main.view.transit.phase, PortalTransitView.Phase.NONE)
	assert_eq(get_errors().size(), 0, "no engine or script error")
