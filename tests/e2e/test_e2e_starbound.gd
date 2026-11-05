extends GutTest
## v0.10.5 W3-P10b (owner W7): a Starbound card through main.tscn with real input only. The run is put into loop 2 by a
## labelled TEST HELPER (the run's loop number, as test_e2e_ascension sets the floor number; walking a whole loop is
## test_e2e_ascension's job) and the F10 panel's Restart floor (a key press) rebuilds the floor from it. A regular altar
## whose offer holds a Starbound card is found by reading the sim (Starbound.offer_card, pure: the altar's own named
## stream; a later floor of loop 2 when this one has none, the same helper); the dev panel's God mode stands in for
## the fight on the walk; the left stick walks there, E opens it, the pick shows the card on the gold Starbound frame
## with its name, the arrows focus it and Enter takes it: one stack, saved in the build; the dealt card at loop 1 is
## never one (test_starbound covers the rates).

const FLOORS_TRIED := 3


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


## F10 -> Restart floor (Enter on the focused button, as test_e2e_ascension): the run's current floor rebuilt.
func _restart_floor(e: E2e, main: Main) -> void:
	await e.tap(KEY_F10)
	var panel := main.get_node_or_null("UI/DevMasterPanel") as DevMasterPanel
	assert_not_null(panel, "F10 opens the panel")
	var restart: Button = null
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.text == "UI_DEVM_RESTART":
			restart = b
	restart.grab_focus()
	await e.tap(KEY_ENTER)
	await e.frames(4)
	await e.landed()


## The nearest open regular altar on this floor whose offer gets a Starbound card (-1: none).
func _starbound_altar(w: World) -> int:
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] != RewardStore.Kind.ALTAR or Arenas.locked(w, i):
			continue
		if Routes.is_epic_altar(w, i) or TimedDoor.is_epic(w, i) or BossReward.is_legendary(w, i):
			continue
		if Starbound.offer_card(w, i) < 0:
			continue
		var d := w.rewards.pos(i).distance_to(w.player_pos())
		if best < 0 or d < w.rewards.pos(best).distance_to(w.player_pos()):
			best = i
	return best


func test_a_starbound_card_is_offered_in_loop_two_and_taken_with_the_keys() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	assert_eq(w.loop, 1)
	assert_eq(Starbound.offer_permille(w), 0, "loop 1: no Starbound card is ever offered")
	var altar := -1
	for f in FLOORS_TRIED:
		main.run.loop = 2  # TEST HELPER (labelled): the run is in loop 2
		main.run.floor_index = f + 1  # TEST HELPER (labelled): this loop's floor
		await _restart_floor(e, main)
		w = e.world()
		assert_eq(w.loop, 2, "the floor is built in loop 2")
		altar = _starbound_altar(w)
		if altar >= 0:
			break
	assert_gte(altar, 0, "an altar of loop 2 offers a Starbound card")
	if altar < 0:
		return
	var card := Starbound.offer_card(w, altar)
	var altar_id := w.rewards.ids[altar]
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")  # the walk is about the card, not survival
	await e.tap(KEY_QUOTELEFT)
	assert_true(await e.walk_to(w.rewards.pos(altar), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	var panel := hud.pick_panel()
	assert_true(panel.is_open(), "E opened the altar")
	var offer := w.rewards.offer_of(w.rewards.index_of(altar_id))
	var code := Offers.starbound_code(card)
	var k := offer.find(code)
	assert_gte(k, 0, "the offer holds the Starbound card offer_card named")
	if k < 0:
		return
	await e.frames(90)  # the deal
	var slot := panel.slot(k)
	assert_eq(slot.face_type(), WorldReader.CARD_STARBOUND, "a Starbound card")
	assert_eq(
		slot.card.frame_texture().resource_path,
		"res://assets/ui/card_frames/frame_starbound.png",
		"on the owner's gold Starbound frame"
	)
	assert_eq(slot.card.title_text(), tr(w.starbound_tables[card].name_key), "its name")
	assert_eq(slot.card.tier_text(), tr("STARBOUND_KIND"), "the Starbound kind line")
	for n in k:
		await e.tap(KEY_RIGHT)
	assert_eq(panel.focus_index(), k)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_eq(Starbound.picks(w, card), 1, "taken: one stack")
	assert_false(main.driver.reader.choosing(), "the pick closed")
	assert_eq(main.driver.reader.starbound()["cards"][card]["picks"], 1, "the build reads it")
