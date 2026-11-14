extends GutTest
## v0.4.0 AB through the real game (main.tscn, input only: keys, the stick and mouse clicks on the dev panel):
## v0.10.5 O1: the Storm Bombs pair test is gone with the retired abilities.
## - the dev route puts the hero by the Overrun door, the stick walks through the red frame: the banner shows, the
##   room's enemies arrive as Overrun enemies.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_walk_over_the_red_rune_into_an_overrun() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var o := main.driver.reader.overrun()
	assert_true(o["active"], "this floor has an Overrun room")
	assert_gte(main.view.overrun_doors.rune_count(), 1, "a red rune lies outside its doorway")
	assert_true(main.view.overrun_doors.is_lit(), "glowing")
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")
	await e.click_dev("GoOverrun")  # the dev route: by the door, outside the room
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	assert_ne(w.floor_layout.room_of(w.player_pos()), w.floor_layout.overrun_room, "outside it")
	assert_false(hud.overrun_hud.visible)
	assert_true(await e.walk_to(Overrun.reward_spot(w.floor_layout), 1.0), "walked in")
	assert_true(main.driver.reader.overrun()["inside"], "inside the Overrun")
	assert_true(hud.overrun_hud.visible, "the banner shows")
	assert_eq(hud.overrun_hud.title.text, tr("HUD_OVERRUN"))
	await e.frames(30)
	assert_eq(
		main.view.lockdowns.bars_down(w.floor_layout.overrun_room), 1.0, "v0.9.5 DR: bars fell"
	)
	assert_eq(main.view.arenas.barrier_count(), 0, "and no glowing barrier box")
	var boosted := false
	for k in 1200:
		await e.frames(1)
		if not w.overrun.boosted.is_empty():
			boosted = true
			break
	assert_true(boosted, "an enemy arrived as an Overrun enemy")
	if boosted:
		var i := w.actors.index_of(w.overrun.boosted[0])
		var base := w.enemy_table(w.actors.kinds[i]).hp
		# v0.4.0 TU: on top of the curve's HP (the calm minute eases it below the table's).
		assert_gt(w.actors.max_hp[i], w.spawner.hp_now(base, w.run_ticks), "with more HP")
