extends GutTest
## v0.10.5 O17 (owner P17) through main.tscn with real input only: Play -> the hub, the left stick walks the hero south
## through the rim's door down its lane (the Training Room loads behind the cover), the stick to the terminal, E (or
## pad X) opens its panel, the keys (or the d-pad and A) spawn a Charger and take a wand card, Esc closes it, and the
## exit pad at the room's top corner walks the hero back to the hub. The Codex is pre-filled (a Charger met, a card
## seen): the terminal offers only what the Codex knows.


func after_each() -> void:
	E2e.center_sticks()
	for a in [&"ui_accept", &"ui_down", &"ui_up", &"pause", &"interact"]:
		Input.action_release(a)


## A profile whose Codex has met the Charger and seen one wand card (the Gun's first, in item order).
func _profile() -> ProfileStore:
	var p := ProfileStore.new("")
	var codex := CodexStore.new(p)
	codex.unlock(&"enemies", &"charger")
	codex.unlock(&"cards", _first_card())
	p.section("loadout")["build"] = "gun"
	return p


func _first_card() -> StringName:
	var repo := AttackScenario.repo()
	var w := TrainingScenario.build(repo, &"gun", repo.get_def(&"biomes", HubSession.BIOME))
	for e in PlaygroundApi.new(w).catalog():
		if e["group"] == PlaygroundApi.GROUP_WAND:
			return w.item_tables[int(e["code"])].id
	return &""


## The stick pushed down (the plan's south) until the Training Room runs; false after `limit` frames.
func _walk_into_training(e: E2e, limit: int = 600) -> bool:
	var main := e.main
	for k in limit:
		if main.training != null:
			break
		e.joy_axis(JOY_AXIS_LEFT_X, 0.0)
		e.joy_axis(JOY_AXIS_LEFT_Y, 1.0)
		await e.frames(1)
	e.joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	await e.frames(4)
	return main.training != null


func _focused(main: Main) -> String:
	var f := main.get_viewport().gui_get_focus_owner()
	return String(f.name) if f != null else ""


## Taps `key` until the focus is on `target` (at most 12 taps).
func _focus_to(e: E2e, key: Key, target: String) -> bool:
	for k in 12:
		if _focused(e.main) == target:
			return true
		await e.tap(key)
	return _focused(e.main) == target


func _chargers(w: World) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		if w.actors.kinds[i] == ActorStore.Kind.CHARGER and w.actors.dead[i] == 0:
			n += 1
	return n


func _to_terminal(e: E2e) -> bool:
	var room := e.main.training.room
	await e.walk_to(TrainingRoom.terminal_point(room), 1.3)
	for k in 30:
		if e.main.training.at_terminal:
			return true
		await e.frames(1)
	return e.main.training.at_terminal


func test_walk_in_spawn_a_charger_take_a_card_and_walk_out() -> void:
	var e := E2e.new(self)
	e.real_start = true  # v0.11.1 T1: Play goes to the hub (the full path)
	var main: Main = await e.boot(_profile())
	assert_true(await HubWalk.new(e).enter(), "Play goes to the hub")
	assert_eq((main.get_node("UI/HubHud") as HubHud).station_name(), "", "no station at the spawn")
	assert_true(await _walk_into_training(e), "south through the door: the Training Room")

	assert_null(main.hub, "the hub is gone")
	assert_true(main.is_playing(), "a room World runs")
	var w := e.world()
	assert_eq(w.player_hp_floor, TrainingScenario.HP_FLOOR, "the hero can't die here")
	assert_true(await _to_terminal(e), "the hero walks to the terminal")
	var thud := main.get_node_or_null("UI/TrainingHud") as HubHud
	assert_not_null(thud)
	assert_eq(thud.prompt_text(), tr("UI_TRAINING_PROMPT_TERMINAL"), "its prompt shows")
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := main.get_node_or_null("UI/TrainingPanel") as TrainingPanel
	assert_not_null(panel, "E opens the terminal's panel")
	assert_true(main.driver.paused, "the room waits while it is open")
	assert_eq(_focused(main), "Enemy", "the enemy pick has focus")
	assert_eq(panel.enemy_cycler.text, "‹  %s  ›" % tr("ENEMY_CHARGER"), "the Codex's Charger")
	assert_true(await _focus_to(e, KEY_DOWN, "Spawn"), "down to Spawn")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_eq(_chargers(w), 1, "Spawn: one Charger (the count's first, 1)")
	assert_true(await _focus_to(e, KEY_DOWN, "AddCard"), "down to Add card")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var owned := w.items_owned.size()
	assert_gt(owned, 0, "the card is in the build")
	assert_eq(panel.status.text, tr("UI_TRAINING_CARD_ADDED") % tr(panel.picked_card()["name_key"]))
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/TrainingPanel"), "Esc closes it")
	assert_false(main.driver.paused, "the room runs again")
	assert_null(main.get_node_or_null("UI/PauseMenu"), "and no pause menu opened with it")
	await e.walk_to(TrainingRoom.exit_point(main.training.room), 0.6)
	for k in 60:
		if main.hub != null:
			break
		await e.frames(1)
	assert_not_null(main.hub, "the exit pad walks the hero back to the hub")
	assert_null(main.training)


func test_the_pad_opens_the_terminal_and_spawns_three() -> void:
	var e := E2e.new(self)
	e.real_start = true  # v0.11.1 T1: Play goes to the hub (the full path)
	var main: Main = await e.boot(_profile())
	await HubWalk.new(e).enter()
	assert_true(await _walk_into_training(e))
	assert_true(await _to_terminal(e))
	e.joy_button(JOY_BUTTON_X, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_X, false)
	await e.frames(2)
	var panel := main.get_node_or_null("UI/TrainingPanel") as TrainingPanel
	assert_not_null(panel, "pad X opens the panel")
	for k in 2:  # Enemy -> Count, then the count to 3
		e.joy_button(JOY_BUTTON_DPAD_DOWN, true)
		await e.frames(1)
		e.joy_button(JOY_BUTTON_DPAD_DOWN, false)
		await e.frames(1)
		if _focused(main) == "Count":
			break
	assert_eq(_focused(main), "Count")
	e.joy_button(JOY_BUTTON_DPAD_RIGHT, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_DPAD_RIGHT, false)
	await e.frames(1)
	assert_eq(panel.picked_count(), 3, "d-pad right: 3")
	e.joy_button(JOY_BUTTON_DPAD_DOWN, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_DPAD_DOWN, false)
	await e.frames(1)
	assert_eq(_focused(main), "Spawn")
	e.joy_button(JOY_BUTTON_A, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_A, false)
	await e.frames(2)
	assert_eq(_chargers(e.world()), 3, "pad A: three Chargers")
