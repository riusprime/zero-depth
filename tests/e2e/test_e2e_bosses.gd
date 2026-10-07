extends GutTest
## The dev panel's boss spawn through real input (v0.3.0 C): backtick opens the panel, a click on "Spawn boss" puts
## the chosen boss near the player between ticks, its model appears and the HUD's boss bar shows its name.


func test_the_dev_panel_spawns_a_boss_with_its_bar() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_eq(e.world().boss_tables.size(), 3, "the run carries the compiled bosses")
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	var panel := main.ui.find_child("DevPanel", true, false) as Control
	var button := panel.find_child("SpawnBoss", true, false) as Button
	await e.frames(2)
	var at := button.get_global_rect().get_center()
	await e.mouse_to(at)
	var scale := await e._mouse_scale()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at / scale
		ev.global_position = at / scale
		e.send(ev)
		await e.frames(1)
	await e.frames(4)
	assert_true(e.world().boss_alive(), "a boss came")
	var reader := main.driver.reader
	var i := reader.boss_index()
	var first := e.world().boss_tables[0]
	assert_eq(reader.actor_kind(i), first.kind, "the first choice (boss tables are in id order)")
	var node := main.view.actors.actor_node(reader.actor_id(i))
	assert_true(node.get_meta(&"enemy_avatar") is BossAvatar)
	var hud := main.ui.find_child("Hud", true, false) as Hud
	assert_true(hud.boss_bar.visible)
	assert_eq(hud.boss_bar.boss_name(), tr(first.name_key))
