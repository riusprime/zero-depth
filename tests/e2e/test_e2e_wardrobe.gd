extends GutTest
## v0.9.0 RB (owner, PLAN "Owner decisions" RB) through main.tscn with real input only: Play -> the hub, the hero
## walks to the Wardrobe and E opens it; Right picks the Ash robe, Down then Right x5 picks Guardian; the hub's hero
## wears both at once; Esc closes it and the profile keeps them; the Portal Machine starts a run that has Guardian
## locked in (its ward up, the gold rune under the hero's feet and on the robe's back, the robe Ash); the run's pause
## leaves to the main menu, Play goes back to the hub, and the hero there still wears Ash and the Guardian rune; the
## Wardrobe shows both again.
## v0.9.0 MP2 (owner, PLAN "Owner decisions" MP2): a profile with 260 Rune Fragments (a test helper: banked before the
## boot) -> Play -> the Progression Station lists "???" (an epic robe at 250); Down x4 + Enter buys it and reveals The
## Fallen's Regalia; Esc; the Wardrobe: Right x6 wears it, the hub's hero builds its crown and eyes and the blue face
## square goes; the Portal Machine starts a run and the hero wears it there, the plain shots violet.


func after_each() -> void:
	E2e.center_sticks()
	ElementLooks.set_energy(&"")


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _hero(main: Main) -> PlayerAvatar:
	var r := main.driver.reader
	return main.view.actors.actor_node(r.actor_id(0)).get_meta(&"avatar") as PlayerAvatar


func test_pick_a_robe_and_an_affinity_then_run_with_them() -> void:
	var profile := ProfileStore.new("")
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	var repo := ContentRepository.load_all()
	var ash: RobeDefinition = repo.get_def(&"robe", &"ash")
	var guardian: AffinityDefinition = repo.get_def(&"affinity", &"guardian")
	var walk := HubWalk.new(e)
	assert_true(await walk.enter(), "Play goes to the hub")
	assert_eq(main.hub.view.avatar.runes.glyph, 0, "a fresh profile: no rune (None)")
	await walk.use(&"wardrobe")
	var panel := main.get_node_or_null("UI/WardrobePanel") as WardrobePanel
	assert_not_null(panel, "E at the Wardrobe opens its panel")
	if panel == null:
		return
	assert_eq(_focused(main), panel.robe_cycler, "the robe has focus")
	await e.tap(KEY_RIGHT)
	assert_eq(panel.worn_robe, &"ash", "Right: Ash")
	assert_eq(main.hub.view.avatar.cloak_color, ash.cloak, "the hub's hero wears it at once")
	await e.tap(KEY_DOWN)
	assert_eq(_focused(main), panel.affinity_cycler, "Down: the affinity")
	for k in 5:
		await e.tap(KEY_RIGHT)
	assert_eq(panel.affinity, &"guardian", "five steps: Guardian")
	assert_true(panel.desc.text.contains(tr("AFFINITY_GUARDIAN_DESC")), "its line")
	assert_eq(main.hub.view.avatar.runes.glyph, guardian.glyph, "the hub's hero shows its rune")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/WardrobePanel"), "Esc closes it")
	assert_eq(Wardrobe.robe_of(profile), &"ash", "the profile keeps the robe")
	assert_eq(Wardrobe.affinity_of(profile), &"guardian", "and the affinity")
	# The run: the Portal Machine's build screen, Enter (Blade).
	await walk.use(&"portal")
	await e.tap(KEY_ENTER)
	await e.loaded()
	await e.frames(4)
	assert_true(await e.landed(), "the run's first floor")
	assert_eq(main.run.affinity, &"guardian", "the run locked Guardian")
	var r := main.driver.reader
	assert_eq(r.affinity_id(), &"guardian", "the floor's affinity")
	assert_eq(r.affinity_ward(), 1, "its ward up")
	var hero := _hero(main)
	assert_eq(hero.cloak_color, ash.cloak, "the hero wears Ash in the run")
	assert_true(hero.runes.visible and hero.runes.circle.visible, "the rune circle under the feet")
	assert_true(hero.runes.back.visible, "and the rune on the robe's back")
	var tint: Color = (hero.runes.circle.material_override as ShaderMaterial).get_shader_parameter(
		&"tint"
	)
	assert_eq(tint, guardian.color, "in Guardian's gold")
	# Back to the hub: the pause menu's last row leads there (owner 2026-10-23, the PLAN's HB row).
	assert_true(await walk.from_run(), "the pause menu: to the Rune Ring")
	assert_eq(main.hub.view.avatar.cloak_color, ash.cloak, "the hub remembers the robe")
	assert_eq(main.hub.view.avatar.runes.glyph, guardian.glyph, "and the affinity")
	await walk.use(&"wardrobe")
	panel = main.get_node_or_null("UI/WardrobePanel") as WardrobePanel
	assert_not_null(panel)
	if panel != null:
		assert_eq(panel.robe_cycler.value(), "ash", "the Wardrobe shows Ash")
		assert_eq(panel.affinity_cycler.value(), "guardian", "and Guardian")


func test_buy_the_hidden_robe_and_run_in_it() -> void:
	var profile := ProfileStore.new("")
	MetaProgress.bank(profile, 260)  # earlier runs' fragments (a test helper)
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	var repo := ContentRepository.load_all()
	var fallen: RobeDefinition = repo.get_def(&"robe", &"fallen")
	var walk := HubWalk.new(e)
	assert_true(await walk.enter(), "Play goes to the hub")
	await walk.use(&"progression")
	var station := main.get_node_or_null("UI/ProgressionPanel") as ProgressionPanel
	assert_not_null(station, "E at the Progression Station opens its panel")
	if station == null:
		return
	var row := station.rows[4]
	assert_eq(row.get_meta(&"robe"), &"fallen")
	assert_true(row.text.begins_with(tr("ROBE_HIDDEN")), "listed as ???")
	assert_true(row.text.ends_with(tr("PROGRESSION_PRICE") % 250), "250 fragments")
	for k in 4:
		await e.tap(KEY_DOWN)
	assert_eq(_focused(main), row, "Down x4: the ??? robe")
	await e.tap(KEY_ENTER)
	assert_true(Wardrobe.robe_unlocked(profile, fallen), "Enter bought it")
	assert_eq(MetaProgress.fragments(profile), 10, "250 spent")
	assert_true(row.text.begins_with(tr("ROBE_FALLEN")), "revealed")
	assert_eq(station.status.text, tr("PROGRESSION_REVEALED") % tr("ROBE_FALLEN"))
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	await walk.use(&"wardrobe")
	var panel := main.get_node_or_null("UI/WardrobePanel") as WardrobePanel
	assert_not_null(panel)
	if panel == null:
		return
	for k in 6:
		await e.tap(KEY_RIGHT)
	assert_eq(panel.robe_cycler.value(), "fallen", "Right x6: The Fallen's Regalia")
	assert_false(panel.lock_note.visible, "owned: not locked")
	assert_eq(panel.worn_robe, &"fallen", "worn")
	var hub_hero := main.hub.view.avatar
	assert_not_null(hub_hero.epic, "the hub's hero builds the epic robe")
	if hub_hero.epic != null:
		assert_not_null(hub_hero.epic.crown, "its crown")
		assert_not_null(hub_hero.epic.eyes, "its eyes")
	assert_false(hub_hero.visor.visible, "no blue square with the red eyes")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_eq(Wardrobe.robe_of(profile), &"fallen", "the profile keeps it")
	await walk.use(&"portal")
	await e.tap(KEY_ENTER)
	await e.loaded()
	await e.frames(4)
	assert_true(await e.landed(), "the run's first floor")
	var hero := _hero(main)
	assert_not_null(hero.epic, "the hero wears it in the run")
	if hero.epic != null:
		assert_eq(hero.epic.style, &"fallen")
	assert_false(hero.visor.visible, "the eyes are its face")
	assert_eq(ElementLooks.player_energy(), ElementLooks.FALLEN_CORE, "the plain shots are violet")
	assert_eq(AttackView.bolt_look_of(main.driver.reader)["color"], ElementLooks.FALLEN_CORE)
	assert_eq(get_errors().size(), 0, "no engine or script error")
