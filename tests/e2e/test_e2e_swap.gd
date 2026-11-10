extends GutTest


## Boots a Blade run, fills floor 1's four slots and grants an attack item: returns with the Swap panel open.
func _to_swap(e: E2e) -> Main:
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")
	for k in 4:
		await e.click_dev("GrantMod")
		await e.frames(2)
	assert_eq(w.mod_slots.size(), 4, "four wand cards fill floor 1's wand")
	var hud: Hud = main.get_node("UI/Hud")
	await e.frames(2)
	assert_eq(hud.build_hud.filled_pips(), 4, "four pips on the HUD")
	await e.click_dev("GrantMod")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)  # the dev panel closes; the swap waits
	await e.frames(2)
	assert_true(hud.swap.is_open(), "a fifth modifier: the Swap panel")
	assert_true(BuildSlots.swapping(w))
	assert_eq(hud.swap.slot_count(), 4)
	return main


func test_swap_with_the_keyboard() -> void:
	var e := E2e.new(self)
	var main := await _to_swap(e)
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var code := w.swap_code
	var gone := w.mod_slots[2]
	var t0 := w.run_ticks
	await e.frames(10)
	assert_eq(w.run_ticks, t0, "the world waits for the answer (only the tick counts)")
	await e.tap(KEY_3)
	assert_eq(hud.swap.focus_index(), 2)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_false(hud.swap.is_open(), "answered")
	assert_eq(w.mod_slots[2], code, "the new modifier took slot 3")
	assert_false(BuildSlots.held(w, gone), "the replaced one left the build")
	assert_eq(hud.build_hud.filled_pips(), 4)
	assert_true(Modifiers.book(w).modifier_ids.size() > 0, "the build recompiled with it")


func test_swap_with_the_mouse() -> void:
	var e := E2e.new(self)
	var main := await _to_swap(e)
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var code := w.swap_code
	await e.click_at(hud.swap.tile(3).get_global_rect().get_center())
	await e.frames(3)
	assert_false(hud.swap.is_open())
	assert_eq(w.mod_slots[3], code, "a click on slot 4 swapped it")


func test_swap_with_the_pad_and_skip() -> void:
	var e := E2e.new(self)
	var main := await _to_swap(e)
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var code := w.swap_code
	for k in 2:
		await e.joy_button(JOY_BUTTON_DPAD_RIGHT, true)
		await e.joy_button(JOY_BUTTON_DPAD_RIGHT, false)
	assert_eq(hud.swap.focus_index(), 2)
	await e.joy_button(JOY_BUTTON_A, true)
	await e.joy_button(JOY_BUTTON_A, false)
	await e.frames(3)
	assert_eq(w.mod_slots[2], code, "A swapped slot 3")
	# A second one, skipped with B: the build stays as it is.
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("GrantMod")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(hud.swap.is_open())
	var before := w.mod_slots.duplicate()
	var skipped := w.swap_code
	await e.joy_button(JOY_BUTTON_B, true)
	await e.joy_button(JOY_BUTTON_B, false)
	await e.frames(3)
	assert_false(hud.swap.is_open(), "B skipped")
	assert_eq(w.mod_slots, before, "nothing changed")
	assert_false(w.items_owned.has(skipped), "the skipped card is not held")


func test_skip_with_escape() -> void:
	var e := E2e.new(self)
	var main := await _to_swap(e)
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var before := w.mod_slots.duplicate()
	await e.tap(KEY_ESCAPE)
	await e.frames(3)
	assert_false(hud.swap.is_open())
	assert_eq(w.mod_slots, before)
	assert_eq(main.get("_pause"), null, "Esc skipped the swap, no pause")
