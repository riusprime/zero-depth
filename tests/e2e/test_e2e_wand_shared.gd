extends GutTest
## v0.6.5 WN5a (docs/design/WAND.md, the shared pool and the triggers): a Blade run takes a trigger and a shared card
## and the trigger's small spell shows in play, through main.tscn and real input only. The dev panel (real clicks;
## TEST HELPER, as test_e2e_wand_blade.gd) grants On End, then Explosive; the player swings with the mouse. On End
## sits left of Explosive, so every slash casts a small slash where it ends, and that small slash explodes where it
## ends: AttackFormView draws the cast's sigil, the small slash and its blast. The wand reads the cut back.


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
		and guard < 160
	):
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


func test_on_end_and_explosive_cast_a_small_slash_that_explodes() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"blade")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"trigger_on_end")
	await _grant(e, main, &"shared_explosive")
	var cut := AttackScenario.item_index(w.item_tables, &"trigger_on_end")
	var boom := AttackScenario.item_index(w.item_tables, &"shared_explosive")
	assert_eq(Array(w.mod_slots).slice(0, 2), [cut, boom], "On End then Explosive, left to right")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var read: Dictionary = main.driver.reader.wand()
	assert_eq(read["cuts"], PackedInt32Array([0]), "the wand is cut after On End")
	assert_eq(read["cards"][0]["trigger"], AttackSpec.Trigger.ON_END)
	var root: WorldViewRoot = main.view
	var forms: AttackFormView = root.attack_forms
	var sigils := forms.casts_drawn
	var slashes := int(forms.cast_forms.get(&"arc", 0))
	var blasts := int(forms.cast_forms.get(&"burst", 0))
	for swing in 12:
		e.mouse_button(MOUSE_BUTTON_LEFT, true)
		e.mouse_button(MOUSE_BUTTON_LEFT, false)
		await e.frames(14)
		if (
			forms.casts_drawn > sigils
			and int(forms.cast_forms.get(&"arc", 0)) > slashes
			and int(forms.cast_forms.get(&"burst", 0)) > blasts
		):
			break
	var cast := 0
	for m: Dictionary in main.driver.reader.wand_casts():
		cast += 1 if m["cast"] else 0
	assert_gt(cast, 0, "the sim cast the small slash where the slash ended")
	assert_gt(forms.casts_drawn, sigils, "its sigil is drawn where it fired")
	assert_gt(int(forms.cast_forms.get(&"arc", 0)), slashes, "the small slash is drawn")
	assert_gt(int(forms.cast_forms.get(&"burst", 0)), blasts, "and its blast where it ends")
	assert_false(w.player_dead())
