extends GutTest
## The run through real input only (v0.3.0 PLAN L3-L4, B): floor 1 shows its card and "Floor 1 · <biome>"; the
## left stick walks to the nearest altar (E and Enter take a card: an item to carry), then through the boss door,
## which seals behind you and starts floor 1's real boss (drawn from its pool, its arena sizing the room); the dev
## panel (backtick, then mouse clicks: God mode for the long walk, Kill boss) stands in for the fight; the portal
## opens, the stick walks into it, and floor 2 loads with the items and shards kept, a 40 % heal, its own card and
## HUD line. Pause: Esc freezes the sim and Enter resumes; Restart run from the pause menu starts a fresh run.

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
	# Leg 1: the nearest free altar (v0.3.0 E): walk up, E opens its 3-card pick, Enter takes the focused card.
	var altar := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(altar, 0, "the floor has an altar")
	var reached: bool = await e.walk_to(
		w.rewards.pos(altar), w.reward_table.interact_radius_m * 0.6
	)
	assert_true(reached, "walked up to an altar")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_gte(w.choosing, 0, "E opened the altar's pick")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	# v0.4.0 BS: an altar's first (focused) card is a new ability while a slot is free.
	assert_eq(w.ability_owned.size(), 2, "took the card: a second ability slot")
	var item := w.ability_owned[1] if w.ability_owned.size() > 1 else -1
	# Leg 2: through the boss door.
	var into := Kin.dir(f.boss_door_angle)
	var walls_before := w.walls.size()
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	assert_true(sealed, "walking past the boss door seals it")
	if not sealed:
		return
	assert_eq(w.walls.size(), walls_before + 1, "the door is a wall now")
	assert_true(w.boss_alive(), "the boss is up")
	var boss_i := w.actors.index_of(w.boss_id)
	var pool := ContentCompiler.compile_boss_pool(ContentRepository.load_all(), 1)
	assert_has(pool, w.boss_flow.boss_index, "floor 1's boss comes from floor 1's pool")
	assert_eq(
		w.actors.kinds[boss_i], w.boss_tables[w.boss_flow.boss_index].kind, "the real boss (C's)"
	)
	var arena := w.boss_tables[w.boss_flow.boss_index].arena_cells
	var cells := f.room_cells[f.boss_room].size
	assert_true(
		cells == arena or cells == Vector2i(arena.y, arena.x), "the room has the boss's arena size"
	)
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
	assert_true(
		hud.gate_text().begins_with(tr("HUD_PORTALS_OPEN")), "v0.5.0 RT: floor 1 opens both portals"
	)
	assert_true(
		hud.gate_text().ends_with(tr("HUD_EXPLORE_AFTER_BOSS")), "v0.5.0 PB: and you may explore"
	)
	var hp_before := w.actors.hp[0]
	var owned := w.ability_owned.duplicate()
	var levels := w.ability_levels.duplicate()
	var items := w.items_owned.duplicate()
	var shards := w.shards  # kills on the way and the boss's purse
	assert_has(owned, item)
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
	assert_eq(w2.ability_owned, owned, "the abilities came along, in slot order")
	assert_eq(w2.ability_levels, levels, "at their levels")
	assert_eq(w2.items_owned, items, "and the items")
	assert_eq(w2.shards, shards, "the shards came along")
	assert_eq(
		w2.player.weapons, PlayerTable.WEAPON_BLADE, "the run's build came along (v0.3.0 L15)"
	)
	assert_eq(w2.floor_index, 2, "chest prices and boss shards read floor 2")
	assert_eq(w2.actors.hp[0], mini(100, hp_before + 40), "healed 40 % of max HP")
	assert_lt(w2.run_ticks, 30, "the danger clock restarts")
	assert_eq(w2.seed_value, main.run.floor_seed(2), "with floor 2's seed")
	var hud2: Hud = main.get_node("UI/Hud")
	var biome_2: BiomeDefinition = ContentRepository.load_all().get_def(
		&"biomes", main.run_biome_id()
	)
	assert_eq(hud2.floor_text(), tr("HUD_FLOOR") % [2, tr(biome_2.name_key)])
	assert_true(hud2.floor_card_showing(), "floor 2's card")
	assert_eq(hud2.item_icon_count(), items.size(), "the carried items' icons")
	assert_eq(hud2.ability_hud.filled_count(), owned.size(), "the ability slots")
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
