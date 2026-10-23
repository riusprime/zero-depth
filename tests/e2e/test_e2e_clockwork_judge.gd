extends GutTest
## v0.9.0 NB3 (BOSSES_4_5.md N3): The Clockwork Judge reaches the real game. Through main.tscn with real input only: a
## floor-5 save (floor 5's pool holds the Judge; built with SaveLab as Main builds floors) continued from the menu
## (Enter); God from the dev panel (clicked); the stick walks to the boss door, E opens it, the stick walks in and the
## door seals; the Judge rises (its model, its name on the boss bar) and fights: the stick circles while it records,
## then its echo comes: the whole path shows (JudgeViews' markers and ribbon), the ghosts strike along it, the Judge
## shielded; then, the shield down, the hero closes in and the mouse's attack lands hits on it.

const FLOOR := 5
const LEG_FRAMES := 900


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


func _walk(e: E2e, target: Vector2, done: Callable) -> bool:
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
			dir = (target - p).normalized() if (target - p).length() > 0.2 else Vector2.ZERO
		e.stick_toward(dir)
		await e.frames(1)
	e.stick_toward(Vector2.ZERO)
	return done.call()


func test_continue_floor_5_and_fight_the_judge_through_its_echo() -> void:
	var run_seed := 1
	var e := E2e.new(self)
	var run := SaveLab.run_state(run_seed, FLOOR, &"blade")
	var saved := SaveLab.build_floor(run)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, run_seed, PackedByteArray())))
	var main: Main = await e.boot(null, store, run_seed)
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	assert_eq(main.run.floor_index, FLOOR, "floor 5 continues")
	await e.landed()
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	assert_true(main.driver.debug.god, "God mode for the fight")
	await e.tap(KEY_QUOTELEFT)
	assert_true(await e.open_boss_door(), "E opened the boss door")
	var f := w.floor_layout
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.5), func() -> bool: return w.boss_flow.door_sealed()
	)
	assert_true(sealed, "walked in: the door sealed")
	if not sealed:
		return
	var reader := main.driver.reader
	for k in 300:
		if reader.boss_index() >= 0:
			break
		await e.frames(1)
	var bi := reader.boss_index()
	assert_gte(bi, 0, "the boss rose")
	if bi < 0:
		return
	assert_eq(
		reader.actor_kind(bi), WorldReader.KIND_CLOCKWORK_JUDGE, "floor 5's boss is the Judge"
	)
	var bid := reader.actor_id(bi)
	var hud: Hud = main.get_node("UI/Hud")
	var avatar: Node = null
	for n in main.view.actors.find_children("*", "Node3D", true, false):
		if n is ClockworkJudgeAvatar:
			avatar = n
	assert_true(avatar is ClockworkJudgeAvatar, "its avatar")
	assert_not_null((avatar as ClockworkJudgeAvatar).imported, "the owner's model")
	assert_eq(tr(reader.boss_name_key(bi)), "The Clockwork Judge", "its name")
	# The stick circles while it records; its echo comes within its cadence and shows the whole path.
	var shown := 0
	var ghosts := 0
	var shielded := false
	var replayed := false
	for k in 60 * 25:
		var a := TAU * float(k) / 150.0
		e.stick_toward(Vector2(cos(a), sin(a)))
		await e.frames(1)
		var i := w.actors.index_of(bid)
		if i < 0:
			break
		var echo := reader.boss_echo(i)
		var phase := int(echo.get("phase", WorldReader.ECHO_NONE))
		if phase == WorldReader.ECHO_SHOW:
			shown = maxi(shown, main.view.judges.markers_shown())
			shielded = shielded or reader.boss_shielded(i)
		elif phase == WorldReader.ECHO_REPLAY:
			replayed = true
			ghosts = maxi(ghosts, main.view.judges.ghosts_shown())
		elif replayed:
			break
	e.stick_toward(Vector2.ZERO)
	assert_true(replayed, "the echo came and replayed")
	assert_gt(shown, 0, "its whole path showed before the first strike")
	assert_true(shielded, "shielded through its echo")
	assert_gt(ghosts, 0, "the ghosts struck along the path")
	assert_true(hud.boss_bar.visible, "its bar")
	# The shield down, the hero closes in and strikes.
	for k in 400:
		if not reader.boss_shielded(w.actors.index_of(bid)):
			break
		await e.frames(1)
	var hp0 := w.actors.hp[w.actors.index_of(bid)]
	await _walk(
		e,
		w.actors.pos(w.actors.index_of(bid)),
		func() -> bool:
			var j := w.actors.index_of(bid)
			return j < 0 or w.player_pos().distance_to(w.actors.pos(j)) < w.actors.radius[j] + 1.2
	)
	for k in 6:
		await e.mouse_button(MOUSE_BUTTON_LEFT, true)
		await e.frames(10)
		await e.mouse_button(MOUSE_BUTTON_LEFT, false)
		await e.frames(10)
	var j := w.actors.index_of(bid)
	assert_true(j < 0 or w.actors.hp[j] < hp0, "the hero's hits landed on it")
