extends GutTest
## v0.10.5 W3-O15 (owner 2026-11-04: UI style Astral; his painted card icons and carved frames; "make sure to not lose
## the burn effect when picking one … a glare kind of particle effect … with a noise texture dissolve"): the pick's and
## the shop's cards wear the owner's frame (one of four, by the card's id) and icon (icon_unknown without one); focus
## swaps the frame for its focused twin; a card not picked dissolves along the noise with a glare, and the glare's
## nodes are gone when the dissolve ends.

var _repo: ContentRepository
var _density := "high"


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	_density = ViewPrefs.effects_density


func after_each() -> void:
	HudStyle.reduced_motion = false
	ViewPrefs.effects_density = _density


func _face(id: StringName, tier: int = 0) -> Dictionary:
	return {
		"id": id,
		"title": "Card",
		"sentence": "A sentence.",
		"color": Color.WHITE,
		"tier": tier,
		"tier_text": "Common",
	}


func _slot(id: StringName) -> PickSlot:
	var s := PickSlot.new(0)
	add_child_autofree(s)
	s.show_card(_face(id))
	return s


func test_every_item_has_its_icon() -> void:
	var items := _repo.all_of(&"items")
	assert_gt(items.size(), 0)
	for d: ContentDef in items:
		assert_true(AstralCardArt.has_icon(d.id), "%s has an icon" % d.id)
	for id: StringName in [&"aegis", &"blink", &"combo_sword", &"pulse_gun", &"unknown"]:
		assert_true(AstralCardArt.has_icon(id), "%s has an icon" % id)


func test_the_card_shows_its_icon_and_frame_by_id() -> void:
	var s := _slot(&"wildfire")
	assert_true(s.card.astral, "the pick's card is an Astral card")
	assert_eq(
		s.card.medallion.icon_texture().resource_path,
		"res://assets/ui/card_icons/icon_wildfire.png",
		"its own icon"
	)
	var icon := s.card.medallion.icon
	assert_true(icon.visible, "the icon shows")
	assert_gt(icon.size.x, s.card.socket.size.x, "at the medallion's size, its glow round it")
	var v := AstralCardArt.variant_of(&"wildfire")
	assert_between(v, 1, AstralCardArt.FRAMES)
	assert_eq(v, AstralCardArt.variant_of(&"wildfire"), "the same frame every time")
	assert_eq(s.card.frame_variant, v)
	assert_eq(s.card.frame_texture().resource_path, "res://assets/ui/card_frames/frame_%d.png" % v)
	assert_false(s.card.socket.visible, "the stone socket is hidden")
	assert_false(s.panel_box() == null, "the box still holds the card's colours")
	var seen := {}
	for d: ContentDef in _repo.all_of(&"items"):
		seen[AstralCardArt.variant_of(d.id)] = true
	assert_eq(seen.size(), AstralCardArt.FRAMES, "the cards wear all four frames")


func test_a_card_without_an_icon_shows_the_unknown_one() -> void:
	var s := _slot(&"no_such_card")
	assert_eq(
		s.card.medallion.icon_texture().resource_path, "res://assets/ui/card_icons/icon_unknown.png"
	)
	var sold := _slot(&"")
	assert_null(sold.card.medallion.icon_texture(), "an empty (sold) card shows no icon")


func test_focus_swaps_the_frame_for_its_focused_twin() -> void:
	var s := _slot(&"gun_twin")
	var v := s.card.frame_variant
	s.set_focused(true)
	assert_eq(
		s.card.frame_texture().resource_path, "res://assets/ui/card_frames/frame_%d_focus.png" % v
	)
	assert_true(s.card.medallion.focused, "the medallion lights")
	s.set_focused(false)
	assert_eq(s.card.frame_texture().resource_path, "res://assets/ui/card_frames/frame_%d.png" % v)
	assert_false(s.card.medallion.focused)


func test_the_frames_are_nine_sliced_round_their_corners() -> void:
	var s := _slot(&"heavy")
	var f := s.card.frame
	assert_eq(f.patch_margin_left, AstralCardArt.MARGIN_X)
	assert_eq(f.patch_margin_top, AstralCardArt.MARGIN_Y)
	var tex := f.texture
	assert_eq(tex.get_size(), AstralCardArt.CANVAS, "every frame on one canvas")
	assert_lt(AstralCardArt.MARGIN_X * 2, int(tex.get_size().x), "a middle left to stretch")
	assert_lt(AstralCardArt.MARGIN_Y * 2, int(tex.get_size().y))


func test_the_shop_cards_are_astral_too() -> void:
	var s := PickSlot.new(0, ShopPanel.CARD_SCALE)
	add_child_autofree(s)
	s.show_card(_face(&"gun_lance"))
	assert_true(s.card.astral)
	assert_eq(
		s.card.medallion.icon_texture().resource_path,
		"res://assets/ui/card_icons/icon_gun_lance.png"
	)


func test_the_dissolve_runs_to_completion_and_frees_its_nodes() -> void:
	var s := _slot(&"wildfire")
	var fx := s.card.fx
	fx.set_burn(0.3)
	assert_true(fx.burning())
	var mat := fx.face.material as ShaderMaterial
	assert_not_null(mat, "the face dissolves")
	assert_eq(
		(mat.get_shader_parameter("noise_tex") as Texture2D).resource_path,
		"res://assets/ui/fx/dissolve_noise.png",
		"along the owner's noise"
	)
	assert_not_null(fx.glare, "the glare flies off it")
	var burst := fx.glare
	assert_gt(burst.alive(), 0, "sparkles show mid-dissolve")
	assert_eq(
		(burst.material as CanvasItemMaterial).blend_mode,
		CanvasItemMaterial.BLEND_MODE_ADD,
		"additive light"
	)
	fx.set_burn(1.0)
	assert_null(fx.glare, "the dissolve done, the glare goes")
	await get_tree().process_frame
	assert_false(is_instance_valid(burst), "its node is freed")
	fx.set_burn(0.0)
	assert_false(fx.burning())
	assert_null(fx.face.material, "the card is whole again")
	assert_eq(fx.find_children("*", "GlareBurst", true, false).size(), 0)


func test_the_glare_follows_the_effects_density() -> void:
	var hi := GlareBurst.new(Vector2(275, 450), &"x", "high")
	var lo := GlareBurst.new(Vector2(275, 450), &"x", "low")
	assert_gt(hi.count(), lo.count(), "fewer sparkles at low density")
	hi.free()
	lo.free()


func test_the_glare_is_the_same_at_the_same_progress() -> void:
	var a := GlareBurst.new(Vector2(275, 450), &"wildfire", "high")
	var b := GlareBurst.new(Vector2(275, 450), &"wildfire", "high")
	for t in [0.1, 0.4, 0.7, 0.99]:
		a.progress = t
		b.progress = t
		assert_eq(a.alive(), b.alive(), "progress %.2f" % t)
	a.progress = 1.0
	assert_eq(a.alive(), 0, "all gone by the end")
	a.free()
	b.free()


## v0.10.5 W3-S12 (the Blink card's "HABILIDAD NUEVA · RARO" ran past the frame): every card's rarity line and title
## keep inside the carved frame's inner width, in both languages; the rarity line steps down to 85 % of its size,
## then wraps to two lines.
func _all_names() -> Array:
	var out: Array = []
	for cat: StringName in [&"abilities", &"items", &"stat_cards", &"curses", &"modifiers"]:
		for d: ContentDef in _repo.all_of(cat):
			var k = d.get("name_key")
			if k != null and String(k) != "":
				out.append(k)
	return out


func _tier_lines() -> Array:
	var out: Array = []
	for r in ["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY"]:
		out.append(tr(r))
		for k in [
			"UI_CARD_ABILITY_NEW",
			"UI_CARD_MODIFIER_NEW",
			"UI_CARD_MOD",
			"UI_CARD_MODIFIER",
			"UI_CARD_CURSE"
		]:
			out.append("%s · %s" % [tr(k), tr(r)])
		for lv in [2, 5, 10]:
			out.append("%s · %s" % [tr("UI_CARD_ABILITY_LEVEL") % lv, tr(r)])
	return out


func test_card_titles_and_rarity_lines_fit_the_frame_in_every_language() -> void:
	var longest := {}
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		var names := _all_names()
		assert_gt(names.size(), 20, "%s: the cards' names were found" % lang)
		for scale_f in [1.0, 1.5]:
			var card := StoneCard.new(scale_f, true)
			add_child_autofree(card)
			var inner := card.inner_width()
			var tier_font: Font = card.find_child("Tier", true, false).get_theme_font("font")
			for line: String in _tier_lines():
				card.show_face(&"blink", "Blink", "A sentence.", &"", 0, Color.WHITE, line)
				var floor_px := ceili(roundi(StoneCard.TIER_SIZE * scale_f) * StoneCard.TIER_FLOOR)
				assert_lte(
					card.tier_line_width(), inner + 1.0, "%s: '%s' fits %s" % [lang, line, inner]
				)
				assert_gte(card.tier_fit_size, floor_px, "'%s' stays at or above the floor" % line)
				assert_gte(
					card.tier_rect().position.y,
					card.gem_rect().end.y,
					"%s: '%s' sits under the gem" % [lang, line]
				)
				assert_lte(card.tier_rect().end.y, card.size.y + 0.5, "inside the card's foot")
				assert_lte(card.tier_rect().size.x, inner + 0.5, "the box is inside the frame")
				if scale_f == 1.0:
					var w := (
						tier_font
						. get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, card.tier_fit_size)
						. x
					)
					if w > longest.get(lang + "_w", 0.0):
						longest[lang + "_w"] = w
						longest[lang] = "'%s' at %d px" % [line, card.tier_fit_size]
			for n: StringName in names:
				var title := tr(n)
				card.show_face(&"blink", title, "A sentence.", &"", 0, Color.WHITE, "Rare")
				var tf: Font = card.find_child("Title", true, false).get_theme_font("font")
				assert_lte(
					card.title_box().x, inner + 0.5, "%s: %s's box is inside the frame" % [lang, n]
				)
				assert_lte(
					TextFit.widest_word(tf, title.to_upper(), card.title_size),
					inner + 0.5,
					"%s: every word of '%s' fits at %d px" % [lang, title, card.title_size]
				)
				if scale_f == 1.0 and title.length() > longest.get(lang + "_t", 0):
					longest[lang + "_t"] = title.length()
					longest[lang + "_title"] = "'%s' at %d px" % [title, card.title_size]
	TranslationServer.set_locale("en")
	gut.p("longest: %s" % longest)
