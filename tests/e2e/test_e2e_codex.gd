extends GutTest
## v0.7.5 CX (owner N6): the Codex through real input only. From the main menu (keyboard, then the pad's RB and B)
## everything is still a silhouette; in a run you take an altar's card and shoot an enemy dead; the pause menu's Codex
## row shows both met (the card's tile named, its "Taken: 1"; the enemy's kill on the Enemies page); back in the main
## menu the Codex still has them (the profile, outside the run), and the mouse picks a page and leaves by Back.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"shoot", &"pause"]:
		Input.action_release(a)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _pad(e: E2e, b: JoyButton) -> void:
	e.joy_button(b, true)
	await e.frames(1)
	e.joy_button(b, false)
	await e.frames(2)


func _nearest_enemy(w: World) -> int:
	var best := -1
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or w.actors.teams[i] != ActorStore.TEAM_ENEMY:
			continue
		var d := w.actors.pos(i).distance_to(w.player_pos())
		if best < 0 or d < w.actors.pos(best).distance_to(w.player_pos()):
			best = i
	return best


## Holds the right trigger, aiming the right stick at the nearest enemy, until something died (or the budget ends).
func _shoot_until_a_kill(e: E2e) -> void:
	var w := e.world()
	var shooting := false
	for k in 3600:
		var target := _nearest_enemy(w)
		if target >= 0:
			var d := (w.actors.pos(target) - w.player_pos()).normalized()
			var c := InputLatch.C45
			var screen := Vector2((d.x + d.y) * c, (d.y - d.x) * c)
			e.joy_axis(JOY_AXIS_RIGHT_X, screen.x)
			e.joy_axis(JOY_AXIS_RIGHT_Y, -screen.y)
			if not shooting:
				e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
				shooting = true
		await e.frames(1)
		if w.kills > 0 or w.player_dead():
			break
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	e.joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	e.joy_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await e.frames(2)


## v0.8.0 RR: walks the Cards page by the arrow keys (right along a row, down at its end, then left along the
## next) and checks every met mod card it shows: its tier word on the card and in the section line. Returns the tiers
## seen (a set of Offers rarities).
func _walk_met_mods(e: E2e, main: Main, codex: CodexView) -> Dictionary:
	var seen := {}
	await e.tap(KEY_DOWN)
	# v0.8.0 RM: each row is swept to its left end, then to its right end (the arrows stop at a row's ends), so a
	# row entered from the middle is read whole.
	for row in 200:
		for key in [KEY_LEFT, KEY_RIGHT]:
			for k in 60:
				var at := codex.shown_entry()
				_note_tier(main, codex, at, seen)
				await e.tap(key)
				if codex.shown_entry() == at:
					break
		var end := codex.shown_entry()
		await e.tap(KEY_DOWN)
		if codex.shown_entry() == end:
			break
	return seen


func _note_tier(main: Main, codex: CodexView, at: Dictionary, seen: Dictionary) -> void:
	if (
		codex.page == &"cards"
		and int(at.get("type", -1)) == WorldReader.CARD_MOD
		and main.codex.is_unlocked(&"cards", at["id"])
	):
		var word := tr(CodexView.RARITY_KEYS[int(at["rarity"])])
		assert_eq(codex.card.tier_text(), word, "%s: the card says its tier" % at["id"])
		assert_string_contains(codex.section_label.text, word, "and the section line")
		seen[int(at["rarity"])] = true


## v0.8.0 RR (owner O33): the Codex says every mod card's tier. The profile already holds one card of each tier (a
## profile from earlier runs: setup); the main menu's Codex row opens it (keys) and the arrows reach all four.
func test_the_codex_says_each_cards_tier() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	for id in [&"gun_pierce", &"halo_shot", &"gun_twin", &"chain_blast"]:
		main.codex.unlock(&"cards", id)
	for k in 3:
		await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Codex")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var codex := main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex)
	if codex == null:
		return
	var seen := await _walk_met_mods(e, main, codex)
	gut.p("tiers seen: %s" % [seen.keys()])
	assert_eq(seen.keys().size(), 4, "Common, Rare, Epic and Legendary cards each say their tier")


func test_the_codex_fills_in_a_run_and_opens_from_both_menus() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	# The main menu: Play, Options, Credits, Codex.
	for k in 3:
		await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Codex", "the Codex row is under Credits")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var codex := main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex, "Enter on Codex opens it from the main menu")
	assert_eq(codex.page, &"cards", "on the Cards page")
	assert_true(codex.tiles.all(func(t: CodexTile) -> bool: return t.locked), "nothing met yet")
	assert_eq(codex.tiles[0].name_label.text, "???", "a silhouette")
	await _pad(e, JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(codex.page, &"enemies", "RB turns to the Enemies page")
	await _pad(e, JOY_BUTTON_B)
	assert_null(main.get_node_or_null("UI/CodexView"), "pad B leaves the Codex")
	assert_not_null(main.get_node_or_null("UI/MainMenu"))
	assert_eq(_focused(main).name, &"Codex", "back on the Codex row")
	for k in 3:
		await e.tap(KEY_UP)
	assert_eq(_focused(main).name, &"Play")
	await e.start_from_menu(&"gun")
	assert_true(main.is_playing())
	var biome := main.run_biome_id()
	assert_eq(
		main.codex.count(&"biomes", biome, &"visits"), 1, "the first floor's biome is visited"
	)
	var w := e.world()
	# Take a card of the nearest altar (E opens it, its number key and Enter take it).
	var altar := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_true(await e.walk_to(w.rewards.pos(altar), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	assert_true(main.driver.reader.choosing(), "E opened the altar")
	# v0.8.0 RR (owner O33): a mod card says its tier on the card (the word, not the colour alone); take the first
	# mod card offered (else the first card), so the Codex later holds a met mod card
	var panel := (main.get_node("UI/Hud") as Hud).pick_panel()
	var take := -1
	for k in panel.card_count():
		var info := main.driver.reader.card_info(main.driver.reader.choice_items()[k])
		if int(info["type"]) == WorldReader.CARD_MOD:
			var word := tr(PickPanel.RARITY_KEYS[int(info["rarity"])])
			assert_true(
				panel.slot(k).card.tier_text().ends_with(word), "card %d says %s" % [k, word]
			)
			take = k if take < 0 else take
	take = maxi(take, 0)
	var card_id: StringName = (
		main.driver.reader.card_info(main.driver.reader.choice_items()[take])["id"]
	)
	await e.tap([KEY_1, KEY_2, KEY_3][take])
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_false(main.driver.reader.choosing(), "the card was taken")
	# Shoot an enemy dead.
	await _shoot_until_a_kill(e)
	assert_false(w.player_dead(), "survived")
	assert_gt(w.kills, 0, "shot something dead")
	var killed: Array[StringName] = []
	for id in main.codex.unlocked_ids(&"enemies"):
		if main.codex.count(&"enemies", id, &"kills") > 0:
			killed.append(id)
	assert_false(killed.is_empty(), "the kill is in the Codex")
	# Pause -> Codex (Resume, Build, Restart, Options, Codex).
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	for k in 4:
		await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Codex", "the pause menu's Codex row")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	codex = main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex, "the Codex opens over the paused run")
	assert_false(
		(main.get_node("UI/PauseMenu") as Control).visible, "the pause menu hides under it"
	)
	var tile := codex.tile(card_id)
	assert_not_null(tile, "%s is a Codex card" % card_id)
	if tile != null:
		assert_false(tile.locked, "the taken card is met")
		assert_eq(tile.name_label.text, CodexView.title_of(codex, tile.entry), "and named")
	assert_eq(main.codex.count(&"cards", card_id, &"taken"), 1, "taken once")
	assert_gt(main.codex.count(&"cards", card_id, &"offered"), 0, "the altar offered it")
	await e.tap(KEY_E)
	assert_eq(codex.page, &"enemies", "E turns to the Enemies page")
	assert_false(codex.tile(killed[0]).locked, "the enemy shot dead is met")
	await e.tap(KEY_DOWN)
	await e.frames(1)
	var shown := codex.shown_entry()
	assert_eq(shown["page"], &"enemies", "arrows move through the Enemies page")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/CodexView"), "Esc leaves the Codex")
	assert_true((main.get_node("UI/PauseMenu") as Control).visible, "back to the pause menu")
	assert_eq(_focused(main).name, &"Codex")
	assert_true(main.driver.paused, "still paused")
	# Main menu, and the Codex there still holds the run's finds.
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_false(main.is_playing(), "Main menu ends the run")
	for k in 4:  # Continue (the run's save), Play, Options, Credits, Codex
		await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Codex")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	codex = main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex)
	assert_false(codex.tile(card_id).locked, "the card is still met: the profile, not the run")
	var tab := codex.tabs[&"enemies"] as Button
	await e.click_at(tab.get_global_rect().get_center())
	await e.frames(2)
	assert_eq(codex.page, &"enemies", "a click picks the page")
	assert_false(codex.tile(killed[0]).locked)
	await e.click_at((codex.tabs[&"biomes"] as Button).get_global_rect().get_center())
	await e.frames(2)
	assert_false(codex.tile(biome).locked, "the biome entered is met")
	await e.click_at(codex.back.get_global_rect().get_center())
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/CodexView"), "a click on Back leaves")
	assert_not_null(main.get_node_or_null("UI/MainMenu"))
