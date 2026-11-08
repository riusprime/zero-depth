extends GutTest
## v0.11.0 O14b (owner Q-O14b "Both"; OWNER_QUESTIONS §J N1, N2) through main.tscn with real input only: a profile that
## learned all ten Runic Stone lines (r11 known: a labelled TEST HELPER writes them) starts a run; as
## test_e2e_final_approach, a labelled TEST HELPER moves the run to its last floor and F10's Restart floor rebuilds it,
## the dev panel (God, Kill boss) stands in for the floor's boss, and the Ascension portal opens the final approach.
## There the ring's cracked wall hides the heart room (unseen); the stick walks up to it and Q (the Blade's Lunge
## Cleave) breaks it in three uses; the room comes into sight (its rune slab carved), E by the pedestal takes the
## City's Heart (its Codex entry unlocks), and by the sealed door no prompt shows but its rune line does.

const LEG_FRAMES := 7000


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)
	E2e.center_sticks()


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


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


## TEST HELPER (labelled): a profile whose Runic Stone learned r1-r10 and so r11.
func _ten_lines() -> ProfileStore:
	var p := ProfileStore.new("")
	var learned := []
	for k in 11:
		learned.append("r%d" % (k + 1))
	p.data["runes"] = {"learned": learned}
	return p


## As test_e2e_final_approach: the run on its last floor (TEST HELPER, labelled), rebuilt by F10's Restart floor;
## through the boss with the dev panel; into the Ascension portal. True once the final world is up.
func _to_the_approach(e: E2e) -> Main:
	var main: Main = await e.boot(_ten_lines())
	await e.start_from_menu()
	main.run.floor_index = main.run.table.floors  # TEST HELPER (labelled)
	await e.tap(KEY_F10)
	var panel := main.get_node_or_null("UI/DevMasterPanel") as DevMasterPanel
	var restart: Button = null
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.text == "UI_DEVM_RESTART":
			restart = b
	restart.grab_focus()
	await e.tap(KEY_ENTER)
	await e.frames(4)
	var w := e.world()
	var f := w.floor_layout
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	assert_true(await e.open_boss_door(), "E opened the boss door")
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	assert_true(sealed, "walked through the boss door")
	await e.frames(30)
	await _click(e, main, "KillBoss")
	await e.frames(12)
	await e.tap(KEY_QUOTELEFT)  # the panel closes
	var took: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return main.driver.reader.ascension_choice() == WorldReader.ASCEND_PORTAL,
		-f.portal_facing()
	)
	assert_true(took, "walked into the Ascension portal")
	var frames := 0
	while (main.run == null or not main.run.final_fight) and frames < 400:
		await e.frames(1)
		frames += 1
	await e.frames(3)
	return main


func test_break_into_the_heart_room_and_take_the_city_heart() -> void:
	TranslationServer.set_locale("en")
	var e := E2e.new(self)
	var main := await _to_the_approach(e)
	assert_true(main.run.heart_room, "the run knows the profile's ten lines")
	var reader := main.driver.reader
	var w := e.world()
	assert_true(reader.final_approach(), "on the final approach")
	assert_true(reader.heart_room(), "with the hidden room under the throne")
	var view := main.view.heart_room
	assert_not_null(view, "the room is drawn")
	if view == null:
		return
	assert_false(view.revealed, "unseen behind its cracked wall")
	assert_true(await e.landed(), "the hero lands")
	var f := w.floor_layout
	var b := w.breakables
	var goal := CrackLab.before_wall(w, 1.4)
	var to_wall := (f.door_centers[f.crack_door] - goal).normalized()
	var uses := 0
	while b.crack_broken == 0 and uses < 6:
		assert_true(await e.walk_to(goal, 0.5), "walked up to the cracked wall")
		var wait := 0
		while not PlayerSkill.ready(w) and wait < 400:
			await e.frames(5)
			wait += 5
		e.stick_toward(to_wall)  # face it
		await e.frames(4)
		e.stick_toward(Vector2.ZERO)
		await e.frames(2)
		await e.tap(KEY_Q)
		await e.frames(40)
		uses += 1
	assert_eq(b.crack_broken, 1, "Q broke it")
	assert_eq(uses, 3, "in three Skill uses")
	await e.frames(2)
	assert_true(view.revealed, "the heart room comes into sight")
	assert_gt(view.glyphs_carved, 20, "its rune slab is carved")
	assert_true(view.heart.visible, "the City's Heart on its pedestal")
	assert_true(
		await e.walk_to(f.heart_pedestal + Vector2(-1.1, 0.0), 0.4), "walked in to the pedestal"
	)
	assert_true(f.rooms[f.heart_room].has_point(w.player_pos()), "inside the heart room")
	var hud := main.get_node("UI/Hud") as Hud
	assert_eq(hud.interact.prompt_text(), tr("HEART_PEDESTAL_PROMPT"), "the prompt by the pedestal")
	await e.tap(KEY_E)
	await e.frames(4)
	assert_true(reader.relic_held(), "E took the City's Heart")
	assert_false(view.heart.visible, "the pedestal is empty")
	assert_true(main.codex.is_unlocked(&"cards", &"city_heart"), "its Codex entry unlocks")
	assert_true(
		await e.walk_to(f.heart_door + Vector2(0.0, -1.3), 0.5), "walked over to the sealed door"
	)
	await e.frames(3)
	assert_eq(hud.interact.prompt_text(), "", "no prompt at the sealed door")
	assert_true(reader.heart_door_sealed(), "it stays sealed")
	assert_true(view.bubble.is_open(), "its rune line shows")
	gut.p("HEART_E2E| uses=%d glyphs=%d" % [uses, view.glyphs_carved])
