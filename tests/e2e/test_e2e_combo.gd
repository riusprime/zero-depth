extends GutTest
## A named combo through real input (v0.3.0 G, L8): on the first floor, walk (left stick only) to the two pedestals
## whose items make a combo; taking the second unlocks it, the combo card names it and the HUD gains its badge.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_walk_to_a_combo_pair_and_unlock_it() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(w.combo_tables.size(), 8, "the game loads the combos")
	var pick := _closest_pair(w)
	assert_false(pick.is_empty(), "this floor has both items of some combo on pedestals")
	if pick.is_empty():
		return
	var combo: int = pick[0]
	for item: int in [pick[1], pick[2]]:
		var at := -1
		for i in w.pickups.size():
			if w.pickups.item[i] == item:
				at = i
		if at < 0:
			continue  # already taken on the way to the first
		await _walk_to(e, w, w.pickups.pos(at), item)
	assert_false(w.player_dead(), "survived the walk")
	assert_true(w.combos_owned.has(combo), "owning both items unlocked the combo")
	await e.frames(2)
	var reader := main.driver.reader
	assert_true(hud.combo_card().is_showing(), "the combo card shows")
	assert_eq(hud.combo_card().title_text(), tr(reader.combo_name_key(combo)))
	assert_eq(hud.combo_card().desc_text(), tr(reader.combo_desc_key(combo)))
	assert_eq(hud.combo_card().pair_ids(), reader.combo_item_ids(combo), "with both items' icons")
	assert_eq(hud.combo_badge_count(), w.combos_owned.size(), "and a badge in the HUD")


## [combo index, item a, item b] for the combo whose two pedestals are nearest the player in total, or [].
func _closest_pair(w: World) -> Array:
	var best := []
	var best_d := INF
	for c in w.combo_tables.size():
		var t := w.combo_tables[c]
		var da := _pickup_distance(w, t.item_a)
		var db := _pickup_distance(w, t.item_b)
		if da < INF and db < INF and da + db < best_d:
			best_d = da + db
			best = [c, t.item_a, t.item_b] if da <= db else [c, t.item_b, t.item_a]
	return best


func _pickup_distance(w: World, item: int) -> float:
	for i in w.pickups.size():
		if w.pickups.item[i] == item:
			return w.pickups.pos(i).distance_to(w.player_pos())
	return INF


## Walks along the flow field to `target` until `item` is owned (or the player dies, or time runs out).
func _walk_to(e: E2e, w: World, target: Vector2, item: int) -> void:
	var nav := NavField.new()
	nav.build(w.walls)
	nav.flood(target)
	for k in 2400:
		var p := w.player_pos()
		var dir := (target - p).normalized() if (target - p).length() < 1.5 else nav.direction(p)
		var c := InputLatch.C45
		var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
		e.joy_axis(JOY_AXIS_LEFT_X, screen.x)
		e.joy_axis(JOY_AXIS_LEFT_Y, -screen.y)
		await e.frames(1)
		if w.items_owned.has(item) or w.player_dead():
			break
	e.joy_axis(JOY_AXIS_LEFT_X, 0.0)
	e.joy_axis(JOY_AXIS_LEFT_Y, 0.0)
