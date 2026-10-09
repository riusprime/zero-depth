extends GutTest
## v0.6.0 CU through real input (PLAN v0.5.5 S6, S7, X2): start a run from the menu, god mode from the dev panel (so
## the walk survives the floor), then
## 1. the dev route curses the next chest; walk (left stick) to a chest, open it with the pad's X: its first card is a
##    trade-off curse card (the curse's name, its upside on the face, rare; its drawback under it); take it with A:
##    the curse is held, T shows 1 and the HUD lists drawback and upside; the curse's effect shows in play;
## 2. the dev panel's TEST HELPER spawns an elite carrying a core (the crystal glows its card family's colour); walk
##    up and swing (left trigger) until it staggers: the steal ring shows; keep swinging and kill it inside the
##    window: its core drops; walk to it, E opens the pick ("Stolen core"), Enter takes it and the card is yours.

const MAX_FRAMES := 3600
const CLOSE_M := 1.4


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"primary"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _dev(e: E2e, main: Main, button: String) -> void:
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, button)
	await e.tap(KEY_QUOTELEFT)


func _stick(e: E2e, x_axis: JoyAxis, y_axis: JoyAxis, dir: Vector2) -> void:
	var c := InputLatch.C45
	e.joy_axis(x_axis, (dir.x + dir.y) * c)
	e.joy_axis(y_axis, -(dir.y - dir.x) * c)


func _pad_tap(e: E2e, button: JoyButton) -> void:
	e.joy_button(button, true)
	await e.frames(1)
	e.joy_button(button, false)
	await e.frames(3)


func test_take_a_cursed_chest_card_and_feel_its_trade_off() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	await _dev(e, main, "God")
	await _dev(e, main, "CurseChest")
	var chest := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
	assert_gte(chest, 0, "a chest on the floor")
	# TEST HELPER (labelled): grant the shards directly; earning them is test_e2e_rewards' job.
	w.shards = 500
	assert_true(await e.walk_to(w.rewards.pos(chest), 0.6), "walked to the chest")
	await _pad_tap(e, JOY_BUTTON_X)
	assert_gte(w.choosing, 0, "the pad's X opened the chest")
	var pick := hud.pick_panel()
	var curse := Curses.offer_curse(w, w.choosing, 0)
	assert_gte(curse, 0, "its first card is cursed")
	var t := w.ev.curses[curse]
	gut.p("cursed card: %s / %s" % [t.id, pick.slot(0).curse_text()])
	assert_true(t.is_trade_off(), "S6: a trade-off curse, not an epic stat card")
	assert_eq(pick.slot(0).card.title_text(), tr(t.name_key), "the card is the curse")
	assert_eq(pick.slot(0).card.tier_text(), "%s · %s" % [tr("UI_CARD_CURSE"), tr("RARITY_RARE")])
	assert_false(pick.slot(0).card.desc_text().is_empty(), "its face says the upside")
	assert_true(pick.slot(0).curse_text().begins_with(tr(t.name_key)), "the drawback under it")
	assert_eq(pick.slot(0).family(), &"curse", "the curse frame")
	assert_eq(pick.slot(1).curse_text(), "", "the others are clean")
	await _pad_tap(e, JOY_BUTTON_A)
	assert_eq(w.choosing, -1, "A took it")
	assert_eq(w.curses_owned, PackedInt32Array([curse]), "the curse is held")
	assert_eq(hud.events.threat.title_text(), tr("UI_THREAT") % 1, "T + 1")
	await e.frames(2)
	var r := WorldReader.new(w)
	var line := CurseLook.line(hud, r, curse)
	assert_true(line.contains(" · "), "the HUD line names drawback and upside: %s" % line)
	await _feel(e, main, w, curse)


## The taken curse's effect, seen in play (input where the effect is about input).
func _feel(e: E2e, main: Main, w: World, c: int) -> void:
	var hud: Hud = main.get_node("UI/Hud")
	match w.ev.curses[c].id:
		&"rooted":
			await e.tap(KEY_SPACE)
			await e.frames(2)
			assert_eq(w.dash_ticks_left, 0, "Rooted: Space doesn't dash")
			assert_eq(w.dash_cooldown_left, 0, "not even its cooldown")
		&"tunnel_vision":
			await e.frames(2)
			assert_false(hud.minimap.corner.visible, "Tunnel Vision: no minimap")
			assert_eq(Stats.shards(w, 100), 125)
		&"glass_heart":
			assert_eq(Stats.crit_chance(w), w.player.crit_chance_permille + 150)
			assert_lt(w.actors.max_hp[0], Stats.max_hp(w) + 1)
		&"heavy_hands":
			assert_eq(Stats.period(w, 30), 38, "Heavy Hands: slower attacks")
		&"blood_price":
			var hp := w.actors.hp[0]
			await e.tap(KEY_Q)
			await e.frames(3)
			assert_lt(w.actors.hp[0], hp, "Blood Price: the Skill cost HP")
		&"fevered":
			assert_eq(Curses.overclock_bonus(w), 400)
		&"brittle":
			assert_almost_eq(Curses.move_factor(w), 1.2, 0.001)
		&"marked_hunt":
			assert_true(Curses.elite_drops(w))
		_:
			fail_test("an unknown trade-off: %s" % w.ev.curses[c].id)


func test_steal_a_core_from_an_elite() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var r := WorldReader.new(w)
	var hud: Hud = main.get_node("UI/Hud")
	await _dev(e, main, "God")
	var before := w.ev.elite_ids.size()
	await _dev(e, main, "SpawnElite")  # TEST HELPER: an elite with a core, 6 m away
	await e.frames(2)
	assert_eq(w.ev.elite_ids.size(), before + 1, "an elite arrived")
	var id := w.ev.elite_ids[w.ev.elite_ids.size() - 1]
	var k := CoreTheft.entry_of(w, id)
	assert_gte(k, 0, "it carries a core")
	var card := w.cores.card[k]
	gut.p("the elite's core: %s" % r.card_info(card)["id"])
	await e.frames(2)
	assert_eq(main.view.cores.core_count(), 1, "its core is drawn")
	assert_eq(
		main.view.cores.core_color_of(id), CoreViews.card_color(r, card), "in its family's colour"
	)
	var saw_ring := false
	var trigger := false
	for f in MAX_FRAMES:
		var i := w.actors.index_of(id)
		if i < 0 or w.actors.dead[i] == 1:
			break
		var p := r.player_pos()
		var to := r.actor_pos(i) - p
		var walk := to.normalized() * 0.4 if to.length() <= CLOSE_M else to.normalized()
		_stick(e, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, walk)
		_stick(e, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, to.normalized())
		if trigger:
			e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
			trigger = false
		elif r.swing_tick() == 0 and to.length() < CLOSE_M + 0.6:
			e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
			trigger = true
		await e.frames(1)
		var j := w.actors.index_of(id)
		if j >= 0 and CoreTheft.window_open(w, j):
			saw_ring = saw_ring or main.view.cores.ring_count() == 1
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_stick(e, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, Vector2.ZERO)
	_stick(e, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, Vector2.ZERO)
	await e.frames(3)
	assert_eq(w.actors.index_of(id), -1, "the elite fell to the swings")
	assert_true(saw_ring, "the steal ring showed while its window was open")
	gut.p("stolen at tick %d" % w.cores.steal_tick)
	assert_true(w.cores.steal_tick >= 0, "killed inside the window: the core was stolen")
	var drop := -1
	for q in w.rewards.size():
		if CoreTheft.drop_kind(w, w.rewards.ids[q]) == CoreState.Drop.CORE:
			drop = q
	assert_gte(drop, 0, "the core lies on the floor")
	if drop < 0:
		return
	assert_eq(w.rewards.offer_of(drop), PackedInt32Array([card]), "holding the elite's card")
	assert_true(await e.walk_to(w.rewards.pos(drop), 0.5), "walked to the core")
	await e.frames(2)
	assert_eq(hud.prompt_text(), tr("REWARD_OPEN_DROP"), "the prompt offers the card")
	await e.tap(KEY_E)
	await e.frames(3)
	assert_gte(w.choosing, 0, "E opened it")
	var pick := hud.pick_panel()
	assert_eq(pick.card_count(), 1, "one card: the core")
	assert_eq(pick.title_text(), tr("PICK_TITLE_CORE"))
	var values := w.stat_values.duplicate()
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_eq(w.choosing, -1, "Enter took it")
	if Offers.type_of(card) == Offers.MOD:
		assert_true(w.items_owned.has(card), "the stolen mod is yours")
	else:
		assert_ne(w.stat_values, values, "the stolen stat card is yours")
