extends GutTest
## The build system through real input (v0.4.0 BS, owner F8, F9, F11): start a run (slot 1 = the Blade's Combo
## Sword), walk (left stick only) to the nearest altar, open it with E: its first card is a new ability; take an
## auto ability with the keyboard (arrows, Enter). The HUD gains its slot, and the ability fires at the enemies that
## come (its hits reach the damage numbers). v0.6.0 MX2: the six auto abilities are weapon modifiers, so the player
## attacks (left mouse) and dashes while waiting: Bomb Lobber lobs on every 4th attack, Arc Field leaves its field
## where an attack ends, Flame Trail's dash leaves fire, Frost Nova's frost element rides the swings (its stacks, or
## its ring on a kill streak). Then the dev panel grants Blink, and Shift blinks.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_pick_an_ability_card_at_an_altar_and_see_it_fire() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var reader := main.driver.reader
	assert_eq(reader.abilities().size(), 1, "slot 1 holds the weapon")
	assert_eq(reader.abilities()[0]["id"], &"combo_sword", "the Blade's Combo Sword")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")  # the walk and the wait are about the ability, not survival (panel stays open)
	var altar := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	var altar_id := w.rewards.ids[altar]
	assert_true(await e.walk_to(w.rewards.pos(altar), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_true(panel.is_open(), "E opened the altar")
	var offer := w.rewards.offer_of(w.rewards.index_of(altar_id))
	assert_eq(Offers.type_of(offer[0]), Offers.ABILITY, "the first card is an ability")
	assert_eq(panel.slot(0).rarity_color(), PickSlot.ABILITY, "drawn as an ability card")
	assert_eq(
		panel.slot(0).card.title_text(), tr(w.ability_tables[Offers.ability_of(offer[0])].name_key)
	)
	# Take an auto ability: the first card if it is one, else the first auto ability among the cards; if the
	# altar offers none (a utility first card and two others), the first card and its button.
	var pick := 0
	for k in offer.size():
		if (
			Offers.type_of(offer[k]) == Offers.ABILITY
			and w.ability_tables[Offers.ability_of(offer[k])].auto
		):
			pick = k
			break
	for k in pick:
		await e.tap(KEY_RIGHT)
	assert_eq(panel.focus_index(), pick)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	var idx := Offers.ability_of(offer[pick])
	var t := w.ability_tables[idx]
	assert_true(Abilities.owned(w, idx), "the ability is held")
	assert_eq(reader.abilities().size(), 2)
	assert_eq(hud.ability_hud.filled_count(), 2, "the HUD shows it")
	assert_eq(hud.ability_hud.slot(1).ability_id, t.id)
	gut.p("took %s" % t.id)
	if not t.auto:
		pending("the altar offered only a utility ability: its use is test_e2e_utility")
		return
	var effect: StringName = {
		AbilityTable.Kind.BOMB_LOBBER: Abilities.EFFECT_BOMB,
		AbilityTable.Kind.DRONE_BUDDY: Abilities.EFFECT_DRONE,
		AbilityTable.Kind.ORBIT_BLADES: Abilities.EFFECT_ORBIT,
		AbilityTable.Kind.ARC_FIELD: ElementAbilities.EFFECT_ARC,  # v0.4.0 AB
		AbilityTable.Kind.FROST_NOVA: ElementAbilities.EFFECT_NOVA,
		AbilityTable.Kind.FLAME_TRAIL: ElementAbilities.EFFECT_FLAME,
	}[t.kind]
	var seq := w.last_event_seq()
	var fired := false
	var numbers := false
	for k in 3600:
		await e.frames(1)
		if k % 20 == 0:  # v0.6.0 MX2: attack (the modifiers ride the weapon's attacks)
			await e.mouse_button(MOUSE_BUTTON_LEFT, true)
			await e.mouse_button(MOUSE_BUTTON_LEFT, false)
		if k % 90 == 45:
			await e.tap(KEY_SPACE)  # a dash (Flame Trail)
		for ev in w.events_since(seq):
			fired = fired or (ev.kind == SimEvent.Kind.DAMAGE and ev.effect_id == effect)
		if t.kind == AbilityTable.Kind.FROST_NOVA and not fired:  # the frost element on the swings
			for i in range(1, w.actors.size()):
				fired = fired or w.actors.frost_stacks[i] > 0 or w.actors.frozen_t[i] > 0
		seq = w.last_event_seq()
		numbers = numbers or main.view.damage_numbers.showing() > 0
		if fired and numbers:
			break
		if k % 600 == 599 and not fired:  # walk toward the nearest enemy so one comes within reach
			var near := _nearest_enemy(w)
			if near >= 0:
				await e.walk_to(w.actors.pos(near), 2.0)
	assert_true(fired, "%s hit an enemy" % t.id)
	assert_true(numbers, "and its damage floated up")


func test_blink_card_then_shift_blinks() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	while w.ability_tables[main.driver.debug.ability_choice].id != &"blink":
		await _click(e, main, "NextAbility")  # (the dev panel's forced loadout)
	assert_eq(w.ability_tables[main.driver.debug.ability_choice].id, &"blink")
	await _click(e, main, "GrantAbility")
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(hud.ability_hud.filled_count(), 2, "Blink in slot 2")
	assert_ne(hud.ability_hud.slot(1).key_text, "", "a manual slot shows its key")
	var start := w.player_pos()
	e.key(KEY_W, true)
	await e.frames(3)
	e.key(KEY_SHIFT, true)
	e.key(KEY_SHIFT, false)
	await e.frames(3)
	e.key(KEY_W, false)
	assert_gt(w.player_pos().distance_to(start), 2.5, "Shift blinked")
	assert_eq(w.ab.blink_charges, 0, "spending its charge")
	await e.frames(2)
	assert_lt(hud.ability_hud.slot(1).fill, 1.0, "the slot's cooldown sweep runs")


func _nearest_enemy(w: World) -> int:
	var best := -1
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or w.actors.teams[i] == ActorStore.TEAM_PLAYER:
			continue
		if (
			best < 0
			or (
				w.actors.pos(i).distance_to(w.player_pos())
				< w.actors.pos(best).distance_to(w.player_pos())
			)
		):
			best = i
	return best
