extends GutTest
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F1-F3): the final boss through main.tscn with real input only. As
## test_e2e_ascension: the run is moved to its last floor by a labelled TEST HELPER and F10's Restart floor rebuilds it;
## the dev panel (backtick, clicks: God mode, Kill boss) stands in for the fights. Walking into the Ascension portal
## (v0.8.0 P2: no menu) takes the hero to the final arena: a round room drawn as the cosmic arena, the boss bar one bar
## in three named segments. Kill boss ends the Colossus's segment: it shatters (the bar says SHATTERED, no hostile shot
## stays), the Prism rises from its shards, a save is taken at the Prism's start and Continue after Main menu resumes
## there; two more Kill boss win the run: the victory recap with the true ending line, the achievement unlocked.

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


## As test_e2e_ascension: boots, starts a run, TEST HELPER (labelled) sets the run's floor to its last, F10 -> Restart
## floor rebuilds it.
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
	restart.grab_focus()
	await e.tap(KEY_ENTER)
	await e.frames(4)
	return main


## God mode, through the boss door, Kill boss, into the Ascension portal (P2: no menu): true once the final arena is
## the world. The dev panel stays open (its God mode keeps the hero up in the arena too).
func _to_the_arena(e: E2e, main: Main) -> bool:
	var w := e.world()
	var f := w.floor_layout
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
	await e.frames(12)
	var took: bool = await _walk(
		e,
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return main.driver.reader.ascension_choice() == WorldReader.ASCEND_PORTAL,
		-f.portal_facing()
	)
	assert_true(took, "walking into the Ascension portal takes it (v0.8.0 P2: no menu)")
	if not took:
		return false
	var frames := 0
	while (main.run == null or not main.run.final_fight) and frames < 400:
		await e.frames(1)
		frames += 1
	await e.frames(3)
	return main.run != null and main.run.final_fight


func _hud(main: Main) -> Hud:
	return main.get_node("UI/Hud") as Hud


func _hostile_shots(w: World) -> int:
	var n := 0
	for k in w.projectiles.size():
		if w.projectiles.team[k] != ActorStore.TEAM_PLAYER:
			n += 1
	return n


func test_the_ascension_portal_walks_into_the_final_boss_and_beats_it() -> void:
	var e := E2e.new(self)
	var main := await _boot_on_last_floor(e)
	if not await _to_the_arena(e, main):
		return
	var reader := main.driver.reader
	var w := e.world()
	assert_true(reader.final_arena(), "the world is the final arena")
	assert_eq(main.run.loop, 1, "no new loop")
	assert_null(main.get_node_or_null("UI/EndPanel"), "the run goes on")
	assert_not_null(main.view.stage.final_arena, "drawn as the cosmic arena")
	assert_eq(main.view.stage.final_arena.wall_nodes.size(), 32, "its round wall")
	assert_gt(main.view.stage.final_arena.brazier_count, 0, "braziers")
	assert_not_null(main.view.stage.final_arena.gate, "the sealed gate")
	assert_null(main.view.gate, "no portal")
	var body := reader.boss_index()
	assert_gte(body, 0, "the Colossus is here")
	assert_eq(reader.actor_kind(body), WorldReader.KIND_COLOSSUS)
	var avatar: Node = main.view.actors.actor_node(reader.actor_id(body)).get_meta(&"enemy_avatar")
	assert_true(avatar is ColossusAvatar, "drawn as the Colossus")
	await e.tap(KEY_QUOTELEFT)  # the dev panel again (a new world): God mode for the fight
	await _click(e, main, "God")
	await e.frames(150)  # the arrival, then its rise
	var bar := _hud(main).boss_bar
	assert_true(bar.visible, "the boss bar shows")
	assert_eq(bar.boss_name(), tr("BOSS_HOLLOW_CROWN"), "one boss: the Hollow Crown")
	assert_eq(bar.segment_count(), 3, "in three segments")
	assert_almost_eq(bar.segment_fraction(0), 1.0, 0.01, "the Colossus's is full")
	assert_almost_eq(bar.segment_fraction(2), 1.0, 0.01, "the bodies to come are full")
	# The Colossus's segment ends: it shatters.
	await _click(e, main, "KillBoss")
	await e.frames(3)
	assert_true(reader.final_shattering(), "it shatters")
	assert_eq(bar.status_text(), tr("HUD_FINAL_SHATTER"), "the bar says so")
	assert_almost_eq(bar.segment_fraction(0), 0.0, 0.01, "its segment is empty")
	for k in 20:
		await e.frames(1)
		assert_eq(_hostile_shots(w), 0, "no hostile shot while it shatters")
	var frames := 0
	while reader.final_phase() < 1 and frames < 200:
		await e.frames(1)
		frames += 1
	assert_eq(reader.final_phase(), 1, "the next body")
	assert_eq(reader.actor_kind(reader.boss_index()), WorldReader.KIND_PRISM, "the Prism rises")
	assert_eq(main.view.final_views.burst_count(), 1, "from the Colossus's shards")
	assert_gt(main.view.final_views.shard_count(), 0)
	await e.frames(2)
	var saved: Dictionary = main.saves.last
	assert_true(bool(saved.get("run", {}).get("final", false)), "a save at the Prism's start")
	assert_eq(int(saved["world"]["world"][&"final_fight"][&"phase"]), 1)
	# Main menu, then Continue: the fight resumes at the Prism's start.
	await e.tap(KEY_ESCAPE)
	for k in 5:  # Resume -> Build -> Restart run -> Options -> Codex -> Main menu
		await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "back on the main menu")
	await e.tap(KEY_ENTER)  # Continue has focus
	await e.frames(4)
	assert_true(main.is_playing(), "Continue resumed the run")
	assert_true(main.driver.reader.final_arena(), "in the final arena")
	assert_eq(main.driver.reader.final_phase(), 1, "at the Prism")
	assert_eq(
		main.driver.reader.actor_kind(main.driver.reader.boss_index()), WorldReader.KIND_PRISM
	)
	# The Prism's and the Nemesis's segments end: the run is won.
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.frames(130)
	for phase in [1, 2]:
		await _click(e, main, "KillBoss")
		frames = 0
		while main.driver != null and main.driver.reader.final_phase() == phase and frames < 260:
			await e.frames(1)
			frames += 1
			if main.driver.reader.final_won():
				break
		await e.frames(130)
	frames = 0
	while main.get_node_or_null("UI/EndPanel") == null and frames < 400:
		await e.frames(1)
		frames += 1
	var end := main.get_node_or_null("UI/EndPanel") as EndPanel
	assert_not_null(end, "the run's end panel")
	if end == null:
		return
	assert_eq(main.driver.reader.outcome(), 1, "a victory")
	assert_eq((end.box.find_child("Title", true, false) as Label).text, "UI_RUN_COMPLETE")
	assert_eq(end.recap_line("TrueEnding"), tr("UI_RECAP_TRUE_ENDING"), "the true ending")
	assert_eq(end.recap_line("Loops"), tr("UI_RECAP_LOOPS") % 1, "the loop cleared")
	assert_false(main.saves.store.has_save(), "a won run leaves no save")
	assert_true(main.achievements.is_unlocked(&"final_boss"), "Crown Breaker unlocked")
	assert_eq(get_errors().size(), 0, "no engine or script error")
