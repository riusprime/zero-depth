extends GutTest
## v0.6.0 Step UP through the real game (main.tscn, input only): a run shows its first phase banner ("New:
## Charger") in English; switching the language to Spanish in Options (from the pause menu) words the banner on
## screen again ("Nuevo: Embestidor"), and the weapon slot's key reads "Clic izq." instead of "LMB".


func after_each() -> void:
	TranslationServer.set_locale("en")


func test_a_language_switch_words_the_live_banner_again() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var hud := main.get_node("UI/Hud") as Hud
	var shown := ""
	for k in 90:  # up to 15 s of play for the first banner
		await e.frames(10)
		shown = hud.phase_hud.announcement()
		if not shown.is_empty():
			break
	assert_false(shown.is_empty(), "a banner shows (the first enemy kind met)")
	var entry := hud.phase_hud.current_entry()
	assert_eq(shown, hud.phase_hud.line(entry), "worded in English")
	assert_eq(hud.ability_hud.slot(0).key_text, "LMB", "the weapon's key, short")
	# Options from the pause menu (Esc, Down, Down, Enter), the Language category (Down x4), into it (Right) and
	# one step to Spanish (Right).
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	for k in 2:
		await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	for k in 4:
		await e.tap(KEY_DOWN)
	await e.tap(KEY_RIGHT)
	await e.tap(KEY_RIGHT)
	await e.frames(2)
	assert_eq(TranslationServer.get_locale(), "es", "Spanish chosen in Options")
	var es := TranslationServer.translate(entry[0])
	if not entry[1].is_empty():
		es = es % TranslationServer.translate(entry[1])
	assert_ne(es, shown, "the Spanish line differs")
	assert_eq(hud.phase_hud.announce.text, es, "the banner on screen is worded in Spanish at once")
	# Back to the run (Esc out of the section, out of Options, out of the pause menu).
	for k in 3:
		await e.tap(KEY_ESCAPE)
		await e.frames(2)
	await e.frames(3)
	assert_false(main.driver.paused, "the run goes on")
	assert_eq(hud.ability_hud.slot(0).key_text, "Clic izq.", "the weapon's key, in Spanish")
