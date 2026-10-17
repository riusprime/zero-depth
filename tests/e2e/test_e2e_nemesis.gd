extends GutTest
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards", F7; FINAL_BOSS.md F6-F8): the Nemesis through main.tscn with real
## input only.
## - The Playground on a Blade run and on a Gun run (the main menu's row): a wand card added at level 3 (Build tab),
##   God mode (Player tab), "Phase 3" (Spawn tab): the Nemesis rises holding the run's weapon, fights with it (a Blade
##   run's combo or crescents, a Gun run's own shots in its look), answers the hero's dash (Space) with its own, and
##   casts the card, its name over its head.
## - v0.8.0 N2 (owner O42, O52: "The Fallen", "on and off"): it rises in its own kit; its mimic window is warned on the
##   boss bar's line (HUD_FALLEN_WARN) and by the violet rings at the hero's and its feet, then opens
##   (HUD_FALLEN_WINDOW, the rings and the thread between them): in the window it copies the weapon, dash and card.
## - A run on its second loop (a labelled TEST HELPER sets the loop and the floor; F10's Restart floor rebuilds it):
##   God mode and Kill boss (the dev panel) through the Colossus and the Prism, the Ascension portal on the way; at the
##   Nemesis, its HP is the pace's (N2) and in its window it answers a dash; Kill boss beats it: the victory recap with
##   the true ending, Crown Breaker, Untouched and Beyond the Loop unlocked.

const LEG_FRAMES := 7000
const LIMIT := 1500

var _e: E2e
var _scale := Vector2.ONE


func after_each() -> void:
	Input.action_release(&"pause")
	Input.action_release(&"ui_accept")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)
	if _e != null:
		_e.stick_toward(Vector2.ZERO)


func _press(main: Main, n: String) -> void:
	var b := main.playground.panel.find_child(n, true, false) as Button
	assert_not_null(b, n)
	b.grab_focus()
	await _e.tap(KEY_ENTER)
	await _e.frames(2)


func _tab(main: Main, i: int) -> void:
	var tabs := main.playground.panel.tabs
	var bar := tabs.get_tab_bar()
	await _e.click_at(bar.get_global_rect().position + bar.get_tab_rect(i).get_center())
	await _e.frames(2)
	assert_eq(tabs.current_tab, i, "tab %d" % i)


func _type(text: String) -> void:
	for ch in text:
		for pressed in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = OS.find_keycode_from_string(ch)
			ev.physical_keycode = ev.keycode
			ev.unicode = ch.unicode_at(0)
			ev.pressed = pressed
			_e.send(ev)
		await _e.frames(1)


## The Playground on a `build` run, a wand card added at level 3, God mode, then Phase 3; returns the card's code.
func _playground_phase_3(main: Main, build: StringName) -> int:
	for k in 4:  # Play -> Options -> Credits -> Codex -> Playground
		await _e.tap(KEY_DOWN)
	await _e.tap(KEY_ENTER)
	await _e.frames(2)
	await _e.tap(KEY_RIGHT if build == &"gun" else KEY_LEFT)  # the Playground's picker opens on the Gun
	await _e.tap(KEY_ENTER)
	await _e.frames(4)
	assert_not_null(main.playground, "in the Playground")
	await _e.tap(KEY_F1)
	await _tab(main, 0)
	var panel := main.playground.panel
	var level_edit := panel.level.get_line_edit()
	level_edit.grab_focus()
	await _e.frames(2)
	level_edit.select_all()
	await _type("3")
	await _e.tap(KEY_ENTER)
	var cat := panel.catalog
	var first := cat.get_root().get_first_child().get_first_child()  # the first wand card of this run
	var code := int(first.get_metadata(0))
	cat.scroll_to_item(first)
	await _e.frames(2)
	await _e.click_at(cat.get_global_rect().position + cat.get_item_area_rect(first).get_center())
	await _e.frames(2)
	await _press(main, "Add")
	assert_true(_e.world().items_owned.has(code), "the card is in the build")
	await _tab(main, 3)
	await _press(main, "God")
	await _tab(main, 1)
	await _press(main, "FinalPhase3")
	await _e.tap(KEY_F1)
	assert_false(main.driver.paused, "the game runs")
	return code


## Waits for the current body to be past its rise; its index.
func _risen(main: Main) -> int:
	var reader := main.driver.reader
	for k in 400:
		var b := reader.boss_index()
		if b >= 0 and reader.actor_state(b) != WorldReader.STATE_SPAWN:
			return b
		await _e.frames(1)
	return reader.boss_index()


## Taps Space (the hero's dash) until the Nemesis answers with its own dash (at most `tries` dashes, a second apart).
## v0.8.0 N2: it answers only in its mimic window, so each try waits for one.
func _dash_answered(main: Main, tries: int = 10) -> bool:
	var reader := main.driver.reader
	for t in tries:
		if reader.fallen_window() != WorldReader.FALLEN_ON:
			await _until_window(main, WorldReader.FALLEN_ON)
		await _e.tap(KEY_SPACE)
		for k in 50:
			await _e.frames(1)
			var i := reader.boss_index()
			if i >= 0 and bool(reader.nemesis(i).get("dashing", false)):
				return true
		await _e.frames(10)
	return false


## v0.8.0 N2: waits until The Fallen's window is `state` (WorldReader.FALLEN_*), at most `limit` frames; true if it is.
func _until_window(main: Main, state: int, limit: int = 2400) -> bool:
	for k in limit:
		if main.driver.reader.fallen_window() == state:
			return true
		await _e.frames(1)
	return false


## v0.8.0 N2: its window shows: the boss bar's line and the rings (then the thread) at the hero's and its feet.
func _window_shows(main: Main) -> void:
	var hud: Hud = main.get_node("UI/Hud")
	assert_true(await _until_window(main, WorldReader.FALLEN_WARN), "a window is warned")
	await _e.frames(2)
	assert_eq(hud.boss_bar.fallen_text(), tr("HUD_FALLEN_WARN"), "the warning's line")
	assert_eq(main.view.nemesis_views.cue_shown(), 1, "the warning's rings")
	assert_true(await _until_window(main, WorldReader.FALLEN_ON), "the window opens")
	await _e.frames(2)
	assert_true(
		hud.boss_bar.fallen_text().begins_with(tr("HUD_FALLEN_WINDOW").get_slice("(", 0)),
		"the window's line"
	)
	assert_eq(main.view.nemesis_views.cue_shown(), 2, "the rings and the thread")


func _mimics(main: Main, build: StringName) -> void:
	var code := await _playground_phase_3(main, build)
	var reader := main.driver.reader
	var w := _e.world()
	var i := await _risen(main)
	assert_gte(i, 0, "a body is here")
	assert_eq(reader.final_phase(), 2, "the jump went to phase 3")
	assert_eq(reader.actor_kind(i), WorldReader.KIND_NEMESIS, "the Nemesis")
	var n := reader.nemesis(i)
	assert_eq(n["weapon"], build, "it takes the run's weapon")
	assert_eq((n["cards"] as Array).size(), 1, "and the card")
	assert_eq(int((n["cards"] as Array)[0]["code"]), code)
	var avatar: Node = main.view.actors.actor_node(reader.actor_id(i)).get_meta(&"enemy_avatar")
	assert_true(avatar is NemesisAvatar, "drawn as the Nemesis")
	assert_eq((avatar as NemesisAvatar).weapon_kind, build, "the weapon in its hand")
	assert_eq(reader.fallen_window(), WorldReader.FALLEN_OFF, "N2: it rises in its own kit")
	await _window_shows(main)
	assert_true(await _dash_answered(main), "in its window it dashes when the hero dashes")
	var weapon_ids: Array = (
		[&"nemesis_combo", &"nemesis_crescents"]
		if build == &"blade"
		else [&"nemesis_volley", &"nemesis_point_blank"]
	)
	var used_weapon := false
	var named := ""
	var bolts := 0
	for k in LIMIT:
		await _e.frames(1)
		i = reader.boss_index()
		if i < 0:
			break
		var atk := BossAi.attack_of(w, i)  # a read
		var copying := bool(reader.final_pace().get("copying", false))
		if atk != null and copying and weapon_ids.has(atk.id):
			used_weapon = true
		assert_false(
			(
				atk != null
				and copying
				and not weapon_ids.has(atk.id)
				and atk.move != BossAttackTable.Move.CARD_CAST
			),
			"in a window never the other weapon's attack"
		)
		assert_false(
			atk != null and not copying and atk.move == BossAttackTable.Move.CARD_CAST,
			"no card outside a window"
		)
		if main.view.nemesis_views.card_shown() != "":
			named = main.view.nemesis_views.card_shown()
		bolts = maxi(bolts, main.view.fireballs.ball_count(NemesisCast.LOOK_BOLT))
		if used_weapon and named != "" and (build == &"blade" or bolts > 0):
			break
	assert_true(used_weapon, "it fights with the run's weapon")
	assert_eq(named, tr(StringName(reader.card_info(code)["name_key"])), "it casts your card")
	if build == &"gun":
		assert_gt(bolts, 0, "your shots, in its look")
	assert_false(w.player_dead(), "the hero stands (God mode)")


func test_the_nemesis_mimics_a_blade_run_in_the_playground() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	_scale = await _e._mouse_scale()
	await _mimics(main, &"blade")


func test_the_nemesis_mimics_a_gun_run_in_the_playground() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	_scale = await _e._mouse_scale()
	await _mimics(main, &"gun")


# --- the run: a true ending ----------------------------------------------------------------------------------------


func _walk(target: Vector2, done: Callable, push: Vector2 = Vector2.ZERO) -> bool:
	var w := _e.world()
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
		_e.stick_toward(dir)
		await _e.frames(1)
		if w.player_dead():
			break
	_e.stick_toward(Vector2.ZERO)
	return done.call()


func _click(main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await _e.click_at(b.get_global_rect().get_center())


func test_beating_the_nemesis_on_a_later_loop_is_the_true_ending() -> void:
	_e = E2e.new(self)
	var main: Main = await _e.boot()
	await _e.start_from_menu()
	main.run.loop = 2  # TEST HELPER (labelled): the run's second loop, on its last floor
	main.run.loop_floors = main.run.table.floors
	main.run.floor_index = main.run.table.floors
	await _e.tap(KEY_F10)
	var panel := main.get_node_or_null("UI/DevMasterPanel") as DevMasterPanel
	assert_not_null(panel, "F10 opens the panel")
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.text == "UI_DEVM_RESTART":
			b.grab_focus()
	await _e.tap(KEY_ENTER)
	await _e.frames(4)
	var w := _e.world()
	var f := w.floor_layout
	await _e.tap(KEY_QUOTELEFT)
	await _click(main, "God")
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	assert_true(sealed, "walked through the boss door")
	await _e.frames(30)
	await _click(main, "KillBoss")
	await _e.frames(12)
	var took: bool = await _walk(
		f.portal_pos + f.portal_facing() * 1.0,
		func() -> bool: return main.driver.reader.ascension_choice() == WorldReader.ASCEND_PORTAL,
		-f.portal_facing()
	)
	assert_true(took, "walked into the Ascension portal (v0.8.0 P2: no menu)")
	var frames := 0
	while (main.run == null or not main.run.final_fight) and frames < 400:
		await _e.frames(1)
		frames += 1
	await _e.frames(3)
	assert_true(main.driver.reader.final_arena(), "the final arena")
	assert_eq(main.driver.reader.loop(), 2, "on the second loop")
	await _e.tap(KEY_QUOTELEFT)
	await _click(main, "God")
	await _e.frames(150)
	for phase in [0, 1]:  # the Colossus's and the Prism's segments end
		await _click(main, "KillBoss")
		frames = 0
		while main.driver.reader.final_phase() == phase and frames < 260:
			await _e.frames(1)
			frames += 1
	# v0.8.0 N2: the panel stays open (its buttons take no focus), so God mode holds while the hero waits for The
	# Fallen's window (closing it drops the debug tools: O27's hits would kill the hero meanwhile)
	var reader := main.driver.reader
	w = _e.world()
	var i := await _risen(main)
	assert_eq(reader.actor_kind(i), WorldReader.KIND_NEMESIS, "the Nemesis rises")
	var t := BossAi.table_of(w, i)  # reads
	var pace := reader.final_pace()
	var expect := FinalPace.hp_for(w.final_fight.pace_dps, t) if bool(pace["paced"]) else -1
	if expect > 0:
		assert_eq(reader.actor_max_hp(i), expect, "N2: its HP from the pace")
	assert_gte(
		reader.actor_max_hp(i), t.dps_hp_min, "its HP (the pace's, or its own before a meter)"
	)
	assert_eq(reader.nemesis(i)["weapon"], &"blade", "the run's Blade")
	await _window_shows(main)
	assert_true(await _dash_answered(main, 20), "in its window it answers a dash")
	await _click(main, "KillBoss")
	frames = 0
	while main.get_node_or_null("UI/EndPanel") == null and frames < 600:
		await _e.frames(1)
		frames += 1
	var end := main.get_node_or_null("UI/EndPanel") as EndPanel
	assert_not_null(end, "the run's end panel")
	if end == null:
		return
	assert_eq(main.driver.reader.outcome(), 1, "a victory")
	assert_eq(end.recap_line("TrueEnding"), tr("UI_RECAP_TRUE_ENDING"), "the true ending")
	assert_true(main.achievements.is_unlocked(&"final_boss"), "Crown Breaker")
	assert_true(
		main.achievements.is_unlocked(&"final_no_hit"), "Untouched (God mode: no hit lands)"
	)
	assert_true(main.achievements.is_unlocked(&"final_looped"), "Beyond the Loop")
	assert_eq(get_errors().size(), 0, "no engine or script error")
