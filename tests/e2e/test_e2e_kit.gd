extends GutTest
## The Vent and Skill buttons in the real game (v0.3.5 K, owner F1, F12, F18), through real input only
## (Input.parse_input_event): on a Blade run, Q lunges and cleaves (the HUD pip empties and refills over 4 s) and F
## while cool only clicks; on a Gun run, pad Y fires the Scatter Blast (7 pellets, tracers drawn) and the dash waits
## 1.4 s between uses. Read through WorldReader and the HUD. (Venting while Hot through pad B is in
## test_e2e_heat.gd.)


func after_each() -> void:
	for a in [&"skill", &"vent", &"dash"]:
		Input.action_release(a)


func _events(r: WorldReader, kind: SimEvent.Kind, after: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in r.events_since(after):
		if e.kind == kind:
			out.append(e)
	return out


func _press_pad(e: E2e, button: JoyButton) -> void:
	e.joy_button(button, true)
	await e.frames(2)
	e.joy_button(button, false)
	await e.frames(1)


func test_blade_q_lunges_and_cleaves_and_f_clicks_while_cool() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"blade")
	await e.frames(5)
	assert_true(main.is_playing())
	var r := WorldReader.new(e.world())
	var hud: Hud = main.get_node("UI/Hud")
	var pip := hud.kit_hud
	var s := r.skill_state()
	assert_false(s.is_empty(), "the Blade run has its skill")
	assert_eq(int(s["kind"]), WorldReader.SKILL_LUNGE_CLEAVE)
	assert_true(pip.skill_visible(), "the HUD shows the skill pip")
	assert_true(pip.skill_text().contains("Q"), "with its key: %s" % pip.skill_text())
	assert_almost_eq(pip.skill_fill(), 1.0, 1e-6, "ready")
	var seq := r.last_event_seq()
	var from := r.player_pos()
	await e.tap(KEY_Q)
	await e.frames(2)
	var used := _events(r, SimEvent.Kind.SKILL_USED, seq)
	assert_eq(used.size(), 1, "Q used the skill")
	assert_true(int(r.skill_state()["running"]) > 0, "the lunge runs")
	assert_true(main.view.skill_fx.forecast_visible(), "its cleave fan rides along")
	# v0.5.5 LK (A1): the hero lunges and the cleave sweeps the real fan, landing on the hit tick.
	var hero: PlayerAvatar = (
		main.view.actors.actor_node(r.actor_id(0)).get_meta(&"avatar") as PlayerAvatar
	)
	var lunged := 0.0
	var swept := false
	for k in 20:
		await e.frames(1)
		lunged = maxf(lunged, hero.lunge_amount())
		var sw: Array = main.view.skill_fx.cleave_sweep()
		swept = swept or (sw[0] == 1.0 and sw[1] > 0.0)
	assert_gt(lunged, 0.5, "the hero took the lunge pose")
	assert_true(swept, "the cleave sweep crossed the whole arc")
	s = r.skill_state()
	assert_eq(int(s["running"]), 0, "lunge and cleave done")
	assert_gt(int(s["hit_tick"]), -1, "the cleave went off")
	var moved := r.player_pos().distance_to(from)
	gut.p("lunged %.2f m" % moved)
	assert_gt(moved, 0.3, "the lunge moved the hero (walls may stop it short)")
	assert_lte(moved, 3.5 + 0.05, "never farther than 3.5 m")
	assert_lt(pip.skill_fill(), 0.2, "the pip emptied")
	await e.tap(KEY_Q)
	await e.frames(3)
	assert_eq(_events(r, SimEvent.Kind.SKILL_USED, seq).size(), 1, "on cooldown: nothing")
	# F while cool: no blast, only the cold click.
	assert_lt(float(r.heat_state()["heat"]), float(r.heat_state()["hot"]), "still cool")
	var vseq := r.last_event_seq()
	await e.tap(KEY_F)
	await e.frames(2)
	assert_eq(_events(r, SimEvent.Kind.VENT_COLD, vseq).size(), 1, "F clicked cold")
	assert_eq(_events(r, SimEvent.Kind.VENT, vseq).size(), 0, "and vented nothing")
	assert_false(pip.vent_lit(), "the vent hint stays dim")
	# The pip refills: the skill is back 4 s after the press.
	await e.frames(240)
	assert_true(bool(r.skill_state()["ready"]), "ready again after 4 s")
	assert_almost_eq(pip.skill_fill(), 1.0, 1e-6, "the pip is full")
	await e.tap(KEY_Q)
	await e.frames(2)
	assert_eq(_events(r, SimEvent.Kind.SKILL_USED, seq).size(), 2, "and Q uses it again")


func test_gun_pad_y_fires_the_scatter_blast_and_the_dash_waits_1_4_s() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.frames(5)
	var r := WorldReader.new(e.world())
	var s := r.skill_state()
	assert_eq(int(s["kind"]), WorldReader.SKILL_SCATTER_BLAST, "the Gun run has the Scatter Blast")
	var seq := r.last_event_seq()
	e.joy_button(JOY_BUTTON_Y, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_Y, false)
	await e.frames(1)
	var used := _events(r, SimEvent.Kind.SKILL_USED, seq)
	assert_eq(used.size(), 1, "pad Y used the skill")
	s = r.skill_state()
	assert_eq((s["pellet_ends"] as PackedVector2Array).size(), 7, "7 pellets flew")
	assert_eq(main.view.skill_fx.fx_count_of(&"tracer"), 7, "7 tracers drawn")
	# v0.5.5 LK (A1): a braced blast that kicks the hero back.
	var hero: PlayerAvatar = (
		main.view.actors.actor_node(r.actor_id(0)).get_meta(&"avatar") as PlayerAvatar
	)
	var kicked := 0.0
	for k in 4:
		await e.frames(1)
		kicked = maxf(kicked, hero.recoil_amount())
	assert_gt(kicked, 0.3, "the recoil kicked the hero back")
	assert_gt(hero.brace_amount(), 0.2, "braced")
	# The dash (pad right bumper): used, then refused until 1.4 s later.
	await e.frames(6)
	await _press_pad(e, JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(r.dash_cooldown_total(), 84, "a 1.4 s dash cooldown")
	assert_gt(r.dash_cooldown(), 70, "the dash went")
	await e.frames(30)
	await _press_pad(e, JOY_BUTTON_RIGHT_SHOULDER)
	assert_false(r.is_dashing(), "0.6 s later: not yet")
	await e.frames(60)
	await _press_pad(e, JOY_BUTTON_RIGHT_SHOULDER)
	assert_gt(r.dash_cooldown(), 70, "after 1.4 s it dashes again")
