extends GutTest
## The gamble shrine's views (v0.3.0 L19): the shrine's glow and flash change no shader, its price turns red when
## you can't pay, the card's spin lands on the stat won, every stat has an icon and a line in both languages, and
## the stats panel lists what was won.


func _world() -> World:
	var w := World.new(5, PlayerTable.starting_values())
	w.gamble_id = w.take_root()
	w.gamble_pos = Vector2(0.8, 0)
	return w


func test_the_shrine_glows_and_flashes_without_changing_a_shader() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var view := GambleShrineView.new()
	add_child_autofree(view)
	view.set_process(false)
	view.setup(reader.gamble_pos())
	view.sync(reader)
	var before := DamageFlashKeys.of(view)
	assert_gt(before.size(), 10, "the shrine has its pieces")
	for m in view.materials():
		assert_true(m.emission_enabled, "emission on from creation")
	w.shards = 100
	w.input_buffer[3] = 1
	Gamble.interact(w)
	view.sync(reader)
	assert_true(view.spinning())
	for k in 80:
		view._process(1.0 / 60.0)
	assert_false(view.spinning(), "the spin ends")
	assert_eq(DamageFlashKeys.of(view), before, "the spin and the landing flash changed no shader")
	for m in view.materials():
		assert_true(m.emission_enabled)


func test_the_price_is_red_when_you_cant_pay() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var view := GambleShrineView.new()
	add_child_autofree(view)
	view.setup(reader.gamble_pos())
	view.sync(reader)
	assert_true(view.price_label.visible, "near: the price shows")
	assert_eq(view.price_label.text, "25")
	assert_eq(view.price_label.modulate, GambleShrineView.PRICE_POOR)
	w.shards = 25
	view.sync(reader)
	assert_eq(view.price_label.modulate, GambleShrineView.PRICE_OK)
	w.actors.set_pos(0, Vector2(GambleShrineView.PRICE_NEAR_M + 2.0, 0))
	view.sync(reader)
	assert_false(view.price_label.visible, "far: hidden")


func test_the_card_spins_then_lands_on_the_result() -> void:
	var card := GambleCard.new()
	add_child_autofree(card)
	card.set_process(false)
	var reel: Array[StringName] = [&"max_hp", &"shot_damage", &"melee_damage"]
	card.play(reel, &"melee_damage", "+6 % melee damage")
	assert_true(card.spinning())
	assert_eq(card.line_text(), "", "no line while spinning")
	var seen := {}
	for k in int(GambleCard.SPIN_S * 60.0) + 3:
		card._process(1.0 / 60.0)
		if card.spinning():
			seen[card.shown_stat()] = true
	assert_gt(seen.size(), 1, "the reel shows several stats")
	assert_false(card.spinning())
	assert_eq(card.shown_stat(), &"melee_damage")
	assert_eq(card.line_text(), "+6 % melee damage")
	for k in int((GambleCard.HOLD_S + GambleCard.FADE_S) * 60.0) + 4:
		card._process(1.0 / 60.0)
	assert_false(card.visible, "it fades away")


func test_every_stat_has_an_icon_and_a_line() -> void:
	var ci := Control.new()
	add_child_autofree(ci)
	for s in GambleTable.STAT_COUNT:
		var id := GambleTable.STAT_IDS[s]
		assert_true(GambleIcons.KEYS.has(id), "%s has a line" % id)
		assert_true(GambleIcons.COLORS.has(id), "%s has a colour" % id)
		assert_gt(GambleIcons.shapes(id).size(), 1, "%s has its own icon" % id)
	assert_eq(GambleIcons.percent(60), "6")
	assert_eq(GambleIcons.percent(5), "0.5")
	assert_eq(GambleIcons.line(ci, &"max_hp", 16), tr("UI_GAMBLE_MAX_HP") % 16)
	TranslationServer.set_locale("en")
	assert_eq(GambleIcons.line(ci, &"melee_damage", 60), "+6 % melee damage")
	assert_eq(GambleIcons.line(ci, &"regen", 5), "+0.5 % HP/s out of combat")
	TranslationServer.set_locale("es")
	assert_eq(GambleIcons.line(ci, &"melee_damage", 60), "+6 % de daño cuerpo a cuerpo")
	TranslationServer.set_locale("en")


func test_the_stats_panel_lists_what_was_won() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var panel := GambleStatsPanel.new()
	add_child_autofree(panel)
	panel.sync(reader)
	assert_eq(panel.row_count(), 0)
	Gamble.grant(w, GambleTable.Stat.MELEE)
	Gamble.grant(w, GambleTable.Stat.MELEE)
	Gamble.grant(w, GambleTable.Stat.MAX_HP)
	panel.sync(reader)
	assert_eq(panel.row_count(), 2, "one row per stat")
	assert_eq(panel.row_text(0), GambleIcons.line(panel, &"max_hp", 8))
	assert_eq(panel.row_text(1), GambleIcons.line(panel, &"melee_damage", 120))
