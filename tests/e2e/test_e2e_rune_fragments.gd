extends GutTest
## v0.9.0 MP (PLAN W49-W52, Q28; owner "void unlocked when traveling through a purple portal, lance is unlocked by
## default"; RB: Night, Canyon, Frost and Moss bought with Rune Fragments) through main.tscn with real input only:
## 1. A floor-2 save that earned fragments on floor 1 is continued from the menu (Enter); standing still, the hero
##    dies; the run summary shows the fragments banked and the balance; Down + Enter goes to the hub; the Progression
##    Station (E) lists the robes with their prices; Enter buys Night; Esc; the Wardrobe (E) offers Night, Right x2
##    wears it.
## 2. Seed 1's floor-2 save on a profile that never travelled (the Void locked in the run) is continued: the stick
##    walks to the purple dais, E awakens it, the dev panel's Kill boss stands in for the fight, the stick walks into
##    the Purple Portal: the profile records it, a toast says the Void is unlocked, and floor 3 offers the Void.

const LEG_FRAMES := 7000
const PURPLE_SEED := 1
const EARNED := 4


func after_each() -> void:
	E2e.center_sticks()
	TranslationServer.set_locale("en")


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## A floor-2 save of run `run_seed` (built as Main builds floors), its run holding `fragments` and `locked`.
func _save(
	run_seed: int, fragments: int, locked: Array[StringName], build: StringName = &"blade"
) -> RunSaveStore:
	var run := SaveLab.run_state(run_seed, 2, build)
	run.fragments_done = fragments
	run.locked_cards = locked
	var saved := SaveLab.build_floor(run)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, run_seed, PackedByteArray())))
	return store


func _continue(e: E2e, main: Main) -> void:
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	await e.landed()


func _wait_for_end(e: E2e, main: Main) -> EndPanel:
	for k in 4000:
		await e.frames(1)
		var p := main.get_node_or_null("UI/EndPanel")
		if p != null:
			return p
	return null


func test_a_run_banks_fragments_and_the_station_sells_a_robe() -> void:
	var repo := ContentRepository.load_all()
	var night: RobeDefinition = repo.get_def(&"robe", &"night")
	var profile := ProfileStore.new("")
	MetaProgress.bank(profile, night.price - EARNED + 1)  # earlier runs' fragments
	MetaProgress.travel_portal(profile)
	var before := MetaProgress.fragments(profile)
	var e := E2e.new(self)
	var none: Array[StringName] = []
	var main: Main = await e.boot(profile, _save(4242, EARNED, none))
	await _continue(e, main)
	assert_eq(main.run.floor_index, 2, "floor 2 continues")
	assert_eq(main.run.fragments_done, EARNED, "with floor 1's fragments")
	var panel := await _wait_for_end(e, main)
	assert_not_null(panel, "standing still, you die")
	if panel == null:
		return
	var earned := int(panel.recap["fragments"])
	assert_gte(earned, EARNED, "the run's fragments")
	assert_eq(MetaProgress.fragments(profile), before + earned, "banked into the profile")
	assert_eq(
		panel.recap_line("Fragments"),
		tr("UI_RECAP_FRAGMENTS") % [earned, before + earned],
		"the summary shows them and the balance"
	)
	await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Hub")
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_not_null(main.hub, "the hub")
	var walk := HubWalk.new(e)
	await walk.use(&"progression")
	var station := main.get_node_or_null("UI/ProgressionPanel") as ProgressionPanel
	assert_not_null(station, "E at the Progression Station opens its panel")
	if station == null:
		return
	assert_true(main.hub.driver.paused, "the hub holds under it")
	assert_eq(station.rows.size(), 4, "the four robes, nothing else")
	assert_eq(station.balance.text, tr("PROGRESSION_BALANCE") % (before + earned))
	assert_eq(_focused(main), station.rows[0], "Night has focus")
	assert_true(station.rows[0].text.ends_with(tr("PROGRESSION_PRICE") % night.price), "its price")
	await e.tap(KEY_ENTER)
	assert_true(Wardrobe.robe_unlocked(profile, night), "Enter bought Night")
	assert_eq(MetaProgress.fragments(profile), before + earned - night.price, "the price spent")
	assert_true(station.rows[0].text.ends_with(tr("PROGRESSION_OWNED")), "owned")
	assert_eq(station.status.text, tr("PROGRESSION_BOUGHT") % tr("ROBE_NIGHT"))
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)  # Canyon: too dear now
	assert_false(
		Wardrobe.robe_unlocked(profile, repo.get_def(&"robe", &"canyon")), "not enough left"
	)
	assert_eq(station.status.text, tr("PROGRESSION_SHORT") % tr("ROBE_CANYON"))
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/ProgressionPanel"), "Esc closes it")
	await walk.use(&"wardrobe")
	var wardrobe := main.get_node_or_null("UI/WardrobePanel") as WardrobePanel
	assert_not_null(wardrobe)
	if wardrobe == null:
		return
	await e.tap(KEY_RIGHT)
	await e.tap(KEY_RIGHT)
	assert_eq(wardrobe.robe_cycler.value(), "night", "Right x2: Night")
	assert_false(wardrobe.lock_note.visible, "no longer locked")
	assert_eq(wardrobe.worn_robe, &"night", "worn")
	assert_eq(main.hub.view.avatar.cloak_color, night.cloak, "the hub's hero wears it")
	assert_eq(get_errors().size(), 0, "no engine or script error")


## Walks the left stick along the flow field toward `target` until `done` is true (or the frame limit).
func _walk(e: E2e, target: Vector2, done: Callable, push: Vector2 = Vector2.ZERO) -> bool:
	var w := e.world()
	var nav := NavField.new()
	nav.build(E2e.walk_walls(w, target))
	nav.flood(target)
	for k in LEG_FRAMES:
		if done.call():
			break
		var p := w.player_pos()
		var dir := nav.direction(p)
		if (target - p).length() < 1.5 or dir == Vector2.ZERO:
			dir = (target - p).normalized() if (target - p).length() > 0.2 else push
		e.stick_toward(dir)
		await e.frames(1)
		if w.player_dead():
			break
	return done.call()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


func test_the_purple_portal_unlocks_the_void() -> void:
	var profile := ProfileStore.new("")
	assert_false(MetaProgress.portal_travelled(profile), "never travelled")
	var locked := MetaProgress.locked_cards(ContentRepository.load_all(), profile)
	var e := E2e.new(self)
	var main: Main = await e.boot(profile, _save(PURPLE_SEED, EARNED, locked), PURPLE_SEED)
	await _continue(e, main)
	var w := e.world()
	var f := w.floor_layout
	assert_eq(
		main.run.locked_cards, [&"gun_void"] as Array[StringName], "the run keeps the Void locked"
	)
	assert_eq(w.locked_items.size(), 1, "out of floor 2's offers")
	assert_not_null(w.purple, "floor 2 holds the purple runes")
	if w.purple == null:
		return
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	assert_true(await e.walk_to(f.purple_pos, 1.0), "walked to the dais")
	await e.frames(2)
	await e.tap(KEY_E)
	await e.frames(2)
	assert_true(PurpleRunes.earned(w), "E awakened the runes")
	assert_true(await e.open_boss_door(), "E opened the boss door")
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	e.stick_toward(Vector2.ZERO)
	assert_true(sealed, "walked through the boss door")
	if not sealed:
		return
	await e.frames(30)
	await _click(e, main, "KillBoss")
	await e.frames(BossFlow.PORTAL_FORM_TICKS + 8)
	assert_true(main.driver.reader.gate_open(WorldReader.ROUTE_DEEP), "the Purple Portal is open")
	var facing := Kin.dir(f.deep_portal_angle)
	var entered: bool = await _walk(
		e,
		f.deep_portal_pos + facing * 1.0,
		func() -> bool: return w.boss_flow.state == BossFlow.State.ENTERING,
		-facing
	)
	e.stick_toward(Vector2.ZERO)
	assert_true(entered, "the Purple Portal takes the hero")
	var held := 0
	while main.run.floor_index < 3 and held < 300:
		held += 1
		await e.frames(1)
	assert_eq(main.run.floor_index, 3, "floor 3 started")
	assert_true(main.run.is_deep(), "through the Purple Portal")
	assert_true(MetaProgress.portal_travelled(profile), "the profile records the Purple Portal")
	assert_eq(main.run.locked_cards.size(), 0, "the run's lock is gone")
	await e.landed()
	assert_eq(e.world().locked_items.size(), 0, "floor 3 offers the Void")
	var toast := main.toast
	assert_true(
		toast.current_id() == &"unlock_void" or toast.queued_ids().has(&"unlock_void"),
		"a toast says the Void is unlocked"
	)
	var t := main.run.fragment_table
	assert_gte(
		main.run.fragments_done,
		EARNED + t.secret + t.boss + t.floor_cleared + t.purple_portal,
		"floor 2's boss, its secret, the floor and the Purple Portal earned fragments"
	)
	gut.p("MP_E2E| fragments=%d" % main.run.fragments_done)
	assert_eq(get_errors().size(), 0, "no engine or script error")
