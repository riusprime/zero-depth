extends GutTest
## v0.9.5 SM (owner Q14 a) through the real game (main.tscn, input by Input.parse_input_event only): a Gun run takes
## the Stress Mark at an altar, walks near an enemy, reads the side that enemy shows, steps to that side and shoots:
## the first hit deals double what the next plain hit does, its arc is drawn on that side, and it breaks.


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _item(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## True when the straight line a to b crosses no wall.
static func clear_line(w: World, a: Vector2, b: Vector2) -> bool:
	for i in w.walls_along(a, b, 0.6):
		if Collide.sweep_vs_obb(a, b, 0.6, w.walls[i]) >= 0.0:
			return false
	return true


## A spot 3 to 5 m from the hero, in sight of it, whose four screen sides all have a clear spot 2 m out (or INF).
static func open_spot(w: World) -> Vector2:
	var p := w.player_pos()
	for r in [4.0, 3.5, 4.5, 3.0, 5.0]:
		for k in 16:
			var at: Vector2 = p + Vector2.from_angle(TAU * k / 16.0) * r
			var ok := clear_line(w, p, at)
			for s in 4:
				ok = ok and clear_line(w, at, at + StressMarks.side_dir(s) * 2.0)
			if ok:
				return at
	return Vector2.INF


## Takes card `id` at the nearest altar (its offer forced: TEST HELPER). True when taken.
func take_at_altar(e: E2e, main: Main, id: StringName) -> bool:
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	if i < 0:
		return false
	w.rewards.set_offer(i, PackedInt32Array([_item(w, id), _item(w, &"gun_twin")]))
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_true(panel.is_open(), "E opened the altar")
	for k in 240:
		if panel.deal.done():
			break
		await e.frames(1)
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(70)
	return w.items_owned.has(_item(w, id))


func test_a_hit_from_the_shown_side_deals_double() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await take_at_altar(e, main, &"shared_stress_mark"), "took the Stress Mark")
	# TEST HELPERS (labelled): crit off so the two hits compare exactly; one standing dummy on a clear line.
	w.player.crit_chance_permille = 0
	w.dummy_speed = 0.0
	var at := open_spot(w)
	gut.p("SM e2e: spot %s" % [at])
	assert_ne(at, Vector2.INF, "an open spot near the hero")
	if at == Vector2.INF:
		return
	var id := w.add_dummy(at, 0.35, 1000000)
	var reader := WorldReader.new(w)
	var j := w.actors.index_of(id)
	for k in 30:
		await e.frames(1)
		if reader.stress_mask(j) != 0:
			break
	var mask := reader.stress_mask(j)
	assert_ne(mask, 0, "the enemy within 6 m shows a weak side")
	var side := 0
	for s in 4:
		if mask & (1 << s):
			side = s
	var stand := at + StressMarks.side_dir(side) * 2.0
	assert_true(clear_line(w, at, stand), "a clear line from that side")
	var quad := main.view.stress_marks.quad_of(id, side)
	assert_not_null(quad, "its arc is drawn")
	if quad != null:
		var dir3 := quad.global_transform.basis.x.normalized()
		var want := SimPlane.to_3d(StressMarks.side_dir(side)).normalized()
		assert_gt(dir3.dot(want), 0.99, "on the side the sim marked")
	assert_true(await e.walk_to(stand, 0.5), "stepped to that side")
	assert_ne(reader.stress_mask(j) & (1 << side), 0, "still marked")
	var cam := main.view.rig.camera
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	var hits: Array[int] = []
	var seq := 0
	for k in 150:
		await e.frames(1)
		for ev in w.events_since(seq):
			seq = ev.seq
			if (
				ev.kind == SimEvent.Kind.DAMAGE
				and ev.target_id == id
				and ev.owner_id == w.actors.ids[0]
				and not ev.tags & SimEvent.TAG_DOT
			):
				hits.append(ev.amount)
		if hits.size() >= 3:
			break
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	gut.p("SM e2e: hits on the marked enemy %s" % [hits])
	assert_gte(hits.size(), 2, "shots landed")
	if hits.size() >= 2:
		assert_eq(hits[0], hits[1] * 2, "the first, from the shown side, dealt double")
	assert_eq(reader.stress_mask(j) & (1 << side), 0, "and the mark broke")
	assert_eq(main.audio.played_log.has(&"stress_break"), true, "the ting is heard")
