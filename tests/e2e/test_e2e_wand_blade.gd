extends GutTest
## v0.6.5 WN4 (docs/design/WAND.md, the Blade pool; owner W5: "the slash becomes a spell"): a Blade run takes two of
## the Blade's cards and the slash changes in play, through main.tscn and real input only. The dev panel (real
## clicks; TEST HELPER, as test_e2e_modifiers_mx4.gd) grants Whirl, then Wave, and spawns an enemy; the player swings
## with the mouse. Whirl sits left of Wave, so every slash is a full spin (the laser blade turns all round) and the
## spin throws a ring of crescents (BladeForms.CRESCENT_RING) that BladeFormView draws as crescents.


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
		and guard < 120
	):
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


func _crescents(w: World) -> int:
	var n := 0
	for i in w.projectiles.size():
		var s := Modifiers.book(w).find(w.projectiles.spec_key[i])
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER and s != null and s.id == &"echo_slash":
			n += 1
	return n


func test_whirl_and_wave_spin_and_throw_a_ring_of_crescents() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"blade")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"whirl")
	await _grant(e, main, &"echo_slash")
	var whirl := AttackScenario.item_index(w.item_tables, &"whirl")
	var wave := AttackScenario.item_index(w.item_tables, &"echo_slash")
	assert_eq(Array(w.mod_slots).slice(0, 2), [whirl, wave], "Whirl then Wave, left to right")
	await _click(e, main, "SpawnEnemy")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var read: Dictionary = main.driver.reader.wand()
	assert_eq(read["cards"][0]["id"], &"whirl", "the wand reads the cards back in order")
	var root: WorldViewRoot = main.view
	var spun := false
	var most := 0
	var drawn := 0
	for swing in 16:
		e.mouse_button(MOUSE_BUTTON_LEFT, true)
		e.mouse_button(MOUSE_BUTTON_LEFT, false)
		for f in 12:
			await e.frames(1)
			spun = (
				spun or (root.kit.blade_visible() and root.kit.motion() == WorldReader.MOTION_SPIN)
			)
			most = maxi(most, _crescents(w))
			drawn = maxi(drawn, int(root.blade_forms.drawn.get(&"crescent", 0)))
		if spun and most >= BladeForms.CRESCENT_RING and drawn >= BladeForms.CRESCENT_RING:
			break
	assert_true(spun, "every slash is a full spin")
	assert_gte(most, BladeForms.CRESCENT_RING, "the spin throws a ring of crescents")
	assert_gte(drawn, BladeForms.CRESCENT_RING, "drawn as crescents")
	assert_false(w.player_dead())
