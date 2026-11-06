extends GutTest
## v0.10.5 W3-O12 (docs/roadmap/v0.10.5/W3_O12_VFX_GALLERY.md): the Effects gallery from the real game, through real
## input: F10 opens the master dev panel, Enter on its Effects button (GUT's output window lies over the panel's top
## bar in a test run, so the button gets focus directly; the press is a real key event) opens the gallery; Right and
## Left page the entries, Down the groups, G the grid and Right its pages, Esc leaves the grid and then the gallery.

var _e: E2e


func _gallery(main: Main) -> EffectsGallery:
	return main.find_child("EffectsGallery", true, false) as EffectsGallery


func test_open_page_and_leave_the_effects_gallery() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	await _e.tap(KEY_F10)
	var panel := main.get_node_or_null("UI/DevMasterPanel")
	assert_not_null(panel, "F10 opens the master dev panel")
	if panel == null:
		return
	var b := panel.find_child("EffectsGallery", true, false) as Button
	assert_not_null(b, "the panel's Effects button (a debug build)")
	if b == null:
		return
	b.grab_focus()
	await _e.frames(1)
	await _e.tap(KEY_ENTER)
	await _e.frames(3)
	var g := _gallery(main)
	assert_not_null(g, "Enter on Effects opens the gallery")
	if g == null:
		return
	assert_null(main.get_node_or_null("UI/DevMasterPanel"), "the panel closed")
	assert_eq([g.group, g.index, g.grid], [0, 0, false], "the hero's first entry")
	assert_eq(g.stages.size(), 1, "one entry plays")
	assert_not_null(g.stages[0].view, "in a game view of its own")
	await _e.tap(KEY_RIGHT)
	await _e.tap(KEY_RIGHT)
	assert_eq(g.index, 2, "Right: the next entry")
	await _e.tap(KEY_LEFT)
	assert_eq(g.index, 1, "Left: the one before")
	assert_eq(g.stages[0].entry, g.entries()[1], "its stage plays that entry")
	await _e.frames(30)
	assert_gt(g.stages[0].ticks, 0, "its sim runs")
	await _e.tap(KEY_DOWN)
	await _e.tap(KEY_DOWN)
	await _e.tap(KEY_DOWN)
	assert_eq([g.group, g.index], [3, 0], "Down: the next groups (the pack effects in use)")
	await _e.tap(KEY_G)
	assert_true(g.grid, "G: the group's grid")
	assert_eq(g.stages.size(), g.page_size(), "a full page of cells")
	await _e.tap(KEY_RIGHT)
	assert_eq(g.page, 1, "Right: the grid's next page")
	assert_eq(
		g.stages[0].entry, g.entries()[g.page_size()], "its first cell is the page's first entry"
	)
	await _e.frames(20)
	assert_gt(g.stages[0].loops, 0, "a pack cell plays its effect")
	await _e.tap(KEY_ESCAPE)
	assert_false(g.grid, "Esc leaves the grid")
	await _e.tap(KEY_ESCAPE)
	await _e.frames(3)
	assert_null(_gallery(main), "Esc again: back to the main menu")
	assert_not_null(main.find_child("MainMenu", true, false), "the main menu")
