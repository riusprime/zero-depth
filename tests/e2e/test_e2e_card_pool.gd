extends GutTest
## The bigger card pool through real input (v0.5.0 CP): start a run, fill the four slots from the dev panel (Bomb
## Lobber, Drone Buddy, Orbit Blades: so ability mods can come up and no altar opens with a new ability), then walk
## (left stick only) from altar to altar, opening each with E, until one offers a v0.5.0 CP card: its face shows
## its own symbol, its translated name and its numbers; take it with the keyboard (arrows, Enter) and see it apply.

const CP_STATS: Array[StringName] = [
	&"glass_cannon", &"onrush", &"overkill", &"hoarder", &"fast_hands"
]
const CP_MODS: Array[StringName] = [
	&"cluster_payload", &"overclocked_drone", &"razor_orbit", &"afterimage"
]


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _grant(e: E2e, main: Main, id: StringName) -> void:
	var w := e.world()
	while w.ability_tables[main.driver.debug.ability_choice].id != id:
		await _click(e, main, "NextAbility")
	await _click(e, main, "GrantAbility")
	await e.frames(2)


## The index of a CP card in `offer`, or -1.
static func _cp_card(w: World, offer: PackedInt32Array) -> int:
	for k in offer.size():
		var c := offer[k]
		match Offers.type_of(c):
			Offers.STAT:
				if w.stat_tables[Offers.stat_of(c)].id in CP_STATS:
					return k
			Offers.MOD:
				if w.item_tables[c].id in CP_MODS:
					return k
	return -1


func test_open_altars_until_a_new_card_is_offered_and_take_it() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	for id in [&"bomb_lobber", &"drone_buddy", &"orbit_blades"]:
		await _grant(e, main, id)
	await e.tap(KEY_QUOTELEFT)
	assert_eq(w.ability_owned.size(), 4, "four slots full")
	var visited := []
	var found := -1
	var offer := PackedInt32Array()
	for attempt in 3:
		var altar := -1
		for i in w.rewards.size():
			if w.rewards.kind[i] != RewardStore.Kind.ALTAR or w.rewards.ids[i] in visited:
				continue
			if (
				altar < 0
				or (
					w.rewards.pos(i).distance_to(w.player_pos())
					< w.rewards.pos(altar).distance_to(w.player_pos())
				)
			):
				altar = i
		if altar < 0:
			break
		var altar_id := w.rewards.ids[altar]
		visited.append(altar_id)
		assert_true(await e.walk_to(w.rewards.pos(altar), w.reward_table.interact_radius_m * 0.6))
		await e.tap(KEY_E)
		await e.frames(2)
		assert_true(hud.pick_panel().is_open(), "E opened altar %d" % altar_id)
		offer = w.rewards.offer_of(w.rewards.index_of(altar_id))
		found = _cp_card(w, offer)
		if found >= 0:
			break
		await e.tap(KEY_ENTER)  # take the first card and walk on
		await e.frames(3)
	assert_gte(found, 0, "an altar offered a v0.5.0 CP card (visited %d)" % visited.size())
	if found < 0:
		return
	var panel := hud.pick_panel()
	var code := offer[found]
	var info := main.driver.reader.card_info(code)
	var slot := panel.slot(found)
	gut.p("offered %s: %s / %s" % [info["id"], slot.card.title_text(), slot.card.desc_text()])
	assert_eq(slot.card.title_text(), tr(info["name_key"]), "its translated name")
	assert_ne(str(ItemIcons.shapes(info["id"])), str(ItemIcons.gem()), "its own symbol")
	if Offers.type_of(code) == Offers.STAT:
		assert_string_contains(slot.card.desc_text(), GambleIcons.percent(int(info["amount"])))
		if int(info["side"]) > 0:
			assert_string_contains(slot.card.desc_text(), GambleIcons.percent(int(info["side"])))
	var before := Stats.value(w, Offers.stat_of(code)) if Offers.type_of(code) == Offers.STAT else 0
	for k in found:
		await e.tap(KEY_RIGHT)
	assert_eq(panel.focus_index(), found)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	if Offers.type_of(code) == Offers.STAT:
		assert_ne(Stats.value(w, Offers.stat_of(code)), before, "the stat card applied")
	else:
		assert_true(w.items_owned.has(code), "the mod is owned")
