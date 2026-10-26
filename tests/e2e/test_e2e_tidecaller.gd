extends GutTest
## v0.9.0 NB1 (BOSSES_4_5.md N1): The Tidecaller reaches the real game. Through main.tscn with real input only: a
## floor-4 save (floor 4's pool holds the Tidecaller; built with SaveLab as Main builds floors) continued from the menu
## (Enter); God from the dev panel (clicked); the stick walks to the boss door, E opens it, the stick walks in and the
## door seals; the Tidecaller rises (its model, its name on the boss bar) and fights: its Pull comes, the water drawn
## round it (TideViews) and the hero, standing still, drawn toward it; then, the shield down, the hero closes in and
## the mouse's attack lands hits on it.

const FLOOR := 4
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


func test_continue_floor_4_and_fight_the_tidecaller_through_its_pull() -> void:
	# v0.9.0 NB2: floor 4 draws the Tidecaller or the Twin Wardens: the first seed that draws the Tidecaller.
	var run_seed: int = preload("res://tests/e2e/test_e2e_twin_wardens.gd").seed_for(&"tidecaller")
	var e := E2e.new(self)
	var run := SaveLab.run_state(run_seed, FLOOR, &"blade")
	var saved := SaveLab.build_floor(run)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, run_seed, PackedByteArray())))
	var main: Main = await e.boot(null, store, run_seed)
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	assert_eq(main.run.floor_index, FLOOR, "floor 4 continues")
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
		reader.actor_kind(bi), WorldReader.KIND_TIDECALLER, "floor 4's boss is the Tidecaller"
	)
	var bid := reader.actor_id(bi)
	var hud: Hud = main.get_node("UI/Hud")
	var avatar: Node = null
	for n in main.view.actors.find_children("*", "Node3D", true, false):
		if n is TidecallerAvatar:
			avatar = n
	assert_true(avatar is TidecallerAvatar, "its avatar")
	assert_not_null((avatar as TidecallerAvatar).imported, "the owner's model")
	# Up to it across its big room (the stick), then the hero stands still.
	await _walk(
		e,
		w.actors.pos(bi),
		func() -> bool:
			var j := w.actors.index_of(bid)
			return j < 0 or w.player_pos().distance_to(w.actors.pos(j)) < 9.0
	)
	# Its Pull: comes within its cadence; the hero stands still and is drawn in.
	var pulled := false
	for k in 60 * 25:
		await e.frames(1)
		var i := w.actors.index_of(bid)
		if i < 0:
			break
		if int(reader.boss_tide(i).get("phase", 0)) == WorldReader.TIDE_PULL:
			pulled = true
			break
	assert_true(pulled, "the Pull came")
	if not pulled:
		return
	var i0 := w.actors.index_of(bid)
	var d0 := w.player_pos().distance_to(w.actors.pos(i0))
	await e.frames(60)
	var i1 := w.actors.index_of(bid)
	var d1 := w.player_pos().distance_to(w.actors.pos(i1))
	assert_gt(
		d0 - d1, 0.6, "standing still, the hero was drawn about 1.2 m in (%.2f m)" % (d0 - d1)
	)
	assert_gt(main.view.tides.strength(), 0.3, "the water drawn round it")
	assert_true(hud.boss_bar.visible, "its bar")
	# v0.9.5 BH4: the ring stream and the crossing waves run beside its attacks, in the real boss room: a wave's foam line
	# is drawn at a wall of the room, then the band crosses it.
	var line_seen := false
	var band_seen := false
	var room := w.bosses.arena
	for k in 60 * 10:
		await e.frames(1)
		line_seen = line_seen or main.view.tide_waves.lines_shown() > 0
		band_seen = band_seen or main.view.tide_waves.bands_shown() > 0
		if line_seen and band_seen:
			break
	assert_true(room.has_area(), "the boss room's rectangle is the waves' room")
	assert_true(line_seen, "a wave's foam line was drawn on the floor")
	assert_true(band_seen, "and the wave crossed the room")
	var rings := w.bosses.str_ring_n
	assert_false(rings.is_empty(), "the ring stream is running")
	assert_gt(rings[0], 0, "and has fired")
	# The tide over and the shell down, the hero closes in and strikes.
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
