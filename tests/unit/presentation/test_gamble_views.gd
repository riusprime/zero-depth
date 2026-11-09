extends GutTest
## The gamble shrine's views (v0.3.0 L19): the shrine's glow and flash change no shader, its price turns red when
## you can't pay, the reward rolls above the shrine and flies to the corner panel (v0.11.0 F13), every stat has an
## icon and a line in both languages, and the stats panel lists what was won. v0.8.0 N14 (owner O72): a failed use
## fizzles (no shader changes); a spent shrine is dimmed with "Spent" above it; the prompt's odds line reads the
## sim's numbers.


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


## v0.11.0 F13: the Fortune shrine's reward rolls above the shrine, then flies to the corner panel.
func _hud_with_shrine(win: bool) -> Array:
	var w := _world() if win else _failing_world()
	var reader := WorldReader.new(w)
	var hud := GambleHud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.roll.set_process(false)
	hud.sync(reader)
	w.shards = 100
	if win:
		w.gamble_table.fail_permille = 0
	w.input_buffer[3] = 1
	assert_eq(Gamble.interact(w), win)
	hud.sync(reader)
	return [w, reader, hud]


func _run(roll: GambleRoll, seconds: float) -> void:
	for k in int(seconds * 60.0):
		roll._process(1.0 / 60.0)


func test_a_win_cycles_stops_then_flies_into_the_panel_row_that_updates_on_arrival() -> void:
	var old := ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false
	var made := _hud_with_shrine(true)
	var reader: WorldReader = made[1]
	var hud: GambleHud = made[2]
	var roll := hud.roll
	var stat := reader.gamble_last_stat()
	var id := reader.gamble_stat_id(stat)
	assert_eq(roll.count(), 1, "a symbol above the shrine")
	assert_eq(roll.phase_of(0), GambleRoll.Phase.SPIN)
	assert_null(hud.find_child("GambleCard", true, false), "no centre card")
	assert_null(hud.find_child("GambleFailed", true, false), "no centre line")
	assert_eq(Gamble.stacks(made[0], stat), 1, "the sim applied it at once")
	assert_eq(hud.stats.row_count(), 0, "the panel's row waits for the symbol")
	assert_true(hud.stats.visible, "and the panel is up for it to land in")
	var seen := {}
	for k in int(GambleRoll.SPIN_S * 60.0) - 2:
		roll._process(1.0 / 60.0)
		seen[roll.shown_id(0)] = true
	assert_gte(seen.size(), 4, "it cycles through several stat symbols")
	_run(roll, 0.05)
	assert_eq(roll.phase_of(0), GambleRoll.Phase.HOLD, "then stops")
	assert_eq(roll.shown_id(0), id, "on the real result")
	_run(roll, GambleRoll.HOLD_S + 0.02)
	assert_eq(roll.phase_of(0), GambleRoll.Phase.FLY, "then flies")
	var start := roll.center_of(0)
	var size0 := roll.view_of(0).scale.x
	_run(roll, GambleRoll.FLY_S * 0.5)
	assert_lt(roll.view_of(0).scale.x, size0, "shrinking on the way")
	assert_eq(hud.stats.row_count(), 0, "still not updated mid-flight")
	_run(roll, GambleRoll.FLY_S * 0.5 + 0.05)
	assert_eq(roll.count(), 0, "it arrived and is gone")
	assert_eq(roll.arrived, 1)
	assert_ne(roll.center_of_last(), start, "from above the shrine to the corner")
	assert_eq(hud.stats.row_count(), 1, "the row shows on arrival")
	assert_eq(hud.stats.held(stat), 0)
	assert_true(hud.stats.lit(), "with a brief highlight")
	hud._process(1.0 / 60.0)
	assert_true(hud.stats.visible, "the panel stays up after landing")
	ViewPrefs.reduced_motion = old


func test_a_fail_stops_on_a_broken_symbol_shakes_fades_and_flies_nowhere() -> void:
	var old := ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false
	var made := _hud_with_shrine(false)
	var hud: GambleHud = made[2]
	var roll := hud.roll
	assert_eq(roll.count(), 1)
	_run(roll, GambleRoll.SPIN_S + 0.05)
	assert_true(roll.is_broken(0), "the cracked symbol")
	_run(roll, GambleRoll.HOLD_S + 0.02)
	assert_eq(roll.phase_of(0), GambleRoll.Phase.FAIL)
	var x0 := roll.view_of(0).position.x
	var moved := false
	for k in 12:
		roll._process(1.0 / 60.0)
		moved = moved or not is_equal_approx(roll.view_of(0).position.x, x0)
	assert_true(moved, "it shakes")
	assert_lt(roll.view_of(0).modulate.a, 1.0, "and fades")
	_run(roll, GambleRoll.FAIL_S)
	assert_eq(roll.count(), 0, "gone")
	assert_eq(roll.arrived, 0, "nothing flew")
	assert_eq(hud.stats.row_count(), 0)
	assert_null(hud.find_child("GambleFailed", true, false), "no line, no text")
	ViewPrefs.reduced_motion = old


func test_reduced_motion_shows_the_result_holds_fades_and_updates_the_panel_at_once() -> void:
	var old := ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = true
	var made := _hud_with_shrine(true)
	var reader: WorldReader = made[1]
	var hud: GambleHud = made[2]
	var roll := hud.roll
	assert_eq(roll.shown_id(0), reader.gamble_stat_id(reader.gamble_last_stat()), "no cycling")
	assert_eq(hud.stats.row_count(), 1, "the panel updated at once")
	assert_true(hud.stats.visible)
	_run(roll, GambleRoll.REDUCED_HOLD_S - 0.1)
	assert_eq(roll.count(), 1, "it holds")
	assert_eq(roll.phase_of(0), GambleRoll.Phase.HOLD)
	_run(roll, 0.2 + GambleRoll.REDUCED_FADE_S + 0.05)
	assert_eq(roll.count(), 0, "then fades away")
	assert_eq(roll.arrived, 0, "with no flight")
	ViewPrefs.reduced_motion = old


func test_a_second_use_has_its_own_symbol_and_clearing_leaves_nothing_held() -> void:
	var old := ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false
	var made := _hud_with_shrine(true)
	var reader: WorldReader = made[1]
	var hud: GambleHud = made[2]
	var roll := hud.roll
	var stat := reader.gamble_last_stat()
	_run(roll, 0.3)
	roll.start(reader, stat)  # a second use while the first is still rolling
	assert_eq(roll.count(), 2, "its own symbol")
	assert_eq(hud.stats.held(stat), 2)
	_run(roll, 3.0)
	assert_eq(roll.count(), 0, "both finished")
	assert_eq(hud.stats.held(stat), 0, "nothing stuck")
	roll.start(reader, stat)
	roll.clear()
	assert_eq(roll.count(), 0)
	assert_eq(hud.stats.held(stat), 0, "cleared symbols release their rows")
	ViewPrefs.reduced_motion = old


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
	assert_eq(hud.roll.count(), 1, "the broken symbol rolls above the shrine")
	assert_null(hud.find_child("GambleCard", true, false), "no centre card")
	for k in int(GambleShrineView.FIZZLE_S * 60.0) + 2:
		view._process(1.0 / 60.0)
	assert_false(view.fizzling(), "the fizzle ends")
	assert_eq(DamageFlashKeys.of(view), before, "the fizzle changed no shader")


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
