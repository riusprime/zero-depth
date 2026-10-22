extends GutTest
## v0.9.0 DP (owner Q26b: "the purple portal should be linked to one of the new puzzles or events, not be there as
## default"; "one of the event rooms, in a big room, has activation purple runes, that make the screen shake so you
## know something happened, but then when you kill the boss the purple portal appears"; "never in floor 1") through
## main.tscn with real input only. The dev panel (backtick, mouse clicks: God mode for the walks, Kill boss) stands in
## for the fights, as in test_e2e_routes (opened again on floor 2: a new floor drops it). Run seed SEED: floor 1 has
## no purple runes and its boss opens the gate alone; the stick walks into it. Floor 2 holds the purple-rune room
## (asserted below): the stick walks to the dais, the shared prompt reads "Awaken", E awakens it: the runes light one
## after another while the camera vibrates. The boss then opens the violet Purple Portal beside the gate; the stick
## walks into it, and floor 3 is a Deep floor (its card says so, its enemies are ×1.25 on top of the floor, its epic
## altar stands, the violet haze, T + 1).

## Run seed SEED: floor 2 holds the purple runes (found with SaveLab.floor_world(SEED, 2), asserted below).
const SEED := 1
const LEG_FRAMES := 7000


func after_each() -> void:
	E2e.center_sticks()


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


## Opens the boss door (E), walks in, kills the boss (the dev panel). True once the boss is dead.
func _beat_boss(e: E2e, main: Main) -> bool:
	var w := e.world()
	var f := w.floor_layout
	assert_true(await e.open_boss_door(), "E opened the boss door")
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	e.stick_toward(Vector2.ZERO)
	assert_true(sealed, "walked through the boss door")
	if not sealed:
		return false
	await e.frames(30)
	await _click(e, main, "KillBoss")
	await e.frames(3)
	return w.boss_flow.portal_active()


## Walks into the gate at `pos` facing `angle` until the way in starts, then waits for floor `next`.
func _take_gate(e: E2e, main: Main, pos: Vector2, angle: int, next: int) -> bool:
	var w := e.world()
	await e.frames(BossFlow.PORTAL_FORM_TICKS + 5)
	var facing := Kin.dir(angle)
	var entered: bool = await _walk(
		e,
		pos + facing * 1.0,
		func() -> bool: return w.boss_flow.state == BossFlow.State.ENTERING,
		-facing
	)
	e.stick_toward(Vector2.ZERO)
	assert_true(entered, "the gate takes the hero")
	var held := 0
	while main.run.floor_index < next and held < 300:
		held += 1
		await e.frames(1)
	assert_eq(main.run.floor_index, next, "floor %d started" % next)
	return entered and main.run.floor_index == next


func test_awaken_the_purple_runes_and_the_boss_opens_the_purple_portal() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu()
	var w := e.world()
	var reader := main.driver.reader
	assert_null(w.purple, "never on floor 1")
	assert_false(reader.has_deep_portal(), "floor 1 has no Purple Portal")
	await e.tap(KEY_QUOTELEFT)  # the dev panel stays open (closing it drops its tools)
	await _click(e, main, "God")
	assert_true(await _beat_boss(e, main), "floor 1's boss is dead")
	assert_true(reader.gate_open(WorldReader.ROUTE_NORMAL), "the gate is open")
	assert_false(reader.gate_open(WorldReader.ROUTE_DEEP), "and no Deep gate beside it")
	var f := w.floor_layout
	if not await _take_gate(e, main, f.portal_pos, f.portal_angle, 2):
		return
	await e.landed()
	var w2 := e.world()
	var f2 := w2.floor_layout
	reader = main.driver.reader
	assert_not_null(w2.purple, "floor 2 holds the purple runes")
	if w2.purple == null:
		return
	assert_false(reader.has_deep_portal(), "not earned yet")
	await e.tap(KEY_QUOTELEFT)  # a new floor's dev panel: God again for the walks
	await _click(e, main, "God")
	var view := main.view.purple
	assert_not_null(view, "the dais and its runes are drawn")
	assert_false(view.lit, "dim")
	assert_true(await e.walk_to(f2.purple_pos, 1.0), "walked to the dais")
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(hud.interact.prompt_text(), tr("APPROACH_PYLON_PROMPT"), "the shared prompt: Awaken")
	var rig := main.view.rig
	await e.tap(KEY_E)
	await e.frames(2)
	assert_true(PurpleRunes.earned(w2), "E awakened the runes")
	assert_true(view.lit, "the runes light")
	var peak := 0.0
	for k in 90:
		peak = maxf(peak, rig.vibration_level())
		await e.frames(1)
	for j in PurpleRuneView.RUNES:
		assert_gte(view.glow[j], PurpleRuneView.LIT - 0.2, "rune %d lit" % j)
	if rig.shake_enabled and not ViewPrefs.reduced_motion:
		assert_gt(peak, 0.2, "the camera vibrated")
	assert_true(reader.has_deep_portal(), "the floor earned the Purple Portal")
	assert_true(await _beat_boss(e, main), "floor 2's boss is dead")
	assert_true(reader.gate_open(WorldReader.ROUTE_NORMAL), "the gate is open")
	assert_true(reader.gate_open(WorldReader.ROUTE_DEEP), "and the Purple Portal beside it")
	await e.frames(BossFlow.PORTAL_FORM_TICKS + 5)
	assert_false(main.view.deep_gate.is_sealed(), "drawn open")
	assert_true(
		(main.get_node("UI/Hud") as Hud).gate_text().begins_with(tr("HUD_PORTALS_OPEN")),
		"the HUD names both"
	)
	if not await _take_gate(e, main, f2.deep_portal_pos, f2.deep_portal_angle, 3):
		return
	var w3 := e.world()
	assert_true(main.run.is_deep(), "the run took the Deep route")
	assert_eq(main.run.routes, PackedInt32Array([0, 0, 1]), "floor 3 is Deep")
	assert_true(Routes.is_deep(w3), "a Deep floor")
	assert_true(
		(main.get_node("UI/Hud") as Hud).floor_card_text().begins_with(
			tr("HUD_FLOOR_CARD_DEEP") % 3
		),
		"the card says so"
	)
	assert_gte(w3.boss_flow.epic_altar_id, 0, "the epic altar stands on the floor")
	assert_eq(Curses.threat(w3), 1, "T + 1")
	var t := main.run.table
	var hp_pm := SpawnTable.scale(SpawnTable.per_floor(t.enemy_hp_floor_permille, 3), 1250)
	for b in ContentCompiler.compile_enemies(ContentRepository.load_all()):
		assert_eq(
			w3.enemy_table(b.kind).hp, maxi(1, SpawnTable.scale(b.hp, hp_pm)), "×1.25 on the floor"
		)
	await e.frames(2)
	assert_true(main.view.stage.deep, "the violet haze")
	assert_null(w3.purple, "one purple room a loop: none on floor 3")
	assert_false(main.driver.reader.has_deep_portal(), "so floor 3 offers no Purple Portal")
	gut.p(
		(
			"PURPLE_E2E| seed=%d room=%d cells=%d vibration_peak=%.2f"
			% [SEED, f2.purple_room, f2.room_cell_count(f2.purple_room), peak]
		)
	)
	assert_eq(get_errors().size(), 0, "no engine or script error")
