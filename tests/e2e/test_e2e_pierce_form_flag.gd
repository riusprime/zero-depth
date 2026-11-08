extends GutTest
## v0.11.0 S6 (owner, PIERCE.md P2) through main.tscn and real input only (Input.parse_input_event): a Gun run takes
## Pierce (the dev panel's NextMod / GrantMod, real clicks: TEST HELPER, as test_e2e_attack_order); Esc, Down, Enter
## opens the Build page, where Pierce's tile reads as any card's (the plain bolt uses it). Back in play the run takes
## the Lance form the same way; on the Build page again Pierce's tile now says "Does nothing with this form" (the form
## fired now does not compile it: Wand.DEAD_FORM).


func after_each() -> void:
	Input.action_release(&"pause")


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## TEST HELPER (labelled): the dev panel's NextMod until card `id` is chosen, then GrantMod.
func _grant(e: E2e, main: Main, id: StringName) -> void:
	var w := e.world()
	var guard := 0
	while (
		(main.driver.debug.mod_choice < 0 or w.item_tables[main.driver.debug.mod_choice].id != id)
		and guard < 200
	):
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


## Opens the Build page from play (Esc, Down, Enter) and returns Pierce's tile's [dead reason, level text], then
## goes back to play (Esc, Esc).
func _pierce_tile(e: E2e, main: Main) -> Array:
	var w := e.world()
	var name := tr(w.item_tables[AttackScenario.item_index(w.item_tables, &"gun_pierce")].name_key)
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var page := main.get_node_or_null("UI/BuildPage") as BuildPage
	assert_not_null(page, "the Build page opens")
	var out := [&"?", "?"]
	if page != null:
		for k in page.row.card_count():
			if page.row.card_name(k) == name:
				out = [page.row.dead_reason(k), page.row.level_text(k)]
	await e.tap(KEY_ESCAPE)  # back to the pause menu
	await e.frames(1)
	await e.tap(KEY_ESCAPE)  # resume
	await e.frames(3)
	assert_null(main.get_node_or_null("UI/PauseMenu"), "the run goes on")
	return out


func test_the_build_page_flags_pierce_once_the_lance_form_is_taken() -> void:
	TranslationServer.set_locale("en")
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await _grant(e, main, &"gun_pierce")
	assert_true(
		w.items_owned.has(AttackScenario.item_index(w.item_tables, &"gun_pierce")), "Pierce taken"
	)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var before: Array = await _pierce_tile(e, main)
	assert_eq(before[0], &"", "the plain bolt uses Pierce: no flag")
	assert_ne(before[1], "Does nothing with this form")
	await e.tap(KEY_QUOTELEFT)
	await _grant(e, main, &"gun_lance")
	assert_eq(AttackSlots.form_id(w), &"lance", "the Gun's shot is the Lance now")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var after: Array = await _pierce_tile(e, main)
	assert_eq(after[0], Wand.DEAD_FORM, "the Lance form does not use Pierce")
	assert_eq(after[1], "Does nothing with this form", "the tile says why")
