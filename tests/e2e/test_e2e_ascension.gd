extends GutTest
## v0.7.5 AP (owner N4): the Ascension portal and the endless loop through main.tscn with real input only. The run is
## moved to its last floor by a labelled TEST HELPER (the run's floor number) and the F10 panel's Restart floor (a key
## press) rebuilds it; the dev panel (backtick, mouse clicks: God mode for the long walk, Kill boss) stands in for the
## fight as in test_e2e_run_flow; the left stick walks through the boss door. v0.8.0 P2 (owner O28): no choice panel;
## the boss's death opens two devices, both drawn (v0.8.0 N18, O76: no names over them
## and no HUD line about them). The stick walks onto the Loop device:
## the build goes into loop 2's floor 1, "Loop 2 · Floor 1" on the HUD, the Codex counts it, and Continue after Main
## menu resumes loop 2. Another run walks into the Ascension portal: on to the final arena (v0.8.0 FB1).

const LEG_FRAMES := 7000


func after_each() -> void:
	Input.action_release(&"pause")
	Input.action_release(&"ui_accept")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


## Walks the left stick along the flow field toward `target` until `done` is true (or the frame limit).
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


## Boots, starts a run and puts it on its last floor: TEST HELPER (labelled) sets the run's floor number to the
## last (walking three floors is test_e2e_run_flow's and test_e2e_portal's job), then F10 -> Restart floor (Enter on
## the focused button, as test_e2e_dev_master_panel) rebuilds the run's current floor from it.
func _boot_on_last_floor(e: E2e) -> Main:
	var main: Main = await e.boot()
	await e.start_from_menu()
	main.run.floor_index = main.run.table.floors  # TEST HELPER (labelled)
	await e.tap(KEY_F10)
	var panel := main.get_node_or_null("UI/DevMasterPanel") as DevMasterPanel
	assert_not_null(panel, "F10 opens the panel")
	var restart: Button = null
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.text == "UI_DEVM_RESTART":
			restart = b
	restart.grab_focus()  # GUT's output window covers the top bar's right end (as test_e2e_dev_master_panel)
	await e.tap(KEY_ENTER)
	await e.frames(4)
	assert_eq(e.world().floor_index, main.run.table.floors, "the run's last floor")
	return main


## God mode, through the boss door, Kill boss: true when both devices opened (v0.8.0 P2: the Ascension portal and the
## Loop device beside it, no menu).
func _to_the_devices(e: E2e, main: Main) -> bool:
	var w := e.world()
	var f := w.floor_layout
	assert_true(main.driver.reader.ascension_floor(), "the last floor has the Ascension portal")
	assert_not_null(main.view.ascension, "drawn as the Ascension portal")
	assert_null(main.view.gate, "not the blue gate")
	assert_not_null(main.view.loop_device, "and the Loop device beside it")
	assert_true(main.view.ascension.is_sealed(), "dormant while the boss lives")
	assert_true(main.view.loop_device.is_sealed(), "both")
	assert_null(main.get_node_or_null("UI/Hud/AscensionPanel"), "no choice panel any more")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	assert_true(sealed, "walked through the boss door")
	if not sealed:
		return false
	await e.frames(30)
	await _click(e, main, "KillBoss")
	await e.frames(3)
	assert_true(main.driver.reader.portal_active(), "the portal is open")
	await e.frames(10)
	assert_false(main.view.ascension.is_sealed(), "the column rises")
	assert_gt(main.view.ascension.rise, 0.0)
	assert_false(main.view.loop_device.is_sealed(), "the Loop device lights")
	# v0.8.0 N18 (owner O76: the game stops explaining): no floating names, no HUD lines about the two devices
	for n: Node3D in [main.view.loop_device, main.view.ascension]:
		assert_eq(
			n.find_children("*", "Label3D", true, false).size(), 0, "%s: no floating name" % n.name
		)
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(hud.gate_text(), "", "the HUD explains neither device")
	await e.tap(KEY_QUOTELEFT)  # the dev panel away (God mode stays)
	return true


## Walks onto the Loop device until the hero goes in.
func _onto_loop(e: E2e, main: Main) -> bool:
	var f := e.world().floor_layout
	var took: bool = await _walk(
		e,
		f.loop_pos,
		func() -> bool: return main.driver.reader.ascension_choice() == WorldReader.ASCEND_LOOP
	)
	return took


func test_the_loop_device_carries_the_build_into_loop_two() -> void:
	var e := E2e.new(self)
	var main := await _boot_on_last_floor(e)
	if not await _to_the_devices(e, main):
		return
	var w := e.world()
	var owned := w.ability_owned.duplicate()
	var levels := w.ability_levels.duplicate()
	var items := w.items_owned.duplicate()
	var wand := w.mod_slots.duplicate()
	var cards := w.card_levels.duplicate()
	var stats := w.stat_values.duplicate()
	var biome_left := main.run_biome_id()
	assert_true(await _onto_loop(e, main), "stepping onto the Loop device takes it")
	assert_false(main.run.final_fight, "not the final boss")
	var frames := 0
	while main.run.loop == 1 and frames < 300:
		await e.frames(1)
		frames += 1
	assert_eq(main.run.loop, 2, "the Loop device: loop 2")
	await e.frames(3)
	var w2 := e.world()
	assert_ne(w2, w, "a new floor")
	assert_eq(main.run.floor_index, 1, "its floor 1")
	assert_eq(w2.floor_index, 1)
	assert_eq(w2.loop, 2)
	assert_eq(w2.run_floor_index(), main.run.table.floors + 1, "the run's floor keeps counting")
	assert_ne(main.run_biome_id(), biome_left, "a new biome")
	assert_eq(w2.ability_owned, owned, "the abilities came along")
	assert_eq(w2.ability_levels, levels, "at their levels")
	assert_eq(w2.items_owned, items, "the items")
	assert_eq(w2.mod_slots, wand, "the wand, in its order")
	assert_eq(w2.card_levels, cards, "the cards' levels")
	assert_eq(w2.stat_values, stats, "the stats")
	assert_eq(Wand.slots(w2), Wand.slots(w), "the wand keeps its slots")
	assert_eq(w2.loop_threat, main.run.table.loop_threat, "harder: the loop's threat")
	assert_gte(main.driver.reader.threat(), main.run.table.loop_threat, "threat T shows it")
	var hud: Hud = main.get_node("UI/Hud")
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(
		&"biomes", main.run_biome_id()
	)
	assert_eq(
		hud.floor_text(),
		tr("HUD_LOOP") % 2 + " · " + tr("HUD_FLOOR") % [1, tr(biome.name_key)],
		"the HUD says Loop 2 · Floor 1"
	)
	assert_true(hud.floor_card_text().begins_with(tr("HUD_LOOP") % 2), "and so does the card")
	assert_eq(main.codex.count(&"runs", &"ascended", &"times"), 1, "the Codex counts the loop")
	assert_eq(main.codex.count(&"runs", &"loop", &"best"), 2, "and the loop reached")
	# Continue mid-loop: Esc -> Main menu, then Continue (focused) resumes loop 2's floor 1.
	await e.frames(90)  # past the arrival and the start hall's save
	await e.tap(KEY_ESCAPE)
	for k in 5:  # Resume -> Build -> Restart run -> Options -> Codex -> Main menu
		await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "back on the main menu")
	await e.tap(KEY_ENTER)  # Continue has focus
	await e.frames(4)
	assert_true(main.is_playing(), "Continue resumed the run")
	assert_eq(main.run.loop, 2, "in loop 2")
	assert_eq(main.run.floor_index, 1)
	assert_eq(e.world().loop, 2)
	assert_eq(e.world().items_owned, items, "with the build")
	assert_eq(get_errors().size(), 0, "no engine or script error")


## v0.8.0 P2 (owner O28): walking into the Ascension portal goes straight on to the final arena (no menu; the fight and
## its victory recap: test_e2e_final_boss).
func test_the_ascension_portal_leads_to_the_final_arena() -> void:
	var e := E2e.new(self)
	var main := await _boot_on_last_floor(e)
	if not await _to_the_devices(e, main):
		return
	var f := e.world().floor_layout
	var took: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return main.driver.reader.ascension_choice() == WorldReader.ASCEND_PORTAL,
		-f.portal_facing()
	)
	assert_true(took, "walking into the light takes the portal")
	var frames := 0
	while not main.run.final_fight and frames < 400:
		await e.frames(1)
		frames += 1
	await e.frames(3)
	assert_true(main.run.final_fight, "on to the final boss")
	assert_true(main.driver.reader.final_arena(), "the final arena")
	assert_null(main.get_node_or_null("UI/EndPanel"), "no recap")
	assert_eq(main.run.loop, 1, "no new loop")
	assert_eq(main.codex.count(&"runs", &"ascended", &"times"), 0, "no loop counted")
	assert_eq(get_errors().size(), 0, "no engine or script error")
