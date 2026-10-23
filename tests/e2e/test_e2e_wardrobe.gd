extends GutTest
## v0.9.0 RB (owner, PLAN "Owner decisions" RB) through main.tscn with real input only: Play -> the hub, the hero
## walks to the Wardrobe and E opens it; Right picks the Ash robe, Down then Right x5 picks Guardian; the hub's hero
## wears both at once; Esc closes it and the profile keeps them; the Portal Machine starts a run that has Guardian
## locked in (its ward up, the gold rune under the hero's feet and on the robe's back, the robe Ash); the run's pause
## leaves to the main menu, Play goes back to the hub, and the hero there still wears Ash and the Guardian rune; the
## Wardrobe shows both again.


func after_each() -> void:
	E2e.center_sticks()


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
	# Back to the hub: the pause's last row (HB, owner 2026-10-23: "To the hub", was Main menu).
	assert_true(await walk.from_run(), "the pause's To the Rune Ring: the hub again")
	assert_eq(main.hub.view.avatar.cloak_color, ash.cloak, "the hub remembers the robe")
	assert_eq(main.hub.view.avatar.runes.glyph, guardian.glyph, "and the affinity")
	await walk.use(&"wardrobe")
	panel = main.get_node_or_null("UI/WardrobePanel") as WardrobePanel
	assert_not_null(panel)
	if panel != null:
		assert_eq(panel.robe_cycler.value(), "ash", "the Wardrobe shows Ash")
		assert_eq(panel.affinity_cycler.value(), "guardian", "and Guardian")
