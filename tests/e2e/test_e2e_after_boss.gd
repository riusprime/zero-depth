extends GutTest
## Explore after the boss (v0.5.0 PB, owner D10), through main.tscn with real input only: the dev panel (backtick,
## mouse clicks: God mode for the long walk, Kill boss) stands in for the fight as in test_e2e_run_flow; the left
## stick walks through the boss door (it seals), and after Kill boss the door is open again: the HUD says you may
## keep exploring, nothing arrives while you stand in the boss room, the stick walks back out through the doorway into
## the room before it, normal spawns resume there, and the stick walks back in and into the still-open portal:
## floor 2 loads.

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
	e.stick_toward(Vector2.ZERO)
	return done.call()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


## Normal enemies that arrived after event `after` (SPAWN of a live non-boss enemy).
func _arrivals(w: World, after: int) -> int:
	var n := 0
	for ev in w.events_since(after):
		if ev.kind != SimEvent.Kind.SPAWN:
			continue
		var i := w.actors.index_of(ev.target_id)
		if i >= 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			n += 1
	return n


func test_out_through_the_boss_door_and_back_to_the_portal() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	var hud: Hud = main.get_node("UI/Hud")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	assert_true(main.driver.debug.god, "God mode for the walk")
	var walls_open := w.walls.size()
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	assert_true(sealed, "walked through the boss door: it sealed")
	if not sealed:
		return
	assert_eq(w.walls.size(), walls_open + 1, "the door is a wall during the fight")
	await e.frames(30)
	await _click(e, main, "KillBoss")
	await e.frames(3)
	var reader := main.driver.reader
	assert_false(w.boss_alive(), "Kill boss killed it")
	assert_true(reader.portal_active(), "the portal is open")
	assert_false(reader.boss_door_sealed(), "and the boss door with it")
	assert_eq(w.walls.size(), walls_open, "its collider is gone")
	assert_true(
		hud.gate_text().ends_with(tr("HUD_EXPLORE_AFTER_BOSS")), "the HUD says: keep exploring"
	)
	# The boss room is a safe spot: nothing arrives while you stand in it.
	var seq := w.last_event_seq()
	await e.frames(240)
	assert_eq(_arrivals(w, seq), 0, "no spawns in the boss room after the boss")
	# Out through the doorway into the room before it.
	var out: bool = await _walk(
		e,
		f.boss_door_outside(3.0),
		func() -> bool: return f.room_of(w.player_pos()) == f.boss_host_room,
		-into
	)
	assert_true(out, "the stick walks out through the open boss door")
	if not out:
		return
	await e.frames(20)
	assert_false(main.view.boss_door.is_sealed(), "the door view is open")
	assert_eq(hud.gate_text(), "", "no portal note away from the boss room")
	seq = w.last_event_seq()
	var waited := 0
	while _arrivals(w, seq) == 0 and waited < 2400:
		await e.frames(10)
		waited += 10
	assert_gt(_arrivals(w, seq), 0, "normal spawns resume outside the boss room")
	gut.p(
		"first post-boss arrival after %d frames out, floor time %d ticks" % [waited, w.run_ticks]
	)
	assert_true(reader.portal_active(), "the portal still waits")
	# Back in and into the portal.
	var entered: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return w.boss_flow.state == BossFlow.State.ENTERING,
		-f.portal_facing()
	)
	assert_true(entered, "the portal takes the hero after exploring")
	if not entered:
		return
	var frames := 0
	while main.run.floor_index == 1 and frames < 400:
		await e.frames(1)
		frames += 1
	assert_eq(main.run.floor_index, 2, "floor 2 loads")
	assert_eq(get_errors().size(), 0, "no engine or script error")
