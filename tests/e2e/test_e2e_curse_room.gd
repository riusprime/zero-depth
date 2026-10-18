extends GutTest
## v0.8.0 N17 (owner O75) through real input: run seed 1's floor 1 has a curse room (Events.curse_site), a combat room
## away from the start hall holding the curse altar in its dark, glyph-lit room. God from the dev panel (clicked with
## the mouse: the dev route, so the walk is safe), then walking to the altar with the stick: no name floats over it and
## the prompt doesn't name it; E opens the panel, which names it; the digit picks the choice that carries a curse and
## Enter takes it: the curse is held and threat shows on the HUD. v0.8.0 N19 (owner O80): the room is a room of its
## own (no enemy spawns inside, crystals round its walls, the four purple ritual sigils) and the altar is solid, so
## the walk ends at its walk-up, in reach.

## Run seed 1: floor 1 holds a curse room (asserted below).
const SEED := 1


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_walk_into_the_curse_room_open_the_altar_and_take_a_curse() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var k := w.ev.curse_k
	assert_gte(k, 0, "this floor has a curse room")
	if k < 0:
		return
	var layout := w.floor_layout
	var room := w.ev.room[k]
	assert_ne(room, layout.start_room, "not the start hall")
	assert_ne(room, layout.boss_room, "nor the boss room")
	assert_false(layout.arena_rooms.has(room), "nor an arena")
	var events := main.view.events
	assert_not_null(events.curse_room, "the room is dressed (dark, glyphs)")
	assert_eq(events.pedestal_root(k).name, &"CurseAltar", "the altar's own model")
	assert_eq(events.label_count(), 0, "no name floats over it")
	assert_eq(layout.curse_room, room, "a room of its own (N19)")
	for q in w.spawn_points:
		assert_ne(layout.room_of(q), room, "no enemy spawns inside")
	assert_gt(events.curse_room.crystals.size(), 0, "crystals round its walls")
	assert_true(events.curse_room.uses_sheet, "the ritual sigils")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	var at := w.ev.pos(k)
	var up := at + (CurseRoom.front(layout, room, at) - at).normalized() * 1.25  # the walk-up, in reach
	assert_true(await e.walk_to(up, 0.35), "walked up to the altar")
	await e.frames(2)
	var name := tr(Events.table(w, k).name_key)
	gut.p("curse altar: %s" % Events.table(w, k).id)
	assert_eq(hud.events.prompt_text(), tr("UI_CURSE_ALTAR_OPEN"), "a plain prompt")
	assert_eq(hud.events.prompt_text().find(name), -1, "that doesn't name it")
	assert_eq(events.label_count(), 0, "still no name over it up close")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.ev.open, k, "E opened it")
	var panel := hud.events.panel
	assert_true(panel.is_open() and panel.visible, "the panel shows")
	assert_eq(panel.title_text(), name, "and names it")
	var t := Events.table(w, k)
	var c := -1
	for j in t.choice_count():
		if w.ev.roll_curse[k * Events.MAX_CHOICES + j] >= 0:
			c = j
	assert_gte(c, 0, "a choice carries a curse")
	if c < 0:
		return
	assert_true(panel.card_enabled(c), "and can be taken")
	await e.tap(KEY_1 + c)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_eq(w.ev.open, -1, "Enter took it")
	assert_eq(w.ev.result_choice, c, "the cursed choice")
	assert_eq(w.curses_owned.size(), 1, "the curse is held")
	assert_eq(w.ev.state[k], Events.State.DONE, "the altar is spent")
	await e.frames(2)
	assert_true(hud.events.threat.visible, "threat shows on the HUD")
