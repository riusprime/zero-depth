extends GutTest
## v0.6.0 MX4 (owner B8: "a shooting fire sword that divides when you hit an enemy"): two of the M-list's cards
## taken in a real run combine in play, through main.tscn and real input only. The dev panel (real clicks; TEST
## HELPER, as test_e2e_swap.gd) grants Echo Slash and then Split Shot to a Blade run and spawns an enemy; the player
## turns to it with the stick and swings with the mouse. Each slash throws a crescent (Echo Slash), and the crescent
## splits in three where it hits (Split Shot rides the crescent because the crescent is a projectile): no code names
## the pair. The HUD's pips show both cards and the view's spec read carries the split under the crescent.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"primary"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## TEST HELPER (labelled): the dev panel's NextMod until card `id` is chosen, then GrantMod.
func _grant(e: E2e, main: Main, id: StringName) -> void:
	var w := e.world()
	var guard := 0
	while (
		(main.driver.debug.mod_choice < 0 or w.item_tables[main.driver.debug.mod_choice].id != id)
		and guard < 80
	):
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


func _projectiles_of(w: World, spec_id: StringName) -> int:
	var n := 0
	for i in w.projectiles.size():
		var s := Modifiers.book(w).find(w.projectiles.spec_key[i])
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER and s != null and s.id == spec_id:
			n += 1
	return n


func test_echo_slash_and_split_shot_combine_in_play() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"blade")
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"echo_slash")
	await _grant(e, main, &"split_shot")
	var echo := AttackScenario.item_index(w.item_tables, &"echo_slash")
	var split := AttackScenario.item_index(w.item_tables, &"split_shot")
	assert_true(w.items_owned.has(echo) and w.items_owned.has(split), "both cards held")
	assert_true(w.mod_slots.has(echo) and w.mod_slots.has(split), "each in a modifier slot")
	await _click(e, main, "SpawnEnemy")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_eq(hud.build_hud.filled_pips(), w.mod_slots.size(), "a pip per held modifier")
	# What the view reads: the step's crescent carries the split.
	var spec: Dictionary = main.driver.reader.attack_spec(Modifiers.step_id(0))
	var crescent := {}
	for h: Dictionary in spec["hooks"]:
		if h["id"] == &"echo_slash":
			crescent = h["child"]
	assert_false(crescent.is_empty(), "the slash's spec has the crescent")
	var splits := false
	for h: Dictionary in crescent.get("hooks", []):
		splits = splits or h["id"] == &"split_shot"
	assert_true(splits, "and the crescent's spec splits on hit")
	# Face the enemy with the stick, then swing with the mouse until a crescent lands and splits.
	var enemy := w.actors.size() - 1
	var seen_crescent := 0
	var seen_split := 0
	for swing in 24:
		if w.actors.size() <= 1:
			break
		enemy = w.actors.size() - 1
		var to := w.actors.pos(enemy) - w.player_pos()
		e.stick_toward(to.normalized())
		await e.frames(3)
		e.stick_toward(Vector2.ZERO)
		e.mouse_button(MOUSE_BUTTON_LEFT, true)
		e.mouse_button(MOUSE_BUTTON_LEFT, false)
		for f in 14:
			await e.frames(1)
			seen_crescent = maxi(seen_crescent, _projectiles_of(w, &"echo_slash"))
			seen_split = maxi(seen_split, _projectiles_of(w, &"split_shot"))
		if seen_split > 0:
			break
	assert_gt(seen_crescent, 0, "the slash throws a crescent")
	assert_eq(seen_split, 3, "the crescent splits in three where it hits")
	assert_false(w.player_dead())
