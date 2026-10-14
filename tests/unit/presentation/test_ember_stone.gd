extends GutTest
## v0.8.0 MU (owner O14: "we're just throwing away the shard cards"; G2 pick "menu style B", Ember stone): every card
## and menu surface wears the carved stone (StoneBox, StoneCard, PlaqueBox) and none the retired crystal art; the
## ember glow stays apart from the heat meter's Hot colour; focus is visible on every surface (light and shape, for
## the mouse and the pad alike) under every colour-blind mode; the screens fit at Interface size 110 %; reduced motion
## stops the backdrop's sparks and flicker; the main menu has a backdrop of its own.

const PRESENTATION := ["res://src/presentation/hud", "res://src/presentation/menus"]

var _locale := ""
var _mode := &"off"
var _calm := false


func before_all() -> void:
	_locale = TranslationServer.get_locale()
	_mode = ThemePalette.mode
	_calm = HudStyle.reduced_motion


func after_all() -> void:
	TranslationServer.set_locale(_locale)
	ThemePalette.mode = _mode
	HudStyle.reduced_motion = _calm


func _defs(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for path in ContentScanner.scan(dir):
		out.append(load(path))
	return out


func _face(id: StringName, tier: int) -> Dictionary:
	return {
		"id": id,
		"title": "Wildfire",
		"sentence": "Kills spread burn.",
		"color": Color("#FF7A3D"),
		"tier": tier,
		"tier_text": "Rare",
		"type": Offers.MOD,
	}


## MENU_G2 "Known limits": the mockup's warm glow (#F28A3A) was close to the Hot heat colour; the shipped ember is
## kept apart by saturation (and from Overclock by hue).
func test_the_ember_glow_is_apart_from_the_heat_colours() -> void:
	var e := EmberStone.EMBER
	var hot := HeatLooks.HOT
	assert_gte(absf(e.s - hot.s), 0.2, "saturation apart from Hot (%.2f vs %.2f)" % [e.s, hot.s])
	assert_gte(absf(e.v - hot.v), 0.05, "and value")
	var dh := absf(e.h - HeatLooks.OVERCLOCK.h)
	assert_gte(minf(dh, 1.0 - dh), 0.04, "hue apart from Overclock")
	assert_gte(absf(e.s - HeatLooks.OVERCLOCK.s), 0.3, "and saturation")
	assert_eq(MenuStyle.EMBER, e, "the menus' accent is the ember")


func test_no_crystal_art_is_left_in_the_ui() -> void:
	assert_false(
		DirAccess.dir_exists_absolute("res://assets/ui"), "the crystal frames and plaques retired"
	)
	for dir: String in PRESENTATION:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + "/" + f)
			assert_false(src.contains("assets/ui/"), "%s loads no UI art" % f)
			for gone in ["CrystalCard", "BuildArt", "glass_panel", "GlassMarker"]:
				assert_false(
					src.contains(gone + ".") or src.contains(gone + "("), "%s: no %s" % [f, gone]
				)


func test_every_card_surface_is_carved_stone() -> void:
	var pick := PickPanel.new()
	add_child_autofree(pick)
	for k in PickPanel.SLOTS:
		pick.slot(k).show_card(_face(&"wildfire", 1))
		assert_true(pick.slot(k).card is StoneCard, "pick card %d" % k)
		assert_true(pick.slot(k).panel_box() is StoneBox)
	var swap := SwapPanel.new()
	add_child_autofree(swap)
	assert_true(
		swap.find_child("SwapCard", true, false).get("card") is StoneCard, "the swap's card"
	)
	var item := ItemCard.new()
	add_child_autofree(item)
	item.show_item(&"wildfire", "Wildfire", "Kills spread burn.", Color.ORANGE)
	assert_true(item.plaque_box() is StoneBox, "the item plaque")
	var shop := ShopTile.new("T")
	add_child_autofree(shop)
	assert_true(shop.panel_box() is StoneBox, "a shop tile")
	var gamble := GambleCard.new()
	add_child_autofree(gamble)
	assert_true(gamble.plaque_box() is StoneBox, "the shrine card")
	var tile := CodexTile.new()
	add_child_autofree(tile)
	tile.show_entry({"page": &"cards", "id": &"wildfire", "type": Offers.MOD}, "Wildfire", false)
	for s in ["normal", "hover", "focus"]:
		assert_true(tile.get_theme_stylebox(s) is StoneBox, "codex tile %s" % s)
	assert_gt((tile.get_theme_stylebox("normal") as StoneBox).ring_color.a, 0.0, "its inlay ring")
	var row := WandRow.new()
	add_child_autofree(row)
	row.show_wand({"cards": []}, 4)
	assert_true(row.tile_box(0) is StoneBox, "a wand tile")
	var hud := BuildHud.new()
	add_child_autofree(hud)
	assert_true(hud.pip_box(0) is StoneBox, "a wand pip")
	var toast := AchievementToast.new()
	add_child_autofree(toast)
	assert_eq(toast.slab().rim, Color(EmberStone.GOLD, 0.75), "the toast's gold rim")
	var catalog := CodexCatalog.build(ContentRepository.load_all())
	var view := CodexView.new(catalog, CodexStore.new(ProfileStore.new("")))
	add_child_autofree(view)
	assert_true(view.card is StoneCard, "the Codex's card")
	for t: TextureRect in view.find_children("*", "TextureRect", true, false):
		var path := t.texture.resource_path if t.texture != null else ""
		assert_false(path.contains("assets/ui"), "%s: no crystal art (%s)" % [t.get_path(), path])


func test_every_menu_is_on_ember_stone() -> void:
	var t := MenuStyle.theme()
	assert_true(t.get_stylebox("panel", "PanelContainer") is StoneBox, "panels are slabs")
	for s in ["focus", "pressed", "hover"]:
		assert_true(t.get_stylebox(s, "Button") is StoneBox, "a %s row is a lit slab" % s)
	assert_true(t.get_stylebox("normal", "Button") is StyleBoxEmpty, "a plain row is type only")
	var main := MainMenu.new("v", false)
	add_child_autofree(main)
	var bd := main.find_child("MenuBackdrop", true, false) as MenuBackdrop
	assert_not_null(bd, "the main menu has a backdrop")
	assert_true(bd.own_scene, "of its own: the ember-lit stone scene (nothing is behind it)")
	assert_true(main.slab.get_theme_stylebox("panel") is StoneBox, "its list on a slab")
	var repo := ContentRepository.load_all()
	for screen: Control in [
		PauseMenu.new(),
		EndPanel.new(false, 0),
		OptionsMenu.new(ProfileStore.new("")),
		CreditsView.new(repo.get_def(&"credits", &"main"), repo.get_def(&"licences", &"generated")),
		BuildPicker.new(_defs("res://data/builds"), &"blade"),
	]:
		add_child_autofree(screen)
		assert_eq(screen.theme, t, "%s wears the Ember stone theme" % screen.name)
		assert_not_null(
			screen.find_child("MenuBackdrop", true, false), "%s: the backdrop" % screen.name
		)


func test_focus_is_visible_for_mouse_and_pad_under_every_colour_mode() -> void:
	for mode: StringName in [&"off", &"protanopia", &"deuteranopia", &"tritanopia"]:
		ThemePalette.mode = mode
		var s := PickSlot.new(0)
		add_child_autofree(s)
		s.show_card(_face(&"wildfire", 0))
		var idle := s.card.glow_alpha()
		assert_eq(s.card.lift(), 0.0)
		s.set_focused(true)
		assert_gt(s.card.lift(), 0.0, "%s: the focused card lifts" % mode)
		assert_gt(s.card.glow_alpha(), idle, "%s: and glows" % mode)
		assert_gt(s.panel_box().dim, StoneCard.IDLE_DIM, "%s: and is brighter" % mode)
	ThemePalette.mode = &"off"
	var t := MenuStyle.theme()
	var lit := t.get_stylebox("focus", "Button") as StoneBox
	var hover := t.get_stylebox("hover", "Button") as StoneBox
	assert_eq(lit.focus, 1.0, "a focused row (keys, pad) is fully lit")
	assert_gt(
		lit.focus, hover.focus, "a hovered row (mouse) half lit, so the focus still stands out"
	)
	assert_gt(hover.focus, 0.0)
	var tile := CodexTile.new()
	add_child_autofree(tile)
	tile.show_entry({"page": &"enemies", "id": &"charger"}, "Charger", false)
	assert_gt(
		(tile.get_theme_stylebox("focus") as StoneBox).focus,
		(tile.get_theme_stylebox("normal") as StoneBox).focus,
		"a focused codex tile is lit"
	)
	var row := WandRow.new()
	add_child_autofree(row)
	row.show_wand({"cards": []}, 4)
	row.focus = 2
	row.refresh_marks()
	assert_eq(row.tile_box(2).focus, 1.0, "the focused wand tile is lit")
	assert_eq(row.tile_box(1).focus, 0.0)


func test_reduced_motion_stops_the_sparks_and_the_flicker() -> void:
	var bd := MenuBackdrop.new()
	add_child_autofree(bd)
	HudStyle.reduced_motion = false
	await wait_process_frames(3)
	var t := bd.shown_clock()
	assert_gt(t, 0.0, "the embers drift")
	HudStyle.reduced_motion = true
	var held := bd.shown_clock()
	await wait_process_frames(4)
	assert_eq(
		bd.shown_clock(),
		held,
		"reduced motion: the clock (sparks, flicker, breathing) stands still"
	)
	HudStyle.reduced_motion = _calm


func test_the_screens_fit_at_interface_size_110() -> void:
	var visible := Vector2(1920, 1080) / 1.1  # Interface size 110 %: the base layout sees less of it
	var pick := PickPanel.new()
	add_child_autofree(pick)
	TranslationServer.set_locale("es")
	var nova: Resource = load("res://data/abilities/frost_nova.tres")
	for k in PickPanel.SLOTS:
		var f := _face(&"frost_nova", 3)
		f["sentence"] = tr(nova.desc_key)
		pick.slot(k).show_card(f)
		pick.slot(k).visible = true
	var col := pick.slot(0).get_parent().get_parent() as Control
	var need := col.get_combined_minimum_size()
	assert_lt(need.x, visible.x, "the three cards fit across (%d px)" % need.x)
	assert_lt(need.y, visible.y, "and down (%d px)" % need.y)
	var main := MainMenu.new("v", true, true, true)
	add_child_autofree(main)
	var slab := main.slab.get_combined_minimum_size()
	assert_lt(slab.y, visible.y, "the longest main menu fits (%d px)" % slab.y)
	assert_lt(MenuStyle.LIST_LEFT + slab.x, visible.x)
	TranslationServer.set_locale(_locale)
