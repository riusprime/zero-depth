extends GutTest
## v0.8.0 BS2 (owner O5; BOSS_SIGNATURES.md S4-S6): the Hive Lens's Gaze, the Siege Engine's ricochet shells and the
## Foundry's lava and meltdown reach the real game. Through main.tscn with real input only (Input.parse_input_event):
## backtick opens the dev panel, clicks turn on God, pick the boss and summon it, backtick closes it. The boss fights
## on its own: the Gaze's beam is drawn (BossSignatureViews), a Turret Cross ember's bounce off a wall throws sparks,
## a Molten Flood leaves lava drawn on the floor. For the meltdown, F10 first sets the Foundry's phase-2 and phase-3
## thresholds to 1000 (typed into its rows, then Restart floor), so the summoned Foundry goes through both gates
## at once and opens phase 3 with the meltdown: the outer ring glows, then melts.

const FOUNDRY := "res://data/bosses/foundry.tres"
const SAVE := "user://e2e_boss_signatures_2.json"

var _e: E2e


func after_each() -> void:
	if _e != null and _e.main != null:
		_e.main.tuning.reset_all()
		_e.main.tuning.apply()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _summon(e: E2e, main: Main, id: StringName) -> int:
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, id)].name_key)
	for k in 8:
		if choice.text == name:
			break
		await _click(e, main, "NextBoss")
		await e.frames(1)
	assert_eq(choice.text, name)
	await _click(e, main, "SpawnBoss")
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	assert_false(main.is_dev_panel_open())
	var reader := main.driver.reader
	return reader.actor_id(reader.boss_index())


func test_the_hive_lens_turns_its_gaze_round_the_room() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var bid := await _summon(e, main, &"hive_lens")
	var w := e.world()
	var beam := false
	for k in 9000:
		await e.frames(1)
		if w.actors.index_of(bid) < 0:
			break
		if (main.view.signatures.get_node("GazeBeam") as Node3D).visible:
			beam = true
			break
	assert_true(beam, "the Gaze's beam drawn")


func test_the_siege_engines_shells_ricochet() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var bid := await _summon(e, main, &"siege_engine")
	var w := e.world()
	var sparks := 0
	for k in 9000:
		await e.frames(1)
		if w.actors.index_of(bid) < 0:
			break
		sparks = main.view.signatures.spark_count()
		if sparks > 0:
			break
	assert_gt(sparks, 0, "an ember bounced off a wall")


func test_the_foundry_leaves_lava() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var bid := await _summon(e, main, &"foundry")
	var w := e.world()
	var lava := 0
	for k in 9000:
		await e.frames(1)
		if w.actors.index_of(bid) < 0:
			break
		lava = main.view.signatures.lava_count()
		if lava > 0:
			break
	assert_gt(lava, 0, "lava drawn on the floor")


func test_the_foundrys_phase_three_melts_the_outer_ring() -> void:
	_e = E2e.new(self)
	var main: Main = await _e.boot()
	main.tuning.save_path = SAVE
	await _e.start_from_menu()
	await _e.tap(KEY_F10)
	var panel := main.get_node_or_null("UI/DevMasterPanel") as DevMasterPanel
	assert_not_null(panel, "F10 opens the panel")
	var t: Tree = null
	for n in panel.find_children("*", "Tree", true, false):
		t = n
	var item := _find(t.get_root(), "foundry")
	assert_not_null(item, "the Foundry is listed (the Bosses page)")
	t.scroll_to_item(item)
	await _e.frames(2)
	await _e.click_at(t.get_global_rect().position + t.get_item_area_rect(item).get_center())
	await _e.frames(2)
	for phase in [1, 2]:
		var spin := (
			panel.editor_of(DevTuning.key_of(FOUNDRY, "phases/%d/hp_threshold_permille" % phase))
			as SpinBox
		)
		assert_not_null(spin, "phase %d's threshold is a row" % (phase + 1))
		var line := spin.get_line_edit()
		line.grab_focus()  # GUT's output window covers the panel's right side (test_e2e_dev_master_panel)
		await _e.frames(2)
		line.select_all()
		await _type("1000")
		await _e.tap(KEY_ENTER)
	var restart: Button = null
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.text == "UI_DEVM_RESTART":
			restart = b
	restart.grab_focus()
	await _e.tap(KEY_ENTER)
	await _e.frames(4)
	var bid := await _summon(_e, main, &"foundry")
	var w := _e.world()
	var glowed := false
	var melted := false
	for k in 3000:
		await _e.frames(1)
		if w.actors.index_of(bid) < 0:
			break
		var rows: Array = main.driver.reader.boss_melts()
		if not rows.is_empty() and float(rows[0]["radius"]) == INF:
			glowed = true
		if not w.bosses.melt_boss.is_empty() and main.view.signatures.melt_count() > 0:
			melted = true
			break
	assert_true(glowed, "the ring glowed through its roar")
	assert_true(melted, "phase 3 melts the outer ring")


## Types `text` as key presses that carry their characters (as test_e2e_dev_master_panel).
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


func _find(it: TreeItem, text: String) -> TreeItem:
	if it == null:
		return null
	if it.get_text(0) == text:
		return it
	var c := it.get_first_child()
	while c != null:
		var f := _find(c, text)
		if f != null:
			return f
		c = c.get_next()
	return null
