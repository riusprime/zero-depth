extends GutTest
## v0.7.5 AC (owner N7): the Codex's Achievements page (AchievementsPage in CodexView) and the unlock toast
## (AchievementToast). Unlocked rows are lit, locked ones dimmed with their sentence and progress, hidden ones "???";
## the page is the fifth tab, reached by E / RB and its tab; the page and the toast fit the 1920 x 1080 base (so
## 1280 x 720 scaled) in English and Spanish for every achievement.

var _locale := ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _book() -> AchievementBook:
	var profile := ProfileStore.new("")
	var repo := ContentRepository.load_all()
	return AchievementBook.build(
		repo, AchievementStore.new(profile), CodexStore.new(profile), CodexCatalog.build(repo)
	)


func _screen() -> Control:
	var screen := Control.new()  # the 1920 x 1080 base the game lays its menus and HUD out on
	screen.size = Vector2(1920, 1080)
	add_child_autofree(screen)
	return screen


func _view(book: AchievementBook) -> CodexView:
	var v := CodexView.new(book.catalog, book.codex, book)
	_screen().add_child(v)
	return v


func test_the_page_is_the_codexs_fifth_tab_with_lit_dim_and_hidden_rows() -> void:
	TranslationServer.set_locale("en")
	var book := _book()
	book.store.unlock(&"kills_1")
	book.store.add_stat(&"runs:won", 2)
	var v := _view(book)
	await wait_physics_frames(2)
	var order: Array[StringName] = CodexStore.PAGES.duplicate()
	order.append_array([CodexView.ACHIEVEMENTS, CodexView.COLLECTIBLES])
	assert_eq(v.pages, order, "after the four Codex pages, before v0.9.0 CL's Collectibles")
	assert_true(v.tabs.has(CodexView.ACHIEVEMENTS))
	v.open(CodexView.ACHIEVEMENTS)
	await wait_physics_frames(2)
	var page := v.achievements_page
	assert_true(page.is_visible_in_tree(), "the page shows")
	assert_false((v.get_node("Margin/Column/Body") as Control).visible, "in the tiles' place")
	assert_eq(page.rows.size(), book.size(), "a row per achievement")
	assert_eq(v.progress.text, tr("UI_ACH_PROGRESS") % [1, book.size()])
	var lit := page.row(&"kills_1")
	assert_true(lit.unlocked)
	assert_eq(lit.name_label.text, tr("ACH_KILLS_1_NAME"))
	assert_eq(lit.state_label.text, tr("UI_ACH_UNLOCKED"))
	var dim := page.row(&"win_5")
	assert_false(dim.unlocked)
	assert_eq(dim.name_label.text, tr("ACH_WIN_5_NAME"), "a locked one keeps its name")
	assert_eq(dim.desc_label.text, tr("ACH_WIN_5_DESC"), "and its sentence")
	assert_eq(dim.state_label.text, "2 / 5", "and how far along")
	var boss := page.row(&"boss_warlord")
	assert_eq(
		boss.name_label.text, tr("ACH_BOSS_NAME") % tr("BOSS_WARLORD"), "the boss's name in it"
	)
	var hidden := page.row(&"ascend_1")
	assert_true(hidden.hidden_locked)
	assert_eq(hidden.name_label.text, "???", "a hidden one stays unnamed")
	assert_eq(hidden.desc_label.text, tr("UI_ACH_HIDDEN"))
	var first := page.rows[0]
	assert_eq(
		first.get_node(first.focus_neighbor_top),
		v.tabs[CodexView.ACHIEVEMENTS],
		"up from the first line: the page's tab"
	)
	var tab := v.tabs[CodexView.ACHIEVEMENTS] as Button
	assert_eq(tab.get_node(tab.focus_neighbor_bottom), first, "and down from it, the first row")
	v.open(&"cards")
	await wait_physics_frames(1)
	assert_false(page.visible, "another page hides it")
	assert_true((v.get_node("Margin/Column/Body") as Control).visible)


func test_a_codex_without_a_book_has_its_four_pages() -> void:
	var book := _book()
	var v := CodexView.new(book.catalog, book.codex)
	_screen().add_child(v)
	await wait_physics_frames(1)
	var order: Array[StringName] = CodexStore.PAGES.duplicate()
	order.append(CodexView.COLLECTIBLES)
	assert_eq(v.pages, order, "no Achievements tab without a book (CL's Collectibles stays)")
	assert_null(v.achievements_page)


func test_the_page_fits_1080p_in_english_and_spanish() -> void:
	var book := _book()
	for k in book.size():
		if k % 2 == 0:
			book.store.unlock(book.all()[k]["id"])
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		var v := _view(book)
		v.open(CodexView.ACHIEVEMENTS)
		await wait_physics_frames(2)
		var screen := Rect2(Vector2.ZERO, Vector2(1920, 1080))
		assert_true(screen.encloses(v.content_rect()), "%s: the page fits" % lang)
		assert_true(
			screen.encloses(v.achievements_page.get_global_rect()),
			"%s: the list fits (%s)" % [lang, v.achievements_page.get_global_rect()]
		)
		for r in v.achievements_page.rows:
			var text := "%s / %s / %s" % [r.name_label.text, r.desc_label.text, r.state_label.text]
			assert_eq(r.name_label.get_line_count(), 1, "%s: one line name: %s" % [lang, text])
			assert_lte(r.desc_label.get_line_count(), 2, "%s: two lines at most: %s" % [lang, text])
			assert_lte(r.state_label.get_line_count(), 1, "%s: state in a line: %s" % [lang, text])
			assert_true(
				r.size.x <= AchievementRow.SIZE.x + 0.5, "%s: the row keeps its width" % lang
			)
		v.get_parent().queue_free()
		await wait_physics_frames(1)


func test_the_toast_shows_queues_and_fits_every_achievement_in_english_and_spanish() -> void:
	var book := _book()
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		var toast := AchievementToast.new()
		_screen().add_child(toast)
		assert_false(toast.showing())
		assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never takes the mouse")
		assert_eq(toast.focus_mode, Control.FOCUS_NONE, "nor the focus")
		toast.push(book.get_entry(&"kills_1"))
		toast.push(book.get_entry(&"biome_frozen_shore"))
		assert_eq(toast.current_id(), &"kills_1", "the first shows")
		assert_eq(toast.header.text, tr("UI_ACH_TOAST"), "%s: its line, translated" % lang)
		assert_eq(toast.name_label.text, tr("ACH_KILLS_1_NAME"), "%s: and its name" % lang)
		assert_eq(
			toast.queued_ids(), [&"biome_frozen_shore"] as Array[StringName], "the next waits"
		)
		toast.skip()
		assert_eq(toast.current_id(), &"biome_frozen_shore")
		assert_eq(
			toast.name_label.text,
			tr("ACH_BIOME_NAME") % tr("BIOME_FROZEN_SHORE"),
			"%s: its name" % lang
		)
		toast.skip()
		assert_false(toast.showing(), "and then it's gone")
		var screen := Rect2(Vector2.ZERO, Vector2(1920, 1080))
		for a in book.all():
			toast.push(a)
			await wait_physics_frames(2)
			var r := toast.get_global_rect()
			var text := "%s / %s" % [toast.name_label.text, toast.desc_label.text]
			assert_true(screen.encloses(r), "%s: %s fits (%s)" % [lang, a["id"], r])
			assert_lte(r.end.y, AchievementToast.TOP + 200.0, "%s: a small slab: %s" % [lang, text])
			assert_lte(toast.name_label.get_line_count(), 2, "%s: %s" % [lang, text])
			assert_lte(toast.desc_label.get_line_count(), 3, "%s: %s" % [lang, text])
			toast.skip()
		toast.get_parent().queue_free()
		await wait_physics_frames(1)


func test_the_toast_fades_out_on_its_own() -> void:
	var toast := AchievementToast.new()
	_screen().add_child(toast)
	toast.push(_book().get_entry(&"win_run"))
	toast._process(AchievementToast.FADE_IN_S)
	assert_almost_eq(toast.modulate.a, 1.0, 0.01, "faded in")
	toast._process(AchievementToast.SHOW_S)
	assert_false(toast.showing(), "gone after its time")
	assert_false(toast.visible)
