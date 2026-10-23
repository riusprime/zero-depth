extends GutTest
## v0.9.0 SV (owner: "Hero grows each floor"): the floor's arrival card says the max HP the hero grew ("Max HP +15", en
## and es); a floor without growth (the run's first, the final arena, a resumed floor) shows no such line.


func test_the_arrival_card_names_the_growth() -> void:
	var h := Hud.new()
	add_child_autofree(h)
	h.show_floor(2, "BIOME_RUINS", false, 0, 1, 15)
	var head := "%s %s" % [tr("HUD_FLOOR_CARD") % 2, tr("BIOME_RUINS")]
	assert_eq(h.floor_card_text(), head + " " + tr("HUD_MAX_HP_GROWN") % 15)
	h.show_floor(3, "BIOME_RUINS", false, 16, 1, 15)
	assert_eq(
		h.floor_card_text(),
		(
			"%s %s %s %s"
			% [
				tr("HUD_FLOOR_CARD") % 3,
				tr("BIOME_RUINS"),
				tr("HUD_SHARDS_HALVED") % 16,
				tr("HUD_MAX_HP_GROWN") % 15
			]
		),
		"after the shard line"
	)
	h.show_floor(1, "BIOME_RUINS")
	assert_eq(
		h.floor_card_text(),
		"%s %s" % [tr("HUD_FLOOR_CARD") % 1, tr("BIOME_RUINS")],
		"no growth: no line"
	)


func test_the_line_is_in_english_and_spanish() -> void:
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(tr("HUD_MAX_HP_GROWN") % 15, "Max HP +15")
	TranslationServer.set_locale("es")
	assert_eq(tr("HUD_MAX_HP_GROWN") % 15, "Vida máxima +15")
	TranslationServer.set_locale(was)
