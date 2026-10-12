extends GutTest
## v0.6.5 WN3 (docs/design/WAND.md, the Gun pool): two Gun cards taken in a real Gun run change the shot in play,
## through main.tscn and real input only. The dev panel (real clicks; TEST HELPER, as test_e2e_swap.gd) grants Big
## Shot and then Charge; the wand holds them left to right; holding right click charges a shot (nothing fires, the
## orb's charge rises) and the release fires one big, charged bolt, bigger than Big Shot alone. Granting Charge again
## levels it to 2 (no new slot) and the bolt's spec grows. No code names the pair.


func after_each() -> void:
	Input.action_release(&"shoot")


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


func _player_bolts(w: World) -> Array[int]:
	var out: Array[int] = []
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			out.append(i)
	return out


func test_big_shot_and_charge_change_the_gun_shot_in_play() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var reader: WorldReader = main.driver.reader
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"gun_big_shot")
	await _grant(e, main, &"gun_charge")
	var big := AttackScenario.item_index(w.item_tables, &"gun_big_shot")
	var charge := AttackScenario.item_index(w.item_tables, &"gun_charge")
	assert_eq(Array(w.mod_slots), [big, charge], "the wand holds Big Shot, then Charge")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var spec: Dictionary = reader.attack_spec(WorldReader.ATTACK_BOLT)
	var plain_r := w.player.bolt_radius_m
	assert_almost_eq(float(spec["radius_m"]), plain_r * 2.0, 1e-4, "the view reads a big bolt")
	assert_gt(int(spec["hold_ticks"]), 0, "that charges")
	# Hold right click: it charges, nothing fires.
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.frames(30)
	assert_eq(_player_bolts(w).size(), 0, "holding charges the shot")
	assert_gt(reader.gun_charge(), 0.3, "the charge rises (the orb swells in the barrel)")
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(3)
	var bolts := _player_bolts(w)
	assert_eq(bolts.size(), 1, "the release fires one shot")
	if bolts.size() > 0:
		assert_gt(
			w.projectiles.radius[bolts[0]], plain_r * 2.0 * 1.3, "a charged big shot: bigger still"
		)
	# Charge again: a level-up, no new slot (the panel's choice starts over when it opens again).
	await e.tap(KEY_QUOTELEFT)
	await _grant(e, main, &"gun_charge")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_eq(w.mod_slots.size(), 2, "no new slot")
	var cards: Array = reader.wand()["cards"]
	assert_eq(int(cards[1]["level"]), 2, "Charge is level 2")
	assert_gt(
		int(reader.attack_spec(WorldReader.ATTACK_BOLT)["hold_permille"]),
		int(spec["hold_permille"]),
		"and charges further"
	)
	assert_false(w.player_dead())
