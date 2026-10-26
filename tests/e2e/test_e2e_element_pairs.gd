extends GutTest
## v0.9.5 EE3 (ELEMENTS.md X1) through the real game (main.tscn, input by Input.parse_input_event only): a Gun run holds
## Fire and Frost at Lv 3 (the dev panel's GrantMod, real clicks), the pair banner shows, and a bolt hits an enemy
## that is burning and frozen: a neighbour within 1.5 m takes Thermal Shock's burst.

const W := preload("res://tests/support/mx4_world.gd")


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## Grants card `id` through the dev panel until it is Lv `lv` (NextMod to pick it, GrantMod to give it).
func _grant(e: E2e, main: Main, id: StringName, lv: int) -> void:
	var w := e.world()
	var k := W.item(w, id)
	var guard := 0
	while main.driver.debug.mod_choice != k and guard < 300:
		await _click(e, main, "NextMod")
		guard += 1
	var n := 0
	while (not w.items_owned.has(k) or CardLevels.level(w, k) < lv) and n < 6:
		await _click(e, main, "GrantMod")
		await e.frames(3)
		n += 1


func test_fire_and_frost_at_level_3_wake_thermal_shock() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"ember_core", 3)
	await _grant(e, main, &"frost_core", 3)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(3)
	assert_eq(CardLevels.level(w, W.item(w, &"ember_core")), 3, "Fire Lv 3")
	assert_eq(CardLevels.level(w, W.item(w, &"frost_core")), 3, "Frost Lv 3")
	assert_true(ElementPairs.on(w, ElementPairs.X1), "Thermal Shock is on")
	var hud: Hud = main.get_node("UI/Hud")
	assert_true(hud.combo_card().is_showing(), "its banner shows")
	assert_eq(hud.combo_card().title_text(), tr("PAIR_THERMAL_SHOCK"))
	# TEST HELPER (labelled): two standing dummies 4 m away on a clear line, 1 m apart across it; the first is burning
	# and frozen (the statuses are set; the hit is the real bolt).
	var bomb := load("res://tests/e2e/test_e2e_bomb.gd")
	var at: Vector2 = bomb.clear_spot(w, 4.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var side := (at - w.player_pos()).normalized().orthogonal()
	w.dummy_speed = 0.0
	var first := w.add_dummy(at, 0.35, 9000)
	var near := w.add_dummy(at + side * 1.0, 0.35, 9000)
	await e.frames(2)
	var a := w.actors
	var i := a.index_of(first)
	a.burn_stacks[i] = 1
	a.burn_t[i] = 600
	a.burn_cd[i] = 600
	a.frozen_t[i] = 600
	var cam := main.view.rig.camera
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))
	var burst := 0
	for n in 240:
		await e.frames(1)
		burst = 0
		for ev in w.events_since(0):
			if (
				ev.kind == SimEvent.Kind.DAMAGE
				and ev.effect_id == SimEvent.EFFECT_PAIR_BURST
				and ev.target_id == near
			):
				burst += 1
		if burst > 0:
			break
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	gut.p("EE3 e2e: %d burst hit(s) on the neighbour at 1 m" % burst)
	assert_gt(burst, 0, "the neighbour within 1.5 m took Thermal Shock's burst")
