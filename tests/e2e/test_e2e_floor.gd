extends GutTest
## The floor through real input (PLAN v0.2.0 F): it has 8 pedestals and the sealed gate; walking (left stick
## only) to the nearest pedestal picks its item up, the HUD names it, and the item list shows it. The item card
## (v0.2.0 K, L13) previews the pedestal's item as you come near, then shows what you took; the icon row gains one.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_the_floor_has_pedestals_and_a_gate() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_not_null(e.world().floor_layout, "the game runs on a generated floor")
	assert_eq(e.world().pickups.ids.size(), 8, "one pedestal per room but the start")
	assert_eq(main.view.pickups.count(), 8)
	assert_not_null(main.view.gate, "the gate is placed")
	assert_true(main.view.gate.is_sealed())


func test_walk_to_a_pedestal_and_take_its_item() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var target_i := _nearest(w)
	var target := w.pickups.pos(target_i)
	var item := w.pickups.item[target_i]
	assert_eq(hud.card_mode(), &"", "no card far from the pedestals")
	assert_eq(hud.item_icon_count(), 0)
	var previewed := ""
	var nav := NavField.new()
	nav.build(w.walls)
	nav.flood(target)
	for k in 1800:
		var p := w.player_pos()
		var dir := (target - p).normalized() if (target - p).length() < 1.5 else nav.direction(p)
		# Sim direction -> screen stick (the inverse of the +45 degree screen-to-sim rotation); stick y is down.
		var c := InputLatch.C45
		var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
		e.joy_axis(JOY_AXIS_LEFT_X, screen.x)
		e.joy_axis(JOY_AXIS_LEFT_Y, -screen.y)
		await e.frames(1)
		if hud.card_mode() == &"preview" and w.items_owned.size() == 0:
			previewed = hud.card().title_text()
		if w.items_owned.size() > 0 or w.player_dead():
			break
	e.joy_axis(JOY_AXIS_LEFT_X, 0.0)
	e.joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	assert_false(w.player_dead(), "survived the walk")
	assert_eq(w.items_owned.size(), 1, "walking onto the pedestal took the item")
	var reader := main.driver.reader
	assert_eq(
		previewed,
		tr(reader.item_name_key(item)),
		"the card previewed the pedestal's item on the way"
	)
	await e.frames(2)
	assert_eq(hud.card_mode(), &"pickup", "the card shows the item just taken")
	assert_true(hud.card().is_showing())
	assert_eq(hud.card().title_text(), tr(reader.item_name_key(item)), "the HUD names the item")
	assert_eq(hud.card().desc_text(), tr(reader.item_desc_key(item)), "and says what it does")
	assert_eq(hud.card().icon_id(), reader.item_id(item), "with its symbol")
	assert_eq(hud.item_icon_count(), 1, "the carried-items row has one icon")


func _nearest(w: World) -> int:
	var best := 0
	for i in w.pickups.ids.size():
		if (
			w.pickups.pos(i).distance_to(w.player_pos())
			< w.pickups.pos(best).distance_to(w.player_pos())
		):
			best = i
	return best
