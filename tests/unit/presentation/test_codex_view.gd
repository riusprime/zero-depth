extends GutTest
## v0.7.5 CX: the Codex page (CodexView): locked entries are silhouettes "???", met ones show their name, sentence and
## counts; pages switch; the page fits the 1920 x 1080 base (so 1280 x 720 scaled) in English and Spanish.

var _locale := ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _view(store: CodexStore) -> CodexView:
	var v := CodexView.new(CodexCatalog.build(ContentRepository.load_all()), store)
	var screen := Control.new()  # the 1920 x 1080 base the game lays its menus out on
	screen.size = Vector2(1920, 1080)
	add_child_autofree(screen)
	screen.add_child(v)
	return v


func test_locked_is_a_silhouette_and_met_shows_name_text_and_counts() -> void:
	TranslationServer.set_locale("en")
	var store := CodexStore.new(ProfileStore.new(""))
	store.add(&"cards", &"gun_twin", &"taken", 2)
	store.raise_to(&"cards", &"gun_twin", &"level", 3)
	var v := _view(store)
	await wait_physics_frames(2)
	var met := v.tile(&"gun_twin")
	var locked := v.tile(&"gun_pierce")
	assert_not_null(met)
	assert_not_null(locked)
	assert_false(met.locked)
	assert_eq(met.name_label.text, tr("ITEM_GUN_TWIN"), "the game's own name key")
	assert_true(locked.locked)
	assert_eq(locked.name_label.text, "???", "a silhouette, unnamed")
	met.grab_focus()
	await wait_physics_frames(1)
	assert_eq(v.shown_entry()["id"], &"gun_twin", "focus shows the entry")
	assert_eq(v.desc_label.text, tr(String(v.shown_entry()["desc_key"])), "its sentence")
	assert_eq(v.card.title_text(), tr("ITEM_GUN_TWIN"), "in its crystal frame")
	assert_string_contains(v.counts_label.text, "%s: 2" % tr("UI_CODEX_TAKEN"))
	assert_string_contains(v.counts_label.text, "%s: 3" % tr("UI_CODEX_LEVEL"))
	locked.grab_focus()
	await wait_physics_frames(1)
	assert_eq(v.name_label.text, "???")
	assert_eq(v.desc_label.text, tr("UI_CODEX_LOCKED"))
	assert_eq(v.counts_label.text, "", "no counts for an entry not met")
	assert_eq(v.progress.text, tr("UI_CODEX_FOUND") % [1, v.catalog.size(&"cards")])


func test_pages_switch_and_list_the_data() -> void:
	var store := CodexStore.new(ProfileStore.new(""))
	store.add(&"enemies", &"charger", &"kills", 5)
	store.add(&"biomes", &"ruins", &"visits")
	var v := _view(store)
	v.open(&"enemies")
	await wait_physics_frames(1)
	assert_eq(v.page, &"enemies")
	assert_eq(v.tiles.size(), v.catalog.size(&"enemies"))
	v.tile(&"charger").grab_focus()
	await wait_physics_frames(1)
	assert_true(v.emblem.drawn > 0 or not v.emblem.is_visible_in_tree(), "the emblem draws")
	assert_string_contains(v.counts_label.text, "%s: 5" % tr("UI_CODEX_KILLS"))
	v.open(&"biomes")
	await wait_physics_frames(1)
	assert_eq(
		v.tiles.size(), ContentRepository.load_all().count(&"biomes"), "every biome of the data"
	)
	assert_false(v.tile(&"ruins").locked)
	v.open(&"bosses")
	await wait_physics_frames(1)
	assert_true(v.tiles.all(func(t: CodexTile) -> bool: return t.locked), "no boss met yet")
	var first := v.tiles[0]
	assert_eq(
		first.get_node(first.focus_neighbor_top),
		v.tabs[&"bosses"],
		"up from the top row: this page's tab"
	)
	var tab := v.tabs[&"bosses"] as Button
	assert_eq(tab.get_node(tab.focus_neighbor_bottom), first, "and down from it, the first tile")


## v0.8.0: down from any tile goes to the next row of its section (its last tile when that row is short), and from a
## section's last row into the next section's first row; up the same way back. No row is skipped (AO's two Gun cards
## left the Gun section a short third row that down from its right side jumped over).
func test_down_and_up_never_skip_a_short_row() -> void:
	var v := _view(CodexStore.new(ProfileStore.new("")))
	await wait_physics_frames(2)
	var rows: Array = []  # every row of the Cards page, top to bottom: Array of Array[CodexTile]
	for s: StringName in v.catalog.sections(&"cards"):
		var grid := v.find_child("Grid_%s" % s, true, false) as GridContainer
		assert_not_null(grid, "the %s grid" % s)
		var kids := grid.get_children()
		for start in range(0, kids.size(), CodexView.COLUMNS):
			rows.append(kids.slice(start, mini(start + CodexView.COLUMNS, kids.size())))
	assert_gt(rows.size(), 2)
	var short := 0
	for r in rows.size() - 1:
		var next: Array = rows[r + 1]
		short += 1 if next.size() < CodexView.COLUMNS else 0
		for t: CodexTile in rows[r]:
			var down := t.find_valid_focus_neighbor(SIDE_BOTTOM)
			assert_true(next.has(down), "down from %s lands on the next row" % t.entry["id"])
		for t: CodexTile in next:
			var up := t.find_valid_focus_neighbor(SIDE_TOP)
			assert_true(
				(rows[r] as Array).has(up), "up from %s lands on the row above" % t.entry["id"]
			)
	assert_gt(short, 0, "the page has a short row to cross")


func test_it_fits_1080p_in_english_and_spanish() -> void:
	var store := CodexStore.new(ProfileStore.new(""))
	for e: Dictionary in CodexCatalog.build(ContentRepository.load_all()).entries(&"cards"):
		store.unlock(&"cards", e["id"])
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		var v := _view(store)
		await wait_physics_frames(2)
		var screen := Rect2(Vector2.ZERO, Vector2(1920, 1080))
		var r := v.content_rect()
		assert_true(screen.encloses(r), "%s: the page %s fits the screen" % [lang, r])
		for t in v.tiles:
			var lines := t.name_label.get_line_count()
			assert_lte(lines, 2, "%s: %s wraps to %d lines" % [lang, t.name_label.text, lines])
		for p: StringName in CodexStore.PAGES:
			v.open(p)
			await wait_physics_frames(1)
			for t in v.tiles:
				t.grab_focus()
				await wait_physics_frames(1)
				var d := v.get_node("Margin/Column/Body/Detail") as Control
				assert_true(
					screen.encloses(d.get_global_rect()),
					"%s: %s's detail fits (%s)" % [lang, t.entry["id"], d.get_global_rect()]
				)
				if d.get_global_rect().end.y > 1080:
					break
		v.get_parent().queue_free()
		await wait_physics_frames(1)
