extends GutTest
## v0.5.5 AR through the real game (main.tscn, input only: the stick, keys and mouse clicks on the dev panel):
## - an arena: the dev route puts the hero by an arena's amber door, the stick walks in: the doors seal (barriers in the
##   doorways), the banner shows the wave, the rest of the floor goes dark on top of the biome's lighting (the sun and
##   the ambient light are untouched), the arena's reward wears its seal; the dev panel's Clear wave stands in for the
##   fight wave by wave until the doors open, the dark lifts, the seal goes and E opens the reward;
## - the boss: through the boss door, Kill boss: a bright-gold legendary altar rises where the boss stood; E opens
##   "Pick a legendary card" with three legendary cards, Enter takes one.

const LEG_FRAMES := 7000


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


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


func test_walk_into_an_arena_fight_its_waves_and_open_its_reward() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	var hud: Hud = main.get_node("UI/Hud")
	var a := main.driver.reader.arenas()
	assert_true(a["active"], "this floor has arenas")
	assert_false(f.arena_rooms.is_empty(), "regular ones besides the Overrun")
	if f.arena_rooms.is_empty():
		return
	assert_gt(main.view.arenas.frame_count(), 0, "their doorways wear amber frames")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _click(e, main, "GoArena")  # the dev route: by an arena's door, outside it
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	var room := -1
	for r in f.arena_rooms:
		for d in ArenaRooms.doors_of(f, r):
			if room < 0 and f.door_centers[d].distance_to(w.player_pos()) < 3.0:
				room = r
	assert_gte(room, 0, "by an arena's door")
	assert_ne(f.room_of(w.player_pos()), room, "outside it")
	var reward := -1
	for i in w.rewards.size():
		if f.room_of(w.rewards.pos(i)) == room:
			reward = w.rewards.ids[i]
	var sun_energy := main.view.stage.sun.light_energy
	var ambient := (
		main.view.stage.environment.ambient_light_energy if main.view.stage.environment else 0.0
	)
	var walls := w.walls.size()
	var sealed: bool = await _walk(
		e, f.rooms[room].get_center(), func() -> bool: return w.arenas.room == room
	)
	assert_true(sealed, "walking in seals the arena")
	if not sealed:
		return
	await e.frames(3)
	assert_gt(w.walls.size(), walls, "barriers stand in its doorways")
	assert_eq(main.view.arenas.barrier_count(), w.arenas.barriers.size(), "and are drawn")
	assert_true(hud.overrun_hud.visible, "the banner shows")
	assert_eq(hud.overrun_hud.title.text, tr("HUD_ARENA"))
	var veiled := main.view.arenas.veiled_rooms()
	assert_eq(veiled.size(), f.room_count() - 1, "every other room goes dark")
	assert_false(veiled.has(room), "but not this one")
	assert_gt(main.view.arenas.veil_target(), 0.5)
	assert_eq(main.view.stage.sun.light_energy, sun_energy, "the biome's sun is untouched")
	if main.view.stage.environment:
		assert_eq(
			main.view.stage.environment.ambient_light_energy, ambient, "and its ambient light"
		)
	if reward >= 0:
		assert_true(main.view.rewards.is_sealed(reward), "its reward wears the seal")
	var waves := w.arenas.waves
	var cleared := false
	for k in 40:
		await e.frames(70)  # the next wave arrives (and spawns in)
		if not w.arenas.sealed():
			cleared = true
			break
		await e.tap(KEY_QUOTELEFT)
		await _click(e, main, "ClearWave")
		await e.frames(2)
		await e.tap(KEY_QUOTELEFT)
	assert_true(cleared, "after %d waves the arena clears" % waves)
	await e.frames(3)
	assert_eq(w.walls.size(), walls, "the doors open")
	assert_eq(main.view.arenas.barrier_count(), 0, "the barriers go")
	assert_eq(main.view.arenas.veil_target(), 0.0, "the dark lifts")
	assert_eq(hud.overrun_hud.progress.text, tr("HUD_ARENA_CLEARED"))
	if reward < 0:
		return
	assert_false(main.view.rewards.is_sealed(reward), "the seal goes")
	var i := w.rewards.index_of(reward)
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	var afford := Rewards.can_afford(w, i)
	await e.tap(KEY_E)
	await e.frames(2)
	if afford:
		assert_eq(w.choosing, reward, "E opens the arena's reward")
	else:
		assert_eq(w.reward_denied_id, reward, "E tries it (a chest you can't afford stays shut)")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)


func test_the_boss_leaves_a_legendary_pick() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	var hud: Hud = main.get_node("UI/Hud")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	assert_true(sealed, "into the boss room")
	if not sealed:
		return
	assert_eq(w.legendary_id, -1, "no legendary while the boss lives")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "KillBoss")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(3)
	var r := w.rewards.index_of(w.legendary_id)
	assert_gte(r, 0, "the boss's death leaves a legendary altar")
	if r < 0:
		return
	var node := main.view.rewards.node_of(w.legendary_id)
	assert_not_null(node, "drawn")
	assert_true(node.get_meta(&"legendary"), "in bright gold")
	assert_true(await e.walk_to(w.rewards.pos(r), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(3)
	assert_eq(w.choosing, w.legendary_id, "E opens it")
	var panel := hud.pick_panel()
	assert_true(panel.is_open())
	assert_eq(panel.title_text(), tr("PICK_TITLE_LEGENDARY"), "Pick a legendary card")
	assert_eq(panel.card_count(), 3, "three cards")
	assert_true(panel.is_legendary())
	for k in panel.card_count():
		var s := panel.slot(k)
		assert_eq(s.tier, CardFrames.LEGENDARY_TIER, "card %d is legendary" % k)
		assert_eq(s.frame_id(), &"gold", "in the gold frame")
		assert_true(s.card.tier_text().ends_with(tr("RARITY_LEGENDARY")))
	var before := w.stat_cards.size() + w.items_owned.size()
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_eq(w.choosing, -1, "Enter took the focused card")
	assert_eq(
		w.stat_cards.size() + w.items_owned.size(), before + 1, "a legendary card joined the build"
	)
	assert_eq(w.rewards.index_of(w.legendary_id), -1)
