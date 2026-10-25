extends GutTest
## The gamble shrine's views (v0.3.0 L19): the shrine's glow and flash change no shader, its price turns red when
## you can't pay, the card's spin lands on the stat won, every stat has an icon and a line in both languages, and
## the stats panel lists what was won. v0.8.0 N14 (owner O72): a failed use fizzles (no shader changes) and shows
## "It failed"; a spent shrine is dimmed with "Spent" above it; the prompt's odds line reads the sim's numbers.


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
	w.gamble_table.fail_permille = 0  # v0.8.0 N14: this use wins
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


## v0.8.0 N14: a world whose shrine's first use fails.
func _failing_world() -> World:
	var w := _world()
	for s in range(1, 1000):
		w.seed_value = s
		if Gamble.fails(w, 0):
			break
	return w


func test_a_failed_use_fizzles_without_changing_a_shader_and_says_so() -> void:
	var w := _failing_world()
	var reader := WorldReader.new(w)
	var view := GambleShrineView.new()
	add_child_autofree(view)
	view.set_process(false)
	view.setup(reader.gamble_pos())
	var hud := GambleHud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	view.sync(reader)
	hud.sync(reader)
	var before := DamageFlashKeys.of(view)
	w.shards = 100
	w.input_buffer[3] = 1
	assert_false(Gamble.interact(w), "the use failed")
	view.sync(reader)
	hud.sync(reader)
	assert_true(view.fizzling(), "the shrine fizzles")
	assert_false(view.spinning(), "no spin: nothing won")
	assert_false(hud.card.showing(), "no result card")
	TranslationServer.set_locale("en")
	hud.sync(reader)
	assert_eq(hud.fail_text(), "It failed")
	for k in int(GambleShrineView.FIZZLE_S * 60.0) + 2:
		view._process(1.0 / 60.0)
	assert_false(view.fizzling(), "the fizzle ends")
	assert_eq(DamageFlashKeys.of(view), before, "the fizzle changed no shader")
	for k in int(GambleHud.FAIL_S * 60.0) + 2:
		hud._process(1.0 / 60.0)
	assert_eq(hud.fail_text(), "", "the line goes")
	TranslationServer.set_locale("es")
	w.gamble_fail_tick = 99
	hud.sync(reader)
	assert_eq(hud.fail_text(), "Falló")
	TranslationServer.set_locale("en")


## v0.8.0 N18 (owner O76): N14's odds line is gone (no wins count, no chance to fail on screen); a spent shrine says
## one word and dims.
func test_no_odds_line_and_a_spent_shrine_dims() -> void:
	var w := _world()
	w.actors.set_pos(0, w.gamble_pos + Vector2(1.0, 0))
	var reader := WorldReader.new(w)
	var hud := GambleHud.new()
	add_child_autofree(hud)
	var view := GambleShrineView.new()
	add_child_autofree(view)
	view.setup(reader.gamble_pos())
	TranslationServer.set_locale("en")
	hud.sync(reader)
	assert_null(hud.find_child("GambleOdds", true, false), "no odds line")
	assert_false(hud.prompt_text().contains("%"), "the prompt names no chance")
	w.gamble_table.max_wins = 4
	w.gamble_wins = 4
	w.shards = 1000
	hud.sync(reader)
	view.sync(reader)
	assert_true(reader.gamble_spent())
	assert_eq(hud.prompt_text(), "Spent")
	assert_true(hud.prompt_poor(), "in the refusal colour")
	assert_true(view.dimmed(), "dimmed")
	assert_true(view.price_label.visible)
	assert_eq(view.price_label.text, "Spent")
	assert_eq(view.price_label.modulate, GambleShrineView.PRICE_SPENT)
	TranslationServer.set_locale("es")
	view.sync(reader)
	assert_eq(view.price_label.text, "Agotado")
	TranslationServer.set_locale("en")


## v0.9.5 SS (owner: "clearer and more visual when it fails ... the reward shown over it"): a fail cracks the core
## for under 1.2 s and ends at rest; a win floats the stat's icon above the shrine and frees it after 2 s.
func test_a_fail_cracks_the_core_briefly_and_returns_to_rest() -> void:
	var w := _failing_world()
	var reader := WorldReader.new(w)
	var view := GambleShrineView.new()
	add_child_autofree(view)
	view.set_process(false)
	view.setup(reader.gamble_pos())
	view.sync(reader)
	w.shards = 100
	w.input_buffer[3] = 1
	assert_false(Gamble.interact(w))
	view.sync(reader)
	assert_lte(GambleShrineView.FIZZLE_S, 1.2, "the fail reads in 1.2 s")
	var cracked_seen := false
	var peak_drop := 0.0
	var dimmest := 99.0
	var flashed := false
	var t := 0.0
	while view.fizzling() and t < 3.0:
		view._process(1.0 / 60.0)
		t += 1.0 / 60.0
		peak_drop = maxf(peak_drop, -view._body.position.y)
		dimmest = minf(dimmest, view._core_mat.emission_energy_multiplier)
		flashed = flashed or view._core_mat.emission.is_equal_approx(Color.WHITE)
		cracked_seen = cracked_seen or view.cracked()
	assert_lte(t, 1.2, "the fizzle ends within 1.2 s")
	assert_true(flashed, "the core flashes white first")
	assert_almost_eq(peak_drop, GambleShrineView.JOLT_M, 0.01, "the body drops 6 cm")
	assert_lte(dimmest, GambleShrineView.CORE_ENERGY * 0.3, "the core dims toward 20 %")
	assert_true(cracked_seen, "the cracks showed")
	for k in 20:
		view._process(1.0 / 60.0)
	assert_false(view.cracked(), "the cracks are gone within 1 s")
	assert_eq(view._body.position, Vector3.ZERO, "the body is back at rest")
	assert_almost_eq(
		view._core_mat.emission_energy_multiplier,
		GambleShrineView.CORE_ENERGY * (1.35 if reader.gamble_in_reach() else 1.0),
		0.01
	)


func test_a_fail_under_reduced_motion_does_not_jolt_but_still_cracks() -> void:
	var old := ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = true
	var w := _failing_world()
	var reader := WorldReader.new(w)
	var view := GambleShrineView.new()
	add_child_autofree(view)
	view.set_process(false)
	view.setup(reader.gamble_pos())
	view.sync(reader)
	w.shards = 100
	w.input_buffer[3] = 1
	Gamble.interact(w)
	view.sync(reader)
	var drop := 0.0
	for k in 30:
		view._process(1.0 / 60.0)
		drop = maxf(drop, -view._body.position.y)
	assert_eq(drop, 0.0, "no jolt")
	assert_true(view.cracked(), "the cracks still show")
	ViewPrefs.reduced_motion = old


func test_a_win_floats_the_prize_icon_over_the_shrine_for_two_seconds() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var view := GambleShrineView.new()
	add_child_autofree(view)
	view.set_process(false)
	view.setup(reader.gamble_pos())
	view.sync(reader)
	w.shards = 100
	w.gamble_table.fail_permille = 0
	w.input_buffer[3] = 1
	assert_true(Gamble.interact(w))
	view.sync(reader)
	assert_null(view.prize(), "the prize waits for the landing")
	var t := 0.0
	while view.prize() == null and t < 2.0:
		view._process(1.0 / 60.0)
		t += 1.0 / 60.0
	var prize := view.prize()
	assert_not_null(prize, "the prize appears when the spin lands")
	assert_true(view.pulsing(), "the gold ring pulses at the same moment")
	assert_eq(prize.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
	assert_true(prize.no_depth_test)
	assert_false(prize.fixed_size)
	assert_almost_eq(prize.pixel_size * GambleShrineView.PRIZE_PX, 0.45, 0.001, "0.45 m wide")
	assert_almost_eq(prize.position.y, GambleShrineView.PRIZE_FROM_M, 0.05, "starts at 1.4 m")
	assert_almost_eq(prize.scale.x, 0.6, 0.15, "starts small")
	for k in 12:
		view._process(1.0 / 60.0)
	assert_almost_eq(prize.scale.x, 1.0, 0.02, "full size after 0.2 s")
	for k in 60:
		view._process(1.0 / 60.0)
	assert_gt(prize.position.y, GambleShrineView.PRIZE_FROM_M + 0.2, "rising")
	for k in 60:
		view._process(1.0 / 60.0)
	assert_lt(prize.modulate.a, 1.0, "fading in the last half second")
	for k in 40:
		view._process(1.0 / 60.0)
	assert_null(view.prize(), "gone after 2 s")
	assert_false(view.pulsing())
