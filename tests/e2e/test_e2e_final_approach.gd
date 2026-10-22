extends GutTest
## v0.9.0 FA (owner C §3: "The player should no longer teleport directly into the final boss arena … the player must
## activate a small number of mechanisms … The boss sequence must only trigger once the required activations are
## complete"; Q18: the stair causeway, one press per pylon, the plateau is the arena), through main.tscn with real
## input only. As test_e2e_final_boss: a labelled TEST HELPER moves the run to its last floor and F10's Restart floor
## rebuilds it; the dev panel (God mode, Kill boss) stands in for the floor's boss. Walking into the Ascension portal
## opens the final approach: the hero lands at the causeway's foot, nobody else is there and no boss bar shows; E far
## from a pylon does nothing; by pylon A the prompt says "Awaken", E locks it in (its sound, its runes on the purple
## altar) and still no boss comes; by pylon B, E starts the buildup (the altar's runes spin, its sound), the walls of
## light rise and the Colossus rises from the altar; a save is taken at its start. All in well under 30 s.

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


## The run on its last floor (TEST HELPER, labelled), rebuilt by F10's Restart floor; through the boss with the dev
## panel; into the Ascension portal. True once the final world is up.
func _to_the_approach(e: E2e) -> Main:
	var main: Main = await e.boot()
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


func _played(main: Main, id: StringName) -> int:
	var n := 0
	for c in main.audio.played_log:
		if c == id:
			n += 1
	return n


func test_the_ascension_portal_opens_the_approach_and_two_pylons_wake_the_colossus() -> void:
	var e := E2e.new(self)
	var main := await _to_the_approach(e)
	assert_true(main.run.final_fight, "on to the final boss")
	var reader := main.driver.reader
	var w := e.world()
	assert_true(reader.final_approach(), "C25: not straight into the arena: the approach")
	assert_true(reader.final_arena(), "the final world")
	assert_null(w.final_fight, "no fight yet")
	assert_not_null(main.view.approach_view, "the approach is drawn")
	assert_eq(main.view.approach_view.altar.look.color, AltarStage.VIOLET, "the purple altar")
	assert_eq(main.view.approach_view.pylons.size(), 2, "two pylons")
	assert_null(main.view.gate, "no run gate")
	assert_null(main.view.receiver, "no floor receiver")
	assert_gt(
		main.view.stage.final_arena.flights.size(),
		0,
		"the stair causeway (v0.9.0 MI2: the owner's flights)"
	)
	assert_true(await e.landed(), "the hero lands")
	var t0 := w.tick
	assert_eq(w.player_pos(), w.floor_layout.causeway_foot, "at the causeway's foot")
	var hud := main.get_node("UI/Hud") as Hud
	assert_false(hud.boss_bar.visible, "no boss bar")
	await e.tap(KEY_E)  # far from any pylon
	await e.frames(3)
	assert_eq(reader.approach_pylons_lit(), 0, "E far from a pylon does nothing")
	var f := w.floor_layout
	assert_true(await e.walk_to(f.pylons[0], 1.2), "walked up to pylon A")
	assert_eq(hud.interact.prompt_text(), tr("APPROACH_PYLON_PROMPT"), "the prompt by it")
	await e.tap(KEY_E)
	await e.frames(3)
	assert_true(reader.approach_pylon_lit(0), "E locked pylon A in")
	assert_true(main.view.approach_view.locked[0], "it lit up")
	assert_eq(_played(main, &"pylon_lock"), 1, "with its sound")
	assert_eq(hud.interact.prompt_text(), "", "no prompt by a lit pylon")
	await e.frames(120)
	assert_null(w.final_fight, "one pylon: still no boss")
	assert_true(await e.walk_to(f.pylons[1], 1.2), "walked over to pylon B")
	await e.tap(KEY_E)
	await e.frames(3)
	assert_eq(
		reader.approach_state(), WorldReader.APPROACH_BUILDUP, "the second starts the buildup"
	)
	assert_eq(_played(main, &"pylon_lock"), 2)
	var spun := 0.0
	var frames := 0
	while w.final_fight == null and frames < FinalApproach.BUILDUP_TICKS + 60:
		spun = maxf(spun, main.view.approach_view.altar.angle)
		await e.frames(1)
		frames += 1
	assert_gt(spun, 0.0, "the purple runes spun")
	assert_not_null(w.final_fight, "C32: the encounter began")
	assert_true(reader.approach_walls_up(), "the walls of light rose")
	await e.frames(3)
	assert_true(main.view.approach_view.walls_up, "and are drawn")
	assert_eq(_played(main, AltarStage.final().cue), 1, "the altar's sound")
	var body := reader.boss_index()
	assert_eq(reader.actor_kind(body), WorldReader.KIND_COLOSSUS, "the Colossus")
	assert_eq(reader.actor_pos(body), f.altar_pos, "risen from the altar")
	var took := w.tick - t0
	gut.p("landing to the Colossus through real input: %d ticks (%.1f s)" % [took, took / 60.0])
	assert_lt(took, 30 * 60, "C33: well under 30 s")
	await e.frames(2)
	var saved: Dictionary = main.saves.last
	assert_eq(int(saved["world"]["world"][&"final_fight"][&"phase"]), 0, "a save at its start")
	assert_true(FloorPlan.approach_of(saved), "which resumes on the approach's plateau")
	assert_eq(get_errors().size(), 0, "no engine or script error")
