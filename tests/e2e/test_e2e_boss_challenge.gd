extends GutTest
## The boss summon through real input only (v0.3.0 BX; owner lines L20, L22): the left stick walks floor 1 to the
## boss door (the dev panel's God mode, clicked with the mouse, keeps the long walk safe) while the floor's enemies
## keep arriving; walking through the door seals it and summons the boss, and at that tick every normal enemy on the
## floor dissolves (no kill counted, no shards paid, a dissolve effect each), and the boss bar appears empty and
## fills to full over exactly the boss's rise, then shows its HP.

const LEG_FRAMES := 7000


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


static func _normal_enemies(w: World) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		var k := w.actors.kinds[i]
		if w.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(k) and not BossAi.is_boss_kind(k):
			n += 1
	return n


func test_summoning_the_boss_dissolves_the_floor_and_its_bar_fills_over_the_rise() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	var hud: Hud = main.get_node("UI/Hud")
	await e.tap(KEY_QUOTELEFT)
	var god := main.get_node("UI/DevPanel").find_child("God", true, false) as Button
	await e.click_at(god.get_global_rect().get_center())
	assert_true(main.driver.debug.god, "God mode for the walk")
	await e.tap(KEY_QUOTELEFT)
	# Walk to the boss door with the stick; enemies keep arriving meanwhile.
	var nav := NavField.new()
	nav.build(w.walls)
	var target := f.boss_door_inside(2.0)
	nav.flood(target)
	var into := Kin.dir(f.boss_door_angle)
	var before := 0
	var kills := 0
	var shards := 0
	var seq0 := 0
	for k in LEG_FRAMES:
		if w.boss_flow.door_sealed():
			break
		before = _normal_enemies(w)
		kills = w.kills
		shards = w.shards
		seq0 = w.last_event_seq()
		var p := w.player_pos()
		var dir := nav.direction(p)
		if (target - p).length() < 1.5 or dir == Vector2.ZERO:
			dir = (target - p).normalized() if (target - p).length() > 0.2 else into
		e.stick_toward(dir)
		await e.frames(1)
	e.stick_toward(Vector2.ZERO)
	assert_true(w.boss_flow.door_sealed(), "walking through the boss door seals it")
	if not w.boss_flow.door_sealed():
		return
	print("BX| enemies on the floor at the summon: %d" % before)
	assert_gt(before, 0, "the floor had enemies when the boss was summoned")
	assert_eq(_normal_enemies(w), 0, "every normal enemy is gone")
	var dissolved := w.events_since(seq0).filter(
		func(ev: SimEvent) -> bool: return ev.kind == SimEvent.Kind.ENEMY_DISSOLVED
	)
	assert_eq(dissolved.size(), before, "one dissolve each")
	assert_eq(w.kills, kills, "no kills credited")
	assert_eq(w.shards, shards, "no shards paid")
	assert_eq(main.view.challenge.dissolved_count(), before, "each dissolves on screen")
	# The bar: empty as the boss appears, full exactly when its rise ends.
	assert_true(w.boss_alive(), "the boss is up")
	var reader := main.driver.reader
	var i := reader.boss_index()
	var spawn_tick := w.tick - 1 - w.actors.state_t[i]
	assert_true(hud.boss_bar.visible, "the bar shows")
	assert_lt(hud.boss_bar.hp_fraction(), 0.1, "nearly empty at first")
	var last := hud.boss_bar.hp_fraction()
	var full_tick := -1
	for k in BossAi.INTRO_TICKS + 30:
		await e.frames(1)
		i = reader.boss_index()
		var frac := hud.boss_bar.hp_fraction()
		assert_gte(frac, last - 0.0001, "the bar only fills while it rises")
		assert_almost_eq(frac, reader.boss_intro_permille(i) / 1000.0, 0.001, "at the rise's pace")
		last = frac
		if frac >= 0.999 and full_tick < 0:
			full_tick = w.tick - 1
			assert_ne(reader.actor_state(i), WorldReader.STATE_SPAWN, "full the tick it acts")
	assert_eq(full_tick - spawn_tick, BossAi.INTRO_TICKS, "filled over exactly the rise")
	assert_eq(get_errors().size(), 0, "no engine or script error")
