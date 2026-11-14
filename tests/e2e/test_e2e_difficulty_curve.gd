extends GutTest


func test_a_run_starts_calm_then_announces_the_next_phase() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(240)  # 4 s of play (the fade-in, the first calm spawns)
	var w := e.world()
	assert_not_null(w)
	var hud := main.get_node("UI/Hud") as Hud
	assert_true(hud.phase_hud.visible, "the floor has a difficulty curve")
	assert_eq(hud.phase_hud.phase_label.text, tr("PHASE_CALM"))
	assert_eq(main.driver.reader.tier(), 0, "no tier growth in the calm minute")
	var calm := [ActorStore.Kind.CHARGER, ActorStore.Kind.NEEDLE, ActorStore.Kind.SWARMER]
	for i in range(1, w.actors.size()):
		if EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			assert_has(calm, w.actors.kinds[i], "only the calm kinds in the first minute")
	assert_lte(WaveDirector.enemies_alive(w), w.spawner.cap_now(1, w.run_ticks))
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await e.click_dev("NextPhase")
	await e.frames(3)
	assert_eq(main.driver.reader.phase(), 1)
	assert_eq(hud.phase_hud.phase_label.text, tr("PHASE_STIR"))
	assert_eq(hud.phase_hud.announcement(), tr("PHASE_STIR"), "the new phase is announced")
