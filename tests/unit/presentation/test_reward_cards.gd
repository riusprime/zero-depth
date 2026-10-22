extends GutTest
## v0.8.0 N8 (owner O62, D48): the reward cards that deal, flip and react. The deal's order (Epic and Legendary last,
## the wait before them), a press during the deal skipping to the end and still counting, the gain line's numbers
## being the sim's forecast (and the outcome), the count-up from the old value, the rarity painting (every tier its
## colour, its word, the text's contrast), the Legendary shine, the hover tilt, and on a pick the burn and the flight
## to the HUD (a chest's one card flies, nothing burns). Reduced motion: no deal, no tilt, a still shine.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func after_each() -> void:
	HudStyle.reduced_motion = false


func _world(build: StringName = &"gun") -> World:
	return CardPoolSurvey.world(_repo, 4242, build, [])


func _open(w: World) -> void:
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT))


func _step(w: World, pick: int = InputFrame.PICK_NONE) -> void:
	var f := InputFrame.new()
	f.pick = pick
	w.step(f)


func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	return ev


## An altar holding `cards` (forced: the draw is the sim's test), opened, and a panel synced to it.
func _altar(w: World, cards: PackedInt32Array) -> PickPanel:
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	w.rewards.set_offer(w.rewards.size() - 1, cards)
	_open(w)
	var p := PickPanel.new()
	add_child_autofree(p)
	p.sync(WorldReader.new(w))
	return p


func _stat(w: World, id: StringName, rarity: int) -> int:
	for s in w.stat_tables.size():
		if w.stat_tables[s] != null and w.stat_tables[s].id == id:
			return Offers.stat_code(s, rarity)
	return -1


func _item(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


func _run(p: Node, seconds: float) -> void:
	for k in int(seconds * 60.0):
		p._process(1.0 / 60.0)


func test_the_deal_order_puts_epic_and_legendary_last() -> void:
	assert_eq(
		CardDeal.order([0, 2, 1]), PackedInt32Array([0, 2, 1]), "the epic card (slot 2) flips last"
	)
	assert_eq(
		CardDeal.order([4, 0, 2]),
		PackedInt32Array([1, 0, 2]),
		"legendary and epic after the common"
	)
	assert_eq(CardDeal.order([0, 1, 3]), PackedInt32Array([0, 1, 2]), "no high card: slot order")
	var d := CardDeal.new()
	d.start([2, 0, 1])
	assert_false(d.done())
	assert_eq(d.arrive(0), 0.0, "every card starts below the screen")
	assert_false(d.face_up(0), "face down")
	var t := 0.0
	var flipped := []
	var dark_before_high := 0.0
	var glow_waiting := 0.0
	while not d.done() and t < 10.0:
		d.advance(1.0 / 60.0)
		t += 1.0 / 60.0
		for k in 3:
			if d.face_up(k) and not flipped.has(k):
				flipped.append(k)
		if not d.face_up(0):
			dark_before_high = maxf(dark_before_high, d.dark())
			glow_waiting = maxf(glow_waiting, d.back_glow(0))
		assert_lte(d.width(0), 1.0)
	assert_true(d.done(), "the deal ends (%.2f s)" % t)
	assert_eq(flipped, [1, 2, 0], "one by one, the epic card last")
	assert_gt(dark_before_high, 0.5, "the background darkens before the epic card flips")
	assert_gt(glow_waiting, 0.5, "its back glows while it waits")
	assert_eq(d.back_glow(1), 0.0, "a common card's back never glows")


func test_a_flip_shrinks_the_width_to_zero_and_swaps_the_face_halfway() -> void:
	var d := CardDeal.new()
	d.start([0])
	var min_w := 1.0
	var swapped_at := -1.0
	var w_at_swap := 1.0
	while not d.done():
		var was := d.face_up(0)
		d.advance(1.0 / 240.0)
		min_w = minf(min_w, d.width(0))
		if d.face_up(0) and not was:
			swapped_at = d.flip(0)
			w_at_swap = d.width(0)
	assert_lt(min_w, 0.05, "the width goes to 0")
	assert_between(swapped_at, 0.5, 0.52, "the face swaps halfway")
	assert_lt(w_at_swap, 0.06, "while the card is edge on")


func test_a_high_card_punches_flashes_and_raises_rays() -> void:
	var d := CardDeal.new()
	d.start([0, 4])
	var punch := 0.0
	var flash := 0.0
	var rays := 0.0
	while not d.done():
		d.advance(1.0 / 60.0)
		punch = maxf(punch, d.punch(1))
		flash = maxf(flash, d.flash(1))
		rays = maxf(rays, d.rays(1))
		assert_eq(d.punch(0), 0.0, "the common card doesn't punch")
	assert_gt(punch, 0.1, "a punch")
	assert_gt(flash, 0.8, "a flash")
	assert_gt(rays, 0.9, "rays behind it")
	assert_gt(d.rays(1), 0.3, "the rays stay behind it while it shows")


func test_a_pick_press_during_the_deal_skips_to_the_end_and_still_counts() -> void:
	var w := _world()
	var p := _altar(
		w,
		PackedInt32Array([_item(w, &"gun_pierce"), _item(w, &"gun_twin"), _item(w, &"gun_spread")])
	)
	var got := []
	p.picked.connect(func(v: int) -> void: got.append(v))
	_run(p, 0.1)
	assert_false(p.deal.done(), "still dealing")
	assert_false(p.slot(0).card.fx.face.visible, "face down")
	p._input(_key(KEY_ENTER))
	assert_true(p.deal.done(), "the press ended the deal")
	assert_eq(got, [1], "and it counted: the first card, at once")
	for k in 3:
		assert_true(p.slot(k).card.fx.face.visible, "card %d face up" % k)
		assert_almost_eq(
			p.slot(k).card.fx.offset.y,
			p.deal.fan(k).y * p.slot(k).card.scale_factor,
			0.01,
			"in place"
		)
	var q := _altar(_world(), PackedInt32Array([_item(w, &"gun_pierce"), _item(w, &"gun_spread")]))
	q._input(_key(KEY_2))
	assert_true(q.deal.done(), "a focus key skips the deal too")
	assert_eq(q.focus_index(), 1)


func test_the_epic_card_waits_in_the_panel_with_its_back_glowing() -> void:
	var w := _world()
	var twin := _item(w, &"gun_twin")  # Epic
	assert_eq(w.item_tables[twin].tier(), ItemTable.TIER_EPIC)
	var p := _altar(w, PackedInt32Array([twin, _item(w, &"gun_pierce"), _item(w, &"gun_spread")]))
	assert_true(p.deal.is_high(0))
	var dimmest := 0.0
	var glow := 0.0
	while not p.deal.done():
		p._process(1.0 / 60.0)
		if not p.slot(0).card.fx.face.visible:
			glow = maxf(glow, p.slot(0).card.fx.back.glow)
			dimmest = maxf(dimmest, p._dim.color.a)
	assert_gt(glow, 0.5, "its back glows")
	assert_gt(dimmest, PickPanel.DIM + 0.15, "the background darkens")
	assert_true(p.slot(0).card.fx.face.visible, "then it flips")


func test_the_gain_line_is_the_forecast_and_the_outcome() -> void:
	var w := _world()
	var dmg := _stat(w, &"damage", Stats.Rarity.RARE)
	var hp := _stat(w, &"max_hp", Stats.Rarity.EPIC)
	var pierce := _item(w, &"gun_pierce")
	w.add_item(pierce)  # held at level 1: a level-up
	var r := WorldReader.new(w)
	var f_dmg := r.card_forecast(dmg)
	var f_hp := r.card_forecast(hp)
	var f_lv := r.card_forecast(pierce)
	assert_eq(
		[
			WorldReader.GAIN_NONE,
			WorldReader.GAIN_LEVEL,
			WorldReader.GAIN_PERMILLE,
			WorldReader.GAIN_HP
		],
		[
			CardForecast.KIND_NONE,
			CardForecast.KIND_LEVEL,
			CardForecast.KIND_PERMILLE,
			CardForecast.KIND_HP
		],
		"the reader's kinds are the forecast's"
	)
	assert_eq(int(f_dmg["kind"]), CardForecast.KIND_PERMILLE)
	assert_eq(int(f_dmg["old"]), 1000)
	assert_eq(int(f_hp["kind"]), CardForecast.KIND_HP)
	assert_eq(int(f_hp["old"]), Stats.max_hp(w))
	assert_eq([int(f_lv["old"]), int(f_lv["new"])], [1, 2], "a held wand card: level 1 → 2")
	var p := _altar(w, PackedInt32Array([dmg, hp, pierce]))
	assert_eq(p.slot(0).card.gain_text(), CardGain.final_text(p, f_dmg))
	assert_eq(p.slot(1).card.gain_text(), tr("UI_GAIN_HP") % [f_hp["old"], f_hp["new"]])
	assert_eq(p.slot(2).card.gain_text(), tr("UI_GAIN_LEVEL") % [1, 2])
	# The outcome: what the take gives is what the card said.
	Offers.apply(w, dmg)
	assert_eq(Stats.total(w, Offers.stat_of(dmg)), int(f_dmg["new"]), "damage as forecast")
	Offers.apply(w, hp)
	assert_eq(Stats.max_hp(w), int(f_hp["new"]), "max HP as forecast")
	Offers.apply(w, pierce)
	assert_eq(CardLevels.level(w, pierce), int(f_lv["new"]), "the level as forecast")


func test_numbers_count_up_from_the_old_value_on_focus() -> void:
	var w := _world()
	var dmg := _stat(w, &"damage", Stats.Rarity.EPIC)
	var spread := _item(w, &"gun_spread")
	var p := _altar(w, PackedInt32Array([spread, dmg]))
	p.skip_deal()
	var f := WorldReader.new(w).card_forecast(dmg)
	var card := p.slot(1).card
	assert_eq(card.gain_value(), int(f["new"]), "at rest the card shows the new value")
	p._set_focus(1)
	assert_eq(card.gain_value(), int(f["old"]), "focused: it starts from the old value")
	var seen := [card.gain_value()]
	for k in 40:
		card._process(1.0 / 60.0)
		seen.append(card.gain_value())
	for k in range(1, seen.size()):
		assert_gte(seen[k], seen[k - 1], "it only counts up")
	assert_eq(card.gain_value(), int(f["new"]), "and lands on the forecast")
	assert_eq(card.gain_text(), CardGain.final_text(p, f))
	assert_eq(CardGain.value_at(f, 0.0), int(f["old"]))
	assert_eq(CardGain.value_at(f, 1.0), int(f["new"]))


func test_every_tier_paints_the_whole_card_and_writes_its_word() -> void:
	var seen := {}
	for tier in PickSlot.TIERS.size():
		var c: Color = PickSlot.TIERS[tier]
		var card := StoneCard.new(PickSlot.PICK_SCALE)
		add_child_autofree(card)
		card.show_face(&"gun_spread", "Spread", "x", &"projectile", tier, c, "Word %d" % tier)
		var box := card.panel_box()
		assert_eq(box.fill, CardPaint.face(c), "tier %d: the face is its colour's stone" % tier)
		assert_eq(box.edge, c, "tier %d: its frame" % tier)
		assert_eq(box.glow_color, c, "tier %d: its glow" % tier)
		assert_eq(card.fx.back.box().fill, CardPaint.face(c), "tier %d: and its back" % tier)
		assert_eq(card.tier_text(), "Word %d" % tier, "the word is on the card")
		var ratio := CardPaint.contrast(StoneCard.TEXT, CardPaint.face_peak(c))
		assert_gte(
			ratio, CardPaint.MIN_CONTRAST, "tier %d: the text reads (%.1f:1)" % [tier, ratio]
		)
		seen[box.fill.to_html()] = true
	assert_eq(seen.size(), PickSlot.TIERS.size(), "every tier its own colour")
	for key: String in PickPanel.RARITY_KEYS:
		assert_ne(tr(key), key, "%s is translated" % key)


func test_a_legendary_card_keeps_its_shine_and_a_rare_one_does_not() -> void:
	var leg := StoneCard.new()
	add_child_autofree(leg)
	leg.show_face(
		&"chain_blast",
		"Chain Blast",
		"x",
		&"fire",
		CardFrames.LEGENDARY_TIER,
		PickSlot.LEGENDARY,
		"L"
	)
	assert_true(leg.fx.shining(), "the holographic shine")
	assert_true(leg.fx.shine_moves(), "it loops")
	var rare := StoneCard.new()
	add_child_autofree(rare)
	rare.show_face(&"halo_shot", "Halo", "x", &"projectile", 1, PickSlot.RARE, "R")
	assert_false(rare.fx.shining())
	HudStyle.reduced_motion = true
	var still := StoneCard.new()
	add_child_autofree(still)
	still.show_face(
		&"chain_blast",
		"Chain Blast",
		"x",
		&"fire",
		CardFrames.LEGENDARY_TIER,
		PickSlot.LEGENDARY,
		"L"
	)
	assert_true(still.fx.shining(), "reduced motion: the gloss stays")
	assert_false(still.fx.shine_moves(), "but it holds still")


func test_hover_tilts_toward_the_cursor_and_sinks() -> void:
	var w := _world()
	var p := _altar(w, PackedInt32Array([_item(w, &"gun_pierce"), _item(w, &"gun_spread")]))
	p.skip_deal()
	p._process(1.0 / 60.0)
	var fx := p.slot(0).card.fx
	assert_eq(fx.tilt, PickPanel.FOCUS_TILT, "focused by key: a fixed tilt")
	assert_eq(fx.sink, 1.0, "and it sinks")
	assert_gt(p.slot(0).card.lift(), 0.0, "it moves, so focus reads by shape")
	assert_eq(p.slot(1).card.fx.tilt, Vector2.ZERO, "the other card rests")
	assert_eq(p.slot(1).card.fx.sink, 0.0)
	HudStyle.reduced_motion = true
	p._process(1.0 / 60.0)
	assert_eq(fx.tilt, Vector2.ZERO, "reduced motion: no tilt")


func test_reduced_motion_deals_nothing_and_shows_the_faces() -> void:
	HudStyle.reduced_motion = true
	var w := _world()
	var p := _altar(w, PackedInt32Array([_item(w, &"gun_twin"), _item(w, &"gun_spread")]))
	assert_true(p.deal.done(), "no deal")
	for k in 2:
		assert_true(p.slot(k).card.fx.face.visible, "card %d face up" % k)
		assert_eq(p.slot(k).card.fx.width, 1.0)
	assert_eq(p.slot(0).card.tier_text().contains(tr("RARITY_EPIC")), true, "the tier's word kept")


func test_a_pick_burns_the_others_and_flies_the_icon_to_its_hud_slot() -> void:
	var w := _world()
	var hud := Hud.new()
	add_child_autofree(hud)
	var r := WorldReader.new(w)
	var spread := _item(w, &"gun_spread")
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	w.rewards.set_offer(
		0, PackedInt32Array([_item(w, &"gun_pierce"), spread, _stat(w, &"damage", 0)])
	)
	_open(w)
	hud.sync(r)
	var p := hud.pick_panel()
	assert_true(p.is_open())
	p.skip_deal()
	p._input(_key(KEY_2))
	p._input(_key(KEY_ENTER))
	_step(w, 2)  # the latch's pick reaches the sim
	assert_eq(w.choosing, -1, "the sim took it")
	hud.sync(r)
	assert_true(p.outro_playing(), "the outro plays")
	assert_eq(p.picked_slot(), 1)
	await get_tree().process_frame  # the flight launches once the HUD's slots synced
	assert_eq(hud.flights.flying(), 1, "the picked card's icon flies")
	var fly := hud.flights.get_child(0) as CardFly
	var slot := Array(w.mod_slots).find(spread)
	assert_gte(slot, 0, "Spread is in the wand")
	assert_eq(fly.to, hud.build_hud.pip_rect(slot), "to its wand pip")
	assert_eq(fly.id, &"gun_spread")
	_run(p, 0.3)
	assert_true(p.slot(0).card.fx.burning(), "a card not picked burns")
	assert_true(p.slot(2).card.fx.burning())
	assert_false(p.slot(1).card.fx.burning(), "the picked one doesn't")
	assert_gt(p.slot(0).card.fx.burn, 0.2)
	_run(p, 1.0)
	assert_false(p.outro_playing(), "the outro ends")
	assert_false(p.visible)
	for k in 3:
		assert_false(p.slot(k).card.fx.burning(), "the cards are whole for the next deal")


func test_a_cancel_neither_burns_nor_flies() -> void:
	var w := _world()
	var hud := Hud.new()
	add_child_autofree(hud)
	var r := WorldReader.new(w)
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	_open(w)
	hud.sync(r)
	hud.pick_panel()._input(_key(KEY_ESCAPE))
	_step(w, InputFrame.PICK_CANCEL)
	hud.sync(r)
	assert_false(hud.pick_panel().outro_playing())
	await get_tree().process_frame
	assert_eq(hud.flights.flying(), 0)


func test_a_chest_deals_one_card_that_flies_when_closed() -> void:
	var w := _world()
	var hud := Hud.new()
	add_child_autofree(hud)
	var r := WorldReader.new(w)
	w.add_reward(RewardStore.Kind.CHEST, Vector2(1, 0), 40)
	w.shards = 40
	_open(w)
	assert_eq(w.rewards.rolled[0], RewardStore.DEALT, "dealt (N7): its answer takes it")
	var code := w.rewards.offer_of(0)[0]
	hud.sync(r)
	var p := hud.pick_panel()
	assert_eq(p.card_count(), 1, "one card")
	assert_eq(p.title_text(), tr("PICK_TITLE_CHEST_DEALT"))
	assert_eq(CardDeal.order([p.slot(0).tier]), PackedInt32Array([0]))
	assert_false(p.slot(0).card.fx.face.visible, "it arrives face down")
	_run(p, 3.0)
	assert_true(p.slot(0).card.fx.face.visible, "and flips")
	p._input(_key(KEY_ENTER))
	_step(w, 1)
	assert_eq(w.choosing, -1)
	hud.sync(r)
	assert_true(p.outro_playing())
	await get_tree().process_frame
	assert_eq(hud.flights.flying(), 1, "its icon flies to the HUD")
	assert_eq((hud.flights.get_child(0) as CardFly).to, hud.flights.slot_rect_for(r, code))
	_run(p, 0.3)
	assert_false(p.slot(0).card.fx.burning(), "nothing burns at a chest")
