extends GutTest
## v0.6.5 WN3 (docs/design/WAND.md, the Gun pool): two Gun cards taken in a real Gun run change the shot in play,
## through main.tscn and real input only. The dev panel (real clicks; TEST HELPER, as test_e2e_swap.gd) grants Twin
## and then the Lance (v0.9.0 AF1: the Charge card this test took is retired into the Lance); the wand holds them left
## to right; holding right click charges (nothing fires, the charge rises) and the release fires one Lance as Twin's
## two lines. Granting the Lance again levels it to 2 (no new slot) and the shot's spec grows. No code names the pair.


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


## v0.9.0 AF1: the Lance lines released so far (LANCE events).
func _lances(w: World) -> int:
	var n := 0
	for ev in w.events_since(0):
		n += 1 if ev.kind == SimEvent.Kind.LANCE else 0
	return n


func _player_bolts(w: World) -> Array[int]:
	var out: Array[int] = []
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			out.append(i)
	return out


func test_twin_and_the_lance_change_the_gun_shot_in_play() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var reader: WorldReader = main.driver.reader
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"gun_twin")
	await _grant(e, main, &"gun_lance")
	var twin := AttackScenario.item_index(w.item_tables, &"gun_twin")
	var lance := AttackScenario.item_index(w.item_tables, &"gun_lance")
	assert_eq(Array(w.mod_slots), [twin, lance], "the wand holds Twin, then the Lance")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var spec: Dictionary = reader.attack_spec(WorldReader.ATTACK_BOLT)
	assert_gt(int(spec["hold_ticks"]), 0, "the shot charges")
	# Hold right click: it charges, nothing fires.
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.frames(30)
	assert_eq(_player_bolts(w).size(), 0, "holding charges the shot")
	assert_eq(_lances(w), 0, "no line yet")
	assert_gt(reader.gun_charge(), 0.3, "the charge rises")
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(3)
	assert_eq(_lances(w), 2, "the release fires one Lance: Twin's two lines")
	assert_eq(_player_bolts(w).size(), 0, "no projectile")
	# The Lance again: a level-up, no new slot (the panel's choice starts over when it opens again).
	await e.tap(KEY_QUOTELEFT)
	await _grant(e, main, &"gun_lance")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_eq(w.mod_slots.size(), 2, "no new slot")
	var cards: Array = reader.wand()["cards"]
	assert_eq(int(cards[1]["level"]), 2, "the Lance is level 2")
	assert_gt(
		int(reader.attack_spec(WorldReader.ATTACK_BOLT)["hold_permille"]),
		int(spec["hold_permille"]),
		"and its full charge hits harder"
	)
	assert_false(w.player_dead())
