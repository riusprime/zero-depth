extends GutTest
## v0.9.0 NB2 (BOSSES_4_5.md N2): The Twin Wardens reach the real game. Through main.tscn with real input only: a
## floor-4 save whose floor draws the Wardens from floor 4's pool (built with SaveLab as Main builds floors; the seed
## is the first that draws them) continued from the menu (Enter); God from the dev panel (clicked); the stick walks to
## the boss door, E opens it, the stick walks in and the door seals; the two Wardens rise (both owner models, one bar
## with their name) with their chain drawn between them; the stick walks up to the violet twin and the mouse's attack
## lands: the one shared HP drops (the bar's, both bodies') and the other Warden turns angry.

const FLOOR := 4
const LEG_FRAMES := 900


func after_each() -> void:
	E2e.center_sticks()


## The first run seed whose floor 4 draws boss `id`.
static func seed_for(id: StringName) -> int:
	var repo := ContentRepository.load_all()
	var ids := BossLab.tables().map(func(x: BossTable) -> StringName: return x.id)
	for s in range(1, 60):
		var run := SaveLab.run_state(s, FLOOR, &"blade", 0, repo)
		var pools := RunContentCompiler.compile_boss_pools(repo, run.table.floors)
		if ids[FloorShape.boss(run, pools, FLOOR)] == id:
			return s
	return -1


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


func _walk(e: E2e, target: Callable, done: Callable) -> bool:
	var w := e.world()
	var goal: Vector2 = target.call()
	var nav := NavField.new()
	nav.build(E2e.walk_walls(w, goal))
	nav.flood(goal)
	for k in LEG_FRAMES:
		if done.call():
			break
		var p := w.player_pos()
		var to: Vector2 = target.call()
		var dir := nav.direction(p)
		if (to - p).length() < 3.0 or dir == Vector2.ZERO:
			dir = (to - p).normalized() if (to - p).length() > 0.2 else Vector2.ZERO
		e.stick_toward(dir)
		await e.frames(1)
	e.stick_toward(Vector2.ZERO)
	return done.call()


func test_continue_floor_4_and_fight_the_twin_wardens() -> void:
	var run_seed := seed_for(&"twin_wardens")
	assert_gt(run_seed, 0, "a seed draws the Wardens on floor 4")
	if run_seed < 0:
		return
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
	var inside := f.boss_door_inside(2.5)
	var sealed: bool = await _walk(
		e, func() -> Vector2: return inside, func() -> bool: return w.boss_flow.door_sealed()
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
		reader.actor_kind(bi), WorldReader.KIND_TWIN_WARDEN, "floor 4's boss is the Twin Wardens"
	)
	var bid := reader.actor_id(bi)
	var tid := reader.actor_id(int(reader.boss_twin(bi)["partner"]))
	assert_eq(
		reader.actor_kind(w.actors.index_of(tid)),
		WorldReader.KIND_TWIN_WARDEN_VIOLET,
		"its violet twin"
	)
	assert_eq(tr(reader.boss_name_key(bi)), "The Twin Wardens", "one name")
	var amber: TwinWardenAvatar = null
	var violet: TwinWardenVioletAvatar = null
	for n in main.view.actors.find_children("*", "Node3D", true, false):
		if n is TwinWardenVioletAvatar:
			violet = n
		elif n is TwinWardenAvatar:
			amber = n
	assert_not_null(amber, "the amber Warden's avatar")
	assert_not_null(violet, "the violet Warden's avatar")
	if amber == null or violet == null:
		return
	assert_not_null(amber.imported, "the owner's amber model")
	assert_not_null(violet.imported, "the owner's violet model")
	await e.frames(90)  # past the rise
	assert_gt(main.view.twins.links_drawn(), 8, "their chain drawn between them")
	var hud: Hud = main.get_node("UI/Hud")
	assert_true(hud.boss_bar.visible, "one bar")
	# Up to the violet twin, then the mouse's attack.
	var near := func() -> bool:
		var j := w.actors.index_of(tid)
		return j < 0 or w.player_pos().distance_to(w.actors.pos(j)) < w.actors.radius[j] + 1.2
	var hp0 := w.actors.hp[w.actors.index_of(bid)]
	var landed := false
	var angered := false
	for round in 6:
		await _walk(
			e,
			func() -> Vector2:
				var j := w.actors.index_of(tid)
				return w.actors.pos(j) if j >= 0 else w.player_pos(),
			near
		)
		for k in 4:
			await e.mouse_button(MOUSE_BUTTON_LEFT, true)
			await e.frames(8)
			await e.mouse_button(MOUSE_BUTTON_LEFT, false)
			await e.frames(4)
			var i := w.actors.index_of(bid)
			if i < 0:
				break
			var tj := w.actors.index_of(tid)
			angered = angered or bool(reader.boss_twin(i).get("angry", false))
			angered = angered or (tj >= 0 and bool(reader.boss_twin(tj).get("angry", false)))
		var i := w.actors.index_of(bid)
		var j := w.actors.index_of(tid)
		if i < 0 or j < 0:
			landed = true
			break
		if w.actors.hp[i] < hp0:
			landed = true
			assert_eq(w.actors.hp[i], w.actors.hp[j], "one shared HP")
			break
	assert_true(landed, "the hero's hits landed")
	assert_true(angered, "a hit on one Warden angered the other")
