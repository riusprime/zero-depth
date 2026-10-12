extends GutTest
## The master dev panel in the real game (docs/tools/DEV_PANEL.md Step 2), through real input: F10 opens it and
## pauses the run, a click picks an enemy in the list, typing changes its HP, Restart floor (Enter on it) rebuilds the
## floor with the new number, F10 closes it. GUT's output window covers the panel's right side in a test run, so the
## HP field and the Restart button get focus directly; the typing and the press are real key events.

const ENEMY := "res://data/enemies/arc_caster.tres"
const SAVE := "user://e2e_dev_master_panel.json"

var _e: E2e


func after_each() -> void:
	if _e != null and _e.main != null:
		_e.main.tuning.reset_all()
		_e.main.tuning.apply()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _arc_caster_hp(w: World) -> int:
	for t: EnemyTable in w.enemy_tables.values():
		if t.name_key == &"ENEMY_ARC_CASTER":
			return t.hp
	return -1


func test_f10_edit_restart_floor() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	main.tuning.save_path = SAVE
	await _e.start_from_menu()
	assert_not_null(_e.world(), "in a run")
	var shipped := _arc_caster_hp(_e.world())
	await _e.tap(KEY_F10)
	var panel := main.get_node_or_null("UI/DevMasterPanel") as DevMasterPanel
	assert_not_null(panel, "F10 opens the panel")
	assert_true(main.driver.paused, "the run waits")
	var t: Tree = null
	for n in panel.find_children("*", "Tree", true, false):
		t = n
	var item := _find(t.get_root(), "arc_caster")
	assert_not_null(item, "the enemy is listed")
	t.scroll_to_item(item)
	await _e.frames(2)
	var rect := t.get_item_area_rect(item)
	await _e.click_at(t.get_global_rect().position + rect.get_center())
	await _e.frames(2)
	var spin := panel.editor_of(DevTuning.key_of(ENEMY, "hp")) as SpinBox
	assert_not_null(spin, "its HP field is shown")
	var line := spin.get_line_edit()
	# GUT's own output window lies over the panel's right side in a test run and takes the click: focus it directly,
	# then type with real key events.
	line.grab_focus()
	await _e.frames(2)  # the focus's select-all lands a frame later
	line.select_all()
	await _type("97")
	await _e.tap(KEY_ENTER)
	assert_eq((load(ENEMY) as EnemyDefinition).hp, 97, "typed into the content")
	var restart: Button = null
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.text == "UI_DEVM_RESTART":
			restart = b
	restart.grab_focus()  # the same GUT window covers the top bar's right end
	await _e.tap(KEY_ENTER)
	await _e.frames(4)
	assert_ne(_arc_caster_hp(_e.world()), shipped)
	assert_eq(_arc_caster_hp(_e.world()), 97, "the rebuilt floor uses it (floor 1 scaling is x1)")
	assert_null(main.get_node_or_null("UI/DevMasterPanel"), "restart closes the panel")
	await _e.tap(KEY_F10)
	var again := main.get_node_or_null("UI/DevMasterPanel") as DevMasterPanel
	assert_not_null(again)
	# Step 3: a lighting edit shows at once on the running floor (the panel's API; typing is covered above).
	var biome := main._biome_path
	again.set_value(DevTuning.key_of(biome, "mood/ambient_energy"), 0.07)
	assert_almost_eq(main.view.stage.environment.ambient_light_energy, 0.07, 0.0001, "live")
	assert_true(
		DevTuning.is_lighting(DevTuning.key_of(biome, "mood/ambient_energy")), "not a balance tweak"
	)
	await _e.tap(KEY_F10)
	assert_null(main.get_node_or_null("UI/DevMasterPanel"), "F10 closes it")
	assert_false(main.driver.paused)


## Types `text` as key presses that carry their characters (a text field reads the unicode, not the key).
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
