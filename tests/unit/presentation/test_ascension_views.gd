extends GutTest
## v0.7.5 AP: the Ascension portal's views. The choice panel shows what the sim waits on and sends the picks as input
## (End the run 1, Ascend 2, Not yet = cancel); the portal has its own look (gold-white and lavender, never the
## visor blue or the Deep violet) and its column rises when the portal opens; the HUD, pause line and recap say
## "Loop N · " past the first loop, and the recap counts the loops cleared.


func _choice_world() -> World:
	var w := SaveLab.floor_world(41, 3)
	w.boss_flow.state = BossFlow.State.OPEN  # a state set for the view only: the sim's own path is test_ascension
	w.boss_flow.ascend_open = true
	return w


func _key(panel: AscensionPanel, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	panel._input(ev)


func test_the_panel_opens_on_the_choice_and_sends_the_picks() -> void:
	var w := _choice_world()
	var reader := WorldReader.new(w)
	var panel := AscensionPanel.new()
	add_child_autofree(panel)
	var sent := []
	panel.picked.connect(func(v: int) -> void: sent.append(v))
	assert_false(panel.visible, "hidden until the choice opens")
	panel.sync(reader)
	assert_true(panel.visible and panel.is_open())
	assert_eq(panel.card_count(), 3)
	assert_eq(panel.title_text(), tr("UI_ASCEND_TITLE"))
	assert_eq(panel.card_text(0, "Title"), tr("UI_ASCEND_END"))
	assert_eq(panel.card_text(1, "Title"), tr("UI_ASCEND_GO"))
	assert_eq(panel.card_text(1, "Line"), tr("UI_ASCEND_GO_LINE") % 2, "Ascend names the next loop")
	assert_eq(panel.card_text(2, "Title"), tr("UI_ASCEND_NOT_YET"))
	assert_eq(panel.focus_index(), 0, "End the run has the focus")
	_key(panel, KEY_DOWN)
	assert_eq(panel.focus_index(), 1)
	_key(panel, KEY_ENTER)
	assert_eq(sent, [WorldReader.PICK_ASCEND_ASCEND], "Enter sends Ascend")
	_key(panel, KEY_ENTER)
	assert_eq(sent.size(), 1, "one answer per opening")
	w.boss_flow.ascend_open = false
	panel.sync(reader)
	assert_false(panel.visible, "it closes with the sim's choice")
	w.boss_flow.ascend_open = true
	panel.sync(reader)
	_key(panel, KEY_ESCAPE)
	assert_eq(sent[1], InputFrame.PICK_CANCEL, "Esc is Not yet")
	w.boss_flow.ascend_open = false
	panel.sync(reader)
	w.boss_flow.ascend_open = true
	panel.sync(reader)
	_key(panel, KEY_1)
	_key(panel, KEY_ENTER)
	assert_eq(sent[2], WorldReader.PICK_ASCEND_END, "1 then Enter is End the run")


func test_the_portal_has_its_own_look_and_its_column_rises() -> void:
	var p := AscensionPortal.new()
	add_child_autofree(p)
	p.calm = false
	assert_true(p.is_sealed(), "dormant at first")
	assert_false(p.column.visible, "no column while the boss lives")
	for c: Color in [AscensionPortal.GOLD, AscensionPortal.LAVENDER, AscensionPortal.CORE]:
		for other: Color in [PortalGate.visor_blue(), PortalGate.DEEP_VIOLET, PortalGate.DEEP_RIM]:
			assert_gt(_dist(c, other), 0.25, "%s reads apart from the other portals" % c.to_html())
	p.set_sealed(false)
	assert_false(p.is_sealed())
	assert_eq(p.rise, 0.0, "the column starts at the dais")
	p._process(AscensionPortal.RISE_SECONDS * 0.5)
	assert_almost_eq(p.rise, 0.5, 0.01, "and rises")
	assert_true(p.column.visible)
	p._process(AscensionPortal.RISE_SECONDS)
	assert_eq(p.rise, 1.0, "to its full height")
	assert_gt(p.light.light_energy, AscensionPortal.LIGHT_SEALED)
	var calm := AscensionPortal.new()
	calm.calm = true
	add_child_autofree(calm)
	calm.set_sealed(false)
	assert_eq(calm.rise, 1.0, "reduced motion: there at once")


func _palette() -> Dictionary:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	return biome.palette


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_the_world_view_draws_the_ascension_portal_on_the_last_floor() -> void:
	var w := SaveLab.floor_world(42, 3)
	var view := WorldViewRoot.new()
	add_child_autofree(view)
	view.setup(WorldReader.new(w), _palette(), 40.0)
	assert_not_null(view.ascension, "the Ascension portal")
	assert_null(view.gate, "not the blue gate")
	var w1 := SaveLab.floor_world(42, 1)
	var view1 := WorldViewRoot.new()
	add_child_autofree(view1)
	view1.setup(WorldReader.new(w1), _palette(), 40.0)
	assert_null(view1.ascension, "floor 1 keeps its gate")
	assert_not_null(view1.gate)


func test_loop_lines_on_the_hud_pause_and_recap() -> void:
	assert_eq(Hud.loop_prefix(self, 1), "", "loop 1 reads as before")
	assert_eq(Hud.loop_prefix(self, 3), tr("HUD_LOOP") % 3 + " · ")
	var end := EndPanel.new(true, -1, &"", {"floor": 3, "floors": 3, "loop": 2, "loops_cleared": 2})
	add_child_autofree(end)
	assert_eq(end.recap_line("Floor"), tr("HUD_LOOP") % 2 + " · " + tr("UI_RECAP_FLOOR") % [3, 3])
	assert_eq(end.recap_line("Loops"), tr("UI_RECAP_LOOPS") % 2, "the loops cleared")
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	pause.show_run(1, 75.0, 10, 4, 2)
	assert_true(
		pause.run_line.text.begins_with(tr("HUD_LOOP") % 2), "the pause line names the loop"
	)
