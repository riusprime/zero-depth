extends GutTest
## v0.5.0 EV views: the pedestals (glow and state change no shader; the name floats when near), the drone's ring
## and the elite crowns; the event panel's cards for all eight events (cost, reward, curse mark, refusals, Leave)
## in the pick cards' look; the cursed chest card's mark; the threat panel; the recap line; and every event and
## curse string in en and es with matching placeholders.

const EVENTS: Array[StringName] = [
	&"ambush_cache",
	&"blood_price",
	&"cleansing_font",
	&"echo_mirror",
	&"overclock_vent",
	&"scrap_heap",
	&"unstable_core",
	&"wandering_drone",
]


func test_pedestals_glow_and_go_dark_without_changing_a_shader() -> void:
	var w := EventLab.world(3)
	var reader := WorldReader.new(w)
	var view := EventPedestalViews.new()
	add_child_autofree(view)
	view.setup(reader)
	view.sync(reader)
	assert_eq(view.pedestal_count(), w.ev.size())
	var before := DamageFlashKeys.of(view)
	assert_gt(before.size(), 4, "the pedestal has its pieces")
	assert_false(view.name_label(0).visible, "far: no name")
	w.actors.set_pos(0, w.ev.pos(0))
	view.sync(reader)
	assert_true(view.name_label(0).visible, "near: its name floats")
	assert_eq(view.name_label(0).text, tr(Events.table(w, 0).name_key))
	view._process(0.1)
	var lit := view.glyph_energy(0)
	EventLab.set_event(w, &"scrap_heap")
	w.shards = 999
	EventLab.open(w)
	EventLab.pick(w, 1)
	view.sync(reader)
	view._process(0.1)
	assert_lt(view.glyph_energy(0), lit * 0.2, "spent: it goes dark")
	assert_false(view.name_label(0).visible, "and its name with it")
	assert_eq(DamageFlashKeys.of(view), before, "no shader changed")


func test_the_drone_ring_and_elite_crowns_follow_the_sim() -> void:
	var w := EventLab.world(3)
	var reader := WorldReader.new(w)
	var view := EventPedestalViews.new()
	add_child_autofree(view)
	view.setup(reader)
	EventLab.set_event(w, &"wandering_drone")
	EventLab.open(w)
	EventLab.pick(w, 1)
	view.sync(reader)
	assert_true(view.ring_visible(), "the ring shows while you defend")
	var v := EventLab.world(3)
	var rv := WorldReader.new(v)
	var crowns := EventPedestalViews.new()
	add_child_autofree(crowns)
	crowns.setup(rv)
	EventLab.set_event(v, &"ambush_cache")
	EventLab.open(v)
	EventLab.pick(v, 1)
	crowns.sync(rv)
	assert_eq(crowns.crown_count(), 3, "a crown under each elite")
	assert_false(crowns.ring_visible())


func test_the_panel_shows_every_event_with_costs_rewards_curses_and_leave() -> void:
	for id in EVENTS:
		var w := EventLab.world(4242, 1, &"blade", [&"withering"])
		Stats.add_card(w, Stats.Stat.DAMAGE, 0)  # test setup: a raised stat for Echo Mirror
		EventLab.set_event(w, id)
		EventLab.open(w)
		var reader := WorldReader.new(w)
		var panel := EventPanel.new()
		add_child_autofree(panel)
		panel.sync(reader)
		var n := Events.table(w, 0).choice_count()
		assert_true(panel.is_open(), "%s opens" % id)
		assert_eq(panel.card_count(), n + 1, "%s: choices and Leave" % id)
		assert_eq(panel.card_text(n, "Title"), tr("UI_EVENT_LEAVE"))
		for c in n:
			assert_false(panel.card_text(c, "Title").is_empty(), "%s %d title" % [id, c])
			assert_false(panel.card_text(c, "Cost").is_empty(), "%s %d cost" % [id, c])
			assert_false(panel.card_text(c, "Reward").is_empty(), "%s %d reward" % [id, c])
			var cursed := reader.event_choice_curse(0, c) >= 0
			assert_eq(
				not panel.card_text(c, "Curse").is_empty(), cursed, "%s %d curse mark" % [id, c]
			)
			var ok := reader.event_choice_block(0, c) == WorldReader.EVENT_BLOCK_OK
			assert_eq(panel.card_enabled(c), ok)
			assert_eq(
				panel.card_text(c, "Block").is_empty(), ok, "%s %d says why it's refused" % [id, c]
			)
			assert_true(panel.card_fits(c), "%s %d fits its plaque (v0.6.1 R1)" % [id, c])
		gut.p("%s: %s / %s" % [id, panel.card_text(0, "Cost"), panel.card_text(0, "Reward")])


func test_a_cursed_chest_card_is_marked_and_the_others_are_clean() -> void:
	var w := EventLab.world(4242)
	var chest := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
	w.ev.force_curse = true
	w.shards = 999
	w.actors.set_pos(0, w.rewards.pos(chest))
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)
	var reader := WorldReader.new(w)
	var panel := PickPanel.new()
	add_child_autofree(panel)
	panel.sync(reader)
	var curse := reader.choice_curse(0)
	assert_gte(curse, 0)
	# v0.6.0 CU: the card is the trade-off curse (its face the upside); the line under it is the drawback
	assert_eq(panel.slot(0).curse_text(), CurseLook.down_line(panel, reader, curse))
	assert_eq(panel.slot(0).card.desc_text(), CurseLook.up_sentence(panel, reader, curse))
	for k in range(1, panel.card_count()):
		assert_eq(panel.slot(k).curse_text(), "", "card %d is clean" % k)


func test_the_threat_panel_lists_curses_and_the_recap_counts_t() -> void:
	var w := EventLab.world(5, 1, &"blade", [&"swift_foes", &"price_gouge"])
	var reader := WorldReader.new(w)
	var panel := ThreatPanel.new()
	add_child_autofree(panel)
	panel.sync(reader)
	assert_eq(panel.title_text(), tr("UI_THREAT") % 2)
	assert_eq(panel.row_count(), 2)
	Curses.add(w, EventLab.curse_index(w, &"withering"))
	panel.sync(reader)
	assert_eq(panel.row_count(), 3)
	assert_true(panel.note_text().begins_with(tr("UI_CURSE_GAINED")), "a new curse flashes a note")
	var end := EndPanel.new(false, 0, &"", {"floor": 1, "threat": 3, "threat_peak": 3})
	add_child_autofree(end)
	assert_eq(end.recap_line("Threat"), tr("UI_RECAP_THREAT") % [3, 3])


func test_every_event_and_curse_string_is_in_both_languages() -> void:
	var rows := ReadableCause.locale_rows()
	var keys: Array[String] = []
	var repo := EventLab.repo()
	for d: EventDefinition in repo.all_of(&"events"):
		keys.append_array([String(d.name_key), String(d.desc_key)])
		for c in d.choices:
			keys.append(String(c.label_key))
	for d: CurseDefinition in repo.all_of(&"curses"):
		keys.append_array([String(d.name_key), String(d.desc_key)])
		if d.is_trade_off():
			keys.append(String(d.up_desc_key))  # v0.6.0 CU: the upside's sentence
	# v0.5.5 DS: Whispering Deep and its two choices; v0.6.0 CU: 13 curses, 8 of them with an upside
	assert_eq(keys.size(), 9 * 2 + 14 + 13 * 2 + 8)
	for k in keys:
		assert_true(rows.has(k), "%s is in strings.csv" % k)
		if rows.has(k):
			var en := String(rows[k][0])
			var es := String(rows[k][1])
			assert_false(en.is_empty() or es.is_empty(), "%s en and es" % k)
			assert_eq(en.count("%s"), es.count("%s"), "%s: same placeholders" % k)
