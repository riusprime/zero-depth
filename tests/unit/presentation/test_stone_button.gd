extends GutTest
## v0.9.5 MM: the main menu's StoneButton (a Button drawn in code) and the main menu's order and focus.


func test_the_states_are_flags_on_the_button() -> void:
	var b := StoneButton.new(1)
	b.text = "UI_PLAY"
	add_child_autofree(b)
	await get_tree().process_frame
	assert_false(b.is_lit(), "plain: not lit")
	b.grab_focus()
	assert_true(b.is_lit(), "focused: lit")
	b.release_focus()
	assert_false(b.is_lit())
	b.disabled = true
	assert_false(b.is_lit(), "disabled: never lit")
	b.disabled = false
	b.grab_focus()
	for k in 30:
		b._process(0.05)
	assert_almost_eq(b.glow, 1.0, 0.001, "the glow eases to full while lit")
	b.disabled = true
	for k in 30:
		b._process(0.05)
	assert_eq(b.glow, 0.0, "and goes out when disabled")
	b.flash = 0.0
	b.button_down.emit()
	assert_eq(b.flash, 1.0, "a press flashes")


func test_the_stone_texture_is_made_once() -> void:
	assert_same(StoneButton.stone_texture(), StoneButton.stone_texture())
	assert_same(StoneButton.label_font(), StoneButton.label_font())
	assert_eq(StoneButton.label_font().spacing_glyph, 3, "about 0.2 em at 17 px")


func test_the_rows_and_where_the_focus_starts() -> void:
	var m := MainMenu.new("v", false)
	add_child_autofree(m)
	var rows := []
	for c in m.box.get_children():
		if c is StoneButton:
			rows.append(String(c.name))
	assert_eq(rows, ["Continue", "Play", "Options", "Credits", "Quit"])
	m.focus_first()
	assert_eq(m.get_viewport().gui_get_focus_owner().name, &"Play", "no save: Continue is skipped")
	var s := MainMenu.new("v", true)
	add_child_autofree(s)
	s.focus_first()
	assert_eq(s.get_viewport().gui_get_focus_owner().name, &"Continue", "a save: Continue first")
	assert_not_null(m.find_child("Logo", true, false), "the logo is over the column")
	assert_not_null(m.backdrop.texture, "the owner's picture is behind")
