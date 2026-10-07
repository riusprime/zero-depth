extends GutTest
## The floor through real input (PLAN v0.2.0 F; v0.3.0 E replaced the pedestals): it has 2-3 free altars and 2-3
## shard chests on the item spots (one per room, none in the start hall) and the sealed gate. Walking (left stick
## only) to the nearest altar shows the interact prompt; pad X opens it, the 3-card pick appears, d-pad right and
## A take the 2nd card: the item is owned, the altar is gone, the HUD card names the item and the icon row gains
## one.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_the_floor_has_altars_chests_and_a_gate() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_not_null(e.world().floor_layout, "the game runs on a generated floor")
	var w := e.world()
	var layout := w.floor_layout
	assert_eq(w.pickups.size(), 0, "no v0.2.0 pedestals")
	var altars := 0
	var chests := 0
	var rooms := {}
	for i in w.rewards.size():
		var room := layout.room_of(w.rewards.pos(i))
		assert_ne(room, layout.start_room, "no altar or chest in the start hall")
		assert_false(rooms.has(room), "one per room")
		rooms[room] = true
		if w.rewards.kind[i] == RewardStore.Kind.ALTAR:
			altars += 1
		else:
			chests += 1
	assert_between(altars, 2, 3, "2-3 free altars")
	assert_between(chests, 2, 3, "2-3 chests")
	assert_eq(main.view.rewards.count(), w.rewards.size(), "each one is drawn")
	assert_true(main.view.stage.covers_ground(layout.start_pos), "ground under the start")
	var b := layout.bounds
	var void_found := false
	for k in 400:
		var p := (
			b.position
			+ Vector2(b.size.x * float(k % 20) / 20.0, b.size.y * float(k - k % 20) / 400.0)
		)
		if layout.room_of(p) == -1 and not main.view.stage.covers_ground(p):
			void_found = true
	assert_true(void_found, "the space between rooms has no ground (v0.2.0 I)")
	assert_not_null(main.view.gate, "the gate is placed")
	assert_true(main.view.gate.is_sealed())


func test_walk_to_an_altar_and_take_the_second_card_with_the_pad() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var target_i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	var altar_id := w.rewards.ids[target_i]
	assert_eq(hud.prompt_text(), "", "no prompt far from the altars")
	assert_eq(hud.item_icon_count(), 0)
	var reached: bool = await e.walk_to(
		w.rewards.pos(target_i), w.reward_table.interact_radius_m * 0.6
	)
	assert_true(reached, "walked up to the altar")
	assert_false(w.player_dead(), "survived the walk")
	await e.frames(2)
	assert_eq(hud.prompt_text(), tr("REWARD_OPEN_ALTAR"), "the prompt says how to open it")
	e.joy_button(JOY_BUTTON_X, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_X, false)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_eq(w.choosing, altar_id, "pad X opened the altar")
	assert_true(panel.is_open(), "the 3-card pick shows")
	assert_eq(panel.card_count(), 3)
	assert_eq(panel.title_text(), tr("PICK_TITLE_ALTAR"))
	var offer := w.rewards.offer_of(w.rewards.index_of(altar_id))
	var reader := main.driver.reader
	for k in 3:
		assert_eq(
			panel.slot(k).card.title_text(), tr(reader.item_name_key(offer[k])), "card %d" % k
		)
	var tick := w.tick
	var hp := w.actors.hp[0]
	await e.frames(30)
	assert_eq(w.tick, tick + 30, "the clock runs while choosing")
	assert_eq(w.actors.hp[0], hp, "nothing hurts you while you choose")
	assert_eq(panel.focus_index(), 0)
	e.joy_button(JOY_BUTTON_DPAD_RIGHT, true)
	e.joy_button(JOY_BUTTON_DPAD_RIGHT, false)
	await e.frames(1)
	assert_eq(panel.focus_index(), 1, "d-pad right moved to the 2nd card")
	e.joy_button(JOY_BUTTON_A, true)
	e.joy_button(JOY_BUTTON_A, false)
	await e.frames(3)
	assert_eq(w.choosing, -1, "the pick closed the choice")
	assert_false(panel.is_open())
	assert_eq(w.items_owned, PackedInt32Array([offer[1]]), "the 2nd card's item is owned")
	assert_eq(w.rewards.index_of(altar_id), -1, "the altar is consumed")
	assert_eq(main.view.rewards.node_of(altar_id), null, "and gone from the view")
	assert_eq(hud.card_mode(), &"pickup", "the card shows the item just taken")
	assert_eq(hud.card().title_text(), tr(reader.item_name_key(offer[1])), "the HUD names the item")
	assert_eq(hud.card().desc_text(), tr(reader.item_desc_key(offer[1])), "and says what it does")
	assert_eq(hud.card().icon_id(), reader.item_id(offer[1]), "with its symbol")
	assert_eq(hud.item_icon_count(), 1, "the carried-items row has one icon")
