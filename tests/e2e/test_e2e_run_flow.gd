extends GutTest
## The run through real input only (v0.3.0 PLAN L3-L4, B): floor 1 shows its card and "Floor 1 · <biome>"; the
## left stick walks to the nearest pedestal (an item to carry), then through the boss door, which seals behind you
## and starts the boss; the dev panel (backtick, then mouse clicks: God mode for the long walk, Kill boss) stands in
## for the fight, which is C's; the portal opens, the stick walks into it, and floor 2 loads with the item kept, a
## 40 % heal, its own card and HUD line. Pause: Esc freezes the sim and Enter resumes; Restart run from the pause
## menu starts a fresh run.

const LEG_FRAMES := 7000


func after_each() -> void:
	Input.action_release(&"pause")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


## Walks the left stick along the flow field toward `target` until `done` is true (or the frame limit).
func _walk(e: E2e, target: Vector2, done: Callable, push: Vector2 = Vector2.ZERO) -> bool:
	var w := e.world()
	var nav := NavField.new()
	nav.build(w.walls)
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


func test_through_the_boss_door_and_down_the_portal_to_floor_two() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(main.run.floor_index, 1, "a run starts on floor 1")
	assert_eq(w.floor_count, 3, "of three")
	var biome_1: BiomeDefinition = ContentRepository.load_all().get_def(
		&"biomes", main.run_biome_id()
	)
	assert_eq(hud.floor_text(), tr("HUD_FLOOR") % [1, tr(biome_1.name_key)], "the HUD names it")
	assert_true(hud.floor_card_showing(), "the floor-title card shows on arrival")
	assert_not_null(main.view.boss_door, "the boss door stands in the layout")
	assert_true(main.view.gate.is_sealed(), "the gate starts dark")
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	assert_true(main.driver.debug.god, "a click on God mode turns it on")
	# Leg 1: the nearest pedestal.
	var near := 0
	for i in w.pickups.ids.size():
		if (
			w.pickups.pos(i).distance_to(w.player_pos())
			< w.pickups.pos(near).distance_to(w.player_pos())
		):
			near = i
	var item := w.pickups.item[near]
	var took: bool = await _walk(
		e, w.pickups.pos(near), func() -> bool: return w.items_owned.size() > 0
	)
	assert_true(took, "walked onto a pedestal")
	# Leg 2: through the boss door.
	var into := Kin.dir(f.boss_door_angle)
	var walls_before := w.walls.size()
	var sealed: bool = await _walk(
		e, f.boss_door_center + into * 3.0, func() -> bool: return w.boss_flow.door_sealed(), into
	)
	assert_true(sealed, "walking past the boss door seals it")
	if not sealed:
		return
	assert_eq(w.walls.size(), walls_before + 1, "the door is a wall now")
	assert_true(w.boss_alive(), "the boss is up")
	await e.frames(30)
	assert_true(main.view.boss_door.is_sealed(), "the door view shut")
	assert_lt(main.view.boss_door.open_amount, 0.5, "and its slab is up")
	assert_true(main.view.gate.is_sealed(), "the gate stays dark while the boss lives")
	# The fight is C's: the dev panel's Kill boss stands in.
	await _click(e, main, "KillBoss")
	await e.frames(3)
	assert_false(w.boss_alive(), "Kill boss killed it")
	assert_true(main.driver.reader.portal_active(), "the boss's death opens the portal")
	assert_false(main.view.gate.is_sealed(), "the gate lights up")
	assert_eq(hud.gate_text(), tr("HUD_PORTAL_OPEN"))
	var hp_before := w.actors.hp[0]
	# Leg 3: into the portal.
	var gone: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,  # in the gate's opening
		func() -> bool: return main.run.floor_index == 2,
		-f.portal_facing()
	)
	assert_true(gone, "walking into the portal goes down")
	if not gone:
		return
	await e.frames(2)
	var w2 := e.world()
	assert_ne(w2, w, "a new floor")
	assert_eq(w2.floor_index, 2)
	assert_eq(w2.items_owned, PackedInt32Array([item]), "the item came along")
	assert_eq(w2.actors.hp[0], mini(100, hp_before + 40), "healed 40 % of max HP")
	assert_lt(w2.run_ticks, 30, "the danger clock restarts")
	assert_eq(w2.seed_value, main.run.floor_seed(2), "with floor 2's seed")
	var hud2: Hud = main.get_node("UI/Hud")
	var biome_2: BiomeDefinition = ContentRepository.load_all().get_def(
		&"biomes", main.run_biome_id()
	)
	assert_eq(hud2.floor_text(), tr("HUD_FLOOR") % [2, tr(biome_2.name_key)])
	assert_true(hud2.floor_card_showing(), "floor 2's card")
	assert_eq(hud2.item_icon_count(), 1, "the carried item's icon")
	assert_true(main.get_node("UI/Fade").visible, "the floor fades in")
	assert_eq(get_errors().size(), 0, "no engine or script error")


func test_esc_pauses_and_enter_resumes() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(5)
	await e.tap(KEY_ESCAPE)
	assert_not_null(main.get_node_or_null("UI/PauseMenu"), "Esc opens the pause menu")
	var tick := e.world().tick
	await e.frames(10)
	assert_eq(e.world().tick, tick, "no ticks while paused")
	await e.tap(KEY_ENTER)  # Resume has focus
	assert_null(main.get_node_or_null("UI/PauseMenu"))
	await e.frames(5)
	assert_gt(e.world().tick, tick, "the sim runs again")


func test_restart_run_from_the_pause_menu() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(5)
	var w := e.world()
	var run_seed := main.run.run_seed
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_DOWN)  # Resume -> Restart run
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_null(main.get_node_or_null("UI/PauseMenu"), "the pause menu closed")
	assert_ne(e.world(), w, "a fresh run")
	assert_eq(main.run.run_seed, run_seed + 1, "with the next seed")
	assert_eq(main.run.floor_index, 1)
	assert_gt(e.world().tick, 0, "and it runs")
